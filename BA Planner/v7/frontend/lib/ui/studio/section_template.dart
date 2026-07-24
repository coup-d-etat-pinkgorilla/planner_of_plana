const sectionTemplateMajorDivisions = 6;
const sectionTemplateSubdivisionsPerMajor = 8;
const sectionTemplateGridSize =
    sectionTemplateMajorDivisions * sectionTemplateSubdivisionsPerMajor;
const sectionTemplateSectionGap = 1;
const sectionTemplateDetailGridSize = 96;

enum StudioLayer {
  section('섹션', sectionTemplateGridSize),
  container('컨테이너', sectionTemplateDetailGridSize),
  feature('Feature', sectionTemplateDetailGridSize);

  const StudioLayer(this.label, this.gridSize);
  final String label;
  final int gridSize;
}

enum StudioFeatureKind {
  shape('도형'),
  image('이미지');

  const StudioFeatureKind(this.label);
  final String label;
}

const studioSquareAssetPath = 'assets/studio_features/square.png';
const studioSquareAspectRatio = 252 / 172;

enum SectionShapeMode {
  triangle('삼각형'),
  trapezoid('사다리꼴'),
  parallelogram('평행사변형');

  const SectionShapeMode(this.label);
  final String label;
}

enum SectionAttachmentFace {
  left('왼쪽 면'),
  right('오른쪽 면'),
  top('위쪽 면'),
  bottom('아래쪽 면');

  const SectionAttachmentFace(this.label);
  final String label;
}

class AttachedSectionSpec {
  const AttachedSectionSpec({
    required this.mode,
    required this.face,
    this.faceStart = 0,
    this.faceSpan = sectionTemplateGridSize,
    this.height = 3,
  });

  final SectionShapeMode mode;
  final SectionAttachmentFace face;
  final int faceStart;
  final int faceSpan;
  final int height;

  int get faceEnd => faceStart + faceSpan;

  AttachedSectionSpec copyWith({
    SectionShapeMode? mode,
    SectionAttachmentFace? face,
    int? faceStart,
    int? faceSpan,
    int? height,
    int gridSize = sectionTemplateGridSize,
  }) {
    final nextStart = faceStart ?? this.faceStart;
    final requestedSpan = faceSpan ?? this.faceSpan;
    return AttachedSectionSpec(
      mode: mode ?? this.mode,
      face: face ?? this.face,
      faceStart: nextStart,
      faceSpan: requestedSpan.clamp(1, gridSize - nextStart),
      height: (height ?? this.height).clamp(1, gridSize),
    );
  }
}

const defaultAttachedSectionSpec = AttachedSectionSpec(
  mode: SectionShapeMode.trapezoid,
  face: SectionAttachmentFace.left,
  faceSpan: sectionTemplateGridSize,
  height: sectionTemplateGridSize ~/ 2,
);

const defaultDetailedShapeSpec = AttachedSectionSpec(
  mode: SectionShapeMode.trapezoid,
  face: SectionAttachmentFace.left,
  faceSpan: sectionTemplateDetailGridSize,
  height: sectionTemplateDetailGridSize ~/ 2,
);

enum SectionShape {
  rightCut('우측 / 사선'),
  leftCut('좌측 / 사선'),
  bilateral('양측 / 사선'),
  triangleLeft('좌상단 잔여 삼각형'),
  triangleRight('우하단 잔여 삼각형');

  const SectionShape(this.label);
  final String label;
}

class SectionGridRect {
  const SectionGridRect(this.x, this.y, this.width, this.height);

  final int x;
  final int y;
  final int width;
  final int height;

  int get right => x + width;
  int get bottom => y + height;

  bool overlaps(SectionGridRect other) =>
      x < other.right &&
      right > other.x &&
      y < other.bottom &&
      bottom > other.y;
  SectionGridRect copyWith({int? x, int? y, int? width, int? height}) {
    final nextX = (x ?? this.x).clamp(0, sectionTemplateGridSize - 1);
    final nextY = (y ?? this.y).clamp(0, sectionTemplateGridSize - 1);
    return SectionGridRect(
      nextX,
      nextY,
      (width ?? this.width).clamp(1, sectionTemplateGridSize - nextX),
      (height ?? this.height).clamp(1, sectionTemplateGridSize - nextY),
    );
  }
}

