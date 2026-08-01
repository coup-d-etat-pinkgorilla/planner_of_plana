import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/planning_models.dart';
import '../studio/plan_studio_layout.dart';
import 'animated_section_stack.dart';
import 'ba_triangle_background.dart';
import 'diagonal_media_list_item.dart';
import 'lifted_path_shadow.dart';
import 'plan_element_builder.dart';
import 'plan_phase_editor.dart';
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
    this.backgroundAsset,
    this.equipmentTier,
  });

  final String id;
  final String name;
  final int amount;
  final int owned;
  final String iconAsset;
  final Set<String> affectedStageKeys;
  final String? backgroundAsset;
  final int? equipmentTier;

  String get displayName =>
      equipmentTier == null ? name : '$name (T$equipmentTier)';

  bool get isBottleneck => amount > owned;

  int get endingAmount => owned - amount;

  int get shortageAmount => math.max(0, -endingAmount);

  double get coverageRatio => amount <= 0 ? 1 : (owned / amount).clamp(0, 1);

  int get coveragePercent => (coverageRatio * 100).round();

  String get balanceDisplay =>
      isBottleneck ? '부족 ${formatPlanAmount(shortageAmount)}' : '충족';

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

class PlanSectionLayout extends StatefulWidget {
  const PlanSectionLayout({super.key, this.active = true, this.initialSeed});

  final bool active;
  final PlanningStudentSeed? initialSeed;

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
  bool _usingLivePlanElements = false;
  String? _consumedHandoffId;
  PlanningStudentSeed? _builderSeed;
  final Map<String, List<PlanElementStageDraft>> _draftsByStudent = {};
  List<PlanStudentStepPreview> _planElements = const [];
  Set<String> _unassignedPlanElementIds = const {};
  List<PlanPhasePreview> _planPhases = dummyPlanPhases;
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

  @override
  void initState() {
    super.initState();
    _consumeInitialSeed();
    if (widget.active) _setActive(true);
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
    _showElementBuilder = true;
    _showPhaseEditor = false;
  }

  void _setActive(bool active) {
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
    });
    if (!_showElementBuilder) {
      for (final entry in _controllers.entries) {
        if (entry.key != 'element-2') entry.value.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
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
        dummyPlanBottleneckDetails,
        categories: _selectedResourceCategories,
        sort: _resourceSort,
      );
      final phaseConsumptions = filterPlanConsumptionGroups(
        dummyPlanPhaseConsumptions,
        categories: _selectedResourceCategories,
        hideSatisfied: _hideSatisfiedResources,
        sort: _resourceSort,
      );
      final overallConsumptions = filterPlanConsumptionGroups(
        const [dummyPlanOverallConsumption],
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
                top: bounds.top + bounds.height * 0.34,
                width: math.max(120, bounds.width * 0.54),
                height: 58,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('plan-phase-editor-launch'),
                  onPressed: _openPhaseEditor,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text(
                    '페이즈 만들기',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
            if (!_showPhaseEditor && !_showElementBuilder)
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
                  onConfirm: _confirmPlanElementStages,
                  onRenameUnassigned: _renameUnassignedPlanElement,
                  onOpenPhaseEditor: _openPhaseEditor,
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
          ],
        ),
      );
    },
  );
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
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
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
        ? '보유 ${formatPlanAmount(resource.owned)}, '
              '필요 ${formatPlanAmount(resource.amount)}, ${resource.coveragePercent}%, '
              '${resource.balanceDisplay}'
        : '진입 ${formatPlanAmount(resource.owned)}, '
              '필요 ${formatPlanAmount(resource.amount)}, '
              '종료 ${formatPlanAmount(resource.endingAmount)}, ${resource.balanceDisplay}',
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
                            '보유 ${formatPlanAmount(resource.owned)} / '
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
                                  '진입 ${formatPlanAmount(resource.owned)}  │ '
                                  '필요 ${formatPlanAmount(resource.amount)} │ '
                                  '종료 ${formatPlanAmount(resource.endingAmount)}',
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
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
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
          '보유 ${formatPlanAmount(resource.owned)} / '
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
          scale: scale,
        ),
        SizedBox(height: 6 * scale),
      ] else ...[
        Text(
          '진입 ${formatPlanAmount(resource.owned)}  │ '
          '필요 ${formatPlanAmount(resource.amount)} │ '
          '종료 ${formatPlanAmount(resource.endingAmount)}',
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
    this.scale = 1,
    this.compact = false,
  });

  final double ratio;
  final int percent;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '확보율 $percent%',
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
              '$percent%',
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
                      child: const _PlanPhaseFlowIndicator(),
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

class _PlanPhaseFlowIndicator extends StatelessWidget {
  const _PlanPhaseFlowIndicator();

  @override
  Widget build(BuildContext context) => const Center(
    child: CustomPaint(
      key: ValueKey('plan-phase-flow-triangle'),
      size: Size(16, 10),
      painter: _PlanPhaseFlowIndicatorPainter(),
    ),
  );
}

class _PlanPhaseFlowIndicatorPainter extends CustomPainter {
  const _PlanPhaseFlowIndicatorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = const Color(0xfff2b3ef).withValues(alpha: 0.88),
    );
  }

  @override
  bool shouldRepaint(_PlanPhaseFlowIndicatorPainter oldDelegate) => false;
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
  });

  final String keyPrefix;
  final ScrollController controller;
  final double contentExtent;
  final Widget child;

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
                child: ScrollViewportFog(
                  key: ValueKey('$keyPrefix-fog'),
                  keyPrefix: '$keyPrefix-viewport-fog',
                  showTop: fogVisibility.showTop,
                  showBottom: fogVisibility.showBottom,
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
