// UI Kit 갤러리 (FE2, 개발 패널에서 연다).
//
// FE2 동안의 검수 대상이다(워크플로 "검증" 4). 공용 키트 위젯을 시안 W-*·UI-Elements artboard 배치대로 올린다.
// FE2-a: W-Layout-Widgets "사다리꼴 안 스크롤"(resize 모드 + 포그 B + 사선 스크롤바), translate 모드(포그 C),
// UI-Elements 행 견본(.srow/.row/.plain/.tile/rail × 기본·hover·선택·파랑).
// FE2-b: `ui_kit_controls_section.dart`(W-Layout 첫 줄, W-Filter, 레일 버튼·스위치·스테퍼, 상태 견본).
// FE2-c: `ui_kit_overlays_section.dart`(W-Info-Popover 보드, 모달 스크림 프리셋, W-Layout 팝오버 줄, 프리셋 견본).
// FE2-d: `ui_kit_data_section.dart`(W-Data KPI · 주요 재화 · 아이템 타일 · 비율 막대 행, 차트·이미지 원자 견본).
// 다음 FE2 slice는 이 페이지에 자기 위젯 타일을 더한다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../geometry/diagonal_geometry.dart';
import '../../widgets/section_surface.dart';
import '../diagonal_row.dart';
import '../diagonal_scroll_viewport.dart';
import '../scroll_viewport_fog.dart';
import '../titles.dart';
import 'ui_kit_controls_section.dart';
import 'ui_kit_data_section.dart';
import 'ui_kit_overlays_section.dart';

/// 갤러리 페이지. 개발 패널의 "UI Kit 갤러리" 버튼이 연다.
class UiKitGalleryPage extends StatelessWidget {
  const UiKitGalleryPage({super.key});

  static const pageKey = ValueKey('ui-kit-gallery-page');

  /// 시안 artboard 폭(2560)에서 좌우 여백 40을 뺀 내용 폭.
  static const contentWidth = 2480.0;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: pageKey,
    backgroundColor: AppColors.canvas,
    appBar: AppBar(
      backgroundColor: AppColors.navigation,
      title: const Text('UI Kit 갤러리'),
    ),
    body: SingleChildScrollView(
      key: const ValueKey('ui-kit-gallery-scroll'),
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: contentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _GalleryHeading(
                title: 'FE2-a 행·스크롤',
                caption:
                    '사선 행, 사선 스크롤 뷰포트(resize · translate), 사선 스크롤바, 스크롤 포그입니다. '
                    '시안 W-Layout-Widgets와 UI-Elements의 견본과 나란히 비교합니다.',
              ),
              SizedBox(height: 24),
              _TrapezoidScrollTile(),
              SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ParallelogramScrollTile(),
                  SizedBox(width: 24),
                  _RowVariantsTile(),
                ],
              ),
              SizedBox(height: 48),
              _GalleryHeading(
                title: 'FE2-b 소형 컨트롤 · 제목',
                caption:
                    '칩 · 단계 태그 · 세그먼트 · 토글 칩 · 필터 버튼 · 스위치 · 스테퍼 · 버튼 · 제목입니다. '
                    '시안 W-Layout-Widgets 첫 줄과 W-Filter-Widgets의 배치를 따르고, 상태 견본을 덧붙였습니다.',
              ),
              SizedBox(height: 24),
              UiKitControlsSection(),
              SizedBox(height: 48),
              _GalleryHeading(
                title: 'FE2-c 오버레이',
                caption:
                    '(i) 도움말 · 앵커 플라이아웃(프리셋) · 모달 스크림입니다. '
                    '시안 W-Info-Popover 보드와 W-Layout-Widgets 팝오버 줄을 같은 좌표로 올렸습니다.',
              ),
              SizedBox(height: 24),
              UiKitOverlaysSection(),
              SizedBox(height: 48),
              _GalleryHeading(
                title: 'FE2-d 이미지·차트 원자',
                caption:
                    '아이템 아이콘 · 아이템 타일 · 초상 줄 · 막대 · KPI · 차트 원자입니다. '
                    '시안 W-Data-Widgets의 KPI · 주요 재화 · 아이템 타일 · 비율 막대 행과 나란히 비교합니다.',
              ),
              SizedBox(height: 24),
              UiKitDataSection(),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 공통 글꼴. 타일 제목·소제목은 FE2-b 키트(`TileTitle`, `SubHeader`)를 쓴다.

