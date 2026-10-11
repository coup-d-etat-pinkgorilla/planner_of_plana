// 계획 Detail 모델(FE5-c1, 시안 Scenario-Detail-Bottleneck, D 보고서 §2, FD-034 · FD-035 · FD-038 · FD-039).
//
// 시나리오 보기 모드는 FE5-b 미리보기와 같은 응답(`getScenario` 문서 + `compareScenarios(활성 = A, 시나리오 = B)`)만으로
// 그린다. 새 서비스 호출은 없다. FE5-c2의 활성 계획 홈은 같은 모델을 문서 계산 projection 하나로 만든다(비교 없음).
// - 단계 상태(FD-035): 여기서 막힘 = 어떤 병목의 `stage_id`, 앞 단계 대기 = 다른 병목의 `affected_stage_ids` 중 문서
//   순서상 그 병목 단계 뒤에 오는 단계(겹치면 앞 단계 대기). `affected_stage_ids`는 그 재화를 쓰는 모든 단계라서(백엔드
//   `planning_document.py`) 병목 단계 앞의 단계는 빼야 FE4-d(3단계 배지)와 같은 뜻이 된다.
// - 끝까지 가는 학생(FD-034 (a)): 위 두 상태에 단계가 하나도 없는 학생 수 / 문서 계산 단계의 학생 수.
// - 병목 카드: 같은 `stage_id`의 병목을 한 장으로 묶는다(카드 번호 = 처음 나온 순서). 재화 타일은 그 단계에서 모자란
//   재화 먼저, 타일이 둘보다 적으면 그 단계 `stage_results` 재화 중 충분한 것(크레딧 먼저)으로 채운다. 최대 3개.
//   지연 단계 = 카드 병목들의 앞 단계 대기 단계(문서 순서).
// - 단계 맞춤(FD-039): `stage_id`가 같으면(같은 학생) 그 단계, 아니면 (학생, 학생 안 순번). 차이 칩은 FE5-b 학생 칩
//   함수([planScenarioStudentDelta])를 그대로 쓴다.
// - 재화 ±(FD-038 (c)): 기본은 부족량 차이(FE5-b [planScenarioShortageDelta]), 두 문서 모두 부족 0이면 필요량 차이를
//   회색으로, 크레딧은 필요량 차이.
//
// FE5-d(시안 Scenario-Detail-Phase · -All): 페이즈별 · 전체 탭 재화.
// - 페이즈 진입/필요/종료(FD-037): 백엔드 `calculate_document_projection`의 `phase_results[].resources[].owned`는 그
//   페이즈에 들어설 때 남은 양(앞 페이즈 단계들이 쓰고 남은 재고, `phase_remaining`)이다. 백엔드는 단계마다
//   `max(0, 남은 양 − 필요량)`으로 줄이므로 페이즈 끝 잔량은 `max(0, owned − required)`와 같다(음이 아닌 필요량을
//   차례로 빼고 0에서 자르는 것은 합을 한 번에 빼고 자르는 것과 같다). 그래서 종료 = max(0, 진입 − 필요)를 클라이언트가
//   계산한다(FB-9 없음). 보유를 모르는 재화(owned null)는 진입 · 종료 모두 모른다("—").
// - 충족 막대: min(진입 또는 보유, 필요) / 필요, 내림 %(시안 12/42 → 28%).
// - 활성 대비 ±(FD-038 (c)): 재화 줄 단위(비교 `resources[]`)다. 두 문서의 페이즈를 맞추는 규칙이 없어서(FD-039는 단계만
//   맞춘다) 페이즈 타일의 칩도 그 재화의 계획 전체 차이다. 활성 계획에 없는 재화(필요 0 → 시나리오 > 0)는 "이 시나리오에만".
// - 전체 확보율(FD-031 (a)): `overall.resources[]`의 재화별 min(보유, 필요)/필요 단순 평균(크레딧 포함, 보유 모름 제외 ·
//   "보유 모름 n종" 병기). 활성 쪽은 비교 `resources[]`의 a쪽으로 같은 식([planFlowFulfillment])을 쓴다.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'plan_flow_save.dart' show planFlowFulfillment;
import 'plan_scenario_preview.dart';
import 'planning_models.dart';

List<Map<String, dynamic>> _rows(Object? raw) => [
  for (final row in raw is List ? raw : const <Object?>[])
    if (row is Map) Map<String, dynamic>.from(row),
];

int? _int(Object? value) => value is int ? value : null;

/// 단계 행 상태(FD-035). [clear]는 칩을 달지 않는다.
enum PlanDetailStageState { clear, blockedHere, waiting }

/// 문서 계산 projection의 단계 상태(FD-035)와 끝까지 가는 학생(FD-034 (a)).
@immutable
class PlanDetailStageStates {
  PlanDetailStageStates._({
    required Map<String, int> order,
    required Map<String, String> studentOf,
    required List<String> students,
    required Map<String, List<String>> affectedByResource,
  }) : order = Map.unmodifiable(order),
       studentOf = Map.unmodifiable(studentOf),
       students = List.unmodifiable(students),
       _affectedByResource = Map.unmodifiable(affectedByResource);

