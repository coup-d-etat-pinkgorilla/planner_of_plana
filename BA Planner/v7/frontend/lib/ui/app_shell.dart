import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/app_service.dart';
import '../services/repository_service.dart';
import '../services/scanner_service.dart';
import 'app_section.dart';
import 'kit/ba_chip.dart';
import 'kit/ba_modal.dart';
import 'kit/kit_pressable.dart';
import 'models/recent_students.dart';
import 'models/student_filter_controller.dart';
import 'models/student_filter_selection.dart';
import 'navigation/app_navigation_intent.dart';
import 'pages/adaptive_sync_page.dart';
import 'pages/home_page.dart';
import 'pages/inventory_page.dart';
import 'pages/planning_page.dart';
import 'pages/section_template_studio_page.dart';
import 'pages/settings_page.dart';
import 'pages/student_page.dart';
import 'pages/statistics_page.dart';
import 'pages/tactical_page.dart';
import 'scan/connected_target_controller.dart';
import 'scan/scan_end_toast.dart';
import 'scan/scan_header_progress.dart';
import 'scan/scan_session_controller.dart';
import 'scan/scan_tab_page.dart';
import 'tactical/tactical_lobby_view.dart' show TacticalLobbyHandoff;
import 'widgets/animated_section_stack.dart';
import 'widgets/ba_triangle_background.dart';
import 'widgets/development_panel.dart';
import 'widgets/diagonal_header.dart';
import 'widgets/lifted_path_shadow.dart';
import 'widgets/page_header_override.dart';
import 'widgets/recovery_banner.dart';
import 'widgets/scan_companion_dock.dart';

const _sectionMotions = <SectionMotionSpec>[
  SectionMotionSpec(intro: 0, outro: 180),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
  SectionMotionSpec(intro: 90, outro: 270),
];

const _tabGlassShadow = LiftedPathShadowSpec(
  color: Color(0xff050911),
  offset: Offset(2, 2),
  inset: 3,
  layers: 4,
  maxAlpha: 0.22,
);

