import 'dart:math' as math;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/pages/section_template_studio_page.dart';
import 'package:ba_planner_v7/ui/studio/section_template.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user elements validate against the shared 48x48 board', () {
    const elements = [
      SectionCanvasElement(
        id: 'left',
        label: '왼쪽',
        rect: SectionGridRect(0, 0, 24, 48),
        spec: defaultAttachedSectionSpec,
      ),
      SectionCanvasElement(
        id: 'right',
        label: '오른쪽',
        rect: SectionGridRect(24, 0, 24, 48),
        spec: defaultAttachedSectionSpec,
      ),
    ];

    expect(sectionTemplateGridSize, 48);
    expect(validateSectionCanvas(elements), isEmpty);
    expect(
      validateSectionCanvas([
        ...elements,
        elements.last.copyWith(rect: const SectionGridRect(12, 12, 12, 12)),
      ]),
      isNotEmpty,
    );
  });

  test('left and right template cuts remove opposite corners', () {
    const size = Size(300, 180);
    final rightCut = buildSectionTemplatePath(size, SectionShape.rightCut);
    final leftCut = buildSectionTemplatePath(size, SectionShape.leftCut);

    expect(rightCut.contains(const Offset(280, 160)), isFalse);
    expect(rightCut.contains(const Offset(20, 20)), isTrue);
    expect(leftCut.contains(const Offset(20, 20)), isFalse);
    expect(leftCut.contains(const Offset(280, 20)), isTrue);
  });

  test('every diagonal uses the fixed upward-right 80 degree track', () {
    const height = 240.0;
    final cut = sectionTemplateCutDepth(height);
    final angle = math.atan2(height, cut) * 180 / math.pi;

    expect(angle, closeTo(80, 1e-9));
    final names = SectionShape.values.map((shape) => shape.name);
    expect(names, isNot(contains('topCut')));
    expect(names, isNot(contains('bottomCut')));
  });

  test('attached modes derive geometry from face grid and height', () {
    const size = Size(600, 600);
    const triangle = AttachedSectionSpec(
      mode: SectionShapeMode.triangle,
      face: SectionAttachmentFace.left,
      faceStart: 8,
      faceSpan: 24,
    );
    const trapezoid = AttachedSectionSpec(
      mode: SectionShapeMode.trapezoid,
      face: SectionAttachmentFace.top,
      faceStart: 8,
      faceSpan: 32,
      height: 16,
    );
    const parallelogram = AttachedSectionSpec(
      mode: SectionShapeMode.parallelogram,
      face: SectionAttachmentFace.bottom,
      faceStart: 8,
      faceSpan: 32,
      height: 16,
    );

    expect(
      buildAttachedSectionPath(size, triangle).contains(const Offset(5, 200)),
      isTrue,
    );
    expect(
      buildAttachedSectionPath(
        size,
        trapezoid,
      ).contains(const Offset(300, 100)),
      isTrue,
    );
    expect(
      buildAttachedSectionPath(
        size,
        parallelogram,
      ).contains(const Offset(300, 500)),
      isTrue,
    );
  });

  test('every selected attachment face is the actual outer boundary', () {
    const size = Size(600, 600);
    for (final mode in SectionShapeMode.values) {
      for (final face in SectionAttachmentFace.values) {
        final path = buildAttachedSectionPath(
          size,
          AttachedSectionSpec(
            mode: mode,
            face: face,
            faceStart: 16,
            faceSpan: 16,
            height: 4,
          ),
        );
        final bounds = path.getBounds();
        switch (face) {
          case SectionAttachmentFace.left:
            expect(bounds.left, closeTo(0, 0.01), reason: '${mode.name}/left');
          case SectionAttachmentFace.right:
            expect(
              bounds.right,
              closeTo(size.width, 0.01),
              reason: '${mode.name}/right',
            );
          case SectionAttachmentFace.top:
            expect(bounds.top, closeTo(0, 0.01), reason: '${mode.name}/top');
          case SectionAttachmentFace.bottom:
            expect(
              bounds.bottom,
              closeTo(size.height, 0.01),
              reason: '${mode.name}/bottom',
            );
        }
      }
    }
  });

  test('elements share one canvas and are not clipped to footprint rects', () {
    const canvasSize = Size(480, 480);
    const element = SectionCanvasElement(
      id: 'shared',
      label: '공용',
      rect: SectionGridRect(16, 16, 16, 16),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.left,
        faceStart: 24,
        faceSpan: 24,
        height: 12,
      ),
    );
    final footprint = sectionCanvasElementRect(canvasSize, element);
    final path = buildSectionCanvasElementPath(canvasSize, element);

    expect(footprint.contains(const Offset(190, 100)), isFalse);
    expect(path.contains(const Offset(190, 100)), isTrue);
    expect(
      hitTestSectionCanvasElement(canvasSize, const [
        element,
      ], const Offset(190, 100)),
      element.id,
    );
  });

  test('move and resize operations snap and clamp to the 48x48 grid', () {
    const rect = SectionGridRect(10, 10, 12, 14);

    final moved = moveSectionGridRect(rect, deltaX: 100, deltaY: -100);
    expect(moved.x, 36);
    expect(moved.y, 0);
    expect(moved.width, 12);
    expect(moved.height, 14);

    final expanded = resizeSectionGridRect(
      rect,
      handle: SectionResizeHandle.topLeft,
      deltaX: -100,
      deltaY: -100,
    );
    expect(expanded.x, 0);
    expect(expanded.y, 0);
    expect(expanded.right, rect.right);
    expect(expanded.bottom, rect.bottom);

    final minimum = resizeSectionGridRect(
      rect,
      handle: SectionResizeHandle.bottomRight,
      deltaX: -100,
      deltaY: -100,
    );
    expect(minimum.width, 1);
    expect(minimum.height, 1);

    const element = SectionCanvasElement(
      id: 'handles',
      label: '핸들',
      rect: rect,
      spec: defaultAttachedSectionSpec,
    );
    const size = Size(480, 480);
    final centers = sectionCanvasResizeHandleCenters(size, element);
    expect(
      hitTestSectionResizeHandle(
        size,
        element,
        centers[SectionResizeHandle.bottomRight]!,
      ),
      SectionResizeHandle.bottomRight,
    );
  });

  test('nested layers use 96-grid parents and image resize keeps ratio', () {
    const section = SectionCanvasElement(
      id: 'section',
      label: 'section',
      rect: SectionGridRect(0, 0, 24, 48),
      spec: defaultAttachedSectionSpec,
    );
    const container = StudioContainerElement(
      id: 'container',
      label: 'container',
      parentSectionId: 'section',
      rect: SectionGridRect(0, 0, 96, 96),
      spec: defaultDetailedShapeSpec,
    );
    const feature = StudioFeatureElement(
      id: 'image',
      label: 'image',
      parentContainerId: 'container',
      rect: SectionGridRect(12, 12, 48, 33),
      kind: StudioFeatureKind.image,
      spec: defaultDetailedShapeSpec,
      imageAsset: studioSquareAssetPath,
      aspectRatio: studioSquareAspectRatio,
    );
    const canvas = Size(960, 480);
    final sectionBounds = sectionCanvasElementRect(canvas, section);
    final containerPath = buildStudioContainerPath(canvas, const [
      section,
    ], container)!;
    final featurePath = buildStudioFeaturePath(
      canvas,
      const [section],
      const [container],
      feature,
    )!;
    expect(
      containerPath.getBounds().right,
      lessThanOrEqualTo(sectionBounds.right),
    );
    expect(
      featurePath.getBounds().right,
      lessThanOrEqualTo(sectionBounds.right),
    );

    final resized = resizeAspectLockedGridRect(
      feature.rect,
      handle: SectionResizeHandle.bottomRight,
      deltaX: 20,
      deltaY: 20,
      aspectRatio: studioSquareAspectRatio,
    );
    expect(
      resized.width / resized.height,
      closeTo(studioSquareAspectRatio, 0.03),
    );
    expect(resized.right, lessThanOrEqualTo(96));
    expect(resized.bottom, lessThanOrEqualTo(96));
  });

  testWidgets('container and feature layers add nested shapes and images', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: const Scaffold(body: SectionTemplateStudioPage()),
      ),
    );

    await tester.tap(find.text('컨테이너').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-add-container')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feature').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-add-shape-feature')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-add-image-feature')));
    await tester.pumpAndSettle();

    final paint = find.descendant(
      of: find.byKey(const ValueKey('studio-shared-canvas')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.foregroundPainter is LayeredStudioPainter,
      ),
    );
    final painter =
        tester.widget<CustomPaint>(paint).foregroundPainter!
            as LayeredStudioPainter;
    expect(painter.activeLayer, StudioLayer.feature);
    expect(painter.containers.single.parentSectionId, 'element-1');
    expect(painter.features, hasLength(2));
    expect(painter.features.last.kind, StudioFeatureKind.image);
    expect(painter.features.last.aspectRatio, studioSquareAspectRatio);

    final canvasFinder = find.byKey(const ValueKey('studio-shared-canvas'));
    final canvasRect = tester.getRect(canvasFinder);
    final imageRect = studioFeatureRect(
      canvasRect.size,
      painter.sections,
      painter.containers,
      painter.features.last,
    )!.shift(canvasRect.topLeft);
    final resize = await tester.startGesture(
      imageRect.bottomRight - const Offset(2, 2),
    );
    await resize.moveBy(const Offset(24, 18));
    await resize.up();
    await tester.pumpAndSettle();
    final updatedPaint = find.descendant(
      of: canvasFinder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.foregroundPainter is LayeredStudioPainter,
      ),
    );
    final updated =
        tester.widget<CustomPaint>(updatedPaint).foregroundPainter!
            as LayeredStudioPainter;
    final image = updated.features.last;
    expect(
      image.rect.width / image.rect.height,
      closeTo(studioSquareAspectRatio, 0.04),
    );
    expect(image.rect.right, lessThanOrEqualTo(sectionTemplateDetailGridSize));
    expect(image.rect.bottom, lessThanOrEqualTo(sectionTemplateDetailGridSize));
  });

  test('rendered section polygons round every original corner', () {
    final path = buildRoundedSectionPolygon(const [
      Offset(0, 0),
      Offset(120, 0),
      Offset(100, 100),
      Offset(0, 100),
    ]);

    expect(path.contains(const Offset(1, 1)), isFalse);
    expect(path.contains(const Offset(4, 10)), isTrue);
    expect(path.contains(const Offset(10, 4)), isTrue);
    expect(path.contains(const Offset(12, 12)), isTrue);
    expect(path.contains(const Offset(60, 50)), isTrue);

    final acuteTriangle = buildRoundedSectionPolygon(const [
      Offset(0, 100),
      Offset(17.63, 0),
      Offset(17.63, 100),
    ]);
    expect(acuteTriangle.contains(const Offset(17, 2)), isFalse);
    expect(acuteTriangle.contains(const Offset(14.5, 25)), isFalse);
    expect(acuteTriangle.contains(const Offset(14.5, 34)), isTrue);
    expect(acuteTriangle.contains(const Offset(14.5, 45)), isTrue);
    expect(acuteTriangle.contains(const Offset(10, 80)), isTrue);
  });

  testWidgets('studio adds and edits elements on one shared 48x48 canvas', (
    tester,
  ) async {
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: const Scaffold(body: SectionTemplateStudioPage()),
      ),
    );

    expect(find.byKey(const ValueKey('studio-mode')), findsNothing);
    expect(find.byKey(const ValueKey('studio-composition')), findsNothing);
    expect(find.byKey(const ValueKey('studio-shared-canvas')), findsOneWidget);
    expect(find.textContaining('공용 48×48 그리드'), findsOneWidget);
    final initialCanvas = tester.getSize(
      find.byKey(const ValueKey('studio-preview-canvas')),
    );
    final initialCanvasRect = tester.getRect(
      find.byKey(const ValueKey('studio-preview-canvas')),
    );
    final initialHeaderRect = tester.getRect(
      find.byKey(const ValueKey('studio-preview-header')),
    );
    final initialContentRect = tester.getRect(
      find.byKey(const ValueKey('studio-preview-content')),
    );
    expect(
      initialHeaderRect.height,
      closeTo(initialCanvas.height * 8 / sectionTemplateGridSize, 0.01),
    );
    expect(initialHeaderRect.top, initialCanvasRect.top);
    expect(initialContentRect.top, closeTo(initialHeaderRect.bottom, 0.01));

    await tester.tap(find.byKey(const ValueKey('studio-header-rows')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('16/48 · 33.3%').last);
    await tester.pumpAndSettle();
    final resizedHeader = tester.getRect(
      find.byKey(const ValueKey('studio-preview-header')),
    );
    expect(
      resizedHeader.height,
      closeTo(initialCanvas.height * 16 / sectionTemplateGridSize, 0.01),
    );

    await tester.tap(find.byKey(const ValueKey('studio-add-element')));
    await tester.pumpAndSettle();
    expect(find.textContaining('섹션 2 · 24×24'), findsOneWidget);
    final sharedCanvas = find.byKey(const ValueKey('studio-shared-canvas'));
    final canvasPaint = find.descendant(
      of: sharedCanvas,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.foregroundPainter is LayeredStudioPainter,
      ),
    );
    final painter =
        tester.widget<CustomPaint>(canvasPaint).foregroundPainter!
            as LayeredStudioPainter;
    expect(painter.sections, hasLength(2));

    await tester.ensureVisible(
      find.byKey(const ValueKey('studio-shape-mode-element-2')),
    );
    await tester.tap(find.byKey(const ValueKey('studio-shape-mode-element-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삼각형').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('studio-shape-height-element-2')),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('studio-copy-summary')),
    );
    await tester.tap(find.byKey(const ValueKey('studio-copy-summary')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(copiedText, contains('- 공용 그리드: 48×48'));
    expect(copiedText, contains('- 섹션 수: 2'));
    expect(copiedText, contains('- 고정 헤더: 16/48 (33.3%)'));
    expect(copiedText, contains('[섹션 2] 섹션 2'));
    expect(copiedText, contains('- 도형: 삼각형'));
    expect(copiedText, contains('- 높이: 자동 계산'));
    expect(copiedText, contains('우측 위 방향 /, 80° 고정'));

    await tester.tap(find.byKey(const ValueKey('studio-viewport-compact')));
    await tester.pumpAndSettle();
    final canvas = tester.getSize(
      find.byKey(const ValueKey('studio-preview-canvas')),
    );
    expect(canvas.width / canvas.height, closeTo(1, 0.01));
  });

  testWidgets('canvas drag moves and resizes the selected element on grid', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: const Scaffold(body: SectionTemplateStudioPage()),
      ),
    );

    final sharedCanvas = find.byKey(const ValueKey('studio-shared-canvas'));
    final canvasRect = tester.getRect(sharedCanvas);
    final unitX = canvasRect.width / sectionTemplateGridSize;
    final unitY = canvasRect.height / sectionTemplateGridSize;

    LayeredStudioPainter currentPainter() {
      final paint = find.descendant(
        of: sharedCanvas,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.foregroundPainter is LayeredStudioPainter,
        ),
      );
      return tester.widget<CustomPaint>(paint).foregroundPainter!
          as LayeredStudioPainter;
    }

    final moveStart = canvasRect.topLeft + Offset(unitX * 3, unitY * 24);
    final moveGesture = await tester.startGesture(moveStart);
    await moveGesture.moveBy(Offset(unitX * 2, 0));
    await tester.pump();
    await moveGesture.moveBy(Offset(unitX * 6, 0));
    await moveGesture.up();
    await tester.pumpAndSettle();
    final moved = currentPainter().sections.single.rect;
    expect(moved.x, greaterThan(0));
    expect(moved.y, 0);
    expect(moved.width, 24);
    expect(moved.height, 48);
    expect(moved.right, lessThanOrEqualTo(sectionTemplateGridSize));

    final topRightHandle =
        canvasRect.topLeft +
        Offset(moved.right * unitX - 2, moved.y * unitY + 2);
    final resizeGesture = await tester.startGesture(topRightHandle);
    await resizeGesture.moveBy(Offset(unitX * 2, unitY * 2));
    await tester.pump();
    await resizeGesture.moveBy(Offset(unitX * 6, unitY * 6));
    await resizeGesture.up();
    await tester.pumpAndSettle();
    final resized = currentPainter().sections.single.rect;
    expect(resized.x, moved.x);
    expect(resized.y, greaterThan(moved.y));
    expect(resized.right, greaterThan(moved.right));
    expect(resized.bottom, moved.bottom);
    expect(resized.right, lessThanOrEqualTo(sectionTemplateGridSize));
  });

  testWidgets('development panel opens the section template studio', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.tap(find.byIcon(Icons.developer_board_outlined));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('open-section-template-studio')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('section-template-studio-page')),
      findsOneWidget,
    );
    expect(find.text('Section Template Studio'), findsWidgets);
  });
}
