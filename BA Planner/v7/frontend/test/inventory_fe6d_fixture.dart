// FE6-d 오파츠 확장 검수 fixture(시안 Inventory-Analysis-Opa의 예시 값을 따른 대역). 테스트 파일이 아니다.
//
// FE6-c fixture(`inventory_fe6c_fixture.dart`)는 `inventory-analysis` 장면이 쓰므로 건드리지 않고 따로 둔다. 오파츠만 있는
// 계정이다(S1 · S4는 확장 장면에서 퇴장해 보이지 않는다).
// - 오파츠 8종 × T1~T4: 네브라 디스크 · 로혼치 사본 · 파에스토스 원반 · 안티키테라 장치(게임 아이콘 있음) · 아우름 코인 ·
//   오브 오브 위트 · 구스타프 총알 · 토리노 수의(아이콘 id가 없는 대역 → 이름 앞 두 글자, 시안 "아우/오브/구스/토리").
// - 네브라 디스크는 시안 상세 그대로다: T1 보유 210 / 필요 180, T2 160 / 120, T3 96 / 133(−37), T4 12 / 58(−46). 사용 학생
//   6명(문서 순서 리오(무장) · 토키(무장) · 쿠루미 · 호시노 · 아루 · 미카), 학생별 부족 T4 12 · 10 · 8 · 6 · 4 · 6, T3 8 · 6 ·
//   (없음) · 4 · 12 · 7(문서 순서대로 보유를 깎으면 첫 학생이 남은 보유를 다 쓰고 나머지는 자기 필요량만큼 모자란다).
// - 병목 순위(가장 부족한 티어 기준): 네브라 T4 −46 · 로혼치 T4 −31 · 파에스토스 T3 −22 · 안티키테라 T4 −18 · 토리노 T3 −9.
//   핵심 병목(보유율 50% 미만 + 학생 수 > 최대 8명의 절반)은 네브라 T4 · 로혼치 T4다(시안 분홍 이름 둘).
// - 부족 계산과 문서 계산은 FE6-c fixture와 같은 방식(문서 순서대로 보유를 깎는다)이다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';

const inventoryOpaFixtureProfileId = '000000000000000000000001';
const inventoryOpaFixtureRevision =
    '7d1e7d7b2f4d2e4b4c8d3d6f1b5a0e9f8c7b6d5e4f3a2b1c0d9e8f7a6b5c4d3e';

/// 학생 id → 표시 이름(문서 순서).
const inventoryOpaFixtureStudents = <String, String>{
  'rio_battle': '리오(무장)',
  'toki_battle': '토키(무장)',
  'kurumi': '쿠루미',
  'hoshino': '호시노',
  'aru': '아루',
  'mika': '미카',
  'hina': '히나',
  'iori': '이오리',
  'noa': '노아',
  'yuuka': '유우카',
  'kazusa': '카즈사',
  'mari': '마리',
  'izuna': '이즈나',
  'saya': '사야',
};

Map<String, int> _each(List<String> students, int amount) => {
  for (final student in students) student: amount,
};

const _nebra = ['rio_battle', 'toki_battle', 'kurumi', 'hoshino', 'aru', 'mika'];
const _rohonc = ['hina', 'iori', 'noa', 'yuuka', 'kazusa', 'mari'];
const _phaistos = ['izuna', 'saya', 'hina', 'noa'];
const _antikythera = ['yuuka', 'mari', 'saya'];
const _aurum = ['rio_battle', 'toki_battle', 'hina', 'iori', 'noa', 'yuuka', 'kazusa', 'mari'];
const _orb = ['izuna', 'saya'];
const _gustav = ['aru', 'mika', 'kurumi'];
const _torino = ['hoshino', 'aru', 'iori', 'noa', 'izuna'];

