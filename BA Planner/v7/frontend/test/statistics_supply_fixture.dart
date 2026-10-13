// 통계 "인벤토리 현황" · "계획 집계" 검수 fixture(FE7-c, 시안 Stats-Inventory · Stats-Plan 숫자).
//
// 시안 숫자를 재현해 사용자가 캔버스와 같은 숫자로 비교하게 한다(워크플로 불변식 "mock fixture"). 학생 · 목표는 학생 성장
// fixture(`statistics_growth_fixture.dart`, 계획 학생 9명) 그대로이고, 인벤토리 목록 · 계정 인벤토리 · 부족 계산만 더한다.
// - 인벤토리 KPI: 전체 충족률 72%(크레딧 · 엘리그마 포함 23종 평균 72.05%), 부족 재화 14종, 과잉 재화 6종(보유 ≥ 필요 × 1.5),
//   충족 카테고리 3 / 6, 스캔 없음 1종 · 엘레프.
// - B1: 장비 설계도 78% · 기술 노트 64% · 활동 보고서 91% · 전술 BD 52% · 오파츠 47% · 엘레프 모름(빗금).
// - C1: 크레딧 98.4M / 261.5M · 엘리그마 1020 / 2245가 첫 두 행이다. 계획 범위 칩 "활성 계획 · 9명 · 페이즈 —".
// 시안끼리 맞지 않는 숫자는 재현하지 않는다(status FE7-c 종료 기록 발견 사항): C1 3~5행(시안 기술 노트 (최상급) 96 / 120 ·
// 설계도 · 시계 T8 52 / 60 · 상급 활동 보고서 384 / 300)은 B1 오파츠 47% · 전술 BD 52%와 함께 "부족 큰 순"이 될 수 없어 이
// 재화들은 C1 아래쪽에 있고, C2 기술 노트 (최상급) 24%는 C1 96 / 120(80%)과 맞지 않아 80%다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';

import 'statistics_growth_fixture.dart';

/// 재화 한 줄: key, 이름, category, 필요, 보유(모르면 null), 영향 학생 수.
typedef StatisticsSupplyFixtureRow = (
  String key,
  String name,
  String category,
  int required,
  int? owned,
  int students,
);

const statisticsSupplyFixtureRows = <StatisticsSupplyFixtureRow>[
  // 장비 설계도 9종: 부족 6(합 4.02) + 과잉 3 → 평균 78%.
  ('Equipment_Icon_Watch_Tier8', '설계도 · 시계 T8', 'equipment', 60, 52, 3),
  ('Equipment_Icon_Hat_Tier7', '설계도 · 모자 T7', 'equipment', 50, 30, 2),
  ('Equipment_Icon_Gloves_Tier6', '설계도 · 장갑 T6', 'equipment', 20, 11, 4),
  ('Equipment_Icon_Shoes_Tier7', '설계도 · 신발 T7', 'equipment', 20, 14, 1),
  ('Equipment_Icon_Bag_Tier6', '설계도 · 가방 T6', 'equipment', 20, 13, 2),
  ('Equipment_Icon_Badge_Tier7', '설계도 · 배지 T7', 'equipment', 75, 49, 1),
  ('Equipment_Icon_Hairpin_Tier5', '설계도 · 헤어핀 T5', 'equipment', 20, 30, 2),
  ('Equipment_Icon_Charm_Tier4', '설계도 · 부적 T4', 'equipment', 30, 45, 1),
  ('Equipment_Icon_Necklace_Tier3', '설계도 · 목걸이 T3', 'equipment', 40, 90, 3),
  // 기술 노트 2종: 80% · 48% → 64%.
  ('Item_Icon_SkillBook_Abydos_3', '기술 노트 (최상급)', 'tech_notes', 120, 96, 6),
  ('Item_Icon_SkillBook_Abydos_2', '기술 노트 (상급)', 'tech_notes', 25, 12, 2),
  // 활동 보고서 6종: 충족 4(상급 384 / 300 · 과잉 3) + 73% 2 → 91%.
  ('Item_Icon_ExpItem_2', '상급 활동 보고서', 'activity_report', 300, 384, 5),
  ('Item_Icon_ExpItem_0', '초급 활동 보고서', 'activity_report', 500, 900, 4),
  ('Item_Icon_ExpItem_1', '일반 활동 보고서', 'activity_report', 200, 300, 3),
  ('Item_Icon_ExpItem_Event_1', '일반 활동 보고서 (이벤트)', 'activity_report', 100, 160, 1),
  ('Item_Icon_ExpItem_3', '최상급 활동 보고서', 'activity_report', 100, 73, 2),
  ('Item_Icon_ExpItem_Event_3', '최상급 활동 보고서 (이벤트)', 'activity_report', 200, 146, 1),
  // 전술 BD 2종: 50% · 54% → 52%.
  ('Item_Icon_Material_ExSkill_Abydos_3', '전술 교육 BD (최상급)', 'tactical_bd', 20, 10, 2),
  ('Item_Icon_Material_ExSkill_Abydos_2', '전술 교육 BD (상급)', 'tactical_bd', 50, 27, 1),
  // 오파츠 2종: 46% · 48% → 47%.
  ('Item_Icon_Material_Nebra_3', '네브라 디스크 T4', 'oopart', 50, 23, 6),
  ('Item_Icon_Material_Nimrud_2', '님루드 렌즈 T3', 'oopart', 50, 24, 3),
  // 엘레프 1종: 스캔 없음(보유 모름).
  ('Item_Icon_SecretStone_hoshino', '호시노의 엘레프', 'student_eleph', 120, null, 1),
  // 재화 2종(카테고리 막대 아님, 전체 충족률 · C1에는 든다).
  ('credits', '크레딧', 'credits', 261500000, 98400000, 7),
  ('Item_Icon_SecretStone', '엘리그마', 'eligma', 2245, 1020, 4),
];

