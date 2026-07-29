import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'bond_rank_portrait.dart';
import 'section_template_surface.dart';

const diagonalMediaIncreaseColor = AppColors.success;
const diagonalMediaDecreaseColor = AppColors.danger;
const diagonalMediaHighlightColor = Color(0xfff2b3ef);
const diagonalMediaHighlightStrokeWidth = 1.8;

@immutable
class DiagonalMediaValue {
  const DiagonalMediaValue(
    this.value, {
    this.delta,
    this.componentDeltas = const [],
  });

  final String value;
  final int? delta;
  final List<int?> componentDeltas;
}

@immutable
class DiagonalMediaEquipment {
  const DiagonalMediaEquipment({
    required this.assetPath,
    required this.tier,
    required this.level,
  });

  final String assetPath;
  final DiagonalMediaValue tier;
  final DiagonalMediaValue level;
}

@immutable
class DiagonalMediaListItemData {
  const DiagonalMediaListItemData({
    required this.order,
    required this.mediaAssetPath,
    required this.title,
    required this.studentStars,
    required this.weaponStars,
    required this.studentLevel,
    required this.weaponLevel,
    required this.skills,
    required this.equipment,
    required this.favoriteItem,
    required this.bondRank,
    required this.stats,
    this.studentStarDelta,
    this.weaponStarDelta,
    this.titleColor,
    this.skillsColor,
    this.equipmentValueColors = const [],
  });

  final int order;
  final String mediaAssetPath;
  final String title;
  final int studentStars;
  final int weaponStars;
  final int? studentStarDelta;
  final int? weaponStarDelta;
  final DiagonalMediaValue studentLevel;
  final DiagonalMediaValue weaponLevel;
  final DiagonalMediaValue skills;
  final List<DiagonalMediaEquipment> equipment;
  final DiagonalMediaValue favoriteItem;
  final DiagonalMediaValue bondRank;
  final DiagonalMediaValue stats;
  final Color? titleColor;
  final Color? skillsColor;
  final List<Color?> equipmentValueColors;
}

abstract final class DiagonalMediaListItemLayout {
  static const portrait = Rect.fromLTWH(
    0.02673061028145967,
    0.06667155170316601,
    0.11665172675573504,
    0.8504803022126282,
  );
  static const order = Rect.fromLTWH(
    0.011954426973180027,
    0.258279264012443,
    0.030330114477959885,
    0.4672648775940735,
  );
  static const stars = Rect.fromLTWH(
    0.3033738401775881,
    0.135340637364583,
    0.2899206577028625,
    0.154,
  );
  static const title = Rect.fromLTWH(
    0.14525452422767093,
    0.09056611938391293,
    0.14717341631167402,
    0.24354903596134034,
  );
  static const studentLevel = Rect.fromLTWH(
    0.14510586298340147,
    0.5219890306248066,
    0.06670585938845575,
    0.30830888485502617,
  );
  static const weaponLevel = Rect.fromLTWH(
    0.60079054937114,
    0.096453378374248,
    0.056234054035434244,
    0.23177451798067014,
  );
  static const skills = Rect.fromLTWH(0.224, 0.41614347305232, 0.146, 0.52);
  static const equipmentImages = <Rect>[
    Rect.fromLTWH(0.382, 0.49614347305232, 0.045, 0.36),
    Rect.fromLTWH(0.512, 0.49614347305232, 0.045, 0.36),
    Rect.fromLTWH(0.642, 0.49614347305232, 0.045, 0.36),
  ];
  static const equipmentValues = <Rect>[
    Rect.fromLTWH(0.435, 0.42614347305232, 0.072, 0.5),
    Rect.fromLTWH(0.565, 0.42614347305232, 0.072, 0.5),
    Rect.fromLTWH(0.695, 0.42614347305232, 0.072, 0.5),
  ];
  static const favoriteItem = Rect.fromLTWH(
    0.775,
    0.53614347305232,
    0.05,
    0.28,
  );
  static const bondAnchor = Rect.fromLTWH(0.92, 0.3119117028094801, 0.06, 0.36);
  static const bondWithDelta = Rect.fromLTWH(
    0.92,
    0.3119117028094801,
    0.06,
    0.48,
  );
  static const stats = Rect.fromLTWH(0.835, 0.42614347305232, 0.08, 0.5);

