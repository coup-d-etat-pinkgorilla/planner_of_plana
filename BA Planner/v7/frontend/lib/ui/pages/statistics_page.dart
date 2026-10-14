// ignore_for_file: curly_braces_in_flow_control_structures

// 통계 탭(FE7-a 골격 · FE7-b 학생 성장 · FE7-c 인벤토리 현황 · 계획 집계 · FE7-g 활성 문서 계산, 시안 Stats-Growth ·
// Stats-Inventory · Stats-Plan).
//
// 화면은 `ui/statistics/statistics_workspace.dart`의 3섹션이다. 이 State는 원천 자료 읽기(`_reload()`)와 화면 상태
// (주제, 학생 성장 A1 seg · 고른 구간 · 항목 · 근거 펼침, 인벤토리 · 계획에서 고른 카테고리 · 재화 · C1 순서)를 맡는다.
// 읽기 순서: 계정 → 활성 계획 문서(`plan.get`) → 계정 상태 → 학생 목록 → 인벤토리 목록 → (목표가 있으면) 총 계산 · 부족
// 계산 → (활성 문서에 단계가 있고 계산할 수 있으면) 문서 계산, generation 가드. 활성 계획을 계정 상태보다 먼저 읽는다
// (인벤토리 탭 · `loadRepositoryPlanSnapshot`과 같은 순서: 목표 v1만 있는 계정은 첫 `plan.get`이 문서로 옮기며 revision을
// 올린다). "활성 계획"은 저장된 활성 문서다(오케스트레이터 2026-10-13 20:05 결정, FE7-c 발견 1).
// 학생 성장 projection(`buildStatisticsGrowth`, FD-028)은 읽은 계정 상태 · 학생 목록에서, 인벤토리 · 계획 projection
// (`StatisticsSupply.build`, FD-031 · 032)은 인벤토리 목록 · 계정 인벤토리 · 부족 계산에서, 계획 집계의 문서 계산 projection
// (`StatisticsPlanning.build`, FD-034 · 035 · 037)은 활성 문서 · 문서 계산에서만 만든다(계획 Detail 화면과 같은 projection).
// 활성 계획 · 문서 계산 읽기 오류는 계획 집계 C3 타일에만 보이고(다른 주제 근거 안내를 막지 않는다), 그때 첫 부족 · 막힌
// 학생 · 페이즈 수는 '—', C1 "페이즈 순"은 비활성이다.
// 다시 읽으면 고른 구간 · 재화를 지운다(값이 바뀌었을 수 있다). C1 순서는 보기 선택이라 남긴다.
// 읽기는 탭이 처음 보일 때 시작한다(FE6-b 인벤토리와 같은 정책). 셸은 모든 탭을 오프스테이지로 짓고, 보이지 않는
// 탭은 `TickerMode`가 꺼져 있으므로 그것으로 보임을 판단한다(`app_shell.dart`를 고치지 않는다). 숨어 있는 동안
// 다시 읽기 요청(`reloadToken` · 연결 · 서비스 교체)이 오면 표시만 해 두고, 다시 보일 때 한 번 읽는다.
// FE7-d: 근거 패널 아래 두 버튼이 고른 구간 · 재화를 원본 탭으로 넘긴다([StatisticsPage.onNavigate], 의도는
// `ui/navigation/app_navigation_intent.dart`). 고른 것이 없거나 넘길 대상이 없으면 버튼은 비활성이다. 넘어간 탭의
// "← 통계" 칩으로 돌아오면([StatisticsPage.returnToken]) 평소처럼 다시 읽고, 다시 읽은 뒤에도 근거가 있는 고른 것 ·
// 펼침을 되살린다(주제 · 스크롤은 다시 읽어도 그대로다).
// FE7-h: 읽기가 끝나면(보드를 먼저 그린 뒤) 이력을 읽는다 — events 전부(cursor 끝까지) · scan_latest(보유 학생 · 카탈로그
// 재화, 256개씩). 이력 revision이 계정 상태와 다르면 섞지 않고 A6 · B3에 안내한다. 탭이 다시 보이면(숨어 있는 동안 다시
// 읽기 요청이 없었어도) summary revision만 보고, 계정 상태와 다르면 다시 읽는다(FE6-f 인벤토리 탭과 같은 방식 — 다른 탭의
// 저장 · 스캔 commit). "지금"은 서비스 시계(`services/app_clock.dart` `AppClockSource`, 검수 fixture 고정 시각)이고 없으면
// 기기 시계다.
// FE7-e: 왼쪽 "필터"가 통계 전용 필터 모달(FE3-d 공용 모달, 통계 전용 [StudentFilterController] 주입)을 연다. 이 상태는
// 학생 탭 필터와 다른 객체라 서로 덮어쓰지 않는다(FD-104 (a) — 통계 → 학생 탭 이동도 학생 필터에 쓰지 않는 FE7-d 규칙
// 그대로). 모달 머리 "학생 탭 필터 불러오기"는 셸이 넘긴 학생 탭 필터의 적용 값을 초안에 한 번 복사한다(연결 아님). 걸린
// 필터는 학생 성장(A1~A6 · KPI · 근거)에만 쓰고(`statistics/statistics_growth_filter.dart`), 인벤토리 · 계획은 늘 전체
// 성장이다. 필터를 바꾸면 고른 구간을 지운다(대상이 바뀌었다). 탭을 떠나면 열린 모달은 닫고 초안을 버린다.
// FE7-f: 2차 타일 A3 · A4(`statistics/statistics_breakdown_projection.dart`, 학생 성장 — 필터 대상 학생) · B2(인벤토리,
// `statisticsB2Rows`) · C4(계획, `statistics/statistics_goal_projection.dart` — 전체)를 만든다. A4 seg · B2 seg는 보기
// 선택이라 다시 읽어도 남긴다(C1 순서와 같다). B2 근거의 "쓰는 학생 · 필요량 순"은 활성 문서 계산의 단계별 사용
// (`inventoryStageUses`, 인벤토리 상세와 같은 함수), "최근 변화"는 이력의 지금 − 28일 색인이다. 이동: A3 · A4 근거는
// 학생 성장 버튼 그대로(학생 탭 임시 목록 · 계획 1단계), B2 행은 인벤토리 그 행(+ 티어 표가 있는 카테고리면 티어별
// 충족률), C4 학생은 "계획 만들기 2 · 목표 정하기"(`PlanNavigationIntent.goals`, 활성 계획 편집 흐름 2단계에서 그 학생).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/app_clock.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../statistics/statistics_breakdown_projection.dart';
import '../../statistics/statistics_goal_projection.dart';
import '../../statistics/statistics_growth_filter.dart';
import '../../statistics/statistics_growth_projection.dart';
import '../../statistics/statistics_history_projection.dart';
import '../../statistics/statistics_plan_projection.dart';
import '../../statistics/statistics_supply_projection.dart';
import '../app_section.dart';
import '../inventory/inventory_analysis.dart'
    show
        inventoryOopartCategory,
        inventoryTacticalBdCategory,
        inventoryTechNotesCategory;
