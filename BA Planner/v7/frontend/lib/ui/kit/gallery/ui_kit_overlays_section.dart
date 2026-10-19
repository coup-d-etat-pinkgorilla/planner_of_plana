// UI Kit 갤러리 — FE2-c 오버레이.
//
// 배치:
// - 1줄: W-Info-Popover 보드(1160×400, 시안 좌표 그대로) · BaModal 스크림 프리셋 4종.
// - 2줄: W-Layout-Widgets "팝오버 (열린 상태)" 줄(가로 = 시안 x − 40, 세로 = 시안 y − 852).
//   부족 재화 플라이아웃(FD-090 부족량·단계별) · 페이즈 팝오버 · (i) 도움말(오른쪽 정렬).
// - 3줄: 나머지 프리셋 견본(시나리오 분야별 그룹 · 통계 점 · 아래 `.dn` · 왼쪽 아래 `.dl` 사선 카드).
//   닫힌 채로 두며 마우스를 올리거나 누르거나 키보드로 포커스하면 열린다(같은 그룹이라 하나만 열린다).
// 시안의 `.open` 견본은 처음부터 열어 두고, 각자 다른 그룹이라 함께 열린다. 바깥을 누르면 닫히므로
// "열린 견본 다시 열기"로 되살린다. 문구는 시안 그대로이고 값은 시안 예시 값의 정적 fixture다.
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../geometry/diagonal_geometry.dart';
import '../anchored_flyout.dart';
import '../ba_chip.dart';
import '../ba_modal.dart';
import '../buttons.dart';
import '../game_assets.dart';
import '../diagonal_row.dart';
import '../info_popover.dart';
import '../item_icon_tile.dart';
import '../kit_overlay.dart';
import '../portrait_strip.dart';
import '../shortage_flyout.dart';
import '../titles.dart';

/// 시안 `.wsub` 13px / 1.5.
const _wsub = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySize,
  height: 1.5,
  color: AppColors.textMuted,
);

/// 시안 `.cap` 11px w600.
const _cap = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.35,
  fontWeight: AppType.semiBold,
  color: AppColors.textMuted,
);

/// 시안 `.mut`.
TextStyle _mut(double size) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.35,
  color: AppColors.textMuted,
);

TextStyle _bold(double size, {Color color = AppColors.text}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.3,
  fontWeight: AppType.bold,
  color: color,
);

/// 시안 요약 줄·트리거 바탕(#1b2a3a).
const _triggerFill = Color(0xff1b2a3a);

/// FE2-c 갤러리 구역. [UiKitGalleryPage]가 FE2-b 구역 아래에 둔다.
class UiKitOverlaysSection extends StatefulWidget {
  const UiKitOverlaysSection({super.key});

  @override
  State<UiKitOverlaysSection> createState() => _UiKitOverlaysSectionState();
}

class _UiKitOverlaysSectionState extends State<UiKitOverlaysSection> {
  int _generation = 0;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TonalButton(
        key: const ValueKey('kit-gallery-fe2c-reopen'),
        label: '열린 견본 다시 열기',
        icon: Icons.refresh,
        onPressed: () => setState(() => _generation++),
      ),
      const SizedBox(height: 20),
      KeyedSubtree(
        key: ValueKey('kit-gallery-fe2c-generation-$_generation'),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoPopoverBoard(),
                SizedBox(width: 40),
                _ModalTile(),
              ],
            ),
            SizedBox(height: 32),
            _LayoutPopoverStrip(),
          ],
        ),
      ),
      const SizedBox(height: 32),
      const _PresetSamples(),
    ],
  );
}

// ---------------------------------------------------------------------------
// 1줄: W-Info-Popover (1160×400)

class _InfoPopoverBoard extends StatefulWidget {
  const _InfoPopoverBoard();

  @override
  State<_InfoPopoverBoard> createState() => _InfoPopoverBoardState();
}

