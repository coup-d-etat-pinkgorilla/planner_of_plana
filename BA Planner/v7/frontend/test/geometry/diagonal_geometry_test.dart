// FE1-b 기하 단위 테스트.
//
// 공용 기하 API(lib/ui/geometry/diagonal_geometry.dart)가 교체 전 인라인 식과 **비트 단위로 같은 값**을
// 내는지 대표 입력으로 확인한다. 동작 보존 slice라 `closeTo`가 아니라 정확히 같은지(`equals`) 본다.
// golden 장면에서 실행되지 않는 계산 줄도 이 테스트가 공개 함수를 통해 덮는다.
// 아래 `_legacy*` 함수는 FE1-b 이전 코드를 그대로 옮긴 비교 기준이다(수정하지 않는다).
import 'dart:math' as math;

import 'package:ba_planner_v7/ui/geometry/diagonal_geometry.dart';
import 'package:ba_planner_v7/ui/widgets/account_section_cluster.dart'
    show portraitGridTrajectoryOffset;
import 'package:ba_planner_v7/ui/widgets/diagonal_flow_indicator.dart'
    show diagonalParallelogramBottomCenterX;
import 'package:ba_planner_v7/ui/widgets/diagonal_menu.dart'
    show roundedPolygonPath;
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart'
    show
        planPhaseRowHorizontalOffset,
        planPhaseRowWidth,
        planScenarioParallelogramDepth;
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart'
    show buildRoundedSectionPolygon, sectionTemplateCutDepth;
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart'
    show
        studentDiagonalFilterRowWidth,
        studentDiagonalRowHorizontalOffset,
        studentFilterGroupContentInset,
        studentStarSegmentDepth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 교체 전 인라인 식.
double get _legacyTan80 => math.tan(80 * math.pi / 180);
double get _legacySin80 => math.sin(80 * math.pi / 180);

const _heights = <double>[
  0,
  0.5,
  1,
  7.25,
  13.6,
  38,
  65,
  69,
  94.3,
  142,
  587.4,
  1183,
  1208,
  1392,
  -3.5,
];

void _expectSamePath(Path actual, Path expected) {
  expect(actual.getBounds(), expected.getBounds());
  final actualMetrics = actual.computeMetrics().toList();
  final expectedMetrics = expected.computeMetrics().toList();
  expect(actualMetrics, hasLength(expectedMetrics.length));
  for (var index = 0; index < expectedMetrics.length; index++) {
    final a = actualMetrics[index];
    final e = expectedMetrics[index];
    expect(a.length, e.length);
    expect(a.isClosed, e.isClosed);
    for (var step = 0; step <= 16; step++) {
      final offset = e.length * step / 16;
      expect(
        a.getTangentForOffset(offset)!.position,
        e.getTangentForOffset(offset)!.position,
      );
    }
  }
}

List<Offset> _parallelogram(Rect rect) {
  final depth = rect.height / _legacyTan80;
  return [
    Offset(rect.left + depth, rect.top),
    rect.topRight,
    Offset(rect.right - depth, rect.bottom),
    rect.bottomLeft,
  ];
}

final _polygons = <List<Offset>>[
  _parallelogram(const Rect.fromLTWH(0, 0, 900, 142)),
  _parallelogram(const Rect.fromLTWH(12.5, 40, 520, 65)),
  const [Offset(0, 0), Offset(587, 0), Offset(400, 1183), Offset(0, 1183)],
  const [Offset(0, 0), Offset(90, 28), Offset(0, 56)],
  const [Offset(0, 0), Offset(0, 0), Offset(40, 0), Offset(40, 30)],
];

