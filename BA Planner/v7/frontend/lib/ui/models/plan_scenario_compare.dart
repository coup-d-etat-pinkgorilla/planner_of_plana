// 시나리오 나란히 비교 4열 모델(FE5-e, 시안 Scenario-Compare, D 보고서 §3, FD-034 · FD-038 · FD-086 · FD-092 · FD-093).
//
// 목록 비교 슬롯(A = 활성 계획 + 시나리오 2~3개)을 열마다 보여 주고, 고른 기준 열 대비 차이를 붙인다.
// - 호출(FD-092): 기준 열 대비 나머지 열마다 `compareScenarios(기준 = A, 열 = B)`를 한 번씩(N−1회) 부른다. 새 서비스
//   메서드는 없다. 기준을 바꾸면 그 기준으로 다시 N−1회다(이미 받은 쌍은 캐시에서 쓴다).
// - 캐시: FE5-b 미리보기(FD-089)와 같은 규칙으로 (기준 id, 기준 revision, 열 id, 열 revision, 프로필 revision) 키다.
//   활성 계획의 revision은 저장된 활성 계획 revision(없으면 null)이다. 같은 키는 다시 부르지 않고, 키에 없는 입력
//   (활성 계획 문서 자체 · 확정 상태)이 바뀌면 [PlanComparePairLoader.invalidate]로 버린다.
// - 열 값(절대값): 크레딧 = 비교 `credits_b`(기준 열은 `credits_a`), 부족 재화 = `known_shortage_type_count_b`(_a),
//   첫 병목 = projection `bottlenecks[]`의 가장 이른 `phase_number` 줄(재화 이름 · 부족량), 끝까지 가는 학생 =
//   FD-034 (a)([PlanDetailStageStates.finishingStudents] / 문서 계산 학생 수), 규모 = 문서의 학생 · 페이즈(단계가 있는
//   것) · 단계 수, 분야별 부족 = 비교 `resources[]`의 `shortage_b`(_a) > 0 재화, 학생 최종 목표 = 문서에서 학생마다
//   마지막 단계 목표. 응답에 없는 값은 null("—")이다. 0으로 채우지 않는다.
// - 기준 대비: 크레딧은 필요량 차이, 부족 재화는 종 수 차이(FD-038 (c)의 크레딧 규칙 · 종 수), 재화 팝오버 칩은 부족량
//   차이(FD-038 (c) 기본, FE5-b [planScenarioShortageDelta]를 "기준" 문구로), 학생은 비교 `students[]`의
//   `presence` · `target_differences`(같음 / 다름 n / 신규 / 포함 안 됨).
// - 최고 값(초록): 크레딧 · 부족 재화 · 분야별 부족 종 수는 적을수록, 첫 병목은 늦을수록(병목 없음이 가장 좋음), 끝까지
//   가는 학생은 비율이 높을수록. 모든 열이 같거나 아는 값이 둘보다 적으면 칠하지 않는다. 규모 · 학생 행은 없다.
// - 차이만 보기: 모든 열의 값이 같은 행을 숨긴다(기준 대비 같음 = 모든 열이 같음).
// - 페이즈 단위 기준 대비는 만들지 않는다(두 문서의 페이즈를 맞추는 규칙이 없다. FE5-d 발견 · FE5-e 종료 기록 FD 안).
import 'package:flutter/foundation.dart';

import '../../services/scenario_service.dart';
import 'plan_scenario_detail.dart' show PlanDetailStageStates;
import 'plan_scenario_preview.dart';
import 'planning_growth_rules.dart';
import 'planning_models.dart';

/// 활성 계획 열 id(2-pane 비교 화면과 같은 값).
const planCompareActiveId = 'active-plan';

/// 4열 비교 열 글자.
const planCompareLetters = ['A', 'B', 'C', 'D'];

/// 비교 쌍 캐시 키(FD-089와 같은 규칙: id · revision · 프로필 revision).
typedef PlanComparePairKey = ({
  String baseId,
  int? baseRevision,
  String columnId,
  int? columnRevision,
  int profileRevision,
});

/// 비교할 계획 하나(활성 계획 또는 시나리오).
@immutable
class PlanCompareTarget {
  const PlanCompareTarget({
    required this.id,
    required this.name,
    required this.document,
    this.revision,
    this.scenario,
    this.collectionRevision,
    this.stale = false,
  });

