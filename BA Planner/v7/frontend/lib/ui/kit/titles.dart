// 제목·텍스트 (FE2-b, H §6.4, W-Layout "제목 3단계").
//
// - 패널 제목: 7×22 r2 핑크 사선 막대 + `.dsp` 19px + (오른쪽 칩) / 아래 1px 룰, 왼쪽 46×3 핑크 캡. 줄 사이 6.
// - 타일 제목: 6×18 막대 + `.dsp` 16px + (오른쪽 칩) / 룰 캡 40. 줄 사이 7.
//   룰 = rgba(113,199,244,.65) → .22(45%) → .06.
// - 소제목 `.ihdr`: 5×5 r1 #71c7f4 점 + 경기천년제목 8px(자리마다 9~11px) w800 #f4f8fb, 간격 4.
// - 키-값 `.kv`: 세로 간격 3, 라벨 `.cap` 11px w600 #9eb0c2.
// `.dsp` = 경기천년제목, 자간 −.01em. 시안 w800은 굵기 700으로 그린다(FD-009).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 시안 `.dsp` 글자(경기천년제목, 자간 −.01em).
TextStyle kitDisplayStyle(double fontSize, {Color color = AppColors.text}) =>
    TextStyle(
      fontFamily: AppFonts.display,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: fontSize,
      height: 1.2,
      letterSpacing: -0.01 * fontSize,
      color: color,
    );

final _titleSkew = Matrix4.skewX(-10 * math.pi / 180);

/// 제목 앞 핑크 사선 막대.
class TitleBar extends StatelessWidget {
  const TitleBar({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Transform(
    transform: _titleSkew,
    alignment: Alignment.center,
    child: SizedBox(
      width: width,
      height: height,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
    ),
  );
}

/// 제목 아래 1px 그라데이션 룰과 왼쪽 핑크 캡.
class TitleRule extends StatelessWidget {
  const TitleRule({super.key, this.capWidth = 40});

  final double capWidth;

  static const gradient = LinearGradient(
    colors: [
      Color.fromRGBO(113, 199, 244, 0.65),
      Color.fromRGBO(113, 199, 244, 0.22),
      Color.fromRGBO(113, 199, 244, 0.06),
    ],
    stops: [0, 0.45, 1],
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        ),
        Positioned(
          left: 0,
          top: -1,
          width: capWidth,
          height: 3,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 패널(섹션) 제목. [trailing]은 오른쪽 칩 자리다.
class PanelTitle extends StatelessWidget {
  const PanelTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const TitleBar(width: 7, height: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kitDisplayStyle(AppType.panelTitleSize),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing],
          ],
        ),
        const SizedBox(height: 6),
        const TitleRule(capWidth: 46),
      ],
    );
  }
}

/// 타일(위젯 카드) 안 제목. [trailing]은 오른쪽 칩 자리다.
class TileTitle extends StatelessWidget {
  const TileTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const TitleBar(width: 6, height: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kitDisplayStyle(AppType.titleSize),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 7),
        const TitleRule(),
      ],
    );
  }
}

/// 소제목(`.ihdr`): 파란 점 + 경기천년제목.
class SubHeader extends StatelessWidget {
  const SubHeader(
    this.text, {
    super.key,
    this.fontSize = AppType.indicatorHeaderSize,
  });

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        width: 5,
        height: 5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.all(Radius.circular(1)),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: fontSize,
          height: 1.2,
          fontWeight: AppType.bold,
          color: AppColors.text,
        ),
      ),
    ],
  );
}

/// 키-값(`.kv`): 위 라벨(`.cap` 11px), 아래 값.
class KV extends StatelessWidget {
  const KV({super.key, required this.label, required this.value});

  final String label;
  final Widget value;

  /// `.kv .cap` 글자.
  static const labelStyle = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppType.captionSize,
    height: 1.35,
    fontWeight: AppType.semiBold,
    color: AppColors.textMuted,
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: labelStyle),
      const SizedBox(height: 3),
      value,
    ],
  );
}
