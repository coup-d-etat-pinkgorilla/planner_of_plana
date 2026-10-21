// 계획 만들기 2단계 목표 정하기(FE4-c, 시안 Flow-2-Goals, C 보고서 §2).
//
// - B 본문: 학생 탭 줄(1단계에서 고른 순서, `설정 중`·`완료`·`미설정`), 프리셋 바(인메모리 단계 프리셋 · 한 번에
//   MAX · 직접 입력), 가로 단계 카드(지금 상태 · 단계 카드 · 단계 추가), 현재 → 최종 줄.
// - 단계 카드: 머리(단계 태그 · 이름 인라인 편집 · 상태 칩 · 삭제, 비용 한 줄), LEVEL·STAR·WEAPON·인연 미세 조절,
//   성급 9칸(학생 5 + 전용무기 4), SKILL SUMMARY, EQUIPMENT(티어), ABILITY + "더 보기"(카드에 칸이 없는 목표, FD-072),
//   COST(`stage_results[].cost`·`resources`, 디바운스 계산).
// - C 보조: 단계 프리셋 목록, 다른 학생에도 적용(학생별 · 모두), 이 학생 재화 요약.
// - FD-074·FE4-i: 단계 프리셋은 프로필 저장소(FB-14, [RepositoryPresetsController])에 둔다. 프리셋 바 "지금 구성을
//   프리셋으로"가 지금 학생의 단계(이름 + 19키 nullable 원본)를 저장하고, C 행에서 적용·이름 바꾸기·삭제한다. 계획
//   화면 프리셋 관리의 인메모리 프리셋은 저장된 프리셋 뒤에 적용만 할 수 있게 둔다.
// - FD-076: 미보유 학생은 목표 최솟값을 지금 값으로 보고 "모집 필요" 칩만 단다(모집 비용은 FB-9).
// 좌표는 시안(2560×1392, 헤더 184 아래가 캔버스)의 값이다([planFlowProtoRect]). 블록은 시안 크기로 그린 뒤
// 자리에 맞춰 같은 비율로 줄인다(기준 캔버스 2560×1208에서 배율 1).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/game_assets.dart';
import '../kit/info_popover.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_overlay.dart';
import '../kit/kit_pressable.dart';
import '../kit/portrait_strip.dart';
import '../kit/skew_box.dart';
import '../kit/skew_controls.dart';
import '../kit/stepper.dart';
import '../kit/titles.dart';
import '../models/plan_flow_draft.dart';
import '../models/plan_flow_goal_editor.dart';
import '../models/planning_growth_rules.dart';
import '../models/planning_models.dart';
import '../models/planning_resource_assets.dart';
import '../models/repository_presets_controller.dart';
import '../../services/repository_service.dart' show RepositoryPresetStage;
import 'diagonal_media_list_item.dart'
    show formatDiagonalMediaSkillLevels, relationshipRankHeartPath;
import 'growth_calculator_section.dart' show growthCalculatorCompactNumber;
import 'plan_flow_student_step.dart'
    show PlanFlowStoreMessage, planFlowAsideLeftAt, planFlowProtoRect;
import '../tutorial/tutorial_script.dart';
import '../tutorial_targets/tutorial_hooks.dart';

/// 단계 카드 시안 크기(지금 상태 카드는 폭만 [planFlowGoalCurrentCardWidth]).
const planFlowGoalCardSize = Size(473.3, 716);
const planFlowGoalCurrentCardWidth = 398.5;

/// 단계 카드 사이 간격(시안 x 771.5 → 1134.6 → 1497.7).
const planFlowGoalCardPitch = 363.1;

/// "단계 추가" 세로 버튼 폭.
const planFlowGoalAddWidth = 190.0;

/// 카드 열 자리(시안 x 483.3 ~ 2051, y 351.2, 높이 716).
const _cardsLeft = 483.3;
const _cardsTop = 351.2;
const _cardsWidth = 2051 - _cardsLeft;
const _stagesLeft = 771.5 - _cardsLeft;

const _cardFill = Color.fromRGBO(27, 42, 58, 0.92);
const _currentCardFill = Color.fromRGBO(27, 42, 58, 0.6);
const _currentCardStroke = Color.fromRGBO(56, 81, 107, 0.6);
const _blockStroke = Color.fromRGBO(56, 81, 107, 0.75);
const _changedFill = Color.fromRGBO(242, 179, 239, 0.13);
const _starOn = Color.fromRGBO(243, 201, 107, 0.86);
const _weaponStarOn = Color.fromRGBO(113, 199, 244, 0.86);
const _starOff = Color.fromRGBO(56, 81, 107, 0.48);
const _addFill = Color.fromRGBO(113, 199, 244, 0.06);
const _addStroke = Color.fromRGBO(158, 176, 194, 0.35);

const _mutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  fontWeight: AppType.medium,
  color: AppColors.textMuted,
);

const _bodyStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySize,
  fontWeight: AppType.semiBold,
  color: AppColors.text,
);

TextStyle _valueStyle(double size, {Color color = AppColors.text}) =>
    TextStyle(
      fontFamily: AppFonts.display,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: size,
      height: 1.05,
      fontWeight: FontWeight.w800,
      color: color,
    );

TextStyle _labelStyle(Color color, {FontWeight weight = FontWeight.w800}) =>
    TextStyle(
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: AppType.indicatorLabelSize,
      height: 1.2,
      fontWeight: weight,
      color: color,
    );

/// 사선 블록·카드 path(윗변이 `diagonalCutDepth(h)`만큼 오른쪽으로 밀린 평행사변형, Q 곡선 모서리).
Path planFlowGoalSkewPath(Size size, {double radius = 8}) {
  final depth = math.min(size.width * 0.45, diagonalCutDepth(size.height));
  return diagonalRoundedPolygon(
    [
      Offset(depth, 0),
      Offset(size.width, 0),
      Offset(size.width - depth, size.height),
      Offset(0, size.height),
    ],
    radius: radius,
    corner: DiagonalCornerStyle.quadratic,
  );
}

/// 큰 수(크레딧 18.2M, 재화 1.2K).
String planFlowGoalAmount(int value) => growthCalculatorCompactNumber(value);

/// 단계 카드 비용 한 줄(시안 `크레딧 18.2M · 설계도 170`): 크레딧 + 그다음 많이 드는 재화.
String planFlowGoalCostLine(PlanFlowStageCost cost) {
  final parts = [
    if (cost.credits case final credits?) '크레딧 ${planFlowGoalAmount(credits)}',
  ];
  final others = [
    for (final resource in cost.resources)
      if (!resource.isCredits) resource,
  ]..sort((a, b) => b.required.compareTo(a.required));
  if (others.firstOrNull case final top?) {
    parts.add('${_shortName(top.name)} ${planFlowGoalAmount(top.required)}');
  }
  return parts.isEmpty ? '드는 재화가 없습니다' : parts.join(' · ');
}

String _shortName(String name) {
  final parts = name.split(' · ');
  return parts.length > 1 ? parts.last : name;
}

/// COST 블록 행 순서: 모자라는 재화(많이 모자란 순) → 크레딧 → 나머지(많이 드는 순).
List<PlanFlowStageResource> planFlowGoalCostRows(PlanFlowStageCost cost) {
  final resources = [...cost.resources];
  if (cost.credits case final credits?
      when !resources.any((resource) => resource.isCredits)) {
    resources.add(
      PlanFlowStageResource(
        resourceKey: 'credits',
        name: '크레딧',
        category: 'credits',
        required: credits,
      ),
    );
  }
  int rank(PlanFlowStageResource resource) =>
      (resource.shortageAtEntry ?? 0) > 0
      ? 0
      : resource.isCredits
      ? 1
      : 2;
  return resources..sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    if (rank(a) == 0) {
      return b.shortageAtEntry!.compareTo(a.shortageAtEntry!);
    }
    return b.required.compareTo(a.required);
  });
}

/// 단계 카드 상태 칩(시안 `지금 가능`·`부족 n종`).
({String label, AppTone tone}) planFlowGoalStageStatus({
  required bool effective,
  required bool owned,
  required PlanFlowStageCost? cost,
  required bool calculating,
}) {
  if (!effective) return (label: '목표 없음', tone: AppTones.gray);
  if (!owned) return (label: '모집 필요', tone: AppTones.warn);
  if (cost == null) {
    return (label: calculating ? '계산 중' : '—', tone: AppTones.gray);
  }
  return switch (cost.shortageKinds) {
    null => (label: '보유 모름', tone: AppTones.gray),
    0 => (label: '지금 가능', tone: AppTones.ok),
    final kinds => (label: '부족 $kinds종', tone: AppTones.warn),
  };
}

