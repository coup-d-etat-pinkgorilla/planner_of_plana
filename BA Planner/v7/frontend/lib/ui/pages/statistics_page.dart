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
import 'package:flutter/material.dart';

import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../statistics/statistics_growth_projection.dart';
import '../../statistics/statistics_plan_projection.dart';
import '../../statistics/statistics_supply_projection.dart';
import '../app_section.dart';
import '../models/plan_scenario_detail.dart' show PlanDetailData;
import '../statistics/statistics_growth_evidence.dart';
import '../statistics/statistics_source.dart';
import '../statistics/statistics_supply_evidence.dart';
import '../statistics/statistics_topics.dart';
import '../statistics/statistics_workspace.dart';

export '../statistics/statistics_topics.dart' show StatisticsMode;

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

  /// 인벤토리 · 계획 projection 캐시(읽은 인벤토리 목록 · 계정 상태 · 부족 계산 · 성장이 같으면 다시 만들지 않는다).
  StatisticsSupply? _supply;
  Map<String, StatisticsEvidenceStudent> _supplyStudents = const {};
  List<InventoryCatalogEntry>? _supplyCatalog;
  RepositoryState? _supplyState;
  InventoryShortageResult? _supplyShortages;
  StatisticsGrowth? _supplyGrowth;

  /// C1 순서(FE7-g). 다시 읽어도 남긴다.
  StatisticsC1Order _c1Order = StatisticsC1Order.shortage;

  /// 문서 계산 projection 캐시(읽은 문서 · 문서 계산이 같으면 다시 만들지 않는다).
  StatisticsPlanning? _planning;
  RepositoryPlanState? _planningPlan;
  Map<String, dynamic>? _planningProjection;

  /// 이 탭이 지금 보이는가(`TickerMode`).
  bool _visible = false;

  /// 보이지 않는 동안 다시 읽기 요청이 있었는가. 처음에는 아직 읽지 않았으므로 true다.
  bool _stale = true;

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (visible && _stale) _reload();
  }

  @override
  void didUpdateWidget(StatisticsPage old) {
    super.didUpdateWidget(old);
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
    super.dispose();
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
    setState(() {
      _loading = true;
      _growthSelection = null;
      _supplySelection = null;
      _evidenceExpanded = false;
      _profile = null;
      _state = null;
      _students = null;
      _inventory = null;
      _gross = null;
      _shortages = null;
      _plan = null;
      _planProjection = null;
      _planError = null;
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
    if (mounted && generation == _generation) setState(() => _loading = false);
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
    return StatisticsWorkspace(
      key: const ValueKey('statistics-page'),
      mode: _mode,
      data: data,
      growth: StatisticsGrowthView(
        growth: growth,
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
      ),
      supply: StatisticsSupplyView(
        supply: _loading ? null : _currentSupply(growth),
        loading: _loading,
        selection: _supplySelection,
        students: _supplyStudents,
        onSelectionChanged: (selection) =>
            setState(() => _supplySelection = selection),
        planning: _loading ? null : _currentPlanning(),
        planningError: _planError,
        c1Order: _c1Order,
        onC1OrderChanged: (order) => setState(() {
          _c1Order = order;
          // 고른 C1 행은 순서가 바뀌면 화면에 없을 수 있다.
          if (_supplySelection case StatisticsResourceSelection(
            source: StatisticsResourceSource.c1,
          )) {
            _supplySelection = null;
          }
        }),
      ),
      onModeChanged: (mode) => setState(() {
        _mode = mode;
        _growthSelection = null;
        _supplySelection = null;
        _evidenceExpanded = false;
      }),
      onRescan: () => widget.onOpen(AppSection.scan),
    );
  }
}