class _InfoPopoverBoardState extends State<_InfoPopoverBoard> {
  final _leftGroup = KitOverlayGroup(debugLabel: 'gallery info left');
  final _rightGroup = KitOverlayGroup(debugLabel: 'gallery info right');

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('kit-gallery-fe2c-info'),
    width: 1160,
    height: 400,
    child: KitOverlayBounds(
      child: DecoratedBox(
        // artboard 경계 표시(시안에는 없음).
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 40,
              top: 28,
              child: Text('도움말 (i) · 팝오버', style: kitDisplayStyle(18)),
            ),
            const Positioned(
              left: 40,
              top: 58,
              width: 980,
              child: Text(
                '사용법·설명 문장은 화면에 늘 띄우지 않고 제목 옆 (i) 뒤에 둡니다. '
                '마우스를 올리거나, 키보드로 포커스하거나, 누르면 열립니다. '
                '상태·수치·선택지 설명은 그대로 보여 줍니다.',
                style: _wsub,
              ),
            ),
            const Positioned(
              left: 40,
              top: 104,
              child: Text('닫힘', style: _wsub),
            ),
            const Positioned(
              left: 300,
              top: 104,
              child: Text('열림 · 왼쪽 정렬', style: _wsub),
            ),
            const Positioned(
              left: 820,
              top: 104,
              child: Text('열림 · 오른쪽 정렬 (화면 오른쪽 끝)', style: _wsub),
            ),
            Positioned(
              left: 40,
              top: 136,
              child: Row(
                children: [
                  Text('고른 학생', style: kitDisplayStyle(19)),
                  const SizedBox(width: 8),
                  InfoPopover(
                    key: const ValueKey('kit-gallery-info-closed'),
                    label: '고른 학생',
                    title: '고른 학생',
                    children: [
                      InfoPopoverText([
                        const TextSpan(text: '고른 순서대로 '),
                        InfoPopoverText.em('목표 정하기'),
                        const TextSpan(text: ' 탭에 놓입니다.'),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 300,
              top: 136,
              child: Row(
                children: [
                  Text('단계 순서', style: kitDisplayStyle(19)),
                  const SizedBox(width: 8),
                  InfoPopover(
                    key: const ValueKey('kit-gallery-info-open-left'),
                    label: '단계 순서 정하는 법',
                    title: '단계 순서 정하는 법',
                    width: 300,
                    initiallyOpen: true,
                    group: _leftGroup,
                    children: const [
                      InfoPopoverList([
                        '카드를 끌어 칸을 옮깁니다.',
                        '선행 단계보다 앞 칸에는 놓을 수 없습니다.',
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 820,
              top: 136,
              child: Row(
                children: [
                  const SizedBox(width: 200),
                  const Text('넣을 단계', style: _cap),
                  const SizedBox(width: 8),
                  InfoPopover(
                    key: const ValueKey('kit-gallery-info-open-right'),
                    label: '넣을 단계',
                    title: '넣을 단계',
                    width: 300,
                    align: KitOverlayAlign.end,
                    initiallyOpen: true,
                    group: _rightGroup,
                    children: [
                      InfoPopoverText([
                        const TextSpan(text: '줄 끝의 '),
                        InfoPopoverText.em('1 · 2 · 3'),
                        const TextSpan(text: '을 누르면 그 항목이 해당 단계로 들어갑니다.'),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 40,
              top: 330,
              width: 980,
              child: Text(
                '버튼 24px 원 · 기본 #71c7f4@.12 / 열림·호버 #f2b3ef@.24 · 팝오버 #0d151f r9 · '
                '외곽 #71c7f4@.38 · 제목 앞 분홍 사선 막대 · 강조어 #f7c9f4 · '
                '섹션 안에서 잘리지 않게 왼쪽/오른쪽 정렬을 고릅니다',
                style: _wsub,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 1줄 오른쪽: BaModal 스크림 프리셋

class _ModalTile extends StatelessWidget {
  const _ModalTile();

  static const _height = 400.0;

  @override
  Widget build(BuildContext context) {
    final inset = diagonalCutDepth(_height) + 70;
    return SizedBox(
      key: const ValueKey('kit-gallery-fe2c-modal'),
      width: 1280,
      height: _height,
      child: WidgetTile(
        padding: EdgeInsets.fromLTRB(inset, 16, inset, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TileTitle('모달 · 스크림 프리셋 (FD-013)'),
            const SizedBox(height: 16),
            const Text(
              '스크림 알파는 시안 화면마다 다릅니다. 하나로 맞추지 않고 네 가지를 그대로 둡니다. '
              'Esc를 누르거나 스크림을 누르면 닫히고, 포커스는 연 버튼으로 돌아갑니다.',
              style: _wsub,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final scrim in BaScrim.values) _ModalDemoButton(scrim: scrim),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _scrimLabels = {
  BaScrim.filter: '필터 팝업 · .8 + blur 2',
  BaScrim.scan: '홈 스캔 · 계정 추가 · .72 + blur 2',
  BaScrim.excel: '엑셀 가져오기 · .62',
  BaScrim.anchored: '앵커 팝업 · .35',
};

class _ModalDemoButton extends StatefulWidget {
  const _ModalDemoButton({required this.scrim});

  final BaScrim scrim;

  @override
  State<_ModalDemoButton> createState() => _ModalDemoButtonState();
}

class _ModalDemoButtonState extends State<_ModalDemoButton> {
  final _controller = BaModalController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _scrimLabels[widget.scrim]!;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelTitle(label),
        const SizedBox(height: 12),
        const Text(
          '스크림 위에 놓인 패널입니다. Esc를 누르거나 바깥을 누르면 닫힙니다.',
          style: kitPopoverTextStyle,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TonalButton(
            key: ValueKey('kit-gallery-modal-close-${widget.scrim.name}'),
            label: '닫기',
            onPressed: _controller.close,
          ),
        ),
      ],
    );
    return BaModal(
      controller: _controller,
      scrim: widget.scrim,
      label: label,
      builder: (context) => widget.scrim == BaScrim.excel
          ? BaModalPanel.sheet(width: 640, child: body)
          : BaModalPanel.dialog(width: 520, child: body),
      child: TonalButton(
        key: ValueKey('kit-gallery-modal-${widget.scrim.name}'),
        label: label,
        onPressed: _controller.open,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2줄: W-Layout-Widgets "팝오버 (열린 상태)"

// 견본 아이콘(FE2-d부터 실제 그림. 파일이 없으면 빈 상자).
final _techNoteIcon = GameAssets.itemIcon(
  'skill_book',
  'Item_Icon_SkillBook_Millennium_3',
);
final _tacticalBdIcon = GameAssets.itemIcon(
  'skill_db',
  'Item_Icon_Material_ExSkill_Millennium_3',
);
final _watchIcon = GameAssets.equipmentIcon('Watch', 10, piece: true);
final _hatIcon = GameAssets.equipmentIcon('Hat', 9, piece: true);
final _hairpinIcon = GameAssets.equipmentIcon('Hairpin', 10, piece: true);
final _nebraIcon = GameAssets.itemIcon('ooparts', 'Item_Icon_Material_Nebra_3');

final _flow4Items = [
  ShortageItem(
    name: '기술 노트 (최상급)',
    shortage: 30,
    owned: 66,
    needed: 96,
    iconAsset: _techNoteIcon,
    iconBackground: ItemBackground.yellow,
    uses: const [
      ShortageUse(student: '호시노', stage: 2, studentId: 'hoshino'),
      ShortageUse(student: '리오(무장)', stage: 1, studentId: 'rio_battle'),
    ],
  ),
  ShortageItem(
    name: '설계도 · 시계 T10',
    shortage: 14,
    owned: 76,
    needed: 90,
    iconAsset: _watchIcon,
    uses: const [
      ShortageUse(student: '리오(무장)', stage: 2, studentId: 'rio_battle'),
    ],
  ),
  ShortageItem(
    name: '전술 교육 BD (최상급)',
    shortage: 8,
    owned: 10,
    needed: 18,
    iconAsset: _tacticalBdIcon,
    iconBackground: ItemBackground.yellow,
    uses: const [ShortageUse(student: '호시노', stage: 2, studentId: 'hoshino')],
  ),
  ShortageItem(
    name: '설계도 · 모자 T9',
    shortage: 6,
    owned: 34,
    needed: 40,
    iconAsset: _hatIcon,
    uses: const [ShortageUse(student: '호시노', stage: 1, studentId: 'hoshino')],
  ),
  ShortageItem(
    name: '설계도 · 머리핀 T10',
    shortage: 3,
    owned: 57,
    needed: 60,
    iconAsset: _hairpinIcon,
    uses: const [
      ShortageUse(student: '리오(무장)', stage: 2, studentId: 'rio_battle'),
    ],
  ),
];

/// 페이즈 팝오버 행(`.pr`): 아이콘 42×34 · 이름 · "필요 n" 폭 64 · 칩.
final _phaseRows = [
  (_techNoteIcon, ItemBackground.yellow, '기술 노트 (최상급)', '필요 96', '−30', AppTones.danger),
  (_tacticalBdIcon, ItemBackground.yellow, '전술 교육 BD (최상급)', '필요 18', '−8', AppTones.warn),
  (_watchIcon, ItemBackground.basic, '설계도 · 시계 T10', '필요 60', '−3', AppTones.warn),
  (GameAssets.creditIcon, ItemBackground.basic, '크레딧', '필요 14.8M', '충분', AppTones.ok),
];

class _LayoutPopoverStrip extends StatefulWidget {
  const _LayoutPopoverStrip();

  @override
  State<_LayoutPopoverStrip> createState() => _LayoutPopoverStripState();
}

class _LayoutPopoverStripState extends State<_LayoutPopoverStrip> {
  final _shortageGroup = KitOverlayGroup(debugLabel: 'gallery shortage');
  final _phaseGroup = KitOverlayGroup(debugLabel: 'gallery phase');
  final _infoGroup = KitOverlayGroup(debugLabel: 'gallery layout info');

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('kit-gallery-fe2c-layout'),
    width: 2480,
    height: 620,
    child: KitOverlayBounds(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Text('팝오버 (열린 상태)', style: kitDisplayStyle(16)),
          ),
          Positioned(
            left: 20,
            top: 36,
            child: ShortageBreakdownFlyout(
              key: const ValueKey('kit-gallery-flyout-shortage'),
              semanticLabel: '부족 재화 자세히 보기',
              title: '부족 재화 5종',
              items: _flow4Items,
              footer: '항목을 누르면 그 재화가 들어가는 단계로 이동합니다',
              onOpenInventory: () {},
              initiallyOpen: true,
              group: _shortageGroup,
              child: const _ShortageSummary(),
            ),
          ),
          const Positioned(
            left: 20,
            top: 96,
            width: 380,
            child: Text(
              '부족 재화 플라이아웃 · 요약 줄 옆으로 열립니다 (계획 만들기 왼쪽 레일)',
              style: _wsub,
            ),
          ),
          Positioned(
            left: 960,
            top: 36,
            child: AnchoredFlyout(
              key: const ValueKey('kit-gallery-flyout-phase'),
              semanticLabel: '페이즈 2 필요 재화 보기',
              panelLabel: '페이즈 2 필요 재화',
              preset: FlyoutPreset.phase,
              initiallyOpen: true,
              group: _phaseGroup,
              children: [
                FlyoutHeader(
                  '필요 재화',
                  leading: Text(
                    'P2',
                    style: kitDisplayStyle(18, color: AppColors.accent),
                  ),
                  trailing: const BaChip(label: '부족 3종', tone: AppTones.warn),
                ),
                for (final (icon, background, name, need, chip, tone)
                    in _phaseRows)
                  FlyoutRow(
                    children: [
                      ItemIconTile(
                        iconAsset: icon,
                        background: background,
                        size: ItemIconSizes.s42,
                      ),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bold(AppType.bodySize),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          need,
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          style: _mut(AppType.bodySmallSize),
                        ),
                      ),
                      BaChip(label: chip, tone: tone),
                    ],
                  ),
                FlyoutFooter(
                  text: '앞 페이즈에서 쓰고 남은 양 기준입니다',
                  trailing: ShortageInventoryButton(onPressed: () {}),
                ),
              ],
              child: const _PhaseTrigger(),
            ),
          ),
          const Positioned(
            left: 1520,
            top: 52,
            width: 360,
            child: Text(
              '페이즈별 필요 재화 · 누르면 아래로 열리고 부족한 것부터 (계획 저장 화면)',
              style: _wsub,
            ),
          ),
          Positioned(
            left: 2000,
            top: 44,
            child: Row(
              children: [
                Text('부족 위험도 순위', style: kitDisplayStyle(18)),
                const SizedBox(width: 10),
                InfoPopover(
                  key: const ValueKey('kit-gallery-info-layout'),
                  label: '위험도',
                  title: '위험도',
                  width: 300,
                  align: KitOverlayAlign.end,
                  initiallyOpen: true,
                  group: _infoGroup,
                  children: [
                    InfoPopoverText.plain(
                      '사용법과 도움말은 제목 옆 (i) 뒤에 둡니다. 화면에는 결과만 남깁니다.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Positioned(
            left: 2000,
            top: 236,
            width: 420,
            child: Text(
              '(i) 도움말 · 자세한 규칙은 ‘도움말 (i) · 팝오버’ 보드',
              style: _wsub,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 요약 줄 380×46: "부족 재화" + `.dsp` 18 "5종" + 화살표.
class _ShortageSummary extends StatelessWidget {
  const _ShortageSummary();

  @override
  Widget build(BuildContext context) => Container(
    width: 380,
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: const BoxDecoration(
      color: _triggerFill,
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    child: Row(
      children: [
        Expanded(child: Text('부족 재화', style: _mut(AppType.bodySize))),
        const SizedBox(width: 10),
        Text('5종', style: kitDisplayStyle(18, color: AppColors.accent)),
        const SizedBox(width: 10),
        const Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted),
      ],
    ),
  );
}

/// 페이즈 사선 행 530×56: "P2" + "페이즈 2 · 스킬 M" + 칩.
class _PhaseTrigger extends StatelessWidget {
  const _PhaseTrigger();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 529.9,
    height: 56,
    child: ColoredBox(
      color: _triggerFill,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 14),
        child: Row(
          children: [
            Text('P2', style: kitDisplayStyle(18, color: AppColors.accent)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '페이즈 2 · 스킬 M',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _bold(AppType.titleSmallSize),
              ),
            ),
            const SizedBox(width: 12),
            const BaChip(label: '부족 3종', tone: AppTones.warn),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 3줄: 나머지 프리셋

final _scenarioGroups = [
  ShortageGroup(
    label: '엘레프',
    items: [
      ShortageItem(name: '리오(무장)의 엘레프', shortage: 449, note: '활성 계획과 같음'),
    ],
  ),
  ShortageGroup(
    label: '오파츠',
    items: [
      ShortageItem(
        name: '네브라 디스크 (최상급)',
        shortage: 14,
        iconAsset: _nebraIcon,
        iconBackground: ItemBackground.yellow,
        note: '−6',
        noteTone: AppTones.ok,
      ),
      ShortageItem(
        name: '로혼치 사본 (상급)',
        shortage: 5,
        note: '이 시나리오에만',
        noteTone: AppTones.pink,
      ),
    ],
  ),
  ShortageGroup(
    label: '노트 · BD',
    items: [
      ShortageItem(
        name: '기술 노트 (최상급)',
        shortage: 30,
        iconAsset: _techNoteIcon,
        iconBackground: ItemBackground.yellow,
        note: '+12',
        noteTone: AppTones.warn,
      ),
      ShortageItem(
        name: '전술 교육 BD (최상급)',
        shortage: 8,
        iconAsset: _tacticalBdIcon,
        iconBackground: ItemBackground.yellow,
        note: '이 시나리오에만',
        noteTone: AppTones.pink,
      ),
    ],
  ),
  ShortageGroup(
    label: '장비 설계도',
    items: [
      ShortageItem(
        name: '설계도 · 시계 T10',
        shortage: 3,
        iconAsset: _watchIcon,
        note: '−11',
        noteTone: AppTones.ok,
      ),
      ShortageItem(
        name: '설계도 · 머리핀 T10',
        shortage: 3,
        iconAsset: _hairpinIcon,
        note: '활성 계획과 같음',
      ),
      ShortageItem(
        name: '설계도 · 모자 T9',
        shortage: 6,
        iconAsset: _hatIcon,
        note: '−2',
        noteTone: AppTones.ok,
      ),
    ],
  ),
];

/// Inventory-Analysis `.fly.dn` 행: 학생 · 상급 BD · 최상급 노트.
const _planStudents = [
  ('rio_battle', '리오(무장)', '상급 BD 12', '최상급 노트 8'),
  ('toki_battle', '토키(무장)', '상급 BD 10', '최상급 노트 6'),
  ('himari_battle', '히마리(무장)', '상급 BD 6', '—'),
  ('noa', '노아', '—', '최상급 노트 4'),
  ('yuuka', '유우카', '상급 BD 4', '최상급 노트 2'),
];

/// Stats-Growth `.spop` 밀레니엄 학생 초상 6개.
const _millenniumStudents = ['yuuka', 'noa', 'rio', 'toki', 'himari', 'koyuki'];

/// Tactical 방어 덱 초상(스트라이커 4 · 스페셜 2), 36×29.
const _deckStudents = ['yuuka', 'shun_swimsuit', 'toki_battle', 'kurumi'];
const _deckPortrait = Size(36, 29);

/// Tactical `.fly.dl` 행: 기간 · 비공개 수 · 방어 승률 · 승률 색 · 전적 · 전적 칩.
const _defenseDecks = [
  ('9/24 ~ 현재', 0, '41%', AppColors.success, '2승 0패', AppTones.ok),
  ('9/18 ~ 9/23', 0, '47%', AppColors.success, '1승 1패', null),
  ('9/12 ~ 9/17', 3, '63%', AppColors.accent, '기록 없음', AppTones.gray),
  ('9/05 ~ 9/11', 0, '72%', AppColors.accent, '0승 2패', AppTones.danger),
  ('8/29 ~ 9/04', 0, '38%', AppColors.success, '1승 0패', AppTones.ok),
];

class _PresetSamples extends StatelessWidget {
  const _PresetSamples();

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('kit-gallery-fe2c-presets'),
    width: 2480,
    height: 640,
    child: KitOverlayBounds(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Text('프리셋 견본 (닫힌 상태)', style: kitDisplayStyle(16)),
          ),
          const Positioned(
            left: 0,
            top: 30,
            width: 1600,
            child: Text(
              '마우스를 올리거나, 키보드로 포커스하거나, 누르면 열립니다. 같은 묶음이라 한 번에 하나만 열립니다.',
              style: _wsub,
            ),
          ),
          Positioned(
            left: 20,
            top: 80,
            child: GroupedShortageFlyout(
              key: const ValueKey('kit-gallery-flyout-scenario'),
              semanticLabel: '부족 재화 자세히 보기',
              title: '부족 재화 8종',
              note: '활성 계획 14종 · 빠진 6종은 이 시나리오에 없는 학생 몫',
              groups: _scenarioGroups,
              footer: '항목을 누르면 그 재화가 막는 단계로 이동합니다',
              onOpenInventory: () {},
              child: const _ParallelogramCard(
                width: 240,
                height: 62,
                label: '부족 재화',
                value: '8종',
              ),
            ),
          ),
          const Positioned(
            left: 20,
            top: 154,
            width: 420,
            child: Text(
              '시나리오 팝오버(.shw) · FD-090 분야별 그룹 · 패널 500, 꼬리 left 90',
              style: _wsub,
            ),
          ),
          const Positioned(left: 660, top: 80, child: _StatsDotSample()),
          const Positioned(
            left: 660,
            top: 270,
            width: 320,
            child: Text(
              '통계 점 팝오버(.sdot) · 26px 원을 누르면 왼쪽으로 열립니다',
              style: _wsub,
            ),
          ),
          Positioned(
            left: 1360,
            top: 80,
            child: AnchoredFlyout(
              key: const ValueKey('kit-gallery-flyout-down'),
              semanticLabel: '밀레니엄 계획 학생 5명 보기',
              panelLabel: '밀레니엄 계획 학생',
              preset: FlyoutPreset.down,
              children: [
                const FlyoutHeader(
                  '밀레니엄 · 계획 학생 5명',
                  note: '부족 필요량 · ',
                  noteSpans: [
                    TextSpan(
                      text: 'BD',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    TextSpan(text: ' · '),
                    TextSpan(
                      text: '노트',
                      style: TextStyle(color: AppColors.accentText),
                    ),
                  ],
                ),
                for (final (studentId, name, bd, note) in _planStudents)
                  FlyoutRow(
                    children: [
                      PortraitStrip(
                        studentIds: [studentId],
                        maxVisible: 1,
                        portraitSize: const Size(40, 32),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name, maxLines: 1, style: _bold(AppType.bodySize)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  bd,
                                  style: _mut(AppType.captionSize).copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  note,
                                  style: _mut(AppType.captionSize).copyWith(
                                    color: AppColors.accentText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const FlyoutFooter(trailing: FlyoutLink('계획에서 보기 →')),
              ],
              child: const _ChipTrigger(label: '밀레니엄'),
            ),
          ),
          const Positioned(
            left: 1060,
            top: 124,
            width: 280,
            child: Text(
              '아래 · 오른쪽 맞춤(.fly.dn) · 폭 380',
              style: _wsub,
            ),
          ),
          Positioned(
            left: 1500,
            top: 80,
            child: AnchoredFlyout(
              key: const ValueKey('kit-gallery-flyout-down-left'),
              semanticLabel: 'A 유저 · 23위 최근 방어 덱 5종 보기',
              panelLabel: 'A 유저 · 23위 최근 방어 덱',
              preset: FlyoutPreset.downLeft.withRing(FlyoutTriggerRing.lineCard),
              children: [
                const FlyoutHeader(
                  'A 유저 · 23위 · 최근 방어 덱 5종',
                  note: '방어 승률 · 내 전적 · ? = 비공개',
                ),
                for (var index = 0; index < _defenseDecks.length; index++)
                  _DefenseDeckRow(index: index),
                const FlyoutFooter(
                  text: '변경 주기 평균 6일',
                  trailing: FlyoutLink('상대 카드 열기 →'),
                ),
              ],
              child: const _ParallelogramCard(
                width: 356.5,
                height: 104,
                label: 'A 유저',
                value: '23위',
              ),
            ),
          ),
          const Positioned(
            left: 1880,
            top: 80,
            width: 420,
            child: Text(
              '왼쪽 아래(.fly.dl) · 사선 카드 트리거(.flyw.lc) · 폭 540',
              style: _wsub,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 사선 카드 트리거(80° 평행사변형, #1b2a3a).
class _ParallelogramCard extends StatelessWidget {
  const _ParallelogramCard({
    required this.width,
    required this.height,
    required this.label,
    required this.value,
  });

  final double width;
  final double height;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: ColoredBox(
      color: _triggerFill,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: diagonalCutDepth(height) + 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label, maxLines: 1, style: _mut(AppType.bodySize)),
            ),
            const SizedBox(width: 10),
            Text(value, style: kitDisplayStyle(18, color: AppColors.accent)),
          ],
        ),
      ),
    ),
  );
}

/// 작은 트리거 66×28(#1b2a3a r8).
class _ChipTrigger extends StatelessWidget {
  const _ChipTrigger({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 66,
    height: 28,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: _triggerFill,
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    child: Text(
      label,
      maxLines: 1,
      style: _mut(AppType.bodySmallSize).copyWith(color: AppColors.text),
    ),
  );
}

/// 통계 점: 차트 자리 300×170 안의 점 하나. 26px 원을 누르면 `.spop`이 왼쪽으로 열린다.
class _StatsDotSample extends StatelessWidget {
  const _StatsDotSample();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    height: 170,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.rowSurface.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Stack(
        children: [
          // 점 그림(차트가 그리는 자리).
          const Positioned(
            left: 230,
            top: 50,
            child: SizedBox.square(
              dimension: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: 222,
            top: 42,
            child: AnchoredFlyout(
              key: const ValueKey('kit-gallery-flyout-stats-dot'),
              semanticLabel: '밀레니엄 학생 목록',
              panelLabel: '밀레니엄',
              preset: FlyoutPreset.statsDot,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('밀레니엄', style: _bold(AppType.bodySize)),
                    const SizedBox(width: 8),
                    Text(
                      '보유 28명 · 보유율 93% · 평균 육성도 71%',
                      style: _mut(AppType.captionPlusSize),
                    ),
                  ],
                ),
                const PortraitStrip(
                  studentIds: _millenniumStudents,
                  maxVisible: 6,
                  portraitSize: Size(44, 36),
                ),
              ],
              child: const FlyoutDot(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Tactical 방어 덱 행(`.fr` 간격 12). 첫 행은 지금 덱이라 왼쪽 핑크 막대.
class _DefenseDeckRow extends StatelessWidget {
  const _DefenseDeckRow({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final (period, hidden, rate, rateColor, record, recordTone) =
        _defenseDecks[index];
    final current = index == 0;
    return FlyoutRow(
      gap: 12,
      leftBar: current ? AppColors.accent : null,
      children: [
        SizedBox(
          width: 84,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(period, style: _bold(AppType.bodySmallSize)),
              if (current) ...[
                const SizedBox(height: 3),
                const BaChip(label: '현재', tone: AppTones.pink),
              ],
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _DeckPortraits(hidden: hidden),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('방어', style: _mut(9)),
              Text(rate, maxLines: 1, style: kitDisplayStyle(15, color: rateColor)),
            ],
          ),
        ),
        if (recordTone == null)
          Text(record, style: _bold(AppType.bodySmallSize, color: AppColors.textMuted))
        else
          BaChip(label: record, tone: recordTone),
      ],
    );
  }
}

/// 방어 덱 초상 4 + 구분선 + 2(36×29). [hidden]칸은 비공개 "?" 점선 상자.
class _DeckPortraits extends StatelessWidget {
  const _DeckPortraits({required this.hidden});

  final int hidden;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < 4; index++) ...[
        if (index > 0) const SizedBox(width: 3),
        if (index >= 4 - hidden)
          Container(
            width: 36,
            height: 29,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outline, width: 1.5),
              borderRadius: const BorderRadius.all(Radius.circular(5)),
            ),
            child: Text('?', style: _bold(AppType.bodySmallSize, color: AppColors.textMuted)),
          )
        else
          PortraitStrip(
            studentIds: [_deckStudents[index]],
            maxVisible: 1,
            portraitSize: _deckPortrait,
          ),
      ],
      const SizedBox(width: 8),
      Container(
        width: 1,
        height: 23,
        color: AppColors.textMuted.withValues(alpha: 0.3),
      ),
      const SizedBox(width: 8),
      const PortraitStrip(
        studentIds: ['noa', 'shiroko'],
        portraitSize: _deckPortrait,
        gap: 3,
      ),
    ],
  );
}
