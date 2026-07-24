import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../studio/section_template.dart';

class AttachedSectionTemplateSurface extends StatelessWidget {
  const AttachedSectionTemplateSurface({
    super.key,
    required this.spec,
    required this.child,
    this.selected = false,
    this.showFaceGrid = true,
  });

  final AttachedSectionSpec spec;
  final Widget child;
  final bool selected;
  final bool showFaceGrid;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _AttachedSectionPainter(
      spec: spec,
      selected: selected,
      showFaceGrid: showFaceGrid,
    ),
    child: ClipPath(
      clipper: AttachedSectionClipper(spec),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: selected
              ? AppColors.primaryMuted.withValues(alpha: 0.78)
              : AppColors.surface.withValues(alpha: 0.88),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    ),
  );
}

class AttachedSectionClipper extends CustomClipper<Path> {
  const AttachedSectionClipper(this.spec);

  final AttachedSectionSpec spec;

  @override
  Path getClip(Size size) => buildAttachedSectionPath(size, spec);

  @override
  bool shouldReclip(AttachedSectionClipper oldDelegate) =>
      oldDelegate.spec != spec;
}

Path buildAttachedSectionPath(Size size, AttachedSectionSpec spec) {
  final points = buildAttachedSectionPolygon(size, spec);
  final raw = buildRoundedSectionPolygon(points);
  final roundedBounds = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
    );
  return Path.combine(PathOperation.intersect, raw, roundedBounds);
}

List<Offset> buildAttachedSectionPolygon(
  Size size,
  AttachedSectionSpec spec, {
  int gridSize = sectionTemplateGridSize,
}) {
  final horizontalFace =
      spec.face == SectionAttachmentFace.top ||
      spec.face == SectionAttachmentFace.bottom;
  final faceExtent = horizontalFace ? size.width : size.height;
  final faceStart = faceExtent * spec.faceStart / gridSize;
  final faceEnd = faceExtent * spec.faceEnd / gridSize;
  final perpendicularExtent = horizontalFace ? size.height : size.width;
  final requestedDepth = perpendicularExtent * spec.height / gridSize;
  final span = faceEnd - faceStart;
  return switch ((spec.mode, spec.face)) {
    (SectionShapeMode.triangle, SectionAttachmentFace.left) => <Offset>[
      Offset(0, faceStart),
      Offset(sectionTemplateCutDepth(span), faceStart),
      Offset(0, faceEnd),
    ],
    (SectionShapeMode.triangle, SectionAttachmentFace.right) => <Offset>[
      Offset(size.width, faceStart),
      Offset(size.width, faceEnd),
      Offset(size.width - sectionTemplateCutDepth(span), faceEnd),
    ],
    (SectionShapeMode.triangle, SectionAttachmentFace.top) => <Offset>[
      Offset(faceStart, 0),
      Offset(faceEnd, 0),
      Offset(faceStart, span * math.tan(80 * math.pi / 180)),
    ],
    (SectionShapeMode.triangle, SectionAttachmentFace.bottom) => <Offset>[
      Offset(faceStart, size.height),
      Offset(faceEnd, size.height),
      Offset(faceEnd, size.height - span * math.tan(80 * math.pi / 180)),
    ],
    (SectionShapeMode.trapezoid, SectionAttachmentFace.left) => <Offset>[
      Offset(0, faceStart),
      Offset(requestedDepth, faceStart),
      Offset(requestedDepth - sectionTemplateCutDepth(span), faceEnd),
      Offset(0, faceEnd),
    ],
    (SectionShapeMode.trapezoid, SectionAttachmentFace.right) => <Offset>[
      Offset(size.width, faceStart),
      Offset(size.width, faceEnd),
      Offset(size.width - requestedDepth, faceEnd),
      Offset(
        size.width - requestedDepth + sectionTemplateCutDepth(span),
        faceStart,
      ),
    ],
    (SectionShapeMode.trapezoid, SectionAttachmentFace.top) => <Offset>[
      Offset(faceStart, 0),
      Offset(faceEnd, 0),
      Offset(faceEnd - sectionTemplateCutDepth(requestedDepth), requestedDepth),
      Offset(faceStart, requestedDepth),
    ],
    (SectionShapeMode.trapezoid, SectionAttachmentFace.bottom) => <Offset>[
      Offset(
        faceStart + sectionTemplateCutDepth(requestedDepth),
        size.height - requestedDepth,
      ),
      Offset(faceEnd, size.height - requestedDepth),
      Offset(faceEnd, size.height),
      Offset(faceStart, size.height),
    ],
    (SectionShapeMode.parallelogram, SectionAttachmentFace.top) => <Offset>[
      Offset(faceStart, 0),
      Offset(faceEnd, 0),
      Offset(faceEnd - sectionTemplateCutDepth(requestedDepth), requestedDepth),
      Offset(
        faceStart - sectionTemplateCutDepth(requestedDepth),
        requestedDepth,
      ),
    ],
    (SectionShapeMode.parallelogram, SectionAttachmentFace.bottom) => <Offset>[
      Offset(
        faceStart + sectionTemplateCutDepth(requestedDepth),
        size.height - requestedDepth,
      ),
      Offset(
        faceEnd + sectionTemplateCutDepth(requestedDepth),
        size.height - requestedDepth,
      ),
      Offset(faceEnd, size.height),
      Offset(faceStart, size.height),
    ],
    (SectionShapeMode.parallelogram, SectionAttachmentFace.left) =>
      _sideParallelogramPoints(size, spec, faceStart, faceEnd, requestedDepth),
    (SectionShapeMode.parallelogram, SectionAttachmentFace.right) =>
      _sideParallelogramPoints(size, spec, faceStart, faceEnd, -requestedDepth),
  };
}

