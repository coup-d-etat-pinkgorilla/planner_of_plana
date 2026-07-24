import 'dart:convert';

import 'section_template.dart';

const sectionStudioDocumentFormat = 'ba-planner-section-studio';
const sectionStudioDocumentVersion = 2;
const sectionStudioDocumentExtension = 'ba-section-studio.json';
const sectionStudioMaximumElements = 256;

class SectionStudioDocument {
  SectionStudioDocument({
    required this.headerRows,
    required this.viewport,
    required this.showGrid,
    required this.showSafeArea,
    required this.selectedElementId,
    required List<SectionCanvasElement> elements,
    this.activeLayer = StudioLayer.section,
    this.selectedContainerId,
    this.selectedFeatureId,
    List<StudioContainerElement> containers = const [],
    List<StudioFeatureElement> features = const [],
  }) : elements = List<SectionCanvasElement>.unmodifiable(elements),
       containers = List<StudioContainerElement>.unmodifiable(containers),
       features = List<StudioFeatureElement>.unmodifiable(features);

  final int headerRows;
  final String viewport;
  final bool showGrid;
  final bool showSafeArea;
  final String selectedElementId;
  final List<SectionCanvasElement> elements;
  final StudioLayer activeLayer;
  final String? selectedContainerId;
  final String? selectedFeatureId;
  final List<StudioContainerElement> containers;
  final List<StudioFeatureElement> features;
}

