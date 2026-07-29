const sectionTemplateMajorDivisions = 12;
const sectionTemplateSubdivisionsPerMajor = 8;
const sectionTemplateGridSize =
    sectionTemplateMajorDivisions * sectionTemplateSubdivisionsPerMajor;
const sectionTemplateSectionGap = 1;
const sectionTemplateDetailGridSize = sectionTemplateGridSize;
const studioDefaultPlacementGap = 0.02;
const studioPlacementSnapTolerance = 0.012;
const studioMinimumPlacementExtent = 0.01;

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
  image('이미지'),
  text('텍스트'),
  line('선');

  const StudioFeatureKind(this.label);
  final String label;
}

const studioSquareAssetPath = 'assets/studio_features/square.png';
const studioSquareAspectRatio = 252 / 172;
const studioTitleAssetPath = 'assets/studio_features/plan_a_title.png';
const studioTitleAspectRatio = 863 / 250;
const studioRoundedArrowAssetId = 'builtin:rounded-arrow-left';

enum StudioImagePreset {
  square('기본 이미지', studioSquareAssetPath, studioSquareAspectRatio),
  title('Plan A 타이틀', studioTitleAssetPath, studioTitleAspectRatio),
  roundedArrow('둥근 뒤로 화살표', studioRoundedArrowAssetId, 1);

  const StudioImagePreset(this.label, this.asset, this.aspectRatio);

  final String label;
  final String asset;
  final double aspectRatio;
}

StudioImagePreset studioImagePresetForAsset(String? asset) =>
    StudioImagePreset.values.firstWhere(
      (item) => item.asset == asset,
      orElse: () => StudioImagePreset.square,
    );

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

class StudioPlacementRect {
  const StudioPlacementRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool overlaps(StudioPlacementRect other) =>
      left < other.right &&
      right > other.left &&
      top < other.bottom &&
      bottom > other.top;

  StudioPlacementRect copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) => copyPlacementRectWithin(
    this,
    left: left,
    top: top,
    width: width,
    height: height,
  );

  factory StudioPlacementRect.fromGrid(SectionGridRect rect) =>
      StudioPlacementRect(
        rect.x / sectionTemplateDetailGridSize,
        rect.y / sectionTemplateDetailGridSize,
        rect.width / sectionTemplateDetailGridSize,
        rect.height / sectionTemplateDetailGridSize,
      );
}

StudioPlacementRect copyPlacementRectWithin(
  StudioPlacementRect rect, {
  double? left,
  double? top,
  double? width,
  double? height,
}) {
  final nextLeft = (left ?? rect.left).clamp(
    0.0,
    1.0 - studioMinimumPlacementExtent,
  );
  final nextTop = (top ?? rect.top).clamp(
    0.0,
    1.0 - studioMinimumPlacementExtent,
  );
  return StudioPlacementRect(
    nextLeft,
    nextTop,
    (width ?? rect.width).clamp(studioMinimumPlacementExtent, 1.0 - nextLeft),
    (height ?? rect.height).clamp(studioMinimumPlacementExtent, 1.0 - nextTop),
  );
}

StudioPlacementRect moveStudioPlacementRect(
  StudioPlacementRect rect, {
  required double deltaX,
  required double deltaY,
}) => StudioPlacementRect(
  (rect.left + deltaX).clamp(0.0, 1.0 - rect.width),
  (rect.top + deltaY).clamp(0.0, 1.0 - rect.height),
  rect.width,
  rect.height,
);

