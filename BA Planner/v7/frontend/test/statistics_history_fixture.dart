// 통계 이력 검수 fixture(FE7-h, 시안 Stats-Growth · Stats-Inventory · Stats-Plan 숫자). 테스트 파일이 아니다.
//
// 학생 성장 fixture(`statistics_growth_fixture.dart`) 학생 · 목표와 인벤토리 · 계획 fixture(`statistics_supply_fixture.dart`)
// 인벤토리를 "지금" 상태로 두고, 그 상태로 끝나는 스캔 이력(FB-2a `current_history` v1)을 만든다. 시계는 지역 2026-10-06
// 12:00이다(학생 스캔 "어제 21:40" · 인벤토리 "3일 전", 지역 시각이라 어느 시간대에서도 같은 글자다).
// - 학생 스캔 세션 6개(지역 21:40): 9/02 · 9/08 · 9/15 · 9/22 · 9/29 · 10/05. 세션 끝 평균 육성도 58.1 · 59.0 · 60.2 · 61.4 ·
//   62.2 · 63.4%(A6 점 6개, 강조 "9/22 → 10/05 +2.0%p"). 9/29 → 10/05 사이에 보유 +2 · 최대 레벨 +4 · 완전 육성 +1 ·
//   평균 +1.2(시안 KPI). 시안 A6 9/29 점(62.0)은 KPI +1.2와 맞지 않아 62.2다(status FE7-h 발견 사항).
// - 인벤토리 스캔 세션 6개(지역 21:50): 9/02 · 9/08 · 9/15 · 9/22 · 9/29 · 10/03. 세션마다 수량을 아는 재화 전부를 본다.
//   B3: 크레딧 142.0M → 98.4M(−43.6M) · 엘리그마 760 → 1020(+260) · 상급 활동 보고서 180 → 384(+204, 필요 300 점선).
//   KPI(지난 스캔 = 9/29): 전체 충족률 +6 · 부족 재화 −2 · 과잉 재화 +1 · 충족 카테고리 +1(시안).
// - 스냅샷은 2시간 안 scan 세션 묶음(FD-175)이라 기준 데이터는 "7회 · 9/02 ~ 10/05"다: 9/02 ~ 9/29는 학생 21:40 + 인벤토리
//   21:50이 한 묶음(5회), 10/03 인벤토리 · 10/05 학생이 따로다(시안 "6회"는 인벤토리 "3일 전"과 함께 맞출 수 없다 — status FE7-e
//   발견 사항). A6 · B3 점은 묶음별 마지막 상태라 6점 그대로다.
// 학생 과거 값은 지금 값에서 정해진 순서로 스킬을 한 칸씩 내려 목표 평균(한 자리)에 맞춘다(FD-028 식, 성장 projection으로 잰다).
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:ba_planner_v7/ui/models/planning_growth_rules.dart';

import 'statistics_growth_fixture.dart';
import 'statistics_supply_fixture.dart';

/// 검수 fixture의 "지금"(지역 2026-10-06 12:00).
final statisticsHistoryFixtureNow = DateTime(2026, 10, 6, 12);

/// 학생 스캔 세션 시각(지역 21:40).
final statisticsHistoryStudentScans = [
  for (final (month, day) in const [
    (9, 2),
    (9, 8),
    (9, 15),
    (9, 22),
    (9, 29),
    (10, 5),
  ])
    DateTime(2026, month, day, 21, 40),
];

/// 학생 스냅샷 평균 육성도(% × 10, 마지막 = 지금 fixture 63.4%).
const statisticsHistoryAverageTenths = [581, 590, 602, 614, 622, 634];

/// 인벤토리 스캔 세션 시각(지역 21:50).
final statisticsHistoryInventoryScans = [
  for (final (month, day) in const [
    (9, 2),
    (9, 8),
    (9, 15),
    (9, 22),
    (9, 29),
    (10, 3),
  ])
    DateTime(2026, month, day, 21, 50),
];

/// 재화별 회차 수량(인벤토리 세션 순, 마지막 = 지금 fixture). 표에 없는 재화는 늘 지금 수량이다.
const statisticsHistoryInventoryTracks = <String, List<int>>{
  'credits': [142000000, 130000000, 121000000, 109000000, 104000000, 98400000],
  'Item_Icon_SecretStone': [760, 820, 870, 940, 990, 1020],
  'Item_Icon_ExpItem_2': [180, 210, 240, 260, 280, 384],
  'Item_Icon_SkillBook_Abydos_3': [84, 84, 84, 84, 84, 96],
  'Equipment_Icon_Hairpin_Tier5': [19, 19, 19, 19, 19, 30],
  'Equipment_Icon_Hat_Tier7': [10, 10, 10, 10, 10, 30],
  'Equipment_Icon_Gloves_Tier6': [5, 5, 5, 5, 5, 11],
  'Equipment_Icon_Badge_Tier7': [30, 30, 30, 30, 30, 49],
  'Equipment_Icon_Bag_Tier6': [9, 9, 9, 9, 9, 13],
};

