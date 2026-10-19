// FE6-d 공용 섹션 morph 테스트: 0 · 1에서 원래 path와 같음, 중간값 단조, 계단 없음(정수 grid 반올림 없음), 사선 80°
// 유지, 퇴장 · 등장 오프셋, 확장 시퀀스 구간.
import 'dart:math' as math;

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/section_morph.dart';
import 'package:ba_planner_v7/ui/studio/section_template.dart';
import 'package:ba_planner_v7/ui/widgets/animated_section_stack.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(2560, 1208);
final _tan10 = math.tan(10 * math.pi / 180);

/// 오른쪽 면 사다리꼴(인벤토리 S2 접힘 → 확장과 같은 꼴).
const _small = SectionCanvasElement(
  id: 'small',
  label: 'small',
  rect: SectionGridRect(52, 2, 44, 51),
  spec: AttachedSectionSpec(
    mode: SectionShapeMode.trapezoid,
    face: SectionAttachmentFace.right,
    faceSpan: 85,
    height: 88,
  ),
);

const _large = SectionCanvasElement(
  id: 'large',
  label: 'large',
  rect: SectionGridRect(0, 2, 96, 94),
  spec: AttachedSectionSpec(
    mode: SectionShapeMode.trapezoid,
    face: SectionAttachmentFace.right,
    faceSpan: 96,
    height: 96,
  ),
);

/// 위 면 평행사변형 두 개(face 구간 · 깊이가 다르다).
const _topA = SectionCanvasElement(
  id: 'top-a',
  label: 'top-a',
  rect: SectionGridRect(20, 2, 44, 47),
  spec: AttachedSectionSpec(
    mode: SectionShapeMode.parallelogram,
    face: SectionAttachmentFace.top,
    faceStart: 15,
    faceSpan: 69,
    height: 96,
  ),
);

const _topB = SectionCanvasElement(
  id: 'top-b',
  label: 'top-b',
  rect: SectionGridRect(3, 2, 74, 35),
  spec: AttachedSectionSpec(
    mode: SectionShapeMode.parallelogram,
    face: SectionAttachmentFace.top,
    faceStart: 31,
    faceSpan: 41,
    height: 95,
  ),
);

void _expectSamePath(Path actual, Path expected) {
  final a = actual.getBounds();
  final b = expected.getBounds();
  expect(a.left, closeTo(b.left, 1e-9));
  expect(a.top, closeTo(b.top, 1e-9));
  expect(a.right, closeTo(b.right, 1e-9));
  expect(a.bottom, closeTo(b.bottom, 1e-9));
  // 같은 점들이 안 · 밖으로 같게 판정된다(모양 비교).
  for (var x = b.left - 4; x <= b.right + 4; x += 37) {
    for (var y = b.top - 4; y <= b.bottom + 4; y += 29) {
      final point = Offset(x, y);
      expect(actual.contains(point), expected.contains(point), reason: '$point');
    }
  }
}

