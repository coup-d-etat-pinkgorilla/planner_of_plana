// 시나리오 미리보기 모델(FE5-b, 시안 Scenario-List S3, D 보고서 §1-2 · §1-5, FD-089 · FD-090).
//
// 행을 고르면 `getScenario`(문서) + `compareScenarios(활성 계획 = A, 시나리오 = B)`를 한 번 부르고, 그 응답만으로
// 미리보기를 만든다(클라이언트 계산은 방향 판단 · 묶음뿐이다).
// - KPI 3개: `credits_a/b`, `known_shortage_type_count_a/b`, 첫 병목 = projection의 `bottlenecks[].phase_number` 최솟값.
//   응답에 없는 값은 null("—")이다. 0으로 채우지 않는다.
// - 학생 · 단계: 시나리오 문서의 학생(처음 나온 순서)과 그 단계(페이즈 번호 · 단계 이름). 차이는
//   `comparison.students[]`의 `presence`와 `target_differences{key: {a, b}}`로 정한다. 방향(활성보다 낮은 목표)은
//   a/b 값으로 클라이언트가 판단한다(D §1-5).
// - 분야별 가장 큰 부족: `comparison.resources[]`의 `category` · `shortage_a/b`. 위치는 `projection_b.bottlenecks[]`의
//   `stage_id`로 문서 단계를 찾는다(병목이 없으면 위치 없음).
// - 부족 재화 팝오버: `shortage_b > 0`인 재화 전부를 분야별로 묶는다. 활성 대비 칩은 a/b 부족량으로 정한다.
// - 캐시(FD-089): (시나리오 id, 시나리오 revision, 활성 revision, 프로필 revision) 키. 같은 키는 다시 부르지 않는다.
//   다른 행을 고르는 사이 늦게 온 응답은 자기 키의 캐시에만 들어가고, 지금 고른 행의 화면을 덮지 않는다.
import 'package:flutter/foundation.dart';

import '../../services/scenario_service.dart';
import 'planning_growth_rules.dart';
import 'planning_models.dart';

/// 미리보기 캐시 키(FD-089). 활성 revision은 저장된 활성 계획이 없으면 null이다.
typedef PlanScenarioPreviewKey = ({
  String scenarioId,
  int scenarioRevision,
  int? activeRevision,
  int profileRevision,
});

/// 분야(시안 "분야별 가장 큰 부족"의 다섯 줄 + 그 밖의 재화).
enum PlanScenarioResourceField {
  eleph('엘레프', ['student_eleph']),
  ooparts('오파츠', ['oopart', 'workbook']),
  notes('노트 · BD', ['tech_notes', 'tactical_bd']),
  equipment('장비 설계도', ['equipment']),
  credits('크레딧', ['credits']),
  other('그 밖의 재화', []);

  const PlanScenarioResourceField(this.label, this.categories);

  final String label;

  /// 백엔드 `category` 값.
  final List<String> categories;

  /// 미리보기에 늘 보이는 다섯 줄(시안 순서).
  static const shown = [eleph, ooparts, notes, equipment, credits];

  static PlanScenarioResourceField of(String category) => values.firstWhere(
    (field) => field.categories.contains(category),
    orElse: () => other,
  );
}

/// 활성 계획 대비 칩(시안 `.chip.gy/.ok/.wn/.pk`).
enum PlanScenarioDeltaTone { same, better, worse, only, differs }

/// 칩 하나.
@immutable
class PlanScenarioDelta {
  const PlanScenarioDelta(this.label, this.tone);

  final String label;
  final PlanScenarioDeltaTone tone;

  @override
  bool operator ==(Object other) =>
      other is PlanScenarioDelta && other.label == label && other.tone == tone;

  @override
  int get hashCode => Object.hash(label, tone);

  @override
  String toString() => 'PlanScenarioDelta($label, $tone)';
}

/// 수량 표기(만 이상은 줄임). 화면 표기 함수는 위젯 쪽에서 넘긴다.
typedef PlanScenarioAmountFormat = String Function(int amount);

