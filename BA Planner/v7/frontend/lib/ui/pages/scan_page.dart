import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../widgets/diagonal_section.dart';
import '../widgets/repository_profile_panel.dart';

enum _SessionStage { idle, starting, running, cancelling, terminal }

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.service,
    required this.onCandidateHandoff,
    this.onRecentChanged,
  });

  final AppService service;
  final void Function(ScannerSession session, ScannerCandidate candidate)
  onCandidateHandoff;
  final ValueChanged<List<ScannerRecentSummary>>? onRecentChanged;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  ScannerService? get _scanner => widget.service is ScannerService
      ? widget.service as ScannerService
      : null;
  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;

  StreamSubscription<ScannerEvent>? _subscription;
  List<ScannerTarget> _targets = const [];
  Map<String, dynamic>? _readiness;
  RepositoryProfile? _profile;
  String? _targetId;
  ScannerKind _kind = ScannerKind.student;
  bool _targetsLoading = true;
  bool _readinessLoading = true;
  bool _recovering = false;
  String? _targetError;
  String? _readinessError;
  String? _sessionError;

  _SessionStage _stage = _SessionStage.idle;
  ScannerSession? _session;
  final List<ScannerEvent> _pendingStartEvents = [];
  String? _phase;
  int? _progressCurrent;
  int? _progressTotal;
  String? _messageKey;
  String? _diagnostic;
  String? _outcome;
  Map<String, dynamic>? _terminalError;
  final Map<String, ScannerCandidate> _candidates = {};
  final List<ScannerRecentSummary> _recent = [];

  bool get _connected =>
      widget.service.state.value.connection == BackendConnection.connected;
  bool get _recognitionReady => _readiness?['ready'] == true;
  ScannerTarget? get _selectedTarget {
    for (final target in _targets) {
      if (target.id == _targetId) return target;
    }
    return null;
  }

  bool get _canStart =>
      _connected &&
      _scanner != null &&
      _repository != null &&
      _profile != null &&
      _recognitionReady &&
      _selectedTarget?.status == ScannerTargetStatus.ready &&
      (_stage == _SessionStage.idle || _stage == _SessionStage.terminal);

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
    final scanner = _scanner;
    if (scanner != null) {
      _subscription = scanner.scannerEvents.listen(
        _handleEvent,
        onError: _handleStreamError,
      );
    }
    _refreshPreparation();
  }

  @override
  void dispose() {
    widget.service.state.removeListener(_connectionChanged);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _connectionChanged() {
    if (!mounted) return;
    setState(() {
      if (!_connected &&
          (_stage == _SessionStage.running ||
              _stage == _SessionStage.cancelling)) {
        _sessionError =
            'Backend disconnected. Reconnect, then recover the active snapshot.';
      }
    });
  }

  Future<void> _refreshPreparation() async {
    final scanner = _scanner;
    if (scanner == null) {
      setState(() {
        _targetsLoading = false;
        _readinessLoading = false;
        _targetError = 'Scanner service is unavailable.';
        _readinessError = 'Scanner service is unavailable.';
      });
      return;
    }
    setState(() {
      _targetsLoading = true;
      _readinessLoading = true;
      _targetError = null;
      _readinessError = null;
    });
    try {
      final readiness = await scanner.scannerReadiness();
      if (readiness['ready'] is! bool ||
          readiness['missing'] is! List ||
          readiness['corrupt'] is! List) {
        throw const FormatException('Invalid recognition readiness');
      }
      if (mounted) setState(() => _readiness = readiness);
    } catch (error) {
      if (mounted) {
        setState(() => _readinessError = 'Readiness failed: $error');
      }
    } finally {
      if (mounted) setState(() => _readinessLoading = false);
    }
    try {
      final targets = await scanner.listScannerTargets();
      if (!mounted) return;
      setState(() {
        _targets = targets;
        if (!targets.any((item) => item.id == _targetId)) _targetId = null;
      });
    } catch (error) {
      if (mounted) setState(() => _targetError = 'Target list failed: $error');
    } finally {
      if (mounted) setState(() => _targetsLoading = false);
    }
  }

  Future<void> _start() async {
    final scanner = _scanner;
    final target = _selectedTarget;
    if (!_canStart || scanner == null || target == null) return;
    setState(() {
      _stage = _SessionStage.starting;
      _session = null;
      _sessionError = null;
      _pendingStartEvents.clear();
      _resetProjection();
    });
    try {
      final session = await scanner.startScannerSession(_kind, target.id);
      if (!mounted) return;
      setState(() {
        _session = session;
        _stage = _SessionStage.running;
        final buffered = List<ScannerEvent>.from(_pendingStartEvents);
        _pendingStartEvents.clear();
        for (final event in buffered) {
          if (event.sessionId == session.id &&
              event.generation == session.generation) {
            _applyEvent(event);
          }
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _stage = _SessionStage.idle;
          _sessionError = 'Could not start scan: $error';
        });
      }
    }
  }

  Future<void> _cancel() async {
    final scanner = _scanner;
    final session = _session;
    if (scanner == null ||
        session == null ||
        _stage != _SessionStage.running) {
      return;
    }
    setState(() {
      _stage = _SessionStage.cancelling;
      _sessionError = null;
    });
    try {
      await scanner.cancelScannerSession(session);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() {
          _stage = _SessionStage.running;
          _sessionError = 'Cancel request failed: $error';
        });
      }
    }
  }

  Future<void> _recoverSnapshot() async {
    final scanner = _scanner;
    final session = _session;
    if (scanner == null || session == null || _recovering) return;
    setState(() {
      _recovering = true;
      _sessionError = null;
    });
    try {
      final snapshot = await scanner.scannerSnapshot(session);
      if (!mounted) return;
      setState(() {
        _resetProjection();
        _stage = _SessionStage.running;
        for (final candidate in snapshot.candidates) {
          _keepCandidate(candidate);
        }
        for (final event in snapshot.events) {
          _applyEvent(event, recordRecent: false);
        }
        if (snapshot.terminal != null && _stage != _SessionStage.terminal) {
          _outcome = snapshot.terminal;
          _stage = _SessionStage.terminal;
        }
        if (_stage == _SessionStage.terminal) _recordRecent();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _sessionError =
              'Snapshot recovery failed; the previous projection was kept: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (!mounted || _session == null) return;
    setState(() => _sessionError = 'Scanner event stream needs recovery: $error');
    unawaited(_recoverSnapshot());
  }

  void _handleEvent(ScannerEvent event) {
    if (!mounted) return;
    if (_stage == _SessionStage.starting && _session == null) {
      _pendingStartEvents.add(event);
      return;
    }
    final session = _session;
    if (session == null ||
        event.sessionId != session.id ||
        event.generation != session.generation ||
        _stage == _SessionStage.terminal) {
      return;
    }
    setState(() => _applyEvent(event));
  }

  void _applyEvent(ScannerEvent event, {bool recordRecent = true}) {
    switch (event.eventKind) {
      case ScannerEventKind.phase:
        _phase = event.payload['phase'] as String?;
        break;
      case ScannerEventKind.progress:
        _progressCurrent = event.payload['current'] as int?;
        _progressTotal = event.payload['total'] as int?;
        _messageKey = event.payload['message_key'] as String?;
        break;
      case ScannerEventKind.diagnostic:
        final code = event.payload['code'];
        final message = event.payload['message'];
        _diagnostic = [code, message]
            .where((item) => item is String && item.isNotEmpty)
            .join(': ');
        break;
      case ScannerEventKind.candidate:
        final raw = event.payload['candidate'];
        if (raw is Map) {
          _keepCandidate(
            ScannerCandidate.fromWire(Map<String, dynamic>.from(raw)),
          );
        }
        break;
      case ScannerEventKind.terminal:
        _outcome = event.payload['outcome'] as String?;
        final error = event.payload['error'];
        _terminalError = error is Map
            ? Map<String, dynamic>.from(error)
            : null;
        _stage = _SessionStage.terminal;
        if (recordRecent) _recordRecent();
        break;
    }
  }

  void _keepCandidate(ScannerCandidate candidate) {
    final current = _candidates[candidate.id];
    if (current == null || candidate.revision > current.revision) {
      _candidates[candidate.id] = candidate;
    }
  }

  void _resetProjection() {
    _phase = null;
    _progressCurrent = null;
    _progressTotal = null;
    _messageKey = null;
    _diagnostic = null;
    _outcome = null;
    _terminalError = null;
    _candidates.clear();
  }

  void _recordRecent() {
    final session = _session;
    final target = _selectedTarget;
    if (session == null) return;
    _recent.removeWhere(
      (item) =>
          item.sessionId == session.id && item.generation == session.generation,
    );
    _recent.insert(
      0,
      ScannerRecentSummary(
        session: session,
        targetId: target?.id ?? _targetId ?? '',
        targetTitle: target?.title ?? _targetId ?? 'Unknown target',
        outcome: _outcome ?? 'unknown',
        phase: _phase,
        diagnostic: _diagnostic ?? _terminalError?['message'] as String?,
        candidateCount: _candidates.length,
        reviewRequired: _candidates.values.any((item) => item.reviewRequired),
        progressCurrent: _progressCurrent,
        progressTotal: _progressTotal,
        messageKey: _messageKey,
        terminalError: _terminalError,
        candidates: _candidates.values.toList(growable: false),
      ),
    );
    if (_recent.length > 8) _recent.removeRange(8, _recent.length);
    widget.onRecentChanged?.call(
      List<ScannerRecentSummary>.unmodifiable(_recent),
    );
  }

  void _openRecent(ScannerRecentSummary item) {
    setState(() {
      _session = item.session;
      _kind = item.kind;
      _targetId = _targets.any((target) => target.id == item.targetId)
          ? item.targetId
          : null;
      _stage = _SessionStage.terminal;
      _phase = item.phase;
      _diagnostic = item.diagnostic;
      _progressCurrent = item.progressCurrent;
      _progressTotal = item.progressTotal;
      _messageKey = item.messageKey;
      _outcome = item.outcome;
      _terminalError = item.terminalError;
      _candidates
        ..clear()
        ..addEntries(item.candidates.map((item) => MapEntry(item.id, item)));
      _sessionError = null;
    });
  }

  void _handoff(ScannerCandidate candidate) {
    final session = _session;
    if (session == null ||
        candidate.sessionId != session.id ||
        candidate.generation != session.generation ||
        candidate.kind != session.kind ||
        !_payloadMatchesKind(candidate)) {
      setState(() => _sessionError = 'Candidate kind or payload mismatch.');
      return;
    }
    widget.onCandidateHandoff(session, candidate);
  }

  bool _payloadMatchesKind(ScannerCandidate candidate) {
    if (candidate.payload['version'] != 1) return false;
    return switch (candidate.kind) {
      ScannerKind.student =>
        candidate.payload['student_id'] is String &&
            candidate.payload['values'] is Map,
      ScannerKind.inventory => candidate.payload['entries'] is List,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scannerMissing = _scanner == null;
    final repositoryMissing = _repository == null;
    final readinessMissing =
        (_readiness?['missing'] as List?)?.length ?? 0;
    final readinessCorrupt =
        (_readiness?['corrupt'] as List?)?.length ?? 0;
    final selectedTarget = _selectedTarget;
    final total = _progressTotal;
    final progress = total == null || total <= 0 || _progressCurrent == null
        ? null
        : (_progressCurrent! / total).clamp(0.0, 1.0).toDouble();

    return ListView(
      key: const ValueKey('scan-page'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        RepositoryProfilePanel(
          service: widget.service,
          onSelected: (profile) => setState(() => _profile = profile),
        ),
        const SizedBox(height: AppSpacing.sm),
        DiagonalSection(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 36, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Scan preparation',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    _StatusChip(
                      label: _connected ? 'Backend connected' : 'Backend disconnected',
                      ok: _connected,
                    ),
                    _StatusChip(
                      label: _recognitionReady
                          ? 'Recognition ready'
                          : 'Recognition not ready',
                      ok: _recognitionReady,
                    ),
                    _StatusChip(
                      label: _profile == null
                          ? 'No profile selected'
                          : 'Profile: ${_profile!.displayName}',
                      ok: _profile != null,
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('scan-refresh'),
                      onPressed: _targetsLoading || _readinessLoading
                          ? null
                          : _refreshPreparation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_readinessLoading || _targetsLoading)
                  const LinearProgressIndicator(),
                Text(
                  'Manifest ${_readiness?['manifest_version'] ?? 'unknown'} · '
                  'missing $readinessMissing · corrupt $readinessCorrupt',
                  key: const ValueKey('scan-readiness-summary'),
                ),
                if (scannerMissing)
                  const Text('Scanner service is unavailable.'),
                if (repositoryMissing)
                  const Text('Repository service is unavailable.'),
                if (_readinessError != null)
                  Text(_readinessError!, style: const TextStyle(color: AppColors.danger)),
                if (_targetError != null)
                  Text(_targetError!, style: const TextStyle(color: AppColors.danger)),
                if (!_targetsLoading && _targets.isEmpty)
                  const Text('No game windows were found. Open Blue Archive and refresh.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DiagonalSection(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 36, 18),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 420,
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('scan-target'),
                    initialValue: _targetId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Game window target'),
                    items: [
                      for (final target in _targets)
                        DropdownMenuItem(
                          value: target.id,
                          child: Text(
                            '${target.title} · ${target.status.name}'
                            '${target.foreground ? ' · foreground' : ''} · ${target.id}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _stage == _SessionStage.running ||
                            _stage == _SessionStage.cancelling ||
                            _stage == _SessionStage.starting
                        ? null
                        : (value) => setState(() => _targetId = value),
                  ),
                ),
                SegmentedButton<ScannerKind>(
                  key: const ValueKey('scan-kind'),
                  segments: const [
                    ButtonSegment(
                      value: ScannerKind.student,
                      label: Text('Student'),
                      icon: Icon(Icons.school_outlined),
                    ),
                    ButtonSegment(
                      value: ScannerKind.inventory,
                      label: Text('Inventory'),
                      icon: Icon(Icons.inventory_2_outlined),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: _stage == _SessionStage.running ||
                          _stage == _SessionStage.cancelling ||
                          _stage == _SessionStage.starting
                      ? null
                      : (value) => setState(() => _kind = value.first),
                ),
                FilledButton.icon(
                  key: const ValueKey('scan-start'),
                  onPressed: _canStart ? _start : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start scan'),
                ),
                if (selectedTarget != null &&
                    selectedTarget.status != ScannerTargetStatus.ready)
                  Text(
                    'Selected target is ${selectedTarget.status.name}; choose a ready target.',
                    style: const TextStyle(color: AppColors.warning),
                  ),
              ],
            ),
          ),
        ),
        if (_stage != _SessionStage.idle) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildSession(progress),
        ],
        if (_recent.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildRecent(),
        ],
      ],
    );
  }

  Widget _buildSession(double? progress) => DiagonalSection(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 36, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Session ${_session?.id ?? 'starting'} · generation ${_session?.generation ?? '-'}',
                key: const ValueKey('scan-session'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Chip(label: Text(_stage.name)),
              if (_phase != null) Chip(label: Text('Phase: $_phase')),
              if (_outcome != null) Chip(label: Text('Outcome: $_outcome')),
              FilledButton.tonalIcon(
                key: const ValueKey('scan-cancel'),
                onPressed: _stage == _SessionStage.running ? _cancel : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(
                  _stage == _SessionStage.cancelling ? 'Cancelling…' : 'Cancel',
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('scan-retry'),
                onPressed: _stage == _SessionStage.terminal && _canStart
                    ? _start
                    : null,
                icon: const Icon(Icons.replay),
                label: const Text('Retry'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('scan-recover'),
                onPressed: _session == null || _recovering
                    ? null
                    : _recoverSnapshot,
                icon: const Icon(Icons.sync),
                label: Text(_recovering ? 'Recovering…' : 'Recover snapshot'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: progress == null
                ? 'Scan progress indeterminate'
                : 'Scan progress ${_progressCurrent ?? 0} of $_progressTotal',
            child: LinearProgressIndicator(value: progress),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _progressCurrent == null
                ? 'Waiting for progress'
                : _progressTotal == null || _progressTotal == 0
                ? '${_progressCurrent!} · total unknown'
                : '${_progressCurrent!} / $_progressTotal',
            key: const ValueKey('scan-progress'),
          ),
          if (_messageKey != null) Text('Message: $_messageKey'),
          if (_diagnostic != null)
            SelectableText('Diagnostic: $_diagnostic'),
          if (_terminalError != null)
            SelectableText(
              'Terminal error: ${_terminalError!['code']} · ${_terminalError!['message']}',
              style: const TextStyle(color: AppColors.danger),
            ),
          if (_sessionError != null)
            SelectableText(
              _sessionError!,
              style: const TextStyle(color: AppColors.danger),
            ),
          for (final candidate in _candidates.values) ...[
            const Divider(),
            _CandidateSummary(candidate: candidate, onHandoff: () => _handoff(candidate)),
          ],
        ],
      ),
    ),
  );

  Widget _buildRecent() => DiagonalSection(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 36, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent sessions in this app run',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final item in _recent)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${item.kind.name} · ${item.targetTitle} · ${item.outcome}',
              ),
              subtitle: Text(
                'generation ${item.generation} · phase ${item.phase ?? 'unknown'} · '
                '${item.candidateCount} candidate(s)'
                '${item.reviewRequired ? ' · review required' : ''}'
                '${item.diagnostic == null ? '' : ' · ${item.diagnostic}'}',
              ),
              trailing: OutlinedButton(
                key: ValueKey('scan-recent-${item.session.id}'),
                onPressed: () => _openRecent(item),
                child: const Text('Open'),
              ),
            ),
        ],
      ),
    ),
  );
}
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(ok ? Icons.check_circle : Icons.error_outline, size: 18),
    label: Text(label),
  );
}

