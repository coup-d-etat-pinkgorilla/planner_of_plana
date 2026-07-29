import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';

@immutable
class AssetImageGridItem {
  const AssetImageGridItem({
    required this.asset,
    required this.column,
    required this.row,
    this.columnSpan = 1,
    this.rowSpan = 1,
    this.scale = 1,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.clipRadiusFraction = 0,
  }) : assert(column >= 0),
       assert(row >= 0),
       assert(columnSpan > 0),
       assert(rowSpan > 0),
       assert(scale > 0 && scale <= 1),
       assert(clipRadiusFraction >= 0 && clipRadiusFraction <= 0.5);

  final String asset;
  final int column;
  final int row;
  final int columnSpan;
  final int rowSpan;
  final double scale;
  final BoxFit fit;
  final Alignment alignment;
  final double clipRadiusFraction;
}

/// Paints asset images directly into calculated grid cells.
///
/// There are deliberately no per-image layout widgets. This keeps transparent
/// image pixels transparent and gives future card grids one shared placement
/// path for cell spans, fitting, scaling, and clipping.
class AssetImageGrid extends StatefulWidget {
  const AssetImageGrid({
    super.key,
    required this.items,
    this.columns = 1,
    this.rows = 1,
    this.columnGap = 0,
    this.rowGap = 0,
    this.rowHorizontalOffsets = const [],
    this.contentPadding = EdgeInsets.zero,
    this.selectedCell,
    this.selectionShapeAsset,
    this.selectionColor = const Color(0xffff72b6),
    this.selectionWidthFraction = 0.02,
    this.onCellTap,
  }) : assert(columns > 0),
       assert(rows > 0),
       assert(columnGap >= 0),
       assert(rowGap >= 0);

  final List<AssetImageGridItem> items;
  final int columns;
  final int rows;
  final double columnGap;
  final double rowGap;
  final List<double> rowHorizontalOffsets;
  final EdgeInsets contentPadding;
  final int? selectedCell;
  final String? selectionShapeAsset;
  final Color selectionColor;
  final double selectionWidthFraction;
  final ValueChanged<int>? onCellTap;

  @override
  State<AssetImageGrid> createState() => _AssetImageGridState();
}

