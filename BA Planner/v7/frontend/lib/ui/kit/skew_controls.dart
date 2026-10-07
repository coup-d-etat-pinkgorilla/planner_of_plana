// 사선 세그먼트·토글 칩·타입 칩·필터 버튼·스위치 (FE2-b, H §6.3, W-Layout·W-Filter).
//
// 시안 값:
// - `.seg`: h36 padding 0 16, 세그먼트 사이 6, r5 skewX(−10°), 바탕 rgba(16,24,35,.9) + 1px rgba(158,176,194,.35),
//   13px w600 #c3cfdb. on = #3a2a44 + 1.5px #f2b3ef + #f7c9f4.
// - 토글 칩(aria-pressed): h30 padding 0 13, 간격 7, off = white@.05 + 안쪽 1px rgba(56,81,107,.9), 12.5px w500,
//   on = #f2b3ef@.2 + 안쪽 1.5px #f2b3ef, w700 #f7c9f4. 오른쪽 개수 10.5px #9eb0c2.
// - 타입 칩: 토글 칩 앞에 8×14 r2 사선 색 막대(공격·방어 타입 5색 = AppColors, FD-024).
// - 필터 버튼: h30 padding 0 12, 간격 6, 깔때기 14px + "필터" 12.5 bold. 적용 중이면 "필터 · n",
//   #f2b3ef@.16 + 안쪽 1.5px 핑크 + #f7c9f4, 아니면 white@.05 + 안쪽 1px rgba(90,110,130,.9).
// - `.tog`: 40×22 r11, off rgba(158,176,194,.25) + 손잡이 16 #c3cfdb(left 3), on #f2b3ef + 손잡이 #2a1330(left 21).
// 시안에 hover·비활성 규칙은 없다. 비활성은 키트 공통으로 불투명도 .45, 키보드 포커스는 파랑 테두리로 보인다
// (워커 결정, 시안 근거 없음). 포커스 중에는 선택된 칸도 테두리가 파랑이고, 선택은 채움·글자색으로 남는다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'kit_glyph.dart';
import 'kit_pressable.dart';
import 'skew_box.dart';

Widget _dimIfDisabled(bool enabled, Widget child) =>
    enabled ? child : Opacity(opacity: kitDisabledOpacity, child: child);

// ---------------------------------------------------------------------------
// SkewSegmented

/// 세그먼트 하나.
@immutable
class SkewSegment<T> {
  const SkewSegment({required this.value, required this.label, this.leading});

  final T value;
  final String label;
  final Widget? leading;
}

/// 사선 세그먼트(`.seg`). 고른 값은 핑크 테두리로 보인다.
class SkewSegmented<T> extends StatelessWidget {
  const SkewSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = AppControlHeights.segmented,
    this.fontSize = AppType.bodySize,
    this.horizontalPadding = 16,
    this.spacing = 6,
  });

  final List<SkewSegment<T>> segments;
  final T? selected;

  /// `null`이면 비활성.
  final ValueChanged<T>? onChanged;
  final double height;
  final double fontSize;
  final double horizontalPadding;
  final double spacing;

  /// 세그먼트 바탕 색(시안 `rgba(16,24,35,.9)` / on `#3a2a44`).
  static final idleFill = AppColors.rowSurface.withValues(alpha: 0.9);
  static const selectedFill = Color(0xff3a2a44);
  static final idleBorder = AppColors.textMuted.withValues(alpha: 0.35);

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return _dimIfDisabled(
      onChanged != null,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < segments.length; index++)
            Padding(
              padding: EdgeInsets.only(
                right: index == segments.length - 1 ? 0 : spacing,
              ),
              child: _SkewSegmentButton<T>(
                segment: segments[index],
                selected: segments[index].value == selected,
                onPressed: onChanged == null
                    ? null
                    : () => onChanged(segments[index].value),
                height: height,
                fontSize: fontSize,
                horizontalPadding: horizontalPadding,
              ),
            ),
        ],
      ),
    );
  }
}

class _SkewSegmentButton<T> extends StatelessWidget {
  const _SkewSegmentButton({
    required this.segment,
    required this.selected,
    required this.onPressed,
    required this.height,
    required this.fontSize,
    required this.horizontalPadding,
  });

