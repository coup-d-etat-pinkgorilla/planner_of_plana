import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scenario_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/diagonal_scrollbar.dart';
import '../kit/game_assets.dart';
import '../kit/skew_bar.dart';
import '../models/plan_flow_draft.dart';
import '../models/plan_flow_save.dart'
    show
        PlanFlowSaveOutcome,
        PlanFlowSaveTarget,
        planFlowAuthoringReasonText,
        planFlowFulfillment,
        planFlowIncorporateScenario,
        planFlowSaveErrorCode;
import '../models/planning_models.dart';
import '../models/planning_resource_assets.dart';
import '../models/repository_plan_snapshot.dart';
import '../studio/plan_studio_layout.dart';
import 'animated_section_stack.dart';
import 'ba_triangle_background.dart';
import 'diagonal_menu.dart' show roundedPolygonPath;
import 'diagonal_flow_indicator.dart';
import 'diagonal_media_list_item.dart';
import 'lifted_path_shadow.dart';
import 'plan_element_builder.dart';
import 'plan_flow_save_step.dart' show planFlowSavePercent;
import 'plan_flow_workspace.dart';
import 'plan_phase_editor.dart';
import 'plan_preset_manager.dart';
import 'plan_scenario_list.dart';
import 'plan_student_selector.dart';
import 'plan_student_step_tile.dart';
import 'section_surface.dart';
import 'section_template_surface.dart';

export 'plan_scenario_list.dart'
    show PlanScenarioListSection, PlanScenarioListRow, PlanScenarioActiveRow;
export 'plan_student_step_tile.dart';

const planSectionOpacity = sectionSurfaceOpacity;
const planPhaseItemHeight = 65.0;
const planPhaseItemExtent = 69.0;
const planPhaseHeaderHeight = 38.0;
const planPhaseFlowGap = 20.0;
const planResourceTabHeight = 44.0;
const planResourceHeaderHeight = 94.0;
const planSection1Motion = SectionMotionSpec(intro: 0, outro: 180);

/// 저장된 활성 계획의 `calculation`이 null일 때 섹션 3 문구(FE4-h). 문서 내용(섹션 2)은 그대로 보인다.
const planCalculationUnavailableMessage =
    '계산할 수 없음\n지금은 이 계획을 계산할 수 없습니다. 계획 내용은 그대로 보여 줍니다.';
const planSection2Motion = SectionMotionSpec(intro: 80, outro: 260);
const planSection3Motion = SectionMotionSpec(intro: 80, outro: 260);
const planSection4Motion = SectionMotionSpec(intro: 180, outro: 0);
const planSection5Motion = SectionMotionSpec(intro: 260, outro: 80);
const planSection3TabMotion = SectionMotionSpec(intro: 80, outro: 260);
const planScenarioListMotion = SectionMotionSpec(intro: 80, outro: 260);

const Map<String, SectionMotionSpec> planSectionMotions = {
  'element-1': planSection1Motion,
  'element-2': planSection2Motion,
  'element-3': planSection3Motion,
  'element-4': planSection4Motion,
  'element-5': planSection5Motion,
};

enum PlanResourceView { bottleneck, byPhase, overall }

enum PlanResourceCategory {
  tacticalBd('전술 교육 BD'),
  skillNote('기술 노트'),
  ooparts('오파츠'),
  equipment('장비'),
  weaponParts('무기 부품'),
  enhancementStone('강화석'),
  credits('크레딧'),
  report('보고서'),
  eleph('엘레프'),
  gift('선물');

  const PlanResourceCategory(this.label);

  final String label;
}

enum PlanResourceSort {
  defaultOrder('기본 순서', '기본'),
  shortageDescending('부족량 많은 순', '부족량 ↓'),
  requiredDescending('필요량 많은 순', '필요량 ↓'),
  ownedAscending('보유량 적은 순', '보유량 ↑'),
  nameAscending('이름순', '이름 ↑');

  const PlanResourceSort(this.menuLabel, this.compactLabel);

  final String menuLabel;
  final String compactLabel;
}

typedef PlanResourceToggle =
    void Function(String resourceKey, Set<String> stageKeys);

// FE5-c1: 요약 행 3종의 숫자(보유 · 필요 · 학생 수 · 충족률 등)는 상수가 아니라 화면 목록의 projection이다
// ([PlanResourceSummaryProjection]). 아래 이름 · 아이콘 상수는 계산 전 견본 목록(dummy)과 아이콘 대체값이 쓴다.
const planPrimaryBottleneckItemId = 'Item_Icon_Material_Nebra_2';
// Canonical display names follow the v6 item-id catalogs. Opart icon suffixes
// are zero-based rarity indices, while equipment TierN suffixes are 1-based.
const planPrimaryBottleneckItemName = '마모된 네브라 디스크';
const planPrimaryBottleneckIconAsset =
    '${GameAssets.itemIconDirectory}/ooparts/Item_Icon_Material_Nebra_2.png';
const planPrimaryBottleneckBackgroundAsset = GameAssets.itemBackgroundYellow;
const planPhaseShortageItemName = '온전한 안티키테라 장치';
const planPhaseShortageIconAsset =
    '${GameAssets.itemIconDirectory}/ooparts/Item_Icon_Material_Antikythera_3.png';
const planPhaseShortageBackgroundAsset = GameAssets.itemBackgroundPurple;
const planBottleneckContainerScale = 0.95;
const planBottleneckContainerTopRatio = 0.025;
const planCreditIconAsset = GameAssets.creditIcon;
const planBasicTacticalBdIconAsset =
    '${GameAssets.itemIconDirectory}/tactical_bd/Item_Icon_Material_ExSkill_Abydos_0.png';
const planDefaultItemBackgroundAsset = GameAssets.itemBackgroundBasic;
const planHairpinTier10ItemName = '전자파 차단 헤어핀';
const planHatTier10ItemName = '게이밍 헬멧';
const planWatchTier10ItemName = '스크린 워치';

@immutable
class PlanBottleneckResourcePreview {
  const PlanBottleneckResourcePreview({
    required this.id,
    required this.name,
    required this.remainingAtEntry,
    required this.requiredAtEntry,
    required this.shortage,
    required this.iconAsset,
    required this.affectedStageKeys,
    this.backgroundAsset,
    this.equipmentTier,
  });

  final String id;
  final String name;
  final int remainingAtEntry;
  final int requiredAtEntry;
  final int shortage;
  final String iconAsset;
  final Set<String> affectedStageKeys;
  final String? backgroundAsset;
  final int? equipmentTier;

  String get displayName =>
      equipmentTier == null ? name : '$name (T$equipmentTier)';

  // v6 treats regular Equipment_Icon_*_TierN icons as a separate family from
  // tier-indexed materials. Their background is always the default square.
  String? get effectiveBackgroundAsset =>
      equipmentTier == null ? backgroundAsset : planDefaultItemBackgroundAsset;
}

@immutable
class PlanDelayedStagePreview {
  const PlanDelayedStagePreview({
    required this.phaseId,
    required this.studentId,
    required this.step,
    required this.label,
  });

  final String phaseId;
  final String studentId;
  final int step;
  final String label;

  String get key => planStudentStageKey(phaseId, studentId, step);
}

@immutable
class PlanBottleneckDetailPreview {
  const PlanBottleneckDetailPreview({
    required this.id,
    required this.rankLabel,
    required this.phaseNumber,
    required this.focusPhaseId,
    required this.focusStudentId,
    required this.focusStep,
    required this.focusStage,
    required this.focusField,
    required this.resources,
    required this.delayedStages,
    this.focusBondRank,
    this.focusStepData,
  });

  final String id;
  final String rankLabel;
  final int phaseNumber;
  final String focusPhaseId;
  final String focusStudentId;
  final int focusStep;
  final String focusStage;
  final PlanBottleneckFocusField focusField;
  final List<PlanBottleneckResourcePreview> resources;
  final List<PlanDelayedStagePreview> delayedStages;
  final int? focusBondRank;
  final PlanStudentStepPreview? focusStepData;
}

const dummyPlanBottleneckDetails = <PlanBottleneckDetailPreview>[
  PlanBottleneckDetailPreview(
    id: 'bottleneck-1',
    rankLabel: '병목 1',
    phaseNumber: 2,
    focusPhaseId: 'phase-2',
    focusStudentId: 'hoshino',
    focusStep: 2,
    focusStage: '호시노 2단계',
    focusField: PlanBottleneckFocusField.skills,
    resources: [
      PlanBottleneckResourcePreview(
        id: 'basic-tactical-bd',
        name: '기초 전술교육 BD : 아비도스',
        remainingAtEntry: 4,
        requiredAtEntry: 12,
        shortage: 8,
        iconAsset: planBasicTacticalBdIconAsset,
        affectedStageKeys: {
          'phase-2:hoshino:2',
          'phase-3:nonomi:2',
          'phase-4:ako:3',
        },
        backgroundAsset: planDefaultItemBackgroundAsset,
      ),
    ],
    delayedStages: [
      PlanDelayedStagePreview(
        phaseId: 'phase-2',
        studentId: 'hoshino',
        step: 2,
        label: '호시노 2단계',
      ),
      PlanDelayedStagePreview(
        phaseId: 'phase-3',
        studentId: 'nonomi',
        step: 2,
        label: '노노미 2단계',
      ),
      PlanDelayedStagePreview(
        phaseId: 'phase-4',
        studentId: 'ako',
        step: 3,
        label: '아코 3단계',
      ),
    ],
  ),
  PlanBottleneckDetailPreview(
    id: 'bottleneck-2',
    rankLabel: '병목 2',
    phaseNumber: 2,
    focusPhaseId: 'phase-2',
    focusStudentId: 'nonomi',
    focusStep: 1,
    focusStage: '노노미 1단계',
    focusField: PlanBottleneckFocusField.title,
    resources: [
      PlanBottleneckResourcePreview(
        id: 'credits',
        name: '크레딧',
        remainingAtEntry: 120000,
        requiredAtEntry: 850000,
        shortage: 730000,
        iconAsset: planCreditIconAsset,
        affectedStageKeys: {'phase-2:nonomi:1', 'phase-3:azusa:3'},
      ),
      PlanBottleneckResourcePreview(
        id: 'antikythera-t4',
        name: planPhaseShortageItemName,
        remainingAtEntry: 1,
        requiredAtEntry: 5,
        shortage: 4,
        iconAsset: planPhaseShortageIconAsset,
        affectedStageKeys: {'phase-2:yuuka:2', 'phase-3:azusa:3'},
        backgroundAsset: planPhaseShortageBackgroundAsset,
      ),
      PlanBottleneckResourcePreview(
        id: 'nebra-t3-secondary',
        name: planPrimaryBottleneckItemName,
        remainingAtEntry: 3,
        requiredAtEntry: 7,
        shortage: 4,
        iconAsset: planPrimaryBottleneckIconAsset,
        affectedStageKeys: {'phase-2:nonomi:1', 'phase-3:azusa:3'},
        backgroundAsset: planPrimaryBottleneckBackgroundAsset,
      ),
    ],
    delayedStages: [
      PlanDelayedStagePreview(
        phaseId: 'phase-2',
        studentId: 'nonomi',
        step: 1,
        label: '노노미 1단계',
      ),
      PlanDelayedStagePreview(
        phaseId: 'phase-3',
        studentId: 'azusa',
        step: 3,
        label: '아즈사 3단계',
      ),
    ],
  ),
  PlanBottleneckDetailPreview(
    id: 'bottleneck-3',
    rankLabel: '병목 3',
    phaseNumber: 3,
    focusPhaseId: 'phase-3',
    focusStudentId: 'azusa',
    focusStep: 3,
    focusStage: '아즈사 3단계',
    focusField: PlanBottleneckFocusField.equipment1,
    focusBondRank: 100,
    resources: [
      PlanBottleneckResourcePreview(
        id: 'hairpin-t10',
        name: planHairpinTier10ItemName,
        remainingAtEntry: 1,
        requiredAtEntry: 3,
        shortage: 2,
        iconAsset: GameAssets.equipmentHairpinT10,
        affectedStageKeys: {'phase-3:azusa:3', 'phase-4:ako:3'},
        backgroundAsset: planDefaultItemBackgroundAsset,
        equipmentTier: 10,
      ),
    ],
    delayedStages: [
      PlanDelayedStagePreview(
        phaseId: 'phase-3',
        studentId: 'azusa',
        step: 3,
        label: '아즈사 3단계',
      ),
      PlanDelayedStagePreview(
        phaseId: 'phase-4',
        studentId: 'ako',
        step: 3,
        label: '아코 3단계',
      ),
    ],
  ),
  PlanBottleneckDetailPreview(
    id: 'bottleneck-4',
    rankLabel: '병목 4',
    phaseNumber: 1,
    focusPhaseId: 'phase-1',
    focusStudentId: 'haruka',
    focusStep: 1,
    focusStage: '하루카 1단계',
    focusField: PlanBottleneckFocusField.skills,
    resources: [
      PlanBottleneckResourcePreview(
        id: 'nebra-t3',
        name: planPrimaryBottleneckItemName,
        remainingAtEntry: 2,
        requiredAtEntry: 9,
        shortage: 7,
        iconAsset: planPrimaryBottleneckIconAsset,
        affectedStageKeys: {'phase-1:haruka:1', 'phase-2:nonomi:1'},
        backgroundAsset: planPrimaryBottleneckBackgroundAsset,
      ),
    ],
    delayedStages: [
      PlanDelayedStagePreview(
        phaseId: 'phase-1',
        studentId: 'haruka',
        step: 1,
        label: '하루카 1단계',
      ),
      PlanDelayedStagePreview(
        phaseId: 'phase-2',
        studentId: 'nonomi',
        step: 1,
        label: '노노미 1단계',
      ),
    ],
  ),
];

@immutable
class PlanConsumptionResourcePreview {
  const PlanConsumptionResourcePreview({
    required this.id,
    required this.name,
    required this.amount,
    required this.owned,
    required this.iconAsset,
    required this.affectedStageKeys,
    this.inventoryKnown = true,
    this.backgroundAsset,
    this.equipmentTier,
  });

  final String id;
  final String name;
  final int amount;
  final int owned;
  final String iconAsset;
  final Set<String> affectedStageKeys;
  final bool inventoryKnown;
  final String? backgroundAsset;
  final int? equipmentTier;

  String get displayName =>
      equipmentTier == null ? name : '$name (T$equipmentTier)';

  bool get isBottleneck => inventoryKnown && amount > owned;

  int get endingAmount => owned - amount;

  int get shortageAmount => math.max(0, -endingAmount);

  double get coverageRatio => !inventoryKnown
      ? 0
      : amount <= 0
      ? 1
      : (owned / amount).clamp(0, 1);

  int get coveragePercent => (coverageRatio * 100).round();

  String get ownedDisplay => inventoryKnown ? formatPlanAmount(owned) : '미확인';

  String get endingDisplay =>
      inventoryKnown ? formatPlanAmount(endingAmount) : '미확인';

  String get _knownBalanceDisplay =>
      isBottleneck ? '부족 ${formatPlanAmount(shortageAmount)}' : '충족';

  String get balanceDisplay =>
      inventoryKnown ? _knownBalanceDisplay : '보유량 미확인';

  String? get effectiveBackgroundAsset =>
      equipmentTier == null ? backgroundAsset : planDefaultItemBackgroundAsset;
}

@immutable
class PlanConsumptionGroupPreview {
  const PlanConsumptionGroupPreview({
    required this.id,
    required this.label,
    required this.resources,
  });

  final String id;
  final String label;
  final List<PlanConsumptionResourcePreview> resources;
}

const dummyPlanPhaseConsumptions = <PlanConsumptionGroupPreview>[
  PlanConsumptionGroupPreview(
    id: 'phase-1',
    label: '페이즈 1',
    resources: [
      PlanConsumptionResourcePreview(
        id: 'phase-1-credits',
        name: '크레딧',
        amount: 360000,
        owned: 4000000,
        iconAsset: planCreditIconAsset,
        affectedStageKeys: {
          'phase-1:shiroko:1',
          'phase-1:hoshino:1',
          'phase-1:serika:1',
          'phase-1:haruka:1',
        },
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-1-basic-bd',
        name: '기초 전술교육 BD : 아비도스',
        amount: 12,
        owned: 20,
        iconAsset: planBasicTacticalBdIconAsset,
        affectedStageKeys: {'phase-1:hoshino:1', 'phase-1:haruka:1'},
        backgroundAsset: planDefaultItemBackgroundAsset,
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-1-nebra-t3',
        name: planPrimaryBottleneckItemName,
        amount: 9,
        owned: 18,
        iconAsset: planPrimaryBottleneckIconAsset,
        affectedStageKeys: {'phase-1:shiroko:1', 'phase-1:haruka:1'},
        backgroundAsset: planPrimaryBottleneckBackgroundAsset,
      ),
    ],
  ),
  PlanConsumptionGroupPreview(
    id: 'phase-2',
    label: '페이즈 2',
    resources: [
      PlanConsumptionResourcePreview(
        id: 'phase-2-credits',
        name: '크레딧',
        amount: 850000,
        owned: 3640000,
        iconAsset: planCreditIconAsset,
        affectedStageKeys: {
          'phase-2:shiroko:2',
          'phase-2:nonomi:1',
          'phase-2:hoshino:2',
          'phase-2:yuuka:2',
        },
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-2-antikythera-t4',
        name: planPhaseShortageItemName,
        amount: 5,
        owned: 3,
        iconAsset: planPhaseShortageIconAsset,
        affectedStageKeys: {'phase-2:yuuka:2'},
        backgroundAsset: planPhaseShortageBackgroundAsset,
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-2-nebra-t3',
        name: planPrimaryBottleneckItemName,
        amount: 7,
        owned: 9,
        iconAsset: planPrimaryBottleneckIconAsset,
        affectedStageKeys: {'phase-2:nonomi:1', 'phase-2:hoshino:2'},
        backgroundAsset: planPrimaryBottleneckBackgroundAsset,
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-2-hairpin-t10',
        name: planHairpinTier10ItemName,
        amount: 3,
        owned: 2,
        iconAsset: GameAssets.equipmentHairpinT10,
        affectedStageKeys: {'phase-2:yuuka:2'},
        backgroundAsset: planDefaultItemBackgroundAsset,
        equipmentTier: 10,
      ),
    ],
  ),
  PlanConsumptionGroupPreview(
    id: 'phase-3',
    label: '페이즈 3',
    resources: [
      PlanConsumptionResourcePreview(
        id: 'phase-3-credits',
        name: '크레딧',
        amount: 1240000,
        owned: 2790000,
        iconAsset: planCreditIconAsset,
        affectedStageKeys: {
          'phase-3:shiroko:3',
          'phase-3:serika:2',
          'phase-3:nonomi:2',
          'phase-3:azusa:3',
        },
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-3-basic-bd',
        name: '기초 전술교육 BD : 아비도스',
        amount: 18,
        owned: 8,
        iconAsset: planBasicTacticalBdIconAsset,
        affectedStageKeys: {'phase-3:nonomi:2', 'phase-3:azusa:3'},
        backgroundAsset: planDefaultItemBackgroundAsset,
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-3-antikythera-t4',
        name: planPhaseShortageItemName,
        amount: 12,
        owned: 0,
        iconAsset: planPhaseShortageIconAsset,
        affectedStageKeys: {'phase-3:azusa:3'},
        backgroundAsset: planPhaseShortageBackgroundAsset,
      ),
    ],
  ),
  PlanConsumptionGroupPreview(
    id: 'phase-4',
    label: '페이즈 4',
    resources: [
      PlanConsumptionResourcePreview(
        id: 'phase-4-credits',
        name: '크레딧',
        amount: 1960000,
        owned: 1550000,
        iconAsset: planCreditIconAsset,
        affectedStageKeys: {
          'phase-4:aru:1',
          'phase-4:ayane:1',
          'phase-4:hina:2',
          'phase-4:ako:3',
        },
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-4-nebra-t3',
        name: planPrimaryBottleneckItemName,
        amount: 16,
        owned: 2,
        iconAsset: planPrimaryBottleneckIconAsset,
        affectedStageKeys: {'phase-4:ako:3'},
        backgroundAsset: planPrimaryBottleneckBackgroundAsset,
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-4-hat-t10',
        name: planHatTier10ItemName,
        amount: 4,
        owned: 1,
        iconAsset: GameAssets.equipmentHatT10,
        affectedStageKeys: {'phase-4:hina:2'},
        backgroundAsset: planDefaultItemBackgroundAsset,
        equipmentTier: 10,
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-4-watch-t10',
        name: planWatchTier10ItemName,
        amount: 2,
        owned: 5,
        iconAsset: GameAssets.equipmentWatchT10,
        affectedStageKeys: {'phase-4:ako:3'},
        backgroundAsset: planDefaultItemBackgroundAsset,
        equipmentTier: 10,
      ),
    ],
  ),
];

const dummyPlanOverallConsumption = PlanConsumptionGroupPreview(
  id: 'overall',
  label: '전체 계획',
  resources: [
    PlanConsumptionResourcePreview(
      id: 'overall-credits',
      name: '크레딧',
      amount: 4410000,
      owned: 4000000,
      iconAsset: planCreditIconAsset,
      affectedStageKeys: {
        'phase-1:shiroko:1',
        'phase-1:hoshino:1',
        'phase-1:serika:1',
        'phase-1:haruka:1',
        'phase-2:shiroko:2',
        'phase-2:nonomi:1',
        'phase-2:hoshino:2',
        'phase-2:yuuka:2',
        'phase-3:shiroko:3',
        'phase-3:serika:2',
        'phase-3:nonomi:2',
        'phase-3:azusa:3',
        'phase-4:aru:1',
        'phase-4:ayane:1',
        'phase-4:hina:2',
        'phase-4:ako:3',
      },
    ),
    PlanConsumptionResourcePreview(
      id: 'overall-basic-bd',
      name: '기초 전술교육 BD : 아비도스',
      amount: 30,
      owned: 20,
      iconAsset: planBasicTacticalBdIconAsset,
      affectedStageKeys: {
        'phase-1:hoshino:1',
        'phase-1:haruka:1',
        'phase-3:nonomi:2',
        'phase-3:azusa:3',
      },
      backgroundAsset: planDefaultItemBackgroundAsset,
    ),
    PlanConsumptionResourcePreview(
      id: 'overall-antikythera-t4',
      name: planPhaseShortageItemName,
      amount: 17,
      owned: 3,
      iconAsset: planPhaseShortageIconAsset,
      affectedStageKeys: {'phase-2:yuuka:2', 'phase-3:azusa:3'},
      backgroundAsset: planPhaseShortageBackgroundAsset,
    ),
    PlanConsumptionResourcePreview(
      id: 'overall-nebra-t3',
      name: planPrimaryBottleneckItemName,
      amount: 32,
      owned: 18,
      iconAsset: planPrimaryBottleneckIconAsset,
      affectedStageKeys: {
        'phase-1:shiroko:1',
        'phase-1:haruka:1',
        'phase-2:nonomi:1',
        'phase-2:hoshino:2',
        'phase-4:ako:3',
      },
      backgroundAsset: planPrimaryBottleneckBackgroundAsset,
    ),
    PlanConsumptionResourcePreview(
      id: 'overall-hairpin-t10',
      name: planHairpinTier10ItemName,
      amount: 3,
      owned: 2,
      iconAsset: GameAssets.equipmentHairpinT10,
      affectedStageKeys: {'phase-2:yuuka:2'},
      backgroundAsset: planDefaultItemBackgroundAsset,
      equipmentTier: 10,
    ),
    PlanConsumptionResourcePreview(
      id: 'overall-hat-t10',
      name: planHatTier10ItemName,
      amount: 4,
      owned: 1,
      iconAsset: GameAssets.equipmentHatT10,
      affectedStageKeys: {'phase-4:hina:2'},
      backgroundAsset: planDefaultItemBackgroundAsset,
      equipmentTier: 10,
    ),
    PlanConsumptionResourcePreview(
      id: 'overall-watch-t10',
      name: planWatchTier10ItemName,
      amount: 2,
      owned: 5,
      iconAsset: GameAssets.equipmentWatchT10,
      affectedStageKeys: {'phase-4:ako:3'},
      backgroundAsset: planDefaultItemBackgroundAsset,
      equipmentTier: 10,
    ),
  ],
);

PlanResourceCategory planResourceCategory({
  required String id,
  required String iconAsset,
  int? equipmentTier,
}) {
  final key = '$id $iconAsset'.toLowerCase();
  if (iconAsset == planCreditIconAsset || key.contains('credit')) {
    return PlanResourceCategory.credits;
  }
  if (equipmentTier != null || key.contains('equipment_icons')) {
    return PlanResourceCategory.equipment;
  }
  if (key.contains('tactical_bd') || key.contains('basic-bd')) {
    return PlanResourceCategory.tacticalBd;
  }
  if (key.contains('skill_note') || key.contains('skillnote')) {
    return PlanResourceCategory.skillNote;
  }
  if (key.contains('weaponexp') || key.contains('weapon-part')) {
    return PlanResourceCategory.weaponParts;
  }
  if (key.contains('equipment_icon_exp') || key.contains('enhancement-stone')) {
    return PlanResourceCategory.enhancementStone;
  }
  if (key.contains('report') || key.contains('activity')) {
    return PlanResourceCategory.report;
  }
  if (key.contains('eleph')) return PlanResourceCategory.eleph;
  if (key.contains('present') || key.contains('gift')) {
    return PlanResourceCategory.gift;
  }
  return PlanResourceCategory.ooparts;
}

int _comparePlanConsumptionResources(
  PlanConsumptionResourcePreview a,
  PlanConsumptionResourcePreview b,
  PlanResourceSort sort,
) {
  final comparison = switch (sort) {
    PlanResourceSort.defaultOrder => 0,
    PlanResourceSort.shortageDescending => b.shortageAmount.compareTo(
      a.shortageAmount,
    ),
    PlanResourceSort.requiredDescending => b.amount.compareTo(a.amount),
    PlanResourceSort.ownedAscending => a.owned.compareTo(b.owned),
    PlanResourceSort.nameAscending => a.displayName.compareTo(b.displayName),
  };
  return comparison != 0 ? comparison : a.displayName.compareTo(b.displayName);
}

int _comparePlanBottleneckResources(
  PlanBottleneckResourcePreview a,
  PlanBottleneckResourcePreview b,
  PlanResourceSort sort,
) {
  final comparison = switch (sort) {
    PlanResourceSort.defaultOrder => 0,
    PlanResourceSort.shortageDescending => b.shortage.compareTo(a.shortage),
    PlanResourceSort.requiredDescending => b.requiredAtEntry.compareTo(
      a.requiredAtEntry,
    ),
    PlanResourceSort.ownedAscending => a.remainingAtEntry.compareTo(
      b.remainingAtEntry,
    ),
    PlanResourceSort.nameAscending => a.displayName.compareTo(b.displayName),
  };
  return comparison != 0 ? comparison : a.displayName.compareTo(b.displayName);
}

