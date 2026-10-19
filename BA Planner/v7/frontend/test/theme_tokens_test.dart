import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/widgets/diagonal_media_list_item.dart';
import 'package:ba_planner_v7/ui/widgets/plan_preset_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// FE1-a(동작 보존) 계약: 토큰은 토큰화 전에 하드코딩되어 있던 값과 정확히 같다.
// 이 테스트가 실패하면 토큰 값이 바뀐 것이므로 화면 결과도 바뀐다.
void main() {
  test('color tokens keep the previously hardcoded and prototype values', () {
    expect(AppColors.accent, const Color(0xfff2b3ef));
    expect(AppColors.accentText, const Color(0xfff7c9f4));
    expect(AppColors.onAccent, const Color(0xff2a1330));
    expect(AppColors.scrollThumb, const Color(0xffe5a0ea));
    expect(AppColors.textSecondary, const Color(0xffc3cfdb));
    expect(AppColors.textDim, const Color(0xff6f8397));
    expect(AppColors.popover, const Color(0xff0d151f));
    expect(AppColors.rowSurface, const Color(0xff101823));
    expect(AppColors.indicatorSurface, const Color(0xff203243));
    expect(AppColors.scrim, const Color(0xff060a10));
    expect(AppColors.starDisplay, const Color(0xfff3c96b));
    expect(AppColors.starFilter, const Color(0xffe8c15a));
    expect(AppColors.typeExplosive, const Color(0xff920008));
    expect(AppColors.typePiercing, const Color(0xffbd8901));
    expect(AppColors.typeMystic, const Color(0xff226f9b));
    expect(AppColors.typeSonic, const Color(0xff9945a8));
    expect(AppColors.typeComposite, const Color(0xff7a8ea3));

    expect(diagonalMediaHighlightColor, const Color(0xfff2b3ef));
    expect(planPresetButtonHoverColor, const Color(0x33f2b3ef));
    expect(planPresetButtonPressedColor, const Color(0x4df2b3ef));
    expect(AppTextStyles.planPhaseNumber.color, const Color(0xfff2b3ef));
    expect(AppTextStyles.planPhaseNumber.fontSize, 17);
  });

  test('chip tones match the prototype .chip pairs', () {
    expect(AppTones.all, hasLength(6));
    expect(AppTones.info.foreground, const Color(0xffa8e0ff));
    expect(AppTones.pink.foreground, const Color(0xfff7c9f4));
    expect(AppTones.ok.foreground, const Color(0xff7fe3bd));
    expect(AppTones.warn.foreground, const Color(0xffffd08a));
    expect(AppTones.danger.foreground, const Color(0xffffa0a8));
    expect(AppTones.gray.foreground, const Color(0xffc3cfdb));
    expect(AppTones.pink.backgroundAlpha, 0.2);
    expect(AppTones.gray.backgroundAlpha, 0.14);
    for (final tone in [
      AppTones.info,
      AppTones.ok,
      AppTones.warn,
      AppTones.danger,
    ]) {
      expect(tone.backgroundAlpha, 0.16);
    }
  });

  test('motion, radius and control height tokens keep existing values', () {
    expect(AppMotion.section, const Duration(milliseconds: 360));
    expect(AppMotion.shell, const Duration(milliseconds: 460));
    expect(AppMotion.tabBody, const Duration(milliseconds: 970));
    expect(
      AppMotion.tabBodyPull +
          AppMotion.tabBodyExit +
          AppMotion.tabBodyEnter +
          AppMotion.tabBodySettle,
      AppMotion.tabBody,
    );
    expect(AppMotion.header, const Duration(milliseconds: 220));
    expect(AppMotion.tab, const Duration(milliseconds: 180));
    expect(AppMotion.sectionCurve, Curves.easeInOutCubic);
    expect(AppMotion.entranceCurve, Curves.easeOutCubic);

    expect(planPresetManagerMotionDuration, AppMotion.section);

    expect(AppRadii.section, 14);
    expect(AppRadii.control, 10);
    expect(AppRadii.tooltip, 8);
    expect(AppControlHeights.tab, 44);
  });
}
