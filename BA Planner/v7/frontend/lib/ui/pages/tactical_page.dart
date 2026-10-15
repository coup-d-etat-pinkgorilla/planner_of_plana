// FE9-a: 전술대항전 기록 화면(시안 Tactical S1 기록 목록 + S3 기록 작성, S2 · S4는 FE9-c · FE9-d 자리).
//
// - 데이터는 FE9-b1 [TacticalRecordsController](v2)다. v1 쓰기(`saveTacticalMatch` 등)는 부르지 않는다. 기록 저장 · 지우기는
//   컨트롤러가 v2 tactical revision을 `expected_revision`으로 보내고 idempotency key를 만든다. 저장 오류 문구는 컨트롤러 표 그대로다.
// - revision 분리(T-FB1b): 계정 상태(repository) revision은 보유 학생 읽기에만 쓰고 tactical 쓰기에 섞지 않는다. 다른 탭에서
//   프로필이 바뀌면 셸이 [TacticalPage.reloadToken]을 올리고(또는 계정 세대 key로 새로 만들고) 화면이 다시 읽는다.
// - v1 기록이 남아 있으면(컨트롤러 `migrationRequired`) S1에 이관 안내 띠를 띄우고, v1 기록을 읽기 전용 행으로 목록 뒤에 보인다.
//   "가져오기"를 누를 때만 이관한다(자동 이관 없음).
// - 학생 고르기 · 상대 고르기 · 지우기 확인은 공용 [BaModal]이다(AlertDialog 없음).
// - FE9-d: S4 "이 시그니처의 족보"는 고른 기록(작성 중 초안)의 상대 덱 공개 시그니처로 [TacticalEvidenceReadService] 통계 ·
//   추이 · 추천을 읽는다(시그니처 · 기록 revision · 상대 · 시즌이 바뀌면 디바운스 뒤 다시 질의, 늦게 온 응답은 세대 번호로 버린다).
//   카드는 컨트롤러 족보 중 그 시그니처를 가진 것(FD-129)이다. 카드를 끌어 내 덱 줄에 놓거나 "족보에서 가져오기"를 누르면
//   내 덱 초안을 그 공격 덱으로 채운다(저장하지 않는다, 공격 기록만). 이관 전에는 S4를 열지 않는다(FE9-a "준비 중" 그대로).
import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/app_clock.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/tactical_service.dart';
import '../../services/tactical_v2_service.dart';
import '../../tactical/tactical_records_controller.dart';
import '../kit/ba_modal.dart';
import '../tactical/tactical_jokbo_view.dart';
import '../tactical/tactical_pickers.dart';
import '../tactical/tactical_records_view.dart';
import '../tactical/tactical_workspace.dart';
import '../widgets/account_section_cluster.dart'
    show repositoryProfileWithRevision;

/// 목록 · 작성 섹션 안내 문구.
const tacticalNoServiceText = '전술 기록 서비스가 제공되지 않습니다.';
const tacticalNoProfileText = '선택된 프로필이 없습니다.';
const tacticalLoadingText = '전술 기록을 읽는 중입니다.';
const tacticalEmptyText = '아직 저장한 기록이 없습니다. 기록 작성에서 저장하면 여기에 나타납니다.';
const tacticalDisconnectedText = '백엔드 연결이 끊어졌습니다.';
const tacticalOtherProfileText = '선택 계정과 다른 계정의 응답을 받았습니다.';
const tacticalReadOnlyHint = '이전 형식 기록은 가져온 뒤에 고칠 수 있습니다.';
const tacticalNeedOpponentHint = '상대 이름을 입력해 주십시오.';
const tacticalNeedAttemptHint = '시도 횟수를 정해 주십시오.';
const tacticalInvalidInputText = '입력한 기록을 저장할 수 없습니다. 칸과 이름을 확인해 주십시오.';

/// S4 · 족보 복사 문구(FE9-d).
const tacticalJokboNoSignatureText =
    '상대 덱에 로비 스캔 공개 칸(1번 · SP1 · SP2)이 없어 족보를 찾지 않았습니다.';
const tacticalJokboEmptyText =
    '이 공개 시그니처의 족보가 아직 없습니다. 공격 기록을 저장하면 같은 편성 족보가 생깁니다.';
