import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../studio/section_studio_document.dart';
import '../studio/section_studio_file_service.dart';
import '../studio/section_template.dart';
import '../widgets/section_template_surface.dart';

enum _StudioViewport {
  standard('Standard', Size(1200, 720)),
  wide('Wide', Size(1600, 720)),
  compact('Compact', Size(900, 900));

  const _StudioViewport(this.label, this.size);
  final String label;
  final Size size;
}

class SectionTemplateStudioPage extends StatefulWidget {
  const SectionTemplateStudioPage({super.key, this.fileService});

  final SectionStudioFileService? fileService;

  @override
  State<SectionTemplateStudioPage> createState() =>
      _SectionTemplateStudioPageState();
}

class _SectionTemplateStudioPageState extends State<SectionTemplateStudioPage> {
  _StudioViewport _viewport = _StudioViewport.standard;
  final List<SectionCanvasElement> _elements = [
    const SectionCanvasElement(
      id: 'element-1',
      label: '섹션 1',
      rect: SectionGridRect(0, 0, 24, 48),
      spec: defaultAttachedSectionSpec,
    ),
  ];
  final List<StudioContainerElement> _containers = [];
  final List<StudioFeatureElement> _features = [];
  StudioLayer _activeLayer = StudioLayer.section;
  String _selectedElementId = 'element-1';
  String? _selectedContainerId;
  String? _selectedFeatureId;
  int _nextElementNumber = 2;
  int _nextContainerNumber = 1;
  int _nextFeatureNumber = 1;
  bool _showGrid = true;
  bool _showSafeArea = true;
  bool _fileOperationInProgress = false;
  int _headerRows = sectionTemplateSubdivisionsPerMajor;
  ui.Image? _squareImage;

  @override
  void initState() {
    super.initState();
    _loadSquareImage();
  }

  Future<void> _loadSquareImage() async {
    final data = await rootBundle.load(studioSquareAssetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _squareImage = frame.image);
  }

  @override
  void dispose() {
    _squareImage?.dispose();
    super.dispose();
  }

  SectionStudioFileService get _fileService =>
      widget.fileService ?? const NativeSectionStudioFileService();

  SectionCanvasElement get _selectedElement => _elements.firstWhere(
    (element) => element.id == _selectedElementId,
    orElse: () => _elements.first,
  );

  void _replaceSelected(SectionCanvasElement value) {
    setState(() {
      final index = _elements.indexWhere(
        (element) => element.id == _selectedElementId,
      );
      _elements[index] = value;
    });
  }

  void _changeElementRect(String id, SectionGridRect rect) {
    setState(() {
      final index = _elements.indexWhere((element) => element.id == id);
      if (index < 0) return;
      _elements[index] = _elements[index].copyWith(rect: rect);
    });
  }

  void _addElement() {
    var number = _nextElementNumber;
    while (_elements.any((element) => element.id == 'element-$number')) {
      number++;
    }
    _nextElementNumber = number + 1;
    final id = 'element-$number';
    final rect = _findAvailableRect();
    setState(() {
      _elements.add(
        SectionCanvasElement(
          id: id,
          label: '섹션 $number',
          rect: rect,
          spec: defaultAttachedSectionSpec.copyWith(
            face: rect.right == sectionTemplateGridSize
                ? SectionAttachmentFace.right
                : SectionAttachmentFace.left,
          ),
        ),
      );
      _selectedElementId = id;
    });
  }

  SectionGridRect _findAvailableRect() {
    for (final size in const [24, 16, 12, 8]) {
      for (var y = 0; y <= sectionTemplateGridSize - size; y += size) {
        for (var x = 0; x <= sectionTemplateGridSize - size; x += size) {
          final candidate = SectionGridRect(x, y, size, size);
          if (_elements.every((element) => !element.rect.overlaps(candidate))) {
            return candidate;
          }
        }
      }
    }
    final offset = ((_nextElementNumber - 2) * 4) % 32;
    return SectionGridRect(offset, offset, 16, 16);
  }

  void _removeSelected() {
    if (_elements.length == 1) return;
    setState(() {
      final index = _elements.indexWhere(
        (element) => element.id == _selectedElementId,
      );
      final removedId = _elements[index].id;
      final removedContainers = _containers
          .where((item) => item.parentSectionId == removedId)
          .map((item) => item.id)
          .toSet();
      _features.removeWhere(
        (item) => removedContainers.contains(item.parentContainerId),
      );
      _containers.removeWhere((item) => item.parentSectionId == removedId);
      _elements.removeAt(index);
      _selectedElementId = _elements[index.clamp(0, _elements.length - 1)].id;
      _syncChildSelection();
    });
  }

  void _selectSection(SectionCanvasElement section) {
    setState(() {
      _selectedElementId = section.id;
      _syncChildSelection();
    });
  }

  void _syncChildSelection() {
    final children = _containers
        .where((item) => item.parentSectionId == _selectedElementId)
        .toList();
    if (!children.any((item) => item.id == _selectedContainerId)) {
      _selectedContainerId = children.isEmpty ? null : children.first.id;
    }
    final featureChildren = _features
        .where((item) => item.parentContainerId == _selectedContainerId)
        .toList();
    if (!featureChildren.any((item) => item.id == _selectedFeatureId)) {
      _selectedFeatureId = featureChildren.isEmpty
          ? null
          : featureChildren.first.id;
    }
  }

  void _addContainer() {
    final number = _nextContainerNumber++;
    final container = StudioContainerElement(
      id: 'container-$number',
      label: '컨테이너 $number',
      parentSectionId: _selectedElementId,
      rect: const SectionGridRect(8, 8, 80, 80),
      spec: defaultDetailedShapeSpec,
    );
    setState(() {
      _containers.add(container);
      _selectedContainerId = container.id;
      _selectedFeatureId = null;
      _activeLayer = StudioLayer.container;
    });
  }

  void _replaceContainer(StudioContainerElement value) {
    setState(() {
      final index = _containers.indexWhere((item) => item.id == value.id);
      if (index >= 0) _containers[index] = value;
    });
  }

  void _removeContainer() {
    final id = _selectedContainerId;
    if (id == null) return;
    setState(() {
      _features.removeWhere((item) => item.parentContainerId == id);
      _containers.removeWhere((item) => item.id == id);
      _selectedContainerId = null;
      _selectedFeatureId = null;
      _syncChildSelection();
    });
  }

