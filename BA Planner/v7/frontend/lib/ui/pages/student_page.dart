import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../app_section.dart';
import '../kit/ba_modal.dart';
import '../kit/kit_overlay.dart';
import '../models/active_plan_bond_target.dart';
import '../models/growth_calculator_adapter.dart';
import '../models/growth_calculator_rules.dart';
import '../models/growth_calculator_state.dart';
import '../models/planning_models.dart';
import '../models/recent_students.dart';
import '../models/repository_plan_snapshot.dart';
import '../models/student_filter_controller.dart';
import '../navigation/app_navigation_intent.dart';
import '../widgets/diagonal_section.dart';
import '../widgets/growth_calculator_section.dart';
import '../widgets/page_header_override.dart';
import '../widgets/plan_element_builder.dart' show planElementCurrentTargets;
import '../widgets/student_grid_warmup.dart';
import '../widgets/student_section_layout.dart';

class StudentCandidateContext {
  const StudentCandidateContext({
    required this.session,
    required this.candidate,
  });
  final ScannerSession session;
  final ScannerCandidate candidate;
}

class StudentPage extends StatefulWidget {
  const StudentPage({
    super.key,
    required this.service,
    required this.onAddToPlan,
    this.onOpenScan,
    this.candidateContext,
    this.onCandidateCommitted,
    this.active = true,
    this.recentStudents,
    this.headerOverride,
    this.navigation,
    this.onNavigate,
    this.filterController,
  });

  final AppService service;

  /// 계획 만들기로 학생을 넘긴다. FD-160 (a)로 학생 S1의 "포커스 학생으로 계획 열기" 자리가 "성장 계산기
  /// 열기"가 되어, 성장 계산기 "이 목표로 계획에 추가"(FE4-g, FD-171 (a))만 쓴다. 시드에 계산기 목표를 싣는다.
  final ValueChanged<PlanningStudentSeed> onAddToPlan;
  final VoidCallback? onOpenScan;
  final StudentCandidateContext? candidateContext;
  final ValueChanged<ScannerCandidate>? onCandidateCommitted;
  final bool active;

  /// 최근 본 학생(FD-061). 앱 셸이 계획 화면과 함께 쓰도록 넘긴다. 없으면 페이지가 만든다.
  final RecentStudents? recentStudents;

  /// 성장 계산기 모드의 머리말 제목·"← 학생" 칩(FD-161 (a)). 앱 셸이 넘긴다.
  final PageHeaderOverrideController? headerOverride;

  /// 통계 근거 "학생 탭에서 보기"(FE7-d). 같은 의도는 한 번만 적용한다: 그 학생만 보이는 이동용 임시 목록을 걸고(학생
  /// 필터 상태는 그대로, FD-104), 고른 학생이 목록에 없으면 첫 학생을 고르고, 계산기가 열려 있으면 닫는다. 임시 목록은
  /// S4 칩 × · "모두 지우기" · 탭을 떠날 때 지운다.
  final StudentsNavigationIntent? navigation;

  /// 다른 탭으로 가는 이동 의도(tidy1, FD-108). 앱 셸이 넘긴다. 지금은 계산기 "인벤토리 · 부족 위험에서 보기" 연결만
  /// 준비한다(버튼은 FD-173 (c) 그대로 숨김, [GrowthCalculatorModeData.onOpenInventory]).
  final ValueChanged<AppNavigationIntent>? onNavigate;

  /// 학생 탭 필터 상태. 앱 셸이 넘기면 그 객체를 쓴다(FE7-e: 통계 "학생 탭 필터 불러오기"가 적용 값을 읽기만 한다). 없으면
  /// 페이지가 만든다.
  final StudentFilterController? filterController;

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  final _search = TextEditingController();
  final Map<String, TextEditingController> _editors = {};
  List<StudentCatalogEntry> _catalog = const [];
  RepositoryState? _repositoryState;

  /// 저장된 활성 계획 문서(FD-049, FE4-h `plan.get`). 인연 목표(→N)·PLAN 배지·계산기 계획 포함의 원천이다.
  /// 읽지 못했으면 null이다.
  PlanningDocument? _activePlan;
  RepositoryProfile? _profile;
  String? _selectedId;
  String? _message;
  bool _loading = true;
  bool _saving = false;
  int _warmupRequest = 0;