const tacticalJokboReadErrorText = '족보 통계를 읽지 못했습니다. 기록에서 센 값만 보입니다.';
const tacticalJokboDefenseText = '방어 기록에는 족보 덱을 복사할 수 없습니다. 공격 기록에서만 복사합니다.';
const tacticalJokboBusyText = '저장하는 중에는 덱을 바꿀 수 없습니다.';
const tacticalJokboUnavailableText = '지금은 덱을 바꿀 수 없습니다.';
const tacticalJokboNoneText = '가져올 족보가 없습니다.';
const tacticalJokboCopyHint = '오른쪽에서 고른 족보 덱을 내 공격 덱에 복사합니다. 저장은 따로 합니다.';

/// S4 질의 디바운스(고른 기록 · 공개 칸이 잇따라 바뀔 때 마지막 것만 묻는다).
const tacticalJokboQueryDelay = Duration(milliseconds: 200);

/// S4 질의 조건. 하나라도 바뀌면 다시 묻는다(기록 revision이 오르면 통계도 바뀐다).
typedef _JokboQuery = ({
  String profileId,
  String signature,
  int revision,
  String? opponentId,
  String season,
});

class TacticalPage extends StatefulWidget {
  const TacticalPage({super.key, required this.service, this.reloadToken = 0});
  final AppService service;
  final int reloadToken;
  @override
  State<TacticalPage> createState() => _TacticalPageState();
}

enum _OpponentPickerMode { editor, filter }

class _TacticalPageState extends State<TacticalPage> {
  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;

  /// FE9-d S4 읽기(통계 · 추이 · 추천).
  TacticalEvidenceReadService? get _reader =>
      widget.service is TacticalEvidenceReadService
      ? widget.service as TacticalEvidenceReadService
      : null;

  /// v1 읽기(이관 전 읽기 전용 목록). 쓰기는 하지 않는다.
  TacticalService? get _legacyReader => widget.service is TacticalService
      ? widget.service as TacticalService
      : null;

  TacticalRecordsController? _controller;

  /// 선택 계정. revision은 목록 summary가 아니라 마지막으로 읽은 repository state 값이다(FB-1b).
  RepositoryProfile? _profile;

  /// 계정 상태(보유 학생). 그 revision은 tactical 쓰기에 쓰지 않는다(T-FB1b).
  RepositoryState? _repositoryState;
  List<StudentCatalogEntry> _catalog = const [];
  Map<String, String> _names = const {};

  /// 이관 전 v1 기록(읽기 전용 표시만).
  TacticalState? _legacyState;
  bool _loading = true;
  String? _error;
  int _generation = 0;

  TacticalRecordFilter _filter = const TacticalRecordFilter();
  String? _selectedKey;
  TacticalRecordDraft _draft = TacticalRecordDraft.blank();
  bool _autoSelect = true;
  String? _localError;

  final _opponentText = TextEditingController();
  final _notesText = TextEditingController();
  final _studentModal = BaModalController();
  final _opponentModal = BaModalController();
  final _deleteModal = BaModalController();
  ({bool mine, int index})? _pickerSlot;
  _OpponentPickerMode _opponentMode = _OpponentPickerMode.editor;

  /// 새 기록 · 새 상대 ID 순번(같은 µs 시계에서도 겹치지 않게, 프로세스 전체).
  static int _idSequence = 0;

  // --- S4 족보(FE9-d) ---
  _JokboQuery? _jokboQuery;
  Timer? _jokboTimer;
  int _jokboGeneration = 0;
  TacticalJokboReads? _jokboReads;
  String? _jokboError;

  /// 사용자가 고른 족보 카드(없으면 지금 내 덱과 같은 카드 → 첫 카드).
  String? _selectedJokboId;

  /// 마지막으로 그린 S4(버튼이 고른 카드를 찾는다).
  TacticalJokboPanel _lastJokbo = const TacticalJokboPanel.pending();

  /// 족보 덱을 복사한 뒤 상태 문구(다음 초안 변경까지).
  String? _copyNotice;

  @override
  void initState() {
    super.initState();
    _attach();
    widget.service.state.addListener(_connection);
    _opponentText.addListener(_textChanged);
    _notesText.addListener(_textChanged);
    _reload();
  }

