// FE6-a 인벤토리 화면 모델: FD-030 (b) 위험도, FD-031 (a) 충족률, FD-040 과잉, FD-095 종류, FD-101 사용 단계.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_view_model.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';

InventoryShortageRow _row(
  String key,
  int required,
  int? owned,
  List<String> students, {
  String category = 'material',
}) => InventoryShortageRow(
  resourceKey: key,
  itemId: key,
  displayName: key,
  category: category,
  requiredAmount: required,
  owned: owned,
  shortage: owned == null ? null : (owned >= required ? 0 : required - owned),
  affectedStudentIds: students,
  resolved: true,
);

InventoryBoard _fixtureBoard() {
  final entries = [
    for (final entry in inventoryFixtureOwned.entries)
      {
        'key': entry.key,
        'item_id': entry.key == 'credits' ? null : entry.key,
        'quantity': entry.value,
      },
  ];
  return InventoryBoard.build(
    catalog: inventoryFixtureCatalog,
    inventory: RepositoryInventoryState.fromEntries(entries),
    shortages: InventoryShortageResult([
      for (final entry in inventoryFixturePlan.entries)
        _row(
          entry.key,
          entry.value.values.fold<int>(0, (a, b) => a + b),
          int.tryParse(inventoryFixtureOwned[entry.key] ?? ''),
          entry.value.keys.toList(),
        ),
    ], const []),
  );
}

