// FE6-e 인벤토리 티어별 충족률 검수 fixture(시안 Inventory-Tiers의 예시 값을 따른 대역).
//
// FE6-a · FE6-c fixture는 기존 golden 장면이 쓰므로 건드리지 않고 따로 둔다. `MockAppService` 기본값도 바꾸지 않는다.
// - 계정 `000000000000000000000001`(Mock 기본 Main, 선택됨), 학생 35명(모두 초상 그림이 있는 실제 id), 학생마다 목표
//   1개(Mock 활성 문서 한 페이즈, 단계 `v6-<학생>-1`, 문서 순서 = [inventoryTiersFixtureStudents] 순서).
// - 카탈로그: 기술 노트 · BD 9학교(시안 순서 = 백엔드 카탈로그 순서) × 4티어, 오파츠 13종 × 4티어. 모든 칸이 계획에 쓰인다.
// - 칸마다 (필요, 보유)는 시안 칸 %가 나오도록 골랐다(반올림 %가 시안과 같다). "가장 부족" 칸은 시안 글자(`최상급 −27`)를
//   따르되, 시안의 부족 상위(T5) 6행이 그대로 나오도록 그 6개 밖의 부족량은 23 이하로 줄였다(시안 견본 값끼리 서로
//   맞지 않는다 — 예: T1 백귀야행 −27이 T5 6위 −24보다 큰데 T5에 없다). 시안과 다른 칸:
//   · 노트 백귀야행 최상급 −27 → −19, 노트 산해경 최상급 −24 → −20.
//   · BD 백귀야행 · 붉은겨울 · 밀레니엄 최상급 −23 → −21(22%와 −23은 정수로 함께 안 된다), BD 산해경 상급 −31 → −23,
//     BD 발키리 최상급 −17 → −18(42%와 −17은 정수로 함께 안 된다).
//   · 오파츠 파에스토스 · 볼프세크 T4 −24 → −23, 에테르 T4 −27 → −23, 보이니치 T4 −30 → −23, 토템 폴 · 고대 전지 T3 −37 →
//     −23. 로혼치 사본 T4는 −27(T5 5위)을 지키려고 8% → 7%(29개 중 2개).
//   · 부족 상위 6행: 오파츠 네브라 디스크 T3 −37 · 3명 / BD 트리니티 상급 −31 · 2명 / 기술 노트 게헨나 최상급 −30 · 6명 /
//     기술 노트 아비도스 최상급 −30 · 3명 / 오파츠 로혼치 사본 T4 −27 · 2명 / 기술 노트 붉은겨울 최상급 −24 · 1명(시안과 같다).
// - T6 요약 · 티어 분포는 이 칸 값에서 계산된다(시안 68% · 77% · 61% · 25종 0/2/9/14는 위 히트맵 %와 맞지 않는 견본이다).
// - 부족 계산과 문서 계산은 FE6-c fixture와 같은 방식(문서 순서대로 보유를 깎는다)이다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';

const inventoryTiersFixtureProfileId = '000000000000000000000001';
const inventoryTiersFixtureRevision =
    '9e2b7f0c4a1d3e5f6a7b8c9d0e1f2a3b4c5d6e7f8091a2b3c4d5e6f708192a3b';

/// 학생 id → 표시 이름(문서 순서). 모두 `assets/student_portraits/<id>.png`가 있다.
const inventoryTiersFixtureStudents = <String, String>{
  'izuna': '이즈나',
  'michiru': '미치루',
  'tsukuyo': '츠쿠요',
  'cherino': '체리노',
  'nodoka': '노도카',
  'shigure': '시구레',
  'mika': '미카',
  'kazusa': '카즈사',
  'mari': '마리',
  'hifumi': '히후미',
  'hina': '히나',
  'aru': '아루',
  'iori': '이오리',
  'ako': '아코',
  'chinatsu': '치나츠',
  'haruna': '하루나',
  'hoshino': '호시노',
  'shiroko': '시로코',
  'serika': '세리카',
  'nonomi': '노노미',
  'ayane': '아야네',
  'yuuka': '유우카',
  'noa': '노아',
  'rio_battle': '리오(무장)',
  'saori': '사오리',
  'atsuko': '아츠코',
  'misaki': '미사키',
  'hiyori': '히요리',
  'kisaki': '키사키',
  'saya': '사야',
  'shun': '슌',
  'kokona': '코코나',
  'kanna': '칸나',
  'fubuki': '후부키',
  'kirino': '키리노',
};

