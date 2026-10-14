// FE6-a 인벤토리 시안 숫자 데이터(시안 Inventory "부족한 것 · 엘레프 선택"의 예시 값). mockdemo에서
// `test/inventory_fe6a_fixture.dart`에서 옮겼다.
//
// 테스트 fixture(`test/inventory_fe6a_fixture.dart`의 `InventoryFixtureService`)와 검수 시나리오 Mock
// (`mock_design_review_scenario.dart`)이 같이 쓴다. `MockAppService` 기본값은 바꾸지 않는다.
// - 계정 `000000000000000000000001`(Mock 기본 Main, 선택됨), 학생 6명, 저장된 목표 6개(목표 v1 → Mock 활성 문서
//   한 페이즈 `v6-imported-plan`, 단계 `v6-<학생>-1`, 단계 이름 = notes).
// - 카탈로그: 엘레프 2 · 기술 노트 2 · BD 1 · 오파츠 1 · 활동 보고서 3 · 장비 2(강화석 · 헤어핀) + 재화 2(credits ·
//   엘리그마).
// - 부족 계산(`calculateShortages`)과 활성 문서 계산(`calculatePlanningDocument`)은 같은 표 [inventoryFixturePlan]에서
//   만든다. 위험도(FD-030 (b)): 리오 엘레프 1/450·1명 → 99.78(표시 100), 오파츠 3/40·2명 → 95.4999(95), 기술 노트
//   12/60·4명 → 91.07(91), 토키 엘레프 53/330·1명 → 83.94(84), BD 20/28·3명 → 55.05(55). 활동 보고서(상급)는 보유를
//   모른다(점수 —). 장비 헤어핀 0/55·2명 → 100(장비 모드).
// - 획득처: 카탈로그 품목은 FB-3 packaged v1처럼 빈 표(methods = [])다.
// - 학생 id · 엘레프 key는 실제 그림 id(`rio_battle` · `toki_battle`)다(FE6-e 발견 3, FE6-f에서 고침).
// - 이력(FE6-f, [inventoryFixtureScans]): 지금 = 2026-10-05 12:00 UTC([AppClockSource]), 스캔 회차 31 · 24 · 17 · 10
//   · 3일 전, profile별 세션. 시안 KPI "+3 지난 스캔 대비"(BD · 네브라 · 헤어핀이 지난 스캔 뒤 부족으로) · "−1"(네브라가 과잉
//   에서 빠짐) · "최근 감소 6종" · "마지막 스캔 3일 전", 리오 엘레프 스파크라인 0 · 0 · 1 · 1("순변화 +1 · 이전 스캔과 이상
//   없음"). 기술 노트(최상급)는 31 · 24 · 18 · 12(시안 18 · 15 · 12 · 12는 추세 규칙으로 "소진 예상"이 나오지 않아 바꿨다,
//   "순변화 −19 · 2주 뒤 소진 예상"). `owned`를 바꿔 만들면 이력은 넣지 않는다(지금 수량과 맞지 않으므로).
import '../app_service.dart';

const inventoryFixtureProfileId = '000000000000000000000001';
const inventoryFixtureRevision =
    'ace36d60b34093ee29af143e0b60fc22166002e85de13b095600378e62e690d8';

/// 학생 id → 표시 이름.
const inventoryFixtureStudents = <String, String>{
  'rio_battle': '리오(무장)',
  'toki_battle': '토키(무장)',
  'aru': '아루',
  'hoshino': '호시노',
  'ayane': '아야네',
  'hina': '히나',
};

/// 단계 이름(목표 notes).
const inventoryFixtureStageNames = <String, String>{
  'rio_battle': '성급 3→5',
  'toki_battle': '성급 3→5',
  'aru': '스킬',
  'hoshino': '스킬',
  'ayane': 'EX',
  'hina': 'EX',
};

InventoryCatalogEntry _entry(
  String key,
  String name,
  String category,
  String profile,
  int order, {
  String? itemId,
  bool useKeyAsItem = true,
  String? school,
  String? family,
  int? tier,
  bool zeroFill = true,
}) => InventoryCatalogEntry(
  resourceKey: key,
  itemId: itemId ?? (useKeyAsItem ? key : null),
  displayName: name,
  category: category,
  profileId: profile,
  orderIndex: order,
  zeroFillAllowed: zeroFill,
  school: school,
  family: family,
  tier: tier,
);

