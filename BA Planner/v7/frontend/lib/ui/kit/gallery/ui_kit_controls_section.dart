// UI Kit 갤러리 — FE2-b 소형 컨트롤·제목.
//
// 배치(가로 좌표는 시안 artboard x − 40):
// - 1줄: W-Layout-Widgets 첫 줄. 제목 3단계 · 칩/세그먼트/버튼 · 단계 태그 · 변경 강조 + 조절(250 높이).
// - 2줄: W-Filter-Widgets 첫 줄. 토글 칩 · 타입 칩 · 적용 중 필터(250 높이).
// - 3줄: W-Filter 둘째 줄 자리. 범위 슬라이더·성급 범위는 FE3-d 범위라 그 자리에 레일 버튼과
//   스위치·스테퍼를 두고, 필터 버튼은 시안 위치에 둔다(330 높이).
// - 3½줄(FE3-d1): W-Filter 둘째 줄의 범위 슬라이더·성급 범위(250 높이, 시안 x − 40).
// - 4줄: 상태 견본(기본 · hover · 선택 · 비활성). 시안 CSS에 규칙이 없는 칸은 "—"다.
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../geometry/diagonal_geometry.dart';
import '../ba_chip.dart';
import '../buttons.dart';
import '../diagonal_row.dart';
import '../range_controls.dart';
import '../skew_controls.dart';
import '../stepper.dart';
import '../titles.dart';

const _contentWidth = 2480.0;

/// 시안 `.mut` 11px.
const _mut = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.35,
  color: AppColors.textMuted,
);

/// 시안 타일 하단 `.wsub` 11.5px.
const _tileCaption = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionPlusSize,
  height: 1.5,
  color: AppColors.textMuted,
);

/// FE2-b 갤러리 구역. [UiKitGalleryPage]가 FE2-a 타일 아래에 둔다.
class UiKitControlsSection extends StatelessWidget {
  const UiKitControlsSection({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _TileRow(
        height: 250,
        tiles: [
          (0.0, _TitlesTile()),
          (658.2, _ChipsSegmentsButtonsTile()),
          (1316.4, _StageTagTile()),
          (1859.4, _NudgeTile()),
        ],
      ),
      SizedBox(height: 24),
      _TileRow(
        height: 250,
        tiles: [
          (0.0, _ToggleChipTile()),
          (820.0, _TypeChipTile()),
          (1772.6, _ActiveFilterTile()),
        ],
      ),
      SizedBox(height: 24),
      _TileRow(
        height: 330,
        tiles: [
          (0.0, _RailButtonTile()),
          (965.8, _SwitchStepperTile()),
          (1831.6, _FilterButtonTile()),
        ],
      ),
      SizedBox(height: 24),
      _TileRow(
        height: 250,
        tiles: [(0.0, _RangeSliderTile()), (960.4, _StarRangeTile())],
      ),
      SizedBox(height: 24),
      _StateSamplesTile(),
    ],
  );
}

// ---------------------------------------------------------------------------
// 틀

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

/// W-* 위젯 타일: 평행사변형 카드 + 타일 제목 + 가운데 내용 + 아래 설명.
class _KitTile extends StatelessWidget {
  const _KitTile({
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
    // 시안 타일의 안쪽 여백: 80° 컷 + 10 + 60.
    final inset = diagonalCutDepth(height) + 70;
    return SizedBox(
      key: ValueKey('kit-gallery-fe2b-$tileKey'),
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
// 1줄: W-Layout-Widgets

class _TitlesTile extends StatelessWidget {
  const _TitlesTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'titles',
    title: '제목 3단계',
    caption: '패널 제목(섹션) · 타일 안 제목 · 소제목. 요소마다 헤더로 구분합니다.',
    width: 678.3,
    height: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelTitle(
          '패널 제목',
          trailing: BaChip(label: '보조 칩', tone: AppTones.gray),
        ),
        SizedBox(height: 22),
        TileTitle(
          '타일 안 제목',
          trailing: BaChip(label: '1주', tone: AppTones.pink),
        ),
        SizedBox(height: 22),
        SubHeader('소제목 · 파란 점', fontSize: AppType.microSize),
      ],
    ),
  );
}

class _ChipsSegmentsButtonsTile extends StatelessWidget {
  const _ChipsSegmentsButtonsTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'chips',
    title: '칩 · 세그먼트 · 버튼',
    caption: '칩 6색 역할 고정. 세그먼트는 사선, 선택 = 분홍 테두리.',
    width: 678.3,
    height: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SegmentDemo(),
        SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            BaChip(label: '정보'),
            BaChip(label: '강조', tone: AppTones.pink),
            BaChip(label: '충분', tone: AppTones.ok),
            BaChip(label: '주의', tone: AppTones.warn),
            BaChip(label: '위험', tone: AppTones.danger),
            BaChip(label: '보조', tone: AppTones.gray),
          ],
        ),
        SizedBox(height: 16),
        _TonalDemo(),
      ],
    ),
  );
}