  /// [projection]으로 만든다. `stage_results` 목록이 없으면 null.
  static PlanDetailStageStates? fromProjection(
    Map<String, dynamic> projection,
  ) {
    final rawStages = projection['stage_results'];
    if (rawStages is! List) return null;
    final order = <String, int>{};
    final studentOf = <String, String>{};
    final students = <String>[];
    for (final row in _rows(rawStages)) {
      final id = row['stage_id']?.toString();
      if (id == null) continue;
      order.putIfAbsent(id, () => order.length);
      final student = row['student_id']?.toString();
      if (student == null) continue;
      studentOf[id] = student;
      if (!students.contains(student)) students.add(student);
    }
    final overall = projection['overall'];
    final affectedByResource = <String, List<String>>{
      for (final row in _rows(overall is Map ? overall['resources'] : null))
        if (row['resource_key'] != null)
          row['resource_key'].toString(): [
            for (final id
                in row['affected_stage_ids'] is List
                    ? row['affected_stage_ids'] as List
                    : const <Object?>[])
              id.toString(),
          ],
    };
    final states = PlanDetailStageStates._(
      order: order,
      studentOf: studentOf,
      students: students,
      affectedByResource: affectedByResource,
    );
    for (final bottleneck in _rows(projection['bottlenecks'])) {
      final stageId = bottleneck['stage_id']?.toString();
      if (stageId == null || !order.containsKey(stageId)) continue;
      states._blockedHere.add(stageId);
      states._waiting.addAll(states.delayedBy(bottleneck));
    }
    return states;
  }

  /// 단계 id → 문서 순서(`stage_results` 순서, 백엔드가 페이즈 → 단계 순으로 만든다).
  final Map<String, int> order;
  final Map<String, String> studentOf;

  /// 문서 계산 단계의 학생(처음 나온 순서).
  final List<String> students;
  final Map<String, List<String>> _affectedByResource;
  final Set<String> _blockedHere = {};
  final Set<String> _waiting = {};

  /// 어떤 병목의 단계(여기서 막힘).
  Set<String> get blockedHere => Set.unmodifiable(_blockedHere);

  /// 앞 단계 병목 때문에 기다리는 단계(앞 단계 대기).
  Set<String> get waiting => Set.unmodifiable(_waiting);

  /// 단계 상태. 둘 다면 앞 단계 대기(FD-035).
  PlanDetailStageState stateOf(String stageId) => _waiting.contains(stageId)
      ? PlanDetailStageState.waiting
      : _blockedHere.contains(stageId)
      ? PlanDetailStageState.blockedHere
      : PlanDetailStageState.clear;

  /// 끝까지 가는 학생 수(FD-034 (a)).
  int get finishingStudents {
    final stuck = <String>{
      for (final id in {..._blockedHere, ..._waiting})
        ?studentOf[id],
    };
    return students.where((student) => !stuck.contains(student)).length;
  }

  /// 병목 [bottleneck] 때문에 기다리는 단계(그 병목 단계 뒤, 문서 순서). 병목 줄에 `affected_stage_ids`가 없으면 전체
  /// 재화 줄의 것을 쓴다.
  List<String> delayedBy(Map<String, dynamic> bottleneck) {
    final stageId = bottleneck['stage_id']?.toString();
    final start = stageId == null ? null : order[stageId];
    if (start == null) return const [];
    final raw = bottleneck['affected_stage_ids'];
    final affected = raw is List
        ? [for (final id in raw) id.toString()]
        : _affectedByResource[bottleneck['resource_key']?.toString()] ??
              const <String>[];
    final result = <String>[
      for (final id in affected)
        if (id != stageId && (order[id] ?? -1) > start) id,
    ];
    result.sort((a, b) => order[a]!.compareTo(order[b]!));
    return result;
  }
}

/// 첫 병목 페이즈 번호: 병목이 없으면 0, projection에 병목 목록이 없으면 null(FE5-b와 같다).
int? planDetailFirstBottleneck(Map<String, dynamic> projection) {
  final raw = projection['bottlenecks'];
  if (raw is! List) return null;
  final phases = [
    for (final row in _rows(raw))
      if (row['phase_number'] case final int phase) phase,
  ];
  if (phases.isEmpty) return 0;
  return phases.reduce((a, b) => a < b ? a : b);
}

