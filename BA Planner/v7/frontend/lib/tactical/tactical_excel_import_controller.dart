// FE9-f: 전술 엑셀 · UTF-8 CSV 가져오기 흐름(시안 Tactical-Import-Excel, FB-7 `tactical.v2.excel.*`).
//
// - 파일은 Flutter가 읽지 않는다(경계 문서 · FD-131). 사용자가 고른 경로와 명시 선택(시트 · 열 연결 · 처리 방법 · 행 결정 ·
//   on_conflict)만 미리보기에 보내고, 해석 · 지문은 백엔드가 만든다.
// - 열 연결 후보(`mapping_candidates`) · 저장된 열 연결(`saved_mapping`)과 문자열 제안(`suggestions`)은 사용자가 확인하기 전에는
//   보내지 않는다. 첫 미리보기는 열 연결 없이(null) 보내 후보만 받는다.
// - 선택을 바꾸면 같은 선택으로 다시 미리보기를 읽는다(늦게 온 응답은 세대 번호로 버린다). commit은 **마지막으로 받은 미리보기**의
//   선택 객체 그대로 · 그 `fingerprint` · `interpretation_fingerprint` · `current_revision`으로 보낸다(fb7-dart 발견 5 — 미리보기
//   응답에 구분자 · on_conflict 메아리가 없으므로 선택을 들고 있는다). idempotency key는 commit마다 새로 만든다(발견 4 — 변화 없는
//   commit도 key를 쓴다).
// - 처리한 문자열 그룹은 다음 미리보기에서 사라져도 표에 남긴다(시안 "모두 처리됨 5 / 5"). 처리하지 않은 그룹이 다른 처리로
//   사라지면(예: 결과 · 시도로 나누기가 같은 행의 시도 칸을 채움) 표에서 뺀다. 열 연결 · 시트를 바꾸면 처리 방법 · 행 결정을 비운다
//   (칸이 달라져 resolution이 맞지 않는다).
// - 오류는 컨트롤러 문구 표(`tacticalExcelImportErrorMessages`)로 보인다. 미리보기 뒤 원본 · 해석 · revision이 바뀐 commit 오류는
//   같은 선택으로 미리보기를 다시 읽는다.
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../services/idempotency_keys.dart';
import '../services/planning_protocol_client.dart' show BackendRemoteException;
import '../services/tactical_v2_service.dart';

// --- 파일 고르기 -------------------------------------------------------------

/// 가져올 파일 경로를 고른다(취소면 null). 기본은 `file_selector`(기존 의존성) 대화상자다.
abstract interface class TacticalExcelFilePicker {
  Future<String?> pick();
}

/// `.xlsx` · `.csv`만 보이는 운영체제 파일 대화상자.
class NativeTacticalExcelFilePicker implements TacticalExcelFilePicker {
  const NativeTacticalExcelFilePicker();

  static const _types = XTypeGroup(
    label: '엑셀 · CSV',
    extensions: <String>['xlsx', 'csv'],
  );

  @override
  Future<String?> pick() async {
    final file = await openFile(acceptedTypeGroups: const [_types]);
    final path = file?.path;
    return path == null || path.isEmpty ? null : path;
  }
}

/// 테스트 · golden이 파일 대화상자 대신 쓸 대역(셸을 거쳐 띄우는 화면에서도 바꿀 수 있게). null이면 [NativeTacticalExcelFilePicker].
@visibleForTesting
TacticalExcelFilePicker? debugTacticalExcelFilePicker;

/// 지금 쓸 파일 고르기.
TacticalExcelFilePicker tacticalExcelFilePicker() =>
    debugTacticalExcelFilePicker ?? const NativeTacticalExcelFilePicker();

// --- 오류 문구 ---------------------------------------------------------------

/// 화면 오류(코드와 ~습니다체 문구).
@immutable
class TacticalExcelImportError {
  const TacticalExcelImportError(this.code, this.message);

  /// 백엔드 오류 코드, 또는 `connection_failed` · `invalid_choices`.
  final String code;
  final String message;
}

