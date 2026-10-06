// FE2-a 공용 사선 스크롤바 테스트.
//
// 동작 보존 확인: 이전 화면별 painter(코드 그대로 아래에 복사)와 공용 painter가 같은 그리기 명령을
// 내는지 여러 크기·스크롤 값에서 비교한다. golden 17장(사용자 PC)과 함께 "현재 렌더 재현"의 근거다.
import 'dart:math' as math;

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/geometry/diagonal_geometry.dart';
import 'package:ba_planner_v7/ui/kit/diagonal_scrollbar.dart';
import 'package:ba_planner_v7/ui/kit/scroll_viewport_fog.dart';
import 'package:ba_planner_v7/ui/widgets/account_section_cluster.dart'
    show portraitScrollbarTrackPoint;
import 'package:ba_planner_v7/ui/widgets/plan_phase_editor.dart'
    show phaseEditorScrollbarStyle, phaseEditorScrollbarTrackPoint;
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart'
    show studentScrollbarDragPath, studentScrollbarTrackPoint;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// 그리기 명령 기록

class _OpLog implements Canvas {
  final ops = <String>[];

  static String _point(Offset point) => '${point.dx},${point.dy}';

  static String _paint(Paint paint) {
    final color = paint.color;
    return 'color=${color.a},${color.r},${color.g},${color.b} '
        'width=${paint.strokeWidth} cap=${paint.strokeCap} '
        'style=${paint.style}';
  }