/// 단계 맞춤(FD-039): 시나리오 단계 id → 활성 계획 단계(없으면 null).
///
/// `stage_id`가 같고 학생도 같으면 그 단계를 먼저 쓴다. 나머지는 (학생, 학생 안 순번)으로 맞추되 이미 id로 맞춘 활성
/// 단계는 다시 쓰지 않는다.
Map<String, PlanningDocumentStage?> planScenarioStageMatches({
  required PlanningDocument active,
  required PlanningDocument scenario,
}) {
  final activeById = {for (final stage in active.stages) stage.id: stage};
  final used = <String>{};
  final result = <String, PlanningDocumentStage?>{};
  for (final stage in scenario.stages) {
    final match = activeById[stage.id];
    if (match != null && match.studentId == stage.studentId) {
      result[stage.id] = match;
      used.add(match.id);
    }
  }
  final activeByStudent = <String, List<PlanningDocumentStage>>{};
  for (final stage in active.stages) {
    activeByStudent.putIfAbsent(stage.studentId, () => []).add(stage);
  }
  final index = <String, int>{};
  for (final stage in scenario.stages) {
    final position = index.update(
      stage.studentId,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    if (result.containsKey(stage.id)) continue;
    final candidates = activeByStudent[stage.studentId] ?? const [];
    final candidate = position < candidates.length
        ? candidates[position]
        : null;
    if (candidate != null && used.add(candidate.id)) {
      result[stage.id] = candidate;
    } else {
      result[stage.id] = null;
    }
  }
  return result;
}

/// 단계 행의 활성 대비 칩(FD-039): 맞는 활성 단계가 없으면 "이 시나리오에만", 있으면 목표 차이로 FE5-b 학생 칩과 같은
/// 규칙(같음 / 활성보다 낮은 목표 / 목표 다름 n).
PlanScenarioDelta planScenarioStageDelta(
  PlanningDocumentStage stage,
  PlanningDocumentStage? match,
) {
  if (match == null) {
    return planScenarioStudentDelta(presence: 'b_only', differences: const {});
  }
  final a = match.nullableTargets;
  final b = stage.nullableTargets;
  return planScenarioStudentDelta(
    presence: 'both',
    differences: {
      for (final key in {...a.keys, ...b.keys})
        if (a[key] != b[key]) key: (a: a[key], b: b[key]),
    },
  );
}

/// 재화 ±(FD-038 (c), 비교 `resources[]` 한 줄). [prefix]는 병목 카드 타일의 "활성보다 ".
///
/// - 크레딧: 필요량 차이(줄면 ok, 늘면 경고).
/// - 두 문서 모두 부족 0: 필요량 차이를 회색으로.
/// - 그 밖: 부족량 차이(FE5-b와 같은 [planScenarioShortageDelta]).
PlanScenarioDelta? planScenarioResourceDelta(
  Map<String, dynamic>? row, {
  required PlanScenarioAmountFormat format,
  String prefix = '',
}) {
  if (row == null) return null;
  final requiredA = _int(row['required_a']);
  final requiredB = _int(row['required_b']);
  final shortageA = _int(row['shortage_a']);
  final shortageB = _int(row['shortage_b']);
  final credits = row['category']?.toString() == 'credits';
  if (credits || (shortageA == 0 && shortageB == 0)) {
    if (requiredA == null || requiredB == null) return null;
    if (requiredA == requiredB) {
      return const PlanScenarioDelta('활성 계획과 같음', PlanScenarioDeltaTone.same);
    }
    final difference = requiredB - requiredA;
    final label =
        '$prefix${difference < 0 ? '−' : '+'}${format(difference.abs())}';
    return PlanScenarioDelta(
      label,
      !credits
          ? PlanScenarioDeltaTone.same
          : difference < 0
          ? PlanScenarioDeltaTone.better
          : PlanScenarioDeltaTone.worse,
    );
  }
  final delta = planScenarioShortageDelta(
    shortageA: shortageA,
    shortageB: shortageB,
    requiredA: requiredA,
    format: format,
  );
  if (delta == null || prefix.isEmpty) return delta;
  return switch (delta.tone) {
    PlanScenarioDeltaTone.better ||
    PlanScenarioDeltaTone.worse => PlanScenarioDelta(
      '$prefix${delta.label}',
      delta.tone,
    ),
    _ => delta,
  };
}

/// 페이즈별 · 전체 탭 재화의 활성 대비(FD-038 (c), FE5-d). 활성 계획이 그 재화를 쓰지 않고(필요 0) 시나리오만 쓰면
/// "이 시나리오에만"(전체 타일 마크는 위젯이 "신규"로 줄인다), 그 밖은 [planScenarioResourceDelta]와 같다.
PlanScenarioDelta? planDetailResourceDelta(
  Map<String, dynamic>? row, {
  required PlanScenarioAmountFormat format,
  String prefix = '',
}) {
  if (row == null) return null;
  final requiredA = _int(row['required_a']);
  final requiredB = _int(row['required_b']);
  if (requiredA != null && requiredA <= 0 && (requiredB ?? 0) > 0) {
    return const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only);
  }
  return planScenarioResourceDelta(row, format: format, prefix: prefix);
}

/// 페이즈별 요약 행 칩(시안 "활성보다 +12 부족"): 부족량 차이면 "활성보다 ±n 부족", 필요량 차이 · 같음 · 신규는
/// [planDetailResourceDelta] 그대로(앞에 "활성보다 ").
PlanScenarioDelta? planDetailSummaryDelta(
  Map<String, dynamic>? row, {
  required PlanScenarioAmountFormat format,
}) {
  final delta = planDetailResourceDelta(row, format: format, prefix: '활성보다 ');
  if (row == null || delta == null) return null;
  final credits = row['category']?.toString() == 'credits';
  final noShortage = _int(row['shortage_a']) == 0 && _int(row['shortage_b']) == 0;
  final directional =
      delta.tone == PlanScenarioDeltaTone.better ||
      delta.tone == PlanScenarioDeltaTone.worse;
  if (credits || noShortage || !directional) return delta;
  return PlanScenarioDelta('${delta.label} 부족', delta.tone);
}

/// 병목 카드의 활성 대비 칩(비교 `bottlenecks[]` 한 줄: 재화마다 처음 모자라는 페이즈 · 단계 · 부족량).
///
/// 활성 계획에 없으면 "이 시나리오에만", 더 이른 페이즈면 "활성보다 n페이즈 빨리"(경고), 늦으면 "… 늦게"(ok), 같은
/// 페이즈면 부족량으로 "부족 줄어듦"(ok) / "부족 늘어남"(경고) / "활성 계획과 같음".
PlanScenarioDelta? planScenarioBottleneckDelta(Map<String, dynamic>? row) {
  if (row == null) return null;
  final a = _int(row['first_phase_a']);
  final b = _int(row['first_phase_b']);
  if (b == null) return null;
  if (a == null) {
    return const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only);
  }
  if (b < a) {
    return PlanScenarioDelta(
      '활성보다 ${a - b}페이즈 빨리',
      PlanScenarioDeltaTone.worse,
    );
  }
  if (b > a) {
    return PlanScenarioDelta(
      '활성보다 ${b - a}페이즈 늦게',
      PlanScenarioDeltaTone.better,
    );
  }
  final shortageA = _int(row['shortage_a']);
  final shortageB = _int(row['shortage_b']);
  if (shortageA == null || shortageB == null || shortageA == shortageB) {
    return const PlanScenarioDelta('활성 계획과 같음', PlanScenarioDeltaTone.same);
  }
  return shortageB < shortageA
      ? const PlanScenarioDelta('부족 줄어듦', PlanScenarioDeltaTone.better)
      : const PlanScenarioDelta('부족 늘어남', PlanScenarioDeltaTone.worse);
}