class _SegmentDemo extends StatefulWidget {
  const _SegmentDemo();

  @override
  State<_SegmentDemo> createState() => _SegmentDemoState();
}

class _SegmentDemoState extends State<_SegmentDemo> {
  String _selected = '1주';

  @override
  Widget build(BuildContext context) => SkewSegmented<String>(
    key: const ValueKey('kit-gallery-segment'),
    segments: const [
      SkewSegment(value: '1주', label: '1주'),
      SkewSegment(value: '2주', label: '2주'),
      SkewSegment(value: '4주', label: '4주'),
    ],
    selected: _selected,
    onChanged: (value) => setState(() => _selected = value),
    height: 28,
    fontSize: AppType.captionSize,
  );
}

class _TonalDemo extends StatelessWidget {
  const _TonalDemo();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TonalButton(
        label: '주 버튼',
        icon: Icons.layers_outlined,
        variant: TonalButtonVariant.primary,
        onPressed: () {},
      ),
      const SizedBox(width: 10),
      TonalButton(
        label: '보조 버튼',
        icon: Icons.view_agenda_outlined,
        onPressed: () {},
      ),
    ],
  );
}

class _StageTagTile extends StatelessWidget {
  const _StageTagTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'stage-tags',
    title: '단계 태그',
    caption: '계획 만들기. 1 파랑 · 2 분홍 · 3 노랑, 채움 = 지금 보는 단계.',
    width: 563,
    height: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            StageTag(stage: 1),
            SizedBox(width: 8),
            StageTag(stage: 2),
            SizedBox(width: 8),
            StageTag(stage: 3),
          ],
        ),
        SizedBox(height: 14),
        Row(
          children: [
            StageTag(stage: 1, selected: true),
            SizedBox(width: 8),
            StageTag(stage: 2, selected: true),
            SizedBox(width: 8),
            StageTag(stage: 3, selected: true, label: '3단계 · 선택'),
          ],
        ),
      ],
    ),
  );
}

class _NudgeTile extends StatelessWidget {
  const _NudgeTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'nudge',
    title: '변경 강조 + 조절',
    caption: '미세 조절 ▲▼(.nd). 바뀐 값의 평행사변형 강조는 계획 만들기(FE4)에서 만듭니다.',
    width: 620.6,
    height: 250,
    child: _NudgeDemo(),
  );
}

class _NudgeDemo extends StatefulWidget {
  const _NudgeDemo();

  @override
  State<_NudgeDemo> createState() => _NudgeDemoState();
}

class _NudgeDemoState extends State<_NudgeDemo> {
  int _level = 90;

