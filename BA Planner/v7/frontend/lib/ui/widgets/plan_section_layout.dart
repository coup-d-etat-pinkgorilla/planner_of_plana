import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scenario_service.dart';
import '../models/planning_models.dart';
import '../studio/plan_studio_layout.dart';
import 'animated_section_stack.dart';
import 'ba_triangle_background.dart';
import 'diagonal_menu.dart' show roundedPolygonPath;
import 'diagonal_flow_indicator.dart';
import 'diagonal_media_list_item.dart';
import 'lifted_path_shadow.dart';
import 'plan_element_builder.dart';
import 'plan_phase_editor.dart';
import 'plan_preset_manager.dart';
import 'plan_student_selector.dart';
import 'plan_student_step_tile.dart';
import 'scroll_viewport_fog.dart';
import 'section_template_surface.dart';

export 'plan_student_step_tile.dart';

const planSectionOpacity = 0.76;
const planPhaseItemHeight = 65.0;
const planPhaseItemExtent = 69.0;
const planPhaseHeaderHeight = 38.0;
const planPhaseFlowGap = 20.0;
const planResourceTabHeight = 44.0;
const planResourceHeaderHeight = 94.0;
const planSection1Motion = SectionMotionSpec(intro: 0, outro: 180);
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

const planPrimaryBottleneckOwned = 42;
const planPrimaryBottleneckRequired = 60;
const planPrimaryBottleneckStudentCount = 3;
const planPrimaryBottleneckItemId = 'Item_Icon_Material_Nebra_2';
// Canonical display names follow the v6 item-id catalogs. Opart icon suffixes
// are zero-based rarity indices, while equipment TierN suffixes are 1-based.
const planPrimaryBottleneckItemName = '마모된 네브라 디스크';
const planPrimaryBottleneckIconAsset =
    'assets/item_icons/ooparts/Item_Icon_Material_Nebra_2.png';
const planPrimaryBottleneckBackgroundAsset =
    'assets/item_backgrounds/square_yellow.png';
const planPrimaryBottleneckStudentIds = {'azusa', 'nonomi', 'haruka'};
const planPhaseShortageOwned = 42;
const planPhaseShortageRequired = 60;
const planPhaseShortageNumber = 2;
const planPhaseShortageStudentCount = 4;
const planPhaseShortageCompletableCount = 1;
const planPhaseShortageItemName = '온전한 안티키테라 장치';
const planPhaseShortageIconAsset =
    'assets/item_icons/ooparts/Item_Icon_Material_Antikythera_3.png';
const planPhaseShortageBackgroundAsset =
    'assets/item_backgrounds/square_purple.png';
const planPhaseShortageStudentIds = {'yuuka'};
const planOverallProgressPercent = 72;
const planOverallShortageKindCount = 14;
const planOverallAffectedPlanCount = 6;
const planOverallAffectedStudentIds = {
  'shiroko',
  'hoshino',
  'serika',
  'haruka',
  'nonomi',
  'azusa',
};
const planBottleneckContainerScale = 0.95;
const planBottleneckContainerTopRatio = 0.025;
const planCreditIconAsset = 'assets/item_icons/currency/Currency_Icon_Gold.png';
const planBasicTacticalBdIconAsset =
    'assets/item_icons/tactical_bd/Item_Icon_Material_ExSkill_Abydos_0.png';
const planDefaultItemBackgroundAsset = 'assets/item_backgrounds/square.png';
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
        iconAsset: 'assets/equipment_icons/hairpin_t10.png',
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
        iconAsset: 'assets/equipment_icons/hairpin_t10.png',
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
        iconAsset: 'assets/equipment_icons/hat_t10.png',
        affectedStageKeys: {'phase-4:hina:2'},
        backgroundAsset: planDefaultItemBackgroundAsset,
        equipmentTier: 10,
      ),
      PlanConsumptionResourcePreview(
        id: 'phase-4-watch-t10',
        name: planWatchTier10ItemName,
        amount: 2,
        owned: 5,
        iconAsset: 'assets/equipment_icons/watch_t10.png',
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
      iconAsset: 'assets/equipment_icons/hairpin_t10.png',
      affectedStageKeys: {'phase-2:yuuka:2'},
      backgroundAsset: planDefaultItemBackgroundAsset,
      equipmentTier: 10,
    ),
    PlanConsumptionResourcePreview(
      id: 'overall-hat-t10',
      name: planHatTier10ItemName,
      amount: 4,
      owned: 1,
      iconAsset: 'assets/equipment_icons/hat_t10.png',
      affectedStageKeys: {'phase-4:hina:2'},
      backgroundAsset: planDefaultItemBackgroundAsset,
      equipmentTier: 10,
    ),
    PlanConsumptionResourcePreview(
      id: 'overall-watch-t10',
      name: planWatchTier10ItemName,
      amount: 2,
      owned: 5,
      iconAsset: 'assets/equipment_icons/watch_t10.png',
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
  final depth = bounds.height / math.tan(80 * math.pi / 180);
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
  final depth = rect.height / math.tan(80 * math.pi / 180);
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
  final depth = rect.height / math.tan(80 * math.pi / 180);
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
  final depth = rect.height / math.tan(80 * math.pi / 180);
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
  return (viewportHeight - bottomViewportY) / math.tan(80 * math.pi / 180);
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
        (viewportHeight - rowHeight) / math.tan(80 * math.pi / 180),
  );
}

class _PlanWorkspaceSnapshot {
  const _PlanWorkspaceSnapshot({
    required this.document,
    required this.elements,
    required this.phases,
    required this.drafts,
    required this.unassignedIds,
    required this.bottlenecks,
    required this.phaseConsumptions,
    required this.overallConsumption,
  });

