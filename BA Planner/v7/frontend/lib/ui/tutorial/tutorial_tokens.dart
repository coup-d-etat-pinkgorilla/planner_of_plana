// 튜토리얼 부품 공용 값 (F3a, 시안 W-Tutorial-Card · W-Plana-Dialogue, FD-182 · FD-183).
//
// 키트(`lib/ui/kit/**`)를 고치지 않는 slice라 튜토리얼에서만 쓰는 색 · 글자 · 선 아이콘을 여기에 둔다.
// 키트 승격 후보: 체크 · 깃발 선 아이콘(KitGlyph에 없음), 굵기 700 · 간격 5의 작은 tonal 버튼(TonalButton은
// 간격 8 · 굵기 600 고정), 강조 하늘색 빛 테두리.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_pressable.dart';

/// 강조 테두리 · 밝히기 테두리 색 #71c7f4(앱 기본 하늘색).
const tutorialHighlightColor = AppColors.primary;

/// 강조 테두리 두께 2.5px.
const tutorialHighlightStroke = 2.5;

/// 바깥 빛: 굵기 9 · 흐림 5 · 1.8초 숨쉬기(불투명도 .35 ↔ .9). 움직임 줄이기면 .6에 멈춘다.
const tutorialGlowStroke = 9.0;
const tutorialGlowBlur = 5.0;
const tutorialGlowPeriod = Duration(milliseconds: 1800);
const tutorialGlowMinOpacity = 0.35;
const tutorialGlowMaxOpacity = 0.9;
const tutorialGlowStillOpacity = 0.6;

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

/// 튜토리얼 선 아이콘(시안 svg, viewBox 24).
enum TutorialGlyph {
  /// 체크 `M5 12.5l4.5 4.5L19 7.5`(stroke 2.8).
  check,

  /// 깃발 `M5 21V4M5 4h11l-2 4 2 4H5`(stroke 1.9).
  flag,
}

/// [TutorialGlyph]를 상자 크기에 맞춰 그린다.
class TutorialGlyphPainter extends CustomPainter {
  const TutorialGlyphPainter({
    required this.glyph,
    required this.color,
    this.strokeWidth,
  });

  final TutorialGlyph glyph;
  final Color color;
  final double? strokeWidth;

  Path _path() => switch (glyph) {
    TutorialGlyph.check =>
      Path()
        ..moveTo(5, 12.5)
        ..lineTo(9.5, 17)
        ..lineTo(19, 7.5),
    TutorialGlyph.flag =>
      Path()
        ..moveTo(5, 21)
        ..lineTo(5, 4)
        ..moveTo(5, 4)
        ..lineTo(16, 4)
        ..lineTo(14, 8)
        ..lineTo(16, 12)
        ..lineTo(5, 12),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      _path(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            strokeWidth ?? (glyph == TutorialGlyph.check ? 2.8 : 1.9)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(TutorialGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// 그만두기 버튼(시안 `.tonal` + × 아이콘). 카드 30px · 대사 띠 40px · 진행 창 한 줄 26px.
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

  static const _fill = Color(0xff3a4b58);
  static const _hoverFill = Color(0xff455866);
  static const _foreground = Color(0xffd6e4f0);

  @override
  Widget build(BuildContext context) {
    final button = KitPressable(
      onPressed: onPressed,
      builder: (context, state) => Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: state.hovered ? _hoverFill : _fill,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadii.control),
          ),
          boxShadow: state.focused
              ? const [BoxShadow(color: kitFocusColor, spreadRadius: 1.5)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: iconSize,
              child: const CustomPaint(
                painter: KitGlyphPainter(
                  glyph: KitGlyph.close,
                  color: _foreground,
                ),
              ),
            ),
            SizedBox(width: gap),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tutorialText(fontSize, color: _foreground, height: 1.2),
            ),
          ],
        ),
      ),
    );
    return onPressed == null
        ? Opacity(opacity: kitDisabledOpacity, child: button)
        : button;
  }
}
