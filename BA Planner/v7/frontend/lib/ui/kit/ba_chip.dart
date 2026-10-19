// 칩·단계 태그 (FE2-b, H §6.4).
//
// `.chip`: h24, padding 0 10, r7, 12px w700, 6색 역할 고정(정보·강조·충분·주의·위험·보조 = [AppTones]).
// 제거 칩: 같은 칩 + 오른쪽 × 11px(W-Filter "적용 중 필터").
// 테두리 변형([BaChipShape.outlined], FE3-d1): S4 적용 필터 칩(W-Student-Search) h24, padding 0 9, r5, 간격 5,
// 안쪽 1px 테두리(tone 기본색 @.6), × 불투명도 .8. 필터 모달 머리 칩은 시안 `.chip.pk`라 기본 모양이다.
// 단계 태그: h24 r5 사선, 1단계 파랑 · 2단계 핑크 · 3단계 노랑. 지금 보는 단계 = 원색 채움 + #1a1f2a 글자.
// `.chip.solid`는 시안에서 쓰지 않아 만들지 않는다(FD-014).
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'kit_glyph.dart';
import 'kit_pressable.dart';
import 'skew_box.dart';

/// 칩 글자(12px, 시안 w700).
const baChipTextStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
  fontWeight: AppType.bold,
);

/// 칩 모양.
enum BaChipShape {
  /// 시안 `.chip`: r7, 좌우 10, 간격 6, 테두리 없음.
  standard(radius: AppRadii.chip, padding: 10, gap: 6, borderAlpha: 0, removeAlpha: 1),

  /// S4 적용 필터 칩(W-Student-Search): r5, 좌우 9, 간격 5, 안쪽 1px 테두리 @.6, × @.8.
  outlined(radius: 5, padding: 9, gap: 5, borderAlpha: 0.6, removeAlpha: 0.8);

  const BaChipShape({
    required this.radius,
    required this.padding,
    required this.gap,
    required this.borderAlpha,
    required this.removeAlpha,
  });

  final double radius;

  /// 좌우 안쪽 여백.
  final double padding;

  /// 앞 아이콘·글자·× 사이.
  final double gap;

  /// 안쪽 테두리 알파(tone 기본색). 0이면 테두리 없음.
  final double borderAlpha;

  /// × 기본 알파.
  final double removeAlpha;
}

/// × 크기.
const baChipRemoveSize = 11.0;

/// 시안 `.chip`. [tone]은 [AppTones]의 6색 중 하나다.
///
/// [onRemove]가 있으면 오른쪽에 × 버튼이 붙는다(제거 칩). [leading]은 앞 아이콘 자리(12px)다.
class BaChip extends StatelessWidget {
  const BaChip({
    super.key,
    required this.label,
    this.tone = AppTones.info,
    this.leading,
    this.onRemove,
    this.removeLabel,
    this.shape = BaChipShape.standard,
  });

  final String label;
  final AppTone tone;
  final Widget? leading;
  final VoidCallback? onRemove;

  /// × 버튼의 접근성 이름. 없으면 "`label` 빼기".
  final String? removeLabel;
  final BaChipShape shape;

  /// 앞 아이콘 없는 칩의 폭(글자 폭은 [baChipTextStyle]로 잰다). 한 줄에 칩이 몇 개 들어가는지 셀 때 쓴다.
  static double widthFor(
    String label, {
    required TextScaler textScaler,
    bool removable = false,
    BaChipShape shape = BaChipShape.standard,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: baChipTextStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final text = painter.width.ceilToDouble() + 1;
    painter.dispose();
    return text +
        shape.padding * 2 +
        (removable ? shape.gap + baChipRemoveSize : 0);
  }

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final onRemove = this.onRemove;
    return Container(
      height: AppControlHeights.chip,
      padding: EdgeInsets.symmetric(horizontal: shape.padding),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.all(Radius.circular(shape.radius)),
      ),
      // 시안 `box-shadow: inset`처럼 자리를 차지하지 않게 테두리는 위에 그린다.
      foregroundDecoration: shape.borderAlpha > 0
          ? BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(shape.radius)),
              border: Border.all(
                color: tone.base.withValues(alpha: shape.borderAlpha),
              ),
            )
          : null,
      child: IconTheme.merge(
        data: IconThemeData(color: tone.foreground, size: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, SizedBox(width: shape.gap)],
            Text(
              label,
              maxLines: 1,
              style: baChipTextStyle.copyWith(color: tone.foreground),
            ),
            if (onRemove != null) ...[
              SizedBox(width: shape.gap),
              KitPressable(
                onPressed: onRemove,
                semanticLabel: removeLabel ?? '$label 빼기',
                builder: (context, state) => SizedBox(
                  width: baChipRemoveSize,
                  height: baChipRemoveSize,
                  child: CustomPaint(
                    painter: KitGlyphPainter(
                      glyph: KitGlyph.close,
                      color: state.hovered || state.focused
                          ? AppColors.text
                          : tone.foreground.withValues(
                              alpha: tone.foreground.a * shape.removeAlpha,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 단계 태그(1~3단계). [selected] = 지금 보는 단계.
class StageTag extends StatelessWidget {
  const StageTag({
    super.key,
    required this.stage,
    this.selected = false,
    this.label,
  });

  /// 1, 2, 3. 범위 밖이면 3단계 색을 쓴다.
  final int stage;
  final bool selected;

  /// 없으면 "`stage`단계".
  final String? label;

  /// 단계 색: 1 파랑, 2 핑크, 3 노랑.
  static Color colorOf(int stage) => switch (stage) {
    1 => AppColors.primary,
    2 => AppColors.accent,
    _ => AppColors.warning,
  };

  /// 선택된 태그의 글자색(시안 `#1a1f2a`).
  static const selectedText = Color(0xff1a1f2a);

  @override
  Widget build(BuildContext context) {
    final color = colorOf(stage);
    return SizedBox(
      height: AppControlHeights.chip,
      child: SkewBox(
        fill: selected ? color : color.withValues(alpha: 0.16),
        border: color.withValues(alpha: 0.55),
        borderWidth: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Center(
            widthFactor: 1,
            child: Text(
              label ?? '$stage단계',
              maxLines: 1,
              style: baChipTextStyle.copyWith(
                color: selected ? selectedText : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