  final PlanningDocument? document;
  final List<PlanStudentStepPreview> elements;
  final List<PlanPhasePreview> phases;
  final Map<String, List<PlanElementStageDraft>> drafts;
  final Set<String> unassignedIds;
  final List<PlanBottleneckDetailPreview> bottlenecks;
  final List<PlanConsumptionGroupPreview> phaseConsumptions;
  final PlanConsumptionGroupPreview overallConsumption;
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
  static const _motionDuration = Duration(milliseconds: 360);
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
  bool _showScenarioComparison = false;
  bool _switchingScenarioWorkspace = false;
  bool _creatingScenario = false;
  PlanningScenarioRecord? _editingScenario;
  int? _editingScenarioCollectionRevision;
  _PlanWorkspaceSnapshot? _scenarioPlanSnapshot;
  bool _usingLivePlanElements = false;
  String? _consumedHandoffId;
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
  PlanningDocument? _document;
  String? _calculationError;
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
      final results = await Future.wait([
        repository.loadRepositoryState(selected.id),
        widget.service!.listStudents(),
      ]);
      final state = results[0] as RepositoryState;
      final catalog = results[1] as List<StudentCatalogEntry>;
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
      final drafts = <String, List<PlanElementStageDraft>>{};
      final elements = <PlanStudentStepPreview>[];
      final documentStages = <PlanningDocumentStage>[];
      for (var index = 0; index < state.goals.length; index++) {
        final goal = state.goals[index];
        final current = currentById[goal.studentId];
        final targets = planningDocumentTargets(
          current: current?.values ?? const {},
          goal: goal.values,
        );
        final stageId = 'v6-${goal.studentId}-1';
        final stageName =
            goal.values['notes']?.toString().trim().isNotEmpty == true
            ? goal.values['notes'].toString().trim()
            : 'v6 목표';
        final displayName =
            catalogById[goal.studentId]?.displayName ?? goal.studentId;
        drafts[goal.studentId] = [
          PlanElementStageDraft(id: stageId, name: stageName, targets: targets),
        ];
        elements.add(
          PlanStudentStepPreview(
            studentId: goal.studentId,
            displayName: displayName,
            step: 1,
            target: stageName,
            bondRank: targets['bond_rank'],
            stageId: stageId,
            targetValues: targets,
          ),
        );
        documentStages.add(
          PlanningDocumentStage(
            id: stageId,
            studentId: goal.studentId,
            name: stageName,
            targets: targets,
          ),
        );
      }
      final document = PlanningDocument(
        id: 'active-plan',
        name: 'v6 가져온 계획',
        kind: PlanningDocumentKind.plan,
        phases: documentStages.isEmpty
            ? const []
            : [
                PlanningDocumentPhase(
                  id: 'v6-imported-plan',
                  name: 'v6 가져온 계획',
                  stages: documentStages,
                ),
              ],
      );
      if (!mounted) return;
      setState(() {
        _repositoryState = state;
        _studentSeedsById
          ..clear()
          ..addAll(seedsById);
        _document = document;
        _usingLivePlanElements = true;
        _draftsByStudent
          ..clear()
          ..addAll(drafts);
        _planElements = List.unmodifiable(elements);
        _unassignedPlanElementIds = const {};
        _planPhases = documentStages.isEmpty
            ? const []
            : [
                PlanPhasePreview(
                  id: 'v6-imported-plan',
                  name: 'v6 가져온 계획',
                  steps: elements,
                ),
              ];
        _bottleneckDetails = const [];
        _phaseConsumptions = const [];
        _overallConsumption = const PlanConsumptionGroupPreview(
          id: 'overall',
          label: '전체 계획',
          resources: [],
        );
      });
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

  String _resourceIcon(String? itemId, String category) {
    if (itemId == null || category == 'credits') return planCreditIconAsset;
    final folder = switch (category) {
      'oopart' || 'workbook' => 'ooparts',
      'tactical_bd' => 'tactical_bd',
      'tech_notes' => 'skill_db',
      'equipment' => 'equipment',
      _ => null,
    };
    return folder == null
        ? planCreditIconAsset
        : 'assets/item_icons/$folder/$itemId.png';
  }

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
      id: _creatingScenario ? _document?.id ?? 'scenario-draft' : 'active-plan',
      name: _document?.name ?? (_creatingScenario ? '새 시나리오' : '계획'),
      kind: _creatingScenario
          ? PlanningDocumentKind.scenario
          : PlanningDocumentKind.plan,
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

  void _consumeInitialSeed() {
    final seed = widget.initialSeed;
    if (seed == null || seed.handoffId == _consumedHandoffId) return;
    _consumedHandoffId = seed.handoffId;
    _builderSeed = seed;
    _studentSeedsById[seed.studentId] = seed;
    _builderStudentQueue = [seed];
    _builderStudentQueueIndex = 0;
    _showElementBuilder = true;
    _showPhaseEditor = false;
    _showPresetManager = false;
    _showStudentSelector = false;
    _showScenarioList = false;
    _showScenarioComparison = false;
    _creatingScenario = false;
  }

