// UI Kit 갤러리 — 섹션 틀(FE7-j, tidy2 발견 3).
//
// tidy2가 키트로 올린 `section_frame.dart` 두 위젯의 견본이다. 시안 W-* artboard에 따로 그린 견본이 없어(화면 틀이다) 동작만
// 보인다.
// - [SectionFrame]: Studio 섹션 하나(왼쪽 면에 붙은 사다리꼴)의 표면과, 그 모양으로 잘린 내용. 분홍 막대는 일부러 섹션
//   밖까지 놓아 잘리는 것을 보인다.
// - [SectionScaledBox]: 같은 시안 크기 내용(근거 패널 머리 한 줄)을 배율 1 · 0.75 · 0.5 자리에 넣는다. 1 미만이면 시안
//   크기로 배치한 뒤 같은 비율로 줄인다(통계 · 전술 섹션 안 요소가 작은 창에서 쓰는 규칙).
// 통계 · 인벤토리 차트(스파크라인 · 발산 막대)는 같은 그림이 아니라 키트로 올리지 않았다(status FE7-j 승격 표).
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../geometry/diagonal_geometry.dart';
import '../../studio/section_template.dart';
import '../ba_chip.dart';
import '../diagonal_row.dart';
import '../section_frame.dart';
import '../titles.dart';

const _contentWidth = 2480.0;
const _rowHeight = 420.0;

/// 타일 하단 설명(11.5px).
const _tileCaption = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionPlusSize,
  height: 1.5,
  color: AppColors.textMuted,
);

/// 견본 섹션: 왼쪽 면에 붙은 사다리꼴(붙지 않은 오른쪽이 80° 사선).
const _sampleSection = SectionCanvasElement(
  id: 'kit-gallery-section',
  label: 'kit-gallery-section',
  rect: SectionGridRect(0, 0, 96, 96),
  spec: AttachedSectionSpec(
    mode: SectionShapeMode.trapezoid,
    face: SectionAttachmentFace.left,
    faceSpan: 96,
    height: 96,
  ),
);

/// 섹션 틀 갤러리 구역. [UiKitGalleryPage]가 FE2-d 구역 아래에 둔다.
class UiKitFrameSection extends StatelessWidget {
  const UiKitFrameSection({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: _contentWidth,
    height: _rowHeight,
    child: Stack(
      children: [
        Positioned(left: 0, top: 0, child: _SectionFrameSample()),
        Positioned(left: 1180, top: 0, child: _ScaledBoxSample()),
      ],
    ),
  );
}

/// 평행사변형 카드 + 타일 제목 + 내용 + 아래 설명(FE2-d 데이터 타일과 같은 여백: 2 × 80° 컷 + 26).
class _FrameTile extends StatelessWidget {
  const _FrameTile({
    required this.tileKey,
    required this.title,
    required this.caption,
    required this.child,
  });

  static const width = 1150.0;

  final String tileKey;
  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = diagonalCutDepth(_rowHeight) * 2 + 26;
    return SizedBox(
      key: ValueKey('kit-gallery-frame-$tileKey'),
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

/// 근거 패널 머리 한 줄(시안 크기 360 × 44): 제목 + 분홍 인원 칩.
class _HeaderLine extends StatelessWidget {
  const _HeaderLine();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: PanelTitle(
      '9/22 → 10/05',
      trailing: BaChip(label: '12명', tone: AppTones.pink),
    ),
  );
}

class _SectionFrameSample extends StatelessWidget {
  const _SectionFrameSample();

  static const size = Size(560, 270);

  @override
  Widget build(BuildContext context) => _FrameTile(
    tileKey: 'section-frame',
    title: '섹션 틀 · SectionFrame',
    caption:
        '섹션 표면(그림자 포함)을 그리고 내용을 섹션 모양으로 자릅니다. 분홍 막대는 섹션 밖까지 놓았지만 사선에서 잘립니다. '
        '통계 · 전술 섹션이 씁니다.',
    child: SizedBox.fromSize(
      key: const ValueKey('kit-gallery-section-frame'),
      size: size,
      child: SectionFrame(
        section: _sampleSection,
        surfaceKey: const ValueKey('kit-gallery-section-frame-surface'),
        children: [
          const Positioned(
            left: 28,
            top: 24,
            width: 360,
            height: 44,
            child: _HeaderLine(),
          ),
          Positioned(
            left: 28,
            top: 120,
            width: size.width + 80,
            height: 28,
            child: const ColoredBox(
              key: ValueKey('kit-gallery-section-frame-overflow'),
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScaledBoxSample extends StatelessWidget {
  const _ScaledBoxSample();

  /// 시안 크기 내용 자리.
  static const design = Size(360, 44);
  static const scales = [1.0, 0.75, 0.5];

  @override
  Widget build(BuildContext context) => _FrameTile(
    tileKey: 'scaled-box',
    title: '섹션 안 배율 · SectionScaledBox',
    caption:
        '같은 내용을 배율 1 · 0.75 · 0.5 자리에 넣었습니다. 1보다 작으면 시안 크기로 배치한 뒤 같은 비율로 줄입니다. '
        '화면 전체가 아니라 섹션 안 요소 하나에만 씁니다.',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final scale in scales) ...[
          if (scale != scales.first) const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  '× $scale',
                  maxLines: 1,
                  style: _tileCaption.copyWith(color: AppColors.textSecondary),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textMuted, width: 1),
                ),
                child: SizedBox(
                  key: ValueKey(
                    'kit-gallery-scaled-box-${(scale * 100).round()}',
                  ),
                  width: design.width * scale,
                  height: design.height * scale,
                  child: SectionScaledBox(
                    scale: scale,
                    child: const _HeaderLine(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
