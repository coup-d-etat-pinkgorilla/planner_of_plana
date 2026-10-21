// 인벤토리 탭(FE6-a, 시안 Inventory "부족한 것" 보기). 로드·편집·저장·부족 계산은
// [InventoryController](`ui/inventory/inventory_controller.dart`)가, 4섹션 화면은 [InventoryWorkspace]가 맡는다.
// 스캔 후보 승인은 스캔 탭 아이템 결과 검토 보드가 한다(FE8-g5b — 예전 후보 승인 띠 `_CandidatePanel`과 후보 인계는 없앴다).
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

import '../../services/app_service.dart';
import '../app_section.dart';
import '../inventory/inventory_analysis.dart' show InventoryScreenMode;
import '../inventory/inventory_controller.dart';
import '../inventory/inventory_view_model.dart';
import '../inventory/inventory_workspace.dart';
import '../navigation/app_navigation_intent.dart';
import '../tutorial_host/tutorial_session.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.service,
    this.onOpenPlan,
    this.onNavigate,
    required this.onOpenScan,
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
      (_ownController ??= InventoryController(
        widget.service,
        practiceProfile: () => TutorialHostScope.practiceProfileOf(context),
      ));

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
    builder: (context, _) => InventoryWorkspace(
      controller: _controller,
      onOpenPlan: _openPlan,
      onOpenScan: widget.onOpenScan,
      reveal: _reveal,
    ),
  );
}