/// 오류 코드 → 화면 문구(FB-7 tactical allowlist).
const tacticalExcelImportErrorMessages = <String, String>{
  'import_interpretation_changed':
      '미리보기 뒤에 해석 조건(열 연결 · 처리 방법 · 저장한 규칙 · 기록)이 바뀌어 가져오지 않았습니다. 미리보기를 다시 읽었습니다.',
  'import_source_changed': '미리보기 뒤에 파일 내용이 바뀌어 가져오지 않았습니다. 미리보기를 다시 읽었습니다.',
  'import_source_unreadable': '파일을 읽지 못했습니다.',
  'import_review_required':
      '처리 방법을 고르지 않은 문자열이나 결정하지 않은 행이 있어 가져오지 않았습니다. 표에서 처리 방법을 골라 주십시오.',
  'legacy_migration_required':
      '이전 형식의 전술 기록을 새 형식으로 옮긴 뒤에 엑셀 기록을 가져올 수 있습니다. 기록 화면에서 "가져오기"를 눌러 주십시오.',
  'opponent_alias_required':
      '상대 이름이 이 상대에 저장된 이름과 다릅니다. 새 상대로 저장하거나 그 행을 건너뛰어 주십시오.',
  'link_conflict': '가져올 기록이 이미 있는 기록 연결과 겹쳐 가져오지 않았습니다.',
  'lineage_conflict': '자동으로 만든 족보의 편성과 겹쳐 가져오지 않았습니다.',
  'invalid_payload': '가져오기 선택이 파일 내용과 맞지 않습니다. 열 연결과 처리 방법을 다시 확인해 주십시오.',
  'revision_conflict': '미리보기 뒤에 전술 기록이 바뀌어 가져오지 않았습니다. 미리보기를 다시 읽었습니다.',
  'idempotency_conflict': '같은 요청 번호로 다른 내용이 와서 가져오지 않았습니다. 미리보기를 다시 읽었습니다.',
  'persistence_failed': '가져온 기록을 저장하지 못했습니다.',
  'profile_not_found': '선택한 계정을 찾지 못했습니다.',
  'repository_busy': '저장소가 다른 작업을 하는 중입니다. 잠시 뒤 다시 시도해 주십시오.',
};

/// `import_source_unreadable` details `reason` → 덧붙일 문구.
const tacticalExcelUnreadableReasons = <String, String>{
  'source_unavailable': '파일이 없거나 열 수 없습니다.',
  'format_unsupported': '.xlsx · .csv 파일만 가져올 수 있습니다.',
  'sheet_not_found': '고른 시트가 파일에 없습니다.',
};

const _failedMessage = '엑셀 가져오기를 하지 못했습니다.';
const _connectionMessage = '백엔드의 답을 받지 못했습니다. 다시 연결한 뒤 다시 시도해 주십시오.';
const _invalidChoicesMessage = '고른 처리 방법을 보낼 수 없습니다. 처리 방법을 다시 골라 주십시오.';

/// [error]를 화면 오류로 바꾼다.
TacticalExcelImportError tacticalExcelImportError(Object error) {
  if (error is BackendRemoteException) {
    var message =
        tacticalExcelImportErrorMessages[error.code] ?? _failedMessage;
    final reason = error.details?['reason'];
    final extra = reason is String
        ? tacticalExcelUnreadableReasons[reason]
        : null;
    if (error.code == 'import_source_unreadable' && extra != null) {
      message = '$message $extra';
    }
    return TacticalExcelImportError(error.code, message);
  }
  if (error is FormatException) {
    return const TacticalExcelImportError(
      'invalid_choices',
      _invalidChoicesMessage,
    );
  }
  return const TacticalExcelImportError(
    'connection_failed',
    _connectionMessage,
  );
}

/// commit 오류 뒤 같은 선택으로 미리보기를 다시 읽는 코드.
const _repreviewAfterCommit = {
  'import_interpretation_changed',
  'import_source_changed',
  'revision_conflict',
  'idempotency_conflict',
  'import_review_required',
};

// --- 처리 방법 -----------------------------------------------------------------

/// 처리 방법 종류(시안 범례 7종 + 상대 · 결과 · 종류 · 시도의 명시 값).
enum TacticalExcelTreatmentKind {
  /// 학생으로 연결(제안 또는 검색) — `value` 학생 ID.
  student,

  /// 기존 상대로 합치기 — `value` 상대 identity ID.
  opponentExisting,

  /// 새 상대로 저장 — `value` `{identity_id, display_name}`(원문 이름).
  opponentNew,

  /// 결과 · 시도로 나누기 — 결과 `value` + 그 행 시도 칸 `value`(행 지정).
  split,

