// FE6-a 인벤토리 검수 fixture(시안 Inventory "부족한 것 · 엘레프 선택"의 예시 값).
//
// `MockAppService` 기본값은 바꾸지 않는다(서비스 파일은 이 slice 범위 밖). 테스트와 golden이 이 대역을 쓴다.
// - 계정 `000000000000000000000001`(Mock 기본 Main, 선택됨), 학생 6명, 저장된 목표 6개(목표 v1 → Mock 활성 문서
//   한 페이즈 `v6-imported-plan`, 단계 `v6-<학생>-1`, 단계 이름 = notes).
// - 카탈로그: 엘레프 2 · 기술 노트 2 · BD 1 · 오파츠 1 · 활동 보고서 3 · 장비 2(강화석 · 헤어핀) + 재화 2(credits ·
//   엘리그마).
// - 부족 계산(`calculateShortages`)과 활성 문서 계산(`calculatePlanningDocument`)은 같은 표 [inventoryFixturePlan]에서
//   만든다. 위험도(FD-030 (b)): 리오 엘레프 1/450·1명 → 99.78(표시 100), 오파츠 3/40·2명 → 95.4999(95), 기술 노트
//   12/60·4명 → 91.07(91), 토키 엘레프 53/330·1명 → 83.94(84), BD 20/28·3명 → 55.05(55). 활동 보고서(상급)는 보유를
//   모른다(점수 —). 장비 헤어핀 0/55·2명 → 100(장비 모드).
// - 획득처: 카탈로그 품목은 FB-3 packaged v1처럼 빈 표(methods = [])다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';

const inventoryFixtureProfileId = '000000000000000000000001';
const inventoryFixtureRevision =
    'ace36d60b34093ee29af143e0b60fc22166002e85de13b095600378e62e690d8';

/// 학생 id → 표시 이름.
const inventoryFixtureStudents = <String, String>{
  'rio_armed': '리오(무장)',
  'toki_armed': '토키(무장)',
  'aru': '아루',
  'hoshino': '호시노',
  'ayane': '아야네',
  'hina': '히나',
};

/// 단계 이름(목표 notes).
const inventoryFixtureStageNames = <String, String>{
  'rio_armed': '성급 3→5',
  'toki_armed': '성급 3→5',
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
  _entry('Item_Icon_SecretStone_rio_armed', '리오(무장)의 엘레프', 'student_eleph', 'student_elephs', 0),
  _entry('Item_Icon_SecretStone_toki_armed', '토키(무장)의 엘레프', 'student_eleph', 'student_elephs', 1),
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
  'Item_Icon_SecretStone_rio_armed': '1',
  'Item_Icon_SecretStone_toki_armed': '53',
  'credits': '98400000',
  'Item_Icon_SecretStone': '1020',
};

/// 계획 표: 재화 → 학생별 필요량(학생 순서 = 문서 단계 순서).
const inventoryFixturePlan = <String, Map<String, int>>{
  'Item_Icon_SecretStone_rio_armed': {'rio_armed': 450},
  'Item_Icon_SecretStone_toki_armed': {'toki_armed': 330},
  'Item_Icon_SkillBook_Gehenna_3': {'aru': 15, 'hoshino': 15, 'ayane': 15, 'hina': 15},
  'Item_Icon_Material_ExSkill_Gehenna_3': {'aru': 10, 'ayane': 9, 'hina': 9},
  'Item_Icon_Material_Nebra_1': {'hoshino': 20, 'ayane': 20},
  'Item_Icon_ExpItem_1': {'aru': 120},
  'Item_Icon_ExpItem_2': {'hoshino': 30},
  'Equipment_Icon_Hairpin_Tier7': {'aru': 30, 'hina': 25},
  'credits': {'rio_armed': 100000000, 'toki_armed': 100000000, 'aru': 31500000, 'hina': 30000000},
  'Item_Icon_SecretStone': {'rio_armed': 2245},
};

/// 검수 fixture 서비스. [plan]이 false면 목표 없이(부족 계산 없음) 시작한다.
class InventoryFixtureService extends MockAppService {
  InventoryFixtureService({bool plan = true, Map<String, String>? owned})
    : super(
        repositoryStates: {
          inventoryFixtureProfileId: {
            'profile_id': inventoryFixtureProfileId,
            'revision': 3,
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
                for (final entry in (owned ?? inventoryFixtureOwned).entries)
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
          },
        },
      );