  void _setActive(bool active) {
    if (_showScenarioList || _showScenarioComparison) {
      for (final entry in _controllers.entries) {
        if (entry.key == 'element-1') {
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

  Future<RepositoryState?> _ensureRepositoryContext() async {
    if (_repositoryState case final state?) return state;
    final service = widget.service;
    if (service is! RepositoryService) return null;
    final repository = service as RepositoryService;
    final profiles = await repository.listProfiles();
    final selected = profiles.cast<RepositoryProfile?>().firstWhere(
      (profile) => profile?.selected == true,
      orElse: () => null,
    );
    if (selected == null) return null;
    final state = await repository.loadRepositoryState(selected.id);
    if (mounted) setState(() => _repositoryState = state);
    return state;
  }

  Future<void> _openScenarioList() async {
    await _openScenarioWorkspace(comparison: false);
  }

  Future<void> _openScenarioComparison() async {
    await _openScenarioWorkspace(comparison: true);
  }

  Future<void> _openScenarioWorkspace({required bool comparison}) async {
    if (_showScenarioList ||
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
        if (_creatingScenario) {
          await _restorePlanAfterScenarioCreation(revealPlanSections: false);
          if (!mounted) return;
        }
      }
      final state = await _ensureRepositoryContext();
      if (state == null || !mounted) return;
      await Future.wait([
        for (final entry in _controllers.entries)
          if (entry.key != 'element-1') entry.value.reverse(),
      ]);
      if (!mounted) return;
      setState(() {
        _showScenarioList = !comparison;
        _showScenarioComparison = comparison;
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
    setState(() => _switchingScenarioWorkspace = true);
    try {
      await _scenarioListController.reverse(from: 1);
      if (!mounted) return;
      setState(() {
        _showScenarioList = false;
        _showScenarioComparison = false;
      });
      await Future.wait([
        for (final entry in _controllers.entries)
          if (entry.key != 'element-1') entry.value.forward(from: 0),
      ]);
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  Future<void> _openScenarioCreation() async {
    if (_creatingScenario ||
        _showScenarioList ||
        _showScenarioComparison ||
        _switchingScenarioWorkspace ||
        widget.service is! PlanningScenarioRepositoryService) {
      return;
    }
    final state = await _ensureRepositoryContext();
    if (state == null || !mounted) return;
    final draftId = 'scenario-draft-${DateTime.now().microsecondsSinceEpoch}';
    _captureScenarioPlanSnapshot();
    setState(() {
      _creatingScenario = true;
      _builderStudentQueue = const [];
      _builderStudentQueueIndex = 0;
      _usingLivePlanElements = true;
      _draftsByStudent.clear();
      _planElements = const [];
      _unassignedPlanElementIds = const {};
      _planPhases = const [];
      _bottleneckDetails = const [];
      _phaseConsumptions = const [];
      _overallConsumption = const PlanConsumptionGroupPreview(
        id: 'overall',
        label: '전체 시나리오',
        resources: [],
      );
      _document = PlanningDocument(
        id: draftId,
        name: '새 시나리오',
        kind: PlanningDocumentKind.scenario,
        phases: const [],
      );
    });
    await _openStudentSelector();
  }

  Future<void> _restorePlanAfterScenarioCreation({
    bool revealPlanSections = true,
  }) async {
    if (!mounted) return;
    final snapshot = _scenarioPlanSnapshot;
    setState(() {
      _creatingScenario = false;
      _editingScenario = null;
      _editingScenarioCollectionRevision = null;
      _showElementBuilder = false;
      _showPhaseEditor = false;
      _showStudentSelector = false;
      _builderSeed = null;
      _builderStudentQueue = const [];
      _builderStudentQueueIndex = 0;
      if (snapshot != null) {
        _document = snapshot.document;
        _planElements = snapshot.elements;
        _planPhases = snapshot.phases;
        _draftsByStudent
          ..clear()
          ..addAll(snapshot.drafts);
        _unassignedPlanElementIds = snapshot.unassignedIds;
        _bottleneckDetails = snapshot.bottlenecks;
        _phaseConsumptions = snapshot.phaseConsumptions;
        _overallConsumption = snapshot.overallConsumption;
        _usingLivePlanElements = snapshot.elements.isNotEmpty;
      }
      _scenarioPlanSnapshot = null;
    });
    if (snapshot == null) await _loadRepositoryPlan();
    if (!mounted || !revealPlanSections) return;
    for (final controller in _controllers.values) {
      controller.forward(from: controller.value);
    }
  }

  void _captureScenarioPlanSnapshot() {
    _scenarioPlanSnapshot ??= _PlanWorkspaceSnapshot(
      document: _document,
      elements: List.unmodifiable(_planElements),
      phases: List.unmodifiable(_planPhases),
      drafts: Map.unmodifiable({
        for (final entry in _draftsByStudent.entries)
          entry.key: List.unmodifiable(entry.value),
      }),
      unassignedIds: Set.unmodifiable(_unassignedPlanElementIds),
      bottlenecks: List.unmodifiable(_bottleneckDetails),
      phaseConsumptions: List.unmodifiable(_phaseConsumptions),
      overallConsumption: _overallConsumption,
    );
  }

  Future<void> _editScenarioFromComparison(
    PlanningScenarioRecord scenario,
    int collectionRevision,
  ) async {
    if (_switchingScenarioWorkspace) return;
    setState(() => _switchingScenarioWorkspace = true);
    try {
      await _scenarioListController.reverse(from: 1);
      if (!mounted) return;
      _captureScenarioPlanSnapshot();
      final steps = <PlanStudentStepPreview>[];
      final drafts = <String, List<PlanElementStageDraft>>{};
      final phases = <PlanPhasePreview>[];
      final stepByStudent = <String, int>{};
      for (final phase in scenario.document.phases) {
        final phaseSteps = <PlanStudentStepPreview>[];
        for (final stage in phase.stages) {
          final step = (stepByStudent[stage.studentId] ?? 0) + 1;
          stepByStudent[stage.studentId] = step;
          final displayName =
              _studentSeedsById[stage.studentId]?.metadata['display_name']
                  ?.toString() ??
              stage.studentId;
          final preview = PlanStudentStepPreview(
            studentId: stage.studentId,
            displayName: displayName,
            step: step,
            target: stage.name,
            bondRank: stage.targets['bond_rank'],
            stageId: stage.id,
            targetValues: stage.targets,
          );
          steps.add(preview);
          phaseSteps.add(preview);
          drafts
              .putIfAbsent(stage.studentId, () => [])
              .add(
                PlanElementStageDraft(
                  id: stage.id,
                  name: stage.name,
                  targets: stage.targets,
                ),
              );
        }
        phases.add(
          PlanPhasePreview(id: phase.id, name: phase.name, steps: phaseSteps),
        );
      }
      setState(() {
        _showScenarioComparison = false;
        _creatingScenario = true;
        _editingScenario = scenario;
        _editingScenarioCollectionRevision = collectionRevision;
        _document = scenario.document;
        _usingLivePlanElements = true;
        _planElements = List.unmodifiable(steps);
        _planPhases = List.unmodifiable(phases);
        _draftsByStudent
          ..clear()
          ..addEntries(
            drafts.entries.map(
              (entry) => MapEntry(entry.key, List.unmodifiable(entry.value)),
            ),
          );
        _unassignedPlanElementIds = const {};
        _showPhaseEditor = true;
      });
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) setState(() => _switchingScenarioWorkspace = false);
    }
  }

  bool _targetsAtLeast(Map<String, int> candidate, Map<String, int> floor) =>
      planningDocumentTargetKeys.every(
        (key) => (candidate[key] ?? 0) >= (floor[key] ?? 0),
      );

  Future<void> _incorporateScenario(PlanningScenarioRecord scenario) async {
    final document = _document;
    if (document == null || document.kind != PlanningDocumentKind.plan) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final targetFloor = <String, Map<String, int>>{};
    final stepByStudent = <String, int>{};
    for (final stage in document.stages) {
      targetFloor[stage.studentId] = stage.targets;
      stepByStudent[stage.studentId] =
          (stepByStudent[stage.studentId] ?? 0) + 1;
    }
    final importedElements = <PlanStudentStepPreview>[];
    final importedPhases = <PlanPhasePreview>[];
    final importedDrafts = <String, List<PlanElementStageDraft>>{};
    var skipped = 0;
    for (
      var phaseIndex = 0;
      phaseIndex < scenario.document.phases.length;
      phaseIndex++
    ) {
      final sourcePhase = scenario.document.phases[phaseIndex];
      final phaseSteps = <PlanStudentStepPreview>[];
      for (
        var stageIndex = 0;
        stageIndex < sourcePhase.stages.length;
        stageIndex++
      ) {
        final source = sourcePhase.stages[stageIndex];
        final floor = targetFloor[source.studentId];
        if (floor != null && !_targetsAtLeast(source.targets, floor)) {
          skipped++;
          continue;
        }
        targetFloor[source.studentId] = source.targets;
        final step = (stepByStudent[source.studentId] ?? 0) + 1;
        stepByStudent[source.studentId] = step;
        final id = 'import-$stamp-$phaseIndex-$stageIndex';
        final displayName =
            _studentSeedsById[source.studentId]?.metadata['display_name']
                ?.toString() ??
            source.studentId;
        final preview = PlanStudentStepPreview(
          studentId: source.studentId,
          displayName: displayName,
          step: step,
          target: source.name,
          bondRank: source.targets['bond_rank'],
          stageId: id,
          targetValues: source.targets,
        );
        importedElements.add(preview);
        phaseSteps.add(preview);
        importedDrafts
            .putIfAbsent(source.studentId, () => [])
            .add(
              PlanElementStageDraft(
                id: id,
                name: source.name,
                targets: source.targets,
              ),
            );
      }
      if (phaseSteps.isNotEmpty) {
        importedPhases.add(
          PlanPhasePreview(
            id: 'import-$stamp-phase-$phaseIndex',
            name: '${scenario.name} · ${sourcePhase.name}',
            steps: phaseSteps,
          ),
        );
      }
    }
    if (importedElements.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 계획 뒤에 이어질 수 있는 성장 단계가 없습니다.')),
        );
      }
      return;
    }
    setState(() {
      _planElements = List.unmodifiable([
        ..._planElements,
        ...importedElements,
      ]);
      _planPhases = List.unmodifiable([..._planPhases, ...importedPhases]);
      for (final entry in importedDrafts.entries) {
        _draftsByStudent[entry.key] = List.unmodifiable([
          ...?_draftsByStudent[entry.key],
          ...entry.value,
        ]);
      }
      _usingLivePlanElements = true;
    });
    _rebuildDocumentFromPhases();
    await _closeScenarioList();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          skipped == 0
              ? '"${scenario.name}" 시나리오를 현재 계획에 편입했습니다.'
              : '"${scenario.name}" 시나리오를 편입했습니다. 퇴행하는 $skipped개 단계는 제외했습니다.',
        ),
      ),
    );
  }

  Future<void> _saveScenarioDraft() async {
    final service = widget.service;
    final state = _repositoryState;
    final document = _document;
    if (!_creatingScenario ||
        service is! PlanningScenarioRepositoryService ||
        state == null ||
        document == null ||
        document.phases.isEmpty) {
      return;
    }
    final scenarioRepository = service as PlanningScenarioRepositoryService;
    try {
      final list = await scenarioRepository.listScenarios(state.profileId);
      if (!mounted) return;
      var scenarioName =
          _editingScenario?.name ?? '새 시나리오 ${list.scenarios.length + 1}';
      var scenarioDescription = _editingScenario?.description ?? '';
      final result = await showDialog<(String, String)>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('plan-scenario-save-dialog'),
          title: Text(_editingScenario == null ? '시나리오 저장' : '시나리오 편집 저장'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('plan-scenario-name-field'),
                  initialValue: scenarioName,
                  onChanged: (value) => scenarioName = value,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '이름'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('plan-scenario-description-field'),
                  initialValue: scenarioDescription,
                  onChanged: (value) => scenarioDescription = value,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '설명'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const ValueKey('plan-scenario-save-confirm'),
              onPressed: () {
                final name = scenarioName.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, (
                    name,
                    scenarioDescription.trim(),
                  ));
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      );
      if (result == null) {
        await _restorePlanAfterScenarioCreation();
        return;
      }
      final savedDocument = PlanningDocument(
        id: document.id,
        name: result.$1,
        kind: PlanningDocumentKind.scenario,
        phases: document.phases,
      );
      final editing = _editingScenario;
      if (editing == null) {
        await scenarioRepository.createScenario(
          profileId: state.profileId,
          expectedRevision: list.revision,
          idempotencyKey:
              'scenario-create-${DateTime.now().microsecondsSinceEpoch}',
          name: result.$1,
          description: result.$2,
          baseProfileRevision: state.revision,
          document: savedDocument,
        );
      } else {
        await scenarioRepository.updateScenario(
          profileId: state.profileId,
          scenarioId: editing.id,
          expectedRevision: _editingScenarioCollectionRevision ?? list.revision,
          expectedScenarioRevision: editing.revision,
          idempotencyKey:
              'scenario-update-${DateTime.now().microsecondsSinceEpoch}',
          name: result.$1,
          description: result.$2,
          baseProfileRevision: state.revision,
          document: PlanningDocument(
            id: editing.document.id,
            name: result.$1,
            kind: PlanningDocumentKind.scenario,
            phases: savedDocument.phases,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${result.$1} 시나리오를 저장했습니다.')));
      await _restorePlanAfterScenarioCreation();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('시나리오 저장 실패: $error')));
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
      if (_creatingScenario) {
        await _restorePlanAfterScenarioCreation();
        return;
      }
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
    if (_creatingScenario) {
      if (_planElements.isEmpty) {
        _restorePlanAfterScenarioCreation();
      } else {
        setState(() {
          _showElementBuilder = false;
          _builderSeed = null;
          _builderStudentQueue = const [];
          _builderStudentQueueIndex = 0;
        });
        _openStudentSelector();
      }
      return;
    }
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
    if (_creatingScenario) {
      _restorePlanAfterScenarioCreation();
      return;
    }
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
    if (_creatingScenario) _saveScenarioDraft();
  }

  @override
  void dispose() {
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
        if (id == 'element-4' && _calculationError != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: CustomPaint(
                  key: ValueKey('plan-$id-foundation'),
                  painter: PlanSectionFoundationPainter(id),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '계산 오류\n$_calculationError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
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
                !_showPresetManager)
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
            if (_showScenarioList &&
                widget.service is PlanningScenarioRepositoryService &&
                _repositoryState != null)
              Positioned.fill(
                child: PlanSectionMotion(
                  key: const ValueKey('plan-scenario-list-motion'),
                  animation: _scenarioListController,
                  introDegrees: planScenarioListMotion.intro,
                  outroDegrees: planScenarioListMotion.outro,
                  child: PlanScenarioListSection(
                    service:
                        widget.service! as PlanningScenarioRepositoryService,
                    profileId: _repositoryState!.profileId,
                    currentProfileRevision: _repositoryState!.revision,
                    section1Bounds: planSectionPath(
                      size,
                      'element-1',
                    ).getBounds(),
                    active: widget.active && !_switchingScenarioWorkspace,
                  ),
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
  final depth = rect.height / math.tan(80 * math.pi / 180);
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
  });

  final Object service;
  final RepositoryState repositoryState;
  final PlanningDocument activePlan;
  final Rect section1Bounds;
  final bool active;
  final Future<void> Function(PlanningScenarioRecord, int) onEdit;
  final Future<void> Function(PlanningScenarioRecord) onIncorporate;

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

  PlanningScenarioRepositoryService get _repository =>
      widget.service as PlanningScenarioRepositoryService;
  PlanningScenarioComparisonService get _calculator =>
      widget.service as PlanningScenarioComparisonService;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _repository.listScenarios(
        widget.repositoryState.profileId,
      );
      if (!mounted) return;
      setState(() {
        _list = result;
        _error = null;
        _selectedIds.removeWhere(
          (id) =>
              id != 'active-plan' &&
              !result.scenarios.any((scenario) => scenario.id == id),
        );
      });
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
              painter: _PlanScenarioListSectionPainter(path),
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
          bottom: 62 + errorHeight,
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
                        Text(
                          '시나리오 비교',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
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
                  ? const Center(child: CircularProgressIndicator())
                  : _ComparisonCandidateDiagonalList(
                      key: const ValueKey('plan-scenario-compare-candidates'),
                      cards: [
                        _ComparisonCandidateCard(
                          key: const ValueKey(
                            'plan-compare-candidate-active-plan',
                          ),
                          label: '활성 계획',
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
            bottom: stale ? 76 : 58,
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
                    _ComparisonSideBySide(
                      left: _ComparisonStudentPane(
                        side: 'a',
                        target: targetA,
                        comparison: result.comparison,
                      ),
                      right: _ComparisonStudentPane(
                        side: 'b',
                        target: targetB,
                        comparison: result.comparison,
                      ),
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

class _ComparisonCandidateCard extends StatelessWidget {
  const _ComparisonCandidateCard({
    super.key,
    required this.label,
    required this.detail,
    required this.selectedIndex,
    required this.onTap,
    this.stale = false,
  });

  final String label;
  final String detail;
  final int selectedIndex;
  final VoidCallback onTap;
  final bool stale;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PlanScenarioListCardPainter(selectedIndex >= 0),
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
                CircleAvatar(
                  radius: 15,
                  backgroundColor: selectedIndex >= 0
                      ? AppColors.primary
                      : Colors.white12,
                  child: Text(selectedIndex < 0 ? '–' : '${selectedIndex + 1}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        detail,
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
  static const _rowHeight = 72.0;
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
      return PlanDiagonalScrollbar(
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
        bottom: 44,
        inset: 14,
      );
      final listBand = planScenarioComparisonRailBandRect(
        size,
        top: 50,
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
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
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
      return PlanDiagonalScrollbar(
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
          104,
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('크레딧 ${comparison['credits_$side'] ?? 0}'),
              Text('필요 재화 ${comparison['resource_type_count_$side'] ?? 0}종'),
              Text(
                '부족 재화 ${comparison['known_shortage_type_count_$side'] ?? 0}종',
              ),
              const Divider(height: 12),
              Text('페이즈 ${phases.length}개'),
            ],
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

class _ComparisonStudentPane extends StatelessWidget {
  const _ComparisonStudentPane({
    required this.side,
    required this.target,
    required this.comparison,
  });
  final String side;
  final _PlanComparisonTarget target;
  final Map<String, dynamic> comparison;

  @override
  Widget build(BuildContext context) {
    final rows = _comparisonRows(comparison['students']);
    return _ComparisonPaneShell(
      keyPrefix: 'plan-comparison-$side-students',
      title: target.name,
      entries: [
        for (final row in rows)
          _ComparisonPaneEntry(
            76,
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: AssetImage(
                  'assets/student_portraits/${row['student_id']}.png',
                ),
              ),
              title: Text(row['student_id']?.toString() ?? '학생'),
              subtitle: Text(
                [
                  for (final entry in Map<String, dynamic>.from(
                    row['target_differences'] as Map? ?? const {},
                  ).entries)
                    '${entry.key}: ${Map<String, dynamic>.from(entry.value as Map)[side] ?? '–'}',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (rows.isEmpty)
          const _ComparisonPaneEntry(
            52,
            Align(
              alignment: Alignment.centerLeft,
              child: Text('학생 최종 목표가 같습니다.'),
            ),
          ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    final rows = _comparisonRows(comparison['resources']);
    return _ComparisonPaneShell(
      keyPrefix: 'plan-comparison-$side-resources',
      title: target.name,
      entries: [
        for (final row in rows)
          _ComparisonPaneEntry(
            64,
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(row['display_name']?.toString() ?? '재화'),
              subtitle: Text(
                '필요 ${row['required_$side'] ?? 0} · 보유 ${row['owned'] ?? '미확인'} · 부족 ${row['shortage_$side'] ?? '미확인'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (rows.isEmpty)
          const _ComparisonPaneEntry(
            52,
            Align(alignment: Alignment.centerLeft, child: Text('필요 재화가 없습니다.')),
          ),
      ],
    );
  }
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
    final rows = _comparisonRows(
      comparison['bottlenecks'],
    ).where((row) => (row['shortage_$side'] as int? ?? 0) > 0).toList();
    return _ComparisonPaneShell(
      keyPrefix: 'plan-comparison-$side-bottlenecks',
      title: target.name,
      entries: [
        for (final row in rows)
          _ComparisonPaneEntry(
            64,
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(row['resource_key']?.toString() ?? '재화'),
              subtitle: Text(
                '최초 페이즈 ${row['first_phase_$side'] ?? '–'} · 부족 ${row['shortage_$side'] ?? 0}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (rows.isEmpty)
          const _ComparisonPaneEntry(
            52,
            Align(
              alignment: Alignment.centerLeft,
              child: Text('확인된 병목이 없습니다.'),
            ),
          ),
      ],
    );
  }
}

class PlanScenarioListSection extends StatefulWidget {
  const PlanScenarioListSection({
    super.key,
    required this.service,
    required this.profileId,
    required this.currentProfileRevision,
    required this.section1Bounds,
    required this.active,
  });

  final PlanningScenarioRepositoryService service;
  final String profileId;
  final int currentProfileRevision;
  final Rect section1Bounds;
  final bool active;

  @override
  State<PlanScenarioListSection> createState() =>
      _PlanScenarioListSectionState();
}

class _PlanScenarioListSectionState extends State<PlanScenarioListSection> {
  final ScrollController _controller = ScrollController();
  PlanningScenarioListResult? _result;
  Object? _error;
  String? _selectedScenarioId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlanScenarioListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.service.listScenarios(widget.profileId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _error = null;
        if (!result.scenarios.any(
          (scenario) => scenario.id == _selectedScenarioId,
        )) {
          _selectedScenarioId = null;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              key: const ValueKey('plan-scenario-list-foundation'),
              size: size,
              painter: _PlanScenarioListSectionPainter(path),
            ),
          ),
          Positioned.fromRect(
            rect: bounds,
            child: ClipPath(
              clipper: _PlanLocalPathClipper(localPath),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.view_list_rounded),
                        const SizedBox(width: 10),
                        Text(
                          '시나리오 리스트',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          key: const ValueKey('plan-scenario-list-refresh'),
                          onPressed: widget.active ? _load : null,
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: '새로고침',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _buildContent() {
    if (_error case final error?) {
      return Center(
        child: TextButton.icon(
          key: const ValueKey('plan-scenario-list-retry'),
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('목록을 불러오지 못했습니다.\n$error'),
        ),
      );
    }
    final result = _result;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (result.scenarios.isEmpty) {
      return const Center(
        child: Text(
          '저장된 시나리오가 없습니다.\n섹션 1의 시나리오 생성 버튼으로 시작할 수 있습니다.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const rowHeight = 142.0;
        const rowGap = 10.0;
        const inset = 8.0;
        final contentHeight =
            inset * 2 + result.scenarios.length * (rowHeight + rowGap) - rowGap;
        return PlanDiagonalScrollbar(
          keyPrefix: 'plan-scenario',
          controller: _controller,
          contentExtent: contentHeight,
          fogClipper: const PlanScenarioParallelogramClipper(),
          child: SingleChildScrollView(
            key: const ValueKey('plan-scenario-diagonal-scroll'),
            controller: _controller,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final scroll = _controller.hasClients
                    ? _controller.offset
                    : 0.0;
                return SizedBox(
                  height: contentHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (
                        var index = 0;
                        index < result.scenarios.length;
                        index++
                      )
                        () {
                          final scenario = result.scenarios[index];
                          final top = inset + index * (rowHeight + rowGap);
                          final offset = planPhaseRowHorizontalOffset(
                            viewportHeight: constraints.maxHeight,
                            rowTop: top,
                            rowHeight: rowHeight,
                            scrollOffset: scroll,
                          );
                          final width = planPhaseRowWidth(
                            viewportWidth: constraints.maxWidth,
                            viewportHeight: constraints.maxHeight,
                            rowHeight: rowHeight,
                          );
                          return Positioned(
                            key: ValueKey('plan-scenario-row-${scenario.id}'),
                            left: inset + offset,
                            top: top,
                            width: width,
                            height: rowHeight,
                            child: PlanScenarioListCard(
                              scenario: scenario,
                              stale:
                                  scenario.baseProfileRevision <
                                  result.currentProfileRevision,
                              selected: scenario.id == _selectedScenarioId,
                              onTap: widget.active
                                  ? () => setState(
                                      () => _selectedScenarioId = scenario.id,
                                    )
                                  : null,
                            ),
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
}

class PlanScenarioListCard extends StatelessWidget {
  const PlanScenarioListCard({
    super.key,
    required this.scenario,
    required this.stale,
    required this.selected,
    required this.onTap,
  });

  final PlanningScenarioSummary scenario;
  final bool stale;
  final bool selected;
  final VoidCallback? onTap;

  String _updatedLabel() {
    final parsed = DateTime.tryParse(scenario.updatedAt);
    if (parsed == null) return '수정 시각 미상';
    final local = parsed.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '수정 ${local.year}.${twoDigits(local.month)}.${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _compactAmount(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return value.toString();
  }

  String _calculationLabel() {
    final calculation = scenario.calculation;
    if (calculation == null) return '계산 요약 없음';
    final shortage = calculation.inventoryComplete
        ? '부족 ${calculation.knownShortageTypeCount}종'
        : '부족 ${calculation.knownShortageTypeCount}종 · 일부 재고 미확인';
    final bottleneck = calculation.firstBottleneckPhaseNumber == null
        ? '병목 없음'
        : '최초 병목 페이즈 ${calculation.firstBottleneckPhaseNumber}';
    return '크레딧 ${_compactAmount(calculation.credits)} · $shortage · $bottleneck';
  }

  String? _shortageIconAsset(PlanningScenarioRepresentativeShortage shortage) {
    final itemId = shortage.itemId;
    if (itemId == null || shortage.category == 'credits') {
      return shortage.category == 'credits' ? planCreditIconAsset : null;
    }
    final folder = switch (shortage.category) {
      'oopart' || 'workbook' => 'ooparts',
      'tactical_bd' => 'tactical_bd',
      'tech_notes' => 'skill_db',
      'equipment' => 'equipment',
      _ => null,
    };
    return folder == null ? null : 'assets/item_icons/$folder/$itemId.png';
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PlanScenarioListCardPainter(selected),
    child: ClipPath(
      key: ValueKey('plan-scenario-card-clip-${scenario.id}'),
      clipper: const PlanScenarioParallelogramClipper(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.analytics_outlined,
                  color: selected ? AppColors.primary : Colors.white70,
                ),
                const SizedBox(width: 10),
                _ScenarioStudentPortraits(
                  scenarioId: scenario.id,
                  studentIds: scenario.studentIds,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        scenario.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (scenario.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          scenario.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        '학생 ${scenario.studentCount} · 페이즈 ${scenario.phaseCount} · 성장 단계 ${scenario.stageCount}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _calculationLabel(),
                        key: ValueKey(
                          'plan-scenario-calculation-${scenario.id}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              scenario.calculation?.inventoryComplete == false
                              ? Colors.amberAccent
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: stale
                          ? '저장 시점보다 프로필이 변경되었습니다. 요약은 현재 데이터로 다시 계산되었습니다.'
                          : '현재 계정 데이터를 기준으로 저장되었습니다.',
                      child: Container(
                        key: ValueKey('plan-scenario-status-${scenario.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stale
                              ? Colors.amber.withValues(alpha: 0.16)
                              : AppColors.primary.withValues(alpha: 0.16),
                          border: Border.all(
                            color: stale
                                ? Colors.amberAccent
                                : AppColors.primary,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              stale
                                  ? Icons.history_rounded
                                  : Icons.check_rounded,
                              size: 14,
                              color: stale
                                  ? Colors.amberAccent
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              stale ? '저장 시점과 다름' : '현재 데이터 기준',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (scenario.calculation?.representativeShortage
                        case final shortage?) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_shortageIconAsset(shortage) case final asset?)
                            Image.asset(
                              asset,
                              key: ValueKey(
                                'plan-scenario-shortage-icon-${scenario.id}',
                              ),
                              width: 22,
                              height: 22,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: Colors.amberAccent,
                              ),
                            )
                          else
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                              color: Colors.amberAccent,
                            ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              '${shortage.displayName} −${_compactAmount(shortage.shortage)}',
                              key: ValueKey(
                                'plan-scenario-shortage-${scenario.id}',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.amberAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      _updatedLabel(),
                      key: ValueKey('plan-scenario-updated-${scenario.id}'),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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

class _PlanScenarioListSectionPainter extends CustomPainter {
  const _PlanScenarioListSectionPainter(this.path);
  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path, Paint()..color = const Color(0xf01a2c3b));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_PlanScenarioListSectionPainter oldDelegate) =>
      oldDelegate.path.getBounds() != path.getBounds();
}

double planScenarioParallelogramDepth(double height) =>
    height / math.tan(80 * math.pi / 180);

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
  const _PlanScenarioListCardPainter(this.selected);
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final path = planScenarioParallelogramPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? AppColors.primary.withValues(alpha: 0.22)
            : const Color(0xd9264359),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? AppColors.primary
            : AppColors.outline.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 0.8,
    );
  }

  @override
  bool shouldRepaint(_PlanScenarioListCardPainter oldDelegate) =>
      oldDelegate.selected != selected;
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
              constraints.maxHeight / math.tan(80 * math.pi / 180) + 8;
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
    final depth = size.height / math.tan(80 * math.pi / 180);
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
  });

  final PlanResourceView selected;
  final ValueChanged<PlanResourceView> onSelected;
  final Set<String> highlightedStudentIds;
  final ValueChanged<Set<String>> onHighlightStudents;

  @override
  State<PlanResourceHeader> createState() => _PlanResourceHeaderState();
}

class _PlanResourceHeaderState extends State<PlanResourceHeader> {
  bool _isHighlighted(Set<String> studentIds) =>
      widget.highlightedStudentIds.length == studentIds.length &&
      widget.highlightedStudentIds.every(studentIds.contains);

  void _toggle(Set<String> studentIds) => widget.onHighlightStudents(
    _isHighlighted(studentIds) ? const {} : studentIds,
  );

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
                    highlighted: _isHighlighted(
                      planPrimaryBottleneckStudentIds,
                    ),
                    onTap: () => _toggle(planPrimaryBottleneckStudentIds),
                  ),
                  PlanResourceView.byPhase => PlanPhaseResourceSummary(
                    highlighted: _isHighlighted(planPhaseShortageStudentIds),
                    onTap: () => _toggle(planPhaseShortageStudentIds),
                  ),
                  PlanResourceView.overall => PlanOverallResourceSummary(
                    highlighted: _isHighlighted(planOverallAffectedStudentIds),
                    onTap: () => _toggle(planOverallAffectedStudentIds),
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

class PlanPrimaryBottleneckSummary extends StatelessWidget {
  const PlanPrimaryBottleneckSummary({
    super.key,
    required this.highlighted,
    required this.onTap,
  });

  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PlanResourceItemSummary(
    keyPrefix: 'plan-primary-bottleneck',
    semanticsLabel: '가장 심한 병목 요소, $planPrimaryBottleneckItemName',
    kicker: '가장 심한 병목 요소',
    quantity:
        '보유량 : $planPrimaryBottleneckOwned / '
        '필요량 : $planPrimaryBottleneckRequired',
    detail:
        '확보 시 학생 $planPrimaryBottleneckStudentCount명의 '
        '목표 단계가 가능해집니다',
    backgroundAsset: planPrimaryBottleneckBackgroundAsset,
    iconAsset: planPrimaryBottleneckIconAsset,
    highlighted: highlighted,
    onTap: onTap,
  );
}

class PlanPhaseResourceSummary extends StatelessWidget {
  const PlanPhaseResourceSummary({
    super.key,
    required this.highlighted,
    required this.onTap,
  });

  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PlanResourceItemSummary(
    keyPrefix: 'plan-phase-shortage',
    semanticsLabel: '가장 부족한 재화, $planPhaseShortageItemName',
    kicker: '가장 부족한 재화',
    quantity:
        '보유량 : $planPhaseShortageOwned / '
        '필요량 : $planPhaseShortageRequired',
    detail:
        '$planPhaseShortageNumber단계에서 '
        '$planPhaseShortageStudentCount명 중 '
        '$planPhaseShortageCompletableCount명만 완료 가능',
    backgroundAsset: planPhaseShortageBackgroundAsset,
    iconAsset: planPhaseShortageIconAsset,
    highlighted: highlighted,
    onTap: onTap,
  );
}

class PlanOverallResourceSummary extends StatelessWidget {
  const PlanOverallResourceSummary({
    super.key,
    required this.highlighted,
    required this.onTap,
  });

  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 52;
      return Semantics(
        label:
            '전체 요구량의 $planOverallProgressPercent% 확보, '
            '$planOverallShortageKindCount종 부족, '
            '$planOverallAffectedPlanCount명의 성장 계획에 영향',
        button: true,
        selected: highlighted,
        child: Material(
          key: const ValueKey('plan-overall-summary'),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('plan-overall-action'),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '전체 요구량의 $planOverallProgressPercent% 확보',
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
                    '$planOverallShortageKindCount종 부족 · '
                    '$planOverallAffectedPlanCount명의 성장 계획에 영향',
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
            ),
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
  final String iconAsset;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
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
  final curved = Curves.easeInOutCubic.transform(
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
    final path = planSectionPath(size, sectionId);
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.surface.withValues(alpha: planSectionOpacity)
        ..style = PaintingStyle.fill,
    );
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
      return PlanDiagonalScrollbar(
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
      longControlHeight / math.tan(80 * math.pi / 180) -
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
      return PlanDiagonalScrollbar(
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
                    painter: _PlanInventoryCoveragePainter(ratio),
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

class _PlanInventoryCoveragePainter extends CustomPainter {
  const _PlanInventoryCoveragePainter(this.ratio);

  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(track, Paint()..color = const Color(0x324F7090));
    final fillWidth = size.width * ratio.clamp(0, 1);
    if (fillWidth <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, fillWidth, size.height),
        Radius.circular(size.height / 2),
      ),
      Paint()..color = diagonalMediaHighlightColor,
    );
  }

  @override
  bool shouldRepaint(_PlanInventoryCoveragePainter oldDelegate) =>
      oldDelegate.ratio != ratio;
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
    final depth = size.height / math.tan(80 * math.pi / 180);
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
    final depth = size.height / math.tan(80 * math.pi / 180);
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
    final depth = size.height / math.tan(80 * math.pi / 180);
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
      return PlanDiagonalScrollbar(
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
  final depth = size.height / math.tan(80 * math.pi / 180);
  return depth * (1 - y / size.height);
}

double planPhaseRightBoundary(Size size, double y) {
  final depth = size.height / math.tan(80 * math.pi / 180);
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
    final depth = size.height / math.tan(80 * math.pi / 180);
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

class PlanDiagonalScrollbar extends StatelessWidget {
  const PlanDiagonalScrollbar({
    super.key,
    this.keyPrefix = 'plan-phase',
    required this.controller,
    required this.contentExtent,
    required this.child,
    this.fogClipper,
  });

  final String keyPrefix;
  final ScrollController controller;
  final double contentExtent;
  final Widget child;
  final CustomClipper<Path>? fogClipper;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final size = constraints.biggest;
          final hasClients = controller.hasClients;
          final maxScroll = hasClients
              ? controller.position.maxScrollExtent
              : math.max(0.0, contentExtent - size.height);
          final viewport = hasClients
              ? controller.position.viewportDimension
              : size.height;
          final offset = hasClients ? controller.offset : 0.0;
          final fogVisibility = scrollViewportFogVisibility(
            minScrollExtent: hasClients
                ? controller.position.minScrollExtent
                : 0.0,
            maxScrollExtent: maxScroll,
            pixels: offset,
          );
          const trackInset = 10.0;
          final trackHeight = math.max(1.0, size.height - trackInset * 2);
          final handleHeight = maxScroll <= 0
              ? trackHeight
              : math.max(28.0, trackHeight * viewport / (viewport + maxScroll));
          final travel = math.max(1.0, trackHeight - handleHeight);
          final handleTop =
              trackInset +
              travel *
                  (maxScroll <= 0 ? 0 : (offset / maxScroll).clamp(0.0, 1.0));
          final handleCenter = planScrollbarTrackPoint(
            size,
            handleTop + handleHeight / 2,
            trackInset: trackInset,
          );
          final trajectoryDepth = size.height / math.tan(80 * math.pi / 180);
          return Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned.fill(
                child: fogClipper == null
                    ? ScrollViewportFog(
                        key: ValueKey('$keyPrefix-fog'),
                        keyPrefix: '$keyPrefix-viewport-fog',
                        showTop: fogVisibility.showTop,
                        showBottom: fogVisibility.showBottom,
                      )
                    : ClipPath(
                        key: ValueKey('$keyPrefix-fog-clip'),
                        clipper: fogClipper,
                        child: ScrollViewportFog(
                          key: ValueKey('$keyPrefix-fog'),
                          keyPrefix: '$keyPrefix-viewport-fog',
                          showTop: fogVisibility.showTop,
                          showBottom: fogVisibility.showBottom,
                        ),
                      ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: ValueKey('$keyPrefix-diagonal-scrollbar'),
                    painter: _PlanDiagonalScrollbarPainter(
                      offset: offset,
                      maxScrollExtent: maxScroll,
                      handleHeight: handleHeight,
                      trackInset: trackInset,
                    ),
                  ),
                ),
              ),
              Positioned(
                key: ValueKey('$keyPrefix-scrollbar-handle-center'),
                left: handleCenter.dx - 0.5,
                top: handleCenter.dy - 0.5,
                width: 1,
                height: 1,
                child: const IgnorePointer(),
              ),
              if (maxScroll > 0)
                Positioned(
                  left: math.max(0, size.width - trajectoryDepth - 24),
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    key: ValueKey('$keyPrefix-scrollbar-drag'),
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) {
                      controller.jumpTo(
                        (controller.offset +
                                details.delta.dy * maxScroll / travel)
                            .clamp(0.0, maxScroll),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

Offset planScrollbarTrackPoint(Size size, double y, {double trackInset = 10}) {
  final depth = size.height / math.tan(80 * math.pi / 180);
  final clampedY = y.clamp(0.0, size.height);
  return Offset(
    size.width -
        trackInset -
        depth +
        (size.height - clampedY) / math.tan(80 * math.pi / 180),
    clampedY,
  );
}

class _PlanDiagonalScrollbarPainter extends CustomPainter {
  const _PlanDiagonalScrollbarPainter({
    required this.offset,
    required this.maxScrollExtent,
    required this.handleHeight,
    required this.trackInset,
  });

  final double offset;
  final double maxScrollExtent;
  final double handleHeight;
  final double trackInset;

  Path _segment(Size size, double top, double bottom) {
    final start = planScrollbarTrackPoint(size, top, trackInset: trackInset);
    final end = planScrollbarTrackPoint(size, bottom, trackInset: trackInset);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trackBottom = size.height - trackInset;
    canvas.drawPath(
      _segment(size, trackInset, trackBottom),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.outline.withValues(alpha: 0.48),
    );
    if (maxScrollExtent <= 0) return;
    final travel = math.max(0.0, trackBottom - trackInset - handleHeight);
    final top =
        trackInset + travel * (offset / maxScrollExtent).clamp(0.0, 1.0);
    canvas.drawPath(
      _segment(size, top, top + handleHeight),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xffe5a0ea),
    );
  }

  @override
  bool shouldRepaint(_PlanDiagonalScrollbarPainter oldDelegate) =>
      oldDelegate.offset != offset ||
      oldDelegate.maxScrollExtent != maxScrollExtent ||
      oldDelegate.handleHeight != handleHeight ||
      oldDelegate.trackInset != trackInset;
}

class _PlanLocalPathClipper extends CustomClipper<Path> {
  const _PlanLocalPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PlanLocalPathClipper oldClipper) =>
      oldClipper.path != path;
}