/// 현재 → 최종 한 항목 글자.
String planFlowGoalGroupText(PlanFlowGoalGroup group, Map<String, int> values) {
  int v(String key) => values[key] ?? 0;
  switch (group) {
    case PlanFlowGoalGroup.level:
      return '${v('level')}';
    case PlanFlowGoalGroup.star:
      return '★${v('student_star')}';
    case PlanFlowGoalGroup.weapon:
      return v('weapon_level') == 0 ? '—' : 'Lv.${v('weapon_level')}';
    case PlanFlowGoalGroup.skill:
      return formatDiagonalMediaSkillLevels(
        '${v('ex_skill')}/${v('skill1')}/${v('skill2')}/${v('skill3')}',
      );
    case PlanFlowGoalGroup.equipment:
      final tiers = [for (var slot = 1; slot <= 3; slot++) v('equip${slot}_tier')];
      String tier(int value) => value == 0 ? '-' : 'T$value';
      return tiers.toSet().length == 1 && tiers.first > 0
          ? '${tier(tiers.first)} ×3'
          : tiers.map(tier).join('/');
    case PlanFlowGoalGroup.bond:
      return '${v('bond_rank')}';
    case PlanFlowGoalGroup.ability:
      return '${v('stat_hp')}/${v('stat_atk')}/${v('stat_heal')}';
  }
}

/// 현재 → 최종 막대: 지금 값이 최종의 어디쯤인지(0~1).
double planFlowGoalGroupProgress(
  PlanFlowGoalGroup group,
  Map<String, int> current,
  Map<String, int> target,
) {
  final keys = group == PlanFlowGoalGroup.equipment
      ? const {'equip1_tier', 'equip2_tier', 'equip3_tier'}
      : group == PlanFlowGoalGroup.weapon
      ? const {'weapon_level'}
      : group.keys;
  final now = keys.fold<int>(0, (sum, key) => sum + (current[key] ?? 0));
  final goal = keys.fold<int>(0, (sum, key) => sum + (target[key] ?? 0));
  if (goal <= 0) return now > 0 ? 1.0 : 0.0;
  return (now / goal).clamp(0.0, 1.0).toDouble();
}

/// 시안 크기 [design]로 그린 [child]를 [rect]에 같은 비율로 맞춘다.
Widget _designBox(
  Rect rect,
  Size design,
  Widget child, {
  Alignment alignment = Alignment.topLeft,
}) => Positioned.fromRect(
  rect: rect,
  child: FittedBox(
    fit: BoxFit.contain,
    alignment: alignment,
    child: SizedBox.fromSize(size: design, child: child),
  ),
);

// ---------------------------------------------------------------------------
// B 본문

/// 2단계 B 본문. 콘텐츠 캔버스 전체를 받는다.
class PlanFlowGoalBody extends StatelessWidget {
  const PlanFlowGoalBody({
    super.key,
    required this.flow,
    required this.editor,
    this.presets,
  });

  final PlanFlowController flow;
  final PlanFlowGoalEditor editor;

  /// 단계 프리셋 저장소(FE4-i). 없으면 "지금 구성을 프리셋으로"를 그리지 않는다.
  final RepositoryPresetsController? presets;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([flow, editor, ?presets]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => _build(constraints.biggest),
    ),
  );

  Widget _build(Size size) {
    final studentId = editor.studentId;
    if (studentId == null) {
      return Stack(
        key: const ValueKey('plan-flow-goal-body'),
        children: [
          Positioned.fromRect(
            rect: planFlowProtoRect(size, 622.2, 229.2, 1450.1, 120),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '1단계에서 학생을 고르면 여기서 학생마다 목표 단계를 정합니다.',
                key: ValueKey('plan-flow-goal-empty'),
                style: _bodyStyle,
              ),
            ),
          ),
        ],
      );
    }
    final name = editor.displayName(studentId);
    return Stack(
      key: const ValueKey('plan-flow-goal-body'),
      children: [
        _designBox(
          planFlowProtoRect(size, 622.2, 229.2, 1450.1, 50),
          const Size(1450.1, 50),
          _StudentTabs(editor: editor),
          alignment: Alignment.centerLeft,
        ),
        _designBox(
          planFlowProtoRect(size, 624.2, 291.2, 1425.3, 44),
          const Size(1425.3, 44),
          _PresetBar(editor: editor, studentId: studentId, store: presets),
          alignment: Alignment.centerLeft,
        ),
        _designBox(
          planFlowProtoRect(size, _cardsLeft, _cardsTop, _cardsWidth, 716),
          const Size(_cardsWidth, 716),
          TutorialTarget(
            id: TutorialTargets.planGoalStageCells,
            child: _StageCards(
              flow: flow,
              editor: editor,
              studentId: studentId,
            ),
          ),
        ),
        _designBox(
          planFlowProtoRect(size, 491.1, 1087.2, 1413.3, 30),
          const Size(1413.3, 30),
          Row(
            children: [
              Flexible(
                child: Text(
                  '$name · 현재 → 최종',
                  key: const ValueKey('plan-flow-goal-final-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kitDisplayStyle(AppType.titleSize),
                ),
              ),
              const SizedBox(width: 10),
              const InfoPopover(
                key: ValueKey('plan-flow-goal-final-info'),
                label: '현재 → 최종',
                title: '현재 → 최종',
                width: 280,
                children: [
                  InfoPopoverText.plain(
                    '마지막 단계까지 끝났을 때의 모습입니다. 막대는 지금 값이 최종 목표의 어디쯤인지 보여 줍니다. '
                    '× 를 누르면 그 목표를 모든 단계에서 지웁니다.',
                  ),
                ],
              ),
            ],
          ),
          alignment: Alignment.centerLeft,
        ),
        _designBox(
          planFlowProtoRect(size, 478.9, 1125.2, 1413.3, 92),
          const Size(1413.3, 92),
          _FinalStrip(editor: editor, studentId: studentId),
        ),
      ],
    );
  }
}

/// 학생 탭 줄(시안 1450×50, 탭 `.seg` h44: 초상 37×30 · 이름 13 · 상태 칩).
class _StudentTabs extends StatelessWidget {
  const _StudentTabs({required this.editor});

  final PlanFlowGoalEditor editor;

  @override
  Widget build(BuildContext context) => DiagonalRow(
    key: const ValueKey('plan-flow-goal-tabs'),
    variant: DiagonalRowVariant.row,
    padding: const EdgeInsets.symmetric(horizontal: 18.8),
    child: SingleChildScrollView(
      key: const ValueKey('plan-flow-goal-tabs-scroll'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (index, studentId) in editor.studentIds.indexed) ...[
            if (index > 0) const SizedBox(width: 10),
            _StudentTab(
              key: ValueKey('plan-flow-goal-tab-$studentId'),
              studentId: studentId,
              name: editor.displayName(studentId),
              state: editor.tabStateOf(studentId),
              owned: editor.isOwned(studentId),
              onPressed: () => editor.selectStudent(studentId),
            ),
          ],
        ],
      ),
    ),
  );
}

class _StudentTab extends StatelessWidget {
  const _StudentTab({
    super.key,
    required this.studentId,
    required this.name,
    required this.state,
    required this.owned,
    required this.onPressed,
  });

