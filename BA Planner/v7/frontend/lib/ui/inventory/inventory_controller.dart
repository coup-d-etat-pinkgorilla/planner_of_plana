// 인벤토리 화면 컨트롤러(FE6-a). 옛 `_InventoryPageState`의 로드·편집·저장·부족 계산·후보 승인을 옮겼다.
//
// 로드 순서: 카탈로그(`listInventoryItems`) → 선택된 계정(`listProfiles`의 selected) → 활성 계획(`loadRepositoryPlan`,
// 목표 v1만 있던 계정은 이때 문서로 옮겨져 revision이 오를 수 있다) → 저장된 상태(`loadRepositoryState`, 저장 기준
// revision) → 학생 이름(`listStudents`, 실패해도 계속) → 저장된 목표가 있으면 부족 계산(`calculateShortages`)과 활성
// 문서 계산(`calculatePlanningDocument`, FD-101 사용 학생). 늦게 온 응답은 세대 번호로 버린다.
//
// 분석 모드(FE6-c): "목록 · 분석" seg, 분석 사이드바 강조, S2 티어 토글, S4 종류·표시, S5 기간을 들고, 집계
// (`inventory_analysis.dart`)는 보드·사용 단계가 바뀔 때만 다시 센다.
//
// 티어별 충족률(FE6-e): 분석 모드 안의 "따로 여는 화면"이다([tiersOpen]). 사이드바 버튼을 다시 누르거나, 분석 버튼
// 4개 중 하나(그 섹션을 강조한 채 분석으로) · "목록"을 누르면 닫힌다. T1 · T2 · T4 표시 칩은 표마다 따로 든다. 집계
// (`inventory_tiers.dart`)도 같은 메모 규칙이다.
//
// 재화 읽기 전용(fb3-dart, FB-3 `currency_read_only`):
// - 재화 키(credits·엘리그마)는 draft·dirty가 되지 않는다([setDraft]·[beginEdit]가 거절한다).
// - 저장 wire는 재화 항목을 저장된 map 그대로(이름·메타 포함) 두고, 없는 재화는 만들지 않으며 null을 '0'으로 바꾸지
//   않는다. 고치지 않은 재료 항목도 통째로 둔다.
// - 백엔드·Mock이 `invalid_payload` + `reason=currency_read_only`로 거부하면 draft를 지우지 않고 그 사유를 알린다.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/app_service.dart';
import '../../services/planning_protocol_client.dart' show BackendRemoteException;
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import 'inventory_analysis.dart';
import 'inventory_tiers.dart';
import 'inventory_view_model.dart';

/// 스캔 탭이 인벤토리로 넘긴 후보(FE8-g5 전까지 인벤토리에서 승인한다).
class InventoryCandidateContext {
  const InventoryCandidateContext({
    required this.session,
    required this.candidate,
  });
  final ScannerSession session;
  final ScannerCandidate candidate;
}

/// 화면 위 알림 줄의 색.
enum InventoryMessageTone { info, warning }

/// 저장이 재화 읽기 전용으로 거부되었을 때의 오류 사유.
const inventoryCurrencyReadOnlyReason = 'currency_read_only';

/// [error]가 재화 읽기 전용 거부(`invalid_payload` + `reason=currency_read_only`)인가.
bool inventoryIsCurrencyReadOnlyError(Object error) =>
    error is BackendRemoteException &&
    error.code == 'invalid_payload' &&
    error.details?['reason'] == inventoryCurrencyReadOnlyReason;

class InventoryController extends ChangeNotifier {
  InventoryController(this.service);

  final AppService service;

  List<InventoryCatalogEntry> _catalog = const [];
  String? _catalogRevision;
  RepositoryProfile? _profile;
  RepositoryState? _state;
  RepositoryPlanState? _plan;
  Object? _planError;
  InventoryShortageResult? _shortages;
  Map<String, List<InventoryStageUse>> _uses = const {};
  Map<String, String> _studentNames = const {};
  InventoryBoard _board = InventoryBoard.build(
    catalog: const [],
    inventory: null,
    shortages: null,
  );

  bool _loading = false;
  bool _loaded = false;
  bool _disconnected = false;
  bool _saving = false;
  String? _catalogError;
  String? _profileError;
  String? _shortageError;
  String? _usesError;
  bool _usesAvailable = false;
  String? _message;
  InventoryMessageTone _messageTone = InventoryMessageTone.info;
  String? _lastSaveErrorReason;