class _CandidateSummary extends StatelessWidget {
  const _CandidateSummary({required this.candidate, required this.onHandoff});
  final ScannerCandidate candidate;
  final VoidCallback onHandoff;

  String get _payloadSummary {
    if (candidate.kind == ScannerKind.student) {
      final values = candidate.payload['values'];
      return 'Student ${candidate.payload['student_id']} · '
          '${values is Map ? values.length : 0} observed field(s)';
    }
    final entries = candidate.payload['entries'];
    final unknown = entries is List
        ? entries.where((item) => item is Map && item['quantity'] == null).length
        : 0;
    return 'Inventory · ${entries is List ? entries.length : 0} entry(s) · '
        '$unknown unknown quantity';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Candidate ${candidate.id} · revision ${candidate.revision}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Chip(label: Text(candidate.kind.name)),
          if (candidate.reviewRequired) const Chip(label: Text('Review required')),
          if (candidate.approved) const Chip(label: Text('Approved')),
        ],
      ),
      Text(_payloadSummary),
      for (final evidence in candidate.evidence)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${evidence.field}: ${evidence.status} · ${evidence.source}'
            '${evidence.confidence == null ? '' : ' · ${(evidence.confidence! * 100).toStringAsFixed(1)}%'}'
            '${evidence.note.isEmpty ? '' : ' · ${evidence.note}'}',
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      FilledButton.icon(
        key: ValueKey('scan-review-${candidate.id}'),
        onPressed: onHandoff,
        icon: const Icon(Icons.rate_review_outlined),
        label: Text(
          candidate.kind == ScannerKind.student
              ? 'Review in Students'
              : 'Review in Inventory',
        ),
      ),
    ],
  );
}