/// 카탈로그(백엔드 순서: 장비 → 활동 보고서 → 노트·BD → 오파츠 → 엘레프 → 재화).
final inventoryFixtureCatalog = <InventoryCatalogEntry>[
  // FE6-b: 장비 profile 안의 FB-3 family 묶음(강화석 · 장비)을 보이도록 강화석 한 줄(저장 항목 없음 = 모름, 계획
  // 무관)을 두고 헤어핀에 family · tier를 단다. `inventory` 장면(아이템 모드)의 숫자는 바뀌지 않는다.
  _entry('Equipment_Icon_Exp_3', '최상급 강화석', 'equipment', 'equipment', 0, family: 'equipment_exp', tier: 4),
  _entry('Equipment_Icon_Hairpin_Tier7', '다목적 헤어핀', 'equipment', 'equipment', 1, family: 'equipment:Hairpin', tier: 7),
  _entry('Item_Icon_ExpItem_0', '초급 활동 보고서', 'activity_report', 'activity_reports', 0, family: 'activity_report', tier: 1),
  _entry('Item_Icon_ExpItem_1', '일반 활동 보고서', 'activity_report', 'activity_reports', 1, family: 'activity_report', tier: 2),
  _entry('Item_Icon_ExpItem_2', '상급 활동 보고서', 'activity_report', 'activity_reports', 2, family: 'activity_report', tier: 3),
  _entry('Item_Icon_SkillBook_Gehenna_3', '기술 노트 (최상급)', 'tech_notes', 'tech_notes', 3, school: 'Gehenna', family: 'tech_notes', tier: 4),
  _entry('Item_Icon_SkillBook_Abydos_0', '기술 노트 (초급)', 'tech_notes', 'tech_notes', 4, school: 'Abydos', family: 'tech_notes', tier: 1),
  _entry('Item_Icon_Material_ExSkill_Gehenna_3', '전술 교육 BD (최상급)', 'tactical_bd', 'tactical_bd', 3, school: 'Gehenna', family: 'tactical_bd', tier: 4),
  _entry('Item_Icon_Material_Nebra_1', '네브라 디스크 T2', 'oopart', 'ooparts', 1, family: 'oopart:Nebra', tier: 2),
  _entry('Item_Icon_SecretStone_rio_battle', '리오(무장)의 엘레프', 'student_eleph', 'student_elephs', 0),
  _entry('Item_Icon_SecretStone_toki_battle', '토키(무장)의 엘레프', 'student_eleph', 'student_elephs', 1),
  _entry('credits', '크레딧', 'credits', 'currencies', 0, useKeyAsItem: false, zeroFill: false),
  _entry('Item_Icon_SecretStone', '엘리그마', 'eligma', 'currencies', 1, zeroFill: false),
];

/// 저장된 인벤토리(수량 문자열). 활동 보고서(상급)·초급 노트는 항목이 없다(모름).
const inventoryFixtureOwned = <String, String>{
  'Equipment_Icon_Hairpin_Tier7': '0',
  'Item_Icon_ExpItem_0': '900',
  'Item_Icon_ExpItem_1': '500',
  'Item_Icon_SkillBook_Gehenna_3': '12',
  'Item_Icon_Material_ExSkill_Gehenna_3': '20',
  'Item_Icon_Material_Nebra_1': '3',
  'Item_Icon_SecretStone_rio_battle': '1',
  'Item_Icon_SecretStone_toki_battle': '53',
  'credits': '98400000',
  'Item_Icon_SecretStone': '1020',
};

/// 계획 표: 재화 → 학생별 필요량(학생 순서 = 문서 단계 순서).
const inventoryFixturePlan = <String, Map<String, int>>{
  'Item_Icon_SecretStone_rio_battle': {'rio_battle': 450},
  'Item_Icon_SecretStone_toki_battle': {'toki_battle': 330},
  'Item_Icon_SkillBook_Gehenna_3': {'aru': 15, 'hoshino': 15, 'ayane': 15, 'hina': 15},
  'Item_Icon_Material_ExSkill_Gehenna_3': {'aru': 10, 'ayane': 9, 'hina': 9},
  'Item_Icon_Material_Nebra_1': {'hoshino': 20, 'ayane': 20},
  'Item_Icon_ExpItem_1': {'aru': 120},
  'Item_Icon_ExpItem_2': {'hoshino': 30},
  'Equipment_Icon_Hairpin_Tier7': {'aru': 30, 'hina': 25},
  'credits': {'rio_battle': 100000000, 'toki_battle': 100000000, 'aru': 31500000, 'hina': 30000000},
  'Item_Icon_SecretStone': {'rio_battle': 2245},
};

