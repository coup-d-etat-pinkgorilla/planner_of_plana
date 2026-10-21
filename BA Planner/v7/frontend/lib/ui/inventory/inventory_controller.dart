// 인벤토리 화면 컨트롤러(FE6-a). 옛 `_InventoryPageState`의 로드·편집·저장·부족 계산을 옮겼다. 스캔 후보 승인은 스캔 탭
// 아이템 결과 검토 보드로 옮겼다(FE8-g5b).
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
// 오파츠 확장(FE6-d): S2 "확장"은 탭 안 로컬 상태([oopartExpanded], FD-103)다. 분석 모드 · 티어 화면이 아닐 때만 켜지고,
// 목록으로 가거나 티어 화면을 열면 접힌다. 고른 오파츠([selectOopart])는 확장 전후 그대로이고, 고르지 않았으면 병목 순위
// 1위가 기본이다(FD-103). 병목 순위 · 상세도 같은 메모 규칙이다.
//
// 재화 읽기 전용(fb3-dart, FB-3 `currency_read_only`):
// - 재화 키(credits·엘리그마)는 draft·dirty가 되지 않는다([setDraft]·[beginEdit]가 거절한다).
// - 저장 wire는 재화 항목을 저장된 map 그대로(이름·메타 포함) 두고, 없는 재화는 만들지 않으며 null을 '0'으로 바꾸지
//   않는다. 고치지 않은 재료 항목도 통째로 둔다.
// - 백엔드·Mock이 `invalid_payload` + `reason=currency_read_only`로 거부하면 draft를 지우지 않고 그 사유를 알린다.
//
// 확인 필요 표시(fb10b-dart, FB-10b · FD-146):
// - 상태(`loadRepositoryState`) 뒤 `loadRepositoryInventoryReview`를 읽고, revision이 다르면 둘 다 다시 읽는다. 표시는
//   그 행 key(정규 key)에만 매핑한다. `migration_required`·`corrupt_data`는 빈 표시로 바꾸지 않고 계정 오류로 알린다.
// - 직접 고치기 저장은 scope(`applied_resource_keys`) = 고친 key + "이 값이 맞습니다"로 확인한 key만 보낸다.
// - 응답 손실·저장소 바쁨·쓰기 실패 뒤 같은 내용을 다시 저장하면 원 revision·key·scope·bucket을 그대로 다시 보낸다.
//
// 이력(FE6-f, FB-2 · FD-041 · FD-042):
// - 로드가 끝난 뒤(보드를 먼저 그린 다음) 지금 − 28일 이력(`repository.history.events`, cursor 끝까지)과 카탈로그 재화의
//   마지막 스캔(`repository.history.scan_latest`, 256개씩)을 읽어 [InventoryHistory]를 만든다. 같은 계정 · 같은 revision이면
//   다시 읽지 않는다. 저장은 [load]를 다시 부르므로 revision이 바뀐 뒤 다시 읽는다.
// - 이력 응답의 revision이 읽은 상태와 다르면(사이에 쓰기) 이력을 버리고 다음 기회에 다시 읽는다(섞어 그리지 않는다).
// - 탭을 다시 열 때 [refreshIfChanged]가 `repository.history.summary`의 revision만 보고, 다르면(다른 탭의 스캔 commit 등)
//   [load]를 다시 부른다. 셸 시작 때(탭을 열기 전)는 아무것도 읽지 않는다(FE6-b).
// - "지금"은 서비스가 [AppClockSource]면 그 시각(검수 fixture · 테스트의 고정 시계), 아니면 기기 시계다(`services/app_clock.dart`).
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../services/app_clock.dart';
import '../../services/app_service.dart';
import '../../services/idempotency_keys.dart';
import '../../services/planning_protocol_client.dart'
    show BackendDisconnectedException, BackendRemoteException;
import '../../services/repository_service.dart';
import 'inventory_analysis.dart';
import 'inventory_history.dart';
import 'inventory_tiers.dart';
import 'inventory_view_model.dart';

/// 이력 events를 끝까지 읽을 때의 쪽 수 상한(200 × 50 = FB-2 보존 상한 10,000건).
const _historyMaxPages = 50;

/// 화면 위 알림 줄의 색.
enum InventoryMessageTone { info, warning }

/// 저장이 재화 읽기 전용으로 거부되었을 때의 오류 사유.
const inventoryCurrencyReadOnlyReason = 'currency_read_only';

