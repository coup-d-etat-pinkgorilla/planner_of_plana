// UI Kit 갤러리 — 키트 승격 1차(K1, F3a 키트 승격 후보 1~6 · F3d 발견 9).
//
// 튜토리얼 · 빈 상태 · 계정 추가 모달에서 올린 부품의 견본이다. 원본 화면의 쓰임새(크기 · 색)대로 놓는다.
// - 선 아이콘: [KitGlyph] 전부(체크는 1.9 · 튜토리얼 2.8 두 굵기).
// - tonal 버튼: 기본(간격 8 · 600 · 아이콘 16)과 튜토리얼 그만두기 세 크기(카드 30 · 대사 띠 40 · 진행 창 26, 간격 5/7/4 · 700).
// - 강조 테두리: 평행사변형 · 둥근 사각형 대상. 도는 표시: 16 · 24.
// - 칩: 기본 칩과 링 변형(튜토리얼 머리글 칩 26 · 깃발 13).
// - 평행사변형 패널 버튼: 계정 추가 모달 닫기 · 취소 · 만들기(130×56).
// 숨쉬는 빛 · 도는 표시는 갤러리에서 움직임 줄이기로 멈춘 모습(빛 .6)을 보인다(갤러리 시험이 화면이 멈출 때까지 기다린다).
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../geometry/diagonal_geometry.dart';
import '../../widgets/ba_triangle_background.dart'
    show titlePrimaryActionTexture;
import '../ba_chip.dart';
import '../buttons.dart';
import '../diagonal_row.dart';
import '../focus_ring.dart';
import '../kit_glyph.dart';
import '../kit_spinner.dart';
import '../panel_button.dart';
import '../titles.dart';

const _contentWidth = 2480.0;
const _rowHeight = 300.0;

/// 타일 하단 설명(11.5px).
const _tileCaption = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionPlusSize,
  height: 1.5,
  color: AppColors.textMuted,
);

/// 튜토리얼 머리글 칩 색(하늘 @.18, 글자 #a8e0ff).
const _headerChipTone = AppTone(
  base: AppColors.primary,
  backgroundAlpha: 0.18,
  foreground: Color(0xffa8e0ff),
);

/// 키트 승격 1차 갤러리 구역. [UiKitGalleryPage]가 섹션 틀 구역 아래에 둔다.
class UiKitPromotionSection extends StatelessWidget {
  const UiKitPromotionSection({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: _contentWidth,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_GlyphSample(), SizedBox(width: 24), _TonalSample()],
        ),
        SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FocusRingSample(),
            SizedBox(width: 24),
            _ChipSample(),
            SizedBox(width: 24),
            _PanelButtonSample(),
          ],
        ),
      ],
    ),
  );
}

/// 평행사변형 카드 + 타일 제목 + 내용 + 아래 설명(섹션 틀 타일과 같은 여백: 2 × 80° 컷 + 26).
class _PromotionTile extends StatelessWidget {
  const _PromotionTile({
    required this.tileKey,
    required this.width,
    required this.title,
    required this.caption,
    required this.child,
  });

  final String tileKey;
  final double width;
  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = diagonalCutDepth(_rowHeight) * 2 + 26;
    return SizedBox(
      key: ValueKey('kit-gallery-k1-$tileKey'),
      width: width,
      height: _rowHeight,
      child: WidgetTile(
        padding: EdgeInsets.fromLTRB(inset, 16, inset, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TileTitle(title),
            const SizedBox(height: 12),
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _tileCaption,
            ),
          ],
        ),
      ),
    );
  }
}

/// 숨쉬는 빛 · 도는 표시를 멈춘 모습으로 보인다.
class _Still extends StatelessWidget {
  const _Still({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  );
}

class _GlyphSample extends StatelessWidget {
  const _GlyphSample();

  @override
  Widget build(BuildContext context) => _PromotionTile(
    tileKey: 'glyphs',
    width: 1300,
    title: '선 아이콘 · KitGlyph',
    caption:
        '시안 svg(viewBox 24, 굵기 1.9)를 옮긴 선 아이콘입니다. 체크 · 깃발은 튜토리얼, 스캔 틀부터 오른쪽 화살표까지는 '
        '빈 상태에서 왔습니다. 튜토리얼 체크는 굵기 2.8입니다.',
    child: Wrap(
      spacing: 18,
      runSpacing: 14,
      children: [
        for (final glyph in KitGlyph.values)
          _GlyphCell(label: glyph.name, glyph: glyph),
        const _GlyphCell(
          label: 'check 2.8',
          glyph: KitGlyph.check,
          strokeWidth: 2.8,
        ),
      ],
    ),
  );
}

class _GlyphCell extends StatelessWidget {
  const _GlyphCell({
    required this.label,
    required this.glyph,
    this.strokeWidth,
  });