Rect sectionCanvasElementRect(Size size, SectionCanvasElement element) =>
    Rect.fromLTWH(
      size.width * element.rect.x / sectionTemplateGridSize,
      size.height * element.rect.y / sectionTemplateGridSize,
      size.width * element.rect.width / sectionTemplateGridSize,
      size.height * element.rect.height / sectionTemplateGridSize,
    );

const sectionCanvasHandleRadius = 7.0;
const sectionCanvasHandleHitRadius = 14.0;

Map<SectionResizeHandle, Offset> sectionCanvasResizeHandleCenters(
  Size size,
  SectionCanvasElement element,
) {
  final rect = sectionCanvasElementRect(size, element);
  return {
    SectionResizeHandle.topLeft: rect.topLeft,
    SectionResizeHandle.topRight: rect.topRight,
    SectionResizeHandle.bottomLeft: rect.bottomLeft,
    SectionResizeHandle.bottomRight: rect.bottomRight,
  };
}

SectionResizeHandle? hitTestSectionResizeHandle(
  Size size,
  SectionCanvasElement element,
  Offset position,
) {
  for (final entry in sectionCanvasResizeHandleCenters(size, element).entries) {
    if ((entry.value - position).distance <= sectionCanvasHandleHitRadius) {
      return entry.key;
    }
  }
  return null;
}

Path buildSectionCanvasElementPath(Size size, SectionCanvasElement element) {
  final elementRect = sectionCanvasElementRect(size, element);
  final points = buildAttachedSectionPolygon(
    elementRect.size,
    element.spec,
  ).map((point) => point + elementRect.topLeft).toList(growable: false);
  final raw = buildRoundedSectionPolygon(points);
  final canvasBounds = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
    );
  return Path.combine(PathOperation.intersect, raw, canvasBounds);
}

String? hitTestSectionCanvasElement(
  Size size,
  List<SectionCanvasElement> elements,
  Offset position,
) {
  for (final element in elements.reversed) {
    if (buildSectionCanvasElementPath(size, element).contains(position)) {
      return element.id;
    }
  }
  return null;
}

class SectionCanvasPainter extends CustomPainter {
  const SectionCanvasPainter({
    required this.elements,
    required this.selectedElementId,
    required this.showGrid,
    required this.showSafeArea,
  });

  final List<SectionCanvasElement> elements;
  final String selectedElementId;
  final bool showGrid;
  final bool showSafeArea;