/// 지금 계정 상태의 revision(이력 적용 12건 뒤).
const statisticsHistoryFixtureRevision = 12;

/// 10/05 학생 스캔에서 새로 보유한 학생(9/29까지는 없다).
const statisticsHistoryNewStudents = ['akari_new_year', 'azusa_swimsuit'];

/// 10/05 학생 스캔에서 레벨 90이 된 학생(9/29까지는 85).
const statisticsHistoryLeveledStudents = [
  'akane_school_uniform',
  'aru_dress',
  'chiaki',
  'cherino_hot_springs',
];

/// 10/05 학생 스캔에서 완전 육성이 된 학생(9/29까지는 EX 4).
const statisticsHistoryCompletedStudent = 'akane_bunny_girl';

/// 지금 계정 상태: 학생 성장 fixture 학생 · 목표 + 인벤토리 · 계획 fixture 인벤토리.
RepositoryState statisticsHistoryFixtureState({
  String profileId = '0123456789abcdef01234567',
  int revision = statisticsHistoryFixtureRevision,
}) => statisticsSupplyFixtureState(profileId: profileId, revision: revision);

Map<String, dynamic> _copyStudent(Map<String, dynamic> wire) => {
  ...wire,
  'values': Map<String, dynamic>.of(wire['values'] as Map<String, dynamic>),
};

/// 학생 스냅샷 6개의 학생 wire(오래된 것부터, 마지막 = 지금).
List<List<Map<String, dynamic>>> statisticsHistoryStudentSnapshots() {
  final catalog = {
    for (final entry in statisticsGrowthFixtureCatalog())
      entry.studentId: entry,
  };
  final planned = statisticsGrowthFixturePlannedIds.toSet();
  double growthOf(Map<String, dynamic> wire) =>
      statisticsStudentGrowth(
        ConfirmedStudentState.fromWire(wire),
        catalog: catalog[wire['student_id']],
      ).growth ??
      0;
  int averageTenths(List<Map<String, dynamic>> students) {
    final values = [for (final student in students) growthOf(student)];
    final mean = values.reduce((a, b) => a + b) / values.length;
    return (mean * 1000).round();
  }

  final now = statisticsGrowthFixtureStudentsWire();
  final full = {
    for (final student in now)
      if (growthOf(student) >= 1 - 1e-9) student['student_id'] as String,
  };
  // 9/29: 새 학생 둘을 빼고, 레벨 · 완전 육성 학생을 되돌린다.
  var state = [
    for (final student in now)
      if (!statisticsHistoryNewStudents.contains(student['student_id']))
        _copyStudent(student),
  ];
  for (final student in state) {
    final id = student['student_id'] as String;
    final values = student['values'] as Map<String, dynamic>;
    if (statisticsHistoryLeveledStudents.contains(id)) {
      if (values['level'] != 90) throw StateError('$id must be level 90');
      values['level'] = 85;
    }
    if (id == statisticsHistoryCompletedStudent) {
      if (!full.contains(id)) throw StateError('$id must be fully grown');
      values['ex_skill'] = 4;
    }
  }
  // 스킬을 내릴 학생: 계획 · 완전 육성 · 위에서 고친 학생을 뺀 나머지(id 순).
  final touched = {
    ...statisticsHistoryLeveledStudents,
    statisticsHistoryCompletedStudent,
  };
  final targets =
      [
        for (final student in state)
          if (!planned.contains(student['student_id']) &&
              !full.contains(student['student_id']) &&
              !touched.contains(student['student_id']))
            student,
      ]..sort(
        (a, b) =>
            (a['student_id'] as String).compareTo(b['student_id'] as String),
      );
  const keys = ['skill3', 'skill2', 'skill1', 'ex_skill'];
  var cursor = 0;
  bool lower() {
    for (var tries = 0; tries < targets.length * keys.length; tries++) {
      final student = targets[cursor % targets.length];
      final key = keys[(cursor ~/ targets.length) % keys.length];
      cursor++;
      final values = student['values'] as Map<String, dynamic>;
      final value = values[key] as int;
      if (value > planElementTargetMinimums[key]!) {
        values[key] = value - 1;
        return true;
      }
    }
    return false;
  }

  final snapshots = <List<Map<String, dynamic>>>[now];
  for (
    var index = statisticsHistoryAverageTenths.length - 2;
    index >= 0;
    index--
  ) {
    final target = statisticsHistoryAverageTenths[index];
    while (averageTenths(state) > target) {
      if (!lower()) throw StateError('cannot reach average $target');
    }
    if (averageTenths(state) != target) {
      throw StateError('average ${averageTenths(state)} != $target');
    }
    snapshots.insert(0, [for (final student in state) _copyStudent(student)]);
  }
  return snapshots;
}

