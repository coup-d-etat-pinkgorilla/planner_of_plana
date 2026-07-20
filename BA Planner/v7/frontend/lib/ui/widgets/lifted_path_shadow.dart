import 'package:flutter/material.dart';

@immutable
class LiftedPathShadowSpec {
  const LiftedPathShadowSpec({
    required this.color,
    this.offset = const Offset(2, 2),
    this.inset = 3,
    this.layers = 4,
    this.maxAlpha = 0.2,
  });

  final Color color;
  final Offset offset;
  final double inset;
  final int layers;
  final double maxAlpha;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiftedPathShadowSpec &&
          color == other.color &&
          offset == other.offset &&
          inset == other.inset &&
          layers == other.layers &&
          maxAlpha == other.maxAlpha;

  @override
  int get hashCode => Object.hash(color, offset, inset, layers, maxAlpha);
}

void paintLiftedPathShadow(
  Canvas canvas,
  Path path,
  LiftedPathShadowSpec spec,
) {
  final layers = spec.layers.clamp(1, 8);
  final maximumAlpha = spec.maxAlpha.clamp(0, 1).toDouble();
  final paint = Paint()..style = PaintingStyle.fill;

  for (var layer = layers; layer >= 1; layer--) {
    final progress = layer / layers;
    paint.color = spec.color.withValues(
      alpha: maximumAlpha * (1 - progress * 0.65),
    );
    canvas.save();
    canvas.translate(spec.offset.dx * progress, spec.offset.dy * progress);
    canvas.drawPath(path, paint);
    canvas.restore();
  }
}