  @override
  void paint(Canvas canvas, Size size) {
    for (final element in elements) {
      final selected = element.id == selectedElementId;
      final path = buildSectionCanvasElementPath(size, element);
      canvas.drawPath(
        path,
        Paint()
          ..color = selected
              ? AppColors.primaryMuted.withValues(alpha: 0.88)
              : AppColors.surface.withValues(alpha: 0.92),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.5 : 1
          ..color = selected ? AppColors.primary : AppColors.outline,
      );
      if (showSafeArea) _paintSafeArea(canvas, path);
      if (selected && showGrid) _paintAttachmentFace(canvas, size, element);
      _paintElementLabel(canvas, path, element);
      if (selected) _paintSelectionFrame(canvas, size, element);
    }
  }

  void _paintSafeArea(Canvas canvas, Path path) {
    final bounds = path.getBounds().deflate(12);
    if (bounds.width <= 0 || bounds.height <= 0) return;
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.warning.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  void _paintAttachmentFace(
    Canvas canvas,
    Size size,
    SectionCanvasElement element,
  ) {
    final bounds = sectionCanvasElementRect(size, element);
    final (start, end) = switch (element.spec.face) {
      SectionAttachmentFace.left => (bounds.topLeft, bounds.bottomLeft),
      SectionAttachmentFace.right => (bounds.topRight, bounds.bottomRight),
      SectionAttachmentFace.top => (bounds.topLeft, bounds.topRight),
      SectionAttachmentFace.bottom => (bounds.bottomLeft, bounds.bottomRight),
    };
    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.72)
      ..strokeWidth = 1;
    canvas.drawLine(start, end, paint);
    for (var index = 0; index <= sectionTemplateGridSize; index++) {
      final point = Offset.lerp(start, end, index / sectionTemplateGridSize)!;
      final major = index % sectionTemplateSubdivisionsPerMajor == 0;
      final tickLength = major ? 6.0 : 3.0;
      final tick =
          element.spec.face == SectionAttachmentFace.left ||
              element.spec.face == SectionAttachmentFace.right
          ? Offset(tickLength, 0)
          : Offset(0, tickLength);
      canvas.drawLine(point - tick, point + tick, paint);
    }
    canvas.drawLine(
      Offset.lerp(
        start,
        end,
        element.spec.faceStart / sectionTemplateGridSize,
      )!,
      Offset.lerp(start, end, element.spec.faceEnd / sectionTemplateGridSize)!,
      Paint()
        ..color = AppColors.warning
        ..strokeWidth = 3,
    );
  }

  void _paintElementLabel(
    Canvas canvas,
    Path path,
    SectionCanvasElement element,
  ) {
    final bounds = path.getBounds();
    if (bounds.width < 56 || bounds.height < 34) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${element.label}\n${element.rect.width}×${element.rect.height}',
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: bounds.width - 16);
    canvas.save();
    canvas.clipPath(path);
    textPainter.paint(
      canvas,
      bounds.center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
    canvas.restore();
  }

  void _paintSelectionFrame(
    Canvas canvas,
    Size size,
    SectionCanvasElement element,
  ) {
    final bounds = sectionCanvasElementRect(size, element);
    canvas.drawRect(
      bounds,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = AppColors.primary.withValues(alpha: 0.72),
    );
    final centers = sectionCanvasResizeHandleCenters(size, element);
    for (final center in centers.values) {
      canvas.drawCircle(
        center,
        sectionCanvasHandleRadius + 1.5,
        Paint()..color = AppColors.navigation,
      );
      canvas.drawCircle(
        center,
        sectionCanvasHandleRadius,
        Paint()..color = AppColors.primary,
      );
      canvas.drawCircle(
        center,
        sectionCanvasHandleRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.text,
      );
    }
  }

  @override
  bool shouldRepaint(SectionCanvasPainter oldDelegate) =>
      oldDelegate.elements != elements ||
      oldDelegate.selectedElementId != selectedElementId ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.showSafeArea != showSafeArea;
}

Rect studioGridRectWithin(
  Rect parent,
  SectionGridRect rect, {
  int gridSize = sectionTemplateDetailGridSize,
}) => Rect.fromLTWH(
  parent.left + parent.width * rect.x / gridSize,
  parent.top + parent.height * rect.y / gridSize,
  parent.width * rect.width / gridSize,
  parent.height * rect.height / gridSize,
);

