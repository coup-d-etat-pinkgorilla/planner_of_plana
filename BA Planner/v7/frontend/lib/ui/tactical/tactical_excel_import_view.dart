// FE9-f: 엑셀 가져오기 모달의 위젯 없는 모델(시안 Tactical-Import-Excel, G 보고서 §5).
//
// - 열 연결 칸 8개(날짜 · 공격/방어 · 상대 유저 · 상대 덱 6칸 · 내 덱 6칸 · 승/패 · 시도 횟수 · 메모, 시즌은 연결했을 때만 아홉째).
//   미리보기 응답에 머리글 글자가 없어 열 글자(A, B, …)만 보인다.
// - 문자열 표 한 줄: 원문 · 나온 곳 · 플래너가 본 것(이슈 코드) · 처리 방법 · 근거 · "모두 적용". 처리 방법은 필드마다 보낼 수 있는
//   것만(필수 필드에 무시 · 메모를 고르면 다시 미해결이 되므로 두지 않는다). 시안 범례 7종 → resolution 행동:
//   학생으로 연결 · 기존 상대로 합치기 · 결과 · 시도로 나누기 = `value`, 빈칸으로 두기 = `wildcard`(슬롯만), 메모로 옮기기 = `notes`,
//   이 칸 무시 = `ignore`, 이 행 건너뛰기 = `skip`. 시안에 없는 명시 값(새 상대로 저장 · 결과 승/패 · 공격/방어 · 시도 n회)을 더한다.
// - 미리보기 줄: 결정이 필요한 행(겹침 · 행 이슈)을 먼저, 그다음 가져올 기록 몇 줄(처리 방법이 적용된 분홍 줄 먼저).
import 'dart:convert';

import '../../services/tactical_v2_service.dart';
import '../../tactical/tactical_excel_import_controller.dart';

/// 1부터 센 열 → 엑셀 열 글자(1 → A, 27 → AA).
String tacticalExcelColumnLetter(int column) {
  var value = column;
  var text = '';
  while (value > 0) {
    final rest = (value - 1) % 26;
    text = String.fromCharCode(65 + rest) + text;
    value = (value - 1) ~/ 26;
  }
  return text;
}

const _slotPositions = ['1번', '2번', '3번', '4번', 'SP1', 'SP2'];

String _slotPosition(String field) {
  final parts = field.split('_');
  final index = int.parse(parts[2]) - 1;
  return _slotPositions[parts[1] == 'striker' ? index : 4 + index];
}

/// 필드가 나온 곳(시안 "상대 덱 4번" · "결과" · "상대").
String tacticalExcelFieldPlace(String field) {
  if (tacticalExcelSlotFields.contains(field)) {
    final side = field.startsWith('own_') ? '내 덱' : '상대 덱';
    return '$side ${_slotPosition(field)}';
  }
  return switch (field) {
    'date' => '날짜',
    'kind' => '구분',
    'opponent' => '상대',
    'season' => '시즌',
    'result' => '결과',
    'attempts' => '시도',
    'notes' => '메모',
    _ => field,
  };
}

/// 열 연결 칸 하나("A" → "날짜").
typedef TacticalExcelColumnTile = ({String id, String columns, String label});

/// 연결한 열 → 칸 8개(시즌을 연결했으면 9개). 덱은 여섯 열이 이어지면 "D–I", 아니면 글자를 잇고 없으면 '—'.
List<TacticalExcelColumnTile> tacticalExcelColumnTiles(
  TacticalExcelColumnMapping mapping,
) {
  final columns = mapping.columns;
  String single(String field) {
    final column = columns[field];
    return column == null ? '—' : tacticalExcelColumnLetter(column);
  }

  String deck(String side) {
    final fields = [
      for (final field in tacticalExcelSlotFields)
        if (field.startsWith('${side}_')) field,
    ];
    final values = [for (final field in fields) columns[field]];
    final known = values.whereType<int>().toList();
    if (known.isEmpty) return '—';
    final consecutive =
        known.length == values.length &&
        [
          for (var i = 1; i < known.length; i++) known[i] == known[i - 1] + 1,
        ].every((item) => item);
    if (consecutive) {
      return '${tacticalExcelColumnLetter(known.first)}–'
          '${tacticalExcelColumnLetter(known.last)}';
    }
    return [
      for (final value in values)
        value == null ? '—' : tacticalExcelColumnLetter(value),
    ].join(' · ');
  }

  return [
    (id: 'date', columns: single('date'), label: '날짜'),
    (id: 'kind', columns: single('kind'), label: '공격 / 방어'),
    (id: 'opponent', columns: single('opponent'), label: '상대 유저'),
    (id: 'opponent-deck', columns: deck('opponent'), label: '상대 덱 6칸'),
    (id: 'own-deck', columns: deck('own'), label: '내 덱 6칸'),
    (id: 'result', columns: single('result'), label: '승 / 패'),
    (id: 'attempts', columns: single('attempts'), label: '시도 횟수'),
    (id: 'notes', columns: single('notes'), label: '메모'),
    if (columns.containsKey('season'))
      (id: 'season', columns: single('season'), label: '시즌'),
  ];
}

