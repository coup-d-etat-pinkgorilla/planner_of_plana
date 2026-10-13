// 통계 "계획 집계" 활성 문서 · 문서 계산 시안 숫자 데이터(FE7-g, 시안 Stats-Plan). mockdemo에서
// `test/statistics_plan_fixture.dart`에서 옮겼다.
//
// 테스트 fixture(`test/statistics_plan_fixture.dart`)와 검수 시나리오 Mock(`mock_design_review_scenario.dart`)이 같이 쓴다.
// 시안 숫자를 재현해 사용자가 캔버스와 같은 숫자로 비교하게 한다(워크플로 불변식 "mock fixture"). 학생은 학생 성장 fixture의
// 계획 학생 9명이고, 문서는 페이즈 5개 · 학생마다 단계 하나다. 문서 계산 응답은 백엔드 `calculate_document_projection`과
// 같은 방식(단계 순서대로 보유량을 차감, 재화마다 처음 모자라는 단계가 병목)으로 이 파일이 만든다.
// - KPI: 첫 부족 P2 · 기술 노트 (최상급), 막힌 학생 6명(9 − 끝까지 가는 3명), 범위 칩 "페이즈 5".
// - C3: 기술 노트 (최상급) 0 → 18 → 41 → 62 → 74%(분홍, 첫 부족 P2), 엘리그마 0 → 0 → 12 → 22 → 30%, 설계도 · 시계 T8
//   0 → 0 → 0 → 9 → 15%(시안 path 좌표와 같은 값).
// - 근거(기술 노트 (최상급)): 막히는 단계 P2 −18 · P3 −23 · P4 −21 · P5 −12, "P2부터 누적 부족 −74"(시안 칩 값).
// 시안 학생(리오(무장) · 노아 · 미카)은 성장 fixture 계획 학생에 없어 같은 자리에 아리스 · 히나 · 카즈사를 둔다.
// 시안끼리 맞지 않는 숫자(시안 C3 74% ↔ C1 · C2 기술 노트 (최상급) 96 / 120)는 그대로 둔다: 이 문서 계산의 보유 · 필요는
// 부족 계산 fixture(`statistics_supply_fixture.dart`)와 다르다(status FE7-g 종료 기록 발견 사항).
import '../../ui/models/planning_models.dart';
import '../repository_plan_service.dart';

const statisticsPlanFixtureTechNote = 'Item_Icon_SkillBook_Abydos_3';
const statisticsPlanFixtureEligma = 'Item_Icon_SecretStone';
const statisticsPlanFixtureWatch = 'Equipment_Icon_Watch_Tier8';

/// 재화 메타(item_id · 이름 · category).
const _resources = <String, (String, String)>{
  statisticsPlanFixtureTechNote: ('기술 노트 (최상급)', 'tech_notes'),
  statisticsPlanFixtureEligma: ('엘리그마', 'eligma'),
  statisticsPlanFixtureWatch: ('설계도 · 시계 T8', 'equipment'),
};

/// 문서 계산의 계정 보유량.
const statisticsPlanFixtureOwned = <String, int>{
  statisticsPlanFixtureTechNote: 26,
  statisticsPlanFixtureEligma: 700,
  statisticsPlanFixtureWatch: 85,
};

/// 단계 하나: 학생, 이름, 재화별 필요량.
typedef StatisticsPlanFixtureStage = (
  String student,
  String name,
  Map<String, int> required,
);

/// 페이즈 5개(문서 순서). 필요량 합: 기술 노트 100 · 엘리그마 1000 · 설계도 100.
const statisticsPlanFixturePhases = <List<StatisticsPlanFixtureStage>>[
  [
    (
      'airi',
      '레벨 90',
      {
        statisticsPlanFixtureTechNote: 20,
        statisticsPlanFixtureEligma: 300,
        statisticsPlanFixtureWatch: 30,
      },
    ),
  ],
  [
    (
      'akane',
      '레벨 90',
      {statisticsPlanFixtureEligma: 400, statisticsPlanFixtureWatch: 25},
    ),
    ('hoshino', '스킬 M', {statisticsPlanFixtureTechNote: 24}),
  ],
  [
    ('aris', 'EX 5', {statisticsPlanFixtureTechNote: 23}),
    ('aru', '장비 T8', {statisticsPlanFixtureEligma: 120}),
    ('eimi', '레벨 90', {statisticsPlanFixtureWatch: 30}),
  ],
  [
    (
      'hina',
      '스킬 9',
      {statisticsPlanFixtureTechNote: 21, statisticsPlanFixtureEligma: 100},
    ),
    ('koyuki', '장비 T8', {statisticsPlanFixtureWatch: 9}),
  ],
  [
    (
      'kazusa',
      '스킬 M',
      {
        statisticsPlanFixtureTechNote: 12,
        statisticsPlanFixtureEligma: 80,
        statisticsPlanFixtureWatch: 6,
      },
    ),
  ],
];

String _stageId(String student) => 'stage-$student';

/// 활성 계획 문서(v2 · kind=plan).
PlanningDocument statisticsPlanFixtureDocument() {
  final students = <String>{
    for (final phase in statisticsPlanFixturePhases)
      for (final stage in phase) stage.$1,
  };
  return PlanningDocument(
    id: 'active-plan',
    name: '활성 계획',
    kind: PlanningDocumentKind.plan,
    version: 2,
    goalMetadata: {
      for (final student in students)
        student: const PlanningGoalMetadata(favorite: false, notes: ''),
    },
    phases: [
      for (final (index, phase) in statisticsPlanFixturePhases.indexed)
        PlanningDocumentPhase(
          id: 'phase-${index + 1}',
          name: '${index + 1}페이즈',
          stages: [
            for (final stage in phase)
              PlanningDocumentStage(
                id: _stageId(stage.$1),
                studentId: stage.$1,
                name: stage.$2,
                targets: {
                  for (final key in planningDocumentTargetKeys)
                    key: key == 'level' ? 90 : null,
                },
              ),
          ],
        ),
    ],
  );
}