  final String label;
  final KitGlyph glyph;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KitGlyphIcon(
          glyph,
          key: ValueKey('kit-gallery-k1-glyph-$label'),
          size: 26,
          color: AppColors.primary,
          strokeWidth: strokeWidth,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _tileCaption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _TonalSample extends StatelessWidget {
  const _TonalSample();

  static Widget _close(double size) => KitGlyphIcon(
    KitGlyph.close,
    size: size,
    color: TonalButtonColors.of(TonalButtonVariant.normal).foreground,
  );

  @override
  Widget build(BuildContext context) => _PromotionTile(
    tileKey: 'tonal',
    width: 1156,
    title: 'tonal 간격 · 굵기 · 아이콘 · TonalButton',
    caption:
        '왼쪽은 기본값(간격 8 · 600 · 아이콘 16)입니다. 오른쪽 셋은 튜토리얼 그만두기 크기(카드 30 · 대사 띠 40 · 진행 창 26, '
        '간격 5 · 7 · 4, 700, × 13 · 15 · 12)입니다.',
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TonalButton(
          key: const ValueKey('kit-gallery-k1-tonal-default'),
          label: '기본',
          icon: Icons.add,
          onPressed: () {},
        ),
        const SizedBox(width: 24),
        TonalButton(
          key: const ValueKey('kit-gallery-k1-tonal-card'),
          label: '그만두기',
          leading: _close(13),
          height: 30,
          horizontalPadding: 12,
          gap: 5,
          fontWeight: AppType.bold,
          fontSize: AppType.popoverBodySize,
          onPressed: () {},
        ),
        const SizedBox(width: 24),
        TonalButton(
          key: const ValueKey('kit-gallery-k1-tonal-band'),
          label: '그만두기',
          leading: _close(15),
          height: 40,
          gap: 7,
          fontWeight: AppType.bold,
          fontSize: AppType.bodyPlusSize,
          onPressed: () {},
        ),
        const SizedBox(width: 24),
        TonalButton(
          key: const ValueKey('kit-gallery-k1-tonal-inline'),
          label: '그만두기',
          leading: _close(12),
          height: 26,
          horizontalPadding: 9,
          gap: 4,
          fontWeight: AppType.bold,
          fontSize: AppType.captionPlusSize,
          onPressed: () {},
        ),
      ],
    ),
  );
}

class _FocusRingSample extends StatelessWidget {
  const _FocusRingSample();

  @override
  Widget build(BuildContext context) => _PromotionTile(
    tileKey: 'focus-ring',
    width: 940,
    title: '강조 테두리 · 도는 표시',
    caption:
        '대상 외곽을 5px 바깥으로 옮긴 하늘색 2.5px 테두리와 바깥 빛입니다(갤러리는 빛 .6에 멈춘 모습). '
        '도는 표시는 16 · 24입니다.',
    child: _Still(
      child: Row(
        children: [
          KitFocusRing(
            key: const ValueKey('kit-gallery-k1-focus-parallelogram'),
            child: SizedBox(
              width: 220,
              height: 44,
              child: RailButton(
                onPressed: () {},
                child: const Text('학생 전체 스캔 시작', maxLines: 1),
              ),
            ),
          ),
          const SizedBox(width: 48),
          KitFocusRing(
            key: const ValueKey('kit-gallery-k1-focus-rounded'),
            shape: KitFocusRingShape.roundedRect,
            child: TonalButton(label: '성장 추이', onPressed: () {}),
          ),
          const SizedBox(width: 48),
          const KitSpinner(key: ValueKey('kit-gallery-k1-spinner')),
          const SizedBox(width: 24),
          const KitSpinner(size: 24, strokeWidth: 3),
        ],
      ),
    ),
  );
}

class _ChipSample extends StatelessWidget {
  const _ChipSample();

  @override
  Widget build(BuildContext context) => const _PromotionTile(
    tileKey: 'chips',
    width: 640,
    title: '칩 링 변형 · BaChip',
    caption: '기본 칩과 링 변형(높이 26, 안쪽 1px 링, 앞 깃발 13 — 튜토리얼 머리글 칩)입니다.',
    child: Row(
      children: [
        BaChip(label: '튜토리얼', tone: AppTones.info),
        SizedBox(width: 18),
        BaChip(
          key: ValueKey('kit-gallery-k1-chip-ringed'),
          label: '튜토리얼 · 임시 계정',
          tone: _headerChipTone,
          shape: BaChipShape.ringed,
          height: 26,
          leading: KitGlyphIcon(
            KitGlyph.flag,
            size: 13,
            color: Color(0xffa8e0ff),
          ),
        ),
      ],
    ),
  );
}

class _PanelButtonSample extends StatelessWidget {
  const _PanelButtonSample();

  static const _label = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) => _PromotionTile(
    tileKey: 'panel-button',
    width: 852,
    title: '평행사변형 패널 버튼',
    caption: '계정 추가 모달의 닫기(58×40) · 취소 · 만들기(130×56)입니다. 취소는 연분홍 삼각 텍스처입니다.',
    child: Row(
      children: [
        SizedBox(
          width: 58,
          height: 40,
          child: ParallelogramPanelButton(
            key: const ValueKey('kit-gallery-k1-panel-close'),
            radius: 7,
            fill: const Color.fromRGBO(255, 255, 255, 0.07),
            outline: const Color.fromRGBO(56, 81, 107, 0.8),
            outlineWidth: 1.2,
            semanticLabel: '닫기',
            onTap: () {},
            child: const KitGlyphIcon(
              KitGlyph.close,
              size: 18,
              color: Color(0xffdfe7ee),
            ),
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 130,
          height: 56,
          child: ParallelogramPanelButton(
            key: const ValueKey('kit-gallery-k1-panel-cancel'),
            radius: 8,
            texture: kitPanelCancelTexture,
            outline: const Color.fromRGBO(56, 81, 107, 0.72),
            outlineWidth: 1.8,
            onTap: () {},
            child: const Text('취소', maxLines: 1, style: _label),
          ),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 130,
          height: 56,
          child: ParallelogramPanelButton(
            radius: 8,
            texture: titlePrimaryActionTexture,
            outline: const Color.fromRGBO(242, 179, 239, 0.9),
            outlineWidth: 1.8,
            onTap: () {},
            child: const Text('만들기', maxLines: 1, style: _label),
          ),
        ),
      ],
    ),
  );
}