void main() {
  test('80 degree constants are bit-identical to the former inline forms', () {
    expect(diagonalTan80, _legacyTan80);
    expect(diagonalSin80, _legacySin80);
    expect(diagonalAngleDegrees, 80);
  });

  test('cut depth, rise, normal inset and rails match inline arithmetic', () {
    for (final h in _heights) {
      expect(diagonalCutDepth(h), h / _legacyTan80, reason: 'cutDepth($h)');
      expect(diagonalRiseForRun(h), h * _legacyTan80, reason: 'rise($h)');
      expect(
        diagonalNormalInset(h),
        h / _legacySin80,
        reason: 'normalInset($h)',
      );
      expect(
        diagonalRightRailX(right: 2560 - 10, y: h),
        2560 - 10 - h / _legacyTan80,
      );
      expect(diagonalLeftRailX(left: 24, y: h), 24 + h / _legacyTan80);
    }
    // int 입력(math.max(0, …)이 int 0을 돌려주는 경우)도 같은 double이 된다.
    expect(diagonalCutDepth(0), 0 / _legacyTan80);
    expect(diagonalCutDepth(math.max(0, -4)), 0 / _legacyTan80);
  });

  test('row offset modes match the former translate and resize formulas', () {
    for (final viewport in const <double>[0, 69, 420.5, 1183]) {
      for (final row in const <double>[0, 38, 65, 69, 140.25]) {
        expect(
          diagonalRowTranslateOffset(
            viewportHeight: viewport,
            rowBottomInViewport: row,
          ),
          (viewport - row) / _legacyTan80,
        );
        expect(
          diagonalRowResizeReduction(viewportHeight: viewport, rowHeight: row),
          (viewport - row) / _legacyTan80,
        );
      }
    }
  });

  test('public layout helpers keep their former values', () {
    for (final h in _heights) {
      expect(planScenarioParallelogramDepth(h), h / _legacyTan80);
      expect(sectionTemplateCutDepth(h), h / _legacyTan80);
      expect(studentFilterGroupContentInset(h), h / _legacyTan80 + 8);
      expect(
        diagonalParallelogramBottomCenterX(width: 520, height: h),
        (520 - h / _legacyTan80) / 2,
      );
      final rect = Rect.fromLTWH(3, 4, 150, h.abs());
      expect(
        studentStarSegmentDepth(rect),
        math.min(rect.width * 0.45, rect.height / _legacyTan80),
      );
    }

    for (final viewportHeight in const <double>[0, 69, 600, 1183]) {
      for (final viewportY in const <double>[-20, 0, 33.3, 600, 2000]) {
        final legacy = viewportHeight <= 0
            ? 0
            : (viewportHeight - viewportY.clamp(0.0, viewportHeight)) /
                  _legacyTan80;
        expect(portraitGridTrajectoryOffset(viewportY, viewportHeight), legacy);
      }
      for (final rowTop in const <double>[0, 69, 345]) {
        for (final scroll in const <double>[0, 17.5, 400]) {
          final bottom = rowTop + 65 - scroll;
          final legacy = (viewportHeight - bottom) / _legacyTan80;
          expect(
            planPhaseRowHorizontalOffset(
              viewportHeight: viewportHeight,
              rowTop: rowTop,
              rowHeight: 65,
              scrollOffset: scroll,
            ),
            legacy,
          );
          expect(
            studentDiagonalRowHorizontalOffset(
              viewportHeight: viewportHeight,
              rowTop: rowTop,
              rowHeight: 65,
              scrollOffset: scroll,
            ),
            legacy,
          );
        }
      }
      expect(
        planPhaseRowWidth(
          viewportWidth: 587,
          viewportHeight: viewportHeight,
          rowHeight: 65,
        ),
        math.max(
          116,
          587 - 8.0 * 2 - 14.0 - (viewportHeight - 65) / _legacyTan80,
        ),
      );
      expect(
        studentDiagonalFilterRowWidth(
          viewportWidth: 587,
          viewportHeight: viewportHeight,
          rowHeight: 38,
          horizontalInset: 8,
          scrollbarReserve: 14,
        ),
        math.max(
          120.0,
          587 - 8 * 2 - 14 - (viewportHeight - 38) / _legacyTan80,
        ),
      );
    }
  });

  test('rounded polygon wrappers reproduce the former arc and Q paths', () {
    for (final points in _polygons) {
      for (final radius in const <double>[0, 7, 10, 14, 40]) {
        _expectSamePath(
          buildRoundedSectionPolygon(points, radius: radius),
          _legacyArcRoundedPolygon(points, radius: radius),
        );
        _expectSamePath(
          diagonalRoundedPolygon(points, radius: radius),
          _legacyArcRoundedPolygon(points, radius: radius),
        );
        if (points.toSet().length == points.length) {
          _expectSamePath(
            roundedPolygonPath(points, radius),
            _legacyQuadraticRoundedPolygon(points, radius),
          );
          _expectSamePath(
            diagonalRoundedPolygon(
              points,
              radius: radius,
              corner: DiagonalCornerStyle.quadratic,
            ),
            _legacyQuadraticRoundedPolygon(points, radius),
          );
        }
      }
    }
    // 점이 3개 미만이면 원호 방식은 이전처럼 각진 다각형을 돌려준다.
    const line = [Offset(0, 0), Offset(10, 10)];
    _expectSamePath(
      diagonalRoundedPolygon(line, radius: 14),
      _legacyArcRoundedPolygon(line),
    );
  });
}

// --- FE1-b 이전 구현(비교 기준, 그대로 옮김) ----------------------------------
Path _legacyArcRoundedPolygon(List<Offset> points, {double radius = 14}) {
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

Path _legacyQuadraticRoundedPolygon(List<Offset> points, double radius) {
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