/// 열 바꾸기 편집기의 필드 이름(19).
String tacticalExcelFieldLabel(String field) => switch (field) {
  'date' => '날짜',
  'kind' => '공격 / 방어',
  'opponent' => '상대 유저',
  'season' => '시즌',
  'result' => '승 / 패',
  'attempts' => '시도 횟수',
  'notes' => '메모',
  _ => tacticalExcelFieldPlace(field),
};

/// 원문 칸 글자(빈 글자는 "(빈칸)", 모르는 값은 '—').
String tacticalExcelRawText(Object? raw) => switch (raw) {
  null => '—',
  final String text when text.trim().isEmpty => '(빈칸)',
  final String text => text,
  _ => '$raw',
};

const _blankMarks = {'?', '-', '—', 'x', 'X', '？'};

/// "플래너가 본 것"(이슈 코드 → 문구).
String tacticalExcelGroupReading(TacticalExcelStringGroup group) {
  final raw = group.raw;
  final hasSuggestion = group.suggestions.isNotEmpty;
  return switch (group.code) {
    'student_unknown' when raw is String && _blankMarks.contains(raw.trim()) =>
      '빈칸 표시로 보임',
    'student_unknown' => '학생 이름으로 읽지 못함',
    'opponent_resolution_required' when hasSuggestion => '기존 상대와 이름이 같음',
    'opponent_resolution_required' => '처음 보는 상대',
    'saved_opponent_identity_missing' => '저장한 규칙의 상대가 없음',
    'opponent_identity_invalid' || 'opponent_name_required' => '상대 이름으로 읽지 못함',
    'opponent_alias_required' => '저장된 상대 이름과 다름',
    'result_resolution_required' when hasSuggestion => '결과와 시도 횟수가 섞임',
    'result_resolution_required' => '승 · 패로 읽지 못함',
    'positive_attempts_required' => '시도 횟수로 읽지 못함',
    'kind_required' => '공격 · 방어로 읽지 못함',
    'date_required' || 'date_invalid' => '날짜로 읽지 못함',
    'timezone_required' => '시간대가 없는 시각',
    'text_required' => '글자로 읽지 못함',
    final code => '확인 필요($code)',
  };
}

/// 처리 방법 메뉴 한 줄의 특수 동작(학생 검색 · 새 상대는 고를 때 값을 만든다).
enum TacticalExcelOptionSpecial { none, searchStudent, newOpponent }

/// 처리 방법 메뉴 한 줄.
typedef TacticalExcelOption = ({
  String id,
  String label,
  TacticalExcelTreatment? treatment,
  TacticalExcelOptionSpecial special,
});

TacticalExcelOption _option(TacticalExcelTreatment treatment, String label) => (
  id: treatment.id,
  label: label,
  treatment: treatment,
  special: TacticalExcelOptionSpecial.none,
);