  final SkewSegment<T> segment;
  final bool selected;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) => KitPressable(
    onPressed: onPressed,
    selected: selected,
    builder: (context, state) {
      final color = selected ? AppColors.accentText : AppColors.textSecondary;
      final leading = segment.leading;
      return SizedBox(
        height: height,
        child: SkewBox(
          fill: selected
              ? SkewSegmented.selectedFill
              : SkewSegmented.idleFill,
          border: state.focused
              ? kitFocusColor
              : selected
              ? AppColors.accent
              : SkewSegmented.idleBorder,
          borderWidth: selected ? 1.5 : 1,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 6)],
                Text(
                  segment.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: fontSize,
                    height: 1.2,
                    fontWeight: AppType.semiBold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// SkewToggleChip / TypeChip

/// 사선 토글 칩(필터 팝업). [count]는 오른쪽 개수(해당 학생 수)다.
class SkewToggleChip extends StatelessWidget {
  const SkewToggleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.count,
    this.leading,
    this.focusNode,
  });

  final String label;
  final bool selected;

  /// `null`이면 비활성.
  final ValueChanged<bool>? onChanged;
  final int? count;
  final Widget? leading;
  final FocusNode? focusNode;

  static final idleFill = Colors.white.withValues(alpha: 0.05);
  static final idleBorder = AppColors.outline.withValues(alpha: 0.9);
  static final selectedFill = AppColors.accent.withValues(alpha: 0.2);

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final leading = this.leading;
    final count = this.count;
    return _dimIfDisabled(
      onChanged != null,
      KitPressable(
        onPressed: onChanged == null ? null : () => onChanged(!selected),
        focusNode: focusNode,
        toggled: selected,
        builder: (context, state) => SizedBox(
          height: AppControlHeights.toggleChip,
          child: SkewBox(
            fill: selected ? selectedFill : idleFill,
            border: state.focused
                ? kitFocusColor
                : selected
                ? AppColors.accent
                : idleBorder,
            borderWidth: selected ? 1.5 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading, const SizedBox(width: 7)],
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: AppType.popoverBodySize,
                      height: 1.2,
                      fontWeight: selected ? AppType.bold : AppType.medium,
                      color: selected ? AppColors.accentText : AppColors.text,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 7),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: AppType.microPlusSize,
                        height: 1.2,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 공격·방어 타입 칩: 토글 칩 + 8×14 사선 색 막대. 색만으로 구분하지 않게 이름을 항상 쓴다.
class TypeChip extends StatelessWidget {
  const TypeChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onChanged,
    this.count,
    this.focusNode,
  });

  final String label;

  /// `AppColors.typeExplosive` 등 타입 색(FD-024).
  final Color color;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final int? count;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => SkewToggleChip(
    label: label,
    selected: selected,
    onChanged: onChanged,
    count: count,
    focusNode: focusNode,
    leading: TypeColorBar(color: color),
  );
}

/// 타입 칩 앞 막대(8×14, r2, skewX −10°).
class TypeColorBar extends StatelessWidget {
  const TypeColorBar({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Transform(
    transform: Matrix4.skewX(-10 * math.pi / 180),
    alignment: Alignment.center,
    child: SizedBox(
      width: 8,
      height: 14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// FilterButton

/// 필터 버튼. [activeCount]가 0보다 크면 "필터 · n"과 핑크로 보인다.
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.activeCount,
    required this.onPressed,
    this.label = '필터',
    this.focusNode,
  });

  final int activeCount;
  final VoidCallback? onPressed;
  final String label;
  final FocusNode? focusNode;

  static const idleBorder = Color.fromRGBO(90, 110, 130, 0.9);
  static final activeFill = AppColors.accent.withValues(alpha: 0.16);

  @override
  Widget build(BuildContext context) {
    final active = activeCount > 0;
    final color = active ? AppColors.accentText : AppColors.text;
    return _dimIfDisabled(
      onPressed != null,
      KitPressable(
        onPressed: onPressed,
        focusNode: focusNode,
        builder: (context, state) => SizedBox(
          height: AppControlHeights.toggleChip,
          child: SkewBox(
            fill: active
                ? activeFill
                : SkewToggleChip.idleFill,
            border: state.focused
                ? kitFocusColor
                : active
                ? AppColors.accent
                : idleBorder,
            borderWidth: active ? 1.5 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CustomPaint(
                      painter: KitGlyphPainter(
                        glyph: KitGlyph.filter,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    active ? '$label · $activeCount' : label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: AppType.popoverBodySize,
                      height: 1.2,
                      fontWeight: AppType.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BaSwitch

/// 소형 토글 스위치(`.tog`, 40×22).
class BaSwitch extends StatelessWidget {
  const BaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.focusNode,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final FocusNode? focusNode;

  static const width = 40.0;
  static final idleTrack = AppColors.textMuted.withValues(alpha: 0.25);

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return _dimIfDisabled(
      onChanged != null,
      KitPressable(
        onPressed: onChanged == null ? null : () => onChanged(!value),
        focusNode: focusNode,
        toggled: value,
        semanticLabel: semanticLabel,
        builder: (context, state) => AnimatedContainer(
          duration: AppMotion.tab,
          curve: Curves.easeOutCubic,
          width: width,
          height: AppControlHeights.toggle,
          decoration: BoxDecoration(
            color: value ? AppColors.accent : idleTrack,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadii.toggle),
            ),
            boxShadow: state.focused
                ? const [BoxShadow(color: kitFocusColor, spreadRadius: 1.5)]
                : null,
          ),
          child: AnimatedAlign(
            duration: AppMotion.tab,
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: SizedBox(
                width: 16,
                height: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: value ? AppColors.onAccent : AppColors.textSecondary,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