/// [error]가 재화 읽기 전용 거부(`invalid_payload` + `reason=currency_read_only`)인가.
bool inventoryIsCurrencyReadOnlyError(Object error) =>
    error is BackendRemoteException &&
    error.code == 'invalid_payload' &&
    error.details?['reason'] == inventoryCurrencyReadOnlyReason;

/// 저장 scope 밖 수량 변경 거부의 오류 사유(FB-10b).
const inventoryScanScopeMismatchReason = 'scan_scope_mismatch';

/// 저장소 오류 코드(Process는 [BackendRemoteException], Mock은 [StateError] 메시지).
String? _repositoryErrorCode(Object error) => switch (error) {
  BackendRemoteException(:final code) => code,
  StateError(:final message) => message,
  _ => null,
};

/// 같은 요청(원 revision·key·scope)으로 다시 보내야 하는 저장 실패(응답 손실·저장소 바쁨·쓰기 실패).
bool inventorySaveRetryable(Object error) =>
    error is TimeoutException ||
    error is BackendDisconnectedException ||
    (error is BackendRemoteException && error.retryable) ||
    const {
      'repository_busy',
      'persistence_failed',
    }.contains(_repositoryErrorCode(error));

/// 확인 필요 표시를 읽지 못했을 때의 문구(빈 표시로 바꾸지 않는다).
String inventoryReviewLoadErrorText(Object error) =>
    switch (_repositoryErrorCode(error)) {
      'migration_required' =>
        '확인 필요 표시가 이 앱이 모르는 형식이라 인벤토리를 읽지 못했습니다. 원본은 그대로 두었습니다.',
      'corrupt_data' => '저장된 확인 필요 표시가 손상되어 인벤토리를 읽지 못했습니다. 원본은 그대로 두었습니다.',
      _ when error is _InventoryReviewRevisionMismatch =>
        '수량과 확인 필요 표시를 같은 시점으로 읽지 못했습니다. 잠시 뒤 다시 읽어 주십시오.',
      _ => '확인 필요 표시를 불러오지 못했습니다: $error',
    };

/// 수량과 확인 필요 표시의 revision이 다시 읽어도 계속 다르다.
class _InventoryReviewRevisionMismatch implements Exception {
  const _InventoryReviewRevisionMismatch();

  @override
  String toString() => 'inventory review revision mismatch';
}

/// 보낸 뒤 결과를 모르는 저장 요청. 같은 내용을 다시 저장하면 이 값을 그대로 보낸다.
typedef _InventorySaveRequest = ({
  String profileId,
  String signature,
  Map<String, dynamic> wire,
  List<String> applied,
  int expectedRevision,
  String idempotencyKey,
});

class InventoryController extends ChangeNotifier {
  InventoryController(
    this.service, {
    DateTime Function()? clock,
    this.practiceProfile,
  }) : _clock = clock ?? _serviceClock(service);

  final AppService service;

  /// 튜토리얼 임시 계정(일반 목록에 없다 — F3c-3). 있으면 고른 계정 대신 쓴다.
  final RepositoryProfile? Function()? practiceProfile;
  final DateTime Function() _clock;

  static DateTime Function() _serviceClock(AppService service) {
    if (service case final AppClockSource source) {
      return () => source.clockNow;
    }
    return DateTime.now;
  }

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
  bool _oopartExpanded = false;
  String? _selectedOopart;

  // 분석 집계 메모(보드·사용 단계가 바뀌면 다시 센다).
  InventoryBoard? _analysisBoard;
  Map<String, List<InventoryStageUse>>? _analysisUses;
  List<InventorySchoolRow>? _schoolRows;
  InventoryOopartAnalysis? _oopartAnalysis;
  final Map<InventoryHeatmapKind, InventoryHeatmap> _heatmaps = {};
  InventoryTiersAnalysis? _tiersAnalysis;
  List<InventoryOopartRank>? _oopartRanking;
  final Map<String, InventoryOopartDetail?> _oopartDetails = {};

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
  Set<String> _reviewKeys = const {};
  _InventorySaveRequest? _pendingSave;
  final Map<String, InventoryAcquisition> _acquisitions = {};
  int _generation = 0;
  bool _disposed = false;

