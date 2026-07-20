import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

@immutable
class BATriangleTextureConfig {
  const BATriangleTextureConfig({
    required this.baseColor,
    required this.panelColor,
    required this.softColor,
    required this.accentColor,
    this.triangleSize = 138,
    this.tessellationContrast = 0.032,
    this.randomSeed = 7319,
    this.macroTriangleChance = 0.075,
    this.macroTriangleScale = 3,
    this.macroTriangleContrast = 0.024,
    this.lightStrength = 0.16,
    this.lightCenterX = 0.5,
    this.lightCenterY = 0.5,
    this.edgeVignetteStrength = 0.2,
    this.fogDirectionDegrees = 18,
    this.fogStrength = 0.13,
    this.originJitter = 0.35,
    this.rowPhaseJitter = 0.18,
    this.rowHeightJitter = 0.06,
    this.rowHeightJitterTargetRows = 6,
  });

  final Color baseColor;
  final Color panelColor;
  final Color softColor;
  final Color accentColor;
  final double triangleSize;
  final double tessellationContrast;
  final int randomSeed;
  final double macroTriangleChance;
  final double macroTriangleScale;
  final double macroTriangleContrast;
  final double lightStrength;
  final double lightCenterX;
  final double lightCenterY;
  final double edgeVignetteStrength;
  final double fogDirectionDegrees;
  final double fogStrength;
  final double originJitter;
  final double rowPhaseJitter;
  final double rowHeightJitter;
  final double rowHeightJitterTargetRows;

  BATriangleTextureConfig normalized() => BATriangleTextureConfig(
    baseColor: baseColor,
    panelColor: panelColor,
    softColor: softColor,
    accentColor: accentColor,
    triangleSize: triangleSize.clamp(6, double.infinity).toDouble(),
    tessellationContrast: tessellationContrast.clamp(0, 0.18).toDouble(),
    randomSeed: randomSeed,
    macroTriangleChance: macroTriangleChance.clamp(0, 0.35).toDouble(),
    macroTriangleScale: macroTriangleScale.clamp(1.5, 6).toDouble(),
    macroTriangleContrast: macroTriangleContrast.clamp(0, 0.12).toDouble(),
    lightStrength: lightStrength.clamp(0, 0.45).toDouble(),
    lightCenterX: lightCenterX.clamp(0, 1).toDouble(),
    lightCenterY: lightCenterY.clamp(0, 1).toDouble(),
    edgeVignetteStrength: edgeVignetteStrength.clamp(0, 0.45).toDouble(),
    fogDirectionDegrees: fogDirectionDegrees % 360,
    fogStrength: fogStrength.clamp(0, 0.3).toDouble(),
    originJitter: originJitter.clamp(0, 0.5).toDouble(),
    rowPhaseJitter: rowPhaseJitter.clamp(0, 0.3).toDouble(),
    rowHeightJitter: rowHeightJitter.clamp(0, 0.1).toDouble(),
    rowHeightJitterTargetRows: rowHeightJitterTargetRows
        .clamp(0, 12)
        .toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BATriangleTextureConfig &&
          baseColor == other.baseColor &&
          panelColor == other.panelColor &&
          softColor == other.softColor &&
          accentColor == other.accentColor &&
          triangleSize == other.triangleSize &&
          tessellationContrast == other.tessellationContrast &&
          randomSeed == other.randomSeed &&
          macroTriangleChance == other.macroTriangleChance &&
          macroTriangleScale == other.macroTriangleScale &&
          macroTriangleContrast == other.macroTriangleContrast &&
          lightStrength == other.lightStrength &&
          lightCenterX == other.lightCenterX &&
          lightCenterY == other.lightCenterY &&
          edgeVignetteStrength == other.edgeVignetteStrength &&
          fogDirectionDegrees == other.fogDirectionDegrees &&
          fogStrength == other.fogStrength &&
          originJitter == other.originJitter &&
          rowPhaseJitter == other.rowPhaseJitter &&
          rowHeightJitter == other.rowHeightJitter &&
          rowHeightJitterTargetRows == other.rowHeightJitterTargetRows;

  @override
  int get hashCode => Object.hashAll([
    baseColor,
    panelColor,
    softColor,
    accentColor,
    triangleSize,
    tessellationContrast,
    randomSeed,
    macroTriangleChance,
    macroTriangleScale,
    macroTriangleContrast,
    lightStrength,
    lightCenterX,
    lightCenterY,
    edgeVignetteStrength,
    fogDirectionDegrees,
    fogStrength,
    originJitter,
    rowPhaseJitter,
    rowHeightJitter,
    rowHeightJitterTargetRows,
  ]);
}

class BATriangleBackground extends StatelessWidget {
  const BATriangleBackground({super.key, this.config = defaultConfig});