  final String id;
  final String name;
  final PlanningDocument document;

  /// 시나리오 revision 또는 저장된 활성 계획 revision(없으면 null). 캐시 키에 들어간다.
  final int? revision;

  /// 시나리오 기록(활성 계획이면 null). 계획에 적용…이 쓴다.
  final PlanningScenarioRecord? scenario;

  /// 시나리오 목록 revision(`getScenario` 응답). 계획에 적용…이 쓴다.
  final int? collectionRevision;

  /// 지금 프로필 revision보다 오래된 데이터로 저장되었다(FD-093: 열 헤더 "저장 시점과 다름").
  final bool stale;

  bool get isActivePlan => scenario == null;
}

/// [base] 대비 [column] 쌍의 캐시 키.
PlanComparePairKey planComparePairKey({
  required PlanCompareTarget base,
  required PlanCompareTarget column,
  required int profileRevision,
}) => (
  baseId: base.id,
  baseRevision: base.revision,
  columnId: column.id,
  columnRevision: column.revision,
  profileRevision: profileRevision,
);

/// 기준 대비 수 차이(크레딧 필요량 · 부족 종 수). 둘 중 하나라도 모르면 null. 적으면 좋다.
PlanScenarioDelta? planCompareCountDelta({
  required int? base,
  required int? value,
  required PlanScenarioAmountFormat format,
}) {
  if (base == null || value == null) return null;
  if (base == value) {
    return const PlanScenarioDelta('기준과 같음', PlanScenarioDeltaTone.same);
  }
  return value < base
      ? PlanScenarioDelta(
          '−${format(base - value)}',
          PlanScenarioDeltaTone.better,
        )
      : PlanScenarioDelta(
          '+${format(value - base)}',
          PlanScenarioDeltaTone.worse,
        );
}

/// 재화 부족량의 기준 대비 칩(FD-038 (c) 기본 = 부족량 차이). FE5-b [planScenarioShortageDelta]와 같은 판단이고
/// 문구만 "기준"이다.
PlanScenarioDelta? planCompareShortageDelta({
  required int? shortageBase,
  required int? shortage,
  required int? requiredBase,
  required PlanScenarioAmountFormat format,
}) {
  final delta = planScenarioShortageDelta(
    shortageA: shortageBase,
    shortageB: shortage,
    requiredA: requiredBase,
    format: format,
  );
  if (delta == null) return null;
  return switch (delta.tone) {
    PlanScenarioDeltaTone.same => const PlanScenarioDelta(
      '기준과 같음',
      PlanScenarioDeltaTone.same,
    ),
    PlanScenarioDeltaTone.only => const PlanScenarioDelta(
      '기준에 없음',
      PlanScenarioDeltaTone.only,
    ),
    _ => delta,
  };
}

/// 학생 칸 표시(시안 "같음 / 다름 n / 신규 / 포함 안 됨").
enum PlanCompareStudentMark { same, differs, added, missing }

/// 학생 최종 목표 칩 묶음(시안 `Lv · ★ · 무 · S · T · ♥`)과 그 묶음이 보는 목표 키.
enum PlanCompareTargetChip {
  level('Lv', ['level']),
  star('★', ['student_star']),
  weapon('무', ['weapon_level', 'weapon_star']),
  skills('S', ['ex_skill', 'skill1', 'skill2', 'skill3']),
  tiers('T', [
    'equip1_tier',
    'equip2_tier',
    'equip3_tier',
    'equip4_tier',
    'equip1_level',
    'equip2_level',
    'equip3_level',
  ]),
  bond('♥', ['bond_rank']);

  const PlanCompareTargetChip(this.label, this.keys);

  final String label;
  final List<String> keys;

  /// 칩 값(시안 `90` · `5` · `50` · `5·M·M·M` · `10·10·10·2` · `20`). 정하지 않은 목표는 "—".
  String value(Map<String, int?> targets) {
    String plain(String key) => targets[key]?.toString() ?? '—';
    String skill(String key) {
      final value = targets[key];
      if (value == null) return '—';
      return value == planningDocumentTargetMaximums[key] ? 'M' : '$value';
    }

    return switch (this) {
      PlanCompareTargetChip.level => plain('level'),
      PlanCompareTargetChip.star => plain('student_star'),
      // 전용무기는 최솟값(0 = 없음)이면 "—"(시안 슌 "무 —").
      PlanCompareTargetChip.weapon => switch (targets['weapon_level']) {
        final value? when value > (planElementTargetMinimums['weapon_level'] ?? 0) =>
          '$value',
        _ => '—',
      },
      PlanCompareTargetChip.skills => [for (final key in keys) skill(key)].join('·'),
      PlanCompareTargetChip.tiers => [
        for (final key in const [
          'equip1_tier',
          'equip2_tier',
          'equip3_tier',
          'equip4_tier',
        ])
          plain(key),
      ].join('·'),
      PlanCompareTargetChip.bond => plain('bond_rank'),
    };
  }
}

