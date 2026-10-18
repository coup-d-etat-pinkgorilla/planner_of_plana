// 새 스캔 탭(FE8-g1, 시안 Scan · Scan-Items, FD-140 · FD-149 · FD-151 · FD-155).
//
// 시작 전에는 3섹션 고르기 화면([ScanPickWorkspace])이고, 진행(시작 중 · 진행 · 일시정지 · 중지 요청 중)과 검토 대기(끝났고
// 적용하지 않은 후보)에는 지금 [ScanPage]의 진행 · 검토 화면을 그대로 보인다(FE8-g3~g5 전까지, 내부 동작 변경 0). 판단은
// 머리글 칩 · 탭 점과 같은 [ScanHeaderStatus]라서 칩 · 토스트를 누르면 같은 화면이 열린다(FE8-f2). 검토까지 마치면 고르기로
// 돌아온다. 학생 진행만은 새 진행 3섹션([ScanRunWorkspace], FE8-g2 · 시안 Scan-Student-Run)이다 — 세션은 셸 소유라 다른 탭에
// 다녀와도 같은 진행 화면이고, 끝나면 위 규칙대로 검토 대기(결과 있음) 또는 고르기(결과 없음)다.
//
// [ScanPage]는 고르기 화면 동안에도 Offstage로 붙여 둔다: 계정 패널이 컨트롤러에 계정을 넘기고(시작 전제), 셸 · 테스트가
// 컨트롤러를 그 화면에서 찾는다(FE8-f1 · f2와 같은 경로). 고르기 화면은 컨트롤러의 고르기 값만 바꾸고, 시작은
// [ScanSessionController.startPick](지금 시작 동작 그대로)이다.
//
// 아이템 차례 스캔(FE8-g3, FD-143 (a))은 큐가 끝날 때까지 진행이다(진행 창이 플래너를 덮는다). 여러 종류가 끝나면 지금 검토
// 화면 위에 종류별 검토 줄([ScanQueueReviewBar])을 붙여 종류마다 결과를 연다(FE8-g5 전까지 검토 화면은 [ScanPage]).
//
// 미연결이면(앱 전역 게임 창 연결이 없으면) 시작이 막히고 오른쪽 섹션 자리에 홈과 같은 창 선택 패널이 붙는다(FD-155).
// 취소하면 접고, 연결이 다시 끊기면 다시 붙인다. `게임 창 다시 선택` · 준비 상태 게임 창 행도 같은 패널을 연다.
// 종류별 마지막 스캔은 FB-2b `repository.history.scan_latest`(by_kind)를 고르기 화면이 보일 때 읽는다(실패하면 '—').
import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/app_clock.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../pages/scan_page.dart';
import 'connected_target_controller.dart';
import 'scan_item_queue.dart';
import 'scan_pick_logic.dart';
import 'scan_run_logic.dart';
import 'scan_session_controller.dart';
import 'scan_tab_sections.dart';

/// FB-2b by_kind 한 쪽 최대 행 수와 따라갈 쪽 수(넘으면 거기까지 읽은 값으로 그린다).
const _lastScanPageLimit = 200;
const _lastScanMaxPages = 10;

class ScanTabPage extends StatefulWidget {
  const ScanTabPage({
    super.key,
    required this.service,
    required this.controller,
    required this.onCandidateHandoff,
    this.connectedTarget,
    this.active = true,
    this.appliedElsewhere = const {},
    this.onOpenStudents,
  });

  final AppService service;

  /// 셸 소유 스캔 세션(FE8-f1). 이 화면은 dispose하지 않는다.
  final ScanSessionController controller;

  /// 진행 · 검토 화면([ScanPage])의 후보 인계(셸 콜백).
  final void Function(ScannerSession session, ScannerCandidate candidate)
  onCandidateHandoff;

  /// 앱 전역 게임 창 연결(FE8-d). 없으면 창 선택 패널을 붙이지 않는다.
  final ConnectedTargetController? connectedTarget;

  /// 스캔 탭이 보이는가. 보일 때만 창 선택 패널을 붙이고 마지막 스캔을 읽는다.
  final bool active;

  /// 학생 · 인벤토리 탭에서 적용한 후보(`scanCandidateKey`). 검토 대기 판단에서 뺀다.
  final Set<String> appliedElsewhere;

  /// 진행 화면 `학생 탭으로 이동`. 없으면 그 버튼을 끈다(셸 연결은 app_shell 몫, FE8-g2 status 요청).
  final VoidCallback? onOpenStudents;

  @override
  State<ScanTabPage> createState() => _ScanTabPageState();
}

class _ScanTabPageState extends State<ScanTabPage> {
  late ScanSessionController _controller;

  /// `게임 창 다시 선택` 등으로 연 창 선택 패널.
  bool _panelRequested = false;

  /// 미연결일 때 저절로 붙은 패널을 취소로 접었다. 연결이 다시 끊기면 푼다.
  bool _panelDismissed = false;
  bool _wasConnected = false;
  ScanTabView? _lastView;