List<PlanConsumptionGroupPreview> filterPlanConsumptionGroups(
  List<PlanConsumptionGroupPreview> groups, {
  required Set<PlanResourceCategory> categories,
  required bool hideSatisfied,
  required PlanResourceSort sort,
}) => [
  for (final group in groups)
    () {
      final resources = group.resources
          .where(
            (resource) =>
                categories.contains(
                  planResourceCategory(
                    id: resource.id,
                    iconAsset: resource.iconAsset,
                    equipmentTier: resource.equipmentTier,
                  ),
                ) &&
                (!hideSatisfied || resource.isBottleneck),
          )
          .toList(growable: true);
      if (sort != PlanResourceSort.defaultOrder) {
        resources.sort((a, b) => _comparePlanConsumptionResources(a, b, sort));
      }
      return PlanConsumptionGroupPreview(
        id: group.id,
        label: group.label,
        resources: resources,
      );
    }(),
].where((group) => group.resources.isNotEmpty).toList(growable: false);

List<PlanBottleneckDetailPreview> filterPlanBottleneckDetails(
  List<PlanBottleneckDetailPreview> details, {
  required Set<PlanResourceCategory> categories,
  required PlanResourceSort sort,
}) {
  final filtered = <PlanBottleneckDetailPreview>[];
  for (final detail in details) {
    final resources = detail.resources
        .where(
          (resource) => categories.contains(
            planResourceCategory(
              id: resource.id,
              iconAsset: resource.iconAsset,
              equipmentTier: resource.equipmentTier,
            ),
          ),
        )
        .toList(growable: true);
    if (resources.isEmpty) continue;
    if (sort != PlanResourceSort.defaultOrder) {
      resources.sort((a, b) => _comparePlanBottleneckResources(a, b, sort));
    }
    filtered.add(
      PlanBottleneckDetailPreview(
        id: detail.id,
        rankLabel: detail.rankLabel,
        phaseNumber: detail.phaseNumber,
        focusPhaseId: detail.focusPhaseId,
        focusStudentId: detail.focusStudentId,
        focusStep: detail.focusStep,
        focusStage: detail.focusStage,
        focusField: detail.focusField,
        resources: resources,
        delayedStages: detail.delayedStages,
        focusBondRank: detail.focusBondRank,
        focusStepData: detail.focusStepData,
      ),
    );
  }
  if (sort != PlanResourceSort.defaultOrder) {
    filtered.sort(
      (a, b) => _comparePlanBottleneckResources(
        a.resources.first,
        b.resources.first,
        sort,
      ),
    );
  }
  return filtered;
}

String planStudentStageKey(String phaseId, String studentId, int step) =>
    '$phaseId:$studentId:$step';

@immutable
class PlanPhasePreview {
  const PlanPhasePreview({
    required this.id,
    required this.name,
    required this.steps,
  });

  final String id;
  final String name;
  final List<PlanStudentStepPreview> steps;
}

const dummyPlanPhases = <PlanPhasePreview>[
  PlanPhasePreview(
    id: 'phase-1',
    name: '기초 전력 확보',
    steps: [
      PlanStudentStepPreview(
        studentId: 'shiroko',
        displayName: '시로코',
        step: 1,
        target: 'Lv.50 · ★3',
      ),
      PlanStudentStepPreview(
        studentId: 'hoshino',
        displayName: '호시노',
        step: 1,
        target: 'Lv.50 · EX 3',
      ),
      PlanStudentStepPreview(
        studentId: 'serika',
        displayName: '세리카',
        step: 1,
        target: 'Lv.45 · 장비 T4',
      ),
      PlanStudentStepPreview(
        studentId: 'haruka',
        displayName: '하루카',
        step: 1,
        target: 'Lv.50 · 방어 장비 T4',
        bondRank: 35,
      ),
    ],
  ),
  PlanPhasePreview(
    id: 'phase-2',
    name: '핵심 학생 육성',
    steps: [
      PlanStudentStepPreview(
        studentId: 'shiroko',
        displayName: '시로코',
        step: 2,
        target: 'Lv.70 · ★4',
      ),
      PlanStudentStepPreview(
        studentId: 'nonomi',
        displayName: '노노미',
        step: 1,
        target: 'Lv.65 · 스킬 4/4/4',
      ),
      PlanStudentStepPreview(
        studentId: 'hoshino',
        displayName: '호시노',
        step: 2,
        target: 'Lv.70 · EX 5',
      ),
      PlanStudentStepPreview(
        studentId: 'yuuka',
        displayName: '유우카',
        step: 2,
        target: 'Lv.75 · 장비 T6',
        bondRank: 50,
      ),
    ],
  ),
  PlanPhasePreview(
    id: 'phase-3',
    name: '주력 완성',
    steps: [
      PlanStudentStepPreview(
        studentId: 'shiroko',
        displayName: '시로코',
        step: 3,
        target: 'Lv.90 · ★5 · 전무 1',
      ),
      PlanStudentStepPreview(
        studentId: 'serika',
        displayName: '세리카',
        step: 2,
        target: 'Lv.85 · 장비 T8',
      ),
      PlanStudentStepPreview(
        studentId: 'nonomi',
        displayName: '노노미',
        step: 2,
        target: 'Lv.90 · EX 5',
      ),
      PlanStudentStepPreview(
        studentId: 'azusa',
        displayName: '아즈사',
        step: 3,
        target: 'Lv.90 · ★5 · 전무 2',
        bondRank: 100,
      ),
    ],
  ),
  PlanPhasePreview(
    id: 'phase-4',
    name: '후속 보강',
    steps: [
      PlanStudentStepPreview(
        studentId: 'aru',
        displayName: '아루',
        step: 1,
        target: 'Lv.80 · ★5',
      ),
      PlanStudentStepPreview(
        studentId: 'ayane',
        displayName: '아야네',
        step: 1,
        target: 'Lv.70 · 스킬 4/7/7',
      ),
      PlanStudentStepPreview(
        studentId: 'hina',
        displayName: '히나',
        step: 2,
        target: 'Lv.85 · EX 5',
        bondRank: 50,
      ),
      PlanStudentStepPreview(
        studentId: 'ako',
        displayName: '아코',
        step: 3,
        target: 'Lv.90 · 스킬 MAX',
        bondRank: 100,
      ),
    ],
  ),
];

(PlanStudentStepPreview, int) planBottleneckFocusStep(
  PlanBottleneckDetailPreview detail,
) {
  if (detail.focusStepData != null) return (detail.focusStepData!, 1);
  final phase = dummyPlanPhases.firstWhere(
    (candidate) => candidate.id == detail.focusPhaseId,
  );
  final index = phase.steps.indexWhere(
    (step) =>
        step.studentId == detail.focusStudentId &&
        step.step == detail.focusStep,
  );
  if (index < 0) {
    throw StateError(
      'Missing bottleneck focus step: '
      '${detail.focusPhaseId}/${detail.focusStudentId}/${detail.focusStep}',
    );
  }
  return (phase.steps[index], index + 1);
}

Path planSectionPath(Size size, String id) {
  final section = planStudioDocument.elements.firstWhere(
    (element) => element.id == id,
  );
  return buildSectionCanvasElementPath(size, section);
}

double planStudentSelectorSection1RightAtReference(Size size) {
  final section = planStudioDocument.elements.firstWhere(
    (element) => element.id == 'element-1',
  );
  final rect = sectionCanvasElementRect(size, section);
  final points = buildAttachedSectionPolygon(
    rect.size,
    section.spec,
  ).map((point) => point + rect.topLeft).toList(growable: false);
  final topRight = points[1];
  final bottomRight = points[2];
  final referenceY = planStudentSelectorReferenceY(
    planSectionPath(size, 'element-1').getBounds(),
  );
  final progress = ((referenceY - topRight.dy) / (bottomRight.dy - topRight.dy))
      .clamp(0.0, 1.0)
      .toDouble();
  return topRight.dx + (bottomRight.dx - topRight.dx) * progress;
}

(double, double) planResourceHorizontalInterval(Size size, double y) {
  final bounds = planSectionPath(size, 'element-5').getBounds();
  final localY = (y - bounds.top).clamp(0.0, bounds.height).toDouble();
  final depth = diagonalCutDepth(bounds.height);
  return (
    bounds.left + depth * (1 - localY / bounds.height),
    bounds.right - depth * localY / bounds.height,
  );
}

Rect planResourceTabShelfRect(Size size) {
  final bounds = planSectionPath(size, 'element-5').getBounds();
  final top = bounds.top + (bounds.height * 0.04).clamp(2.0, 6.0).toDouble();
  final height = math.min(
    planResourceTabHeight,
    math.max(26, bounds.height * 0.34),
  );
  final centerY = top + height / 2;
  final (left, right) = planResourceHorizontalInterval(size, centerY);
  return Rect.fromLTRB(
    left + 10,
    top,
    math.max(left + 11, right - 10),
    top + height,
  );
}

Path planResourceHeaderPath(Size size) {
  final bounds = planSectionPath(size, 'element-5').getBounds();
  final tabs = planResourceTabShelfRect(size);
  final top = tabs.bottom + 3;
  final bottom = math.min(bounds.bottom - 3, top + planResourceHeaderHeight);
  final (topLeft, topRight) = planResourceHorizontalInterval(size, top);
  final (bottomLeft, bottomRight) = planResourceHorizontalInterval(
    size,
    bottom,
  );
  return buildRoundedSectionPolygon([
    Offset(topLeft + 10, top),
    Offset(topRight - 10, top),
    Offset(bottomRight - 10, bottom),
    Offset(bottomLeft + 10, bottom),
  ], radius: 12);
}

Rect planResourceHeaderContentRect(Size size) {
  final pathBounds = planResourceHeaderPath(size).getBounds();
  final top = pathBounds.top;
  final bottom = pathBounds.bottom;
  final verticalInset = (pathBounds.height * 0.06).clamp(2.0, 6.0);
  final (topLeft, _) = planResourceHorizontalInterval(size, top);
  final (_, bottomRight) = planResourceHorizontalInterval(size, bottom);
  return Rect.fromLTRB(
    topLeft + 30,
    top + verticalInset,
    math.max(topLeft + 31, bottomRight - 30),
    bottom - verticalInset,
  );
}

double _planSection4LeftAtY(Rect bounds, double y) =>
    bounds.right -
    bounds.width * ((y - bounds.top) / bounds.height).clamp(0.0, 1.0);

const planResourceControlGap = 12.0;

List<Path> planResourceControlPaths(Size size) {
  final bounds = planSectionPath(size, 'element-4').getBounds();
  final height = (bounds.height * 0.095).clamp(44.0, 68.0).toDouble();
  final centerGap = height + planResourceControlGap;
  final centerYValues = [
    bounds.top + bounds.height * 0.70 - centerGap,
    bounds.top + bounds.height * 0.70,
    bounds.top + bounds.height * 0.70 + centerGap,
  ];
  return [
    for (final centerY in centerYValues)
      () {
        final top = centerY - height / 2;
        final bottom = centerY + height / 2;
        final left = _planSection4LeftAtY(bounds, top) + 8;
        final right = bounds.right - 8;
        return buildRoundedSectionPolygon([
          Offset(left, top),
          Offset(right, top),
          Offset(right, bottom),
          Offset(_planSection4LeftAtY(bounds, bottom) + 8, bottom),
        ], radius: 7);
      }(),
  ];
}

Path planResourceFilterSectionPath(Size size) =>
    planSectionPath(size, 'element-5');

double planResourceFilterResetSize(Size size) {
  final bounds = planResourceFilterSectionPath(size).getBounds();
  return (bounds.height * 0.22).clamp(24.0, 36.0).toDouble();
}

Rect planResourceFilterGroupRect(Size size) {
  final bounds = planResourceFilterSectionPath(size).getBounds();
  final resetSize = planResourceFilterResetSize(size);
  final top = bounds.top + 8;
  final bottom = math.max(top + 24, bounds.bottom - resetSize - 12);
  final (topLeft, topRight) = planResourceHorizontalInterval(size, top);
  final (bottomLeft, bottomRight) = planResourceHorizontalInterval(
    size,
    bottom,
  );
  return buildRoundedSectionPolygon([
    Offset(topLeft + 10, top),
    Offset(topRight - 10, top),
    Offset(bottomRight - 10, bottom),
    Offset(bottomLeft + 10, bottom),
  ], radius: 9).getBounds();
}

Path planResourceFilterResetPath(Size size) {
  final bounds = planResourceFilterSectionPath(size).getBounds();
  final resetSize = planResourceFilterResetSize(size);
  final bottom = bounds.bottom - 6;
  final centerY = bottom - resetSize / 2;
  final (_, right) = planResourceHorizontalInterval(size, centerY);
  final rect = Rect.fromLTWH(
    right - resetSize - 10,
    bottom - resetSize,
    resetSize,
    resetSize,
  );
  final depth = diagonalCutDepth(rect.height);
  return buildRoundedSectionPolygon([
    Offset(rect.left + depth, rect.top),
    rect.topRight,
    Offset(rect.right - depth, rect.bottom),
    rect.bottomLeft,
  ], radius: 7);
}

Path planPhaseContainerPath(Size size) {
  final sectionPath = planSectionPath(size, 'element-2');
  final sectionBounds = sectionPath.getBounds();
  final rect = Rect.fromLTRB(
    sectionBounds.left + 10,
    sectionBounds.top + 10,
    sectionBounds.right - 10,
    sectionBounds.bottom - 10,
  );
  final depth = diagonalCutDepth(rect.height);
  final raw = buildRoundedSectionPolygon([
    Offset(rect.left + depth, rect.top),
    rect.topRight,
    Offset(rect.right - depth, rect.bottom),
    rect.bottomLeft,
  ], radius: 10);
  return Path.combine(PathOperation.intersect, raw, sectionPath);
}

Path planBottleneckContainerPath(Size size) {
  final sectionPath = planSectionPath(size, 'element-3');
  final sectionBounds = sectionPath.getBounds();
  final width = sectionBounds.width * planBottleneckContainerScale;
  final height = sectionBounds.height * planBottleneckContainerScale;
  final rect = Rect.fromLTWH(
    sectionBounds.center.dx - width / 2,
    sectionBounds.top + sectionBounds.height * planBottleneckContainerTopRatio,
    width,
    height,
  );
  final depth = diagonalCutDepth(rect.height);
  final raw = buildRoundedSectionPolygon([
    Offset(rect.left + depth, rect.top),
    rect.topRight,
    Offset(rect.right - depth, rect.bottom),
    rect.bottomLeft,
  ], radius: 10);
  return Path.combine(PathOperation.intersect, raw, sectionPath);
}

double planPhaseRowHorizontalOffset({
  required double viewportHeight,
  required double rowTop,
  required double rowHeight,
  required double scrollOffset,
}) {
  final bottomViewportY = rowTop + rowHeight - scrollOffset;
  return diagonalRowTranslateOffset(
    viewportHeight: viewportHeight,
    rowBottomInViewport: bottomViewportY,
  );
}

double planPhaseRowWidth({
  required double viewportWidth,
  required double viewportHeight,
  required double rowHeight,
}) {
  const horizontalInset = 8.0;
  const scrollbarReserve = 14.0;
  return math.max(
    116,
    viewportWidth -
        horizontalInset * 2 -
        scrollbarReserve -
        diagonalRowResizeReduction(
          viewportHeight: viewportHeight,
          rowHeight: rowHeight,
        ),
  );
}

class PlanSectionLayout extends StatefulWidget {
  const PlanSectionLayout({
    super.key,
    this.service,
    this.active = true,
    this.initialSeed,
    this.initialPresets = const [],
    this.loadRepositoryPlan = false,
  });

  final AppService? service;
  final bool active;
  final PlanningStudentSeed? initialSeed;
  final List<PlanElementPreset> initialPresets;
  final bool loadRepositoryPlan;

  @override
  State<PlanSectionLayout> createState() => _PlanSectionLayoutState();
}

