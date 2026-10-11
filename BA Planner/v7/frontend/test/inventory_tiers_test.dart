// FE6-e 인벤토리 티어별 충족률 집계(`inventory_tiers.dart`) 단위 테스트: 학교 × 티어 칸 평균(FD-031 · FD-032), 모름 제외,
// 카탈로그 전부 범위(FD-099 Tiers), "가장 부족" 칸, 부족 상위(FE6-c 규칙), 티어 분포 개수(품목 수), KPI.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_tiers.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// 재화 한 줄: 카탈로그 · 보유(null = 항목 없음) · 필요(null = 계획 밖) · 사용 학생.
typedef _Spec = ({
  String key,
  String category,
  String? school,
  String? family,
  int? tier,
  int? owned,
  int? required,
  List<String> students,
});

_Spec _spec(
  String key,
  String category, {
  String? school,
  String? family,
  int? tier,
  int? owned,
  int? required,
  List<String> students = const [],
}) => (
  key: key,
  category: category,
  school: school,
  family: family,
  tier: tier,
  owned: owned,
  required: required,
  students: students,
);

/// 노트(`tech_notes`) 한 칸.
_Spec _note(String school, int tier, {int? owned, int? required, List<String> students = const []}) =>
    _spec(
      'note-$school-$tier',
      'tech_notes',
      school: school,
      family: 'tech_notes',
      tier: tier,
      owned: owned,
      required: required,
      students: students,
    );

/// BD(`tactical_bd`) 한 칸.
_Spec _bd(String school, int tier, {int? owned, int? required, List<String> students = const []}) =>
    _spec(
      'bd-$school-$tier',
      'tactical_bd',
      school: school,
      family: 'tactical_bd',
      tier: tier,
      owned: owned,
      required: required,
      students: students,
    );

/// 오파츠 한 칸.
_Spec _oopart(String key, int tier, {int? owned, int? required, List<String> students = const []}) =>
    _spec(
      'oopart-$key-$tier',
      'oopart',
      family: 'oopart:$key',
      tier: tier,
      owned: owned,
      required: required,
      students: students,
    );

InventoryBoard _board(List<_Spec> specs, {Map<String, String> names = const {}}) {
  final catalog = [
    for (final (index, spec) in specs.indexed)
      InventoryCatalogEntry(
        resourceKey: spec.key,
        itemId: spec.key,
        displayName: names[spec.key] ?? spec.key,
        category: spec.category,
        profileId: spec.category,
        orderIndex: index,
        zeroFillAllowed: true,
        school: spec.school,
        family: spec.family,
        tier: spec.tier,
      ),
  ];
  final inventory = RepositoryInventoryState.fromWire({
    'version': 1,
    'entries': [
      for (final spec in specs)
        if (spec.owned != null)
          {'key': spec.key, 'item_id': spec.key, 'quantity': '${spec.owned}'},
    ],
  });
  final shortages = InventoryShortageResult([
    for (final spec in specs)
      if (spec.required case final required?)
        InventoryShortageRow(
          resourceKey: spec.key,
          itemId: spec.key,
          displayName: names[spec.key] ?? spec.key,
          category: spec.category,
          requiredAmount: required,
          owned: spec.owned,
          shortage: spec.owned == null
              ? null
              : (spec.owned! >= required ? 0 : required - spec.owned!),
          affectedStudentIds: spec.students,
          resolved: true,
        ),
  ], const []);
  return InventoryBoard.build(
    catalog: catalog,
    inventory: inventory,
    shortages: shortages,
  );
}

String _amount(int value) => '$value';

