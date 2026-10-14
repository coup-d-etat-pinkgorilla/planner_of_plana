// FE9-a: 전술대항전 기록 화면(시안 Tactical S1 기록 목록 + S3 기록 작성, S2 · S4는 FE9-c · FE9-d 자리).
//
// - 데이터는 FE9-b1 [TacticalRecordsController](v2)다. v1 쓰기(`saveTacticalMatch` 등)는 부르지 않는다. 기록 저장 · 지우기는
//   컨트롤러가 v2 tactical revision을 `expected_revision`으로 보내고 idempotency key를 만든다. 저장 오류 문구는 컨트롤러 표 그대로다.
// - revision 분리(T-FB1b): 계정 상태(repository) revision은 보유 학생 읽기에만 쓰고 tactical 쓰기에 섞지 않는다. 다른 탭에서
//   프로필이 바뀌면 셸이 [TacticalPage.reloadToken]을 올리고(또는 계정 세대 key로 새로 만들고) 화면이 다시 읽는다.
// - v1 기록이 남아 있으면(컨트롤러 `migrationRequired`) S1에 이관 안내 띠를 띄우고, v1 기록을 읽기 전용 행으로 목록 뒤에 보인다.
//   "가져오기"를 누를 때만 이관한다(자동 이관 없음).
// - 학생 고르기 · 상대 고르기 · 지우기 확인은 공용 [BaModal]이다(AlertDialog 없음).
import 'package:flutter/material.dart';

import '../../services/app_clock.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/tactical_service.dart';
import '../../services/tactical_v2_service.dart';
import '../../tactical/tactical_records_controller.dart';
import '../kit/ba_modal.dart';
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
      _reload();
    } else if (old.reloadToken != widget.reloadToken) {
      _reload();
    }
  }

  @override
  void dispose() {
    _generation++;
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

  void _updateDraft(TacticalRecordDraft Function(TacticalRecordDraft) change) {
    _controller?.clearError();
    setState(() {
      _localError = null;
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