class _PlanSectionLayoutState extends State<PlanSectionLayout>
    with TickerProviderStateMixin {
  static const _motionDuration = AppMotion.section;
  Set<String> _highlightedStudentIds = const {};
  Set<String> _highlightedStageKeys = const {};
  String? _selectedSection3ResourceKey;
  PlanResourceView _selectedResourceView = PlanResourceView.bottleneck;
  bool _showResourceTypeFilters = false;
  bool _hideSatisfiedResources = false;
  PlanResourceSort _resourceSort = PlanResourceSort.defaultOrder;
  bool _showPhaseEditor = false;
  bool _showElementBuilder = false;
  bool _showPresetManager = false;
  bool _showStudentSelector = false;
  bool _switchingStudentSelector = false;
  bool _showScenarioList = false;

  /// 시나리오 목록에서 연 시나리오(FE5-c1 보기 모드). 목록 위젯이 같은 자리에서 Detail 3섹션을 그린다.
  String? _viewingScenarioId;
  bool _showScenarioComparison = false;
  bool _switchingScenarioWorkspace = false;

  /// 시나리오 목록 "나란히 비교"(FE5-a)로 연 비교 화면이 처음 고를 대상(`active-plan` + 시나리오 id). 비교 화면을
  /// 섹션 1 "시나리오 비교"로 열면 비어 있다.
  List<String> _comparisonInitialIds = const [];

  /// 계획 만들기 흐름(FE4-a1). 시나리오 만들기·시나리오 편집이 이 흐름으로 열린다. 초안은 흐름이 따로
  /// 가지므로 활성 계획 작업 상태를 건드리지 않는다.
  PlanFlowController? _flow;

  /// 흐름 4단계 저장 결과(FE4-e). 흐름을 닫을 때 다시 읽기·시나리오 보기 이동에 쓰고 비운다.
  PlanFlowSaveOutcome? _flowSaveOutcome;
  bool _usingLivePlanElements = false;
  String? _consumedHandoffId;

  /// 넘어온 학생(FE4-g)으로 흐름을 여는 중(흐름 상태를 읽는 동안). 이 동안 계획 홈 섹션을 들이지 않는다.
  bool _handoffPending = false;
  PlanningStudentSeed? _builderSeed;
  List<PlanningStudentSeed> _builderStudentQueue = const [];
  int _builderStudentQueueIndex = 0;
  final Map<String, PlanningStudentSeed> _studentSeedsById = {};
  final Map<String, List<PlanElementStageDraft>> _draftsByStudent = {};
  List<PlanStudentStepPreview> _planElements = const [];
  late List<PlanElementPreset> _presets;
  Set<String> _unassignedPlanElementIds = const {};
  List<PlanPhasePreview> _planPhases = dummyPlanPhases;
  List<PlanBottleneckDetailPreview> _bottleneckDetails =
      dummyPlanBottleneckDetails;
  List<PlanConsumptionGroupPreview> _phaseConsumptions =
      dummyPlanPhaseConsumptions;
  PlanConsumptionGroupPreview _overallConsumption = dummyPlanOverallConsumption;
  RepositoryState? _repositoryState;

  /// 저장된 활성 계획(`plan.get`, FE4-h). [_repositoryState]와 같은 revision이다. 그 revision이 나중 저장(FE4-e)의
  /// `expectedRevision`이다. 서비스가 문서를 주지 않으면 null이다.
  RepositoryPlanState? _repositoryPlan;

  /// 화면이 계산·비교에 쓰는 작업 문서. 처음에는 저장 문서(v2, null = 목표 없음) 그대로이고 편집·편입 뒤에는
  /// 화면 상태에서 다시 만든다([_rebuildDocumentFromPhases]).
  PlanningDocument? _document;
  String? _calculationError;

  /// `plan.get`의 `calculation`이 null이었다(계산할 수 없음). 문서 내용은 그대로 보인다.
  bool _calculationUnavailable = false;
  int _calculationGeneration = 0;
  Set<PlanResourceCategory> _selectedResourceCategories = {
    ...PlanResourceCategory.values,
  };
  late final Map<String, AnimationController> _controllers = {
    for (final id in planSectionMotions.keys)
      id: AnimationController(
        vsync: this,
        duration: _motionDuration,
        reverseDuration: _motionDuration,
      ),
  };
  late final AnimationController _scenarioListController = AnimationController(
    vsync: this,
    duration: _motionDuration,
    reverseDuration: _motionDuration,
  );

  @override
  void initState() {
    super.initState();
    _presets = List.unmodifiable(widget.initialPresets);
    _consumeInitialSeed();
    if (widget.loadRepositoryPlan) _loadRepositoryPlan();
    if (widget.active) _setActive(true);
  }

  /// 활성 계획을 저장 문서(`plan.get`)에서 읽는다(FE4-h). goals v1에서 문서를 다시 만들지 않는다. 빈 문서는 빈
  /// 계획이다. `plan.get`과 `state.get`은 같은 revision으로 맞춘다([loadRepositoryPlanSnapshot]).
  Future<void> _loadRepositoryPlan() async {
    final service = widget.service;
    final RepositoryService? repository = service is RepositoryService
        ? service as RepositoryService
        : null;
    if (repository == null) return;
    try {
      final profiles = await repository.listProfiles();
      final selected = profiles.cast<RepositoryProfile?>().firstWhere(
        (profile) => profile?.selected == true,
        orElse: () => null,
      );
      if (selected == null) {
        if (mounted) {
          setState(() {
            _usingLivePlanElements = true;
            _planElements = const [];
            _planPhases = const [];
            _bottleneckDetails = const [];
            _phaseConsumptions = const [];
            _overallConsumption = const PlanConsumptionGroupPreview(
              id: 'overall',
              label: '전체 계획',
              resources: [],
            );
          });
        }
        return;
      }
      final results = await Future.wait<Object>([
        loadRepositoryPlanSnapshot(repository, selected.id),
        widget.service!.listStudents(),
      ]);
      final snapshot = results[0] as RepositoryPlanSnapshot;
      final catalog = results[1] as List<StudentCatalogEntry>;
      final state = snapshot.state;
      final plan = snapshot.plan;
      final catalogById = {for (final item in catalog) item.studentId: item};
      final currentById = {
        for (final item in state.students) item.studentId: item,
      };
      final seedsById = {
        for (final student in catalog)
          student.studentId: PlanningStudentSeed(
            handoffId: 'repository-plan-${student.studentId}',
            studentId: student.studentId,
            metadata: student.metadata,
            currentValues: currentById[student.studentId]?.values ?? const {},
            owned: currentById.containsKey(student.studentId),
          ),
      };
      // 문서가 없으면(문서를 주지 않는 서비스) 빈 계획이다.
      final document =
          plan?.document ??
          PlanningDocument(
            id: 'active-plan',
            name: '활성 계획',
            kind: PlanningDocumentKind.plan,
            phases: const [],
          );
      // v2 null(목표 없음)은 기존 정수 화면에 넘길 때만 앞 단계 값(첫 단계는 확정 현재값)으로 채운다. 계산에는
      // 저장 문서를 그대로 보낸다.
      final integerTargets = planFlowDocumentIntegerTargets(
        document,
        seedFor: (studentId) =>
            seedsById[studentId] ??
            PlanningStudentSeed(
              handoffId: 'repository-plan-$studentId',
              studentId: studentId,
              metadata: const {},
              currentValues: currentById[studentId]?.values ?? const {},
              owned: currentById.containsKey(studentId),
            ),
      );
      final drafts = <String, List<PlanElementStageDraft>>{};
      final elements = <PlanStudentStepPreview>[];
      final phases = <PlanPhasePreview>[];
      final stepByStudent = <String, int>{};
      for (final phase in document.phases) {
        final steps = <PlanStudentStepPreview>[];
        for (final stage in phase.stages) {
          final targets = integerTargets[stage.id]!;
          final step = (stepByStudent[stage.studentId] ?? 0) + 1;
          stepByStudent[stage.studentId] = step;
          final preview = PlanStudentStepPreview(
            studentId: stage.studentId,
            displayName:
                catalogById[stage.studentId]?.displayName ?? stage.studentId,
            step: step,
            target: stage.name,
            bondRank: targets['bond_rank'],
            stageId: stage.id,
            targetValues: targets,
          );
          steps.add(preview);
          elements.add(preview);
          drafts
              .putIfAbsent(stage.studentId, () => [])
              .add(
                PlanElementStageDraft(
                  id: stage.id,
                  name: stage.name,
                  targets: targets,
                ),
              );
        }
        phases.add(
          PlanPhasePreview(id: phase.id, name: phase.name, steps: steps),
        );
      }
      if (!mounted) return;
      setState(() {
        _repositoryState = state;
        _repositoryPlan = plan;
        _studentSeedsById
          ..clear()
          ..addAll(seedsById);
        _document = document;
        _usingLivePlanElements = true;
        _draftsByStudent
          ..clear()
          ..addAll({
            for (final entry in drafts.entries)
              entry.key: List<PlanElementStageDraft>.unmodifiable(
                entry.value,
              ),
          });
        _planElements = List.unmodifiable(elements);
        _unassignedPlanElementIds = const {};
        _planPhases = List.unmodifiable(phases);
        _bottleneckDetails = const [];
        _phaseConsumptions = const [];
        _overallConsumption = const PlanConsumptionGroupPreview(
          id: 'overall',
          label: '전체 계획',
          resources: [],
        );
        _calculationError = null;
        _calculationUnavailable = plan != null && plan.calculation == null;
      });
      // 계산할 수 없는 문서는 자세한 계산도 부르지 않는다. 문서 내용(섹션 2)은 그대로 보인다.
      if (_calculationUnavailable) return;
      await _calculateDocument();
    } catch (error) {
      if (mounted) setState(() => _calculationError = error.toString());
    }
  }

  Map<String, String> _stageKeysById() {
    final result = <String, String>{};
    for (final phase in _planPhases) {
      for (var index = 0; index < phase.steps.length; index++) {
        final step = phase.steps[index];
        if (step.stageId != null) {
          result[step.stageId!] = planStudentStageKey(
            phase.id,
            step.studentId,
            step.step,
          );
        }
      }
    }
    return result;
  }

  String _resourceIcon(String? itemId, String category) =>
      planningResourceIconAsset(category: category, itemId: itemId) ??
      planPrimaryBottleneckIconAsset;

  PlanConsumptionResourcePreview _consumptionResource(
    Map<String, dynamic> raw,
    Map<String, String> stageKeys,
  ) {
    final required = raw['required'] as int? ?? 0;
    final owned = raw['owned'] as int?;
    final category = raw['category']?.toString() ?? 'unresolved';
    final itemId = raw['item_id']?.toString();
    return PlanConsumptionResourcePreview(
      id: raw['resource_key']?.toString() ?? raw['display_name'].toString(),
      name: raw['display_name']?.toString() ?? itemId ?? '알 수 없는 재화',
      amount: required,
      owned: owned ?? 0,
      inventoryKnown: owned != null,
      iconAsset: _resourceIcon(itemId, category),
      backgroundAsset: itemId == null ? null : planDefaultItemBackgroundAsset,
      affectedStageKeys: {
        for (final id
            in (raw['affected_stage_ids'] as List<dynamic>? ?? const []))
          if (stageKeys[id.toString()] != null) stageKeys[id.toString()]!,
      },
    );
  }

  Future<void> _calculateDocument() async {
    final service = widget.service;
    final PlanningDocumentService? calculator =
        service is PlanningDocumentService
        ? service as PlanningDocumentService
        : null;
    final state = _repositoryState;
    final document = _document;
    if (calculator == null || state == null || document == null) {
      return;
    }
    final generation = ++_calculationGeneration;
    try {
      final projection = await calculator.calculatePlanningDocument(
        currentStudents: [
          for (final student in state.students)
            confirmedStudentPlanningCurrent(student),
        ],
        inventory: state.inventory.toWire(),
        document: document.toWire(),
      );
      if (!mounted || generation != _calculationGeneration) return;
      final stageKeys = _stageKeysById();
      final phaseResults =
          (projection['phase_results'] as List<dynamic>? ?? const []);
      final nextPhaseConsumptions = <PlanConsumptionGroupPreview>[
        for (final raw in phaseResults)
          () {
            final phase = Map<String, dynamic>.from(raw as Map);
            return PlanConsumptionGroupPreview(
              id: phase['phase_id'].toString(),
              label: phase['name'].toString(),
              resources: [
                for (final item
                    in phase['resources'] as List<dynamic>? ?? const [])
                  _consumptionResource(
                    Map<String, dynamic>.from(item as Map),
                    stageKeys,
                  ),
              ],
            );
          }(),
      ];
      final overall = Map<String, dynamic>.from(projection['overall'] as Map);
      final nextOverall = PlanConsumptionGroupPreview(
        id: 'overall',
        label: '전체 계획',
        resources: [
          for (final item in overall['resources'] as List<dynamic>? ?? const [])
            _consumptionResource(
              Map<String, dynamic>.from(item as Map),
              stageKeys,
            ),
        ],
      );
      final stepById = {
        for (final phase in _planPhases)
          for (final step in phase.steps)
            if (step.stageId != null) step.stageId!: (phase, step),
      };
      final nextBottlenecks = <PlanBottleneckDetailPreview>[];
      for (final raw
          in projection['bottlenecks'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(raw as Map);
        final focused = stepById[item['stage_id']?.toString()];
        if (focused == null) continue;
        final affectedIds =
            (item['affected_stage_ids'] as List<dynamic>? ?? const [])
                .map((id) => id.toString())
                .toList(growable: false);
        final affectedKeys = {
          for (final id in affectedIds)
            if (stageKeys[id] != null) stageKeys[id]!,
        };
        final category = item['category']?.toString() ?? 'unresolved';
        final itemId = item['item_id']?.toString();
        nextBottlenecks.add(
          PlanBottleneckDetailPreview(
            id: 'bottleneck-${nextBottlenecks.length + 1}',
            rankLabel: '병목 ${nextBottlenecks.length + 1}',
            phaseNumber: item['phase_number'] as int? ?? 1,
            focusPhaseId: focused.$1.id,
            focusStudentId: focused.$2.studentId,
            focusStep: focused.$2.step,
            focusStage: focused.$2.target,
            focusField: PlanBottleneckFocusField.title,
            focusBondRank: focused.$2.bondRank,
            focusStepData: focused.$2,
            resources: [
              PlanBottleneckResourcePreview(
                id: item['resource_key'].toString(),
                name: item['display_name'].toString(),
                remainingAtEntry: item['remaining_at_entry'] as int? ?? 0,
                requiredAtEntry: item['required_at_entry'] as int? ?? 0,
                shortage: item['shortage'] as int? ?? 0,
                iconAsset: _resourceIcon(itemId, category),
                backgroundAsset: itemId == null
                    ? null
                    : planDefaultItemBackgroundAsset,
                affectedStageKeys: affectedKeys,
              ),
            ],
            delayedStages: [
              for (final id in affectedIds)
                if (stepById[id] case final affected?)
                  PlanDelayedStagePreview(
                    phaseId: affected.$1.id,
                    studentId: affected.$2.studentId,
                    step: affected.$2.step,
                    label: '${affected.$2.displayName} · ${affected.$2.target}',
                  ),
            ],
          ),
        );
      }
      setState(() {
        _phaseConsumptions = List.unmodifiable(nextPhaseConsumptions);
        _overallConsumption = nextOverall;
        _bottleneckDetails = List.unmodifiable(nextBottlenecks);
        _calculationError = null;
        _calculationUnavailable = false;
      });
    } catch (error) {
      if (mounted && generation == _calculationGeneration) {
        setState(() => _calculationError = error.toString());
      }
    }
  }

  void _rebuildDocumentFromPhases() {
    if (_repositoryState == null) return;
    _document = PlanningDocument(
      id: 'active-plan',
      name: _document?.name ?? '계획',
      kind: PlanningDocumentKind.plan,
      phases: [
        for (final phase in _planPhases)
          PlanningDocumentPhase(
            id: phase.id,
            name: phase.name,
            stages: [
              for (final step in phase.steps)
                if (step.stageId != null)
                  PlanningDocumentStage(
                    id: step.stageId!,
                    studentId: step.studentId,
                    name: step.target,
                    targets: step.targetValues,
                  ),
            ],
          ),
      ],
    );
    _calculateDocument();
  }

  @override
  void didUpdateWidget(PlanSectionLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _setActive(widget.active);
    if (oldWidget.initialSeed?.handoffId != widget.initialSeed?.handoffId) {
      _consumeInitialSeed();
    }
  }

  /// 계획 탭으로 넘어온 학생(성장 계산기 "이 목표로 계획에 추가", FE4-g, FD-171 (a)).
  ///
  /// 계획 만들기 흐름을 2단계(목표 정하기)로 열고 그 학생 단계를 넘긴 목표로 채운다
  /// ([PlanFlowController.receiveHandoff]). 진행 중 흐름이 있으면 그 초안에 덧붙인다. 흐름을 열 수 없는 서비스(계정
  /// 상태·시나리오 저장소 없음)면 예전처럼 요소 편집기로 연다(목표는 싣지 않는다).
  void _consumeInitialSeed() {
    final seed = widget.initialSeed;
    if (seed == null || seed.handoffId == _consumedHandoffId) return;
    _consumedHandoffId = seed.handoffId;
    final flow = _flow;
    if (flow != null) {
      // didUpdateWidget(빌드 중)에서 흐름 리스너를 깨우지 않게 다음 프레임에 넣는다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_flow, flow)) return;
        _notifyHandoff(flow, flow.receiveHandoff(seed), seed.studentId);
      });
      return;
    }
    // 흐름이 들어올 자리를 비운다. 넘길 때는 계획 탭이 보이지 않으므로 모션 없이 내린다.
    _handoffPending = true;
    _showElementBuilder = false;
    _showPhaseEditor = false;
    _showPresetManager = false;
    _showStudentSelector = false;
    _showScenarioList = false;
    _viewingScenarioId = null;
    _showScenarioComparison = false;
    _scenarioListController.value = 0;
    for (final controller in _controllers.values) {
      controller.value = 0;
    }
    _openHandoffFlow(seed);
  }

  /// [seed]로 새 흐름을 연다(FE4-g). 상태를 읽는 사이 흐름이 생겼으면 그 초안에 넣는다.
  Future<void> _openHandoffFlow(PlanningStudentSeed seed) async {
    PlanFlowContext? flowContext;
    if (widget.service is PlanningScenarioRepositoryService) {
      try {
        flowContext = await _flowContext();
      } on Object {
        flowContext = null;
      }
    }
    // 그 사이 다른 학생이 넘어왔으면 그쪽이 연다(대기 표시도 그쪽이 푼다).
    if (!mounted || _consumedHandoffId != seed.handoffId) return;
    var opened = false;
    try {
      final existing = _flow;
      if (existing != null) {
        _notifyHandoff(existing, existing.receiveHandoff(seed), seed.studentId);
        opened = true;
        return;
      }
      if (flowContext == null) {
        setState(() {
          _builderSeed = seed;
          _studentSeedsById[seed.studentId] = seed;
          _builderStudentQueue = [seed];
          _builderStudentQueueIndex = 0;
          _showElementBuilder = true;
        });
        return;
      }
      final flow = PlanFlowController(
        purpose: PlanFlowPurpose.newScenario,
        context: flowContext,
        service: widget.service,
      );
      final result = flow.receiveHandoff(seed);
      setState(() => _flow = flow);
      opened = true;
      _notifyHandoff(flow, result, seed.studentId);
    } finally {
      // 흐름을 못 열었으면(요소 편집기 대체 · 오류) 계획 홈 섹션을 다시 들인다.
      if (mounted) {
        setState(() => _handoffPending = false);
        if (!opened) _setActive(widget.active);
      }
    }
  }

  /// 넘긴 목표를 어떻게 넣었는지 알린다(새 학생 1단계는 화면으로 보이므로 알리지 않는다).
  void _notifyHandoff(
    PlanFlowController flow,
    PlanFlowHandoffResult result,
    String studentId,
  ) {
    final name = flow.context.displayName(studentId);
    final message = switch (result.kind) {
      PlanFlowHandoffKind.added || PlanFlowHandoffKind.ignored => null,
      PlanFlowHandoffKind.appendedToDraft =>
        '만들던 초안에 이어 $name ${result.step}단계로 계산기 목표를 넣었습니다.',
      PlanFlowHandoffKind.appendedAfterActive =>
        '$name 학생은 활성 계획에 있어 활성 계획 마지막 단계에 이어지는 단계로 계산기 목표를 넣었습니다.',
      PlanFlowHandoffKind.nothingNew =>
        '계산기 목표가 이미 $name 학생의 마지막 단계에 들어 있어 새 단계를 만들지 않았습니다.',
      PlanFlowHandoffKind.noTargets =>
        '계산기에서 올린 목표가 없어 $name 학생을 목표 없이 더했습니다.',
    };
    if (message == null || !mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _setActive(bool active) {
    // 흐름 화면은 자기 섹션 모션을 `active`로 튼다. 넘어온 학생으로 흐름을 여는 중에도 홈 섹션을 들이지 않는다.
    if (_flow != null || _handoffPending) return;
    if (_showScenarioList || _showScenarioComparison) {
      for (final entry in _controllers.entries) {
        // 시나리오 목록(FE5-a)은 자기 S1 메뉴가 있어 계획 홈 섹션 1도 내린다. 비교 화면은 섹션 1을 둔다.
        if (entry.key == 'element-1' && !_showScenarioList) {
          active ? entry.value.forward(from: 0) : entry.value.reverse(from: 1);
        } else {
          entry.value.value = 0;
        }
      }
      active
          ? _scenarioListController.forward(from: 0)
          : _scenarioListController.reverse(from: 1);
      return;
    }
    if (_showStudentSelector) {
      for (final entry in _controllers.entries) {
        if (entry.key == 'element-1') {
          if (active) {
            entry.value.forward(from: 0);
          } else {
            entry.value.reverse(from: 1);
          }
        } else {
          entry.value.value = 0;
        }
      }
      return;
    }
    for (final controller in _controllers.values) {
      if (active) {
        controller.forward(from: 0);
      } else {
        controller.reverse(from: 1);
      }
    }
  }

  void _toggleHighlightedStudents(Set<String> studentIds) {
    final sameSelection =
        _highlightedStudentIds.length == studentIds.length &&
        _highlightedStudentIds.every(studentIds.contains);
    setState(() {
      _highlightedStudentIds = sameSelection ? const {} : studentIds;
      _highlightedStageKeys = const {};
      _selectedSection3ResourceKey = null;
    });
  }

  void _toggleHighlightedStages(Set<String> stageKeys) {
    final sameSelection =
        _highlightedStageKeys.length == stageKeys.length &&
        _highlightedStageKeys.every(stageKeys.contains);
    setState(() {
      _highlightedStudentIds = const {};
      _highlightedStageKeys = sameSelection ? const {} : stageKeys;
      _selectedSection3ResourceKey = null;
    });
  }

  void _toggleSection3Resource(String resourceKey, Set<String> stageKeys) {
    final sameSelection = _selectedSection3ResourceKey == resourceKey;
    setState(() {
      _highlightedStudentIds = const {};
      _highlightedStageKeys = sameSelection ? const {} : stageKeys;
      _selectedSection3ResourceKey = sameSelection ? null : resourceKey;
    });
  }

  void _selectResourceView(PlanResourceView view) {
    if (_selectedResourceView == view) return;
    setState(() {
      _selectedResourceView = view;
      _highlightedStudentIds = const {};
      _highlightedStageKeys = const {};
      _selectedSection3ResourceKey = null;
    });
  }

  void _toggleResourceTypeFilters() {
    setState(() => _showResourceTypeFilters = !_showResourceTypeFilters);
  }

  void _toggleHideSatisfiedResources() {
    setState(() {
      _hideSatisfiedResources = !_hideSatisfiedResources;
      _highlightedStudentIds = const {};
      _highlightedStageKeys = const {};
      _selectedSection3ResourceKey = null;
    });
  }

  void _selectResourceSort(PlanResourceSort sort) {
    if (_resourceSort == sort) return;
    setState(() {
      _resourceSort = sort;
      _highlightedStudentIds = const {};
      _highlightedStageKeys = const {};
      _selectedSection3ResourceKey = null;
    });
  }

  void _toggleResourceCategory(PlanResourceCategory category) {
    setState(() {
      final next = {..._selectedResourceCategories};
      next.contains(category) ? next.remove(category) : next.add(category);
      _selectedResourceCategories = next;
      _highlightedStudentIds = const {};
      _highlightedStageKeys = const {};
      _selectedSection3ResourceKey = null;
    });
  }

  void _toggleAllResourceCategories() {
    setState(() {
      _selectedResourceCategories =
          _selectedResourceCategories.length ==
              PlanResourceCategory.values.length
          ? <PlanResourceCategory>{}
          : {...PlanResourceCategory.values};
      _highlightedStudentIds = const {};
      _highlightedStageKeys = const {};
      _selectedSection3ResourceKey = null;
    });
  }

  void _resetResourceCategories() {
    setState(() {
      _selectedResourceCategories = {...PlanResourceCategory.values};
      _highlightedStudentIds = const {};
      _highlightedStageKeys = const {};
      _selectedSection3ResourceKey = null;
    });
  }

  /// 계정 상태와 저장된 활성 계획(같은 revision). 계획 화면이 이미 읽었으면 그 snapshot을 쓰고, 아니면
  /// [_loadRepositoryPlan]과 같은 경로([loadRepositoryPlanSnapshot])로 읽는다. 작업 문서([_document])는 바꾸지
  /// 않는다.
  ///
  /// [refresh]면 이미 읽었어도 다시 읽는다(활성 계획을 흐름 초안으로 열 때, FE4-f2).
  Future<RepositoryState?> _ensureRepositoryContext({
    bool refresh = false,
  }) async {
    if (!refresh) {
      if (_repositoryState case final state?) return state;
    }
    final service = widget.service;
    if (service is! RepositoryService) return null;
    final repository = service as RepositoryService;
    final profiles = await repository.listProfiles();
    final selected = profiles.cast<RepositoryProfile?>().firstWhere(
      (profile) => profile?.selected == true,
      orElse: () => null,
    );
    if (selected == null) return null;
    final snapshot = await loadRepositoryPlanSnapshot(repository, selected.id);
    if (mounted) {
      setState(() {
        _repositoryState = snapshot.state;
        _repositoryPlan = snapshot.plan;
      });
    }
    return snapshot.state;
  }

  Future<void> _openScenarioList() async {
    await _openScenarioWorkspace(comparison: false);
  }

  Future<void> _openScenarioComparison() async {
    await _openScenarioWorkspace(comparison: true);
  }

  Future<void> _openScenarioWorkspace({required bool comparison}) async {
    if (_flow != null ||
        _showScenarioList ||
        _showScenarioComparison ||
        _switchingScenarioWorkspace ||
        _switchingStudentSelector ||
        widget.service is! PlanningScenarioRepositoryService ||
        (comparison && widget.service is! PlanningScenarioComparisonService)) {
      return;
    }
    final leavingStudentSelector = _showStudentSelector;
    setState(() {
      _switchingScenarioWorkspace = true;
      if (leavingStudentSelector) _switchingStudentSelector = true;
    });
    try {
      if (leavingStudentSelector) {
        await Future<void>.delayed(planStudentSelectorMotionDuration);
        if (!mounted) return;
        setState(() {
          _showStudentSelector = false;
          _switchingStudentSelector = false;
        });
      }
      final state = await _ensureRepositoryContext();
      if (state == null || !mounted) return;
      // 시나리오 목록(FE5-a)은 자기 S1 메뉴가 있어 섹션 1도 내린다. 비교 화면은 섹션 1을 둔다.
      await Future.wait([
        for (final entry in _controllers.entries)
          if (entry.key != 'element-1' || !comparison) entry.value.reverse(),
      ]);
      // 그 사이 계산기에서 학생이 넘어와 흐름이 열리면(FE4-g) 목록을 열지 않는다.
      if (!mounted || _flow != null || _handoffPending) return;
      setState(() {
        _showScenarioList = !comparison;
        _viewingScenarioId = null;
        _showScenarioComparison = comparison;
        _comparisonInitialIds = const [];
      });
      await _scenarioListController.forward(from: 0);
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) {
        setState(() {
          _switchingScenarioWorkspace = false;
          _switchingStudentSelector = false;
        });
      }
    }
  }

  Future<void> _closeScenarioList() async {
    if ((!_showScenarioList && !_showScenarioComparison) ||
        _switchingScenarioWorkspace) {
      return;
    }
    final closingList = _showScenarioList;
    setState(() => _switchingScenarioWorkspace = true);
    try {
      await _scenarioListController.reverse(from: 1);
      if (!mounted) return;
      setState(() {
        _showScenarioList = false;
        _viewingScenarioId = null;
        _showScenarioComparison = false;
        _comparisonInitialIds = const [];
      });
      // 목록을 닫으면 섹션 1도 다시 들어온다(목록이 내렸다). 비교 화면은 섹션 1을 그대로 둔다.
      await Future.wait([
        for (final entry in _controllers.entries)
          if (entry.key != 'element-1' || closingList)
            entry.value.forward(from: 0),
      ]);
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 시나리오 목록 S1 "새 시나리오"(FE5-a): 목록을 내리고 계획 만들기 1단계를 연다. 계획 홈 섹션은 이미 내려가 있고,
  /// 흐름을 닫으면([_closeFlow]) 다시 들어온다.
  Future<void> _createScenarioFromList() async {
    if (!_showScenarioList || _switchingScenarioWorkspace || _flow != null) {
      return;
    }
    setState(() => _switchingScenarioWorkspace = true);
    try {
      // final로 받아야 아래 setState 클로저 안에서도 null이 아님이 유지된다.
      final flowContext = await _flowContextOrNull();
      if (flowContext == null || !mounted || _flow != null) return;
      // 퇴장 Future를 기다리지 않는다(도중에 멈추면 끝나지 않는다). 모션 시간만 기다린다.
      _scenarioListController.reverse(from: _scenarioListController.value);
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || !_showScenarioList) return;
      setState(() {
        _showScenarioList = false;
        _viewingScenarioId = null;
        _flow = PlanFlowController(
          purpose: PlanFlowPurpose.newScenario,
          context: flowContext,
          service: widget.service,
        );
      });
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 시나리오 목록 S1 "프리셋 관리"(FE5-a): 목록을 내리고 프리셋 관리를 연다. 닫으면 계획 홈으로 돌아간다.
  Future<void> _openPresetManagerFromList() async {
    if (!_showScenarioList || _switchingScenarioWorkspace) return;
    setState(() => _switchingScenarioWorkspace = true);
    try {
      _scenarioListController.reverse(from: _scenarioListController.value);
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || !_showScenarioList) return;
      setState(() {
        _showScenarioList = false;
        _viewingScenarioId = null;
        _showPresetManager = true;
      });
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 시나리오 목록 "나란히 비교"(FE5-a, FD-084·FD-085): 활성 계획(A)과 담은 시나리오 하나(B)로 기존 A↔B 비교
  /// 화면을 연다. 셋 이상(4열 비교)은 FE5-e에서 연다.
  Future<void> _compareFromList(List<String> scenarioIds) async {
    if (!_showScenarioList ||
        _switchingScenarioWorkspace ||
        scenarioIds.length != 1 ||
        _document == null) {
      return;
    }
    setState(() => _switchingScenarioWorkspace = true);
    try {
      _scenarioListController.reverse(from: _scenarioListController.value);
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || _handoffPending || !_showScenarioList) {
        return;
      }
      setState(() {
        _showScenarioList = false;
        _viewingScenarioId = null;
        _showScenarioComparison = true;
        _comparisonInitialIds = List.unmodifiable([
          'active-plan',
          scenarioIds.single,
        ]);
      });
      _controllers['element-1']!.forward(from: 0);
      _scenarioListController.forward(from: 0);
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 시나리오 목록 "열기"(FE5-c1): 같은 목록 위젯을 그 시나리오의 읽기 전용 보기 모드로 바꾼다. 3섹션이 나가고
  /// 들어오는 모션만 다시 튼다(미리보기 캐시를 가진 목록 위젯은 그대로 남는다).
  Future<void> _openScenarioView(String scenarioId) =>
      _switchScenarioView(scenarioId);

  /// 보기 모드 S1 "시나리오 목록": 목록으로 돌아간다.
  Future<void> _closeScenarioView() => _switchScenarioView(null);

  Future<void> _switchScenarioView(String? scenarioId) async {
    if (!_showScenarioList ||
        _switchingScenarioWorkspace ||
        _flow != null ||
        _viewingScenarioId == scenarioId) {
      return;
    }
    setState(() => _switchingScenarioWorkspace = true);
    try {
      // 퇴장 Future를 기다리지 않는다(도중에 멈추면 끝나지 않는다). 모션 시간만 기다린다.
      _scenarioListController.reverse(from: _scenarioListController.value);
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || _handoffPending || !_showScenarioList) {
        return;
      }
      setState(() => _viewingScenarioId = scenarioId);
      _scenarioListController.forward(from: 0);
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 보기 모드 S1 "페이즈 편집": 시나리오 비교 "편집"과 같은 길(계획 만들기 3단계, FE4-f1 복원)로 연다.
  Future<void> _editScenarioFromView(
    PlanningScenarioRecord scenario,
    int collectionRevision,
  ) => _openFlowFromView(
    scenario,
    collectionRevision,
    initialStep: PlanFlowStep.order,
  );

  /// 계획에 적용…(FD-088): 시나리오를 초안으로 계획 만들기 4단계(FE4-e 저장)를 [target] 위치로 연다. 저장 · 비교 ·
  /// revision 확인 · 다시 보내기는 FE4-e 그대로다(이걸로 바꾸기는 기존 활성 계획을 시나리오로 옮겨 둔다, FD-067).
  /// 시나리오 단계 순서에 고칠 점이 있어 4단계에 들어갈 수 없으면 3단계로 연다.
  Future<void> _applyScenarioFromView(
    PlanningScenarioRecord scenario,
    int collectionRevision,
    PlanFlowSaveTarget target,
  ) => _openFlowFromView(
    scenario,
    collectionRevision,
    initialStep: PlanFlowStep.save,
    saveTarget: target,
  );

  Future<void> _openFlowFromView(
    PlanningScenarioRecord scenario,
    int collectionRevision, {
    required PlanFlowStep initialStep,
    PlanFlowSaveTarget? saveTarget,
  }) async {
    if (!_showScenarioList ||
        _switchingScenarioWorkspace ||
        _flow != null ||
        _handoffPending) {
      return;
    }
    setState(() => _switchingScenarioWorkspace = true);
    try {
      // final로 받아야 아래 setState 클로저 안에서도 null이 아님이 유지된다.
      final flowContext = await _flowContextOrNull();
      if (flowContext == null || !mounted || _flow != null) return;
      _scenarioListController.reverse(from: _scenarioListController.value);
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null || _handoffPending || !_showScenarioList) {
        return;
      }
      PlanFlowController open(PlanFlowStep step) => PlanFlowController(
        purpose: PlanFlowPurpose.editScenario,
        context: flowContext,
        service: widget.service,
        initialDraft: PlanFlowDocumentBoundary.fromDocument(
          scenario.document,
          seedFor: flowContext.seedFor,
          authoring: scenario.authoring,
        ),
        initialStep: step,
        initialSaveTarget: saveTarget,
        scenario: scenario,
        scenarioCollectionRevision: collectionRevision,
      );
      var flow = open(initialStep);
      if (initialStep == PlanFlowStep.save && !flow.orderReady) {
        flow.dispose();
        flow = open(PlanFlowStep.order);
      }
      final opened = flow;
      setState(() {
        _showScenarioList = false;
        _viewingScenarioId = null;
        _flow = opened;
      });
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// [_flowContext]를 읽다 실패하면 null(목록 S1 "새 시나리오"가 예외를 버튼 밖으로 내보내지 않게 한다).
  Future<PlanFlowContext?> _flowContextOrNull() async {
    try {
      return await _flowContext();
    } on Object {
      return null;
    }
  }

  /// 흐름을 열 때 한 번 읽는 프로필 상태(확정 현재값·재고·카탈로그)와 저장된 활성 계획 문서(FE4-h).
  Future<PlanFlowContext?> _flowContext({bool refresh = false}) async {
    final service = widget.service;
    if (service == null) return null;
    final state = await _ensureRepositoryContext(refresh: refresh);
    if (state == null) return null;
    final catalog = await service.listStudents();
    return PlanFlowContext(
      repositoryState: state,
      catalog: {for (final entry in catalog) entry.studentId: entry},
      activePlan: _repositoryPlan?.document,
    );
  }

  /// 계획 탭 S1 "시나리오 생성" → 계획 만들기 1단계(FD-081 "새 시나리오").
  Future<void> _openScenarioCreation() async {
    if (_flow != null ||
        _showScenarioList ||
        _showScenarioComparison ||
        _switchingScenarioWorkspace ||
        widget.service is! PlanningScenarioRepositoryService) {
      return;
    }
    final flowContext = await _flowContext();
    if (flowContext == null || !mounted || _flow != null) return;
    // 퇴장 Future를 기다리지 않는다(도중에 멈추면 끝나지 않는다). 모션 시간만 기다린다.
    for (final controller in _controllers.values) {
      controller.reverse();
    }
    await Future<void>.delayed(_motionDuration);
    if (!mounted || _flow != null) return;
    setState(() {
      _flow = PlanFlowController(
        purpose: PlanFlowPurpose.newScenario,
        context: flowContext,
        service: widget.service,
      );
    });
  }

  /// 계획 탭 "단계 순서 바꾸기"(FE4-f2): 저장된 활성 계획을 다시 읽어(`plan.get` document + authoring, 없으면 DTO
  /// 기본값) 흐름 초안으로 연다. 단계가 있으면 3단계(단계 순서), 없으면 1단계다. 4단계 저장은 "이걸로 바꾸기"가
  /// 기본이고 expected revision은 이때 읽은 revision이다.
  Future<void> _openActivePlanFlow() async {
    if (_flow != null ||
        _showScenarioList ||
        _showScenarioComparison ||
        _switchingScenarioWorkspace ||
        widget.service is! RepositoryPlanService) {
      return;
    }
    final flowContext = await _flowContext(refresh: true);
    final plan = _repositoryPlan;
    if (flowContext == null || plan == null || !mounted || _flow != null) {
      return;
    }
    final draft = PlanFlowDocumentBoundary.fromDocument(
      plan.document,
      seedFor: flowContext.seedFor,
      authoring: plan.authoring,
    );
    for (final controller in _controllers.values) {
      controller.reverse();
    }
    await Future<void>.delayed(_motionDuration);
    if (!mounted || _flow != null) return;
    setState(() {
      _flow = PlanFlowController(
        purpose: PlanFlowPurpose.editActivePlan,
        context: flowContext,
        service: widget.service,
        initialDraft: draft,
        initialStep: draft.hasStages
            ? PlanFlowStep.order
            : PlanFlowStep.students,
        activePlanRevision: plan.revision,
      );
    });
  }

  /// 흐름을 닫고 계획 홈 섹션을 다시 들인다.
  ///
  /// 4단계에서 활성 계획을 바꿨으면(FE4-e) 돌려받은 revision으로 snapshot을 덮지 않고 계정 상태·활성 계획을
  /// 다시 읽는다(FB-1c 연결 메모). 계획 화면이 저장 문서를 읽는 중이면 화면도 다시 읽는다. 시나리오 목록은 열 때
  /// 새로 읽는다. "시나리오 보기로 이동"을 켰으면 시나리오 목록을 연다.
  void _closeFlow(bool saved) {
    if (_flow == null) return;
    final outcome = saved ? _flowSaveOutcome : null;
    _flowSaveOutcome = null;
    final changedActivePlan = outcome?.changedActivePlan ?? false;
    setState(() {
      _discardFlow();
      if (changedActivePlan) {
        _repositoryState = null;
        _repositoryPlan = null;
      }
    });
    for (final controller in _controllers.values) {
      controller.forward(from: controller.value);
    }
    if (changedActivePlan) {
      if (widget.loadRepositoryPlan) {
        _loadRepositoryPlan();
      } else {
        _ensureRepositoryContext();
      }
    }
    if (outcome?.openScenarioList ?? false) _openScenarioList();
  }

  /// 흐름 컨트롤러를 버린다(화면이 내려간 다음 프레임에 dispose).
  void _discardFlow() {
    final flow = _flow;
    if (flow == null) return;
    _flow = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => flow.dispose());
  }

  /// 시나리오 비교 "편집" → 계획 만들기 3단계(단계 순서)로 그 시나리오를 연다.
  Future<void> _editScenarioFromComparison(
    PlanningScenarioRecord scenario,
    int collectionRevision,
  ) async {
    if (_switchingScenarioWorkspace || _flow != null) return;
    setState(() => _switchingScenarioWorkspace = true);
    try {
      final flowContext = await _flowContext();
      if (flowContext == null || !mounted) return;
      _scenarioListController.reverse(from: _scenarioListController.value);
      for (final controller in _controllers.values) {
        controller.reverse();
      }
      await Future<void>.delayed(_motionDuration);
      if (!mounted || _flow != null) return;
      setState(() {
        _showScenarioComparison = false;
        _flow = PlanFlowController(
          purpose: PlanFlowPurpose.editScenario,
          context: flowContext,
          service: widget.service,
          // FE4-f1: 시나리오 document + authoring(없으면 DTO 기본값)으로 나중에 칸·직접 선행·학생 순서까지 복원한다.
          initialDraft: PlanFlowDocumentBoundary.fromDocument(
            scenario.document,
            seedFor: flowContext.seedFor,
            authoring: scenario.authoring,
          ),
          initialStep: PlanFlowStep.order,
          scenario: scenario,
          scenarioCollectionRevision: collectionRevision,
        );
      });
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  /// 시나리오 비교 "편입"(FE4-f2): 저장된 활성 계획(`plan.get` document + authoring) 뒤에 시나리오(document +
  /// authoring)를 붙여 `plan.save`로 저장한다([planFlowIncorporateScenario]).
  ///
  /// - 문서는 v2 nullable 원본 그대로, authoring은 전체(활성 + 편입, stage ID 재발급 remap)를 보낸다. 계획 화면 작업
  ///   문서(정수 보기)에서 다시 만들지 않는다.
  /// - 활성 목표보다 낮은 시나리오 단계는 빼고, 그 단계에 이은 직접 선행은 명시해 빼고 수를 알린다.
  /// - 저장하면 활성 계획을 다시 읽는다(편집기에서 저장하지 않은 작업 문서 변경은 다시 읽은 저장 계획으로 바뀐다).
  ///   그 사이 활성 계획이 바뀌었으면(`revision_conflict`) 편입하지 않고 다시 읽어 알린다.
  Future<void> _incorporateScenario(PlanningScenarioRecord scenario) async {
    final plan = _repositoryPlan;
    final service = widget.service;
    if (plan == null || service is! RepositoryPlanService) return;
    final repository = service as RepositoryPlanService;
    void notify(String message) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }

    final currentById = {
      for (final student
          in _repositoryState?.students ?? const <ConfirmedStudentState>[])
        student.studentId: student.values,
    };
    PlanningStudentSeed seedFor(String studentId) =>
        _studentSeedsById[studentId] ??
        PlanningStudentSeed(
          handoffId: 'scenario-import-$studentId',
          studentId: studentId,
          metadata: const {},
          currentValues: currentById[studentId] ?? const {},
          owned: currentById.containsKey(studentId),
        );
    final incorporation = planFlowIncorporateScenario(
      active: plan.document,
      activeAuthoring: plan.authoring,
      scenarioDocument: scenario.document,
      scenarioAuthoring: scenario.authoring,
      scenarioName: scenario.name,
      seedFor: seedFor,
    );
    if (incorporation.addedStageCount == 0) {
      notify('현재 계획 뒤에 이어질 수 있는 성장 단계가 없습니다.');
      return;
    }
    final merged = incorporation.merged;
    final document = merged.document;
    final authoring = merged.authoring;
    if (document == null || authoring == null) {
      notify(
        '활성 계획의 나중에 칸·선행 조건과 맞출 수 없어 "${scenario.name}" 시나리오를 편입하지 않았습니다'
        '(${planFlowAuthoringReasonText(merged.authoringReason ?? '')}).',
      );
      return;
    }
    try {
      await repository.saveRepositoryPlan(
        profileId: plan.profileId,
        document: document,
        authoring: authoring,
        expectedRevision: plan.revision,
        idempotencyKey:
            'plan-incorporate-${scenario.id}-${DateTime.now().microsecondsSinceEpoch}',
      );
    } on Object catch (error) {
      if (!mounted) return;
      final code = planFlowSaveErrorCode(error);
      if (code == 'revision_conflict') {
        _reloadRepositoryPlan();
        notify('편입하는 사이에 활성 계획이 바뀌어 편입하지 않았습니다. 최신 상태를 다시 읽었습니다. 다시 편입해 주십시오.');
      } else {
        notify('"${scenario.name}" 시나리오를 편입하지 못했습니다($code).');
      }
      return;
    }
    if (!mounted) return;
    // 비교 화면을 먼저 닫고(닫는 모션이 계정 상태를 쓴다) 저장된 활성 계획을 다시 읽는다.
    await _closeScenarioList();
    if (!mounted) return;
    _reloadRepositoryPlan();
    final skipped = incorporation.skippedStageCount;
    final dropped = incorporation.droppedPrerequisites.length;
    notify(
      skipped == 0
          ? '"${scenario.name}" 시나리오를 현재 계획에 편입했습니다.'
          : '"${scenario.name}" 시나리오를 편입했습니다. 퇴행하는 $skipped개 단계는 제외했습니다.'
                '${dropped == 0 ? '' : ' 그 단계에 이은 직접 선행 $dropped개도 뺐습니다.'}',
    );
  }

  /// 저장된 활성 계획과 계정 상태를 다시 읽는다(편입·흐름 저장 뒤).
  void _reloadRepositoryPlan() {
    setState(() {
      _repositoryState = null;
      _repositoryPlan = null;
    });
    if (widget.loadRepositoryPlan) {
      _loadRepositoryPlan();
    } else {
      _ensureRepositoryContext();
    }
  }

  Future<void> _openPhaseEditor() async {
    if (_showPhaseEditor) return;
    if (!_showElementBuilder) {
      await Future.wait([
        for (final controller in _controllers.values) controller.reverse(),
      ]);
    }
    if (!mounted) return;
    setState(() => _showPhaseEditor = true);
  }

  Future<void> _openPresetManager() async {
    if (_showPresetManager || _showPhaseEditor || _showElementBuilder) return;
    await Future.wait([
      for (final controller in _controllers.values) controller.reverse(),
    ]);
    if (!mounted) return;
    setState(() => _showPresetManager = true);
  }

  void _closePresetManager() {
    if (!_showPresetManager) return;
    setState(() => _showPresetManager = false);
    for (final controller in _controllers.values) {
      controller.forward(from: 0);
    }
  }

  void _replacePresets(List<PlanElementPreset> presets) {
    setState(() => _presets = List.unmodifiable(presets));
  }

  Future<void> _openStudentSelector() async {
    if (_showStudentSelector ||
        _switchingStudentSelector ||
        widget.service == null) {
      return;
    }
    setState(() => _switchingStudentSelector = true);
    try {
      await Future.wait([
        for (final entry in _controllers.entries)
          if (entry.key != 'element-1') entry.value.reverse(),
      ]);
      if (!mounted) return;
      setState(() => _showStudentSelector = true);
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) setState(() => _switchingStudentSelector = false);
    }
  }

  Future<void> _closeStudentSelector() async {
    if (!_showStudentSelector || _switchingStudentSelector) return;
    setState(() => _switchingStudentSelector = true);
    try {
      await Future<void>.delayed(planStudentSelectorMotionDuration);
      if (!mounted) return;
      setState(() => _showStudentSelector = false);
      await Future.wait([
        for (final entry in _controllers.entries)
          if (entry.key != 'element-1') entry.value.forward(from: 0),
      ]);
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) setState(() => _switchingStudentSelector = false);
    }
  }

  Future<void> _selectPlanStudents(List<PlanningStudentSeed> seeds) async {
    if (!_showStudentSelector || _switchingStudentSelector || seeds.isEmpty) {
      return;
    }
    setState(() => _switchingStudentSelector = true);
    await Future<void>.delayed(planStudentSelectorMotionDuration);
    if (!mounted) return;
    setState(() {
      _builderStudentQueue = List.unmodifiable(seeds);
      _builderStudentQueueIndex = 0;
      for (final seed in seeds) {
        _studentSeedsById[seed.studentId] = seed;
      }
      _builderSeed = seeds.first;
      _showStudentSelector = false;
      _showElementBuilder = true;
      _showPhaseEditor = false;
      _switchingStudentSelector = false;
    });
  }

  void _closeElementBuilder() {
    if (!_showElementBuilder) return;
    setState(() {
      _showElementBuilder = false;
      _builderSeed = null;
      _builderStudentQueue = const [];
      _builderStudentQueueIndex = 0;
    });
    for (final entry in _controllers.entries) {
      if (entry.value.value < 1) entry.value.forward(from: entry.value.value);
    }
  }

  void _closePhaseEditor() {
    if (!_showPhaseEditor) return;
    setState(() => _showPhaseEditor = false);
    if (!_showElementBuilder) {
      for (final controller in _controllers.values) {
        controller.forward(from: 0);
      }
    }
  }

  void _confirmPlanElementStages(List<PlanElementStageDraft> stages) {
    final seed = _builderSeed;
    if (seed == null) return;
    final displayName =
        seed.metadata['display_name']?.toString() ?? seed.studentId;
    final replacedIds = {
      for (final element in _planElements)
        if (element.studentId == seed.studentId && element.stageId != null)
          element.stageId!,
    };
    final nextElements = [
      for (final element in _planElements)
        if (element.studentId != seed.studentId) element,
      for (var index = 0; index < stages.length; index++)
        PlanStudentStepPreview(
          studentId: seed.studentId,
          displayName: displayName,
          step: index + 1,
          target: stages[index].name,
          bondRank: stages[index].targets['bond_rank'],
          stageId: stages[index].id,
          targetValues: stages[index].targets,
        ),
    ];
    final newIds = {for (final stage in stages) stage.id};
    final existingPhases = _usingLivePlanElements
        ? _planPhases
        : const <PlanPhasePreview>[];
    setState(() {
      _usingLivePlanElements = true;
      _draftsByStudent[seed.studentId] = List.unmodifiable(stages);
      _planElements = List.unmodifiable(nextElements);
      _unassignedPlanElementIds = {
        for (final id in _unassignedPlanElementIds)
          if (!replacedIds.contains(id)) id,
        ...newIds,
      };
      _planPhases = [
        for (final phase in existingPhases)
          PlanPhasePreview(
            id: phase.id,
            name: phase.name,
            steps: [
              for (final step in phase.steps)
                if (step.studentId != seed.studentId) step,
            ],
          ),
      ];
    });
    _rebuildDocumentFromPhases();
    final nextIndex = _builderStudentQueueIndex + 1;
    if (nextIndex < _builderStudentQueue.length && mounted) {
      setState(() {
        _builderStudentQueueIndex = nextIndex;
        _builderSeed = _builderStudentQueue[nextIndex];
      });
    }
  }

  void _editPlanStudent(String studentId) {
    final source = _studentSeedsById[studentId];
    if (source == null) return;
    final seed = PlanningStudentSeed(
      handoffId:
          'plan-edit-$studentId-${DateTime.now().microsecondsSinceEpoch}',
      studentId: source.studentId,
      metadata: source.metadata,
      currentValues: source.currentValues,
      owned: source.owned,
    );
    setState(() {
      _builderStudentQueue = [seed];
      _builderStudentQueueIndex = 0;
      _builderSeed = seed;
    });
  }

  void _renameUnassignedPlanElement(String id, String name) {
    PlanStudentStepPreview? renamed;
    setState(() {
      _planElements = [
        for (final element in _planElements)
          if (element.stageId == id)
            () {
              renamed = element.copyWith(target: name);
              return renamed!;
            }()
          else
            element,
      ];
      final element = renamed;
      if (element != null) {
        final drafts = _draftsByStudent[element.studentId];
        if (drafts != null) {
          _draftsByStudent[element.studentId] = [
            for (final draft in drafts)
              if (draft.id == id) draft.copyWith(name: name) else draft,
          ];
        }
      }
    });
  }

  void _deleteUnassignedPlanElement(String id) {
    final removed = _planElements.cast<PlanStudentStepPreview?>().firstWhere(
      (element) => element?.stageId == id,
      orElse: () => null,
    );
    if (removed == null || !_unassignedPlanElementIds.contains(id)) return;
    setState(() {
      _planElements = [
        for (final element in _planElements)
          if (element.stageId != id) element,
      ];
      _unassignedPlanElementIds = {
        for (final elementId in _unassignedPlanElementIds)
          if (elementId != id) elementId,
      };
      final drafts = _draftsByStudent[removed.studentId];
      if (drafts != null) {
        final remaining = [
          for (final draft in drafts)
            if (draft.id != id) draft,
        ];
        if (remaining.isEmpty) {
          _draftsByStudent.remove(removed.studentId);
        } else {
          _draftsByStudent[removed.studentId] = List.unmodifiable(remaining);
        }
      }
      _planPhases = [
        for (final phase in _planPhases)
          PlanPhasePreview(
            id: phase.id,
            name: phase.name,
            steps: [
              for (final step in phase.steps)
                if (step.stageId != id) step,
            ],
          ),
      ];
      _usingLivePlanElements = _planElements.isNotEmpty;
    });
  }

  void _completePhaseEditor(
    List<PlanPhaseEditorGroup<PlanStudentStepPreview>> groups,
  ) {
    _controllers['element-2']!.value = 1;
    setState(() {
      _planPhases = [
        for (final group in groups)
          PlanPhasePreview(
            id: group.id,
            name: group.name,
            steps: [for (final item in group.items) item.data],
          ),
      ];
      _unassignedPlanElementIds = const {};
      _showPhaseEditor = false;
      _showElementBuilder = false;
      _builderSeed = null;
      _builderStudentQueue = const [];
      _builderStudentQueueIndex = 0;
    });
    for (final entry in _controllers.entries) {
      if (entry.key != 'element-2' && entry.value.value < 1) {
        entry.value.forward(from: entry.value.value);
      }
    }
    _rebuildDocumentFromPhases();
  }

  @override
  void dispose() {
    _flow?.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _scenarioListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth,
        constraints.maxHeight.isFinite ? constraints.maxHeight : 660,
      );
      final bottlenecks = filterPlanBottleneckDetails(
        _bottleneckDetails,
        categories: _selectedResourceCategories,
        sort: _resourceSort,
      );
      final phaseConsumptions = filterPlanConsumptionGroups(
        _phaseConsumptions,
        categories: _selectedResourceCategories,
        hideSatisfied: _hideSatisfiedResources,
        sort: _resourceSort,
      );
      final overallConsumptions = filterPlanConsumptionGroups(
        [_overallConsumption],
        categories: _selectedResourceCategories,
        hideSatisfied: _hideSatisfiedResources,
        sort: _resourceSort,
      );
      Widget sectionLayer(String id) {
        if (id == 'element-5') {
          return AnimatedSectionStack(
            key: const ValueKey('plan-section-5-6-stack'),
            index: _showResourceTypeFilters ? 1 : 0,
            motions: const [planSection5Motion, planSection5Motion],
            children: [
              Stack(
                key: const ValueKey('plan-section-5-resource-header'),
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: CustomPaint(
                      key: ValueKey('plan-$id-foundation'),
                      painter: PlanSectionFoundationPainter(id),
                    ),
                  ),
                  PlanResourceHeader(
                    selected: _selectedResourceView,
                    onSelected: _selectResourceView,
                    highlightedStudentIds: _highlightedStudentIds,
                    onHighlightStudents: _toggleHighlightedStudents,
                    summary: PlanResourceSummaryProjection.of(
                      bottlenecks: _bottleneckDetails,
                      phases: _phaseConsumptions,
                      overall: _overallConsumption,
                      planPhases: _planPhases,
                    ),
                  ),
                ],
              ),
              Stack(
                key: const ValueKey('plan-section-6-resource-filter'),
                fit: StackFit.expand,
                children: [
                  const IgnorePointer(
                    child: CustomPaint(
                      key: ValueKey('plan-element-6-foundation'),
                      painter: PlanSectionFoundationPainter('element-5'),
                    ),
                  ),
                  PlanResourceTypeFilterSection(
                    selected: _selectedResourceCategories,
                    onToggle: _toggleResourceCategory,
                    onToggleAll: _toggleAllResourceCategories,
                    onReset: _resetResourceCategories,
                  ),
                ],
              ),
            ],
          );
        }
        if (id == 'element-4') {
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: CustomPaint(
                  key: ValueKey('plan-$id-foundation'),
                  painter: PlanSectionFoundationPainter(id),
                ),
              ),
              PlanResourceControls(
                filterOpen: _showResourceTypeFilters,
                hideSatisfied: _hideSatisfiedResources,
                sort: _resourceSort,
                onToggleFilter: _toggleResourceTypeFilters,
                onToggleHideSatisfied: _toggleHideSatisfiedResources,
                onSortSelected: _selectResourceSort,
              ),
            ],
          );
        }
        if (id == 'element-1') {
          final bounds = planSectionPath(size, id).getBounds();
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: CustomPaint(
                  key: ValueKey('plan-$id-foundation'),
                  painter: PlanSectionFoundationPainter(id),
                ),
              ),
              Positioned(
                key: const ValueKey('plan-phase-editor-launch-position'),
                left: bounds.left + 18,
                top: bounds.top + bounds.height * 0.12,
                width: math.max(120, bounds.width * 0.54),
                height: math.min(420, bounds.height * 0.76),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              key: const ValueKey('plan-phase-editor-launch'),
                              onPressed:
                                  _showStudentSelector ||
                                      _switchingStudentSelector ||
                                      _showScenarioList ||
                                      _showScenarioComparison ||
                                      _switchingScenarioWorkspace
                                  ? null
                                  : _openPhaseEditor,
                              icon: const Icon(Icons.account_tree_outlined),
                              label: const Text(
                                '페이즈 만들기',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // FE4-f2: 저장된 활성 계획을 계획 만들기 흐름(3단계 단계 순서)으로 연다. 열 폭이 가장
                          // 좁을 때(120)도 왼쪽 버튼에 아이콘·여백 자리가 남게 40이다.
                          SizedBox(
                            width: 40,
                            child: Tooltip(
                              message: '활성 계획 단계 순서 바꾸기',
                              child: FilledButton.tonal(
                                key: const ValueKey('plan-flow-edit-active-launch'),
                                onPressed:
                                    _showStudentSelector ||
                                        _switchingStudentSelector ||
                                        _showScenarioList ||
                                        _showScenarioComparison ||
                                        _switchingScenarioWorkspace ||
                                        _flow != null ||
                                        widget.service
                                            is! RepositoryPlanService
                                    ? null
                                    : _openActivePlanFlow,
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                ),
                                child: const Icon(
                                  Icons.swap_vert_rounded,
                                  semanticLabel: '활성 계획 단계 순서 바꾸기',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('plan-student-selector-launch'),
                        onPressed:
                            _switchingStudentSelector ||
                                _showScenarioList ||
                                _showScenarioComparison ||
                                _switchingScenarioWorkspace
                            ? null
                            : _showStudentSelector
                            ? _closeStudentSelector
                            : widget.service == null
                            ? null
                            : _openStudentSelector,
                        icon: Icon(
                          _showStudentSelector
                              ? Icons.arrow_back
                              : Icons.person_add_alt_1,
                        ),
                        label: Text(
                          _showStudentSelector ? '선택 취소' : '학생 추가',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('plan-preset-manager-launch'),
                        onPressed:
                            _showStudentSelector ||
                                _switchingStudentSelector ||
                                _showScenarioList ||
                                _showScenarioComparison ||
                                _switchingScenarioWorkspace
                            ? null
                            : _openPresetManager,
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text(
                          '프리셋 생성·관리',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('plan-scenario-compare-launch'),
                        onPressed:
                            _showStudentSelector ||
                                _switchingStudentSelector ||
                                _showScenarioList ||
                                _showScenarioComparison ||
                                _switchingScenarioWorkspace ||
                                widget.service
                                    is! PlanningScenarioRepositoryService ||
                                widget.service
                                    is! PlanningScenarioComparisonService ||
                                _document == null
                            ? null
                            : _openScenarioComparison,
                        icon: const Icon(Icons.compare_arrows_rounded),
                        label: const Text(
                          '시나리오 비교',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('plan-scenario-create-launch'),
                        onPressed:
                            _showStudentSelector ||
                                _switchingStudentSelector ||
                                _showScenarioList ||
                                _showScenarioComparison ||
                                _switchingScenarioWorkspace ||
                                widget.service
                                    is! PlanningScenarioRepositoryService
                            ? null
                            : _openScenarioCreation,
                        icon: const Icon(Icons.add_chart_rounded),
                        label: const Text(
                          '시나리오 생성',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('plan-scenario-list-launch'),
                        onPressed:
                            _switchingScenarioWorkspace ||
                                _showScenarioComparison ||
                                widget.service
                                    is! PlanningScenarioRepositoryService
                            ? null
                            : _showScenarioList
                            ? _closeScenarioList
                            : _openScenarioList,
                        icon: Icon(
                          _showScenarioList
                              ? Icons.arrow_back_rounded
                              : Icons.view_list_rounded,
                        ),
                        label: Text(
                          _showScenarioList ? '목록 닫기' : '시나리오 리스트',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        if (id == 'element-3') {
          final containerPath = planBottleneckContainerPath(size);
          final containerBounds = containerPath.getBounds();
          final localPath = containerPath.shift(-containerBounds.topLeft);
          // FE4-h: 읽기·계산 오류, 또는 저장 문서를 계산할 수 없음(`calculation == null`)이면 재화 탭 대신 그
          // 상태를 보인다. 계획 내용(섹션 2)은 그대로 보인다.
          final calculationError = _calculationError;
          if (calculationError != null || _calculationUnavailable) {
            return Stack(
              key: const ValueKey('plan-section-3-status'),
              fit: StackFit.expand,
              children: [
                const IgnorePointer(
                  child: CustomPaint(
                    key: ValueKey('plan-element-3-foundation'),
                    painter: PlanSectionFoundationPainter('element-3'),
                  ),
                ),
                Positioned.fromRect(
                  rect: containerBounds,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: calculationError != null
                          ? Text(
                              '계산 오류\n$calculationError',
                              key: const ValueKey('plan-calculation-error'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            )
                          : const Text(
                              planCalculationUnavailableMessage,
                              key: ValueKey('plan-calculation-unavailable'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                    ),
                  ),
                ),
              ],
            );
          }
          return AnimatedSectionStack(
            key: const ValueKey('plan-section-3-tab-stack'),
            index: _selectedResourceView.index,
            motions: const [
              planSection3TabMotion,
              planSection3TabMotion,
              planSection3TabMotion,
            ],
            children: [
              Stack(
                key: const ValueKey('plan-section-3-1-bottleneck'),
                fit: StackFit.expand,
                children: [
                  const IgnorePointer(
                    child: CustomPaint(
                      key: ValueKey('plan-element-3-foundation'),
                      painter: PlanSectionFoundationPainter('element-3'),
                    ),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey(
                        'plan-bottleneck-container-foundation',
                      ),
                      painter: PlanPhaseContainerPainter(containerPath),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: containerBounds,
                    child: ClipPath(
                      clipper: _PlanLocalPathClipper(localPath),
                      child: PlanBottleneckDiagonalList(
                        bottlenecks: bottlenecks,
                        highlightedStageKeys: _highlightedStageKeys,
                        onHighlightStages: _toggleHighlightedStages,
                        selectedResourceKey: _selectedSection3ResourceKey,
                        onToggleResource: _toggleSection3Resource,
                      ),
                    ),
                  ),
                ],
              ),
              Stack(
                key: const ValueKey('plan-section-3-2-phase'),
                fit: StackFit.expand,
                children: [
                  const IgnorePointer(
                    child: CustomPaint(
                      key: ValueKey('plan-element-3-phase-foundation'),
                      painter: PlanSectionFoundationPainter('element-3'),
                    ),
                  ),
                  PlanConsumptionSection(
                    containerPath: containerPath,
                    groups: phaseConsumptions,
                    keyPrefix: 'plan-phase-consumption',
                    selectedResourceKey: _selectedSection3ResourceKey,
                    onToggleResource: _toggleSection3Resource,
                  ),
                ],
              ),
              Stack(
                key: const ValueKey('plan-section-3-3-overall'),
                fit: StackFit.expand,
                children: [
                  const IgnorePointer(
                    child: CustomPaint(
                      key: ValueKey('plan-element-3-overall-foundation'),
                      painter: PlanSectionFoundationPainter('element-3'),
                    ),
                  ),
                  PlanConsumptionSection(
                    containerPath: containerPath,
                    groups: overallConsumptions,
                    keyPrefix: 'plan-overall-consumption',
                    selectedResourceKey: _selectedSection3ResourceKey,
                    onToggleResource: _toggleSection3Resource,
                  ),
                ],
              ),
            ],
          );
        }
        if (id != 'element-2') {
          return IgnorePointer(
            child: CustomPaint(
              key: ValueKey('plan-$id-foundation'),
              painter: PlanSectionFoundationPainter(id),
            ),
          );
        }
        final containerPath = planPhaseContainerPath(size);
        final containerBounds = containerPath.getBounds();
        final localPath = containerPath.shift(-containerBounds.topLeft);
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: CustomPaint(
                key: ValueKey('plan-$id-foundation'),
                painter: PlanSectionFoundationPainter(id),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('plan-phase-container-foundation'),
                painter: PlanPhaseContainerPainter(containerPath),
              ),
            ),
            Positioned.fromRect(
              rect: containerBounds,
              child: ClipPath(
                clipper: _PlanLocalPathClipper(localPath),
                child: PlanPhaseDiagonalList(
                  phases: _planPhases,
                  highlightedStudentIds: _highlightedStudentIds,
                  highlightedStageKeys: _highlightedStageKeys,
                ),
              ),
            ),
          ],
        );
      }

      final editorItems = _usingLivePlanElements
          ? [
              for (final step in _planElements)
                PlanPhaseEditorItem<PlanStudentStepPreview>(
                  id: step.stageId!,
                  label: '${step.displayName} · ${step.target}',
                  iconAsset: 'assets/student_portraits/${step.studentId}.png',
                  data: step,
                  sequenceGroup: step.studentId,
                  sequenceIndex: step.step,
                ),
            ]
          : [
              for (final phase in dummyPlanPhases)
                for (final step in phase.steps)
                  PlanPhaseEditorItem<PlanStudentStepPreview>(
                    id: '${phase.id}-${step.studentId}-${step.step}',
                    label: '${step.displayName} · ${step.step}단계',
                    iconAsset: 'assets/student_portraits/${step.studentId}.png',
                    data: step,
                  ),
            ];
      final editorItemsById = {for (final item in editorItems) item.id: item};
      final initialEditorGroups = _usingLivePlanElements
          ? [
              for (final phase in _planPhases)
                PlanPhaseEditorGroup<PlanStudentStepPreview>(
                  id: phase.id,
                  name: phase.name,
                  items: [
                    for (final step in phase.steps)
                      if (step.stageId != null &&
                          editorItemsById.containsKey(step.stageId))
                        editorItemsById[step.stageId]!,
                  ],
                ),
            ]
          : const <PlanPhaseEditorGroup<PlanStudentStepPreview>>[];
      final builderSeed = _builderSeed;
      final unassignedBuilderItems = [
        for (final step in _planElements)
          if (step.stageId != null &&
              _unassignedPlanElementIds.contains(step.stageId))
            PlanElementUnassignedItem(
              id: step.stageId!,
              studentId: step.studentId,
              displayName: step.displayName,
              stageNumber: step.step,
              stageName: step.target,
              targetSummary: planElementTargetSummary(step.targetValues),
            ),
      ];
      return SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!_showPhaseEditor &&
                !_showElementBuilder &&
                !_showPresetManager &&
                _flow == null)
              for (final id in const [
                'element-2',
                'element-3',
                'element-4',
                'element-1',
                'element-5',
              ])
                Positioned.fill(
                  child: PlanSectionMotion(
                    key: ValueKey('plan-$id-motion'),
                    animation: _controllers[id]!,
                    introDegrees: planSectionMotions[id]!.intro,
                    outroDegrees: planSectionMotions[id]!.outro,
                    child: sectionLayer(id),
                  ),
                ),
            // FE5-a: 시나리오 목록은 S1 메뉴 · S2 목록 · S3 미리보기 3섹션이다(계획 홈 섹션 1도 나간다). 모션은 섹션마다
            // 부착면 방향이고 같은 [_scenarioListController]로 움직인다.
            if (_showScenarioList &&
                widget.service is PlanningScenarioRepositoryService &&
                _repositoryState != null)
              Positioned.fill(
                child: PlanScenarioListSection(
                  key: const ValueKey('plan-scenario-list-view'),
                  service: widget.service! as PlanningScenarioRepositoryService,
                  profileId: _repositoryState!.profileId,
                  currentProfileRevision: _repositoryState!.revision,
                  animation: _scenarioListController,
                  active: widget.active && !_switchingScenarioWorkspace,
                  activePlan: _repositoryPlan,
                  activeDocument: _document,
                  repositoryState: _repositoryState,
                  onBackToActivePlan: _closeScenarioList,
                  onCreateScenario: _createScenarioFromList,
                  onOpenPresets: _openPresetManagerFromList,
                  onCompare:
                      widget.service is PlanningScenarioComparisonService &&
                          _document != null
                      ? _compareFromList
                      : null,
                  viewingScenarioId: _viewingScenarioId,
                  onOpenScenario: _openScenarioView,
                  onCloseScenario: _closeScenarioView,
                  onEditScenario: _editScenarioFromView,
                  onApplyScenario:
                      widget.service is RepositoryPlanService &&
                          _repositoryPlan != null
                      ? _applyScenarioFromView
                      : null,
                ),
              ),
            if (_showScenarioComparison &&
                widget.service is PlanningScenarioRepositoryService &&
                widget.service is PlanningScenarioComparisonService &&
                _repositoryState != null &&
                _document != null)
              Positioned.fill(
                child: PlanSectionMotion(
                  key: const ValueKey('plan-scenario-comparison-motion'),
                  animation: _scenarioListController,
                  introDegrees: planScenarioListMotion.intro,
                  outroDegrees: planScenarioListMotion.outro,
                  child: PlanScenarioComparisonSection(
                    service: widget.service!,
                    repositoryState: _repositoryState!,
                    activePlan: _document!,
                    initialSelectedIds: _comparisonInitialIds,
                    section1Bounds: planSectionPath(
                      size,
                      'element-1',
                    ).getBounds(),
                    active: widget.active && !_switchingScenarioWorkspace,
                    onEdit: _editScenarioFromComparison,
                    onIncorporate: _incorporateScenario,
                  ),
                ),
              ),
            if (_flow case final flow? when widget.service != null)
              Positioned.fill(
                child: PlanFlowWorkspace(
                  key: const ValueKey('plan-flow-workspace-view'),
                  flow: flow,
                  service: widget.service!,
                  presets: _presets,
                  active: widget.active,
                  onSaved: (outcome) => _flowSaveOutcome = outcome,
                  onClosed: _closeFlow,
                ),
              ),
            if (!_showPhaseEditor && _showElementBuilder && builderSeed != null)
              Positioned.fill(
                child: PlanElementBuilder(
                  key: ValueKey(
                    'plan-element-builder-${builderSeed.handoffId}',
                  ),
                  seed: builderSeed,
                  initialStages:
                      _draftsByStudent[builderSeed.studentId] ?? const [],
                  unassignedItems: unassignedBuilderItems,
                  hasPlanElements: _planElements.isNotEmpty,
                  active: widget.active,
                  presets: _presets,
                  onConfirm: _confirmPlanElementStages,
                  onRenameUnassigned: _renameUnassignedPlanElement,
                  onDeleteUnassigned: _deleteUnassignedPlanElement,
                  onEditStudent: _editPlanStudent,
                  onExitToPlan: _closeElementBuilder,
                  onOpenPhaseEditor: _openPhaseEditor,
                ),
              ),
            if (!_showPhaseEditor &&
                !_showElementBuilder &&
                !_showPresetManager &&
                _showStudentSelector &&
                widget.service != null)
              Positioned.fill(
                child: PlanStudentSelector(
                  key: const ValueKey('plan-student-selector-view'),
                  service: widget.service!,
                  plannedIds: _draftsByStudent.keys.toSet(),
                  onConfirmed: _selectPlanStudents,
                  section1Bounds: planSectionPath(
                    size,
                    'element-1',
                  ).getBounds(),
                  section1RightAtReference:
                      planStudentSelectorSection1RightAtReference(size),
                  active: widget.active && !_switchingStudentSelector,
                ),
              ),
            if (_showPhaseEditor)
              Positioned.fill(
                child: PlanPhaseEditor<PlanStudentStepPreview>(
                  key: const ValueKey('plan-phase-editor'),
                  items: editorItems,
                  initialGroups: initialEditorGroups,
                  active: widget.active,
                  itemBuilder: (context, item, order) =>
                      PlanStudentStepTile(order: order, step: item.data),
                  onCancel: _closePhaseEditor,
                  onComplete: _completePhaseEditor,
                ),
              ),
            if (_showPresetManager)
              Positioned.fill(
                child: PlanPresetManager(
                  key: const ValueKey('plan-preset-manager'),
                  presets: _presets,
                  active: widget.active,
                  onPresetsChanged: _replacePresets,
                  onExit: _closePresetManager,
                ),
              ),
          ],
        ),
      );
    },
  );
}

Rect planScenarioListSectionRect(Size size, Rect section1Bounds) {
  const gap = 24.0;
  const outerInset = 16.0;
  final right = size.width - outerInset;
  final preferredLeft = section1Bounds.right + gap;
  final left = math.min(preferredLeft, right - 280);
  return Rect.fromLTRB(
    math.max(outerInset, left),
    section1Bounds.top,
    right,
    section1Bounds.bottom,
  );
}

Path planScenarioListSectionPath(Size size, Rect section1Bounds) {
  final rect = planScenarioListSectionRect(size, section1Bounds);
  final depth = diagonalCutDepth(rect.height);
  return roundedPolygonPath([
    Offset(rect.left + depth, rect.top),
    Offset(rect.right, rect.top),
    Offset(rect.right - depth, rect.bottom),
    Offset(rect.left, rect.bottom),
  ], 12);
}

Rect planScenarioComparisonSafeRect(
  Size size, {
  required double top,
  required double bottom,
  double inset = 12,
}) {
  final safeTop = top.clamp(0.0, size.height).toDouble();
  final safeBottom = bottom.clamp(safeTop, size.height).toDouble();
  if (size.height <= 0) {
    return Rect.fromLTRB(
      inset,
      safeTop,
      math.max(inset, size.width - inset),
      safeBottom,
    );
  }
  final depth = planScenarioParallelogramDepth(size.height);
  final leftBoundary = depth * (1 - safeTop / size.height);
  final rightBoundary = size.width - depth * safeBottom / size.height;
  return Rect.fromLTRB(
    leftBoundary + inset,
    safeTop,
    math.max(leftBoundary + inset, rightBoundary - inset),
    safeBottom,
  );
}

Rect planScenarioComparisonRailBandRect(
  Size size, {
  required double top,
  required double bottom,
  double inset = 12,
}) {
  final bandTop = top.clamp(0.0, size.height).toDouble();
  final bandBottom = bottom.clamp(bandTop, size.height).toDouble();
  final left = planPhaseLeftBoundary(size, bandBottom) + inset;
  final right = planPhaseRightBoundary(size, bandTop) - inset;
  return Rect.fromLTRB(left, bandTop, math.max(left + 1, right), bandBottom);
}

class _PlanComparisonTarget {
  const _PlanComparisonTarget({
    required this.id,
    required this.name,
    required this.document,
    this.scenario,
  });

  final String id;
  final String name;
  final PlanningDocument document;
  final PlanningScenarioRecord? scenario;

  bool get isActivePlan => scenario == null;
}

class PlanScenarioComparisonSection extends StatefulWidget {
  const PlanScenarioComparisonSection({
    super.key,
    required this.service,
    required this.repositoryState,
    required this.activePlan,
    required this.section1Bounds,
    required this.active,
    required this.onEdit,
    required this.onIncorporate,
    this.initialSelectedIds = const [],
  });

  final Object service;
  final RepositoryState repositoryState;
  final PlanningDocument activePlan;
  final Rect section1Bounds;
  final bool active;
  final Future<void> Function(PlanningScenarioRecord, int) onEdit;
  final Future<void> Function(PlanningScenarioRecord) onIncorporate;

  /// 처음 고를 두 대상(`active-plan` 또는 시나리오 id, FE5-a 시나리오 목록 "나란히 비교"). 둘이면 목록을 읽은 뒤
  /// 바로 비교한다.
  final List<String> initialSelectedIds;

  @override
  State<PlanScenarioComparisonSection> createState() =>
      _PlanScenarioComparisonSectionState();
}

class _PlanScenarioComparisonSectionState
    extends State<PlanScenarioComparisonSection> {
  PlanningScenarioListResult? _list;
  Object? _error;
  final List<String> _selectedIds = [];
  _PlanComparisonTarget? _targetA;
  _PlanComparisonTarget? _targetB;
  PlanningScenarioComparisonResult? _comparison;
  bool _working = false;
  Map<String, StudentCatalogEntry> _comparisonStudents = {};

  /// 시나리오 목록에서 두 대상을 골라 열었으면(FE5-a) 첫 읽기 뒤 한 번만 바로 비교한다.
  late bool _autoComparePending = widget.initialSelectedIds.length == 2;

  PlanningScenarioRepositoryService get _repository =>
      widget.service as PlanningScenarioRepositoryService;
  PlanningScenarioComparisonService get _calculator =>
      widget.service as PlanningScenarioComparisonService;

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelectedIds.take(2));
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _repository.listScenarios(
        widget.repositoryState.profileId,
      );
      final service = widget.service;
      final students = service is AppService
          ? await service.listStudents()
          : <StudentCatalogEntry>[];
      if (!mounted) return;
      setState(() {
        _comparisonStudents = {
          for (final student in students) student.studentId: student,
        };
        _list = result;
        _error = null;
        _selectedIds.removeWhere(
          (id) =>
              id != 'active-plan' &&
              !result.scenarios.any((scenario) => scenario.id == id),
        );
      });
      // 시나리오 목록에서 두 대상을 골라 열었으면(FE5-a) 바로 비교한다(한 번만).
      if (_autoComparePending) {
        _autoComparePending = false;
        if (_selectedIds.length == 2 && _comparison == null) _compare();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _toggle(String id) {
    if (!widget.active || _working) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 2) {
        _selectedIds.add(id);
      } else {
        _selectedIds
          ..removeAt(0)
          ..add(id);
      }
    });
  }

  Future<_PlanComparisonTarget> _resolve(String id) async {
    if (id == 'active-plan') {
      return _PlanComparisonTarget(
        id: id,
        name: '활성 계획',
        document: widget.activePlan,
      );
    }
    final loaded = await _repository.getScenario(
      widget.repositoryState.profileId,
      id,
    );
    return _PlanComparisonTarget(
      id: id,
      name: loaded.scenario.name,
      document: loaded.scenario.document,
      scenario: loaded.scenario,
    );
  }

  Future<void> _compare() async {
    if (_selectedIds.length != 2 || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final targets = await Future.wait([
        _resolve(_selectedIds[0]),
        _resolve(_selectedIds[1]),
      ]);
      final result = await _calculator.compareScenarios(
        currentStudents: [
          for (final student in widget.repositoryState.students)
            confirmedStudentPlanningCurrent(student),
        ],
        inventory: widget.repositoryState.inventory.toWire(),
        documentA: targets[0].document,
        documentB: targets[1].document,
      );
      if (!mounted) return;
      setState(() {
        _targetA = targets[0];
        _targetB = targets[1];
        _comparison = result;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _duplicate(_PlanComparisonTarget target) async {
    final scenario = target.scenario;
    final list = _list;
    if (scenario == null || list == null || _working) return;
    setState(() => _working = true);
    try {
      await _repository.duplicateScenario(
        profileId: widget.repositoryState.profileId,
        scenarioId: scenario.id,
        expectedRevision: list.revision,
        expectedScenarioRevision: scenario.revision,
        idempotencyKey:
            'scenario-duplicate-${DateTime.now().microsecondsSinceEpoch}',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${scenario.name}을 복제했습니다.')));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final path = planScenarioListSectionPath(size, widget.section1Bounds);
      final bounds = path.getBounds();
      final localPath = path.shift(-bounds.topLeft);
      return Stack(
        children: [
          IgnorePointer(
            child: CustomPaint(
              key: const ValueKey('plan-scenario-comparison-foundation'),
              size: size,
              painter: _ComparisonFoundationPainter(path),
            ),
          ),
          Positioned.fromRect(
            rect: bounds,
            child: ClipPath(
              clipper: _PlanLocalPathClipper(localPath),
              child: _comparison == null ? _buildSelection() : _buildResult(),
            ),
          ),
        ],
      );
    },
  );

  Widget _buildSelection() {
    final list = _list;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final errorHeight = _error == null ? 0.0 : 34.0;
        final header = planScenarioComparisonSafeRect(
          size,
          top: 12,
          bottom: 92 + errorHeight,
          inset: 16,
        );
        final footer = planScenarioComparisonRailBandRect(
          size,
          top: size.height - 62,
          bottom: size.height - 12,
          inset: 16,
        );
        final body = planScenarioComparisonRailBandRect(
          size,
          top: header.bottom + 10,
          bottom: footer.top - 10,
          inset: 16,
        );
        return Stack(
          children: [
            Positioned.fromRect(
              rect: header,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 50,
                    child: Row(
                      children: [
                        const Icon(Icons.compare_arrows_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '시나리오 비교',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text('${_selectedIds.length}/2 선택'),
                        const SizedBox(width: 12),
                        IconButton(
                          key: const ValueKey('plan-scenario-compare-refresh'),
                          onPressed: widget.active && !_working ? _load : null,
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: '새로고침',
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '먼저 선택한 계획은 A, 다음은 B로 비교합니다.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  if (_error case final error?)
                    Text(
                      '비교 준비 실패: $error',
                      key: const ValueKey('plan-scenario-compare-error'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                ],
              ),
            ),
            Positioned.fromRect(
              rect: body,
              child: list == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : TextButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('다시 불러오기'),
                            ),
                    )
                  : _ComparisonCandidateDiagonalList(
                      key: const ValueKey('plan-scenario-compare-candidates'),
                      cards: [
                        _ComparisonCandidateCard(
                          key: const ValueKey(
                            'plan-compare-candidate-active-plan',
                          ),
                          label: '활성 계획',
                          studentIds: widget.activePlan.stages
                              .map((stage) => stage.studentId)
                              .toSet()
                              .toList(),
                          detail:
                              '페이즈 ${widget.activePlan.phases.length} · 성장 단계 ${widget.activePlan.stages.length}',
                          selectedIndex: _selectedIds.indexOf('active-plan'),
                          onTap: () => _toggle('active-plan'),
                        ),
                        for (final scenario in list.scenarios)
                          _ComparisonCandidateCard(
                            key: ValueKey(
                              'plan-compare-candidate-${scenario.id}',
                            ),
                            label: scenario.name,
                            studentIds: scenario.studentIds,
                            detail:
                                '학생 ${scenario.studentCount} · 페이즈 ${scenario.phaseCount} · 성장 단계 ${scenario.stageCount}',
                            stale:
                                scenario.baseProfileRevision <
                                list.currentProfileRevision,
                            selectedIndex: _selectedIds.indexOf(scenario.id),
                            onTap: () => _toggle(scenario.id),
                          ),
                      ],
                    ),
            ),
            Positioned.fromRect(
              rect: footer,
              child: CustomPaint(
                painter: const _PlanScenarioListCardPainter(false),
                child: ClipPath(
                  clipper: const PlanScenarioParallelogramClipper(),
                  child: FilledButton.icon(
                    key: const ValueKey('plan-scenario-compare-confirm'),
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed:
                        widget.active && _selectedIds.length == 2 && !_working
                        ? _compare
                        : null,
                    icon: _working
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.compare_arrows_rounded),
                    label: const Text('두 계획 나란히 보기'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResult() {
    final targetA = _targetA!;
    final targetB = _targetB!;
    final result = _comparison!;
    return DefaultTabController(
      length: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final stale = [targetA, targetB].any(
            (target) =>
                target.scenario != null &&
                target.scenario!.baseProfileRevision <
                    widget.repositoryState.revision,
          );
          final header = planScenarioComparisonSafeRect(
            size,
            top: 10,
            bottom: 58 + (stale ? 20 : 0) + (_error == null ? 0 : 20),
            inset: 16,
          );
          final tabs = planScenarioComparisonRailBandRect(
            size,
            top: header.bottom + 4,
            bottom: header.bottom + 50,
            inset: 16,
          );
          final actions = planScenarioComparisonRailBandRect(
            size,
            top: size.height - 66,
            bottom: size.height - 10,
            inset: 16,
          );
          final body = planScenarioComparisonRailBandRect(
            size,
            top: tabs.bottom + 10,
            bottom: actions.top - 10,
            inset: 16,
          );
          return Stack(
            children: [
              Positioned.fromRect(
                rect: header,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          IconButton(
                            key: const ValueKey(
                              'plan-scenario-comparison-back',
                            ),
                            onPressed: _working
                                ? null
                                : () => setState(() {
                                    _comparison = null;
                                    _targetA = null;
                                    _targetB = null;
                                  }),
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: '선택 목록으로 이동',
                          ),
                          Expanded(
                            child: Text(
                              '${targetA.name}  ↔  ${targetB.name}',
                              key: const ValueKey(
                                'plan-scenario-comparison-title',
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      const Text(
                        '작업을 완료하지 못했습니다. 다시 시도해 주세요.',
                        key: ValueKey('plan-scenario-comparison-action-error'),
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    if (stale)
                      const Text(
                        '오래된 시나리오가 포함되어 있습니다. 현재 학생·인벤토리 데이터로 다시 계산한 결과입니다.',
                        key: ValueKey('plan-scenario-comparison-stale-warning'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.amberAccent),
                      ),
                  ],
                ),
              ),
              Positioned.fromRect(
                rect: tabs,
                child: CustomPaint(
                  painter: const _PlanScenarioListCardPainter(false),
                  child: ClipPath(
                    clipper: const PlanScenarioParallelogramClipper(),
                    child: const TabBar(
                      labelColor: AppColors.accent,
                      unselectedLabelColor: AppColors.textMuted,
                      indicatorColor: AppColors.accent,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: TextStyle(fontWeight: FontWeight.w700),
                      tabs: [
                        Tab(text: '전체 결과'),
                        Tab(text: '학생 목표'),
                        Tab(text: '재화·부족'),
                        Tab(text: '병목'),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: body,
                child: TabBarView(
                  children: [
                    _ComparisonSideBySide(
                      left: _ComparisonSummaryPane(
                        side: 'a',
                        target: targetA,
                        result: result,
                      ),
                      right: _ComparisonSummaryPane(
                        side: 'b',
                        target: targetB,
                        result: result,
                      ),
                    ),
                    _ComparisonStudentWorkspace(
                      targetA: targetA,
                      targetB: targetB,
                      comparison: result.comparison,
                      students: _comparisonStudents,
                      currentValues: {
                        for (final student in widget.repositoryState.students)
                          student.studentId: student.values,
                      },
                    ),
                    _ComparisonSideBySide(
                      left: _ComparisonResourcePane(
                        side: 'a',
                        target: targetA,
                        comparison: result.comparison,
                      ),
                      right: _ComparisonResourcePane(
                        side: 'b',
                        target: targetB,
                        comparison: result.comparison,
                      ),
                    ),
                    _ComparisonSideBySide(
                      left: _ComparisonBottleneckPane(
                        side: 'a',
                        target: targetA,
                        comparison: result.comparison,
                      ),
                      right: _ComparisonBottleneckPane(
                        side: 'b',
                        target: targetB,
                        comparison: result.comparison,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fromRect(
                rect: actions,
                child: Row(
                  children: [
                    Expanded(child: _actionsFor(targetA, 'a')),
                    const SizedBox(width: 12),
                    Expanded(child: _actionsFor(targetB, 'b')),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actionsFor(_PlanComparisonTarget target, String side) {
    final scenario = target.scenario;
    return CustomPaint(
      painter: const _PlanScenarioListCardPainter(false),
      child: ClipPath(
        clipper: const PlanScenarioParallelogramClipper(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  key: ValueKey('plan-scenario-$side-edit'),
                  onPressed: scenario == null || _working || _list == null
                      ? null
                      : () => widget.onEdit(scenario, _list!.revision),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('편집'),
                ),
                TextButton.icon(
                  key: ValueKey('plan-scenario-$side-duplicate'),
                  onPressed: scenario == null || _working
                      ? null
                      : () => _duplicate(target),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('복제'),
                ),
                TextButton.icon(
                  key: ValueKey('plan-scenario-$side-incorporate'),
                  onPressed: scenario == null || _working
                      ? null
                      : () => widget.onIncorporate(scenario),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('계획에 편입'),
                ),
                TextButton.icon(
                  key: ValueKey('plan-scenario-$side-move'),
                  onPressed: _working
                      ? null
                      : () => setState(() {
                          _comparison = null;
                          _targetA = null;
                          _targetB = null;
                        }),
                  icon: const Icon(Icons.view_list_rounded),
                  label: const Text('목록으로 이동'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonFoundationPainter extends CustomPainter {
  const _ComparisonFoundationPainter(this.path);
  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    PlanPhaseContainerPainter(path).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_ComparisonFoundationPainter oldDelegate) =>
      oldDelegate.path != path;
}

class _ComparisonCandidateCard extends StatelessWidget {
  const _ComparisonCandidateCard({
    super.key,
    required this.label,
    required this.detail,
    required this.selectedIndex,
    required this.onTap,
    this.stale = false,
    this.studentIds = const [],
  });

  final String label;
  final String detail;
  final int selectedIndex;
  final VoidCallback onTap;
  final bool stale;
  final List<String> studentIds;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PlanScenarioListCardPainter(
      selectedIndex >= 0,
      accent: selectedIndex == 1 ? AppColors.accent : AppColors.primary,
    ),
    child: ClipPath(
      clipper: const PlanScenarioParallelogramClipper(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              children: [
                _ComparisonBadge(
                  side: selectedIndex < 0
                      ? '–'
                      : selectedIndex == 0
                      ? 'A'
                      : 'B',
                ),
                if (studentIds.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _ScenarioStudentPortraits(
                    scenarioId: label,
                    studentIds: studentIds.take(3).toList(),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (stale)
                  const Tooltip(
                    message: '저장 후 프로필 데이터가 변경되었습니다.',
                    child: Icon(
                      Icons.history_rounded,
                      color: Colors.amberAccent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ComparisonCandidateDiagonalList extends StatefulWidget {
  const _ComparisonCandidateDiagonalList({super.key, required this.cards});

  final List<Widget> cards;

  @override
  State<_ComparisonCandidateDiagonalList> createState() =>
      _ComparisonCandidateDiagonalListState();
}

class _ComparisonCandidateDiagonalListState
    extends State<_ComparisonCandidateDiagonalList> {
  static const _inset = 8.0;
  static const _rowHeight = 88.0;
  static const _rowGap = 10.0;
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final contentHeight =
          _inset * 2 +
          widget.cards.length * _rowHeight +
          math.max(0, widget.cards.length - 1) * _rowGap;
      return DiagonalScrollbar(
        keyPrefix: 'plan-scenario-compare',
        controller: _controller,
        contentExtent: contentHeight,
        fogClipper: const PlanScenarioParallelogramClipper(),
        child: SingleChildScrollView(
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
              return SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var index = 0; index < widget.cards.length; index++)
                      () {
                        final top = _inset + index * (_rowHeight + _rowGap);
                        final offset = planPhaseRowHorizontalOffset(
                          viewportHeight: constraints.maxHeight,
                          rowTop: top,
                          rowHeight: _rowHeight,
                          scrollOffset: scroll,
                        );
                        final width = planPhaseRowWidth(
                          viewportWidth: constraints.maxWidth,
                          viewportHeight: constraints.maxHeight,
                          rowHeight: _rowHeight,
                        );
                        return Positioned(
                          left: _inset + offset,
                          top: top,
                          width: width,
                          height: _rowHeight,
                          child: widget.cards[index],
                        );
                      }(),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class _ComparisonSideBySide extends StatelessWidget {
  const _ComparisonSideBySide({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: left),
      const SizedBox(width: planResourceControlGap),
      Expanded(child: right),
    ],
  );
}

List<Map<String, dynamic>> _comparisonRows(Object? value) => [
  for (final item in value is List ? value : const [])
    if (item is Map) Map<String, dynamic>.from(item),
];

class _ComparisonPaneShell extends StatelessWidget {
  const _ComparisonPaneShell({
    required this.keyPrefix,
    required this.title,
    required this.entries,
  });
  final String keyPrefix;
  final String title;
  final List<_ComparisonPaneEntry> entries;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final header = planScenarioComparisonSafeRect(
        size,
        top: 12,
        bottom: 48,
        inset: 14,
      );
      final listBand = planScenarioComparisonRailBandRect(
        size,
        top: 58,
        bottom: size.height - 12,
        inset: 12,
      );
      return CustomPaint(
        key: ValueKey('$keyPrefix-pane'),
        painter: const _PlanScenarioListCardPainter(false),
        child: ClipPath(
          clipper: const PlanScenarioParallelogramClipper(),
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: header,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      if (keyPrefix != 'plan-comparison-students')
                        _ComparisonBadge(
                          side: keyPrefix.startsWith('plan-comparison-a-')
                              ? 'A'
                              : 'B',
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: listBand,
                child: ClipPath(
                  clipper: const PlanScenarioParallelogramClipper(),
                  child: _ComparisonPaneDiagonalList(
                    keyPrefix: keyPrefix,
                    entries: entries,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ComparisonPaneEntry {
  const _ComparisonPaneEntry(this.height, this.child);

  final double height;
  final Widget child;
}

class _ComparisonPaneDiagonalList extends StatefulWidget {
  const _ComparisonPaneDiagonalList({
    required this.keyPrefix,
    required this.entries,
  });

  final String keyPrefix;
  final List<_ComparisonPaneEntry> entries;

  @override
  State<_ComparisonPaneDiagonalList> createState() =>
      _ComparisonPaneDiagonalListState();
}

class _ComparisonPaneDiagonalListState
    extends State<_ComparisonPaneDiagonalList> {
  static const _inset = 8.0;
  static const _gap = 8.0;
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final contentHeight =
          _inset * 2 +
          widget.entries.fold<double>(0, (sum, entry) => sum + entry.height) +
          math.max(0, widget.entries.length - 1) * _gap;
      return DiagonalScrollbar(
        keyPrefix: widget.keyPrefix,
        controller: _controller,
        contentExtent: contentHeight,
        fogClipper: const PlanScenarioParallelogramClipper(),
        child: SingleChildScrollView(
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
              var top = _inset;
              final rows = <Widget>[];
              for (var index = 0; index < widget.entries.length; index++) {
                final entry = widget.entries[index];
                final offset = planPhaseRowHorizontalOffset(
                  viewportHeight: constraints.maxHeight,
                  rowTop: top,
                  rowHeight: entry.height,
                  scrollOffset: scroll,
                );
                final width = planPhaseRowWidth(
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: constraints.maxHeight,
                  rowHeight: entry.height,
                );
                rows.add(
                  Positioned(
                    key: ValueKey('${widget.keyPrefix}-row-$index'),
                    left: _inset + offset,
                    top: top,
                    width: width,
                    height: entry.height,
                    child: _ComparisonPaneRailRow(child: entry.child),
                  ),
                );
                top += entry.height + _gap;
              }
              return SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(clipBehavior: Clip.none, children: rows),
              );
            },
          ),
        ),
      );
    },
  );
}

class _ComparisonPaneRailRow extends StatelessWidget {
  const _ComparisonPaneRailRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final depth = planScenarioParallelogramDepth(constraints.maxHeight);
      return CustomPaint(
        painter: const _ComparisonPaneRailRowPainter(),
        child: ClipPath(
          clipper: const PlanScenarioParallelogramClipper(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(depth + 12, 6, depth + 12, 6),
            child: child,
          ),
        ),
      );
    },
  );
}

class _ComparisonPaneRailRowPainter extends CustomPainter {
  const _ComparisonPaneRailRowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = planScenarioParallelogramPath(size);
    canvas.drawPath(path, Paint()..color = const Color(0xc9264359));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_ComparisonPaneRailRowPainter oldDelegate) => false;
}

class _ComparisonSummaryPane extends StatelessWidget {
  const _ComparisonSummaryPane({
    required this.side,
    required this.target,
    required this.result,
  });
  final String side;
  final _PlanComparisonTarget target;
  final PlanningScenarioComparisonResult result;

  @override
  Widget build(BuildContext context) {
    final comparison = result.comparison;
    final projection = side == 'a' ? result.projectionA : result.projectionB;
    final phases = _comparisonRows(projection['phase_results']);
    return _ComparisonPaneShell(
      keyPrefix: 'plan-comparison-$side-summary',
      title: target.name,
      entries: [
        _ComparisonPaneEntry(
          174,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '총 필요 크레딧',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Image.asset(planCreditIconAsset, width: 32, height: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _comparisonAmount(comparison['credits_$side'] ?? 0),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _ComparisonDelta(
                value:
                    (comparison['credits_$side'] as num? ?? 0) -
                    (comparison['credits_${side == 'a' ? 'b' : 'a'}'] as num? ??
                        0),
                other: side == 'a' ? 'B' : 'A',
              ),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ComparisonMetric(
                      label: '필요 재화',
                      value: '${comparison['resource_type_count_$side'] ?? 0}종',
                    ),
                  ),
                  Expanded(
                    child: _ComparisonMetric(
                      label: '확인된 부족',
                      value:
                          '${comparison['known_shortage_type_count_$side'] ?? 0}종',
                      color: AppColors.warning,
                    ),
                  ),
                  Expanded(
                    child: _ComparisonMetric(
                      label: '페이즈',
                      value: '${phases.length}개',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_comparisonRows(
          comparison['resources'],
        ).any((row) => row['owned'] == null))
          const _ComparisonPaneEntry(
            52,
            Text(
              '일부 재고 미확인 · 부족량 계산에서 제외',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
        for (var index = 0; index < phases.length; index++)
          _ComparisonPaneEntry(
            64,
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 12, child: Text('${index + 1}')),
              title: Text(phases[index]['name']?.toString() ?? '페이즈'),
              subtitle: Text(
                '성장 단계 ${(phases[index]['stage_ids'] as List?)?.length ?? 0}개',
              ),
            ),
          ),
        if (phases.isEmpty)
          const _ComparisonPaneEntry(
            52,
            Align(
              alignment: Alignment.centerLeft,
              child: Text('구성된 페이즈가 없습니다.'),
            ),
          ),
      ],
    );
  }
}

class _ComparisonStudentWorkspace extends StatelessWidget {
  const _ComparisonStudentWorkspace({
    required this.targetA,
    required this.targetB,
    required this.comparison,
    required this.students,
    this.currentValues = const {},
  });
  final _PlanComparisonTarget targetA;
  final _PlanComparisonTarget targetB;
  final Map<String, dynamic> comparison;
  final Map<String, StudentCatalogEntry> students;

  /// 학생별 확정 현재값(v2 null을 채우는 바닥값).
  final Map<String, Map<String, dynamic>> currentValues;

  @override
  Widget build(BuildContext context) {
    final rows = _comparisonRows(comparison['students']);
    // v2 시나리오의 null(목표 없음)은 지금 값으로 채워 보인다(FE4-b1).
    PlanningStudentSeed seedFor(String studentId) => PlanningStudentSeed(
      handoffId: 'plan-comparison-$studentId',
      studentId: studentId,
      metadata: students[studentId]?.metadata ?? const {},
      currentValues: currentValues[studentId] ?? const {},
      owned: currentValues.containsKey(studentId),
    );
    Map<String, Map<String, int>> finalTargets(PlanningDocument document) {
      final targets = planFlowDocumentIntegerTargets(
        document,
        seedFor: seedFor,
      );
      return {
        for (final stage in document.stages)
          stage.studentId: targets[stage.id]!,
      };
    }

    final finalA = finalTargets(targetA.document);
    final finalB = finalTargets(targetB.document);
    final entries = <_ComparisonPaneEntry>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final id = row['student_id']?.toString() ?? '';
      final name = students[id]?.displayName ?? id;
      final differences = Map<String, dynamic>.from(
        row['target_differences'] as Map? ?? const {},
      );
      entries.add(
        _ComparisonPaneEntry(
          44,
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                differences.isEmpty
                    ? '최종 목표 동일'
                    : '다른 목표 ${differences.length}개',
                style: const TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
      for (final side in ['a', 'b']) {
        final values = (side == 'a' ? finalA : finalB)[id];
        final target = side == 'a' ? targetA : targetB;
        entries.add(
          _ComparisonPaneEntry(
            100,
            Row(
              children: [
                Tooltip(
                  message: target.name,
                  child: _ComparisonBadge(side: side.toUpperCase()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: values == null
                      ? Text(
                          '${target.name} · 이 계획에 포함되지 않음',
                          style: const TextStyle(color: AppColors.textMuted),
                        )
                      : DiagonalMediaListItem(
                          key: ValueKey('plan-comparison-$side-student-$id'),
                          currentStudentState: true,
                          data: _comparisonStudentData(
                            index + 1,
                            id,
                            name,
                            values,
                            students[id],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return _ComparisonPaneShell(
      keyPrefix: 'plan-comparison-students',
      title: '학생별 최종 목표 · A / B',
      entries: entries.isEmpty
          ? const [_ComparisonPaneEntry(52, Text('비교할 학생 목표가 없습니다.'))]
          : entries,
    );
  }
}

DiagonalMediaListItemData _comparisonStudentData(
  int order,
  String id,
  String name,
  Map<String, int> values,
  StudentCatalogEntry? student,
) {
  String value(String key) => values[key]?.toString() ?? '-';
  return DiagonalMediaListItemData(
    order: order,
    mediaAssetPath: 'assets/student_portraits/$id.png',
    title: name,
    studentStars: values['student_star'] ?? 0,
    weaponStars: values['weapon_star'] ?? 0,
    studentLevel: DiagonalMediaValue('Lv.${value('level')}'),
    weaponLevel: DiagonalMediaValue('Lv.${value('weapon_level')}'),
    skills: DiagonalMediaValue(
      ['ex_skill', 'skill1', 'skill2', 'skill3'].map(value).join('/'),
    ),
    equipment: [
      for (var slot = 1; slot <= 3; slot++)
        DiagonalMediaEquipment(
          assetPath: GameAssets.equipmentIcon(
            switch (slot) {
              1 => student?.equipmentSlot1 ?? 'Hat',
              2 => student?.equipmentSlot2 ?? 'Hairpin',
              _ => student?.equipmentSlot3 ?? 'Watch',
            },
            math.max(1, values['equip${slot}_tier'] ?? 1),
          ),
          tier: DiagonalMediaValue('T${value('equip${slot}_tier')}'),
          level: DiagonalMediaValue('Lv.${value('equip${slot}_level')}'),
        ),
    ],
    favoriteItem: DiagonalMediaValue('T${value('equip4_tier')}'),
    bondRank: DiagonalMediaValue(value('bond_rank')),
    stats: DiagonalMediaValue(
      ['stat_hp', 'stat_atk', 'stat_heal'].map(value).join('/'),
    ),
  );
}

class _ComparisonResourcePane extends StatelessWidget {
  const _ComparisonResourcePane({
    required this.side,
    required this.target,
    required this.comparison,
  });
  final String side;
  final _PlanComparisonTarget target;
  final Map<String, dynamic> comparison;

  @override
  Widget build(BuildContext context) => _ComparisonPaneShell(
    keyPrefix: 'plan-comparison-$side-resources',
    title: target.name,
    entries: [
      for (final row in _comparisonRows(comparison['resources']))
        _ComparisonPaneEntry(
          164,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ComparisonResourceTitle(row: row),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ComparisonMetric(
                      label: '필요',
                      value: _comparisonAmount(row['required_$side'] ?? 0),
                    ),
                  ),
                  Expanded(
                    child: _ComparisonMetric(
                      label: '보유',
                      value: _comparisonAmount(row['owned']),
                    ),
                  ),
                  Expanded(
                    child: _ComparisonMetric(
                      label: '부족',
                      value: _comparisonAmount(row['shortage_$side']),
                      color: row['shortage_$side'] == 0
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _ComparisonDelta(
                value:
                    (row['required_$side'] as num? ?? 0) -
                    (row['required_${side == 'a' ? 'b' : 'a'}'] as num? ?? 0),
                other: side == 'a' ? 'B' : 'A',
              ),
            ],
          ),
        ),
      if (_comparisonRows(comparison['resources']).isEmpty)
        const _ComparisonPaneEntry(52, Text('필요 재화가 없습니다.')),
    ],
  );
}

class _ComparisonBottleneckPane extends StatelessWidget {
  const _ComparisonBottleneckPane({
    required this.side,
    required this.target,
    required this.comparison,
  });
  final String side;
  final _PlanComparisonTarget target;
  final Map<String, dynamic> comparison;

  @override
  Widget build(BuildContext context) {
    // Keep the union in the same order on both sides, even where one has no bottleneck.
    final rows = _comparisonRows(comparison['bottlenecks']);
    final resources = {
      for (final row in _comparisonRows(comparison['resources']))
        row['resource_key']: row,
    };
    return _ComparisonPaneShell(
      keyPrefix: 'plan-comparison-$side-bottlenecks',
      title: target.name,
      entries: [
        for (final row in rows)
          _ComparisonPaneEntry(
            154,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ComparisonResourceTitle(
                  row: resources[row['resource_key']] ?? row,
                ),
                const SizedBox(height: 8),
                Text(
                  (row['shortage_$side'] as num? ?? 0) > 0
                      ? '최초 부족 · 페이즈 ${row['first_phase_$side'] ?? '–'}'
                      : '확인된 병목 없음',
                  style: TextStyle(
                    color: (row['shortage_$side'] as num? ?? 0) > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '발생 시점 부족량  ${_comparisonAmount(row['shortage_$side'] ?? 0)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        if (rows.isEmpty) const _ComparisonPaneEntry(52, Text('확인된 병목이 없습니다.')),
        if (_comparisonRows(
          comparison['resources'],
        ).any((row) => row['owned'] == null))
          const _ComparisonPaneEntry(
            52,
            Text(
              '미확인 재고의 병목은 판단할 수 없습니다.',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

String _comparisonAmount(Object? value) {
  if (value == null) return '미확인';
  return value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

class _ComparisonBadge extends StatelessWidget {
  const _ComparisonBadge({required this.side});
  final String side;
  @override
  Widget build(BuildContext context) {
    final color = side == 'A'
        ? AppColors.primary
        : side == 'B'
        ? AppColors.accent
        : AppColors.textMuted;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        side,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,
    required this.value,
    this.color = AppColors.text,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      Tooltip(
        message: value,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _ComparisonDelta extends StatelessWidget {
  const _ComparisonDelta({required this.value, required this.other});
  final num value;
  final String other;
  @override
  Widget build(BuildContext context) => Text(
    value == 0
        ? '$other 대비 동일'
        : '$other 대비 ${value > 0 ? '+' : ''}${_comparisonAmount(value)}',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 12,
      color: value == 0
          ? AppColors.textMuted
          : value > 0
          ? AppColors.warning
          : AppColors.primary,
    ),
  );
}

class _ComparisonResourceTitle extends StatelessWidget {
  const _ComparisonResourceTitle({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final asset = planningResourceIconAsset(
      category: row['category']?.toString() ?? '',
      itemId: row['item_id']?.toString(),
    );
    return Row(
      children: [
        if (asset != null)
          Image.asset(
            asset,
            width: 72,
            height: 72,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.inventory_2_outlined, size: 72),
          )
        else
          const Icon(
            Icons.inventory_2_outlined,
            size: 72,
            color: AppColors.primary,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            row['display_name']?.toString() ??
                row['resource_key']?.toString() ??
                '재화',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ScenarioStudentPortraits extends StatelessWidget {
  const _ScenarioStudentPortraits({
    required this.scenarioId,
    required this.studentIds,
  });

  final String scenarioId;
  final List<String> studentIds;

  @override
  Widget build(BuildContext context) {
    const diameter = 38.0;
    const overlap = 10.0;
    final visible = studentIds.take(4).toList(growable: false);
    final hidden = studentIds.length - visible.length;
    final itemCount = visible.length + (hidden > 0 ? 1 : 0);
    final width = itemCount == 0
        ? 0.0
        : diameter + (itemCount - 1) * (diameter - overlap);
    return SizedBox(
      key: ValueKey('plan-scenario-portraits-$scenarioId'),
      width: width,
      height: diameter,
      child: Stack(
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * (diameter - overlap),
              child: Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outline, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/student_portraits/${visible[index]}.png',
                  key: ValueKey(
                    'plan-scenario-portrait-$scenarioId-${visible[index]}',
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xff23394a),
                    child: Icon(Icons.person_outline, size: 22),
                  ),
                ),
              ),
            ),
          if (hidden > 0)
            Positioned(
              left: visible.length * (diameter - overlap),
              child: Container(
                width: diameter,
                height: diameter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xff23394a),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outline, width: 1.5),
                ),
                child: Text(
                  '+$hidden',
                  key: ValueKey('plan-scenario-portrait-overflow-$scenarioId'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

double planScenarioParallelogramDepth(double height) =>
    diagonalCutDepth(height);

Path planScenarioParallelogramPath(Size size) {
  final depth = planScenarioParallelogramDepth(size.height);
  return roundedPolygonPath([
    Offset(depth, 0),
    Offset(size.width, 0),
    Offset(size.width - depth, size.height),
    Offset(0, size.height),
  ], 8);
}

class PlanScenarioParallelogramClipper extends CustomClipper<Path> {
  const PlanScenarioParallelogramClipper();

  @override
  Path getClip(Size size) => planScenarioParallelogramPath(size);

  @override
  bool shouldReclip(PlanScenarioParallelogramClipper oldClipper) => false;
}

class _PlanScenarioListCardPainter extends CustomPainter {
  const _PlanScenarioListCardPainter(
    this.selected, {
    this.accent = AppColors.primary,
  });
  final bool selected;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final path = planScenarioParallelogramPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? accent.withValues(alpha: 0.22)
            : const Color(0xd9264359),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = selected ? accent : AppColors.outline.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 0.8,
    );
  }

  @override
  bool shouldRepaint(_PlanScenarioListCardPainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.accent != accent;
}

const _planResourceHeaderTexture = BATriangleTextureConfig(
  baseColor: Color(0xff263747),
  panelColor: AppColors.surfaceRaised,
  softColor: Color(0xff8295a6),
  accentColor: AppColors.primaryMuted,
  triangleSize: 82,
  tessellationContrast: 0.055,
  randomSeed: 6197,
  macroTriangleChance: 0.09,
  macroTriangleScale: 2.6,
  macroTriangleContrast: 0.035,
  lightStrength: 0.12,
  edgeVignetteStrength: 0.12,
  fogDirectionDegrees: 12,
  fogStrength: 0.07,
);

const _planResourceControlTexture = BATriangleTextureConfig(
  baseColor: BATrianglePalette.softTitlePinkBase,
  panelColor: BATrianglePalette.softTitlePinkPanel,
  softColor: BATrianglePalette.softTitlePinkSoft,
  accentColor: BATrianglePalette.softTitlePinkAccent,
  triangleSize: 48,
  tessellationContrast: 0.045,
  randomSeed: 7441,
  macroTriangleChance: 0.08,
  macroTriangleContrast: 0.035,
  lightStrength: 0.1,
  edgeVignetteStrength: 0.1,
  fogStrength: 0.05,
);

class PlanResourceControls extends StatelessWidget {
  const PlanResourceControls({
    super.key,
    required this.filterOpen,
    required this.hideSatisfied,
    required this.sort,
    required this.onToggleFilter,
    required this.onToggleHideSatisfied,
    required this.onSortSelected,
  });

  final bool filterOpen;
  final bool hideSatisfied;
  final PlanResourceSort sort;
  final VoidCallback onToggleFilter;
  final VoidCallback onToggleHideSatisfied;
  final ValueChanged<PlanResourceSort> onSortSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final paths = planResourceControlPaths(constraints.biggest);
      return Stack(
        key: const ValueKey('plan-resource-controls'),
        fit: StackFit.expand,
        children: [
          _PlanResourceControlButton(
            path: paths[0],
            controlKey: const ValueKey('plan-resource-type-filter-button'),
            tooltip: '재화 유형 필터',
            icon: filterOpen
                ? Icons.inventory_2_outlined
                : Icons.filter_alt_outlined,
            label: '재화 유형 필터',
            selected: filterOpen,
            onTap: onToggleFilter,
          ),
          _PlanResourceControlButton(
            path: paths[1],
            controlKey: const ValueKey('plan-hide-satisfied-button'),
            tooltip: '충족 재화 숨기기',
            icon: hideSatisfied
                ? Icons.visibility_off_rounded
                : Icons.visibility_outlined,
            label: '충족 재화 숨기기',
            selected: hideSatisfied,
            onTap: onToggleHideSatisfied,
          ),
          _PlanResourceSortDropdown(
            path: paths[2],
            value: sort,
            onSelected: onSortSelected,
          ),
        ],
      );
    },
  );
}

class _PlanResourceControlButton extends StatelessWidget {
  const _PlanResourceControlButton({
    required this.path,
    required this.controlKey,
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Path path;
  final Key controlKey;
  final String tooltip;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      rect: bounds,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Tooltip(
          message: tooltip,
          child: CustomPaint(
            painter: _PlanResourceControlPainter(localPath, selected),
            child: ClipPath(
              clipper: _PlanLocalPathClipper(localPath),
              child: Material(
                key: controlKey,
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final iconSize = math.min(
                        24.0,
                        math.min(
                          constraints.maxHeight * 0.42,
                          math.max(10.0, constraints.maxWidth - 8),
                        ),
                      );
                      return Center(
                        child: Icon(
                          icon,
                          size: iconSize,
                          color: selected ? AppColors.primary : AppColors.text,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanResourceSortDropdown extends StatelessWidget {
  const _PlanResourceSortDropdown({
    required this.path,
    required this.value,
    required this.onSelected,
  });

  final Path path;
  final PlanResourceSort value;
  final ValueChanged<PlanResourceSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      rect: bounds,
      child: CustomPaint(
        painter: _PlanResourceSortDropdownBorderPainter(localPath),
        child: ClipPath(
          clipper: _PlanLocalPathClipper(localPath),
          child: Material(
            color: Colors.transparent,
            child: PopupMenuButton<PlanResourceSort>(
              key: const ValueKey('plan-resource-sort-dropdown'),
              tooltip: '재화별 정렬방식',
              initialValue: value,
              color: AppColors.surfaceRaised,
              padding: EdgeInsets.zero,
              onSelected: onSelected,
              itemBuilder: (context) => [
                for (final option in PlanResourceSort.values)
                  PopupMenuItem(
                    value: option,
                    child: Text(
                      option.menuLabel,
                      style: const TextStyle(
                        color: diagonalMediaHighlightColor,
                        fontSize: 18,
                      ),
                    ),
                  ),
              ],
              child: bounds.width < 26
                  ? const SizedBox.expand()
                  : Padding(
                      padding: EdgeInsets.only(
                        left: math.min(26, bounds.width * 0.24),
                        right: math.min(20, bounds.width * 0.28),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value.compactLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: diagonalMediaHighlightColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanResourceSortDropdownBorderPainter extends CustomPainter {
  const _PlanResourceSortDropdownBorderPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = diagonalMediaHighlightColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (size.width < 26 || size.height < 6) return;
    final arrowWidth = math.min(9.0, size.width * 0.16);
    final arrowHeight = math.min(6.0, size.height * 0.32);
    final right = size.width - math.min(7.0, size.width * 0.1);
    final top = (size.height - arrowHeight) / 2;
    canvas.drawPath(
      Path()
        ..moveTo(right - arrowWidth, top)
        ..lineTo(right, top)
        ..lineTo(right - arrowWidth / 2, top + arrowHeight)
        ..close(),
      Paint()..color = diagonalMediaHighlightColor,
    );
  }

  @override
  bool shouldRepaint(_PlanResourceSortDropdownBorderPainter oldDelegate) =>
      oldDelegate.path.getBounds() != path.getBounds();
}

class _PlanResourceControlPainter extends CustomPainter {
  const _PlanResourceControlPainter(this.path, this.selected);

  final Path path;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(_planResourceControlTexture).paint(canvas, size);
    if (selected) {
      canvas.drawPath(
        path,
        Paint()..color = diagonalMediaHighlightColor.withValues(alpha: 0.1),
      );
    }
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? diagonalMediaHighlightColor
            : AppColors.outline.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 0.9,
    );
  }

  @override
  bool shouldRepaint(_PlanResourceControlPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.selected != selected;
}

class PlanResourceTypeFilterSection extends StatelessWidget {
  const PlanResourceTypeFilterSection({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onToggleAll,
    required this.onReset,
  });

  final Set<PlanResourceCategory> selected;
  final ValueChanged<PlanResourceCategory> onToggle;
  final VoidCallback onToggleAll;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final groupRect = planResourceFilterGroupRect(size);
      final resetPath = planResourceFilterResetPath(size);
      final resetBounds = resetPath.getBounds();
      return Stack(
        key: const ValueKey('plan-resource-type-filter-section'),
        fit: StackFit.expand,
        children: [
          Positioned.fromRect(
            rect: groupRect,
            child: _PlanResourceFilterGroupCard(
              key: const ValueKey('plan-resource-filter-group'),
              selected: selected,
              onToggle: onToggle,
              onToggleAll: onToggleAll,
            ),
          ),
          Positioned.fromRect(
            rect: resetBounds,
            child: Tooltip(
              message: '재화 유형 필터 초기화',
              child: CustomPaint(
                painter: _PlanResourceControlPainter(
                  resetPath.shift(-resetBounds.topLeft),
                  false,
                ),
                child: ClipPath(
                  clipper: _PlanLocalPathClipper(
                    resetPath.shift(-resetBounds.topLeft),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('plan-resource-filter-reset'),
                      onTap: onReset,
                      child: const Icon(
                        Icons.restart_alt_rounded,
                        size: 21,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PlanResourceFilterGroupCard extends StatelessWidget {
  const _PlanResourceFilterGroupCard({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onToggleAll,
  });

  final Set<PlanResourceCategory> selected;
  final ValueChanged<PlanResourceCategory> onToggle;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final allSelected = selected.length == PlanResourceCategory.values.length;
    final allValue = allSelected ? true : (selected.isEmpty ? false : null);
    final entries = <(String, bool?, VoidCallback, String)>[
      ('전체', allValue, onToggleAll, 'all'),
      for (final category in PlanResourceCategory.values)
        (
          category.label,
          selected.contains(category),
          () => onToggle(category),
          category.name,
        ),
    ];
    const columnCount = 4;
    final rows = (entries.length + columnCount - 1) ~/ columnCount;
    return CustomPaint(
      painter: const _PlanResourceFilterGroupPainter(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset =
              diagonalCutDepth(constraints.maxHeight) + 8;
          final titleHeight = constraints.maxHeight < 100 ? 24.0 : 31.0;
          final checkboxHeight = math.max(
            1.0,
            (constraints.maxHeight - titleHeight - 11) / rows,
          );
          final compactScale = (checkboxHeight / 30).clamp(0.62, 1.0);
          return Padding(
            padding: EdgeInsets.fromLTRB(inset, 6, inset, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: titleHeight,
                  child: Text(
                    '표시할 재화',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18 * compactScale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    children: [
                      for (final entry in entries)
                        FractionallySizedBox(
                          widthFactor: 1 / columnCount,
                          child: InkWell(
                            key: ValueKey('plan-resource-filter-${entry.$4}'),
                            onTap: entry.$3,
                            child: SizedBox(
                              height: checkboxHeight,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24 * compactScale,
                                    child: Transform.scale(
                                      scale: 0.68 * compactScale,
                                      child: IgnorePointer(
                                        child: Checkbox(
                                          tristate: entry.$2 == null,
                                          value: entry.$2,
                                          onChanged: (_) {},
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.$1,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.text,
                                        fontSize: 15.75 * compactScale,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanResourceFilterGroupPainter extends CustomPainter {
  const _PlanResourceFilterGroupPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final depth = diagonalCutDepth(size.height);
    final path = buildRoundedSectionPolygon([
      Offset(depth, 0),
      Offset(size.width, 0),
      Offset(size.width - depth, size.height),
      Offset(0, size.height),
    ], radius: 7);
    canvas.drawPath(path, Paint()..color = const Color(0xc735526b));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_PlanResourceFilterGroupPainter oldDelegate) => false;
}

class PlanResourceHeader extends StatefulWidget {
  const PlanResourceHeader({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.highlightedStudentIds,
    required this.onHighlightStudents,
    this.summary = PlanResourceSummaryProjection.empty,
  });

  /// 요약 행 3종의 값(FE5-c1, 화면 목록의 projection).
  final PlanResourceSummaryProjection summary;
  final PlanResourceView selected;
  final ValueChanged<PlanResourceView> onSelected;
  final Set<String> highlightedStudentIds;
  final ValueChanged<Set<String>> onHighlightStudents;

  @override
  State<PlanResourceHeader> createState() => _PlanResourceHeaderState();
}

class _PlanResourceHeaderState extends State<PlanResourceHeader> {
  bool _isHighlighted(Set<String> studentIds) =>
      studentIds.isNotEmpty &&
      widget.highlightedStudentIds.length == studentIds.length &&
      widget.highlightedStudentIds.every(studentIds.contains);

  void _toggle(Set<String> studentIds) => widget.onHighlightStudents(
    _isHighlighted(studentIds) ? const {} : studentIds,
  );

  /// 강조할 학생이 없으면 누를 수 없다.
  VoidCallback? _toggler(Set<String> studentIds) =>
      studentIds.isEmpty ? null : () => _toggle(studentIds);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final tabs = planResourceTabShelfRect(size);
      final headerPath = planResourceHeaderPath(size);
      final content = planResourceHeaderContentRect(size);

      return Stack(
        key: const ValueKey('plan-resource-header'),
        fit: StackFit.expand,
        children: [
          Positioned.fromRect(
            rect: tabs,
            child: _PlanResourceTabs(
              selected: widget.selected,
              onSelected: widget.onSelected,
            ),
          ),
          Positioned(
            left: tabs.left,
            top: tabs.bottom,
            width: tabs.width,
            height: 1,
            child: DecoratedBox(
              key: const ValueKey('plan-resource-header-divider'),
              decoration: BoxDecoration(
                color: AppColors.outline.withValues(alpha: 0.55),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('plan-resource-header-surface'),
                painter: PlanResourceHeaderPainter(headerPath),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: content,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.025, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(
                  'plan-resource-header-content-${widget.selected.name}',
                ),
                child: switch (widget.selected) {
                  PlanResourceView.bottleneck => PlanPrimaryBottleneckSummary(
                    projection: widget.summary.bottleneck,
                    highlighted: _isHighlighted(
                      widget.summary.bottleneck?.studentIds ?? const {},
                    ),
                    onTap: _toggler(
                      widget.summary.bottleneck?.studentIds ?? const {},
                    ),
                  ),
                  PlanResourceView.byPhase => PlanPhaseResourceSummary(
                    projection: widget.summary.phase,
                    highlighted: _isHighlighted(
                      widget.summary.phase?.studentIds ?? const {},
                    ),
                    onTap: _toggler(
                      widget.summary.phase?.studentIds ?? const {},
                    ),
                  ),
                  PlanResourceView.overall => PlanOverallResourceSummary(
                    projection: widget.summary.overall,
                    highlighted: _isHighlighted(
                      widget.summary.overall.studentIds,
                    ),
                    onTap: _toggler(widget.summary.overall.studentIds),
                  ),
                },
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PlanResourceTabs extends StatelessWidget {
  const _PlanResourceTabs({required this.selected, required this.onSelected});

  final PlanResourceView selected;
  final ValueChanged<PlanResourceView> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('plan-resource-tabs'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final view in PlanResourceView.values)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _PlanResourceTab(
              view: view,
              selected: view == selected,
              onTap: () => onSelected(view),
            ),
          ),
        ),
    ],
  );
}

class _PlanResourceTab extends StatelessWidget {
  const _PlanResourceTab({
    required this.view,
    required this.selected,
    required this.onTap,
  });

  final PlanResourceView view;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (view) {
      PlanResourceView.bottleneck => ('병목', Icons.warning_amber_rounded),
      PlanResourceView.byPhase => ('페이즈별', Icons.layers_outlined),
      PlanResourceView.overall => ('전체', Icons.inventory_2_outlined),
    };
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        key: ValueKey('plan-resource-tab-${view.name}'),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: double.infinity,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryMuted.withValues(alpha: 0.34)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.text : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 스테이지 키(`phase:student:step`)의 학생.
String _stageKeyStudent(String key) {
  final parts = key.split(':');
  return parts.length >= 3 ? parts[parts.length - 2] : key;
}

/// 요약 행 "가장 심한 병목 요소"(FE5-c1): 화면 병목 목록의 첫 병목(문서 순서) · 그 첫 재화.
@immutable
class PlanPrimaryBottleneckProjection {
  const PlanPrimaryBottleneckProjection({
    required this.name,
    required this.owned,
    required this.required,
    required this.iconAsset,
    required this.backgroundAsset,
    required this.studentIds,
  });

  final String name;

  /// 그 단계에 들어설 때 남은 양.
  final int owned;

  /// 그 단계 필요량.
  final int required;
  final String iconAsset;
  final String backgroundAsset;

  /// 확보하면 이어서 진행하는 학생(막힌 단계 학생 + 지연 단계 학생).
  final Set<String> studentIds;
}

/// 요약 행 "가장 부족한 재화"(FE5-c1): 부족 재화가 있는 첫 페이즈에서 충족률(보유/필요)이 가장 낮은 재화.
@immutable
class PlanPhaseShortageProjection {
  const PlanPhaseShortageProjection({
    required this.name,
    required this.owned,
    required this.required,
    required this.iconAsset,
    required this.backgroundAsset,
    required this.phaseNumber,
    required this.studentCount,
    required this.completableCount,
    required this.studentIds,
  });

  final String name;

  /// 그 페이즈에 들어설 때 보유.
  final int owned;
  final int required;
  final String iconAsset;
  final String backgroundAsset;

  /// 페이즈 번호(1부터).
  final int phaseNumber;

  /// 그 페이즈의 학생 수.
  final int studentCount;

  /// 그 페이즈의 모자란 재화를 하나도 쓰지 않는 학생 수.
  final int completableCount;

  /// 이 재화를 쓰는 그 페이즈 학생(강조).
  final Set<String> studentIds;
}

/// 요약 행 "전체 요구량"(FE5-c1): 충족률은 FD-031 (a)(재화별 min(보유, 필요)/필요 평균, 크레딧 포함, 보유를 모르는 재화는
/// 빼고 [unknownKinds]로 센다). FE4-e 저장 비교 타일과 같은 함수([planFlowFulfillment])다.
@immutable
class PlanOverallProjection {
  const PlanOverallProjection({
    required this.rate,
    required this.unknownKinds,
    required this.shortageKinds,
    required this.studentIds,
  });

  final double? rate;
  final int unknownKinds;
  final int shortageKinds;

  /// 모자란 재화를 쓰는 학생.
  final Set<String> studentIds;
}

/// 계획 홈 요약 행 3종(FE5-c1). 상수가 아니라 화면이 그리는 병목 · 페이즈별 · 전체 목록(문서 계산 projection에서 만든 것,
/// 계산 전에는 견본 목록)에서 정한다.
@immutable
class PlanResourceSummaryProjection {
  const PlanResourceSummaryProjection({
    this.bottleneck,
    this.phase,
    required this.overall,
  });

  /// 목록이 비었을 때.
  static const empty = PlanResourceSummaryProjection(
    overall: PlanOverallProjection(
      rate: null,
      unknownKinds: 0,
      shortageKinds: 0,
      studentIds: {},
    ),
  );

  /// 병목이 없으면 null.
  final PlanPrimaryBottleneckProjection? bottleneck;

  /// 모자란 재화가 있는 페이즈가 없으면 null.
  final PlanPhaseShortageProjection? phase;
  final PlanOverallProjection overall;

  factory PlanResourceSummaryProjection.of({
    required List<PlanBottleneckDetailPreview> bottlenecks,
    required List<PlanConsumptionGroupPreview> phases,
    required PlanConsumptionGroupPreview overall,
    required List<PlanPhasePreview> planPhases,
  }) {
    PlanPrimaryBottleneckProjection? bottleneck;
    if (bottlenecks.firstOrNull case final first?
        when first.resources.isNotEmpty) {
      final resource = first.resources.first;
      bottleneck = PlanPrimaryBottleneckProjection(
        name: resource.displayName,
        owned: resource.remainingAtEntry,
        required: resource.requiredAtEntry,
        iconAsset: resource.iconAsset,
        backgroundAsset:
            resource.effectiveBackgroundAsset ?? planDefaultItemBackgroundAsset,
        studentIds: {
          first.focusStudentId,
          for (final stage in first.delayedStages) stage.studentId,
        },
      );
    }

    PlanPhaseShortageProjection? phase;
    for (final (index, group) in phases.indexed) {
      final short = [
        for (final (order, resource) in group.resources.indexed)
          if (resource.isBottleneck) (order: order, resource: resource),
      ];
      if (short.isEmpty) continue;
      short.sort((a, b) {
        final ratio = a.resource.coverageRatio.compareTo(
          b.resource.coverageRatio,
        );
        if (ratio != 0) return ratio;
        final amount = b.resource.shortageAmount.compareTo(
          a.resource.shortageAmount,
        );
        return amount != 0 ? amount : a.order.compareTo(b.order);
      });
      final top = short.first.resource;
      final planPhase = planPhases
          .where((candidate) => candidate.id == group.id)
          .firstOrNull;
      final students = planPhase != null
          ? {for (final step in planPhase.steps) step.studentId}
          : {
              for (final resource in group.resources)
                for (final key in resource.affectedStageKeys)
                  _stageKeyStudent(key),
            };
      final stuck = {
        for (final item in short)
          for (final key in item.resource.affectedStageKeys)
            _stageKeyStudent(key),
      };
      phase = PlanPhaseShortageProjection(
        name: top.displayName,
        owned: top.owned,
        required: top.amount,
        iconAsset: top.iconAsset,
        backgroundAsset:
            top.effectiveBackgroundAsset ?? planDefaultItemBackgroundAsset,
        phaseNumber: index + 1,
        studentCount: students.length,
        completableCount: students
            .where((student) => !stuck.contains(student))
            .length,
        studentIds: {
          for (final key in top.affectedStageKeys) _stageKeyStudent(key),
        },
      );
      break;
    }

    final fulfillment = planFlowFulfillment([
      for (final resource in overall.resources)
        {
          'required_a': resource.amount,
          'owned': resource.inventoryKnown ? resource.owned : null,
        },
    ], 'a');
    final shortages = [
      for (final resource in overall.resources)
        if (resource.isBottleneck) resource,
    ];
    return PlanResourceSummaryProjection(
      bottleneck: bottleneck,
      phase: phase,
      overall: PlanOverallProjection(
        rate: fulfillment.rate,
        unknownKinds: fulfillment.unknown,
        shortageKinds: shortages.length,
        studentIds: {
          for (final resource in shortages)
            for (final key in resource.affectedStageKeys)
              _stageKeyStudent(key),
        },
      ),
    );
  }
}

class PlanPrimaryBottleneckSummary extends StatelessWidget {
  const PlanPrimaryBottleneckSummary({
    super.key,
    required this.projection,
    required this.highlighted,
    required this.onTap,
  });

  /// null이면 병목 없음.
  final PlanPrimaryBottleneckProjection? projection;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final projection = this.projection;
    if (projection == null) {
      return PlanResourceItemSummary(
        keyPrefix: 'plan-primary-bottleneck',
        semanticsLabel: '가장 심한 병목 요소 없음',
        kicker: '가장 심한 병목 요소',
        quantity: '병목 없음',
        detail: '알려진 보유로는 막히는 단계가 없습니다',
        backgroundAsset: planDefaultItemBackgroundAsset,
        iconAsset: null,
        highlighted: highlighted,
        onTap: onTap,
      );
    }
    return PlanResourceItemSummary(
      keyPrefix: 'plan-primary-bottleneck',
      semanticsLabel: '가장 심한 병목 요소, ${projection.name}',
      kicker: '가장 심한 병목 요소',
      quantity:
          '보유량 : ${formatPlanAmount(projection.owned)} / '
          '필요량 : ${formatPlanAmount(projection.required)}',
      detail:
          '확보 시 학생 ${projection.studentIds.length}명의 '
          '목표 단계가 가능해집니다',
      backgroundAsset: projection.backgroundAsset,
      iconAsset: projection.iconAsset,
      highlighted: highlighted,
      onTap: onTap,
    );
  }
}

class PlanPhaseResourceSummary extends StatelessWidget {
  const PlanPhaseResourceSummary({
    super.key,
    required this.projection,
    required this.highlighted,
    required this.onTap,
  });

  /// null이면 모자란 재화가 있는 페이즈가 없다.
  final PlanPhaseShortageProjection? projection;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final projection = this.projection;
    if (projection == null) {
      return PlanResourceItemSummary(
        keyPrefix: 'plan-phase-shortage',
        semanticsLabel: '가장 부족한 재화 없음',
        kicker: '가장 부족한 재화',
        quantity: '부족한 재화 없음',
        detail: '알려진 보유로는 모든 페이즈를 마칠 수 있습니다',
        backgroundAsset: planDefaultItemBackgroundAsset,
        iconAsset: null,
        highlighted: highlighted,
        onTap: onTap,
      );
    }
    return PlanResourceItemSummary(
      keyPrefix: 'plan-phase-shortage',
      semanticsLabel: '가장 부족한 재화, ${projection.name}',
      kicker: '가장 부족한 재화',
      quantity:
          '보유량 : ${formatPlanAmount(projection.owned)} / '
          '필요량 : ${formatPlanAmount(projection.required)}',
      detail:
          'P${projection.phaseNumber}에서 '
          '${projection.studentCount}명 중 '
          '${projection.completableCount}명만 완료 가능',
      backgroundAsset: projection.backgroundAsset,
      iconAsset: projection.iconAsset,
      highlighted: highlighted,
      onTap: onTap,
    );
  }
}

class PlanOverallResourceSummary extends StatelessWidget {
  const PlanOverallResourceSummary({
    super.key,
    required this.projection,
    required this.highlighted,
    required this.onTap,
  });

  final PlanOverallProjection projection;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 52;
      final progress = '전체 요구량의 ${planFlowSavePercent(projection.rate)} 확보';
      final impact = [
        '${projection.shortageKinds}종 부족',
        '${projection.studentIds.length}명의 성장 계획에 영향',
        if (projection.unknownKinds > 0) '보유 모름 ${projection.unknownKinds}종',
      ].join(' · ');
      final content = Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              progress,
              key: const ValueKey('plan-overall-progress'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.text,
                fontSize: compact ? 13 : 24,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: compact ? 3 : 10),
            Text(
              impact,
              key: const ValueKey('plan-overall-impact'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: diagonalMediaHighlightColor,
                fontSize: compact ? 8.5 : 15,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
      return Semantics(
        label: '$progress, $impact',
        button: onTap != null,
        selected: highlighted,
        child: Material(
          key: const ValueKey('plan-overall-summary'),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('plan-overall-action'),
            onTap: onTap,
            child: content,
          ),
        ),
      );
    },
  );
}

class PlanResourceItemSummary extends StatelessWidget {
  const PlanResourceItemSummary({
    super.key,
    required this.keyPrefix,
    required this.semanticsLabel,
    required this.kicker,
    required this.quantity,
    required this.detail,
    required this.backgroundAsset,
    required this.iconAsset,
    this.highlighted = false,
    this.onTap,
  });

  final String keyPrefix;
  final String semanticsLabel;
  final String kicker;
  final String quantity;
  final String detail;
  final String backgroundAsset;

  /// null이면 바탕만 보인다(요약할 재화가 없음).
  final String? iconAsset;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final iconAsset = this.iconAsset;
      final compact = constraints.maxHeight < 52;
      final iconHeight = constraints.maxHeight * 0.85;
      final iconWidth = iconHeight * 256 / 204;
      final content = Row(
        children: [
          SizedBox(
            width: iconWidth,
            height: iconHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    backgroundAsset,
                    key: ValueKey('$keyPrefix-square'),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                if (iconAsset != null)
                  FractionallySizedBox(
                    widthFactor: 227 / 234,
                    heightFactor: 181 / 190,
                    child: Image.asset(
                      iconAsset,
                      key: ValueKey('$keyPrefix-icon'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: compact ? 8 : 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kicker,
                  key: ValueKey('$keyPrefix-kicker'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: diagonalMediaHighlightColor,
                    fontSize: compact ? 7 : 12,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: compact ? 1.5 : 4.5),
                Text(
                  quantity,
                  key: ValueKey('$keyPrefix-quantity'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: compact ? 9 : 15,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: compact ? 1.5 : 6),
                Text(
                  detail,
                  key: ValueKey('$keyPrefix-impact'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: compact ? 6.5 : 11,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      return Semantics(
        label: semanticsLabel,
        button: onTap != null,
        selected: onTap == null ? null : highlighted,
        child: Material(
          key: ValueKey('$keyPrefix-summary'),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? content
              : InkWell(
                  key: ValueKey('$keyPrefix-action'),
                  onTap: onTap,
                  child: content,
                ),
        ),
      );
    },
  );
}

class PlanResourceHeaderPainter extends CustomPainter {
  const PlanResourceHeaderPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(_planResourceHeaderTexture).paint(canvas, size);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(PlanResourceHeaderPainter oldDelegate) =>
      oldDelegate.path != path;
}

class PlanSectionMotion extends StatelessWidget {
  const PlanSectionMotion({
    super.key,
    required this.animation,
    required this.introDegrees,
    required this.outroDegrees,
    required this.child,
  });

  final Animation<double> animation;
  final double introDegrees;
  final double outroDegrees;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    assert(
      (((introDegrees - outroDegrees).abs() % 360) - 180).abs() < 0.001,
      'Intro and outro must be opposite directions on one trajectory.',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Transform.translate(
            key: key == null ? null : ValueKey('$key-transform'),
            offset: planSectionMotionTranslation(
              size: size,
              introDegrees: introDegrees,
              outroDegrees: outroDegrees,
              progress: animation.value,
              exiting: animation.status == AnimationStatus.reverse,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

Offset planSectionMotionTranslation({
  required Size size,
  required double introDegrees,
  required double outroDegrees,
  required double progress,
  required bool exiting,
}) {
  final curved = AppMotion.sectionCurve.transform(
    progress.clamp(0.0, 1.0).toDouble(),
  );
  final remaining = 1 - curved;
  final direction = sectionMotionOffset(
    size,
    exiting ? outroDegrees : introDegrees,
  );
  return direction * (exiting ? remaining : -remaining);
}

class PlanSectionFoundationPainter extends CustomPainter {
  const PlanSectionFoundationPainter(this.sectionId);

  final String sectionId;

  @override
  void paint(Canvas canvas, Size size) {
    paintSectionSurface(canvas, planSectionPath(size, sectionId));
  }

  @override
  bool shouldRepaint(PlanSectionFoundationPainter oldDelegate) =>
      oldDelegate.sectionId != sectionId;
}

const _planPhaseTexture = BATriangleTextureConfig(
  baseColor: Color(0x8a29435b),
  panelColor: Color(0x8a355a75),
  softColor: Color(0x8a47738d),
  accentColor: Color(0x916291ad),
  triangleSize: 104,
  tessellationContrast: 0.026,
  randomSeed: 404,
  macroTriangleChance: 0.06,
  macroTriangleContrast: 0.018,
  lightStrength: 0.12,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

class PlanPhaseContainerPainter extends CustomPainter {
  const PlanPhaseContainerPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(_planPhaseTexture).paint(canvas, size);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(PlanPhaseContainerPainter oldDelegate) =>
      oldDelegate.path != path;
}

String formatPlanAmount(int value) {
  final isNegative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  if (isNegative) buffer.write('-');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

bool planConsumptionResourceIsCredit(PlanConsumptionResourcePreview resource) =>
    resource.iconAsset == planCreditIconAsset;

double planConsumptionCardHeight(PlanConsumptionGroupPreview group) {
  final hasCredit = group.resources.any(planConsumptionResourceIsCredit);
  final isOverall = group.id == 'overall';
  final ordinaryCount = group.resources
      .where((resource) => !planConsumptionResourceIsCredit(resource))
      .length;
  final rowCount = math.max(1, (ordinaryCount + 1) ~/ 2);
  final resourceTop = hasCredit ? (isOverall ? 116.0 : 96.0) : 48.0;
  final gridHeight = rowCount * 107.0 + math.max(0, rowCount - 1) * 8.0;
  return resourceTop + gridHeight + 16.0;
}

class PlanConsumptionSection extends StatelessWidget {
  const PlanConsumptionSection({
    super.key,
    required this.containerPath,
    required this.groups,
    required this.keyPrefix,
    required this.selectedResourceKey,
    required this.onToggleResource,
  });

  final Path containerPath;
  final List<PlanConsumptionGroupPreview> groups;
  final String keyPrefix;
  final String? selectedResourceKey;
  final PlanResourceToggle onToggleResource;

  @override
  Widget build(BuildContext context) {
    final bounds = containerPath.getBounds();
    final localPath = containerPath.shift(-bounds.topLeft);
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: CustomPaint(
            key: ValueKey('$keyPrefix-container-foundation'),
            painter: PlanPhaseContainerPainter(containerPath),
          ),
        ),
        Positioned.fromRect(
          rect: bounds,
          child: ClipPath(
            clipper: _PlanLocalPathClipper(localPath),
            child: PlanConsumptionDiagonalList(
              groups: groups,
              keyPrefix: keyPrefix,
              selectedResourceKey: selectedResourceKey,
              onToggleResource: onToggleResource,
            ),
          ),
        ),
      ],
    );
  }
}

class PlanConsumptionDiagonalList extends StatefulWidget {
  const PlanConsumptionDiagonalList({
    super.key,
    required this.groups,
    required this.keyPrefix,
    required this.selectedResourceKey,
    required this.onToggleResource,
  });

  final List<PlanConsumptionGroupPreview> groups;
  final String keyPrefix;
  final String? selectedResourceKey;
  final PlanResourceToggle onToggleResource;

  @override
  State<PlanConsumptionDiagonalList> createState() =>
      _PlanConsumptionDiagonalListState();
}

class _PlanConsumptionDiagonalListState
    extends State<PlanConsumptionDiagonalList> {
  static const _inset = 8.0;
  static const _cardGap = 18.0;
  final ScrollController _controller = ScrollController();
  bool _scrollCorrectionScheduled = false;

  void _scheduleScrollCorrection() {
    if (_scrollCorrectionScheduled) return;
    _scrollCorrectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCorrectionScheduled = false;
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      final corrected = _controller.offset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((_controller.offset - corrected).abs() > 0.01) {
        _controller.jumpTo(corrected);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heights = [
        for (final group in widget.groups) planConsumptionCardHeight(group),
      ];
      final contentHeight =
          _inset * 2 +
          heights.fold<double>(0, (sum, height) => sum + height) +
          math.max(0, widget.groups.length - 1) * _cardGap;
      return DiagonalScrollbar(
        keyPrefix: widget.keyPrefix,
        controller: _controller,
        contentExtent: contentHeight,
        child: SingleChildScrollView(
          key: ValueKey('${widget.keyPrefix}-scroll'),
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final rawScroll = _controller.hasClients
                  ? _controller.offset
                  : 0.0;
              final scroll = planStageEffectiveScrollOffset(
                rawOffset: rawScroll,
                contentHeight: contentHeight,
                viewportHeight: constraints.maxHeight,
              );
              if ((rawScroll - scroll).abs() > 0.01) {
                _scheduleScrollCorrection();
              }
              var top = _inset;
              final children = <Widget>[];
              for (var index = 0; index < widget.groups.length; index++) {
                final height = heights[index];
                final offset = planPhaseRowHorizontalOffset(
                  viewportHeight: constraints.maxHeight,
                  rowTop: top,
                  rowHeight: height,
                  scrollOffset: scroll,
                );
                final width = planPhaseRowWidth(
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: constraints.maxHeight,
                  rowHeight: height,
                );
                children.add(
                  Positioned(
                    key: ValueKey('${widget.keyPrefix}-card-${index + 1}'),
                    left: _inset + offset,
                    top: top,
                    width: width,
                    height: height,
                    child: PlanConsumptionCard(
                      group: widget.groups[index],
                      keyPrefix: widget.keyPrefix,
                      selectedResourceKey: widget.selectedResourceKey,
                      onToggleResource: widget.onToggleResource,
                    ),
                  ),
                );
                top += height + _cardGap;
              }
              return SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(clipBehavior: Clip.none, children: children),
              );
            },
          ),
        ),
      );
    },
  );
}

class _PlanDiagonalTwoColumnGrid extends StatelessWidget {
  const _PlanDiagonalTwoColumnGrid({
    required this.cardSize,
    required this.top,
    required this.itemCount,
    required this.gridKey,
    required this.itemBuilder,
  });

  final Size cardSize;
  final double top;
  final int itemCount;
  final Key gridKey;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) => Stack(
    key: gridKey,
    clipBehavior: Clip.none,
    children: [
      for (var index = 0; index < itemCount; index++)
        Builder(
          builder: (context) {
            final rect = planDiagonalTwoColumnTileRect(
              cardSize: cardSize,
              gridTop: top,
              index: index,
            );
            return Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: itemBuilder(index),
            );
          },
        ),
    ],
  );
}

Rect planDiagonalTwoColumnTileRect({
  required Size cardSize,
  required double gridTop,
  required int index,
}) {
  const tileHeight = 107.0;
  const gap = 8.0;
  const longControlInset = 16.0;
  const longControlHeight = 38.0;
  const previousGridInset = 12.0;
  final row = index ~/ 2;
  final column = index % 2;
  final rowTop = gridTop + row * (tileHeight + gap);
  final rowBottom = rowTop + tileHeight;
  final rowLeft =
      planPhaseLeftBoundary(cardSize, rowBottom) + previousGridInset;
  final rowRight = planPhaseRightBoundary(cardSize, rowTop) - previousGridInset;
  final tileWidth = math.max(1.0, (rowRight - rowLeft - gap) / 2);
  final railAlignmentShift =
      longControlInset +
      diagonalCutDepth(longControlHeight) -
      previousGridInset;
  final previousLeft = rowLeft + column * (tileWidth + gap);
  final alignedLeft =
      previousLeft + (column == 0 ? railAlignmentShift : -railAlignmentShift);
  return Rect.fromLTWH(alignedLeft, rowTop, tileWidth, tileHeight);
}

class PlanConsumptionCard extends StatelessWidget {
  const PlanConsumptionCard({
    super.key,
    required this.group,
    required this.keyPrefix,
    required this.selectedResourceKey,
    required this.onToggleResource,
  });

  final PlanConsumptionGroupPreview group;
  final String keyPrefix;
  final String? selectedResourceKey;
  final PlanResourceToggle onToggleResource;

  Rect _safeRect(Size size, double top, double bottom, {double inset = 12}) {
    final left = planPhaseLeftBoundary(size, top) + inset;
    final right = planPhaseRightBoundary(size, bottom) - inset;
    return Rect.fromLTRB(left, top, math.max(left + 1, right), bottom);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      PlanConsumptionResourcePreview? credit;
      final ordinaryResources = <PlanConsumptionResourcePreview>[];
      for (final resource in group.resources) {
        if (planConsumptionResourceIsCredit(resource)) {
          credit = resource;
        } else {
          ordinaryResources.add(resource);
        }
      }
      final isOverall = group.id == 'overall';
      final resolvedResourceTop = credit == null
          ? 48.0
          : (isOverall ? 116.0 : 96.0);
      return CustomPaint(
        painter: const _PlanBottleneckCardPainter(),
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: _safeRect(size, 16, 42, inset: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  group.label,
                  key: ValueKey('$keyPrefix-${group.id}-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: diagonalMediaHighlightColor,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (credit != null)
              Positioned.fromRect(
                rect: _safeRect(size, 48, isOverall ? 106 : 86, inset: 16),
                child: PlanConsumptionCreditRow(
                  resource: credit,
                  keyPrefix: keyPrefix,
                  isOverall: isOverall,
                  selected: selectedResourceKey == '$keyPrefix-${credit.id}',
                  onTap: () => onToggleResource(
                    '$keyPrefix-${credit!.id}',
                    credit.affectedStageKeys,
                  ),
                ),
              ),
            Positioned.fill(
              child: _PlanDiagonalTwoColumnGrid(
                cardSize: size,
                top: resolvedResourceTop,
                itemCount: ordinaryResources.length,
                gridKey: ValueKey('$keyPrefix-${group.id}-resource-grid'),
                itemBuilder: (index) => PlanConsumptionResourceTile(
                  resource: ordinaryResources[index],
                  keyPrefix: keyPrefix,
                  isOverall: isOverall,
                  selected:
                      selectedResourceKey ==
                      '$keyPrefix-${ordinaryResources[index].id}',
                  onTap: () => onToggleResource(
                    '$keyPrefix-${ordinaryResources[index].id}',
                    ordinaryResources[index].affectedStageKeys,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class PlanConsumptionCreditRow extends StatelessWidget {
  const PlanConsumptionCreditRow({
    super.key,
    required this.resource,
    required this.keyPrefix,
    required this.isOverall,
    required this.selected,
    required this.onTap,
  });

  final PlanConsumptionResourcePreview resource;
  final String keyPrefix;
  final bool isOverall;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: isOverall
        ? '보유 ${resource.ownedDisplay}, '
              '필요 ${formatPlanAmount(resource.amount)}, ${resource.coveragePercent}%, '
              '${resource.balanceDisplay}'
        : '진입 ${resource.ownedDisplay}, '
              '필요 ${formatPlanAmount(resource.amount)}, '
              '종료 ${resource.endingDisplay}, ${resource.balanceDisplay}',
    button: true,
    selected: selected,
    child: CustomPaint(
      key: ValueKey('$keyPrefix-${resource.id}-credit-row'),
      painter: _PlanBottleneckActionPainter(selected: selected),
      child: ClipPath(
        clipper: const _PlanBottleneckActionClipper(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('$keyPrefix-${resource.id}-action'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Image.asset(
                      resource.iconAsset,
                      key: ValueKey('$keyPrefix-${resource.id}-credit-icon'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isOverall) ...[
                          Text(
                            '보유 ${resource.ownedDisplay} / '
                            '필요 ${formatPlanAmount(resource.amount)}',
                            key: ValueKey('$keyPrefix-${resource.id}-amount'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          PlanInventoryCoverageBar(
                            key: ValueKey('$keyPrefix-${resource.id}-progress'),
                            ratio: resource.coverageRatio,
                            percent: resource.coveragePercent,
                            known: resource.inventoryKnown,
                            compact: true,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            resource.balanceDisplay,
                            key: ValueKey('$keyPrefix-${resource.id}-balance'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: resource.isBottleneck
                                  ? diagonalMediaHighlightColor
                                  : AppColors.textMuted,
                              fontSize: 10.5,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '진입 ${resource.ownedDisplay}  │ '
                                  '필요 ${formatPlanAmount(resource.amount)} │ '
                                  '종료 ${resource.endingDisplay}',
                                  key: ValueKey(
                                    '$keyPrefix-${resource.id}-amount',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10.5,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                resource.balanceDisplay,
                                key: ValueKey(
                                  '$keyPrefix-${resource.id}-balance',
                                ),
                                maxLines: 1,
                                style: TextStyle(
                                  color: resource.isBottleneck
                                      ? diagonalMediaHighlightColor
                                      : AppColors.textMuted,
                                  fontSize: 11.5,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

bool planBottleneckResourceIsCredit(PlanBottleneckResourcePreview resource) =>
    resource.id == 'credits';

double planBottleneckCardHeight(PlanBottleneckDetailPreview detail) =>
    detail.resources.any(planBottleneckResourceIsCredit) ? 353 : 305;

class PlanBottleneckDiagonalList extends StatefulWidget {
  const PlanBottleneckDiagonalList({
    super.key,
    required this.bottlenecks,
    required this.highlightedStageKeys,
    required this.onHighlightStages,
    required this.selectedResourceKey,
    required this.onToggleResource,
  });

  final List<PlanBottleneckDetailPreview> bottlenecks;
  final Set<String> highlightedStageKeys;
  final ValueChanged<Set<String>> onHighlightStages;
  final String? selectedResourceKey;
  final PlanResourceToggle onToggleResource;

  @override
  State<PlanBottleneckDiagonalList> createState() =>
      _PlanBottleneckDiagonalListState();
}

class _PlanBottleneckDiagonalListState
    extends State<PlanBottleneckDiagonalList> {
  static const _inset = 8.0;
  static const _cardGap = 18.0;
  final ScrollController _controller = ScrollController();
  bool _scrollCorrectionScheduled = false;

  void _scheduleScrollCorrection() {
    if (_scrollCorrectionScheduled) return;
    _scrollCorrectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCorrectionScheduled = false;
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      final corrected = _controller.offset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((_controller.offset - corrected).abs() > 0.01) {
        _controller.jumpTo(corrected);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heights = [
        for (final detail in widget.bottlenecks)
          planBottleneckCardHeight(detail),
      ];
      final contentHeight =
          _inset * 2 +
          heights.fold<double>(0, (sum, height) => sum + height) +
          math.max(0, widget.bottlenecks.length - 1) * _cardGap;
      return DiagonalScrollbar(
        keyPrefix: 'plan-bottleneck',
        controller: _controller,
        contentExtent: contentHeight,
        child: SingleChildScrollView(
          key: const ValueKey('plan-bottleneck-scroll'),
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final rawScroll = _controller.hasClients
                  ? _controller.offset
                  : 0.0;
              final scroll = planStageEffectiveScrollOffset(
                rawOffset: rawScroll,
                contentHeight: contentHeight,
                viewportHeight: constraints.maxHeight,
              );
              if ((rawScroll - scroll).abs() > 0.01) {
                _scheduleScrollCorrection();
              }
              var top = _inset;
              final children = <Widget>[];
              for (var index = 0; index < widget.bottlenecks.length; index++) {
                final height = heights[index];
                final offset = planPhaseRowHorizontalOffset(
                  viewportHeight: constraints.maxHeight,
                  rowTop: top,
                  rowHeight: height,
                  scrollOffset: scroll,
                );
                final width = planPhaseRowWidth(
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: constraints.maxHeight,
                  rowHeight: height,
                );
                children.add(
                  Positioned(
                    key: ValueKey('plan-bottleneck-card-${index + 1}'),
                    left: _inset + offset,
                    top: top,
                    width: width,
                    height: height,
                    child: PlanBottleneckDetailCard(
                      detail: widget.bottlenecks[index],
                      selectedResourceKey: widget.selectedResourceKey,
                      onToggleResource: widget.onToggleResource,
                      delayedStagesHighlighted:
                          widget.bottlenecks[index].delayedStages.isNotEmpty &&
                          widget.bottlenecks[index].delayedStages.every(
                            (stage) =>
                                widget.highlightedStageKeys.contains(stage.key),
                          ),
                      onToggleDelayedStages: () => widget.onHighlightStages({
                        for (final stage
                            in widget.bottlenecks[index].delayedStages)
                          stage.key,
                      }),
                    ),
                  ),
                );
                top += height + _cardGap;
              }
              return SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(clipBehavior: Clip.none, children: children),
              );
            },
          ),
        ),
      );
    },
  );
}

class PlanBottleneckDetailCard extends StatelessWidget {
  const PlanBottleneckDetailCard({
    super.key,
    required this.detail,
    required this.delayedStagesHighlighted,
    required this.onToggleDelayedStages,
    required this.selectedResourceKey,
    required this.onToggleResource,
  });

  final PlanBottleneckDetailPreview detail;
  final bool delayedStagesHighlighted;
  final VoidCallback onToggleDelayedStages;
  final String? selectedResourceKey;
  final PlanResourceToggle onToggleResource;

  Rect _safeRect(Size size, double top, double bottom, {double inset = 12}) {
    final left = planPhaseLeftBoundary(size, top) + inset;
    final right = planPhaseRightBoundary(size, bottom) - inset;
    return Rect.fromLTRB(left, top, math.max(left + 1, right), bottom);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final (focusStep, focusOrder) = planBottleneckFocusStep(detail);
      PlanBottleneckResourcePreview? credit;
      final cardResources = <PlanBottleneckResourcePreview>[];
      for (final resource in detail.resources) {
        if (planBottleneckResourceIsCredit(resource)) {
          credit = resource;
        } else {
          cardResources.add(resource);
        }
      }
      final resourceTop = credit == null ? 126.0 : 174.0;
      final buttonTop = resourceTop + 125;
      return CustomPaint(
        painter: const _PlanBottleneckCardPainter(),
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: _safeRect(size, 16, 42, inset: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  detail.rankLabel,
                  key: ValueKey('plan-bottleneck-${detail.id}-rank'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: diagonalMediaHighlightColor,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: _safeRect(size, 48, 113),
              child: PlanStudentStepTile(
                key: ValueKey('plan-bottleneck-${detail.id}-focus-item'),
                order: focusOrder,
                step: focusStep,
                bottleneckField: detail.focusField,
              ),
            ),
            if (credit != null)
              Positioned.fromRect(
                rect: _safeRect(size, 122, 160, inset: 16),
                child: PlanBottleneckCreditShortage(
                  resource: credit,
                  selected:
                      selectedResourceKey ==
                      'plan-bottleneck-${detail.id}-${credit.id}',
                  onTap: () => onToggleResource(
                    'plan-bottleneck-${detail.id}-${credit!.id}',
                    credit.affectedStageKeys,
                  ),
                ),
              ),
            Positioned.fill(
              child: _PlanDiagonalTwoColumnGrid(
                cardSize: size,
                top: resourceTop,
                itemCount: cardResources.length,
                gridKey: ValueKey('plan-bottleneck-${detail.id}-resource-grid'),
                itemBuilder: (index) => PlanBottleneckResourceTile(
                  resource: cardResources[index],
                  selected:
                      selectedResourceKey ==
                      'plan-bottleneck-${detail.id}-${cardResources[index].id}',
                  onTap: () => onToggleResource(
                    'plan-bottleneck-${detail.id}-${cardResources[index].id}',
                    cardResources[index].affectedStageKeys,
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: _safeRect(size, buttonTop, buttonTop + 38, inset: 16),
              child: CustomPaint(
                painter: _PlanBottleneckActionPainter(
                  selected: delayedStagesHighlighted,
                ),
                child: ClipPath(
                  clipper: const _PlanBottleneckActionClipper(),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey(
                        'plan-bottleneck-${detail.id}-delayed-action',
                      ),
                      onTap: onToggleDelayedStages,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_center_focus_rounded,
                              size: 17,
                              color: delayedStagesHighlighted
                                  ? diagonalMediaHighlightColor
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '이 병목으로 지연되는 단계',
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 12,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${detail.delayedStages.length}',
                              style: const TextStyle(
                                color: diagonalMediaHighlightColor,
                                fontSize: 12,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class PlanBottleneckCreditShortage extends StatelessWidget {
  const PlanBottleneckCreditShortage({
    super.key,
    required this.resource,
    required this.selected,
    required this.onTap,
  });

  final PlanBottleneckResourcePreview resource;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '크레딧, ${formatPlanAmount(resource.remainingAtEntry)} / '
        '${formatPlanAmount(resource.requiredAtEntry)}, '
        '${formatPlanAmount(resource.shortage)} 부족',
    button: true,
    selected: selected,
    child: CustomPaint(
      key: const ValueKey('plan-bottleneck-credit-shortage'),
      painter: _PlanBottleneckActionPainter(selected: selected),
      child: ClipPath(
        clipper: const _PlanBottleneckActionClipper(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('plan-bottleneck-resource-credits-action'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Image.asset(
                      resource.iconAsset,
                      key: const ValueKey(
                        'plan-bottleneck-credit-shortage-icon',
                      ),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${formatPlanAmount(resource.remainingAtEntry)} / '
                      '${formatPlanAmount(resource.requiredAtEntry)}',
                      key: const ValueKey(
                        'plan-bottleneck-credit-shortage-quantity',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${formatPlanAmount(resource.shortage)} 부족',
                      key: const ValueKey(
                        'plan-bottleneck-credit-shortage-value',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: diagonalMediaHighlightColor,
                        fontSize: 14,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PlanBottleneckResourceTile extends StatelessWidget {
  const PlanBottleneckResourceTile({
    super.key,
    required this.resource,
    required this.selected,
    required this.onTap,
  });

  final PlanBottleneckResourcePreview resource;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _PlanResourceTileFrame(
    id: 'plan-bottleneck-resource-${resource.id}',
    iconAsset: resource.iconAsset,
    backgroundAsset: resource.effectiveBackgroundAsset,
    selected: selected,
    onTap: onTap,
    contentBuilder: (scale) => [
      Text(
        resource.displayName,
        key: ValueKey('plan-bottleneck-resource-${resource.id}-name'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 16.5 * scale,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      SizedBox(height: 10.5 * scale),
      Text(
        '단계 진입 잔량 '
        '${formatPlanAmount(resource.remainingAtEntry)} / '
        '단계 필요량 '
        '${formatPlanAmount(resource.requiredAtEntry)}',
        key: ValueKey('plan-bottleneck-resource-${resource.id}-quantity'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12 * scale,
          height: 1.15,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: 10.5 * scale),
      Text(
        '${formatPlanAmount(resource.shortage)}개 부족',
        key: ValueKey('plan-bottleneck-resource-${resource.id}-shortage'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: diagonalMediaHighlightColor,
          fontSize: 18 * scale,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class PlanConsumptionResourceTile extends StatelessWidget {
  const PlanConsumptionResourceTile({
    super.key,
    required this.resource,
    required this.keyPrefix,
    required this.isOverall,
    required this.selected,
    required this.onTap,
  });

  final PlanConsumptionResourcePreview resource;
  final String keyPrefix;
  final bool isOverall;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _PlanResourceTileFrame(
    id: '$keyPrefix-${resource.id}',
    iconAsset: resource.iconAsset,
    backgroundAsset: resource.effectiveBackgroundAsset,
    selected: selected,
    onTap: onTap,
    contentBuilder: (scale) => [
      Text(
        resource.displayName,
        key: ValueKey('$keyPrefix-${resource.id}-name'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 16.5 * scale,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      SizedBox(height: (isOverall ? 7 : 10.5) * scale),
      if (isOverall) ...[
        Text(
          '보유 ${resource.ownedDisplay} / '
          '필요 ${formatPlanAmount(resource.amount)}',
          key: ValueKey('$keyPrefix-${resource.id}-amount'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5 * scale,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6 * scale),
        PlanInventoryCoverageBar(
          key: ValueKey('$keyPrefix-${resource.id}-progress'),
          ratio: resource.coverageRatio,
          percent: resource.coveragePercent,
          known: resource.inventoryKnown,
          scale: scale,
        ),
        SizedBox(height: 6 * scale),
      ] else ...[
        Text(
          '진입 ${resource.ownedDisplay}  │ '
          '필요 ${formatPlanAmount(resource.amount)} │ '
          '종료 ${resource.endingDisplay}',
          key: ValueKey('$keyPrefix-${resource.id}-amount'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5 * scale,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          resource.balanceDisplay,
          key: ValueKey('$keyPrefix-${resource.id}-balance'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: resource.isBottleneck
                ? diagonalMediaHighlightColor
                : AppColors.textMuted,
            fontSize: 14 * scale,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
      if (isOverall)
        Text(
          resource.balanceDisplay,
          key: ValueKey('$keyPrefix-${resource.id}-balance'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: resource.isBottleneck
                ? diagonalMediaHighlightColor
                : AppColors.textMuted,
            fontSize: 12.5 * scale,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
    ],
  );
}

class PlanInventoryCoverageBar extends StatelessWidget {
  const PlanInventoryCoverageBar({
    super.key,
    required this.ratio,
    required this.percent,
    this.known = true,
    this.scale = 1,
    this.compact = false,
  });

  final double ratio;
  final int percent;
  final bool known;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: known ? '확보율 $percent%' : '보유량 미확인',
    child: Padding(
      padding: EdgeInsets.only(right: (compact ? 10 : 14) * scale),
      child: SizedBox(
        height: (compact ? 8 : 12) * scale,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: double.infinity,
                  height: (compact ? 7.2 : 10.8) * scale,
                  child: CustomPaint(
                    key: const ValueKey('plan-inventory-coverage-bar-fill'),
                    painter: SkewBarPainter(
                      fraction: ratio,
                      color: diagonalMediaHighlightColor,
                      style: SkewBarStyle.planCoverage,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: (compact ? 5 : 7) * scale),
            Text(
              known ? '$percent%' : '—',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: (compact ? 8.5 : 11) * scale,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PlanResourceTileFrame extends StatelessWidget {
  const _PlanResourceTileFrame({
    required this.id,
    required this.iconAsset,
    required this.backgroundAsset,
    required this.selected,
    required this.onTap,
    required this.contentBuilder,
  });

  final String id;
  final String iconAsset;
  final String? backgroundAsset;
  final bool selected;
  final VoidCallback onTap;
  final List<Widget> Function(double scale) contentBuilder;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: CustomPaint(
      painter: _PlanBottleneckResourceTilePainter(selected: selected),
      child: ClipPath(
        clipper: const _PlanBottleneckActionClipper(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('$id-action'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 230).clamp(0.65, 1.0);
                  final iconWidth = math.min(97.5, constraints.maxWidth * 0.42);
                  final iconHeight = math.min(123.0, iconWidth * 123 / 97.5);
                  final gap = math.min(13.5, constraints.maxWidth * 0.06);
                  return Row(
                    children: [
                      SizedBox(
                        width: iconWidth,
                        height: iconHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (backgroundAsset != null)
                              Positioned.fill(
                                child: Image.asset(
                                  backgroundAsset!,
                                  key: ValueKey('$id-square'),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            FractionallySizedBox(
                              widthFactor: 0.92,
                              heightFactor: 0.92,
                              child: Image.asset(
                                iconAsset,
                                key: ValueKey('$id-icon'),
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: contentBuilder(scale),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PlanBottleneckActionClipper extends CustomClipper<Path> {
  const _PlanBottleneckActionClipper();

  @override
  Path getClip(Size size) {
    final depth = diagonalCutDepth(size.height);
    return buildRoundedSectionPolygon([
      Offset(depth, 0),
      Offset(size.width, 0),
      Offset(size.width - depth, size.height),
      Offset(0, size.height),
    ], radius: 7);
  }

  @override
  bool shouldReclip(_PlanBottleneckActionClipper oldClipper) => false;
}

class _PlanBottleneckActionPainter extends CustomPainter {
  const _PlanBottleneckActionPainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final path = const _PlanBottleneckActionClipper().getClip(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? diagonalMediaHighlightColor.withValues(alpha: 0.12)
            : const Color(0x7a20394e),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? diagonalMediaHighlightColor
            : AppColors.outline.withValues(alpha: 0.54)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 0.8,
    );
  }

  @override
  bool shouldRepaint(_PlanBottleneckActionPainter oldDelegate) =>
      oldDelegate.selected != selected;
}

class _PlanBottleneckCardPainter extends CustomPainter {
  const _PlanBottleneckCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final depth = diagonalCutDepth(size.height);
    final path = buildRoundedSectionPolygon([
      Offset(depth, 0),
      Offset(size.width, 0),
      Offset(size.width - depth, size.height),
      Offset(0, size.height),
    ], radius: 9);
    canvas.drawPath(path, Paint()..color = const Color(0xd635526b));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(_PlanBottleneckCardPainter oldDelegate) => false;
}

class _PlanBottleneckResourceTilePainter extends CustomPainter {
  const _PlanBottleneckResourceTilePainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final depth = diagonalCutDepth(size.height);
    final path = buildRoundedSectionPolygon([
      Offset(depth, 0),
      Offset(size.width, 0),
      Offset(size.width - depth, size.height),
      Offset(0, size.height),
    ], radius: 7);
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? diagonalMediaHighlightColor.withValues(alpha: 0.12)
            : const Color(0xb7213c52),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? diagonalMediaHighlightColor
            : AppColors.outline.withValues(alpha: 0.56)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 0.8,
    );
  }

  @override
  bool shouldRepaint(_PlanBottleneckResourceTilePainter oldDelegate) =>
      oldDelegate.selected != selected;
}

class PlanPhaseDiagonalList extends StatefulWidget {
  const PlanPhaseDiagonalList({
    super.key,
    required this.phases,
    required this.highlightedStudentIds,
    required this.highlightedStageKeys,
  });

  final List<PlanPhasePreview> phases;
  final Set<String> highlightedStudentIds;
  final Set<String> highlightedStageKeys;

  @override
  State<PlanPhaseDiagonalList> createState() => _PlanPhaseDiagonalListState();
}

class _PlanPhaseDiagonalListState extends State<PlanPhaseDiagonalList> {
  static const _inset = 8.0;
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heights = [
        for (final phase in widget.phases)
          planPhaseHeaderHeight + phase.steps.length * planPhaseItemExtent + 12,
      ];
      final contentHeight =
          _inset * 2 +
          heights.fold<double>(0, (sum, height) => sum + height) +
          planPhaseFlowGap * math.max(0, widget.phases.length - 1);
      return DiagonalScrollbar(
        keyPrefix: 'plan-phase',
        controller: _controller,
        contentExtent: contentHeight,
        child: SingleChildScrollView(
          key: const ValueKey('plan-phase-scroll'),
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
              var top = _inset;
              final children = <Widget>[];
              for (var index = 0; index < widget.phases.length; index++) {
                final phase = widget.phases[index];
                final height = heights[index];
                final offset = planPhaseRowHorizontalOffset(
                  viewportHeight: constraints.maxHeight,
                  rowTop: top,
                  rowHeight: height,
                  scrollOffset: scroll,
                );
                final width = planPhaseRowWidth(
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: constraints.maxHeight,
                  rowHeight: height,
                );
                children.add(
                  Positioned(
                    key: ValueKey('plan-phase-${phase.id}'),
                    left: _inset + offset,
                    top: top,
                    width: width,
                    height: height,
                    child: PlanPhaseCard(
                      phaseId: phase.id,
                      number: index + 1,
                      phase: phase,
                      highlightedStudentIds: widget.highlightedStudentIds,
                      highlightedStageKeys: widget.highlightedStageKeys,
                    ),
                  ),
                );
                if (index < widget.phases.length - 1) {
                  children.add(
                    Positioned(
                      key: ValueKey('plan-phase-flow-${phase.id}'),
                      left: _inset + offset,
                      top: top + height + 2,
                      width: width,
                      height: planPhaseFlowGap - 4,
                      child: DiagonalFlowIndicator(
                        parallelogramHeight: height,
                        paintKey: const ValueKey('plan-phase-flow-triangle'),
                      ),
                    ),
                  );
                }
                top += height + planPhaseFlowGap;
              }
              return SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(clipBehavior: Clip.none, children: children),
              );
            },
          ),
        ),
      );
    },
  );
}

class PlanPhaseCard extends StatelessWidget {
  const PlanPhaseCard({
    super.key,
    required this.phaseId,
    required this.number,
    required this.phase,
    required this.highlightedStudentIds,
    required this.highlightedStageKeys,
  });

  final String phaseId;
  final int number;
  final PlanPhasePreview phase;
  final Set<String> highlightedStudentIds;
  final Set<String> highlightedStageKeys;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final headerCenterY = 19.0;
      final headerLeft = planPhaseLeftBoundary(size, headerCenterY) + 9;
      final headerRight = planPhaseRightBoundary(size, headerCenterY) - 9;
      return CustomPaint(
        painter: const _PlanPhaseCardPainter(),
        child: Stack(
          children: [
            Positioned(
              left: headerLeft,
              top: 8,
              width: math.max(1, headerRight - headerLeft),
              height: 23,
              child: Row(
                children: [
                  Text('$number', style: AppTextStyles.planPhaseNumber),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      phase.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < phase.steps.length; index++)
              Positioned.fromRect(
                rect: planPhaseItemRect(size, index),
                child: PlanStudentStepTile(
                  key: ValueKey(
                    'plan-step-${phase.id}-${phase.steps[index].studentId}-${phase.steps[index].step}',
                  ),
                  order: index + 1,
                  step: phase.steps[index],
                  highlighted:
                      highlightedStudentIds.contains(
                        phase.steps[index].studentId,
                      ) ||
                      highlightedStageKeys.contains(
                        planStudentStageKey(
                          phaseId,
                          phase.steps[index].studentId,
                          phase.steps[index].step,
                        ),
                      ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

double planPhaseLeftBoundary(Size size, double y) {
  final depth = diagonalCutDepth(size.height);
  return depth * (1 - y / size.height);
}

double planPhaseRightBoundary(Size size, double y) {
  final depth = diagonalCutDepth(size.height);
  return size.width - depth * y / size.height;
}

Rect planPhaseItemRect(Size size, int index) {
  final top = planPhaseHeaderHeight + index * planPhaseItemExtent;
  final bottom = top + planPhaseItemHeight;
  const inset = 9.0;
  final left = planPhaseLeftBoundary(size, bottom) + inset;
  final right = planPhaseRightBoundary(size, top) - inset;
  return Rect.fromLTRB(left, top, math.max(left + 1, right), bottom);
}

class _PlanPhaseCardPainter extends CustomPainter {
  const _PlanPhaseCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final depth = diagonalCutDepth(size.height);
    final path = buildRoundedSectionPolygon([
      Offset(depth, 0),
      Offset(size.width, 0),
      Offset(size.width - depth, size.height),
      Offset(0, size.height),
    ], radius: 8);
    canvas.drawPath(path, Paint()..color = const Color(0xd635526b));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_PlanPhaseCardPainter oldDelegate) => false;
}

/// 계획 화면의 예전 이름. 구현은 공용 [DiagonalScrollbar](`ui/kit/`, FE2-a)로 옮겼다.
typedef PlanDiagonalScrollbar = DiagonalScrollbar;

class _PlanLocalPathClipper extends CustomClipper<Path> {
  const _PlanLocalPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PlanLocalPathClipper oldClipper) =>
      oldClipper.path != path;
}