import '../inventory/inventory_history.dart'
    show
        inventoryDaysAgo,
        inventoryHistoryPageLimit,
        inventoryLastScanAt,
        inventoryScanLatestChunk;
import '../inventory/inventory_view_model.dart'
    show InventoryBoard, InventoryStageUse, inventoryStageUses;
import '../kit/ba_modal.dart';
import '../kit/buttons.dart';
import '../models/plan_scenario_detail.dart' show PlanDetailData;
import '../models/student_filter_controller.dart';
import '../models/student_filter_selection.dart';
import '../navigation/app_navigation_intent.dart';
import '../statistics/statistics_filter_view.dart';
import '../statistics/statistics_growth_evidence.dart';
import '../statistics/statistics_history_charts.dart';
import '../statistics/statistics_source.dart';
import '../statistics/statistics_supply_evidence.dart';
import '../statistics/statistics_topics.dart';
import '../statistics/statistics_workspace.dart';
import '../widgets/account_section_cluster.dart' show accountLastScanText;
import '../widgets/student_filter_modal.dart';

export '../statistics/statistics_topics.dart' show StatisticsMode;

/// 이력 events를 끝까지 읽을 때의 쪽 수 상한(200 × 50 = FB-2 보존 상한 10,000건, FE6-f와 같다).
const _historyMaxPages = 50;