InventoryCatalogEntry _entry(StatisticsSupplyFixtureRow row, int order) =>
    InventoryCatalogEntry(
      resourceKey: row.$1,
      itemId: row.$1 == 'credits' ? null : row.$1,
      displayName: row.$2,
      category: row.$3,
      profileId: switch (row.$3) {
        'credits' || 'eligma' => 'currencies',
        final category => category,
      },
      orderIndex: order,
      zeroFillAllowed: row.$3 != 'credits' && row.$3 != 'eligma',
      school: null,
      family: null,
      tier: null,
    );

/// 인벤토리 목록(시안 순서와 무관한 카탈로그 순서 = 위 표 순서).
final statisticsSupplyFixtureCatalog = <InventoryCatalogEntry>[
  for (final (index, row) in statisticsSupplyFixtureRows.indexed)
    _entry(row, index),
];

/// 계정 인벤토리 wire(보유를 모르는 재화는 항목이 없다).
Map<String, dynamic> statisticsSupplyFixtureInventoryWire() => {
  'version': 1,
  'entries': [
    for (final row in statisticsSupplyFixtureRows)
      if (row.$5 != null)
        {
          'key': row.$1,
          'item_id': row.$1 == 'credits' ? null : row.$1,
          'quantity': '${row.$5}',
        },
  ],
};

/// 영향 학생: 계획 학생 9명을 행마다 돌려 가며 [count]명.
List<String> _students(int index, int count) => [
  for (var offset = 0; offset < count; offset++)
    statisticsGrowthFixturePlannedIds[(index + offset) %
        statisticsGrowthFixturePlannedIds.length],
];

/// 부족 계산 결과(계획 학생 9명의 목표에서 나온 것으로 본다).
InventoryShortageResult statisticsSupplyFixtureShortages() =>
    InventoryShortageResult([
      for (final (index, row) in statisticsSupplyFixtureRows.indexed)
        InventoryShortageRow(
          resourceKey: row.$1,
          itemId: row.$1 == 'credits' ? null : row.$1,
          displayName: row.$2,
          category: row.$3,
          requiredAmount: row.$4,
          owned: row.$5,
          shortage: row.$5 == null
              ? null
              : (row.$5! >= row.$4 ? 0 : row.$4 - row.$5!),
          affectedStudentIds: _students(index, row.$6),
          resolved: true,
        ),
    ], const []);

/// 계정 상태: 학생 성장 fixture 학생 · 목표 + 이 인벤토리.
RepositoryState statisticsSupplyFixtureState({
  String profileId = '0123456789abcdef01234567',
  int revision = 1,
}) => statisticsGrowthFixtureState(
  profileId: profileId,
  revision: revision,
  inventory: statisticsSupplyFixtureInventoryWire(),
);

/// 시안에서 재현한 숫자.
abstract final class StatisticsSupplyFixtureExpected {
  static const inventoryKpis = ['72%', '14종', '6종', '3 / 6', '1종'];
  static const unknownLabel = '엘레프';
  static const b1Labels = [
    '장비 설계도',
    '기술 노트',
    '활동 보고서',
    '전술 BD',
    '오파츠',
    '엘레프',
  ];
  static const b1Percents = ['78%', '64%', '91%', '52%', '47%', '—'];
  static const c1FirstRows = ['98.4M / 261.5M', '1020 / 2245'];
  static const planStudents = 9;
}