  static const defaultConfig = BATriangleTextureConfig(
    baseColor: AppColors.canvas,
    panelColor: AppColors.surfaceRaised,
    softColor: AppColors.textMuted,
    accentColor: AppColors.primary,
  );

  final BATriangleTextureConfig config;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('ba-triangle-background'),
        painter: BATriangleTexturePainter(config),
        isComplex: true,
        willChange: false,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class BATriangleTexturePainter extends CustomPainter {
  BATriangleTexturePainter(BATriangleTextureConfig config)
    : config = config.normalized();

  final BATriangleTextureConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = config.baseColor);
    _paintFineFaces(canvas, rect);
    _paintMacroFaces(canvas, rect);
    _paintAtmosphere(canvas, rect);
  }

  void _paintFineFaces(Canvas canvas, Rect rect) {
    final side = config.triangleSize;
    final nominalHeight = side * math.sqrt(3) * 0.5;
    final variation = _effectiveRowHeightJitter(
      rect.height,
      nominalHeight,
      config.rowHeightJitter,
      config.rowHeightJitterTargetRows,
    );
    final minimumHeight = nominalHeight * (1 - variation);
    final firstRow = ((rect.top - nominalHeight) / minimumHeight).floor() - 2;
    final lastRow = ((rect.bottom + nominalHeight) / minimumHeight).ceil() + 2;
    final colors = [
      _alpha(config.softColor, config.tessellationContrast * 0.62),
      _alpha(config.panelColor, config.tessellationContrast * 0.9),
      _alpha(Colors.black, config.tessellationContrast * 0.38),
      _alpha(config.accentColor, config.tessellationContrast * 0.2),
    ];
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (var row = firstRow; row <= lastRow; row++) {
      final band = _warpedRow(
        row,
        side: side,
        nominalHeight: nominalHeight,
        variation: variation,
        channel: 20,
      );
      final firstColumn = ((rect.left - band.phase - side) / side).floor();
      final lastColumn = ((rect.right - band.phase + side) / side).ceil();

      for (var column = firstColumn; column <= lastColumn; column++) {
        final x = column * side + band.phase;
        _drawFace(
          canvas,
          paint..color = colors[_shade(column, row, 0, colors.length)],
          Offset(x, band.top),
          Offset(x + side, band.top),
          Offset(x + side * 0.5, band.bottom),
        );
        _drawFace(
          canvas,
          paint..color = colors[_shade(column, row, 1, colors.length)],
          Offset(x + side, band.top),
          Offset(x + side * 1.5, band.bottom),
          Offset(x + side * 0.5, band.bottom),
        );
      }
    }
  }