class _AssetImageGridState extends State<AssetImageGrid> {
  final Map<String, ImageStream> _streams = {};
  final Map<String, ImageStreamListener> _listeners = {};
  Map<String, ui.Image> _images = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImages();
  }

  @override
  void didUpdateWidget(AssetImageGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameAssets(oldWidget.items, widget.items)) {
      _resolveImages();
    }
  }

  bool _sameAssets(
    List<AssetImageGridItem> oldItems,
    List<AssetImageGridItem> newItems,
  ) {
    final oldAssets = oldItems.map((item) => item.asset).toSet();
    final newAssets = newItems.map((item) => item.asset).toSet();
    return oldAssets.length == newAssets.length &&
        oldAssets.containsAll(newAssets);
  }

  void _resolveImages() {
    final assets = widget.items.map((item) => item.asset).toSet();
    for (final asset in _streams.keys.toList()) {
      if (assets.contains(asset)) continue;
      _streams.remove(asset)?.removeListener(_listeners.remove(asset)!);
      _images = Map.of(_images)..remove(asset);
    }
    for (final asset in assets) {
      if (_streams.containsKey(asset)) continue;
      final stream = AssetImage(
        asset,
      ).resolve(createLocalImageConfiguration(context));
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!mounted) return;
          setState(
            () => _images = Map.unmodifiable({..._images, asset: info.image}),
          );
        },
        onError: (_, _) {
          if (!mounted || !_images.containsKey(asset)) return;
          setState(() => _images = Map.of(_images)..remove(asset));
        },
      );
      _streams[asset] = stream;
      _listeners[asset] = listener;
      stream.addListener(listener);
    }
  }

  @override
  void dispose() {
    for (final entry in _streams.entries) {
      entry.value.removeListener(_listeners[entry.key]!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapUp: widget.onCellTap == null
        ? null
        : (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final index = _cellAt(details.localPosition, box.size);
            if (index != null) widget.onCellTap!(index);
          },
    child: CustomPaint(
      key: const ValueKey('asset-image-grid-painter'),
      painter: _AssetImageGridPainter(
        items: widget.items,
        images: _images,
        columns: widget.columns,
        rows: widget.rows,
        columnGap: widget.columnGap,
        rowGap: widget.rowGap,
        rowHorizontalOffsets: widget.rowHorizontalOffsets,
        contentPadding: widget.contentPadding,
        selectedCell: widget.selectedCell,
        selectionShapeAsset: widget.selectionShapeAsset,
        selectionColor: widget.selectionColor,
        selectionWidthFraction: widget.selectionWidthFraction,
      ),
    ),
  );

  int? _cellAt(Offset point, Size size) {
    final content = widget.contentPadding.deflateRect(Offset.zero & size);
    if (!content.contains(point)) return null;
    final cellWidth =
        (content.width - widget.columnGap * (widget.columns - 1)) /
        widget.columns;
    final cellHeight =
        (content.height - widget.rowGap * (widget.rows - 1)) / widget.rows;
    final row = ((point.dy - content.top) / (cellHeight + widget.rowGap))
        .floor();
    if (row < 0 || row >= widget.rows) {
      return null;
    }
    final column =
        ((point.dx - content.left - _rowOffset(row)) /
                (cellWidth + widget.columnGap))
            .floor();
    if (column < 0 || column >= widget.columns) return null;
    final localX =
        point.dx -
        content.left -
        _rowOffset(row) -
        column * (cellWidth + widget.columnGap);
    final localY = point.dy - content.top - row * (cellHeight + widget.rowGap);
    if (localX > cellWidth || localY > cellHeight) return null;
    return row * widget.columns + column;
  }

  double _rowOffset(int row) => row < widget.rowHorizontalOffsets.length
      ? widget.rowHorizontalOffsets[row]
      : 0;
}

class _AssetImageGridPainter extends CustomPainter {
  const _AssetImageGridPainter({
    required this.items,
    required this.images,
    required this.columns,
    required this.rows,
    required this.columnGap,
    required this.rowGap,
    required this.rowHorizontalOffsets,
    required this.contentPadding,
    required this.selectedCell,
    required this.selectionShapeAsset,
    required this.selectionColor,
    required this.selectionWidthFraction,
  });

  final List<AssetImageGridItem> items;
  final Map<String, ui.Image> images;
  final int columns;
  final int rows;
  final double columnGap;
  final double rowGap;
  final List<double> rowHorizontalOffsets;
  final EdgeInsets contentPadding;
  final int? selectedCell;
  final String? selectionShapeAsset;
  final Color selectionColor;
  final double selectionWidthFraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final content = contentPadding.deflateRect(Offset.zero & size);
    final cellWidth = (content.width - columnGap * (columns - 1)) / columns;
    final cellHeight = (content.height - rowGap * (rows - 1)) / rows;
    for (final item in items) {
      final image = images[item.asset];
      if (image == null ||
          item.column + item.columnSpan > columns ||
          item.row + item.rowSpan > rows) {
        continue;
      }
      final cell = Rect.fromLTWH(
        content.left +
            _rowOffset(item.row) +
            item.column * (cellWidth + columnGap),
        content.top + item.row * (cellHeight + rowGap),
        cellWidth * item.columnSpan + columnGap * (item.columnSpan - 1),
        cellHeight * item.rowSpan + rowGap * (item.rowSpan - 1),
      );
      final target = Rect.fromCenter(
        center: cell.center,
        width: cell.width * item.scale,
        height: cell.height * item.scale,
      );
      canvas.save();
      if (item.clipRadiusFraction > 0) {
        final fitted = _fittedImageRect(
          image,
          target,
          item.fit,
          item.alignment,
        );
        final radius = fitted.shortestSide * item.clipRadiusFraction;
        canvas.clipRRect(
          RRect.fromRectAndRadius(fitted, Radius.circular(radius)),
          doAntiAlias: true,
        );
      }
      paintImage(
        canvas: canvas,
        rect: target,
        image: image,
        fit: item.fit,
        alignment: item.alignment,
        filterQuality: FilterQuality.high,
      );
      canvas.restore();
    }
    final selected = selectedCell;
    if (selected != null && selected >= 0 && selected < columns * rows) {
      final column = selected % columns;
      final row = selected ~/ columns;
      final cell = Rect.fromLTWH(
        content.left + _rowOffset(row) + column * (cellWidth + columnGap),
        content.top + row * (cellHeight + rowGap),
        cellWidth,
        cellHeight,
      );
      final stroke = math.max(1.0, cell.shortestSide * selectionWidthFraction);
      final shapeAsset = selectionShapeAsset;
      final shapeItem = shapeAsset == null
          ? null
          : items
                .where(
                  (item) =>
                      item.asset == shapeAsset &&
                      item.column == column &&
                      item.row == row,
                )
                .firstOrNull;
      final shapeImage = shapeItem == null ? null : images[shapeItem.asset];
      if (shapeItem != null && shapeImage != null) {
        final target = Rect.fromCenter(
          center: cell.center,
          width: cell.width * shapeItem.scale,
          height: cell.height * shapeItem.scale,
        );
        final fitted = _fittedImageRect(
          shapeImage,
          target,
          shapeItem.fit,
          shapeItem.alignment,
        );
        _paintImageSilhouetteOutline(
          canvas,
          shapeImage,
          fitted,
          stroke,
          selectionColor,
        );
      } else if (shapeAsset == null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            cell.deflate(stroke / 2),
            Radius.circular(cell.shortestSide * 0.08),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = selectionColor,
        );
      }
    }
  }

  double _rowOffset(int row) =>
      row < rowHorizontalOffsets.length ? rowHorizontalOffsets[row] : 0;

  void _paintImageSilhouetteOutline(
    Canvas canvas,
    ui.Image image,
    Rect fitted,
    double stroke,
    Color color,
  ) {
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final expanded = fitted.inflate(stroke);
    canvas.saveLayer(expanded, Paint());
    canvas.drawImageRect(
      image,
      source,
      expanded,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
    );
    canvas.drawImageRect(
      image,
      source,
      fitted,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high
        ..blendMode = BlendMode.dstOut,
    );
    canvas.restore();
  }

  Rect _fittedImageRect(
    ui.Image image,
    Rect outputRect,
    BoxFit fit,
    Alignment alignment,
  ) {
    final fitted = applyBoxFit(
      fit,
      Size(image.width.toDouble(), image.height.toDouble()),
      outputRect.size,
    );
    return alignment.inscribe(fitted.destination, outputRect);
  }

  @override
  bool shouldRepaint(_AssetImageGridPainter oldDelegate) =>
      oldDelegate.items != items ||
      oldDelegate.images != images ||
      oldDelegate.columns != columns ||
      oldDelegate.rows != rows ||
      oldDelegate.columnGap != columnGap ||
      oldDelegate.rowGap != rowGap ||
      oldDelegate.rowHorizontalOffsets != rowHorizontalOffsets ||
      oldDelegate.contentPadding != contentPadding ||
      oldDelegate.selectedCell != selectedCell ||
      oldDelegate.selectionShapeAsset != selectionShapeAsset ||
      oldDelegate.selectionColor != selectionColor ||
      oldDelegate.selectionWidthFraction != selectionWidthFraction;
}
