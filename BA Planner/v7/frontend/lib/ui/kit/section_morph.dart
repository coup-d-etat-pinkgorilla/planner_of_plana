// 공용 섹션 morph(FE6-d, 시안 Inventory-Analysis-Opa, E 보고서 §4.4). 한 섹션이 다른 rect · 깊이로 커지거나 줄어드는
// 동안의 표면 path와, 나머지 섹션이 부착면 쪽으로 빠지는 진행을 계산한다.
//
// - rect 보간은 실수다([sectionMorphRect] = `Rect.lerp`). Studio 문서의 정수 grid(`SectionGridRect`)를 반올림하며
//   보간하면 기준 viewport에서 한 칸(가로 26.7px · 세로 12.6px)씩 계단이 지므로 grid를 거치지 않는다(옛 페이즈 편집기
//   `plan_phase_editor.dart`의 private `_lerpGridRect`가 `.round()` 보간이었다. 그 파일은 FE5-f2에서 지웠다).
// - path는 두 끝 element의 꼭짓점(`buildAttachedSectionPolygon`, 같은 mode · face)을 실수로 보간한 polygon에서 같은 둥근
//   모서리 함수(`buildRoundedSectionPolygon`)와 캔버스 경계로 다시 만든다([buildSectionMorphPath]). 같은 mode · face면 두
//   끝의 사선 변이 모두 80°이고, 꼭짓점의 선형 보간도 그 기울기를 지킨다(가로 차 = tan 10° × 세로 차가 두 끝에서 성립하면
//   보간에서도 성립). 보간 polygon은 보간된 rect 안에 있다. 0 · 1에서는 원래 element path와 같다.
// - 퇴장 · 등장은 §1.4 부착면 표의 각도로 `sectionMotionOffset`만큼 민다([sectionExitOffset] · [sectionEntryOffset]).
// - [SectionMorphTimeline]: 퇴장 → morph → 상세 등장 세 구간. 구간 길이는 `AppMotion` 상수다.
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../app/theme.dart';
import '../studio/section_template.dart';
import '../widgets/animated_section_stack.dart' show sectionMotionOffset;
import '../widgets/section_template_surface.dart';

/// [from] → [to] 사이 [t](0~1)의 섹션 rect(실수 보간, grid 반올림 없음).
Rect sectionMorphRect(
  Size size,
  SectionCanvasElement from,
  SectionCanvasElement to,
  double t,
) => Rect.lerp(
  sectionCanvasElementRect(size, from),
  sectionCanvasElementRect(size, to),
  t,
)!;

/// element 한 개의 캔버스 좌표 꼭짓점(`buildSectionCanvasElementPath`와 같은 순서).
List<Offset> sectionCanvasElementPolygon(
  Size size,
  SectionCanvasElement element,
) {
  final rect = sectionCanvasElementRect(size, element);
  return [
    for (final point in buildAttachedSectionPolygon(rect.size, element.spec))
      point + rect.topLeft,
  ];
}

/// [from] → [to] 사이 [t]의 꼭짓점. 두 element는 mode · face가 같아야 한다(꼭짓점 순서가 같다).
List<Offset> sectionMorphPolygon(
  Size size,
  SectionCanvasElement from,
  SectionCanvasElement to,
  double t,
) {
  assert(
    from.spec.mode == to.spec.mode && from.spec.face == to.spec.face,
    'section morph needs the same shape mode and attachment face',
  );
  final start = sectionCanvasElementPolygon(size, from);
  final end = sectionCanvasElementPolygon(size, to);
  return [
    for (var index = 0; index < start.length; index++)
      Offset(
        lerpDouble(start[index].dx, end[index].dx, t)!,
        lerpDouble(start[index].dy, end[index].dy, t)!,
      ),
  ];
}

/// [from] → [to] 사이 [t]의 섹션 표면 path. 0 · 1에서는 `buildSectionCanvasElementPath` 그대로다.
Path buildSectionMorphPath(
  Size size,
  SectionCanvasElement from,
  SectionCanvasElement to,
  double t,
) {
  if (t <= 0) return buildSectionCanvasElementPath(size, from);
  if (t >= 1) return buildSectionCanvasElementPath(size, to);
  final raw = buildRoundedSectionPolygon(sectionMorphPolygon(size, from, to, t));
  final canvasBounds = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
    );
  return Path.combine(PathOperation.intersect, raw, canvasBounds);
}

/// 퇴장 진행 [progress](0 제자리 → 1 화면 밖)만큼 outro 방향([outroDegrees], §1.4)으로 민 거리.
Offset sectionExitOffset(Size size, double outroDegrees, double progress) =>
    sectionMotionOffset(size, outroDegrees) * progress;

/// 등장 진행 [progress](0 화면 밖 → 1 제자리). intro 방향([introDegrees])으로 움직여 들어오므로 반대쪽에서 출발한다.
Offset sectionEntryOffset(Size size, double introDegrees, double progress) =>
    sectionMotionOffset(size, introDegrees) * -(1 - progress);

/// 확장 시퀀스 구간: 다른 섹션 퇴장([exit]) → 남는 섹션 morph([morph]) → 상세 등장([reveal]). 한 AnimationController
/// 값(0~1)을 세 구간 진행으로 나눈다. 되돌리기(reverse)는 같은 값을 거꾸로 지나므로 정확히 역순이 된다.
@immutable
class SectionMorphTimeline {
  const SectionMorphTimeline({
    this.exit = AppMotion.section,
    this.morph = AppMotion.section,
    this.reveal = AppMotion.header,
    this.curve = AppMotion.sectionCurve,
  });

  final Duration exit;
  final Duration morph;
  final Duration reveal;
  final Curve curve;

  Duration get total => exit + morph + reveal;

  double get _totalMs => total.inMicroseconds.toDouble();

  double _phase(double value, Duration start, Duration length) {
    if (length == Duration.zero) return value >= 1 ? 1 : 0;
    final begin = start.inMicroseconds / _totalMs;
    final span = length.inMicroseconds / _totalMs;
    return curve.transform(((value - begin) / span).clamp(0.0, 1.0).toDouble());
  }

  /// 다른 섹션 퇴장 진행(곡선 적용).
  double exitProgress(double value) => _phase(value, Duration.zero, exit);

  /// 남는 섹션 morph 진행(곡선 적용).
  double morphProgress(double value) => _phase(value, exit, morph);

  /// 상세 등장 진행(곡선 적용).
  double revealProgress(double value) => _phase(value, exit + morph, reveal);
}