  InventoryScreenMode _screenMode = InventoryScreenMode.list;
  InventoryAnalysisFocus? _analysisFocus;
  InventoryHeatmapKind _heatmapKind = InventoryHeatmapKind.blueprint;
  InventoryHeatmapValue _heatmapValue = InventoryHeatmapValue.fulfillment;
  final Set<int> _oopartTiers = {1, 2, 3, 4};
  InventoryChangeWindow _changeWindow = InventoryChangeWindow.week1;
  bool _tiersOpen = false;
  final Map<InventoryHeatmapKind, InventoryHeatmapValue> _tierValues = {};

  // 분석 집계 메모(보드·사용 단계가 바뀌면 다시 센다).
  InventoryBoard? _analysisBoard;
  Map<String, List<InventoryStageUse>>? _analysisUses;
  List<InventorySchoolRow>? _schoolRows;
  InventoryOopartAnalysis? _oopartAnalysis;
  final Map<InventoryHeatmapKind, InventoryHeatmap> _heatmaps = {};
  InventoryTiersAnalysis? _tiersAnalysis;

  InventoryListMode _mode = InventoryListMode.items;
  InventoryView _view = InventoryView.shortage;
  String? _category;
  InventorySort _sort = InventorySort.risk;
  bool _plannedOnly = false;
  bool _hideZero = false;
  String? _selectedKey;
  String? _editingKey;

  final Map<String, String> _drafts = {};
  final Set<String> _dirtyKeys = {};
  final Map<String, InventoryAcquisition> _acquisitions = {};
  int _generation = 0;
  bool _disposed = false;

  // --- 읽기 -----------------------------------------------------------------

  List<InventoryCatalogEntry> get catalog => _catalog;
  String? get catalogRevision => _catalogRevision;
  RepositoryProfile? get profile => _profile;
  RepositoryState? get repositoryState => _state;
  InventoryShortageResult? get shortages => _shortages;
  InventoryBoard get board => _board;

  bool get loading => _loading;

  /// 첫 로드가 끝났다(성공·실패 무관).
  bool get loaded => _loaded;
  bool get disconnected => _disconnected;
  bool get saving => _saving;
  String? get catalogError => _catalogError;

  /// 계정을 고르지 못했거나 저장된 상태를 읽지 못했다.
  String? get profileError => _profileError;
  String? get shortageError => _shortageError;

  /// 활성 계획 문서 계산(사용 학생)을 읽지 못했다.
  String? get usesError => _usesError;

  /// 활성 계획 문서 계산을 읽었다(사용 학생 목록을 믿을 수 있다).
  bool get usesAvailable => _usesAvailable;
  String? get message => _message;
  InventoryMessageTone get messageTone => _messageTone;

  /// 마지막 저장 실패 사유(`currency_read_only` 등). 성공하면 null.
  String? get lastSaveErrorReason => _lastSaveErrorReason;

  /// 저장된 목표가 있는가(부족 계산을 부를 수 있는가).
  bool get hasPlan => _state?.goals.isNotEmpty ?? false;

  /// 사이드바 최상단 "목록 · 분석"(FE6-c).
  InventoryScreenMode get screenMode => _screenMode;

  /// 분석 사이드바에서 고른(강조할) 섹션. 없으면 null.
  InventoryAnalysisFocus? get analysisFocus => _analysisFocus;
  InventoryHeatmapKind get heatmapKind => _heatmapKind;
  InventoryHeatmapValue get heatmapValue => _heatmapValue;

  /// S2 산점도에 보이는 오파츠 티어.
  Set<int> get oopartTiers => Set.unmodifiable(_oopartTiers);
  InventoryChangeWindow get changeWindow => _changeWindow;

  /// 티어별 충족률 화면이 열려 있다(분석 모드 안, FE6-e).
  bool get tiersOpen => _screenMode == InventoryScreenMode.analysis && _tiersOpen;

  /// 티어 화면 표([kind] = 기술 노트 · BD · 오파츠)의 표시 칩.
  InventoryHeatmapValue tierValue(InventoryHeatmapKind kind) =>
      _tierValues[kind] ?? InventoryHeatmapValue.fulfillment;

  void _syncAnalysis() {
    if (identical(_analysisBoard, _board) && identical(_analysisUses, _uses)) {
      return;
    }
    _analysisBoard = _board;
    _analysisUses = _uses;
    _schoolRows = null;
    _oopartAnalysis = null;
    _heatmaps.clear();
    _tiersAnalysis = null;
  }