void main() {
  test('polygon equals each end element at 0 and 1 exactly', () {
    for (final (from, to) in [(_small, _large), (_topA, _topB)]) {
      expect(
        sectionMorphPolygon(_size, from, to, 0),
        sectionCanvasElementPolygon(_size, from),
      );
      expect(
        sectionMorphPolygon(_size, from, to, 1),
        sectionCanvasElementPolygon(_size, to),
      );
    }
  });

  test('path equals buildSectionCanvasElementPath at 0 and 1 (and just inside)', () {
    _expectSamePath(
      buildSectionMorphPath(_size, _small, _large, 0),
      buildSectionCanvasElementPath(_size, _small),
    );
    _expectSamePath(
      buildSectionMorphPath(_size, _small, _large, 1),
      buildSectionCanvasElementPath(_size, _large),
    );
    // 끝 바로 안쪽도 보간 경로로 만든 path가 원래 path와 겹친다(0 · 1의 짧은 길이 실제 보간과 이어진다).
    final near = buildSectionMorphPath(_size, _small, _large, 1e-12).getBounds();
    final original = buildSectionCanvasElementPath(_size, _small).getBounds();
    expect(near.left, closeTo(original.left, 1e-6));
    expect(near.bottom, closeTo(original.bottom, 1e-6));
  });

  test('rect is a real lerp (no grid rounding)', () {
    final from = sectionCanvasElementRect(_size, _small);
    final to = sectionCanvasElementRect(_size, _large);
    final mid = sectionMorphRect(_size, _small, _large, 0.37);
    expect(mid.left, closeTo(from.left + (to.left - from.left) * 0.37, 1e-9));
    expect(mid.height, closeTo(from.height + (to.height - from.height) * 0.37, 1e-9));
    // grid 한 칸(26.67px)의 배수가 아니다.
    final cell = _size.width / sectionTemplateGridSize;
    final remainder = mid.left % cell;
    expect(remainder > 0.5 && remainder < cell - 0.5, isTrue);
  });

  test('middle values are monotone and have no steps', () {
    const samples = 1000;
    final start = sectionCanvasElementPolygon(_size, _small);
    final end = sectionCanvasElementPolygon(_size, _large);
    var previous = sectionMorphPolygon(_size, _small, _large, 0);
    var previousBounds = buildSectionMorphPath(_size, _small, _large, 0).getBounds();
    for (var step = 1; step <= samples; step++) {
      final t = step / samples;
      final points = sectionMorphPolygon(_size, _small, _large, t);
      for (var index = 0; index < points.length; index++) {
        final total = end[index] - start[index];
        final delta = points[index] - previous[index];
        // 같은 방향으로만(단조) 움직이고, 한 걸음이 전체 변화 / 표본 수를 넘지 않는다(계단 없음).
        expect(delta.dx * total.dx >= -1e-9, isTrue, reason: 'x monotone $index@$t');
        expect(delta.dy * total.dy >= -1e-9, isTrue, reason: 'y monotone $index@$t');
        expect(delta.dx.abs(), lessThanOrEqualTo(total.dx.abs() / samples + 1e-6));
        expect(delta.dy.abs(), lessThanOrEqualTo(total.dy.abs() / samples + 1e-6));
      }
      if (step % 50 == 0) {
        final bounds = buildSectionMorphPath(_size, _small, _large, t).getBounds();
        // path 좌표는 float32라 허용치를 1e-3으로 둔다.
        expect(bounds.left, lessThanOrEqualTo(previousBounds.left + 1e-3));
        expect(bounds.bottom, greaterThanOrEqualTo(previousBounds.bottom - 1e-3));
        expect(bounds.right, closeTo(_size.width, 1e-3));
        previousBounds = bounds;
      }
      previous = points;
    }
  });

  test('the diagonal stays 80 degrees and inside the lerped rect', () {
    for (final t in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
      // 오른쪽 면 사다리꼴: [위 오른, 아래 오른, 아래 왼, 위 왼]. 왼쪽 변이 사선이다.
      final points = sectionMorphPolygon(_size, _small, _large, t);
      final bottomLeft = points[2];
      final topLeft = points[3];
      expect(
        topLeft.dx - bottomLeft.dx,
        closeTo((bottomLeft.dy - topLeft.dy) * _tan10, 1e-6),
        reason: 't=$t',
      );
      final rect = sectionMorphRect(_size, _small, _large, t).inflate(1e-6);
      for (final point in points) {
        expect(rect.contains(point), isTrue, reason: '$point in $rect at $t');
      }
      // 평행사변형(위 면)의 양쪽 변.
      final top = sectionMorphPolygon(_size, _topA, _topB, t);
      for (final (upper, lower) in [(top[0], top[3]), (top[1], top[2])]) {
        expect(upper.dx - lower.dx, closeTo((lower.dy - upper.dy) * _tan10, 1e-6));
      }
    }
  });

  test('exit and entry offsets follow the attachment-face angles', () {
    expect(sectionExitOffset(_size, 0, 0), Offset.zero);
    expect(sectionExitOffset(_size, 180, 1), sectionMotionOffset(_size, 180));
    expect(sectionExitOffset(_size, 180, 1).dx, closeTo(-(_size.width + 40), 1e-6));
    expect(sectionExitOffset(_size, 0, 0.5).dx, closeTo((_size.width + 40) / 2, 1e-6));
    // 위로(80°) 나가면 y가 줄고, 아래로(260°) 나가면 y가 는다.
    expect(sectionExitOffset(_size, 80, 1).dy, lessThan(-_size.height));
    expect(sectionExitOffset(_size, 260, 1).dy, greaterThan(_size.height));
    expect(sectionEntryOffset(_size, 0, 1), Offset.zero);
    expect(sectionEntryOffset(_size, 0, 0), -sectionMotionOffset(_size, 0));
  });

  test('timeline splits exit, morph and reveal in AppMotion lengths', () {
    const timeline = SectionMorphTimeline();
    expect(
      timeline.total,
      AppMotion.section + AppMotion.section + AppMotion.header,
    );
    final exitEnd =
        AppMotion.section.inMicroseconds / timeline.total.inMicroseconds;
    final morphEnd =
        (AppMotion.section * 2).inMicroseconds / timeline.total.inMicroseconds;
    expect(timeline.exitProgress(0), 0);
    expect(timeline.exitProgress(exitEnd), closeTo(1, 1e-9));
    expect(timeline.morphProgress(exitEnd), closeTo(0, 1e-9));
    expect(timeline.morphProgress(morphEnd), closeTo(1, 1e-9));
    expect(timeline.revealProgress(morphEnd), closeTo(0, 1e-9));
    expect(timeline.revealProgress(1), 1);
    var last = (-1.0, -1.0, -1.0);
    for (var step = 0; step <= 100; step++) {
      final value = step / 100;
      final now = (
        timeline.exitProgress(value),
        timeline.morphProgress(value),
        timeline.revealProgress(value),
      );
      expect(now.$1 >= last.$1 && now.$2 >= last.$2 && now.$3 >= last.$3, isTrue);
      // 한 번에 한 구간만 움직인다(앞 구간이 끝나야 다음이 시작).
      if (now.$2 > 0) expect(now.$1, closeTo(1, 1e-9));
      if (now.$3 > 0) expect(now.$2, closeTo(1, 1e-9));
      last = now;
    }
  });
}
