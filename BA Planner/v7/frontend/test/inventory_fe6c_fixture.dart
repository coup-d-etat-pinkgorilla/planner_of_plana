// FE6-c 인벤토리 분석 검수 fixture(시안 Inventory-Analysis의 예시 값을 따른 대역).
//
// FE6-a fixture(`inventory_fe6a_fixture.dart`)는 `inventory`·`inventory-all` 장면이 쓰므로 건드리지 않고 따로 둔다.
// `MockAppService` 기본값도 바꾸지 않는다(서비스 파일은 이 slice 범위 밖).
// - 계정 `000000000000000000000001`(Mock 기본 Main, 선택됨), 학생 23명, 학생마다 목표 1개(Mock 활성 문서 한 페이즈,
//   단계 `v6-<학생>-1`, 문서 순서 = [inventoryAnalysisFixtureStudents] 순서).
// - S1: 학교 6곳(밀레니엄 · 게헨나 · 트리니티 · 아비도스 · 백귀야행 · 산해경)이 BD 한 티어 · 노트 한 티어를 쓴다. 필요는 학교
//   학생 수 × 20, 보유는 시안 %대로(BD 91 · 노트 76 등). 붉은겨울 BD는 카탈로그에만 있다(계획 밖, FD-099로 행 없음).
// - S2: 오파츠 8종 × T1~T4. 티어별 보유율은 시안 점 위치를 따른 값이고, 사용 학생 수는 오파츠마다 같다.
// - S4: 장비 9부위 × T1~T10 카탈로그, 계획은 T5~T10(필요 10, 시안 % 근사). 부족 상위 3은 시계 T8(필요 80 · 보유 44 ·
//   학생 7명), 가방 T10(필요 30 · 보유 8 · 학생 2명), 헤어핀 T10(필요 20 · 보유 8 · 학생 1명)이다. 목걸이 T9는 보유 항목이
//   없다(모름, 빗금).
// - 부족 계산과 문서 계산은 FE6-a fixture와 같은 방식(문서 순서대로 보유를 깎는다)이다.
// - S5 최근 변화(FE6-f, [inventoryAnalysisFixtureScans]): 지금 = 2026-10-05 12:00 UTC, 스캔 회차 31 · 24 · 17 · 10 · 3일 전.
//   1주 순증감 상위 6행 = 상급 활동 보고서 +120 · 로혼치 사본 T1 +36 · 밀레니엄 BD (최상급) +24 · 트리니티 기술 노트
//   (최상급) −7 · 시계 T8 설계도 −9 · 게헨나 기술 노트 (최상급) −14. 이 추세라면 = 트리니티 기술 노트 (최상급) 부족이
//   커지는 중(4주 뒤 −66) · 밀레니엄 BD (상급)은 곧 충분(2주 뒤 0). 시안 견본(로혼치 +86 · 네브라 −6)은 계획 재화의 지금
//   보유(S2 · S4 값)를 바꾸지 않고는 낼 수 없어 가까운 값으로 두었다. 상급 활동 보고서와 밀레니엄 BD (최상급)은 계획에
//   쓰지 않는 보유 항목으로 더했다(S1 · S2 · S4는 계획 재화만 그린다).
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';

import 'inventory_history_fixture.dart';

const inventoryAnalysisFixtureProfileId = '000000000000000000000001';
const inventoryAnalysisFixtureRevision =
    '6c0f6c6a1e3c1f3a3b7c2c5e0a4f9d8e7b6a5c4d3e2f1a0b9c8d7e6f5a4b3c2d';

/// 학생 id → 표시 이름(문서 순서).
const inventoryAnalysisFixtureStudents = <String, String>{
  'rio_battle': '리오(무장)',
  'toki_battle': '토키(무장)',
  'himari_battle': '히마리(무장)',
  'noa': '노아',
  'yuuka': '유우카',
  'hina': '히나',
  'aru': '아루',
  'iori': '이오리',
  'ako': '아코',
  'chinatsu': '치나츠',
  'haruna': '하루나',
  'kayoko': '카요코',
  'mika': '미카',
  'kazusa': '카즈사',
  'mari': '마리',
  'hifumi': '히후미',
  'hoshino': '호시노',
  'shiroko': '시로코',
  'izuna': '이즈나',
  'michiru': '미치루',
  'tsukuyo': '츠쿠요',
  'kisaki': '키사키',
  'saya': '사야',
};