/// 학생 한 칸.
@immutable
class PlanCompareStudentCell {
  PlanCompareStudentCell({
    this.targets,
    this.mark,
    this.differenceCount = 0,
    Set<String> differingKeys = const {},
  }) : differingKeys = Set.unmodifiable(differingKeys);

  /// 이 열의 마지막 단계 목표. 열에 학생이 없으면 null.
  final Map<String, int?>? targets;

  /// 기준 대비 표시. 기준 열이면 null(열에 없으면 [PlanCompareStudentMark.missing]).
  final PlanCompareStudentMark? mark;

  /// 기준과 다른 목표 키 수(시안 "다름 n").
  final int differenceCount;
  final Set<String> differingKeys;

  bool get included => targets != null;

  /// 표시 문구. 없으면 null.
  String? get markLabel => switch (mark) {
    null => null,
    PlanCompareStudentMark.same => '같음',
    PlanCompareStudentMark.differs => '다름 $differenceCount',
    PlanCompareStudentMark.added => '신규',
    PlanCompareStudentMark.missing => '포함 안 됨',
  };

  /// [chip] 묶음에 기준과 다른 키가 있다(시안 분홍 칩).
  bool differs(PlanCompareTargetChip chip) =>
      chip.keys.any(differingKeys.contains);
}

/// 첫 병목 줄(가장 이른 페이즈의 첫 병목).
typedef PlanCompareBottleneck = ({int phase, String name, int? shortage});

/// 한 열(기준 대비 값 포함).
@immutable
class PlanCompareColumn {
  PlanCompareColumn({
    required this.target,
    required this.letter,
    required this.isBase,
    required this.credits,
    required this.shortageKinds,
    required this.firstBottleneckPhase,
    required this.firstBottleneck,
    required this.finishing,
    required this.studentTotal,
    required this.scale,
    required List<PlanScenarioPreviewShortage> shortages,
    required Set<PlanScenarioResourceField> knownFields,
    required Map<String, PlanCompareStudentCell> students,
    required this.creditsDelta,
    required this.shortageDelta,
    required this.baseShortageKinds,
    required this.baseOnlyShortageKinds,
  }) : shortages = List.unmodifiable(shortages),
       knownFields = Set.unmodifiable(knownFields),
       students = Map.unmodifiable(students);

  final PlanCompareTarget target;
  final String letter;
  final bool isBase;

  /// 필요 크레딧. 모르면 null.
  final int? credits;

  /// 부족 재화 종 수. 모르면 null.
  final int? shortageKinds;

  /// 첫 병목 페이즈: 0 = 병목 없음, null = 모름.
  final int? firstBottleneckPhase;
  final PlanCompareBottleneck? firstBottleneck;

  /// 끝까지 가는 학생(FD-034 (a)) / 문서 계산 학생 수. 모르면 null.
  final int? finishing;
  final int? studentTotal;
  final ({int students, int phases, int stages}) scale;

  /// 부족 재화(부족량 큰 순). 칩은 기준 대비(기준 열이면 null).
  final List<PlanScenarioPreviewShortage> shortages;

  /// 부족량을 하나라도 아는 분야.
  final Set<PlanScenarioResourceField> knownFields;

  /// 학생 id → 칸(모든 열 학생의 합집합).
  final Map<String, PlanCompareStudentCell> students;
  final PlanScenarioDelta? creditsDelta;
  final PlanScenarioDelta? shortageDelta;

  /// 기준 열의 부족 재화 종 수(팝오버 안내).
  final int? baseShortageKinds;

  /// 기준에서만 모자라는 재화 수(두 부족량을 알고, 이 열에서는 모자라지 않는 재화).
  final int baseOnlyShortageKinds;