  final String studentId;
  final String name;
  final PlanFlowGoalTabState state;
  final bool owned;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selected = state == PlanFlowGoalTabState.editing;
    final (label, tone) = switch (state) {
      PlanFlowGoalTabState.editing => ('설정 중', AppTones.pink),
      PlanFlowGoalTabState.done => ('완료', AppTones.ok),
      PlanFlowGoalTabState.unset => ('미설정', AppTones.gray),
    };
    return KitPressable(
      onPressed: onPressed,
      selected: selected,
      semanticLabel: '$name, $label${owned ? '' : ', 미보유'}',
      builder: (context, pressState) => SizedBox(
        height: 44,
        child: SkewBox(
          fill: selected
              ? SkewSegmented.selectedFill
              : SkewSegmented.idleFill,
          border: pressState.focused
              ? kitFocusColor
              : selected
              ? AppColors.accent
              : SkewSegmented.idleBorder,
          borderWidth: selected ? 1.5 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PortraitStrip(
                    studentIds: [studentId],
                    maxVisible: 1,
                    portraitSize: const Size(37, 30),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle.copyWith(
                        fontWeight: AppType.bold,
                        color: selected
                            ? AppColors.accentText
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BaChip(label: label, tone: tone),
                  if (!owned) ...[
                    const SizedBox(width: 4),
                    const BaChip(label: '미보유', tone: AppTones.warn),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "지금 구성을 프리셋으로"의 기본 이름(이름은 C 행에서 바꾼다).
String planFlowGoalNewPresetName(String studentName, int stageCount) =>
    '$studentName 목표 $stageCount단계';

/// 프리셋 바(시안 1425×44: `단계 프리셋` + 세그먼트 h32 12px + "지금 구성을 프리셋으로" + (i)).
class _PresetBar extends StatelessWidget {
  const _PresetBar({
    required this.editor,
    required this.studentId,
    required this.store,
  });

  final PlanFlowGoalEditor editor;
  final String studentId;
  final RepositoryPresetsController? store;

  /// 지금 학생의 단계(이름 + 19키 nullable 원본)를 새 프리셋으로 저장한다.
  void _save(RepositoryPresetsController store) {
    final stages = editor.presetStagesOf(studentId);
    if (stages.isEmpty) return;
    store.addStagePreset(
      name: planFlowGoalNewPresetName(
        editor.displayName(studentId),
        stages.length,
      ),
      stages: [
        for (final stage in stages)
          RepositoryPresetStage(name: stage.name, targets: stage.targets),
      ],
    );
  }

  Widget _segment(String key, String mode, String label) {
    final selected = editor.modeOf(studentId) == mode;
    return SkewSegmented<String>(
      key: ValueKey(key),
      segments: [SkewSegment(value: mode, label: label)],
      selected: selected ? mode : null,
      onChanged: (value) => editor.applyMode(value),
      height: 32,
      fontSize: AppType.bodySmallSize,
      horizontalPadding: 14,
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('plan-flow-goal-preset-bar'),
    children: [
      const Text('단계 프리셋', style: KV.labelStyle),
      const SizedBox(width: 10),
      Flexible(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final preset in editor.presets) ...[
                _segment(
                  'plan-flow-goal-preset-${preset.id}',
                  planFlowGoalPresetMode(preset.id),
                  preset.name,
                ),
                const SizedBox(width: 10),
              ],
              _segment(
                'plan-flow-goal-mode-max',
                planFlowGoalModeMax,
                '한 번에 MAX',
              ),
              const SizedBox(width: 10),
              _segment(
                'plan-flow-goal-mode-direct',
                planFlowGoalModeDirect,
                '직접 입력',
              ),
            ],
          ),
        ),
      ),
      if (store case final store? when store.available) ...[
        const SizedBox(width: 10),
        TonalButton(
          key: const ValueKey('plan-flow-goal-preset-save'),
          label: '지금 구성을 프리셋으로',
          icon: Icons.bookmark_add_outlined,
          height: 32,
          horizontalPadding: 12,
          fontSize: AppType.bodySmallSize,
          onPressed:
              store.canEdit && editor.presetStagesOf(studentId).isNotEmpty
              ? () => _save(store)
              : null,
        ),
      ],
      const SizedBox(width: 10),
      const InfoPopover(
        key: ValueKey('plan-flow-goal-preset-info'),
        label: '단계 프리셋',
        title: '단계 프리셋',
        width: 300,
        align: KitOverlayAlign.end,
        children: [
          InfoPopoverText.plain(
            '단계 여러 개를 한 묶음으로 저장해 두고 불러옵니다. 불러온 뒤 칸마다 값을 고칠 수 있고, 목표가 현재보다 '
            '낮은 항목은 자동으로 현재 값에 맞춰집니다. 한 번에 MAX는 1단계에 모든 목표를 최대로, 직접 입력은 빈 '
            '1단계로 시작합니다.',
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 카드 열

/// 지금 상태 카드 + 단계 카드(가로 스크롤) + 단계 추가. 시안 1567.7×716.
class _StageCards extends StatefulWidget {
  const _StageCards({
    required this.flow,
    required this.editor,
    required this.studentId,
  });

  final PlanFlowController flow;
  final PlanFlowGoalEditor editor;
  final String studentId;

  @override
  State<_StageCards> createState() => _StageCardsState();
}

class _StageCardsState extends State<_StageCards> {
  final _scroll = ScrollController();
  String? _shownSelection;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 고른 단계가 바뀌면 그 카드가 보이게 스크롤한다(애니메이션 없이).
  void _revealSelected(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      final left = index * planFlowGoalCardPitch;
      final right = left + planFlowGoalCardSize.width;
      var offset = position.pixels;
      if (left < offset) offset = left;
      if (right > offset + position.viewportDimension) {
        offset = right - position.viewportDimension;
      }
      final clamped = offset.clamp(0.0, position.maxScrollExtent).toDouble();
      if ((clamped - position.pixels).abs() > 0.5) _scroll.jumpTo(clamped);
    });
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final studentId = widget.studentId;
    final stages = editor.stagesOf(studentId);
    final selectedId = editor.selectedStageIdOf(studentId);
    final selectedIndex = stages.indexWhere((stage) => stage.id == selectedId);
    final selectionKey = '$studentId:$selectedId:${stages.length}';
    if (_shownSelection != selectionKey) {
      _shownSelection = selectionKey;
      if (selectedIndex >= 0) _revealSelected(selectedIndex);
    }
    final calculation = widget.flow.calculation;
    final contentWidth = math.max(
      _cardsWidth - _stagesLeft,
      stages.length * planFlowGoalCardPitch + planFlowGoalAddWidth,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: planFlowGoalCurrentCardWidth,
          height: planFlowGoalCardSize.height,
          child: _CurrentCard(editor: editor, studentId: studentId),
        ),
        Positioned(
          left: _stagesLeft,
          top: 0,
          right: 0,
          bottom: 0,
          child: ClipPath(
            clipper: const _StageViewportClipper(),
            child: SingleChildScrollView(
              key: const ValueKey('plan-flow-goal-stage-scroll'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                height: planFlowGoalCardSize.height,
                child: Stack(
                  children: [
                    for (final (index, stage) in stages.indexed)
                      Positioned(
                        left: index * planFlowGoalCardPitch,
                        top: 0,
                        width: planFlowGoalCardSize.width,
                        height: planFlowGoalCardSize.height,
                        child: _StageCard(
                          key: ValueKey('plan-flow-goal-card-${stage.id}'),
                          editor: editor,
                          studentId: studentId,
                          index: index,
                          stage: stage,
                          stageCount: stages.length,
                          selected: stage.id == selectedId,
                          cost: calculation?.stageCosts[stage.id],
                          calculating: widget.flow.calculating,
                          canCalculate: widget.flow.canCalculate,
                        ),
                      ),
                    Positioned(
                      left: stages.length * planFlowGoalCardPitch,
                      top: 0,
                      width: planFlowGoalAddWidth,
                      height: planFlowGoalCardSize.height,
                      child: TutorialTarget(
                        id: studentId == 'maki'
                            ? TutorialTargets.planMakiAddStage
                            : null,
                        child: _AddStageColumn(onPressed: editor.addStage),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 단계 카드 스크롤 자리: 왼쪽 변은 첫 단계 카드의 사선을 따른다(지금 상태 카드와 겹치지 않는다).
class _StageViewportClipper extends CustomClipper<Path> {
  const _StageViewportClipper();

  @override
  Path getClip(Size size) {
    final depth = diagonalCutDepth(size.height);
    return Path()
      ..moveTo(depth, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_StageViewportClipper oldClipper) => false;
}

/// 카드 안 블록 자리(카드 기준, 시안 값). 단계 카드와 지금 상태 카드는 폭만 다르다.
class _CardLayout {
  const _CardLayout({
    required this.main,
    required this.stars,
    required this.skill,
    required this.equipment,
    required this.ability,
    required this.cost,
  });

  final Rect main;
  final Rect stars;
  final Rect skill;
  final Rect equipment;
  final Rect ability;
  final Rect cost;

  static const stage = _CardLayout(
    main: Rect.fromLTWH(108.9, 86, 335.2, 92),
    stars: Rect.fromLTWH(109, 188, 311, 22),
    skill: Rect.fromLTWH(83.1, 220, 337.4, 104),
    equipment: Rect.fromLTWH(57, 334, 343.4, 138),
    ability: Rect.fromLTWH(47.1, 482, 327.1, 46),
    cost: Rect.fromLTWH(20.7, 538, 343.7, 140),
  );

  static const current = _CardLayout(
    main: Rect.fromLTWH(108.9, 86, 260.5, 92),
    stars: Rect.fromLTWH(109, 188, 236, 22),
    skill: Rect.fromLTWH(83.1, 220, 262.6, 104),
    equipment: Rect.fromLTWH(57, 334, 268.6, 138),
    ability: Rect.fromLTWH(47.1, 482, 252.4, 46),
    cost: Rect.fromLTWH(20.7, 538, 269, 140),
  );

  /// "더 보기"를 열었을 때 EQUIPMENT·ABILITY·COST 자리 전체.
  Rect get more => Rect.fromLTRB(cost.left, equipment.top, equipment.right, cost.bottom);
}

/// 카드 바탕(사선 평행사변형, 시안 r12 · 테두리 5.2).
class _CardPainter extends CustomPainter {
  const _CardPainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
  });

  final Color fill;
  final Color stroke;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = planFlowGoalSkewPath(size, radius: 12);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth
        ..color = stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _CardClipper extends CustomClipper<Path> {
  const _CardClipper();

  @override
  Path getClip(Size size) => planFlowGoalSkewPath(size, radius: 12);

  @override
  bool shouldReclip(_CardClipper oldClipper) => false;
}

/// 카드 안 사선 블록(시안 #203243 · 테두리 1.8 rgba(56,81,107,.75) · r8).
class _Block extends StatelessWidget {
  const _Block({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final depth = diagonalCutDepth(constraints.maxHeight);
      return CustomPaint(
        painter: const _BlockPainter(),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(depth + 4, 7, depth * 0.5 + 6, 7),
          child: child,
        ),
      );
    },
  );
}

class _BlockPainter extends CustomPainter {
  const _BlockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = planFlowGoalSkewPath(size);
    canvas.drawPath(path, Paint()..color = AppColors.indicatorSurface);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = _blockStroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlockPainter oldDelegate) => false;
}

/// 블록 소제목 + 선(시안 `.ihdr` 9px + 1px rgba(113,199,244,.42)).
class _BlockHeader extends StatelessWidget {
  const _BlockHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: SubHeader(text, fontSize: AppType.indicatorLabelSize),
      ),
      const SizedBox(height: 3),
      Container(height: 1, color: AppColors.primary.withValues(alpha: 0.42)),
    ],
  );
}

/// 지금 상태 카드(읽기 전용).
class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.editor, required this.studentId});

  final PlanFlowGoalEditor editor;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final current = editor.currentOf(studentId);
    final owned = editor.isOwned(studentId);
    const layout = _CardLayout.current;
    return Semantics(
      container: true,
      label: '지금 상태',
      value: owned ? '스캔 기준' : '미보유',
      child: Stack(
        key: const ValueKey('plan-flow-goal-current-card'),
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _CardPainter(
                fill: _currentCardFill,
                stroke: _currentCardStroke,
                strokeWidth: 2.8,
              ),
            ),
          ),
          Positioned(
            left: 128,
            top: 12,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '지금 상태',
                      style: KV.labelStyle.copyWith(
                        fontSize: AppType.bodySize,
                      ),
                    ),
                    if (!owned) ...[
                      const SizedBox(width: 8),
                      const BaChip(
                        key: ValueKey('plan-flow-goal-recruit'),
                        label: '모집 필요',
                        tone: AppTones.warn,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  owned ? '스캔 기준 · 고칠 수 없습니다' : '미보유 · 최솟값에서 시작합니다',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle,
                ),
              ],
            ),
          ),
          _cardBlocks(
            layout: layout,
            values: current,
            previous: current,
            editor: null,
            studentId: studentId,
            stageId: null,
            expanded: false,
            equipmentTypes: planFlowGoalEquipmentTypes(editor, studentId),
          ),
          Positioned.fromRect(
            rect: layout.cost,
            child: const _Block(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BlockHeader('COST'),
                  Expanded(
                    child: Center(
                      child: Text(
                        '오른쪽에 단계마다 드는 재화가 나옵니다',
                        textAlign: TextAlign.center,
                        style: _mutedStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 지금 상태·단계 카드의 LEVEL ~ ABILITY 블록. [editor]가 없으면 읽기 전용이다.
Widget _cardBlocks({
  required _CardLayout layout,
  required Map<String, int> values,
  required Map<String, int> previous,
  required PlanFlowGoalEditor? editor,
  required String studentId,
  required String? stageId,
  required bool expanded,
  required List<String?> equipmentTypes,
}) {
  _ValueControl control(String key, String label, String Function(int) text) {
    final value = values[key] ?? 0;
    final stage = stageId;
    final edit = editor;
    if (edit == null || stage == null) {
      return _ValueControl(label: label, value: value, text: text);
    }
    final index = edit
        .stagesOf(studentId)
        .indexWhere((item) => item.id == stage);
    final minimum = edit.minimumOf(studentId, index, key);
    final maximum = math.max(minimum, edit.maximumOf(studentId, key));
    return _ValueControl(
      label: label,
      value: value,
      text: text,
      fieldKey: 'plan-flow-goal-$stage-$key',
      changed: value != (previous[key] ?? value),
      propagated: edit.isPropagated(stage, key),
      onIncrease: value < maximum
          ? () => edit.setTarget(stage, key, value + 1)
          : null,
      onDecrease: value > minimum
          ? () => edit.setTarget(stage, key, value - 1)
          : null,
    );
  }

  String plain(int value) => '$value';
  final level = control('level', '레벨', (value) => 'Lv.$value');
  final star = control('student_star', '성급', (value) => '★$value');
  final weapon = control(
    'weapon_level',
    '전용무기',
    (value) => value == 0 ? '—' : 'Lv.$value',
  );
  final bond = control('bond_rank', '인연', plain);
  final skills = [
    for (final (key, label, maximum) in const [
      ('ex_skill', 'EX', 5),
      ('skill1', 'Normal', 10),
      ('skill2', 'Passive', 10),
      ('skill3', 'Sub', 10),
    ])
      (control(key, label, plain), label, maximum),
  ];
  return Positioned.fill(
    child: Stack(
      children: [
        Positioned.fromRect(
          rect: layout.main,
          child: _Block(
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _LabeledValue(
                    label: 'LEVEL',
                    labelColor: AppColors.accent,
                    control: level,
                    fontSize: AppType.displaySize,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _LabeledValue(
                    label: 'STAR',
                    labelColor: AppColors.starDisplay,
                    control: star,
                    fontSize: AppType.titleLargeSize,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: _LabeledValue(
                    label: 'WEAPON',
                    labelColor: AppColors.primary,
                    control: weapon,
                    fontSize: AppType.titleLargeSize,
                    mutedWhenZero: true,
                  ),
                ),
                Expanded(flex: 3, child: _BondValue(control: bond)),
              ],
            ),
          ),
        ),
        Positioned.fromRect(
          rect: layout.stars,
          child: _StarStrip(
            stageId: stageId,
            studentStar: values['student_star'] ?? 1,
            weaponStar: values['weapon_star'] ?? 0,
            onChanged: editor == null || stageId == null
                ? null
                : (key, value) => editor.setTarget(stageId, key, value),
          ),
        ),
        Positioned.fromRect(
          rect: layout.skill,
          child: // F3c-2: 마키 1단계 카드의 스킬 칸(7-2b · 대사 08g-2).
          TutorialTarget(
            id:
                studentId == 'maki' &&
                    stageId != null &&
                    editor?.stagesOf(studentId).firstOrNull?.id == stageId
                ? TutorialTargets.planMakiStage1Skills
                : null,
            child: _Block(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BlockHeader('SKILL SUMMARY'),
                  Expanded(
                    child: Row(
                      children: [
                        for (final (skill, label, maximum) in skills)
                          Expanded(
                            child: _SkillValue(
                              label: label,
                              control: skill,
                              maximum: maximum,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded && editor != null && stageId != null)
          Positioned.fromRect(
            rect: layout.more,
            child: _MoreBlock(
              editor: editor,
              studentId: studentId,
              stageId: stageId,
              values: values,
            ),
          )
        else ...[
          Positioned.fromRect(
            rect: layout.equipment,
            child: _Block(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BlockHeader('EQUIPMENT'),
                  Expanded(
                    child: Row(
                      children: [
                        for (var slot = 1; slot <= 3; slot++)
                          Expanded(
                            child: _EquipmentSlot(
                              slot: slot,
                              type: equipmentTypes.elementAtOrNull(slot - 1),
                              control: control(
                                'equip${slot}_tier',
                                '장비 $slot 티어',
                                (value) => value == 0 ? '-' : 'T$value',
                              ),
                              level: values['equip${slot}_level'] ?? 0,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fromRect(
            rect: layout.ability,
            child: _Block(
              child: _AbilityRow(
                values: values,
                onMore: editor == null || stageId == null
                    ? null
                    : () => editor.toggleExpanded(stageId),
                moreKey: stageId == null
                    ? null
                    : 'plan-flow-goal-$stageId-more',
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// 값 하나와 미세 조절(▲▼). 읽기 전용이면 [onIncrease]·[onDecrease]가 모두 null이고 버튼을 그리지 않는다.
@immutable
class _ValueControl {
  const _ValueControl({
    required this.label,
    required this.value,
    required this.text,
    this.fieldKey,
    this.changed = false,
    this.propagated = false,
    this.onIncrease,
    this.onDecrease,
  });

  final String label;
  final int value;
  final String Function(int value) text;

  /// 편집 가능한 칸의 키 접두어(`plan-flow-goal-<stage>-<key>`).
  final String? fieldKey;
  final bool changed;
  final bool propagated;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  bool get editable => fieldKey != null;

  /// 값 글자 + 의미 노드(Semantics value 3종: value · increasedValue · decreasedValue, 동작과 짝).
  Widget valueText(TextStyle style) {
    final display = Text(
      text(value),
      key: fieldKey == null ? null : ValueKey('$fieldKey-value'),
      maxLines: 1,
      style: style,
    );
    if (!editable) {
      return Semantics(
        container: true,
        label: label,
        value: text(value),
        child: ExcludeSemantics(child: display),
      );
    }
    return Semantics(
      container: true,
      label: '$label 목표',
      value: text(value),
      increasedValue: onIncrease == null ? null : text(value + 1),
      decreasedValue: onDecrease == null ? null : text(value - 1),
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      child: ExcludeSemantics(child: display),
    );
  }

  Widget nudges() => KeyedSubtree(
    key: ValueKey('$fieldKey-nudge'),
    child: NudgeButtons(
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      increaseLabel: '$label 올리기',
      decreaseLabel: '$label 낮추기',
    ),
  );

  /// 바뀐 칸(분홍 사선 바탕)·이어받은 칸(파란 바탕).
  Widget highlight(Widget child) {
    if (!changed && !propagated) return child;
    return SkewBox(
      fill: propagated ? AppColors.primary.withValues(alpha: 0.22) : _changedFill,
      child: child,
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({
    required this.label,
    required this.labelColor,
    required this.control,
    required this.fontSize,
    this.mutedWhenZero = false,
  });

  final String label;
  final Color labelColor;
  final _ValueControl control;
  final double fontSize;
  final bool mutedWhenZero;

  @override
  Widget build(BuildContext context) {
    final muted = mutedWhenZero && control.value == 0;
    return control.highlight(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: _labelStyle(labelColor)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  control.valueText(
                    _valueStyle(
                      fontSize,
                      color: muted ? AppColors.textMuted : AppColors.text,
                    ),
                  ),
                  if (control.editable) ...[
                    const SizedBox(width: 4),
                    control.nudges(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 인연 하트(시안 34×31, 숫자 15.75 w900 #27465a).
class _BondValue extends StatelessWidget {
  const _BondValue({required this.control});

  final _ValueControl control;

  @override
  Widget build(BuildContext context) => control.highlight(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 31,
              child: CustomPaint(
                painter: const _HeartPainter(),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: control.valueText(
                      const TextStyle(
                        color: Color(0xff27465a),
                        fontSize: 15.75,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (control.editable) ...[
              const SizedBox(width: 4),
              control.nudges(),
            ],
          ],
        ),
      ),
    ),
  );
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = relationshipRankHeartPath(size);
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xff94506f).withValues(alpha: 0.18),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xffffb9e3));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1, size.shortestSide * 0.075)
        ..color = const Color(0xffec70bd),
    );
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) => false;
}

class _SkillValue extends StatelessWidget {
  const _SkillValue({
    required this.label,
    required this.control,
    required this.maximum,
  });

  final String label;
  final _ValueControl control;
  final int maximum;

  @override
  Widget build(BuildContext context) => control.highlight(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: _labelStyle(AppColors.textMuted, weight: AppType.semiBold),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                control.valueText(_valueStyle(AppType.headlineLargeSize)),
                Text(
                  '/$maximum',
                  style: _mutedStyle.copyWith(fontSize: AppType.microSize),
                ),
                if (control.editable) ...[
                  const SizedBox(width: 3),
                  control.nudges(),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 장비 한 칸(시안: 아이콘 48×38 + 티어 배지, `Lv.50/50`, 막대 52×3, 티어 ◀▶).
class _EquipmentSlot extends StatelessWidget {
  const _EquipmentSlot({
    required this.slot,
    required this.type,
    required this.control,
    required this.level,
  });

  final int slot;
  final String? type;
  final _ValueControl control;
  final int level;

  @override
  Widget build(BuildContext context) {
    final tier = control.value;
    final type = this.type;
    final maximum = equipmentTierMaximumLevels[tier] ?? 0;
    return control.highlight(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ItemIconTile(
                    iconAsset: type == null || tier < 1
                        ? null
                        : GameAssets.equipmentIcon(type, tier),
                    size: const Size(48, 38),
                  ),
                  Positioned(
                    left: -4,
                    top: -6,
                    child: Container(
                      height: 15,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      color: const Color.fromRGBO(6, 8, 14, 0.9),
                      child: control.valueText(
                        _labelStyle(const Color(0xffa8e0ff)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Lv.$level', style: _valueStyle(AppType.bodySize)),
                  Text(
                    '/$maximum',
                    style: _mutedStyle.copyWith(
                      fontSize: AppType.indicatorLabelSize,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 52,
                height: 3,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.1),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: maximum <= 0
                        ? 0
                        : (level / maximum).clamp(0.0, 1.0).toDouble(),
                    child: const ColoredBox(color: AppColors.primary),
                  ),
                ),
              ),
              if (control.editable) ...[
                const SizedBox(height: 4),
                KeyedSubtree(
                  key: ValueKey('${control.fieldKey}-nudge'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SideNudge(
                        icon: Icons.chevron_left_rounded,
                        label: '장비 $slot 티어 내리기',
                        onPressed: control.onDecrease,
                      ),
                      const SizedBox(width: 2),
                      _SideNudge(
                        icon: Icons.chevron_right_rounded,
                        label: '장비 $slot 티어 올리기',
                        onPressed: control.onIncrease,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 학생 장비 칸 종류(카탈로그 metadata `equipment_slot_1~3`, 예: `Hat`).
List<String?> planFlowGoalEquipmentTypes(
  PlanFlowGoalEditor editor,
  String studentId,
) {
  final metadata = editor.seedOf(studentId).metadata;
  return [
    for (var slot = 1; slot <= 3; slot++)
      metadata['equipment_slot_$slot']?.toString(),
  ];
}

/// 가로 미세 조절(시안 `.nd` 22 폭, 장비 티어 ◀▶).
class _SideNudge extends StatelessWidget {
  const _SideNudge({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? kitDisabledOpacity : 1,
    child: KitPressable(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (context, state) {
        final active = state.hovered || state.focused;
        return Container(
          width: 22,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.25)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
          child: Icon(
            icon,
            size: 14,
            color: active ? AppColors.accent : AppColors.textMuted,
          ),
        );
      },
    ),
  );
}

/// ABILITY 한 줄(시안 `HP 0 | ATK 0 | HEAL 0`) + "더 보기".
class _AbilityRow extends StatelessWidget {
  const _AbilityRow({required this.values, this.onMore, this.moreKey});

  final Map<String, int> values;
  final VoidCallback? onMore;
  final String? moreKey;

  @override
  Widget build(BuildContext context) {
    final style = _mutedStyle.copyWith(fontSize: AppType.microSize);
    final strong = style.copyWith(
      color: AppColors.text,
      fontWeight: AppType.bold,
    );
    final onMore = this.onMore;
    final moreKey = this.moreKey;
    return Row(
      children: [
        const SubHeader('ABILITY'),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  for (final (index, (key, label)) in const [
                    ('stat_hp', 'HP'),
                    ('stat_atk', 'ATK'),
                    ('stat_heal', 'HEAL'),
                  ].indexed) ...[
                    if (index > 0)
                      const TextSpan(
                        text: '  |  ',
                        style: TextStyle(color: AppColors.outline),
                      ),
                    TextSpan(text: '$label '),
                    TextSpan(text: '${values[key] ?? 0}', style: strong),
                  ],
                ],
              ),
              style: style,
            ),
          ),
        ),
        if (onMore != null)
          KitPressable(
            key: moreKey == null ? null : ValueKey<String>(moreKey),
            onPressed: onMore,
            semanticLabel: '더 보기 · 장비 레벨 · 애장품 · 능력치',
            builder: (context, state) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '더 보기',
                  style: _mutedStyle.copyWith(
                    fontSize: AppType.microSize,
                    color: state.hovered || state.focused
                        ? AppColors.accent
                        : AppColors.textMuted,
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "더 보기"(FD-072): 카드에 칸이 없는 목표(장비 레벨 · 애장품 · 추가 능력치 · 전용무기 성급)를 스테퍼로 고친다.
class _MoreBlock extends StatelessWidget {
  const _MoreBlock({
    required this.editor,
    required this.studentId,
    required this.stageId,
    required this.values,
  });

  final PlanFlowGoalEditor editor;
  final String studentId;
  final String stageId;
  final Map<String, int> values;

  @override
  Widget build(BuildContext context) {
    final index = editor
        .stagesOf(studentId)
        .indexWhere((stage) => stage.id == stageId);
    final fields = <(String, String)>[
      ('equip1_level', '장비 1 Lv'),
      ('equip2_level', '장비 2 Lv'),
      ('equip3_level', '장비 3 Lv'),
      if (editor.hasFavoriteItem(studentId)) ('equip4_tier', '애장품'),
      ('weapon_star', '무기 ★'),
      ('stat_hp', 'HP'),
      ('stat_atk', 'ATK'),
      ('stat_heal', 'HEAL'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final depth = diagonalCutDepth(constraints.maxHeight);
        return _Block(
          padding: EdgeInsets.fromLTRB(depth + 4, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: _BlockHeader('더 보기 · 카드에 없는 목표')),
                  const SizedBox(width: 8),
                  TonalButton(
                    key: ValueKey('plan-flow-goal-$stageId-less'),
                    label: '접기',
                    variant: TonalButtonVariant.ghost,
                    height: 24,
                    horizontalPadding: 10,
                    fontSize: AppType.captionSize,
                    onPressed: () => editor.toggleExpanded(stageId),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: GridView.count(
                  primary: false,
                  crossAxisCount: 2,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3.2,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final (key, label) in fields)
                      () {
                        final minimum = editor.minimumOf(studentId, index, key);
                        final maximum = math.max(
                          minimum,
                          editor.maximumOf(studentId, key),
                        );
                        final value = values[key] ?? 0;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: BaStepper(
                            key: ValueKey('plan-flow-goal-$stageId-$key'),
                            label: label,
                            value: value,
                            minimum: minimum,
                            maximum: maximum,
                            propagated: editor.isPropagated(stageId, key),
                            unsupported: false,
                            valueFontSize: AppType.titleSmallSize,
                            onChanged: (next) =>
                                editor.setTarget(stageId, key, next),
                          ),
                        );
                      }(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 성급 9칸(학생 5 + 전용무기 4, 시안 칸 h22 · 간격 2.5). 누르면 그 칸까지(이미 그 칸이면 한 칸 아래까지).
class _StarStrip extends StatelessWidget {
  const _StarStrip({
    required this.stageId,
    required this.studentStar,
    required this.weaponStar,
    required this.onChanged,
  });

  final String? stageId;
  final int studentStar;
  final int weaponStar;
  final void Function(String key, int value)? onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 2.5;
      final width = (constraints.maxWidth - gap * 8) / 9;
      return Row(
        children: [
          for (var index = 0; index < 9; index++) ...[
            if (index > 0) const SizedBox(width: gap),
            SizedBox(width: width, child: _segment(index)),
          ],
        ],
      );
    },
  );

  Widget _segment(int index) {
    final studentSegment = index < 5;
    final value = studentSegment ? index + 1 : index - 4;
    final selectedValue = studentSegment ? studentStar : weaponStar;
    final on = value <= selectedValue;
    final color = on
        ? studentSegment
              ? _starOn
              : _weaponStarOn
        : _starOff;
    final bar = CustomPaint(
      painter: _SkewFillPainter(color),
      child: const SizedBox.expand(),
    );
    final onChanged = this.onChanged;
    if (onChanged == null || stageId == null) return bar;
    final key = studentSegment ? 'student_star' : 'weapon_star';
    final requested = value <= selectedValue ? value - 1 : value;
    return Semantics(
      button: true,
      selected: value == selectedValue,
      label: '${studentSegment ? '학생' : '전용무기'} 성급 $value',
      child: GestureDetector(
        key: ValueKey(
          'plan-flow-goal-$stageId-${studentSegment ? 'student' : 'weapon'}-star-$value',
        ),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(key, requested),
        child: bar,
      ),
    );
  }
}

class _SkewFillPainter extends CustomPainter {
  const _SkewFillPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    planFlowGoalSkewPath(size, radius: 3),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_SkewFillPainter oldDelegate) => oldDelegate.color != color;
}

/// 단계 카드.
class _StageCard extends StatelessWidget {
  const _StageCard({
    super.key,
    required this.editor,
    required this.studentId,
    required this.index,
    required this.stage,
    required this.stageCount,
    required this.selected,
    required this.cost,
    required this.calculating,
    required this.canCalculate,
  });

  final PlanFlowGoalEditor editor;
  final String studentId;
  final int index;
  final PlanElementStageDraft stage;
  final int stageCount;
  final bool selected;
  final PlanFlowStageCost? cost;
  final bool calculating;
  final bool canCalculate;

  @override
  Widget build(BuildContext context) {
    final effective = editor.isEffective(studentId, stage.id);
    final owned = editor.isOwned(studentId);
    final color = StageTag.colorOf(index + 1);
    final status = planFlowGoalStageStatus(
      effective: effective,
      owned: owned,
      cost: cost,
      calculating: calculating,
    );
    final summary = !effective
        ? '앞 단계보다 올린 목표가 없습니다'
        : !owned
        ? '모집 비용은 아직 계산하지 않습니다'
        : cost != null
        ? planFlowGoalCostLine(cost!)
        : calculating
        ? '비용을 계산하고 있습니다'
        : canCalculate
        ? '비용을 기다립니다'
        : '비용을 계산할 수 없습니다';
    const layout = _CardLayout.stage;
    // 카드는 겹쳐 놓인다(간격 363 < 폭 473). 누르기는 평행사변형 안에서만 받도록 자르기 안쪽에 둔다.
    return ClipPath(
      clipper: const _CardClipper(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => editor.selectStage(stage.id),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CardPainter(
                  fill: effective ? _cardFill : _currentCardFill,
                  stroke: color.withValues(alpha: selected ? 1 : 0.7),
                  strokeWidth: selected ? 6.4 : 5.2,
                ),
              ),
            ),
            Positioned(
              left: 128,
              top: 12,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Semantics(
                        selected: selected,
                        label: '${index + 1}단계',
                        child: ExcludeSemantics(
                          child: StageTag(stage: index + 1, selected: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StageNameField(
                          key: ValueKey('plan-flow-goal-${stage.id}-name'),
                          name: stage.name,
                          onSubmitted: (name) =>
                              editor.renameStage(stage.id, name),
                        ),
                      ),
                      const SizedBox(width: 6),
                      BaChip(
                        key: ValueKey('plan-flow-goal-${stage.id}-status'),
                        label: status.label,
                        tone: status.tone,
                      ),
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: IconButton(
                          key: ValueKey('plan-flow-goal-${stage.id}-remove'),
                          tooltip: '${index + 1}단계 지우기',
                          onPressed: stageCount > 1
                              ? () => editor.removeStage(stage.id)
                              : null,
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    key: ValueKey('plan-flow-goal-${stage.id}-summary'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mutedStyle,
                  ),
                ],
              ),
            ),
            _cardBlocks(
              layout: layout,
              values: stage.targets,
              previous: editor.previousTargetsOf(studentId, index),
              editor: editor,
              studentId: studentId,
              stageId: stage.id,
              expanded: editor.expandedStageId == stage.id,
              equipmentTypes: planFlowGoalEquipmentTypes(editor, studentId),
            ),
            if (editor.expandedStageId != stage.id)
              Positioned.fromRect(
                rect: layout.cost,
                child: _CostBlock(
                  key: ValueKey('plan-flow-goal-${stage.id}-cost'),
                  cost: effective && owned ? cost : null,
                  message: !effective
                      ? '목표를 올리면 비용을 계산합니다'
                      : !owned
                      ? '모집 뒤에 비용을 계산합니다'
                      : calculating
                      ? '계산하고 있습니다'
                      : canCalculate
                      ? '계산을 기다립니다'
                      : '비용을 계산할 수 없습니다',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 카드 머리 단계 이름(인라인 편집, FD-073). 바깥에서 이름이 바뀌면(번호 다시 매기기) 따라간다.
class _StageNameField extends StatefulWidget {
  const _StageNameField({
    super.key,
    required this.name,
    required this.onSubmitted,
  });

  final String name;
  final ValueChanged<String> onSubmitted;

  @override
  State<_StageNameField> createState() => _StageNameFieldState();
}

class _StageNameFieldState extends State<_StageNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.name,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(_StageNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.name != _controller.text && !_focus.hasFocus) {
      _controller.text = widget.name;
    }
  }

  void _focusChanged() {
    if (!_focus.hasFocus && _controller.text != widget.name) {
      widget.onSubmitted(_controller.text);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    maxLines: 1,
    textInputAction: TextInputAction.done,
    onSubmitted: widget.onSubmitted,
    style: _bodyStyle.copyWith(
      fontSize: AppType.bodyLargeSize,
      fontWeight: AppType.bold,
    ),
    decoration: const InputDecoration.collapsed(
      hintText: '단계 이름',
      hintStyle: _mutedStyle,
    ),
  );
}

/// COST 블록(시안: 재화 행 = 아이콘 32×26 · 이름 12 · 양 12 bold · 충분/−n 칩, 세 줄까지).
class _CostBlock extends StatelessWidget {
  const _CostBlock({super.key, required this.cost, required this.message});

  final PlanFlowStageCost? cost;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cost = this.cost;
    final rows = cost == null
        ? const <PlanFlowStageResource>[]
        : planFlowGoalCostRows(cost);
    final visible = rows.take(3).toList();
    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BlockHeader('COST'),
          const SizedBox(height: 4),
          if (cost == null || rows.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  cost == null ? message : '드는 재화가 없습니다',
                  textAlign: TextAlign.center,
                  style: _mutedStyle,
                ),
              ),
            )
          else ...[
            for (final resource in visible)
              Expanded(child: _CostRow(resource: resource)),
            if (rows.length > visible.length)
              Text(
                '외 ${rows.length - visible.length}종',
                textAlign: TextAlign.right,
                style: _mutedStyle.copyWith(fontSize: AppType.microSize),
              ),
          ],
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.resource});

  final PlanFlowStageResource resource;

  @override
  Widget build(BuildContext context) {
    final shortage = resource.shortageAtEntry;
    final amount = planFlowGoalAmount(resource.required);
    final (chip, tone) = switch (shortage) {
      null => (null, AppTones.gray),
      0 => ('충분', AppTones.ok),
      final int value => (
        '−${planFlowGoalAmount(value)}',
        value >= resource.required ? AppTones.danger : AppTones.warn,
      ),
    };
    return Semantics(
      container: true,
      label: resource.name,
      value: chip == null ? '필요 $amount' : '필요 $amount, ${chip == '충분' ? '충분' : '부족 ${chip.substring(1)}'}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            ItemIconTile(
              iconAsset: planningResourceIconAsset(
                category: resource.category,
                itemId: resource.itemId,
              ),
              size: const Size(32, 26),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                resource.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle.copyWith(
                  fontSize: AppType.bodySmallSize,
                  fontWeight: AppType.medium,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              amount,
              style: _bodyStyle.copyWith(
                fontSize: AppType.bodySmallSize,
                fontWeight: AppType.bold,
              ),
            ),
            if (chip != null) ...[
              const SizedBox(width: 6),
              BaChip(label: chip, tone: tone),
            ],
          ],
        ),
      ),
    );
  }
}

/// "단계 추가" 세로 버튼(시안 190×716, 사선 · 점선 테두리 · 세로 글자).
class _AddStageColumn extends StatelessWidget {
  const _AddStageColumn({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _AddClipper(),
    child: KitPressable(
      key: const ValueKey('plan-flow-goal-add-stage'),
      onPressed: onPressed,
      semanticLabel: '단계 추가',
      builder: (context, state) {
        final active = state.hovered || state.focused;
        return CustomPaint(
          painter: _AddPainter(active: active),
          child: Align(
            alignment: const Alignment(-0.15, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: active ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(height: 6),
                for (final char in '단계 추가'.split(''))
                  if (char != ' ')
                    Text(
                      char,
                      style: _mutedStyle.copyWith(
                        height: 1.15,
                        color: active ? AppColors.accent : AppColors.textMuted,
                      ),
                    )
                  else
                    const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// 시안 `clip-path: polygon(126px 0, 100% 0, 64px 100%, 0 100%)`.
List<Offset> _addPolygon(Size size) => [
  Offset(size.width * 126 / 190, 0),
  Offset(size.width, 0),
  Offset(size.width * 64 / 190, size.height),
  Offset(0, size.height),
];

class _AddClipper extends CustomClipper<Path> {
  const _AddClipper();

  @override
  Path getClip(Size size) => Path()..addPolygon(_addPolygon(size), true);

  @override
  bool shouldReclip(_AddClipper oldClipper) => false;
}

class _AddPainter extends CustomPainter {
  const _AddPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addPolygon(_addPolygon(size), true);
    canvas.drawPath(
      path,
      Paint()
        ..color = active ? AppColors.accent.withValues(alpha: 0.1) : _addFill,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = active ? AppColors.accent.withValues(alpha: 0.6) : _addStroke;
    canvas.save();
    canvas.clipPath(path);
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 10) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 5, metric.length)),
          stroke,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AddPainter oldDelegate) => oldDelegate.active != active;
}

// ---------------------------------------------------------------------------
// 현재 → 최종

class _FinalStrip extends StatelessWidget {
  const _FinalStrip({required this.editor, required this.studentId});

  final PlanFlowGoalEditor editor;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    final current = editor.currentOf(studentId);
    final target = editor.finalTargetsOf(studentId);
    return Row(
      key: const ValueKey('plan-flow-goal-final'),
      children: [
        for (final (index, group) in PlanFlowGoalGroup.values.indexed) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(
            child: _FinalItem(
              key: ValueKey('plan-flow-goal-final-${group.name}'),
              group: group,
              current: current,
              target: target,
              hasGoal: editor.hasGoal(studentId, group.keys),
              onClear: () => editor.clearGoal(group.keys),
            ),
          ),
        ],
      ],
    );
  }
}

class _FinalItem extends StatelessWidget {
  const _FinalItem({
    super.key,
    required this.group,
    required this.current,
    required this.target,
    required this.hasGoal,
    required this.onClear,
  });

  final PlanFlowGoalGroup group;
  final Map<String, int> current;
  final Map<String, int> target;
  final bool hasGoal;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final now = planFlowGoalGroupText(group, current);
    final goal = planFlowGoalGroupText(group, target);
    final progress = planFlowGoalGroupProgress(group, current, target);
    final long = group == PlanFlowGoalGroup.skill ||
        group == PlanFlowGoalGroup.equipment ||
        group == PlanFlowGoalGroup.ability;
    return SkewBox(
      fill: AppColors.indicatorSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SubHeader(group.label, fontSize: AppType.indicatorLabelSize),
                const Spacer(),
                if (hasGoal)
                  SizedBox(
                    width: 20,
                    height: 18,
                    child: IconButton(
                      key: ValueKey('plan-flow-goal-clear-${group.name}'),
                      tooltip: '${group.label} 목표 지우기',
                      onPressed: onClear,
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Semantics(
                container: true,
                label: '${group.label} 현재 → 최종',
                value: '$now에서 $goal',
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          now,
                          style: _valueStyle(
                            AppType.bodyLargeSize,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.accent,
                          ),
                        ),
                        Text(
                          goal,
                          style: _valueStyle(
                            long
                                ? AppType.headlineMediumSize
                                : AppType.displaySmallSize,
                            color: hasGoal ? AppColors.text : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 4,
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.08),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: const ColoredBox(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// C 보조

/// 프리셋 행 부제(단계마다 바꾸는 값, `Lv.30 → EX 5`).
String planFlowGoalPresetSummary(PlanElementPreset preset) {
  String stage(Map<String, int> values) {
    final parts = [
      if (values['level'] case final level?) 'Lv.$level',
      if (values['student_star'] case final star?) '★$star',
      if (values['ex_skill'] case final ex?) 'EX $ex',
      if (values.keys.any((key) => key.startsWith('skill'))) '스킬',
      if (values.keys.any((key) => key.endsWith('_tier'))) '장비',
      if (values['weapon_level'] case final weapon?) '무기 Lv.$weapon',
      if (values['bond_rank'] case final bond?) '인연 $bond',
    ];
    return parts.isEmpty ? '목표 없음' : parts.join('·');
  }

  return preset.stages.isEmpty
      ? '단계가 없습니다'
      : preset.stages.map(stage).join(' → ');
}

/// 2단계 C 보조(단계 프리셋 · 다른 학생에도 적용 · 이 학생 재화). 캔버스 전체를 받는다.
class PlanFlowGoalAside extends StatelessWidget {
  const PlanFlowGoalAside({
    super.key,
    required this.flow,
    required this.editor,
    this.presets,
  });

  final PlanFlowController flow;
  final PlanFlowGoalEditor editor;

  /// 단계 프리셋 저장소(FE4-i). 저장된 프리셋 행에 이름 바꾸기·삭제와 저장 안내를 단다.
  final RepositoryPresetsController? presets;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([flow, editor, ?presets]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => _build(context, constraints.biggest),
    ),
  );

  Widget _build(BuildContext context, Size size) {
    final studentId = editor.studentId;
    final sy = size.height / 1208;
    final right = planFlowProtoRect(size, 2538, 0, 0, 0).left;
    double y(double protoTop) => (protoTop - 184) * sy;
    Rect row(double top, double height, double inset) {
      final left = planFlowAsideLeftAt(size, top) + inset * size.width / 2560;
      return Rect.fromLTRB(left, top, math.max(left, right), top + height);
    }

    final children = <Widget>[];
    final header = row(y(231.2), 34, 36.8);
    children.add(
      Positioned.fromRect(
        rect: header,
        child: Row(
          children: [
            Text('단계 프리셋', style: kitDisplayStyle(AppType.panelTitleSize)),
            const SizedBox(width: 8),
            const InfoPopover(
              key: ValueKey('plan-flow-goal-aside-info'),
              label: '단계 프리셋',
              title: '단계 프리셋',
              width: 300,
              children: [
                InfoPopoverText.plain(
                  '프리셋은 학생과 상관없이 단계 구성만 담습니다. 학생에게 적용하면 그 학생의 현재 값에서 시작해 목표만 '
                  '채웁니다. 위 바의 "지금 구성을 프리셋으로"가 지금 학생의 단계를 이 계정에 저장하고, 저장한 프리셋은 '
                  '여기서 이름을 바꾸거나 지웁니다.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (studentId == null) {
      return Stack(
        key: const ValueKey('plan-flow-goal-aside'),
        children: children,
      );
    }
    final mode = editor.modeOf(studentId);
    var top = y(277.2);
    if (editor.presets.isEmpty) {
      final rect = row(top, 64, 16);
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: const DiagonalRow(
            key: ValueKey('plan-flow-goal-aside-presets-empty'),
            variant: DiagonalRowVariant.row,
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '만든 단계 프리셋이 없습니다. 한 번에 MAX나 직접 입력으로 시작한 뒤 "지금 구성을 프리셋으로"로 저장합니다.',
                maxLines: 2,
                style: _mutedStyle,
              ),
            ),
          ),
        ),
      );
      top = rect.bottom + 8 * sy;
    }
    final store = presets;
    for (final preset in editor.presets.take(4)) {
      final presetMode = planFlowGoalPresetMode(preset.id);
      final applied = mode == presetMode;
      final rect = row(top, 64, 9.3);
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: Semantics(
            selected: applied,
            child: DiagonalRow(
              key: ValueKey('plan-flow-goal-aside-preset-${preset.id}'),
              variant: DiagonalRowVariant.srow,
              mark: applied ? DiagonalRowMark.selected : DiagonalRowMark.none,
              onTap: () => editor.applyMode(presetMode),
              padding: const EdgeInsets.only(left: 23.3, right: 14),
              child: _PresetRowContent(
                key: ValueKey('plan-flow-goal-aside-preset-${preset.id}-content'),
                preset: preset,
                applied: applied,
                store: preset.repositoryPresetId == null || store == null
                    ? null
                    : store,
              ),
            ),
          ),
        ),
      );
      top = rect.bottom + 8 * sy;
    }
    // 저장 안내(저장 결과 · 실패 · 다시 읽음) + 다시 저장.
    if (store != null) {
      if (store.message case final message?
          when message.shownIn(RepositoryPresetsScope.presets)) {
        final rect = row(top, 44, 16.2);
        children.add(
          Positioned.fromRect(
            rect: rect,
            child: PlanFlowStoreMessage(
              key: const ValueKey('plan-flow-goal-presets-message'),
              message: message,
              retryKey: const ValueKey('plan-flow-goal-presets-retry'),
              onRetry: store.canRetry ? store.retry : null,
            ),
          ),
        );
        top = rect.bottom + 6 * sy;
      }
    }

    final others = [
      for (final id in editor.studentIds)
        if (id != studentId) id,
    ];
    final applicable = mode != null && mode != planFlowGoalModeDirect;
    if (others.isNotEmpty) {
      final caption = row(top + 12 * sy, 24, 16.2);
      children.add(
        Positioned.fromRect(
          rect: caption,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              applicable
                  ? '다른 학생에도 적용 · ${editor.modeLabel(mode)}'
                  : '다른 학생에도 적용 · 프리셋이나 MAX를 고르면 씁니다',
              key: const ValueKey('plan-flow-goal-apply-caption'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KV.labelStyle,
            ),
          ),
        ),
      );
      top = caption.bottom + 6 * sy;
      const shownLimit = 4;
      for (final other in others.take(shownLimit)) {
        final rect = row(top, 62, 22.9);
        final otherMode = editor.modeOf(other);
        final stages = flow.draft.stagesByStudent[other]?.length ?? 0;
        final sub = stages == 0
            ? '목표 없음'
            : otherMode == null
            ? '$stages단계 · 완료'
            : '${editor.modeLabel(otherMode)} $stages단계 · 완료';
        children.add(
          Positioned.fromRect(
            rect: rect,
            child: DiagonalRow(
              key: ValueKey('plan-flow-goal-other-$other'),
              variant: DiagonalRowVariant.row,
              padding: const EdgeInsets.only(left: 22.9, right: 14),
              child: Row(
                children: [
                  PortraitStrip(
                    studentIds: [other],
                    maxVisible: 1,
                    portraitSize: const Size(49, 40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editor.displayName(other),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle.copyWith(fontWeight: AppType.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _mutedStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: TonalButton(
                        key: ValueKey('plan-flow-goal-apply-$other'),
                        label: !applicable
                            ? '적용'
                            : stages == 0
                            ? '${editor.modeLabel(mode)} 적용'
                            : '바꾸기',
                        height: 28,
                        horizontalPadding: 12,
                        fontSize: AppType.bodySmallSize,
                        onPressed: applicable && otherMode != mode
                            ? () => editor.applyCurrentModeTo([other])
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        top = rect.bottom + 8 * sy;
      }
      if (others.length > shownLimit) {
        final rest = row(top, 22, 20);
        children.add(
          Positioned.fromRect(
            rect: rest,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '외 ${others.length - shownLimit}명은 아래 버튼으로 함께 적용합니다',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mutedStyle,
              ),
            ),
          ),
        );
        top = rest.bottom + 6 * sy;
      }
      final all = row(top, 50, 10.2);
      children.add(
        Positioned.fromRect(
          rect: all,
          child: // F3c-2: 시안은 버튼이 아니라 줄 전체(451×50)에 테두리를 그린다.
          TutorialTarget(
            id: TutorialTargets.planAllMaxPreset,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: TonalButton(
                  key: const ValueKey('plan-flow-goal-apply-all'),
                  label: applicable
                      ? '고른 ${editor.studentIds.length}명 모두 ${editor.modeLabel(mode)}로'
                      : '고른 ${editor.studentIds.length}명 모두 같은 목표로',
                  icon: Icons.groups_rounded,
                  variant: TonalButtonVariant.ghost,
                  height: 44,
                  fontSize: AppType.bodySize,
                  onPressed: applicable
                      ? () {
                          editor.applyCurrentModeTo(others);
                          if (editor.studentIds.every(
                            (id) => editor.modeOf(id) == planFlowGoalModeMax,
                          )) {
                            TutorialHooksScope.emit(
                              context,
                              TutorialSignals.planAllMaxApplied,
                            );
                          }
                        }
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
      top = all.bottom + 14 * sy;
    }

    // 이 학생 재화 요약.
    final calculation = flow.calculation;
    final stageIds = {
      for (final stage
          in flow.draft.stagesByStudent[studentId] ??
              const <PlanFlowStageDraft>[])
        stage.id,
    };
    final costs = [
      for (final id in stageIds) ?calculation?.stageCosts[id],
    ];
    final resourceKeys = {
      for (final cost in costs)
        for (final resource in cost.resources) resource.resourceKey,
    };
    final shortKeys = {
      for (final cost in costs)
        for (final resource in cost.resources)
          if ((resource.shortageAtEntry ?? 0) > 0) resource.resourceKey,
    };
    final known = costs.isNotEmpty && costs.length == stageIds.length;
    final summary = row(top, 92, 4.9);
    children.add(
      Positioned.fromRect(
        rect: summary,
        child: DiagonalRow(
          key: const ValueKey('plan-flow-goal-aside-summary'),
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.only(left: 28.2, right: 14),
          child: Row(
            children: [
              Expanded(
                child: KV(
                  label: '이 학생 재화',
                  value: Text(
                    known ? '${resourceKeys.length}종' : '—',
                    key: const ValueKey('plan-flow-goal-aside-resources'),
                    style: kitDisplayStyle(AppType.displaySmallSize),
                  ),
                ),
              ),
              Expanded(
                child: KV(
                  label: '부족',
                  value: Text(
                    known && costs.any((cost) => cost.shortageKnown)
                        ? '${shortKeys.length}종'
                        : '—',
                    key: const ValueKey('plan-flow-goal-aside-shortage'),
                    style: kitDisplayStyle(
                      AppType.displaySmallSize,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Stack(
      key: const ValueKey('plan-flow-goal-aside'),
      children: children,
    );
  }
}

/// C 프리셋 행 내용: 이름(저장된 프리셋은 인라인으로 바꾼다) · 적용 중 칩 · 단계 요약 · 이름 바꾸기/지우기.
class _PresetRowContent extends StatefulWidget {
  const _PresetRowContent({
    super.key,
    required this.preset,
    required this.applied,
    required this.store,
  });

  final PlanElementPreset preset;
  final bool applied;

  /// 저장된 프리셋이면 그 저장소. 인메모리 프리셋(계획 화면 프리셋 관리)이면 null이다.
  final RepositoryPresetsController? store;

  @override
  State<_PresetRowContent> createState() => _PresetRowContentState();
}

class _PresetRowContentState extends State<_PresetRowContent> {
  bool _renaming = false;

  void _rename(String value) {
    final store = widget.store;
    final presetId = widget.preset.repositoryPresetId;
    setState(() => _renaming = false);
    if (store == null || presetId == null) return;
    if (value.trim().isEmpty || value.trim() == widget.preset.name) return;
    store.renameStagePreset(presetId, value);
  }

  @override
  Widget build(BuildContext context) {
    final preset = widget.preset;
    final store = widget.store;
    final presetId = preset.repositoryPresetId;
    final nameStyle = _bodyStyle.copyWith(
      fontSize: AppType.titleSmallSize,
      fontWeight: AppType.bold,
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: _renaming
                        ? TextFormField(
                            key: ValueKey(
                              'plan-flow-goal-aside-preset-${preset.id}-name-field',
                            ),
                            initialValue: preset.name,
                            autofocus: true,
                            maxLines: 1,
                            textInputAction: TextInputAction.done,
                            style: nameStyle,
                            decoration: const InputDecoration.collapsed(
                              hintText: '프리셋 이름',
                              hintStyle: _mutedStyle,
                            ),
                            onFieldSubmitted: _rename,
                          )
                        : Text(
                            preset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: nameStyle,
                          ),
                  ),
                  if (widget.applied) ...[
                    const SizedBox(width: 8),
                    const BaChip(label: '적용 중', tone: AppTones.pink),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                planFlowGoalPresetSummary(preset),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mutedStyle,
              ),
            ],
          ),
        ),
        if (store != null && presetId != null) ...[
          IconButton(
            key: ValueKey('plan-flow-goal-aside-preset-${preset.id}-rename'),
            tooltip: '프리셋 이름 바꾸기',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: AppColors.textMuted,
            onPressed: store.canEdit
                ? () => setState(() => _renaming = !_renaming)
                : null,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: ValueKey('plan-flow-goal-aside-preset-${preset.id}-delete'),
            tooltip: '프리셋 지우기',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: AppColors.textMuted,
            onPressed: store.canEdit
                ? () => store.deleteStagePreset(presetId)
                : null,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ] else
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
      ],
    );
  }
}