  static double centerY(Rect rect) => rect.top + rect.height / 2;
}

Path diagonalMediaListItemPath(Size size) {
  final depth = math.min(
    size.width * 0.08,
    size.height / math.tan(80 * math.pi / 180),
  );
  return buildRoundedSectionPolygon([
    Offset(depth, 0),
    Offset(size.width, 0),
    Offset(size.width - depth, size.height),
    Offset(0, size.height),
  ], radius: math.min(7, size.height * 0.16));
}

Path relationshipRankHeartPath(Size size) => Path()
  ..moveTo(size.width * 0.51, size.height * 0.96)
  ..cubicTo(
    size.width * 0.44,
    size.height * 0.86,
    size.width * 0.06,
    size.height * 0.67,
    size.width * 0.06,
    size.height * 0.34,
  )
  ..cubicTo(
    size.width * 0.06,
    size.height * 0.10,
    size.width * 0.24,
    size.height * 0.03,
    size.width * 0.39,
    size.height * 0.08,
  )
  ..cubicTo(
    size.width * 0.47,
    size.height * 0.11,
    size.width * 0.50,
    size.height * 0.20,
    size.width * 0.52,
    size.height * 0.27,
  )
  ..cubicTo(
    size.width * 0.56,
    size.height * 0.16,
    size.width * 0.65,
    size.height * 0.07,
    size.width * 0.77,
    size.height * 0.06,
  )
  ..cubicTo(
    size.width * 0.93,
    size.height * 0.04,
    size.width * 0.98,
    size.height * 0.21,
    size.width * 0.96,
    size.height * 0.37,
  )
  ..cubicTo(
    size.width * 0.93,
    size.height * 0.65,
    size.width * 0.62,
    size.height * 0.86,
    size.width * 0.51,
    size.height * 0.96,
  )
  ..close();

class DiagonalMediaListItem extends StatelessWidget {
  const DiagonalMediaListItem({
    super.key,
    required this.data,
    this.onTap,
    this.highlighted = false,
  });

  final DiagonalMediaListItemData data;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      Widget slot(Rect unitRect, Widget child) => Positioned.fromRect(
        rect: Rect.fromLTWH(
          unitRect.left * size.width,
          unitRect.top * size.height,
          unitRect.width * size.width,
          unitRect.height * size.height,
        ),
        child: child,
      );