  /// 결과 승 · 패로 읽기 — `value` win/loss.
  result,

  /// 공격 · 방어로 읽기 — `value` attack/defense.
  kind,

  /// 시도 n회로 읽기 — `value` 정수.
  attempts,

  /// 빈칸으로 두기(슬롯만) — `wildcard`.
  wildcard,

  /// 메모로 옮기기 — `notes`.
  notes,

  /// 이 칸 무시 — `ignore`(칸을 읽지 않음, 슬롯이면 모름).
  ignore,

  /// 이 행 건너뛰기 — `skip`.
  skip,
}

/// 사용자가 고른 처리 방법 하나. 값이 있는 종류는 그 값을 함께 든다(새 상대 ID는 고를 때 한 번 만든다 — 다시 미리보기해도
/// 해석 지문이 바뀌지 않게).
@immutable
class TacticalExcelTreatment {
  const TacticalExcelTreatment(this.kind, {this.text, this.label, this.count});

  final TacticalExcelTreatmentKind kind;

  /// 학생 ID · 상대 identity ID · 결과(win/loss) · 종류(attack/defense) · 새 상대 identity ID.
  final String? text;

  /// 학생 표시 이름 · 상대 표시 이름 · 새 상대 이름.
  final String? label;

  /// 시도 횟수(split · attempts).
  final int? count;

  /// 화면 키 · 같음 비교용 ID.
  String get id => switch (kind) {
    TacticalExcelTreatmentKind.student => 'student:$text',
    TacticalExcelTreatmentKind.opponentExisting => 'opponent:$text',
    TacticalExcelTreatmentKind.opponentNew => 'opponent-new',
    TacticalExcelTreatmentKind.split => 'split:$text:$count',
    TacticalExcelTreatmentKind.result => 'result:$text',
    TacticalExcelTreatmentKind.kind => 'kind:$text',
    TacticalExcelTreatmentKind.attempts => 'attempts:$count',
    _ => kind.name,
  };

  /// resolution `action`.
  String get action => switch (kind) {
    TacticalExcelTreatmentKind.wildcard => 'wildcard',
    TacticalExcelTreatmentKind.notes => 'notes',
    TacticalExcelTreatmentKind.ignore => 'ignore',
    TacticalExcelTreatmentKind.skip => 'skip',
    _ => 'value',
  };

  /// 필드 [field] 원값 칸에 넣을 resolution 값(`value` 밖 행동은 null).
  TacticalExcelResolutionValue? valueFor(String field) => switch (kind) {
    TacticalExcelTreatmentKind.opponentNew => TacticalExcelNewOpponentValue(
      identityId: text!,
      displayName: label!,
    ),
    TacticalExcelTreatmentKind.attempts => TacticalExcelIntegerValue(count!),
    TacticalExcelTreatmentKind.student ||
    TacticalExcelTreatmentKind.opponentExisting ||
    TacticalExcelTreatmentKind.split ||
    TacticalExcelTreatmentKind.result ||
    TacticalExcelTreatmentKind.kind => TacticalExcelTextValue(text!),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is TacticalExcelTreatment &&
      other.kind == kind &&
      other.text == text &&
      other.label == label &&
      other.count == count;

  @override
  int get hashCode => Object.hash(kind, text, label, count);
}

/// 표의 문자열 그룹 한 줄: 마지막으로 본 그룹 · 고른 처리 방법 · "모두 적용" · 지금도 미해결인가.
@immutable
class TacticalExcelGroupEntry {
  const TacticalExcelGroupEntry({
    required this.group,
    required this.treatment,
    required this.applyAll,
    required this.open,
  });

  /// 마지막으로 미리보기에 나온 그룹(처리한 뒤 사라져도 그때 값).
  final TacticalExcelStringGroup group;
  final TacticalExcelTreatment? treatment;

  /// "모두 적용": 켜면 같은 필드 · 원값 전체(행 없는 resolution — 규칙으로 저장될 수 있다), 끄면 나온 행에만.
  final bool applyAll;

  /// 마지막 미리보기에도 이 그룹이 남아 있는가(처리 방법을 골랐는데 남았으면 그 방법으로 풀리지 않은 것이다).
  final bool open;

  /// 처리 완료(처리 방법을 고르고 미리보기에서 사라짐).
  bool get resolved => treatment != null && !open;