  /// 끝까지 가는 학생 비율(0~1). 모르면 null.
  double? get finishingRatio {
    final finishing = this.finishing;
    final total = studentTotal;
    if (finishing == null || total == null || total <= 0) return null;
    return finishing / total;
  }

  /// [field] 분야 부족 재화(부족량 큰 순).
  List<PlanScenarioPreviewShortage> fieldShortages(
    PlanScenarioResourceField field,
  ) => [
    for (final item in shortages)
      if (item.field == field) item,
  ];

  /// [shortages]를 분야별로 묶는다(분야 순서 = [PlanScenarioResourceField] 순서).
  List<(PlanScenarioResourceField, List<PlanScenarioPreviewShortage>)>
  get shortageGroups => [
    for (final field in PlanScenarioResourceField.values)
      if (fieldShortages(field) case final items when items.isNotEmpty)
        (field, items),
  ];
}

/// 4열 표의 행.
sealed class PlanCompareRow {
  const PlanCompareRow();
}

/// 위 다섯 줄(시안 순서).
enum PlanCompareMetric { credits, shortage, bottleneck, finishing, scale }

final class PlanCompareMetricRow extends PlanCompareRow {
  const PlanCompareMetricRow(this.metric);

  final PlanCompareMetric metric;

  @override
  bool operator ==(Object other) =>
      other is PlanCompareMetricRow && other.metric == metric;

  @override
  int get hashCode => metric.hashCode;
}

/// 분야별 부족 한 줄.
final class PlanCompareFieldRow extends PlanCompareRow {
  const PlanCompareFieldRow(this.field);

  final PlanScenarioResourceField field;

  @override
  bool operator ==(Object other) =>
      other is PlanCompareFieldRow && other.field == field;

  @override
  int get hashCode => field.hashCode;
}

/// 학생 한 줄.
final class PlanCompareStudentRow extends PlanCompareRow {
  const PlanCompareStudentRow(this.studentId);

  final String studentId;

  @override
  bool operator ==(Object other) =>
      other is PlanCompareStudentRow && other.studentId == studentId;

  @override
  int get hashCode => studentId.hashCode;
}

/// 분야별 부족 줄에 보이는 분야(시안 네 줄. 크레딧은 위 "필요 크레딧" 줄이 맡는다).
const planCompareFields = [
  PlanScenarioResourceField.eleph,
  PlanScenarioResourceField.ooparts,
  PlanScenarioResourceField.notes,
  PlanScenarioResourceField.equipment,
];

List<Map<String, dynamic>> _rows(Object? raw) => [
  for (final row in raw is List ? raw : const <Object?>[])
    if (row is Map) Map<String, dynamic>.from(row),
];

int? _int(Object? value) => value is int ? value : null;

/// 4열 표 한 장(한 기준의 쌍 비교 응답들로 만든다).
@immutable
class PlanCompareTable {
  PlanCompareTable._({
    required this.baseId,
    required List<PlanCompareColumn> columns,
    required List<String> studentIds,
  }) : columns = List.unmodifiable(columns),
       studentIds = List.unmodifiable(studentIds);

  final String baseId;
  final List<PlanCompareColumn> columns;

  /// 학생 줄 순서: 열 순서(A → D)로 처음 나온 학생.
  final List<String> studentIds;

  PlanCompareColumn get base => columns.firstWhere((column) => column.isBase);