  void _attach() {
    final service = widget.service;
    if (service is TacticalEvidenceWriteService) {
      _controller = TacticalRecordsController(
        service as TacticalEvidenceWriteService,
        now: () => appClockNow(service),
      )..addListener(_controllerChanged);
    }
  }

  void _detach() {
    _controller
      ?..removeListener(_controllerChanged)
      ..dispose();
    _controller = null;
  }

  @override
  void didUpdateWidget(TacticalPage old) {
    super.didUpdateWidget(old);
    if (old.service != widget.service) {
      old.service.state.removeListener(_connection);
      widget.service.state.addListener(_connection);
      _detach();
      _attach();
      _syncJokboQuery(null);
      _jokboReads = null;
      _reload();
    } else if (old.reloadToken != widget.reloadToken) {
      _reload();
    }
  }

  @override
  void dispose() {
    _generation++;
    _jokboGeneration++;
    _jokboTimer?.cancel();
    widget.service.state.removeListener(_connection);
    _detach();
    _opponentText.dispose();
    _notesText.dispose();
    _studentModal.dispose();
    _opponentModal.dispose();
    _deleteModal.dispose();
    super.dispose();
  }

  void _connection() {
    if (!mounted) return;
    if (widget.service.state.value.connection == BackendConnection.connected) {
      _reload();
    } else {
      setState(() {
        _loading = false;
        _error = tacticalDisconnectedText;
      });
    }
  }