  /// 성장 계산기 모드(FE3-f2a, FD-160 (a)). 열려 있으면 null이 아니다. 목표는 저장하지 않는다.
  GrowthCalculatorState? _calculator;
  GrowthCalculatorEngine? _calculatorEngine;

  /// 계산기 "빠른 목표"의 단계 프리셋 항목(FD-169 (a), FE4-i). 계산기를 열 때마다 선택 프로필 저장소(FB-14)에서
  /// 다시 읽는다. 저장소가 없거나 못 읽으면 비어 있다(고정 항목만).
  List<GrowthCalculatorPresetTarget> _calculatorPresets = const [];
  int _calculatorPresetsRequest = 0;

  /// 최근 계산(FD-170): 앱 실행 동안만, 계정이 바뀌면 비운다(최근 본 학생과 같은 규칙).
  final RecentGrowthCalculations _recentCalculations =
      RecentGrowthCalculations();

  /// S4·S1 배지·필터 모달이 함께 쓰는 필터 상태(FE3-c, FE3-d2). 성장 범위 조건도 여기 있다.
  late final StudentFilterController _filter =
      widget.filterController ?? (_ownFilter = StudentFilterController());
  StudentFilterController? _ownFilter;
  RecentStudents? _ownRecent;

  /// 마지막으로 적용한 이동 의도 id와 그 임시 목록(FE7-d).
  int? _navigationId;
  StudentsNavigationIntent? _restriction;
  Set<String>? _restrictedIds;

