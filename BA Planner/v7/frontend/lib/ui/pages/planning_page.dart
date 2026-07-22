import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../widgets/repository_profile_panel.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key, required this.service});

  final AppService service;

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  final _studentIdController = TextEditingController();
  final List<_StudentPlanDraft> _students = [];
  bool _adding = false;
  bool _calculating = false;
  String? _lookupMessage;
  String? _calculationMessage;
  Map<String, dynamic>? _totalCost;
  Map<String, Map<String, dynamic>> _studentCosts = {};
  int _generation = 0;
  String? _profileId;
  int? _repositoryRevision;

  Future<void> _restoreProfile(RepositoryProfile profile) async {
    if (widget.service is! RepositoryService) return;
    if (_profileId == profile.id && _repositoryRevision == profile.revision) return;
    try {
      final state = await (widget.service as RepositoryService).loadRepositoryState(profile.id);
      final goals = <String, Map<String, dynamic>>{
        for (final raw in ((state['goals'] as Map?)?['goals'] as List<dynamic>? ?? const []))
          (raw as Map)['student_id'] as String: Map<String, dynamic>.from(raw),
      };
      final restored = <_StudentPlanDraft>[];
      for (final raw in (state['students'] as List<dynamic>? ?? const [])) {
        final wire = Map<String, dynamic>.from(raw as Map);
        final id = wire['student_id'] as String;
        final metadata = await widget.service.getStudent(id) ?? {'student_id': id, 'display_name': id};
        final draft = _StudentPlanDraft(id: id, metadata: metadata, onChanged: _invalidateResults);
        draft.restore(Map<String, dynamic>.from(wire['values'] as Map), goals[id]);
        restored.add(draft);
      }
      if (!mounted) return;
      setState(() {
        for (final old in _students) { old.dispose(); }
        _students..clear()..addAll(restored);
        _profileId = profile.id;
        _repositoryRevision = state['revision'] as int;
        _invalidateResults(notify: false);
      });
    } catch (error) {
      if (mounted) setState(() => _calculationMessage = '프로필 복원 실패: $error');
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    for (final student in _students) {
      student.dispose();
    }
    super.dispose();
  }

  Future<void> _addStudent() async {
    final id = _studentIdController.text.trim();
    if (id.isEmpty) {
      setState(() => _lookupMessage = '학생 ID를 입력해 주세요.');
      return;
    }
    if (_students.any((student) => student.id == id)) {
      setState(() => _lookupMessage = '이미 계획에 추가된 학생입니다.');
      return;
    }

    setState(() {
      _adding = true;
      _lookupMessage = null;
    });
    try {
      final metadata = await widget.service.getStudent(id);
      if (!mounted) return;
      if (metadata == null) {
        setState(() => _lookupMessage = '일치하는 학생을 찾지 못했습니다.');
        return;
      }
      final draft = _StudentPlanDraft(
        id: id,
        metadata: Map<String, dynamic>.from(metadata),
        onChanged: _invalidateResults,
      );
      setState(() {
        _students.add(draft);
        _studentIdController.clear();
        _lookupMessage = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _lookupMessage = '학생 조회 중 오류가 발생했습니다: $error');
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _removeStudent(_StudentPlanDraft student) {
    setState(() {
      _students.remove(student);
      student.dispose();
      _invalidateResults(notify: false);
    });
  }

  void _invalidateResults({bool notify = true}) {
    void update() {
      _generation += 1;
      _calculating = false;
      _totalCost = null;
      _studentCosts = {};
      _calculationMessage = null;
    }

    if (notify) {
      setState(update);
    } else {
      update();
    }
  }

  Future<void> _calculate() async {
    if (_students.isEmpty) {
      setState(() => _calculationMessage = '계산할 학생을 먼저 추가해 주세요.');
      return;
    }
    final invalid = _students.where((student) => student.hasErrors).toList();
    if (invalid.isNotEmpty) {
      setState(() => _calculationMessage = '범위를 벗어나거나 올바르지 않은 목표 값을 확인해 주세요.');
      return;
    }

    final requestGeneration = ++_generation;
    setState(() {
      _calculating = true;
      _calculationMessage = null;
    });
    try {
      final currentStudents = _students
          .map((student) => student.current)
          .toList();
      final canonicalPlan = await widget.service.validatePlan({
        'version': 1,
        'goals': _students.map((student) => student.goal).toList(),
      });
      final canonicalGoals = (canonicalPlan['goals'] as List<dynamic>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
      final perStudent = await Future.wait(
        _students.asMap().entries.map((entry) async {
          final cost = await widget.service.calculatePlan(
            currentStudents: [entry.value.current],
            plan: {
              'version': 1,
              'goals': [canonicalGoals[entry.key]],
            },
          );
          return MapEntry(entry.value.id, cost);
        }),
      );
      final total = await widget.service.calculatePlan(
        currentStudents: currentStudents,
        plan: canonicalPlan,
      );
      if (widget.service is RepositoryService && _profileId != null && _repositoryRevision != null) {
        _repositoryRevision = await (widget.service as RepositoryService).saveRepositoryGoals(
          _profileId!, canonicalPlan, _repositoryRevision!, 'planning-save-$requestGeneration',
        );
      }
      if (!mounted || requestGeneration != _generation) return;
      setState(() {
        _studentCosts = Map.fromEntries(perStudent);
        _totalCost = total;
      });
    } catch (error) {
      if (mounted && requestGeneration == _generation) {
        setState(() => _calculationMessage = '총 필요량 계산 중 오류가 발생했습니다: $error');
      }
    } finally {
      if (mounted && requestGeneration == _generation) {
        setState(() => _calculating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppServiceState>(
      valueListenable: widget.service.state,
      builder: (context, state, _) {
        final connected = state.connection == BackendConnection.connected;
        return ColoredBox(
          color: AppColors.canvas.withValues(alpha: 0.72),
          child: ListView(
            key: const ValueKey('planning-page'),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 48),
            children: [
              RepositoryProfilePanel(service: widget.service, onSelected: _restoreProfile),
              const SizedBox(height: 12),
              _PlanningHeader(
                connected: connected,
                reconnecting: state.connection == BackendConnection.connecting,
                onReconnect: widget.service.reconnect,
              ),
              const SizedBox(height: 16),
              _StudentLookup(
                controller: _studentIdController,
                enabled: connected && !_adding,
                loading: _adding,
                message: _lookupMessage,
                onSubmitted: (_) => _addStudent(),
                onAdd: _addStudent,
              ),
              const SizedBox(height: 18),
              if (_students.isEmpty)
                const _EmptyPlan()
              else
                for (final student in _students) ...[
                  _StudentPlanCard(
                    key: ValueKey('student-card-${student.id}'),
                    draft: student,
                    cost: _studentCosts[student.id],
                    onRemove: () => _removeStudent(student),
                  ),
                  const SizedBox(height: 14),
                ],
              _CalculationBar(
                connected: connected,
                calculating: _calculating,
                hasStudents: _students.isNotEmpty,
                message: _calculationMessage,
                onCalculate: _calculate,
              ),
              if (_totalCost != null) ...[
                const SizedBox(height: 16),
                _CostSummary(
                  key: const ValueKey('total-cost-summary'),
                  title: '전체 총 필요량',
                  cost: _totalCost!,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StudentPlanDraft {
  _StudentPlanDraft({
    required this.id,
    required this.metadata,
    required this.onChanged,
  }) : current = _defaultCurrent(id),
       goal = {'student_id': id, 'favorite': false},
       controllers = {
         for (final field in _goalFields) field.name: TextEditingController(),
         'notes': TextEditingController(),
       };

  final String id;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> current;
  final Map<String, dynamic> goal;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onChanged;
  final Map<String, String> errors = {};

  bool get hasErrors => errors.isNotEmpty;
  String get displayName =>
      (metadata['display_name'] ?? metadata['name'] ?? id).toString();

  void restore(Map<String, dynamic> values, Map<String, dynamic>? savedGoal) {
    current.addAll(values);
    if (savedGoal == null) return;
    goal
      ..clear()
      ..addAll(savedGoal);
    for (final field in _goalFields) {
      final value = savedGoal[field.name];
      controllers[field.name]?.text = value == null ? '' : value.toString();
    }
    controllers['notes']?.text = (savedGoal['notes'] ?? '').toString();
  }

  void updateInteger(_GoalField field, String raw) {
    final valueText = raw.trim();
    if (valueText.isEmpty) {
      goal.remove(field.name);
      errors.remove(field.name);
      onChanged();
      return;
    }
    final value = int.tryParse(valueText);
    if (value == null || value < field.minimum || value > field.maximum) {
      goal.remove(field.name);
      errors[field.name] = '${field.minimum}~${field.maximum} 정수를 입력하세요.';
    } else {
      goal[field.name] = value;
      errors.remove(field.name);
    }
    onChanged();
  }

  void updateFavorite(bool value) {
    goal['favorite'] = value;
    onChanged();
  }

  void updateNotes(String value) {
    if (value.isEmpty) {
      goal.remove('notes');
    } else {
      goal['notes'] = value;
    }
    onChanged();
  }

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  static Map<String, dynamic> _defaultCurrent(String id) => {
    'student_id': id,
    'level': 1,
    'student_star': 1,
    'weapon_state': 'weapon_locked',
    'weapon_star': 0,
    'weapon_level': 0,
    'ex_skill': 1,
    'skill1': 1,
    'skill2': 1,
    'skill3': 1,
    'equip1': 'T1',
    'equip2': 'T1',
    'equip3': 'T1',
    'equip4': null,
    'equip1_level': 1,
    'equip2_level': 1,
    'equip3_level': 1,
    'stat_hp': 0,
    'stat_atk': 0,
    'stat_heal': 0,
  };
}

class _GoalField {
  const _GoalField(
    this.name,
    this.label,
    this.minimum,
    this.maximum,
    this.group,
  );

  final String name;
  final String label;
  final int minimum;
  final int maximum;
  final String group;
}

const _goalFields = <_GoalField>[
  _GoalField('target_level', '레벨', 0, 90, '기본 성장'),
  _GoalField('target_star', '성급', 0, 5, '기본 성장'),
  _GoalField('target_weapon_level', '전용무기 레벨', 0, 60, '기본 성장'),
  _GoalField('target_weapon_star', '전용무기 성급', 0, 4, '기본 성장'),
  _GoalField('target_ex_skill', 'EX 스킬', 0, 5, '스킬'),
  _GoalField('target_skill1', '기본 스킬', 0, 10, '스킬'),
  _GoalField('target_skill2', '강화 스킬', 0, 10, '스킬'),
  _GoalField('target_skill3', '서브 스킬', 0, 10, '스킬'),
  _GoalField('target_equip1_tier', '장비 1 티어', 0, 10, '장비'),
  _GoalField('target_equip1_level', '장비 1 레벨', 0, 70, '장비'),
  _GoalField('target_equip2_tier', '장비 2 티어', 0, 10, '장비'),
  _GoalField('target_equip2_level', '장비 2 레벨', 0, 70, '장비'),
  _GoalField('target_equip3_tier', '장비 3 티어', 0, 10, '장비'),
  _GoalField('target_equip3_level', '장비 3 레벨', 0, 70, '장비'),
  _GoalField('target_equip4_tier', '장비 4 티어', 0, 2, '장비'),
  _GoalField('target_stat_hp', 'HP 능력치', 0, 25, '능력치'),
  _GoalField('target_stat_atk', '공격력 능력치', 0, 25, '능력치'),
  _GoalField('target_stat_heal', '치유력 능력치', 0, 25, '능력치'),
];

class _PlanningHeader extends StatelessWidget {
  const _PlanningHeader({
    required this.connected,
    required this.reconnecting,
    required this.onReconnect,
  });

  final bool connected;
  final bool reconnecting;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 20,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SizedBox(
              width: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '성장 계획',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '현재 상태와 목표를 분리해 관리합니다. 현재 상태는 P4 이전까지 보수적 임시값이며, 입력 내용은 앱을 닫으면 사라집니다.',
                  ),
                ],
              ),
            ),
            if (!connected)
              FilledButton.icon(
                key: const ValueKey('planning-reconnect'),
                onPressed: reconnecting ? null : onReconnect,
                icon: reconnecting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(reconnecting ? '연결 중' : '백엔드 재연결'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentLookup extends StatelessWidget {
  const _StudentLookup({
    required this.controller,
    required this.enabled,
    required this.loading,
    required this.message,
    required this.onSubmitted,
    required this.onAdd,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool loading;
  final String? message;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    key: const ValueKey('student-id-input'),
                    controller: controller,
                    enabled: enabled,
                    onSubmitted: enabled ? onSubmitted : null,
                    decoration: const InputDecoration(
                      labelText: '정확한 학생 ID',
                      hintText: '예: ayane',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('add-student-button'),
                  onPressed: enabled ? onAdd : null,
                  icon: loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: const Text('학생 추가'),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                key: const ValueKey('student-lookup-message'),
                style: const TextStyle(color: AppColors.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) {
    return const Card(
      key: ValueKey('planning-empty-state'),
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: Text('아직 계획에 포함된 학생이 없습니다. 학생 ID를 조회해 추가하세요.')),
      ),
    );
  }
}

class _StudentPlanCard extends StatefulWidget {
  const _StudentPlanCard({
    super.key,
    required this.draft,
    required this.cost,
    required this.onRemove,
  });

  final _StudentPlanDraft draft;
  final Map<String, dynamic>? cost;
  final VoidCallback onRemove;

  @override
  State<_StudentPlanCard> createState() => _StudentPlanCardState();
}

class _StudentPlanCardState extends State<_StudentPlanCard> {
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          draft.displayName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${draft.id} · 임시 현재 상태 레벨 ${draft.current['level']} / 성급 ${draft.current['student_star']}',
        ),
        trailing: IconButton(
          key: ValueKey('remove-student-${draft.id}'),
          tooltip: '계획에서 제거',
          onPressed: widget.onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('입력하지 않은 목표는 현재 값을 유지합니다. 숫자 0은 유효한 목표로 보존됩니다.'),
                const SizedBox(height: 12),
                ExpansionTile(
                  key: ValueKey('current-state-${draft.id}'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    '현재 상태 (읽기 전용 · 임시값)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          for (final entry in draft.current.entries)
                            if (entry.key != 'student_id')
                              Chip(
                                label: Text(
                                  '${entry.key}: ${entry.value ?? '-'}',
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
                for (final group in ['기본 성장', '스킬', '장비', '능력치'])
                  ExpansionTile(
                    key: ValueKey('goal-group-${draft.id}-$group'),
                    initiallyExpanded: group == '기본 성장',
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      group,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final field in _goalFields.where(
                              (field) => field.group == group,
                            ))
                              SizedBox(
                                width: 180,
                                child: TextField(
                                  key: ValueKey(
                                    'goal-${draft.id}-${field.name}',
                                  ),
                                  controller: draft.controllers[field.name],
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    draft.updateInteger(field, value);
                                    setState(() {});
                                  },
                                  decoration: InputDecoration(
                                    labelText: field.label,
                                    hintText:
                                        '${field.minimum}~${field.maximum} 또는 비움',
                                    errorText: draft.errors[field.name],
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                SwitchListTile(
                  key: ValueKey('goal-${draft.id}-favorite'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('즐겨찾기'),
                  value: draft.goal['favorite'] as bool,
                  onChanged: draft.updateFavorite,
                ),
                TextField(
                  key: ValueKey('goal-${draft.id}-notes'),
                  controller: draft.controllers['notes'],
                  onChanged: draft.updateNotes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '메모',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (widget.cost != null) ...[
                  const SizedBox(height: 14),
                  _CostSummary(
                    key: ValueKey('student-cost-${draft.id}'),
                    title: '${draft.displayName} 총 필요량',
                    cost: widget.cost!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculationBar extends StatelessWidget {
  const _CalculationBar({
    required this.connected,
    required this.calculating,
    required this.hasStudents,
    required this.message,
    required this.onCalculate,
  });

  final bool connected;
  final bool calculating;
  final bool hasStudents;
  final String? message;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const ValueKey('calculate-plan-button'),
              onPressed: connected && hasStudents && !calculating
                  ? onCalculate
                  : null,
              icon: calculating
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate_outlined),
              label: Text(calculating ? '계산 중' : '총 필요량 계산'),
            ),
            if (!connected) const Text('백엔드 연결 후 조회와 계산을 사용할 수 있습니다.'),
            if (message != null)
              Text(
                message!,
                key: const ValueKey('calculation-message'),
                style: const TextStyle(color: AppColors.warning),
              ),
          ],
        ),
      ),
    );
  }
}

class _CostSummary extends StatelessWidget {
  const _CostSummary({super.key, required this.title, required this.cost});

  final String title;
  final Map<String, dynamic> cost;

  @override
  Widget build(BuildContext context) {
    const scalarLabels = {
      'credits': '크레딧',
      'level_exp': '레벨 경험치',
      'equipment_exp': '장비 경험치',
      'weapon_exp': '전용무기 경험치',
    };
    const mapLabels = {
      'star_materials': '성급 재료',
      'equipment_materials': '장비 재료',
      'level_exp_items': '레벨 경험치 아이템',
      'equipment_exp_items': '장비 경험치 아이템',
      'weapon_exp_items': '전용무기 경험치 아이템',
      'skill_books': '기술 노트/전술 교육 BD',
      'ex_ooparts': 'EX 오파츠',
      'skill_ooparts': '스킬 오파츠',
      'favorite_item_materials': '애용품 재료',
      'stat_materials': '능력치 재료',
      'stat_levels': '능력치 단계',
    };
    final nonEmptyMaps = mapLabels.entries.where((entry) {
      final value = cost[entry.key];
      return value is Map && value.isNotEmpty;
    });
    final warnings = (cost['warnings'] as List<dynamic>? ?? const []);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryMuted.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final entry in scalarLabels.entries)
                Text(
                  '${entry.value}: ${cost[entry.key] ?? 0}',
                  key: ValueKey('cost-${entry.key}'),
                ),
            ],
          ),
          for (final entry in nonEmptyMaps) ...[
            const SizedBox(height: 8),
            Text('${entry.value}: ${_formatCountMap(cost[entry.key] as Map)}'),
          ],
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '경고: ${warnings.join(' · ')}',
              style: const TextStyle(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatCountMap(Map<dynamic, dynamic> values) => values.entries
      .where((entry) => entry.value != 0)
      .map((entry) => '${entry.key} ${entry.value}')
      .join(', ');
}