      final content = Stack(
        clipBehavior: Clip.none,
        children: [
          slot(
            DiagonalMediaListItemLayout.portrait,
            ClipPath(
              clipper: const _PortraitClipper(),
              child: BondRankPortrait(
                key: const ValueKey('diagonal-media-portrait'),
                portraitAsset: data.mediaAssetPath,
                bondRank: int.tryParse(data.bondRank.value),
                clipRadius: 0,
              ),
            ),
          ),
          slot(
            DiagonalMediaListItemLayout.order,
            _FittedLabel(
              '${data.order}',
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              alignment: Alignment.center,
            ),
          ),
          slot(
            DiagonalMediaListItemLayout.title,
            _FittedLabel(
              data.title,
              color: data.titleColor ?? AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          slot(
            DiagonalMediaListItemLayout.stars,
            _StarIndicator(
              studentStars: data.studentStars,
              weaponStars: data.weaponStars,
              studentDelta: data.studentStarDelta,
              weaponDelta: data.weaponStarDelta,
            ),
          ),
          slot(
            DiagonalMediaListItemLayout.weaponLevel,
            _DeltaLabel(data.weaponLevel),
          ),
          slot(
            DiagonalMediaListItemLayout.bondWithDelta,
            _BondRank(value: data.bondRank),
          ),
          slot(
            DiagonalMediaListItemLayout.studentLevel,
            _DeltaLabel(data.studentLevel),
          ),
          slot(
            DiagonalMediaListItemLayout.skills,
            _StackedDeltaLabel(
              DiagonalMediaValue(
                formatDiagonalMediaSkillLevels(data.skills.value),
                delta: data.skills.delta,
                componentDeltas: data.skills.componentDeltas,
              ),
              key: const ValueKey('diagonal-media-skills'),
              fontSize: 14.25,
              valueColor: data.skillsColor,
            ),
          ),
          for (var index = 0; index < 3; index++) ...[
            slot(
              DiagonalMediaListItemLayout.equipmentImages[index],
              _EquipmentIcon(
                key: ValueKey('diagonal-media-equipment-$index'),
                assetPath: data.equipment[index].assetPath,
              ),
            ),
            slot(
              DiagonalMediaListItemLayout.equipmentValues[index],
              _EquipmentValueLabel(
                key: ValueKey('diagonal-media-equipment-value-$index'),
                equipment: data.equipment[index],
                valueColor: index < data.equipmentValueColors.length
                    ? data.equipmentValueColors[index]
                    : null,
              ),
            ),
          ],
          slot(
            DiagonalMediaListItemLayout.favoriteItem,
            _DeltaLabel(
              data.favoriteItem,
              key: const ValueKey('diagonal-media-favorite-item'),
            ),
          ),
          slot(
            DiagonalMediaListItemLayout.stats,
            _StackedDeltaLabel(
              data.stats,
              key: const ValueKey('diagonal-media-stats'),
              fontSize: 9.5,
            ),
          ),
        ],
      );

      return CustomPaint(
        painter: _ItemSurfacePainter(highlighted: highlighted),
        child: ClipPath(
          clipper: const _ItemClipper(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: content),
          ),
        ),
      );
    },
  );
}

class _FittedLabel extends StatelessWidget {
  const _FittedLabel(
    this.text, {
    required this.color,
    this.fontWeight = FontWeight.w700,
    this.alignment = Alignment.centerLeft,
  });

  final String text;
  final Color color;
  final FontWeight fontWeight;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: fontWeight,
          height: 1,
        ),
      ),
    ),
  );
}

class _DeltaLabel extends StatelessWidget {
  const _DeltaLabel(
    this.value, {
    super.key,
    this.fontSize = 9.5,
    this.alignment = Alignment.centerLeft,
    this.contentKey,
  });

  final DiagonalMediaValue value;
  final double fontSize;
  final Alignment alignment;
  final Key? contentKey;

