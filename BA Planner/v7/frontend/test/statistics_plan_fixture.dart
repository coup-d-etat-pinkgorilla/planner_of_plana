// 통계 "계획 집계" 활성 문서 · 문서 계산 검수 fixture(FE7-g, 시안 Stats-Plan 숫자).
//
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
// mockdemo: 문서 · 문서 계산 데이터는 검수 시나리오 Mock과 같이 쓰도록 `lib/services/design_review/statistics_plan_data.dart`로
// 옮겼고 이 파일은 같은 이름을 그대로 내보낸다. 기대값만 여기 있다.
import 'package:ba_planner_v7/services/design_review/statistics_plan_data.dart';

export 'package:ba_planner_v7/services/design_review/statistics_plan_data.dart';

/// 시안에서 재현한 숫자.
abstract final class StatisticsPlanFixtureExpected {
  static const phaseCount = 5;
  static const firstPhase = 'P2';
  static const firstResource = '기술 노트 (최상급)';
  static const blockedStudents = 6;
  static const scope = '활성 계획 · 9명 · 페이즈 5';

  /// C3 선(첫 부족 재화가 처음), 페이즈마다 누적 부족 %.
  static const c3 = <(String, List<int>)>[
    (statisticsPlanFixtureTechNote, [0, 18, 41, 62, 74]),
    (statisticsPlanFixtureEligma, [0, 0, 12, 22, 30]),
    (statisticsPlanFixtureWatch, [0, 0, 0, 9, 15]),
  ];

  /// 기술 노트 (최상급) 막히는 단계(페이즈 · 학생 · 부족).
  static const techNoteStages = <(int, String, int)>[
    (2, 'hoshino', 18),
    (3, 'aris', 23),
    (4, 'hina', 21),
    (5, 'kazusa', 12),
  ];
  static const techNoteCumulative = 74;
}
