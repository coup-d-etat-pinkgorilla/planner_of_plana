// UI Kit 갤러리 — FE2-d 이미지·차트 원자.
//
// 배치(가로 = 시안 x − 40, 세로는 줄마다 위에서부터):
// - 1줄: W-Data-Widgets 첫 줄(높이 300). KPI 사선 타일 · 전후 비교 / 주요 재화 (숫자형) / 아이템 타일 + 충족 막대.
// - 2줄: 비율 막대 행 (사선 정렬)(W-Data 둘째 줄 첫 타일, 높이 330) · 차트 원자 견본 · 이미지 원자·막대 견본.
//   W-Data 둘째 줄의 히스토그램·꺾은선·± 막대와 셋째 줄 이후 완성 위젯은 FE6·FE7 몫이라 원자 견본만 둔다.
// 타일 안쪽 여백은 시안 그대로 2 × 80° 컷 + 26(300 높이 131.9, 330 높이 142.4)이다. 값은 시안 예시 값이다.
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../geometry/diagonal_geometry.dart';
import '../diagonal_row.dart';
import '../game_assets.dart';
import '../hatch.dart';
import '../item_icon_tile.dart';
import '../kpi_tile.dart';
import '../portrait_strip.dart';
import '../skew_bar.dart';
import '../skew_box.dart';
import '../stat_chart.dart';
import '../titles.dart';

const _contentWidth = 2480.0;

/// 시안 타일 하단 `.wsub` 11.5px.
const _tileCaption = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionPlusSize,
  height: 1.5,
  color: AppColors.textMuted,
);

/// 시안 `.mut` 11px.
const _mut = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.35,
  color: AppColors.textMuted,
);

final _techNoteIcon = GameAssets.itemIcon(
  'skill_book',
  'Item_Icon_SkillBook_Millennium_3',
);

/// FE2-d 갤러리 구역. [UiKitGalleryPage]가 FE2-c 구역 아래에 둔다.
class UiKitDataSection extends StatelessWidget {
  const UiKitDataSection({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _TileRow(
        height: 300,
        tiles: [
          (0.0, _KpiTileSample()),
          (982.7, _ResourceAmountSample()),
          (1716.9, _ItemTileSample()),
        ],
      ),
      SizedBox(height: 24),
      _TileRow(
        height: 330,
        tiles: [
          (0.0, _RatioBarSample()),
          (778.3, _ChartAtomSample()),
          (1324.4, _ImageAtomSample()),
        ],
      ),
    ],
  );
}

class _TileRow extends StatelessWidget {
  const _TileRow({required this.height, required this.tiles});

  final double height;
  final List<(double, Widget)> tiles;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _contentWidth,
    height: height,
    child: Stack(
      children: [
        for (final (left, tile) in tiles)
          Positioned(left: left, top: 0, child: tile),
      ],
    ),
  );
}

/// W-Data 위젯 타일: 평행사변형 카드 + 타일 제목 + 가운데 내용 + 아래 설명.
class _DataTile extends StatelessWidget {
  const _DataTile({
    required this.tileKey,
    required this.title,
    required this.caption,
    required this.width,
    required this.height,
    required this.child,
  });