/// 재화 부족량의 활성 대비 칩. 둘 중 하나라도 모르면 null.
///
/// - 활성 계획에 그 재화가 없고(필요 0, 모르면 이 판단을 하지 않는다) 시나리오만 모자라면 "이 시나리오에만"
/// - 같으면 "활성 계획과 같음", 적으면 "−n"(ok), 많으면 "+n"(경고)
PlanScenarioDelta? planScenarioShortageDelta({
  required int? shortageA,
  required int? shortageB,
  required int? requiredA,
  required PlanScenarioAmountFormat format,
}) {
  if (shortageA == null || shortageB == null) return null;
  if (requiredA != null && requiredA <= 0 && shortageB > 0) {
    return const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only);
  }
  if (shortageB == shortageA) {
    return const PlanScenarioDelta('활성 계획과 같음', PlanScenarioDeltaTone.same);
  }
  return shortageB < shortageA
      ? PlanScenarioDelta(
          '−${format(shortageA - shortageB)}',
          PlanScenarioDeltaTone.better,
        )
      : PlanScenarioDelta(
          '+${format(shortageB - shortageA)}',
          PlanScenarioDeltaTone.worse,
        );
}

/// 학생 목표 차이 칩.
///
/// - 시나리오에만 있는 학생: "이 시나리오에만"
/// - 차이 없음: "활성 계획과 같음"
/// - 모든 차이가 두 값을 알고 시나리오 쪽이 낮으면: "활성보다 낮은 목표"
/// - 그 밖: "목표 다름 n"
PlanScenarioDelta planScenarioStudentDelta({
  required String presence,
  required Map<String, ({int? a, int? b})> differences,
}) {
  if (presence == 'b_only') {
    return const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only);
  }
  if (differences.isEmpty) {
    return const PlanScenarioDelta('활성 계획과 같음', PlanScenarioDeltaTone.same);
  }
  final lower = differences.values.every(
    (value) => value.a != null && value.b != null && value.b! < value.a!,
  );
  if (lower) {
    return const PlanScenarioDelta(
      '활성보다 낮은 목표',
      PlanScenarioDeltaTone.better,
    );
  }
  return PlanScenarioDelta(
    '목표 다름 ${differences.length}',
    PlanScenarioDeltaTone.differs,
  );
}

/// KPI 한 칸(a = 활성 계획, b = 시나리오). 모르는 값은 null.
@immutable
class PlanScenarioPreviewKpi<T extends Object> {
  const PlanScenarioPreviewKpi(this.a, this.b);

  final T? a;
  final T? b;
}

/// 학생 · 단계 한 줄.
@immutable
class PlanScenarioPreviewStudent {
  const PlanScenarioPreviewStudent({
    required this.studentId,
    required this.stages,
    required this.finalTargets,
    required this.delta,
  });

  final String studentId;

  /// (페이즈 번호, 단계 이름) 문서 순서.
  final List<({int phase, String name})> stages;

  /// 마지막 단계 목표(nullable).
  final Map<String, int?> finalTargets;
  final PlanScenarioDelta? delta;
}

/// 부족 재화 하나(`comparison.resources[]`, `shortage_b > 0`).
@immutable
class PlanScenarioPreviewShortage {
  const PlanScenarioPreviewShortage({
    required this.resourceKey,
    required this.itemId,
    required this.name,
    required this.category,
    required this.shortage,
    required this.delta,
    this.location,
  });

  final String resourceKey;
  final String? itemId;
  final String name;
  final String category;
  final int shortage;
  final PlanScenarioDelta? delta;

  /// 병목 위치(페이즈 번호 · 학생 · 그 학생 몇 번째 단계). 병목이 없으면 null.
  final ({int phase, String studentId, int step})? location;

  PlanScenarioResourceField get field => PlanScenarioResourceField.of(category);
}

/// 분야별 가장 큰 부족 한 줄.
@immutable
class PlanScenarioPreviewFieldRow {
  const PlanScenarioPreviewFieldRow({
    required this.field,
    this.top,
    this.known = false,
  });

  final PlanScenarioResourceField field;

  /// 그 분야에서 가장 큰 부족. 부족이 없으면 null.
  final PlanScenarioPreviewShortage? top;

  /// 그 분야 재화의 보유를 하나라도 안다(부족 없음 = "충분"/"부족 없음"). 모르면 "—".
  final bool known;
}

/// 미리보기 하나(한 캐시 키의 결과).
@immutable
class PlanScenarioPreview {
  PlanScenarioPreview({
    required this.scenario,
    required this.credits,
    required this.shortageKinds,
    required this.firstBottleneck,
    required List<PlanScenarioPreviewStudent> students,
    required List<PlanScenarioPreviewShortage> shortages,
    required List<PlanScenarioPreviewFieldRow> fields,
    required this.activeOnlyShortageKinds,
    required this.result,
    this.activeDocument,
  }) : students = List.unmodifiable(students),
       shortages = List.unmodifiable(shortages),
       fields = List.unmodifiable(fields);

