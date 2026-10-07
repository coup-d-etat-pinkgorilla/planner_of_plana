// 수치 조절: 스테퍼·MAX 배지·스텝 버튼·미세 조절 (FE2-b, H §6.3).
//
// [BaStepper]·[MaxBadge]·[StepButton]은 `plan_element_builder.dart`의 `_CompactTargetStepper`·`_MaxBadge`·
// `_StepTextButton`을 그대로 옮긴 것이다(동작 보존, 요소 빌더 golden 차이 0이 조건).
// 기본값은 지금 요소 빌더 렌더다. 시안 `.stp`와 다른 점은 파라미터로 골라 쓴다.
// - 시안 `.stp`: 22×24 r14, 16.5px w800 #9eb0c2, hover rgba(255,255,255,.08) + #f4f8fb.
//   지금 렌더는 활성 #f4f8fb·비활성 #9eb0c2이고 Material ink를 쓴다([StepButtonLook.planBuilder]).
// - 시안 스테퍼(UI-Elements): 라벨 13.5px w700 #9eb0c2가 위에 있고, 값 25.2 w800은 최소 폭 40으로 가운데 정렬,
//   전파 표시는 rgba(113,199,244,.22) r5 padding 2 4. 지금 렌더는 라벨이 값 왼쪽에 붙는다([BaStepperLayout.inline]).
// - MAX 배지는 시안과 같다(min 28×11 r8, 7.5px w800, 활성 #71c7f4@.3 + .8px @.72, 비활성 #243448@.3 + #9eb0c2@.24).
// 이름: Material `Stepper`와 겹치지 않게 `BaStepper`로 한다.
//
// [NudgeButtons]는 시안 `.nd`(Flow-2-Goals): 18×13 r3 rgba(113,199,244,.1) #9eb0c2, hover rgba(242,179,239,.25) #f2b3ef,
// 꺾쇠 11px, 위아래 간격 1.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'kit_glyph.dart';
import 'kit_pressable.dart';

/// 스텝 버튼 모양.
enum StepButtonLook {
  /// 지금 요소 빌더 렌더: 활성 흰색·비활성 회색 글자, Material ink(반경 14).
  planBuilder,

  /// 시안 `.stp`: 평소 회색, hover 때 흰 글자 + rgba(255,255,255,.08) 원.
  prototype,
}

/// 스테퍼 배치.
enum BaStepperLayout {
  /// 지금 요소 빌더 렌더: `− 라벨 값 +` 한 줄, 아래 MAX 배지.
  inline,

  /// 시안 UI-Elements: 라벨이 위, `− 값 +`가 아래.
  labelAbove,
}

/// 22×24 스텝 버튼(`−`·`+`).
class StepButton extends StatelessWidget {
  const StepButton({
    super.key,
    required this.text,
    required this.enabled,
    required this.onTap,
    this.look = StepButtonLook.planBuilder,
    this.hovered,
    this.semanticLabel,
  });

  final String text;
  final bool enabled;
  final VoidCallback onTap;
  final StepButtonLook look;

  /// 시안 모양에서 hover 상태를 고정한다(갤러리 견본용). [StepButtonLook.planBuilder]는
  /// 지금 렌더를 그대로 두기 위해 [hovered]·[semanticLabel]을 쓰지 않는다.
  final bool? hovered;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => switch (look) {
    StepButtonLook.planBuilder => InkResponse(
      onTap: enabled ? onTap : null,
      radius: 14,
      child: SizedBox(
        width: 22,
        height: 24,
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: enabled ? AppColors.text : AppColors.textMuted,
              fontFamily: 'GyeonggiTitle',
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    ),
    StepButtonLook.prototype => Opacity(
      opacity: enabled ? 1 : kitDisabledOpacity,
      child: KitPressable(
        onPressed: enabled ? onTap : null,
        hovered: hovered,
        semanticLabel: semanticLabel,
        builder: (context, state) => Container(
          width: 22,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: state.hovered || state.focused
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: state.hovered || state.focused
                  ? AppColors.text
                  : AppColors.textMuted,
              fontFamily: AppFonts.display,
              fontSize: AppType.stepperGlyphSize,
              fontWeight: AppType.bold,
              height: 1,
            ),
          ),
        ),
      ),
    ),
  };
}