/// S2 단계 행 하나.
@immutable
class PlanDetailStageRow {
  const PlanDetailStageRow({
    required this.stageId,
    required this.studentId,
    required this.name,
    required this.phase,
    required this.targets,
    required this.state,
    this.bottleneckNumber,
    this.delta,
  });

  final String stageId;
  final String studentId;

  /// 문서 단계 이름(시안 "1단계").
  final String name;

  /// 페이즈 번호(1부터).
  final int phase;
  final Map<String, int?> targets;
  final PlanDetailStageState state;

  /// 이 단계가 병목 카드의 단계면 그 카드 번호(1부터).
  final int? bottleneckNumber;

  /// 활성 대비 칩(FD-039). 비교가 없으면 null.
  final PlanScenarioDelta? delta;
}

/// S2 페이즈 하나(헤더 + 단계 행).
@immutable
class PlanDetailPhase {
  PlanDetailPhase({
    required this.number,
    required this.name,
    required List<PlanDetailStageRow> stages,
    this.shortageKinds,
  }) : stages = List.unmodifiable(stages);

  final int number;
  final String name;
  final List<PlanDetailStageRow> stages;

  /// 이 페이즈 단계들이 들어설 때 모자라는 재화 종 수(`stage_results[].resources[].shortage_at_entry > 0`). 보유를 하나도
  /// 모르면 null.
  final int? shortageKinds;
}

/// 병목 카드의 재화 타일 하나.
@immutable
class PlanDetailCardResource {
  const PlanDetailCardResource({
    required this.resourceKey,
    required this.name,
    required this.category,
    required this.required,
    required this.shortage,
    this.itemId,
    this.ownedAtEntry,
    this.delta,
  });

  final String resourceKey;
  final String name;
  final String? itemId;
  final String category;

  /// 그 단계 필요량.
  final int required;

  /// 들어설 때 남은 양(모르면 null).
  final int? ownedAtEntry;

  /// 모자라는 양. 0이면 충분.
  final int shortage;

  /// 활성 대비(FD-038 (c), "활성보다 ±n"). 비교가 없으면 null.
  final PlanScenarioDelta? delta;
}

/// 지연되는 단계 하나.
@immutable
class PlanDetailDelayedStage {
  const PlanDetailDelayedStage({
    required this.stageId,
    required this.studentId,
    required this.name,
    required this.phase,
  });

  final String stageId;
  final String studentId;
  final String name;
  final int phase;
}

/// 병목 카드 하나(같은 단계의 병목 묶음).
@immutable
class PlanDetailBottleneckCard {
  PlanDetailBottleneckCard({
    required this.number,
    required this.phase,
    required this.stageId,
    required this.studentId,
    required this.stageName,
    required this.targets,
    required List<PlanDetailCardResource> resources,
    required this.hiddenShortages,
    required List<PlanDetailDelayedStage> delayed,
    this.delta,
  }) : resources = List.unmodifiable(resources),
       delayed = List.unmodifiable(delayed);

  /// 카드 번호(1부터, 병목이 처음 나온 순서).
  final int number;
  final int phase;
  final String stageId;
  final String studentId;
  final String stageName;
  final Map<String, int?> targets;

  /// 모자란 재화 먼저, 그다음 충분한 재화. 최대 [PlanDetailData.maxCardResources]개.
  final List<PlanDetailCardResource> resources;

  /// 타일에 다 싣지 못한 모자란 재화 수.
  final int hiddenShortages;
  final List<PlanDetailDelayedStage> delayed;

  /// 활성 대비(첫 재화 기준). 비교가 없으면 null.
  final PlanScenarioDelta? delta;

  /// 대표(첫) 모자란 재화. 모자란 재화가 없는 카드는 없다.
  PlanDetailCardResource get primary => resources.first;
}

/// 페이즈별 · 전체 탭의 재화 한 줄(FE5-d).
///
/// 페이즈 줄의 [owned]는 그 페이즈에 들어설 때 남은 양(진입, FD-037), 전체 줄의 [owned]는 지금 보유량이다. 모르면 null.
@immutable
class PlanDetailResourceTile {
  PlanDetailResourceTile({
    required this.resourceKey,
    required this.name,
    required this.category,
    required this.required,
    this.itemId,
    this.owned,
    this.exit,
    this.delta,
    List<String> affectedStageIds = const [],
  }) : affectedStageIds = List.unmodifiable(affectedStageIds);

  final String resourceKey;
  final String name;
  final String? itemId;
  final String category;
  final int required;

  /// 진입 잔량(페이즈) 또는 보유량(전체). 모르면 null.
  final int? owned;

  /// 페이즈 종료 잔량 = max(0, 진입 − 필요). 전체 줄 · 모르면 null.
  final int? exit;

  /// 활성 대비(FD-038 (c), [planDetailResourceDelta]). 비교가 없으면 null.
  final PlanScenarioDelta? delta;

  /// 이 재화를 쓰는 단계(문서 순서). 전체 탭에서 누르면 왼쪽에서 강조한다.
  final List<String> affectedStageIds;

  bool get isCredits => category == 'credits' || resourceKey == 'credits';

  PlanScenarioResourceField get field => PlanScenarioResourceField.of(category);

  /// 모자라는 양. 보유를 모르면 null.
  int? get shortage {
    final value = owned;
    return value == null ? null : math.max(0, required - value);
  }

  /// 충족 비율 min(보유, 필요)/필요. 보유를 모르면 null.
  double? get fraction {
    final value = owned;
    if (value == null) return null;
    if (required <= 0) return 1;
    return math.min(value, required) / required;
  }

  /// 충족률(내림 %). 보유를 모르면 null.
  int? get percent {
    final value = fraction;
    return value == null ? null : (value * 100).floor();
  }