SectionCanvasElement? _sectionById(
  List<SectionCanvasElement> sections,
  String id,
) {
  for (final section in sections) {
    if (section.id == id) return section;
  }
  return null;
}

StudioContainerElement? _containerById(
  List<StudioContainerElement> containers,
  String id,
) {
  for (final container in containers) {
    if (container.id == id) return container;
  }
  return null;
}

Rect? studioContainerRect(
  Size size,
  List<SectionCanvasElement> sections,
  StudioContainerElement container,
) {
  final parent = _sectionById(sections, container.parentSectionId);
  if (parent == null) return null;
  return studioGridRectWithin(
    sectionCanvasElementRect(size, parent),
    container.rect,
  );
}

Path? buildStudioContainerPath(
  Size size,
  List<SectionCanvasElement> sections,
  StudioContainerElement container,
) {
  final parent = _sectionById(sections, container.parentSectionId);
  final rect = studioContainerRect(size, sections, container);
  if (parent == null || rect == null) return null;
  final points = buildAttachedSectionPolygon(
    rect.size,
    container.spec,
    gridSize: sectionTemplateDetailGridSize,
  ).map((point) => point + rect.topLeft).toList(growable: false);
  return Path.combine(
    PathOperation.intersect,
    buildRoundedSectionPolygon(points, radius: 10),
    buildSectionCanvasElementPath(size, parent),
  );
}

Rect? studioFeatureRect(
  Size size,
  List<SectionCanvasElement> sections,
  List<StudioContainerElement> containers,
  StudioFeatureElement feature,
) {
  final parent = _containerById(containers, feature.parentContainerId);
  if (parent == null) return null;
  final parentRect = studioContainerRect(size, sections, parent);
  if (parentRect == null) return null;
  return studioGridRectWithin(parentRect, feature.rect);
}

Path? buildStudioFeaturePath(
  Size size,
  List<SectionCanvasElement> sections,
  List<StudioContainerElement> containers,
  StudioFeatureElement feature,
) {
  final parent = _containerById(containers, feature.parentContainerId);
  final rect = studioFeatureRect(size, sections, containers, feature);
  if (parent == null || rect == null) return null;
  final raw = feature.kind == StudioFeatureKind.image
      ? (Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8))))
      : buildRoundedSectionPolygon(
          buildAttachedSectionPolygon(
            rect.size,
            feature.spec,
            gridSize: sectionTemplateDetailGridSize,
          ).map((point) => point + rect.topLeft).toList(growable: false),
          radius: 8,
        );
  final parentPath = buildStudioContainerPath(size, sections, parent);
  return parentPath == null
      ? null
      : Path.combine(PathOperation.intersect, raw, parentPath);
}

Map<SectionResizeHandle, Offset> studioRectHandleCenters(Rect rect) => {
  SectionResizeHandle.topLeft: rect.topLeft,
  SectionResizeHandle.topRight: rect.topRight,
  SectionResizeHandle.bottomLeft: rect.bottomLeft,
  SectionResizeHandle.bottomRight: rect.bottomRight,
};

SectionResizeHandle? hitTestStudioRectHandle(Rect rect, Offset position) {
  for (final entry in studioRectHandleCenters(rect).entries) {
    if ((entry.value - position).distance <= sectionCanvasHandleHitRadius) {
      return entry.key;
    }
  }
  return null;
}

String? hitTestStudioContainer(
  Size size,
  List<SectionCanvasElement> sections,
  List<StudioContainerElement> containers,
  Offset position,
) {
  for (final container in containers.reversed) {
    if (buildStudioContainerPath(
          size,
          sections,
          container,
        )?.contains(position) ??
        false) {
      return container.id;
    }
  }
  return null;
}

String? hitTestStudioFeature(
  Size size,
  List<SectionCanvasElement> sections,
  List<StudioContainerElement> containers,
  List<StudioFeatureElement> features,
  Offset position,
) {
  for (final feature in features.reversed) {
    if (buildStudioFeaturePath(
          size,
          sections,
          containers,
          feature,
        )?.contains(position) ??
        false) {
      return feature.id;
    }
  }
  return null;
}