enum SectionResizeHandle { topLeft, topRight, bottomLeft, bottomRight }

SectionGridRect copyGridRectWithin(
  SectionGridRect rect, {
  int? x,
  int? y,
  int? width,
  int? height,
  int gridSize = sectionTemplateGridSize,
}) {
  final nextX = (x ?? rect.x).clamp(0, gridSize - 1);
  final nextY = (y ?? rect.y).clamp(0, gridSize - 1);
  return SectionGridRect(
    nextX,
    nextY,
    (width ?? rect.width).clamp(1, gridSize - nextX),
    (height ?? rect.height).clamp(1, gridSize - nextY),
  );
}

SectionGridRect moveSectionGridRect(
  SectionGridRect rect, {
  required int deltaX,
  required int deltaY,
  int gridSize = sectionTemplateGridSize,
}) => SectionGridRect(
  (rect.x + deltaX).clamp(0, gridSize - rect.width),
  (rect.y + deltaY).clamp(0, gridSize - rect.height),
  rect.width,
  rect.height,
);

SectionGridRect resizeSectionGridRect(
  SectionGridRect rect, {
  required SectionResizeHandle handle,
  required int deltaX,
  required int deltaY,
  int gridSize = sectionTemplateGridSize,
}) {
  final moveLeft =
      handle == SectionResizeHandle.topLeft ||
      handle == SectionResizeHandle.bottomLeft;
  final moveTop =
      handle == SectionResizeHandle.topLeft ||
      handle == SectionResizeHandle.topRight;
  final moveRight =
      handle == SectionResizeHandle.topRight ||
      handle == SectionResizeHandle.bottomRight;
  final moveBottom =
      handle == SectionResizeHandle.bottomLeft ||
      handle == SectionResizeHandle.bottomRight;

  final nextLeft = moveLeft
      ? (rect.x + deltaX).clamp(0, rect.right - 1)
      : rect.x;
  final nextTop = moveTop
      ? (rect.y + deltaY).clamp(0, rect.bottom - 1)
      : rect.y;
  final nextRight = moveRight
      ? (rect.right + deltaX).clamp(rect.x + 1, gridSize)
      : rect.right;
  final nextBottom = moveBottom
      ? (rect.bottom + deltaY).clamp(rect.y + 1, gridSize)
      : rect.bottom;
  return SectionGridRect(
    nextLeft,
    nextTop,
    nextRight - nextLeft,
    nextBottom - nextTop,
  );
}

SectionGridRect resizeAspectLockedGridRect(
  SectionGridRect rect, {
  required SectionResizeHandle handle,
  required int deltaX,
  required int deltaY,
  required double aspectRatio,
  int gridSize = sectionTemplateDetailGridSize,
}) {
  final candidate = resizeSectionGridRect(
    rect,
    handle: handle,
    deltaX: deltaX,
    deltaY: deltaY,
    gridSize: gridSize,
  );
  var width = candidate.width;
  var height = (width / aspectRatio).round().clamp(1, gridSize);
  if ((height - candidate.height).abs() >
      (width - (candidate.height * aspectRatio).round()).abs()) {
    height = candidate.height;
    width = (height * aspectRatio).round().clamp(1, gridSize);
  }
  width = width.clamp(1, gridSize);
  height = height.clamp(1, gridSize);
  final anchorRight =
      handle == SectionResizeHandle.topLeft ||
      handle == SectionResizeHandle.bottomLeft;
  final anchorBottom =
      handle == SectionResizeHandle.topLeft ||
      handle == SectionResizeHandle.topRight;
  final x = anchorRight ? rect.right - width : rect.x;
  final y = anchorBottom ? rect.bottom - height : rect.y;
  if (x < 0 || y < 0 || x + width > gridSize || y + height > gridSize) {
    return rect;
  }
  return SectionGridRect(x, y, width, height);
}

class SectionCanvasElement {
  const SectionCanvasElement({
    required this.id,
    required this.label,
    required this.rect,
    required this.spec,
  });

  final String id;
  final String label;
  final SectionGridRect rect;
  final AttachedSectionSpec spec;

