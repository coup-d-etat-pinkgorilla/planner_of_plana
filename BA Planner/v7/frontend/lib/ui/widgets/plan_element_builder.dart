import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../models/planning_models.dart';
import '../studio/plan_starter_studio_layout.dart';
import '../studio/preset_element_studio_layout.dart';
import '../studio/section_template.dart';
import 'ba_triangle_background.dart';
import 'lifted_path_shadow.dart';
import 'section_template_surface.dart';
import 'student_section_layout.dart';

const planElementBuilderSectionOpacity = 0.76;
const planElementBuilderGap = 12.0;
const planElementBuilderCardGap = 14.0;

const planElementTargetMaximums = <String, int>{
  'level': 90,
  'bond_rank': 100,
  'student_star': 5,
  'weapon_level': 60,
  'weapon_star': 4,
  'ex_skill': 5,
  'skill1': 10,
  'skill2': 10,
  'skill3': 10,
  'equip1_tier': 10,
  'equip2_tier': 10,
  'equip3_tier': 10,
  'equip1_level': 70,
  'equip2_level': 70,
  'equip3_level': 70,
  'equip4_tier': 2,
  'stat_hp': 25,
  'stat_atk': 25,
  'stat_heal': 25,
};

const planElementTargetMinimums = <String, int>{
  'level': 1,
  'bond_rank': 1,
  'student_star': 1,
  'weapon_level': 0,
  'weapon_star': 0,
  'ex_skill': 1,
  'skill1': 1,
  'skill2': 1,
  'skill3': 1,
  'equip1_tier': 0,
  'equip2_tier': 0,
  'equip3_tier': 0,
  'equip1_level': 0,
  'equip2_level': 0,
  'equip3_level': 0,
  'equip4_tier': 0,
  'stat_hp': 0,
  'stat_atk': 0,
  'stat_heal': 0,
};

final defaultPlanElementPresets = <PlanElementPreset>[
  PlanElementPreset(
    id: 'balanced-growth',
    name: '균형 육성',
    isDefault: true,
    stages: const [
      {
        'level': 50,
        'student_star': 3,
        'ex_skill': 3,
        'skill1': 4,
        'skill2': 4,
        'skill3': 4,
        'equip1_tier': 4,
        'equip2_tier': 4,
        'equip3_tier': 4,
      },
      {
        'level': 70,
        'student_star': 4,
        'weapon_star': 1,
        'weapon_level': 30,
        'ex_skill': 5,
        'skill1': 7,
        'skill2': 7,
        'skill3': 7,
        'equip1_tier': 6,
        'equip2_tier': 6,
        'equip3_tier': 6,
      },
      {
        'level': 90,
        'student_star': 5,
        'weapon_star': 2,
        'weapon_level': 50,
        'ex_skill': 5,
        'skill1': 10,
        'skill2': 10,
        'skill3': 10,
        'equip1_tier': 10,
        'equip2_tier': 10,
        'equip3_tier': 10,
      },
    ],
  ),
  PlanElementPreset(
    id: 'maximum-growth',
    name: '최대 육성',
    isDefault: false,
    stages: const [
      {
        'level': 90,
        'bond_rank': 100,
        'student_star': 5,
        'weapon_star': 4,
        'weapon_level': 60,
        'ex_skill': 5,
        'skill1': 10,
        'skill2': 10,
        'skill3': 10,
        'equip1_tier': 10,
        'equip2_tier': 10,
        'equip3_tier': 10,
        'equip1_level': 70,
        'equip2_level': 70,
        'equip3_level': 70,
        'equip4_tier': 2,
        'stat_hp': 25,
        'stat_atk': 25,
        'stat_heal': 25,
      },
    ],
  ),
];

Map<String, int> planElementCurrentTargets(PlanningStudentSeed seed) {
  int value(String key, int fallback) {
    final raw = seed.currentValues[key];
    return raw is int ? raw : fallback;
  }

  int equipmentTier(String key) {
    final raw = seed.currentValues[key];
    if (raw is int) return raw;
    final match = RegExp(r'(\d+)').firstMatch(raw?.toString() ?? '');
    return match == null ? 0 : int.parse(match.group(1)!);
  }

  int initialStar() {
    final raw = seed.metadata['rarity'];
    final match = RegExp(r'(\d+)').firstMatch(raw?.toString() ?? '');
    return match == null ? 1 : int.parse(match.group(1)!).clamp(1, 5);
  }

  if (!seed.owned) {
    return {
      'level': 1,
      'bond_rank': 1,
      'student_star': initialStar(),
      'weapon_level': 0,
      'weapon_star': 0,
      'ex_skill': 1,
      'skill1': 1,
      'skill2': 1,
      'skill3': 1,
      'equip1_tier': 0,
      'equip2_tier': 0,
      'equip3_tier': 0,
      'equip1_level': 0,
      'equip2_level': 0,
      'equip3_level': 0,
      'equip4_tier': 0,
      'stat_hp': 0,
      'stat_atk': 0,
      'stat_heal': 0,
    };
  }
  return {
    'level': value('level', 1),
    'bond_rank': value('bond_rank', 1),
    'student_star': value('student_star', 1),
    'weapon_level': value('weapon_level', 0),
    'weapon_star': value('weapon_star', 0),
    'ex_skill': value('ex_skill', 1),
    'skill1': value('skill1', 1),
    'skill2': value('skill2', 1),
    'skill3': value('skill3', 1),
    'equip1_tier': equipmentTier('equip1'),
    'equip2_tier': equipmentTier('equip2'),
    'equip3_tier': equipmentTier('equip3'),
    'equip1_level': value('equip1_level', 0),
    'equip2_level': value('equip2_level', 0),
    'equip3_level': value('equip3_level', 0),
    'equip4_tier': equipmentTier('equip4'),
    'stat_hp': value('stat_hp', 0),
    'stat_atk': value('stat_atk', 0),
    'stat_heal': value('stat_heal', 0),
  };
}