  ({ScanLastScan student, Map<InventoryScanProfile, ScanLastScan> items})?
  _lastScans;
  String? _lastScansProfileId;
  bool _lastScansStale = true;
  var _lastScansGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller..addListener(_controllerChanged);
    _controller.ensureStarted();
    _wasConnected = _connected;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadLastScans());
  }

  @override
  void didUpdateWidget(covariant ScanTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_controllerChanged);
      _controller = widget.controller..addListener(_controllerChanged);
      _controller.ensureStarted();
      _lastScansStale = true;
    }
    if (widget.active && !oldWidget.active) {
      _lastScansStale = true;
      _panelRequested = false;
    }
    _trackView();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadLastScans());
  }

  @override
  void dispose() {
    _lastScansGeneration += 1;
    _controller.removeListener(_controllerChanged);
    super.dispose();
  }

  bool get _connected =>
      widget.connectedTarget?.isConnected ?? _controller.selectedTarget != null;

  void _controllerChanged() {
    if (!mounted) return;
    final connected = _connected;
    setState(() {
      // 연결이 끊기면 저절로 붙는 패널을 다시 허락한다.
      if (_wasConnected && !connected) _panelDismissed = false;
      _wasConnected = connected;
      _trackView();
    });
    _maybeLoadLastScans();
  }

  /// 진행 · 검토를 마치고 고르기로 돌아오면 마지막 스캔을 다시 읽게 표시한다(적용으로 바뀌었을 수 있다).
  void _trackView() {
    final view = scanTabViewFor(
      _controller,
      appliedElsewhere: widget.appliedElsewhere,
    );
    if (_lastView == ScanTabView.session && view == ScanTabView.pick) {
      _lastScansStale = true;
    }
    _lastView = view;
  }

  void _openPanel() {
    if (widget.connectedTarget == null) return;
    setState(() => _panelRequested = true);
  }

  void _closePanel() => setState(() {
    _panelRequested = false;
    _panelDismissed = true;
  });

  void _useTarget(ScannerTarget target) {
    final connectedTarget = widget.connectedTarget;
    if (connectedTarget != null) {
      connectedTarget.connect(target);
    } else {
      _controller.chooseTarget(target.id);
    }
    setState(() => _panelRequested = false);
  }

  /// 고르기 화면이 보이고 계정을 알면 FB-2b by_kind를 읽는다(계정이 바뀌었거나 다시 읽을 때만).
  void _maybeLoadLastScans() {
    if (!mounted || !widget.active) return;
    if (scanTabViewFor(
          _controller,
          appliedElsewhere: widget.appliedElsewhere,
        ) !=
        ScanTabView.pick) {
      return;
    }
    final profile = _controller.profile;
    if (profile == null) return;
    if (!_lastScansStale && _lastScansProfileId == profile.id) return;
    _lastScansStale = false;
    _lastScansProfileId = profile.id;
    unawaited(_loadLastScans(profile.id));
  }

  Future<void> _loadLastScans(String profileId) async {
    final generation = ++_lastScansGeneration;
    final service = widget.service;
    if (service is! RepositoryService) {
      setState(() => _lastScans = null);
      return;
    }
    final repository = service as RepositoryService;
    try {
      final rows = <({String kind, String? profile, String at})>[];
      var request = RepositoryHistoryScanLatestRequest(
        profileId: profileId,
        includeByKind: true,
        byKindLimit: _lastScanPageLimit,
      );
      for (var page = 0; page < _lastScanMaxPages; page += 1) {
        final result = await repository.loadRepositoryHistoryScanLatest(
          request,
        );
        if (!mounted || generation != _lastScansGeneration) return;
        rows.addAll([
          for (final scan in result.byKind)
            (
              kind: scan.scanKind,
              profile: scan.inventoryScanProfile,
              at: scan.recordedAt,
            ),
        ]);
        if (result.byKindNextAfterSequence == null) break;
        request = request.nextKindPage(result);
      }
      setState(() => _lastScans = scanLastScansFrom(rows));
    } catch (_) {
      if (!mounted || generation != _lastScansGeneration) return;
      setState(() => _lastScans = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = scanTabViewFor(
      _controller,
      appliedElsewhere: widget.appliedElsewhere,
    );
    final sessionShown = view == ScanTabView.session;
    final runShown = sessionShown && scanRunVisible(_controller);
    final pageShown = sessionShown && !runShown;
    final queueBarShown = pageShown && scanQueueReviewVisible(_controller);
    final connectedTarget = widget.connectedTarget;
    final panelVisible =
        widget.active &&
        connectedTarget != null &&
        (_panelRequested || (!_connected && !_panelDismissed));
    return Stack(
      key: const ValueKey('scan-tab-page'),
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !pageShown,
          child: TickerMode(
            enabled: pageShown,
            child: Column(
              children: [
                if (queueBarShown)
                  ScanQueueReviewBar(
                    key: const ValueKey('scan-queue-review'),
                    controller: _controller,
                    appliedElsewhere: widget.appliedElsewhere,
                  )
                else
                  const SizedBox.shrink(),
                Expanded(
                  child: ScanPage(
                    service: widget.service,
                    onCandidateHandoff: widget.onCandidateHandoff,
                    controller: _controller,
                    active: widget.active,
                    connectedTarget: connectedTarget,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (runShown)
          ScanRunWorkspace(
            key: const ValueKey('scan-run'),
            onOpenStudents: widget.onOpenStudents,
            view: ScanPickView(
              controller: _controller,
              service: widget.service,
              now: appClockNow(widget.service),
              lastScans: _lastScans,
              appliedElsewhere: widget.appliedElsewhere,
              connectedTarget: connectedTarget,
              panelVisible: false,
              onOpenPanel: null,
              onClosePanel: _closePanel,
              onUseTarget: _useTarget,
            ),
          ),
        if (!sessionShown)
          ScanPickWorkspace(
            key: const ValueKey('scan-pick'),
            view: ScanPickView(
              controller: _controller,
              service: widget.service,
              now: appClockNow(widget.service),
              lastScans: _lastScans,
              appliedElsewhere: widget.appliedElsewhere,
              connectedTarget: connectedTarget,
              panelVisible: panelVisible,
              onOpenPanel: connectedTarget == null ? null : _openPanel,
              onClosePanel: _closePanel,
              onUseTarget: _useTarget,
            ),
          ),
      ],
    );
  }
}