String encodeSectionStudioDocument(SectionStudioDocument document) {
  final data = <String, Object>{
    'format': sectionStudioDocumentFormat,
    'version': sectionStudioDocumentVersion,
    'gridSize': sectionTemplateGridSize,
    'detailGridSize': sectionTemplateDetailGridSize,
    'diagonal': <String, Object>{'direction': 'up-right', 'angleDegrees': 80},
    'workspace': <String, Object?>{
      'headerRows': document.headerRows,
      'viewport': document.viewport,
      'showGrid': document.showGrid,
      'showSafeArea': document.showSafeArea,
      'selectedElementId': document.selectedElementId,
      'activeLayer': document.activeLayer.name,
      'selectedContainerId': document.selectedContainerId,
      'selectedFeatureId': document.selectedFeatureId,
    },
    'elements': [
      for (final element in document.elements)
        <String, Object>{
          'id': element.id,
          'label': element.label,
          'rect': <String, Object>{
            'x': element.rect.x,
            'y': element.rect.y,
            'width': element.rect.width,
            'height': element.rect.height,
          },
          'shape': <String, Object>{
            'mode': element.spec.mode.name,
            'face': element.spec.face.name,
            'faceStart': element.spec.faceStart,
            'faceSpan': element.spec.faceSpan,
            'height': element.spec.height,
          },
        },
    ],
    'containers': [
      for (final item in document.containers)
        <String, Object>{
          'id': item.id,
          'label': item.label,
          'parentSectionId': item.parentSectionId,
          'rect': _encodeRect(item.rect),
          'shape': _encodeShape(item.spec),
        },
    ],
    'features': [
      for (final item in document.features)
        <String, Object?>{
          'id': item.id,
          'label': item.label,
          'parentContainerId': item.parentContainerId,
          'kind': item.kind.name,
          'rect': _encodeRect(item.rect),
          'shape': _encodeShape(item.spec),
          'imageAsset': item.imageAsset,
          'aspectRatio': item.aspectRatio,
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}

SectionStudioDocument decodeSectionStudioDocument(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw FormatException('올바른 JSON 파일이 아닙니다: ${error.message}');
  }
  final root = _map(decoded, '문서');
  if (_string(root, 'format') != sectionStudioDocumentFormat) {
    throw const FormatException('Section Template Studio 저장 파일이 아닙니다.');
  }
  final version = _integer(root, 'version');
  if (version < 1 || version > sectionStudioDocumentVersion) {
    throw FormatException(
      '지원하지 않는 저장 형식 버전입니다: $version '
      '(지원 버전: $sectionStudioDocumentVersion)',
    );
  }
  if (_integer(root, 'gridSize') != sectionTemplateGridSize) {
    throw const FormatException('이 Studio는 48×48 그리드 문서만 불러올 수 있습니다.');
  }
  if (version >= 2 &&
      _integer(root, 'detailGridSize') != sectionTemplateDetailGridSize) {
    throw const FormatException('컨테이너와 feature는 96×96 그리드 문서여야 합니다.');
  }
  final diagonal = _map(root['diagonal'], 'diagonal');
  if (_string(diagonal, 'direction') != 'up-right' ||
      _integer(diagonal, 'angleDegrees') != 80) {
    throw const FormatException('사선은 우측 위 방향 80°로 고정되어야 합니다.');
  }

  final workspace = _map(root['workspace'], 'workspace');
  final headerRows = _integerInRange(
    workspace,
    'headerRows',
    1,
    sectionTemplateGridSize ~/ 2,
  );
  final viewport = _string(workspace, 'viewport');
  if (!const {'standard', 'wide', 'compact'}.contains(viewport)) {
    throw FormatException('알 수 없는 viewport 값입니다: $viewport');
  }
  final showGrid = _boolean(workspace, 'showGrid');
  final showSafeArea = _boolean(workspace, 'showSafeArea');
  final selectedElementId = _nonEmptyString(workspace, 'selectedElementId');
  final activeLayer = version >= 2
      ? _enumValue(
          StudioLayer.values,
          _string(workspace, 'activeLayer'),
          'workspace.activeLayer',
        )
      : StudioLayer.section;
  final selectedContainerId = version >= 2
      ? _nullableString(workspace, 'selectedContainerId')
      : null;
  final selectedFeatureId = version >= 2
      ? _nullableString(workspace, 'selectedFeatureId')
      : null;

  final rawElements = root['elements'];
  if (rawElements is! List || rawElements.isEmpty) {
    throw const FormatException('elements에는 하나 이상의 요소가 필요합니다.');
  }
  if (rawElements.length > sectionStudioMaximumElements) {
    throw FormatException(
      '요소는 최대 $sectionStudioMaximumElements개까지 불러올 수 있습니다.',
    );
  }

  final ids = <String>{};
  final elements = <SectionCanvasElement>[];
  for (var index = 0; index < rawElements.length; index++) {
    final path = 'elements[$index]';
    final raw = _map(rawElements[index], path);
    final id = _nonEmptyString(raw, 'id', path: path, maxLength: 120);
    if (!ids.add(id)) {
      throw FormatException('중복 요소 ID입니다: $id');
    }
    final label = _nonEmptyString(raw, 'label', path: path, maxLength: 120);
    final rectData = _map(raw['rect'], '$path.rect');
    final x = _integerInRange(
      rectData,
      'x',
      0,
      sectionTemplateGridSize - 1,
      path: '$path.rect',
    );
    final y = _integerInRange(
      rectData,
      'y',
      0,
      sectionTemplateGridSize - 1,
      path: '$path.rect',
    );
    final width = _integerInRange(
      rectData,
      'width',
      1,
      sectionTemplateGridSize - x,
      path: '$path.rect',
    );
    final height = _integerInRange(
      rectData,
      'height',
      1,
      sectionTemplateGridSize - y,
      path: '$path.rect',
    );
    final shapeData = _map(raw['shape'], '$path.shape');
    final mode = _enumValue(
      SectionShapeMode.values,
      _string(shapeData, 'mode', path: '$path.shape'),
      '$path.shape.mode',
    );
    final face = _enumValue(
      SectionAttachmentFace.values,
      _string(shapeData, 'face', path: '$path.shape'),
      '$path.shape.face',
    );
    final faceStart = _integerInRange(
      shapeData,
      'faceStart',
      0,
      sectionTemplateGridSize - 1,
      path: '$path.shape',
    );
    final faceSpan = _integerInRange(
      shapeData,
      'faceSpan',
      1,
      sectionTemplateGridSize - faceStart,
      path: '$path.shape',
    );
    final shapeHeight = _integerInRange(
      shapeData,
      'height',
      1,
      sectionTemplateGridSize,
      path: '$path.shape',
    );
    elements.add(
      SectionCanvasElement(
        id: id,
        label: label,
        rect: SectionGridRect(x, y, width, height),
        spec: AttachedSectionSpec(
          mode: mode,
          face: face,
          faceStart: faceStart,
          faceSpan: faceSpan,
          height: shapeHeight,
        ),
      ),
    );
  }
  if (!ids.contains(selectedElementId)) {
    throw const FormatException('선택된 요소 ID가 elements에 존재하지 않습니다.');
  }

  final containers = <StudioContainerElement>[];
  final features = <StudioFeatureElement>[];
  if (version >= 2) {
    final rawContainers = root['containers'];
    final rawFeatures = root['features'];
    if (rawContainers is! List || rawFeatures is! List) {
      throw const FormatException('containers와 features는 배열이어야 합니다.');
    }
    for (var index = 0; index < rawContainers.length; index++) {
      final path = 'containers[$index]';
      final raw = _map(rawContainers[index], path);
      final id = _nonEmptyString(raw, 'id', path: path, maxLength: 120);
      if (!ids.add(id)) throw FormatException('중복 요소 ID입니다: $id');
      final parentId = _nonEmptyString(raw, 'parentSectionId', path: path);
      if (!elements.any((item) => item.id == parentId)) {
        throw FormatException('$path 부모 섹션이 존재하지 않습니다.');
      }
      containers.add(
        StudioContainerElement(
          id: id,
          label: _nonEmptyString(raw, 'label', path: path),
          parentSectionId: parentId,
          rect: _decodeRect(
            raw['rect'],
            '$path.rect',
            sectionTemplateDetailGridSize,
          ),
          spec: _decodeShape(
            raw['shape'],
            '$path.shape',
            sectionTemplateDetailGridSize,
          ),
        ),
      );
    }
    for (var index = 0; index < rawFeatures.length; index++) {
      final path = 'features[$index]';
      final raw = _map(rawFeatures[index], path);
      final id = _nonEmptyString(raw, 'id', path: path, maxLength: 120);
      if (!ids.add(id)) throw FormatException('중복 요소 ID입니다: $id');
      final parentId = _nonEmptyString(raw, 'parentContainerId', path: path);
      if (!containers.any((item) => item.id == parentId)) {
        throw FormatException('$path 부모 컨테이너가 존재하지 않습니다.');
      }
      final kind = _enumValue(
        StudioFeatureKind.values,
        _string(raw, 'kind', path: path),
        '$path.kind',
      );
      final imageAsset = _nullableString(raw, 'imageAsset');
      final aspectRatio = _nullableNumber(raw, 'aspectRatio');
      if (kind == StudioFeatureKind.image &&
          (imageAsset == null || aspectRatio == null || aspectRatio <= 0)) {
        throw FormatException('$path 이미지 source와 양수 비율이 필요합니다.');
      }
      features.add(
        StudioFeatureElement(
          id: id,
          label: _nonEmptyString(raw, 'label', path: path),
          parentContainerId: parentId,
          rect: _decodeRect(
            raw['rect'],
            '$path.rect',
            sectionTemplateDetailGridSize,
          ),
          kind: kind,
          spec: _decodeShape(
            raw['shape'],
            '$path.shape',
            sectionTemplateDetailGridSize,
          ),
          imageAsset: imageAsset,
          aspectRatio: aspectRatio,
        ),
      );
    }
    if (selectedContainerId != null &&
        !containers.any((item) => item.id == selectedContainerId)) {
      throw const FormatException('선택된 컨테이너 ID가 존재하지 않습니다.');
    }
    if (selectedFeatureId != null &&
        !features.any((item) => item.id == selectedFeatureId)) {
      throw const FormatException('선택된 feature ID가 존재하지 않습니다.');
    }
    if (selectedContainerId != null &&
        containers
                .firstWhere((item) => item.id == selectedContainerId)
                .parentSectionId !=
            selectedElementId) {
      throw const FormatException('선택된 컨테이너는 선택된 섹션의 자식이어야 합니다.');
    }
    if (selectedFeatureId != null &&
        features
                .firstWhere((item) => item.id == selectedFeatureId)
                .parentContainerId !=
            selectedContainerId) {
      throw const FormatException('선택된 feature는 선택된 컨테이너의 자식이어야 합니다.');
    }
  }

  return SectionStudioDocument(
    headerRows: headerRows,
    viewport: viewport,
    showGrid: showGrid,
    showSafeArea: showSafeArea,
    selectedElementId: selectedElementId,
    elements: elements,
    activeLayer: activeLayer,
    selectedContainerId: selectedContainerId,
    selectedFeatureId: selectedFeatureId,
    containers: containers,
    features: features,
  );
}

Map<String, Object> _encodeRect(SectionGridRect rect) => {
  'x': rect.x,
  'y': rect.y,
  'width': rect.width,
  'height': rect.height,
};

Map<String, Object> _encodeShape(AttachedSectionSpec spec) => {
  'mode': spec.mode.name,
  'face': spec.face.name,
  'faceStart': spec.faceStart,
  'faceSpan': spec.faceSpan,
  'height': spec.height,
};

SectionGridRect _decodeRect(Object? value, String path, int gridSize) {
  final raw = _map(value, path);
  final x = _integerInRange(raw, 'x', 0, gridSize - 1, path: path);
  final y = _integerInRange(raw, 'y', 0, gridSize - 1, path: path);
  return SectionGridRect(
    x,
    y,
    _integerInRange(raw, 'width', 1, gridSize - x, path: path),
    _integerInRange(raw, 'height', 1, gridSize - y, path: path),
  );
}

AttachedSectionSpec _decodeShape(Object? value, String path, int gridSize) {
  final raw = _map(value, path);
  final start = _integerInRange(raw, 'faceStart', 0, gridSize - 1, path: path);
  return AttachedSectionSpec(
    mode: _enumValue(
      SectionShapeMode.values,
      _string(raw, 'mode', path: path),
      '$path.mode',
    ),
    face: _enumValue(
      SectionAttachmentFace.values,
      _string(raw, 'face', path: path),
      '$path.face',
    ),
    faceStart: start,
    faceSpan: _integerInRange(raw, 'faceSpan', 1, gridSize - start, path: path),
    height: _integerInRange(raw, 'height', 1, gridSize, path: path),
  );
}

Map<String, Object?> _map(Object? value, String path) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$path 값은 객체여야 합니다.');
  }
  return value;
}

