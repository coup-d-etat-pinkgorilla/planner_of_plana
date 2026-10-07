// 작은 초상 줄 + "…+n" 사선 칩 (FE2-d, H §2.2 ShortageTopRow·§6.6).
//
// 시안: 초상 34×28(아이템 기본 배경 + 초상 98% contain), 간격 4, 최대 5개. 넘치는 수는 사선 칩
// "…+n"(h28, 안쪽 0 8, r5, skewX −10°, rgba(255,255,255,.07) + 안쪽 1px rgba(56,81,107,.7), 12px w700 #9eb0c2)이다.
// 줄 폭은 슬롯 폭(시안 246)으로 고정할 수 있다.
// 그림은 `AssetImageGrid` 한 장에 그린다(그림이 없으면 그 칸을 비우고 예외를 내지 않는다).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../widgets/asset_image_grid.dart';
import 'game_assets.dart';
import 'skew_box.dart';

/// [count]명 중 보일 수와 칩으로 접을 수.
({int visible, int hidden}) portraitStripSplit(int count, int maxVisible) {
  final visible = math.max(0, math.min(count, maxVisible));
  return (visible: visible, hidden: math.max(0, count - visible));
}

/// 학생 초상 줄.
class PortraitStrip extends StatelessWidget {
  const PortraitStrip({
    super.key,
    required this.studentIds,
    this.maxVisible = 5,
    this.portraitSize = const Size(34, 28),
    this.gap = 4,
    this.slotWidth,
  });

  final List<String> studentIds;
  final int maxVisible;
  final Size portraitSize;
  final double gap;

  /// 줄 폭을 고정한다(시안 246). 없으면 내용 폭.
  final double? slotWidth;

  /// 칩 글자(`…+n`).
  static String overflowLabel(int hidden) => '…+$hidden';

  @override
  Widget build(BuildContext context) {
    final split = portraitStripSplit(studentIds.length, maxVisible);
    final visible = studentIds.take(split.visible).toList(growable: false);
    final items = <AssetImageGridItem>[
      for (var index = 0; index < visible.length; index++) ...[
        AssetImageGridItem(
          asset: GameAssets.portraitBackground,
          column: index,
          row: 0,
        ),
        AssetImageGridItem(
          asset: GameAssets.studentPortrait(visible[index]),
          column: index,
          row: 0,
          scale: 0.98,
        ),
      ],
    ];
    final strip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (visible.isNotEmpty)
          SizedBox(
            key: const ValueKey('portrait-strip-grid'),
            width:
                portraitSize.width * visible.length +
                gap * (visible.length - 1),
            height: portraitSize.height,
            child: AssetImageGrid(
              items: items,
              columns: visible.length,
              columnGap: gap,
            ),
          ),
        if (split.hidden > 0) ...[
          if (visible.isNotEmpty) SizedBox(width: gap),
          PortraitOverflowChip(
            hidden: split.hidden,
            height: portraitSize.height,
          ),
        ],
      ],
    );
    final slotWidth = this.slotWidth;
    return Semantics(
      label: '학생 ${studentIds.length}명',
      child: slotWidth == null
          ? strip
          : SizedBox(
              width: slotWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                heightFactor: 1,
                child: strip,
              ),
            ),
    );
  }
}

/// "…+n" 사선 칩.
class PortraitOverflowChip extends StatelessWidget {
  const PortraitOverflowChip({
    super.key,
    required this.hidden,
    this.height = 28,
  });

  final int hidden;
  final double height;

  static const fill = Color.fromRGBO(255, 255, 255, 0.07);
  static const border = Color.fromRGBO(56, 81, 107, 0.7);

  @override
  Widget build(BuildContext context) => Semantics(
    label: '외 $hidden명',
    excludeSemantics: true,
    child: SizedBox(
      height: height,
      child: SkewBox(
        fill: fill,
        border: border,
        borderWidth: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            widthFactor: 1,
            child: Text(
              PortraitStrip.overflowLabel(hidden),
              maxLines: 1,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: AppType.bodySmallSize,
                height: 1.2,
                fontWeight: AppType.bold,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