  // 이력(FE6-f).
  InventoryHistory? _history;
  String? _historyProfileId;
  int? _historyRevision;
  bool _historyLoading = false;
  String? _historyError;

  // 이력 집계 메모(보드 · 이력이 바뀌면 다시 센다).
  InventoryBoard? _historyBoard;
  InventoryHistory? _historyMemo;
  InventoryKpiDeltas? _kpiDeltas;
  final Map<String, InventorySparkline> _sparklines = {};
  final Map<InventoryChangeWindow, InventoryNetChanges> _netChanges = {};
  List<InventoryForecast>? _forecasts;

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
    _oopartRanking = null;
    _oopartDetails.clear();
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

  /// S2 "확장"(FE6-d): 분석 모드에서 티어 화면이 닫혀 있을 때만 참이다.
  bool get oopartExpanded =>
      _screenMode == InventoryScreenMode.analysis && !_tiersOpen && _oopartExpanded;

  /// 상세 열 병목 순위(오파츠마다 가장 부족한 티어, 부족량 큰 순 5행).
  List<InventoryOopartRank> get oopartRanking {
    _syncAnalysis();
    return _oopartRanking ??= inventoryOopartRanking(oopartAnalysis);
  }

  /// 사용자가 고른 오파츠가 산점도에 있다(선택 표시는 이때만 그린다. 기본 선택은 상세 열에만 쓴다).
  bool get oopartSelectionExplicit {
    final selected = _selectedOopart;
    return selected != null &&
        oopartAnalysis.series.any((series) => series.family == selected);
  }

  /// 상세 열의 오파츠 family: 고른 것, 없거나 산점도에 없으면 병목 순위 1위(FD-103).
  String? get selectedOopartFamily => oopartSelectionExplicit
      ? _selectedOopart
      : inventoryDefaultOopartFamily(oopartAnalysis, oopartRanking);

