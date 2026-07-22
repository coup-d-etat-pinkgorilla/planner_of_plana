import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import 'planning_page.dart';
import '../widgets/repository_profile_panel.dart';
import '../widgets/diagonal_section.dart';

class StudentCandidateContext {
  const StudentCandidateContext({
    required this.session,
    required this.candidate,
  });
  final ScannerSession session;
  final ScannerCandidate candidate;
}

class StudentPage extends StatefulWidget {
  const StudentPage({
    super.key,
    required this.service,
    required this.onAddToPlan,
    this.candidateContext,
  });

  final AppService service;
  final ValueChanged<PlanningStudentSeed> onAddToPlan;
  final StudentCandidateContext? candidateContext;

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  final _search = TextEditingController();
  final Map<String, TextEditingController> _editors = {};
  List<StudentCatalogEntry> _catalog = const [];
  RepositoryState? _repositoryState;
  RepositoryProfile? _profile;
  String? _selectedId;
  String? _school;
  String _sort = 'name';
  String? _message;
  bool _loading = true;
  bool _saving = false;
  bool _ownedOnly = false;
  int _handoffSequence = 0;

  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;
  ScannerService? get _scanner => widget.service is ScannerService
      ? widget.service as ScannerService
      : null;

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
    _loadCatalog();
  }

  @override
  void dispose() {
    widget.service.state.removeListener(_connectionChanged);
    _search.dispose();
    for (final editor in _editors.values) {
      editor.dispose();
    }
    super.dispose();
  }

  void _connectionChanged() {
    if (widget.service.state.value.connection == BackendConnection.connected &&
        _catalog.isEmpty &&
        !_loading) {
      _loadCatalog();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCatalog() async {
    if (widget.service.state.value.connection != BackendConnection.connected) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'Backend is disconnected.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final catalog = await widget.service.listStudents();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _selectedId ??= catalog.isEmpty ? null : catalog.first.studentId;
        _loading = false;
      });
      _syncEditors();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'Could not load students: $error';
        });
      }
    }
  }

  Future<void> _selectProfile(RepositoryProfile profile) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final state = await repository.loadRepositoryState(profile.id);
      if (!mounted) return;
      final known = _catalog.map((student) => student.studentId).toSet();
      final fallback = state.students
          .where((student) => !known.contains(student.studentId))
          .map((student) => StudentCatalogEntry.fallback(student.studentId));
      setState(() {
        _profile = profile;
        _repositoryState = state;
        _catalog = [..._catalog, ...fallback];
        _selectedId ??= _catalog.isEmpty ? null : _catalog.first.studentId;
        _message = null;
      });
      _syncEditors();
    } catch (error) {
      if (mounted) setState(() => _message = 'Could not load profile: $error');
    }
  }

  Future<void> _reloadProfile() async {
    final profile = _profile;
    if (profile != null) await _selectProfile(profile);
  }

  ConfirmedStudentState? get _selectedState {
    final id = _selectedId;
    if (id == null) return null;
    for (final student
        in _repositoryState?.students ?? const <ConfirmedStudentState>[]) {
      if (student.studentId == id) return student;
    }
    return null;
  }

  StudentCatalogEntry? get _selectedEntry {
    final id = _selectedId;
    for (final student in _catalog) {
      if (student.studentId == id) return student;
    }
    return null;
  }

  void _syncEditors() {
    final values = _selectedState?.values ?? _defaultValues;
    for (final field in _studentFields) {
      final editor = _editors.putIfAbsent(
        field.name,
        TextEditingController.new,
      );
      editor.text = (values[field.name] ?? field.minimum).toString();
    }
  }

  Map<String, dynamic>? _draftValues() {
    final values = Map<String, dynamic>.from(_defaultValues);
    for (final field in _studentFields) {
      final value = int.tryParse(_editors[field.name]?.text.trim() ?? '');
      if (value == null || value < field.minimum || value > field.maximum) {
        setState(
          () => _message =
              '${field.label} must be ${field.minimum}-${field.maximum}.',
        );
        return null;
      }
      values[field.name] = value;
    }
    return values;
  }

  Future<void> _save() async {
    final repository = _repository;
    final profile = _profile;
    final state = _repositoryState;
    final id = _selectedId;
    final values = _draftValues();
    if (repository == null ||
        profile == null ||
        state == null ||
        id == null ||
        values == null) {
      if (mounted && profile == null) {
        setState(() => _message = 'Select a repository profile first.');
      }
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final students = [
        for (final student in state.students)
          if (student.studentId != id) student,
        ConfirmedStudentState.fromValues(id, values),
      ];
      final revision = await repository.saveRepositoryStudents(
        profile.id,
        students,
        state.revision,
        'student-save-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      final reloaded = await repository.loadRepositoryState(profile.id);
      if (!mounted) return;
      setState(() {
        _repositoryState = reloaded;
        _message = 'Saved at repository revision $revision.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Save failed; your draft was kept: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addToPlan() {
    final entry = _selectedEntry;
    final values = _draftValues();
    if (entry == null || values == null) return;
    widget.onAddToPlan(
      PlanningStudentSeed(
        handoffId:
            '${entry.studentId}-${++_handoffSequence}-${DateTime.now().microsecondsSinceEpoch}',
        studentId: entry.studentId,
        metadata: entry.metadata,
        currentValues: values,
      ),
    );
  }

  Future<void> _approveCandidate() async {
    final context = widget.candidateContext;
    final scanner = _scanner;
    final profile = _profile;
    final state = _repositoryState;
    if (context == null ||
        scanner == null ||
        profile == null ||
        state == null) {
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final approved = context.candidate.approved
          ? context.candidate
          : await scanner.reviewScannerCandidate(
              context.session,
              context.candidate,
              context.candidate.payload,
              approve: true,
              reason: 'approved_in_student_page',
            );
      final committed = await scanner.commitScannerCandidate(
        context.session,
        approved,
        profileId: profile.id,
        expectedRepositoryRevision: state.revision,
        idempotencyKey: 'candidate-${approved.id}-${approved.revision}',
      );
      if (!mounted) return;
      final refreshed = await _repository!.loadRepositoryState(profile.id);
      if (!mounted) return;
      setState(() {
        _repositoryState = refreshed;
        _message = 'Candidate committed at revision ${committed['revision']}.';
      });
      _syncEditors();
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Candidate was not committed: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (widget.service.state.value.connection != BackendConnection.connected) {
      return _StatusPane(
        message: _message ?? 'Backend is disconnected.',
        onRetry: _loadCatalog,
      );
    }
    if (_catalog.isEmpty) {
      return _StatusPane(
        message: _message ?? 'No students are available.',
        onRetry: _loadCatalog,
      );
    }
    final owned =
        (_repositoryState?.students ?? const <ConfirmedStudentState>[])
            .map((student) => student.studentId)
            .toSet();
    final schools =
        _catalog
            .map((student) => student.school)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    final visible = _catalog
        .where(
          (student) =>
              student.matches(_search.text) &&
              (_school == null || student.school == _school) &&
              (!_ownedOnly || owned.contains(student.studentId)),
        )
        .toList();
    int currentLevel(StudentCatalogEntry student) {
      for (final state
          in _repositoryState?.students ?? const <ConfirmedStudentState>[]) {
        if (state.studentId == student.studentId) {
          return state.values['level'] as int? ?? 0;
        }
      }
      return 0;
    }

    visible.sort(
      (left, right) => switch (_sort) {
        'id' => left.studentId.compareTo(right.studentId),
        'level' => currentLevel(right).compareTo(currentLevel(left)),
        _ => left.displayName.toLowerCase().compareTo(
          right.displayName.toLowerCase(),
        ),
      },
    );
    final selected = _selectedEntry;
    final candidate = widget.candidateContext;

    return ListView(
      key: const ValueKey('student-page'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        RepositoryProfilePanel(
          service: widget.service,
          onSelected: _selectProfile,
        ),
        const SizedBox(height: AppSpacing.md),
        DiagonalSection(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Students',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        key: const ValueKey('student-search'),
                        controller: _search,
                        decoration: const InputDecoration(
                          labelText: 'Search ID, name, or tag',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _school ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'School'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text(
                              'All schools',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...schools.map(
                            (school) => DropdownMenuItem<String>(
                              value: school,
                              child: Text(
                                school,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => _school = value == null || value.isEmpty
                              ? null
                              : value,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _sort,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sort source',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'name',
                            child: Text(
                              'Metadata: name',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'id',
                            child: Text(
                              'Metadata: ID',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'level',
                            child: Text(
                              'Current state: level',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _sort = value);
                        },
                      ),
                    ),
                    FilterChip(
                      label: const Text('Owned only'),
                      selected: _ownedOnly,
                      onSelected: (value) => setState(() => _ownedOnly = value),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${visible.length} results',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final student = visible[index];
                      return ListTile(
                        key: ValueKey('student-${student.studentId}'),
                        selected: student.studentId == _selectedId,
                        title: Text(
                          student.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${student.studentId} · ${student.school ?? 'metadata unavailable'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: owned.contains(student.studentId)
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                              )
                            : null,
                        onTap: () {
                          setState(() => _selectedId = student.studentId);
                          _syncEditors();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (selected != null)
          DiagonalSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    selected.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    'Static metadata · ${selected.studentId} · ${selected.school ?? 'unavailable'} · ${selected.role ?? 'role unavailable'}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const Divider(height: AppSpacing.lg),
                  Text(
                    'Confirmed repository values',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final field in _studentFields)
                        SizedBox(
                          width: 170,
                          child: TextField(
                            key: ValueKey('student-field-${field.name}'),
                            controller: _editors[field.name],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: field.label,
                              helperText: '${field.minimum}-${field.maximum}',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('student-save'),
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save confirmed values'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('student-add-to-plan'),
                        onPressed: _addToPlan,
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('Add to plan draft'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (candidate != null) ...[
          const SizedBox(height: AppSpacing.md),
          DiagonalSection(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Delivered scan candidate',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Candidate ${candidate.candidate.id} · revision ${candidate.candidate.revision}',
                  ),
                  Text(
                    'Confirmed: ${_selectedState?.values ?? const <String, dynamic>{}}',
                  ),
                  Text(
                    'Candidate: ${candidate.candidate.payload['values'] ?? candidate.candidate.payload}',
                  ),
                  Text(
                    'Review required: ${candidate.candidate.reviewRequired}',
                  ),
                  ...candidate.candidate.evidence.map(
                    (evidence) => Text(
                      '${evidence.field}: ${evidence.status} (${evidence.source}, confidence ${evidence.confidence?.toStringAsFixed(2) ?? 'n/a'})',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      FilledButton(
                        key: const ValueKey('candidate-approve'),
                        onPressed: _saving ? null : _approveCandidate,
                        child: const Text('Approve and commit'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('candidate-hold'),
                        onPressed: () => setState(
                          () => _message =
                              'Candidate kept for later review; repository unchanged.',
                        ),
                        child: const Text('Hold'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _message!,
                    key: const ValueKey('student-message'),
                  ),
                ),
                if (_profile != null)
                  TextButton(
                    key: const ValueKey('student-reload-profile'),
                    onPressed: _saving ? null : _reloadProfile,
                    child: const Text('Reload profile'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusPane extends StatelessWidget {
  const _StatusPane({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _StudentField {
  const _StudentField(this.name, this.label, this.minimum, this.maximum);
  final String name;
  final String label;
  final int minimum;
  final int maximum;
}

const _studentFields = <_StudentField>[
  _StudentField('level', 'Level', 1, 90),
  _StudentField('student_star', 'Stars', 1, 5),
  _StudentField('weapon_level', 'Weapon level', 0, 60),
  _StudentField('weapon_star', 'Weapon stars', 0, 4),
  _StudentField('ex_skill', 'EX skill', 1, 5),
  _StudentField('skill1', 'Skill 1', 1, 10),
  _StudentField('skill2', 'Skill 2', 1, 10),
  _StudentField('skill3', 'Skill 3', 1, 10),
  _StudentField('equip1_level', 'Equipment 1', 1, 70),
  _StudentField('equip2_level', 'Equipment 2', 1, 70),
  _StudentField('equip3_level', 'Equipment 3', 1, 70),
  _StudentField('stat_hp', 'HP stat', 0, 25),
  _StudentField('stat_atk', 'ATK stat', 0, 25),
  _StudentField('stat_heal', 'Heal stat', 0, 25),
];

const _defaultValues = <String, dynamic>{
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