class LayeredStudioPainter extends CustomPainter {
  const LayeredStudioPainter({
    required this.sections,
    required this.containers,
    required this.features,
    required this.activeLayer,
    required this.selectedSectionId,
    required this.selectedContainerId,
    required this.selectedFeatureId,
    required this.showGrid,
    required this.showSafeArea,
    this.squareImage,
  });

  final List<SectionCanvasElement> sections;
  final List<StudioContainerElement> containers;
  final List<StudioFeatureElement> features;
  final StudioLayer activeLayer;
  final String selectedSectionId;
  final String? selectedContainerId;
  final String? selectedFeatureId;
  final bool showGrid;
  final bool showSafeArea;
  final ui.Image? squareImage;

  @override
  void paint(Canvas canvas, Size size) {
    SectionCanvasPainter(
      elements: sections,
      selectedElementId: activeLayer == StudioLayer.section
          ? selectedSectionId
          : '',
      showGrid: showGrid && activeLayer == StudioLayer.section,
      showSafeArea: showSafeArea,
    ).paint(canvas, size);

    if (showGrid && activeLayer == StudioLayer.container) {
      final section = _sectionById(sections, selectedSectionId);
      if (section != null) {
        _paintDetailGrid(canvas, sectionCanvasElementRect(size, section));
      }
    } else if (showGrid && activeLayer == StudioLayer.feature) {
      final container = selectedContainerId == null
          ? null
          : _containerById(containers, selectedContainerId!);
      if (container != null) {
        final rect = studioContainerRect(size, sections, container);
        if (rect != null) _paintDetailGrid(canvas, rect);
      }
    }

    for (final container in containers) {
      final path = buildStudioContainerPath(size, sections, container);
      if (path == null) continue;
      final selected =
          activeLayer == StudioLayer.container &&
          container.id == selectedContainerId;
      canvas.drawPath(
        path,
        Paint()
          ..color = selected
              ? AppColors.success.withValues(alpha: 0.34)
              : AppColors.surfaceRaised.withValues(alpha: 0.58),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.2 : 1
          ..color = selected ? AppColors.success : AppColors.outline,
      );
      if (selected) {
        final rect = studioContainerRect(size, sections, container);
        if (rect != null) _paintLayerSelection(canvas, rect, AppColors.success);
      }
    }

    for (final feature in features) {
      final path = buildStudioFeaturePath(size, sections, containers, feature);
      final rect = studioFeatureRect(size, sections, containers, feature);
      if (path == null || rect == null) continue;
      final selected =
          activeLayer == StudioLayer.feature && feature.id == selectedFeatureId;
      if (feature.kind == StudioFeatureKind.image && squareImage != null) {
        canvas.save();
        canvas.clipPath(path);
        paintImage(
          canvas: canvas,
          rect: rect,
          image: squareImage!,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
        canvas.restore();
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..color = selected
                ? AppColors.warning.withValues(alpha: 0.58)
                : AppColors.primaryMuted.withValues(alpha: 0.66),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.2 : 1
          ..color = selected ? AppColors.warning : AppColors.primary,
      );
      if (selected) _paintLayerSelection(canvas, rect, AppColors.warning);
    }
  }

  void _paintDetailGrid(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.18)
      ..strokeWidth = 0.45;
    for (var index = 1; index < sectionTemplateDetailGridSize; index++) {
      final x = rect.left + rect.width * index / sectionTemplateDetailGridSize;
      final y = rect.top + rect.height * index / sectionTemplateDetailGridSize;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  void _paintLayerSelection(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.8),
    );
    for (final center in studioRectHandleCenters(rect).values) {
      canvas.drawCircle(
        center,
        sectionCanvasHandleRadius + 1.5,
        Paint()..color = AppColors.navigation,
      );
      canvas.drawCircle(
        center,
        sectionCanvasHandleRadius,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(LayeredStudioPainter oldDelegate) =>
      oldDelegate.sections != sections ||
      oldDelegate.containers != containers ||
      oldDelegate.features != features ||
      oldDelegate.activeLayer != activeLayer ||
      oldDelegate.selectedSectionId != selectedSectionId ||
      oldDelegate.selectedContainerId != selectedContainerId ||
      oldDelegate.selectedFeatureId != selectedFeatureId ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.showSafeArea != showSafeArea ||
      oldDelegate.squareImage != squareImage;
}

Path buildRoundedSectionPolygon(List<Offset> points, {double radius = 14}) {
  if (points.length < 3) return Path()..addPolygon(points, true);
  final entries = <({Offset start, Offset end, double radius})>[];
  for (var index = 0; index < points.length; index++) {
    final previous = points[(index - 1 + points.length) % points.length];
    final current = points[index];
    final next = points[(index + 1) % points.length];
    final towardPrevious = previous - current;
    final towardNext = next - current;
    final previousLength = towardPrevious.distance;
    final nextLength = towardNext.distance;
    if (previousLength == 0 || nextLength == 0) {
      entries.add((start: current, end: current, radius: 0));
      continue;
    }
    final previousUnit = towardPrevious / previousLength;
    final nextUnit = towardNext / nextLength;
    final cosine =
        (previousUnit.dx * nextUnit.dx + previousUnit.dy * nextUnit.dy)
            .clamp(-1.0, 1.0)
            .toDouble();
    final cornerAngle = math.acos(cosine);
    final halfAngleTangent = math.tan(cornerAngle / 2).abs();
    final requestedCut = halfAngleTangent < 1e-6
        ? double.infinity
        : radius / halfAngleTangent;
    // Keep more of each straight edge visible before an acute corner starts to
    // turn. The circular fillet below still removes substantially more of the
    // sharp tip than the former quadratic curve through the original vertex.
    final availableCut = math.min(previousLength, nextLength) * 0.36;
    final cut = math.min(requestedCut, availableCut);
    entries.add((
      start: current + towardPrevious / previousLength * cut,
      end: current + towardNext / nextLength * cut,
      radius: cut * halfAngleTangent,
    ));
  }

  var twiceSignedArea = 0.0;
  for (var index = 0; index < points.length; index++) {
    final current = points[index];
    final next = points[(index + 1) % points.length];
    twiceSignedArea += current.dx * next.dy - current.dy * next.dx;
  }
  // Follow the polygon winding so arcToPoint chooses the convex fillet. Using
  // the opposite sweep selects the other circle center and carves a concave
  // notch into the surface.
  final clockwise = twiceSignedArea > 0;
  final path = Path()..moveTo(entries.first.start.dx, entries.first.start.dy);
  for (var index = 0; index < points.length; index++) {
    final entry = entries[index];
    if (index > 0) path.lineTo(entry.start.dx, entry.start.dy);
    if (entry.radius <= 1e-6) {
      path.lineTo(entry.end.dx, entry.end.dy);
    } else {
      path.arcToPoint(
        entry.end,
        radius: Radius.circular(entry.radius),
        clockwise: clockwise,
      );
    }
  }
  return path
    ..lineTo(entries.first.start.dx, entries.first.start.dy)
    ..close();
}

List<Offset> _sideParallelogramPoints(
  Size size,
  AttachedSectionSpec spec,
  double faceStart,
  double faceEnd,
  double signedDepth,
) {
  final isLeft = spec.face == SectionAttachmentFace.left;
  final depth = signedDepth.abs();
  final rise = depth * math.tan(80 * math.pi / 180);
  if (isLeft) {
    final attachedTop = Offset(0, faceStart);
    final attachedBottom = Offset(0, faceEnd);
    return [
      attachedTop,
      Offset(depth, faceStart - rise),
      Offset(depth, faceEnd - rise),
      attachedBottom,
    ];
  }
  final attachedTop = Offset(size.width, faceStart);
  final attachedBottom = Offset(size.width, faceEnd);
  return [
    attachedTop,
    attachedBottom,
    Offset(size.width - depth, faceEnd + rise),
    Offset(size.width - depth, faceStart + rise),
  ];
}

class _AttachedSectionPainter extends CustomPainter {
  const _AttachedSectionPainter({
    required this.spec,
    required this.selected,
    required this.showFaceGrid,
  });

  final AttachedSectionSpec spec;
  final bool selected;
  final bool showFaceGrid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      buildAttachedSectionPath(size, spec),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1
        ..color = selected ? AppColors.primary : AppColors.outline,
    );
    if (!showFaceGrid) return;
    final (start, end) = switch (spec.face) {
      SectionAttachmentFace.left => (Offset.zero, Offset(0, size.height)),
      SectionAttachmentFace.right => (
        Offset(size.width, 0),
        Offset(size.width, size.height),
      ),
      SectionAttachmentFace.top => (Offset.zero, Offset(size.width, 0)),
      SectionAttachmentFace.bottom => (
        Offset(0, size.height),
        Offset(size.width, size.height),
      ),
    };
    final gridPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    canvas.drawLine(start, end, gridPaint);
    for (var index = 0; index <= sectionTemplateGridSize; index++) {
      final t = index / sectionTemplateGridSize;
      final point = Offset.lerp(start, end, t)!;
      final major = index % sectionTemplateSubdivisionsPerMajor == 0;
      final tickLength = major ? 7.0 : 3.5;
      final tick =
          spec.face == SectionAttachmentFace.left ||
              spec.face == SectionAttachmentFace.right
          ? Offset(tickLength, 0)
          : Offset(0, tickLength);
      canvas.drawLine(point - tick, point + tick, gridPaint);
    }
    final selectedStart = Offset.lerp(
      start,
      end,
      spec.faceStart / sectionTemplateGridSize,
    )!;
    final selectedEnd = Offset.lerp(
      start,
      end,
      spec.faceEnd / sectionTemplateGridSize,
    )!;
    canvas.drawLine(
      selectedStart,
      selectedEnd,
      Paint()
        ..color = AppColors.warning
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_AttachedSectionPainter oldDelegate) =>
      oldDelegate.spec != spec ||
      oldDelegate.selected != selected ||
      oldDelegate.showFaceGrid != showFaceGrid;
}

class SectionTemplateSurface extends StatelessWidget {
  const SectionTemplateSurface({
    super.key,
    required this.shape,
    required this.child,
    this.selected = false,
  });

  final SectionShape shape;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SectionTemplateBorderPainter(shape: shape, selected: selected),
    child: ClipPath(
      clipper: SectionTemplateClipper(shape),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: selected
              ? AppColors.primaryMuted.withValues(alpha: 0.78)
              : AppColors.surface.withValues(alpha: 0.88),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    ),
  );
}

class SectionTemplateClipper extends CustomClipper<Path> {
  const SectionTemplateClipper(this.shape);