  /// 상세 열 값. 고를 오파츠가 없으면 null.
  InventoryOopartDetail? get selectedOopartDetail {
    final family = selectedOopartFamily;
    if (family == null) return null;
    _syncAnalysis();
    return _oopartDetails.putIfAbsent(
      family,
      () => inventoryOopartDetail(
        _board,
        _uses,
        family,
        analysis: oopartAnalysis,
        studentName: studentName,
      ),
    );
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

  /// 읽은 이력(지금 − 28일). 아직 읽지 않았거나 읽지 못했으면 null.
  InventoryHistory? get history => _history;

  /// 이력을 읽는 중이다.
  bool get historyLoading => _historyLoading;

  /// 이력을 읽지 못한 이유(문구). 읽었거나 아직 읽지 않았으면 null.
  String? get historyError => _historyError;

  void _syncHistory() {
    if (identical(_historyBoard, _board) && identical(_historyMemo, _history)) {
      return;
    }
    _historyBoard = _board;
    _historyMemo = _history;
    _kpiDeltas = null;
    _sparklines.clear();
    _netChanges.clear();
    _forecasts = null;
  }

  /// KPI 띠 이력 값(FD-041). 이력이 없으면 모두 모름.
  InventoryKpiDeltas get kpiDeltas {
    _syncHistory();
    return _kpiDeltas ??= inventoryKpiDeltas(_history, _board);
  }

  /// [key] 재화의 상세 스파크라인. 이력이 없으면 null.
  InventorySparkline? sparklineFor(String key) {
    final history = _history;
    if (history == null) return null;
    _syncHistory();
    return _sparklines.putIfAbsent(key, () => inventorySparkline(history, key));
  }

  /// S5 지금 기간의 순증감 상위. 이력이 없으면 null.
  InventoryNetChanges? get netChanges {
    final history = _history;
    if (history == null) return null;
    _syncHistory();
    return _netChanges.putIfAbsent(
      _changeWindow,
      () => inventoryNetChanges(history, _board, _changeWindow),
    );
  }

  /// S5 "이 추세라면" 행(FD-042). 이력이 없으면 빈 목록.
  List<InventoryForecast> get forecasts {
    final history = _history;
    if (history == null) return const [];
    _syncHistory();
    return _forecasts ??= inventoryForecasts(history, _board);
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
  RepositoryInventoryReviewService? get _reviews =>
      service is RepositoryInventoryReviewService
      ? service as RepositoryInventoryReviewService
      : null;

  /// [key] 행에 확인 필요 표시가 있는가(FB-10b, 그 행 key만 정규 key로 비교한다).
  bool needsReview(String key) =>
      _reviewKeys.contains(historyCanonicalResourceKey(key));

  /// "이 값이 맞습니다"를 누를 수 있는가: 표시가 있고, 저장된 수량이 있으며(수량 없는 표시는 직접 고치기로 넣는다),
  /// 그 품목을 고치는 중이 아니고, 계정 상태가 있고, 저장 중이 아니다.
  bool canConfirmReview(String key) {
    final view = _board[key];
    return view != null &&
        view.present &&
        needsReview(key) &&
        _editingKey != key &&
        _state != null &&
        !_saving;
  }

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
    // 앞 로드의 이력 읽기는 세대가 바뀌어 버려진다. 새 로드가 이력을 다시 읽거나 지운다.
    _historyLoading = false;
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
      final practice = practiceProfile?.call();
      final selected = practice != null
          ? [practice]
          : profiles.where((profile) => profile.selected).toList();
      if (selected.isEmpty) {
        _profile = null;
        _state = null;
        _reviewKeys = const {};
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
      var state = await repository.loadRepositoryState(profile.id);
      if (!_current(generation)) return;
      // FB-10b: 확인 필요 표시는 수량과 같은 revision에서 읽는다. 다르면 둘 다 다시 읽는다(최대 2번 더).
      var reviewKeys = const <String>{};
      final reviews = _reviews;
      if (reviews != null) {
        try {
          var review = await reviews.loadRepositoryInventoryReview(profile.id);
          for (var attempt = 0; review.revision != state.revision; attempt++) {
            if (!_current(generation)) return;
            if (attempt >= 2) throw const _InventoryReviewRevisionMismatch();
            state = await repository.loadRepositoryState(profile.id);
            if (!_current(generation)) return;
            review = await reviews.loadRepositoryInventoryReview(profile.id);
          }
          if (!_current(generation)) return;
          reviewKeys = review.needsReviewKeys.toSet();
        } catch (error) {
          if (!_current(generation)) return;
          // 표시를 모르는 채로 수량만 보여 주거나 고치지 않는다.
          _profile = profile;
          _state = null;
          _reviewKeys = const {};
          _profileError = inventoryReviewLoadErrorText(error);
          _finishLoad();
          return;
        }
      }
      _profile = profile;
      _state = state;
      _reviewKeys = reviewKeys;
    } catch (error) {
      if (!_current(generation)) return;
      _reviewKeys = const {};
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
    await _loadHistory(generation);
  }

  /// 이력(지금 − 28일)과 마지막 스캔을 읽는다. 같은 계정 · 같은 revision이면 다시 읽지 않는다.
  Future<void> _loadHistory(int generation) async {
    final repository = _repository;
    final profile = _profile;
    final state = _state;
    if (repository == null || profile == null || state == null) {
      _clearHistory();
      _notify();
      return;
    }
    if (_history != null &&
        _historyProfileId == profile.id &&
        _historyRevision == state.revision) {
      return;
    }
    _historyLoading = true;
    _historyError = null;
    _notify();
    InventoryHistory? history;
    String? error;
    try {
      final now = _clock();
      final pages = <RepositoryHistoryEventsResult>[];
      var request = RepositoryHistoryEventsRequest(
        profileId: profile.id,
        fromAt: now.subtract(inventoryHistoryWindow),
        limit: inventoryHistoryPageLimit,
      );
      while (true) {
        final page = await repository.loadRepositoryHistoryEvents(request);
        if (!_current(generation)) return;
        pages.add(page);
        final cursor = page.nextCursor;
        if (cursor == null) break;
        if (pages.length >= _historyMaxPages) {
          throw StateError('history_too_large');
        }
        request = request.withCursor(cursor);
      }
      if (pages.first.revision != state.revision) {
        error = '수량이 바뀌는 사이에 읽어 이력을 맞추지 못했습니다. 탭을 다시 열면 다시 읽습니다.';
      } else {
        final keys = {
          for (final item in _catalog)
            historyCanonicalResourceKey(item.resourceKey),
        }.toList();
        final latest = <RepositoryHistoryScanLatestResult>[];
        for (
          var start = 0;
          start < keys.length;
          start += inventoryScanLatestChunk
        ) {
          final result = await repository.loadRepositoryHistoryScanLatest(
            RepositoryHistoryScanLatestRequest(
              profileId: profile.id,
              resourceKeys: keys.sublist(
                start,
                math.min(keys.length, start + inventoryScanLatestChunk),
              ),
            ),
          );
          if (!_current(generation)) return;
          latest.add(result);
        }
        history = InventoryHistory.build(
          inventoryHistoryInputFromQuery(
            now: now,
            inventory: state.inventory,
            pages: pages,
            lastScanAt: inventoryLastScanAt(latest),
          ),
        );
      }
    } on UnsupportedError {
      if (!_current(generation)) return;
      error = '이 연결은 변화 기록 조회를 지원하지 않습니다.';
    } catch (caught) {
      if (!_current(generation)) return;
      error = '변화 기록을 불러오지 못했습니다: $caught';
    }
    _history = history;
    _historyProfileId = history == null ? null : profile.id;
    _historyRevision = history == null ? null : state.revision;
    _historyError = error;
    _historyLoading = false;
    _notify();
  }

  void _clearHistory() {
    _history = null;
    _historyProfileId = null;
    _historyRevision = null;
    _historyLoading = false;
    _historyError = null;
  }

  /// 탭을 다시 열 때 부른다: 저장소 revision이 읽은 상태와 다르면(다른 탭의 스캔 commit 등) 다시 읽는다. 같으면 아무것도
  /// 다시 읽지 않는다(계산 0).
  Future<void> refreshIfChanged() async {
    if (_loading || _saving || !_loaded) return;
    final repository = _repository;
    final profile = _profile;
    final state = _state;
    if (repository == null || profile == null || state == null) return;
    final generation = _generation;
    try {
      final summary = await repository.loadRepositoryHistorySummary([
        profile.id,
      ]);
      if (!_current(generation) || _loading || _saving) return;
      final revision = summary.profiles
          .firstWhere((item) => item.profileId == profile.id)
          .revision;
      if (revision != state.revision) {
        await load();
      } else if (_history == null && !_historyLoading) {
        await _loadHistory(generation);
      }
    } catch (_) {
      // 읽지 못하면 다음 저장 · 활성화 때 다시 본다.
    }
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
    // 계정 상태를 못 읽었으면 이전 계정의 이력도 남기지 않는다.
    if (_state == null) _clearHistory();
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
    if (mode == InventoryScreenMode.list) {
      _tiersOpen = false;
      _oopartExpanded = false;
    }
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
    _oopartExpanded = false;
    _notify();
  }

  /// S2 "확장" · "축소"(FE6-d). 분석 모드이고 티어 화면이 닫혀 있을 때만 켠다.
  void setOopartExpanded(bool expanded) {
    if (expanded &&
        (_screenMode != InventoryScreenMode.analysis || _tiersOpen)) {
      return;
    }
    if (_oopartExpanded == expanded) return;
    _oopartExpanded = expanded;
    _notify();
  }

  /// 산점도 점(오파츠)을 고른다(확장 전후 모두, FD-103). 상세 열이 그 오파츠를 보인다.
  void selectOopart(String family) {
    if (_selectedOopart == family) return;
    _selectedOopart = family;
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

  /// 저장 scope(FB-10b `applied_resource_keys`): 고친 key 중 저장 전후 어느 쪽에든 항목이 있는 것 + "이 값이
  /// 맞습니다"로 확인한 [confirmed]. 고치지 않은 key의 표시는 건드리지 않는다.
  List<String> appliedResourceKeys(
    Map<String, dynamic> wire, {
    String? confirmed,
  }) {
    String identity(Object? entry) => historyCanonicalResourceKey(
      inventoryEntryIdentity(Map<String, dynamic>.from(entry as Map)),
    );
    final identities = {
      for (final entry in _state?.inventory.entries ?? const []) identity(entry),
      for (final entry in wire['entries'] as List) identity(entry),
    };
    final keys = {
      for (final key in _dirtyKeys) historyCanonicalResourceKey(key),
      if (confirmed != null) historyCanonicalResourceKey(confirmed),
    };
    return repositoryInventoryAppliedKeys([
      for (final key in keys)
        if (identities.contains(key)) key,
    ]);
  }

  /// 고친 품목을 저장한다(bucket 전체, revision 확인). 실패하면 draft를 그대로 둔다.
  Future<bool> save() => _save();

  /// "이 값이 맞습니다"(FB-10b): 수량은 그대로 두고 [key]의 확인 필요 표시만 해제한다(scope = 그 key).
  Future<bool> confirmReview(String key) async {
    if (!canConfirmReview(key)) return false;
    return _save(confirmed: key);
  }

  Future<bool> _save({String? confirmed}) async {
    final repository = _repository;
    final profile = _profile;
    final state = _state;
    if (repository == null || profile == null || state == null) {
      _setMessage('계정을 먼저 골라야 저장할 수 있습니다.', InventoryMessageTone.warning);
      return false;
    }
    if (_saving) return false;
    final Map<String, dynamic> wire;
    final List<String> applied;
    try {
      wire = inventoryWire();
      applied = appliedResourceKeys(wire, confirmed: confirmed);
    } on FormatException catch (error) {
      _setMessage(error.message, InventoryMessageTone.warning);
      return false;
    }
    // 결과를 모르는 앞 요청과 같은 내용(고친 값·scope)이면 원 revision·key·bucket을 그대로 다시 보낸다.
    final signature = jsonEncode({
      'drafts': {
        for (final key in _dirtyKeys.toList()..sort()) key: _drafts[key] ?? '',
      },
      'applied': applied,
    });
    final pending = _pendingSave;
    final _InventorySaveRequest request =
        pending != null &&
            pending.profileId == profile.id &&
            pending.signature == signature
        ? pending
        : (
            profileId: profile.id,
            signature: signature,
            wire: wire,
            applied: applied,
            expectedRevision: state.revision,
            // 시계 해상도가 낮아도 새 요청마다 다른 key(같은 key·다른 내용 = idempotency_conflict).
            idempotencyKey:
                newIdempotencyKey('inventory-save'),
          );
    _pendingSave = request;
    _saving = true;
    _message = null;
    _lastSaveErrorReason = null;
    _notify();
    try {
      final revision = await repository.saveRepositoryInventory(
        request.profileId,
        RepositoryInventoryState.fromWire(request.wire),
        request.expectedRevision,
        request.idempotencyKey,
        appliedResourceKeys: request.applied,
      );
      _pendingSave = null;
      if (_disposed) return true;
      _drafts.clear();
      _dirtyKeys.clear();
      _editingKey = null;
      _saving = false;
      await load();
      _setMessage(
        confirmed == null
            ? '저장했습니다(revision $revision).'
            : '이 값을 확인했습니다. 확인 필요 표시를 지웠습니다(revision $revision).',
        InventoryMessageTone.info,
      );
      return true;
    } catch (error) {
      final retryable = inventorySaveRetryable(error);
      if (!retryable) _pendingSave = null;
      if (_disposed) return false;
      _saving = false;
      final reason = switch (error) {
        BackendRemoteException(:final details) => details?['reason'],
        _ => null,
      };
      if (inventoryIsCurrencyReadOnlyError(error)) {
        _lastSaveErrorReason = inventoryCurrencyReadOnlyReason;
        _setMessage(
          '재화(크레딧·엘리그마)는 스캔으로만 바뀌어 저장하지 않았습니다. 고친 수량은 그대로 남아 있습니다.',
          InventoryMessageTone.warning,
        );
      } else if (retryable) {
        _lastSaveErrorReason = _repositoryErrorCode(error) ?? 'save_unknown';
        _setMessage(
          '저장 결과를 확인하지 못했습니다. 고친 수량은 그대로 남아 있습니다. 다시 저장하면 같은 요청으로 다시 확인합니다.',
          InventoryMessageTone.warning,
        );
      } else if (reason == inventoryScanScopeMismatchReason) {
        _lastSaveErrorReason = inventoryScanScopeMismatchReason;
        _setMessage(
          '고친 범위 밖의 수량이 바뀌어 저장하지 않았습니다. 고친 수량은 그대로 남아 있습니다. 다시 읽은 뒤 저장합니다.',
          InventoryMessageTone.warning,
        );
      } else if (_repositoryErrorCode(error) == 'idempotency_conflict') {
        _lastSaveErrorReason = 'idempotency_conflict';
        _setMessage(
          '이 저장 요청은 다른 내용으로 이미 쓰인 요청이라 저장하지 않았습니다. 고친 수량은 그대로 남아 있습니다. 다시 저장하면 새 요청으로 보냅니다.',
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
