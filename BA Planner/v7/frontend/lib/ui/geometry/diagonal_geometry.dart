// BA Planner의 80° 사선 기하 공용 API (FE1-b, 2026-10-06).
//
// 이전에는 `math.tan(80 * math.pi / 180)`이 lib 전체에 108번 인라인으로 흩어져 있었다.
// 이 파일은 그 계산과 둥근 다각형을 한 곳에 모은다. 모든 함수는 기존 인라인 식과
// **같은 연산을 같은 순서로** 수행하도록 썼다(동작 보존 slice, golden diff 0이 완료 조건).
// 연산 순서를 바꾸면 부동소수점 결과가 1ulp 달라져 픽셀이 바뀔 수 있으므로,
// 여기 식을 "정리"할 때는 golden으로 다시 확인한다.
//
// 용어
// - run(가로 이동) = rise(세로 높이) / tan80. 80° 변이 높이 h를 올라가는 동안 가로로 가는 거리.
// - 레일: 섹션의 80° 변. 위에서 아래로 내려갈수록 오른쪽 레일은 왼쪽으로 cutDepth(y)만큼 들어온다.
// - 법선 간격 g: 80° 변에 수직인 간격. 가로로 재면 g / sin80.
import 'dart:math' as math;
import 'dart:ui';

/// 사선 각도(도).
const diagonalAngleDegrees = 80.0;

/// tan 80°. 기존 인라인 식 `math.tan(80 * math.pi / 180)`과 비트 단위로 같은 값이다.
final double diagonalTan80 = math.tan(80 * math.pi / 180);

/// sin 80°. 기존 인라인 식 `math.sin(80 * math.pi / 180)`과 비트 단위로 같은 값이다.
final double diagonalSin80 = math.sin(80 * math.pi / 180);

/// 높이 [height]만큼의 80° 변이 가로로 차지하는 깊이: `height / tan80`.
///
/// 섹션 컷 깊이, 레일 inset, 평행사변형 기울기 폭이 모두 이 값이다.
double diagonalCutDepth(num height) => height / diagonalTan80;

/// 가로 [run]만큼 가는 80° 변의 세로 높이: `run * tan80`. [diagonalCutDepth]의 역.
double diagonalRiseForRun(num run) => run * diagonalTan80;

/// 80° 변에 수직인 간격 [normalGap]을 가로 간격으로 바꾼 값: `normalGap / sin80`.
double diagonalNormalInset(num normalGap) => normalGap / diagonalSin80;

/// 오른쪽 레일의 x: 위쪽 기준 x가 [right]일 때 [y]만큼 내려간 지점.
/// `right - y / tan80`.
double diagonalRightRailX({required double right, required double y}) =>
    right - y / diagonalTan80;

/// 왼쪽 레일의 x: 위쪽 기준 x가 [left]일 때 [y]만큼 내려간 지점.
/// `left + y / tan80`.
double diagonalLeftRailX({required double left, required double y}) =>
    left + y / diagonalTan80;

/// 행 오프셋 translate 모드: 콘텐츠를 레일을 따라 가로로 민다.
///
/// 행 아래쪽 경계가 viewport 안 [rowBottomInViewport]에 있을 때, viewport 바닥까지
/// 남은 높이만큼의 run이다: `(viewportHeight - rowBottomInViewport) / tan80`.
double diagonalRowTranslateOffset({
  required double viewportHeight,
  required double rowBottomInViewport,
}) => (viewportHeight - rowBottomInViewport) / diagonalTan80;

/// 행 오프셋 resize 모드: 행 폭을 레일만큼 줄인다.
///
/// 행 높이 [rowHeight]를 뺀 viewport 높이 동안 레일이 먹는 폭이다:
/// `(viewportHeight - rowHeight) / tan80`. 행 폭 = 가용 폭 - 이 값.
double diagonalRowResizeReduction({
  required double viewportHeight,
  required double rowHeight,
}) => (viewportHeight - rowHeight) / diagonalTan80;

/// 둥근 다각형의 모서리 방식(FD-016).
enum DiagonalCornerStyle {
  /// 원호 필렛. 섹션 표면(`buildRoundedSectionPolygon`)이 쓴다.
  /// 예각에서 꼭짓점을 Q 곡선보다 더 많이 깎는다.
  arc,

  /// 꼭짓점을 제어점으로 하는 2차 베지어(Q 곡선). 홈 메뉴(`roundedPolygonPath`)가 쓴다.
  /// 시안 HTML의 path도 Q 곡선이다.
  quadratic,
}