  void _paintMacroFaces(Canvas canvas, Rect rect) {
    final side = config.triangleSize * config.macroTriangleScale;
    final nominalHeight = side * math.sqrt(3) * 0.5;
    final variation = _effectiveRowHeightJitter(
      rect.height,
      nominalHeight,
      config.rowHeightJitter,
      config.rowHeightJitterTargetRows,
    );
    final minimumHeight = nominalHeight * (1 - variation);
    final firstRow = ((rect.top - nominalHeight) / minimumHeight).floor() - 2;
    final lastRow = ((rect.bottom + nominalHeight) / minimumHeight).ceil() + 2;
    final colors = [
      _alpha(config.softColor, config.macroTriangleContrast),
      _alpha(config.panelColor, config.macroTriangleContrast * 0.82),
      _alpha(config.accentColor, config.macroTriangleContrast * 0.34),
    ];
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (var row = firstRow; row <= lastRow; row++) {
      final band = _warpedRow(
        row,
        side: side,
        nominalHeight: nominalHeight,
        variation: variation,
        channel: 40,
      );
      final firstColumn = ((rect.left - band.phase - side) / side).floor();
      final lastColumn = ((rect.right - band.phase + side) / side).ceil();

      for (var column = firstColumn; column <= lastColumn; column++) {
        final x = column * side + band.phase;
        for (var face = 0; face < 2; face++) {
          if (_cellRandom(column, row, face + 4, config.randomSeed) >=
              config.macroTriangleChance) {
            continue;
          }
          paint.color = colors[_shade(column, row, face + 8, colors.length)];
          if (face == 0) {
            _drawFace(
              canvas,
              paint,
              Offset(x, band.top),
              Offset(x + side, band.top),
              Offset(x + side * 0.5, band.bottom),
            );
          } else {
            _drawFace(
              canvas,
              paint,
              Offset(x + side, band.top),
              Offset(x + side * 1.5, band.bottom),
              Offset(x + side * 0.5, band.bottom),
            );
          }
        }
      }
    }
  }

  void _paintAtmosphere(Canvas canvas, Rect rect) {
    final center = Offset(
      rect.left + rect.width * config.lightCenterX,
      rect.top + rect.height * config.lightCenterY,
    );
    final maximumDimension = math.max(rect.width, rect.height).toDouble();

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          maximumDimension * 0.58,
          [
            _alpha(config.softColor, config.lightStrength),
            _alpha(config.softColor, config.lightStrength * 0.72),
            _alpha(config.accentColor, config.lightStrength * 0.1),
            _alpha(config.softColor, 0),
          ],
          [0, 0.34, 0.7, 1],
        ),
    );

    final fogAxis = _gradientAxis(rect, config.fogDirectionDegrees);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          fogAxis.start,
          fogAxis.end,
          [
            _alpha(config.panelColor, 0),
            _alpha(config.softColor, config.fogStrength * 0.45),
            _alpha(config.softColor, config.fogStrength),
            _alpha(config.panelColor, config.fogStrength * 0.28),
            _alpha(config.panelColor, 0),
          ],
          [0, 0.28, 0.56, 0.82, 1],
        ),
    );

    final glowCenter = Offset.lerp(fogAxis.start, fogAxis.end, 0.7)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          glowCenter,
          maximumDimension * 0.82,
          [
            _alpha(config.softColor, config.fogStrength * 0.5),
            _alpha(config.accentColor, config.fogStrength * 0.12),
            _alpha(config.baseColor, 0),
          ],
          [0, 0.48, 1],
        ),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          maximumDimension * 0.72,
          [
            _alpha(Colors.black, 0),
            _alpha(Colors.black, 0),
            _alpha(Colors.black, config.edgeVignetteStrength * 0.42),
            _alpha(Colors.black, config.edgeVignetteStrength),
          ],
          [0, 0.56, 0.82, 1],
        ),
    );
  }

  _WarpedBand _warpedRow(
    int row, {
    required double side,
    required double nominalHeight,
    required double variation,
    required int channel,
  }) {
    final originX =
        _centeredNoise(0, channel, config.randomSeed) *
        side *
        config.originJitter;
    final originY =
        _centeredNoise(0, channel + 1, config.randomSeed) *
        nominalHeight *
        config.originJitter;
    final top =
        originY + _rowBoundary(row, nominalHeight, variation, channel + 2);
    final bottom =
        originY + _rowBoundary(row + 1, nominalHeight, variation, channel + 2);
    final stagger = row.isOdd ? side * 0.5 : 0.0;
    final phase =
        originX +
        stagger +
        _centeredNoise(row, channel + 3, config.randomSeed) *
            side *
            config.rowPhaseJitter;
    return _WarpedBand(top, bottom, phase);
  }

  double _rowBoundary(
    int row,
    double nominalHeight,
    double variation,
    int channel,
  ) {
    if (row > 0) {
      var total = 0.0;
      for (var index = 0; index < row; index++) {
        total += _rowHeight(index, nominalHeight, variation, channel);
      }
      return total;
    }
    if (row < 0) {
      var total = 0.0;
      for (var index = row; index < 0; index++) {
        total += _rowHeight(index, nominalHeight, variation, channel);
      }
      return -total;
    }
    return 0;
  }

  double _rowHeight(
    int row,
    double nominalHeight,
    double variation,
    int channel,
  ) =>
      nominalHeight *
      (1 + _centeredNoise(row, channel, config.randomSeed) * variation);

  int _shade(int column, int row, int face, int colorCount) => math.min(
    colorCount - 1,
    (_cellRandom(column, row, face, config.randomSeed) * colorCount).floor(),
  );

  @override
  bool shouldRepaint(BATriangleTexturePainter oldDelegate) =>
      oldDelegate.config != config;
}

