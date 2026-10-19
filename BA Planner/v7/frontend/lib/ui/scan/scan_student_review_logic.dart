import '../../services/app_service.dart';
import '../../services/scanner_service.dart';

/// 학생 스캔 결과 검토의 순수 규칙(FE8-f1). 위젯 상태 없이 후보 · 값만 받아 계산한다.
/// 검토 화면(지금 `ScanStudentReviewWorkspace`, 뒤에 FE8-g4 검토 보드)이 같은 규칙을 쓴다.

/// 문제로 보지 않는 근거 상태.
const Set<String> scanStudentSafeEvidenceStatuses = {
  'ok',
  'inferred',
  'skipped',
  'verified',
  'deferred',
  'shadow',
};

/// 레벨 90 · 5성 이상이면 비교 표에 늘 넣는 잠재 능력 필드.
const Set<String> scanStudentPotentialFields = {
  'stat_hp',
  'stat_atk',
  'stat_heal',
};

/// 원래 값이 정수가 아니어도 정수로만 받는 필드.
const Set<String> scanStudentIntegerFields = {
  'level',
  'bond_rank',
  'weapon_level',
  'equip1_level',
  'equip2_level',
  'equip3_level',
};

/// 계산값(`student_stat_validation` 근거의 expected · delta 키) → 비교 표 필드.
const Map<String, String> scanStudentStatToField = {
  'MaxHP': 'combat_hp',
  'AttackPower': 'combat_atk',
  'DefensePower': 'combat_def',
  'HealPower': 'combat_heal',
};

/// 상태 글자를 고를 때 앞에 오는 근거 상태(앞일수록 먼저).
const List<String> _statusPriority = [
  'suspicious',
  'dependency_missing',
  'partial',
  'failed',
  'uncertain',
  'region_missing',
];

String scanStudentId(ScannerCandidate candidate) =>
    candidate.payload['student_id'] as String? ?? 'unknown';

/// 후보가 읽은 값(복사본).
Map<String, dynamic> scanStudentValues(ScannerCandidate candidate) =>
    Map<String, dynamic>.from(candidate.payload['values'] as Map? ?? const {});

/// [applyFailed] = 적용 실패 오류가 있다. [invalidEdit] = 화면에서 고친 값에 오류가 있다.
bool scanStudentCandidateHasProblem(
  ScannerCandidate candidate, {
  required bool applyFailed,
  required bool invalidEdit,
}) =>
    candidate.reviewRequired ||
    applyFailed ||
    invalidEdit ||
    candidate.evidence.any(
      (evidence) => !scanStudentSafeEvidenceStatuses.contains(evidence.status),
    );

String scanStudentCandidateStatus(
  ScannerCandidate candidate, {
  required bool applyFailed,
  required bool invalidEdit,
}) {
  if (applyFailed) return 'apply failed';
  if (invalidEdit) return 'invalid edit';
  if (candidate.evidence.any((item) => item.status == 'deferred')) {
    return '다른 의상 랭크 적용 대기';
  }
  for (final priority in _statusPriority) {
    if (candidate.evidence.any((item) => item.status == priority)) {
      return priority.replaceAll('_', ' ');
    }
  }
  return candidate.reviewRequired ? 'review required' : 'verified';
}