/// 둥근 다각형 단일 API(FD-016).
///
/// 두 방식은 서로 다른 path를 낸다. FE1-b는 동작 보존이므로 어느 한쪽으로 합치지 않고,
/// 기존 두 구현을 [corner]로 고르게 묶었다. 기존 이름(`buildRoundedSectionPolygon`,
/// `roundedPolygonPath`)은 이 함수를 부르는 호환 래퍼다. 시안의 Q 곡선으로 옮기는 일은
/// 캔버스 대조 후 각 화면 slice에서 한다.
Path diagonalRoundedPolygon(
  List<Offset> points, {
  required double radius,
  DiagonalCornerStyle corner = DiagonalCornerStyle.arc,
}) => switch (corner) {
  DiagonalCornerStyle.arc => _arcRoundedPolygon(points, radius),
  DiagonalCornerStyle.quadratic => _quadraticRoundedPolygon(points, radius),
};

// 원래 section_template_surface.dart의 buildRoundedSectionPolygon 본문(내용 그대로 옮김).
Path _arcRoundedPolygon(List<Offset> points, double radius) {
  if (points.length < 3) return Path()..addPolygon(points, true);
  final entries = <({Offset start, Offset end, double radius})>[];
  for (var index = 0; index < points.length; index++) {
    final previous = points[(index - 1 + points.length) % points.length];
    final current = points[index];
    final next = points[(index + 1) % points.length];
    final towardPrevious = previous - current;
    final towardNext = next - current;
    final previousLength = towardPrevious.distance;
    final nextLength = towardNext.distance;
    if (previousLength == 0 || nextLength == 0) {
      entries.add((start: current, end: current, radius: 0));
      continue;
    }
    final previousUnit = towardPrevious / previousLength;
    final nextUnit = towardNext / nextLength;
    final cosine =
        (previousUnit.dx * nextUnit.dx + previousUnit.dy * nextUnit.dy)
            .clamp(-1.0, 1.0)
            .toDouble();
    final cornerAngle = math.acos(cosine);
    // 80° 계산이 아니라 필렛 반각이다(FE1-b 교체 대상 아님).
    final halfAngleTangent = math.tan(cornerAngle / 2).abs();
    final requestedCut = halfAngleTangent < 1e-6
        ? double.infinity
        : radius / halfAngleTangent;
    // Keep more of each straight edge visible before an acute corner starts to
    // turn. The circular fillet below still removes substantially more of the
    // sharp tip than the former quadratic curve through the original vertex.
    final availableCut = math.min(previousLength, nextLength) * 0.36;
    final cut = math.min(requestedCut, availableCut);
    entries.add((
      start: current + towardPrevious / previousLength * cut,
      end: current + towardNext / nextLength * cut,
      radius: cut * halfAngleTangent,
    ));
  }

  var twiceSignedArea = 0.0;
  for (var index = 0; index < points.length; index++) {
    final current = points[index];
    final next = points[(index + 1) % points.length];
    twiceSignedArea += current.dx * next.dy - current.dy * next.dx;
  }
  // Follow the polygon winding so arcToPoint chooses the convex fillet. Using
  // the opposite sweep selects the other circle center and carves a concave
  // notch into the surface.
  final clockwise = twiceSignedArea > 0;
  final path = Path()..moveTo(entries.first.start.dx, entries.first.start.dy);
  for (var index = 0; index < points.length; index++) {
    final entry = entries[index];
    if (index > 0) path.lineTo(entry.start.dx, entry.start.dy);
    if (entry.radius <= 1e-6) {
      path.lineTo(entry.end.dx, entry.end.dy);
    } else {
      path.arcToPoint(
        entry.end,
        radius: Radius.circular(entry.radius),
        clockwise: clockwise,
      );
    }
  }
  return path
    ..lineTo(entries.first.start.dx, entries.first.start.dy)
    ..close();
}

// 원래 diagonal_menu.dart의 roundedPolygonPath 본문(내용 그대로 옮김).
Path _quadraticRoundedPolygon(List<Offset> points, double radius) {
  assert(points.length >= 3);
  final path = Path();
  final starts = <Offset>[];
  final ends = <Offset>[];

  for (var index = 0; index < points.length; index++) {
    final previous = points[(index - 1 + points.length) % points.length];
    final current = points[index];
    final next = points[(index + 1) % points.length];
    final before = (previous - current).distance;
    final after = (next - current).distance;
    final resolvedRadius = math.min(radius, math.min(before, after) / 2);
    starts.add(
      current +
          (previous - current) * (resolvedRadius / math.max(0.001, before)),
    );
    ends.add(
      current + (next - current) * (resolvedRadius / math.max(0.001, after)),
    );
  }

  path.moveTo(ends.last.dx, ends.last.dy);
  for (var index = 0; index < points.length; index++) {
    path
      ..lineTo(starts[index].dx, starts[index].dy)
      ..quadraticBezierTo(
        points[index].dx,
        points[index].dy,
        ends[index].dx,
        ends[index].dy,
      );
  }
  return path..close();
}
