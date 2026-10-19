import '../../../services/app_service.dart';
import '../../../services/repository_service.dart';
import '../../../services/scanner_service.dart';
import '../scan_student_review_logic.dart';

/// 학생 결과 검토 보드의 순수 규칙(FE8-g4a, 시안 Scan-Student-Review, FD-144). 분류는 종료 후보 · 지금 확정값 ·
/// 실제 evidence를 비교한 CF 투영이다(FB-10 고정 선언 — 백엔드 분류 enum · 진행 중 집계를 가정하지 않는다).
/// 문제 판정 · 계산값 · 인연 행은 FE8-f1 `scan_student_review_logic.dart`를 그대로 쓴다.

/// 학생 한 명의 분류.
enum ScanReviewCategory { needsReview, changed, newStudent, unchanged }

/// 분류 버튼(시안 `전체 / 확인 필요 / 바뀐 학생 / 새 학생 / 그대로`).
enum ScanReviewFilter {
  all('전체'),
  needsReview('확인 필요'),
  changed('바뀐 학생'),
  newStudent('새 학생'),
  unchanged('그대로');

  const ScanReviewFilter(this.label);

  final String label;

  bool includes(ScanReviewCategory category) => switch (this) {
    ScanReviewFilter.all => true,
    ScanReviewFilter.needsReview => category == ScanReviewCategory.needsReview,
    ScanReviewFilter.changed => category == ScanReviewCategory.changed,
    ScanReviewFilter.newStudent => category == ScanReviewCategory.newStudent,
    ScanReviewFilter.unchanged => category == ScanReviewCategory.unchanged,
  };
}

/// 확인 필요로 둔 이유(앞일수록 먼저).
enum ScanReviewReason {
  /// 적용 실패 오류가 있다.
  applyFailed,

  /// 화면에서 고친 값에 오류가 있다.
  invalidEdit,

  /// 안전하지 않은 근거 상태(신뢰도 낮음 · 계산 불일치 · 부분 판독 등)가 있다.
  lowConfidence,

  /// 백엔드가 검토를 요구했다(`review_required`).
  reviewRequired,

  /// 값이 바뀌었지만 계산 검증(`student_stat_validation` = `verified`)이 없다. FD-144의 바뀐 학생은 계산 일치가 조건이다.
  calcUnconfirmed,
}

/// 계산 검증 근거 필드(백엔드 `student_candidate_validation`).
const scanReviewStatValidationField = 'student_stat_validation';

/// 폴백 crop을 싣는 근거 필드(FB-10c, FD-145 — 이 두 필드의 원 BasicInfo ROI에만 있다).
const scanReviewFallbackFields = {
  'weapon_level_fallback',
  'weapon_star_fallback',
};

/// 값 필드 표시 순서(목록 칩 · 상세 · 요약이 같은 순서를 쓴다). 여기에 없는 필드는 뒤에 이름순.
const scanReviewFieldOrder = <String>[
  'level',
  'student_star',
  'weapon_state',
  'weapon_star',
  'weapon_level',
  'ex_skill',
  'skill1',
  'skill2',
  'skill3',
  'equip1',
  'equip2',
  'equip3',
  'equip1_level',
  'equip2_level',
  'equip3_level',
  'equip4',
  'bond_rank',
  'stat_hp',
  'stat_atk',
  'stat_heal',
  'combat_hp',
  'combat_atk',
  'combat_def',
  'combat_heal',
];

/// 필드 이름(시안 칩 글자: `레벨` · `EX 스킬` · `스킬 2` · `장비 2` · `인연` · `전용무기 레벨`).
const scanReviewFieldLabels = <String, String>{
  'level': '레벨',
  'student_star': '성급',
  'weapon_state': '전용무기',
  'weapon_star': '전용무기 성급',
  'weapon_level': '전용무기 레벨',
  'ex_skill': 'EX 스킬',
  'skill1': '스킬 1',
  'skill2': '스킬 2',
  'skill3': '스킬 3',
  'equip1': '장비 1',
  'equip2': '장비 2',
  'equip3': '장비 3',
  'equip1_level': '장비 1 레벨',
  'equip2_level': '장비 2 레벨',
  'equip3_level': '장비 3 레벨',
  'equip4': '애장품',
  'bond_rank': '인연',
  'stat_hp': '능력 개방 HP',
  'stat_atk': '능력 개방 ATK',
  'stat_heal': '능력 개방 HEAL',
  'combat_hp': 'HP',
  'combat_atk': '공격력',
  'combat_def': '방어력',
  'combat_heal': '치유력',
};