  /// 보유로 필요량을 채운다(모르면 false).
  bool get satisfied {
    final value = owned;
    return value != null && value >= required;
  }
}

/// 페이즈별 탭 페이즈 카드 하나(FE5-d, 시안 `.srow` 300px).
@immutable
class PlanDetailPhaseResources {
  PlanDetailPhaseResources({
    required this.number,
    required this.name,
    required List<String> studentIds,
    required List<PlanDetailResourceTile> tiles,
    this.credits,
    this.calculated = true,
  }) : studentIds = List.unmodifiable(studentIds),
       tiles = List.unmodifiable(tiles);

  /// 페이즈 번호(1부터, 문서 순서).
  final int number;
  final String name;

  /// 이 페이즈 단계의 학생(처음 나온 순서).
  final List<String> studentIds;

  /// 크레딧 밖의 재화(백엔드 순서).
  final List<PlanDetailResourceTile> tiles;

  /// 크레딧 진입/필요/종료 줄. 이 페이즈가 크레딧을 쓰지 않으면 null.
  final PlanDetailResourceTile? credits;

  /// 계산 응답(`phase_results`)에 이 페이즈 줄이 있었다.
  final bool calculated;

  /// 모자라는 재화 종 수(크레딧 포함). 보유를 하나도 모르면 null.
  int? get shortageKinds {
    final known = [
      ?credits,
      ...tiles,
    ].where((tile) => tile.owned != null).toList();
    if (known.isEmpty) return null;
    return known.where((tile) => (tile.shortage ?? 0) > 0).length;
  }
}

/// 전체 탭(FE5-d, 시안 Scenario-Detail-All): `overall.resources[]`와 확보율(FD-031 (a)).
@immutable
class PlanDetailOverallResources {
  PlanDetailOverallResources({
    required List<PlanDetailResourceTile> tiles,
    required this.rate,
    required this.unknownKinds,
    required this.shortageKinds,
    required this.affectedStudents,
    required this.totalStudents,
    this.credits,
    this.activeRate,
  }) : tiles = List.unmodifiable(tiles);

  /// 크레딧 밖의 재화(백엔드 순서).
  final List<PlanDetailResourceTile> tiles;
  final PlanDetailResourceTile? credits;

  /// 확보율(0~1). 보유를 아는 재화가 없으면 null.
  final double? rate;

  /// 보유를 모르는 재화 종 수.
  final int unknownKinds;

  /// 모자라는 재화 종 수(크레딧 포함).
  final int shortageKinds;

  /// 모자라는 재화를 쓰는 단계의 학생 수 / 문서 학생 수.
  final int affectedStudents;
  final int totalStudents;

  /// 활성 계획 확보율(비교 a쪽, 같은 식). 비교가 없으면 null.
  final double? activeRate;
}

/// 페이즈별 요약 행 "가장 부족한 재화"(FE5-d): 처음으로 모자라는 재화가 있는 페이즈에서 충족률이 가장 낮은(같으면
/// 부족량이 큰) 재화.
@immutable
class PlanDetailPhaseSummary {
  const PlanDetailPhaseSummary({
    required this.tile,
    required this.phase,
    required this.students,
    required this.completable,
    required this.laterStages,
    this.delta,
  });

  final PlanDetailResourceTile tile;

  /// 페이즈 번호(1부터).
  final int phase;

  /// 그 페이즈 학생 수와 그중 그 페이즈 단계가 모두 막히지 않은(FD-035 상태가 없는) 학생 수.
  final int students;
  final int completable;

  /// 뒤 페이즈에서 이 재화를 더 쓰는 단계 수.
  final int laterStages;

  /// 활성 대비(시안 "활성보다 +12 부족"). 비교가 없으면 null.
  final PlanScenarioDelta? delta;
}

/// 활성 대비 KPI 4개(a = 활성 계획, b = 이 문서). 비교가 없으면 a가 모두 null이다.
@immutable
class PlanDetailKpis {
  const PlanDetailKpis({
    required this.credits,
    required this.shortageKinds,
    required this.firstBottleneck,
    required this.finishing,
  });

  final PlanScenarioPreviewKpi<int> credits;
  final PlanScenarioPreviewKpi<int> shortageKinds;

  /// 0 = 병목 없음, null = 모름.
  final PlanScenarioPreviewKpi<int> firstBottleneck;

  /// 끝까지 가는 학생 n / m(FD-034 (a)).
  final PlanScenarioPreviewKpi<({int finishing, int total})> finishing;
}

/// 비교 입력(활성 계획 문서 · 활성 projection · 비교 줄).
@immutable
class PlanDetailComparison {
  const PlanDetailComparison({
    required this.active,
    required this.projectionA,
    required this.comparison,
  });

  final PlanningDocument active;
  final Map<String, dynamic> projectionA;
  final Map<String, dynamic> comparison;
}

/// Detail 화면 하나(S2 페이즈 · S3 병목 카드 · KPI).
@immutable
class PlanDetailData {
  PlanDetailData({
    required List<PlanDetailPhase> phases,
    required List<PlanDetailBottleneckCard> cards,
    required this.kpis,
    required this.studentCount,
    required this.stageCount,
    this.differentStageCount,
    this.differentBottlenecks,
    this.activeOnlyBottlenecks,
    List<PlanDetailPhaseResources> phaseResources = const [],
    this.overall,
    this.phaseSummary,
  }) : phases = List.unmodifiable(phases),
       cards = List.unmodifiable(cards),
       phaseResources = List.unmodifiable(phaseResources);

  /// 병목 카드 한 장에 싣는 재화 타일 수.
  static const maxCardResources = 3;

  final List<PlanDetailPhase> phases;
  final List<PlanDetailBottleneckCard> cards;
  final PlanDetailKpis kpis;
  final int studentCount;
  final int stageCount;