const _wsub = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySize,
  height: 1.5,
  color: AppColors.textMuted,
);

final _skew = Matrix4.skewX(-10 * math.pi / 180);

class _GalleryHeading extends StatelessWidget {
  const _GalleryHeading({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontFamily: AppFonts.display,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: AppType.headlineMediumSize,
          height: 1.2,
          color: AppColors.text,
        ),
      ),
      const SizedBox(height: 8),
      Text(caption, style: _wsub),
    ],
  );
}

/// 설명 한 줄: 5×12 핑크 사선 막대 + 12.5px 본문.
class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Transform(
          transform: _skew,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 5,
            height: 12,
            child: ColoredBox(color: AppColors.accent),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: AppType.popoverBodySize,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}

class _Notes extends StatelessWidget {
  const _Notes({required this.heading, required this.lines, this.width = 520});

  final String heading;
  final List<String> lines;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubHeader(heading, fontSize: AppType.captionSize),
        for (final line in lines) ...[
          const SizedBox(height: 10),
          _Bullet(line),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// W-Layout-Widgets "사다리꼴 안 스크롤" (1807.8×450, resize 모드)

const _demoNames = [
  ('호시노', 92),
  ('시로코', 85),
  ('아루', 78),
  ('미카', 74),
  ('유우카', 66),
  ('노아', 60),
  ('히나', 52),
  ('카즈사', 47),
  ('마리', 40),
  ('쿠루미', 33),
  ('오토기', 25),
  ('토키', 18),
];

/// 시안 `.rs` 패널색.
const _railPanelColor = Color(0xff141e2b);

class _TrapezoidScrollTile extends StatelessWidget {
  const _TrapezoidScrollTile();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey('kit-gallery-tile-trapezoid'),
    width: 1807.8,
    height: 450,
    child: WidgetTile(
      padding: EdgeInsets.fromLTRB(184.3, 16, 184.3, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TileTitle('사다리꼴 안 스크롤'),
          SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrapezoidScrollDemo(),
              SizedBox(width: 40),
              _Notes(
                heading: '직접 스크롤해 보십시오',
                lines: [
                  '행 폭은 그 행이 지금 화면에서 놓인 높이의 레일 위치를 따릅니다. 위로 스크롤될수록 넓어지고, 아래로 내려갈수록 좁아집니다.',
                  '사선 스크롤바는 레일과 평행하게 두고, 썸도 레일을 따라 움직입니다.',
                  '위 안개는 스크롤을 시작하면 나타나고, 아래 안개는 끝에 닿으면 사라집니다.',
                  '선택된 행은 분홍 왼쪽 막대와 옅은 분홍 배경으로 표시합니다.',
                ],
              ),
            ],
          ),
          Spacer(),
          Text(
            '전술대항전 기록 목록. 사다리꼴 패널 안에서 목록만 스크롤되고, 각 행의 오른쪽 끝이 지금 위치의 80° 레일을 따라갑니다.',
            style: _wsub,
          ),
        ],
      ),
    ),
  );
}

/// 560×320 사다리꼴 패널(왼쪽 수직, 오른쪽 80°, r14) 안의 541.5×292 resize 목록.
class _TrapezoidScrollDemo extends StatefulWidget {
  const _TrapezoidScrollDemo();

  @override
  State<_TrapezoidScrollDemo> createState() => _TrapezoidScrollDemoState();
}