  @override
  void drawPath(Path path, Paint paint) {
    final segments = [
      for (final metric in path.computeMetrics())
        '${_point(metric.getTangentForOffset(0)!.position)}'
            '->${_point(metric.getTangentForOffset(metric.length)!.position)}',
    ];
    ops.add('path ${segments.join(' ')} ${_paint(paint)}');
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    ops.add('line ${_point(p1)}->${_point(p2)} ${_paint(paint)}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      fail('unexpected canvas call: ${invocation.memberName}');
}

List<String> _record(CustomPainter painter, Size size) {
  final log = _OpLog();
  painter.paint(log, size);
  return log.ops;
}

// ---------------------------------------------------------------------------
// FE2-a 이전 코드(pre 사본에서 그대로 복사). 비교 기준으로만 쓴다.

Offset _oldPlanTrackPoint(Size size, double y, {double trackInset = 10}) {
  final depth = diagonalCutDepth(size.height);
  final clampedY = y.clamp(0.0, size.height);
  return Offset(
    size.width -
        trackInset -
        depth +
        diagonalCutDepth(size.height - clampedY),
    clampedY,
  );
}

/// plan_section_layout `_PlanDiagonalScrollbarPainter`(학생 painter도 같은 코드).
/// 계정 painter는 레일 점과 썸 색만 다르다.
class _OldViewportPainter extends CustomPainter {
  const _OldViewportPainter({
    required this.offset,
    required this.maxScrollExtent,
    required this.handleHeight,
    this.trackPoint = _oldPlanTrackPoint,
    this.thumbColor = AppColors.scrollThumb,
  });

  final double offset;
  final double maxScrollExtent;
  final double handleHeight;
  final DiagonalScrollbarTrackPoint trackPoint;
  final Color thumbColor;
  static const trackInset = 10.0;

  Path _segment(Size size, double top, double bottom) {
    final start = trackPoint(size, top, trackInset: trackInset);
    final end = trackPoint(size, bottom, trackInset: trackInset);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trackBottom = size.height - trackInset;
    canvas.drawPath(
      _segment(size, trackInset, trackBottom),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.outline.withValues(alpha: 0.48),
    );
    if (maxScrollExtent <= 0) return;
    final travel = math.max(0.0, trackBottom - trackInset - handleHeight);
    final top =
        trackInset + travel * (offset / maxScrollExtent).clamp(0.0, 1.0);
    canvas.drawPath(
      _segment(size, top, top + handleHeight),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = thumbColor,
    );
  }

  @override
  bool shouldRepaint(_OldViewportPainter oldDelegate) => true;
}

/// plan_element_builder `_PlanPresetDiagonalScrollbarPainter`.
class _OldPresetPainter extends CustomPainter {
  const _OldPresetPainter({required this.offset, required this.contentExtent});

  final double offset;
  final double contentExtent;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 10.0;
    final trackHeight = math.max(1.0, size.height - inset * 2);
    final maxScroll = math.max(0.0, contentExtent - size.height);
    final handleHeight = maxScroll <= 0
        ? trackHeight
        : math.max(28.0, trackHeight * size.height / contentExtent);
    final travel = math.max(0.0, trackHeight - handleHeight);
    final handleTop =
        inset +
        (maxScroll <= 0 ? 0 : travel * (offset / maxScroll).clamp(0.0, 1.0));
    Offset point(double y) =>
        Offset(diagonalRightRailX(right: size.width - inset, y: y), y);
    final trackPaint = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.48)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final handlePaint = Paint()
      ..color = AppColors.scrollThumb
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(point(inset), point(size.height - inset), trackPaint);
    if (maxScroll <= 0) return;
    canvas.drawLine(
      point(handleTop),
      point(handleTop + handleHeight),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(_OldPresetPainter oldDelegate) => true;
}

/// plan_phase_editor `_PhaseEditorDiagonalScrollbarPainter`.
class _OldPhasePainter extends CustomPainter {
  const _OldPhasePainter({required this.offset, required this.contentExtent});

  final double offset;
  final double contentExtent;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 10.0;
    final trackHeight = math.max(1.0, size.height - inset * 2);
    final maxScroll = math.max(0.0, contentExtent - size.height);
    final handleHeight = maxScroll <= 0
        ? trackHeight
        : math.max(28.0, trackHeight * size.height / contentExtent);
    final travel = math.max(0.0, trackHeight - handleHeight);
    final handleTop =
        inset +
        (maxScroll <= 0 ? 0 : travel * (offset / maxScroll).clamp(0.0, 1.0));
    Offset point(double y) =>
        _oldPlanTrackPoint(size, y, trackInset: inset);
    final trackPaint = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.38)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final handlePaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.9)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(point(inset), point(size.height - inset), trackPaint);
    canvas.drawLine(
      point(handleTop),
      point(handleTop + handleHeight),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(_OldPhasePainter oldDelegate) => true;
}

const _sizes = [Size(500, 300), Size(531.7, 417.3), Size(260.25, 96.5)];
const _offsets = [0.0, 37.3, 120.75, 5000.0];

void main() {
  group('track points', () {
    test('shared track point is the former plan formula, bit for bit', () {
      for (final size in _sizes) {
        for (final y in [-4.0, 0.0, 10.0, 77.7, size.height - 10, 999.0]) {
          expect(
            diagonalScrollbarTrackPoint(size, y),
            _oldPlanTrackPoint(size, y),
          );
          expect(studentScrollbarTrackPoint(size, y), _oldPlanTrackPoint(size, y));
          expect(
            phaseEditorScrollbarTrackPoint(size, y),
            _oldPlanTrackPoint(size, y),
          );
          expect(
            diagonalScrollbarRailTrackPoint(size, y),
            Offset(diagonalRightRailX(right: size.width - 10, y: y), y),
          );
        }
      }
    });

    test('track points follow the 80 degree rail', () {
      const size = Size(500, 300);
      final top = diagonalScrollbarTrackPoint(size, 10);
      final bottom = diagonalScrollbarTrackPoint(size, 290);
      final angle = math.atan2(bottom.dy - top.dy, top.dx - bottom.dx);
      expect(angle * 180 / math.pi, closeTo(diagonalAngleDegrees, 1e-9));
      final railTop = diagonalScrollbarRailTrackPoint(size, 10);
      final railBottom = diagonalScrollbarRailTrackPoint(size, 290);
      expect(railTop.dx, closeTo(top.dx, 1e-9));
      expect(railBottom.dx, closeTo(bottom.dx, 1e-9));
    });

    test('student drag band is the shared drag path', () {
      const size = Size(420, 360);
      final shared = diagonalScrollbarDragPath(size);
      final student = studentScrollbarDragPath(size);
      expect(student.getBounds(), shared.getBounds());
      final mid = diagonalScrollbarTrackPoint(size, 180);
      expect(shared.contains(mid), isTrue);
      expect(shared.contains(mid.translate(-20, 0)), isFalse);
    });
  });

  group('painter reproduces the former renders', () {
    test('plan and student (viewport ratio, path stroke)', () {
      for (final size in _sizes) {
        for (final maxScroll in [0.0, 87.4, 600.2]) {
          for (final handle in [28.0, 133.7]) {
            for (final offset in _offsets) {
              final expected = _record(
                _OldViewportPainter(
                  offset: offset,
                  maxScrollExtent: maxScroll,
                  handleHeight: handle,
                ),
                size,
              );
              final actual = _record(
                DiagonalScrollbarPainter(
                  offset: offset,
                  maxScrollExtent: maxScroll,
                  handleHeight: handle,
                  style: DiagonalScrollbarStyle.standard,
                ),
                size,
              );
              expect(actual, expected, reason: '$size $maxScroll $handle');
              expect(actual, hasLength(maxScroll > 0 ? 2 : 1));
            }
          }
        }
      }
    });

    test('account (portrait rail point, #8edcff thumb)', () {
      final style = DiagonalScrollbarStyle.standard.copyWith(
        thumbColor: const Color(0xff8edcff),
      );
      for (final size in _sizes) {
        for (final offset in _offsets) {
          final expected = _record(
            _OldViewportPainter(
              offset: offset,
              maxScrollExtent: 240.5,
              handleHeight: 61.2,
              trackPoint: portraitScrollbarTrackPoint,
              thumbColor: const Color(0xff8edcff),
            ),
            size,
          );
          final actual = _record(
            DiagonalScrollbarPainter(
              offset: offset,
              maxScrollExtent: 240.5,
              handleHeight: 61.2,
              style: style,
              trackPoint: portraitScrollbarTrackPoint,
            ),
            size,
          );
          expect(actual, expected);
        }
      }
    });

    test('element builder preset lists (content ratio, drawLine)', () {
      final style = DiagonalScrollbarStyle.standard.copyWith(
        stroke: DiagonalScrollbarStroke.line,
      );
      for (final size in _sizes) {
        for (final content in [size.height - 40, size.height, 812.6]) {
          for (final offset in _offsets) {
            final expected = _record(
              _OldPresetPainter(offset: offset, contentExtent: content),
              size,
            );
            final actual = _record(
              DiagonalScrollbarPainter(
                offset: offset,
                maxScrollExtent: 0,
                handleHeight: 0,
                contentExtent: content,
                style: style,
                trackPoint: diagonalScrollbarRailTrackPoint,
              ),
              size,
            );
            expect(actual, expected, reason: '$size $content $offset');
          }
        }
      }
    });

    test('phase editor (content ratio, thin accent, thumb when idle)', () {
      for (final size in _sizes) {
        for (final content in [size.height - 40, size.height, 812.6]) {
          for (final offset in _offsets) {
            final expected = _record(
              _OldPhasePainter(offset: offset, contentExtent: content),
              size,
            );
            final actual = _record(
              DiagonalScrollbarPainter(
                offset: offset,
                maxScrollExtent: 0,
                handleHeight: 0,
                contentExtent: content,
                style: phaseEditorScrollbarStyle,
              ),
              size,
            );
            expect(actual, expected, reason: '$size $content $offset');
            expect(actual, hasLength(2));
          }
        }
      }
    });
  });

  group('DiagonalScrollbar widget', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 400, height: 240, child: child)),
      ),
    );

    testWidgets('fog, painter, handle marker and rect drag', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          DiagonalScrollbar(
            keyPrefix: 'kit-test',
            controller: controller,
            contentExtent: 900,
            child: SingleChildScrollView(
              controller: controller,
              child: const SizedBox(height: 900),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fog = tester.widget<ScrollViewportFog>(
        find.byKey(const ValueKey('kit-test-fog')),
      );
      expect(fog.showTop, isFalse);
      expect(fog.showBottom, isTrue);
      expect(fog.color, scrollViewportFogColor);
      expect(fog.extent, scrollViewportFogExtent);
      expect(
        find.byKey(const ValueKey('kit-test-diagonal-scrollbar')),
        findsOneWidget,
      );
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byType(RawScrollbar), findsNothing);

      final before = tester.getRect(
        find.byKey(const ValueKey('kit-test-scrollbar-handle-center')),
      );
      await tester.drag(
        find.byKey(const ValueKey('kit-test-diagonal-scrollbar-drag')),
        const Offset(0, 60),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      final after = tester.getRect(
        find.byKey(const ValueKey('kit-test-scrollbar-handle-center')),
      );
      expect(after.top, greaterThan(before.top));
      expect(after.left, lessThan(before.left));
      expect(
        tester
            .widget<ScrollViewportFog>(
              find.byKey(const ValueKey('kit-test-fog')),
            )
            .showTop,
        isTrue,
      );
    });

    testWidgets('no fog, no drag and fog builder options', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          DiagonalScrollbar(
            keyPrefix: 'kit-plain',
            controller: controller,
            showFog: false,
            drag: DiagonalScrollbarDrag.none,
            child: SingleChildScrollView(
              controller: controller,
              child: const SizedBox(height: 900),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kit-plain-fog')), findsNothing);
      expect(
        find.byKey(const ValueKey('kit-plain-diagonal-scrollbar-drag')),
        findsNothing,
      );

      ({bool showTop, bool showBottom})? seen;
      await tester.pumpWidget(
        host(
          DiagonalScrollbar(
            keyPrefix: 'kit-built',
            controller: controller,
            drag: DiagonalScrollbarDrag.rail,
            fogBuilder: (context, visibility) {
              seen = visibility;
              return const SizedBox(key: ValueKey('kit-built-custom-fog'));
            },
            child: SingleChildScrollView(
              controller: controller,
              child: const SizedBox(height: 900),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kit-built-custom-fog')), findsOne);
      expect(seen?.showBottom, isTrue);
      expect(
        find.byKey(const ValueKey('kit-built-diagonal-scrollbar-drag')),
        findsOneWidget,
      );
    });
  });
}