  /// "활성 계획과 다른 단계 n"(FD-039). 비교가 없으면 null.
  final int? differentStageCount;

  /// "활성 계획과 다른 병목 n개"(시나리오에 있고 활성 계획에 없거나 처음 페이즈 · 부족량이 다른 재화). 비교가 없으면 null.
  final int? differentBottlenecks;

  /// "활성 계획에만 있는 병목 n개". 비교가 없으면 null.
  final int? activeOnlyBottlenecks;

  /// 페이즈별 탭 페이즈 카드(단계가 있는 페이즈, FE5-d).
  final List<PlanDetailPhaseResources> phaseResources;

  /// 전체 탭. 계산 응답에 `overall`이 없으면 null(FE5-d).
  final PlanDetailOverallResources? overall;

  /// 페이즈별 요약 행. 모자라는 재화가 있는 페이즈가 없으면 null(FE5-d).
  final PlanDetailPhaseSummary? phaseSummary;

  /// 병목 카드만 바꾼 사본(재화 유형 필터 · 충족 재화 숨기기).
  PlanDetailData withCards(List<PlanDetailBottleneckCard> cards) =>
      PlanDetailData(
        phases: phases,
        cards: cards,
        kpis: kpis,
        studentCount: studentCount,
        stageCount: stageCount,
        differentStageCount: differentStageCount,
        differentBottlenecks: differentBottlenecks,
        activeOnlyBottlenecks: activeOnlyBottlenecks,
        phaseResources: phaseResources,
        overall: overall,
        phaseSummary: phaseSummary,
      );

  /// 비교 KPI · 칩을 그릴 수 있다.
  bool get hasComparison => differentStageCount != null;

  /// 페이즈 수(단계가 있는 페이즈).
  int get phaseCount => phases.where((phase) => phase.stages.isNotEmpty).length;

  /// [document]와 그 문서 계산 [projection]으로 만든다. [comparison]이 있으면 활성 대비 칩 · KPI a쪽을 채운다.
  factory PlanDetailData.fromProjection({
    required PlanningDocument document,
    required Map<String, dynamic> projection,
    required PlanScenarioAmountFormat format,
    PlanDetailComparison? comparison,
  }) {
    final states = PlanDetailStageStates.fromProjection(projection);
    final comparisonRows = comparison?.comparison;
    final resourceRows = <String, Map<String, dynamic>>{
      for (final row in _rows(comparisonRows?['resources']))
        if (row['resource_key'] != null) row['resource_key'].toString(): row,
    };
    final bottleneckRows = <String, Map<String, dynamic>>{
      for (final row in _rows(comparisonRows?['bottlenecks']))
        if (row['resource_key'] != null) row['resource_key'].toString(): row,
    };

    // 문서 단계 위치.
    final stageInfo =
        <String, ({int phase, String studentId, String name, Map<String, int?> targets})>{};
    final students = <String>{};
    for (final (index, phase) in document.phases.indexed) {
      for (final stage in phase.stages) {
        stageInfo[stage.id] = (
          phase: index + 1,
          studentId: stage.studentId,
          name: stage.name,
          targets: stage.nullableTargets,
        );
        students.add(stage.studentId);
      }
    }

    // 단계 결과(단계 id → 재화 줄).
    final stageResources = <String, List<Map<String, dynamic>>>{
      for (final row in _rows(projection['stage_results']))
        if (row['stage_id'] != null)
          row['stage_id'].toString(): _rows(row['resources']),
    };

    // 병목 카드: 같은 단계의 병목을 처음 나온 순서로 묶는다.
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final bottleneck in _rows(projection['bottlenecks'])) {
      final stageId = bottleneck['stage_id']?.toString();
      if (stageId == null || !stageInfo.containsKey(stageId)) continue;
      grouped.putIfAbsent(stageId, () => []).add(bottleneck);
    }
    final cardNumbers = <String, int>{};
    final cards = <PlanDetailBottleneckCard>[];
    for (final entry in grouped.entries) {
      final info = stageInfo[entry.key]!;
      final number = cards.length + 1;
      cardNumbers[entry.key] = number;
      PlanScenarioDelta? tileDelta(String key) => comparison == null
          ? null
          : planScenarioResourceDelta(
              resourceRows[key],
              format: format,
              prefix: '활성보다 ',
            );
      final shorts = [
        for (final bottleneck in entry.value)
          PlanDetailCardResource(
            resourceKey: bottleneck['resource_key']?.toString() ?? '',
            itemId: bottleneck['item_id']?.toString(),
            name:
                bottleneck['display_name']?.toString() ??
                bottleneck['item_id']?.toString() ??
                '알 수 없는 재화',
            category: bottleneck['category']?.toString() ?? 'unresolved',
            required: _int(bottleneck['required_at_entry']) ?? 0,
            ownedAtEntry: _int(bottleneck['remaining_at_entry']),
            shortage: _int(bottleneck['shortage']) ?? 0,
            delta: tileDelta(bottleneck['resource_key']?.toString() ?? ''),
          ),
      ];
      final shownShorts = shorts.take(maxCardResources).toList();
      final shortKeys = {for (final item in shorts) item.resourceKey};
      final enough = [
        for (final row in stageResources[entry.key] ?? const [])
          if (!shortKeys.contains(row['resource_key']?.toString()) &&
              _int(row['shortage_at_entry']) == 0)
            row,
      ]..sort((a, b) {
          int rank(Map<String, dynamic> row) =>
              row['category']?.toString() == 'credits' ? 0 : 1;
          return rank(a).compareTo(rank(b));
        });
      final padding = [
        for (final row in enough.take(
          (2 - shownShorts.length).clamp(0, maxCardResources),
        ))
          PlanDetailCardResource(
            resourceKey: row['resource_key']?.toString() ?? '',
            itemId: row['item_id']?.toString(),
            name:
                row['display_name']?.toString() ??
                row['item_id']?.toString() ??
                '알 수 없는 재화',
            category: row['category']?.toString() ?? 'unresolved',
            required: _int(row['required']) ?? 0,
            ownedAtEntry: _int(row['owned_at_entry']),
            shortage: 0,
            delta: tileDelta(row['resource_key']?.toString() ?? ''),
          ),
      ];
      final delayedIds = <String>{
        if (states != null)
          for (final bottleneck in entry.value)
            ...states.delayedBy(bottleneck),
      }.toList();
      if (states != null) {
        delayedIds.sort(
          (a, b) => (states.order[a] ?? 0).compareTo(states.order[b] ?? 0),
        );
      }
      cards.add(
        PlanDetailBottleneckCard(
          number: number,
          phase: _int(entry.value.first['phase_number']) ?? info.phase,
          stageId: entry.key,
          studentId: info.studentId,
          stageName: info.name,
          targets: info.targets,
          resources: [...shownShorts, ...padding],
          hiddenShortages: shorts.length - shownShorts.length,
          delayed: [
            for (final id in delayedIds)
              if (stageInfo[id] case final delayed?)
                PlanDetailDelayedStage(
                  stageId: id,
                  studentId: delayed.studentId,
                  name: delayed.name,
                  phase: delayed.phase,
                ),
          ],
          delta: comparison == null
              ? null
              : planScenarioBottleneckDelta(
                  bottleneckRows[entry.value.first['resource_key']
                      ?.toString()],
                ),
        ),
      );
    }