String planElementTargetSummary(Map<String, int> target) {
  final skillText =
      '${target['ex_skill']}/${target['skill1']}/${target['skill2']}/${target['skill3']}';
  final equipmentText =
      'T${target['equip1_tier']}/T${target['equip2_tier']}/T${target['equip3_tier']}';
  return 'Lv.${target['level']} · ★${target['student_star']} · '
      '전무 ${target['weapon_star']} · 스킬 $skillText · $equipmentText';
}

Path planStarterSectionPath(Size size, String id) {
  final section = planStarterStudioDocument.elements.firstWhere(
    (element) => element.id == id,
  );
  return buildSectionCanvasElementPath(size, section);
}

Rect planStarterSectionRect(Size size, String id) {
  final section = planStarterStudioDocument.elements.firstWhere(
    (element) => element.id == id,
  );
  return sectionCanvasElementRect(size, section);
}

StudioContainerElement planStarterContainer(String id) =>
    planStarterStudioDocument.containers.firstWhere(
      (container) => container.id == id,
    );

Path planStarterContainerPath(Size size, String id) => buildStudioContainerPath(
  size,
  planStarterStudioDocument.elements,
  planStarterContainer(id),
)!;

StudioFeatureElement planStarterFeature(String id) => planStarterStudioDocument
    .features
    .firstWhere((feature) => feature.id == id);

Path planStarterFeaturePath(Size size, String id) => buildStudioFeaturePath(
  size,
  planStarterStudioDocument.elements,
  planStarterStudioDocument.containers,
  planStarterFeature(id),
)!;

SectionCanvasElement planPresetElement(String id) => presetElementStudioDocument
    .elements
    .firstWhere((element) => element.id == id);

Rect planPresetElementRect(Size size, String id) {
  final rect = planPresetElement(id).rect;
  final bounds = presetElementReferenceBounds;
  return Rect.fromLTWH(
    (rect.x - bounds.x) * size.width / bounds.width,
    (rect.y - bounds.y) * size.height / bounds.height,
    rect.width * size.width / bounds.width,
    rect.height * size.height / bounds.height,
  );
}

Path planPresetElementLocalPath(Size size, String id) {
  final element = planPresetElement(id);
  assert(element.spec.mode == SectionShapeMode.parallelogram);
  assert(element.spec.face == SectionAttachmentFace.bottom);
  final requestedDepth =
      size.height * element.spec.height / sectionTemplateGridSize;
  final cut = sectionTemplateCutDepth(requestedDepth);
  final sourceSize = Size(math.max(1, size.width - cut), size.height);
  return buildRoundedSectionPolygon(
    buildAttachedSectionPolygon(sourceSize, element.spec),
    radius: math.min(9, size.shortestSide * 0.22),
  );
}

Path planPresetElementPath(Size size, String id) {
  final rect = planPresetElementRect(size, id);
  return planPresetElementLocalPath(rect.size, id).shift(rect.topLeft);
}

Path planPresetElementUnionPath(Size size) {
  var union = Path();
  for (final element in presetElementStudioDocument.elements) {
    union = Path.combine(
      PathOperation.union,
      union,
      planPresetElementPath(size, element.id),
    );
  }
  return union;
}

class PlanElementBuilder extends StatefulWidget {
  const PlanElementBuilder({
    super.key,
    required this.seed,
    required this.unassignedItems,
    required this.hasPlanElements,
    required this.onConfirm,
    required this.onRenameUnassigned,
    required this.onOpenPhaseEditor,
    this.initialStages = const [],
    this.presets,
  });

  final PlanningStudentSeed seed;
  final List<PlanElementStageDraft> initialStages;
  final List<PlanElementUnassignedItem> unassignedItems;
  final bool hasPlanElements;
  final List<PlanElementPreset>? presets;
  final ValueChanged<List<PlanElementStageDraft>> onConfirm;
  final void Function(String id, String name) onRenameUnassigned;
  final VoidCallback onOpenPhaseEditor;

  @override
  State<PlanElementBuilder> createState() => _PlanElementBuilderState();
}

@immutable
class PlanElementUnassignedItem {
  const PlanElementUnassignedItem({
    required this.id,
    required this.studentId,
    required this.displayName,
    required this.stageNumber,
    required this.stageName,
    required this.targetSummary,
  });

  final String id;
  final String studentId;
  final String displayName;
  final int stageNumber;
  final String stageName;
  final String targetSummary;
}

class _PlanElementBuilderState extends State<PlanElementBuilder> {
  late List<PlanElementStageDraft> _stages;
  String? _selectedStageId;
  String? _selectedPresetId;
  int _nextStageId = 1;
  final Set<String> _propagatedFields = {};
  Timer? _propagationTimer;

  Map<String, int> get _current => planElementCurrentTargets(widget.seed);
  List<PlanElementPreset> get _presets =>
      widget.presets ?? defaultPlanElementPresets;

  @override
  void initState() {
    super.initState();
    _resetFromInitial();
  }