  String get key => tacticalExcelGroupKey(group);

  TacticalExcelGroupEntry copyWith({
    TacticalExcelStringGroup? group,
    TacticalExcelTreatment? treatment,
    bool clearTreatment = false,
    bool? applyAll,
    bool? open,
  }) => TacticalExcelGroupEntry(
    group: group ?? this.group,
    treatment: clearTreatment ? null : (treatment ?? this.treatment),
    applyAll: applyAll ?? this.applyAll,
    open: open ?? this.open,
  );
}

/// 그룹 key(필드 · typed 원값 · 이슈 코드). 백엔드 그룹 묶음 기준과 같다.
String tacticalExcelGroupKey(TacticalExcelStringGroup group) =>
    jsonEncode([group.field, group.rawKey, group.code]);

/// 행 결정 화면 값(skip · keep_separate · overwrite).
typedef TacticalExcelRowChoice = ({String action, String? target});

/// 흐름 단계.
enum TacticalExcelImportStage {
  /// 열지 않았다.
  closed,

  /// 미리보기를 읽는 중(첫 읽기 · 다시 읽기).
  previewing,

  /// 미리보기를 받았다(열 연결 확인 전이거나 확인 뒤).
  ready,

  /// 가져오는 중.
  committing,
}

// --- 컨트롤러 -----------------------------------------------------------------

class TacticalExcelImportController extends ChangeNotifier {
  TacticalExcelImportController(this._service, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final TacticalExcelImportService _service;
  final DateTime Function() _now;

  TacticalExcelImportStage _stage = TacticalExcelImportStage.closed;
  String? _profileId;
  String? _sourcePath;
  String? _sheetName;
  TacticalExcelColumnMapping? _mapping;
  final Map<String, TacticalExcelGroupEntry> _groups = {};
  final Map<int, TacticalExcelRowChoice> _rowChoices = {};
  bool _overwrite = false;
  bool _saveRules = true;
  TacticalExcelPreview? _preview;
  TacticalExcelImportChoices? _previewChoices;
  TacticalExcelImportError? _error;
  TacticalExcelCommitResult? _result;
  int _generation = 0;
  bool _disposed = false;

  /// 새 상대 identity 순번(같은 µs 시계에서도 겹치지 않게).
  static int _opponentSequence = 0;

  TacticalExcelImportStage get stage => _stage;
  bool get isOpen => _stage != TacticalExcelImportStage.closed;
  bool get previewing => _stage == TacticalExcelImportStage.previewing;
  bool get committing => _stage == TacticalExcelImportStage.committing;
  String? get profileId => _profileId;
  String? get sourcePath => _sourcePath;

  /// 경로의 파일 이름(표시용).
  String get fileName {
    final path = _sourcePath ?? '';
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty || parts.last.isEmpty ? '—' : parts.last;
  }

  /// 사용자가 확인한 열 연결(없으면 아직 확인 전).
  TacticalExcelColumnMapping? get mapping => _mapping;
  TacticalExcelPreview? get preview => _preview;

  /// 마지막 미리보기에 쓴 선택(commit이 그대로 보낸다).
  TacticalExcelImportChoices? get previewChoices => _previewChoices;
  TacticalExcelImportError? get error => _error;

  /// 마지막 commit 결과(성공했을 때만).
  TacticalExcelCommitResult? get result => _result;

  /// "이 처리 방법을 저장해 다음 가져오기에도 쓰기"(commit `save_rules`, 시안 기본 켬).
  bool get saveRules => _saveRules;

  /// "같은 날짜 · 상대 기록이 이미 있으면 덮어쓰기"(`on_conflict` overwrite).
  bool get overwrite => _overwrite;

  /// 표 줄(처음 나온 순서).
  List<TacticalExcelGroupEntry> get groups => List.unmodifiable(_groups.values);

  /// 행 결정(행 번호 → 결정).
  Map<int, TacticalExcelRowChoice> get rowChoices =>
      Map.unmodifiable(_rowChoices);

  /// 열 연결 확인 전에 보여 줄 제안: 저장된 열 연결 → 첫 후보. 확인하기 전에는 보내지 않는다.
  TacticalExcelColumnMapping? get proposedMapping {
    final preview = _preview;
    if (preview == null) return null;
    final saved = preview.savedMapping;
    if (saved != null) return saved;
    for (final candidate in preview.mappingCandidates) {
      try {
        return TacticalExcelColumnMapping(
          headerRow: candidate.headerRow,
          columns: candidate.columns,
        );
      } on FormatException {
        // 필수 필드가 빠진 후보는 그대로 쓸 수 없다(열 바꾸기에서 채운다).
      }
    }
    return null;
  }

  /// 미리보기가 마지막 선택과 같은 상태(다시 읽는 중이 아님)이고 오류로 막히지 않았는가.
  bool get _current =>
      _stage == TacticalExcelImportStage.ready &&
      _preview != null &&
      _previewChoices != null;

  /// 가져올 수 없는 이유(null = 가져올 수 있다). 화면이 버튼 툴팁 · 안내에 쓴다.
  String? get commitBlocker {
    final preview = _preview;
    if (_stage == TacticalExcelImportStage.previewing) {
      return '미리보기를 다시 읽는 중입니다.';
    }
    if (_stage == TacticalExcelImportStage.committing) {
      return '가져오는 중입니다.';
    }
    if (!_current || preview == null) return '미리보기를 읽지 못했습니다.';
    if (_mapping == null || preview.columnMapping == null) {
      return '열 연결을 확인해야 기록을 읽습니다.';
    }
    if (preview.legacyMigrationRequired) {
      return tacticalExcelImportErrorMessages['legacy_migration_required'];
    }
    if (_groups.values.any((entry) => entry.open)) {
      return '처리 방법을 고르지 않은 문자열이 있습니다.';
    }
    if (preview.rows.any((row) => row.status == 'unresolved')) {
      return '확인이 필요한 행이 있습니다. 미리보기에서 건너뛸지 정해 주십시오.';
    }
    if (preview.rows.any((row) => row.status == 'conflict')) {
      return '이미 있는 기록과 겹치는 행이 있습니다. 미리보기에서 결정해 주십시오.';
    }
    if (preview.issues.isNotEmpty) return '파일 전체에 확인할 문제가 있습니다.';
    if (preview.summary.eligibleRows == 0) return '가져올 기록이 없습니다.';
    return null;
  }

  bool get canCommit => commitBlocker == null;

  /// 가져올 건수(결정 반영 뒤 `eligible_rows`). 미리보기 전이면 null.
  int? get eligibleCount => _preview?.summary.eligibleRows;

  // --- 열기 · 닫기 ---

  /// [sourcePath] 파일로 새로 연다. 열 연결 없이 미리보기를 읽어 후보만 받는다.
  Future<void> open({
    required String profileId,
    required String sourcePath,
  }) async {
    _profileId = profileId;
    _sourcePath = sourcePath;
    _sheetName = null;
    _mapping = null;
    _overwrite = false;
    _saveRules = true;
    _result = null;
    _resetInterpretation();
    await _refresh(keepError: false);
  }

  /// 닫는다(늦게 온 응답은 버린다). 열린 동안의 선택도 버린다.
  void close() {
    if (_stage == TacticalExcelImportStage.closed) return;
    _generation++;
    _stage = TacticalExcelImportStage.closed;
    _preview = null;
    _previewChoices = null;
    _error = null;
    _resetInterpretation();
    _notify();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  void _resetInterpretation() {
    _groups.clear();
    _rowChoices.clear();
    _preview = null;
    _previewChoices = null;
  }

  // --- 선택 바꾸기(모두 다시 미리보기) ---

  /// 시트를 바꾼다(열 연결은 시트마다라 비운다).
  Future<void> selectSheet(String? sheetName) async {
    if (!isOpen || sheetName == _sheetName) return;
    _sheetName = sheetName;
    _mapping = null;
    _resetInterpretation();
    await _refresh(keepError: false);
  }

  /// 열 연결을 확인한다(후보 · 저장된 연결 · 열 바꾸기 결과). 칸이 바뀌므로 처리 방법 · 행 결정을 비운다.
  Future<void> confirmMapping(TacticalExcelColumnMapping mapping) async {
    if (!isOpen) return;
    _mapping = mapping;
    _groups.clear();
    _rowChoices.clear();
    await _refresh(keepError: false);
  }

  /// 그룹 [key]의 처리 방법을 고른다(null이면 고르지 않은 상태로 되돌린다).
  Future<void> setTreatment(
    String key,
    TacticalExcelTreatment? treatment,
  ) async {
    final entry = _groups[key];
    if (entry == null || entry.treatment == treatment) return;
    _groups[key] = entry.copyWith(
      treatment: treatment,
      clearTreatment: treatment == null,
    );
    await _refresh(keepError: false);
  }

  /// 그룹 [key]의 "모두 적용"을 바꾼다.
  Future<void> setApplyAll(String key, bool applyAll) async {
    final entry = _groups[key];
    if (entry == null || entry.applyAll == applyAll) return;
    _groups[key] = entry.copyWith(applyAll: applyAll);
    if (entry.treatment == null) {
      _notify();
      return;
    }
    await _refresh(keepError: false);
  }

  /// 행 [row]의 결정을 정한다(null이면 결정을 지운다 — on_conflict 기본 규칙을 따른다).
  Future<void> setRowChoice(int row, TacticalExcelRowChoice? choice) async {
    if (_rowChoices[row] == choice) return;
    if (choice == null) {
      _rowChoices.remove(row);
    } else {
      _rowChoices[row] = choice;
    }
    await _refresh(keepError: false);
  }

  /// on_conflict(덮어쓰기)를 바꾼다.
  Future<void> setOverwrite(bool overwrite) async {
    if (_overwrite == overwrite) return;
    _overwrite = overwrite;
    await _refresh(keepError: false);
  }

  /// 규칙 저장(commit에만 쓰므로 다시 미리보기하지 않는다).
  void setSaveRules(bool saveRules) {
    if (_saveRules == saveRules) return;
    _saveRules = saveRules;
    _notify();
  }

  /// 새 상대 처리 방법(원문 이름 · 새 identity ID — 고를 때 한 번 만든다).
  TacticalExcelTreatment newOpponentTreatment(String displayName) =>
      TacticalExcelTreatment(
        TacticalExcelTreatmentKind.opponentNew,
        text:
            'opponent-${_now().microsecondsSinceEpoch}-${++_opponentSequence}',
        label: displayName,
      );

  /// 같은 선택으로 미리보기를 다시 읽는다(오류 뒤 "다시 읽기").
  Future<void> retry() => _refresh(keepError: false);

  // --- 가져오기 ---

  /// 마지막 미리보기 그대로 commit한다. 성공하면 true(화면이 닫고 기록을 다시 읽는다).
  Future<bool> commit() async {
    final preview = _preview;
    final choices = _previewChoices;
    if (!canCommit || preview == null || choices == null) return false;
    final generation = ++_generation;
    _stage = TacticalExcelImportStage.committing;
    _error = null;
    _notify();
    try {
      final result = await _service.commitTacticalExcelImport(
        choices: choices,
        saveRules: _saveRules,
        expectedFingerprint: preview.fingerprint,
        expectedInterpretationFingerprint: preview.interpretationFingerprint,
        expectedRevision: preview.currentRevision,
        idempotencyKey: newIdempotencyKey('tactical-excel-commit', now: _now()),
      );
      if (_disposed || generation != _generation) return false;
      _result = result;
      _stage = TacticalExcelImportStage.ready;
      _notify();
      return true;
    } catch (error) {
      if (_disposed || generation != _generation) return false;
      _error = tacticalExcelImportError(error);
      _stage = TacticalExcelImportStage.ready;
      if (_repreviewAfterCommit.contains(_error!.code)) {
        await _refresh(keepError: true);
      } else {
        _notify();
      }
      return false;
    }
  }

  // --- 미리보기 ---

  /// 지금 선택. resolution은 그룹 처리 방법과 마지막 미리보기 행의 칸 원값 키로 만든다.
  TacticalExcelImportChoices _choices() {
    final rows = {
      for (final row in _preview?.rows ?? const <TacticalExcelPreviewRow>[])
        row.rowNumber: row,
    };
    final resolutions = <String, TacticalExcelResolution>{};
    void add(TacticalExcelResolution item) =>
        resolutions[jsonEncode([item.row, item.field, item.raw])] = item;
    final entries = _groups.values.toList()
      // 결과 · 시도로 나누기는 행 지정 시도 칸을 만드므로 마지막에 둔다(같은 칸의 시도 처리보다 앞선다).
      ..sort(
        (a, b) =>
            (a.treatment?.kind == TacticalExcelTreatmentKind.split ? 1 : 0) -
            (b.treatment?.kind == TacticalExcelTreatmentKind.split ? 1 : 0),
      );
    // 건너뛰기로 정한 행의 칸은 읽지 않으므로 그 행만 가리키는 resolution은 보내지 않는다(쓰이지 않은 resolution은
    // `invalid_payload`다).
    final skipped = {
      for (final MapEntry(key: row, value: choice) in _rowChoices.entries)
        if (choice.action == 'skip') row,
    };
    for (final entry in entries) {
      final treatment = entry.treatment;
      if (treatment == null) continue;
      final group = entry.group;
      final placeRows = {
        for (final place in group.places)
          if (!skipped.contains(place.row)) place.row,
      };
      if (placeRows.isEmpty) continue;
      if (entry.applyAll) {
        add(
          TacticalExcelResolution(
            field: group.field,
            raw: group.rawKey,
            action: treatment.action,
            value: treatment.valueFor(group.field),
          ),
        );
      } else {
        for (final row in placeRows) {
          add(
            TacticalExcelResolution(
              field: group.field,
              raw: group.rawKey,
              action: treatment.action,
              value: treatment.valueFor(group.field),
              row: row,
            ),
          );
        }
      }
      if (treatment.kind == TacticalExcelTreatmentKind.split) {
        for (final number in placeRows) {
          final cell = rows[number]?.rawCells
              .where((cell) => cell.field == 'attempts')
              .firstOrNull;
          if (cell == null) continue;
          add(
            TacticalExcelResolution(
              field: 'attempts',
              raw: cell.rawKey,
              action: 'value',
              value: TacticalExcelIntegerValue(treatment.count!),
              row: number,
            ),
          );
        }
      }
    }
    return TacticalExcelImportChoices(
      profileId: _profileId!,
      sourcePath: _sourcePath!,
      sheetName: _sheetName,
      delimiter: ',',
      columnMapping: _mapping,
      resolutions: resolutions.values.toList(),
      rowDecisions: [
        for (final MapEntry(key: row, value: choice) in _rowChoices.entries)
          TacticalExcelRowDecision(
            row: row,
            action: choice.action,
            targetMatchId: choice.action == 'overwrite' ? choice.target : null,
          ),
      ],
      onConflict: _overwrite ? 'overwrite' : 'skip',
    );
  }

  Future<void> _refresh({required bool keepError}) async {
    if (_profileId == null || _sourcePath == null) return;
    final generation = ++_generation;
    _stage = TacticalExcelImportStage.previewing;
    if (!keepError) _error = null;
    _notify();
    final TacticalExcelImportChoices choices;
    try {
      choices = _choices();
    } on FormatException catch (error) {
      _error = tacticalExcelImportError(error);
      _stage = TacticalExcelImportStage.ready;
      _previewChoices = null;
      _notify();
      return;
    }
    try {
      final preview = await _service.previewTacticalExcelImport(choices);
      if (_disposed || generation != _generation) return;
      _preview = preview;
      _previewChoices = choices;
      _mergeGroups(preview.stringGroups);
      // 미리보기에 없는 행 결정은 지운다(다음 요청이 `invalid_payload`가 되지 않게).
      final rowNumbers = {for (final row in preview.rows) row.rowNumber};
      _rowChoices.removeWhere((row, _) => !rowNumbers.contains(row));
      _stage = TacticalExcelImportStage.ready;
      _notify();
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = tacticalExcelImportError(error);
      _stage = TacticalExcelImportStage.ready;
      // 이 선택으로는 미리보기가 없다: commit하지 못하게 한다.
      _previewChoices = null;
      _notify();
    }
  }

  void _mergeGroups(List<TacticalExcelStringGroup> current) {
    final byKey = {
      for (final group in current) tacticalExcelGroupKey(group): group,
    };
    for (final key in _groups.keys.toList()) {
      final entry = _groups[key]!;
      final group = byKey[key];
      if (group != null) {
        _groups[key] = entry.copyWith(group: group, open: true);
      } else if (entry.treatment == null) {
        _groups.remove(key);
      } else {
        _groups[key] = entry.copyWith(open: false);
      }
    }
    for (final MapEntry(:key, value: group) in byKey.entries) {
      _groups.putIfAbsent(
        key,
        () => TacticalExcelGroupEntry(
          group: group,
          treatment: null,
          applyAll: true,
          open: true,
        ),
      );
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