const _headerTriangleTexture = BATriangleTextureConfig(
  baseColor: Color(0xff263747),
  panelColor: AppColors.surfaceRaised,
  softColor: Color(0xff8295a6),
  accentColor: AppColors.primaryMuted,
  triangleSize: 82,
  tessellationContrast: 0.055,
  randomSeed: 6197,
  macroTriangleChance: 0.09,
  macroTriangleScale: 2.6,
  macroTriangleContrast: 0.035,
  lightStrength: 0.12,
  edgeVignetteStrength: 0.12,
  fogDirectionDegrees: 12,
  fogStrength: 0.07,
);

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.service,
    this.initialSection = AppSection.home,
    this.animateHomeEntrance = false,
  });

  final AppService service;
  final AppSection initialSection;
  final bool animateHomeEntrance;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late AppSection _section;
  late final AnimationController _homeEntranceController;
  RepositoryProfile? _selectedProfile;
  var _profileLoadGeneration = 0;
  late BackendConnection _lastConnection;
  bool _showDevelopmentPanel = false;
  PlanningStudentSeed? _planningSeed;
  TacticalLobbyHandoff? _tacticalCandidate;
  List<ScannerRecentSummary> _recentScans = const [];
  var _homeReloadToken = 0;

  /// 머리글 칩을 누르면 올린다. 홈이 창 선택 패널을 연다(FE8-e).
  var _targetPickerRequest = 0;
  var _statisticsReloadToken = 0;

  /// 통계 근거에서 넘긴 마지막 이동 의도(FE7-d). 대상 탭이 id로 한 번만 적용한다.
  AppNavigationIntent? _navigation;

  /// 복귀 칩을 보일 이동(대상 탭에 있는 동안만). 다른 탭으로 가면 지운다.
  AppNavigationIntent? _returnFrom;

  /// "← 통계"로 돌아왔다(통계가 다시 읽은 뒤 고른 것을 복원한다).
  var _statisticsReturnToken = 0;
  var _tacticalReloadToken = 0;
  var _profileGeneration = 0;
  late bool _studentTabActive;

  /// 최근 본 학생(FD-061): 앱 실행 동안만, 학생 탭과 계획 만들기 1단계(FE4-b)가 함께 쓴다.
  final RecentStudents _recentStudents = RecentStudents();

  /// 학생 탭 필터(FE3-d). 학생 탭이 쓰고, 통계 "학생 탭 필터 불러오기"(FE7-e)는 적용 값을 읽기만 한다. 계정을 바꾸면 비운다
  /// (학생 탭이 새로 만들던 것과 같다).
  final StudentFilterController _studentFilter = StudentFilterController();

  /// 탭 안 모드(학생 탭 성장 계산기)가 머리말 제목·복귀 칩을 바꾼다(FE3-f2a, FD-161).
  final PageHeaderOverrideController _headerOverride =
      PageHeaderOverrideController();
  late bool _planTabActive;
  final ValueNotifier<ScanCompanionState?> _scanCompanion = ValueNotifier(null);

  /// 앱 전역 게임 창 연결(FE8-d, FD-116 (a)). 스캔 화면과 머리글 칩이 같은 값을 쓴다.
  late final ConnectedTargetController _connectedTarget =
      ConnectedTargetController.forService(widget.service);

  /// 스캔 세션(FE8-f1). 탭을 옮겨도 살아 있고, 계정을 바꾸면 스캔 화면과 함께 새로 만든다.
  late ScanSessionController _scanSession = _createScanSession();

  /// 완료 토스트(FE8-f2, FD-148). 다른 탭에 있을 때 끝난 세션마다(id + generation) 한 번 띄운다.
  ScanEndNotice? _scanEndNotice;
  Timer? _scanEndNoticeTimer;
  String? _lastScanEndKey;

  /// 다른 탭(전술대항전)에서 처리한 스캔 후보([scanCandidateKey]). 탭 점의 검토 대기에서 뺀다.
  Set<String> _scanAppliedElsewhere = const {};

  ScanSessionController _createScanSession() => ScanSessionController(
    service: widget.service,
    connectedTarget: _connectedTarget,
    onRecentChanged: (recent) {
      setState(() => _recentScans = recent);
    },
    onCompanionChanged: (companion) {
      if (!mounted) return;
      _scanCompanion.value = companion;
    },
  );

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _studentTabActive = _section == AppSection.students;
    _planTabActive = _section == AppSection.plan;
    _homeEntranceController = AnimationController(
      vsync: this,
      duration: AppMotion.shell,
      value:
          widget.animateHomeEntrance && widget.initialSection == AppSection.home
          ? 0
          : 1,
    );
    if (widget.animateHomeEntrance &&
        widget.initialSection == AppSection.home) {
      _homeEntranceController.forward();
    }
    _lastConnection = widget.service.state.value.connection;
    widget.service.state.addListener(_handleConnectionChanged);
    _scanSession.addListener(_scanSessionChanged);
    _loadSelectedProfile();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.service, widget.service)) return;
    oldWidget.service.state.removeListener(_handleConnectionChanged);
    _lastConnection = widget.service.state.value.connection;
    widget.service.state.addListener(_handleConnectionChanged);
    _connectedTarget.rebindService(widget.service);
    _scanSession.updateService(widget.service);
    _loadSelectedProfile();
  }

  @override
  void dispose() {
    _profileLoadGeneration += 1;
    widget.service.state.removeListener(_handleConnectionChanged);
    _homeEntranceController.dispose();
    _scanEndNoticeTimer?.cancel();
    _scanSession
      ..removeListener(_scanSessionChanged)
      ..dispose();
    _scanCompanion.dispose();
    _recentStudents.dispose();
    _studentFilter.dispose();
    _headerOverride.dispose();
    _connectedTarget.dispose();
    super.dispose();
  }

  void _handleConnectionChanged() {
    final connection = widget.service.state.value.connection;
    final becameConnected =
        connection == BackendConnection.connected &&
        _lastConnection != BackendConnection.connected;
    _lastConnection = connection;
    if (becameConnected) {
      _loadSelectedProfile();
    } else if (connection != BackendConnection.connected) {
      _profileLoadGeneration += 1;
    }
  }

  Future<void> _loadSelectedProfile() async {
    final generation = ++_profileLoadGeneration;
    final service = widget.service;
    if (service is! RepositoryService) return;
    if (service.state.value.connection != BackendConnection.connected) return;
    final repository = service as RepositoryService;
    try {
      final profiles = await repository.listProfiles();
      if (!mounted || generation != _profileLoadGeneration) return;
      setState(() {
        _selectedProfile = profiles
            .where((profile) => profile.selected)
            .firstOrNull;
      });
    } catch (_) {
      if (!mounted || generation != _profileLoadGeneration) return;
      setState(() => _selectedProfile = null);
    }
  }

  void _open(AppSection section) {
    if (section == AppSection.scan) _dismissScanEndNotice();
    // 같은 탭을 다시 누르면 탭 안 모드에서 나온다(FD-161 (a)).
    if (section == _section && _headerOverride.back(section)) return;
    setState(() {
      final changingSection = section != _section;
      if (section == AppSection.home) _homeReloadToken += 1;
      if (section == AppSection.statistics) _statisticsReloadToken += 1;
      if (section == AppSection.pvp) _tacticalReloadToken += 1;
      if (changingSection) _returnFrom = null;
      if (changingSection &&
          (_section == AppSection.students || section == AppSection.students)) {
        _studentTabActive = false;
      }
      if (changingSection &&
          (_section == AppSection.plan || section == AppSection.plan)) {
        _planTabActive = false;
      }
      _section = section;
    });
  }

  /// 통계 근거의 이동 버튼(FE7-d): 대상 탭을 열고 의도를 넘기고 복귀 칩을 둔다.
  void _navigate(AppNavigationIntent intent) {
    _open(intent.section);
    setState(() {
      _navigation = intent;
      _returnFrom = intent;
    });
  }

  /// 복귀 칩: 출발 탭(통계)으로 돌아간다.
  void _returnToOrigin() {
    final from = _returnFrom;
    if (from == null) return;
    _open(from.origin);
    if (from.origin == AppSection.statistics) {
      setState(() => _statisticsReturnToken += 1);
    }
  }

  void _openTargetPicker() {
    _open(AppSection.home);
    setState(() => _targetPickerRequest += 1);
  }

  void _addStudentToPlan(PlanningStudentSeed seed) {
    setState(() {
      _planningSeed = seed;
      _studentTabActive = false;
      _planTabActive = false;
      _section = AppSection.plan;
    });
  }

  /// 스캔 화면의 전술 로비 후보만 전술대항전 탭으로 넘긴다(FE9-c). 학생 · 아이템 후보는 스캔 탭 결과 검토 보드가 적용한다
  /// (FE8-g4b · FE8-g5b, I-scan §9.1 인계 제거).
  void _handoffCandidate(ScannerSession session, ScannerCandidate candidate) {
    if (candidate.kind != ScannerKind.tacticalLobby) return;
    setState(() {
      _tacticalCandidate = TacticalLobbyHandoff(
        session: session,
        candidate: candidate,
      );
      _section = AppSection.pvp;
    });
  }

  /// 세션이 새로 끝나면(스캔 탭 밖에서만) 완료 토스트를 띄운다. 끝은 이벤트 · 스냅숏 응답에서만 오므로 빌드 중이 아니다.
  void _scanSessionChanged() {
    final notice = ScanEndNotice.of(_scanSession);
    if (!mounted || notice == null || notice.sessionKey == _lastScanEndKey) {
      return;
    }
    _lastScanEndKey = notice.sessionKey;
    // 스캔 탭에서는 화면이 끝과 결과를 바로 보인다(전술 로비는 전술대항전 탭 S2가 보인다, FE9-c).
    if (_section == AppSection.scan ||
        (_section == AppSection.pvp &&
            notice.kind == ScannerKind.tacticalLobby)) {
      return;
    }
    // 아이템 차례 스캔이 끝나면 플래너가 앞으로 와 결과 검토를 연다(시안 Scan-Item-Run ④, FE8-g3 발견 2).
    if (notice.kind == ScannerKind.inventory) {
      _open(AppSection.scan);
      return;
    }
    _scanEndNoticeTimer?.cancel();
    _scanEndNoticeTimer = Timer(scanEndToastDuration, _dismissScanEndNotice);
    setState(() => _scanEndNotice = notice);
  }

  /// 아이템 진행 창이 덮는 동안(플래너 창이 줄어 있다) 셸 본문은 그리지 · 누르지 않는다. 크기 · 상태는 그대로다(FE8-g3 발견 3).
  Widget _hiddenWhileDocked(Widget body) =>
      ValueListenableBuilder<ScanCompanionState?>(
        valueListenable: _scanCompanion,
        builder: (context, companion, child) => Visibility(
          key: const ValueKey('shell-body'),
          visible: companion == null,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: child!,
        ),
        child: body,
      );

  void _dismissScanEndNotice() {
    _scanEndNoticeTimer?.cancel();
    _scanEndNoticeTimer = null;
    if (!mounted || _scanEndNotice == null) return;
    setState(() => _scanEndNotice = null);
  }

  void _markScanCandidateApplied(ScannerCandidate committed) => setState(
    () => _scanAppliedElsewhere = {
      ..._scanAppliedElsewhere,
      scanCandidateKey(committed),
    },
  );

  void _profileChanged() {
    // 최근 본 학생은 그 계정의 보유·육성 맥락이라 계정을 바꾸면 비운다(오케스트레이터 2026-10-07 13:49).
    _recentStudents.clear();
    _studentFilter
      ..discardDraft()
      ..applied = StudentFilterSelection.empty;
    // 예전 스캔 화면이 프레임 끝에 dispose되던 시점과 맞춘다(새 화면이 새 세션으로 준비를 읽은 뒤).
    final previousScanSession = _scanSession
      ..removeListener(_scanSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => previousScanSession.dispose(),
    );
    _scanEndNoticeTimer?.cancel();
    setState(() {
      _scanSession = _createScanSession()..addListener(_scanSessionChanged);
      _scanEndNotice = null;
      _scanAppliedElsewhere = const {};
      _profileGeneration += 1;
      _homeReloadToken += 1;
      _statisticsReloadToken += 1;
      _tacticalReloadToken += 1;
      _planningSeed = null;
      _tacticalCandidate = null;
      _recentScans = const [];
      _navigation = null;
      _returnFrom = null;
    });
    _loadSelectedProfile();
  }

  void _recoveryCompleted() {
    setState(() {
      _homeReloadToken += 1;
      _statisticsReloadToken += 1;
      _tacticalReloadToken += 1;
    });
  }

  // 모달 배경 범위(FE3-d2, 15:51 결정 4): 화면 모달이 열려 있는 동안 셸 머리 탭 줄·배너·개발 패널·스캔 독
  // ([BaModalBackdropExclude])을 의미 구조에서 뺀다. 모달을 연 화면 내용은 BaModal이 뺀다.
  @override
  Widget build(BuildContext context) =>
      BaModalBackdrop(child: _buildShell(context));

  Widget _buildShell(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: BATriangleBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canShowPanel = constraints.maxWidth >= 1050;
                final showPanel = canShowPanel && _showDevelopmentPanel;

                final mainContent = Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          BaModalBackdropExclude(
                            child: DirectionalSectionEntrance(
                              key: const ValueKey('home-header-entrance'),
                              animation: _homeEntranceController,
                              directionDegrees: 270,
                              child: _CompoundPageHeader(
                                section: _section,
                                headerOverride: _headerOverride,
                                returnLabel: _returnFrom?.section == _section
                                    ? _returnFrom?.returnLabel
                                    : null,
                                onReturn: _returnToOrigin,
                                service: widget.service,
                                profile: _selectedProfile,
                                developmentPanelVisible: _showDevelopmentPanel,
                                connectedTarget: _connectedTarget,
                                scanSession: _scanSession,
                                scanAppliedElsewhere: _scanAppliedElsewhere,
                                onSelected: _open,
                                onOpenTargetPicker: _openTargetPicker,
                                onToggleDevelopmentPanel: () {
                                  setState(() {
                                    _showDevelopmentPanel =
                                        !_showDevelopmentPanel;
                                  });
                                },
                              ),
                            ),
                          ),
                          BaModalBackdropExclude(
                            child: RecoveryBanner(
                              service: widget.service,
                              onOpenSettings: () => _open(AppSection.settings),
                              onOpenScan: () => _open(AppSection.scan),
                            ),
                          ),
                          Expanded(
                            child: AnimatedSectionStack(
                              index: AppSection.values.indexOf(_section),
                              motions: _sectionMotions,
                              independentMotionIndices: {
                                AppSection.values.indexOf(AppSection.students),
                                AppSection.values.indexOf(AppSection.plan),
                              },
                              onIncomingReady: (index) {
                                switch (AppSection.values[index]) {
                                  case AppSection.students
                                      when !_studentTabActive:
                                    setState(() => _studentTabActive = true);
                                  case AppSection.plan when !_planTabActive:
                                    setState(() => _planTabActive = true);
                                  default:
                                    return;
                                }
                              },
                              children: [
                                HomePage(
                                  key: ValueKey('home-$_profileGeneration'),
                                  service: widget.service,
                                  onOpen: _open,
                                  reloadToken: _homeReloadToken,
                                  recentScans: _recentScans,
                                  entranceAnimation: _homeEntranceController,
                                  connectedTarget: _connectedTarget,
                                  openTargetPickerRequest: _targetPickerRequest,
                                  scanSession: _scanSession,
                                  scanAppliedElsewhere: _scanAppliedElsewhere,
                                ),
                                StudentPage(
                                  key: ValueKey('students-$_profileGeneration'),
                                  service: widget.service,
                                  onAddToPlan: _addStudentToPlan,
                                  onOpenScan: () => _open(AppSection.scan),
                                  active: _studentTabActive,
                                  recentStudents: _recentStudents,
                                  headerOverride: _headerOverride,
                                  filterController: _studentFilter,
                                  navigation: switch (_navigation) {
                                    final StudentsNavigationIntent intent =>
                                      intent,
                                    _ => null,
                                  },
                                  onNavigate: _navigate,
                                ),
                                PlanningPage(
                                  key: ValueKey('plan-$_profileGeneration'),
                                  service: widget.service,
                                  initialSeed: _planningSeed,
                                  active: _planTabActive,
                                  loadRepositoryPlan: true,
                                  navigation: switch (_navigation) {
                                    final PlanNavigationIntent intent => intent,
                                    _ => null,
                                  },
                                ),
                                InventoryPage(
                                  key: ValueKey(
                                    'inventory-$_profileGeneration',
                                  ),
                                  service: widget.service,
                                  onNavigate: _navigate,
                                  onOpenScan: () => _open(AppSection.scan),
                                  active: _section == AppSection.inventory,
                                  navigation: switch (_navigation) {
                                    final InventoryNavigationIntent intent =>
                                      intent,
                                    _ => null,
                                  },
                                ),
                                TacticalPage(
                                  key: ValueKey('tactical-$_profileGeneration'),
                                  service: widget.service,
                                  reloadToken: _tacticalReloadToken,
                                  headerOverride: _headerOverride,
                                  scanSession: _scanSession,
                                  connectedTarget: _connectedTarget,
                                  scanAppliedElsewhere: _scanAppliedElsewhere,
                                  lobbyHandoff: _tacticalCandidate,
                                  onLobbyCandidateHandled:
                                      _markScanCandidateApplied,
                                ),
                                StatisticsPage(
                                  key: ValueKey(
                                    'statistics-$_profileGeneration',
                                  ),
                                  service: widget.service,
                                  onOpen: _open,
                                  onNavigate: _navigate,
                                  reloadToken: _statisticsReloadToken,
                                  returnToken: _statisticsReturnToken,
                                  studentFilter: _studentFilter,
                                ),
                                ScanTabPage(
                                  key: ValueKey('scan-$_profileGeneration'),
                                  service: widget.service,
                                  onCandidateHandoff: _handoffCandidate,
                                  onOpenStudents: () =>
                                      _open(AppSection.students),
                                  controller: _scanSession,
                                  active: _section == AppSection.scan,
                                  connectedTarget: _connectedTarget,
                                  appliedElsewhere: _scanAppliedElsewhere,
                                ),
                                SettingsPage(
                                  service: widget.service,
                                  onOpenScan: () => _open(AppSection.scan),
                                  onOpenDiagnostics: () =>
                                      _open(AppSection.adaptiveSync),
                                  onProfileChanged: _profileChanged,
                                  onRecoveryCompleted: _recoveryCompleted,
                                ),
                                const AdaptiveSyncPage(),
                                const SectionTemplateStudioPage(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showPanel) ...[
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 330,
                        child: BaModalBackdropExclude(
                          child: DevelopmentPanel(
                            service: widget.service,
                            onOpenDiagnostics: () =>
                                _open(AppSection.adaptiveSync),
                            onOpenSectionTemplateStudio: () =>
                                _open(AppSection.sectionTemplateStudio),
                            onClose: () {
                              setState(() => _showDevelopmentPanel = false);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                );

                if (canShowPanel || !_showDevelopmentPanel) {
                  return _hiddenWhileDocked(mainContent);
                }

                return Stack(
                  children: [
                    _hiddenWhileDocked(mainContent),
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _showDevelopmentPanel = false),
                        child: const ColoredBox(color: Color(0x66000000)),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: constraints.maxWidth.clamp(280, 330).toDouble(),
                      child: Material(
                        elevation: 16,
                        child: BaModalBackdropExclude(
                          child: DevelopmentPanel(
                            service: widget.service,
                            onOpenDiagnostics: () =>
                                _open(AppSection.adaptiveSync),
                            onOpenSectionTemplateStudio: () =>
                                _open(AppSection.sectionTemplateStudio),
                            onClose: () =>
                                setState(() => _showDevelopmentPanel = false),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_scanEndNotice case final notice?)
            Positioned(
              top: 192,
              right: 26,
              child: BaModalBackdropExclude(
                child: ScanEndToast(
                  notice: notice,
                  onOpen: () => _open(AppSection.scan),
                  onClose: _dismissScanEndNotice,
                ),
              ),
            ),
          ValueListenableBuilder<ScanCompanionState?>(
            valueListenable: _scanCompanion,
            builder: (context, companion, child) => companion == null
                ? const SizedBox.shrink()
                : Positioned.fill(
                    child: BaModalBackdropExclude(
                      child: ScanCompanionDock(state: companion),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompoundPageHeader extends StatelessWidget {
  const _CompoundPageHeader({
    required this.section,
    required this.headerOverride,
    this.returnLabel,
    this.onReturn,
    required this.service,
    required this.profile,
    required this.developmentPanelVisible,
    required this.connectedTarget,
    required this.scanSession,
    required this.scanAppliedElsewhere,
    required this.onSelected,
    required this.onOpenTargetPicker,
    required this.onToggleDevelopmentPanel,
  });

  final AppSection section;
  final PageHeaderOverrideController headerOverride;

  /// 복귀 칩 글자("← 통계", FE7-d). null이면 칩이 없다.
  final String? returnLabel;
  final VoidCallback? onReturn;
  final AppService service;
  final RepositoryProfile? profile;
  final bool developmentPanelVisible;
  final ConnectedTargetController connectedTarget;
  final ScanSessionController scanSession;
  final Set<String> scanAppliedElsewhere;
  final ValueChanged<AppSection> onSelected;
  final VoidCallback onOpenTargetPicker;
  final VoidCallback onToggleDevelopmentPanel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shelfWidth = math.min(760.0, constraints.maxWidth);
          return SizedBox(
            key: const ValueKey('page-header-surface'),
            height: 170,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LGlassShadowPainter(
                        shelfWidth: shelfWidth,
                        shelfHeight: 48,
                        shadow: _tabGlassShadow,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipPath(
                    key: const ValueKey('l-glass-header-background'),
                    clipper: _LGlassClipper(
                      shelfWidth: shelfWidth,
                      shelfHeight: 48,
                      inset: _tabGlassShadow.inset,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.surface.withValues(alpha: 0.46),
                              AppColors.surfaceRaised.withValues(alpha: 0.28),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 4,
                  width: shelfWidth - 8,
                  height: 44,
                  child: _TopTabs(
                    selected: section,
                    onSelected: onSelected,
                    scanSession: scanSession,
                    scanAppliedElsewhere: scanAppliedElsewhere,
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 48,
                  width: shelfWidth - 8,
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.outline.withValues(alpha: 0.55),
                  ),
                ),
                Positioned(
                  left: 5,
                  top: 53,
                  right: 8,
                  bottom: 8,
                  child: DiagonalHeaderSurface(
                    key: const ValueKey('nested-page-header'),
                    radius: 14,
                    angleDegrees: 80,
                    background: CustomPaint(
                      key: const ValueKey('header-triangle-texture'),
                      painter: BATriangleTexturePainter(_headerTriangleTexture),
                    ),
                    child: AnimatedSwitcher(
                      duration: AppMotion.header,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0.025, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey('page-header-content-${section.name}'),
                        child: ListenableBuilder(
                          listenable: headerOverride,
                          builder: (context, _) => _AppHeader(
                            section: section,
                            pageOverride: headerOverride.valueFor(section),
                            returnLabel: returnLabel,
                            onReturn: onReturn,
                            service: service,
                            profile: profile,
                            developmentPanelVisible: developmentPanelVisible,
                            connectedTarget: connectedTarget,
                            scanSession: scanSession,
                            onOpenTargetPicker: onOpenTargetPicker,
                            onOpenScan: () => onSelected(AppSection.scan),
                            onToggleDevelopmentPanel: onToggleDevelopmentPanel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 탭 폭은 라벨이 결정한다.
///
/// 이전 구현은 탭마다 픽셀 폭을 상수로 박아 두었다(`홈` 80, `인벤토리` 112 …).
/// 그 값은 특정 서체·특정 글자 크기에서만 맞는 값이라, 서체를 바꾸거나 Windows
/// 문자 배율을 올리면 라벨이 말줄임으로 잘렸다. 이제는 내용이 폭을 정하고,
/// 짧은 라벨만 최소 폭으로 받쳐 준다.
const _topTabMinWidth = 76.0;
const _topTabGap = 2.0;

class _TopTabs extends StatefulWidget {
  const _TopTabs({
    required this.selected,
    required this.onSelected,
    required this.scanSession,
    required this.scanAppliedElsewhere,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onSelected;
  final ScanSessionController scanSession;
  final Set<String> scanAppliedElsewhere;

  @override
  State<_TopTabs> createState() => _TopTabsState();
}

class _TopTabsState extends State<_TopTabs> {
  final _controller = ScrollController();
  var _overflowStart = false;
  var _overflowEnd = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncOverflow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverflow());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncOverflow);
    _controller.dispose();
    super.dispose();
  }

  /// 탭이 잘려 나갔는지 여부. 잘림을 표시하지 않으면 좁은 창에서 `설정` 탭이
  /// 아무 신호 없이 사라진다.
  void _syncOverflow() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final start = position.pixels > position.minScrollExtent + 0.5;
    final end = position.pixels < position.maxScrollExtent - 0.5;
    if (start == _overflowStart && end == _overflowEnd) return;
    setState(() {
      _overflowStart = start;
      _overflowEnd = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final visibleSelection =
        selected == AppSection.adaptiveSync ||
            selected == AppSection.sectionTemplateStudio
        ? AppSection.settings
        : selected;

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverflow());
        return false;
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in AppSection.primary)
                  _TopTab(
                    section: section,
                    selected: section == visibleSelection,
                    onTap: () => widget.onSelected(section),
                    indicator: section == AppSection.scan
                        ? ScanTabDot(
                            controller: widget.scanSession,
                            appliedElsewhere: widget.scanAppliedElsewhere,
                            onScanTab: section == visibleSelection,
                          )
                        : null,
                  ),
              ],
            ),
          ),
          if (_overflowStart)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: const _TopTabEdgeFade(
                key: ValueKey('top-tabs-overflow-start'),
                alignment: Alignment.centerLeft,
              ),
            ),
          if (_overflowEnd)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: const _TopTabEdgeFade(
                key: ValueKey('top-tabs-overflow-end'),
                alignment: Alignment.centerRight,
              ),
            ),
        ],
      ),
    );
  }
}

class _TopTabEdgeFade extends StatelessWidget {
  const _TopTabEdgeFade({super.key, required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: alignment,
          end: alignment == Alignment.centerLeft
              ? Alignment.centerRight
              : Alignment.centerLeft,
          colors: [
            AppColors.navigation,
            AppColors.navigation.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.section,
    required this.selected,
    required this.onTap,
    this.indicator,
  });

  final AppSection section;
  final bool selected;
  final VoidCallback onTap;

  /// 라벨 뒤 표시(탭 `스캔` 점, FE8-f2).
  final Widget? indicator;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _topTabMinWidth),
        child: Padding(
          padding: const EdgeInsets.only(right: _topTabGap),
          child: Material(
            key: ValueKey('top-tab-${section.name}'),
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: AnimatedContainer(
                duration: AppMotion.tab,
                curve: Curves.easeOutCubic,
                height: AppControlHeights.tab,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryMuted.withValues(alpha: 0.34)
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        section.icon,
                        size: 17,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        section.label,
                        maxLines: 1,
                        softWrap: false,
                        style: AppType.body.copyWith(
                          color: selected
                              ? AppColors.text
                              : AppColors.textMuted,
                          // 선택 표시는 밑줄·배경·색이 이미 하고 있다. 굵기까지
                          // 최대로 올리면 선택되지 않은 탭도 상대적으로 굵어
                          // 보여서 위계가 흐려진다.
                          fontWeight: selected
                              ? AppType.bold
                              : AppType.medium,
                        ),
                      ),
                      ?indicator,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.section,
    this.pageOverride,
    this.returnLabel,
    this.onReturn,
    required this.service,
    required this.profile,
    required this.developmentPanelVisible,
    required this.connectedTarget,
    required this.scanSession,
    required this.onOpenTargetPicker,
    required this.onOpenScan,
    required this.onToggleDevelopmentPanel,
  });

  final AppSection section;
  final PageHeaderOverride? pageOverride;
  final String? returnLabel;
  final VoidCallback? onReturn;
  final AppService service;
  final RepositoryProfile? profile;
  final bool developmentPanelVisible;
  final ConnectedTargetController connectedTarget;
  final ScanSessionController scanSession;
  final VoidCallback onOpenTargetPicker;
  final VoidCallback onOpenScan;
  final VoidCallback onToggleDevelopmentPanel;

  @override
  Widget build(BuildContext context) {
    final pageOverride = this.pageOverride;
    final returnLabel = this.returnLabel;
    final backLabel = pageOverride?.backLabel;
    final trailing = pageOverride?.trailing;
    return ValueListenableBuilder(
      valueListenable: service.state,
      builder: (context, state, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final showMetrics =
                section == AppSection.home && constraints.maxWidth >= 920;
            final title = section == AppSection.home
                ? '안녕하세요, 선생님. 기다리고 있었습니다'
                : pageOverride?.title ?? section.label;
            final subtitle = section == AppSection.home
                ? '현재 프로필 · 아로나 선생님'
                : pageOverride?.subtitle ?? section.description;

            return Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.headline,
                            ),
                          ),
                          if (pageOverride != null && backLabel != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            KitPressable(
                              key: const ValueKey('page-header-back-chip'),
                              onPressed: pageOverride.onBack,
                              semanticLabel: backLabel,
                              builder: (context, state) => BaChip(
                                label: backLabel,
                                tone: state.hovered || state.focused
                                    ? AppTones.pink
                                    : AppTones.info,
                              ),
                            ),
                          ],
                          if (returnLabel != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            KitPressable(
                              key: const ValueKey('page-header-return-chip'),
                              onPressed: onReturn,
                              semanticLabel: returnLabel,
                              builder: (context, state) => BaChip(
                                label: returnLabel,
                                tone: state.hovered || state.focused
                                    ? AppTones.pink
                                    : AppTones.info,
                              ),
                            ),
                          ],
                          if (trailing != null) ...[
                            const SizedBox(width: AppSpacing.md),
                            trailing,
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodySmall.copyWith(
                          color: section == AppSection.home
                              ? AppColors.primary
                              : AppColors.textMuted,
                          fontWeight: section == AppSection.home
                              ? AppType.semiBold
                              : AppType.regular,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showMetrics) ...[
                  if (profile != null) ...[
                    // 시안 초상: 둥근 사각 62×52 r9, 흰 2px 테두리, 이미지 cover 50% 22%(FD-115).
                    Container(
                      key: const ValueKey('home-header-profile-portrait'),
                      width: 62,
                      height: 52,
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        color: Color(0xffc9d6e2),
                        borderRadius: BorderRadius.all(Radius.circular(9)),
                        boxShadow: [
                          BoxShadow(color: AppColors.text, spreadRadius: 2),
                        ],
                      ),
                      child: Image.asset(
                        'assets/student_portraits/${profile!.avatarStudentId}.png',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.56),
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // 지표는 숫자만(시안 `217`·`1,284`, FD-115).
                  _HeaderMetric(
                    label: '학생',
                    value: _headerCount(state.studentCount),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _HeaderMetric(
                    label: '인벤토리',
                    value: _headerCount(state.inventoryItemCount),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
                HeaderStatusChip(
                  backend: state.connection,
                  connectedTarget: connectedTarget,
                  scanSession: scanSession,
                  onOpenTargetPicker: onOpenTargetPicker,
                  onOpenScan: onOpenScan,
                ),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: '개발 상태 패널',
                  child: IconButton.filledTonal(
                    onPressed: onToggleDevelopmentPanel,
                    isSelected: developmentPanelVisible,
                    icon: const Icon(Icons.developer_board_outlined),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 머리글 지표 숫자: 단위 없이 세 자리마다 쉼표(`1,284`).
String _headerCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.caption.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        // 지표 숫자는 탭을 오갈 때 자리가 흔들리지 않도록 tabular figures를 쓴다.
        Text(value, style: AppType.tabular(AppType.title)),
      ],
    );
  }
}

class _LGlassClipper extends CustomClipper<Path> {
  const _LGlassClipper({
    required this.shelfWidth,
    required this.shelfHeight,
    required this.inset,
  });

  final double shelfWidth;
  final double shelfHeight;
  final double inset;

  @override
  Path getClip(Size size) => _buildLGlassPath(
    size,
    shelfWidth: shelfWidth,
    shelfHeight: shelfHeight,
    inset: inset,
  );

  @override
  bool shouldReclip(_LGlassClipper oldDelegate) =>
      oldDelegate.shelfWidth != shelfWidth ||
      oldDelegate.shelfHeight != shelfHeight ||
      oldDelegate.inset != inset;
}

class _LGlassShadowPainter extends CustomPainter {
  const _LGlassShadowPainter({
    required this.shelfWidth,
    required this.shelfHeight,
    required this.shadow,
  });

  final double shelfWidth;
  final double shelfHeight;
  final LiftedPathShadowSpec shadow;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(
      canvas,
      _buildLGlassPath(
        size,
        shelfWidth: shelfWidth,
        shelfHeight: shelfHeight,
        inset: shadow.inset,
      ),
      shadow,
    );
  }

  @override
  bool shouldRepaint(_LGlassShadowPainter oldDelegate) =>
      oldDelegate.shelfWidth != shelfWidth ||
      oldDelegate.shelfHeight != shelfHeight ||
      oldDelegate.shadow != shadow;
}

Path _buildLGlassPath(
  Size size, {
  required double shelfWidth,
  required double shelfHeight,
  required double inset,
}) {
  const radius = 14.0;
  final surfaceWidth = math.max(1, size.width - inset).toDouble();
  final surfaceHeight = math.max(1, size.height - inset).toDouble();
  final right = shelfWidth.clamp(radius * 2, surfaceWidth);
  final path = Path()
    ..moveTo(radius, 0)
    ..lineTo(right - radius, 0)
    ..quadraticBezierTo(right, 0, right, radius);

  if (right < surfaceWidth) {
    path
      ..lineTo(right, shelfHeight - radius)
      ..quadraticBezierTo(right, shelfHeight, right + radius, shelfHeight)
      ..lineTo(surfaceWidth - radius, shelfHeight)
      ..quadraticBezierTo(
        surfaceWidth,
        shelfHeight,
        surfaceWidth,
        shelfHeight + radius,
      );
  } else {
    path.lineTo(surfaceWidth, shelfHeight + radius);
  }

  return path
    ..lineTo(surfaceWidth, surfaceHeight - radius)
    ..quadraticBezierTo(
      surfaceWidth,
      surfaceHeight,
      surfaceWidth - radius,
      surfaceHeight,
    )
    ..lineTo(radius, surfaceHeight)
    ..quadraticBezierTo(0, surfaceHeight, 0, surfaceHeight - radius)
    ..lineTo(0, radius)
    ..quadraticBezierTo(0, 0, radius, 0)
    ..close();
}