void main() {
  group('FD-030 (b) risk score', () {
    test('matches the artboard example and the formula', () {
      // 시안 엘레프: 보유 1 / 필요 450 · 사용 학생 1명 → 부족비율 449/450, n = 1이면 지수 1.
      final eleph = inventoryRiskScore(
        requiredAmount: 450,
        owned: 1,
        studentCount: 1,
      )!;
      expect(eleph, closeTo(99.78, 0.01));
      expect(inventoryRiskLabel(eleph), '100');
      // n = 4: 0.8^(1/(1+ln 4)) = 0.9107.
      expect(
        inventoryRiskScore(requiredAmount: 60, owned: 12, studentCount: 4),
        closeTo(91.07, 0.01),
      );
      // 학생이 많을수록 같은 부족비율에서 점수가 오른다.
      final one = inventoryRiskScore(
        requiredAmount: 28,
        owned: 20,
        studentCount: 1,
      )!;
      final three = inventoryRiskScore(
        requiredAmount: 28,
        owned: 20,
        studentCount: 3,
      )!;
      expect(one, closeTo(28.57, 0.01));
      expect(three, closeTo(55.05, 0.01));
      expect(three, greaterThan(one));
    });

    test('unknown, enough, zero required and zero students', () {
      expect(
        inventoryRiskScore(requiredAmount: 10, owned: null, studentCount: 2),
        isNull,
      );
      expect(inventoryRiskLabel(null), '—');
      expect(
        inventoryRiskScore(requiredAmount: 10, owned: 10, studentCount: 2),
        0,
      );
      expect(
        inventoryRiskScore(requiredAmount: 0, owned: null, studentCount: 2),
        0,
      );
      expect(
        inventoryRiskScore(requiredAmount: 10, owned: 0, studentCount: 0),
        100,
      );
    });
  });

  group('inventory board', () {
    test('shortage view keeps currencies out and sorts by risk', () {
      final board = _fixtureBoard();
      final rows = board.visible(
        mode: InventoryListMode.items,
        view: InventoryView.shortage,
        category: null,
        sort: InventorySort.risk,
      );
      expect(rows.map((row) => row.key), [
        'Item_Icon_SecretStone_rio_battle',
        'Item_Icon_Material_Nebra_1',
        'Item_Icon_SkillBook_Gehenna_3',
        'Item_Icon_SecretStone_toki_battle',
        'Item_Icon_Material_ExSkill_Gehenna_3',
        // 보유를 모르는 계획 재화는 점수가 없어 뒤로 간다.
        'Item_Icon_ExpItem_2',
      ]);
      expect(rows.last.risk, isNull);
      expect(rows.any((row) => row.isCurrency), isFalse);
      expect(board.shortageCount(InventoryListMode.items), 5);
      expect(board.unknownPlannedCount(InventoryListMode.items), 1);
      expect(board.allCount(InventoryListMode.items), 9);
      expect(board.shortageCount(InventoryListMode.equipment), 1);
      expect(board.currencies.map((view) => view.key), [
        'credits',
        'Item_Icon_SecretStone',
      ]);
    });

    test('other sorts keep unknown values last', () {
      final board = _fixtureBoard();
      List<String> keys(InventorySort sort) => board
          .visible(
            mode: InventoryListMode.items,
            view: InventoryView.shortage,
            category: null,
            sort: sort,
          )
          .map((row) => row.key)
          .toList();
      expect(keys(InventorySort.fulfillment).first,
          'Item_Icon_SecretStone_rio_battle');
      expect(keys(InventorySort.fulfillment).last, 'Item_Icon_ExpItem_2');
      expect(keys(InventorySort.shortage).first,
          'Item_Icon_SecretStone_rio_battle');
      expect(keys(InventorySort.shortage)[1],
          'Item_Icon_SecretStone_toki_battle');
      expect(keys(InventorySort.shortage).last, 'Item_Icon_ExpItem_2');
    });

    test('categories follow FD-095 order with shortage counts', () {
      final board = _fixtureBoard();
      final items = board.categories(InventoryListMode.items);
      expect(items.map((category) => category.category), [
        'student_eleph',
        'oopart',
        'activity_report',
        'tech_notes',
        'tactical_bd',
      ]);
      expect(items.map((category) => category.label), [
        '엘레프',
        '오파츠',
        '활동 보고서',
        '기술 노트',
        'BD',
      ]);
      expect(items.map((category) => category.count), [2, 1, 3, 2, 1]);
      expect(items.map((category) => category.shortageCount), [2, 1, 0, 1, 1]);
      final equipment = board.categories(InventoryListMode.equipment);
      expect(equipment.single.category, 'equipment');
      expect(equipment.single.label, '장비 설계도');
      expect(
        board
            .visible(
              mode: InventoryListMode.items,
              view: InventoryView.all,
              category: 'tech_notes',
              sort: InventorySort.risk,
            )
            .map((row) => row.key),
        ['Item_Icon_SkillBook_Gehenna_3', 'Item_Icon_SkillBook_Abydos_0'],
      );
    });

    test('KPIs: owned kinds, shortage, excess (FD-040), fulfillment (FD-031)', () {
      final kpis = _fixtureBoard().kpis;
      expect(kpis.ownedKinds, 7);
      expect(kpis.shortageKinds, 6);
      expect(kpis.excessKinds, 1);
      // 크레딧·엘리그마 포함, 보유를 모르는 활동 보고서(상급)는 빼고 평균한다.
      expect(kpis.unknownKinds, 1);
      const expected =
          (1 / 450 +
              53 / 330 +
              12 / 60 +
              20 / 28 +
              3 / 40 +
              1 +
              0 +
              98400000 / 261500000 +
              1020 / 2245) /
          9;
      expect(kpis.fulfillment, closeTo(expected, 1e-9));
    });

    test('without a shortage result the plan KPIs are unknown', () {
      final board = InventoryBoard.build(
        catalog: inventoryFixtureCatalog,
        inventory: RepositoryInventoryState.fromEntries(const [
          {'key': 'Item_Icon_ExpItem_0', 'quantity': '3'},
        ]),
        shortages: null,
      );
      final kpis = board.kpis;
      expect(board.hasShortages, isFalse);
      expect(kpis.ownedKinds, 1);
      expect(kpis.shortageKinds, isNull);
      expect(kpis.excessKinds, isNull);
      expect(kpis.fulfillment, isNull);
      expect(
        board.visible(
          mode: InventoryListMode.items,
          view: InventoryView.shortage,
          category: null,
          sort: InventorySort.risk,
        ),
        isEmpty,
      );
    });

    test('shortage rows missing from the catalog are kept at the end', () {
      final board = InventoryBoard.build(
        catalog: inventoryFixtureCatalog,
        inventory: null,
        shortages: InventoryShortageResult([
          _row('unresolved:mystery', 5, null, const ['aru']),
        ], const []),
      );
      final view = board['unresolved:mystery']!;
      expect(view.item.profileId, 'missing_catalog');
      expect(view.order, inventoryFixtureCatalog.length);
      expect(view.unknownPlanned, isTrue);
    });
  });

  group('FE6-b tile groups', () {
    test('kind groups follow FD-095 order and equipment splits by family', () {
      final board = _fixtureBoard();
      final items = board.tileGroups(
        mode: InventoryListMode.items,
        category: null,
      );
      expect(items.map((group) => group.id), [
        'student_eleph',
        'oopart',
        'activity_report',
        'tech_notes',
        'tactical_bd',
      ]);
      expect(items.map((group) => group.label), [
        '엘레프',
        '오파츠',
        '활동 보고서',
        '기술 노트',
        'BD',
      ]);
      expect(items.map((group) => group.shortageCount), [2, 1, 0, 1, 1]);
      expect(items.first.shortages.map((view) => view.key), [
        'Item_Icon_SecretStone_rio_battle',
        'Item_Icon_SecretStone_toki_battle',
      ]);
      final equipment = board.tileGroups(
        mode: InventoryListMode.equipment,
        category: null,
      );
      expect(equipment.map((group) => (group.id, group.label)), [
        ('equipment:stone', '강화석'),
        ('equipment:gear', '장비'),
      ]);
    });

    test('planned-only and hide-zero filters keep unknown quantities', () {
      final board = _fixtureBoard();
      List<String> keys({bool plannedOnly = false, bool hideZero = false}) => [
        for (final group in board.tileGroups(
          mode: InventoryListMode.items,
          category: 'activity_report',
          plannedOnly: plannedOnly,
          hideZero: hideZero,
        ))
          for (final view in group.items) view.key,
      ];
      expect(keys(), [
        'Item_Icon_ExpItem_0',
        'Item_Icon_ExpItem_1',
        'Item_Icon_ExpItem_2',
      ]);
      expect(keys(plannedOnly: true), [
        'Item_Icon_ExpItem_1',
        'Item_Icon_ExpItem_2',
      ]);
      final equipment = board.tileGroups(
        mode: InventoryListMode.equipment,
        category: null,
        hideZero: true,
      );
      // 헤어핀 보유 0은 빠지고, 저장 항목이 없는(모름) 강화석은 남는다.
      expect(
        [for (final group in equipment) ...group.items.map((view) => view.key)],
        ['Equipment_Icon_Exp_3'],
      );
    });

    test('tile tones: none, unknown, shortage, enough, excess (FD-040)', () {
      final board = _fixtureBoard();
      InventoryTileTone tone(String key) => inventoryTileTone(board[key]!);
      expect(tone('Item_Icon_ExpItem_0'), InventoryTileTone.none);
      expect(tone('Item_Icon_ExpItem_2'), InventoryTileTone.unknown);
      expect(tone('Item_Icon_SecretStone_rio_battle'), InventoryTileTone.shortage);
      expect(tone('Item_Icon_ExpItem_1'), InventoryTileTone.excess);
      final enough = InventoryBoard.build(
        catalog: inventoryFixtureCatalog,
        inventory: RepositoryInventoryState.fromEntries(const [
          {'key': 'Item_Icon_ExpItem_1', 'quantity': '150'},
        ]),
        shortages: InventoryShortageResult([
          _row('Item_Icon_ExpItem_1', 120, 150, const ['aru']),
        ], const []),
      );
      // 150 < 120 × 1.5 = 180: 충분(과잉 아님).
      expect(
        inventoryTileTone(enough['Item_Icon_ExpItem_1']!),
        InventoryTileTone.enough,
      );
    });

    test('group ids by FB-3 family', () {
      InventoryCatalogEntry equipment(String? family, int? tier) =>
          InventoryCatalogEntry(
            resourceKey: 'x',
            itemId: 'x',
            displayName: 'x',
            category: 'equipment',
            profileId: 'equipment',
            orderIndex: 0,
            zeroFillAllowed: true,
            school: null,
            family: family,
            tier: tier,
          );
      expect(inventoryTileGroupId(equipment('equipment_exp', 1)), 'equipment:stone');
      expect(inventoryTileGroupId(equipment('equipment:Hat', null)), 'equipment:blueprint');
      expect(inventoryTileGroupId(equipment('equipment:Hat', 3)), 'equipment:gear');
      expect(inventoryTileGroupId(equipment('weapon_exp:A', 2)), 'equipment:weapon');
      expect(inventoryTileGroupId(equipment(null, null)), 'equipment:other');
      expect(inventoryTileGroupLabel('equipment:blueprint'), '만능 설계도');
      expect(inventoryTileGroupLabel('equipment:weapon'), '무기 부품');
      expect(inventoryTileGroupId(inventoryFixtureCatalog.firstWhere(
        (item) => item.category == 'tech_notes',
      )), 'tech_notes');
    });
  });

  test('FD-101 stage uses follow document order and student steps', () {
    PlanningDocumentStage stage(String phase, String student) =>
        PlanningDocumentStage(
          id: '$phase-$student',
          studentId: student,
          name: '단계 $student',
          targets: const {},
        );
    final document = PlanningDocument(
      id: 'active-plan',
      name: '활성 계획',
      kind: PlanningDocumentKind.plan,
      version: 2,
      phases: [
        PlanningDocumentPhase(
          id: 'p1',
          name: 'p1',
          stages: [stage('p1', 'aru'), stage('p1', 'hina')],
        ),
        PlanningDocumentPhase(
          id: 'p2',
          name: 'p2',
          stages: [stage('p2', 'aru')],
        ),
      ],
    );
    final uses = inventoryStageUses({
      'stage_results': [
        {
          'stage_id': 'p1-aru',
          'student_id': 'aru',
          'resources': [
            {
              'resource_key': 'note',
              'required': 10,
              'owned_at_entry': 4,
              'shortage_at_entry': 6,
            },
          ],
        },
        {
          'stage_id': 'p1-hina',
          'student_id': 'hina',
          'resources': [
            {'resource_key': 'note', 'required': 3},
            {'resource_key': 'credits', 'required': 0},
          ],
        },
        {
          'stage_id': 'p2-aru',
          'student_id': 'aru',
          'resources': [
            {
              'resource_key': 'note',
              'required': 2,
              'owned_at_entry': 0,
              'shortage_at_entry': 2,
            },
          ],
        },
        {'stage_id': 'unknown-stage', 'resources': []},
        'not a map',
      ],
    }, document);
    final note = uses['note']!;
    expect(note.map((use) => (use.studentId, use.phaseNumber, use.studentStep)), [
      ('aru', 1, 1),
      ('hina', 1, 1),
      ('aru', 2, 2),
    ]);
    expect(note.map((use) => use.blocked), [true, false, true]);
    expect(note[1].shortageAtEntry, isNull);
    expect(note.first.stageName, '단계 aru');
    // 필요량 0인 줄은 사용으로 세지 않는다.
    expect(uses.containsKey('credits'), isFalse);
  });
}