  /// S1 학교 행(FD-099 활성 계획이 쓰는 학교만).
  List<InventorySchoolRow> get schoolRows {
    _syncAnalysis();
    return _schoolRows ??= inventorySchoolRows(
      _board,
      _uses,
      studentName: studentName,
    );
  }

  /// S2 오파츠 산점도 값.
  InventoryOopartAnalysis get oopartAnalysis {
    _syncAnalysis();
    return _oopartAnalysis ??= inventoryOopartAnalysis(_board, _uses);
  }

  /// 티어별 충족률 화면 값(FD-099 Tiers: 카탈로그 전부).
  InventoryTiersAnalysis get tiersAnalysis {
    _syncAnalysis();
    return _tiersAnalysis ??= inventoryTiersAnalysis(_board, _uses);
  }

  /// S4 지금 종류의 히트맵.
  InventoryHeatmap get heatmap {
    _syncAnalysis();
    return _heatmaps[_heatmapKind] ??= inventoryHeatmap(
      _board,
      _uses,
      _heatmapKind,
    );
  }

  InventoryListMode get mode => _mode;
  InventoryView get view => _view;
  String? get category => _category;
  InventorySort get sort => _sort;

  /// 전체 아이템 칩 "계획에 쓰는 것만".
  bool get plannedOnly => _plannedOnly;

  /// 전체 아이템 칩 "보유 0 숨기기".
  bool get hideZero => _hideZero;
  String? get selectedKey => _selectedKey;
  String? get editingKey => _editingKey;
  Set<String> get dirtyKeys => Set.unmodifiable(_dirtyKeys);

  RepositoryService? get _repository => service is RepositoryService
      ? service as RepositoryService
      : null;
  RepositoryPlanService? get _planService => service is RepositoryPlanService
      ? service as RepositoryPlanService
      : null;
  ScannerService? get _scanner =>
      service is ScannerService ? service as ScannerService : null;

  /// 지금 목록. 부족한 것 보기는 위험도 행(정렬됨), 전체 보기는 타일 그룹을 이은 순서다.
  List<InventoryItemView> get visible => _view == InventoryView.all
      ? [for (final group in tileGroups) ...group.items]
      : _board.visible(
          mode: _mode,
          view: _view,
          category: _category,
          sort: _sort,
        );

  /// 전체 아이템 타일 그룹(FE6-b).
  List<InventoryTileGroup> get tileGroups => _board.tileGroups(
    mode: _mode,
    category: _category,
    plannedOnly: _plannedOnly,
    hideZero: _hideZero,
  );

  /// 상세가 보이는 품목.
  InventoryItemView? get selected {
    final key = _selectedKey;
    return key == null ? null : _board[key];
  }

  /// [key] 재화를 쓰는 단계(문서 순서). 없으면 빈 목록.
  List<InventoryStageUse> usesFor(String key) =>
      _uses[key] ?? const <InventoryStageUse>[];

  /// 학생 이름(카탈로그 표시 이름, 모르면 id).
  String studentName(String studentId) =>
      _studentNames[studentId] ?? studentId;

  /// 편집 칸에 보일 값: draft가 있으면 draft, 없으면 저장된 수량(모르면 빈 칸).
  String draftFor(String key) => _drafts[key] ?? _board[key]?.quantity ?? '';

  /// 수량을 고칠 수 있는가(재화 아님 · 계정 상태 있음 · 저장 중 아님).
  bool canEdit(String key) {
    final view = _board[key];
    return view != null &&
        !view.isCurrency &&
        view.item.profileId != 'missing_catalog' &&
        _state != null &&
        !_saving;
  }

  // --- 로드 -----------------------------------------------------------------

