// ignore_for_file: curly_braces_in_flow_control_structures

// 통계 탭(FE7-a 골격, 시안 Stats-Growth · Stats-Inventory · Stats-Plan).
//
// 화면은 `ui/statistics/statistics_workspace.dart`의 3섹션이다. 이 State는 원천 자료 읽기(`_reload()`)만 맡는다:
// 계정 → 계정 상태 → 학생 목록 → 인벤토리 목록 → (목표가 있으면) 총 계산 · 부족 계산, generation 가드.
// 읽기는 탭이 처음 보일 때 시작한다(FE6-b 인벤토리와 같은 정책). 셸은 모든 탭을 오프스테이지로 짓고, 보이지 않는
// 탭은 `TickerMode`가 꺼져 있으므로 그것으로 보임을 판단한다(`app_shell.dart`를 고치지 않는다). 숨어 있는 동안
// 다시 읽기 요청(`reloadToken` · 연결 · 서비스 교체)이 오면 표시만 해 두고, 다시 보일 때 한 번 읽는다.
import 'package:flutter/material.dart';

import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../app_section.dart';
import '../statistics/statistics_source.dart';
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
  String? _profileError,
      _stateError,
      _studentError,
      _inventoryError,
      _grossError,
      _shortageError;
  bool _loading = true;
  int _generation = 0;
  StatisticsMode _mode = StatisticsMode.students;

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
      _profile = null;
      _state = null;
      _students = null;
      _inventory = null;
      _gross = null;
      _shortages = null;
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
    if (mounted && generation == _generation) setState(() => _loading = false);
  }

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
    return StatisticsWorkspace(
      key: const ValueKey('statistics-page'),
      mode: _mode,
      data: data,
      onModeChanged: (mode) => setState(() => _mode = mode),
      onRescan: () => widget.onOpen(AppSection.scan),
    );
  }
}