  /// [targets](열 순서)와 기준 [baseId] 대비 쌍 응답 [pairs](열 id → `compareScenarios(기준, 열)`)로 만든다.
  /// 기준 열의 값은 아무 쌍의 a쪽이다(모든 쌍이 같은 기준 문서를 같은 입력으로 계산한다).
  factory PlanCompareTable.build({
    required List<PlanCompareTarget> targets,
    required String baseId,
    required Map<String, PlanningScenarioComparisonResult> pairs,
    required PlanScenarioAmountFormat format,
  }) {
    final baseTarget = targets.firstWhere((target) => target.id == baseId);
    final anyPair = pairs.values.firstOrNull;
    final studentIds = <String>[];
    final finalTargets = <String, Map<String, Map<String, int?>>>{};
    for (final target in targets) {
      final byStudent = <String, Map<String, int?>>{};
      for (final stage in target.document.stages) {
        byStudent[stage.studentId] = stage.nullableTargets;
        if (!studentIds.contains(stage.studentId)) {
          studentIds.add(stage.studentId);
        }
      }
      finalTargets[target.id] = byStudent;
    }
    final baseKinds = anyPair == null
        ? null
        : _int(anyPair.comparison['known_shortage_type_count_a']);
    final baseCredits = anyPair == null
        ? null
        : _int(anyPair.comparison['credits_a']);
    final columns = <PlanCompareColumn>[];
    for (final (index, target) in targets.indexed) {
      final isBase = target.id == baseId;
      final pair = isBase ? anyPair : pairs[target.id];
      final side = isBase ? 'a' : 'b';
      final comparison = pair?.comparison ?? const <String, dynamic>{};
      final projection = pair == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(
              isBase ? pair.projectionA : pair.projectionB,
            );
      final credits = _int(comparison['credits_$side']);
      final kinds = _int(comparison['known_shortage_type_count_$side']);

      // 첫 병목(가장 이른 페이즈의 첫 줄)과 재화 → 처음 막는 단계.
      int? firstPhase;
      PlanCompareBottleneck? first;
      final bottleneckStages = <String, String>{};
      if (projection['bottlenecks'] is List) {
        firstPhase = 0;
        for (final row in _rows(projection['bottlenecks'])) {
          final key = row['resource_key']?.toString();
          final stageId = row['stage_id']?.toString();
          if (key != null && stageId != null) {
            bottleneckStages.putIfAbsent(key, () => stageId);
          }
          final phase = _int(row['phase_number']);
          if (phase == null) continue;
          if (first == null || phase < first.phase) {
            first = (
              phase: phase,
              name:
                  row['display_name']?.toString() ??
                  row['resource_key']?.toString() ??
                  '알 수 없는 재화',
              shortage: _int(row['shortage']),
            );
          }
        }
        if (first != null) firstPhase = first.phase;
      }

      // 끝까지 가는 학생(FD-034 (a)).
      final states = PlanDetailStageStates.fromProjection(projection);

      // 단계 id → (페이즈 번호, 학생, 학생 안 순번).
      final stageInfo = <String, ({int phase, String studentId, int step})>{};
      final stepCount = <String, int>{};
      final scaleStudents = <String>{};
      var stageCount = 0;
      for (final (phaseIndex, phase) in target.document.phases.indexed) {
        for (final stage in phase.stages) {
          stageCount += 1;
          scaleStudents.add(stage.studentId);
          stageInfo[stage.id] = (
            phase: phaseIndex + 1,
            studentId: stage.studentId,
            step: stepCount.update(
              stage.studentId,
              (count) => count + 1,
              ifAbsent: () => 1,
            ),
          );
        }
      }

      // 재화(비교 `resources[]`).
      final shortages = <PlanScenarioPreviewShortage>[];
      final knownFields = <PlanScenarioResourceField>{};
      var baseOnly = 0;
      for (final row in _rows(comparison['resources'])) {
        final key =
            row['resource_key']?.toString() ?? row['item_id']?.toString() ?? '';
        final category = row['category']?.toString() ?? 'unresolved';
        final shortage = _int(row['shortage_$side']);
        final shortageBase = _int(row['shortage_a']);
        if (shortage != null) {
          knownFields.add(PlanScenarioResourceField.of(category));
        }
        if (!isBase &&
            shortageBase != null &&
            shortageBase > 0 &&
            shortage == 0) {
          baseOnly += 1;
        }
        if (shortage == null || shortage <= 0) continue;
        final stageId = bottleneckStages[key];
        shortages.add(
          PlanScenarioPreviewShortage(
            resourceKey: key,
            itemId: row['item_id']?.toString(),
            name:
                row['display_name']?.toString() ??
                row['item_id']?.toString() ??
                '알 수 없는 재화',
            category: category,
            shortage: shortage,
            delta: isBase
                ? null
                : planCompareShortageDelta(
                    shortageBase: shortageBase,
                    shortage: shortage,
                    requiredBase: _int(row['required_a']),
                    format: format,
                  ),
            location: stageId == null ? null : stageInfo[stageId],
          ),
        );
      }
      shortages.sort((a, b) => b.shortage.compareTo(a.shortage));

      // 학생(비교 `students[]`).
      final presence = <String, String>{};
      final differences = <String, Set<String>>{};
      for (final row in _rows(comparison['students'])) {
        final id = row['student_id']?.toString();
        if (id == null) continue;
        presence[id] = row['presence']?.toString() ?? '';
        final raw = row['target_differences'];
        differences[id] = {
          if (raw is Map)
            for (final key in raw.keys) key.toString(),
        };
      }
      final mine = finalTargets[target.id] ?? const {};
      final students = <String, PlanCompareStudentCell>{};
      for (final studentId in studentIds) {
        final targetsOf = mine[studentId];
        if (targetsOf == null) {
          students[studentId] = PlanCompareStudentCell(
            mark: PlanCompareStudentMark.missing,
          );
          continue;
        }
        if (isBase) {
          students[studentId] = PlanCompareStudentCell(targets: targetsOf);
          continue;
        }
        final keys = differences[studentId] ?? const <String>{};
        final mark = switch (presence[studentId]) {
          'b_only' => PlanCompareStudentMark.added,
          'both' when keys.isEmpty => PlanCompareStudentMark.same,
          'both' => PlanCompareStudentMark.differs,
          // 응답에 그 학생 줄이 없으면(모름) 표시하지 않는다.
          _ => null,
        };
        students[studentId] = PlanCompareStudentCell(
          targets: targetsOf,
          mark: mark,
          differenceCount: mark == PlanCompareStudentMark.differs
              ? keys.length
              : 0,
          differingKeys: mark == PlanCompareStudentMark.differs
              ? keys
              : const {},
        );
      }

      columns.add(
        PlanCompareColumn(
          target: target,
          letter: planCompareLetters[index % planCompareLetters.length],
          isBase: isBase,
          credits: credits,
          shortageKinds: kinds,
          firstBottleneckPhase: firstPhase,
          firstBottleneck: first,
          finishing: states?.finishingStudents,
          studentTotal: states?.students.length,
          scale: (
            students: scaleStudents.length,
            phases: target.document.phases
                .where((phase) => phase.stages.isNotEmpty)
                .length,
            stages: stageCount,
          ),
          shortages: shortages,
          knownFields: knownFields,
          students: students,
          creditsDelta: planCompareCountDelta(
            base: baseCredits,
            value: credits,
            format: format,
          ),
          shortageDelta: planCompareCountDelta(
            base: baseKinds,
            value: kinds,
            format: (amount) => '$amount종',
          ),
          baseShortageKinds: isBase ? null : baseKinds,
          baseOnlyShortageKinds: baseOnly,
        ),
      );
    }
    assert(columns.any((column) => column.target.id == baseTarget.id));
    return PlanCompareTable._(
      baseId: baseId,
      columns: columns,
      studentIds: studentIds,
    );
  }