/// 그룹에 보낼 수 있는 처리 방법(제안이 먼저). [studentName]은 학생 ID → 표시 이름.
List<TacticalExcelOption> tacticalExcelTreatmentOptions(
  TacticalExcelStringGroup group, {
  required String Function(String id) studentName,
}) {
  final field = group.field;
  final raw = group.raw;
  const skip = TacticalExcelTreatment(TacticalExcelTreatmentKind.skip);
  if (tacticalExcelSlotFields.contains(field)) {
    return [
      for (final suggestion
          in group.suggestions.whereType<TacticalExcelStudentSuggestion>())
        _option(
          TacticalExcelTreatment(
            TacticalExcelTreatmentKind.student,
            text: suggestion.studentId,
            label: suggestion.displayName,
          ),
          '학생: ${suggestion.displayName}',
        ),
      (
        id: 'student-search',
        label: '학생으로 연결 (검색)',
        treatment: null,
        special: TacticalExcelOptionSpecial.searchStudent,
      ),
      _option(
        const TacticalExcelTreatment(TacticalExcelTreatmentKind.wildcard),
        '빈칸으로 두기',
      ),
      _option(
        const TacticalExcelTreatment(TacticalExcelTreatmentKind.notes),
        '메모로 옮기기',
      ),
      _option(
        const TacticalExcelTreatment(TacticalExcelTreatmentKind.ignore),
        '이 칸 무시',
      ),
      _option(skip, '이 행 건너뛰기'),
    ];
  }
  return switch (field) {
    'opponent' => [
      for (final suggestion
          in group.suggestions.whereType<TacticalExcelOpponentSuggestion>())
        _option(
          TacticalExcelTreatment(
            TacticalExcelTreatmentKind.opponentExisting,
            text: suggestion.identityId,
            label: suggestion.displayName,
          ),
          "기존 상대 '${suggestion.displayName}'로 합치기",
        ),
      if (raw is String && raw.trim().isNotEmpty)
        (
          id: 'opponent-new',
          label: "새 상대 '${raw.trim()}'로 저장",
          treatment: null,
          special: TacticalExcelOptionSpecial.newOpponent,
        ),
      _option(skip, '이 행 건너뛰기'),
    ],
    'result' => [
      for (final suggestion
          in group.suggestions.whereType<TacticalExcelResultSuggestion>())
        _option(
          TacticalExcelTreatment(
            TacticalExcelTreatmentKind.split,
            text: suggestion.result,
            count: suggestion.attemptCount,
          ),
          tacticalExcelSplitLabel(suggestion.result, suggestion.attemptCount),
        ),
      for (final result in const ['win', 'loss'])
        _option(
          TacticalExcelTreatment(
            TacticalExcelTreatmentKind.result,
            text: result,
          ),
          "결과 '${_resultText(result)}'로 읽기",
        ),
      _option(skip, '이 행 건너뛰기'),
    ],
    'kind' => [
      for (final kind in const ['attack', 'defense'])
        _option(
          TacticalExcelTreatment(TacticalExcelTreatmentKind.kind, text: kind),
          kind == 'attack' ? '공격으로 읽기' : '방어로 읽기',
        ),
      _option(skip, '이 행 건너뛰기'),
    ],
    'attempts' => [
      for (var count = 1; count <= 9; count++)
        _option(
          TacticalExcelTreatment(
            TacticalExcelTreatmentKind.attempts,
            count: count,
          ),
          '시도 $count회로 읽기',
        ),
      _option(skip, '이 행 건너뛰기'),
    ],
    'season' || 'notes' => [
      if (field == 'season')
        _option(
          const TacticalExcelTreatment(TacticalExcelTreatmentKind.notes),
          '메모로 옮기기',
        ),
      _option(
        const TacticalExcelTreatment(TacticalExcelTreatmentKind.ignore),
        '이 칸 무시',
      ),
      _option(skip, '이 행 건너뛰기'),
    ],
    // 날짜: 엑셀에서 고칠 값이라 건너뛰기만 보낼 수 있다(지금 시각으로 채우지 않는다).
    _ => [_option(skip, '이 행 건너뛰기')],
  };
}

String _resultText(String? result) => switch (result) {
  'win' => '승',
  'loss' => '패',
  _ => '—',
};

/// "결과 '승' + 시도 2회로 나누기"(시안 문구).
String tacticalExcelSplitLabel(String? result, int? count) =>
    "결과 '${_resultText(result)}' + 시도 ${count ?? '—'}회로 나누기";