  final PlanningScenarioRecord scenario;
  final PlanScenarioPreviewKpi<int> credits;
  final PlanScenarioPreviewKpi<int> shortageKinds;

  /// 첫 병목 페이즈 번호. 병목이 없으면 0(병목 없음), 응답에 병목 목록이 없으면 null(모름).
  final PlanScenarioPreviewKpi<int> firstBottleneck;
  final List<PlanScenarioPreviewStudent> students;

  /// 부족량이 큰 순.
  final List<PlanScenarioPreviewShortage> shortages;

  /// [PlanScenarioResourceField.shown] 다섯 줄.
  final List<PlanScenarioPreviewFieldRow> fields;

  /// 활성 계획에서만 모자라는 재화 수(두 부족량을 알고, 시나리오에서는 모자라지 않는 재화).
  final int activeOnlyShortageKinds;

  /// 이 미리보기를 만든 비교 응답 그대로(FE5-c1 시나리오 보기 모드가 같은 캐시로 Detail을 그린다).
  final PlanningScenarioComparisonResult result;

  /// 비교의 A 문서(활성 계획). 보기 모드의 단계 맞춤(FD-039)에 쓴다. 넘기지 않았으면 null.
  final PlanningDocument? activeDocument;

  /// [shortages]를 분야별로 묶는다(분야 순서 = [PlanScenarioResourceField] 순서, 분야 안은 부족량 큰 순).
  List<(PlanScenarioResourceField, List<PlanScenarioPreviewShortage>)>
  get shortageGroups => [
    for (final field in PlanScenarioResourceField.values)
      if (shortages.where((item) => item.field == field).toList()
          case final items when items.isNotEmpty)
        (field, items),
  ];

