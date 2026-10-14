// 인벤토리 탭(FE6-a, 시안 Inventory "부족한 것" 보기). 로드·편집·저장·부족 계산·후보 승인은
// [InventoryController](`ui/inventory/inventory_controller.dart`)가, 4섹션 화면은 [InventoryWorkspace]가 맡는다.
// 후보 승인 패널(`_CandidatePanel`)은 스캔 탭 아이템 검토(FE8-g5)로 옮길 때까지 그대로 두고 위험도 목록 위 띠에 둔다.
// FE6-b: 셸은 모든 탭을 오프스테이지로 짓는다. 인벤토리는 [InventoryPage.active]가 처음 true가 될 때(탭을 처음 열 때)
// 읽기·계산을 시작한다. 그 전에는 백엔드를 부르지 않는다.
// FE6-f: 탭을 다시 열 때(false → true)는 저장소 revision만 보고, 바뀌었으면(다른 탭의 스캔 commit 등) 다시 읽는다.
// FE7-d: 통계 근거 이동 의도([InventoryPage.navigation])는 한 번만, 첫 로드가 끝난 뒤 적용한다. 행이면 목록 모드에서
// 그 재화의 종류 · 보기로 거른 뒤 그 행을 고르고(상세가 그 재화를 보인다), 티어별 충족률이면 분석 모드의 티어 화면을 연다.
// 모두 기존 컨트롤러 동작(`setScreenMode` · `setMode` · `showCategoryShortages` · `setView` · `toggleCategory` · `select` ·
// `toggleTiers`)이다. 행을 고르면 그 행이 목록 · 타일에서 보이게 스크롤한다(tidy1, FE7-d 발견 2, [InventoryRevealRequest]).
// tidy1(FD-108): 상세 "계획에서 보기" 등 계획 탭으로 가는 버튼은 [InventoryPage.onNavigate]로 계획 이동 의도를 넘긴다(볼 재화가
// 있으면 [PlanNavigationIntent.resource], 없으면 [PlanNavigationIntent.home]). 셸 밖(테스트)은 [InventoryPage.onOpenPlan]이다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../app_section.dart';
import '../inventory/inventory_analysis.dart' show InventoryScreenMode;
import '../inventory/inventory_controller.dart';
import '../inventory/inventory_view_model.dart';
import '../inventory/inventory_workspace.dart';
import '../navigation/app_navigation_intent.dart';
import '../widgets/diagonal_section.dart';