  @override
  Widget build(BuildContext context) {
    final delta = value.delta;
    return Align(
      alignment: alignment,
      child: FittedBox(
        key: contentKey,
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: RichText(
          maxLines: 1,
          text: TextSpan(
            style: TextStyle(
              color: AppColors.textMuted,
              fontFamily: 'GyeonggiTitle',
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
            children: [
              TextSpan(text: value.value),
              if (delta != null && delta != 0)
                TextSpan(
                  text: delta > 0 ? '(▲$delta)' : '(▼${delta.abs()})',
                  style: TextStyle(
                    color: delta > 0
                        ? diagonalMediaIncreaseColor
                        : diagonalMediaDecreaseColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StackedDeltaLabel extends StatelessWidget {
  const _StackedDeltaLabel(
    this.value, {
    super.key,
    required this.fontSize,
    this.valueColor,
  });

  final DiagonalMediaValue value;
  final double fontSize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final deltas = value.componentDeltas.isNotEmpty
        ? value.componentDeltas
        : [value.delta];
    final hasDelta = deltas.any((delta) => delta != null && delta != 0);
    if (!hasDelta) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _FittedValueText(
          value.value,
          fontSize: fontSize,
          color: valueColor,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: _FittedValueText(
              value.value,
              fontSize: fontSize,
              color: valueColor,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Align(
            alignment: Alignment.topLeft,
            child: _ComponentDeltaLine(deltas: deltas),
          ),
        ),
      ],
    );
  }
}

class _EquipmentValueLabel extends StatelessWidget {
  const _EquipmentValueLabel({
    super.key,
    required this.equipment,
    this.valueColor,
  });

  final DiagonalMediaEquipment equipment;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => _StackedDeltaLabel(
    DiagonalMediaValue(
      '${equipment.tier.value} ${equipment.level.value}',
      componentDeltas: [equipment.tier.delta, equipment.level.delta],
    ),
    fontSize: 8.5,
    valueColor: valueColor,
  );
}

class _FittedValueText extends StatelessWidget {
  const _FittedValueText(this.value, {required this.fontSize, this.color});

  final String value;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      value,
      maxLines: 1,
      style: TextStyle(
        color: color ?? AppColors.textMuted,
        fontFamily: 'GyeonggiTitle',
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
  );
}

class _ComponentDeltaLine extends StatelessWidget {
  const _ComponentDeltaLine({required this.deltas});

  final List<int?> deltas;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: RichText(
      maxLines: 1,
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.textMuted,
          fontFamily: 'GyeonggiTitle',
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
        children: [
          for (var index = 0; index < deltas.length; index++) ...[
            if (index > 0) const TextSpan(text: ' / '),
            TextSpan(
              text: _deltaPart(deltas[index]),
              style: TextStyle(color: _deltaPartColor(deltas[index])),
            ),
          ],
        ],
      ),
    ),
  );

  static String _deltaPart(int? delta) {
    if (delta == null || delta == 0) return '-';
    return delta > 0 ? '▲$delta' : '▼${delta.abs()}';
  }

  static Color _deltaPartColor(int? delta) {
    if (delta == null || delta == 0) return AppColors.textMuted;
    return delta > 0 ? diagonalMediaIncreaseColor : diagonalMediaDecreaseColor;
  }
}

String formatDiagonalMediaSkillLevels(String value) {
  final levels = value.split('/');
  if (levels.length != 4) return value;
  const maximums = [5, 10, 10, 10];
  return [
    for (var index = 0; index < levels.length; index++)
      switch (int.tryParse(levels[index].trim())) {
        final parsed? when parsed >= maximums[index] => 'M',
        _ => levels[index].trim(),
      },
  ].join('/');
}

class _BondRank extends StatelessWidget {
  const _BondRank({required this.value});

  final DiagonalMediaValue value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        flex: 3,
        child: Center(
          child: AspectRatio(
            key: const ValueKey('diagonal-media-heart'),
            aspectRatio: 1.28,
            child: CustomPaint(
              painter: const _HeartPainter(),
              child: Align(
                alignment: const Alignment(0, -0.04),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value.value,
                    style: const TextStyle(
                      color: Color(0xff27465a),
                      fontSize: 15.75,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: [
                        Shadow(color: Colors.white, blurRadius: 1.2),
                        Shadow(color: Colors.white, offset: Offset(0, 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      if (value.delta case final delta? when delta != 0)
        Expanded(
          flex: 1,
          child: Center(
            child: _DeltaLabel(
              DiagonalMediaValue('', delta: delta),
              fontSize: 8.5,
              alignment: Alignment.center,
              contentKey: const ValueKey('diagonal-media-bond-delta'),
            ),
          ),
        )
      else
        const Spacer(),
    ],
  );
}

class _EquipmentIcon extends StatelessWidget {
  const _EquipmentIcon({super.key, required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    alignment: Alignment.center,
    children: [
      Image.asset(
        defaultStudentPortraitBackgroundAsset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
      FractionallySizedBox(
        widthFactor: 0.98,
        heightFactor: 0.98,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    ],
  );
}

class _StarIndicator extends StatelessWidget {
  const _StarIndicator({
    required this.studentStars,
    required this.weaponStars,
    required this.studentDelta,
    required this.weaponDelta,
  });

  final int studentStars;
  final int weaponStars;
  final int? studentDelta;
  final int? weaponDelta;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '성급 ${_deltaSemantics(studentStars, studentDelta)}, '
        '무기 성급 ${_deltaSemantics(weaponStars, weaponDelta)}',
    child: CustomPaint(
      painter: _StarIndicatorPainter(
        studentStars: studentStars,
        weaponStars: weaponStars,
      ),
    ),
  );

  static String _deltaSemantics(int value, int? delta) {
    if (delta == null || delta == 0) return '$value';
    return delta > 0 ? '$value(▲$delta)' : '$value(▼${delta.abs()})';
  }
}

class _StarIndicatorPainter extends CustomPainter {
  const _StarIndicatorPainter({
    required this.studentStars,
    required this.weaponStars,
  });

  final int studentStars;
  final int weaponStars;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = math.max(0.7, size.width * 0.008);
    final segmentWidth = math.max<double>(0, (size.width - gap * 8) / 9);
    for (var index = 0; index < 9; index++) {
      final rect = Rect.fromLTWH(
        index * (segmentWidth + gap),
        0,
        segmentWidth,
        size.height,
      );
      final depth = math.min(
        rect.width * 0.45,
        rect.height / math.tan(80 * math.pi / 180),
      );
      final path = buildRoundedSectionPolygon([
        Offset(rect.left + depth, rect.top),
        rect.topRight,
        Offset(rect.right - depth, rect.bottom),
        rect.bottomLeft,
      ], radius: math.min(3, rect.height * 0.3));
      final active = index < 5 ? index < studentStars : index - 5 < weaponStars;
      final activeColor = index < 5
          ? const Color(0xfff3c96b)
          : AppColors.primary;
      canvas.drawPath(
        path,
        Paint()
          ..color = active
              ? activeColor.withValues(alpha: 0.86)
              : AppColors.outline.withValues(alpha: 0.48),
      );
    }
  }

  @override
  bool shouldRepaint(_StarIndicatorPainter oldDelegate) =>
      oldDelegate.studentStars != studentStars ||
      oldDelegate.weaponStars != weaponStars;
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = relationshipRankHeartPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff94506f).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xffffb9e3));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1, size.shortestSide * 0.075)
        ..color = const Color(0xffec70bd),
    );
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) => false;
}

class _ItemSurfacePainter extends CustomPainter {
  const _ItemSurfacePainter({required this.highlighted});

  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalMediaListItemPath(size);
    canvas.drawPath(
      path,
      Paint()..color = AppColors.canvas.withValues(alpha: 0.58),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? diagonalMediaHighlightStrokeWidth : 0.7
        ..color = highlighted
            ? diagonalMediaHighlightColor
            : AppColors.outline.withValues(alpha: 0.46),
    );
  }

  @override
  bool shouldRepaint(_ItemSurfacePainter oldDelegate) =>
      oldDelegate.highlighted != highlighted;
}

class _ItemClipper extends CustomClipper<Path> {
  const _ItemClipper();

  @override
  Path getClip(Size size) => diagonalMediaListItemPath(size);

  @override
  bool shouldReclip(_ItemClipper oldClipper) => false;
}

class _PortraitClipper extends CustomClipper<Path> {
  const _PortraitClipper();

  @override
  Path getClip(Size size) {
    final depth = math.min(size.width * 0.16, size.height * 0.12);
    return buildRoundedSectionPolygon([
      Offset(depth, 0),
      Offset(size.width, 0),
      Offset(size.width - depth, size.height),
      Offset(0, size.height),
    ], radius: math.min(4, size.height * 0.1));
  }

  @override
  bool shouldReclip(_PortraitClipper oldClipper) => false;
}
