import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import 'diagonal_section.dart';
import 'scroll_viewport_fog.dart';

typedef ScanCandidateAction = Future<void> Function(ScannerCandidate candidate);
typedef ScanCandidateEditAction =
    Future<void> Function(
      ScannerCandidate candidate,
      Map<String, dynamic> candidatePayload,
      Map<int, int> relationshipRanks,
    );

List<ScannerCandidate> orderScanResultCandidatesByGroup(
  List<ScannerCandidate> candidates,
  Map<String, StudentCatalogEntry> catalog,
) {
  final groupOrder = <String, int>{};
  final indexed = candidates.indexed.toList(growable: false);
  for (final entry in indexed) {
    final studentId = entry.$2.payload['student_id'] as String? ?? 'unknown';
    final group = catalog[studentId]?.group ?? studentId;
    groupOrder.putIfAbsent(group, () => groupOrder.length);
  }
  indexed.sort((left, right) {
    String group((int, ScannerCandidate) entry) {
      final studentId = entry.$2.payload['student_id'] as String? ?? 'unknown';
      return catalog[studentId]?.group ?? studentId;
    }

    final groupComparison = groupOrder[group(left)]!.compareTo(
      groupOrder[group(right)]!,
    );
    return groupComparison != 0 ? groupComparison : left.$1.compareTo(right.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

class ScanStudentReviewWorkspace extends StatefulWidget {
  const ScanStudentReviewWorkspace({
    super.key,
    required this.candidates,
    required this.currentStudents,
    required this.catalog,
    required this.busyCandidateIds,
    required this.candidateErrors,
    required this.singleScan,
    required this.onRevalidate,
    required this.onHold,
    required this.onDiscard,
    required this.onApply,
  });

  final List<ScannerCandidate> candidates;
  final Map<String, ConfirmedStudentState> currentStudents;
  final Map<String, StudentCatalogEntry> catalog;
  final Set<String> busyCandidateIds;
  final Map<String, String> candidateErrors;
  final bool singleScan;
  final ScanCandidateEditAction onRevalidate;
  final ScanCandidateAction onHold;
  final ScanCandidateAction onDiscard;
  final ScanCandidateAction onApply;

  @override
  State<ScanStudentReviewWorkspace> createState() =>
      _ScanStudentReviewWorkspaceState();
}

class _ScanStudentReviewWorkspaceState
    extends State<ScanStudentReviewWorkspace> {
  String? _selectedId;
  final Set<String> _editing = {};
  final Map<String, Map<String, dynamic>> _drafts = {};
  final Map<String, String> _localErrors = {};
  final Map<String, Map<int, String>> _relationshipRankInputs = {};

  @override
  void didUpdateWidget(ScanStudentReviewWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.candidates.map((item) => item.id).toSet();
    _editing.removeWhere((id) => !ids.contains(id));
    _drafts.removeWhere((id, _) => !ids.contains(id));
    _localErrors.removeWhere((id, _) => !ids.contains(id));
    _relationshipRankInputs.removeWhere((id, _) => !ids.contains(id));
    if (_selectedId == null || !ids.contains(_selectedId)) {
      _selectedId = widget.candidates.isEmpty
          ? null
          : widget.candidates.first.id;
    }
  }

  ScannerCandidate? get _selected {
    final id = _selectedId;
    for (final candidate in widget.candidates) {
      if (candidate.id == id) return candidate;
    }
    return widget.candidates.firstOrNull;
  }

  static const _safeStatuses = {
    'ok',
    'inferred',
    'skipped',
    'verified',
    'deferred',
  };

  bool _hasProblem(ScannerCandidate candidate) =>
      candidate.reviewRequired ||
      widget.candidateErrors.containsKey(candidate.id) ||
      _localErrors.containsKey(candidate.id) ||
      candidate.evidence.any(
        (evidence) => !_safeStatuses.contains(evidence.status),
      );

  String _status(ScannerCandidate candidate) {
    if (widget.candidateErrors.containsKey(candidate.id)) return 'apply failed';
    if (_localErrors.containsKey(candidate.id)) return 'invalid edit';
    if (candidate.evidence.any((item) => item.status == 'deferred')) {
      return '다른 의상 랭크 적용 대기';
    }
    for (final priority in const [
      'suspicious',
      'dependency_missing',
      'partial',
      'failed',
      'uncertain',
      'region_missing',
    ]) {
      if (candidate.evidence.any((item) => item.status == priority)) {
        return priority.replaceAll('_', ' ');
      }
    }
    return candidate.reviewRequired ? 'review required' : 'verified';
  }

  String _studentId(ScannerCandidate candidate) =>
      candidate.payload['student_id'] as String? ?? 'unknown';

  String _displayName(ScannerCandidate candidate) {
    final id = _studentId(candidate);
    return widget.catalog[id]?.displayName ?? id;
  }

  Map<String, dynamic> _values(ScannerCandidate candidate) =>
      Map<String, dynamic>.from(
        candidate.payload['values'] as Map? ?? const {},
      );

  Map<String, dynamic> _draft(ScannerCandidate candidate) =>
      _drafts.putIfAbsent(candidate.id, () => _values(candidate));

  Map<String, dynamic> _expected(ScannerCandidate candidate) {
    for (final evidence in candidate.evidence) {
      if (evidence.field != 'student_stat_validation') continue;
      final expected = evidence.details?['expected'];
      if (expected is Map) return Map<String, dynamic>.from(expected);
    }
    return const {};
  }

  Map<String, dynamic> _delta(ScannerCandidate candidate) {
    for (final evidence in candidate.evidence) {
      if (evidence.field != 'student_stat_validation') continue;
      final delta = evidence.details?['delta'];
      if (delta is Map) return Map<String, dynamic>.from(delta);
    }
    return const {};
  }

  List<Map<String, dynamic>> _relationshipContributions(
    ScannerCandidate candidate,
  ) {
    for (final evidence in candidate.evidence) {
      if (evidence.field != 'student_stat_validation') continue;
      final rows = evidence.details?['relationship_contributions'];
      if (rows is List) {
        return rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      }
    }
    return const [];
  }

  List<_ResultListEntry> _resultEntries() {
    if (!widget.singleScan) {
      final ordered = orderScanResultCandidatesByGroup(
        widget.candidates,
        widget.catalog,
      );
      return [
        for (var index = 0; index < ordered.length; index++)
          _ResultListEntry.candidate(
            ordered[index],
            group:
                widget.catalog[_studentId(ordered[index])]?.group ??
                _studentId(ordered[index]),
            firstInGroup:
                index == 0 ||
                (widget.catalog[_studentId(ordered[index - 1])]?.group ??
                        _studentId(ordered[index - 1])) !=
                    (widget.catalog[_studentId(ordered[index])]?.group ??
                        _studentId(ordered[index])),
          ),
      ];
    }

    return [
      for (final candidate in widget.candidates) ...[
        _ResultListEntry.candidate(
          candidate,
          group:
              widget.catalog[_studentId(candidate)]?.group ??
              _studentId(candidate),
          firstInGroup: true,
        ),
        for (final row in _relationshipContributions(candidate))
          if (row['kind'] == 'alternate' && row['owned'] == true)
            _ResultListEntry.relationship(candidate, row),
      ],
    ];
  }

  Future<void> _revalidate(ScannerCandidate candidate) async {
    final payload = Map<String, dynamic>.from(candidate.payload);
    payload['values'] = Map<String, dynamic>.from(_draft(candidate));
    final relationshipRanks = <int, int>{};
    for (final row in _relationshipContributions(candidate)) {
      if (row['kind'] != 'alternate' || row['owned'] != true) continue;
      final id = row['schaledb_id'];
      if (id is! int) continue;
      final raw =
          _relationshipRankInputs[candidate.id]?[id] ??
          row['rank']?.toString() ??
          '';
      final rank = int.tryParse(raw);
      if (rank == null || rank < 1 || rank > 100) {
        setState(
          () =>
              _localErrors[candidate.id] = '다른 보유 의상의 인연 랭크를 1~100으로 입력하세요.',
        );
        return;
      }
      relationshipRanks[id] = rank;
    }
    setState(() => _localErrors.remove(candidate.id));
    await widget.onRevalidate(candidate, payload, relationshipRanks);
    if (mounted) setState(() => _editing.remove(candidate.id));
  }

  Future<void> _discard(ScannerCandidate candidate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('후보 폐기'),
        content: Text(
          '${_displayName(candidate)} 스캔 후보를 폐기합니다. 확정된 현재값은 변경되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('scan-student-discard-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('폐기'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDiscard(candidate);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) return const SizedBox.shrink();
    final selected = _selected!;
    final selectedId = selected.id;
    final problem = _hasProblem(selected);
    return Semantics(
      container: true,
      label: '학생 스캔 결과 검토 workspace',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          final list = _ResultList(
            entries: _resultEntries(),
            selectedId: selectedId,
            displayName: _displayName,
            status: _status,
            hasProblem: _hasProblem,
            onSelected: (id) => setState(() => _selectedId = id),
            catalog: widget.catalog,
            relationshipRankInputs: _relationshipRankInputs,
            onRelationshipRankChanged: (candidateId, schaledbId, value) {
              _relationshipRankInputs.putIfAbsent(
                candidateId,
                () => {},
              )[schaledbId] = value;
            },
          );
          final detail = _ResultStateFrame(
            key: ValueKey('scan-student-result-frame-$selectedId'),
            problem: problem,
            child: wide
                ? _ResultDetailScrollView(
                    key: ValueKey('scan-student-detail-scroll-$selectedId'),
                    child: _buildDetail(selected, problem, wide),
                  )
                : _buildDetail(selected, problem, wide),
          );
          if (wide) {
            return SizedBox(
              height: 590,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 340, child: list),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: detail),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: math.min(300, 82.0 * _resultEntries().length),
                child: list,
              ),
              const SizedBox(height: AppSpacing.sm),
              detail,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetail(ScannerCandidate candidate, bool problem, bool wide) {
    final id = _studentId(candidate);
    final current = widget.currentStudents[id]?.values ?? const {};
    final scanned = _editing.contains(candidate.id)
        ? _draft(candidate)
        : _values(candidate);
    final expected = _expected(candidate);
    final delta = _delta(candidate);
    final relationshipContributions = _relationshipContributions(candidate);
    final fields = <String>{...current.keys, ...scanned.keys};
    const statToField = {
      'MaxHP': 'combat_hp',
      'AttackPower': 'combat_atk',
      'DefensePower': 'combat_def',
      'HealPower': 'combat_heal',
    };
    fields.addAll(statToField.values.where((field) => expected.isNotEmpty));
    final ordered = fields.toList()..sort();
    final busy = widget.busyCandidateIds.contains(candidate.id);
    return DiagonalSection(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 38, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/student_portraits/$id.png',
                    width: 82,
                    height: 82,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 82,
                      height: 82,
                      child: Icon(Icons.person_outline, size: 42),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(candidate),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Candidate ${candidate.id} · revision ${candidate.revision}',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Chip(
                        avatar: Icon(
                          problem ? Icons.error_outline : Icons.check_circle,
                          color: problem ? AppColors.danger : AppColors.success,
                        ),
                        label: Text(_status(candidate)),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  key: ValueKey('scan-student-more-${candidate.id}'),
                  enabled: !busy,
                  onSelected: (value) {
                    if (value == 'discard') _discard(candidate);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'discard', child: Text('후보 폐기')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.candidateErrors[candidate.id] case final error?) ...[
              Text(error, style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: AppSpacing.sm),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: problem
                  ? [
                      FilledButton.tonalIcon(
                        key: ValueKey('scan-student-edit-${candidate.id}'),
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                _draft(candidate);
                                _editing.add(candidate.id);
                              }),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('수정'),
                      ),
                      FilledButton.icon(
                        key: ValueKey(
                          'scan-student-revalidate-${candidate.id}',
                        ),
                        onPressed: busy ? null : () => _revalidate(candidate),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('재검증'),
                      ),
                      OutlinedButton.icon(
                        key: ValueKey('scan-student-hold-${candidate.id}'),
                        onPressed: busy ? null : () => widget.onHold(candidate),
                        icon: const Icon(Icons.pause_circle_outline),
                        label: const Text('보류'),
                      ),
                    ]
                  : [
                      FilledButton.icon(
                        key: ValueKey('scan-student-apply-${candidate.id}'),
                        onPressed: busy
                            ? null
                            : () => widget.onApply(candidate),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('적용'),
                      ),
                    ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '현재 확정값 / 스캔값 / 계산값 / 차이',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (wide)
              _ComparisonTable(
                fields: ordered,
                current: current,
                scanned: scanned,
                expected: expected,
                delta: delta,
                statToField: statToField,
                editing: _editing.contains(candidate.id),
                onChanged: (field, value) => _edit(candidate, field, value),
              )
            else
              for (final field in ordered)
                _ComparisonCard(
                  field: field,
                  current: current[field],
                  scanned: scanned[field],
                  calculated: _calculated(field, expected, statToField),
                  delta: _calculatedDelta(field, delta, statToField),
                  editing: _editing.contains(candidate.id),
                  onChanged: (value) => _edit(candidate, field, value),
                ),
            if (_localErrors[candidate.id] case final error?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  error,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            ExpansionTile(
              key: ValueKey('scan-student-evidence-${candidate.id}'),
              tilePadding: EdgeInsets.zero,
              title: const Text('상세 증거'),
              children: [
                if (relationshipContributions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _RelationshipContributionPanel(
                      rows: relationshipContributions,
                      catalog: widget.catalog,
                    ),
                  ),
                for (final evidence in candidate.evidence)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${evidence.field} · ${evidence.status}'),
                    subtitle: Text(
                      '${evidence.source}'
                      '${evidence.confidence == null ? '' : ' · ${(evidence.confidence! * 100).toStringAsFixed(1)}%'}'
                      '${evidence.note.isEmpty ? '' : '\n${evidence.note}'}',
                    ),
                  ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  void _edit(ScannerCandidate candidate, String field, String text) {
    final original = _values(candidate)[field];
    dynamic value = text;
    if (original is int) {
      value = int.tryParse(text);
      if (value == null) {
        setState(() => _localErrors[candidate.id] = '$field 값은 정수여야 합니다.');
        return;
      }
    }
    setState(() {
      _draft(candidate)[field] = value;
      _localErrors.remove(candidate.id);
    });
  }

  static Object? _calculated(
    String field,
    Map<String, dynamic> expected,
    Map<String, String> statToField,
  ) {
    for (final entry in statToField.entries) {
      if (entry.value == field) return expected[entry.key];
    }
    return null;
  }

  static Object? _calculatedDelta(
    String field,
    Map<String, dynamic> delta,
    Map<String, String> statToField,
  ) {
    for (final entry in statToField.entries) {
      if (entry.value == field) return delta[entry.key];
    }
    return null;
  }
}

class _RelationshipContributionPanel extends StatelessWidget {
  const _RelationshipContributionPanel({
    required this.rows,
    required this.catalog,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, StudentCatalogEntry> catalog;

  String _modifier(Map<String, dynamic> row) {
    final modifier = row['modifier'];
    if (modifier is! Map) {
      return row['owned'] == false ? '미보유 · 합산 제외' : '확인 필요';
    }
    final values = <String>[];
    for (final section in const [
      'flat',
      'coefficient_basis_points',
      'separated_flat',
    ]) {
      final stats = modifier[section];
      if (stats is! Map) continue;
      for (final entry in stats.entries) {
        final suffix = section == 'coefficient_basis_points' ? ' bp' : '';
        values.add('${entry.key} +${entry.value}$suffix');
      }
    }
    return values.isEmpty ? '보너스 0' : values.join(' · ');
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('다른 의상 인연 보너스 검증', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.xs),
      Text(
        '각 의상의 확인된 인연 랭크와 실제 합산값을 함께 표시합니다.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final row in rows)
            Container(
              key: ValueKey('relationship-contribution-${row['schaledb_id']}'),
              width: 210,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: row['applied'] == true
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/student_portraits/${row['student_id'] ?? 'unknown'}.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          catalog[row['student_id']]?.displayName ??
                              (row['student_id'] as String? ?? '미확인 의상'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text('인연 ${row['rank'] ?? '미확인'}'),
                        Text(
                          _modifier(row),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    row['applied'] == true
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 18,
                    color: row['applied'] == true
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}

class _ResultDetailScrollView extends StatefulWidget {
  const _ResultDetailScrollView({super.key, required this.child});

  final Widget child;

  @override
  State<_ResultDetailScrollView> createState() =>
      _ResultDetailScrollViewState();
}

class _ResultDetailScrollViewState extends State<_ResultDetailScrollView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _controller,
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: widget.child,
    ),
  );
}

@immutable
class _ResultListEntry {
  const _ResultListEntry._({
    required this.candidate,
    required this.group,
    required this.firstInGroup,
    this.relationship,
  });

  factory _ResultListEntry.candidate(
    ScannerCandidate candidate, {
    required String group,
    required bool firstInGroup,
  }) => _ResultListEntry._(
    candidate: candidate,
    group: group,
    firstInGroup: firstInGroup,
  );

  factory _ResultListEntry.relationship(
    ScannerCandidate candidate,
    Map<String, dynamic> relationship,
  ) => _ResultListEntry._(
    candidate: candidate,
    group: relationship['student_id'] as String? ?? candidate.id,
    firstInGroup: false,
    relationship: relationship,
  );

  final ScannerCandidate candidate;
  final String group;
  final bool firstInGroup;
  final Map<String, dynamic>? relationship;

  bool get isRelationship => relationship != null;
  String get key => isRelationship
      ? '${candidate.id}-relationship-${relationship!['schaledb_id']}'
      : candidate.id;
}

double scanResultRowLeft({
  required double viewportHeight,
  required double rowTop,
  required double rowHeight,
  required double scrollOffset,
}) =>
    10 / math.sin(80 * math.pi / 180) +
    (viewportHeight - (rowTop + rowHeight - scrollOffset)) /
        math.tan(80 * math.pi / 180);

class _ResultList extends StatefulWidget {
  const _ResultList({
    required this.entries,
    required this.selectedId,
    required this.displayName,
    required this.status,
    required this.hasProblem,
    required this.onSelected,
    required this.catalog,
    required this.relationshipRankInputs,
    required this.onRelationshipRankChanged,
  });

  final List<_ResultListEntry> entries;
  final String selectedId;
  final String Function(ScannerCandidate) displayName;
  final String Function(ScannerCandidate) status;
  final bool Function(ScannerCandidate) hasProblem;
  final ValueChanged<String> onSelected;
  final Map<String, StudentCatalogEntry> catalog;
  final Map<String, Map<int, String>> relationshipRankInputs;
  final void Function(String candidateId, int schaledbId, String value)
  onRelationshipRankChanged;

  @override
  State<_ResultList> createState() => _ResultListState();
}

class _ResultListState extends State<_ResultList> {
  static const _verticalInset = 8.0;
  static const _candidateHeight = 74.0;
  static const _relationshipHeight = 82.0;
  static const _rowGap = 8.0;
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DiagonalSection(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('학생 스캔 결과', style: Theme.of(context).textTheme.titleLarge),
          Text(
            '같은 학생의 의상은 이어서 표시됩니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildDiagonalList()),
        ],
      ),
    ),
  );

  Widget _buildDiagonalList() => LayoutBuilder(
    builder: (context, constraints) {
      final heights = [
        for (final entry in widget.entries)
          entry.isRelationship ? _relationshipHeight : _candidateHeight,
      ];
      final contentHeight =
          _verticalInset * 2 +
          heights.fold<double>(0, (sum, height) => sum + height) +
          _rowGap * math.max(0, widget.entries.length - 1);
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final maxScroll = math.max(
            0.0,
            contentHeight - constraints.maxHeight,
          );
          final scroll = _controller.hasClients
              ? _controller.offset.clamp(0.0, maxScroll).toDouble()
              : 0.0;
          var top = _verticalInset;
          final rows = <Widget>[];
          for (var index = 0; index < widget.entries.length; index++) {
            final entry = widget.entries[index];
            final height = heights[index];
            rows.add(
              Positioned(
                key: ValueKey('scan-result-row-host-${entry.key}'),
                left: scanResultRowLeft(
                  viewportHeight: constraints.maxHeight,
                  rowTop: top,
                  rowHeight: height,
                  scrollOffset: scroll,
                ),
                top: top,
                width: math.max(
                  180,
                  constraints.maxWidth -
                      constraints.maxHeight / math.tan(80 * math.pi / 180) -
                      22 +
                      height / math.tan(80 * math.pi / 180),
                ),
                height: height,
                child: entry.isRelationship
                    ? _RelationshipRankResultRow(
                        entry: entry,
                        catalog: widget.catalog,
                        value:
                            widget.relationshipRankInputs[entry
                                .candidate
                                .id]?[entry.relationship!['schaledb_id']] ??
                            entry.relationship!['rank']?.toString() ??
                            '',
                        onChanged: (value) {
                          final id = entry.relationship!['schaledb_id'];
                          if (id is int) {
                            widget.onRelationshipRankChanged(
                              entry.candidate.id,
                              id,
                              value,
                            );
                          }
                        },
                      )
                    : _CandidateResultRow(
                        entry: entry,
                        selected: entry.candidate.id == widget.selectedId,
                        problem: widget.hasProblem(entry.candidate),
                        displayName: widget.displayName(entry.candidate),
                        status: widget.status(entry.candidate),
                        onSelected: () => widget.onSelected(entry.candidate.id),
                      ),
              ),
            );
            top += height + _rowGap;
          }
          final showTop = scroll > 0.5;
          final showBottom = scroll < maxScroll - 0.5;
          return Stack(
            fit: StackFit.expand,
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  key: const ValueKey('scan-student-result-list'),
                  controller: _controller,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: contentHeight,
                    child: Stack(clipBehavior: Clip.none, children: rows),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ScrollViewportFog(
                    key: const ValueKey('scan-student-result-list-fog'),
                    keyPrefix: 'scan-student-result-list-viewport-fog',
                    showTop: showTop,
                    showBottom: showBottom,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _CandidateResultRow extends StatelessWidget {
  const _CandidateResultRow({
    required this.entry,
    required this.selected,
    required this.problem,
    required this.displayName,
    required this.status,
    required this.onSelected,
  });

  final _ResultListEntry entry;
  final bool selected;
  final bool problem;
  final String displayName;
  final String status;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final id = entry.candidate.payload['student_id'] as String? ?? 'unknown';
    return _ResultStateFrame(
      problem: problem,
      selected: selected,
      child: DiagonalSection(
        child: InkWell(
          key: ValueKey('scan-student-result-${entry.candidate.id}'),
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 24, 7),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/student_portraits/$id.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(Icons.person_outline),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: problem ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  problem ? Icons.error_outline : Icons.check_circle,
                  color: problem ? AppColors.danger : AppColors.success,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RelationshipRankResultRow extends StatelessWidget {
  const _RelationshipRankResultRow({
    required this.entry,
    required this.catalog,
    required this.value,
    required this.onChanged,
  });

  final _ResultListEntry entry;
  final Map<String, StudentCatalogEntry> catalog;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final row = entry.relationship!;
    final studentId = row['student_id'] as String? ?? 'unknown';
    final schaledbId = row['schaledb_id'];
    final name = catalog[studentId]?.displayName ?? studentId;
    return _ResultStateFrame(
      problem: row['applied'] != true,
      child: DiagonalSection(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 18, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/student_portraits/$studentId.png',
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(Icons.person_outline),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$name\n다른 보유 의상',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 88,
                child: TextFormField(
                  key: ValueKey(
                    'alternate-rank-${entry.candidate.id}-$schaledbId',
                  ),
                  initialValue: value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '인연 랭크',
                    hintText: '1~100',
                    isDense: true,
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultStateFrame extends StatelessWidget {
  const _ResultStateFrame({
    super.key,
    required this.problem,
    required this.child,
    this.selected = false,
  });

  final bool problem;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: problem ? '문제 있는 스캔 결과' : '문제 없는 스캔 결과',
    child: CustomPaint(
      foregroundPainter: _DiagonalStatusBorderPainter(
        problem ? AppColors.danger : AppColors.success,
        selected ? 3.2 : 2.0,
      ),
      child: child,
    ),
  );
}

class _DiagonalStatusBorderPainter extends CustomPainter {
  const _DiagonalStatusBorderPainter(this.color, this.width);
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final path = const DiagonalSectionClipper().getClip(size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DiagonalStatusBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.width != width;
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.fields,
    required this.current,
    required this.scanned,
    required this.expected,
    required this.delta,
    required this.statToField,
    required this.editing,
    required this.onChanged,
  });
  final List<String> fields;
  final Map<String, dynamic> current;
  final Map<String, dynamic> scanned;
  final Map<String, dynamic> expected;
  final Map<String, dynamic> delta;
  final Map<String, String> statToField;
  final bool editing;
  final void Function(String field, String value) onChanged;

  @override
  Widget build(BuildContext context) => Table(
    border: TableBorder.all(color: AppColors.outline),
    columnWidths: const {
      0: FlexColumnWidth(1.25),
      1: FlexColumnWidth(),
      2: FlexColumnWidth(),
      3: FlexColumnWidth(),
      4: FlexColumnWidth(),
    },
    children: [
      const TableRow(
        children: [
          _TableCellText('필드', header: true),
          _TableCellText('현재 확정값', header: true),
          _TableCellText('스캔값', header: true),
          _TableCellText('계산값', header: true),
          _TableCellText('차이', header: true),
        ],
      ),
      for (final field in fields)
        TableRow(
          children: [
            _TableCellText(field),
            _TableCellText('${current[field] ?? '—'}'),
            editing
                ? Padding(
                    padding: const EdgeInsets.all(4),
                    child: TextFormField(
                      key: ValueKey('scan-student-field-$field'),
                      initialValue: '${scanned[field] ?? ''}',
                      onChanged: (value) => onChanged(field, value),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  )
                : _TableCellText('${scanned[field] ?? '—'}'),
            _TableCellText(
              '${_ScanStudentReviewWorkspaceState._calculated(field, expected, statToField) ?? '—'}',
            ),
            _TableCellText(
              '${_ScanStudentReviewWorkspaceState._calculatedDelta(field, delta, statToField) ?? '—'}',
            ),
          ],
        ),
    ],
  );
}

class _TableCellText extends StatelessWidget {
  const _TableCellText(this.text, {this.header = false});
  final String text;
  final bool header;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(
      text,
      style: TextStyle(fontWeight: header ? FontWeight.w800 : FontWeight.w500),
    ),
  );
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.field,
    required this.current,
    required this.scanned,
    required this.calculated,
    required this.delta,
    required this.editing,
    required this.onChanged,
  });
  final String field;
  final Object? current;
  final Object? scanned;
  final Object? calculated;
  final Object? delta;
  final bool editing;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                Text('현재 ${current ?? '—'}'),
                if (editing)
                  SizedBox(
                    width: 130,
                    child: TextFormField(
                      key: ValueKey('scan-student-field-$field'),
                      initialValue: '${scanned ?? ''}',
                      onChanged: onChanged,
                      decoration: const InputDecoration(
                        labelText: '스캔값',
                        isDense: true,
                      ),
                    ),
                  )
                else
                  Text('스캔 ${scanned ?? '—'}'),
                Text('계산 ${calculated ?? '—'}'),
                Text('차이 ${delta ?? '—'}'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