  void _addFeature(StudioFeatureKind kind) {
    final parentId = _selectedContainerId;
    if (parentId == null) return;
    final number = _nextFeatureNumber++;
    final feature = StudioFeatureElement(
      id: 'feature-$number',
      label: kind == StudioFeatureKind.image
          ? '이미지 $number'
          : 'Feature $number',
      parentContainerId: parentId,
      rect: kind == StudioFeatureKind.image
          ? const SectionGridRect(16, 24, 48, 33)
          : const SectionGridRect(16, 16, 64, 64),
      kind: kind,
      spec: defaultDetailedShapeSpec,
      imageAsset: kind == StudioFeatureKind.image
          ? studioSquareAssetPath
          : null,
      aspectRatio: kind == StudioFeatureKind.image
          ? studioSquareAspectRatio
          : null,
    );
    setState(() {
      _features.add(feature);
      _selectedFeatureId = feature.id;
      _activeLayer = StudioLayer.feature;
    });
  }

  void _replaceFeature(StudioFeatureElement value) {
    setState(() {
      final index = _features.indexWhere((item) => item.id == value.id);
      if (index >= 0) _features[index] = value;
    });
  }

  void _removeFeature() {
    final id = _selectedFeatureId;
    if (id == null) return;
    setState(() {
      _features.removeWhere((item) => item.id == id);
      _selectedFeatureId = null;
      _syncChildSelection();
    });
  }

  SectionStudioDocument _createDocument() => SectionStudioDocument(
    headerRows: _headerRows,
    viewport: _viewport.name,
    showGrid: _showGrid,
    showSafeArea: _showSafeArea,
    selectedElementId: _selectedElementId,
    elements: _elements,
    activeLayer: _activeLayer,
    selectedContainerId: _selectedContainerId,
    selectedFeatureId: _selectedFeatureId,
    containers: _containers,
    features: _features,
  );

  Future<void> _saveDocument() async {
    if (_fileOperationInProgress) return;
    setState(() => _fileOperationInProgress = true);
    try {
      final path = await _fileService.save(
        suggestedName: defaultSectionStudioFileName(),
        contents: encodeSectionStudioDocument(_createDocument()),
      );
      if (path == null || !mounted) return;
      _showFileMessage('Studio 구성을 저장했습니다.');
    } catch (error) {
      if (!mounted) return;
      _showFileMessage('저장 실패: ${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _fileOperationInProgress = false);
    }
  }

  Future<void> _loadDocument() async {
    if (_fileOperationInProgress) return;
    setState(() => _fileOperationInProgress = true);
    try {
      final file = await _fileService.open();
      if (file == null) return;
      final document = decodeSectionStudioDocument(file.contents);
      if (!mounted) return;
      setState(() {
        _elements
          ..clear()
          ..addAll(document.elements);
        _containers
          ..clear()
          ..addAll(document.containers);
        _features
          ..clear()
          ..addAll(document.features);
        _selectedElementId = document.selectedElementId;
        _selectedContainerId = document.selectedContainerId;
        _selectedFeatureId = document.selectedFeatureId;
        _activeLayer = document.activeLayer;
        _headerRows = document.headerRows;
        _viewport = _StudioViewport.values.byName(document.viewport);
        _showGrid = document.showGrid;
        _showSafeArea = document.showSafeArea;
        _nextElementNumber = _nextAvailableElementNumber();
        _nextContainerNumber = _nextAvailableNumber(
          'container-',
          _containers.map((item) => item.id),
        );
        _nextFeatureNumber = _nextAvailableNumber(
          'feature-',
          _features.map((item) => item.id),
        );
      });
      _showFileMessage('${file.name}을 불러왔습니다.');
    } catch (error) {
      if (!mounted) return;
      _showFileMessage('불러오기 실패: ${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _fileOperationInProgress = false);
    }
  }

  int _nextAvailableElementNumber() {
    return _nextAvailableNumber('element-', _elements.map((item) => item.id));
  }

  int _nextAvailableNumber(String prefix, Iterable<String> ids) {
    final used = ids.toSet();
    var number = 1;
    while (used.contains('$prefix$number')) {
      number++;
    }
    return number;
  }

  Future<void> _importDocument() async {
    if (_fileOperationInProgress) return;
    setState(() => _fileOperationInProgress = true);
    try {
      final file = await _fileService.open();
      if (file == null) return;
      final document = decodeSectionStudioDocument(file.contents);
      final sectionIds = <String, String>{};
      final containerIds = <String, String>{};
      final importedSections = <SectionCanvasElement>[];
      final importedContainers = <StudioContainerElement>[];
      final importedFeatures = <StudioFeatureElement>[];
      for (final item in document.elements) {
        while (_elements.any((e) => e.id == 'element-$_nextElementNumber') ||
            importedSections.any(
              (e) => e.id == 'element-$_nextElementNumber',
            )) {
          _nextElementNumber++;
        }
        final id = 'element-${_nextElementNumber++}';
        sectionIds[item.id] = id;
        importedSections.add(
          SectionCanvasElement(
            id: id,
            label: item.label,
            rect: item.rect,
            spec: item.spec,
          ),
        );
      }
      for (final item in document.containers) {
        while (_containers.any(
              (e) => e.id == 'container-$_nextContainerNumber',
            ) ||
            importedContainers.any(
              (e) => e.id == 'container-$_nextContainerNumber',
            )) {
          _nextContainerNumber++;
        }
        final id = 'container-${_nextContainerNumber++}';
        containerIds[item.id] = id;
        importedContainers.add(
          StudioContainerElement(
            id: id,
            label: item.label,
            parentSectionId: sectionIds[item.parentSectionId]!,
            rect: item.rect,
            spec: item.spec,
          ),
        );
      }
      for (final item in document.features) {
        while (_features.any((e) => e.id == 'feature-$_nextFeatureNumber') ||
            importedFeatures.any(
              (e) => e.id == 'feature-$_nextFeatureNumber',
            )) {
          _nextFeatureNumber++;
        }
        importedFeatures.add(
          StudioFeatureElement(
            id: 'feature-${_nextFeatureNumber++}',
            label: item.label,
            parentContainerId: containerIds[item.parentContainerId]!,
            rect: item.rect,
            kind: item.kind,
            spec: item.spec,
            imageAsset: item.imageAsset,
            aspectRatio: item.aspectRatio,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _elements.addAll(importedSections);
        _containers.addAll(importedContainers);
        _features.addAll(importedFeatures);
        _selectedElementId = importedSections.first.id;
        _activeLayer = StudioLayer.section;
        _syncChildSelection();
      });
      _showFileMessage(
        '${file.name}에서 섹션 ${importedSections.length}개를 추가했습니다.',
      );
    } catch (error) {
      if (mounted) _showFileMessage('가져오기 실패: ${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _fileOperationInProgress = false);
    }
  }

  String _errorMessage(Object error) =>
      error is FormatException ? error.message : error.toString();

  void _showFileMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('section-template-studio-page'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final controls = _StudioControls(
            viewport: _viewport,
            elements: _elements,
            containers: _containers,
            features: _features,
            activeLayer: _activeLayer,
            selectedElement: _selectedElement,
            selectedContainerId: _selectedContainerId,
            selectedFeatureId: _selectedFeatureId,
            headerRows: _headerRows,
            showGrid: _showGrid,
            showSafeArea: _showSafeArea,
            onViewportChanged: (value) => setState(() => _viewport = value),
            onLayerChanged: (value) => setState(() => _activeLayer = value),
            onElementSelected: _selectSection,
            onElementChanged: _replaceSelected,
            onAddElement: _addElement,
            onRemoveElement: _removeSelected,
            onAddContainer: _addContainer,
            onContainerSelected: (value) => setState(() {
              _selectedContainerId = value.id;
              _syncChildSelection();
            }),
            onContainerChanged: _replaceContainer,
            onRemoveContainer: _removeContainer,
            onAddFeature: _addFeature,
            onFeatureSelected: (value) =>
                setState(() => _selectedFeatureId = value.id),
            onFeatureChanged: _replaceFeature,
            onRemoveFeature: _removeFeature,
            onLoad: _loadDocument,
            onSave: _saveDocument,
            onImport: _importDocument,
            fileOperationInProgress: _fileOperationInProgress,
            onHeaderRowsChanged: (value) => setState(() => _headerRows = value),
            onShowGridChanged: (value) => setState(() => _showGrid = value),
            onShowSafeAreaChanged: (value) =>
                setState(() => _showSafeArea = value),
          );
          final preview = _StudioPreview(
            viewport: _viewport,
            elements: _elements,
            containers: _containers,
            features: _features,
            activeLayer: _activeLayer,
            selectedElementId: _selectedElementId,
            selectedContainerId: _selectedContainerId,
            selectedFeatureId: _selectedFeatureId,
            squareImage: _squareImage,
            headerRows: _headerRows,
            showGrid: _showGrid,
            showSafeArea: _showSafeArea,
            onElementSelected: (id) {
              final section = _elements.firstWhere((item) => item.id == id);
              _selectSection(section);
            },
            onElementRectChanged: _changeElementRect,
            onContainerSelected: (id) => setState(() {
              _selectedContainerId = id;
              _syncChildSelection();
            }),
            onContainerRectChanged: (id, rect) {
              final item = _containers.firstWhere((item) => item.id == id);
              _replaceContainer(item.copyWith(rect: rect));
            },
            onFeatureSelected: (id) => setState(() => _selectedFeatureId = id),
            onFeatureRectChanged: (id, rect) {
              final item = _features.firstWhere((item) => item.id == id);
              _replaceFeature(item.copyWith(rect: rect));
            },
          );

          if (constraints.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 292, child: controls),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: preview),
              ],
            );
          }
          return ListView(
            children: [
              controls,
              const SizedBox(height: AppSpacing.md),
              SizedBox(height: 520, child: preview),
            ],
          );
        },
      ),
    );
  }
}