void main() {
  group('표 범위와 칸(FD-099 Tiers · FD-031 · FD-032)', () {
    test('행은 카탈로그 전부(계획 밖 학교도), 카탈로그 순서, 열은 가장 높은 티어까지', () {
      final board = _board([
        _note('Hyakkiyako', 1, owned: 5, required: 10),
        _note('Hyakkiyako', 4, owned: 3, required: 30),
        _note('RedWinter', 1, owned: 2), // 계획 밖 학교
        _note('Wildhunt', 2), // 보유 · 계획 모두 없음
        _spec('note-ultimate', 'tech_notes', family: 'tech_notes'), // 학교 · 티어 없음(비의서) → 행 없음
        _bd('Hyakkiyako', 1, owned: 1, required: 1),
      ]);
      final table = inventoryTierTable(board, InventoryHeatmapKind.notes);
      expect(table.tiers, 4);
      expect(table.rows.map((row) => row.id), ['Hyakkiyako', 'RedWinter', 'Wildhunt']);
      expect(table.rows.map((row) => row.label), ['백귀야행', '붉은겨울', '와일드헌트']);
      expect(table.heatmap.rows, hasLength(3));
      expect(table.heatmap.tierLabel(2), '일반');
      final hyakkiyako = table.rows.first;
      expect(hyakkiyako.planned, isTrue);
      expect(hyakkiyako.row.cells.map((cell) => cell.planned), [true, false, false, true]);
      expect(hyakkiyako.row.cells[0].coverage.fulfillment, closeTo(0.5, 1e-9));
      expect(hyakkiyako.row.cells[3].coverage.fulfillment, closeTo(0.1, 1e-9));
      // 계획 밖 행은 칸이 모두 비고 "가장 부족"은 빈 글자다.
      final redWinter = table.rows[1];
      expect(redWinter.planned, isFalse);
      expect(redWinter.row.cells.every((cell) => !cell.planned), isTrue);
      expect(table.weakestText(redWinter, _amount), '');
      // 행 머리 그림은 그 행의 카탈로그 첫 재화다.
      expect(hyakkiyako.icon.key, 'note-Hyakkiyako-1');
    });

    test('보유 모름은 칸 평균에서 빼고(빗금), KPI 충족률도 계획 재화 평균에서 뺀다', () {
      final board = _board([
        _note('Gehenna', 1, owned: 10, required: 10),
        _note('Gehenna', 2, required: 20), // 보유 모름
        _note('Gehenna', 3, owned: 5, required: 20),
        _note('Trinity', 1, owned: 30, required: 10), // 넘쳐도 1
      ]);
      final table = inventoryTierTable(board, InventoryHeatmapKind.notes);
      final gehenna = table.rows.first;
      expect(gehenna.row.cells[1].planned, isTrue);
      expect(gehenna.row.cells[1].coverage.fulfillment, isNull);
      expect(gehenna.row.cells[1].text(InventoryHeatmapValue.fulfillment, _amount), '—');
      // (1 + 0.25 + 1) / 3, 모름 1종.
      expect(table.coverage.fulfillment, closeTo(0.75, 1e-9));
      expect(table.coverage.plannedKinds, 4);
      expect(table.coverage.unknownKinds, 1);
    });

    test('표시 칩: 보유량 · 부족량은 칸 재화 수량, 한 칸이 여러 재화면 n종(FD-033)', () {
      final board = _board([
        _bd('Abydos', 3, owned: 4, required: 10),
        _spec('bd-x', 'tactical_bd', school: 'Arius', family: 'tactical_bd', tier: 2, owned: 1, required: 2),
        _spec('bd-y', 'tactical_bd', school: 'Arius', family: 'tactical_bd', tier: 2, owned: 3, required: 3),
      ]);
      final table = inventoryTierTable(board, InventoryHeatmapKind.bd);
      final abydos = table.rows.first.row.cells[2];
      expect(abydos.text(InventoryHeatmapValue.fulfillment, _amount), '40%');
      expect(abydos.text(InventoryHeatmapValue.owned, _amount), '4');
      expect(abydos.text(InventoryHeatmapValue.shortage, _amount), '6');
      final arius = table.rows[1].row.cells[1];
      expect(arius.items, hasLength(2));
      expect(arius.text(InventoryHeatmapValue.owned, _amount), '2종');
      expect(arius.text(InventoryHeatmapValue.fulfillment, _amount), '75%');
    });

    test('오파츠 표: family 행, 이름은 첫 티어 이름에서 T<n>을 뗀 것, 열 머리는 T<n>', () {
      final board = _board(
        [
          _oopart('Nebra', 1, owned: 10, required: 10),
          _oopart('Nebra', 2, owned: 1, required: 10),
          _oopart('Rohonc', 1), // 계획 밖
        ],
        names: const {
          'oopart-Nebra-1': '네브라 디스크 T1',
          'oopart-Nebra-2': '네브라 디스크 T2',
          'oopart-Rohonc-1': '로혼치 사본 T1',
        },
      );
      final table = inventoryTierTable(board, InventoryHeatmapKind.oopart);
      expect(table.rows.map((row) => row.label), ['네브라 디스크', '로혼치 사본']);
      expect(table.tiers, 2);
      expect(table.heatmap.tierLabel(2), 'T2');
      expect(table.weakestText(table.rows.first, _amount), 'T2 −9');
    });
  });

  group('가장 부족 칸', () {
    test('충족률 낮은 칸 → 같으면 높은 티어 → 부족량 큰 것, 모르는 칸 · 넘치는 칸은 제외', () {
      final board = _board([
        // 시안 네브라 디스크: T3 26% < T4 28% → T3.
        _oopart('Nebra', 3, owned: 13, required: 50),
        _oopart('Nebra', 4, owned: 5, required: 18),
        // 같은 충족률 50%: 높은 티어(T2)가 이긴다.
        _oopart('Tie', 1, owned: 5, required: 10),
        _oopart('Tie', 2, owned: 10, required: 20),
        // 모르는 칸(보유 없음)은 고르지 않는다.
        _oopart('Unknown', 1, owned: 9, required: 10),
        _oopart('Unknown', 2, required: 10),
        // 모두 넉넉하면 계획 행은 `—`.
        _oopart('Enough', 1, owned: 10, required: 10),
      ]);
      final table = inventoryTierTable(board, InventoryHeatmapKind.oopart);
      final byId = {for (final row in table.rows) row.id: row};
      expect(byId['oopart:Nebra']!.weakest!.key, 'oopart-Nebra-3');
      expect(table.weakestText(byId['oopart:Nebra']!, _amount), 'T3 −37');
      expect(byId['oopart:Tie']!.weakest!.key, 'oopart-Tie-2');
      expect(byId['oopart:Unknown']!.weakest!.key, 'oopart-Unknown-1');
      expect(byId['oopart:Enough']!.weakest, isNull);
      expect(table.weakestText(byId['oopart:Enough']!, _amount), '—');
    });

    test('노트 · BD는 티어 라벨(`최상급 −27`)', () {
      final board = _board([
        _note('Hyakkiyako', 3, owned: 11, required: 21),
        _note('Hyakkiyako', 4, owned: 3, required: 30),
      ]);
      final table = inventoryTierTable(board, InventoryHeatmapKind.notes);
      expect(table.weakestText(table.rows.single, _amount), '최상급 −27');
    });
  });

  group('부족 상위 · 요약', () {
    test('세 표의 부족 재화를 부족량 큰 순 → 학생 많은 순 → 카탈로그 순서로 6개, 글자는 종류 · 행 · 티어', () {
      final board = _board(
        [
          _note('Gehenna', 4, owned: 0, required: 30, students: const ['a', 'b', 'c', 'd', 'e', 'f']),
          _note('Abydos', 4, owned: 0, required: 30, students: const ['a', 'b', 'c']),
          _note('RedWinter', 4, owned: 6, required: 30, students: const ['a']),
          _note('Millennium', 4, owned: 12, required: 30, students: const ['a']),
          _bd('Trinity', 3, owned: 19, required: 50, students: const ['a', 'b']),
          _bd('Trinity', 1, owned: 10, required: 10), // 넉넉 → 제외
          _bd('Arius', 2, required: 99), // 보유 모름 → 제외
          _oopart('Nebra', 3, owned: 13, required: 50, students: const ['a', 'b', 'c']),
          _oopart('Rohonc', 4, owned: 2, required: 29, students: const ['a', 'b']),
          _spec('blueprint', 'equipment', family: 'equipment:Hat', tier: 9, owned: 0, required: 99), // 표 밖
        ],
        names: const {'oopart-Nebra-3': '네브라 디스크 T3', 'oopart-Rohonc-4': '로혼치 사본 T4'},
      );
      final analysis = inventoryTiersAnalysis(board, const {});
      expect(analysis.top.map((row) => row.title), [
        '오파츠 · 네브라 디스크 T3',
        'BD · 트리니티 상급',
        '기술 노트 · 게헨나 최상급',
        '기술 노트 · 아비도스 최상급',
        '오파츠 · 로혼치 사본 T4',
        '기술 노트 · 붉은겨울 최상급',
      ]);
      expect(analysis.top.map((row) => row.students.length), [3, 2, 6, 3, 2, 1]);
      // 밀레니엄(−18)은 7번째라 빠진다.
      expect(analysis.top, hasLength(inventoryTierTopCount));
    });

    test('티어 분포는 부족 품목 수(수량 합이 아님), 최상급 부족 품목, 세 충족률과 가장 낮은 값', () {
      final board = _board([
        _note('Gehenna', 2, owned: 1, required: 2), // 부족 1개(일반)
        _note('Gehenna', 4, owned: 0, required: 500), // 부족 500개여도 1종(최상급)
        _bd('Trinity', 3, owned: 1, required: 4), // 상급
        _bd('Trinity', 4, owned: 4, required: 4), // 넉넉 → 분포 밖
        _oopart('Nebra', 4, owned: 0, required: 9), // T4 → 최상급 칸
        _oopart('Nebra', 1, required: 9), // 모름 → 분포 밖
      ]);
      final summary = inventoryTiersAnalysis(board, const {}).summary;
      expect(summary.distribution, [0, 1, 1, 2]);
      expect(summary.shortageKinds, 4);
      expect(summary.topTierShortageKinds, 2);
      expect(summary.notes.fulfillment, closeTo(0.25, 1e-9));
      expect(summary.bd.fulfillment, closeTo(0.625, 1e-9));
      expect(summary.ooparts.fulfillment, closeTo(0, 1e-9));
      expect(summary.ooparts.unknownKinds, 1);
      expect(summary.lowest, closeTo(0, 1e-9));
    });

    test('계획이 없으면 모든 칸이 비고 부족 상위 · 분포가 비며 충족률은 모름', () {
      final board = _board([
        _note('Gehenna', 1, owned: 3),
        _oopart('Nebra', 1, owned: 2),
      ]);
      final analysis = inventoryTiersAnalysis(board, const {});
      expect(analysis.notes.rows.single.planned, isFalse);
      expect(analysis.top, isEmpty);
      expect(analysis.summary.distribution, [0, 0, 0, 0]);
      expect(analysis.summary.notes.fulfillment, isNull);
      expect(analysis.summary.lowest, isNull);
    });
  });
}
