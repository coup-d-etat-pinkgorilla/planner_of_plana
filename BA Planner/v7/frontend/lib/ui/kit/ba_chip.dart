// 칩·단계 태그 (FE2-b, H §6.4).
//
// `.chip`: h24, padding 0 10, r7, 12px w700, 6색 역할 고정(정보·강조·충분·주의·위험·보조 = [AppTones]).
// 제거 칩: 같은 칩 + 오른쪽 × 11px(W-Filter "적용 중 필터").
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
  });

  final String label;
  final AppTone tone;
  final Widget? leading;
  final VoidCallback? onRemove;

  /// × 버튼의 접근성 이름. 없으면 "`label` 빼기".
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final onRemove = this.onRemove;
    return Container(
      height: AppControlHeights.chip,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.chip)),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: tone.foreground, size: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 6)],
            Text(
              label,
              maxLines: 1,
              style: baChipTextStyle.copyWith(color: tone.foreground),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              KitPressable(
                onPressed: onRemove,
                semanticLabel: removeLabel ?? '$label 빼기',
                builder: (context, state) => SizedBox(
                  width: 11,
                  height: 11,
                  child: CustomPaint(
                    painter: KitGlyphPainter(
                      glyph: KitGlyph.close,
                      color: state.hovered || state.focused
                          ? AppColors.text
                          : tone.foreground,
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