  @override
  Widget build(BuildContext context) {
    final value = kitDisplayStyle(
      AppType.headlineMediumSize,
    ).copyWith(fontWeight: AppType.bold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('Lv.78', style: value),
            const SizedBox(width: 24),
            Text(
              'Lv.$_level',
              key: const ValueKey('kit-gallery-nudge-value'),
              style: value,
            ),
            const SizedBox(width: 4),
            NudgeButtons(
              key: const ValueKey('kit-gallery-nudge'),
              increaseLabel: '레벨 올리기',
              decreaseLabel: '레벨 낮추기',
              onIncrease: _level < 90 ? () => setState(() => _level++) : null,
              onDecrease: _level > 1 ? () => setState(() => _level--) : null,
            ),
            const SizedBox(width: 24),
            Text('T8', style: value),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text('hover 고정', style: _mut),
            const SizedBox(width: 6),
            NudgeButtons(onIncrease: () {}, onDecrease: () {}, hovered: true),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2줄: W-Filter-Widgets

class _ToggleChipTile extends StatelessWidget {
  const _ToggleChipTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'toggle-chips',
    title: '토글 칩',
    caption: '10° 사선. 켜짐 = 분홍 채움 + 테두리, 오른쪽 숫자 = 해당 학생 수.',
    width: 840.1,
    height: 250,
    child: _ToggleChipDemo(),
  );
}

class _ToggleChipDemo extends StatefulWidget {
  const _ToggleChipDemo();

  @override
  State<_ToggleChipDemo> createState() => _ToggleChipDemoState();
}

class _ToggleChipDemoState extends State<_ToggleChipDemo> {
  static const _chips = [
    ('게헨나', 28),
    ('밀레니엄', 31),
    ('★3', null),
    ('계획에 없는 학생만', null),
  ];
  final Set<String> _on = {'밀레니엄', '계획에 없는 학생만'};

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('꺼짐 · 켜짐 · 개수 표시', style: _mut),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (label, count) in _chips)
            SkewToggleChip(
              key: ValueKey('kit-gallery-toggle-$label'),
              label: label,
              count: count,
              selected: _on.contains(label),
              onChanged: (value) => setState(
                () => value ? _on.add(label) : _on.remove(label),
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      const Text('같은 줄 = "또는", 줄끼리 = "그리고"', style: _mut),
    ],
  );
}

class _TypeChipTile extends StatelessWidget {
  const _TypeChipTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'type-chips',
    title: '타입 칩',
    caption: '공격·방어 타입 색을 앞 막대로. 색만으로 구분하지 않게 이름을 항상 씀.',
    width: 972.7,
    height: 250,
    child: _TypeChipDemo(),
  );
}

class _TypeChipDemo extends StatefulWidget {
  const _TypeChipDemo();

  @override
  State<_TypeChipDemo> createState() => _TypeChipDemoState();
}

class _TypeChipDemoState extends State<_TypeChipDemo> {
  static const _attack = [
    ('폭발', AppColors.typeExplosive),
    ('관통', AppColors.typePiercing),
    ('신비', AppColors.typeMystic),
    ('진동', AppColors.typeSonic),
  ];
  static const _defense = [
    ('경장갑', AppColors.typeExplosive),
    ('중장갑', AppColors.typePiercing),
    ('특수장갑', AppColors.typeMystic),
    ('탄력장갑', AppColors.typeSonic),
    ('복합장갑', AppColors.typeComposite),
  ];
  final Set<String> _on = {'폭발'};

  Widget _chips(List<(String, Color)> items) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final (label, color) in items)
        TypeChip(
          key: ValueKey('kit-gallery-type-$label'),
          label: label,
          color: color,
          selected: _on.contains(label),
          onChanged: (value) =>
              setState(() => value ? _on.add(label) : _on.remove(label)),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('공격 타입', style: _mut),
      const SizedBox(height: 10),
      _chips(_attack),
      const SizedBox(height: 14),
      const Text('방어 타입', style: _mut),
      const SizedBox(height: 10),
      _chips(_defense),
    ],
  );
}

class _ActiveFilterTile extends StatelessWidget {
  const _ActiveFilterTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'active-filters',
    title: '적용 중 필터',
    caption: '헤더와 검색 줄에 같은 분홍 칩. 결과 수는 큰 숫자.',
    width: 707.4,
    height: 250,
    child: _ActiveFilterDemo(),
  );
}

class _ActiveFilterDemo extends StatefulWidget {
  const _ActiveFilterDemo();

  @override
  State<_ActiveFilterDemo> createState() => _ActiveFilterDemoState();
}

