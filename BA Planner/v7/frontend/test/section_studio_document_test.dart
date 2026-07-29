import 'dart:convert';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/pages/section_template_studio_page.dart';
import 'package:ba_planner_v7/ui/studio/section_studio_document.dart';
import 'package:ba_planner_v7/ui/studio/section_studio_file_service.dart';
import 'package:ba_planner_v7/ui/studio/section_template.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const elements = <SectionCanvasElement>[
    SectionCanvasElement(
      id: 'element-1',
      label: '왼쪽 요소',
      rect: SectionGridRect(2, 3, 18, 24),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.parallelogram,
        face: SectionAttachmentFace.bottom,
        faceStart: 7,
        faceSpan: 31,
        height: 16,
      ),
    ),
    SectionCanvasElement(
      id: 'custom-right',
      label: '오른쪽 요소',
      rect: SectionGridRect(24, 8, 24, 40),
      spec: AttachedSectionSpec(
        mode: SectionShapeMode.triangle,
        face: SectionAttachmentFace.right,
        faceStart: 4,
        faceSpan: 40,
        height: 9,
      ),
    ),
  ];

  test('versioned Studio JSON round-trips every editable value', () {
    final encoded = encodeSectionStudioDocument(
      SectionStudioDocument(
        headerRows: 0,
        viewport: 'wide',
        showGrid: false,
        showSafeArea: true,
        selectedElementId: 'custom-right',
        elements: elements,
      ),
    );
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    expect(json['format'], sectionStudioDocumentFormat);
    expect(json['version'], sectionStudioDocumentVersion);
    expect(json['gridSize'], 96);
    expect(json['diagonal'], {'direction': 'up-right', 'angleDegrees': 80});

    final decoded = decodeSectionStudioDocument(encoded);
    expect(decoded.headerRows, 0);
    expect(decoded.viewport, 'wide');
    expect(decoded.showGrid, isFalse);
    expect(decoded.showSafeArea, isTrue);
    expect(decoded.selectedElementId, 'custom-right');
    expect(decoded.elements, hasLength(2));
    expect(decoded.elements.first.label, '왼쪽 요소');
    expect(decoded.elements.first.rect.x, 2);
    expect(decoded.elements.first.rect.height, 24);
    expect(decoded.elements.first.spec.mode, SectionShapeMode.parallelogram);
    expect(decoded.elements.first.spec.face, SectionAttachmentFace.bottom);
    expect(decoded.elements.first.spec.faceStart, 7);
    expect(decoded.elements.first.spec.faceSpan, 31);
    expect(decoded.elements.first.spec.height, 16);
  });

  test(
    'current version preserves container and feature parent relationships',
    () {
      const container = StudioContainerElement(
        id: 'container-1',
        label: '컨테이너 1',
        parentSectionId: 'element-1',
        rect: StudioPlacementRect(0.08, 0.08, 0.8, 0.8),
        spec: defaultDetailedShapeSpec,
        triangleTexture: true,
      );
      const feature = StudioFeatureElement(
        id: 'feature-1',
        label: '이미지 1',
        parentContainerId: 'container-1',
        rect: StudioPlacementRect(0.16, 0.24, 0.48, 0.33),
        kind: StudioFeatureKind.image,
        spec: defaultDetailedShapeSpec,
        imageAsset: studioTitleAssetPath,
        aspectRatio: studioTitleAspectRatio,
      );
      final encoded = encodeSectionStudioDocument(
        SectionStudioDocument(
          headerRows: 8,
          viewport: 'standard',
          showGrid: true,
          showSafeArea: true,
          selectedElementId: 'element-1',
          elements: [elements[0]],
          activeLayer: StudioLayer.feature,
          selectedContainerId: container.id,
          selectedFeatureId: feature.id,
          containers: const [container],
          features: const [feature],
        ),
      );
      final decoded = decodeSectionStudioDocument(encoded);
      expect(decoded.activeLayer, StudioLayer.feature);
      expect(decoded.placementGap, studioDefaultPlacementGap);
      expect(decoded.containers.single.parentSectionId, 'element-1');
      expect(decoded.containers.single.rect.left, 0.08);
      expect(decoded.containers.single.rect.width, 0.8);
      expect(decoded.containers.single.triangleTexture, isTrue);
      expect(decoded.features.single.parentContainerId, 'container-1');
      expect(decoded.features.single.rect.top, 0.24);
      expect(decoded.features.single.kind, StudioFeatureKind.image);
      expect(decoded.features.single.imageAsset, studioTitleAssetPath);
      expect(decoded.features.single.aspectRatio, studioTitleAspectRatio);
    },
  );

  test('version 5 stores text and line features', () {
    const container = StudioContainerElement(
      id: 'container-1',
      label: '컨테이너 1',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(0.08, 0.08, 0.8, 0.8),
      spec: defaultDetailedShapeSpec,
    );
    const textFeature = StudioFeatureElement(
      id: 'feature-text',
      label: '타이틀 텍스트',
      parentContainerId: 'container-1',
      rect: StudioPlacementRect(0.1, 0.1, 0.5, 0.2),
      kind: StudioFeatureKind.text,
      spec: defaultDetailedShapeSpec,
      text: 'PLAN A',
    );
    const lineFeature = StudioFeatureElement(
      id: 'feature-line',
      label: '구분선',
      parentContainerId: 'container-1',
      rect: StudioPlacementRect(0.1, 0.4, 0.6, 0.08),
      kind: StudioFeatureKind.line,
      spec: defaultDetailedShapeSpec,
    );
    final decoded = decodeSectionStudioDocument(
      encodeSectionStudioDocument(
        SectionStudioDocument(
          headerRows: 0,
          viewport: 'standard',
          showGrid: true,
          showSafeArea: true,
          selectedElementId: 'element-1',
          elements: [elements[0]],
          selectedContainerId: container.id,
          containers: const [container],
          features: const [textFeature, lineFeature],
        ),
      ),
    );
    expect(decoded.headerRows, 0);
    expect(decoded.features.map((item) => item.kind), [
      StudioFeatureKind.text,
      StudioFeatureKind.line,
    ]);
    expect(decoded.features.first.text, 'PLAN A');
  });

  test('version 1 section-only files remain importable', () {
    final legacy =
        jsonDecode(
              encodeSectionStudioDocument(
                SectionStudioDocument(
                  headerRows: 8,
                  viewport: 'standard',
                  showGrid: true,
                  showSafeArea: true,
                  selectedElementId: 'element-1',
                  elements: [elements[0]],
                ),
              ),
            )
            as Map<String, dynamic>;
    legacy['version'] = 1;
    legacy.remove('detailGridSize');
    legacy.remove('containers');
    legacy.remove('features');
    final workspace = legacy['workspace'] as Map<String, dynamic>;
    workspace
      ..remove('activeLayer')
      ..remove('selectedContainerId')
      ..remove('selectedFeatureId');

    final decoded = decodeSectionStudioDocument(jsonEncode(legacy));
    expect(decoded.elements, hasLength(1));
    expect(decoded.containers, isEmpty);
    expect(decoded.features, isEmpty);
    expect(decoded.activeLayer, StudioLayer.section);
  });

  test('version 3 child grid rects migrate to parent-relative placement', () {
    final legacy =
        jsonDecode(
              encodeSectionStudioDocument(
                SectionStudioDocument(
                  headerRows: 8,
                  viewport: 'standard',
                  showGrid: true,
                  showSafeArea: true,
                  selectedElementId: 'element-1',
                  elements: [elements[0]],
                  selectedContainerId: 'container-1',
                  containers: const [
                    StudioContainerElement(
                      id: 'container-1',
                      label: 'legacy container',
                      parentSectionId: 'element-1',
                      rect: StudioPlacementRect(0.08, 0.08, 0.8, 0.8),
                      spec: defaultDetailedShapeSpec,
                    ),
                  ],
                ),
              ),
            )
            as Map<String, dynamic>;
    legacy['version'] = 3;
    final workspace = legacy['workspace'] as Map<String, dynamic>;
    workspace
      ..remove('placementMode')
      ..remove('placementGap');
    final container =
        (legacy['containers'] as List).single as Map<String, dynamic>;
    container['rect'] = {'x': 8, 'y': 12, 'width': 48, 'height': 36};

    final decoded = decodeSectionStudioDocument(jsonEncode(legacy));
    expect(decoded.containers.single.rect.left, closeTo(8 / 96, 1e-9));
    expect(decoded.containers.single.rect.top, closeTo(12 / 96, 1e-9));
    expect(decoded.containers.single.rect.width, closeTo(0.5, 1e-9));
    expect(decoded.containers.single.rect.height, closeTo(0.375, 1e-9));
    expect(decoded.placementGap, studioDefaultPlacementGap);
  });

  test('version 4 files default new decoration fields safely', () {
    const container = StudioContainerElement(
      id: 'container-1',
      label: 'legacy container',
      parentSectionId: 'element-1',
      rect: StudioPlacementRect(0.08, 0.08, 0.8, 0.8),
      spec: defaultDetailedShapeSpec,
    );
    final legacy =
        jsonDecode(
              encodeSectionStudioDocument(
                SectionStudioDocument(
                  headerRows: 8,
                  viewport: 'standard',
                  showGrid: true,
                  showSafeArea: true,
                  selectedElementId: 'element-1',
                  elements: [elements[0]],
                  selectedContainerId: container.id,
                  containers: const [container],
                ),
              ),
            )
            as Map<String, dynamic>;
    legacy['version'] = 4;
    final rawContainer =
        (legacy['containers'] as List).single as Map<String, dynamic>;
    rawContainer.remove('triangleTexture');

    final decoded = decodeSectionStudioDocument(jsonEncode(legacy));
    expect(decoded.headerRows, 8);
    expect(decoded.containers.single.triangleTexture, isFalse);
  });

  test('Studio JSON rejects incompatible or unsafe documents', () {
    Map<String, dynamic> validJson() =>
        jsonDecode(
              encodeSectionStudioDocument(
                SectionStudioDocument(
                  headerRows: 8,
                  viewport: 'standard',
                  showGrid: true,
                  showSafeArea: true,
                  selectedElementId: 'element-1',
                  elements: [elements[0]],
                ),
              ),
            )
            as Map<String, dynamic>;

    final wrongVersion = validJson()..['version'] = 99;
    expect(
      () => decodeSectionStudioDocument(jsonEncode(wrongVersion)),
      throwsFormatException,
    );

    final wrongGrid = validJson()..['gridSize'] = 24;
    expect(
      () => decodeSectionStudioDocument(jsonEncode(wrongGrid)),
      throwsFormatException,
    );

    final duplicateId = validJson();
    (duplicateId['elements'] as List).add(
      Map<String, dynamic>.from(
        (duplicateId['elements'] as List).first as Map<String, dynamic>,
      ),
    );
    expect(
      () => decodeSectionStudioDocument(jsonEncode(duplicateId)),
      throwsFormatException,
    );

    final outsideGrid = validJson();
    final element = (outsideGrid['elements'] as List).first;
    (element['rect'] as Map<String, dynamic>)['width'] = 95;
    expect(
      () => decodeSectionStudioDocument(jsonEncode(outsideGrid)),
      throwsFormatException,
    );
  });

  testWidgets('Studio saves and atomically loads through the file service', (
    tester,
  ) async {
    final service = _FakeSectionStudioFileService();
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(body: SectionTemplateStudioPage(fileService: service)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('studio-add-element')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('studio-save-file')));
    await tester.pumpAndSettle();
    expect(service.savedSuggestedName, endsWith('.ba-section-studio.json'));
    final saved = decodeSectionStudioDocument(service.savedContents!);
    expect(saved.elements, hasLength(2));
    expect(saved.selectedElementId, 'element-2');

    service.fileToOpen = LoadedSectionStudioFile(
      name: 'custom.ba-section-studio.json',
      contents: encodeSectionStudioDocument(
        SectionStudioDocument(
          headerRows: 12,
          viewport: 'compact',
          showGrid: false,
          showSafeArea: false,
          selectedElementId: 'custom-right',
          elements: [elements[1]],
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('studio-load-file')));
    await tester.pumpAndSettle();

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
    expect(painter.sections, hasLength(1));
    expect(painter.sections.single.id, 'custom-right');
    expect(painter.showGrid, isFalse);
    expect(painter.showSafeArea, isFalse);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('studio-preview-canvas')))
          .aspectRatio,
      closeTo(1, 0.01),
    );
    expect(find.text('custom.ba-section-studio.json을 불러왔습니다.'), findsOne);
  });

  testWidgets('invalid load keeps the current canvas unchanged', (
    tester,
  ) async {
    final service = _FakeSectionStudioFileService(
      fileToOpen: const LoadedSectionStudioFile(
        name: 'broken.json',
        contents: '{"format":"wrong"}',
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(body: SectionTemplateStudioPage(fileService: service)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('studio-load-file')));
    await tester.pumpAndSettle();
    expect(find.textContaining('불러오기 실패:'), findsOneWidget);

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
    expect(painter.sections.single.id, 'element-1');
  });

  testWidgets('section import appends and remaps IDs instead of replacing', (
    tester,
  ) async {
    final service = _FakeSectionStudioFileService(
      fileToOpen: LoadedSectionStudioFile(
        name: 'import.ba-section-studio.json',
        contents: encodeSectionStudioDocument(
          SectionStudioDocument(
            headerRows: 8,
            viewport: 'standard',
            showGrid: true,
            showSafeArea: true,
            selectedElementId: 'element-1',
            elements: [elements[0]],
            containers: const [
              StudioContainerElement(
                id: 'container-1',
                label: '가져온 컨테이너',
                parentSectionId: 'element-1',
                rect: StudioPlacementRect(0.08, 0.08, 0.8, 0.8),
                spec: defaultDetailedShapeSpec,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(body: SectionTemplateStudioPage(fileService: service)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('studio-import-sections')));
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
    expect(painter.sections, hasLength(2));
    expect(painter.sections.map((item) => item.id).toSet(), hasLength(2));
    expect(painter.containers.single.parentSectionId, painter.sections.last.id);
  });
}

class _FakeSectionStudioFileService implements SectionStudioFileService {
  _FakeSectionStudioFileService({this.fileToOpen});

  LoadedSectionStudioFile? fileToOpen;
  String? savedSuggestedName;
  String? savedContents;

  @override
  Future<LoadedSectionStudioFile?> open() async => fileToOpen;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
  }) async {
    savedSuggestedName = suggestedName;
    savedContents = contents;
    return 'C:/fake/$suggestedName';
  }
}
