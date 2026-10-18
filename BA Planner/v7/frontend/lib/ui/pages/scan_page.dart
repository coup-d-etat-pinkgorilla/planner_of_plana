import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../../services/student_scan_diagnostic.dart';
import '../../services/window_dock_service.dart';
import '../kit/kit_overlay.dart' show KitOverlayEscape;
import '../scan/connected_target_controller.dart';
import '../scan/scan_session_controller.dart';
import '../widgets/diagonal_section.dart';
import '../widgets/repository_profile_panel.dart';
import '../widgets/scan_companion_dock.dart';
import '../widgets/scan_inventory_identity_review.dart';
import '../widgets/scan_student_review_workspace.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.service,
    required this.onCandidateHandoff,
    this.controller,
    this.onRecentChanged,
    this.onCompanionChanged,
    this.windowDockService = const WindowsWindowDockService(),
    this.studentScanDiagnosticFileService =
        const NativeStudentScanDiagnosticFileService(),
    this.now = DateTime.now,
    this.active = true,
    this.connectedTarget,
    this.showStudentReview = true,
    this.showItemReview = true,
  });

  final AppService service;

  /// 후보를 다른 탭으로 넘긴다. 전술 로비 후보만 넘긴다(FE9-c) — 학생 · 아이템 후보는 스캔 탭 결과 검토 보드가 적용한다
  /// (FE8-g4b · FE8-g5b, I-scan §9.1 인계 제거).
  final void Function(ScannerSession session, ScannerCandidate candidate)
  onCandidateHandoff;

  /// 세션 상태를 가진 컨트롤러(FE8-f1). 셸이 소유한 것을 주면 화면이 사라져도 세션이 남는다. 이때 아래
  /// [onRecentChanged] · [onCompanionChanged] · [windowDockService] · [studentScanDiagnosticFileService] · [now] ·
  /// [connectedTarget]은 쓰지 않고 컨트롤러의 값을 쓴다. null이면 화면이 이 값들로 자기 컨트롤러를 만들고 dispose한다.
  final ScanSessionController? controller;
  final ValueChanged<List<ScannerRecentSummary>>? onRecentChanged;
  final ValueChanged<ScanCompanionState?>? onCompanionChanged;
  final WindowDockService windowDockService;
  final StudentScanDiagnosticFileService studentScanDiagnosticFileService;
  final DateTime Function() now;

  /// 스캔 탭이 보이는가. 보일 때만 Esc가 진행 중(일시정지 포함) 스캔을 중지한다(FD-142, fb10a-dart).
  final bool active;

  /// 앱 전역 게임 창 연결(FE8-d). 있으면 대상 창 선택은 이 값을 읽고 쓴다. 없으면 이 화면만의 선택이다.
  final ConnectedTargetController? connectedTarget;

  /// 학생 후보 검토(기존 [ScanStudentReviewWorkspace])를 그리는가. 스캔 탭은 학생 검토를 새 보드로만 하므로 false를
  /// 준다(FE8-g4b, 마운트 해제). 단독 화면 · 기존 시험은 그대로(true).
  final bool showStudentReview;

  /// 아이템 후보 요약 · 미식별 칸 지정([ScanInventoryIdentityReview])을 그리는가. 스캔 탭은 아이템 검토를 새 보드로만 하므로
  /// false를 준다(FE8-g5b) — 이 화면에는 전술 로비 후보만 남는다. 단독 화면 · 기존 시험은 그대로(true).
  final bool showItemReview;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  /// [ScanPage.controller]가 없을 때 이 화면이 만든 컨트롤러.
  ScanSessionController? _ownedController;
  late ScanSessionController _controller;
  bool _escapeRegistered = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? (_ownedController = _createController());
    _controller.addListener(_controllerChanged);
    _controller.ensureStarted();
  }

  ScanSessionController _createController() => ScanSessionController(
    service: widget.service,
    connectedTarget: widget.connectedTarget,
    windowDockService: widget.windowDockService,
    studentScanDiagnosticFileService: widget.studentScanDiagnosticFileService,
    now: () => widget.now(),
    onRecentChanged: (recent) => widget.onRecentChanged?.call(recent),
    onCompanionChanged: (companion) =>
        widget.onCompanionChanged?.call(companion),
  );

  @override
  void dispose() {
    KitOverlayEscape.remove(this);
    _controller.removeListener(_controllerChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _controller.removeListener(_controllerChanged);
      final previousOwned = _ownedController;
      _ownedController = null;
      _controller =
          widget.controller ?? (_ownedController = _createController());
      _controller.addListener(_controllerChanged);
      _controller.ensureStarted();
      previousOwned?.dispose();
      return;
    }
    final owned = _ownedController;
    if (owned == null) return;
    owned
      ..windowDockService = widget.windowDockService
      ..studentScanDiagnosticFileService =
          widget.studentScanDiagnosticFileService
      ..updateService(widget.service)
      ..updateConnectedTarget(widget.connectedTarget);
  }

  void _controllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// Esc 처리 등록을 단계에 맞춘다. 탭이 보이고 세션이 진행 중(일시정지 포함)일 때만 Esc = 중지(기존 cancel)다.
  /// 단계는 여러 곳에서 바뀌므로 build마다 맞춘다. 이미 등록돼 있으면 다시 넣지 않는다(뒤에 열린 팝오버의 Esc가 먼저).
  void _syncEscape() {
    final wanted =
        widget.active &&
        _controller.stage == ScanSessionStage.running &&
        _controller.session != null;
    if (wanted == _escapeRegistered) return;
    _escapeRegistered = wanted;
    if (wanted) {
      KitOverlayEscape.push(this, context, _cancelByEscape);
    } else {
      KitOverlayEscape.remove(this);
    }
  }

  /// [KitOverlayEscape]는 부른 항목을 스스로 지운다.
  void _cancelByEscape() {
    _escapeRegistered = false;
    unawaited(_controller.cancel());
  }

  void _handoff(ScannerCandidate candidate) {
    final session = _controller.handoffSession(candidate);
    if (session == null) return;
    widget.onCandidateHandoff(session, candidate);
  }

  @override
  Widget build(BuildContext context) {
    _syncEscape();
    final scannerMissing = !_controller.scannerAvailable;
    final repositoryMissing = !_controller.repositoryAvailable;
    final readinessMissing =
        (_controller.readiness?['missing'] as List?)?.length ?? 0;
    final readinessCorrupt =
        (_controller.readiness?['corrupt'] as List?)?.length ?? 0;
    final selectedTarget = _controller.selectedTarget;
    final total = _controller.progressTotal;
    final progress =
        total == null || total <= 0 || _controller.progressCurrent == null
        ? null
        : (_controller.progressCurrent! / total).clamp(0.0, 1.0).toDouble();

    return ListView(
      key: const ValueKey('scan-page'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        RepositoryProfilePanel(
          service: widget.service,
          onSelected: _controller.selectProfile,
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _StatusChip(
                      label: _controller.connected
                          ? 'Backend connected'
                          : 'Backend disconnected',
                      ok: _controller.connected,
                    ),
                    _StatusChip(
                      label: _controller.recognitionReady
                          ? 'Recognition ready'
                          : 'Recognition not ready',
                      ok: _controller.recognitionReady,
                    ),
                    _StatusChip(
                      label: _controller.profile == null
                          ? 'No profile selected'
                          : 'Profile: ${_controller.profile!.displayName} · '
                                'r${_controller.profile!.revision}',
                      ok: _controller.profile != null,
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('scan-refresh'),
                      onPressed:
                          _controller.targetsLoading ||
                              _controller.readinessLoading
                          ? null
                          : _controller.refreshPreparation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_controller.readinessLoading || _controller.targetsLoading)
                  const LinearProgressIndicator(),
                Text(
                  'Manifest ${_controller.readiness?['manifest_version'] ?? 'unknown'} · '
                  'missing $readinessMissing · corrupt $readinessCorrupt',
                  key: const ValueKey('scan-readiness-summary'),
                ),
                if (scannerMissing)
                  const Text('Scanner service is unavailable.'),
                if (repositoryMissing)
                  const Text('Repository service is unavailable.'),
                if (_controller.readinessError != null)
                  Text(
                    _controller.readinessError!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                if (_controller.targetError != null)
                  Text(
                    _controller.targetError!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                if (!_controller.targetsLoading && _controller.targets.isEmpty)
                  const Text(
                    'No game windows were found. Open Blue Archive and refresh.',
                  ),
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
                    initialValue: _controller.targetId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Game window target',
                    ),
                    items: [
                      for (final target in _controller.targets)
                        DropdownMenuItem(
                          value: target.id,
                          child: Text(
                            '${target.title} · ${target.status.name}'
                            '${target.foreground ? ' · foreground' : ''} · ${target.id}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged:
                        _controller.stage == ScanSessionStage.running ||
                            _controller.stage == ScanSessionStage.cancelling ||
                            _controller.stage == ScanSessionStage.starting
                        ? null
                        : _controller.chooseTarget,
                  ),
                ),
                SegmentedButton<String>(
                  key: const ValueKey('scan-kind'),
                  segments: const [
                    ButtonSegment(
                      value: 'student_single',
                      label: Text('1명'),
                      icon: Icon(Icons.school_outlined),
                    ),
                    ButtonSegment(
                      value: 'student_full',
                      label: Text('전체'),
                      icon: Icon(Icons.groups_outlined),
                    ),
                    ButtonSegment(
                      value: 'inventory',
                      label: Text('재고'),
                      icon: Icon(Icons.inventory_2_outlined),
                    ),
                  ],
                  selected: {
                    _controller.kind == ScannerKind.inventory
                        ? 'inventory'
                        : _controller.studentScanMode == StudentScanMode.full
                        ? 'student_full'
                        : 'student_single',
                  },
                  onSelectionChanged:
                      _controller.stage == ScanSessionStage.running ||
                          _controller.stage == ScanSessionStage.cancelling ||
                          _controller.stage == ScanSessionStage.starting
                      ? null
                      : (value) {
                          final selection = value.first;
                          _controller.selectKind(
                            selection == 'inventory'
                                ? ScannerKind.inventory
                                : ScannerKind.student,
                            studentScanMode: selection == 'student_full'
                                ? StudentScanMode.full
                                : StudentScanMode.single,
                          );
                        },
                ),
                if (_controller.kind == ScannerKind.inventory)
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<InventoryScanProfile>(
                      key: const ValueKey('scan-inventory-profile'),
                      initialValue: _controller.inventoryScanProfile,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '재고 스캔 프로필'),
                      items: [
                        for (final profile in InventoryScanProfile.values)
                          DropdownMenuItem(
                            value: profile,
                            child: Text(profile.wireName),
                          ),
                      ],
                      onChanged:
                          _controller.stage == ScanSessionStage.running ||
                              _controller.stage ==
                                  ScanSessionStage.cancelling ||
                              _controller.stage == ScanSessionStage.starting
                          ? null
                          : (value) =>
                                _controller.selectInventoryScanProfile(value!),
                    ),
                  ),
                FilledButton.icon(
                  key: const ValueKey('scan-start'),
                  onPressed: _controller.canStart ? _controller.start : null,
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
        if (_controller.stage != ScanSessionStage.idle) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildSession(progress),
        ],
        if (widget.showStudentReview &&
            _controller.candidates.values.any(
              (item) => item.kind == ScannerKind.student,
            )) ...[
          const SizedBox(height: AppSpacing.sm),
          ScanStudentReviewWorkspace(
            candidates: _controller.candidates.values
                .where((item) => item.kind == ScannerKind.student)
                .toList(growable: false),
            currentStudents: {
              for (final item
                  in _controller.repositoryState?.students ??
                      const <ConfirmedStudentState>[])
                item.studentId: item,
            },
            catalog: _controller.studentCatalog,
            busyCandidateIds: _controller.busyCandidateIds,
            candidateErrors: _controller.candidateErrors,
            singleScan:
                _controller.session?.studentScanMode != StudentScanMode.full,
            onRevalidate: _controller.revalidateStudentCandidate,
            onHold: _controller.holdStudentCandidate,
            onDiscard: _controller.discardStudentCandidate,
            onApply: _controller.applyStudentCandidate,
          ),
        ],
        if (_controller.candidateNotice != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _controller.candidateNotice!,
            key: const ValueKey('scan-student-candidate-notice'),
          ),
        ],
        if (_controller.recent.isNotEmpty) ...[
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
                'Session ${_controller.session?.id ?? 'starting'} · generation ${_controller.session?.generation ?? '-'}',
                key: const ValueKey('scan-session'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Chip(label: Text(_controller.stage.name)),
              if (_controller.phase != null)
                Chip(label: Text('Phase: ${_controller.phase}')),
              if (_controller.outcome != null)
                Chip(label: Text('Outcome: ${_controller.outcome}')),
              FilledButton.tonalIcon(
                key: const ValueKey('scan-cancel'),
                onPressed: _controller.stage == ScanSessionStage.running
                    ? _controller.cancel
                    : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(
                  _controller.stage == ScanSessionStage.cancelling
                      ? 'Cancelling…'
                      : 'Cancel',
                ),
              ),
              // FB-10a(FD-142): 진행 중에는 일시정지, 멈춘 뒤에는 이어서. 끝나면 둘 다 숨긴다.
              if (_controller.stage == ScanSessionStage.running &&
                  _controller.control == ScannerControlState.paused)
                FilledButton.icon(
                  key: const ValueKey('scan-resume'),
                  onPressed: _controller.controlBusy
                      ? null
                      : _controller.resume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('이어서'),
                )
              else if (_controller.stage == ScanSessionStage.running)
                FilledButton.tonalIcon(
                  key: const ValueKey('scan-pause'),
                  onPressed:
                      _controller.controlBusy ||
                          _controller.control != ScannerControlState.running
                      ? null
                      : _controller.pause,
                  icon: const Icon(Icons.pause),
                  label: Text(
                    _controller.control == ScannerControlState.pauseRequested
                        ? '멈추는 중…'
                        : '일시정지',
                  ),
                ),
              if (_controller.pausedLabel case final label?)
                Text(
                  label,
                  key: const ValueKey('scan-paused-reason'),
                  style: const TextStyle(color: AppColors.warning),
                ),
              OutlinedButton.icon(
                key: const ValueKey('scan-retry'),
                onPressed:
                    _controller.stage == ScanSessionStage.terminal &&
                        _controller.canStart
                    ? _controller.start
                    : null,
                icon: const Icon(Icons.replay),
                label: const Text('Retry'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('scan-recover'),
                onPressed: _controller.session == null || _controller.recovering
                    ? null
                    : _controller.recoverSnapshot,
                icon: const Icon(Icons.sync),
                label: Text(
                  _controller.recovering ? 'Recovering…' : 'Recover snapshot',
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('scan-export-student-diagnostic'),
                onPressed: _controller.canExportStudentDiagnostic
                    ? _controller.exportStudentDiagnostic
                    : null,
                icon: const Icon(Icons.file_download_outlined),
                label: Text(
                  _controller.exportingStudentDiagnostic
                      ? '추출 중…'
                      : '진단 JSON 추출',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 끝난 세션에 값 없는 막대(끝없는 애니메이션)는 그리지 않는다(FE8-f2 발견 1, FE8-g2).
          if (!_controller.companionActive &&
              !(progress == null &&
                  _controller.stage == ScanSessionStage.terminal))
            Semantics(
              label: progress == null
                  ? 'Scan progress indeterminate'
                  : 'Scan progress ${_controller.progressCurrent ?? 0} of ${_controller.progressTotal}',
              child: LinearProgressIndicator(value: progress),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _controller.progressCurrent == null
                ? 'Waiting for progress'
                : _controller.progressTotal == null ||
                      _controller.progressTotal == 0
                ? '${_controller.progressCurrent!} · total unknown'
                : '${_controller.progressCurrent!} / ${_controller.progressTotal}',
            key: const ValueKey('scan-progress'),
          ),
          if (_controller.messageKey != null)
            Text('Message: ${_controller.messageKey}'),
          if (_controller.diagnostic != null)
            SelectableText('Diagnostic: ${_controller.diagnostic}'),
          if (_controller.terminalError != null)
            SelectableText(
              'Terminal error: ${_controller.terminalError!['code']} · ${_controller.terminalError!['message']}',
              style: const TextStyle(color: AppColors.danger),
            ),
          if (_controller.sessionError != null)
            SelectableText(
              _controller.sessionError!,
              style: const TextStyle(color: AppColors.danger),
            ),
          for (final candidate in _controller.candidates.values.where(
            (item) =>
                item.kind != ScannerKind.student &&
                (widget.showItemReview || item.kind != ScannerKind.inventory),
          )) ...[
            const Divider(),
            _CandidateSummary(
              candidate: candidate,
              onHandoff: candidate.kind == ScannerKind.tacticalLobby
                  ? () => _handoff(candidate)
                  : null,
            ),
            if (candidate.kind == ScannerKind.inventory) ...[
              if (_controller.unresolvedLoading(candidate.id))
                const LinearProgressIndicator(),
              if ((_controller.unresolvedSlots(candidate.id) ?? const [])
                      .where(
                        (slot) => !_controller.identitySkipped(
                          candidate.id,
                          slot.slot,
                        ),
                      )
                      .toList(growable: false)
                  case final slots when slots.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: ScanInventoryIdentityReview(
                    slots: slots,
                    catalog: _controller.inventoryCatalog,
                    busySlots: {
                      for (final slot in slots)
                        if (_controller.identityBusy(candidate.id, slot.slot))
                          slot.slot,
                    },
                    errors: {
                      for (final slot in slots)
                        slot.slot: ?_controller.identityError(
                          candidate.id,
                          slot.slot,
                        ),
                    },
                    onAssign: (slot, identity, persist) =>
                        _controller.assignInventoryIdentity(
                          candidate,
                          slot,
                          identity,
                          persist,
                        ),
                    onSkip: (slot) =>
                        _controller.skipInventoryIdentity(candidate, slot),
                  ),
                ),
            ],
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
          for (final item in _controller.recent)
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
                onPressed: () => _controller.openRecent(item),
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

  /// 전술 로비 인계. null이면 인계 버튼이 없다(학생 · 아이템은 스캔 탭 보드).
  final VoidCallback? onHandoff;

  String get _payloadSummary {
    if (candidate.kind == ScannerKind.student) {
      final values = candidate.payload['values'];
      return 'Student ${candidate.payload['student_id']} · '
          '${values is Map ? values.length : 0} observed field(s)';
    }
    if (candidate.kind == ScannerKind.tacticalLobby) {
      final rank = candidate.payload['current_rank'];
      final rows = candidate.payload['rows'];
      final current = rank is Map
          ? rank['value'] ?? rank['proposed_value']
          : '?';
      return 'Tactical lobby 쨌 current rank $current 쨌 '
          '${rows is List ? rows.length : 0} opponent row(s)';
    }
    final entries = candidate.payload['entries'];
    final unknown = entries is List
        ? entries
              .where((item) => item is Map && item['quantity'] == null)
              .length
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
          if (candidate.reviewRequired)
            const Chip(label: Text('Review required')),
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
      if (onHandoff case final handoff?) ...[
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          key: ValueKey('scan-review-${candidate.id}'),
          onPressed: handoff,
          icon: const Icon(Icons.rate_review_outlined),
          label: const Text('Review tactical capture'),
        ),
      ],
    ],
  );
}