/// 저장된 활성 계획의 계산 요약(`plan.get`의 `calculation`, 검수 시나리오도 같은 값을 준다).
final statisticsPlanFixtureCalculationWire =
    Map<String, dynamic>.unmodifiable({
      'credits': 0,
      'required_resource_type_count': _resources.length,
      'known_shortage_type_count': _resources.length,
      'inventory_complete': true,
      'first_bottleneck_phase_number': 2,
      'representative_shortage': null,
    });

/// 저장된 활성 계획(`plan.get`). 계산 요약은 있어야 통계가 문서 계산을 부른다(계획 홈과 같은 조건).
RepositoryPlanState statisticsPlanFixturePlan({
  String profileId = '0123456789abcdef01234567',
  int revision = 1,
}) => RepositoryPlanState.fromWire({
  'profile_id': profileId,
  'revision': revision,
  'document': statisticsPlanFixtureDocument().toWire(),
  'calculation': statisticsPlanFixtureCalculationWire,
});

/// 문서 계산 응답(백엔드 `calculate_document_projection`과 같은 키 · 같은 차감 규칙).
Map<String, dynamic> statisticsPlanFixtureProjection({
  Map<String, int?> owned = statisticsPlanFixtureOwned,
}) {
  final remaining = Map<String, int?>.from(owned);
  final stageResults = <Map<String, dynamic>>[];
  final phaseResults = <Map<String, dynamic>>[];
  final bottlenecks = <Map<String, dynamic>>[];
  final affected = <String, List<String>>{};
  final totals = <String, int>{};
  for (final (index, phase) in statisticsPlanFixturePhases.indexed) {
    final phaseId = 'phase-${index + 1}';
    final entry = Map<String, int?>.from(remaining);
    final phaseRequired = <String, int>{};
    final phaseAffected = <String, List<String>>{};
    for (final (step, stage) in phase.indexed) {
      final stageId = _stageId(stage.$1);
      final resources = <Map<String, dynamic>>[];
      for (final MapEntry(:key, value: required) in stage.$3.entries) {
        final (name, category) = _resources[key]!;
        affected.putIfAbsent(key, () => []).add(stageId);
        phaseAffected.putIfAbsent(key, () => []).add(stageId);
        phaseRequired[key] = (phaseRequired[key] ?? 0) + required;
        totals[key] = (totals[key] ?? 0) + required;
        final before = remaining[key];
        final shortage = before == null
            ? null
            : (required - before).clamp(0, required);
        resources.add({
          'resource_key': key,
          'item_id': key,
          'display_name': name,
          'category': category,
          'required': required,
          'owned_at_entry': before,
          'shortage_at_entry': shortage,
        });
        if (before != null) {
          remaining[key] = (before - required).clamp(0, before);
          if ((shortage ?? 0) > 0 &&
              !bottlenecks.any((row) => row['resource_key'] == key)) {
            bottlenecks.add({
              'resource_key': key,
              'item_id': key,
              'display_name': name,
              'category': category,
              'remaining_at_entry': before,
              'required_at_entry': required,
              'shortage': shortage,
              'phase_id': phaseId,
              'phase_number': index + 1,
              'stage_id': stageId,
              'student_id': stage.$1,
              'student_step': step + 1,
              'stage_name': stage.$2,
            });
          }
        }
      }
      stageResults.add({
        'stage_id': stageId,
        'phase_id': phaseId,
        'student_id': stage.$1,
        'name': stage.$2,
        'cost': <String, dynamic>{},
        'resources': resources,
      });
    }
    phaseResults.add({
      'phase_id': phaseId,
      'name': '${index + 1}페이즈',
      'stage_ids': [for (final stage in phase) _stageId(stage.$1)],
      'cost': <String, dynamic>{},
      'resources': [
        for (final MapEntry(:key, value: required) in phaseRequired.entries)
          {
            'resource_key': key,
            'item_id': key,
            'display_name': _resources[key]!.$1,
            'category': _resources[key]!.$2,
            'required': required,
            'owned': entry[key],
            'shortage': entry[key] == null
                ? null
                : (required - entry[key]!).clamp(0, required),
            'affected_stage_ids': phaseAffected[key],
          },
      ],
    });
  }
  for (final row in bottlenecks) {
    row['affected_stage_ids'] = affected[row['resource_key']];
  }
  return {
    'document_id': 'active-plan',
    'kind': 'plan',
    'stage_results': stageResults,
    'phase_results': phaseResults,
    'overall': {
      'cost': {'credits': 0},
      'resources': [
        for (final MapEntry(:key, value: required) in totals.entries)
          {
            'resource_key': key,
            'item_id': key,
            'display_name': _resources[key]!.$1,
            'category': _resources[key]!.$2,
            'required': required,
            'owned': owned[key],
            'shortage': owned[key] == null
                ? null
                : (required - owned[key]!).clamp(0, required),
            'affected_stage_ids': affected[key],
          },
      ],
    },
    'bottlenecks': bottlenecks,
    'warnings': <String>[],
  };
}