/// 학교(카탈로그 값, 시안 순서) → (화면 이름, 학생).
const inventoryTiersFixtureSchools = <String, (String, List<String>)>{
  'Hyakkiyako': ('백귀야행', ['izuna', 'michiru', 'tsukuyo']),
  'RedWinter': ('붉은겨울', ['cherino', 'nodoka', 'shigure']),
  'Trinity': ('트리니티', ['mika', 'kazusa', 'mari', 'hifumi']),
  'Gehenna': ('게헨나', ['hina', 'aru', 'iori', 'ako', 'chinatsu', 'haruna']),
  'Abydos': ('아비도스', ['hoshino', 'shiroko', 'serika', 'nonomi', 'ayane']),
  'Millennium': ('밀레니엄', ['yuuka', 'noa', 'rio_battle']),
  'Arius': ('아리우스', ['saori', 'atsuko', 'misaki', 'hiyori']),
  'Shanhaijing': ('산해경', ['kisaki', 'saya', 'shun', 'kokona']),
  'Valkyrie': ('발키리', ['kanna', 'fubuki', 'kirino']),
};

/// 기술 노트 학교 → 티어 1~4 (필요, 보유). 시안 T1 %: 백귀야행 95/89/52/10 · 붉은겨울 100/94/42/20 · …
const inventoryTiersFixtureNotes = <String, List<(int, int)>>{
  'Hyakkiyako': [(19, 18), (9, 8), (21, 11), (21, 2)],
  'RedWinter': [(10, 10), (16, 15), (12, 5), (30, 6)],
  'Trinity': [(10, 10), (16, 15), (21, 11), (30, 9)],
  'Gehenna': [(10, 10), (16, 15), (12, 5), (30, 0)],
  'Abydos': [(10, 10), (9, 8), (21, 11), (30, 0)],
  'Millennium': [(10, 10), (16, 15), (12, 5), (30, 12)],
  'Arius': [(10, 10), (16, 15), (13, 10), (29, 13)],
  'Shanhaijing': [(10, 10), (9, 8), (13, 8), (25, 5)],
  'Valkyrie': [(10, 10), (16, 15), (19, 6), (30, 9)],
};

/// BD 학교 → 티어 1~4 (필요, 보유). 시안 T2 %.
const inventoryTiersFixtureBd = <String, List<(int, int)>>{
  'Hyakkiyako': [(10, 10), (23, 22), (9, 7), (27, 6)],
  'RedWinter': [(10, 10), (11, 10), (12, 7), (27, 6)],
  'Trinity': [(10, 10), (23, 22), (50, 19), (14, 8)],
  'Gehenna': [(10, 10), (11, 10), (9, 7), (28, 16)],
  'Abydos': [(19, 18), (23, 22), (9, 7), (29, 15)],
  'Millennium': [(19, 18), (11, 10), (9, 7), (27, 6)],
  'Arius': [(19, 18), (23, 22), (9, 7), (28, 16)],
  'Shanhaijing': [(10, 10), (23, 22), (37, 14), (14, 8)],
  'Valkyrie': [(10, 10), (23, 22), (21, 10), (31, 13)],
};

/// 오파츠 (icon key, 이름, 티어 1~4 (필요, 보유)). 시안 T4 순서 · %.
const inventoryTiersFixtureOoparts = <(String, String, List<(int, int)>)>[
  ('Nebra', '네브라 디스크', [(10, 10), (10, 9), (50, 13), (18, 5)]),
  ('Phaistos', '파에스토스 원반', [(19, 18), (10, 9), (19, 5), (28, 5)]),
  ('Wolfsegg', '볼프세크 강철', [(10, 10), (13, 11), (19, 5), (28, 5)]),
  ('Nimrud', '님루드 렌즈', [(19, 18), (10, 9), (29, 19), (29, 11)]),
  ('Mandragora', '만드라고라', [(19, 18), (10, 9), (11, 4), (29, 8)]),
  ('Rohonc', '로혼치 사본', [(10, 10), (13, 11), (11, 4), (29, 2)]),
  ('Ether', '에테르', [(10, 10), (10, 9), (11, 4), (25, 2)]),
  ('Antikythera', '안티키테라 장치', [(10, 10), (13, 11), (29, 19), (29, 11)]),
  ('Voynich', '보이니치 필사본', [(10, 10), (10, 9), (29, 19), (23, 0)]),
  ('CrystalHaniwa', '하니와', [(10, 10), (10, 9), (9, 5), (29, 8)]),
  ('TotemPole', '토템 폴', [(10, 10), (10, 9), (31, 8), (8, 3)]),
  ('Baghdad', '고대 전지', [(10, 10), (10, 9), (31, 8), (14, 6)]),
  ('GoldenFleece', '황금 나사', [(10, 10), (10, 9), (9, 5), (29, 8)]),
];