  final SectionShape shape;

  @override
  Path getClip(Size size) => buildSectionTemplatePath(size, shape);

  @override
  bool shouldReclip(SectionTemplateClipper oldDelegate) =>
      oldDelegate.shape != shape;
}

Path buildSectionTemplatePath(Size size, SectionShape shape) {
  final horizontalCut = sectionTemplateCutDepth(size.height);
  final polygon = switch (shape) {
    SectionShape.rightCut => <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(size.width - horizontalCut, size.height),
      Offset(0, size.height),
    ],
    SectionShape.leftCut => <Offset>[
      Offset(horizontalCut, 0),
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset.zero.translate(0, size.height),
    ],
    SectionShape.bilateral => <Offset>[
      Offset(horizontalCut, 0),
      Offset(size.width, 0),
      Offset(size.width - horizontalCut, size.height),
      Offset.zero.translate(0, size.height),
    ],
    SectionShape.triangleLeft => <Offset>[
      Offset.zero,
      Offset(horizontalCut, 0),
      Offset(0, size.height),
    ],
    SectionShape.triangleRight => <Offset>[
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(size.width - horizontalCut, size.height),
    ],
  };
  final raw = buildRoundedSectionPolygon(polygon);
  final roundedBounds = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
    );
  return Path.combine(PathOperation.intersect, raw, roundedBounds);
}

double sectionTemplateCutDepth(double height) =>
    height / math.tan(80 * math.pi / 180);

class _SectionTemplateBorderPainter extends CustomPainter {
  const _SectionTemplateBorderPainter({
    required this.shape,
    required this.selected,
  });

  final SectionShape shape;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      buildSectionTemplatePath(size, shape),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1
        ..color = selected ? AppColors.primary : AppColors.outline,
    );
  }

  @override
  bool shouldRepaint(_SectionTemplateBorderPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.selected != selected;
}