/// 고른 처리 방법의 드롭다운 글자.
String tacticalExcelTreatmentLabel(
  TacticalExcelTreatment treatment, {
  required String Function(String id) studentName,
}) => switch (treatment.kind) {
  TacticalExcelTreatmentKind.student =>
    '학생: ${treatment.label ?? studentName(treatment.text ?? '')}',
  TacticalExcelTreatmentKind.opponentExisting =>
    "기존 상대 '${treatment.label ?? '—'}'로 합치기",
  TacticalExcelTreatmentKind.opponentNew =>
    "새 상대 '${treatment.label ?? '—'}'로 저장",
  TacticalExcelTreatmentKind.split => tacticalExcelSplitLabel(
    treatment.text,
    treatment.count,
  ),
  TacticalExcelTreatmentKind.result =>
    "결과 '${_resultText(treatment.text)}'로 읽기",
  TacticalExcelTreatmentKind.kind =>
    treatment.text == 'attack' ? '공격으로 읽기' : '방어로 읽기',
  TacticalExcelTreatmentKind.attempts => '시도 ${treatment.count}회로 읽기',
  TacticalExcelTreatmentKind.wildcard => '빈칸으로 두기',
  TacticalExcelTreatmentKind.notes => '메모로 옮기기',
  TacticalExcelTreatmentKind.ignore => '이 칸 무시',
  TacticalExcelTreatmentKind.skip => '이 행 건너뛰기',
};

/// "근거" 칸(시안 "추천 · 이름 일부 일치" · "빗금 빈칸으로 저장" · "규칙: 괄호 안 숫자 = 시도").
String tacticalExcelEvidence(TacticalExcelGroupEntry entry) {
  final treatment = entry.treatment;
  final suggestions = entry.group.suggestions;
  if (treatment == null) {
    return suggestions.isEmpty ? '처리 방법을 골라 주십시오' : '추천 있음 · 확인해 주십시오';
  }
  final suggested = suggestions.any(
    (item) => switch (item) {
      TacticalExcelStudentSuggestion(:final studentId) =>
        treatment.kind == TacticalExcelTreatmentKind.student &&
            treatment.text == studentId,
      TacticalExcelOpponentSuggestion(:final identityId) =>
        treatment.kind == TacticalExcelTreatmentKind.opponentExisting &&
            treatment.text == identityId,
      TacticalExcelResultSuggestion(:final result, :final attemptCount) =>
        treatment.kind == TacticalExcelTreatmentKind.split &&
            treatment.text == result &&
            treatment.count == attemptCount,
    },
  );
  final text = switch (treatment.kind) {
    TacticalExcelTreatmentKind.student when suggested => '추천 · 이름이 비슷함',
    TacticalExcelTreatmentKind.opponentExisting when suggested =>
      '추천 · 같은 이름의 기존 상대',
    TacticalExcelTreatmentKind.split => '규칙: 괄호 안 숫자 = 시도',
    TacticalExcelTreatmentKind.opponentNew => '처음 보는 상대로 저장',
    TacticalExcelTreatmentKind.wildcard => '빗금 빈칸으로 저장',
    TacticalExcelTreatmentKind.notes => '원문을 메모 끝에 붙임',
    TacticalExcelTreatmentKind.ignore => '이 칸을 읽지 않음',
    TacticalExcelTreatmentKind.skip => '이 행을 가져오지 않음',
    _ => '직접 고름',
  };
  return entry.open ? '$text · 아직 풀리지 않음' : text;
}

/// 표 줄 화면 키 조각("<필드>-<원문>").
String tacticalExcelGroupId(TacticalExcelStringGroup group) =>
    '${group.field}-${tacticalExcelRawText(group.raw)}';

/// 그룹이 나온 칸 수 문구("상대 덱 4번 · 2칸").
String tacticalExcelGroupPlaces(TacticalExcelStringGroup group) =>
    '${tacticalExcelFieldPlace(group.field)} · ${group.count}칸';

// --- 미리보기 줄 ---------------------------------------------------------------

/// 미리보기 줄 표시 상태.
enum TacticalExcelRowTone {
  /// 처리 방법이 적용된 가져올 기록(분홍 줄 · "처리 반영").
  treated,

  /// 그대로 가져올 기록("그대로").
  plain,

  /// 이미 있는 기록을 덮어쓴다.
  overwrite,

  /// 건너뛴다(겹침 건너뛰기 · 행 건너뛰기).
  skipped,

  /// 겹치는 기록이 있어 결정이 필요하다.
  conflict,

  /// 해석하지 못한 칸이 남았다(표의 문자열 밖 행 이슈).
  unresolved,
}

/// 미리보기 줄 하나.
typedef TacticalExcelPreviewItem = ({
  TacticalExcelPreviewRow row,
  TacticalExcelRowTone tone,

  /// 행 결정을 고를 수 있는가(겹침 · 행 이슈 · 이미 결정한 행).
  bool decidable,

  /// 겹친 기존 기록(덮어쓰기 대상이 하나일 때만 덮어쓰기를 고를 수 있다).
  TacticalExcelConflict? conflict,
});