/// 인벤토리 회차 [round]의 계정 인벤토리 wire(마지막 회차 = 지금 fixture).
Map<String, dynamic> statisticsHistoryInventoryWire(int round) {
  final now = statisticsSupplyFixtureInventoryWire();
  return {
    'version': 1,
    'entries': [
      for (final entry in now['entries'] as List)
        {
          ...entry as Map<String, dynamic>,
          if (statisticsHistoryInventoryTracks[entry['key']] case final track?)
            'quantity': '${track[round]}',
        },
    ],
  };
}

/// 지금 상태로 끝나는 스캔 이력(legacy 기준선 = 첫 회차 앞 상태).
RepositoryCurrentHistory statisticsHistoryFixtureHistory({
  String profileId = '0123456789abcdef01234567',
}) {
  final students = statisticsHistoryStudentSnapshots();
  RepositoryState stateOf(
    int revision,
    List<Map<String, dynamic>> studentWire,
    Map<String, dynamic> inventory,
  ) => RepositoryState.fromWire({
    'profile_id': profileId,
    'revision': revision,
    'students': studentWire,
    'inventory': inventory,
    'goals': statisticsGrowthFixtureGoalsWire(),
  });
  final sessions = <(DateTime, bool, int)>[
    for (final (index, at) in statisticsHistoryStudentScans.indexed)
      (at, true, index),
    for (final (index, at) in statisticsHistoryInventoryScans.indexed)
      (at, false, index),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  var studentWire = students.first;
  var inventory = statisticsHistoryInventoryWire(0);
  var before = stateOf(0, studentWire, inventory);
  var history = RepositoryCurrentHistory.empty(legacy: before);
  for (final (at, student, index) in sessions) {
    if (student) {
      studentWire = students[index];
    } else {
      inventory = statisticsHistoryInventoryWire(index);
    }
    final after = stateOf(before.revision + 1, studentWire, inventory);
    final kind = student ? 'student' : 'inventory';
    history = history.appendScan(
      before,
      after,
      at,
      rawScanKind: kind,
      rawInventoryScanProfile: student ? null : 'fixture-items',
      scanContext: {
        'session_id': 'fixture-$kind-$index',
        'generation': 1,
        'candidate_id': 'fixture-$kind-candidate-$index',
        'candidate_revision': 0,
      },
      studentIds: student
          ? [for (final item in studentWire) item['student_id'] as String]
          : const [],
      resourceKeys: student
          ? const []
          : [
              for (final entry in inventory['entries'] as List)
                (entry as Map)['key'] as String,
            ],
    );
    before = after;
  }
  if (before.revision != statisticsHistoryFixtureRevision) {
    throw StateError('fixture history revision ${before.revision}');
  }
  return history;
}

/// 시안에서 재현한 숫자.
abstract final class StatisticsHistoryFixtureExpected {
  static const studentScan = '어제 21:40';
  static const inventoryScan = '3일 전';
  static const snapshots = '7회 · 9/02 ~ 10/05';
  static const growthDeltas = ['/ 170 · +2', '+1.2', '+4', '+1', '—'];
  static const inventoryDeltas = ['+6', '−2', '+1', '+1'];
  static const a6Labels = ['9/02', '9/08', '9/15', '9/22', '9/29', '10/05'];
  static const a6Highlight = '9/22 → 10/05 +2.0%p';
  static const b3Panels = ['크레딧', '엘리그마', '상급 활동 보고서'];
  static const b3Changes = ['−43.6M', '+260', '+204'];
}

/// 학생 목록(단위 테스트용, 이름 = id).
List<StudentCatalogEntry> statisticsHistoryFixtureCatalog() =>
    statisticsGrowthFixtureCatalog();