class _StudioControls extends StatelessWidget {
  const _StudioControls({
    required this.viewport,
    required this.elements,
    required this.containers,
    required this.features,
    required this.activeLayer,
    required this.selectedElement,
    required this.selectedContainerId,
    required this.selectedFeatureId,
    required this.headerRows,
    required this.showGrid,
    required this.showSafeArea,
    required this.onViewportChanged,
    required this.onLayerChanged,
    required this.onElementSelected,
    required this.onElementChanged,
    required this.onAddElement,
    required this.onRemoveElement,
    required this.onAddContainer,
    required this.onContainerSelected,
    required this.onContainerChanged,
    required this.onRemoveContainer,
    required this.onAddFeature,
    required this.onFeatureSelected,
    required this.onFeatureChanged,
    required this.onRemoveFeature,
    required this.onLoad,
    required this.onSave,
    required this.onImport,
    required this.fileOperationInProgress,
    required this.onHeaderRowsChanged,
    required this.onShowGridChanged,
    required this.onShowSafeAreaChanged,
  });

  final _StudioViewport viewport;
  final List<SectionCanvasElement> elements;
  final List<StudioContainerElement> containers;
  final List<StudioFeatureElement> features;
  final StudioLayer activeLayer;
  final SectionCanvasElement selectedElement;
  final String? selectedContainerId;
  final String? selectedFeatureId;
  final int headerRows;
  final bool showGrid;
  final bool showSafeArea;
  final ValueChanged<_StudioViewport> onViewportChanged;
  final ValueChanged<StudioLayer> onLayerChanged;
  final ValueChanged<SectionCanvasElement> onElementSelected;
  final ValueChanged<SectionCanvasElement> onElementChanged;
  final VoidCallback onAddElement;
  final VoidCallback onRemoveElement;
  final VoidCallback onAddContainer;
  final ValueChanged<StudioContainerElement> onContainerSelected;
  final ValueChanged<StudioContainerElement> onContainerChanged;
  final VoidCallback onRemoveContainer;
  final ValueChanged<StudioFeatureKind> onAddFeature;
  final ValueChanged<StudioFeatureElement> onFeatureSelected;
  final ValueChanged<StudioFeatureElement> onFeatureChanged;
  final VoidCallback onRemoveFeature;
  final Future<void> Function() onLoad;
  final Future<void> Function() onSave;
  final Future<void> Function() onImport;
  final bool fileOperationInProgress;
  final ValueChanged<int> onHeaderRowsChanged;
  final ValueChanged<bool> onShowGridChanged;
  final ValueChanged<bool> onShowSafeAreaChanged;

  AttachedSectionSpec get spec => selectedElement.spec;
  SectionGridRect get rect => selectedElement.rect;
  List<StudioContainerElement> get sectionContainers => containers
      .where((item) => item.parentSectionId == selectedElement.id)
      .toList(growable: false);
  StudioContainerElement? get selectedContainer {
    for (final item in sectionContainers) {
      if (item.id == selectedContainerId) return item;
    }
    return null;
  }