class _WarpedBand {
  const _WarpedBand(this.top, this.bottom, this.phase);

  final double top;
  final double bottom;
  final double phase;
}

class _GradientAxis {
  const _GradientAxis(this.start, this.end);

  final Offset start;
  final Offset end;
}

_GradientAxis _gradientAxis(Rect rect, double degrees) {
  final radians = degrees * math.pi / 180;
  final dx = math.cos(radians);
  final dy = math.sin(radians);
  final span = dx.abs() * rect.width + dy.abs() * rect.height;
  final offset = Offset(dx * span * 0.5, dy * span * 0.5);
  return _GradientAxis(rect.center - offset, rect.center + offset);
}

double _effectiveRowHeightJitter(
  double surfaceHeight,
  double nominalHeight,
  double configuredJitter,
  double targetRows,
) {
  if (configuredJitter <= 0 || targetRows <= 0 || nominalHeight <= 0) {
    return configuredJitter;
  }
  final visibleRows = math.max(1, surfaceHeight / nominalHeight).toDouble();
  if (visibleRows >= targetRows) {
    return configuredJitter;
  }
  return math.min(0.1, configuredJitter * (targetRows / visibleRows));
}

double _centeredNoise(int row, int channel, int seed) =>
    _cellRandom(0, row, channel, seed) * 2 - 1;

double _cellRandom(int column, int row, int face, int seed) {
  var value =
      (column * 0x1f123bb5) ^ (row * 0x5f356495) ^ (face * 0x6c8e9cf5) ^ seed;
  value &= 0xffffffff;
  value ^= value >> 16;
  value = (value * 0x7feb352d) & 0xffffffff;
  value ^= value >> 15;
  value = (value * 0x846ca68b) & 0xffffffff;
  value ^= value >> 16;
  return (value & 0xffffffff) / 0xffffffff;
}

Color _alpha(Color color, double opacity) =>
    color.withValues(alpha: opacity.clamp(0, 1).toDouble());

void _drawFace(
  Canvas canvas,
  Paint paint,
  Offset first,
  Offset second,
  Offset third,
) {
  canvas.drawPath(
    Path()
      ..moveTo(first.dx, first.dy)
      ..lineTo(second.dx, second.dy)
      ..lineTo(third.dx, third.dy)
      ..close(),
    paint,
  );
}
