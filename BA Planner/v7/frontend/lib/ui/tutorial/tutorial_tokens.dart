// 튜토리얼 부품 공용 값 (F3a, 시안 W-Tutorial-Card · W-Plana-Dialogue, FD-182 · FD-183).
//
// 튜토리얼에서만 쓰는 색 · 글자를 여기에 둔다. K2: 선 아이콘 · 그만두기 버튼 · 강조 값은 K1 키트(`KitGlyph` ·
// `TonalButton` · `kitFocusRing*`)로 옮겼고, 여기 이름은 사용처를 그대로 두는 얇은 별칭이다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../kit/buttons.dart';
import '../kit/focus_ring.dart';
import '../kit/kit_glyph.dart';

/// 강조 테두리 · 밝히기 테두리 색 #71c7f4([kitFocusRingColor]의 별칭).
const tutorialHighlightColor = kitFocusRingColor;

/// 강조 테두리 두께 2.5px([kitFocusRingStroke]의 별칭).
const tutorialHighlightStroke = kitFocusRingStroke;

/// 바깥 빛: 굵기 9 · 흐림 5 · 1.8초 숨쉬기(불투명도 .35 ↔ .9). 움직임 줄이기면 .6에 멈춘다(`kitFocusGlow*`의 별칭).
const tutorialGlowStroke = kitFocusGlowStroke;
const tutorialGlowBlur = kitFocusGlowBlur;
const tutorialGlowPeriod = kitFocusGlowPeriod;
const tutorialGlowMinOpacity = kitFocusGlowMinOpacity;
const tutorialGlowMaxOpacity = kitFocusGlowMaxOpacity;
const tutorialGlowStillOpacity = kitFocusGlowStillOpacity;

/// 단계 카드 바탕 #0f1a26 · 테두리 rgba(113,199,244,.55).
const tutorialCardFill = Color(0xff0f1a26);
const tutorialCardOutline = Color.fromRGBO(113, 199, 244, 0.55);

/// 카드 n / m · 머리글 칩 글자 #a8e0ff.
const tutorialInfoText = Color(0xffa8e0ff);

/// 완료 체크 초록 #7fe3bd.
const tutorialCheckColor = Color(0xff7fe3bd);

/// 얼굴 칩 바탕 #e9eef5 · 안쪽 분홍 링 1.5px rgba(242,179,239,.85).
const tutorialFaceFill = Color(0xffe9eef5);
const tutorialFaceRing = Color.fromRGBO(242, 179, 239, 0.85);

/// 대사 장면 어둡게: 검정 64%(시안 rgba(5,9,15,.64)).
const planaDimColor = Color.fromRGBO(5, 9, 15, 0.64);

/// 움직임 줄이기 설정을 읽는다(없으면 false).
bool tutorialReduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// 본문 글자(Pretendard).
TextStyle tutorialText(
  double size, {
  Color color = AppColors.text,
  FontWeight weight = AppType.bold,
  double height = 1.3,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: height,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
);

/// 제목 글꼴(경기천년제목, `.dsp` w500).
TextStyle tutorialDisplay(double size, {Color color = AppColors.text}) =>
    TextStyle(
      fontFamily: AppFonts.display,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: size,
      height: 1,
      fontWeight: AppType.medium,
      letterSpacing: -0.01 * size,
      color: color,
    );

/// 튜토리얼 체크 굵기(시안 stroke 2.8 — 키트 기본 1.9보다 굵다).
const tutorialCheckStroke = 2.8;

/// 튜토리얼 선 아이콘(시안 svg, viewBox 24). K2: 그림은 키트 [KitGlyph](같은 path)이고, 이 이름은 얇은 별칭이다.
enum TutorialGlyph {
  /// 체크 `M5 12.5l4.5 4.5L19 7.5`(stroke 2.8).
  check(KitGlyph.check, tutorialCheckStroke),

  /// 깃발 `M5 21V4M5 4h11l-2 4 2 4H5`(stroke 1.9).
  flag(KitGlyph.flag, kitGlyphStroke);

  const TutorialGlyph(this.kit, this.strokeWidth);

  /// 그릴 키트 글리프.
  final KitGlyph kit;

  /// 기본 굵기(24 단위).
  final double strokeWidth;
}

/// [KitGlyphPainter]를 감싼 별칭(굵기가 없으면 [TutorialGlyph.strokeWidth] — 체크 2.8 · 깃발 1.9).
class TutorialGlyphPainter extends CustomPainter {
  const TutorialGlyphPainter({
    required this.glyph,
    required this.color,
    this.strokeWidth,
  });

  final TutorialGlyph glyph;
  final Color color;
  final double? strokeWidth;

  @override
  void paint(Canvas canvas, Size size) => KitGlyphPainter(
    glyph: glyph.kit,
    color: color,
    strokeWidth: strokeWidth ?? glyph.strokeWidth,
  ).paint(canvas, size);

  @override
  bool shouldRepaint(TutorialGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// 그만두기 버튼(시안 `.tonal` + × 아이콘). 카드 30px · 대사 띠 40px · 진행 창 한 줄 26px.
/// K2: 키트 [TonalButton](앞 아이콘 [KitGlyphIcon] ×, 굵기 700)에 세 크기 값을 주는 얇은 감싸기다.
class TutorialQuitButton extends StatelessWidget {
  const TutorialQuitButton({
    super.key,
    required this.onPressed,
    this.height = 30,
    this.horizontalPadding = 12,
    this.gap = 5,
    this.fontSize = AppType.popoverBodySize,
    this.iconSize = 13,
    this.label = '그만두기',
  });

  /// 대사 띠 크기(40px, 패딩 16, 간격 7, 13.5px, 아이콘 15).
  const TutorialQuitButton.band({super.key, required this.onPressed})
    : height = 40,
      horizontalPadding = 16,
      gap = 7,
      fontSize = AppType.bodyPlusSize,
      iconSize = 15,
      label = '그만두기';

  /// 진행 창 한 줄 크기(26px, 패딩 9, 간격 4, 11.5px, 아이콘 12).
  const TutorialQuitButton.inline({super.key, required this.onPressed})
    : height = 26,
      horizontalPadding = 9,
      gap = 4,
      fontSize = AppType.captionPlusSize,
      iconSize = 12,
      label = '그만두기';

  final VoidCallback? onPressed;
  final double height;
  final double horizontalPadding;
  final double gap;
  final double fontSize;
  final double iconSize;
  final String label;

  @override
  Widget build(BuildContext context) => TonalButton(
    label: label,
    onPressed: onPressed,
    leading: KitGlyphIcon(
      KitGlyph.close,
      size: iconSize,
      color: TonalButtonColors.of(TonalButtonVariant.normal).foreground,
    ),
    height: height,
    horizontalPadding: horizontalPadding,
    gap: gap,
    fontWeight: AppType.bold,
    fontSize: fontSize,
  );
}