    // S2 페이즈 · 단계 행.
    final matches = comparison == null
        ? null
        : planScenarioStageMatches(active: comparison.active, scenario: document);
    var different = 0;
    final phases = <PlanDetailPhase>[];
    for (final (index, phase) in document.phases.indexed) {
      final rows = <PlanDetailStageRow>[];
      final shortKeys = <String>{};
      var known = false;
      for (final stage in phase.stages) {
        final delta = matches == null
            ? null
            : planScenarioStageDelta(stage, matches[stage.id]);
        if (delta != null && delta.tone != PlanScenarioDeltaTone.same) {
          different += 1;
        }
        for (final row in stageResources[stage.id] ?? const []) {
          final shortage = _int(row['shortage_at_entry']);
          if (shortage == null) continue;
          known = true;
          if (shortage > 0) shortKeys.add(row['resource_key']?.toString() ?? '');
        }
        rows.add(
          PlanDetailStageRow(
            stageId: stage.id,
            studentId: stage.studentId,
            name: stage.name,
            phase: index + 1,
            targets: stage.nullableTargets,
            state: states?.stateOf(stage.id) ?? PlanDetailStageState.clear,
            bottleneckNumber: cardNumbers[stage.id],
            delta: delta,
          ),
        );
      }
      phases.add(
        PlanDetailPhase(
          number: index + 1,
          name: phase.name,
          stages: rows,
          shortageKinds: known || shortKeys.isNotEmpty ? shortKeys.length : null,
        ),
      );
    }

    // KPI.
    final overall = projection['overall'];
    final overallRows = _rows(overall is Map ? overall['resources'] : null);
    final cost = overall is Map ? overall['cost'] : null;
    int? comparisonInt(String key) => _int(comparisonRows?[key]);
    ({int finishing, int total})? finishing(PlanDetailStageStates? value) =>
        value == null
        ? null
        : (finishing: value.finishingStudents, total: value.students.length);
    final kpis = PlanDetailKpis(
      credits: PlanScenarioPreviewKpi(
        comparisonInt('credits_a'),
        comparisonInt('credits_b') ?? (cost is Map ? _int(cost['credits']) : null),
      ),
      shortageKinds: PlanScenarioPreviewKpi(
        comparisonInt('known_shortage_type_count_a'),
        comparisonInt('known_shortage_type_count_b') ??
            (overall is Map
                ? overallRows
                      .where((row) => (_int(row['shortage']) ?? 0) > 0)
                      .length
                : null),
      ),
      firstBottleneck: PlanScenarioPreviewKpi(
        comparison == null
            ? null
            : planDetailFirstBottleneck(comparison.projectionA),
        planDetailFirstBottleneck(projection),
      ),
      finishing: PlanScenarioPreviewKpi(
        comparison == null
            ? null
            : finishing(PlanDetailStageStates.fromProjection(comparison.projectionA)),
        finishing(states),
      ),
    );

    int? differentBottlenecks;
    int? activeOnlyBottlenecks;
    if (comparison != null) {
      var differentCount = 0;
      var activeOnlyCount = 0;
      for (final row in bottleneckRows.values) {
        final a = _int(row['first_phase_a']);
        final b = _int(row['first_phase_b']);
        if (a != null && b == null) {
          activeOnlyCount += 1;
        } else if (b != null &&
            (a == null ||
                a != b ||
                _int(row['shortage_a']) != _int(row['shortage_b']))) {
          differentCount += 1;
        }
      }
      differentBottlenecks = differentCount;
      activeOnlyBottlenecks = activeOnlyCount;
    }

    // 페이즈별 · 전체 탭(FE5-d).
    PlanDetailResourceTile tile(
      Map<String, dynamic> row, {
      required bool phase,
    }) {
      final key =
          row['resource_key']?.toString() ?? row['item_id']?.toString() ?? '';
      final required = _int(row['required']) ?? 0;
      final owned = _int(row['owned']);
      final affected = row['affected_stage_ids'];
      return PlanDetailResourceTile(
        resourceKey: key,
        itemId: row['item_id']?.toString(),
        name:
            row['display_name']?.toString() ??
            row['item_id']?.toString() ??
            '알 수 없는 재화',
        category: row['category']?.toString() ?? 'unresolved',
        required: required,
        owned: owned,
        exit: phase && owned != null ? math.max(0, owned - required) : null,
        delta: comparison == null
            ? null
            : planDetailResourceDelta(resourceRows[key], format: format),
        affectedStageIds: [
          for (final id in affected is List ? affected : const <Object?>[])
            id.toString(),
        ],
      );
    }