  SectionCanvasElement copyWith({
    String? label,
    SectionGridRect? rect,
    AttachedSectionSpec? spec,
  }) => SectionCanvasElement(
    id: id,
    label: label ?? this.label,
    rect: rect ?? this.rect,
    spec: spec ?? this.spec,
  );
}

class StudioContainerElement {
  const StudioContainerElement({
    required this.id,
    required this.label,
    required this.parentSectionId,
    required this.rect,
    required this.spec,
  });

  final String id;
  final String label;
  final String parentSectionId;
  final SectionGridRect rect;
  final AttachedSectionSpec spec;

  StudioContainerElement copyWith({
    String? label,
    String? parentSectionId,
    SectionGridRect? rect,
    AttachedSectionSpec? spec,
  }) => StudioContainerElement(
    id: id,
    label: label ?? this.label,
    parentSectionId: parentSectionId ?? this.parentSectionId,
    rect: rect ?? this.rect,
    spec: spec ?? this.spec,
  );
}

class StudioFeatureElement {
  const StudioFeatureElement({
    required this.id,
    required this.label,
    required this.parentContainerId,
    required this.rect,
    required this.kind,
    required this.spec,
    this.imageAsset,
    this.aspectRatio,
  });

  final String id;
  final String label;
  final String parentContainerId;
  final SectionGridRect rect;
  final StudioFeatureKind kind;
  final AttachedSectionSpec spec;
  final String? imageAsset;
  final double? aspectRatio;

  StudioFeatureElement copyWith({
    String? label,
    String? parentContainerId,
    SectionGridRect? rect,
    StudioFeatureKind? kind,
    AttachedSectionSpec? spec,
    String? imageAsset,
    double? aspectRatio,
  }) => StudioFeatureElement(
    id: id,
    label: label ?? this.label,
    parentContainerId: parentContainerId ?? this.parentContainerId,
    rect: rect ?? this.rect,
    kind: kind ?? this.kind,
    spec: spec ?? this.spec,
    imageAsset: imageAsset ?? this.imageAsset,
    aspectRatio: aspectRatio ?? this.aspectRatio,
  );
}

List<String> validateSectionCanvas(List<SectionCanvasElement> elements) {
  final issues = <String>[];
  for (final element in elements) {
    final rect = element.rect;
    if (rect.x < 0 ||
        rect.y < 0 ||
        rect.right > sectionTemplateGridSize ||
        rect.bottom > sectionTemplateGridSize) {
      issues.add('${element.label}: 48×48 공간을 벗어남');
    }
  }
  for (var i = 0; i < elements.length; i++) {
    for (var j = i + 1; j < elements.length; j++) {
      if (elements[i].rect.overlaps(elements[j].rect)) {
        issues.add('${elements[i].label} · ${elements[j].label}: 점유 공간 중첩');
      }
    }
  }
  return issues;
}

List<String> validateStudioLayers(
  List<SectionCanvasElement> sections,
  List<StudioContainerElement> containers,
  List<StudioFeatureElement> features,
) {
  final issues = validateSectionCanvas(sections);
  final sectionIds = sections.map((item) => item.id).toSet();
  final containerIds = containers.map((item) => item.id).toSet();
  for (final item in containers) {
    if (!sectionIds.contains(item.parentSectionId)) {
      issues.add('${item.label}: 부모 섹션 없음');
    }
    if (item.rect.x < 0 ||
        item.rect.y < 0 ||
        item.rect.right > sectionTemplateDetailGridSize ||
        item.rect.bottom > sectionTemplateDetailGridSize) {
      issues.add('${item.label}: 부모의 96×96 공간을 벗어남');
    }
  }
  for (final item in features) {
    if (!containerIds.contains(item.parentContainerId)) {
      issues.add('${item.label}: 부모 컨테이너 없음');
    }
    if (item.rect.x < 0 ||
        item.rect.y < 0 ||
        item.rect.right > sectionTemplateDetailGridSize ||
        item.rect.bottom > sectionTemplateDetailGridSize) {
      issues.add('${item.label}: 부모의 96×96 공간을 벗어남');
    }
    if (item.kind == StudioFeatureKind.image &&
        (item.aspectRatio == null || item.aspectRatio! <= 0)) {
      issues.add('${item.label}: 이미지 비율 없음');
    }
  }
  return issues;
}