/// C4 학생 근거 primary 버튼(Statistics-Proposal C4 "행 → 계획 만들기 2 · 목표 정하기", FE7-f).
const statisticsGoalActionLabel = '계획 만들기 2 · 목표 정하기';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.service,
    required this.onOpen,
    this.onNavigate,
    this.reloadToken = 0,
    this.returnToken = 0,
    this.studentFilter,
  });
  final AppService service;
  final ValueChanged<AppSection> onOpen;

  /// 근거 패널 이동 버튼(FE7-d). 없으면 버튼은 비활성이다.
  final ValueChanged<AppNavigationIntent>? onNavigate;
  final int reloadToken;

  /// 넘어간 탭의 "← 통계" 칩으로 돌아올 때마다 바뀐다(다음 다시 읽기에서 고른 것을 되살린다).
  final int returnToken;

  /// 학생 탭 필터(FE7-e "학생 탭 필터 불러오기"가 적용 값을 읽기만 한다). 없으면 그 버튼은 비활성이다.
  final StudentFilterController? studentFilter;
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

  /// 활성 계획 문서(`plan.get`)와 그 문서 계산(FE7-g). 읽기 · 계산 오류는 [_planError] 하나로 둔다.
  RepositoryPlanState? _plan;
  Map<String, dynamic>? _planProjection;
  String? _planError;
  String? _profileError,
      _stateError,
      _studentError,
      _inventoryError,
      _grossError,
      _shortageError;
  bool _loading = true;
  int _generation = 0;
  StatisticsMode _mode = StatisticsMode.students;

  /// 학생 성장 화면 상태(FE7-b).
  StatisticsGrowthMetric _growthMetric = StatisticsGrowthMetric.growth;
  StatisticsGrowthSelection? _growthSelection;
  bool _evidenceExpanded = false;

  /// projection 캐시(읽은 계정 상태 · 학생 목록이 같으면 다시 만들지 않는다).
  StatisticsGrowth? _growth;
  RepositoryState? _growthState;
  List<StudentCatalogEntry>? _growthStudents;

  /// 인벤토리 · 계획 화면 상태(FE7-c): 고른 카테고리 · 재화.
  StatisticsSupplySelection? _supplySelection;

  /// 재화 근거 "외 n종 · 외 n명"을 모두 펼쳤는가(FE7-d, 성장 "모두 보기"와 같은 동작).
  bool _supplyExpanded = false;

  /// 다음 다시 읽기가 "← 통계" 복귀다(FE7-d).
  bool _restoreOnReload = false;

  /// 인벤토리 · 계획 projection 캐시(읽은 인벤토리 목록 · 계정 상태 · 부족 계산 · 성장이 같으면 다시 만들지 않는다).
  StatisticsSupply? _supply;
  Map<String, StatisticsEvidenceStudent> _supplyStudents = const {};
  List<InventoryCatalogEntry>? _supplyCatalog;
  RepositoryState? _supplyState;
  InventoryShortageResult? _supplyShortages;
  StatisticsGrowth? _supplyGrowth;

  /// C1 순서(FE7-g). 다시 읽어도 남긴다.
  StatisticsC1Order _c1Order = StatisticsC1Order.shortage;

  /// A4 · B2 seg(FE7-f). 다시 읽어도 남긴다(보기 선택).
  StatisticsA4Group _a4Group = StatisticsA4Group.school;
  StatisticsB2Order _b2Order = StatisticsB2Order.shortage;

  /// A3 · A4 projection 캐시(성장 · 학생 목록이 같으면 다시 만들지 않는다, FE7-f).
  StatisticsGrowthBreakdown? _breakdown;
  StatisticsGrowth? _breakdownGrowth;
  List<StudentCatalogEntry>? _breakdownStudents;

  /// C4 projection 캐시(계정 상태 · 학생 목록이 같으면 다시 만들지 않는다, FE7-f).
  StatisticsGoalProgressSet? _goals;
  RepositoryState? _goalsState;
  List<StudentCatalogEntry>? _goalsStudents;

  /// B2 근거 단계별 사용 캐시(문서 계산이 같으면 다시 만들지 않는다, FE7-f).
  Map<String, List<InventoryStageUse>>? _stageUses;
  Map<String, dynamic>? _stageUsesProjection;

  /// 문서 계산 projection 캐시(읽은 문서 · 문서 계산이 같으면 다시 만들지 않는다).
  StatisticsPlanning? _planning;
  RepositoryPlanState? _planningPlan;
  Map<String, dynamic>? _planningProjection;

  /// 이력(FE7-h). 읽기 실패 · 상태와 맞지 않음은 [_historyError] 글자다.
  StatisticsHistory? _history;
  String? _historyError;
  bool _historyLoading = false;

  /// B3 seg(FD-110). 다시 읽어도 남긴다(보기 선택).
  StatisticsB3Range _b3Range = StatisticsB3Range.recent;

  /// 이력 projection 캐시(읽은 이력 · 성장 · 보드 · seg가 같으면 다시 만들지 않는다).
  StatisticsHistoryView? _historyView;
  StatisticsHistory? _historyViewSource;
  StatisticsGrowth? _historyViewGrowth;
  StatisticsSupply? _historyViewSupply;
  InventoryBoard? _historyBoard;
  StatisticsB3Range? _historyViewRange;
  bool _historyViewLoading = false;
  String? _historyViewError;

  /// 계획이 없을 때 B3 보드(카탈로그 · 계정 인벤토리만, 부족 계산 없음).
  InventoryBoard? _plainBoard;
  List<InventoryCatalogEntry>? _plainBoardCatalog;
  RepositoryState? _plainBoardState;

  /// 통계 전용 필터(FE7-e, FD-104): 학생 탭 필터와 다른 객체다. 모달은 이 객체를 주입받는다.
  final StudentFilterController _filter = StudentFilterController();
  final BaModalController _filterModal = BaModalController();

  /// 필터 후보(보유 학생) 캐시(읽은 계정 상태 · 학생 목록이 같으면 다시 만들지 않는다).
  List<StudentFilterCandidate> _candidates = const [];
  RepositoryState? _candidatesState;
  List<StudentCatalogEntry>? _candidatesStudents;

  /// 학생 성장 범위 캐시(성장 · 적용 필터 · 후보가 같으면 다시 만들지 않는다).
  StatisticsGrowthScope? _scope;
  StatisticsGrowth? _scopeGrowth;
  StudentFilterSelection? _scopeSelection;
  List<StudentFilterCandidate>? _scopeCandidates;

  /// 이 탭이 지금 보이는가(`TickerMode`).
  bool _visible = false;

  /// 보이지 않는 동안 다시 읽기 요청이 있었는가. 처음에는 아직 읽지 않았으므로 true다.
  bool _stale = true;

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
    _filter.addListener(_filterChanged);
    _filterModal.addListener(_filterModalChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (!visible && _filterModal.isOpen) {
      // 탭을 떠나면 열린 필터 모달을 닫는다(초안은 버린다, 학생 탭과 같다).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _filterModal.close();
      });
    }
    if (visible && _stale) {
      _reload();
    } else if (visible) {
      _refreshIfChanged();
    }
  }

  /// 다시 보일 때: 이력 요약의 revision이 읽은 계정 상태와 다르면(다른 탭의 저장 · 스캔 commit) 다시 읽는다.
  Future<void> _refreshIfChanged() async {
    final repository = _repository;
    final profile = _profile;
    final state = _state;
    if (repository == null || profile == null || state == null || _loading) {
      return;
    }
    final generation = _generation;
    try {
      final summary = await repository.loadRepositoryHistorySummary([
        profile.id,
      ]);
      if (!mounted || generation != _generation || !_visible) return;
      for (final item in summary.profiles) {
        if (item.profileId == profile.id && item.revision != state.revision) {
          _reload();
          return;
        }
      }
    } catch (_) {
      // 읽지 못하면 다음에 다시 보일 때 본다.
    }
  }

  /// 서비스 시계(검수 fixture), 없으면 기기 시계.
  DateTime _now() => appClockNow(widget.service);

  @override
  void didUpdateWidget(StatisticsPage old) {
    super.didUpdateWidget(old);
    if (old.returnToken != widget.returnToken) _restoreOnReload = true;
    if (old.service != widget.service) {
      old.service.state.removeListener(_connectionChanged);
      widget.service.state.addListener(_connectionChanged);
      _requestReload();
    } else if (old.reloadToken != widget.reloadToken) {
      _requestReload();
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.service.state.removeListener(_connectionChanged);
    _filter.removeListener(_filterChanged);
    _filter.dispose();
    _filterModal.removeListener(_filterModalChanged);
    _filterModal.dispose();
    super.dispose();
  }

  void _filterChanged() {
    if (mounted) setState(() {});
  }

  /// 닫히면(닫기 · Esc · 스크림 · 탭 떠남) 적용하지 않은 초안을 버린다.
  void _filterModalChanged() {
    if (!_filterModal.isOpen) _filter.discardDraft();
  }

  void _openFilter() {
    if (_filterModal.isOpen) return;
    _filter.beginEdit();
    _filterModal.open();
  }

  /// 적용 필터가 바뀌면 고른 구간 · 근거 펼침을 지운다(대상 학생이 바뀌었다).
  void _changeFilter(VoidCallback change) => setState(() {
    change();
    _growthSelection = null;
    _evidenceExpanded = false;
  });

  void _applyFilter() {
    _changeFilter(_filter.applyDraft);
    _filterModal.close();
  }

  /// "학생 탭 필터 불러오기": 학생 탭의 적용 값을 초안에 한 번 복사한다(연결 아님, FD-104).
  void _importStudentFilter() {
    final source = widget.studentFilter;
    if (source != null) _filter.updateDraft(source.applied);
  }

  /// 필터 후보(보유 학생, 지금 값).
  List<StudentFilterCandidate> _currentCandidates() {
    if (!identical(_candidatesState, _state) ||
        !identical(_candidatesStudents, _students)) {
      _candidatesState = _state;
      _candidatesStudents = _students;
      _candidates = statisticsFilterCandidates(
        state: _state,
        catalog: _students,
      );
    }
    return _candidates;
  }

  /// 학생 성장 범위(통계 필터를 건 성장). 성장 자료가 없으면 null.
  StatisticsGrowthScope? _currentScope(StatisticsGrowth? growth) {
    if (growth == null) return null;
    final candidates = _currentCandidates();
    final selection = _filter.applied;
    if (!identical(_scopeGrowth, growth) ||
        _scopeSelection != selection ||
        !identical(_scopeCandidates, candidates)) {
      _scopeGrowth = growth;
      _scopeSelection = selection;
      _scopeCandidates = candidates;
      _scope = StatisticsGrowthScope.filtered(
        growth,
        selection: selection,
        candidates: candidates,
        groups: _filter.groups,
      );
    }
    return _scope;
  }

  void _connectionChanged() {
    if (!mounted) return;
    if (widget.service.state.value.connection == BackendConnection.connected) {
      _requestReload();
    } else {
      _generation++;
      setState(() => _loading = false);
    }
  }

  /// 보이면 바로 읽고, 숨어 있으면 진행 중인 읽기를 버리고 다시 보일 때 읽는다.
  void _requestReload() {
    if (_visible) {
      _reload();
      return;
    }
    _generation++;
    _stale = true;
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    _stale = false;
    final restore = _restoreOnReload
        ? (
            growth: _growthSelection,
            supply: _supplySelection,
            expanded: _evidenceExpanded,
            supplyExpanded: _supplyExpanded,
          )
        : null;
    _restoreOnReload = false;
    setState(() {
      _loading = true;
      _growthSelection = null;
      _supplySelection = null;
      _evidenceExpanded = false;
      _supplyExpanded = false;
      _profile = null;
      _state = null;
      _students = null;
      _inventory = null;
      _gross = null;
      _shortages = null;
      _plan = null;
      _planProjection = null;
      _planError = null;
      _history = null;
      _historyError = null;
      _historyLoading = false;
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
          _profileError = '계정 저장소에 연결할 수 없습니다.';
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
          _profileError = '계정 목록을 읽지 못했습니다: $error';
          _loading = false;
        });
      return;
    }
    final profile = _profile!;
    if (repository case final RepositoryPlanService plans) {
      try {
        final value = await plans.loadRepositoryPlan(profile.id);
        if (mounted && generation == _generation)
          setState(() => _plan = value);
      } catch (error) {
        if (mounted && generation == _generation)
          setState(() => _planError = '활성 계획을 읽지 못했습니다: $error');
      }
      if (!mounted || generation != _generation) return;
    }
    try {
      final value = await repository.loadRepositoryState(profile.id);
      if (mounted && generation == _generation) setState(() => _state = value);
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() => _stateError = '계정 상태를 읽지 못했습니다: $error');
    }
    try {
      final value = await widget.service.listStudents();
      if (mounted && generation == _generation)
        setState(() => _students = value);
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() => _studentError = '학생 목록을 읽지 못했습니다: $error');
    }
    try {
      final value = await widget.service.listInventoryItems();
      if (mounted && generation == _generation)
        setState(() => _inventory = value.items);
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() => _inventoryError = '인벤토리 목록을 읽지 못했습니다: $error');
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
          setState(() => _grossError = '성장 비용을 계산하지 못했습니다: $error');
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
          setState(() => _shortageError = '부족 재화를 계산하지 못했습니다: $error');
      }
    } else {
      _gross = null;
      _shortages = null;
    }
    if (!mounted || generation != _generation) return;
    await _calculatePlan(generation, snapshot);
    if (mounted && generation == _generation)
      setState(() {
        _loading = false;
        if (restore != null) _restoreSelection(restore);
      });
    if (!mounted || generation != _generation) return;
    await _loadHistory(generation, profile);
  }

  /// 이력(FE7-h): events 전부(같은 anchor, cursor 끝까지), 보유 학생 · 카탈로그 재화의 scan_latest(256개씩).
  Future<void> _loadHistory(int generation, RepositoryProfile profile) async {
    final repository = _repository;
    final state = _state;
    if (repository == null || state == null) return;
    setState(() => _historyLoading = true);
    StatisticsHistory? history;
    String? error;
    try {
      final now = _now();
      final pages = <RepositoryHistoryEventsResult>[];
      var request = RepositoryHistoryEventsRequest(
        profileId: profile.id,
        limit: inventoryHistoryPageLimit,
      );
      while (true) {
        final page = await repository.loadRepositoryHistoryEvents(request);
        if (!mounted || generation != _generation) return;
        pages.add(page);
        final cursor = page.nextCursor;
        if (cursor == null) break;
        if (pages.length >= _historyMaxPages) {
          throw StateError('history_too_large');
        }
        request = request.withCursor(cursor);
      }
      if (pages.first.revision != state.revision) {
        error = statisticsHistoryMismatchText;
      } else {
        Future<List<RepositoryHistoryScanLatestResult>> latest(
          List<String> ids, {
          required bool students,
        }) async {
          final results = <RepositoryHistoryScanLatestResult>[];
          for (
            var start = 0;
            start < ids.length;
            start += inventoryScanLatestChunk
          ) {
            final chunk = ids.sublist(
              start,
              math.min(ids.length, start + inventoryScanLatestChunk),
            );
            results.add(
              await repository.loadRepositoryHistoryScanLatest(
                RepositoryHistoryScanLatestRequest(
                  profileId: profile.id,
                  studentIds: students ? chunk : null,
                  resourceKeys: students ? null : chunk,
                ),
              ),
            );
            if (!mounted || generation != _generation) return const [];
          }
          return results;
        }

        final studentScans = await latest([
          for (final student in state.students) student.studentId,
        ], students: true);
        if (!mounted || generation != _generation) return;
        final inventoryScans = await latest(
          {
            for (final item in _inventory ?? const <InventoryCatalogEntry>[])
              historyCanonicalResourceKey(item.resourceKey),
          }.toList(),
          students: false,
        );
        if (!mounted || generation != _generation) return;
        history = StatisticsHistory.build(
          StatisticsHistoryInput(
            now: now,
            state: state,
            pages: pages,
            students: _students,
            lastStudentScanAt: statisticsLastStudentScanAt(studentScans),
            lastInventoryScanAt: inventoryLastScanAt(inventoryScans),
          ),
        );
      }
    } catch (failure) {
      error = '변화 기록을 읽지 못했습니다: $failure';
    }
    if (mounted && generation == _generation)
      setState(() {
        _history = history;
        _historyError = error;
        _historyLoading = false;
      });
  }

  /// B3 보드: 계획이 있으면 인벤토리 · 계획 projection의 보드, 없으면 카탈로그 · 계정 인벤토리만으로 만든다.
  InventoryBoard? _b3Board(StatisticsSupply? supply) {
    if (supply != null) return supply.board;
    final catalog = _inventory;
    final state = _state;
    if (catalog == null || state == null) return null;
    if (!identical(_plainBoardCatalog, catalog) ||
        !identical(_plainBoardState, state)) {
      _plainBoardCatalog = catalog;
      _plainBoardState = state;
      _plainBoard = InventoryBoard.build(
        catalog: catalog,
        inventory: state.inventory,
        shortages: null,
      );
    }
    return _plainBoard;
  }

  /// 이력 화면 값(FE7-h). [growth] · [supply]는 지금 읽은 projection이다. [growth]는 통계 필터가 걸렸으면 대상 학생만의
  /// 성장이고, [targets]는 그 학생 id다(FE7-e: A6 · 성장 KPI 증감도 대상 학생만 센다).
  StatisticsHistoryView _currentHistoryView(
    StatisticsGrowth? growth,
    StatisticsSupply? supply, {
    Set<String>? targets,
  }) {
    final loading = _loading || _historyLoading;
    final history = loading ? null : _history;
    final board = loading ? null : _b3Board(supply);
    final cached = _historyView;
    if (cached != null &&
        identical(_historyViewSource, history) &&
        identical(_historyViewGrowth, growth) &&
        identical(_historyViewSupply, supply) &&
        identical(_historyBoard, board) &&
        _historyViewRange == _b3Range &&
        _historyViewLoading == loading &&
        _historyViewError == _historyError) {
      return cached;
    }
    _historyViewSource = history;
    _historyViewGrowth = growth;
    _historyViewSupply = supply;
    _historyBoard = board;
    _historyViewRange = _b3Range;
    _historyViewLoading = loading;
    _historyViewError = _historyError;
    final student = history?.lastStudentScanAt;
    final inventory = history?.lastInventoryScanAt;
    return _historyView = StatisticsHistoryView(
      loading: loading,
      error: loading ? null : _historyError,
      history: history,
      studentScan: history == null || student == null
          ? '—'
          : accountLastScanText(student.toIso8601String(), history.now),
      inventoryScan: history == null || inventory == null
          ? '—'
          : accountLastScanText(inventory.toIso8601String(), history.now),
      inventoryScanDays: history == null || inventory == null
          ? null
          : inventoryDaysAgo(inventory, history.now),
      growthDeltas: statisticsGrowthDeltas(history, growth, targets: targets),
      supplyDeltas: statisticsSupplyDeltas(
        history,
        supply,
        catalog: _inventory,
        state: _state,
        shortages: _shortages,
      ),
      growthTrend: statisticsGrowthTrend(history, targets: targets),
      resourceTrends: statisticsResourceTrends(history, board, _b3Range),
      b3Range: _b3Range,
      onB3RangeChanged: (range) => setState(() => _b3Range = range),
    );
  }

  /// "← 통계"로 돌아와 다시 읽은 뒤: 고른 구간 · 재화가 아직 근거를 가지면 되살린다(FE7-d). setState 안에서 부른다.
  void _restoreSelection(
    ({
      StatisticsGrowthSelection? growth,
      StatisticsSupplySelection? supply,
      bool expanded,
      bool supplyExpanded,
    })
    saved,
  ) {
    final growth = _currentGrowth();
    final growthSelection = saved.growth;
    final scoped = _currentScope(growth)?.growth ?? growth;
    if (growthSelection != null &&
        (StatisticsGrowthView(
              growth: scoped,
              metric: _growthMetric,
              selection: growthSelection,
              breakdown: _currentBreakdown(scoped),
              a4Group: _a4Group,
            ).evidence?.students.isNotEmpty ??
            false)) {
      _growthSelection = growthSelection;
      _evidenceExpanded = saved.expanded;
    }
    final supplySelection = saved.supply;
    if (supplySelection != null &&
        _supplyView(growth, supplySelection).evidence != null) {
      _supplySelection = supplySelection;
      _supplyExpanded = saved.supplyExpanded;
    }
  }

  /// 활성 문서 계산(FE7-g): 문서에 단계가 있고, 서비스가 계산할 수 있다고 한 문서(`calculation` 요약이 있음)만 부른다(계획
  /// 홈과 같은 조건). 응답 형식은 계획 홈과 같은 검사([PlanDetailData.checkProjection])를 거친다.
  Future<void> _calculatePlan(int generation, RepositoryState? snapshot) async {
    final plan = _plan;
    final AppService service = widget.service;
    if (snapshot == null ||
        plan == null ||
        plan.document.stages.isEmpty ||
        service is! PlanningDocumentService) {
      return;
    }
    if (plan.calculation == null) {
      setState(() => _planError = '지금은 활성 계획을 계산할 수 없습니다.');
      return;
    }
    final calculator = service as PlanningDocumentService;
    try {
      final value = await calculator.calculatePlanningDocument(
        currentStudents: snapshot.students
            .map(confirmedStudentPlanningCurrent)
            .toList(growable: false),
        inventory: snapshot.inventory.toWire(),
        document: plan.document.toWire(),
      );
      PlanDetailData.checkProjection(value);
      if (mounted && generation == _generation)
        setState(() => _planProjection = value);
    } catch (error) {
      if (mounted && generation == _generation)
        setState(() => _planError = '활성 계획을 계산하지 못했습니다: $error');
    }
  }

  /// 계획 집계 문서 계산 projection(문서 계산이 없으면 null).
  StatisticsPlanning? _currentPlanning() {
    final projection = _planProjection;
    if (!identical(_planningPlan, _plan) ||
        !identical(_planningProjection, projection)) {
      _planningPlan = _plan;
      _planningProjection = projection;
      _planning = StatisticsPlanning.build(
        document: projection == null ? null : _plan?.document,
        projection: projection,
      );
    }
    return _planning;
  }

  /// A3 · A4 projection([growth]는 통계 필터 대상 학생의 성장, FE7-f).
  StatisticsGrowthBreakdown? _currentBreakdown(StatisticsGrowth? growth) {
    if (growth == null) return null;
    if (!identical(_breakdownGrowth, growth) ||
        !identical(_breakdownStudents, _students)) {
      _breakdownGrowth = growth;
      _breakdownStudents = _students;
      _breakdown = StatisticsGrowthBreakdown.of(growth, _students);
    }
    return _breakdown;
  }

  /// C4 projection(계정 상태 · 학생 목록, 통계 필터와 상관없다 — FD-104).
  StatisticsGoalProgressSet? _currentGoals() {
    final state = _state;
    if (state == null) return null;
    if (!identical(_goalsState, state) ||
        !identical(_goalsStudents, _students)) {
      _goalsState = state;
      _goalsStudents = _students;
      _goals = StatisticsGoalProgressSet.of(state: state, catalog: _students);
    }
    return _goals;
  }

  /// B2 근거 "필요량 순"의 단계별 사용(활성 문서 계산이 없으면 null).
  Map<String, List<InventoryStageUse>>? _currentStageUses() {
    final projection = _planProjection;
    final plan = _plan;
    if (projection == null || plan == null) return null;
    if (!identical(_stageUsesProjection, projection)) {
      _stageUsesProjection = projection;
      _stageUses = inventoryStageUses(projection, plan.document);
    }
    return _stageUses;
  }

  StatisticsGrowth? _currentGrowth() {
    if (!identical(_growthState, _state) ||
        !identical(_growthStudents, _students)) {
      _growthState = _state;
      _growthStudents = _students;
      _growth = buildStatisticsGrowth(state: _state, catalog: _students);
    }
    return _growth;
  }

  /// 인벤토리 · 계획 projection(성장 projection 뒤에 만든다 — 미계획 학생 KPI · 근거 학생 이름 · 레벨).
  StatisticsSupply? _currentSupply(StatisticsGrowth? growth) {
    if (!identical(_supplyCatalog, _inventory) ||
        !identical(_supplyState, _state) ||
        !identical(_supplyShortages, _shortages) ||
        !identical(_supplyGrowth, growth)) {
      _supplyCatalog = _inventory;
      _supplyState = _state;
      _supplyShortages = _shortages;
      _supplyGrowth = growth;
      _supply = StatisticsSupply.build(
        catalog: _inventory,
        state: _state,
        shortages: _shortages,
        growth: growth,
      );
      _supplyStudents = statisticsEvidenceStudents(
        growth: growth,
        catalog: _students,
      );
    }
    return _supply;
  }

  void _select(StatisticsGrowthSelection? selection) => setState(() {
    _growthSelection = selection;
    _evidenceExpanded = false;
  });

  /// 인벤토리 · 계획 주제 화면 상태(지금 읽은 자료 + [selection]).
  StatisticsSupplyView _supplyView(
    StatisticsGrowth? growth,
    StatisticsSupplySelection? selection,
  ) => StatisticsSupplyView(
    supply: _loading ? null : _currentSupply(growth),
    loading: _loading,
    selection: selection,
    students: _supplyStudents,
    onSelectionChanged: (selection) => setState(() {
      _supplySelection = selection;
      _supplyExpanded = false;
    }),
    expanded: _supplyExpanded,
    onExpand: () => setState(() => _supplyExpanded = true),
    planning: _loading ? null : _currentPlanning(),
    planningError: _planError,
    goals: _loading ? null : _currentGoals(),
    stageUses: _loading ? null : _currentStageUses(),
    recent: _loading || _historyLoading ? null : _history?.inventoryWindow,
    b2Order: _b2Order,
    onB2OrderChanged: (order) => setState(() {
      _b2Order = order;
      // 고른 B2 행은 순서가 바뀌면 화면에 없을 수 있다(C1과 같다).
      if (_supplySelection case StatisticsResourceSelection(
        source: StatisticsResourceSource.b2,
      )) {
        _supplySelection = null;
        _supplyExpanded = false;
      }
    }),
    c1Order: _c1Order,
    onC1OrderChanged: (order) => setState(() {
      _c1Order = order;
      // 고른 C1 행은 순서가 바뀌면 화면에 없을 수 있다.
      if (_supplySelection case StatisticsResourceSelection(
        source: StatisticsResourceSource.c1,
      )) {
        _supplySelection = null;
        _supplyExpanded = false;
      }
    }),
  );

  /// 근거 패널 아래 두 버튼(FE7-d, 시안 Stats-Growth · Stats-Inventory · Stats-Plan 문구). 고른 것이 없거나 넘길 대상이
  /// 없으면 FE7-a 글자 그대로 비활성이다.
  /// - 학생 성장: "학생 탭에서 보기 · 필터: <구간>" → 학생 탭 임시 목록(근거 학생 전부), "이 구간 학생을 계획에 추가" →
  ///   계획 만들기 1단계에 그 학생들을 미리 고른다.
  /// - 인벤토리 현황(B1 카테고리): "인벤토리 · 티어별 충족률" → 티어별 충족률(그 표가 있는 노트 · BD · 오파츠만),
  ///   "인벤토리 · 부족 위험에서 보기" → 그 카테고리 근거 첫 행(충족률 가장 낮은 재화).
  /// - 계획 집계(C1 · C2 재화): "인벤토리 · 부족 위험에서 보기" → 그 재화 행, "계획 만들기 3 · 단계 순서 · Pn 선택 ·
  ///   순서 바꾸기" → 페이즈 편집 흐름 3단계에서 그 재화의 첫 막히는 단계 카드(활성 문서 계산에 막히는 단계가 있을 때만).
  /// FE7-e: 통계 필터가 걸려 있으면 학생 성장 버튼 둘째 줄 · 학생 탭 칩 글자에 필터 칩 이름을 잇는다(시안 Stats-Growth-Filter
  /// "필터: 육성도 60~70% · 밀레니엄 · 스트라이커"). 넘기는 학생은 이미 대상 학생뿐이다.
  (StatisticsEvidenceAction, StatisticsEvidenceAction) _evidenceActions(
    StatisticsGrowthView growthView,
    StatisticsSupplyView supplyView, {
    StatisticsGrowthScope? scope,
  }) {
    final defaults = _mode.evidenceActions;
    final (secondary, primary) = defaults;
    final navigate = widget.onNavigate;
    if (navigate == null || _loading) return defaults;
    switch (_mode) {
      case StatisticsMode.students:
        final evidence = growthView.evidence;
        if (evidence == null || evidence.students.isEmpty) return defaults;
        final ids = [
          for (final student in evidence.students) student.studentId,
        ];
        final title = [
          evidence.title,
          if (scope != null && scope.filtered)
            for (final chip in scope.chips) chip.label,
        ].join(' · ');
        return (
          StatisticsEvidenceAction(
            secondary.label,
            '필터: $title',
            () => navigate(
              StudentsNavigationIntent(
                studentIds: ids,
                label: '통계: $title · ${ids.length}명',
              ),
            ),
          ),
          StatisticsEvidenceAction(
            primary.label,
            primary.detail,
            () => navigate(PlanNavigationIntent.students(ids)),
          ),
        );
      case StatisticsMode.inventory:
        final evidence = supplyView.evidence;
        // B2 행(FE7-f): 그 재화 행, 티어 표가 있는 카테고리면 티어별 충족률.
        if (evidence?.resource case final resource?) {
          return (
            _tierCategories.contains(resource.item.category)
                ? StatisticsEvidenceAction(
                    secondary.label,
                    secondary.detail,
                    () => navigate(InventoryNavigationIntent.tiers()),
                  )
                : secondary,
            StatisticsEvidenceAction(
              primary.label,
              primary.detail,
              () => navigate(InventoryNavigationIntent.row(resource.key)),
            ),
          );
        }
        final category = supplyView.selectedCategory;
        if (category == null || evidence == null) return defaults;
        final first = evidence.resources?.firstOrNull;
        return (
          _tierCategories.contains(category)
              ? StatisticsEvidenceAction(
                  secondary.label,
                  secondary.detail,
                  () => navigate(InventoryNavigationIntent.tiers()),
                )
              : secondary,
          first == null
              ? primary
              : StatisticsEvidenceAction(
                  primary.label,
                  primary.detail,
                  () => navigate(InventoryNavigationIntent.row(first.key)),
                ),
        );
      case StatisticsMode.plan:
        final evidence = supplyView.evidence;
        // C4 학생(FE7-f): "계획 만들기 2 · 목표 정하기" → 활성 계획 편집 흐름 2단계에서 그 학생.
        if (evidence?.goal case final goal?) {
          return (
            secondary,
            StatisticsEvidenceAction(
              statisticsGoalActionLabel,
              '${goal.displayName} 목표 고치기',
              () => navigate(PlanNavigationIntent.goals(goal.studentId)),
            ),
          );
        }
        final resource = evidence?.resource;
        if (evidence == null || resource == null) return defaults;
        final stage = evidence.stages.firstOrNull?.stage;
        return (
          StatisticsEvidenceAction(
            secondary.label,
            secondary.detail,
            () => navigate(InventoryNavigationIntent.row(resource.key)),
          ),
          stage == null
              ? primary
              : StatisticsEvidenceAction(
                  primary.label,
                  'P${stage.phase} 선택 · 순서 바꾸기',
                  () => navigate(PlanNavigationIntent.order(stage.stageId)),
                ),
        );
    }
  }

  /// 인벤토리 티어별 충족률 표가 있는 카테고리(노트 · BD 학교 × 티어, 오파츠 종류 × 티어, FE6-e).
  static const _tierCategories = {
    inventoryTechNotesCategory,
    inventoryTacticalBdCategory,
    inventoryOopartCategory,
  };

  @override
  Widget build(BuildContext context) {
    final data = StatisticsSourceData(
      connection: widget.service.state.value.connection,
      loading: _loading,
      profile: _profile,
      state: _state,
      students: _students,
      inventory: _inventory,
      gross: _gross,
      shortages: _shortages,
      errors: [
        for (final error in [
          _profileError,
          _stateError,
          _studentError,
          _inventoryError,
          _grossError,
          _shortageError,
        ])
          ?error,
      ],
    );
    final growth = _loading ? null : _currentGrowth();
    // FE7-e: 학생 성장(A1~A6 · KPI · 근거)은 통계 필터 대상 학생만, 인벤토리 · 계획은 전체 성장이다.
    final scope = _currentScope(growth);
    final growthView = StatisticsGrowthView(
      growth: scope?.growth ?? growth,
      breakdown: _currentBreakdown(scope?.growth ?? growth),
      a4Group: _a4Group,
      onA4GroupChanged: (group) => setState(() {
        _a4Group = group;
        // 다른 seg의 점을 고른 채면 푼다.
        if (_growthSelection case StatisticsGrowthGroupSelection(
          group: final selected,
        ) when selected.group != group) {
          _growthSelection = null;
          _evidenceExpanded = false;
        }
      }),
      metric: _growthMetric,
      selection: _growthSelection,
      expanded: _evidenceExpanded,
      onMetricChanged: (metric) => setState(() {
        _growthMetric = metric;
        _growthSelection = null;
        _evidenceExpanded = false;
      }),
      onSelectionChanged: _select,
      onExpand: () => setState(() => _evidenceExpanded = true),
    );
    final supplyView = _supplyView(growth, _supplySelection);
    return BaModal(
      controller: _filterModal,
      scrim: BaScrim.filter,
      label: '통계 필터',
      builder: (context) => ListenableBuilder(
        listenable: _filter,
        builder: (context, _) => _filterModalContent(),
      ),
      child: StatisticsWorkspace(
        key: const ValueKey('statistics-page'),
        mode: _mode,
        data: data,
        growth: growthView,
        supply: supplyView,
        history: _currentHistoryView(
          scope?.growth ?? growth,
          supplyView.supply,
          targets: scope?.targets,
        ),
        filter: StatisticsFilterView(
          scope: scope,
          onOpen: scope == null ? null : _openFilter,
          onRemove: (chip) => _changeFilter(() => _filter.removeApplied(chip)),
          onClear: () => _changeFilter(
            () => _filter.applied = StudentFilterSelection.empty,
          ),
        ),
        evidenceActions: _evidenceActions(growthView, supplyView, scope: scope),
        onModeChanged: (mode) => setState(() {
          _mode = mode;
          _growthSelection = null;
          _supplySelection = null;
          _evidenceExpanded = false;
          _supplyExpanded = false;
        }),
        onRescan: () => widget.onOpen(AppSection.scan),
      ),
    );
  }

  /// 통계 필터 모달 내용(시안 Stats-Filter-Open): 공용 모달에 통계 전용 상태를 넣는다. 머리는 "통계 필터" · "학생 성장(A)에만
  /// 적용 / 학생 탭 필터와 따로 저장" · "n / 보유명" · 적용 칩 · "학생 탭 필터 불러오기"다. 배지 자리 (18, 226)는 학생 탭
  /// S1 버튼 자리라 그리지 않는다(통계 필터 버튼은 왼쪽 섹션 (14, 551)이고 그 버튼이 개수를 보인다).
  Widget _filterModalContent() {
    final candidates = _currentCandidates();
    final source = widget.studentFilter;
    return StudentFilterModal(
      key: const ValueKey('statistics-filter-modal'),
      selection: _filter.draft ?? _filter.applied,
      onChanged: _filter.updateDraft,
      candidates: candidates,
      groups: _filter.groups,
      totalCount: _state?.students.length ?? candidates.length,
      onApply: _applyFilter,
      onReset: _filter.resetDraft,
      onClose: _filterModal.close,
      showCountBadge: false,
      title: '통계 필터',
      caption: '학생 성장(A)에만 적용\n학생 탭 필터와 따로 저장',
      headerAction: TonalButton(
        key: const ValueKey('statistics-filter-import'),
        label: '학생 탭 필터 불러오기',
        icon: Icons.copy_rounded,
        horizontalPadding: 14,
        onPressed: source == null ? null : _importStudentFilter,
      ),
    );
  }
}
