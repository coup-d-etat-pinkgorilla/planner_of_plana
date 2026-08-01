import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'diagonal_media_list_item.dart';

enum PlanBottleneckFocusField { title, skills, equipment1 }

@immutable
class PlanStudentStepPreview {
  const PlanStudentStepPreview({
    required this.studentId,
    required this.displayName,
    required this.step,
    required this.target,
    this.bondRank,
    this.stageId,
    this.targetValues = const {},
  });

  final String studentId;
  final String displayName;
  final int step;
  final String target;
  final int? bondRank;
  final String? stageId;
  final Map<String, int> targetValues;

  PlanStudentStepPreview copyWith({
    String? displayName,
    int? step,
    String? target,
    int? bondRank,
    String? stageId,
    Map<String, int>? targetValues,
  }) => PlanStudentStepPreview(
    studentId: studentId,
    displayName: displayName ?? this.displayName,
    step: step ?? this.step,
    target: target ?? this.target,
    bondRank: bondRank ?? this.bondRank,
    stageId: stageId ?? this.stageId,
    targetValues: targetValues ?? this.targetValues,
  );
}

/// Reusable adapter from a plan student step to the shared diagonal media row.
///
/// Other tabs can import this file directly without depending on the complete
/// plan-section layout implementation.
class PlanStudentStepTile extends StatelessWidget {
  const PlanStudentStepTile({
    super.key,
    required this.order,
    required this.step,
    this.highlighted = false,
    this.bottleneckField,
    this.owned = true,
    this.onTap,
    this.currentStudentState = false,
    this.planned = false,
    this.jpOnly = false,
  });

  final int order;
  final PlanStudentStepPreview step;
  final bool highlighted;
  final PlanBottleneckFocusField? bottleneckField;
  final bool owned;
  final VoidCallback? onTap;
  final bool currentStudentState;
  final bool planned;
  final bool jpOnly;

  @override
  Widget build(BuildContext context) {
    final stage = step.step;
    final live = step.targetValues.isNotEmpty;
    int target(String key, int fallback) => step.targetValues[key] ?? fallback;
    final bondRank = target('bond_rank', step.bondRank ?? 10 + stage * 5);
    return DiagonalMediaListItem(
      highlighted: highlighted,
      onTap: onTap,
      currentStudentState: currentStudentState,
      data: DiagonalMediaListItemData(
        order: order,
        mediaAssetPath: 'assets/student_portraits/${step.studentId}.png',
        title: currentStudentState
            ? step.displayName
            : live
            ? '${step.displayName} · ${step.target}'
            : '${step.displayName} · ${step.step}단계',
        studentStars: target('student_star', math.min(5, 2 + stage)),
        weaponStars: target('weapon_star', math.min(4, stage)),
        studentStarDelta: live ? null : 1,
        weaponStarDelta: live
            ? null
            : stage == 1
            ? null
            : 1,
        studentLevel: DiagonalMediaValue(
          'Lv.${target('level', 40 + stage * 15)}',
          delta: live ? null : 10 + stage * 5,
        ),
        weaponLevel: DiagonalMediaValue(
          'Lv.${target('weapon_level', 20 + stage * 10)}',
          delta: live ? null : 10,
        ),
        skills: DiagonalMediaValue(
          '${target('ex_skill', stage + 2)}/${target('skill1', stage + 3)}/'
          '${target('skill2', stage + 3)}/${target('skill3', stage + 3)}',
          componentDeltas: live ? const [] : [null, null, null, stage + 1],
        ),
        equipment: [
          DiagonalMediaEquipment(
            assetPath: 'assets/equipment_icons/hat_t10.png',
            tier: DiagonalMediaValue(
              'T${target('equip1_tier', stage + 4)}',
              delta: live
                  ? null
                  : stage == 1
                  ? null
                  : 1,
            ),
            level: DiagonalMediaValue(
              'Lv.${target('equip1_level', 20 + stage * 5)}',
              delta: live
                  ? null
                  : stage == 1
                  ? null
                  : 5,
            ),
          ),
          DiagonalMediaEquipment(
            assetPath: 'assets/equipment_icons/hairpin_t10.png',
            tier: DiagonalMediaValue(
              'T${target('equip2_tier', stage + 3)}',
              delta: live
                  ? null
                  : stage == 1
                  ? null
                  : 1,
            ),
            level: DiagonalMediaValue(
              'Lv.${target('equip2_level', 15 + stage * 5)}',
              delta: live
                  ? null
                  : stage == 1
                  ? null
                  : 5,
            ),
          ),
          DiagonalMediaEquipment(
            assetPath: 'assets/equipment_icons/watch_t10.png',
            tier: DiagonalMediaValue(
              'T${target('equip3_tier', stage + 2)}',
              delta: live
                  ? null
                  : stage == 1
                  ? -1
                  : 1,
            ),
            level: DiagonalMediaValue(
              'Lv.${target('equip3_level', 10 + stage * 5)}',
              delta: live
                  ? null
                  : stage == 1
                  ? null
                  : 5,
            ),
          ),
        ],
        favoriteItem: DiagonalMediaValue(
          'T${target('equip4_tier', math.min(2, stage))}',
          delta: live
              ? null
              : stage == 1
              ? null
              : 1,
        ),
        bondRank: DiagonalMediaValue(
          '$bondRank',
          delta: bondRank >= 100 ? null : 2,
        ),
        stats: DiagonalMediaValue(
          '${target('stat_hp', 20 + stage * 5)}/'
          '${target('stat_atk', 18 + stage * 4)}/'
          '${target('stat_heal', 15 + stage * 3)}',
          componentDeltas: live ? const [] : [null, stage, stage * 2],
        ),
        titleColor: bottleneckField == PlanBottleneckFocusField.title
            ? diagonalMediaHighlightColor
            : null,
        skillsColor: bottleneckField == PlanBottleneckFocusField.skills
            ? diagonalMediaHighlightColor
            : null,
        equipmentValueColors: [
          bottleneckField == PlanBottleneckFocusField.equipment1
              ? diagonalMediaHighlightColor
              : null,
        ],
        owned: owned,
        planned: planned,
        jpOnly: jpOnly,
      ),
    );
  }
}