/// 학교 → (BD 티어, BD %, 노트 티어, 노트 %, 학생).
const inventoryAnalysisFixtureSchools =
    <String, (int, int, int, int, List<String>)>{
      'Millennium': (3, 91, 2, 76, ['rio_battle', 'toki_battle', 'himari_battle', 'noa', 'yuuka']),
      'Gehenna': (3, 82, 4, 41, ['hina', 'aru', 'iori', 'ako', 'chinatsu', 'haruna', 'kayoko']),
      'Trinity': (3, 68, 4, 54, ['mika', 'kazusa', 'mari', 'hifumi']),
      'Abydos': (3, 95, 4, 88, ['hoshino', 'shiroko']),
      'Hyakkiyako': (3, 31, 2, 22, ['izuna', 'michiru', 'tsukuyo']),
      'Shanhaijing': (3, 40, 4, 35, ['kisaki', 'saya']),
    };

const _schoolNames = <String, String>{
  'Millennium': '밀레니엄',
  'Gehenna': '게헨나',
  'Trinity': '트리니티',
  'Abydos': '아비도스',
  'Hyakkiyako': '백귀야행',
  'Shanhaijing': '산해경',
  'RedWinter': '붉은겨울',
};

const _noteTiers = ['초급', '일반', '상급', '최상급'];

/// 오파츠 (icon key, 이름, 사용 학생, T1~T4 보유율 %).
const inventoryAnalysisFixtureOoparts = <(String, String, List<String>, List<int>)>[
  ('Nebra', '네브라 디스크', ['rio_battle', 'toki_battle', 'noa', 'yuuka', 'hina', 'aru', 'mika'], [70, 50, 30, 8]),
  ('Rohonc', '로혼치 사본', ['iori', 'ako', 'chinatsu', 'haruna', 'kayoko', 'kazusa'], [80, 60, 40, 20]),
  ('Phaistos', '파에스토스 원반', ['mari', 'hifumi', 'hoshino', 'shiroko', 'izuna'], [95, 75, 55, 35]),
  ('Antikythera', '안티키테라 장치', ['michiru', 'tsukuyo', 'kisaki', 'saya'], [100, 100, 80, 60]),
  ('GoldenFleece', '황금 양털', ['rio_battle', 'himari_battle', 'noa', 'hina', 'mika', 'mari', 'hoshino'], [100, 100, 100, 80]),
  ('Wolfsegg', '볼프세크 강철', ['aru', 'iori'], [100, 100, 100, 85]),
  ('Nimrud', '님루드 렌즈', ['kazusa', 'saya'], [90, 70, 50, 30]),
  ('Voynich', '보이니치 사본', ['ako', 'izuna', 'kisaki'], [100, 90, 70, 50]),
];

/// 장비 부위(icon key, 이름). 카탈로그는 T1~T10, 계획은 T5~T10.
const inventoryAnalysisFixtureParts = <(String, String)>[
  ('Hat', '모자'),
  ('Gloves', '장갑'),
  ('Shoes', '신발'),
  ('Bag', '가방'),
  ('Badge', '배지'),
  ('Hairpin', '헤어핀'),
  ('Watch', '시계'),
  ('Necklace', '목걸이'),
  ('Charm', '부적'),
];

/// 부위별 T5~T10 보유(필요 10 기준, 시안 % 근사). 시계 T8 · 가방 T10 · 헤어핀 T10은 아래 [_blueprintOverrides]다.
const _blueprintOwned = <String, List<int>>{
  'Hat': [10, 9, 6, 7, 6, 2],
  'Gloves': [10, 8, 7, 7, 5, 4],
  'Shoes': [10, 9, 5, 3, 3, 4],
  'Bag': [10, 9, 6, 7, 3, 0],
  'Badge': [10, 10, 7, 5, 4, 3],
  'Hairpin': [9, 10, 10, 7, 3, 0],
  'Watch': [10, 9, 8, 0, 3, 3],
  'Necklace': [10, 10, 9, 8, 0, 3],
  'Charm': [10, 10, 7, 8, 7, 3],
};

/// (필요, 보유, 학생) 덮어쓰기.
const _blueprintOverrides = <String, (int, int, List<String>)>{
  'Equipment_Icon_Watch_Tier8': (80, 44, ['hina', 'aru', 'iori', 'mika', 'kazusa', 'hoshino', 'izuna']),
  'Equipment_Icon_Bag_Tier10': (30, 8, ['hina', 'mika']),
  'Equipment_Icon_Hairpin_Tier10': (20, 8, ['aru']),
};

/// 보유 항목이 없는 계획 재화(모름).
const inventoryAnalysisFixtureUnknown = {'Equipment_Icon_Necklace_Tier9'};