  /// 행이 모든 열에서 같은가(차이만 보기).
  bool isSame(PlanCompareRow row) {
    bool allEqual<T>(T Function(PlanCompareColumn column) value) {
      final first = value(columns.first);
      return columns.every((column) => value(column) == first);
    }

    return switch (row) {
      PlanCompareMetricRow(:final metric) => switch (metric) {
        PlanCompareMetric.credits => allEqual((column) => column.credits),
        PlanCompareMetric.shortage => allEqual(
          (column) => column.shortageKinds,
        ),
        PlanCompareMetric.bottleneck => allEqual(
          (column) => (column.firstBottleneckPhase, column.firstBottleneck),
        ),
        PlanCompareMetric.finishing => allEqual(
          (column) => (column.finishing, column.studentTotal),
        ),
        PlanCompareMetric.scale => allEqual((column) => column.scale),
      },
      PlanCompareFieldRow(:final field) => allEqual(
        (column) => (
          column.knownFields.contains(field),
          [
            for (final item in column.fieldShortages(field))
              '${item.resourceKey}:${item.shortage}',
          ].join(','),
        ),
      ),
      PlanCompareStudentRow(:final studentId) => columns.every((column) {
        final cell = column.students[studentId];
        if (cell == null || !cell.included) return false;
        return column.isBase || cell.mark == PlanCompareStudentMark.same;
      }),
    };
  }

