// FE1-c 공용 섹션 표면 테스트(FD-006·FD-007).
//
// 섹션 표면 = surface@.76, 블러(BackdropFilter) 없음, 테두리 없음, lifted shadow 4층.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/studio/section_template.dart';
import 'package:ba_planner_v7/ui/widgets/diagonal_section.dart';
import 'package:ba_planner_v7/ui/widgets/lifted_path_shadow.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart'
    show planElementBuilderSectionOpacity;
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart'
    show planSectionOpacity;
import 'package:ba_planner_v7/ui/widgets/section_surface.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart'
    show studentSectionOpacity;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `paintLiftedPathShadow`가 [layer]번째 층(4 → 1 순서로 그림)에 쓰는 색.
Color _shadowLayerColor(LiftedPathShadowSpec spec, int layer) {
  final progress = layer / spec.layers;
  return spec.color.withValues(alpha: spec.maxAlpha * (1 - progress * 0.65));
}

Widget _host(Widget child) => MaterialApp(
  theme: BAPlannerTheme.dark(),
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, height: 200, child: child)),
  ),
);

void _expectSectionSurfacePainter(WidgetTester tester, Finder host) {
  final painters = tester
      .widgetList<CustomPaint>(
        find.descendant(of: host, matching: find.byType(CustomPaint)),
      )
      .map((paint) => paint.painter)
      .whereType<SectionSurfacePainter>()
      .toList();
  expect(painters, hasLength(1));
  expect(painters.single.fill, sectionSurfaceColor);
  expect(painters.single.shadow, defaultLiftedSectionShadow);
  expect(
    find.descendant(of: host, matching: find.byType(BackdropFilter)),
    findsNothing,
  );
  final borders = tester
      .widgetList<DecoratedBox>(
        find.descendant(of: host, matching: find.byType(DecoratedBox)),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .where((decoration) => decoration.border != null);
  expect(borders, isEmpty);
}

void main() {
  test('section surface uses the prototype surface at .76', () {
    expect(sectionSurfaceOpacity, 0.76);
    expect(sectionSurfaceColor, AppColors.surface.withValues(alpha: 0.76));
    // 기존 화면별 상수는 공용 값을 가리킨다.
    expect(planSectionOpacity, sectionSurfaceOpacity);
    expect(studentSectionOpacity, sectionSurfaceOpacity);
    expect(planElementBuilderSectionOpacity, sectionSurfaceOpacity);
  });

  test('paintSectionSurface draws four lifted shadow layers then the fill', () {
    final path = Path()..addRect(const Rect.fromLTWH(10, 10, 200, 120));
    void paint(Canvas canvas) => paintSectionSurface(canvas, path);

    expect(paint, paintsExactlyCountTimes(#drawPath, 5));
    const spec = defaultLiftedSectionShadow;
    expect(spec.layers, 4);
    expect(
      paint,
      paints
        ..path(color: _shadowLayerColor(spec, 4))
        ..path(color: _shadowLayerColor(spec, 3))
        ..path(color: _shadowLayerColor(spec, 2))
        ..path(color: _shadowLayerColor(spec, 1))
        ..path(color: sectionSurfaceColor, style: PaintingStyle.fill),
    );
  });

  test('paintSectionSurface can skip the shadow and fill a subtracted path', () {
    final path = Path()..addRect(const Rect.fromLTWH(0, 0, 100, 100));
    final fillPath = Path()..addRect(const Rect.fromLTWH(0, 0, 50, 100));
    void noShadow(Canvas canvas) =>
        paintSectionSurface(canvas, path, shadow: null);
    expect(noShadow, paintsExactlyCountTimes(#drawPath, 1));
    void subtracted(Canvas canvas) =>
        paintSectionSurface(canvas, path, fillPath: fillPath);
    expect(
      subtracted,
      paints
        ..path()
        ..path()
        ..path()
        ..path(color: _shadowLayerColor(defaultLiftedSectionShadow, 1))
        ..path(
          color: sectionSurfaceColor,
          includes: const [Offset(25, 50)],
          excludes: const [Offset(75, 50)],
        ),
    );
  });

  testWidgets('DiagonalSection has no blur, no border and one surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const DiagonalSection(child: Text('section'))),
    );
    final host = find.byType(DiagonalSection);
    _expectSectionSurfacePainter(tester, host);
    expect(find.text('section'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('template surfaces share the section surface when unselected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SectionTemplateSurface(
          shape: SectionShape.rightCut,
          child: SizedBox.expand(),
        ),
      ),
    );
    _expectSectionSurfacePainter(tester, find.byType(SectionTemplateSurface));

    await tester.pumpWidget(
      _host(
        const AttachedSectionTemplateSurface(
          spec: AttachedSectionSpec(
            mode: SectionShapeMode.trapezoid,
            face: SectionAttachmentFace.left,
          ),
          showFaceGrid: false,
          child: SizedBox.expand(),
        ),
      ),
    );
    _expectSectionSurfacePainter(
      tester,
      find.byType(AttachedSectionTemplateSurface),
    );
    expect(tester.takeException(), isNull);
  });
}