  /// 카탈로그·계정 상태·부족 계산·문서 계산을 다시 읽는다. 보기 상태와 선택은 그대로 둔다.
  Future<void> load() async {
    final generation = ++_generation;
    if (service.state.value.connection != BackendConnection.connected) {
      _disconnected = true;
      _loading = false;
      _loaded = true;
      _notify();
      return;
    }
    _disconnected = false;
    _loading = true;
    _catalogError = null;
    _profileError = null;
    _shortageError = null;
    // 계정을 못 고르거나 상태를 못 읽으면 이전 계정의 계산이 남지 않게 먼저 비운다.
    _shortages = null;
    _uses = const {};
    _usesAvailable = false;
    _usesError = null;
    _notify();

    try {
      final catalog = await service.listInventoryItems();
      if (!_current(generation)) return;
      _catalog = catalog.items;
      _catalogRevision = catalog.catalogRevision;
    } catch (error) {
      if (!_current(generation)) return;
      _catalogError = '인벤토리 목록을 불러오지 못했습니다: $error';
      _finishLoad();
      return;
    }

    final repository = _repository;
    if (repository == null) {
      _profileError = '계정 저장소에 연결할 수 없습니다.';
      _finishLoad();
      return;
    }
    try {
      final profiles = await repository.listProfiles();
      if (!_current(generation)) return;
      final selected = profiles.where((profile) => profile.selected).toList();
      if (selected.isEmpty) {
        _profile = null;
        _state = null;
        _profileError = '선택된 계정이 없습니다. 설정에서 계정을 고르면 인벤토리가 보입니다.';
        _finishLoad();
        return;
      }
      final profile = selected.first;
      // 활성 계획을 먼저 읽는다. 목표 v1만 있는 계정은 이 읽기에서 문서로 옮겨지며 revision이 오를 수 있으므로,
      // 저장 기준 revision은 그 뒤에 읽은 상태의 것이어야 한다.
      _plan = null;
      _planError = null;
      final plans = _planService;
      if (plans != null) {
        try {
          final plan = await plans.loadRepositoryPlan(profile.id);
          if (!_current(generation)) return;
          _plan = plan;
        } catch (error) {
          if (!_current(generation)) return;
          _planError = error;
        }
      }
      final state = await repository.loadRepositoryState(profile.id);
      if (!_current(generation)) return;
      _profile = profile;
      _state = state;
    } catch (error) {
      if (!_current(generation)) return;
      _profileError = '계정 상태를 불러오지 못했습니다: $error';
      _finishLoad();
      return;
    }

    try {
      final students = await service.listStudents();
      if (!_current(generation)) return;
      _studentNames = {
        for (final student in students) student.studentId: student.displayName,
      };
    } catch (_) {
      // 이름이 없으면 학생 id로 보인다.
    }

    await _calculate(generation);
    if (!_current(generation)) return;
    _finishLoad();
  }

  /// 부족 계산(목표 v1)과 활성 문서 계산(사용 학생). 실패는 각자 알리고 나머지는 계속한다.
  Future<void> _calculate(int generation) async {
    final state = _state;
    _shortages = null;
    _uses = const {};
    _usesAvailable = false;
    _usesError = null;
    if (state == null || state.goals.isEmpty) return;
    final currentStudents = [
      for (final student in state.students)
        confirmedStudentPlanningCurrent(student),
    ];
    try {
      final result = await service.calculateShortages(
        currentStudents: currentStudents,
        plan: {
          'version': 1,
          'goals': [
            for (final goal in state.goals)
              Map<String, dynamic>.from(goal.values),
          ],
        },
        inventory: state.inventory.toWire(),
      );
      if (!_current(generation)) return;
      _shortages = result;
    } catch (error) {
      if (!_current(generation)) return;
      _shortageError = '부족 재화를 계산하지 못했습니다: $error';
    }

    final AppService current = service;
    final PlanningDocumentService? calculator =
        current is PlanningDocumentService
        ? current as PlanningDocumentService
        : null;
    final plan = _plan;
    if (calculator == null || _planService == null) return;
    if (plan == null) {
      _usesError = '활성 계획을 읽지 못했습니다: $_planError';
      return;
    }
    try {
      final projection = await calculator.calculatePlanningDocument(
        currentStudents: currentStudents,
        inventory: state.inventory.toWire(),
        document: plan.document.toWire(),
      );
      if (!_current(generation)) return;
      _uses = inventoryStageUses(projection, plan.document);
      _usesAvailable = true;
    } catch (error) {
      if (!_current(generation)) return;
      _usesError = '활성 계획의 단계별 필요량을 읽지 못했습니다: $error';
    }
  }

  void _finishLoad() {
    _loading = false;
    _loaded = true;
    _rebuildBoard();
    _notify();
  }

  void _rebuildBoard() {
    _board = InventoryBoard.build(
      catalog: _catalog,
      inventory: _state?.inventory,
      shortages: _shortages,
    );
    _ensureSelection();
  }