  /// 행에서 가장 좋은 열 id(최고 값 강조). 모두 같거나 비교할 값이 둘보다 적으면 빈 집합이다.
  Set<String> best(PlanCompareRow row) {
    Set<String> pick(num? Function(PlanCompareColumn column) score) {
      final known = <String, num>{
        for (final column in columns) column.target.id: ?score(column),
      };
      if (known.length < 2) return const {};
      final values = known.values.toSet();
      if (values.length < 2) return const {};
      final top = values.reduce((a, b) => a > b ? a : b);
      return {
        for (final entry in known.entries)
          if (entry.value == top) entry.key,
      };
    }

    return switch (row) {
      PlanCompareMetricRow(:final metric) => switch (metric) {
        PlanCompareMetric.credits => pick(
          (column) => switch (column.credits) {
            final value? => -value,
            null => null,
          },
        ),
        PlanCompareMetric.shortage => pick(
          (column) => switch (column.shortageKinds) {
            final value? => -value,
            null => null,
          },
        ),
        PlanCompareMetric.bottleneck => pick(
          (column) => switch (column.firstBottleneckPhase) {
            null => null,
            0 => 1 << 20,
            final phase => phase,
          },
        ),
        PlanCompareMetric.finishing => pick(
          (column) => column.finishingRatio,
        ),
        PlanCompareMetric.scale => const {},
      },
      PlanCompareFieldRow(:final field) => pick(
        (column) => column.knownFields.contains(field)
            ? -column.fieldShortages(field).length
            : null,
      ),
      PlanCompareStudentRow() => const {},
    };
  }
}

/// 쌍 비교 읽기 상태.
enum PlanComparePairStatus { loading, ready, failed }

/// 쌍 비교 캐시 · 읽기(FD-092, 키 규칙 = FD-089).
///
/// [request]로 지금 기준의 쌍 키들을 정한다. 캐시에 있으면 바로 쓰고, 없으면 [fetch]를 한 번씩 부른다(같은 키를
/// 읽는 중이면 다시 부르지 않는다). 응답은 자기 키에만 저장된다.
class PlanComparePairLoader extends ChangeNotifier {
  PlanComparePairLoader({required this.fetch});

  final Future<PlanningScenarioComparisonResult> Function(
    PlanComparePairKey key,
  )
  fetch;

  final _cache = <PlanComparePairKey, PlanningScenarioComparisonResult>{};
  final _errors = <PlanComparePairKey, Object>{};
  final _pending = <PlanComparePairKey>{};
  bool _disposed = false;
  int _generation = 0;
  int _fetchCount = 0;

  /// [fetch]를 부른 횟수(테스트 · FB-9 근거).
  int get fetchCount => _fetchCount;

  PlanningScenarioComparisonResult? result(PlanComparePairKey key) =>
      _cache[key];

  Object? error(PlanComparePairKey key) => _errors[key];

  /// [keys] 전부의 상태: 하나라도 실패면 실패, 모두 있으면 준비, 그 밖은 읽는 중.
  PlanComparePairStatus status(Iterable<PlanComparePairKey> keys) {
    var ready = true;
    for (final key in keys) {
      if (_errors.containsKey(key)) return PlanComparePairStatus.failed;
      if (!_cache.containsKey(key)) ready = false;
    }
    return ready ? PlanComparePairStatus.ready : PlanComparePairStatus.loading;
  }

  /// [keys] 중 캐시 · 실패 · 읽는 중이 아닌 것을 읽는다.
  void request(Iterable<PlanComparePairKey> keys) {
    for (final key in keys) {
      _start(key);
    }
  }

  /// [keys]의 실패를 지우고 다시 읽는다.
  void retry(Iterable<PlanComparePairKey> keys) {
    var changed = false;
    for (final key in keys) {
      if (_errors.remove(key) != null) changed = true;
      _start(key);
    }
    if (changed) _changed();
  }

  /// 캐시 · 실패 · 읽는 중인 응답을 모두 버린다(키에 없는 입력이 바뀌었을 때). 버리기 전에 보낸 요청의 응답은
  /// 캐시에 넣지 않는다.
  void invalidate() {
    _generation += 1;
    _cache.clear();
    _errors.clear();
    _pending.clear();
    _changed();
  }

  void _start(PlanComparePairKey key) {
    if (_cache.containsKey(key) ||
        _errors.containsKey(key) ||
        _pending.contains(key)) {
      return;
    }
    _pending.add(key);
    _fetchCount += 1;
    final generation = _generation;
    fetch(key).then(
      (result) {
        if (generation != _generation) return;
        _pending.remove(key);
        _cache[key] = result;
        _changed();
      },
      onError: (Object error) {
        if (generation != _generation) return;
        _pending.remove(key);
        _errors[key] = error;
        _changed();
      },
    );
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