Map<String, dynamic>? _statValidationDetail(
  ScannerCandidate candidate,
  String key,
) {
  for (final evidence in candidate.evidence) {
    if (evidence.field != 'student_stat_validation') continue;
    final value = evidence.details?[key];
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return null;
}

/// 계산한 전투 능력치(`MaxHP` 등 → 값). 없으면 빈 맵.
Map<String, dynamic> scanStudentExpectedStats(ScannerCandidate candidate) =>
    _statValidationDetail(candidate, 'expected') ?? const {};

/// 계산값과 읽은 값의 차이(`MaxHP` 등 → 값). 없으면 빈 맵.
Map<String, dynamic> scanStudentStatDelta(ScannerCandidate candidate) =>
    _statValidationDetail(candidate, 'delta') ?? const {};

/// 다른 의상 인연 보너스 행.
List<Map<String, dynamic>> scanStudentRelationshipContributions(
  ScannerCandidate candidate,
) {
  for (final evidence in candidate.evidence) {
    if (evidence.field != 'student_stat_validation') continue;
    final rows = evidence.details?['relationship_contributions'];
    if (rows is List) {
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
  }
  return const [];
}

/// 화면에서 인연 랭크를 받는 행: 보유한 다른 의상.
bool scanStudentIsOwnedAlternate(Map<String, dynamic> row) =>
    row['kind'] == 'alternate' && row['owned'] == true;

/// 인연 랭크 입력(1~100). 아니면 null.
int? scanStudentRelationshipRank(String raw) {
  final rank = int.tryParse(raw);
  if (rank == null || rank < 1 || rank > 100) return null;
  return rank;
}

/// 비교 표에 보일 필드(이름순): 현재 확정값 · 스캔값의 필드, 레벨 90 · 5성 이상이면 잠재 능력,
/// 계산값이 있으면 전투 능력치.
List<String> scanStudentComparisonFields({
  required Map<String, dynamic> current,
  required Map<String, dynamic> scanned,
  required Map<String, dynamic> expected,
}) {
  final fields = <String>{...current.keys, ...scanned.keys};
  if ((scanned['level'] as int? ?? 0) >= 90 &&
      (scanned['student_star'] as int? ?? 0) >= 5) {
    fields.addAll(scanStudentPotentialFields);
  }
  fields.addAll(
    scanStudentStatToField.values.where((field) => expected.isNotEmpty),
  );
  return fields.toList()..sort();
}

/// 비교 표 [field]의 계산값.
Object? scanStudentCalculatedValue(
  String field,
  Map<String, dynamic> expected,
) {
  for (final entry in scanStudentStatToField.entries) {
    if (entry.value == field) return expected[entry.key];
  }
  return null;
}

/// 비교 표 [field]의 차이.
Object? scanStudentCalculatedDelta(String field, Map<String, dynamic> delta) {
  for (final entry in scanStudentStatToField.entries) {
    if (entry.value == field) return delta[entry.key];
  }
  return null;
}

/// [field] 입력을 정수로만 받는가([original] = 후보가 읽은 원래 값).
bool scanStudentFieldNeedsInteger(String field, Object? original) =>
    original is int ||
    scanStudentPotentialFields.contains(field) ||
    scanStudentIntegerFields.contains(field);

/// 재검증 때 보낼 확인 필드: 화면 확인을 고른 필드 + 원래 값과 다르게 고친 필드.
Set<String> scanStudentConfirmedFields({
  required Map<String, dynamic> original,
  required Map<String, dynamic> draft,
  Set<String>? checked,
}) => <String>{
  ...?checked,
  for (final field in draft.keys)
    if (draft[field] != original[field]) field,
};

/// 전체 스캔 결과 목록 순서: 같은 캐릭터(catalog group)의 의상을 처음 나온 자리에 이어 붙이고,
/// 묶음 안에서는 원래 순서를 지킨다.
List<ScannerCandidate> orderScanResultCandidatesByGroup(
  List<ScannerCandidate> candidates,
  Map<String, StudentCatalogEntry> catalog,
) {
  final groupOrder = <String, int>{};
  final indexed = candidates.indexed.toList(growable: false);
  for (final entry in indexed) {
    final studentId = entry.$2.payload['student_id'] as String? ?? 'unknown';
    final group = catalog[studentId]?.group ?? studentId;
    groupOrder.putIfAbsent(group, () => groupOrder.length);
  }
  indexed.sort((left, right) {
    String group((int, ScannerCandidate) entry) {
      final studentId = entry.$2.payload['student_id'] as String? ?? 'unknown';
      return catalog[studentId]?.group ?? studentId;
    }

    final groupComparison = groupOrder[group(left)]!.compareTo(
      groupOrder[group(right)]!,
    );
    return groupComparison != 0 ? groupComparison : left.$1.compareTo(right.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}