/// 주 버튼 부제에 쓰는 짧은 이름(시안 `전용무기 Lv.30 · 레벨 90 · EX 4`).
const _shortLabels = <String, String>{'weapon_level': '전용무기', 'ex_skill': 'EX'};

/// 값 묶음(일괄 행 요약 `레벨 4 · 스킬 7 · 장비 4 · 인연 1`, 새 학생 칩 `레벨 · 성급 · 스킬`).
const scanReviewValueGroups = <(String, Set<String>)>[
  ('레벨', {'level'}),
  ('성급', {'student_star'}),
  ('전용무기', {'weapon_state', 'weapon_star', 'weapon_level'}),
  ('스킬', {'ex_skill', 'skill1', 'skill2', 'skill3'}),
  (
    '장비',
    {
      'equip1',
      'equip2',
      'equip3',
      'equip1_level',
      'equip2_level',
      'equip3_level',
      'equip4',
    },
  ),
  ('인연', {'bond_rank'}),
  ('능력 개방', {'stat_hp', 'stat_atk', 'stat_heal'}),
  ('능력치', {'combat_hp', 'combat_atk', 'combat_def', 'combat_heal'}),
];

String scanReviewFieldLabel(String field) =>
    scanReviewFieldLabels[field] ?? field;

String scanReviewGroupOf(String field) {
  for (final (label, fields) in scanReviewValueGroups) {
    if (fields.contains(field)) return label;
  }
  return '기타';
}

int _fieldRank(String field) {
  final index = scanReviewFieldOrder.indexOf(field);
  return index < 0 ? scanReviewFieldOrder.length : index;
}

/// [fields]를 표시 순서로 정렬한다.
List<String> scanReviewOrderedFields(Iterable<String> fields) =>
    fields.toSet().toList()..sort((left, right) {
      final rank = _fieldRank(left).compareTo(_fieldRank(right));
      return rank != 0 ? rank : left.compareTo(right);
    });