  int shortageCalls = 0;
  int documentCalls = 0;

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      InventoryCatalogResult(
        catalogRevision: inventoryFixtureRevision,
        items: inventoryFixtureCatalog,
      );

  @override
  Future<List<StudentCatalogEntry>> listStudents() async => [
    for (final entry in inventoryFixtureStudents.entries)
      StudentCatalogEntry(
        studentId: entry.key,
        displayName: entry.value,
        templateName: '${entry.key}.png',
        group: entry.key,
        variant: null,
        school: 'Gehenna',
        rarity: '3',
        attackType: 'Explosive',
        defenseType: 'Light',
        combatClass: 'Striker',
        role: 'Dealer',
        position: 'Back',
        searchTags: const [],
        krSearchTags: const [],
      ),
  ];

  static int? _owned(Map<String, dynamic> inventory, String key) {
    for (final raw in inventory['entries'] as List? ?? const []) {
      final entry = raw as Map;
      if ((entry['item_id'] ?? entry['key']) == key) {
        final quantity = entry['quantity'];
        return quantity == null ? null : int.parse(quantity as String);
      }
    }
    return null;
  }

  static String _name(String key) => inventoryFixtureCatalog
      .firstWhere((item) => item.resourceKey == key)
      .displayName;

  static String _category(String key) => inventoryFixtureCatalog
      .firstWhere((item) => item.resourceKey == key)
      .category;

  @override
  Future<ResourceAcquisitionResult> getResourceAcquisition(
    String resourceKey,
  ) async {
    if (!inventoryFixtureCatalog.any((item) => item.resourceKey == resourceKey)) {
      return super.getResourceAcquisition(resourceKey);
    }
    return ResourceAcquisitionResult.fromWire({
      'resource_key': resourceKey,
      'methods': <dynamic>[],
      'acquisition_revision': mockEmptyResourceAcquisitionRevision,
    });
  }

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async {
    shortageCalls += 1;
    return InventoryShortageResult([
      for (final entry in inventoryFixturePlan.entries)
        () {
          final required = entry.value.values.fold<int>(0, (a, b) => a + b);
          final owned = _owned(inventory, entry.key);
          return InventoryShortageRow(
            resourceKey: entry.key,
            itemId: entry.key == 'credits' ? null : entry.key,
            displayName: _name(entry.key),
            category: _category(entry.key),
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
  }

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    documentCalls += 1;
    final remaining = <String, int?>{
      for (final key in inventoryFixturePlan.keys) key: _owned(inventory, key),
    };
    final stageResults = <Map<String, dynamic>>[];
    for (final rawPhase in document['phases'] as List? ?? const []) {
      final phase = Map<String, dynamic>.from(rawPhase as Map);
      for (final rawStage in phase['stages'] as List? ?? const []) {
        final stage = Map<String, dynamic>.from(rawStage as Map);
        final student = stage['student_id'] as String;
        final resources = <Map<String, dynamic>>[];
        for (final entry in inventoryFixturePlan.entries) {
          final required = entry.value[student];
          if (required == null) continue;
          final before = remaining[entry.key];
          resources.add({
            'resource_key': entry.key,
            'item_id': entry.key == 'credits' ? null : entry.key,
            'display_name': _name(entry.key),
            'category': _category(entry.key),
            'required': required,
            'owned_at_entry': before,
            'shortage_at_entry': before == null
                ? null
                : (before >= required ? 0 : required - before),
          });
          if (before != null) {
            remaining[entry.key] = before >= required ? before - required : 0;
          }
        }
        stageResults.add({
          'stage_id': stage['stage_id'],
          'phase_id': phase['phase_id'],
          'student_id': student,
          'name': stage['name'],
          'cost': <String, dynamic>{},
          'resources': resources,
        });
      }
    }
    return {
      'document_id': document['document_id'],
      'kind': document['kind'],
      'stage_results': stageResults,
      'phase_results': <dynamic>[],
      'overall': {
        'cost': <String, dynamic>{'credits': 0},
        'resources': <dynamic>[],
      },
      'bottlenecks': <dynamic>[],
      'warnings': <dynamic>[],
    };
  }
}