String _string(Map<String, Object?> map, String key, {String? path}) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('${path ?? '문서'}.$key 값은 문자열이어야 합니다.');
  }
  return value;
}

String _nonEmptyString(
  Map<String, Object?> map,
  String key, {
  String? path,
  int maxLength = 240,
}) {
  final value = _string(map, key, path: path);
  if (value.trim().isEmpty || value.length > maxLength) {
    throw FormatException('${path ?? '문서'}.$key 값은 1~$maxLength자여야 합니다.');
  }
  return value;
}

String? _nullableString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty || value.length > 240) {
    throw FormatException('문서.$key 값은 null 또는 문자열이어야 합니다.');
  }
  return value;
}

double? _nullableNumber(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! num || !value.isFinite) {
    throw FormatException('문서.$key 값은 null 또는 숫자여야 합니다.');
  }
  return value.toDouble();
}

int _integer(Map<String, Object?> map, String key, {String? path}) {
  final value = map[key];
  if (value is! int) {
    throw FormatException('${path ?? '문서'}.$key 값은 정수여야 합니다.');
  }
  return value;
}

int _integerInRange(
  Map<String, Object?> map,
  String key,
  int min,
  int max, {
  String? path,
}) {
  final value = _integer(map, key, path: path);
  if (value < min || value > max) {
    throw FormatException('${path ?? '문서'}.$key 값은 $min~$max 범위여야 합니다.');
  }
  return value;
}

bool _boolean(Map<String, Object?> map, String key, {String? path}) {
  final value = map[key];
  if (value is! bool) {
    throw FormatException('${path ?? '문서'}.$key 값은 boolean이어야 합니다.');
  }
  return value;
}

T _enumValue<T extends Enum>(List<T> values, String name, String path) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('$path 값이 올바르지 않습니다: $name');
}