/// [choices]의 resolution이 [row] 칸에 적용됐는가(행 지정 · 전역 모두).
bool tacticalExcelRowTreated(
  TacticalExcelPreviewRow row,
  TacticalExcelImportChoices? choices,
) {
  if (choices == null) return false;
  for (final resolution in choices.resolutions) {
    final target = resolution.row;
    if (target != null && target != row.rowNumber) continue;
    if (row.rawCells.any(
      (cell) => cell.field == resolution.field && cell.rawKey == resolution.raw,
    )) {
      return true;
    }
  }
  return false;
}

/// 미리보기 줄: 결정이 필요한 행 전부 + 가져올 기록 [sampleLimit]줄(분홍 먼저). [openGroupKeys]에 든 이슈는 표에서 다루므로
/// 행 이슈로 따로 보이지 않는다.
List<TacticalExcelPreviewItem> tacticalExcelPreviewItems(
  TacticalExcelPreview preview,
  TacticalExcelImportChoices? choices, {
  required Map<int, TacticalExcelRowChoice> rowChoices,
  required Set<String> openGroupKeys,
  int sampleLimit = 3,
}) {
  final conflicts = {for (final item in preview.conflicts) item.rowId: item};
  final decisions = <TacticalExcelPreviewItem>[];
  final treated = <TacticalExcelPreviewItem>[];
  final plain = <TacticalExcelPreviewItem>[];
  for (final row in preview.rows) {
    final conflict = conflicts[row.rowId];
    final chosen = rowChoices.containsKey(row.rowNumber);
    switch (row.status) {
      case 'conflict':
        decisions.add((
          row: row,
          tone: TacticalExcelRowTone.conflict,
          decidable: true,
          conflict: conflict,
        ));
      case 'conflict_skipped' || 'skipped' when conflict != null || chosen:
        decisions.add((
          row: row,
          tone: TacticalExcelRowTone.skipped,
          decidable: true,
          conflict: conflict,
        ));
      case 'overwrite':
        decisions.add((
          row: row,
          tone: TacticalExcelRowTone.overwrite,
          decidable: true,
          conflict: conflict,
        ));
      case 'unresolved':
        final issueKeys = [
          for (final issue in row.issues)
            if (issue.field != null && issue.rawKey != null)
              jsonEncode([issue.field, issue.rawKey, issue.code]),
        ];
        final covered =
            row.issues.isNotEmpty &&
            issueKeys.length == row.issues.length &&
            issueKeys.every(openGroupKeys.contains);
        if (!covered) {
          decisions.add((
            row: row,
            tone: TacticalExcelRowTone.unresolved,
            decidable: true,
            conflict: conflict,
          ));
        }
      case 'eligible':
        final item = (
          row: row,
          tone: tacticalExcelRowTreated(row, choices)
              ? TacticalExcelRowTone.treated
              : TacticalExcelRowTone.plain,
          decidable: conflict != null || chosen,
          conflict: conflict,
        );
        if (item.decidable) {
          decisions.add(item);
        } else if (item.tone == TacticalExcelRowTone.treated) {
          treated.add(item);
        } else {
          plain.add(item);
        }
    }
  }
  return [
    ...decisions,
    ...[...treated, ...plain].take(sampleLimit),
  ];
}

/// 미리보기 줄 결과 글자("승 · 2회", 시도 없으면 결과만, 해석 전 '—').
String tacticalExcelResultText(TacticalMatchInputV2? match) {
  if (match == null) return '—';
  return '${_resultText(match.result)} · ${match.attemptCount}회';
}

/// 미리보기 줄 날짜("9/22", KST 기준, 모르면 '—').
String tacticalExcelDateText(TacticalMatchInputV2? match) {
  final text = match?.occurredAt;
  final parsed = text == null ? null : DateTime.tryParse(text);
  if (parsed == null) return '—';
  final kst = parsed.toUtc().add(const Duration(hours: 9));
  return '${kst.month}/${kst.day}';
}

/// 행 결정 글자.
String tacticalExcelRowChoiceLabel(String action) => switch (action) {
  'skip' => '건너뛰기',
  'keep_separate' => '따로 두기',
  'overwrite' => '덮어쓰기',
  _ => action,
};