/// 스캔 이력(FE6-f): scan profile → 재화 → (며칠 전 → 수량). 마지막 값은 [inventoryFixtureOwned]와 같다.
const inventoryFixtureScans = <String, Map<String, Map<int, int>>>{
  'student_elephs': {
    'Item_Icon_SecretStone_rio_battle': {31: 0, 24: 0, 17: 0, 10: 1, 3: 1},
    'Item_Icon_SecretStone_toki_battle': {31: 38, 24: 40, 17: 45, 10: 50, 3: 53},
  },
  'tech_notes': {
    'Item_Icon_SkillBook_Gehenna_3': {31: 36, 24: 31, 17: 24, 10: 18, 3: 12},
  },
  'tactical_bd': {
    'Item_Icon_Material_ExSkill_Gehenna_3': {31: 33, 24: 32, 17: 30, 10: 31, 3: 20},
  },
  'ooparts': {
    'Item_Icon_Material_Nebra_1': {31: 70, 24: 66, 17: 64, 10: 62, 3: 3},
  },
  'activity_reports': {
    'Item_Icon_ExpItem_0': {31: 600, 24: 700, 17: 800, 10: 950, 3: 900},
    'Item_Icon_ExpItem_1': {31: 300, 24: 400, 17: 450, 10: 520, 3: 500},
  },
  'equipment': {
    'Equipment_Icon_Hairpin_Tier7': {31: 70, 24: 66, 17: 62, 10: 58, 3: 0},
  },
};

/// 계정 상태 wire(학생 · 목표는 fixture 그대로, 수량만 [owned]).
Map<String, dynamic> inventoryFixtureStateWire({
  required int revision,
  required Map<String, String> owned,
  bool plan = true,
}) => {
  'profile_id': inventoryFixtureProfileId,
  'revision': revision,
  'students': [
    for (final id in inventoryFixtureStudents.keys)
      {
        'version': 1,
        'student_id': id,
        'values': {'level': 70, 'student_star': 3},
      },
  ],
  'inventory': {
    'version': 1,
    'entries': [
      for (final entry in owned.entries)
        {
          'key': entry.key,
          'item_id': entry.key == 'credits' ? null : entry.key,
          'quantity': entry.value,
        },
    ],
  },
  'goals': {
    'version': 1,
    'goals': [
      if (plan)
        for (final id in inventoryFixtureStudents.keys)
          {
            'student_id': id,
            'target_level': 80,
            'notes': inventoryFixtureStageNames[id],
          },
    ],
  },
};

/// 저장된 인벤토리 [inventory]에서 [key]의 보유량. 항목이 없거나 수량이 없으면 null(모름).
int? inventoryFixtureOwnedQuantity(Map<String, dynamic> inventory, String key) {
  for (final raw in inventory['entries'] as List? ?? const []) {
    final entry = raw as Map;
    if ((entry['item_id'] ?? entry['key']) == key) {
      final quantity = entry['quantity'];
      return quantity == null ? null : int.parse(quantity as String);
    }
  }
  return null;
}

/// 카탈로그 품목 [key].
InventoryCatalogEntry inventoryFixtureItem(String key) =>
    inventoryFixtureCatalog.firstWhere((item) => item.resourceKey == key);

/// 부족 계산(`calculateShortages`) 결과: 계획 표 [inventoryFixturePlan]과 저장된 인벤토리 [inventory]에서 만든다.
InventoryShortageResult inventoryFixtureShortages(
  Map<String, dynamic> inventory,
) => InventoryShortageResult([
  for (final entry in inventoryFixturePlan.entries)
    () {
      final required = entry.value.values.fold<int>(0, (a, b) => a + b);
      final owned = inventoryFixtureOwnedQuantity(inventory, entry.key);
      final item = inventoryFixtureItem(entry.key);
      return InventoryShortageRow(
        resourceKey: entry.key,
        itemId: entry.key == 'credits' ? null : entry.key,
        displayName: item.displayName,
        category: item.category,
        requiredAmount: required,
        owned: owned,
        shortage: owned == null
            ? null
            : (owned >= required ? 0 : required - owned),
        affectedStudentIds: entry.value.keys.toList(),
        resolved: true,
      );
    }(),
], const []);
