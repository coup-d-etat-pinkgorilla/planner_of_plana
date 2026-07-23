// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../statistics/statistics_projection.dart';
import '../app_section.dart';
import '../widgets/diagonal_section.dart';

enum StatisticsMode { students, inventory, plan }

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.service,
    required this.onOpen,
    this.reloadToken = 0,
  });
  final AppService service;
  final ValueChanged<AppSection> onOpen;
  final int reloadToken;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;
  RepositoryProfile? _profile;
  RepositoryState? _state;
  List<StudentCatalogEntry>? _students;
  List<InventoryCatalogEntry>? _inventory;
  Map<String, dynamic>? _gross;
  InventoryShortageResult? _shortages;
  String? _profileError,
      _stateError,
      _studentError,
      _inventoryError,
      _grossError,
      _shortageError;
  bool _loading = true;
  int _generation = 0;
  StatisticsMode _mode = StatisticsMode.students;
  String _studentDistribution = 'ownership';
  StatisticsRow? _studentDetail;
  InventoryCategoryStatistics? _inventoryDetail;

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
    _reload();
  }

  @override
  void didUpdateWidget(StatisticsPage old) {
    super.didUpdateWidget(old);
    if (old.service != widget.service) {
      old.service.state.removeListener(_connectionChanged);
      widget.service.state.addListener(_connectionChanged);
      _reload();
    } else if (old.reloadToken != widget.reloadToken) {
      _reload();
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.service.state.removeListener(_connectionChanged);
    super.dispose();
  }

  void _connectionChanged() {
    if (!mounted) return;
    if (widget.service.state.value.connection == BackendConnection.connected) {
      _reload();
    } else {
      _generation++;
      setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _profile = null;
      _state = null;
      _students = null;
      _inventory = null;
      _gross = null;
      _shortages = null;
      _studentDetail = null;
      _inventoryDetail = null;
      _profileError = _stateError = _studentError = _inventoryError =
          _grossError = _shortageError = null;
    });
    if (widget.service.state.value.connection != BackendConnection.connected) {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
      return;
    }
    final repository = _repository;
    if (repository == null) {
      if (mounted && generation == _generation)
        setState(() {
          _profileError = 'Repository service is unavailable.';
          _loading = false;
        });
      return;
    }
    try {
      final profiles = await repository.listProfiles();
      if (!mounted || generation != _generation) return;
      _profile = null;
      for (final item in profiles) {
        if (item.selected) {
          _profile = item;
          break;
        }
      }
      if (_profile == null) {
        setState(() => _loading = false);
        return;
      }
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() {
          _profileError = 'Profile loading failed: $error';
          _loading = false;
        });
      return;
    }
    final profile = _profile!;
    try {
      final value = await repository.loadRepositoryState(profile.id);
      if (mounted && generation == _generation) setState(() => _state = value);
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() => _stateError = 'Repository state failed: $error');
    }
    try {
      final value = await widget.service.listStudents();
      if (mounted && generation == _generation)
        setState(() => _students = value);
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() => _studentError = 'Student catalog failed: $error');
    }
    try {
      final value = await widget.service.listInventoryItems();
      if (mounted && generation == _generation)
        setState(() => _inventory = value);
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() => _inventoryError = 'Inventory catalog failed: $error');
    }
    if (!mounted || generation != _generation) return;
    final snapshot = _state;
    if (snapshot != null && snapshot.goals.isNotEmpty) {
      final current = snapshot.students
          .map(confirmedStudentPlanningCurrent)
          .toList(growable: false);
      final plan = {
        'version': 1,
        'goals': snapshot.goals
            .map((goal) => Map<String, dynamic>.from(goal.values))
            .toList(growable: false),
      };
      try {
        final value = await widget.service.calculatePlan(
          currentStudents: current,
          plan: plan,
        );
        if (mounted && generation == _generation)
          setState(() => _gross = value);
      } catch (error) {
        if (mounted && generation == _generation)
          setState(() => _grossError = 'Gross calculation failed: $error');
      }
      try {
        final value = await widget.service.calculateShortages(
          currentStudents: current,
          plan: plan,
          inventory: snapshot.inventory.toWire(),
        );
        if (mounted && generation == _generation)
          setState(() => _shortages = value);
      } catch (error) {
        if (mounted && generation == _generation)
          setState(
            () => _shortageError = 'Shortage calculation failed: $error',
          );
      }
    } else {
      _gross = null;
      _shortages = null;
    }
    if (mounted && generation == _generation) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.service.state.value.connection;
    final studentStats = _state != null && _students != null
        ? buildStudentStatistics(_students!, _state!)
        : null;
    final inventoryStats = _state != null && _inventory != null
        ? buildInventoryStatistics(_inventory!, _state!.inventory)
        : null;
    final planStats = _state == null
        ? null
        : buildPlanStatistics(_state!.goals.length, _gross, _shortages);
    return ListView(
      key: const ValueKey('statistics-page'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profile statistics',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('statistics-refresh'),
                    onPressed: _loading ? null : _reload,
                    tooltip: 'Refresh statistics',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Text(
                connection == BackendConnection.connected
                    ? 'Selected profile scope'
                    : connection == BackendConnection.connecting
                    ? 'Backend connecting'
                    : 'Backend disconnected',
              ),
              if (_profile != null)
                Text(
                  '${_profile!.displayName} · ${_profile!.id} · revision ${_state?.revision ?? _profile!.revision}',
                ),
              if (_loading) const LinearProgressIndicator(),
              for (final error in [
                _profileError,
                _stateError,
                _studentError,
                _inventoryError,
                _grossError,
                _shortageError,
              ])
                if (error != null)
                  Text(error, style: const TextStyle(color: AppColors.danger)),
              if (!_loading &&
                  _profile == null &&
                  _profileError == null &&
                  connection == BackendConnection.connected)
                const Text('No selected profile.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          SegmentedButton<StatisticsMode>(
            key: const ValueKey('statistics-mode'),
            segments: const [
              ButtonSegment(
                value: StatisticsMode.students,
                label: Text('Students'),
                icon: Icon(Icons.people_outline),
              ),
              ButtonSegment(
                value: StatisticsMode.inventory,
                label: Text('Inventory'),
                icon: Icon(Icons.inventory_2_outlined),
              ),
              ButtonSegment(
                value: StatisticsMode.plan,
                label: Text('Plan'),
                icon: Icon(Icons.route_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() {
              _mode = value.single;
              _studentDetail = null;
            }),
          ),
        ),
        const SizedBox(height: 12),
        if (_mode == StatisticsMode.students) _studentsView(studentStats),
        if (_mode == StatisticsMode.inventory) _inventoryView(inventoryStats),
        if (_mode == StatisticsMode.plan) _planView(planStats),
      ],
    );
  }

  Widget _section(Widget child) => DiagonalSection(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 34, 16),
      child: child,
    ),
  );
  Widget _kpis(List<String> values) => Wrap(
    spacing: 10,
    runSpacing: 8,
    children: [for (final value in values) Chip(label: Text(value))],
  );

  Widget _studentsView(StudentStatistics? stats) {
    if (stats == null)
      return _section(const Text('Student statistics are unavailable.'));
    final rows = stats.distributions[_studentDistribution] ?? const [];
    return Column(
      children: [
        _section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Student KPIs'),
              _kpis([
                'catalog ${stats.catalogCount}',
                'confirmed ${stats.confirmedCount}',
                'saved goals ${stats.goalCount}',
                'orphan goals ${stats.orphanGoalCount}',
                'average level ${stats.averageLevel?.toStringAsFixed(1) ?? 'n/a'} (${stats.knownLevelCount} known)',
                'average star ${stats.averageStar?.toStringAsFixed(1) ?? 'n/a'} (${stats.knownStarCount} known)',
              ]),
              if (stats.missingCatalogIds.isNotEmpty)
                Text(
                  'Missing catalog metadata: ${stats.missingCatalogIds.join(', ')}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                key: const ValueKey('statistics-student-selector'),
                value: _studentDistribution,
                items:
                    const {
                          'ownership': 'Ownership',
                          'level': 'Current level',
                          'star': 'Current star',
                          'school': 'School',
                          'combat_class': 'Combat class',
                          'attack_type': 'Attack type',
                          'defense_type': 'Defense type',
                          'role': 'Role',
                        }.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() {
                  _studentDistribution = value!;
                  _studentDetail = null;
                }),
              ),
              for (final row in rows)
                ListTile(
                  key: ValueKey('statistics-row-${row.key}'),
                  title: Text(row.label),
                  subtitle: LinearProgressIndicator(
                    value: row.denominator == 0
                        ? 0
                        : row.count / row.denominator,
                  ),
                  trailing: Text(
                    '${row.count}/${row.denominator} · ${row.percent.toStringAsFixed(1)}%',
                  ),
                  onTap: () => setState(() => _studentDetail = row),
                ),
              if (_studentDetail != null) ...[
                const Divider(),
                Text('Evidence: ${_studentDetail!.label}'),
                for (final id in _studentDetail!.identities)
                  Text('${stats.displayNames[id] ?? id} · $id'),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('statistics-open-students'),
                  onPressed: () => widget.onOpen(AppSection.students),
                  child: const Text('Review in Students'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inventoryView(InventoryStatistics? stats) {
    if (stats == null)
      return _section(const Text('Inventory statistics are unavailable.'));
    return Column(
      children: [
        _section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Inventory KPIs'),
              _kpis([
                'catalog ${stats.catalogCount}',
                'snapshot ${stats.snapshotCount}',
                'known ${stats.knownCount}',
                'unknown ${stats.unknownCount}',
                'absent ${stats.absentCount}',
                'explicit zero ${stats.zeroCount}',
                'positive ${stats.positiveCount}',
              ]),
              if (stats.missingCatalogIds.isNotEmpty)
                Text(
                  'Missing catalog identities: ${stats.missingCatalogIds.join(', ')}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category coverage'),
              for (final row in stats.categories)
                ListTile(
                  key: ValueKey('statistics-inventory-${row.category}'),
                  title: Text(row.category),
                  subtitle: Text(
                    'catalog ${row.catalogCount} · snapshot ${row.snapshotCount} · absent ${row.absentCount} · known ${row.knownCount} · unknown ${row.unknownCount} · zero ${row.zeroCount} · positive ${row.positiveCount}',
                  ),
                  trailing: Text(
                    '${row.knownPercent.toStringAsFixed(1)}% known',
                  ),
                  onTap: () => setState(() => _inventoryDetail = row),
                ),
              if (_inventoryDetail != null) ...[
                const Divider(),
                Text('Evidence: ${_inventoryDetail!.category}'),
                for (final id in _inventoryDetail!.identities) Text(id),
              ],
              TextButton(
                key: const ValueKey('statistics-open-inventory'),
                onPressed: () => widget.onOpen(AppSection.inventory),
                child: const Text('Review in Inventory'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planView(PlanStatistics? stats) {
    if (stats == null)
      return _section(const Text('Plan statistics are unavailable.'));
    if (stats.savedGoalCount == 0)
      return _section(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No saved goals; gross and shortage APIs were not requested.',
            ),
            TextButton(
              key: const ValueKey('statistics-open-plan'),
              onPressed: () => widget.onOpen(AppSection.plan),
              child: const Text('Open Plan'),
            ),
          ],
        ),
      );
    return Column(
      children: [
        _section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Plan KPIs'),
              _kpis([
                'saved goals ${stats.savedGoalCount}',
                for (final entry in stats.grossScalars.entries)
                  '${entry.key} ${entry.value}',
                'shortage rows ${stats.shortageRowCount}',
                'positive ${stats.positiveShortageCount}',
                'unresolved ${stats.unresolvedCount}',
                'affected students ${stats.affectedStudentCount}',
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gross material maps'),
              if (stats.materials.isEmpty)
                const Text('No gross material rows.'),
              for (final row in stats.materials)
                Text('${row.category} · ${row.key}: ${row.value}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Shortage categories'),
              for (final row in stats.shortageCategories)
                Text(
                  '${row.category} · required ${row.required} · known owned ${row.knownOwned} · positive shortage ${row.positiveShortage} · unknown ${row.unknownCount}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Positive shortages (top 10)'),
              if (stats.topShortages.isEmpty)
                const Text('No positive shortage rows.'),
              for (final row in stats.topShortages)
                Text(
                  '${row.displayName} · required ${row.requiredAmount} · owned ${row.owned ?? 'Unknown'} · shortage ${row.shortage ?? 'Unknown'}',
                ),
              Wrap(
                children: [
                  TextButton(
                    key: const ValueKey('statistics-open-plan'),
                    onPressed: () => widget.onOpen(AppSection.plan),
                    child: const Text('Review in Plan'),
                  ),
                  TextButton(
                    key: const ValueKey('statistics-open-shortages'),
                    onPressed: () => widget.onOpen(AppSection.inventory),
                    child: const Text('Shortage details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