/// 목표 값 스테퍼. [key]가 `ValueKey<String>`이면 그 값이 하위 키 접두사가 된다
/// (`<key>-decrease`, `-label`, `-value`, `-increase`, `-max`).
class BaStepper extends StatelessWidget {
  const BaStepper({
    super.key,
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.propagated,
    required this.unsupported,
    required this.valueFontSize,
    required this.onChanged,
    this.layout = BaStepperLayout.inline,
    this.showMaxBadge = true,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;

  /// 앞 단계에서 이어받은 값(파란 바탕).
  final bool propagated;

  /// 계산이 아직 지원하지 않는 값(`*` 표시).
  final bool unsupported;
  final double valueFontSize;
  final ValueChanged<int> onChanged;
  final BaStepperLayout layout;
  final bool showMaxBadge;

  @override
  Widget build(BuildContext context) {
    final controlKey = key is ValueKey<String>
        ? (key! as ValueKey<String>).value
        : label;
    if (layout == BaStepperLayout.labelAbove) {
      return _labelAbove(controlKey);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: propagated
            ? AppColors.primary.withValues(alpha: 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StepButton(
                  key: ValueKey('$controlKey-decrease'),
                  text: '−',
                  enabled: value > minimum,
                  onTap: () => onChanged(value - 1),
                ),
                if (label.isNotEmpty) ...[
                  Text(
                    label,
                    key: ValueKey('$controlKey-label'),
                    style: TextStyle(
                      fontFamily: 'GyeonggiTitle',
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  '$value${unsupported ? '*' : ''}',
                  key: ValueKey('$controlKey-value'),
                  style: TextStyle(
                    fontFamily: 'GyeonggiTitle',
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                StepButton(
                  key: ValueKey('$controlKey-increase'),
                  text: '+',
                  enabled: value < maximum,
                  onTap: () => onChanged(value + 1),
                ),
              ],
            ),
            if (showMaxBadge)
              MaxBadge(
                controlKey: controlKey,
                enabled: value < maximum,
                onTap: () => onChanged(maximum),
              ),
          ],
        ),
      ),
    );
  }

  Widget _labelAbove(String controlKey) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: propagated
          ? AppColors.primary.withValues(alpha: 0.22)
          : Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(5)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            key: ValueKey('$controlKey-label'),
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.bodyPlusSize,
              height: 1.2,
              fontWeight: AppType.bold,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StepButton(
              key: ValueKey('$controlKey-decrease'),
              text: '−',
              enabled: value > minimum,
              onTap: () => onChanged(value - 1),
              look: StepButtonLook.prototype,
              semanticLabel: '$label 낮추기',
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40),
              child: Text(
                '$value${unsupported ? '*' : ''}',
                key: ValueKey('$controlKey-value'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: valueFontSize,
                  fontWeight: AppType.bold,
                  height: 1.1,
                  color: AppColors.text,
                ),
              ),
            ),
            StepButton(
              key: ValueKey('$controlKey-increase'),
              text: '+',
              enabled: value < maximum,
              onTap: () => onChanged(value + 1),
              look: StepButtonLook.prototype,
              semanticLabel: '$label 올리기',
            ),
          ],
        ),
        if (showMaxBadge) ...[
          const SizedBox(height: 3),
          MaxBadge(
            controlKey: controlKey,
            enabled: value < maximum,
            onTap: () => onChanged(maximum),
          ),
        ],
      ],
    ),
  );
}

/// MAX 배지(최대값으로 올리기). 키는 `<controlKey>-max`.
class MaxBadge extends StatelessWidget {
  const MaxBadge({
    super.key,
    required this.controlKey,
    required this.enabled,
    required this.onTap,
  });

  final String controlKey;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: '최대값',
    child: InkWell(
      key: ValueKey('$controlKey-max'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 28, minHeight: 11),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.surfaceRaised.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.72)
                : AppColors.textMuted.withValues(alpha: 0.24),
            width: 0.8,
          ),
        ),
        child: Text(
          'MAX',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: enabled ? AppColors.text : AppColors.textMuted,
            fontFamily: 'GyeonggiTitle',
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

/// 미세 조절 ▲▼(`.nd`). 값 옆에 붙인다.
class NudgeButtons extends StatelessWidget {
  const NudgeButtons({
    super.key,
    required this.onIncrease,
    required this.onDecrease,
    this.increaseLabel = '올리기',
    this.decreaseLabel = '낮추기',
    this.hovered,
  });

  /// `null`이면 그 버튼은 비활성.
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final String increaseLabel;
  final String decreaseLabel;

  /// 두 버튼의 hover 상태를 고정한다(갤러리 견본용).
  final bool? hovered;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _NudgeButton(
        glyph: KitGlyph.chevronUp,
        onPressed: onIncrease,
        semanticLabel: increaseLabel,
        hovered: hovered,
      ),
      const SizedBox(height: 1),
      _NudgeButton(
        glyph: KitGlyph.chevronDown,
        onPressed: onDecrease,
        semanticLabel: decreaseLabel,
        hovered: hovered,
      ),
    ],
  );
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.glyph,
    required this.onPressed,
    required this.semanticLabel,
    required this.hovered,
  });

  final KitGlyph glyph;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool? hovered;

  static final idleFill = AppColors.primary.withValues(alpha: 0.1);
  static final hoverFill = AppColors.accent.withValues(alpha: 0.25);

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? kitDisabledOpacity : 1,
    child: KitPressable(
      onPressed: onPressed,
      hovered: hovered,
      semanticLabel: semanticLabel,
      builder: (context, state) {
        final active = state.hovered || state.focused;
        return Container(
          width: 18,
          height: 13,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? hoverFill : idleFill,
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
          child: SizedBox(
            width: 11,
            height: 11,
            child: CustomPaint(
              painter: KitGlyphPainter(
                glyph: glyph,
                color: active ? AppColors.accent : AppColors.textMuted,
              ),
            ),
          ),
        );
      },
    ),
  );
}