  final String tileKey;
  final String title;
  final String caption;
  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 시안: 바깥 div = 컷 + 10, 안쪽 div = 컷 + 16 → 합 2 × 컷 + 26.
    final inset = diagonalCutDepth(height) * 2 + 26;
    return SizedBox(
      key: ValueKey('kit-gallery-fe2d-$tileKey'),
      width: width,
      height: height,
      child: WidgetTile(
        padding: EdgeInsets.fromLTRB(inset, 16, inset, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TileTitle(title),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
            const SizedBox(height: 6),
            Text(caption, style: _tileCaption),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1줄

class _KpiTileSample extends StatelessWidget {
  const _KpiTileSample();

  @override
  Widget build(BuildContext context) => const _DataTile(
    tileKey: 'kpi',
    title: 'KPI 사선 타일 · 전후 비교',
    caption: '통계 · 인벤토리. 윗줄은 값+변화, 아랫줄은 지금 → 예상.',
    width: 1011.6,
    height: 300,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: KpiTile(label: '보유 학생', value: '128', delta: '/ 170 · +2'),
            ),
            SizedBox(width: 14),
            Expanded(
              child: KpiTile(label: '평균 육성도', value: '63.4%', delta: '+1.2'),
            ),
            SizedBox(width: 14),
            Expanded(
              child: KpiTile(
                label: '계획 등록',
                value: '9명',
                delta: '+7',
                deltaTone: KpiDeltaTone.plan,
              ),
            ),
          ],
        ),
        SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: KpiTile.compare(
                label: '계획 충족률',
                before: '72%',
                after: '78%',
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: KpiTile.compare(
                label: '부족 재화',
                before: '14종',
                after: '12종',
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: KpiTile.compare(
                label: '풀리는 단계',
                before: '0',
                after: '2개',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ResourceAmountSample extends StatelessWidget {
  const _ResourceAmountSample();

  @override
  Widget build(BuildContext context) => const _DataTile(
    tileKey: 'resources',
    title: '주요 재화 (숫자형)',
    caption: '인벤토리 왼쪽 아래. 크레딧·엘리그마는 아이템 그리드에 넣지 않습니다.',
    width: 763.1,
    height: 300,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ResourceAmountRow(
          iconAsset: GameAssets.creditIcon,
          name: '크레딧',
          value: '98.4M',
          needed: '/ 필요 261.5M',
          shortage: '−163.1M',
          fraction: 0.38,
        ),
        SizedBox(height: 10),
        _ResourceAmountRow(
          label: '엘리그마',
          name: '엘리그마',
          value: '1,020',
          needed: '/ 필요 2,245',
          shortage: '−1,225',
          fraction: 0.45,
        ),
      ],
    ),
  );
}

/// 숫자형 재화 행 견본(완성 위젯 `ResourceAmountRow`는 FE6 몫). 원자 조합만 보인다.
class _ResourceAmountRow extends StatelessWidget {
  const _ResourceAmountRow({
    this.iconAsset,
    this.label,
    required this.name,
    required this.value,
    required this.needed,
    required this.shortage,
    required this.fraction,
  });

  final String? iconAsset;
  final String? label;
  final String name;
  final String value;
  final String needed;
  final String shortage;
  final double fraction;

  @override
  Widget build(BuildContext context) => SkewBox(
    fill: const Color.fromRGBO(16, 24, 35, 0.6),
    border: const Color.fromRGBO(56, 81, 107, 0.6),
    borderWidth: 1,
    radius: 7,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          ItemIconTile(iconAsset: iconAsset, label: label, semanticLabel: name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: AppType.bodyPlusSize,
                        height: 1.3,
                        fontWeight: AppType.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(value, style: kitDisplayStyle(AppType.titleSize)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        needed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _mut,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      shortage,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: AppType.bodySmallSize,
                        height: 1.3,
                        fontWeight: AppType.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SkewBar.tone(
                  fraction: fraction,
                  tone: CoverageTone.shortage,
                  height: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ItemTileSample extends StatelessWidget {
  const _ItemTileSample();

  @override
  Widget build(BuildContext context) => _DataTile(
    tileKey: 'item-tiles',
    title: '아이템 타일 + 충족 막대',
    caption:
        '전체 아이템. 막대는 타일 밑변 길이·기울기에 맞춥니다. '
        '분홍 부족 · 파랑 충분 · 노랑 과잉 · 없음 = 계획 무관.',
    width: 763.1,
    height: 300,
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _labeled(
            '부족',
            ItemTile(
              key: const ValueKey('kit-gallery-item-tile-shortage'),
              quantity: '12',
              iconAsset: _techNoteIcon,
              background: ItemBackground.yellow,
              tone: CoverageTone.shortage,
              fraction: 0.28,
              selected: true,
            ),
          ),
          const SizedBox(width: 16),
          _labeled(
            '충분',
            const ItemTile(
              key: ValueKey('kit-gallery-item-tile-enough'),
              quantity: '88',
              label: '기술\n노트',
              tone: CoverageTone.enough,
              fraction: 1,
            ),
          ),
          const SizedBox(width: 16),
          _labeled(
            '과잉',
            const ItemTile(
              key: ValueKey('kit-gallery-item-tile-excess'),
              quantity: '140',
              label: '기술\n노트',
              tone: CoverageTone.excess,
              fraction: 1,
            ),
          ),
          const SizedBox(width: 16),
          _labeled(
            '계획 무관',
            const ItemTile(
              key: ValueKey('kit-gallery-item-tile-unrelated'),
              quantity: '0',
              label: '기술\n노트',
            ),
          ),
        ],
      ),
    ),
  );

  static Widget _labeled(String label, Widget tile) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      tile,
      const SizedBox(height: 6),
      Text(label, style: _mut),
    ],
  );
}

// ---------------------------------------------------------------------------
// 2줄

/// 비율 막대 행(학교 · 왼쪽 파랑 · 오른쪽 분홍).
const _ratioRows = [
  ('밀레니엄', 0.93, 0.71),
  ('게헨나', 0.89, 0.66),
  ('트리니티', 0.79, 0.62),
  ('백귀야행', 0.60, 0.48),
  ('산해경', 0.57, 0.45),
];

class _RatioBarSample extends StatelessWidget {
  const _RatioBarSample();

  static const rowHeight = 32.0;
  static const rowGap = 8.0;

  @override
  Widget build(BuildContext context) => _DataTile(
    tileKey: 'ratio-bars',
    title: '비율 막대 행 (사선 정렬)',
    caption:
        '통계 학교별·역할별·항목별. 트랙 길이는 모두 같고 행 전체가 80°로 밀립니다. 25/50/75 눈금.',
    width: 812.4,
    height: 330,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < _ratioRows.length; index++) ...[
          if (index > 0) const SizedBox(height: rowGap),
          _ratioRow(index),
        ],
      ],
    ),
  );

  Widget _ratioRow(int index) {
    final (name, left, right) = _ratioRows[index];
    // 행 간격(32 + 8)마다 80° 레일만큼 왼쪽 여백이 줄어든다(시안 28.2 → 0).
    final inset =
        diagonalCutDepth(rowHeight + rowGap) * (_ratioRows.length - 1 - index);
    return SizedBox(
      key: ValueKey('kit-gallery-ratio-row-$index'),
      height: rowHeight,
      child: Padding(
        padding: EdgeInsets.only(left: inset),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(
                name,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.bodySize,
                  height: 1.3,
                  fontWeight: AppType.bold,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _RatioCell(fraction: left, color: AppColors.primary)),
            const SizedBox(width: 14),
            Expanded(child: _RatioCell(fraction: right, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}

class _RatioCell extends StatelessWidget {
  const _RatioCell({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SkewBar(
          fraction: fraction,
          color: color,
          height: 12,
          style: SkewBarStyle.ratio,
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 44,
        child: Text(
          '${(fraction * 100).round()}%',
          maxLines: 1,
          textAlign: TextAlign.right,
          style: kitDisplayStyle(AppType.titleSmallSize),
        ),
      ),
    ],
  );
}

/// 차트 원자 견본: 막대 6개(모름 = 빗금, 0 = 빈 막대), 축·눈금, 평균 점선, 누르면 고르기.
class _ChartAtomSample extends StatefulWidget {
  const _ChartAtomSample();

  @override
  State<_ChartAtomSample> createState() => _ChartAtomSampleState();
}

class _ChartAtomSampleState extends State<_ChartAtomSample> {
  int? _selected = 5;

  @override
  Widget build(BuildContext context) {
    final painter = SampleBarChartPainter(selected: _selected);
    return _DataTile(
      tileKey: 'chart-atoms',
      title: '차트 원자',
      caption: 'viewBox × 1.25 · 80° 막대 · 빗금 = 모름 · 빈 막대 = 0 · 막대를 누르면 고릅니다.',
      width: 580.4,
      height: 330,
      child: Center(
        child: StatChartFrame(
          key: const ValueKey('kit-gallery-chart-frame'),
          viewBox: SampleBarChartPainter.viewBox,
          painter: painter,
          semanticLabel: '차트 원자 견본',
          onTapAt: (point) {
            final hit = painter.hitMap().hitTest(point);
            if (hit != null) setState(() => _selected = hit);
          },
        ),
      ),
    );
  }
}

/// 갤러리 차트 견본 painter(설계 좌표 232×96). 테스트도 이 값을 쓴다.
class SampleBarChartPainter extends StatChartPainter {
  const SampleBarChartPainter({this.selected});

  static const viewBox = Size(232, 96);

  /// 막대 값(%). `null` = 모름.
  static const values = <double?>[62, 81, null, 0, 47, 90];
  static const average = 63.0;
  static const plotLeft = 28.0;
  static const plotTop = 8.0;
  static const plotBottom = 80.0;
  static const slotWidth = 34.0;
  static const barWidthFraction = 0.6;

  final int? selected;

  static const scale = StatChartScale(
    domainMin: 0,
    domainMax: 100,
    rangeStart: plotBottom,
    rangeEnd: plotTop,
  );

  /// 막대 칸 [index]의 사각형(설계 좌표, 기울이기 전).
  static Rect slotRect(int index) {
    final left = plotLeft + index * slotWidth + slotWidth * (1 - barWidthFraction) / 2;
    return Rect.fromLTRB(
      left,
      plotTop,
      left + slotWidth * barWidthFraction,
      plotBottom,
    );
  }

  /// 막대 hit 영역.
  StatChartHitMap<int> hitMap() {
    final map = StatChartHitMap<int>();
    for (var index = 0; index < values.length; index++) {
      map.add(index, skewedBarPath(slotRect(index), topRadius: 0));
    }
    return map;
  }

  @override
  void paint(Canvas canvas, Size viewBox) {
    for (final tick in const [0.0, 50.0, 100.0]) {
      final y = scale.map(tick);
      paintStatGridLine(
        canvas,
        Offset(plotLeft, y),
        Offset(viewBox.width, y),
        color: tick == 0 ? StatChartPalette.axis : StatChartPalette.grid,
      );
      paintStatLabel(
        canvas,
        '${tick.round()}%',
        Offset(plotLeft - 4, y),
        alignment: Alignment.centerRight,
        fontSize: 8,
      );
    }
    for (var index = 0; index < values.length; index++) {
      paintValueBar(
        canvas,
        slot: slotRect(index),
        value: values[index],
        scale: scale,
        color: index == selected
            ? StatChartPalette.highlight
            : StatChartPalette.magnitudeSoft,
      );
      final value = values[index];
      paintStatLabel(
        canvas,
        value == null ? '모름' : '${value.round()}',
        Offset(slotRect(index).center.dx, plotBottom + 3),
        alignment: Alignment.topCenter,
        fontSize: 8,
        color: StatChartPalette.valueLabel,
      );
    }
    final averageY = scale.map(average);
    paintStatGridLine(
      canvas,
      Offset(plotLeft, averageY),
      Offset(viewBox.width, averageY),
      color: StatChartPalette.highlight,
      dashed: true,
    );
  }

  @override
  bool shouldRepaint(SampleBarChartPainter oldPainter) =>
      oldPainter.selected != selected;
}

/// 이미지 원자·막대 견본.
class _ImageAtomSample extends StatelessWidget {
  const _ImageAtomSample();

  @override
  Widget build(BuildContext context) => _DataTile(
    tileKey: 'image-atoms',
    title: '이미지 원자 · 막대',
    caption:
        '아이템 아이콘 42 · 47 · 52 · 74 / 그림 없음 = 빈 상자 · 초상 최대 5 + "…+n" · '
        '막대 부족 · 충분 · 과잉 · 모름(빗금) · 0(빈 트랙).',
    width: 1155.6,
    height: 330,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final size in const [
              ItemIconSizes.s42,
              ItemIconSizes.s47,
              ItemIconSizes.s52,
              ItemIconSizes.s74,
            ]) ...[
              ItemIconTile(
                iconAsset: _techNoteIcon,
                background: ItemBackground.yellow,
                size: size,
              ),
              const SizedBox(width: 12),
            ],
            const SizedBox(width: 12),
            const ItemIconTile(
              key: ValueKey('kit-gallery-item-icon-missing'),
              iconAsset: 'assets/item_icons/__missing__.png',
              backgroundAsset: 'assets/item_backgrounds/__missing__.png',
              size: ItemIconSizes.s52,
            ),
            const SizedBox(width: 40),
            const PortraitStrip(
              key: ValueKey('kit-gallery-portraits-3'),
              studentIds: ['hoshino', 'shiroko', 'nonomi'],
            ),
            const SizedBox(width: 24),
            const PortraitStrip(
              key: ValueKey('kit-gallery-portraits-7'),
              studentIds: [
                'yuuka',
                'noa',
                'rio',
                'toki',
                'himari',
                'koyuki',
                'kei',
              ],
              slotWidth: 246,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (final (label, fraction, tone) in const [
              ('부족 38%', 0.38, CoverageTone.shortage),
              ('충분', 1.0, CoverageTone.enough),
              ('과잉', 1.0, CoverageTone.excess),
              ('모름', null, CoverageTone.enough),
              ('0', 0.0, CoverageTone.shortage),
            ]) ...[
              SizedBox(
                width: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: _mut),
                    const SizedBox(height: 6),
                    SkewBar.tone(
                      key: ValueKey('kit-gallery-skew-bar-$label'),
                      fraction: fraction,
                      tone: tone,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
            ],
            const SizedBox(
              width: 60,
              height: 24,
              child: HatchBox(radius: 4),
            ),
          ],
        ),
      ],
    ),
  );
}