class _ActiveFilterDemoState extends State<_ActiveFilterDemo> {
  final List<String> _filters = ['밀레니엄', '계획에 없는 학생만', '레벨 70~90'];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('모달 헤더 · 검색 줄', style: _mut),
      const SizedBox(height: 14),
      SizedBox(
        height: 24,
        child: _filters.isEmpty
            ? const Align(
                alignment: Alignment.centerLeft,
                child: Text('적용 중인 필터가 없습니다.', style: _mut),
              )
            : Wrap(
                spacing: 6,
                children: [
                  for (final label in _filters)
                    BaChip(
                      key: ValueKey('kit-gallery-active-filter-$label'),
                      label: label,
                      tone: AppTones.pink,
                      onRemove: () => setState(() => _filters.remove(label)),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('24', style: kitDisplayStyle(AppType.headlineMediumSize)),
          const SizedBox(width: 6),
          const Text(
            '/ 170명',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.bodySmallSize,
              height: 1.35,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const Text('× 로 하나씩 뺍니다. 개수는 적용 전 미리보기.', style: _mut),
    ],
  );
}

// ---------------------------------------------------------------------------
// 3줄: 레일 버튼 · 스위치/스테퍼 · 필터 버튼

class _RailButtonTile extends StatelessWidget {
  const _RailButtonTile();

  @override
  Widget build(BuildContext context) => _KitTile(
    tileKey: 'rail-buttons',
    title: '레일 버튼',
    caption: '아래 버튼일수록 레일을 따라 폭이 줄어듭니다. 선택 = 왼쪽 3px 막대 + 그라데이션.',
    width: 1000,
    height: 330,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 340,
          child: RailButtonGroup(
            key: const ValueKey('kit-gallery-rail-group'),
            buttons: [
              RailButton(
                key: const ValueKey('kit-gallery-rail-0'),
                variant: RailButtonVariant.selectedPink,
                height: 58,
                onPressed: () {},
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '시나리오 목록',
                            style: TextStyle(
                              fontSize: AppType.bodyLargeSize,
                              fontWeight: AppType.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '저장된 시나리오 6',
                            style: TextStyle(fontSize: AppType.captionSize),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.expand_more),
                  ],
                ),
              ),
              RailButton(
                key: const ValueKey('kit-gallery-rail-1'),
                variant: RailButtonVariant.ghost,
                onPressed: () {},
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back),
                    SizedBox(width: 10),
                    Text('활성 계획으로'),
                  ],
                ),
              ),
              RailButton(
                key: const ValueKey('kit-gallery-rail-2'),
                variant: RailButtonVariant.primary,
                onPressed: () {},
                child: const Row(
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 10),
                    Text('새 시나리오', style: TextStyle(fontWeight: AppType.bold)),
                  ],
                ),
              ),
              RailButton(
                key: const ValueKey('kit-gallery-rail-3'),
                variant: RailButtonVariant.ghost,
                onPressed: () {},
                child: const Text('비교하기'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
        SizedBox(
          width: 340,
          child: RailButtonGroup(
            buttons: [
              RailButton(onPressed: () {}, child: const Text('기본(.btn)')),
              RailButton(
                variant: RailButtonVariant.selectedBlue,
                onPressed: () {},
                child: const Text('부족한 것(sel-blue)'),
              ),
              RailButton(
                variant: RailButtonVariant.done,
                onPressed: () {},
                child: const Text('완료(done)'),
              ),
              RailButton(
                variant: RailButtonVariant.tri,
                onPressed: () {},
                child: const Text('보조(tri)'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SwitchStepperTile extends StatelessWidget {
  const _SwitchStepperTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'switch-stepper',
    title: '스위치 · 스테퍼 · MAX',
    caption: '토글 스위치(40×22) · 스테퍼(시안 · 요소 빌더 현재 모양) · MAX 배지.',
    width: 900,
    height: 330,
    child: _SwitchStepperDemo(),
  );
}

class _SwitchStepperDemo extends StatefulWidget {
  const _SwitchStepperDemo();

  @override
  State<_SwitchStepperDemo> createState() => _SwitchStepperDemoState();
}

class _SwitchStepperDemoState extends State<_SwitchStepperDemo> {
  bool _autoSave = true;
  bool _compare = false;
  int _level = 90;
  int _ex = 5;
  int _builderLevel = 80;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KV(
            label: '자동 저장',
            value: BaSwitch(
              key: const ValueKey('kit-gallery-switch'),
              value: _autoSave,
              semanticLabel: '자동 저장',
              onChanged: (value) => setState(() => _autoSave = value),
            ),
          ),
          const SizedBox(height: 14),
          KV(
            label: '비교 보기',
            value: BaSwitch(
              value: _compare,
              semanticLabel: '비교 보기',
              onChanged: (value) => setState(() => _compare = value),
            ),
          ),
        ],
      ),
      const SizedBox(width: 40),
      BaStepper(
        key: const ValueKey('kit-gallery-stepper-level'),
        label: '학생 레벨',
        value: _level,
        minimum: 1,
        maximum: 90,
        propagated: false,
        unsupported: false,
        valueFontSize: AppType.stepperValueSize,
        layout: BaStepperLayout.labelAbove,
        onChanged: (value) => setState(() => _level = value),
      ),
      const SizedBox(width: 24),
      BaStepper(
        key: const ValueKey('kit-gallery-stepper-ex'),
        label: 'EX',
        value: _ex,
        minimum: 1,
        maximum: 5,
        propagated: true,
        unsupported: false,
        valueFontSize: AppType.stepperValueSize,
        layout: BaStepperLayout.labelAbove,
        onChanged: (value) => setState(() => _ex = value),
      ),
      const SizedBox(width: 40),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('요소 빌더 현재 모양', style: _mut),
          const SizedBox(height: 6),
          BaStepper(
            key: const ValueKey('kit-gallery-stepper-builder'),
            label: 'Lv',
            value: _builderLevel,
            minimum: 1,
            maximum: 90,
            propagated: false,
            unsupported: false,
            valueFontSize: AppType.stepperValueSize,
            onChanged: (value) => setState(() => _builderLevel = value),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 3½줄: W-Filter 둘째 줄 범위 슬라이더 · 성급 범위 (FE3-d1)

class _RangeSliderTile extends StatelessWidget {
  const _RangeSliderTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'range-slider',
    title: '범위 슬라이더',
    caption: '핸들 두 개 = 최소·최대. 기본값(전체)이 아니면 줄 전체를 분홍으로 강조.',
    width: 980.5,
    height: 250,
    child: _RangeSliderDemo(),
  );
}

class _RangeSliderDemo extends StatefulWidget {
  const _RangeSliderDemo();

  @override
  State<_RangeSliderDemo> createState() => _RangeSliderDemoState();
}

class _RangeSliderDemoState extends State<_RangeSliderDemo> {
  var _level = (70, 90);
  var _ex = (1, 5);
  var _tier = (0, 10);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      RangeSliderRow(
        key: const ValueKey('kit-gallery-range-level'),
        label: '학생 레벨',
        min: 1,
        max: 90,
        low: _level.$1,
        high: _level.$2,
        onChanged: (low, high) => setState(() => _level = (low, high)),
      ),
      const SizedBox(height: 10),
      RangeSliderRow(
        key: const ValueKey('kit-gallery-range-ex'),
        label: 'EX',
        min: 1,
        max: 5,
        low: _ex.$1,
        high: _ex.$2,
        formatValue: (value) => value >= 5 ? 'M' : '$value',
        semanticValue: (value) => '$value',
        onChanged: (low, high) => setState(() => _ex = (low, high)),
      ),
      const SizedBox(height: 10),
      RangeSliderRow(
        key: const ValueKey('kit-gallery-range-tier'),
        label: '장비 티어',
        caption: '3칸 중 가장 낮은 칸',
        min: 0,
        max: 10,
        low: _tier.$1,
        high: _tier.$2,
        formatValue: (value) => 'T$value',
        semanticValue: (value) => '$value티어',
        onChanged: (low, high) => setState(() => _tier = (low, high)),
      ),
    ],
  );
}

class _StarRangeTile extends StatelessWidget {
  const _StarRangeTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'star-range',
    title: '성급 범위',
    caption: '성급 + 전용무기 성급을 v7 9칸 막대 하나로.',
    width: 980.5,
    height: 250,
    child: _StarRangeDemo(),
  );
}

class _StarRangeDemo extends StatefulWidget {
  const _StarRangeDemo();

  @override
  State<_StarRangeDemo> createState() => _StarRangeDemoState();
}

class _StarRangeDemoState extends State<_StarRangeDemo> {
  var _narrowed = (3, 6);
  var _full = (1, starRangeStepCount);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StarRangeBar(
        key: const ValueKey('kit-gallery-star-narrowed'),
        low: _narrowed.$1,
        high: _narrowed.$2,
        onChanged: (low, high) => setState(() => _narrowed = (low, high)),
      ),
      const SizedBox(height: 10),
      StarRangeBar(
        key: const ValueKey('kit-gallery-star-full'),
        low: _full.$1,
        high: _full.$2,
        onChanged: (low, high) => setState(() => _full = (low, high)),
      ),
      const SizedBox(height: 10),
      const Text(
        '5칸 노랑 = 학생 ★ · 4칸 파랑 = 전용무기 ★. 고른 구간만 분홍 테두리.',
        style: _mut,
      ),
    ],
  );
}