StudioPlacementRect resizeStudioPlacementRect(
  StudioPlacementRect rect, {
  required SectionResizeHandle handle,
  required double deltaX,
  required double deltaY,
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
      ? (rect.left + deltaX).clamp(
          0.0,
          rect.right - studioMinimumPlacementExtent,
        )
      : rect.left;
  final nextTop = moveTop
      ? (rect.top + deltaY).clamp(
          0.0,
          rect.bottom - studioMinimumPlacementExtent,
        )
      : rect.top;
  final nextRight = moveRight
      ? (rect.right + deltaX).clamp(
          rect.left + studioMinimumPlacementExtent,
          1.0,
        )
      : rect.right;
  final nextBottom = moveBottom
      ? (rect.bottom + deltaY).clamp(
          rect.top + studioMinimumPlacementExtent,
          1.0,
        )
      : rect.bottom;
  return StudioPlacementRect(
    nextLeft,
    nextTop,
    nextRight - nextLeft,
    nextBottom - nextTop,
  );
}

StudioPlacementRect resizeAspectLockedPlacementRect(
  StudioPlacementRect rect, {
  required SectionResizeHandle handle,
  required double deltaX,
  required double deltaY,
  required double aspectRatio,
  required double parentAspectRatio,
}) {
  final candidate = resizeStudioPlacementRect(
    rect,
    handle: handle,
    deltaX: deltaX,
    deltaY: deltaY,
  );
  var width = candidate.width;
  var height = width * parentAspectRatio / aspectRatio;
  if ((height - candidate.height).abs() >
      (width - candidate.height * aspectRatio / parentAspectRatio).abs()) {
    height = candidate.height;
    width = height * aspectRatio / parentAspectRatio;
  }
  width = width.clamp(studioMinimumPlacementExtent, 1.0);
  height = height.clamp(studioMinimumPlacementExtent, 1.0);
  final anchorRight =
      handle == SectionResizeHandle.topLeft ||
      handle == SectionResizeHandle.bottomLeft;
  final anchorBottom =
      handle == SectionResizeHandle.topLeft ||
      handle == SectionResizeHandle.topRight;
  final left = anchorRight ? rect.right - width : rect.left;
  final top = anchorBottom ? rect.bottom - height : rect.top;
  if (left < 0 || top < 0 || left + width > 1 || top + height > 1) {
    return rect;
  }
  return StudioPlacementRect(left, top, width, height);
}

StudioPlacementRect snapStudioPlacementSpacing(
  StudioPlacementRect rect, {
  required Iterable<StudioPlacementRect> siblings,
  double gap = studioDefaultPlacementGap,
  double tolerance = studioPlacementSnapTolerance,
}) {
  final xTargets = <double>[gap, 1 - gap - rect.width];
  final yTargets = <double>[gap, 1 - gap - rect.height];
  for (final sibling in siblings) {
    if (rect.top < sibling.bottom && rect.bottom > sibling.top) {
      xTargets
        ..add(sibling.right + gap)
        ..add(sibling.left - gap - rect.width);
    }
    if (rect.left < sibling.right && rect.right > sibling.left) {
      yTargets
        ..add(sibling.bottom + gap)
        ..add(sibling.top - gap - rect.height);
    }
  }
  double nearest(double value, Iterable<double> targets) {
    var result = value;
    var distance = tolerance;
    for (final target in targets) {
      if (target < 0 || target > 1) continue;
      final nextDistance = (value - target).abs();
      if (nextDistance <= distance) {
        result = target;
        distance = nextDistance;
      }
    }
    return result;
  }

  return moveStudioPlacementRect(
    rect.copyWith(left: 0, top: 0),
    deltaX: nearest(rect.left, xTargets),
    deltaY: nearest(rect.top, yTargets),
  );
}

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
    this.triangleTexture = false,
  });

  final String id;
  final String label;
  final String parentSectionId;
  final StudioPlacementRect rect;
  final AttachedSectionSpec spec;
  final bool triangleTexture;

  StudioContainerElement copyWith({
    String? label,
    String? parentSectionId,
    StudioPlacementRect? rect,
    AttachedSectionSpec? spec,
    bool? triangleTexture,
  }) => StudioContainerElement(
    id: id,
    label: label ?? this.label,
    parentSectionId: parentSectionId ?? this.parentSectionId,
    rect: rect ?? this.rect,
    spec: spec ?? this.spec,
    triangleTexture: triangleTexture ?? this.triangleTexture,
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
    this.text,
  });

  final String id;
  final String label;
  final String parentContainerId;
  final StudioPlacementRect rect;
  final StudioFeatureKind kind;
  final AttachedSectionSpec spec;
  final String? imageAsset;
  final double? aspectRatio;
  final String? text;

  StudioFeatureElement copyWith({
    String? label,
    String? parentContainerId,
    StudioPlacementRect? rect,
    StudioFeatureKind? kind,
    AttachedSectionSpec? spec,
    String? imageAsset,
    double? aspectRatio,
    String? text,
  }) => StudioFeatureElement(
    id: id,
    label: label ?? this.label,
    parentContainerId: parentContainerId ?? this.parentContainerId,
    rect: rect ?? this.rect,
    kind: kind ?? this.kind,
    spec: spec ?? this.spec,
    imageAsset: imageAsset ?? this.imageAsset,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    text: text ?? this.text,
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
      issues.add('${element.label}: 작업화면의 96×96 공간을 벗어남');
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
    if (item.rect.left < 0 ||
        item.rect.top < 0 ||
        item.rect.right > 1 ||
        item.rect.bottom > 1) {
      issues.add('${item.label}: 부모 섹션의 배치 영역을 벗어남');
    }
  }
  for (final item in features) {
    if (!containerIds.contains(item.parentContainerId)) {
      issues.add('${item.label}: 부모 컨테이너 없음');
    }
    if (item.rect.left < 0 ||
        item.rect.top < 0 ||
        item.rect.right > 1 ||
        item.rect.bottom > 1) {
      issues.add('${item.label}: 부모 컨테이너의 배치 영역을 벗어남');
    }
    if (item.kind == StudioFeatureKind.image &&
        (item.aspectRatio == null || item.aspectRatio! <= 0)) {
      issues.add('${item.label}: 이미지 비율 없음');
    }
    if (item.kind == StudioFeatureKind.text &&
        (item.text == null || item.text!.trim().isEmpty)) {
      issues.add('${item.label}: 텍스트 내용 없음');
    }
  }
  return issues;
}