/// 오파츠 (아이콘 key, 이름, T1~T4 (보유, 학생별 필요)).
final inventoryOpaFixtureOoparts = <(String, String, List<(int, Map<String, int>)>)>[
  ('Nebra', '네브라 디스크', [
    (210, _each(_nebra, 30)),
    (160, _each(_nebra, 20)),
    (96, {'rio_battle': 104, 'toki_battle': 6, 'hoshino': 4, 'aru': 12, 'mika': 7}),
    (12, {'rio_battle': 24, 'toki_battle': 10, 'kurumi': 8, 'hoshino': 6, 'aru': 4, 'mika': 6}),
  ]),
  ('Rohonc', '로혼치 사본', [
    (200, _each(_rohonc, 25)),
    (150, _each(_rohonc, 20)),
    (50, _each(_rohonc, 10)),
    (19, {'hina': 10, 'iori': 8, 'noa': 8, 'yuuka': 8, 'kazusa': 8, 'mari': 8}),
  ]),
  ('Phaistos', '파에스토스 원반', [
    (150, _each(_phaistos, 25)),
    (120, _each(_phaistos, 20)),
    (58, _each(_phaistos, 20)),
    (40, _each(_phaistos, 10)),
  ]),
  ('Antikythera', '안티키테라 장치', [
    (120, _each(_antikythera, 30)),
    (90, _each(_antikythera, 20)),
    (60, _each(_antikythera, 15)),
    (30, _each(_antikythera, 16)),
  ]),
  ('AurumCoin', '아우름 코인', [
    (300, _each(_aurum, 30)),
    (220, _each(_aurum, 20)),
    (140, _each(_aurum, 15)),
    (90, _each(_aurum, 10)),
  ]),
  ('OrbOfWit', '오브 오브 위트', [
    (80, _each(_orb, 30)),
    (60, _each(_orb, 20)),
    (40, _each(_orb, 15)),
    (30, _each(_orb, 10)),
  ]),
  ('GustavBullet', '구스타프 총알', [
    (100, _each(_gustav, 30)),
    (70, _each(_gustav, 20)),
    (50, _each(_gustav, 15)),
    (40, _each(_gustav, 10)),
  ]),
  ('TorinoShroud', '토리노 수의', [
    (160, _each(_torino, 30)),
    (110, _each(_torino, 20)),
    (36, _each(_torino, 9)),
    (60, _each(_torino, 10)),
  ]),
];

/// 카탈로그 · 보유 · 계획 표를 한 번에 만든다.
final _fixture = () {
  final catalog = <InventoryCatalogEntry>[];
  final owned = <String, String>{};
  final plan = <String, Map<String, int>>{};
  var order = 0;
  for (final (icon, label, tiers) in inventoryOpaFixtureOoparts) {
    for (var tier = 1; tier <= 4; tier++) {
      final key = 'Item_Icon_Material_${icon}_${tier - 1}';
      catalog.add(
        InventoryCatalogEntry(
          resourceKey: key,
          itemId: key,
          displayName: '$label T$tier',
          category: 'oopart',
          profileId: 'ooparts',
          orderIndex: order++,
          zeroFillAllowed: true,
          school: null,
          family: 'oopart:$icon',
          tier: tier,
        ),
      );
      final (have, need) = tiers[tier - 1];
      owned[key] = '$have';
      plan[key] = need;
    }
  }
  return (catalog: catalog, owned: owned, plan: plan);
}();

/// 카탈로그.
List<InventoryCatalogEntry> get inventoryOpaFixtureCatalog => _fixture.catalog;

/// 오파츠 확장 검수 fixture 서비스.
class InventoryOpaFixtureService extends MockAppService {
  InventoryOpaFixtureService()
    : super(
        repositoryStates: {
          inventoryOpaFixtureProfileId: {
            'profile_id': inventoryOpaFixtureProfileId,
            'revision': 3,
            'students': [
              for (final id in inventoryOpaFixtureStudents.keys)
                {
                  'version': 1,
                  'student_id': id,
                  'values': {'level': 70, 'student_star': 3},
                },
            ],
            'inventory': {
              'version': 1,
              'entries': [
                for (final entry in _fixture.owned.entries)
                  {
                    'key': entry.key,
                    'item_id': entry.key,
                    'quantity': entry.value,
                  },
              ],
            },
            'goals': {
              'version': 1,
              'goals': [
                for (final id in inventoryOpaFixtureStudents.keys)
                  {'student_id': id, 'target_level': 80, 'notes': '목표'},
              ],
            },
          },
        },
      );

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      InventoryCatalogResult(
        catalogRevision: inventoryOpaFixtureRevision,
        items: _fixture.catalog,
      );

  @override
  Future<List<StudentCatalogEntry>> listStudents() async => [
    for (final entry in inventoryOpaFixtureStudents.entries)
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