  /// 선택이 없거나 지금 목록·재화 카드에 없으면 목록 첫 행을 고른다.
  void _ensureSelection() {
    final key = _selectedKey;
    final visible = this.visible;
    final stillShown =
        key != null &&
        (visible.any((view) => view.key == key) ||
            (_board[key]?.isCurrency ?? false));
    if (stillShown) return;
    _selectedKey = visible.isEmpty ? null : visible.first.key;
    if (_editingKey != _selectedKey) _closeEditor();
  }

  /// 편집 칸을 닫고 그 품목의 저장하지 않은 draft를 버린다(다른 품목 저장 때 몰래 함께 저장되지 않게).
  void _closeEditor() {
    final key = _editingKey;
    if (key == null) return;
    _drafts.remove(key);
    _dirtyKeys.remove(key);
    _editingKey = null;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  // --- 보기 -----------------------------------------------------------------

  /// "목록 · 분석". 목록 보기 상태(모드 · 종류 · 선택)는 그대로 둔다. 목록으로 가면 티어 화면은 닫힌다.
  void setScreenMode(InventoryScreenMode mode) {
    if (_screenMode == mode) return;
    _screenMode = mode;
    if (mode == InventoryScreenMode.list) _tiersOpen = false;
    _notify();
  }

  /// "이 화면에 보이는 분석" 버튼: 그 섹션을 강조한다. 같은 버튼을 다시 누르면 강조를 푼다. 장비 설계도는 S4를
  /// 설계도 보기로 돌린다. 티어 화면에서 누르면 분석으로 돌아가며 그 섹션을 강조한다(다시 눌러 푸는 것은 분석에서).
  void toggleAnalysisFocus(InventoryAnalysisFocus focus) {
    if (_tiersOpen) {
      _tiersOpen = false;
      _analysisFocus = focus;
    } else {
      _analysisFocus = _analysisFocus == focus ? null : focus;
    }
    if (_analysisFocus == InventoryAnalysisFocus.blueprints) {
      _heatmapKind = InventoryHeatmapKind.blueprint;
    }
    _notify();
  }

  /// 사이드바 "따로 여는 화면 → 티어별 충족률": 분석 모드에서 티어 화면을 열고, 열려 있으면 닫는다.
  void toggleTiers() {
    if (_screenMode != InventoryScreenMode.analysis) return;
    _tiersOpen = !_tiersOpen;
    _notify();
  }

  /// 티어 화면 표 하나의 표시 칩.
  void setTierValue(InventoryHeatmapKind kind, InventoryHeatmapValue value) {
    if (tierValue(kind) == value) return;
    _tierValues[kind] = value;
    _notify();
  }

  void setHeatmapKind(InventoryHeatmapKind kind) {
    if (_heatmapKind == kind) return;
    _heatmapKind = kind;
    _notify();
  }

  void setHeatmapValue(InventoryHeatmapValue value) {
    if (_heatmapValue == value) return;
    _heatmapValue = value;
    _notify();
  }

  /// S2 티어 토글. 켜진 티어를 끄고, 꺼진 티어를 켠다.
  void toggleOopartTier(int tier) {
    if (!_oopartTiers.remove(tier)) _oopartTiers.add(tier);
    _notify();
  }

  void setChangeWindow(InventoryChangeWindow window) {
    if (_changeWindow == window) return;
    _changeWindow = window;
    _notify();
  }

  void setMode(InventoryListMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _category = null;
    _ensureSelection();
    _notify();
  }

  void setView(InventoryView view) {
    if (_view == view) return;
    _view = view;
    _ensureSelection();
    _notify();
  }

  /// 종류 버튼. 고른 종류를 다시 누르면 종류 거르기를 푼다.
  void toggleCategory(String category) {
    _category = _category == category ? null : category;
    _ensureSelection();
    _notify();
  }

  /// 전체 아이템 "계획에 쓰는 것만" 칩.
  void togglePlannedOnly() {
    _plannedOnly = !_plannedOnly;
    _ensureSelection();
    _notify();
  }

  /// 전체 아이템 "보유 0 숨기기" 칩.
  void toggleHideZero() {
    _hideZero = !_hideZero;
    _ensureSelection();
    _notify();
  }

  /// 플라이아웃 "모두 보기": 그 종류의 부족한 것 보기로 간다.
  void showCategoryShortages(String category) {
    _view = InventoryView.shortage;
    _category = category;
    _ensureSelection();
    _notify();
  }

  void setSort(InventorySort sort) {
    if (_sort == sort) return;
    _sort = sort;
    _notify();
  }

  /// 목록 행이나 주요 재화 카드를 고른다.
  void select(String key) {
    if (_board[key] == null) return;
    if (_selectedKey != key) {
      _selectedKey = key;
      _closeEditor();
    }
    _notify();
  }

  // --- 편집 -----------------------------------------------------------------

  /// "수량 직접 고치기". 재화·카탈로그에 없는 품목은 거절한다.
  bool beginEdit(String key) {
    if (!canEdit(key)) return false;
    if (_editingKey != key) _closeEditor();
    _selectedKey = key;
    _editingKey = key;
    _notify();
    return true;
  }

  /// 편집을 닫고 그 품목의 draft를 버린다.
  void cancelEdit() {
    if (_editingKey == null) return;
    _closeEditor();
    _notify();
  }

  /// 편집 칸 값. 재화 키는 dirty가 되지 않는다(false).
  bool setDraft(String key, String text) {
    final view = _board[key];
    if (view == null || view.isCurrency) return false;
    _drafts[key] = text;
    _dirtyKeys.add(key);
    return true;
  }

  /// 저장할 인벤토리 bucket 전체(옛 `_inventoryWire`와 같은 규칙).
  ///
  /// - 카탈로그에 없는 저장 항목은 그대로 둔다.
  /// - 재화와 고치지 않은 품목은 저장된 map을 통째로 둔다(없으면 만들지 않는다).
  /// - 고친 품목은 빈 칸이면 뺀다(모름). 정규 정수가 아니면 [FormatException].
  Map<String, dynamic> inventoryWire() {
    final saved = _state?.inventory.entries ?? const <Map<String, dynamic>>[];
    final catalogKeys = _catalog.map((item) => item.resourceKey).toSet();
    final existingByKey = <String, Map<String, dynamic>>{
      for (final entry in saved)
        inventoryEntryIdentity(entry): Map<String, dynamic>.from(entry),
    };
    final entries = <Map<String, dynamic>>[
      for (final entry in saved)
        if (!catalogKeys.contains(inventoryEntryIdentity(entry)))
          Map<String, dynamic>.from(entry),
    ];
    for (final item in _catalog) {
      if (item.isReadOnlyCurrency || !_dirtyKeys.contains(item.resourceKey)) {
        final existing = existingByKey[item.resourceKey];
        if (existing != null) entries.add(existing);
        continue;
      }
      final quantity = (_drafts[item.resourceKey] ?? '').trim();
      if (quantity.isEmpty) continue;
      if (!inventoryCanonicalQuantity.hasMatch(quantity)) {
        throw FormatException(
          '${item.displayName}: 0 또는 0으로 시작하지 않는 양의 정수를 넣어야 합니다.',
        );
      }
      entries.add({
        'key': item.resourceKey,
        'quantity': quantity,
        'item_id': item.itemId,
        'name': item.displayName,
      });
    }
    return {
      'version': 1,
      'catalog_revision': ?_catalogRevision,
      'entries': entries,
    };
  }

  /// [key]의 수량을 [text]로 고쳐 저장한다("수량 직접 고치기").
  Future<bool> saveQuantity(String key, String text) async {
    if (!setDraft(key, text)) {
      _setMessage('재화 수량은 스캔으로만 바뀝니다.', InventoryMessageTone.warning);
      return false;
    }
    return save();
  }

  /// 고친 품목을 저장한다(bucket 전체, revision 확인). 실패하면 draft를 그대로 둔다.
  Future<bool> save() async {
    final repository = _repository;
    final profile = _profile;
    final state = _state;
    if (repository == null || profile == null || state == null) {
      _setMessage('계정을 먼저 골라야 저장할 수 있습니다.', InventoryMessageTone.warning);
      return false;
    }
    if (_saving) return false;
    final Map<String, dynamic> wire;
    try {
      wire = inventoryWire();
    } on FormatException catch (error) {
      _setMessage(error.message, InventoryMessageTone.warning);
      return false;
    }
    _saving = true;
    _message = null;
    _lastSaveErrorReason = null;
    _notify();
    try {
      final revision = await repository.saveRepositoryInventory(
        profile.id,
        RepositoryInventoryState.fromWire(wire),
        state.revision,
        'inventory-save-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (_disposed) return true;
      _drafts.clear();
      _dirtyKeys.clear();
      _editingKey = null;
      _saving = false;
      await load();
      _setMessage('저장했습니다(revision $revision).', InventoryMessageTone.info);
      return true;
    } catch (error) {
      if (_disposed) return false;
      _saving = false;
      if (inventoryIsCurrencyReadOnlyError(error)) {
        _lastSaveErrorReason = inventoryCurrencyReadOnlyReason;
        _setMessage(
          '재화(크레딧·엘리그마)는 스캔으로만 바뀌어 저장하지 않았습니다. 고친 수량은 그대로 남아 있습니다.',
          InventoryMessageTone.warning,
        );
      } else {
        _lastSaveErrorReason = error is BackendRemoteException
            ? error.code
            : 'save_failed';
        _setMessage(
          '저장하지 못했습니다. 고친 수량은 그대로 남아 있습니다. revision이 바뀌었으면 다시 읽은 뒤 저장합니다: $error',
          InventoryMessageTone.warning,
        );
      }
      return false;
    }
  }

  // --- 획득처 ---------------------------------------------------------------

  /// [key]의 획득처(FB-3). 처음 부르면 읽기를 시작하고 읽는 중 상태를 돌려준다.
  InventoryAcquisition acquisitionFor(String key) {
    final cached = _acquisitions[key];
    if (cached != null) return cached;
    if (service is! ResourceAcquisitionService) {
      return _acquisitions[key] = const InventoryAcquisition.unsupported();
    }
    _acquisitions[key] = const InventoryAcquisition.loading();
    unawaited(_fetchAcquisition(key));
    return _acquisitions[key]!;
  }

  /// 실패한 획득처를 다시 읽는다.
  void retryAcquisition(String key) {
    _acquisitions.remove(key);
    acquisitionFor(key);
    _notify();
  }

  Future<void> _fetchAcquisition(String key) async {
    // build 안에서 시작되므로 첫 결과(동기 예외 포함)를 다음 microtask로 미룬다.
    await Future<void>.microtask(() {});
    InventoryAcquisition next;
    try {
      final result = await service.getResourceAcquisition(key);
      next = InventoryAcquisition.loaded(result);
    } on UnsupportedError {
      next = const InventoryAcquisition.unsupported();
    } on BackendRemoteException catch (error) {
      next = error.code == 'resource_not_found'
          ? const InventoryAcquisition.notFound()
          : InventoryAcquisition.failed(error);
    } catch (error) {
      next = InventoryAcquisition.failed(error);
    }
    if (_disposed) return;
    _acquisitions[key] = next;
    _notify();
  }

  // --- 스캔 후보(FE8-g5 전까지) ----------------------------------------------

  /// 후보 보류: 저장소를 바꾸지 않는다.
  void holdCandidate() => _setMessage(
    '후보를 보류했습니다. 인벤토리는 바뀌지 않았습니다.',
    InventoryMessageTone.info,
  );

  /// 후보를 검토 승인하고 커밋한다. 실패하면 비교를 그대로 둔다.
  Future<bool> approveCandidate(InventoryCandidateContext context) async {
    final scanner = _scanner;
    final profile = _profile;
    final state = _state;
    if (scanner == null || profile == null || state == null || _saving) {
      return false;
    }
    _saving = true;
    _message = null;
    _notify();
    try {
      final approved =
          context.candidate.reviewRequired && !context.candidate.approved
          ? await scanner.reviewScannerCandidate(
              context.session,
              context.candidate,
              context.candidate.payload,
              approve: true,
              reason: 'approved_in_inventory_page',
            )
          : context.candidate;
      await scanner.commitScannerCandidate(
        context.session,
        approved,
        profileId: profile.id,
        expectedRepositoryRevision: state.revision,
        idempotencyKey:
            'inventory-candidate-${approved.id}-${approved.revision}',
      );
      if (_disposed) return true;
      _saving = false;
      await load();
      _setMessage('스캔 후보를 반영했습니다.', InventoryMessageTone.info);
      return true;
    } catch (error) {
      if (_disposed) return false;
      _saving = false;
      _setMessage(
        '후보를 반영하지 못했습니다. 비교는 그대로 남아 있습니다: $error',
        InventoryMessageTone.warning,
      );
      return false;
    }
  }

  // --- 공통 -----------------------------------------------------------------

  void _setMessage(String message, InventoryMessageTone tone) {
    _message = message;
    _messageTone = tone;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