class _TrapezoidScrollDemoState extends State<_TrapezoidScrollDemo> {
  int _selected = 1;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 560,
    height: 320,
    child: ClipPath(
      clipper: const _PanelClipper(rail: true),
      child: ColoredBox(
        color: _railPanelColor,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 14),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 541.5,
              height: 292,
              child: DiagonalScrollViewport(
                keyPrefix: 'kit-gallery-resize',
                mode: DiagonalScrollMode.resize,
                itemCount: _demoNames.length,
                itemHeight: (_) => 52,
                itemGap: 6,
                verticalInset: 0,
                horizontalInset: 0,
                scrollbarReserve: 18,
                fog: const ScrollFogSpec.panel(color: _railPanelColor),
                itemBuilder: (context, index) => DiagonalRow(
                  key: ValueKey('kit-gallery-resize-item-$index'),
                  variant: DiagonalRowVariant.rail,
                  mark: index == _selected
                      ? DiagonalRowMark.selected
                      : DiagonalRowMark.none,
                  onTap: () => setState(() => _selected = index),
                  padding: const EdgeInsets.only(left: 16, right: 21),
                  child: _RecordRowContent(index: index),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// rs-* 행 내용: 순위 22 · 초상 44×36 · 이름 80 · 막대 · 비율 34.
class _RecordRowContent extends StatelessWidget {
  const _RecordRowContent({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final (name, percent) = _demoNames[index];
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.bodyLargeSize,
              height: 1.2,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 초상 자리. 갤러리는 학생 이미지 대신 이름 첫 글자를 둔다.
        Container(
          width: 44,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.indicatorSurface,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          child: Text(name.substring(0, 1), style: AppType.bodySmall),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: AppType.body.copyWith(
              fontWeight: AppType.bold,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _Bar(fraction: percent / 100)),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(
            '$percent%',
            textAlign: TextAlign.right,
            style: AppType.bodySmall.copyWith(
              fontWeight: AppType.bold,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// `.bar2`: 8px r4 트랙 white@.09, 채움 #71c7f4.
class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.all(Radius.circular(4)),
    child: SizedBox(
      height: 8,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.white.withValues(alpha: 0.09)),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// translate 모드(통계 sv-*): 평행사변형 섹션 안에서 행을 레일 방향으로 민다.

class _ParallelogramScrollTile extends StatelessWidget {
  const _ParallelogramScrollTile();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey('kit-gallery-tile-parallelogram'),
    width: 1240,
    height: 450,
    child: WidgetTile(
      padding: EdgeInsets.fromLTRB(110, 16, 110, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TileTitle('평행사변형 안 스크롤 (translate)'),
          SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ParallelogramScrollDemo(),
              SizedBox(width: 32),
              _Notes(
                width: 420,
                heading: '직접 스크롤해 보십시오',
                lines: [
                  '행 폭은 그대로 두고, 행이 놓인 높이의 레일 위치만큼 행을 가로로 밉니다.',
                  '통계 탭 스크롤 목록의 방식입니다. 포그는 56px, 페이드 80px입니다.',
                  '행은 사선 행(.srow)입니다. 마우스를 올리면 hover, 누르면 선택으로 바뀝니다.',
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ParallelogramScrollDemo extends StatefulWidget {
  const _ParallelogramScrollDemo();

  @override
  State<_ParallelogramScrollDemo> createState() =>
      _ParallelogramScrollDemoState();
}

class _ParallelogramScrollDemoState extends State<_ParallelogramScrollDemo> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 560,
    height: 320,
    child: SectionSurface(
      clipper: const _PanelClipper(rail: false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: DiagonalScrollViewport(
          keyPrefix: 'kit-gallery-translate',
          itemCount: _demoNames.length,
          itemHeight: (_) => 46,
          itemGap: 6,
          fog: ScrollFogSpec.statistics,
          itemBuilder: (context, index) {
            final (name, percent) = _demoNames[index];
            return DiagonalRow(
              key: ValueKey('kit-gallery-translate-item-$index'),
              mark: index == _selected
                  ? DiagonalRowMark.selected
                  : DiagonalRowMark.none,
              onTap: () => setState(() => _selected = index),
              padding: EdgeInsets.only(
                left: diagonalCutDepth(46) + 12,
                right: diagonalCutDepth(46) + 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: AppType.body.copyWith(color: AppColors.text),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: AppType.bodySmall.copyWith(
                      fontWeight: AppType.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// 데모 패널 모양. rail = 왼쪽 수직·오른쪽 80°(r14), 아니면 평행사변형(r14).
class _PanelClipper extends CustomClipper<Path> {
  const _PanelClipper({required this.rail});

  final bool rail;

  @override
  Path getClip(Size size) {
    final cut = diagonalCutDepth(size.height);
    return diagonalRoundedPolygon(
      [
        Offset(rail ? 0 : cut, 0),
        Offset(size.width, 0),
        Offset(size.width - cut, size.height),
        Offset(0, size.height),
      ],
      radius: AppRadii.section,
      corner: DiagonalCornerStyle.quadratic,
    );
  }

  @override
  bool shouldReclip(_PanelClipper oldClipper) => oldClipper.rail != rail;
}

// ---------------------------------------------------------------------------
// UI-Elements 행 견본: 변형 × 상태

enum _RowState { normal, hover, selected, blue }

const _stateLabels = {
  _RowState.normal: '기본',
  _RowState.hover: 'hover',
  _RowState.selected: '선택',
  _RowState.blue: '파랑',
};

const _variantLabels = {
  DiagonalRowVariant.srow: '.srow',
  DiagonalRowVariant.row: '.row',
  DiagonalRowVariant.plain: '.plain',
  DiagonalRowVariant.tile: '.tile',
  DiagonalRowVariant.rail: 'rail (.rsr)',
};

/// 시안 CSS에 규칙이 있는 조합인가(FD-014: 없는 상태는 만들지 않는다).
bool _stateDefined(DiagonalRowVariant variant, _RowState state) =>
    switch (state) {
      _RowState.normal => true,
      _RowState.hover =>
        variant == DiagonalRowVariant.srow ||
            variant == DiagonalRowVariant.tile ||
            variant == DiagonalRowVariant.rail,
      _RowState.selected =>
        variant == DiagonalRowVariant.srow ||
            variant == DiagonalRowVariant.rail,
      _RowState.blue => variant == DiagonalRowVariant.srow,
    };

class _RowVariantsTile extends StatelessWidget {
  const _RowVariantsTile();

  static const _cellWidth = 200.0;
  static const _cellHeight = 44.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('kit-gallery-tile-rows'),
    width: 1216,
    height: 450,
    child: WidgetTile(
      padding: const EdgeInsets.fromLTRB(110, 16, 110, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TileTitle('사선 행 변형 · 상태'),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 96),
              for (final state in _RowState.values)
                SizedBox(
                  width: _cellWidth + 12,
                  child: SubHeader(
                    _stateLabels[state]!,
                    fontSize: AppType.captionSize,
                  ),
                ),
            ],
          ),
          for (final variant in DiagonalRowVariant.values) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    _variantLabels[variant]!,
                    style: AppType.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                for (final state in _RowState.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: _cellWidth,
                      height: _cellHeight,
                      child: _stateDefined(variant, state)
                          ? _sample(variant, state)
                          : const Center(
                              child: Text('—', style: _wsub),
                            ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Row(
            children: [
              SizedBox(
                width: 96,
                child: Text('직접 눌러 보기', style: _wsub),
              ),
              SizedBox(
                width: _cellWidth * 2,
                height: _cellHeight,
                child: _InteractiveRow(),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _sample(DiagonalRowVariant variant, _RowState state) => DiagonalRow(
    key: ValueKey('kit-gallery-row-${variant.name}-${state.name}'),
    variant: variant,
    mark: switch (state) {
      _RowState.selected => DiagonalRowMark.selected,
      _RowState.blue => DiagonalRowMark.blue,
      _ => DiagonalRowMark.none,
    },
    hovered: state == _RowState.hover,
    padding: EdgeInsets.only(left: diagonalCutDepth(_cellHeight) + 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '${_variantLabels[variant]} ${_stateLabels[state]}',
        style: AppType.bodySmall.copyWith(color: AppColors.text),
      ),
    ),
  );
}

/// 마우스 hover와 누르기(선택 토글)를 직접 확인하는 srow.
class _InteractiveRow extends StatefulWidget {
  const _InteractiveRow();

  @override
  State<_InteractiveRow> createState() => _InteractiveRowState();
}

class _InteractiveRowState extends State<_InteractiveRow> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) => DiagonalRow(
    key: const ValueKey('kit-gallery-row-interactive'),
    mark: _selected ? DiagonalRowMark.selected : DiagonalRowMark.none,
    onTap: () => setState(() => _selected = !_selected),
    padding: EdgeInsets.only(left: diagonalCutDepth(44) + 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        _selected ? '선택됨 · 다시 누르면 해제합니다' : '눌러서 선택합니다',
        style: AppType.bodySmall.copyWith(color: AppColors.text),
      ),
    ),
  );
}