  factory PlanScenarioPreview.fromComparison({
    required PlanningScenarioRecord scenario,
    required PlanningScenarioComparisonResult result,
    required PlanScenarioAmountFormat format,
    PlanningDocument? activeDocument,
  }) {
    final comparison = result.comparison;
    int? integer(String key) {
      final value = comparison[key];
      return value is int ? value : null;
    }

    final document = scenario.document;
    // 단계 id → (페이즈 번호, 학생, 그 학생 몇 번째 단계).
    final stageInfo = <String, ({int phase, String studentId, int step})>{};
    final stepCount = <String, int>{};
    final studentOrder = <String>[];
    final studentStages = <String, List<({int phase, String name})>>{};
    final finalTargets = <String, Map<String, int?>>{};
    for (final (index, phase) in document.phases.indexed) {
      for (final stage in phase.stages) {
        final step = stepCount.update(
          stage.studentId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        stageInfo[stage.id] = (
          phase: index + 1,
          studentId: stage.studentId,
          step: step,
        );
        if (!studentOrder.contains(stage.studentId)) {
          studentOrder.add(stage.studentId);
        }
        studentStages
            .putIfAbsent(stage.studentId, () => [])
            .add((phase: index + 1, name: stage.name));
        finalTargets[stage.studentId] = stage.nullableTargets;
      }
    }

    // 학생 차이.
    final presence = <String, String>{};
    final differences = <String, Map<String, ({int? a, int? b})>>{};
    final rawStudents = comparison['students'];
    for (final raw in rawStudents is List ? rawStudents : const <Object?>[]) {
      if (raw is! Map || raw['student_id'] is! String) continue;
      final id = raw['student_id'] as String;
      presence[id] = raw['presence']?.toString() ?? '';
      final rawDifferences = raw['target_differences'];
      differences[id] = {
        if (rawDifferences is Map)
          for (final entry in rawDifferences.entries)
            if (entry.value is Map)
              entry.key.toString(): (
                a: (entry.value as Map)['a'] is int
                    ? (entry.value as Map)['a'] as int
                    : null,
                b: (entry.value as Map)['b'] is int
                    ? (entry.value as Map)['b'] as int
                    : null,
              ),
      };
    }
    final students = [
      for (final id in studentOrder)
        PlanScenarioPreviewStudent(
          studentId: id,
          stages: studentStages[id] ?? const [],
          finalTargets: finalTargets[id] ?? const {},
          delta: presence.containsKey(id)
              ? planScenarioStudentDelta(
                  presence: presence[id]!,
                  differences: differences[id] ?? const {},
                )
              : null,
        ),
    ];

    // 병목(재화 → 처음 모자라는 단계).
    ({List<int> phases, Map<String, String> stages}) bottlenecks(
      Map<String, dynamic> projection,
    ) {
      final raw = projection['bottlenecks'];
      final phases = <int>[];
      final stages = <String, String>{};
      for (final row in raw is List ? raw : const <Object?>[]) {
        if (row is! Map) continue;
        if (row['phase_number'] case final int phase) phases.add(phase);
        final key = row['resource_key']?.toString();
        final stageId = row['stage_id']?.toString();
        if (key != null && stageId != null) stages.putIfAbsent(key, () => stageId);
      }
      return (phases: phases, stages: stages);
    }

    int? firstPhase(Map<String, dynamic> projection) {
      if (projection['bottlenecks'] is! List) return null;
      final phases = bottlenecks(projection).phases;
      if (phases.isEmpty) return 0;
      return phases.reduce((a, b) => a < b ? a : b);
    }

    final bottleneckStages = bottlenecks(
      Map<String, dynamic>.from(result.projectionB),
    ).stages;

    // 재화.
    final shortages = <PlanScenarioPreviewShortage>[];
    final knownFields = <PlanScenarioResourceField>{};
    var activeOnly = 0;
    final rawResources = comparison['resources'];
    for (final raw in rawResources is List ? rawResources : const <Object?>[]) {
      if (raw is! Map) continue;
      final key =
          raw['resource_key']?.toString() ?? raw['item_id']?.toString() ?? '';
      final category = raw['category']?.toString() ?? 'unresolved';
      final shortageA = raw['shortage_a'] is int ? raw['shortage_a'] as int : null;
      final shortageB = raw['shortage_b'] is int ? raw['shortage_b'] as int : null;
      final requiredA = raw['required_a'] is int
          ? raw['required_a'] as int
          : null;
      if (shortageB != null) {
        knownFields.add(PlanScenarioResourceField.of(category));
      }
      if (shortageA != null && shortageA > 0 && shortageB == 0) activeOnly += 1;
      if (shortageB == null || shortageB <= 0) continue;
      final stageId = bottleneckStages[key];
      shortages.add(
        PlanScenarioPreviewShortage(
          resourceKey: key,
          itemId: raw['item_id']?.toString(),
          name:
              raw['display_name']?.toString() ??
              raw['item_id']?.toString() ??
              '알 수 없는 재화',
          category: category,
          shortage: shortageB,
          delta: planScenarioShortageDelta(
            shortageA: shortageA,
            shortageB: shortageB,
            requiredA: requiredA,
            format: format,
          ),
          location: stageId == null ? null : stageInfo[stageId],
        ),
      );
    }
    shortages.sort((a, b) => b.shortage.compareTo(a.shortage));
    final fields = [
      for (final field in PlanScenarioResourceField.shown)
        PlanScenarioPreviewFieldRow(
          field: field,
          top: shortages.where((item) => item.field == field).firstOrNull,
          known: knownFields.contains(field),
        ),
    ];

    return PlanScenarioPreview(
      scenario: scenario,
      credits: PlanScenarioPreviewKpi(integer('credits_a'), integer('credits_b')),
      shortageKinds: PlanScenarioPreviewKpi(
        integer('known_shortage_type_count_a'),
        integer('known_shortage_type_count_b'),
      ),
      firstBottleneck: PlanScenarioPreviewKpi(
        firstPhase(Map<String, dynamic>.from(result.projectionA)),
        firstPhase(Map<String, dynamic>.from(result.projectionB)),
      ),
      students: students,
      shortages: shortages,
      fields: fields,
      activeOnlyShortageKinds: activeOnly,
      result: result,
      activeDocument: activeDocument,
    );
  }
}

/// 마지막 단계 목표 요약(시안 `Lv.90 · 스킬 M/M/M/M · T10`). 정하지 않은 목표(null)와 최솟값 그대로인 성급 · 장비 ·
/// 전용무기 · 인연(v1 문서의 "올리지 않음")은 쓰지 않는다.
String planScenarioTargetSummary(Map<String, int?> targets) {
  int? raised(String key) {
    final value = targets[key];
    if (value == null) return null;
    return value > (planElementTargetMinimums[key] ?? 0) ? value : null;
  }

  String skill(String key) {
    final value = targets[key];
    if (value == null) return '—';
    return value == planningDocumentTargetMaximums[key] ? 'M' : '$value';
  }

  final parts = <String>[
    if (targets['level'] case final level?) 'Lv.$level',
    if (raised('student_star') case final star?) '★$star',
  ];
  const skillKeys = ['ex_skill', 'skill1', 'skill2', 'skill3'];
  final setSkills = [
    for (final key in skillKeys)
      if (targets[key] != null) key,
  ];
  if (setSkills.length == skillKeys.length) {
    parts.add('스킬 ${skillKeys.map(skill).join('/')}');
  } else if (setSkills.isNotEmpty) {
    const labels = {
      'ex_skill': 'EX',
      'skill1': '기본',
      'skill2': '강화',
      'skill3': '서브',
    };
    for (final key in setSkills) {
      parts.add('${labels[key]} ${skill(key)}');
    }
  }
  final tiers = [
    for (final key in const ['equip1_tier', 'equip2_tier', 'equip3_tier'])
      raised(key),
  ];
  final setTiers = tiers.whereType<int>().toList();
  if (setTiers.isNotEmpty) {
    final same = setTiers.length == tiers.length && setTiers.toSet().length == 1;
    parts.add(
      same
          ? 'T${setTiers.first}'
          : '장비 ${tiers.map((tier) => tier == null ? '—' : 'T$tier').join('/')}',
    );
  }
  if (raised('weapon_level') case final weapon?) parts.add('전무 Lv.$weapon');
  if (raised('bond_rank') case final bond?) parts.add('인연 $bond');
  return parts.isEmpty ? '정한 목표 없음' : parts.join(' · ');
}

/// 미리보기 읽기 상태.
enum PlanScenarioPreviewStatus { none, loading, ready, failed }

/// 미리보기 캐시 · 읽기(FD-089).
///
/// [select]로 지금 고른 키를 정한다. 캐시에 있으면 바로 쓰고, 없으면 [fetch]를 한 번 부른다(같은 키를 읽는 중이면
/// 다시 부르지 않는다). 응답은 자기 키에만 저장되므로, 늦게 온 이전 행의 응답이 지금 고른 행을 덮지 않는다.
class PlanScenarioPreviewLoader extends ChangeNotifier {
  PlanScenarioPreviewLoader({required this.fetch});