/// 천 단위 쉼표(시안 `52,480`).
String scanReviewGroupedInt(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// 값 글자. 모르는 값은 '—'.
String scanReviewValueText(String field, Object? value) {
  if (value == null) return '—';
  if (value is int) {
    return switch (field) {
      'student_star' || 'weapon_star' => '★$value',
      'weapon_level' ||
      'equip1_level' ||
      'equip2_level' ||
      'equip3_level' => 'Lv.$value',
      'combat_hp' ||
      'combat_atk' ||
      'combat_def' ||
      'combat_heal' => scanReviewGroupedInt(value),
      _ => '$value',
    };
  }
  if (field == 'weapon_state') {
    return switch (value) {
      'weapon_unlocked' => '해금',
      'weapon_locked' => '잠김',
      _ => '$value',
    };
  }
  final text = '$value';
  return text.isEmpty ? '—' : text;
}

/// 목록 · 상세에 비교할 수 있는 값(숫자 · 글자). 지도 · 목록 값(`form_combat_stats`)과 모르는 값은 뺀다.
bool _comparable(Object? value) => value is num || value is String;

/// 바뀐 값 하나. [newStudent]면 이전 값은 `없음`이다(시안 `레벨 없음 → 85`).
class ScanReviewChange {
  const ScanReviewChange({
    required this.field,
    required this.before,
    required this.after,
    this.newStudent = false,
  });

  final String field;
  final Object? before;
  final Object? after;
  final bool newStudent;

  String get label => scanReviewFieldLabel(field);
  String get beforeText =>
      newStudent ? '없음' : scanReviewValueText(field, before);
  String get afterText => scanReviewValueText(field, after);
}

/// 후보 값과 확정값의 차이(표시 순서). [current]가 null이면 새 학생 — 읽은 값 전부가 바뀐 값이다.
/// 읽지 못한 값(null)은 바뀐 값이 아니다(0이나 지움으로 바꾸지 않는다).
List<ScanReviewChange> scanReviewChanges({
  required Map<String, dynamic> scanned,
  required Map<String, dynamic>? current,
}) => [
  for (final field in scanReviewOrderedFields(scanned.keys))
    if (_comparable(scanned[field]) &&
        (current == null || current[field] != scanned[field]))
      ScanReviewChange(
        field: field,
        before: current?[field],
        after: scanned[field],
        newStudent: current == null,
      ),
];

/// 목록 칩 하나(시안 `같이 바뀜 · 레벨 85 → 90`, 새 학생 `스킬 없음 → 5 · 7 · 7 · 4`).
class ScanReviewChip {
  const ScanReviewChip({
    required this.label,
    required this.beforeText,
    required this.afterText,
  });

  final String label;
  final String beforeText;
  final String afterText;
}

/// 근거 필드 → 값 필드(`weapon_level_fallback` → `weapon_level`). 계산 검증 근거는 값 필드가 아니다(null).
String? scanReviewEvidenceValueField(String evidenceField) {
  if (evidenceField == scanReviewStatValidationField) return null;
  const suffix = '_fallback';
  return evidenceField.endsWith(suffix)
      ? evidenceField.substring(0, evidenceField.length - suffix.length)
      : evidenceField;
}

/// 학생 한 명의 검토 항목.
class ScanReviewEntry {
  const ScanReviewEntry({
    required this.candidate,
    required this.category,
    required this.changes,
    required this.flaggedFields,
    required this.calcMatched,
    required this.lowConfidence,
    this.reason,
  });

  final ScannerCandidate candidate;
  final ScanReviewCategory category;
  final List<ScanReviewChange> changes;

  /// 안전하지 않은 근거가 붙은 값 필드(상세의 `확인 필요` 표시).
  final Set<String> flaggedFields;

  /// 계산 검증 근거가 `verified`다(백엔드 기준: 화면과 ±2 안 — 시안 `계산값이 화면과 일치`).
  final bool calcMatched;

  /// 안전하지 않은 근거가 있다(행 칩 `신뢰도 낮음`).
  final bool lowConfidence;

  /// 확인 필요인 이유(그 밖의 분류는 null).
  final ScanReviewReason? reason;

  String get id => candidate.id;
  String get studentId => scanStudentId(candidate);

  /// 확인 필요 행 첫 줄에 크게 보이는 값: 확인이 필요한 필드 중 처음, 없으면 첫 바뀐 값.
  ScanReviewChange? get primary {
    for (final change in changes) {
      if (flaggedFields.contains(change.field)) return change;
    }
    return changes.isEmpty ? null : changes.first;
  }

  /// 행 칩 글자 · 색 이름(시안 `.chip.wn 신뢰도 낮음` · `.chip.ok 일치` · `.chip.wn 재검증 필요`).
  String get chipLabel => switch (category) {
    ScanReviewCategory.needsReview => lowConfidence ? '신뢰도 낮음' : '확인 필요',
    ScanReviewCategory.changed => '일치',
    ScanReviewCategory.newStudent => '재검증 필요',
    ScanReviewCategory.unchanged => '그대로',
  };

  /// 폴백 crop 근거(FD-145). 없으면 null.
  ScannerFieldEvidence? get fallbackEvidence {
    for (final evidence in candidate.evidence) {
      if (scanReviewFallbackFields.contains(evidence.field)) return evidence;
    }
    return null;
  }
}

/// [candidate]를 분류한다(FD-144). 문제(확인 필요) > 새 학생 > 그대로 > 바뀐 학생(계산 일치) > 확인 필요(계산 미확인).
ScanReviewEntry scanReviewEntryFor(
  ScannerCandidate candidate, {
  required ConfirmedStudentState? current,
  bool applyFailed = false,
  bool invalidEdit = false,
}) {
  final changes = scanReviewChanges(
    scanned: scanStudentValues(candidate),
    current: current?.values,
  );
  final unsafe = [
    for (final evidence in candidate.evidence)
      if (!scanStudentSafeEvidenceStatuses.contains(evidence.status)) evidence,
  ];
  final flagged = <String>{
    for (final evidence in unsafe)
      ?scanReviewEvidenceValueField(evidence.field),
  };
  final calcMatched = candidate.evidence.any(
    (evidence) =>
        evidence.field == scanReviewStatValidationField &&
        evidence.status == 'verified',
  );
  final problem = scanStudentCandidateHasProblem(
    candidate,
    applyFailed: applyFailed,
    invalidEdit: invalidEdit,
  );
  ScanReviewEntry entry(ScanReviewCategory category, [ScanReviewReason? why]) =>
      ScanReviewEntry(
        candidate: candidate,
        category: category,
        changes: changes,
        flaggedFields: flagged,
        calcMatched: calcMatched,
        lowConfidence: unsafe.isNotEmpty,
        reason: why,
      );
  if (problem) {
    return entry(
      ScanReviewCategory.needsReview,
      applyFailed
          ? ScanReviewReason.applyFailed
          : invalidEdit
          ? ScanReviewReason.invalidEdit
          : unsafe.isNotEmpty
          ? ScanReviewReason.lowConfidence
          : ScanReviewReason.reviewRequired,
    );
  }
  if (current == null) return entry(ScanReviewCategory.newStudent);
  if (changes.isEmpty) return entry(ScanReviewCategory.unchanged);
  if (calcMatched) return entry(ScanReviewCategory.changed);
  return entry(
    ScanReviewCategory.needsReview,
    ScanReviewReason.calcUnconfirmed,
  );
}

/// 보드 목록(같은 캐릭터의 의상을 이어 붙인 순서, FE8-f1 규칙).
List<ScanReviewEntry> scanReviewEntries({
  required List<ScannerCandidate> candidates,
  required Map<String, ConfirmedStudentState> currentStudents,
  required Map<String, StudentCatalogEntry> catalog,
  Map<String, String> candidateErrors = const {},
  Set<String> invalidEditIds = const {},
}) => [
  for (final candidate in orderScanResultCandidatesByGroup(candidates, catalog))
    scanReviewEntryFor(
      candidate,
      current: currentStudents[scanStudentId(candidate)],
      applyFailed: candidateErrors.containsKey(candidate.id),
      invalidEdit: invalidEditIds.contains(candidate.id),
    ),
];

/// 분류 버튼 숫자.
Map<ScanReviewFilter, int> scanReviewCounts(List<ScanReviewEntry> entries) => {
  for (final filter in ScanReviewFilter.values)
    filter: entries.where((entry) => filter.includes(entry.category)).length,
};

List<ScanReviewEntry> scanReviewEntriesIn(
  List<ScanReviewEntry> entries,
  ScanReviewCategory category,
) => [
  for (final entry in entries)
    if (entry.category == category) entry,
];

/// 일괄 적용 대상: 바뀐 학생(문제 없음 · 계산 일치) 전부, 목록 순서.
List<ScanReviewEntry> scanReviewBulkTargets(List<ScanReviewEntry> entries) =>
    scanReviewEntriesIn(entries, ScanReviewCategory.changed);

/// 값 묶음별 건수 요약(시안 `값 16건 · 레벨 4 · 스킬 7 · 장비 4 · 인연 1`).
String scanReviewChangeSummary(Iterable<ScanReviewChange> changes) {
  final list = changes.toList(growable: false);
  final counts = <String, int>{};
  for (final change in list) {
    counts.update(
      scanReviewGroupOf(change.field),
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }
  final order = [for (final (label, _) in scanReviewValueGroups) label, '기타'];
  return [
    '값 ${list.length}건',
    for (final label in order)
      if (counts[label] case final count?) '$label $count',
  ].join(' · ');
}

/// 행 칩. 새 학생은 값 묶음별로 합쳐 `없음 → 값 · 값`, 그 밖은 필드마다.
List<ScanReviewChip> scanReviewChips(ScanReviewEntry entry) {
  if (entry.category != ScanReviewCategory.newStudent) {
    return [
      for (final change in entry.changes)
        ScanReviewChip(
          label: change.label,
          beforeText: change.beforeText,
          afterText: change.afterText,
        ),
    ];
  }
  final grouped = <String, List<ScanReviewChange>>{};
  for (final change in entry.changes) {
    grouped.putIfAbsent(scanReviewGroupOf(change.field), () => []).add(change);
  }
  return [
    for (final MapEntry(key: label, value: changes) in grouped.entries)
      ScanReviewChip(
        label: label,
        beforeText: '없음',
        afterText: changes.map((change) => change.afterText).join(' · '),
      ),
  ];
}

/// 새 학생 행 첫 줄 설명(시안 `레벨 · 성급 · 스킬 · 장비 전체`).
String scanReviewNewStudentScope(ScanReviewEntry entry) {
  final groups = <String>[];
  for (final change in entry.changes) {
    final group = scanReviewGroupOf(change.field);
    if (!groups.contains(group)) groups.add(group);
  }
  return groups.isEmpty ? '—' : '${groups.join(' · ')} 전체';
}

/// 주 버튼 글자(시안 `노아 3건 적용` / `전용무기 Lv.30 · 레벨 90 · EX 4 → 확정값 · 나머지 값은 그대로`).
({String title, String subtitle}) scanReviewApplyLabel(
  String name,
  ScanReviewEntry entry,
) {
  final shown = entry.changes.take(3).map((change) {
    final label = _shortLabels[change.field] ?? change.label;
    return '$label ${change.afterText}';
  }).toList();
  final more = entry.changes.length - shown.length;
  final values = shown.isEmpty
      ? '—'
      : '${shown.join(' · ')}${more > 0 ? ' 외 $more건' : ''}';
  return (
    title: '$name ${entry.changes.length}건 적용',
    subtitle: '$values → 확정값 · 나머지 값은 그대로',
  );
}

/// 상세 주 버튼을 누를 수 있는가. 바뀐 학생은 바로, 새 학생은 이 보드에서 재검증한 revision이 계산 일치일 때만
/// (시안 `확정값이 없어 먼저 재검증합니다`), 확인 필요 · 그대로는 누를 수 없다(고쳐서 재검증하면 분류가 바뀐다).
bool scanReviewCanApply(ScanReviewEntry entry, {required bool revalidated}) =>
    switch (entry.category) {
      ScanReviewCategory.changed => true,
      ScanReviewCategory.newStudent => revalidated && entry.calcMatched,
      ScanReviewCategory.needsReview || ScanReviewCategory.unchanged => false,
    };

/// 계산 검증 근거의 `details[key]`(expected · observed · delta). 없으면 빈 맵.
Map<String, dynamic> scanReviewStatDetail(
  ScannerCandidate candidate,
  String key,
) {
  for (final evidence in candidate.evidence) {
    if (evidence.field != scanReviewStatValidationField) continue;
    final value = evidence.details?[key];
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return const {};
}

/// 폴백 카드 계산 줄(시안 `계산 공격력 5,812 = 화면 5,812`). 계산값 · 화면값이 실제 근거에 있을 때만, 없으면 null.
/// 같음/다름은 백엔드 판정(`verified` = 화면과 ±2 안)을 따른다.
({String text, bool matched})? scanReviewAttackLine(ScanReviewEntry entry) {
  final expected = scanReviewStatDetail(entry.candidate, 'expected');
  final observed = scanReviewStatDetail(entry.candidate, 'observed');
  final calculated = expected['AttackPower'];
  final screen = observed['AttackPower'];
  if (calculated is! num || screen is! num) return null;
  final matched = entry.calcMatched;
  return (
    text:
        '계산 공격력 ${scanReviewGroupedInt(calculated.round())} '
        '${matched ? '=' : '≠'} 화면 ${scanReviewGroupedInt(screen.round())}',
    matched: matched,
  );
}