    final phaseResultRows = _rows(projection['phase_results']);
    final phaseResultById = <String, Map<String, dynamic>>{
      for (final row in phaseResultRows)
        if (row['phase_id'] != null) row['phase_id'].toString(): row,
    };
    final phaseResources = <PlanDetailPhaseResources>[];
    for (final (index, phase) in document.phases.indexed) {
      if (phase.stages.isEmpty) continue;
      final indexed = index < phaseResultRows.length
          ? phaseResultRows[index]
          : null;
      final row =
          phaseResultById[phase.id] ??
          (indexed != null && indexed['phase_id'] == null ? indexed : null);
      final all = [
        for (final resource in _rows(row?['resources']))
          tile(resource, phase: true),
      ];
      phaseResources.add(
        PlanDetailPhaseResources(
          number: index + 1,
          name: phase.name,
          studentIds: {
            for (final stage in phase.stages) stage.studentId,
          }.toList(),
          tiles: [
            for (final item in all)
              if (!item.isCredits) item,
          ],
          credits: all.where((item) => item.isCredits).firstOrNull,
          calculated: row != null,
        ),
      );
    }

    PlanDetailOverallResources? overallResources;
    final overallTiles = [
      for (final row in overallRows) tile(row, phase: false),
    ];
    if (overall is Map) {
      final fulfillment = planFlowFulfillment([
        for (final row in overallRows)
          {'required_a': row['required'], 'owned': row['owned']},
      ], 'a');
      final short = overallTiles.where((item) => (item.shortage ?? 0) > 0);
      overallResources = PlanDetailOverallResources(
        tiles: [
          for (final item in overallTiles)
            if (!item.isCredits) item,
        ],
        credits: overallTiles.where((item) => item.isCredits).firstOrNull,
        rate: fulfillment.rate,
        unknownKinds: fulfillment.unknown,
        shortageKinds: short.length,
        affectedStudents: {
          for (final item in short)
            for (final id in item.affectedStageIds) ?stageInfo[id]?.studentId,
        }.length,
        totalStudents: students.length,
        activeRate: comparison == null
            ? null
            : planFlowFulfillment(_rows(comparisonRows?['resources']), 'a').rate,
      );
    }

    PlanDetailPhaseSummary? phaseSummary;
    final overallAffected = {
      for (final item in overallTiles) item.resourceKey: item.affectedStageIds,
    };
    for (final phase in phaseResources) {
      final short = [
        for (final (order, item) in [?phase.credits, ...phase.tiles].indexed)
          if ((item.shortage ?? 0) > 0) (order: order, item: item),
      ];
      if (short.isEmpty) continue;
      short.sort((a, b) {
        final ratio = (a.item.fraction ?? 0).compareTo(b.item.fraction ?? 0);
        if (ratio != 0) return ratio;
        final amount = (b.item.shortage ?? 0).compareTo(a.item.shortage ?? 0);
        return amount != 0 ? amount : a.order.compareTo(b.order);
      });
      final top = short.first.item;
      final stages = document.phases[phase.number - 1].stages;
      final stuck = <String>{
        for (final stage in stages)
          if ((states?.stateOf(stage.id) ?? PlanDetailStageState.clear) !=
                  PlanDetailStageState.clear ||
              (stageResources[stage.id] ?? const []).any(
                (row) => (_int(row['shortage_at_entry']) ?? 0) > 0,
              ))
            stage.studentId,
      };
      phaseSummary = PlanDetailPhaseSummary(
        tile: top,
        phase: phase.number,
        students: phase.studentIds.length,
        completable: phase.studentIds
            .where((student) => !stuck.contains(student))
            .length,
        laterStages: (overallAffected[top.resourceKey] ?? const <String>[])
            .where((id) => (stageInfo[id]?.phase ?? 0) > phase.number)
            .length,
        delta: comparison == null
            ? null
            : planDetailSummaryDelta(
                resourceRows[top.resourceKey],
                format: format,
              ),
      );
      break;
    }

    return PlanDetailData(
      phases: phases,
      cards: cards,
      kpis: kpis,
      studentCount: students.length,
      stageCount: stageInfo.length,
      differentStageCount: comparison == null ? null : different,
      differentBottlenecks: differentBottlenecks,
      activeOnlyBottlenecks: activeOnlyBottlenecks,
      phaseResources: phaseResources,
      overall: overallResources,
      phaseSummary: phaseSummary,
    );
  }
}

/// 시나리오 보기 모드 데이터: FE5-b 미리보기(같은 캐시)의 비교 응답으로 만든다. 활성 계획 문서가 없으면(비교 없이
/// 읽은 미리보기는 없다) 비교 없는 Detail이다.
PlanDetailData planScenarioDetailData(
  PlanScenarioPreview preview, {
  required PlanScenarioAmountFormat format,
}) {
  final result = preview.result;
  final active = preview.activeDocument;
  return PlanDetailData.fromProjection(
    document: preview.scenario.document,
    projection: Map<String, dynamic>.from(result.projectionB),
    format: format,
    comparison: active == null
        ? null
        : PlanDetailComparison(
            active: active,
            projectionA: Map<String, dynamic>.from(result.projectionA),
            comparison: Map<String, dynamic>.from(result.comparison),
          ),
  );
}