  void _textChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _localError = null;
    });
    final repository = _repository;
    final controller = _controller;
    if (repository == null || controller == null) {
      setState(() {
        _loading = false;
        _error = tacticalNoServiceText;
      });
      return;
    }
    try {
      final profiles = await repository.listProfiles();
      RepositoryProfile? selected;
      for (final item in profiles) {
        if (item.selected) {
          selected = item;
          break;
        }
      }
      if (!mounted || generation != _generation) return;
      if (selected == null) {
        setState(() {
          _profile = null;
          _repositoryState = null;
          _legacyState = null;
          _loading = false;
        });
        return;
      }
      final profileId = selected.id;
      final (repositoryState, catalog, _) = await (
        repository.loadRepositoryState(profileId),
        widget.service.listStudents(),
        controller.load(profileId),
      ).wait;
      if (!mounted || generation != _generation) return;
      final tacticalProfile = controller.state?.profileId;
      if (repositoryState.profileId != profileId ||
          (tacticalProfile != null && tacticalProfile != profileId)) {
        throw StateError(tacticalOtherProfileText);
      }
      TacticalState? legacy;
      final reader = _legacyReader;
      if (controller.migrationRequired && reader != null) {
        legacy = await reader.loadTacticalState(profileId);
        if (!mounted || generation != _generation) return;
        if (legacy.profileId != profileId) legacy = null;
      }
      setState(() {
        _profile = repositoryProfileWithRevision(
          selected!,
          repositoryState.revision,
        );
        _repositoryState = repositoryState;
        _catalog = catalog;
        _names = {for (final item in catalog) item.studentId: item.displayName};
        _legacyState = legacy;
        _loading = false;
        _reconcileSelection();
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = error is StateError ? error.message : '$error';
        });
      }
    }
  }

  void _controllerChanged() {
    if (!mounted) return;
    setState(() {
      final controller = _controller;
      if (controller != null && !controller.migrationRequired) {
        _legacyState = null;
      }
      _reconcileSelection();
    });
  }

  // --- 목록 ------------------------------------------------------------------

  bool get _available =>
      _controller != null && _profile != null && _error == null;

  List<TacticalRecordRow> get _rows {
    final controller = _controller;
    if (controller == null || !_available) return const [];
    return tacticalRecordRows(
      controller.matches,
      legacy: controller.migrationRequired
          ? (_legacyState?.matches ?? const [])
          : const [],
    );
  }

  /// 고른 행이 사라졌으면(지움 · 이관) 같은 ID의 v2 행, 없으면 첫 행이나 새 초안으로 옮긴다. 처음 읽은 뒤에는 첫 행을 고른다.
  void _reconcileSelection() {
    final rows = _rows;
    final key = _selectedKey;
    if (key != null) {
      if (rows.any((row) => row.key == key)) return;
      // 이관한 v1 기록은 새 ID를 받고 원본 ID를 `v7-v1:match:<v1 ID>`로 남긴다.
      final migrated = key.startsWith('v1:')
          ? 'v7-v1:match:${key.substring(3)}'
          : null;
      final match = migrated == null
          ? null
          : rows.where((row) => row.sourceRecordId == migrated).firstOrNull;
      if (match != null) {
        _select(match);
      } else if (rows.isNotEmpty) {
        _select(rows.first);
      } else {
        _setDraft(null, TacticalRecordDraft.blank());
      }
      return;
    }
    if (_autoSelect && rows.isNotEmpty) {
      _select(rows.first);
    }
  }

  void _select(TacticalRecordRow row) {
    _autoSelect = false;
    _setDraft(row.key, row.draft);
  }

  void _setDraft(String? key, TacticalRecordDraft draft) {
    _selectedKey = key;
    _draft = draft;
    _localError = null;
    _copyNotice = null;
    _selectedJokboId = null;
    _opponentText.text = draft.opponentName;
    _notesText.text = draft.notes;
  }

  void _onSelectRow(TacticalRecordRow row) {
    _controller?.clearError();
    setState(() => _select(row));
  }

  void _onNewRecord() {
    _controller?.clearError();
    setState(() {
      _autoSelect = false;
      _setDraft(
        null,
        TacticalRecordDraft.blank(season: tacticalCurrentSeason(_rows) ?? ''),
      );
    });
  }

  // --- 작성 ------------------------------------------------------------------

  TacticalRecordDraft get _current =>
      _draft.copyWith(opponentName: _opponentText.text, notes: _notesText.text);

  bool get _busy {
    final controller = _controller;
    return controller == null || controller.busy || controller.loading;
  }

  bool get _editable => _available && !_draft.readOnly && !_busy;

  bool get _migrationRequired => _controller?.migrationRequired ?? false;

  /// 저장할 수 없는 이유(없으면 null).
  String? get _saveBlocker {
    if (_draft.readOnly) return tacticalReadOnlyHint;
    if (_migrationRequired) {
      return tacticalRecordsErrorMessages['legacy_migration_required'];
    }
    if (_opponentText.text.trim().isEmpty) return tacticalNeedOpponentHint;
    if (_draft.attemptCount == null) return tacticalNeedAttemptHint;
    return null;
  }

  void _updateDraft(
    TacticalRecordDraft Function(TacticalRecordDraft) change, {
    String? notice,
  }) {
    _controller?.clearError();
    setState(() {
      _localError = null;
      _copyNotice = notice;
      _draft = change(_draft);
    });
  }

  String _newId(String prefix) =>
      '$prefix-${appClockNow(widget.service).microsecondsSinceEpoch}-${++_idSequence}';

  Future<void> _save() async {
    final controller = _controller;
    final state = controller?.state;
    if (controller == null ||
        state == null ||
        !_editable ||
        _saveBlocker != null) {
      return;
    }
    final draft = _current;
    final TacticalMatchInputV2 input;
    try {
      input = draft.toInput(
        newId: () => _newId('match'),
        identityId:
            tacticalIdentityForName(state.opponents, draft.opponentName) ??
            _newId('opponent'),
        now: appClockNow(widget.service),
      );
    } on Object {
      setState(() => _localError = tacticalInvalidInputText);
      return;
    }
    final saved = await controller.saveMatch(input);
    if (!mounted || !saved) return;
    final row = _rows.where((row) => row.key == 'v2:${input.id}').firstOrNull;
    setState(() {
      if (row != null) {
        _select(row);
      } else {
        _reconcileSelection();
      }
    });
  }

  void _duplicate() {
    _controller?.clearError();
    setState(() {
      _autoSelect = false;
      _setDraft(null, _current.duplicate());
    });
  }

  void _openDelete() {
    if (_draft.isNew || _draft.readOnly || _busy) return;
    _deleteModal.open();
  }

  Future<void> _confirmDelete() async {
    final controller = _controller;
    final id = _draft.id;
    _deleteModal.close();
    if (controller == null || id == null || _draft.readOnly) return;
    final deleted = await controller.deleteMatch(id);
    if (!mounted || !deleted) return;
    setState(() {
      final rows = _rows;
      if (rows.isNotEmpty) {
        _select(rows.first);
      } else {
        _setDraft(null, TacticalRecordDraft.blank());
      }
    });
  }

  Future<void> _import() async {
    final controller = _controller;
    if (controller == null || !controller.migrationRequired) return;
    final imported = await controller.commitMigration();
    if (!mounted || !imported) return;
    setState(() {
      _legacyState = null;
      _reconcileSelection();
    });
  }

  void _copyLastDeck() {
    final source = _lastDeckSource;
    if (source == null) return;
    _updateDraft((draft) => draft.copyWith(myDeck: source.draft.myDeck));
  }

  /// "지난 기록 덱 복사"의 원본: 같은 종류의 다른 v2 기록 중 같은 상대가 먼저, 없으면 가장 최근.
  TacticalRecordRow? get _lastDeckSource {
    final candidates = [
      for (final row in _rows)
        if (!row.legacy && row.kind == _draft.kind && row.draft.id != _draft.id)
          row,
    ];
    final name = _opponentText.text.trim();
    return candidates.where((row) => row.opponentName == name).firstOrNull ??
        candidates.firstOrNull;
  }

  String get _opponentMeta {
    final name = _opponentText.text.trim();
    if (name.isEmpty) return '순위 — · 최근 대전 —';
    final count = _rows.where((row) => row.opponentName == name).length;
    return '순위 — · 최근 대전 $count회';
  }

  // --- S4 족보 (FE9-d) ----------------------------------------------------------

  /// [query]가 바뀌었으면 이전 질의를 버리고 디바운스 뒤 다시 묻는다. build에서 부른다(setState 없음).
  void _syncJokboQuery(_JokboQuery? query) {
    if (query == _jokboQuery) return;
    _jokboQuery = query;
    _jokboTimer?.cancel();
    _jokboTimer = null;
    final generation = ++_jokboGeneration;
    _jokboError = null;
    if (query == null) return;
    _jokboTimer = Timer(
      tacticalJokboQueryDelay,
      () => _runJokboQuery(query, generation),
    );
  }

  Future<void> _runJokboQuery(_JokboQuery query, int generation) async {
    final reader = _reader;
    if (reader == null || !mounted || generation != _jokboGeneration) return;
    final asOf = tacticalUtcInstant(appClockNow(widget.service));
    final opponentId = query.opponentId;
    try {
      final (statistics, trends, recommendation) = await (
        reader.queryTacticalStatistics(
          query.profileId,
          TacticalStatsFilters(publicSignature: query.signature),
        ),
        reader.queryTacticalTrends(
          query.profileId,
          TacticalTrendFilters(publicSignature: query.signature, asOf: asOf),
        ),
        opponentId == null || query.season.isEmpty
            ? Future<TacticalRecommendationResult?>.value()
            : reader.queryTacticalRecommendations(
                query.profileId,
                TacticalRecommendationFilters(
                  season: query.season,
                  opponentIdentityId: opponentId,
                  publicSignature: query.signature,
                  asOf: asOf,
                  topK: 10,
                ),
              ),
      ).wait;
      if (!mounted || generation != _jokboGeneration) return;
      setState(() {
        _jokboError = null;
        _jokboReads = TacticalJokboReads(
          signature: query.signature,
          statistics: statistics.publicSignatures
              .where((item) => item.signature == query.signature)
              .firstOrNull,
          freshness: [
            for (final item in trends.freshness)
              if (item.publicSignature == query.signature) item,
          ],
          recommendation: recommendation,
        );
      });
    } catch (_) {
      if (!mounted || generation != _jokboGeneration) return;
      setState(() => _jokboError = tacticalJokboReadErrorText);
    }
  }

  void _retryJokbo() {
    final query = _jokboQuery;
    if (query == null) return;
    _jokboTimer?.cancel();
    final generation = ++_jokboGeneration;
    setState(() => _jokboError = null);
    _runJokboQuery(query, generation);
  }

  /// S4 값. 이관 전 · 계정 없음이면 "준비 중" 자리.
  TacticalJokboPanel _jokboPanel(TacticalRecordDraft current) {
    final controller = _controller;
    final profileId = _profile?.id;
    if (controller == null ||
        profileId == null ||
        !_available ||
        _migrationRequired) {
      _syncJokboQuery(null);
      return const TacticalJokboPanel.pending();
    }
    final name = current.opponentName.trim();
    final caption = current.attack ? '대상 방어 덱' : '상대 공격 덱';
    final targetName = name.isEmpty ? '—' : name;
    final signature = tacticalPublicSignature(current.opponentDeck);
    if (signature == null) {
      _syncJokboQuery(null);
      return TacticalJokboPanel(
        targetCaption: caption,
        targetName: targetName,
        targetDeck: current.opponentDeck,
        kpis: null,
        cards: const [],
        selectedId: null,
        onSelect: null,
        message: tacticalJokboNoSignatureText,
      );
    }
    _syncJokboQuery((
      profileId: profileId,
      signature: signature,
      revision: controller.revision ?? -1,
      opponentId:
          tacticalIdentityForName(
            controller.state?.opponents ?? const [],
            name,
          ) ??
          current.opponentIdentityId,
      season: current.season.trim(),
    ));
    final reads = _jokboReads?.signature == signature ? _jokboReads : null;
    final cards = tacticalSignatureJokboCards(
      signature: signature,
      jokbo: controller.jokbo,
      matches: controller.matches,
      statistics: reads?.statistics,
      freshness: reads?.freshness ?? const [],
      recommendations: reads?.recommendation?.recommendations ?? const [],
    );
    final error = _jokboError;
    return TacticalJokboPanel(
      targetCaption: caption,
      targetName: targetName,
      targetDeck: current.opponentDeck,
      kpis: tacticalJokboKpis(
        reads: reads,
        cardCount: cards.length,
        now: appClockNow(widget.service),
      ),
      cards: cards,
      selectedId: tacticalEffectiveJokboSelection(
        cards,
        _selectedJokboId,
        current.myDeck,
      ),
      onSelect: (card) => setState(() => _selectedJokboId = card.id),
      message: cards.isEmpty ? tacticalJokboEmptyText : null,
      readError: error,
      onRetry: error == null ? null : _retryJokbo,
    );
  }

  /// 내 덱에 족보를 놓을 수 없는 이유(null = 놓을 수 있다). 공격 기록 · 고칠 수 있는 초안만.
  String? get _jokboDropReason {
    if (!_available) return tacticalJokboUnavailableText;
    if (_draft.readOnly) return tacticalReadOnlyHint;
    if (_busy) return tacticalJokboBusyText;
    if (!_draft.attack) return tacticalJokboDefenseText;
    return null;
  }

  /// 족보 공격 덱으로 내 덱 초안을 채운다(저장하지 않는다). 보유하지 않은 학생 칸은 빗금 빈칸으로 두고 알린다.
  void _copyJokbo(TacticalJokboCard card) {
    if (_jokboDropReason != null) return;
    final owned = {
      ...?_repositoryState?.students.map((item) => item.studentId),
    };
    final copy = tacticalCopyJokboDeck(card.jokbo.attackDeck, owned);
    final missing = copy.missing;
    final notice = missing.isEmpty
        ? '${card.name} 덱을 내 공격 덱에 복사했습니다. 저장하면 기록에 남습니다.'
        : '${card.name} 덱을 복사했습니다. 보유하지 않은 학생 ${missing.length}명'
              '(${missing.map((id) => _names[id] ?? id).join(' · ')})은 빈칸으로 두었습니다.';
    _selectedJokboId = card.id;
    _updateDraft((draft) => draft.copyWith(myDeck: copy.deck), notice: notice);
  }

  /// "족보에서 가져오기": S4에서 고른 카드를 복사한다(끌기와 같은 일 — 키보드 · 접근성 경로).
  void _copySelectedJokbo() {
    final id = _lastJokbo.selectedId;
    final card = _lastJokbo.cards.where((item) => item.id == id).firstOrNull;
    if (card != null) _copyJokbo(card);
  }

  // --- 피커 ------------------------------------------------------------------

  void _openSlotPicker(bool mine, int index) {
    if (!_editable) return;
    setState(() => _pickerSlot = (mine: mine, index: index));
    _studentModal.open();
  }

  void _pickStudent(String? studentId) {
    final slot = _pickerSlot;
    _studentModal.close();
    if (slot == null) return;
    _updateDraft((draft) {
      if (slot.mine) {
        return draft.copyWith(
          myDeck: tacticalDeckWithSlot(draft.myDeck, slot.index, studentId),
        );
      }
      return draft.copyWith(
        opponentDeck: tacticalDeckWithSlot(
          draft.opponentDeck,
          slot.index,
          studentId,
        ),
      );
    });
  }

  void _openOpponentPicker(_OpponentPickerMode mode) {
    setState(() => _opponentMode = mode);
    _opponentModal.open();
  }

  void _pickOpponent(String? name) {
    _opponentModal.close();
    if (_opponentMode == _OpponentPickerMode.filter) {
      setState(
        () => _filter = name == null
            ? _filter.copyWith(clearOpponent: true)
            : _filter.copyWith(opponent: name),
      );
      return;
    }
    if (name == null) return;
    _controller?.clearError();
    setState(() => _localError = null);
    _opponentText.text = name;
  }

  Widget _studentPanel(BuildContext context) {
    final slot = _pickerSlot;
    if (slot == null) return const SizedBox.shrink();
    final striker = slot.index < 4;
    final combatClass = striker ? 'striker' : 'special';
    final owned = {
      ...?_repositoryState?.students.map((item) => item.studentId),
    };
    final deck = slot.mine ? _draft.myDeck : _draft.opponentDeck;
    final slots = tacticalDeckSlots(deck);
    final classLabel = striker ? '스트라이커' : '스페셜';
    final deckLabel = slot.mine
        ? (_draft.attack ? '내 공격 덱' : '내 방어 덱')
        : (_draft.attack ? '상대 방어 덱' : '상대 공격 덱');
    return TacticalStudentPickerPanel(
      title: '$deckLabel · ${tacticalSlotLabel(slot.index)}번 칸',
      caption: slot.mine ? '$classLabel · 보유 학생' : classLabel,
      students: [
        for (final item in _catalog)
          if (item.combatClass?.toLowerCase() == combatClass &&
              (!slot.mine || owned.contains(item.studentId)))
            TacticalPickerStudent(id: item.studentId, name: item.displayName),
      ],
      usedIds: {
        for (final (index, value) in slots.indexed)
          if (index != slot.index && value.studentId != null) value.studentId!,
      },
      currentId: slots[slot.index].studentId,
      emptyText: slot.mine
          ? '보유한 $classLabel 학생이 없습니다. 학생 스캔을 먼저 실행해 주십시오.'
          : '고를 수 있는 $classLabel 학생이 없습니다.',
      onPicked: _pickStudent,
      onClose: _studentModal.close,
    );
  }

  Widget _opponentPanel(BuildContext context) {
    final filter = _opponentMode == _OpponentPickerMode.filter;
    return TacticalOpponentPickerPanel(
      title: filter ? '상대로 거르기' : '기록한 상대 고르기',
      options: tacticalOpponentOptions(_rows),
      current: filter ? _filter.opponent : _opponentText.text.trim(),
      allLabel: filter ? '전체' : null,
      onPicked: _pickOpponent,
      onClose: _opponentModal.close,
    );
  }

  Widget _deletePanel(BuildContext context) {
    final draft = _current;
    final when = occurredText(draft.occurredAt, draft.occurredPrecision);
    return TacticalDeletePanel(
      label:
          '${draft.attack ? '' : '내 방어덱 · '}vs ${draft.opponentName} · $when',
      busy: _busy,
      onCancel: _deleteModal.close,
      onConfirm: _confirmDelete,
    );
  }

  // --- 그리기 -----------------------------------------------------------------

  String? get _listMessage {
    if (_error != null) return _error;
    if (_controller == null) return tacticalNoServiceText;
    if (_profile == null) {
      return _loading ? tacticalLoadingText : tacticalNoProfileText;
    }
    final error = _controller?.error;
    if (error != null && error.code == 'load_failed') return error.message;
    if (_rows.isEmpty) {
      return _loading || (_controller?.loading ?? false)
          ? tacticalLoadingText
          : tacticalEmptyText;
    }
    return null;
  }

  ({String? text, TacticalEditorStatusTone tone}) get _status {
    final error = _controller?.error;
    if (error != null && error.code != 'load_failed') {
      return (text: error.message, tone: TacticalEditorStatusTone.error);
    }
    final local = _localError;
    if (local != null) {
      return (text: local, tone: TacticalEditorStatusTone.error);
    }
    if (!_available) return (text: null, tone: TacticalEditorStatusTone.none);
    final notice = _copyNotice;
    if (notice != null) {
      return (text: notice, tone: TacticalEditorStatusTone.hint);
    }
    final blocker = _saveBlocker;
    if (blocker != null) {
      return (text: blocker, tone: TacticalEditorStatusTone.hint);
    }
    final controller = _controller;
    if (controller != null && tacticalDraftLinked(_current, controller.jokbo)) {
      return (text: tacticalLinkedText, tone: TacticalEditorStatusTone.linked);
    }
    return (text: null, tone: TacticalEditorStatusTone.none);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final preview = controller?.legacyPreview;
    final rows = _rows;
    final filtered = tacticalFilterRows(rows, _filter);
    final editable = _editable;
    final status = _status;
    final canSave = editable && _saveBlocker == null;
    final jokbo = _lastJokbo = _jokboPanel(_current);
    final dropReason = _jokboDropReason;
    final fromJokboReady = dropReason == null && jokbo.selectedId != null;
    final migration = _available && preview != null && _migrationRequired
        ? TacticalMigrationBand(
            matchCount: preview.matchCount,
            jokboCount: preview.jokboCount,
            issueCount: preview.issues.length,
            onImport: _busy || preview.issues.isNotEmpty ? null : _import,
          )
        : null;
    final workspace = TacticalWorkspace(
      rows: filtered,
      selectedKey: _selectedKey,
      onSelectRow: _available ? _onSelectRow : null,
      filter: _filter,
      onFilter: _available ? (next) => setState(() => _filter = next) : null,
      seasonAvailable: tacticalCurrentSeason(rows) != null,
      onOpenOpponentFilter: _available
          ? () => _openOpponentPicker(_OpponentPickerMode.filter)
          : null,
      onNewRecord: _available && !_busy ? _onNewRecord : null,
      listMessage:
          _listMessage ?? (filtered.isEmpty ? '조건에 맞는 기록이 없습니다.' : null),
      onRetry: _error != null || controller?.error?.code == 'load_failed'
          ? _reload
          : null,
      migration: migration,
      studentName: (id) => _names[id] ?? id,
      draft: _draft,
      editable: editable,
      opponentController: _opponentText,
      notesController: _notesText,
      opponentMeta: _opponentMeta,
      onKind: (kind) => _updateDraft((draft) => draft.copyWith(kind: kind)),
      onResult: (result) =>
          _updateDraft((draft) => draft.copyWith(result: result)),
      onAttempt: (value) =>
          _updateDraft((draft) => draft.copyWith(attemptCount: value)),
      onSlotTap: _openSlotPicker,
      onOpenOpponentPicker: () =>
          _openOpponentPicker(_OpponentPickerMode.editor),
      onCopyLastDeck: _lastDeckSource == null ? null : _copyLastDeck,
      onSave: canSave ? _save : null,
      onDuplicate: _available && !_busy && !_draft.isNew && !_draft.readOnly
          ? _duplicate
          : null,
      onDelete: _available && !_busy && !_draft.isNew && !_draft.readOnly
          ? _openDelete
          : null,
      statusText: status.text,
      statusTone: status.tone,
      jokbo: jokbo,
      onFromJokbo: fromJokboReady ? _copySelectedJokbo : null,
      fromJokboHint:
          dropReason ??
          (jokbo.selectedId == null
              ? tacticalJokboNoneText
              : tacticalJokboCopyHint),
      dropReason: dropReason,
      onDropJokbo: jokbo.cards.isEmpty ? null : _copyJokbo,
    );
    return BaModal(
      controller: _studentModal,
      scrim: BaScrim.anchored,
      label: '학생 고르기',
      builder: _studentPanel,
      child: BaModal(
        controller: _opponentModal,
        scrim: BaScrim.anchored,
        label: '상대 고르기',
        builder: _opponentPanel,
        child: BaModal(
          controller: _deleteModal,
          scrim: BaScrim.anchored,
          label: '기록 지우기',
          builder: _deletePanel,
          child: KeyedSubtree(
            key: const ValueKey('tactical-page'),
            child: workspace,
          ),
        ),
      ),
    );
  }
}