  RecentStudents get _recent =>
      widget.recentStudents ?? (_ownRecent ??= RecentStudents());

  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;
  ScannerService? get _scanner => widget.service is ScannerService
      ? widget.service as ScannerService
      : null;

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
    _filter.addListener(_stateChanged);
    _recent.addListener(_stateChanged);
    _recentCalculations.addListener(_stateChanged);
    _loadCatalog();
    _receiveNavigation();
  }

  /// 새 이동 의도를 다음 프레임에 적용한다(빌드 중에 선택 · 최근 본 학생 · 머리말 알림이 생기지 않게).
  void _receiveNavigation() {
    final intent = widget.navigation;
    if (intent == null || intent.id == _navigationId) return;
    _navigationId = intent.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navigationId != intent.id) return;
      if (_calculator != null) _closeCalculator();
      final ids = intent.studentIds;
      setState(() {
        _restriction = intent;
        _restrictedIds = ids.toSet();
        if (ids.isNotEmpty && !ids.contains(_selectedId)) _select(ids.first);
      });
      _syncEditors();
    });
  }

  void _clearRestriction() {
    if (_restriction == null) return;
    setState(() {
      _restriction = null;
      _restrictedIds = null;
    });
  }

  void _stateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(StudentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recentStudents != widget.recentStudents) {
      (oldWidget.recentStudents ?? _ownRecent)?.removeListener(_stateChanged);
      _recent.addListener(_stateChanged);
    }
    if (oldWidget.active != widget.active) _syncCalculatorEscape();
    // 이동용 임시 목록은 탭을 떠나면 지운다(다음에 학생 탭을 열면 평소 목록이다).
    if (oldWidget.active && !widget.active) {
      _restriction = null;
      _restrictedIds = null;
    }
    _receiveNavigation();
  }

  // --- 성장 계산기 모드 ------------------------------------------------------

  static const _calculatorTitle = '성장 계산기';
  static const _calculatorSubtitle =
      '학생 한 명 · 목표까지 필요한 인연 선물 · 크레딧 · 재화를 바로 계산 (계획에는 저장하지 않음)';

  /// 선택 학생의 현재값(계획 요소 빌더와 같은 변환, 미보유면 기본값).
  Map<String, int> _calculatorCurrent(StudentCatalogEntry entry) =>
      planElementCurrentTargets(
        PlanningStudentSeed(
          handoffId: 'growth-calculator-${entry.studentId}',
          studentId: entry.studentId,
          metadata: entry.metadata,
          currentValues: _selectedState?.values ?? const {},
          owned: _selectedState != null,
        ),
      );

  /// 선택 학생으로 계산기를 연다. 이미 열려 있으면 그 학생으로 다시 연다(기준은 유지).
  /// [record]가 있으면 그 최근 계산의 기준·목표로 연다(FD-170).
  void _openCalculator({GrowthCalculationRecord? record}) {
    final entry = _selectedEntry;
    if (entry == null) return;
    final previous = _calculator;
    final basis =
        record?.basis ?? previous?.basis ?? GrowthCalculatorBasis.confirmed;
    previous?.removeListener(_calculatorChanged);
    _disposeCalculatorEngine();
    final state = GrowthCalculatorState(
      studentId: entry.studentId,
      confirmedCurrent: _calculatorCurrent(entry),
      // 애장품 행은 catalog의 KR 애장품 제공 여부를 따른다(FB-13). 없으면 12행이다(FD-166 (c)).
      hasFavoriteItem: entry.hasFavoriteItem,
      basis: basis,
      initialTargets: record?.targets,
    )..addListener(_calculatorChanged);
    // 학생마다 새 계산 연결을 쓴다(앞 학생의 결과를 흐리게 보이지 않게). 단일 학생 계산(FB-11a)이 있으면
    // 그것을, 없으면 임시 문서 계산을 쓴다(어댑터가 고른다).
    _calculatorEngine = growthCalculatorSupports(widget.service)
        ? (GrowthCalculatorEngine(service: widget.service)
            ..addListener(_calculatorEngineChanged))
        : null;
    setState(() => _calculator = state);
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    widget.headerOverride?.set(
      PageHeaderOverride(
        owner: this,
        section: AppSection.students,
        title: _calculatorTitle,
        subtitle: _calculatorSubtitle,
        backLabel: '← 학생',
        onBack: _closeCalculator,
      ),
    );
    _syncCalculatorEscape();
    _scheduleCalculation();
    _loadCalculatorPresets();
  }

  /// 선택 프로필에 저장된 단계 프리셋의 마지막 단계를 읽는다(2단계 프리셋과 같은 저장소).
  Future<void> _loadCalculatorPresets() async {
    final service = widget.service;
    final profile = _profile;
    final request = ++_calculatorPresetsRequest;
    if (service is! RepositoryPresetsService || profile == null) return;
    try {
      final state = await (service as RepositoryPresetsService)
          .loadRepositoryPresets(profile.id);
      if (!mounted || request != _calculatorPresetsRequest) return;
      setState(() {
        _calculatorPresets = [
          for (final preset in state.stagePresets)
            if (preset.stages.isNotEmpty)
              GrowthCalculatorPresetTarget(
                id: preset.presetId,
                name: preset.name,
                targets: preset.stages.last.targets,
              ),
        ];
      });
    } on Object {
      if (!mounted || request != _calculatorPresetsRequest) return;
      setState(() => _calculatorPresets = const []);
    }
  }

  /// 학생 목록으로 돌아간다(복귀 칩 · Esc · 주 탭 "학생" 다시 누르기, FD-161 (a)).
  void _closeCalculator() {
    final state = _calculator;
    if (state == null || !mounted) return;
    KitOverlayEscape.remove(this);
    widget.headerOverride?.clear(this);
    state.removeListener(_calculatorChanged);
    setState(() => _calculator = null);
    _disposeCalculatorEngine();
    // 레이아웃이 이 상태를 놓은 뒤 버린다.
    WidgetsBinding.instance.addPostFrameCallback((_) => state.dispose());
  }

  void _disposeCalculatorEngine() {
    final engine = _calculatorEngine;
    _calculatorEngine = null;
    if (engine == null) return;
    engine.removeListener(_calculatorEngineChanged);
    engine.cancel();
    // 레이아웃이 아직 이 연결을 듣고 있을 수 있어 다음 프레임에 버린다.
    WidgetsBinding.instance.addPostFrameCallback((_) => engine.dispose());
  }

  /// 탭이 보이고 계산기가 열려 있을 때만 Esc가 계산기를 닫는다. 위에 열린 팝오버가 먼저 닫힌다.
  void _syncCalculatorEscape() {
    if (_calculator != null && widget.active && mounted) {
      KitOverlayEscape.push(this, context, _closeCalculator);
    } else {
      KitOverlayEscape.remove(this);
    }
  }

  void _calculatorChanged() => _scheduleCalculation();

  /// "이 목표로 계획에 추가"(FE4-g, FD-171 (a)): 선택 학생과 계산기 목표를 계획 만들기 2단계로 넘긴다.
  ///
  /// - 목표는 계산기가 지금 현재값보다 올린 키만 싣는다(19키 중 고르지 않은 키는 넘기지 않아 계획 쪽에서 null로
  ///   남는다). 직접 입력(FD-168)이어도 그 입력 현재값 자체는 넘기지 않는다.
  /// - 학생 현재값은 확정값(repository)이다. 계획 쪽은 이 값이 아니라 흐름의 확정값을 바닥으로 쓴다.
  /// - 인연 목표도 올렸을 때만 싣는다. 현재 인연을 목표로 복사하지 않는다(FB-1b 연결 메모 4).
  /// - 계산기 상태·최근 계산(FD-170)은 그대로 둔다. 학생 탭으로 돌아오면 계산기가 그대로 열려 있다.
  /// 계산기 "인벤토리 · 부족 위험에서 보기"(FD-173 (a) 준비, tidy1): 인벤토리 목록에서 그 재화 행을 고른다. 셸이 이동 의도를
  /// 받지 않으면 null이다.
  ValueChanged<String>? get _openInventory {
    final navigate = widget.onNavigate;
    if (navigate == null) return null;
    return (resourceKey) => navigate(
      InventoryNavigationIntent.row(resourceKey, origin: AppSection.students),
    );
  }

  void _addCalculatorToPlan() {
    final state = _calculator;
    final entry = _selectedEntry;
    if (state == null || entry == null || entry.studentId != state.studentId) {
      return;
    }
    final current = state.current;
    final targets = state.targets;
    widget.onAddToPlan(
      PlanningStudentSeed(
        handoffId:
            'growth-calculator-${state.studentId}-${DateTime.now().microsecondsSinceEpoch}',
        studentId: state.studentId,
        metadata: entry.metadata,
        currentValues: _selectedState?.values ?? const {},
        owned: _selectedState != null,
        targets: {
          for (final target in targets.entries)
            if (target.value > (current[target.key] ?? target.value))
              target.key: target.value,
        },
      ),
    );
  }

  /// S4 "최근 계산"을 누르면 그때의 학생·기준·목표로 다시 연다(FD-170). catalog에 없는 학생은 무시한다.
  void _openRecentCalculation(GrowthCalculationRecord record) {
    if (!_catalog.any((student) => student.studentId == record.studentId)) {
      return;
    }
    setState(() => _select(record.studentId));
    _syncEditors();
    _openCalculator(record: record);
  }

  void _scheduleCalculation() {
    final state = _calculator;
    final engine = _calculatorEngine;
    if (state == null || engine == null) return;
    engine.schedule(
      GrowthCalculatorRequest.fromState(
        state,
        repository: _repositoryState,
        activePlan: _activePlan,
      ),
    );
  }

  void _calculatorEngineChanged() {
    final state = _calculator;
    if (state != null && _calculatorEngine?.status is GrowthCalculatorReady) {
      _recentCalculations.add(state.record);
    }
  }

  /// 학생을 고른다. 고른 학생은 최근 본 학생 맨 앞에 온다(FD-061).
  void _select(String? studentId) {
    _selectedId = studentId;
    if (studentId != null) _recent.visit(studentId);
  }

  @override
  void dispose() {
    _warmupRequest += 1;
    KitOverlayEscape.remove(this);
    widget.headerOverride?.release(this);
    _calculator?.removeListener(_calculatorChanged);
    _calculator?.dispose();
    _calculatorEngine?.removeListener(_calculatorEngineChanged);
    _calculatorEngine?.dispose();
    _recentCalculations.removeListener(_stateChanged);
    _recentCalculations.dispose();
    widget.service.state.removeListener(_connectionChanged);
    _filter.removeListener(_stateChanged);
    _ownFilter?.dispose();
    _recent.removeListener(_stateChanged);
    _ownRecent?.dispose();
    _search.dispose();
    for (final editor in _editors.values) {
      editor.dispose();
    }
    super.dispose();
  }

  void _connectionChanged() {
    if (widget.service.state.value.connection == BackendConnection.connected &&
        _catalog.isEmpty &&
        !_loading) {
      _loadCatalog();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCatalog() async {
    if (widget.service.state.value.connection != BackendConnection.connected) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'Backend is disconnected.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final catalog = await widget.service.listStudents();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        if (_selectedId == null && catalog.isNotEmpty) {
          _select(catalog.first.studentId);
        }
        _loading = false;
      });
      _syncEditors();
      if (!widget.active) _scheduleGridWarmup(catalog);
      await _loadSelectedProfile();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'Could not load students: $error';
        });
      }
    }
  }

  void _scheduleGridWarmup(List<StudentCatalogEntry> catalog) {
    final request = ++_warmupRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || request != _warmupRequest || widget.active) return;
      await StudentGridImageWarmup.shared.warm(context, catalog);
    });
  }

  Future<void> _loadSelectedProfile() async {
    final repository = _repository;
    if (repository == null) return;
    final profiles = await repository.listProfiles();
    if (!mounted || profiles.isEmpty) return;
    final profile = profiles.firstWhere(
      (item) => item.selected,
      orElse: () => profiles.first,
    );
    await _selectProfile(profile);
  }

  Future<void> _selectProfile(RepositoryProfile profile) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      // FE4-h: 활성 계획은 저장 문서(plan.get)다. state와 같은 revision으로 읽는다(레거시 첫 읽기의 이관
      // revision도 state에 반영된다). 계획을 못 읽으면 상태만 읽고 계획은 모름(null)이다.
      RepositoryState state;
      PlanningDocument? activePlan;
      try {
        final snapshot = await loadRepositoryPlanSnapshot(
          repository,
          profile.id,
        );
        state = snapshot.state;
        activePlan = snapshot.document;
      } on Object {
        state = await repository.loadRepositoryState(profile.id);
        activePlan = null;
      }
      if (!mounted) return;
      final known = _catalog.map((student) => student.studentId).toSet();
      final fallback = state.students
          .where((student) => !known.contains(student.studentId))
          .map((student) => StudentCatalogEntry.fallback(student.studentId));
      _recentCalculations.syncProfile(profile.id);
      setState(() {
        _profile = profile;
        _repositoryState = state;
        _activePlan = activePlan;
        _catalog = [..._catalog, ...fallback];
        if (_selectedId == null && _catalog.isNotEmpty) {
          _select(_catalog.first.studentId);
        }
        _message = null;
      });
      _syncEditors();
      _refreshCalculatorCurrent();
      // 계정이 바뀌면 계산기 빠른 목표의 프리셋 항목도 그 계정 것으로 다시 읽는다.
      if (_calculator != null) _loadCalculatorPresets();
    } catch (error) {
      if (mounted) setState(() => _message = 'Could not load profile: $error');
    }
  }

  /// repository가 바뀌면(계정 다시 읽기·스캔 승인) 열린 계산기의 확정값을 맞춘다.
  void _refreshCalculatorCurrent() {
    final state = _calculator;
    final entry = _selectedEntry;
    if (state == null || entry == null || entry.studentId != state.studentId) {
      return;
    }
    state.updateConfirmedCurrent(_calculatorCurrent(entry));
    // 학생 값이 그대로여도 인벤토리(보유·부족)는 바뀌었을 수 있다.
    _scheduleCalculation();
  }

  Future<void> _reloadProfile() async {
    final profile = _profile;
    if (profile != null) await _selectProfile(profile);
  }

  ConfirmedStudentState? get _selectedState {
    final id = _selectedId;
    if (id == null) return null;
    for (final student
        in _repositoryState?.students ?? const <ConfirmedStudentState>[]) {
      if (student.studentId == id) return student;
    }
    return null;
  }

  StudentCatalogEntry? get _selectedEntry {
    final id = _selectedId;
    for (final student in _catalog) {
      if (student.studentId == id) return student;
    }
    return null;
  }

  void _syncEditors() {
    final values = _selectedState?.values ?? _defaultValues;
    for (final field in _studentFields) {
      final editor = _editors.putIfAbsent(
        field.name,
        TextEditingController.new,
      );
      editor.text = (values[field.name] ?? field.minimum).toString();
    }
  }

  Future<void> _approveCandidate() async {
    final context = widget.candidateContext;
    final scanner = _scanner;
    final profile = _profile;
    final state = _repositoryState;
    if (context == null ||
        scanner == null ||
        profile == null ||
        state == null) {
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final approved = context.candidate.approved
          ? context.candidate
          : await scanner.reviewScannerCandidate(
              context.session,
              context.candidate,
              context.candidate.payload,
              approve: true,
              reason: 'approved_in_student_page',
            );
      final committed = await scanner.commitScannerCandidate(
        context.session,
        approved,
        profileId: profile.id,
        expectedRepositoryRevision: state.revision,
        idempotencyKey: 'candidate-${approved.id}-${approved.revision}',
      );
      if (!mounted) return;
      final refreshed = await _repository!.loadRepositoryState(profile.id);
      if (!mounted) return;
      setState(() {
        _repositoryState = refreshed;
        _message = 'Candidate committed at revision ${committed['revision']}.';
      });
      _syncEditors();
      _refreshCalculatorCurrent();
      widget.onCandidateCommitted?.call(context.candidate);
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Candidate was not committed: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (widget.service.state.value.connection != BackendConnection.connected) {
      return _StatusPane(
        message: _message ?? 'Backend is disconnected.',
        onRetry: _loadCatalog,
      );
    }
    if (_catalog.isEmpty) {
      return _StatusPane(
        message: _message ?? 'No students are available.',
        onRetry: _loadCatalog,
      );
    }
    final owned =
        (_repositoryState?.students ?? const <ConfirmedStudentState>[])
            .map((student) => student.studentId)
            .toSet();
    final visible = _catalog
        .where((student) => student.matches(_search.text))
        .toList(growable: false);
    final studentValuesById = {
      for (final student
          in _repositoryState?.students ?? const <ConfirmedStudentState>[])
        student.studentId: student.values,
    };
    final candidate = widget.candidateContext;
    final catalogById = {
      for (final student in _catalog) student.studentId: student,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        const pagePadding = EdgeInsets.all(AppSpacing.md);
        final availableCanvasHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - pagePadding.vertical
            : 590.0;
        return SingleChildScrollView(
          key: const ValueKey('student-page'),
          padding: pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: math.max(590, availableCanvasHeight),
                child: StudentSectionLayout(
                  students: visible,
                  ownedIds: owned,
                  selectedId: _selectedId,
                  selectedStudent: _selectedEntry,
                  selectedValues: _selectedState?.values,
                  studentValuesById: studentValuesById,
                  plannedIds: activePlanStudentIds(_activePlan),
                  selectedBondTarget: activePlanBondTarget(
                    _activePlan,
                    _selectedId,
                  ),
                  filterController: _filter,
                  totalStudentCount: _catalog.length,
                  recentStudents: [
                    for (final id in _recent.ids) ?catalogById[id],
                  ],
                  active: widget.active,
                  restrictedIds: _restrictedIds,
                  restrictionLabel: _restriction?.label,
                  onClearRestriction: _clearRestriction,
                  searchController: _search,
                  onSearchChanged: (_) => setState(() {}),
                  onStudentSelected: (studentId) {
                    setState(() => _select(studentId));
                    _syncEditors();
                    // 계산기가 열려 있으면 고른 학생으로 다시 연다.
                    if (_calculator != null) _openCalculator();
                  },
                  onAddToPlan: null,
                  onOpenScan: widget.onOpenScan,
                  onOpenFilter: () {},
                  onOpenCalculator: _openCalculator,
                  calculator: switch (_calculator) {
                    final state? => GrowthCalculatorModeData(
                      state: state,
                      engine: _calculatorEngine,
                      student: _selectedEntry,
                      onOpenScan: widget.onOpenScan,
                      onAddToPlan: _addCalculatorToPlan,
                      onOpenInventory: _openInventory,
                      planMembership: growthCalculatorPlanMembership(
                        _activePlan,
                        state.studentId,
                      ),
                      recent: [
                        for (final record in _recentCalculations.records)
                          if (catalogById[record.studentId] case final entry?)
                            (record: record, student: entry),
                      ],
                      onOpenRecent: _openRecentCalculation,
                      presetTargets: _calculatorPresets,
                    ),
                    null => null,
                  },
                ),
              ),
              // 필터 모달이 열려 있는 동안 학생 탭의 나머지 내용도 의미 구조에서 뺀다(FE3-d2, 15:51 결정 4).
              BaModalBackdropExclude(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (visible.any((student) => student.school == null))
                      const Text(
                        'metadata unavailable',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    if (candidate != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      DiagonalSection(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Delivered scan candidate',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                'Candidate ${candidate.candidate.id} · revision ${candidate.candidate.revision}',
                              ),
                              Text(
                                'Confirmed: ${_selectedState?.values ?? const <String, dynamic>{}}',
                              ),
                              Text(
                                'Candidate: ${candidate.candidate.payload['values'] ?? candidate.candidate.payload}',
                              ),
                              Text(
                                'Review required: ${candidate.candidate.reviewRequired}',
                              ),
                              ...candidate.candidate.evidence.map(
                                (evidence) => Text(
                                  '${evidence.field}: ${evidence.status} (${evidence.source}, confidence ${evidence.confidence?.toStringAsFixed(2) ?? 'n/a'})',
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.sm,
                                children: [
                                  FilledButton(
                                    key: const ValueKey('candidate-approve'),
                                    onPressed: _saving ? null : _approveCandidate,
                                    child: const Text('Approve and commit'),
                                  ),
                                  OutlinedButton(
                                    key: const ValueKey('candidate-hold'),
                                    onPressed: () => setState(
                                      () => _message =
                                          'Candidate kept for later review; repository unchanged.',
                                    ),
                                    child: const Text('Hold'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _message!,
                                key: const ValueKey('student-message'),
                              ),
                            ),
                            if (_profile != null)
                              TextButton(
                                key: const ValueKey('student-reload-profile'),
                                onPressed: _saving ? null : _reloadProfile,
                                child: const Text('Reload profile'),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusPane extends StatelessWidget {
  const _StatusPane({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _StudentField {
  const _StudentField(this.name, this.label, this.minimum, this.maximum);
  final String name;
  final String label;
  final int minimum;
  final int maximum;
}

const _studentFields = <_StudentField>[
  _StudentField('level', 'Level', 1, 90),
  _StudentField('bond_rank', 'Bond rank', 1, 100),
  _StudentField('student_star', 'Stars', 1, 5),
  _StudentField('weapon_level', 'Weapon level', 0, 60),
  _StudentField('weapon_star', 'Weapon stars', 0, 4),
  _StudentField('ex_skill', 'EX skill', 1, 5),
  _StudentField('skill1', 'Skill 1', 1, 10),
  _StudentField('skill2', 'Skill 2', 1, 10),
  _StudentField('skill3', 'Skill 3', 1, 10),
  _StudentField('equip1_level', 'Equipment 1', 1, 70),
  _StudentField('equip2_level', 'Equipment 2', 1, 70),
  _StudentField('equip3_level', 'Equipment 3', 1, 70),
  _StudentField('stat_hp', 'HP stat', 0, 25),
  _StudentField('stat_atk', 'ATK stat', 0, 25),
  _StudentField('stat_heal', 'Heal stat', 0, 25),
];

const _defaultValues = <String, dynamic>{
  'level': 1,
  'bond_rank': 1,
  'student_star': 1,
  'weapon_state': 'weapon_locked',
  'weapon_star': 0,
  'weapon_level': 0,
  'ex_skill': 1,
  'skill1': 1,
  'skill2': 1,
  'skill3': 1,
  'equip1': 'T1',
  'equip2': 'T1',
  'equip3': 'T1',
  'equip4': null,
  'equip1_level': 1,
  'equip2_level': 1,
  'equip3_level': 1,
  'stat_hp': 0,
  'stat_atk': 0,
  'stat_heal': 0,
};