InventoryCatalogEntry _entry(
  String key,
  String name,
  String category,
  String profile,
  int order, {
  String? school,
  String? family,
  int? tier,
}) => InventoryCatalogEntry(
  resourceKey: key,
  itemId: key,
  displayName: name,
  category: category,
  profileId: profile,
  orderIndex: order,
  zeroFillAllowed: true,
  school: school,
  family: family,
  tier: tier,
);

/// 학생을 [count]명에게 고르게 나눈 필요량(앞 학생이 1씩 더 받는다).
Map<String, int> _split(List<String> students, int total) => {
  for (var index = 0; index < students.length; index++)
    students[index]:
        total ~/ students.length + (index < total % students.length ? 1 : 0),
};

/// 카탈로그 · 보유 · 계획 표를 한 번에 만든다.
final _fixture = () {
  final catalog = <InventoryCatalogEntry>[];
  final owned = <String, String>{};
  final plan = <String, Map<String, int>>{};
  var order = 0;
  for (final (part, label) in inventoryAnalysisFixtureParts) {
    for (var tier = 1; tier <= 10; tier++) {
      final key = 'Equipment_Icon_${part}_Tier$tier';
      catalog.add(
        _entry(key, '$label T$tier 설계도', 'equipment', 'equipment', order++,
            family: 'equipment:$part', tier: tier),
      );
      if (tier < 5) continue;
      final override = _blueprintOverrides[key];
      final students = override?.$3 ??
          [inventoryAnalysisFixtureStudents.keys.elementAt((tier + order) % 23)];
      plan[key] = _split(students, override?.$1 ?? 10);
      if (!inventoryAnalysisFixtureUnknown.contains(key)) {
        owned[key] = '${override?.$2 ?? _blueprintOwned[part]![tier - 5]}';
      }
    }
  }
  for (final (category, profile, prefix, kind) in const [
    ('tech_notes', 'tech_notes', 'Item_Icon_SkillBook', '기술 노트'),
    ('tactical_bd', 'tactical_bd', 'Item_Icon_Material_ExSkill', 'BD'),
  ]) {
    var index = 0;
    for (final school in const [
      'Hyakkiyako', 'RedWinter', 'Trinity', 'Gehenna', 'Abydos', 'Millennium', 'Shanhaijing',
    ]) {
      for (var tier = 1; tier <= 4; tier++) {
        final key = '${prefix}_${school}_${tier - 1}';
        catalog.add(
          _entry(key, '${_schoolNames[school]} $kind (${_noteTiers[tier - 1]})', category, profile,
              index++, school: school, family: profile, tier: tier),
        );
        final row = inventoryAnalysisFixtureSchools[school];
        if (row == null) continue;
        final (bdTier, bdPct, noteTier, notePct, students) = row;
        final plannedTier = category == 'tactical_bd' ? bdTier : noteTier;
        if (tier != plannedTier) continue;
        final total = students.length * 20;
        plan[key] = _split(students, total);
        owned[key] = '${total * (category == 'tactical_bd' ? bdPct : notePct) ~/ 100}';
      }
    }
  }
  var index = 0;
  for (final (icon, label, students, percents) in inventoryAnalysisFixtureOoparts) {
    for (var tier = 1; tier <= 4; tier++) {
      final key = 'Item_Icon_Material_${icon}_${tier - 1}';
      catalog.add(
        _entry(key, '$label T$tier', 'oopart', 'ooparts', index++,
            family: 'oopart:$icon', tier: tier),
      );
      final total = students.length * 10;
      plan[key] = _split(students, total);
      owned[key] = '${total * percents[tier - 1] ~/ 100}';
    }
  }
  // FE6-f: 계획에 쓰지 않는 보유 항목(S5 순증감 행).
  catalog.add(
    _entry('Item_Icon_ExpItem_2', '상급 활동 보고서', 'activity_report', 'activity_reports', 2,
        family: 'activity_report', tier: 3),
  );
  owned['Item_Icon_ExpItem_2'] = '640';
  owned['Item_Icon_Material_ExSkill_Millennium_3'] = '40';
  return (catalog: catalog, owned: owned, plan: plan);
}();

/// 스캔 이력(FE6-f): scan profile → 재화 → (며칠 전 → 수량). 마지막 값은 지금 보유와 같다.
const inventoryAnalysisFixtureScans = <String, Map<String, Map<int, int>>>{
  'activity_reports': {
    'Item_Icon_ExpItem_2': {31: 400, 10: 520, 3: 640},
  },
  'ooparts': {
    'Item_Icon_Material_Rohonc_0': {31: 20, 10: 12, 3: 48},
  },
  'tactical_bd': {
    'Item_Icon_Material_ExSkill_Millennium_3': {31: 10, 10: 16, 3: 40},
    'Item_Icon_Material_ExSkill_Millennium_2': {31: 70, 24: 77, 17: 84, 10: 91},
  },
  'equipment': {
    'Equipment_Icon_Watch_Tier8': {31: 60, 10: 53, 3: 44},
  },
  'tech_notes': {
    'Item_Icon_SkillBook_Gehenna_3': {31: 80, 10: 71, 3: 57},
    'Item_Icon_SkillBook_Trinity_3': {31: 72, 24: 65, 17: 57, 10: 50, 3: 43},
  },
};