export '../inventory/inventory_controller.dart' show InventoryCandidateContext;

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.service,
    this.onOpenPlan,
    this.onNavigate,
    required this.onOpenScan,
    this.candidateContext,
    this.onCandidateCommitted,
    this.controller,
    this.active = true,
    this.navigation,
  });
  final AppService service;

  /// 계획 탭으로 간다([onNavigate]가 없을 때, 재화 없이).
  final VoidCallback? onOpenPlan;

  /// 다른 탭으로 가는 이동 의도(tidy1, FD-108). 앱 셸이 넘긴다. 있으면 [onOpenPlan] 대신 쓴다.
  final ValueChanged<AppNavigationIntent>? onNavigate;
  final VoidCallback onOpenScan;
  final InventoryCandidateContext? candidateContext;
  final ValueChanged<ScannerCandidate>? onCandidateCommitted;

  /// 없으면 화면이 직접 만든다(테스트·golden이 상태를 미리 정할 때 넘긴다). 넘긴 컨트롤러는 부른 쪽이 정리한다.
  final InventoryController? controller;

  /// 탭이 보이는가(셸이 넘긴다). 처음 true가 될 때 첫 로드를 시작한다. 셸 밖(테스트·golden)은 기본 true다.
  final bool active;

  /// 다른 탭에서 넘긴 이동 의도(FE7-d). 같은 의도는 한 번만 적용한다.
  final InventoryNavigationIntent? navigation;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  InventoryController? _ownController;

  InventoryController get _controller =>
      widget.controller ??
      (_ownController ??= InventoryController(widget.service));

  /// 첫 로드를 시작했는가.
  bool _started = false;

  /// 마지막으로 받은 이동 의도 id와 아직 적용하지 못한 의도(첫 로드 전).
  int? _navigationId;
  InventoryNavigationIntent? _pendingNavigation;
  InventoryController? _listened;

  /// 마지막 이동 의도로 고른 행(목록 · 타일에서 한 번 보이게 한다).
  InventoryRevealRequest? _reveal;

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
    _listen();
    if (widget.active) _start();
    _receiveNavigation();
  }

  void _listen() {
    final controller = _controller;
    if (identical(controller, _listened)) return;
    _listened?.removeListener(_controllerChanged);
    _listened = controller..addListener(_controllerChanged);
  }

  void _controllerChanged() {
    if (_pendingNavigation == null) return;
    Future<void>.microtask(_applyNavigation);
  }

  /// 새 이동 의도를 받는다. 적용은 build 밖(microtask)에서, 첫 로드가 끝난 뒤다.
  void _receiveNavigation() {
    final intent = widget.navigation;
    if (intent == null || intent.id == _navigationId) return;
    _navigationId = intent.id;
    _pendingNavigation = intent;
    Future<void>.microtask(_applyNavigation);
  }

  void _applyNavigation() {
    final intent = _pendingNavigation;
    final controller = _controller;
    if (!mounted || intent == null || !controller.loaded || controller.loading) {
      return;
    }
    _pendingNavigation = null;
    switch (intent.target) {
      case InventoryNavigationTarget.tiers:
        controller.setScreenMode(InventoryScreenMode.analysis);
        if (!controller.tiersOpen) controller.toggleTiers();
      case InventoryNavigationTarget.row:
        final key = intent.resourceKey;
        final view = key == null ? null : controller.board[key];
        if (key == null || view == null) return;
        controller.setScreenMode(InventoryScreenMode.list);
        final mode = inventoryModeOf(view.item);
        // 재화(크레딧 · 엘리그마)는 목록 행이 아니라 주요 재화 카드다. 고르기만 한다.
        if (mode != null) {
          controller.setMode(mode);
          final category = view.item.category;
          if (InventoryBoard.inShortageView(view)) {
            controller.showCategoryShortages(category);
          } else {
            controller.setView(InventoryView.all);
            if (controller.category != category) {
              controller.toggleCategory(category);
            }
          }
        }
        controller.select(key);
        setState(() => _reveal = InventoryRevealRequest(key));
    }
  }

  @override
  void didUpdateWidget(InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listen();
    final started = _started;
    if (widget.active) _start();
    if (started && widget.active && !oldWidget.active) {
      Future<void>.microtask(() {
        if (mounted) _controller.refreshIfChanged();
      });
    }
    // FE6-c: 스캔 후보가 새로 오면 후보 승인 띠가 있는 목록 보기로 돌린다(build 밖에서 알린다).
    if (widget.candidateContext != null &&
        widget.candidateContext != oldWidget.candidateContext) {
      Future<void>.microtask(() {
        if (mounted) _controller.setScreenMode(InventoryScreenMode.list);
      });
    }
    _receiveNavigation();
  }

  /// 첫 로드는 build 밖에서 시작한다(넘겨받은 컨트롤러에 이미 듣는 위젯이 있어도 build 중 알림이 생기지 않게).
  void _start() {
    if (_started) return;
    _started = true;
    Future<void>.microtask(() {
      if (mounted) _controller.load();
    });
  }

  @override
  void dispose() {
    widget.service.state.removeListener(_connectionChanged);
    _listened?.removeListener(_controllerChanged);
    _ownController?.dispose();
    super.dispose();
  }

  void _connectionChanged() {
    if (!_started) return;
    final controller = _controller;
    final connected =
        widget.service.state.value.connection == BackendConnection.connected;
    if (connected && !controller.loading && controller.disconnected) {
      controller.load();
    } else if (!connected && !controller.disconnected) {
      controller.load();
    }
  }

  Future<void> _approveCandidate() async {
    final context = widget.candidateContext;
    if (context == null) return;
    final committed = await _controller.approveCandidate(context);
    if (committed && mounted) {
      widget.onCandidateCommitted?.call(context.candidate);
    }
  }

  /// 계획 탭으로 간다. [resourceKey]가 있으면 활성 계획 Detail 홈에서 그 재화를 고른다(tidy1, FD-108).
  void _openPlan(String? resourceKey) {
    final navigate = widget.onNavigate;
    if (navigate == null) {
      widget.onOpenPlan?.call();
      return;
    }
    navigate(
      resourceKey == null
          ? PlanNavigationIntent.home(origin: AppSection.inventory)
          : PlanNavigationIntent.resource(
              resourceKey,
              origin: AppSection.inventory,
            ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final controller = _controller;
      final candidate = widget.candidateContext;
      return InventoryWorkspace(
        controller: controller,
        onOpenPlan: _openPlan,
        onOpenScan: widget.onOpenScan,
        reveal: _reveal,
        candidatePanel: candidate == null
            ? null
            : _CandidatePanel(
                key: const ValueKey('inventory-candidate-panel'),
                context: candidate,
                current: controller.repositoryState?.inventory,
                busy: controller.saving,
                onHold: controller.holdCandidate,
                onApprove: _approveCandidate,
              ),
      );
    },
  );
}

class _CandidatePanel extends StatelessWidget {
  const _CandidatePanel({
    super.key,
    required this.context,
    required this.current,
    required this.busy,
    required this.onHold,
    required this.onApprove,
  });
  final InventoryCandidateContext context;
  final RepositoryInventoryState? current;
  final bool busy;
  final VoidCallback onHold;
  final VoidCallback onApprove;
  @override
  Widget build(BuildContext buildContext) {
    final candidateEntries =
        context.candidate.payload['entries'] as List? ?? const [];
    final currentValues = {
      for (final item in current?.entries ?? const <Map<String, dynamic>>[])
        item['item_id'] ?? item['key']: item['quantity'],
    };
    final candidateValues = {
      for (final item in candidateEntries.whereType<Map>())
        item['item_id'] ?? item['key']: item['quantity'],
    };
    final currentKeys = currentValues.keys.toSet();
    final candidateKeys = candidateValues.keys.toSet();
    final added = candidateKeys.difference(currentKeys).length;
    final missing = currentKeys.difference(candidateKeys).length;
    final changed = candidateKeys
        .intersection(currentKeys)
        .where((key) => candidateValues[key] != currentValues[key])
        .length;
    final unknown = candidateValues.values
        .where((value) => value == null)
        .length;
    return DiagonalSection(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 34, 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Scanner candidate · added $added / changed $changed / missing $missing / unknown $unknown',
            ),
            if (context.candidate.reviewRequired)
              const Chip(label: Text('Review required')),
            const Text(
              'Missing rows stay unknown; they are never auto-filled with zero.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            OutlinedButton(
              onPressed: busy ? null : onHold,
              child: const Text('Hold'),
            ),
            FilledButton(
              onPressed: busy ? null : onApprove,
              child: const Text('Review & approve'),
            ),
          ],
        ),
      ),
    );
  }
}