  final Future<PlanScenarioPreview> Function(PlanScenarioPreviewKey key) fetch;

  final _cache = <PlanScenarioPreviewKey, PlanScenarioPreview>{};
  final _errors = <PlanScenarioPreviewKey, Object>{};
  final _pending = <PlanScenarioPreviewKey>{};
  PlanScenarioPreviewKey? _current;
  bool _disposed = false;
  int _generation = 0;

  int _fetchCount = 0;

  /// [fetch]를 부른 횟수(테스트가 캐시를 확인한다).
  int get fetchCount => _fetchCount;

  PlanScenarioPreviewKey? get current => _current;

  PlanScenarioPreviewStatus get status {
    final key = _current;
    if (key == null) return PlanScenarioPreviewStatus.none;
    if (_cache.containsKey(key)) return PlanScenarioPreviewStatus.ready;
    if (_errors.containsKey(key)) return PlanScenarioPreviewStatus.failed;
    return PlanScenarioPreviewStatus.loading;
  }

  /// 지금 고른 키의 미리보기. 없으면 null.
  PlanScenarioPreview? get preview {
    final key = _current;
    return key == null ? null : _cache[key];
  }

  /// 지금 고른 키의 실패. 없으면 null.
  Object? get error {
    final key = _current;
    return key == null ? null : _errors[key];
  }

  void select(PlanScenarioPreviewKey? key) {
    if (key == _current) return;
    _current = key;
    if (key != null) _start(key);
    _changed();
  }

  /// 캐시 · 실패 · 읽는 중인 응답을 모두 버리고 지금 키를 다시 읽는다. 키에 없는 입력(활성 계획 문서 자체)이
  /// 바뀌었을 때 쓴다. 버리기 전에 보낸 요청의 응답은 캐시에 넣지 않는다.
  void invalidate() {
    _generation += 1;
    _cache.clear();
    _errors.clear();
    _pending.clear();
    final key = _current;
    if (key != null) _start(key);
    _changed();
  }

  /// 지금 키의 실패를 지우고 다시 읽는다.
  void retry() {
    final key = _current;
    if (key == null || !_errors.containsKey(key)) return;
    _errors.remove(key);
    _start(key);
    _changed();
  }

  void _start(PlanScenarioPreviewKey key) {
    if (_cache.containsKey(key) ||
        _errors.containsKey(key) ||
        _pending.contains(key)) {
      return;
    }
    _pending.add(key);
    _fetchCount += 1;
    final generation = _generation;
    fetch(key).then(
      (preview) {
        if (generation != _generation) return;
        _pending.remove(key);
        _cache[key] = preview;
        if (key == _current) _changed();
      },
      onError: (Object error) {
        if (generation != _generation) return;
        _pending.remove(key);
        _errors[key] = error;
        if (key == _current) _changed();
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