/// 계정 상태 wire(학생 · 목표는 fixture 그대로, 수량만 [owned]).
Map<String, dynamic> _stateWire(int revision, Map<String, String> owned) => {
  'profile_id': inventoryAnalysisFixtureProfileId,
  'revision': revision,
  'students': [
    for (final id in inventoryAnalysisFixtureStudents.keys)
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
        {'key': entry.key, 'item_id': entry.key, 'quantity': entry.value},
    ],
  },
  'goals': {
    'version': 1,
    'goals': [
      for (final id in inventoryAnalysisFixtureStudents.keys)
        {'student_id': id, 'target_level': 80, 'notes': '목표'},
    ],
  },
};

/// 카탈로그.
List<InventoryCatalogEntry> get inventoryAnalysisFixtureCatalog => _fixture.catalog;

/// 저장된 인벤토리(수량 문자열).
Map<String, String> get inventoryAnalysisFixtureOwned => _fixture.owned;

/// 계획 표: 재화 → 학생별 필요량.
Map<String, Map<String, int>> get inventoryAnalysisFixturePlan => _fixture.plan;

/// 분석 검수 fixture 서비스.
class InventoryAnalysisFixtureService extends MockAppService
    implements AppClockSource {
  InventoryAnalysisFixtureService({bool history = true})
    : super(
        repositoryStates: {
          inventoryAnalysisFixtureProfileId: _stateWire(
            inventoryHistoryFixtureRevision,
            _fixture.owned,
          ),
        },
        historyClock: () => inventoryHistoryFixtureNow,
        repositoryHistories: {
          if (history)
            inventoryAnalysisFixtureProfileId: inventoryFixtureScanHistory(
              stateWire: _stateWire,
              current: _fixture.owned,
              scans: inventoryAnalysisFixtureScans,
            ),
        },
      );

  @override
  DateTime get clockNow => inventoryHistoryFixtureNow;

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      InventoryCatalogResult(
        catalogRevision: inventoryAnalysisFixtureRevision,
        items: _fixture.catalog,
      );

  @override
  Future<List<StudentCatalogEntry>> listStudents() async => [
    for (final entry in inventoryAnalysisFixtureStudents.entries)
      StudentCatalogEntry(
        studentId: entry.key,
        displayName: entry.value,
        templateName: '${entry.key}.png',
        group: entry.key,
        variant: null,
        school: 'Millennium',
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

  static InventoryCatalogEntry _item(String key) =>
      _fixture.catalog.firstWhere((item) => item.resourceKey == key);

  @override
  Future<ResourceAcquisitionResult> getResourceAcquisition(
    String resourceKey,
  ) async => ResourceAcquisitionResult.fromWire({
    'resource_key': resourceKey,
    'methods': <dynamic>[],
    'acquisition_revision': mockEmptyResourceAcquisitionRevision,
  });

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async => InventoryShortageResult([
    for (final entry in _fixture.plan.entries)
      () {
        final required = entry.value.values.fold<int>(0, (a, b) => a + b);
        final owned = _owned(inventory, entry.key);
        final item = _item(entry.key);
        return InventoryShortageRow(
          resourceKey: entry.key,
          itemId: entry.key,
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

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    final remaining = <String, int?>{
      for (final key in _fixture.plan.keys) key: _owned(inventory, key),
    };
    final stageResults = <Map<String, dynamic>>[];
    for (final rawPhase in document['phases'] as List? ?? const []) {
      final phase = Map<String, dynamic>.from(rawPhase as Map);
      for (final rawStage in phase['stages'] as List? ?? const []) {
        final stage = Map<String, dynamic>.from(rawStage as Map);
        final student = stage['student_id'] as String;
        final resources = <Map<String, dynamic>>[];
        for (final entry in _fixture.plan.entries) {
          final required = entry.value[student];
          if (required == null) continue;
          final before = remaining[entry.key];
          final item = _item(entry.key);
          resources.add({
            'resource_key': entry.key,
            'item_id': entry.key,
            'display_name': item.displayName,
            'category': item.category,
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