  List<StudioFeatureElement> get containerFeatures => features
      .where((item) => item.parentContainerId == selectedContainerId)
      .toList(growable: false);
  StudioFeatureElement? get selectedFeature {
    for (final item in containerFeatures) {
      if (item.id == selectedFeatureId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final issues = validateStudioLayers(elements, containers, features);
    return Material(
      color: AppColors.navigation.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        shrinkWrap: true,
        children: [
          const Text(
            'Section Template Studio',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '공용 48×48 그리드에 요소를 직접 추가하고 편집합니다.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<StudioLayer>(
            key: const ValueKey('studio-layer-selector'),
            segments: [
              for (final layer in StudioLayer.values)
                ButtonSegment(value: layer, label: Text(layer.label)),
            ],
            selected: {activeLayer},
            onSelectionChanged: (value) => onLayerChanged(value.single),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (activeLayer == StudioLayer.container)
            _ContainerLayerControls(
              containers: sectionContainers,
              selected: selectedContainer,
              onAdd: onAddContainer,
              onSelected: onContainerSelected,
              onChanged: onContainerChanged,
              onRemove: onRemoveContainer,
            )
          else if (activeLayer == StudioLayer.feature)
            _FeatureLayerControls(
              features: containerFeatures,
              selected: selectedFeature,
              hasParent: selectedContainer != null,
              onAdd: onAddFeature,
              onSelected: onFeatureSelected,
              onChanged: onFeatureChanged,
              onRemove: onRemoveFeature,
            ),
          if (activeLayer != StudioLayer.section)
            const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            key: const ValueKey('studio-header-rows'),
            initialValue: headerRows,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '고정 헤더 높이'),
            items: [
              for (var rows = 1; rows <= sectionTemplateGridSize ~/ 2; rows++)
                DropdownMenuItem(
                  value: rows,
                  child: Text(
                    '$rows/$sectionTemplateGridSize · ${(rows / sectionTemplateGridSize * 100).toStringAsFixed(1)}%',
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onHeaderRowsChanged(value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<SectionCanvasElement>(
            key: const ValueKey('studio-element-selector'),
            initialValue: selectedElement,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '편집할 섹션'),
            items: [
              for (final element in elements)
                DropdownMenuItem(
                  value: element,
                  child: Text(
                    '${element.label} · ${element.rect.width}×${element.rect.height}',
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onElementSelected(value);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const ValueKey('studio-add-element'),
                  onPressed: onAddElement,
                  icon: const Icon(Icons.add),
                  label: const Text('섹션 추가'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.outlined(
                key: const ValueKey('studio-remove-element'),
                onPressed: elements.length > 1 ? onRemoveElement : null,
                tooltip: '선택 요소 삭제',
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('studio-load-file'),
                  onPressed: fileOperationInProgress ? null : onLoad,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('불러오기'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('studio-save-file'),
                  onPressed: fileOperationInProgress ? null : onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('저장'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const ValueKey('studio-import-sections'),
            onPressed: fileOperationInProgress ? null : onImport,
            icon: const Icon(Icons.playlist_add_outlined),
            label: const Text('저장 파일에서 섹션 추가'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('점유 영역', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          _GridRectControls(
            element: selectedElement,
            onChanged: onElementChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<SectionShapeMode>(
            key: ValueKey('studio-shape-mode-${selectedElement.id}'),
            initialValue: spec.mode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '도형 모드'),
            items: [
              for (final item in SectionShapeMode.values)
                DropdownMenuItem(value: item, child: Text(item.label)),
            ],
            onChanged: (value) {
              if (value != null) {
                onElementChanged(
                  selectedElement.copyWith(spec: spec.copyWith(mode: value)),
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<SectionAttachmentFace>(
            key: ValueKey('studio-attachment-face-${selectedElement.id}'),
            initialValue: spec.face,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '붙는 면'),
            items: [
              for (final item in SectionAttachmentFace.values)
                DropdownMenuItem(value: item, child: Text(item.label)),
            ],
            onChanged: (value) {
              if (value != null) {
                onElementChanged(
                  selectedElement.copyWith(spec: spec.copyWith(face: value)),
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('studio-face-start-${selectedElement.id}'),
                  initialValue: spec.faceStart,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '면 시작'),
                  items: [
                    for (
                      var index = 0;
                      index < sectionTemplateGridSize;
                      index++
                    )
                      DropdownMenuItem(
                        value: index,
                        child: Text('${index + 1}/$sectionTemplateGridSize'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onElementChanged(
                        selectedElement.copyWith(
                          spec: spec.copyWith(faceStart: value),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey(
                    'studio-face-span-${selectedElement.id}-${spec.faceStart}',
                  ),
                  initialValue: spec.faceSpan,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '면 길이'),
                  items: [
                    for (
                      var span = 1;
                      span <= sectionTemplateGridSize - spec.faceStart;
                      span++
                    )
                      DropdownMenuItem(
                        value: span,
                        child: Text('$span/$sectionTemplateGridSize'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onElementChanged(
                        selectedElement.copyWith(
                          spec: spec.copyWith(faceSpan: value),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          if (spec.mode != SectionShapeMode.triangle) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              key: ValueKey('studio-shape-height-${selectedElement.id}'),
              initialValue: spec.height,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '높이'),
              items: [
                for (
                  var height = 1;
                  height <= sectionTemplateGridSize;
                  height++
                )
                  DropdownMenuItem(
                    value: height,
                    child: Text('$height/$sectionTemplateGridSize'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onElementChanged(
                    selectedElement.copyWith(
                      spec: spec.copyWith(height: value),
                    ),
                  );
                }
              },
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            key: const ValueKey('studio-copy-summary'),
            onPressed: () => _copySummary(context),
            icon: const Icon(Icons.content_copy),
            label: const Text('채팅용 요약 복사'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('프리뷰 비율', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in _StudioViewport.values)
                ChoiceChip(
                  key: ValueKey('studio-viewport-${item.name}'),
                  label: Text(item.label),
                  selected: item == viewport,
                  onSelected: (_) => onViewportChanged(item),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('48×48 사선 그리드'),
            value: showGrid,
            onChanged: onShowGridChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('콘텐츠 안전영역'),
            value: showSafeArea,
            onChanged: onShowSafeAreaChanged,
          ),
          const Divider(),
          Row(
            children: [
              Icon(
                issues.isEmpty
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
                size: 17,
                color: issues.isEmpty ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  issues.isEmpty
                      ? '${elements.length}개 섹션 · 계층 규칙 통과'
                      : '${issues.length}개 규칙 확인 필요',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '모든 요소는 하나의 콘텐츠 캔버스에서 함께 렌더링됩니다.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _copySummary(BuildContext context) async {
    final buffer = StringBuffer()
      ..writeln('[BA Planner Section Canvas]')
      ..writeln('- 공용 그리드: 48×48')
      ..writeln(
        '- 고정 헤더: $headerRows/$sectionTemplateGridSize (${(headerRows / sectionTemplateGridSize * 100).toStringAsFixed(1)}%)',
      )
      ..writeln('- 섹션 수: ${elements.length}')
      ..writeln('- 컨테이너 수: ${containers.length} (부모 로컬 96×96)')
      ..writeln('- Feature 수: ${features.length} (부모 로컬 96×96)')
      ..writeln('- 렌더링: 모든 요소가 동일한 콘텐츠 캔버스 좌표계를 공유');
    for (var index = 0; index < elements.length; index++) {
      final element = elements[index];
      final elementSpec = element.spec;
      buffer
        ..writeln()
        ..writeln('[섹션 ${index + 1}] ${element.label}')
        ..writeln(
          '- 점유: x ${element.rect.x}, y ${element.rect.y}, 폭 ${element.rect.width}, 높이 ${element.rect.height}',
        )
        ..writeln('- 도형: ${elementSpec.mode.label}')
        ..writeln('- 붙는 면: ${elementSpec.face.label}')
        ..writeln(
          '- 면 그리드: 시작 ${elementSpec.faceStart + 1}/$sectionTemplateGridSize, 길이 ${elementSpec.faceSpan}/$sectionTemplateGridSize, 끝 ${elementSpec.faceEnd}/$sectionTemplateGridSize',
        )
        ..writeln(
          elementSpec.mode == SectionShapeMode.triangle
              ? '- 높이: 자동 계산'
              : '- 높이: ${elementSpec.height}/$sectionTemplateGridSize',
        );
    }
    for (final container in containers) {
      buffer
        ..writeln()
        ..writeln('[컨테이너] ${container.label}')
        ..writeln('- 부모 섹션 ID: ${container.parentSectionId}')
        ..writeln(
          '- 점유(96): x ${container.rect.x}, y ${container.rect.y}, 폭 ${container.rect.width}, 높이 ${container.rect.height}',
        )
        ..writeln('- 도형: ${container.spec.mode.label}');
    }
    for (final feature in features) {
      buffer
        ..writeln()
        ..writeln('[Feature] ${feature.label}')
        ..writeln('- 부모 컨테이너 ID: ${feature.parentContainerId}')
        ..writeln('- 종류: ${feature.kind.label}')
        ..writeln(
          '- 점유(96): x ${feature.rect.x}, y ${feature.rect.y}, 폭 ${feature.rect.width}, 높이 ${feature.rect.height}',
        );
      if (feature.kind == StudioFeatureKind.image) {
        buffer.writeln('- 이미지 비율: ${feature.aspectRatio}');
      } else {
        buffer.writeln('- 도형: ${feature.spec.mode.label}');
      }
    }
    buffer.writeln('\n- 사선: 우측 위 방향 /, 80° 고정');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('채팅용 섹션 요약을 복사했습니다.')));
  }
}

class _ContainerLayerControls extends StatelessWidget {
  const _ContainerLayerControls({
    required this.containers,
    required this.selected,
    required this.onAdd,
    required this.onSelected,
    required this.onChanged,
    required this.onRemove,
  });

  final List<StudioContainerElement> containers;
  final StudioContainerElement? selected;
  final VoidCallback onAdd;
  final ValueChanged<StudioContainerElement> onSelected;
  final ValueChanged<StudioContainerElement> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              key: const ValueKey('studio-add-container'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('컨테이너 추가'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            key: const ValueKey('studio-remove-container'),
            onPressed: selected == null ? null : onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      if (selected != null) ...[
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<StudioContainerElement>(
          key: const ValueKey('studio-container-selector'),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '부모 섹션의 컨테이너'),
          items: [
            for (final item in containers)
              DropdownMenuItem(value: item, child: Text(item.label)),
          ],
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _DetailedElementControls(
          id: selected!.id,
          rect: selected!.rect,
          spec: selected!.spec,
          onRectChanged: (rect) => onChanged(selected!.copyWith(rect: rect)),
          onSpecChanged: (spec) => onChanged(selected!.copyWith(spec: spec)),
        ),
      ] else
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '선택한 섹션에 컨테이너가 없습니다.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
    ],
  );
}

class _FeatureLayerControls extends StatelessWidget {
  const _FeatureLayerControls({
    required this.features,
    required this.selected,
    required this.hasParent,
    required this.onAdd,
    required this.onSelected,
    required this.onChanged,
    required this.onRemove,
  });

  final List<StudioFeatureElement> features;
  final StudioFeatureElement? selected;
  final bool hasParent;
  final ValueChanged<StudioFeatureKind> onAdd;
  final ValueChanged<StudioFeatureElement> onSelected;
  final ValueChanged<StudioFeatureElement> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              key: const ValueKey('studio-add-shape-feature'),
              onPressed: hasParent
                  ? () => onAdd(StudioFeatureKind.shape)
                  : null,
              icon: const Icon(Icons.change_history_outlined),
              label: const Text('도형'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FilledButton.tonalIcon(
              key: const ValueKey('studio-add-image-feature'),
              onPressed: hasParent
                  ? () => onAdd(StudioFeatureKind.image)
                  : null,
              icon: const Icon(Icons.image_outlined),
              label: const Text('이미지'),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.outlined(
            key: const ValueKey('studio-remove-feature'),
            onPressed: selected == null ? null : onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      if (!hasParent)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '먼저 컨테이너 레이어에서 부모 컨테이너를 추가하세요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        )
      else if (selected != null) ...[
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<StudioFeatureElement>(
          key: const ValueKey('studio-feature-selector'),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '컨테이너의 feature'),
          items: [
            for (final item in features)
              DropdownMenuItem(
                value: item,
                child: Text('${item.label} · ${item.kind.label}'),
              ),
          ],
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _DetailedElementControls(
          id: selected!.id,
          rect: selected!.rect,
          spec: selected!.spec,
          imageAspectRatio: selected!.kind == StudioFeatureKind.image
              ? selected!.aspectRatio
              : null,
          onRectChanged: (rect) => onChanged(selected!.copyWith(rect: rect)),
          onSpecChanged: (spec) => onChanged(selected!.copyWith(spec: spec)),
        ),
      ],
    ],
  );
}

class _DetailedElementControls extends StatelessWidget {
  const _DetailedElementControls({
    required this.id,
    required this.rect,
    required this.spec,
    required this.onRectChanged,
    required this.onSpecChanged,
    this.imageAspectRatio,
  });

  final String id;
  final SectionGridRect rect;
  final AttachedSectionSpec spec;
  final ValueChanged<SectionGridRect> onRectChanged;
  final ValueChanged<AttachedSectionSpec> onSpecChanged;
  final double? imageAspectRatio;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          for (final entry in [('X', rect.x), ('Y', rect.y)]) ...[
            if (entry.$1 == 'Y') const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _GridValueDropdown(
                key: ValueKey('studio-detail-${entry.$1.toLowerCase()}-$id'),
                label: entry.$1,
                value: entry.$2,
                max: sectionTemplateDetailGridSize - 1,
                gridSize: sectionTemplateDetailGridSize,
                onChanged: (value) => onRectChanged(
                  copyGridRectWithin(
                    rect,
                    x: entry.$1 == 'X' ? value : null,
                    y: entry.$1 == 'Y' ? value : null,
                    gridSize: sectionTemplateDetailGridSize,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: _GridValueDropdown(
              label: '폭',
              value: rect.width,
              min: 1,
              max: sectionTemplateDetailGridSize - rect.x,
              gridSize: sectionTemplateDetailGridSize,
              onChanged: (value) => onRectChanged(
                imageAspectRatio == null
                    ? copyGridRectWithin(
                        rect,
                        width: value,
                        gridSize: sectionTemplateDetailGridSize,
                      )
                    : _aspectRect(rect, width: value),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _GridValueDropdown(
              label: '높이',
              value: rect.height,
              min: 1,
              max: sectionTemplateDetailGridSize - rect.y,
              gridSize: sectionTemplateDetailGridSize,
              onChanged: (value) => onRectChanged(
                imageAspectRatio == null
                    ? copyGridRectWithin(
                        rect,
                        height: value,
                        gridSize: sectionTemplateDetailGridSize,
                      )
                    : _aspectRect(rect, height: value),
              ),
            ),
          ),
        ],
      ),
      if (imageAspectRatio != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '이미지 비율 고정 · ${imageAspectRatio!.toStringAsFixed(3)}:1',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        )
      else ...[
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<SectionShapeMode>(
          initialValue: spec.mode,
          decoration: const InputDecoration(labelText: '도형 모드'),
          items: [
            for (final item in SectionShapeMode.values)
              DropdownMenuItem(value: item, child: Text(item.label)),
          ],
          onChanged: (value) {
            if (value != null) {
              onSpecChanged(
                spec.copyWith(
                  mode: value,
                  gridSize: sectionTemplateDetailGridSize,
                ),
              );
            }
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<SectionAttachmentFace>(
          initialValue: spec.face,
          decoration: const InputDecoration(labelText: '붙는 면'),
          items: [
            for (final item in SectionAttachmentFace.values)
              DropdownMenuItem(value: item, child: Text(item.label)),
          ],
          onChanged: (value) {
            if (value != null) {
              onSpecChanged(
                spec.copyWith(
                  face: value,
                  gridSize: sectionTemplateDetailGridSize,
                ),
              );
            }
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _GridValueDropdown(
                label: '면 시작',
                value: spec.faceStart,
                max: sectionTemplateDetailGridSize - 1,
                gridSize: sectionTemplateDetailGridSize,
                onChanged: (value) => onSpecChanged(
                  spec.copyWith(
                    faceStart: value,
                    gridSize: sectionTemplateDetailGridSize,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _GridValueDropdown(
                key: ValueKey('studio-detail-face-span-$id-${spec.faceStart}'),
                label: '면 길이',
                value: spec.faceSpan,
                min: 1,
                max: sectionTemplateDetailGridSize - spec.faceStart,
                gridSize: sectionTemplateDetailGridSize,
                onChanged: (value) => onSpecChanged(
                  spec.copyWith(
                    faceSpan: value,
                    gridSize: sectionTemplateDetailGridSize,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (spec.mode != SectionShapeMode.triangle) ...[
          const SizedBox(height: AppSpacing.sm),
          _GridValueDropdown(
            label: '도형 높이',
            value: spec.height,
            min: 1,
            max: sectionTemplateDetailGridSize,
            gridSize: sectionTemplateDetailGridSize,
            onChanged: (value) => onSpecChanged(
              spec.copyWith(
                height: value,
                gridSize: sectionTemplateDetailGridSize,
              ),
            ),
          ),
        ],
      ],
    ],
  );

  SectionGridRect _aspectRect(
    SectionGridRect source, {
    int? width,
    int? height,
  }) {
    final ratio = imageAspectRatio!;
    var nextWidth = width ?? (height! * ratio).round();
    var nextHeight = height ?? (width! / ratio).round();
    nextWidth = nextWidth.clamp(1, sectionTemplateDetailGridSize - source.x);
    nextHeight = nextHeight.clamp(1, sectionTemplateDetailGridSize - source.y);
    if (nextWidth / nextHeight > ratio) {
      nextWidth = (nextHeight * ratio).round().clamp(
        1,
        sectionTemplateDetailGridSize - source.x,
      );
    } else {
      nextHeight = (nextWidth / ratio).round().clamp(
        1,
        sectionTemplateDetailGridSize - source.y,
      );
    }
    return SectionGridRect(source.x, source.y, nextWidth, nextHeight);
  }
}

class _GridRectControls extends StatelessWidget {
  const _GridRectControls({required this.element, required this.onChanged});

  final SectionCanvasElement element;
  final ValueChanged<SectionCanvasElement> onChanged;

  @override
  Widget build(BuildContext context) {
    final rect = element.rect;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _GridValueDropdown(
                key: ValueKey('studio-rect-x-${element.id}'),
                label: 'X',
                value: rect.x,
                max: sectionTemplateGridSize - 1,
                onChanged: (value) =>
                    onChanged(element.copyWith(rect: rect.copyWith(x: value))),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _GridValueDropdown(
                key: ValueKey('studio-rect-y-${element.id}'),
                label: 'Y',
                value: rect.y,
                max: sectionTemplateGridSize - 1,
                onChanged: (value) =>
                    onChanged(element.copyWith(rect: rect.copyWith(y: value))),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _GridValueDropdown(
                key: ValueKey('studio-rect-width-${element.id}-${rect.x}'),
                label: '폭',
                value: rect.width,
                min: 1,
                max: sectionTemplateGridSize - rect.x,
                onChanged: (value) => onChanged(
                  element.copyWith(rect: rect.copyWith(width: value)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _GridValueDropdown(
                key: ValueKey('studio-rect-height-${element.id}-${rect.y}'),
                label: '높이',
                value: rect.height,
                min: 1,
                max: sectionTemplateGridSize - rect.y,
                onChanged: (value) => onChanged(
                  element.copyWith(rect: rect.copyWith(height: value)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GridValueDropdown extends StatelessWidget {
  const _GridValueDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.min = 0,
    this.gridSize = sectionTemplateGridSize,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int gridSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (var item = min; item <= max; item++)
        DropdownMenuItem(value: item, child: Text('$item/$gridSize')),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );
}

class _StudioPreview extends StatefulWidget {
  const _StudioPreview({
    required this.viewport,
    required this.elements,
    required this.containers,
    required this.features,
    required this.activeLayer,
    required this.selectedElementId,
    required this.selectedContainerId,
    required this.selectedFeatureId,
    required this.squareImage,
    required this.headerRows,
    required this.showGrid,
    required this.showSafeArea,
    required this.onElementSelected,
    required this.onElementRectChanged,
    required this.onContainerSelected,
    required this.onContainerRectChanged,
    required this.onFeatureSelected,
    required this.onFeatureRectChanged,
  });

  final _StudioViewport viewport;
  final List<SectionCanvasElement> elements;
  final List<StudioContainerElement> containers;
  final List<StudioFeatureElement> features;
  final StudioLayer activeLayer;
  final String selectedElementId;
  final String? selectedContainerId;
  final String? selectedFeatureId;
  final ui.Image? squareImage;
  final int headerRows;
  final bool showGrid;
  final bool showSafeArea;
  final ValueChanged<String> onElementSelected;
  final void Function(String id, SectionGridRect rect) onElementRectChanged;
  final ValueChanged<String> onContainerSelected;
  final void Function(String id, SectionGridRect rect) onContainerRectChanged;
  final ValueChanged<String> onFeatureSelected;
  final void Function(String id, SectionGridRect rect) onFeatureRectChanged;

  @override
  State<_StudioPreview> createState() => _StudioPreviewState();
}

class _StudioPreviewState extends State<_StudioPreview> {
  String? _dragElementId;
  SectionGridRect? _dragStartRect;
  Offset? _dragStartPosition;
  SectionResizeHandle? _resizeHandle;
  SectionGridRect? _lastDragRect;
  SectionResizeHandle? _hoveredHandle;
  bool _hoveringElement = false;

  _StudioViewport get viewport => widget.viewport;
  List<SectionCanvasElement> get elements => widget.elements;
  List<StudioContainerElement> get containers => widget.containers;
  List<StudioFeatureElement> get features => widget.features;
  String get selectedElementId => widget.selectedElementId;
  int get headerRows => widget.headerRows;
  bool get showGrid => widget.showGrid;
  bool get showSafeArea => widget.showSafeArea;

  StudioContainerElement? _containerById(String? id) {
    if (id == null) return null;
    for (final item in containers) {
      if (item.id == id) return item;
    }
    return null;
  }

  StudioFeatureElement? _featureById(String? id) {
    if (id == null) return null;
    for (final item in features) {
      if (item.id == id) return item;
    }
    return null;
  }

  SectionCanvasElement? _elementById(String id) {
    for (final element in elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  void _prepareDrag(Offset position, Size size) {
    final selectedRect = _selectedPhysicalRect(size);
    final handle = selectedRect == null
        ? null
        : hitTestStudioRectHandle(selectedRect, position);
    final id = handle == null
        ? _hitTestActiveLayer(size, position)
        : _selectedId;
    if (id == null) return;
    final rect = _activeRectById(id);
    if (rect == null) return;
    if (id != _selectedId) _selectActiveId(id);
    _dragElementId = id;
    _dragStartRect = rect;
    _dragStartPosition = position;
    _resizeHandle = handle;
    _lastDragRect = rect;
  }

  void _startDrag(DragStartDetails details, Size size) {
    if (_dragElementId == null) _prepareDrag(details.localPosition, size);
  }

  void _updateDrag(DragUpdateDetails details, Size size) {
    final id = _dragElementId;
    final startRect = _dragStartRect;
    final startPosition = _dragStartPosition;
    if (id == null || startRect == null || startPosition == null) return;
    final delta = details.localPosition - startPosition;
    final parentRect = _activeParentRect(size, id);
    if (parentRect == null || parentRect.width <= 0 || parentRect.height <= 0) {
      return;
    }
    final gridSize = widget.activeLayer.gridSize;
    final deltaX = (delta.dx * gridSize / parentRect.width).round();
    final deltaY = (delta.dy * gridSize / parentRect.height).round();
    final handle = _resizeHandle;
    final nextRect = handle == null
        ? moveSectionGridRect(
            startRect,
            deltaX: deltaX,
            deltaY: deltaY,
            gridSize: gridSize,
          )
        : _resizeActiveRect(startRect, handle, deltaX, deltaY, gridSize, id);
    if (_sameGridRect(nextRect, _lastDragRect)) return;
    _lastDragRect = nextRect;
    switch (widget.activeLayer) {
      case StudioLayer.section:
        widget.onElementRectChanged(id, nextRect);
      case StudioLayer.container:
        widget.onContainerRectChanged(id, nextRect);
      case StudioLayer.feature:
        widget.onFeatureRectChanged(id, nextRect);
    }
  }

  String? get _selectedId => switch (widget.activeLayer) {
    StudioLayer.section => selectedElementId,
    StudioLayer.container => widget.selectedContainerId,
    StudioLayer.feature => widget.selectedFeatureId,
  };

  SectionGridRect? _activeRectById(String id) => switch (widget.activeLayer) {
    StudioLayer.section => _elementById(id)?.rect,
    StudioLayer.container => _containerById(id)?.rect,
    StudioLayer.feature => _featureById(id)?.rect,
  };

  Rect? _selectedPhysicalRect(Size size) => switch (widget.activeLayer) {
    StudioLayer.section =>
      _elementById(selectedElementId) == null
          ? null
          : sectionCanvasElementRect(size, _elementById(selectedElementId)!),
    StudioLayer.container =>
      _containerById(widget.selectedContainerId) == null
          ? null
          : studioContainerRect(
              size,
              elements,
              _containerById(widget.selectedContainerId)!,
            ),
    StudioLayer.feature =>
      _featureById(widget.selectedFeatureId) == null
          ? null
          : studioFeatureRect(
              size,
              elements,
              containers,
              _featureById(widget.selectedFeatureId)!,
            ),
  };

  String? _hitTestActiveLayer(Size size, Offset position) =>
      switch (widget.activeLayer) {
        StudioLayer.section => hitTestSectionCanvasElement(
          size,
          elements,
          position,
        ),
        StudioLayer.container => hitTestStudioContainer(
          size,
          elements,
          containers
              .where((item) => item.parentSectionId == selectedElementId)
              .toList(growable: false),
          position,
        ),
        StudioLayer.feature => hitTestStudioFeature(
          size,
          elements,
          containers,
          features
              .where(
                (item) => item.parentContainerId == widget.selectedContainerId,
              )
              .toList(growable: false),
          position,
        ),
      };

  void _selectActiveId(String id) {
    switch (widget.activeLayer) {
      case StudioLayer.section:
        widget.onElementSelected(id);
      case StudioLayer.container:
        widget.onContainerSelected(id);
      case StudioLayer.feature:
        widget.onFeatureSelected(id);
    }
  }

  Rect? _activeParentRect(Size size, String id) {
    switch (widget.activeLayer) {
      case StudioLayer.section:
        return Offset.zero & size;
      case StudioLayer.container:
        final item = _containerById(id);
        final section = item == null
            ? null
            : _elementById(item.parentSectionId);
        return section == null ? null : sectionCanvasElementRect(size, section);
      case StudioLayer.feature:
        final item = _featureById(id);
        final container = item == null
            ? null
            : _containerById(item.parentContainerId);
        return container == null
            ? null
            : studioContainerRect(size, elements, container);
    }
  }

  SectionGridRect _resizeActiveRect(
    SectionGridRect rect,
    SectionResizeHandle handle,
    int deltaX,
    int deltaY,
    int gridSize,
    String id,
  ) {
    final feature = widget.activeLayer == StudioLayer.feature
        ? _featureById(id)
        : null;
    if (feature?.kind == StudioFeatureKind.image) {
      return resizeAspectLockedGridRect(
        rect,
        handle: handle,
        deltaX: deltaX,
        deltaY: deltaY,
        aspectRatio: feature!.aspectRatio ?? studioSquareAspectRatio,
        gridSize: gridSize,
      );
    }
    return resizeSectionGridRect(
      rect,
      handle: handle,
      deltaX: deltaX,
      deltaY: deltaY,
      gridSize: gridSize,
    );
  }

  void _endDrag() {
    _dragElementId = null;
    _dragStartRect = null;
    _dragStartPosition = null;
    _resizeHandle = null;
    _lastDragRect = null;
  }

  bool _sameGridRect(SectionGridRect value, SectionGridRect? other) =>
      other != null &&
      value.x == other.x &&
      value.y == other.y &&
      value.width == other.width &&
      value.height == other.height;

  void _updateHover(PointerHoverEvent event, Size size) {
    final selectedRect = _selectedPhysicalRect(size);
    final nextHandle = selectedRect == null
        ? null
        : hitTestStudioRectHandle(selectedRect, event.localPosition);
    final nextHoveringElement =
        nextHandle != null ||
        _hitTestActiveLayer(size, event.localPosition) != null;
    if (nextHandle == _hoveredHandle &&
        nextHoveringElement == _hoveringElement) {
      return;
    }
    setState(() {
      _hoveredHandle = nextHandle;
      _hoveringElement = nextHoveringElement;
    });
  }

  MouseCursor get _cursor => switch (_hoveredHandle) {
    SectionResizeHandle.topLeft ||
    SectionResizeHandle.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
    SectionResizeHandle.topRight ||
    SectionResizeHandle.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
    null => _hoveringElement ? SystemMouseCursors.move : MouseCursor.defer,
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.canvas.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / viewport.size.width).clamp(
              0.0,
              constraints.maxHeight / viewport.size.height,
            );
            final size = viewport.size * scale;
            final headerHeight =
                size.height * headerRows / sectionTemplateGridSize;
            return Center(
              child: SizedBox.fromSize(
                key: const ValueKey('studio-preview-canvas'),
                size: size,
                child: Column(
                  children: [
                    SizedBox(
                      key: const ValueKey('studio-preview-header'),
                      height: headerHeight,
                      child: _StudioPreviewHeader(headerRows: headerRows),
                    ),
                    Expanded(
                      key: const ValueKey('studio-preview-content'),
                      child: LayoutBuilder(
                        builder: (context, contentConstraints) {
                          final contentSize = contentConstraints.biggest;
                          return MouseRegion(
                            cursor: _cursor,
                            onHover: (event) =>
                                _updateHover(event, contentSize),
                            onExit: (_) {
                              if (_hoveredHandle != null || _hoveringElement) {
                                setState(() {
                                  _hoveredHandle = null;
                                  _hoveringElement = false;
                                });
                              }
                            },
                            child: GestureDetector(
                              key: const ValueKey('studio-shared-canvas'),
                              behavior: HitTestBehavior.opaque,
                              onPanDown: (details) => _prepareDrag(
                                details.localPosition,
                                contentSize,
                              ),
                              onPanStart: (details) =>
                                  _startDrag(details, contentSize),
                              onPanUpdate: (details) =>
                                  _updateDrag(details, contentSize),
                              onPanEnd: (_) => _endDrag(),
                              onPanCancel: _endDrag,
                              child: CustomPaint(
                                painter: _StudioGridPainter(showGrid: showGrid),
                                foregroundPainter: LayeredStudioPainter(
                                  sections: List<SectionCanvasElement>.of(
                                    elements,
                                  ),
                                  containers: List<StudioContainerElement>.of(
                                    containers,
                                  ),
                                  features: List<StudioFeatureElement>.of(
                                    features,
                                  ),
                                  activeLayer: widget.activeLayer,
                                  selectedSectionId: selectedElementId,
                                  selectedContainerId:
                                      widget.selectedContainerId,
                                  selectedFeatureId: widget.selectedFeatureId,
                                  showGrid: showGrid,
                                  showSafeArea: showSafeArea,
                                  squareImage: widget.squareImage,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StudioPreviewHeader extends StatelessWidget {
  const _StudioPreviewHeader({required this.headerRows});

  final int headerRows;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised.withValues(alpha: 0.96),
      border: const Border(bottom: BorderSide(color: AppColors.primary)),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.view_agenda_outlined, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('고정 헤더', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          Text(
            '$headerRows/$sectionTemplateGridSize',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _StudioGridPainter extends CustomPainter {
  const _StudioGridPainter({required this.showGrid});

  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = AppColors.navigation.withValues(alpha: 0.72),
    );
    if (!showGrid) return;
    final halfCut = sectionTemplateCutDepth(size.height) / 2;
    for (var i = 1; i < sectionTemplateGridSize; i++) {
      final major = i % sectionTemplateSubdivisionsPerMajor == 0;
      final paint = Paint()
        ..color = AppColors.outline.withValues(alpha: major ? 0.72 : 0.2)
        ..strokeWidth = major ? 1.2 : 0.45;
      final x = size.width * i / sectionTemplateGridSize;
      final y = size.height * i / sectionTemplateGridSize;
      canvas.drawLine(
        Offset(x + halfCut, 0),
        Offset(x - halfCut, size.height),
        paint,
      );
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_StudioGridPainter oldDelegate) =>
      oldDelegate.showGrid != showGrid;
}