class _FilterButtonTile extends StatelessWidget {
  const _FilterButtonTile();

  @override
  Widget build(BuildContext context) => _KitTile(
    tileKey: 'filter-button',
    title: '필터 버튼',
    caption: '검색 줄 끝. 적용 개수를 붙이고, 적용 중이면 분홍.',
    width: 648.4,
    height: 330,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text('없음', style: _mut),
            const SizedBox(width: 12),
            FilterButton(
              key: const ValueKey('kit-gallery-filter-idle'),
              activeCount: 0,
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            const Text('적용 중', style: _mut),
            const SizedBox(width: 12),
            FilterButton(
              key: const ValueKey('kit-gallery-filter-active'),
              activeCount: 3,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('모달 오른쪽 위', style: _mut),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 6,
          children: [
            BaChip(label: '프리셋', leading: Icon(Icons.bookmark_border)),
            BaChip(label: '초기화', leading: Icon(Icons.refresh)),
            BaChip(
              label: '적용',
              tone: AppTones.pink,
              leading: Icon(Icons.check),
            ),
          ],
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 4줄: 상태 견본

enum _SampleState { normal, hover, selected, disabled }

const _sampleStateLabels = {
  _SampleState.normal: '기본',
  _SampleState.hover: 'hover',
  _SampleState.selected: '선택 · 켜짐',
  _SampleState.disabled: '비활성',
};

typedef _SampleBuilder = Widget? Function(_SampleState state);

void _noop() {}

void _noopBool(bool _) {}

void _noopString(String _) {}

VoidCallback? _press(_SampleState state) =>
    state == _SampleState.disabled ? null : _noop;

final List<(String, _SampleBuilder)> _leftSamples = [
  (
    '세그먼트',
    (state) => state == _SampleState.hover
        ? null
        : SkewSegmented<String>(
            segments: const [SkewSegment(value: 'a', label: '총력전 준비')],
            selected: state == _SampleState.selected ? 'a' : null,
            onChanged: state == _SampleState.disabled ? null : _noopString,
          ),
  ),
  (
    '토글 칩',
    (state) => state == _SampleState.hover
        ? null
        : SkewToggleChip(
            label: '밀레니엄',
            count: 31,
            selected: state == _SampleState.selected,
            onChanged: state == _SampleState.disabled ? null : _noopBool,
          ),
  ),
  (
    '타입 칩',
    (state) => state == _SampleState.hover
        ? null
        : TypeChip(
            label: '신비',
            color: AppColors.typeMystic,
            selected: state == _SampleState.selected,
            onChanged: state == _SampleState.disabled ? null : _noopBool,
          ),
  ),
  (
    '필터 버튼',
    (state) => state == _SampleState.hover
        ? null
        : FilterButton(
            activeCount: state == _SampleState.selected ? 3 : 0,
            onPressed: _press(state),
          ),
  ),
  (
    '제거 칩',
    (state) => switch (state) {
      _SampleState.normal => const BaChip(
        label: '밀레니엄',
        tone: AppTones.pink,
        onRemove: _noop,
      ),
      _SampleState.disabled => const BaChip(
        label: '밀레니엄',
        tone: AppTones.pink,
      ),
      _ => null,
    },
  ),
  (
    '스위치',
    (state) => state == _SampleState.hover
        ? null
        : BaSwitch(
            value: state == _SampleState.selected,
            onChanged: state == _SampleState.disabled ? null : _noopBool,
          ),
  ),
  (
    '단계 태그',
    (state) => switch (state) {
      _SampleState.normal => const StageTag(stage: 2),
      _SampleState.selected => const StageTag(stage: 2, selected: true),
      _ => null,
    },
  ),
];

final List<(String, _SampleBuilder)> _rightSamples = [
  (
    'tonal 기본',
    (state) => state == _SampleState.selected
        ? null
        : TonalButton(
            label: '보조 버튼',
            hovered: state == _SampleState.hover,
            onPressed: _press(state),
          ),
  ),
  (
    'tonal 주(pri)',
    (state) => state == _SampleState.selected
        ? null
        : TonalButton(
            label: '주 버튼',
            variant: TonalButtonVariant.primary,
            hovered: state == _SampleState.hover,
            onPressed: _press(state),
          ),
  ),
  (
    '레일 버튼',
    (state) => SizedBox(
      width: 200,
      child: RailButton(
        variant: state == _SampleState.selected
            ? RailButtonVariant.selectedPink
            : RailButtonVariant.ghost,
        hovered: state == _SampleState.hover,
        onPressed: _press(state),
        child: const Text('활성 계획으로'),
      ),
    ),
  ),
  (
    '스텝 버튼(시안)',
    (state) => state == _SampleState.selected
        ? null
        : StepButton(
            text: '+',
            look: StepButtonLook.prototype,
            enabled: state != _SampleState.disabled,
            hovered: state == _SampleState.hover,
            onTap: _noop,
          ),
  ),
  (
    '미세 조절',
    (state) => state == _SampleState.selected
        ? null
        : NudgeButtons(
            hovered: state == _SampleState.hover,
            onIncrease: _press(state),
            onDecrease: _press(state),
          ),
  ),
  (
    'MAX 배지',
    (state) => switch (state) {
      _SampleState.normal => MaxBadge(
        controlKey: 'kit-gallery-max',
        enabled: true,
        onTap: _noop,
      ),
      _SampleState.disabled => MaxBadge(
        controlKey: 'kit-gallery-max-disabled',
        enabled: false,
        onTap: _noop,
      ),
      _ => null,
    },
  ),
];

class _StateSamplesTile extends StatelessWidget {
  const _StateSamplesTile();

  @override
  Widget build(BuildContext context) => const _KitTile(
    tileKey: 'states',
    title: '상태 견본',
    caption:
        '시안 CSS에 규칙이 있는 상태만 그립니다("—" = 규칙 없음). hover는 고정해서 보여 주고, '
        '비활성 모양(불투명도 .45)은 시안에 없어 키트 공통 값입니다.',
    width: _contentWidth,
    height: 480,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SampleGrid(rows: _SampleRows.left),
        SizedBox(width: 60),
        _SampleGrid(rows: _SampleRows.right),
      ],
    ),
  );
}

enum _SampleRows { left, right }

class _SampleGrid extends StatelessWidget {
  const _SampleGrid({required this.rows});

  final _SampleRows rows;

  static const _labelWidth = 150.0;
  static const _cellWidth = 210.0;
  static const _rowHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final samples = rows == _SampleRows.left ? _leftSamples : _rightSamples;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: _labelWidth),
            for (final state in _SampleState.values)
              SizedBox(
                width: _cellWidth,
                child: SubHeader(
                  _sampleStateLabels[state]!,
                  fontSize: AppType.captionSize,
                ),
              ),
          ],
        ),
        for (final (label, builder) in samples) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: _labelWidth,
                child: Text(
                  label,
                  style: AppType.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              for (final state in _SampleState.values)
                SizedBox(
                  width: _cellWidth,
                  height: _rowHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: builder(state) ?? const Text('—', style: _mut),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