/// 학생 덮어쓰기(재화 key → 학생). 없는 재화는 학교의 앞 두 명(오파츠는 순서대로 돌린 두 명)이다.
const inventoryTiersFixtureStudentOverrides = <String, List<String>>{
  'Item_Icon_SkillBook_Gehenna_3': ['hina', 'aru', 'iori', 'ako', 'chinatsu', 'haruna'],
  'Item_Icon_SkillBook_Abydos_3': ['hoshino', 'shiroko', 'serika'],
  'Item_Icon_SkillBook_RedWinter_3': ['cherino'],
  'Item_Icon_Material_ExSkill_Trinity_2': ['mika', 'kazusa'],
  'Item_Icon_Material_Nebra_2': ['hina', 'mika', 'yuuka'],
  'Item_Icon_Material_Rohonc_3': ['aru', 'saori'],
};

const _tierNames = ['초급', '일반', '상급', '최상급'];

InventoryCatalogEntry _entry(
  String key,
  String name,
  String category,
  int order, {
  String? school,
  String? family,
  required int tier,
}) => InventoryCatalogEntry(
  resourceKey: key,
  itemId: key,
  displayName: name,
  category: category,
  profileId: category,
  orderIndex: order,
  zeroFillAllowed: true,
  school: school,
  family: family,
  tier: tier,
);

/// 학생에게 고르게 나눈 필요량(앞 학생이 1씩 더 받는다).
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
  void add(InventoryCatalogEntry entry, (int, int) cell, List<String> students) {
    catalog.add(entry);
    final (required, have) = cell;
    plan[entry.resourceKey] = _split(
      inventoryTiersFixtureStudentOverrides[entry.resourceKey] ?? students,
      required,
    );
    owned[entry.resourceKey] = '$have';
  }

  for (final (category, prefix, kind, table) in [
    ('tech_notes', 'Item_Icon_SkillBook', '기술 노트', inventoryTiersFixtureNotes),
    ('tactical_bd', 'Item_Icon_Material_ExSkill', 'BD', inventoryTiersFixtureBd),
  ]) {
    var index = 0;
    for (final MapEntry(key: school, value: (label, students))
        in inventoryTiersFixtureSchools.entries) {
      for (var tier = 1; tier <= 4; tier++) {
        add(
          _entry(
            '${prefix}_${school}_${tier - 1}',
            '$label $kind (${_tierNames[tier - 1]})',
            category,
            index++,
            school: school,
            family: category,
            tier: tier,
          ),
          table[school]![tier - 1],
          students.take(2).toList(),
        );
      }
    }
  }
  final pool = inventoryTiersFixtureStudents.keys.toList();
  var index = 0;
  for (final (series, (icon, label, cells)) in inventoryTiersFixtureOoparts.indexed) {
    for (var tier = 1; tier <= 4; tier++) {
      add(
        _entry(
          'Item_Icon_Material_${icon}_${tier - 1}',
          '$label T$tier',
          'oopart',
          index++,
          family: 'oopart:$icon',
          tier: tier,
        ),
        cells[tier - 1],
        [pool[(series * 2) % pool.length], pool[(series * 2 + 1) % pool.length]],
      );
    }
  }
  return (catalog: catalog, owned: owned, plan: plan);
}();

/// 카탈로그.
List<InventoryCatalogEntry> get inventoryTiersFixtureCatalog => _fixture.catalog;

/// 저장된 인벤토리(수량 문자열).
Map<String, String> get inventoryTiersFixtureOwned => _fixture.owned;

/// 계획 표: 재화 → 학생별 필요량.
Map<String, Map<String, int>> get inventoryTiersFixturePlan => _fixture.plan;

/// 티어 화면 검수 fixture 서비스.
class InventoryTiersFixtureService extends MockAppService {
  InventoryTiersFixtureService()
    : super(
        repositoryStates: {
          inventoryTiersFixtureProfileId: {
            'profile_id': inventoryTiersFixtureProfileId,
            'revision': 3,
            'students': [
              for (final id in inventoryTiersFixtureStudents.keys)
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
                for (final id in inventoryTiersFixtureStudents.keys)
                  {'student_id': id, 'target_level': 80, 'notes': '목표'},
              ],
            },
          },
        },
      );

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      InventoryCatalogResult(
        catalogRevision: inventoryTiersFixtureRevision,
        items: _fixture.catalog,
      );

  @override
  Future<List<StudentCatalogEntry>> listStudents() async => [
    for (final entry in inventoryTiersFixtureStudents.entries)
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