  @override
  void didUpdateWidget(PlanElementBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed.handoffId != widget.seed.handoffId) {
      _resetFromInitial();
    }
  }

  @override
  void dispose() {
    _propagationTimer?.cancel();
    super.dispose();
  }

  void _resetFromInitial() {
    _nextStageId = 1;
    _stages = widget.initialStages.isEmpty
        ? [
            PlanElementStageDraft(
              id: _newStageId(),
              name: '1단계',
              targets: _current,
            ),
          ]
        : [
            for (final stage in widget.initialStages)
              stage.copyWith(targets: Map<String, int>.from(stage.targets)),
          ];
    final usedStageIds = _stages.map((stage) => stage.id).toSet();
    while (usedStageIds.contains(
      '${widget.seed.studentId}-stage-$_nextStageId',
    )) {
      _nextStageId += 1;
    }
    _selectedStageId = _stages.firstOrNull?.id;
    _selectedPresetId = null;
  }

  String _newStageId() => '${widget.seed.studentId}-stage-${_nextStageId++}';

  int get _selectedIndex =>
      _stages.indexWhere((stage) => stage.id == _selectedStageId);

  void _addStage() {
    final selectedIndex = _selectedIndex;
    final source = selectedIndex >= 0
        ? _stages[selectedIndex]
        : _stages.isEmpty
        ? null
        : _stages.last;
    final insertIndex = selectedIndex >= 0 ? selectedIndex + 1 : _stages.length;
    final stage = PlanElementStageDraft(
      id: _newStageId(),
      name: '${insertIndex + 1}단계',
      targets: source?.targets ?? _current,
    );
    setState(() {
      _stages.insert(insertIndex, stage);
      _renumberDefaultNames();
      _selectedStageId = stage.id;
    });
  }

  void _removeSelectedStage() {
    final index = _selectedIndex;
    if (index < 0 || _stages.length <= 1) return;
    setState(() {
      _stages.removeAt(index);
      _renumberDefaultNames();
      _selectedStageId = _stages[math.max(0, index - 1)].id;
    });
  }

  void _renumberDefaultNames() {
    for (var index = 0; index < _stages.length; index++) {
      final name = _stages[index].name;
      if (RegExp(r'^\d+단계$').hasMatch(name)) {
        _stages[index] = _stages[index].copyWith(name: '${index + 1}단계');
      }
    }
  }

  void _resetDraft() {
    setState(() {
      _stages = [
        PlanElementStageDraft(
          id: _newStageId(),
          name: '1단계',
          targets: _current,
        ),
      ];
      _selectedStageId = _stages.first.id;
      _selectedPresetId = null;
    });
  }

  void _loadPreset(PlanElementPreset preset) {
    var previous = Map<String, int>.from(_current);
    final next = <PlanElementStageDraft>[];
    for (final sparse in preset.stages) {
      final expanded = {...previous};
      for (final entry in sparse.entries) {
        expanded[entry.key] = math.max(
          previous[entry.key] ?? planElementTargetMinimums[entry.key] ?? 0,
          entry.value,
        );
      }
      final effective = {
        for (final entry in expanded.entries)
          entry.key: math.max(entry.value, _current[entry.key] ?? entry.value),
      };
      if (_hasIncreaseOver(effective, previous)) {
        next.add(
          PlanElementStageDraft(
            id: _newStageId(),
            name: '${next.length + 1}단계',
            targets: effective,
          ),
        );
        previous = effective;
      }
    }
    setState(() {
      _selectedPresetId = preset.id;
      _stages = next.isEmpty
          ? [
              PlanElementStageDraft(
                id: _newStageId(),
                name: '1단계',
                targets: _current,
              ),
            ]
          : next;
      _selectedStageId = _stages.first.id;
    });
  }

  bool _hasIncreaseOver(Map<String, int> target, Map<String, int> baseline) =>
      target.entries.any(
        (entry) => entry.value > (baseline[entry.key] ?? entry.value),
      );

  void _setTarget(int stageIndex, String key, int requested) {
    final contractMinimum = planElementTargetMinimums[key] ?? 0;
    final previous = stageIndex == 0
        ? _current[key] ?? contractMinimum
        : _stages[stageIndex - 1].targets[key] ?? contractMinimum;
    final minimum = math.max(contractMinimum, previous);
    final maximum = planElementTargetMaximums[key] ?? requested;
    final value = requested.clamp(minimum, maximum);
    final propagated = <String>{};
    setState(() {
      final selectedTargets = Map<String, int>.from(
        _stages[stageIndex].targets,
      );
      selectedTargets[key] = value;
      _stages[stageIndex] = _stages[stageIndex].copyWith(
        targets: selectedTargets,
      );
      for (var index = stageIndex + 1; index < _stages.length; index++) {
        if ((_stages[index].targets[key] ?? minimum) >= value) continue;
        final targets = Map<String, int>.from(_stages[index].targets);
        targets[key] = value;
        _stages[index] = _stages[index].copyWith(targets: targets);
        propagated.add('${_stages[index].id}:$key');
      }
      _propagatedFields
        ..clear()
        ..addAll(propagated);
    });
    _propagationTimer?.cancel();
    _propagationTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(_propagatedFields.clear);
    });
  }

  void _confirm() {
    final effective = <PlanElementStageDraft>[];
    var baseline = _current;
    for (final stage in _stages) {
      if (_hasIncreaseOver(stage.targets, baseline)) {
        effective.add(stage);
        baseline = stage.targets;
      }
    }
    if (effective.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('현재 상태보다 높은 목표를 하나 이상 설정하세요.')),
      );
      return;
    }
    widget.onConfirm(List.unmodifiable(effective));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final id in const [
              'element-3',
              'element-5',
              'element-7',
              'element-6',
            ])
              Positioned.fill(
                child: _PlanStarterSection(
                  key: ValueKey('plan-starter-$id'),
                  path: planStarterSectionPath(size, id),
                  child: switch (id) {
                    'element-3' => _buildStudentStatus(size),
                    'element-5' => _buildPresetPanel(size),
                    'element-6' => _buildStageEditor(size),
                    'element-7' => _buildUnassignedSection(size),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _buildStudentStatus(Size canvasSize) {
    final displayName =
        widget.seed.metadata['display_name']?.toString() ??
        widget.seed.studentId;
    final current = _current;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('plan-starter-student-status-foundation'),
            painter: _PlanStudentStatusFoundationPainter(
              canvasSize: canvasSize,
              studentStars: current['student_star'] ?? 0,
              weaponStars: current['weapon_star'] ?? 0,
            ),
          ),
        ),
        _statusContainer(
          canvasSize,
          'container-1',
          _PlanStudentPortrait(
            portraitAsset:
                'assets/student_portraits/${widget.seed.studentId}.png',
          ),
        ),
        _statusFeature(
          canvasSize,
          'feature-2',
          _PlanStudentLevelHeader(
            displayName: displayName,
            level: current['level'],
            schoolLogoAsset: studentSchoolLogoAsset(
              widget.seed.metadata['school']?.toString(),
            ),
          ),
        ),
        _statusFeature(
          canvasSize,
          'feature-5',
          _PlanWeaponLevelStatus(
            level: current['weapon_level'],
            unlocked: (current['weapon_star'] ?? 0) > 0,
          ),
        ),
        _statusContainer(
          canvasSize,
          'container-5',
          StudentSkillStatus(
            values: [
              _skillDisplay(current['ex_skill'], 5),
              _skillDisplay(current['skill1'], 10),
              _skillDisplay(current['skill2'], 10),
              _skillDisplay(current['skill3'], 10),
            ],
          ),
        ),
        _statusContainer(
          canvasSize,
          'container-6',
          StudentEquipmentStatus(
            student: null,
            equipmentTypes: [
              widget.seed.metadata['equipment_slot_1']?.toString(),
              widget.seed.metadata['equipment_slot_2']?.toString(),
              widget.seed.metadata['equipment_slot_3']?.toString(),
            ],
            tiers: [
              _equipmentTierDisplay(current['equip1_tier']),
              _equipmentTierDisplay(current['equip2_tier']),
              _equipmentTierDisplay(current['equip3_tier']),
            ],
            levels: [
              current['equip1_level'],
              current['equip2_level'],
              current['equip3_level'],
            ],
            favoriteItem: _equipmentTierDisplay(current['equip4_tier']),
            favoriteItemLocked: (current['equip4_tier'] ?? 0) == 0,
          ),
        ),
        _statusContainer(
          canvasSize,
          'container-7',
          StudentAbilityStatus(
            hp: current['stat_hp'],
            atk: current['stat_atk'],
            heal: current['stat_heal'],
          ),
        ),
        _statusContainer(
          canvasSize,
          'container-9',
          const StudentPotentialStatus(),
        ),
        _statusBondContainer(canvasSize, 'container-8', current['bond_rank']),
      ],
    );
  }

  Widget _statusContainer(
    Size canvasSize,
    String id,
    Widget child, {
    bool foreground = false,
  }) {
    final path = planStarterContainerPath(canvasSize, id);
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      key: ValueKey('plan-starter-status-$id'),
      rect: bounds,
      child: ClipPath(
        clipper: _FixedPathClipper(localPath),
        child: ColoredBox(
          color: foreground
              ? AppColors.surfaceRaised.withValues(alpha: 0.96)
              : Colors.transparent,
          child: CustomPaint(
            foregroundPainter: _LocalPathBorderPainter(localPath),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _statusFeature(Size canvasSize, String id, Widget child) {
    final path = planStarterFeaturePath(canvasSize, id);
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      key: ValueKey('plan-starter-status-$id'),
      rect: bounds,
      child: ClipPath(
        clipper: _FixedPathClipper(localPath),
        child: CustomPaint(
          foregroundPainter: _LocalPathBorderPainter(localPath),
          child: child,
        ),
      ),
    );
  }

  Widget _statusBondContainer(Size canvasSize, String id, int? rank) {
    final path = planStarterContainerPath(canvasSize, id);
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      key: ValueKey('plan-starter-status-$id'),
      rect: bounds,
      child: ClipPath(
        clipper: _FixedPathClipper(localPath),
        child: ColoredBox(
          color: AppColors.surfaceRaised.withValues(alpha: 0.96),
          child: CustomPaint(
            foregroundPainter: _LocalPathBorderPainter(localPath),
            child: StudentBondStatus(bondRank: rank, outerPath: localPath),
          ),
        ),
      ),
    );
  }

  String _skillDisplay(int? value, int maximum) {
    if (value == null) return '-';
    return value >= maximum ? 'M' : '$value';
  }

  String _equipmentTierDisplay(int? value) =>
      value == null || value <= 0 ? '-' : 'T$value';

  Widget _buildPresetPanel(Size canvasSize) {
    final bounds = planStarterSectionRect(canvasSize, 'element-5');
    return Stack(
      children: [
        Positioned.fromRect(
          rect: bounds,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 44, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '프리셋 불러오기',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                for (final preset in _presets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: OutlinedButton(
                      key: ValueKey('plan-starter-preset-${preset.id}'),
                      onPressed: () => _loadPreset(preset),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        foregroundColor: _selectedPresetId == preset.id
                            ? AppColors.primary
                            : AppColors.text,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(preset.name)),
                          if (preset.isDefault)
                            const Text(
                              '기본',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_presets.isEmpty)
                  const Text(
                    '저장된 프리셋이 없습니다.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStageEditor(Size canvasSize) {
    final bounds = planStarterSectionRect(canvasSize, 'element-6');
    const controlHeight = 62.0;
    final diagonalInset = math
        .max(0, (bounds.height - 520) / math.tan(80 * math.pi / 180))
        .clamp(0.0, bounds.width * 0.28)
        .toDouble();
    final contentRect = Rect.fromLTRB(
      bounds.left + 12 + diagonalInset,
      bounds.top + 12,
      bounds.right - 12,
      bounds.bottom - controlHeight - 20,
    );
    return Stack(
      children: [
        Positioned.fromRect(
          rect: contentRect,
          child: ClipRect(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ListView.separated(
                key: const ValueKey('plan-starter-stage-scroll'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _stages.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: planElementBuilderCardGap),
                itemBuilder: (context, index) {
                  final stage = _stages[index];
                  return _PlanPresetElementCard(
                    key: ValueKey('plan-starter-stage-${stage.id}'),
                    stage: stage,
                    stageNumber: index + 1,
                    selected: stage.id == _selectedStageId,
                    propagatedFields: _propagatedFields,
                    onSelected: () =>
                        setState(() => _selectedStageId = stage.id),
                    onChanged: (key, value) => _setTarget(index, key, value),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          left: bounds.left + 14,
          right: canvasSize.width - bounds.right + 14,
          bottom: canvasSize.height - bounds.bottom + 10,
          height: controlHeight,
          child: _BuilderControls(
            canRemove: _stages.length > 1,
            onAdd: _addStage,
            onRemove: _removeSelectedStage,
            onReset: _resetDraft,
            onConfirm: _confirm,
          ),
        ),
      ],
    );
  }

  Widget _buildUnassignedSection(Size canvasSize) {
    final bounds = planStarterSectionRect(canvasSize, 'element-7');
    final listRect = Rect.fromLTRB(
      bounds.left + 14,
      bounds.top + 16,
      bounds.left + bounds.width * 0.64,
      bounds.bottom - 16,
    );
    final buttonRect = Rect.fromLTRB(
      listRect.right + 12,
      bounds.top + bounds.height * 0.40,
      bounds.right - 14,
      bounds.top + bounds.height * 0.58,
    );
    return Stack(
      children: [
        Positioned.fromRect(
          rect: listRect,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '미배정 계획 요소',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${widget.unassignedItems.length}',
                    key: const ValueKey('plan-starter-unassigned-count'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: widget.unassignedItems.isEmpty
                    ? const Center(
                        child: Text(
                          '미배정 요소가 없습니다.',
                          key: ValueKey('plan-starter-unassigned-empty'),
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: ListView.separated(
                          key: const ValueKey('plan-starter-unassigned-scroll'),
                          itemCount: widget.unassignedItems.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 7),
                          itemBuilder: (context, index) {
                            final item = widget.unassignedItems[index];
                            return _UnassignedPlanElementRow(
                              item: item,
                              onRename: (name) =>
                                  widget.onRenameUnassigned(item.id, name),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
        Positioned.fromRect(
          rect: buttonRect,
          child: Tooltip(
            message: widget.hasPlanElements ? '페이즈 구성 열기' : '계획 요소를 먼저 만드세요',
            child: FilledButton(
              key: const ValueKey('plan-starter-open-phase-editor'),
              onPressed: widget.hasPlanElements
                  ? widget.onOpenPhaseEditor
                  : null,
              child: const Icon(Icons.account_tree_outlined),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanStudentLevelHeader extends StatelessWidget {
  const _PlanStudentLevelHeader({
    required this.displayName,
    required this.level,
    required this.schoolLogoAsset,
  });

  final String displayName;
  final int? level;
  final String? schoolLogoAsset;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final headerHeight = (constraints.maxHeight * 0.24).clamp(15.0, 23.0);
      return Column(
        children: [
          SizedBox(
            height: headerHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 8, 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      key: const ValueKey('plan-starter-student-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontFamily: 'GyeonggiTitle',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Tooltip(
                    message: '인연 랭크 필요 아이템 메타데이터 미연결',
                    child: Row(
                      key: ValueKey('plan-starter-bond-metadata-header'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 2),
                        Text(
                          '인연 비용 미연결',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StudentLevelStatus(
              level: level,
              schoolLogoAsset: schoolLogoAsset,
            ),
          ),
        ],
      );
    },
  );
}

class _PlanWeaponLevelStatus extends StatelessWidget {
  const _PlanWeaponLevelStatus({required this.level, required this.unlocked});

  final int? level;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final railInset = constraints.maxHeight / math.tan(80 * math.pi / 180);
      return Padding(
        padding: EdgeInsets.fromLTRB(railInset + 8, 2, railInset + 8, 2),
        child: Row(
          children: [
            const Text(
              'WEAPON',
              style: TextStyle(
                color: AppColors.primary,
                fontFamily: 'GyeonggiTitle',
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                unlocked ? 'Lv. ${level ?? '--'}' : 'Lv. --',
                key: const ValueKey('plan-starter-weapon-level'),
                style: const TextStyle(
                  color: AppColors.text,
                  fontFamily: 'GyeonggiTitle',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PlanStudentPortrait extends StatelessWidget {
  const _PlanStudentPortrait({required this.portraitAsset});

  final String portraitAsset;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/item_backgrounds/square.png', fit: BoxFit.cover),
      Padding(
        padding: const EdgeInsets.all(3),
        child: Image.asset(
          portraitAsset,
          key: const ValueKey('plan-starter-student-portrait'),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.person_outline, size: 54),
        ),
      ),
    ],
  );
}

class _PlanStudentStatusFoundationPainter extends CustomPainter {
  const _PlanStudentStatusFoundationPainter({
    required this.canvasSize,
    required this.studentStars,
    required this.weaponStars,
  });

  final Size canvasSize;
  final int studentStars;
  final int weaponStars;

  @override
  void paint(Canvas canvas, Size size) {
    final containers = planStarterStudioDocument.containers.where(
      (container) => container.parentSectionId == 'element-3',
    );
    for (final container in containers) {
      final path = planStarterContainerPath(canvasSize, container.id);
      if (container.triangleTexture) {
        canvas.save();
        canvas.clipPath(path, doAntiAlias: true);
        BATriangleTexturePainter(_planElementTexture).paint(canvas, size);
        canvas.restore();
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.surfaceRaised.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.outline.withValues(alpha: 0.74)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
    for (final feature in planStarterStudioDocument.features) {
      if (feature.parentContainerId != 'container-2') continue;
      final path = planStarterFeaturePath(canvasSize, feature.id);
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xff203243).withValues(alpha: 0.98),
      );
    }
    _paintStarIndicator(canvas);
  }

  void _paintStarIndicator(Canvas canvas) {
    final bounds = planStarterContainerPath(
      canvasSize,
      'container-3',
    ).getBounds();
    final gap = math.max(1.2, bounds.width * 0.006);
    final segmentWidth = (bounds.width - gap * 8) / 9;
    for (var index = 0; index < 9; index++) {
      final rect = Rect.fromLTWH(
        bounds.left + index * (segmentWidth + gap),
        bounds.top,
        segmentWidth,
        bounds.height,
      );
      final active = index < 5 ? index < studentStars : index - 5 < weaponStars;
      canvas.drawPath(
        studentStarSegmentPath(rect),
        Paint()
          ..color = active
              ? (index < 5 ? const Color(0xfff3c96b) : AppColors.primary)
                    .withValues(alpha: 0.86)
              : AppColors.outline.withValues(alpha: 0.48),
      );
    }
  }

  @override
  bool shouldRepaint(_PlanStudentStatusFoundationPainter oldDelegate) =>
      oldDelegate.canvasSize != canvasSize ||
      oldDelegate.studentStars != studentStars ||
      oldDelegate.weaponStars != weaponStars;
}

class _LocalPathBorderPainter extends CustomPainter {
  const _LocalPathBorderPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.74)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(_LocalPathBorderPainter oldDelegate) =>
      oldDelegate.path != path;
}

class _PlanStarterSection extends StatelessWidget {
  const _PlanStarterSection({
    super.key,
    required this.path,
    required this.child,
  });

  final Path path;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        child: CustomPaint(painter: _PlanStarterFoundationPainter(path)),
      ),
      ClipPath(clipper: _FixedPathClipper(path), child: child),
    ],
  );
}

class _PlanStarterFoundationPainter extends CustomPainter {
  const _PlanStarterFoundationPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(_planElementTexture).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanStarterFoundationPainter oldDelegate) =>
      oldDelegate.path != path;
}

class _PlanPresetElementCard extends StatelessWidget {
  const _PlanPresetElementCard({
    super.key,
    required this.stage,
    required this.stageNumber,
    required this.selected,
    required this.propagatedFields,
    required this.onSelected,
    required this.onChanged,
  });

  final PlanElementStageDraft stage;
  final int stageNumber;
  final bool selected;
  final Set<String> propagatedFields;
  final VoidCallback onSelected;
  final void Function(String key, int value) onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height =
          width *
          presetElementReferenceBounds.height /
          presetElementReferenceBounds.width;
      final size = Size(width, height);
      final unionPath = planPresetElementUnionPath(size);
      return SizedBox(
        height: height,
        child: ClipPath(
          clipper: _FixedPathClipper(unionPath),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onSelected,
              child: CustomPaint(
                foregroundPainter: _CardBorderPainter(
                  unionPath,
                  selected: selected,
                ),
                child: Stack(
                  children: [
                    _surface(
                      size,
                      'element-5',
                      color: selected
                          ? AppColors.surfaceRaised.withValues(alpha: 0.98)
                          : AppColors.surfaceRaised.withValues(alpha: 0.88),
                      child: Align(
                        alignment: const Alignment(-0.82, -0.92),
                        child: Text(
                          '$stageNumber',
                          key: ValueKey('plan-stage-$stageNumber-number'),
                          style: AppTextStyles.planPhaseNumber,
                        ),
                      ),
                    ),
                    _surface(
                      size,
                      'element-1',
                      child: _PresetRegionContent(
                        title: '학생 레벨',
                        children: [_stepper('Lv', 'level')],
                      ),
                    ),
                    _surface(
                      size,
                      'element-2',
                      child: _PresetRegionContent(
                        title: '전용무기 레벨',
                        children: [_stepper('Lv', 'weapon_level')],
                      ),
                    ),
                    _surface(
                      size,
                      'element-3',
                      child: _PresetRegionContent(
                        title: '인연 랭크',
                        compact: true,
                        children: [
                          _stepper('R', 'bond_rank', unsupported: true),
                        ],
                      ),
                    ),
                    _surface(
                      size,
                      'element-4',
                      child: _StarTargetStrip(
                        stageNumber: stageNumber,
                        studentStar: _target('student_star'),
                        weaponStar: _target('weapon_star'),
                        studentPropagated: _propagated('student_star'),
                        weaponPropagated: _propagated('weapon_star'),
                        onChanged: onChanged,
                        interactive: false,
                      ),
                    ),
                    _surface(
                      size,
                      'element-6',
                      child: _PresetRegionContent(
                        title: '스킬 레벨',
                        children: [
                          _stepper('EX', 'ex_skill'),
                          _stepper('기본', 'skill1'),
                          _stepper('강화', 'skill2'),
                          _stepper('서브', 'skill3'),
                        ],
                      ),
                    ),
                    _surface(
                      size,
                      'element-7',
                      child: _PresetRegionContent(
                        title: '장비 상태',
                        children: [
                          _stepper('1T', 'equip1_tier'),
                          _stepper('1L', 'equip1_level'),
                          _stepper('2T', 'equip2_tier'),
                          _stepper('2L', 'equip2_level'),
                          _stepper('3T', 'equip3_tier'),
                          _stepper('3L', 'equip3_level'),
                          _stepper('애장품', 'equip4_tier'),
                        ],
                      ),
                    ),
                    _surface(
                      size,
                      'element-8',
                      child: _PresetRegionContent(
                        title: '추가 능력치',
                        compact: true,
                        children: [
                          _stepper('HP', 'stat_hp'),
                          _stepper('공격', 'stat_atk'),
                          _stepper('치유', 'stat_heal'),
                        ],
                      ),
                    ),
                    _surface(
                      size,
                      'element-9',
                      color: Colors.black.withValues(alpha: 0.34),
                      child: const _LockedTargetRegion(),
                    ),
                    _starHitSurface(size),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  int _target(String key) =>
      stage.targets[key] ?? planElementTargetMinimums[key] ?? 0;

  bool _propagated(String key) => propagatedFields.contains('${stage.id}:$key');

  Widget _surface(Size size, String id, {required Widget child, Color? color}) {
    final rect = planPresetElementRect(size, id);
    final localPath = planPresetElementLocalPath(rect.size, id);
    return Positioned.fromRect(
      rect: rect,
      child: KeyedSubtree(
        key: ValueKey('plan-preset-element-$stageNumber-$id'),
        child: ClipPath(
          clipper: _FixedPathClipper(localPath),
          child: ColoredBox(
            color:
                color ??
                const Color(
                  0xff30485f,
                ).withValues(alpha: selected ? 0.82 : 0.68),
            child: CustomPaint(
              foregroundPainter: _CardBorderPainter(localPath, selected: false),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _starHitSurface(Size size) {
    final visibleRect = planPresetElementRect(size, 'element-4');
    final hitHeight = math.max(28.0, visibleRect.height);
    final rect = Rect.fromCenter(
      center: visibleRect.center,
      width: visibleRect.width,
      height: hitHeight,
    );
    return Positioned.fromRect(
      rect: rect,
      child: _StarTargetStrip(
        stageNumber: stageNumber,
        studentStar: _target('student_star'),
        weaponStar: _target('weapon_star'),
        studentPropagated: _propagated('student_star'),
        weaponPropagated: _propagated('weapon_star'),
        onChanged: onChanged,
        interactive: true,
        cutReferenceHeight: visibleRect.height,
      ),
    );
  }

  Widget _stepper(String label, String key, {bool unsupported = false}) =>
      _CompactTargetStepper(
        key: ValueKey('plan-stage-$stageNumber-$key'),
        label: label,
        value: stage.targets[key] ?? planElementTargetMinimums[key] ?? 0,
        minimum: planElementTargetMinimums[key] ?? 0,
        maximum: planElementTargetMaximums[key] ?? 99,
        propagated: propagatedFields.contains('${stage.id}:$key'),
        unsupported: unsupported,
        onChanged: (value) => onChanged(key, value),
      );
}

class _PresetRegionContent extends StatelessWidget {
  const _PresetRegionContent({
    required this.title,
    required this.children,
    this.compact = false,
  });

  final String title;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cutInset = constraints.maxHeight / math.tan(80 * math.pi / 180);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          cutInset + 1.5,
          compact ? 2 : 6,
          cutInset + 1.5,
          compact ? 2 : 5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: _titleStyle),
            SizedBox(height: compact ? 1 : 4),
            Expanded(
              child: Wrap(
                spacing: compact ? 4 : 7,
                runSpacing: compact ? 1 : 5,
                alignment: compact
                    ? WrapAlignment.end
                    : WrapAlignment.spaceBetween,
                children: children,
              ),
            ),
          ],
        ),
      );
    },
  );

  static const _titleStyle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );
}

class _StarTargetStrip extends StatelessWidget {
  const _StarTargetStrip({
    required this.stageNumber,
    required this.studentStar,
    required this.weaponStar,
    required this.studentPropagated,
    required this.weaponPropagated,
    required this.onChanged,
    required this.interactive,
    this.cutReferenceHeight,
  });

  final int stageNumber;
  final int studentStar;
  final int weaponStar;
  final bool studentPropagated;
  final bool weaponPropagated;
  final void Function(String key, int value) onChanged;
  final bool interactive;
  final double? cutReferenceHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cutInset =
          (cutReferenceHeight ?? constraints.maxHeight) /
          math.tan(80 * math.pi / 180);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: cutInset + 3),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: _segments(
                keyPrefix: 'plan-stage-$stageNumber-student-star',
                count: 5,
                value: studentStar,
                propagated: studentPropagated,
                onSelected: (value) => onChanged('student_star', value),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              flex: 4,
              child: _segments(
                keyPrefix: 'plan-stage-$stageNumber-weapon-star',
                count: 4,
                value: weaponStar,
                propagated: weaponPropagated,
                onSelected: (value) => onChanged('weapon_star', value),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _segments({
    required String keyPrefix,
    required int count,
    required int value,
    required bool propagated,
    required ValueChanged<int> onSelected,
  }) => Row(
    children: [
      for (var index = 1; index <= count; index++)
        Expanded(
          child: _segment(
            index,
            count,
            value,
            propagated,
            keyPrefix,
            onSelected,
          ),
        ),
    ],
  );

  Widget _segment(
    int index,
    int count,
    int value,
    bool propagated,
    String keyPrefix,
    ValueChanged<int> onSelected,
  ) {
    final visible = Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      color: interactive
          ? Colors.transparent
          : propagated
          ? AppColors.primary.withValues(alpha: 0.30)
          : index <= value
          ? AppColors.primary.withValues(alpha: 0.78)
          : AppColors.outline.withValues(alpha: 0.22),
    );
    if (!interactive) return visible;
    return Semantics(
      button: true,
      selected: index == value,
      label: '${count == 5 ? '학생' : '전용무기'} 성급 $index',
      child: InkResponse(
        key: ValueKey('$keyPrefix-$index'),
        onTap: () => onSelected(index),
        radius: 14,
        child: visible,
      ),
    );
  }
}

class _LockedTargetRegion extends StatelessWidget {
  const _LockedTargetRegion();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cutInset = constraints.maxHeight / math.tan(80 * math.pi / 180);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: cutInset + 6),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text(
              '심상개화 · 준비 중',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      );
    },
  );
}

class _CompactTargetStepper extends StatelessWidget {
  const _CompactTargetStepper({
    super.key,
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.propagated,
    required this.unsupported,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final bool propagated;
  final bool unsupported;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final controlKey = key is ValueKey<String>
        ? (key! as ValueKey<String>).value
        : label;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: propagated
            ? AppColors.primary.withValues(alpha: 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkResponse(
            key: ValueKey('$controlKey-decrease'),
            onTap: value > minimum ? () => onChanged(value - 1) : null,
            radius: 11,
            child: const SizedBox(
              width: 18,
              height: 22,
              child: Icon(Icons.remove, size: 11),
            ),
          ),
          const SizedBox(width: 1),
          Text(
            '$label $value${unsupported ? '*' : ''}',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 1),
          InkResponse(
            key: ValueKey('$controlKey-increase'),
            onTap: value < maximum ? () => onChanged(value + 1) : null,
            radius: 11,
            child: const SizedBox(
              width: 18,
              height: 22,
              child: Icon(Icons.add, size: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuilderControls extends StatelessWidget {
  const _BuilderControls({
    required this.canRemove,
    required this.onAdd,
    required this.onRemove,
    required this.onReset,
    required this.onConfirm,
  });

  final bool canRemove;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onReset;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _iconButton(
          key: const ValueKey('plan-starter-add-stage'),
          tooltip: '단계 추가',
          icon: Icons.add_rounded,
          onPressed: onAdd,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _iconButton(
          key: const ValueKey('plan-starter-remove-stage'),
          tooltip: '선택 단계 삭제',
          icon: Icons.remove_rounded,
          onPressed: canRemove ? onRemove : null,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _iconButton(
          key: const ValueKey('plan-starter-reset'),
          tooltip: '현재 상태로 초기화',
          icon: Icons.restart_alt_rounded,
          onPressed: onReset,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _iconButton(
          key: const ValueKey('plan-starter-confirm'),
          tooltip: '계획 요소 확정',
          icon: Icons.check_rounded,
          onPressed: onConfirm,
        ),
      ),
    ],
  );

  Widget _iconButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => Tooltip(
    message: tooltip,
    child: FilledButton(
      key: key,
      onPressed: onPressed,
      child: Icon(icon, size: 20),
    ),
  );
}

class _UnassignedPlanElementRow extends StatefulWidget {
  const _UnassignedPlanElementRow({required this.item, required this.onRename});

  final PlanElementUnassignedItem item;
  final ValueChanged<String> onRename;

  @override
  State<_UnassignedPlanElementRow> createState() =>
      _UnassignedPlanElementRowState();
}

class _UnassignedPlanElementRowState extends State<_UnassignedPlanElementRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.item.stageName,
  );

  @override
  void didUpdateWidget(_UnassignedPlanElementRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.stageName != widget.item.stageName &&
        _controller.text != widget.item.stageName) {
      _controller.text = widget.item.stageName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final name = _controller.text.trim();
    widget.onRename(name.isEmpty ? widget.item.stageName : name);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 66,
    child: ClipPath(
      clipper: _FixedPathClipper(
        _bilateralPath(const Size(260, 66), radius: 7),
        scaleToSize: true,
      ),
      child: ColoredBox(
        color: AppColors.surfaceRaised.withValues(alpha: 0.92),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: ValueKey('plan-unassigned-name-${widget.item.id}'),
                controller: _controller,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _commit(),
                onTapOutside: (_) {
                  _commit();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              ),
              Text(
                widget.item.targetSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Path _bilateralPath(Size size, {double radius = 9}) {
  final depth = size.height / math.tan(80 * math.pi / 180);
  return buildRoundedSectionPolygon([
    Offset(depth, 0),
    Offset(size.width, 0),
    Offset(size.width - depth, size.height),
    Offset(0, size.height),
  ], radius: radius);
}

class _FixedPathClipper extends CustomClipper<Path> {
  const _FixedPathClipper(this.path, {this.scaleToSize = false});

  final Path path;
  final bool scaleToSize;

  @override
  Path getClip(Size size) {
    if (!scaleToSize) return path;
    final bounds = path.getBounds();
    final matrix = Matrix4.identity()
      ..scaleByDouble(
        size.width / bounds.width,
        size.height / bounds.height,
        1,
        1,
      );
    return path.transform(matrix.storage);
  }

  @override
  bool shouldReclip(_FixedPathClipper oldDelegate) =>
      oldDelegate.path != path || oldDelegate.scaleToSize != scaleToSize;
}

class _CardBorderPainter extends CustomPainter {
  const _CardBorderPainter(this.path, {required this.selected});

  final Path path;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 0.9
        ..color = selected
            ? AppColors.primary
            : AppColors.outline.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(_CardBorderPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.selected != selected;
}

const _planElementTexture = BATriangleTextureConfig(
  baseColor: Color(0xff263747),
  panelColor: AppColors.surfaceRaised,
  softColor: Color(0xff8295a6),
  accentColor: AppColors.primaryMuted,
  triangleSize: 76,
  tessellationContrast: 0.05,
  randomSeed: 7319,
  macroTriangleChance: 0.08,
  macroTriangleScale: 2.5,
  macroTriangleContrast: 0.035,
  lightStrength: 0.11,
  edgeVignetteStrength: 0.11,
  fogStrength: 0.06,
);
