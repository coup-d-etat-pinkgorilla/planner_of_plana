// FE6-c 인벤토리 분석 집계(`inventory_analysis.dart`) 단위 테스트: 학교·티어 평균(FD-031·FD-032), 모름 제외,
// 활성 계획 범위(FD-099), 학생별 부족(FD-101), 동점 정렬, 서로 다른 재화 수량을 더하지 않는 칸(FD-033).
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart';
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

InventoryStageUse _use(String student, int required, int? shortage) =>
    InventoryStageUse(
      studentId: student,
      stageId: 'stage-$student',
      stageName: '',
      phaseNumber: 1,
      studentStep: 1,
      requiredAmount: required,
      shortageAtEntry: shortage,
    );

void main() {
  group('충족률(FD-031 · FD-032)', () {
    test('보유를 아는 계획 재화의 단순 평균, 모름은 빼고 센다, 계획 밖은 무시', () {
      final board = _board([
        _spec('a', 'tactical_bd', owned: 50, required: 100),
        _spec('b', 'tactical_bd', owned: 300, required: 100), // 넘쳐도 1
        _spec('c', 'tactical_bd', required: 40), // 보유 모름
        _spec('d', 'tactical_bd', owned: 0), // 계획 밖
      ]);
      final coverage = inventoryCoverageOf(board.items);
      expect(coverage.fulfillment, closeTo(0.75, 1e-9));
      expect(coverage.plannedKinds, 3);
      expect(coverage.unknownKinds, 1);
    });

    test('모두 모르면 null, 계획 재화가 없으면 planned false', () {
      final unknown = inventoryCoverageOf(
        _board([_spec('a', 'tech_notes', required: 10)]).items,
      );
      expect(unknown.fulfillment, isNull);
      expect(unknown.unknownKinds, 1);
      final none = inventoryCoverageOf(_board([_spec('a', 'tech_notes', owned: 3)]).items);
      expect(none.planned, isFalse);
      expect(none.fulfillment, isNull);
    });
  });

  group('S1 학교 행', () {
    test('활성 계획이 쓰는 학교만, 낮은 충족률 순, 모르면 뒤, 동점은 학생 수 → 카탈로그 순서', () {
      final board = _board([
        // Alpha: BD 0.5, 노트 0.9 → 0.5
        _spec('alpha-bd', 'tactical_bd', school: 'Alpha', tier: 3, owned: 5, required: 10, students: ['s1']),
        _spec('alpha-note', 'tech_notes', school: 'Alpha', tier: 4, owned: 9, required: 10, students: ['s1']),
        // Beta: 계획 밖 → 행 없음(FD-099)
        _spec('beta-bd', 'tactical_bd', school: 'Beta', tier: 3, owned: 1),
        // Gamma: 0.5, 학생 2명 → Alpha보다 앞(동점에서 학생 많은 순)
        _spec('gamma-bd', 'tactical_bd', school: 'Gamma', tier: 2, owned: 5, required: 10, students: ['s2', 's3']),
        // Delta: 모두 모름 → 맨 뒤
        _spec('delta-bd', 'tactical_bd', school: 'Delta', tier: 1, required: 10, students: ['s4']),
        // Epsilon: 0.2 → 맨 앞
        _spec('eps-note', 'tech_notes', school: 'Epsilon', tier: 1, owned: 2, required: 10, students: ['s5']),
        // Zeta: 0.5, 학생 1명, 카탈로그가 Alpha 뒤 → Alpha 다음
        _spec('zeta-bd', 'tactical_bd', school: 'Zeta', tier: 1, owned: 1, required: 2, students: ['s6']),
      ]);
      final rows = inventorySchoolRows(board, const {});
      expect(rows.map((row) => row.school), ['Epsilon', 'Gamma', 'Alpha', 'Zeta', 'Delta']);
      final alpha = rows[2];
      expect(alpha.bd.fulfillment, closeTo(0.5, 1e-9));
      expect(alpha.notes.fulfillment, closeTo(0.9, 1e-9));
      expect(alpha.lowest, closeTo(0.5, 1e-9));
      // 가장 높은 티어의 부족: 노트 T4(최상급) → "부족 최상급 노트 외 1".
      expect(alpha.weakest!.key, 'alpha-note');
      expect(alpha.shortageLabel, '부족 최상급 노트 외 1');
      expect(rows.last.unknownKinds, 1);
      expect(rows.last.shortageLabel, '부족 —');
      expect(rows.last.notes.planned, isFalse);
    });

    test('같은 티어면 충족률 낮은 것, 같으면 BD 먼저', () {
      final board = _board([
        _spec('note', 'tech_notes', school: 'S', tier: 3, owned: 5, required: 10, students: ['a']),
        _spec('bd', 'tactical_bd', school: 'S', tier: 3, owned: 5, required: 10, students: ['a']),
      ]);
      final row = inventorySchoolRows(board, const {}).single;
      expect(row.weakest!.key, 'bd');
      expect(row.shortageLabel, '부족 상급 BD 외 1');
    });

    test('학생별 부족(FD-101): 같은 재화 안에서만 더하고 가장 높은 티어를 보인다, 부족 큰 순', () {
      final board = _board(
        [
          _spec('bd3', 'tactical_bd', school: 'M', tier: 3, owned: 10, required: 40, students: ['rio', 'toki', 'noa']),
          _spec('bd4', 'tactical_bd', school: 'M', tier: 4, owned: 0, required: 6, students: ['toki']),
          _spec('note2', 'tech_notes', school: 'M', tier: 2, owned: 3, required: 10, students: ['noa', 'rio']),
        ],
      );
      final uses = {
        'bd3': [_use('rio', 10, 0), _use('toki', 10, 0), _use('noa', 10, 10), _use('noa', 10, 10)],
        'bd4': [_use('toki', 6, 6)],
        'note2': [_use('noa', 5, 2), _use('rio', 5, 5)],
      };
      final row = inventorySchoolRows(board, uses).single;
      expect(row.students.map((s) => s.studentId), ['toki', 'noa', 'rio']);
      final toki = row.students[0];
      expect(toki.bd!.tier, 4);
      expect(toki.bd!.amount, 6);
      expect(toki.notes, isNull);
      final noa = row.students[1];
      expect(noa.bd!.tier, 3);
      expect(noa.bd!.amount, 20); // 같은 재화(bd3)의 두 단계만 더함
      expect(noa.notes!.amount, 2);
      final rio = row.students[2];
      expect(rio.bd, isNull);
      expect(rio.notes!.amount, 5);
      expect(rio.short, isTrue);
    });

    test('문서 계산이 없으면 affected_student_ids로 학생만 센다(부족 모름)', () {
      final board = _board([
        _spec('bd', 'tactical_bd', school: 'M', tier: 3, owned: 1, required: 10, students: ['b', 'a']),
      ]);
      final row = inventorySchoolRows(board, const {}).single;
      expect(row.students.map((s) => s.studentId), ['b', 'a']);
      expect(row.students.every((s) => s.unknown && !s.short), isTrue);
    });

    test('동점 학생은 이름 순', () {
      final board = _board([
        _spec('bd', 'tactical_bd', school: 'M', tier: 3, owned: 100, required: 10, students: ['x', 'y']),
      ]);
      final uses = {
        'bd': [_use('x', 5, 0), _use('y', 5, 0)],
      };
      final names = {'x': '하나', 'y': '가나'};
      final row = inventorySchoolRows(board, uses, studentName: (id) => names[id]!).single;
      expect(row.students.map((s) => s.studentId), ['y', 'x']);
    });

    test('inventoryStudentShortage: 모르는 단계가 있으면 null, 쓰지 않으면 0', () {
      expect(inventoryStudentShortage('a', [_use('a', 3, 1), _use('a', 3, 2)]), 3);
      expect(inventoryStudentShortage('a', [_use('a', 3, null)]), isNull);
      expect(inventoryStudentShortage('b', [_use('a', 3, 1)]), 0);
    });

    test('학교 · 티어 라벨', () {
      expect(inventorySchoolLabel('Millennium'), '밀레니엄');
      expect(inventorySchoolLabel('RedWinter'), '붉은겨울');
      expect(inventorySchoolLabel('Unknown School'), 'Unknown School');
      expect(inventoryNoteTierLabel(1), '초급');
      expect(inventoryNoteTierLabel(2), '일반');
      expect(inventoryNoteTierLabel(4), '최상급');
      expect(inventoryNoteTierLabel(7), 'T7');
    });
  });

  group('S2 오파츠', () {
    test('계획 · 보유 아는 티어만 점, 모름은 센다, 병목은 왼쪽 위, 이름은 티어 뗀 것', () {
      final board = _board(
        [
          _spec('neb1', 'oopart', family: 'oopart:Nebra', tier: 1, owned: 9, required: 10, students: ['a', 'b', 'c', 'd']),
          _spec('neb4', 'oopart', family: 'oopart:Nebra', tier: 4, owned: 1, required: 10, students: ['a', 'b', 'c', 'd']),
          _spec('neb2', 'oopart', family: 'oopart:Nebra', tier: 2, required: 10, students: ['a']), // 모름
          _spec('neb3', 'oopart', family: 'oopart:Nebra', tier: 3, owned: 5), // 계획 밖
          _spec('roh1', 'oopart', family: 'oopart:Rohonc', tier: 1, owned: 1, required: 10, students: ['a']),
          _spec('other', 'oopart', family: 'workbook:x', tier: 1, owned: 1, required: 10),
        ],
        names: {'neb1': '네브라 디스크 T1', 'neb4': '네브라 디스크 T4', 'roh1': 'Rohonc Codex T1'},
      );
      final analysis = inventoryOopartAnalysis(board, const {});
      expect(analysis.unknownKinds, 1);
      expect(analysis.maxStudents, 4);
      expect(analysis.series.map((series) => series.label), ['네브라 디스크', 'Rohonc Codex']);
      final nebra = analysis.series.first;
      expect(nebra.points.map((point) => point.tier), [1, 4]);
      expect(nebra.points.first.bottleneck, isFalse); // 90%
      expect(nebra.points.last.bottleneck, isTrue); // 10% · 4명 > 2
      expect(nebra.bottleneck, isTrue);
      // 10%지만 학생 1명(축 절반 2 이하) → 병목 아님.
      expect(analysis.series.last.points.single.bottleneck, isFalse);
    });

    test('사용 학생 수는 문서 단계의 학생(중복 없음)을 먼저 쓴다', () {
      final board = _board([
        _spec('neb1', 'oopart', family: 'oopart:Nebra', tier: 1, owned: 1, required: 10, students: ['a']),
      ]);
      final analysis = inventoryOopartAnalysis(board, {
        'neb1': [_use('a', 2, 1), _use('b', 2, 2), _use('a', 2, 2)],
      });
      expect(analysis.series.single.points.single.students, 2);
    });
  });

  group('S4 히트맵', () {
    List<_Spec> blueprints() => [
      _spec('hat1', 'equipment', family: 'equipment:Hat', tier: 1, owned: 1),
      _spec('hat2', 'equipment', family: 'equipment:Hat', tier: 2, owned: 5, required: 10, students: ['a', 'b']),
      _spec('hat3', 'equipment', family: 'equipment:Hat', tier: 3, required: 10, students: ['a']),
      _spec('watch3', 'equipment', family: 'equipment:Watch', tier: 3, owned: 0, required: 5, students: ['a', 'b', 'c']),
      _spec('bag3', 'equipment', family: 'equipment:Bag', tier: 3, owned: 4), // 계획 밖 → 행 없음
      _spec('useall', 'equipment', family: 'equipment:Hat'), // 티어 없음 → 제외
      _spec('stone', 'equipment', family: 'equipment_exp', tier: 4, owned: 1, required: 9),
    ];

    test('계획 재화가 있는 부위만 행, 열은 카탈로그 최고 티어, 칸 글자', () {
      final heatmap = inventoryHeatmap(_board(blueprints()), const {}, InventoryHeatmapKind.blueprint);
      expect(heatmap.tiers, 3);
      expect(heatmap.rows.map((row) => row.label), ['모자', '시계']);
      final hat = heatmap.rows.first;
      String text(InventoryHeatmapCell cell, InventoryHeatmapValue value) =>
          cell.text(value, (amount) => '$amount');
      expect(text(hat.cells[0], InventoryHeatmapValue.fulfillment), ''); // 계획 밖
      expect(text(hat.cells[1], InventoryHeatmapValue.fulfillment), '50%');
      expect(text(hat.cells[1], InventoryHeatmapValue.owned), '5');
      expect(text(hat.cells[1], InventoryHeatmapValue.shortage), '5');
      expect(text(hat.cells[2], InventoryHeatmapValue.fulfillment), '—'); // 보유 모름
      expect(text(hat.cells[2], InventoryHeatmapValue.owned), '—');
      expect(heatmap.tierLabel(2), 'T2');
    });

    test('부족 상위: 부족량 큰 순, 같으면 학생 많은 순 → 카탈로그 순서, 최대 3', () {
      final heatmap = inventoryHeatmap(
        _board([
          ...blueprints(),
          _spec('glove3', 'equipment', family: 'equipment:Gloves', tier: 3, owned: 0, required: 5, students: ['a', 'b', 'c']),
          _spec('shoe3', 'equipment', family: 'equipment:Shoes', tier: 3, owned: 1, required: 1, students: ['a']),
        ]),
        const {},
        InventoryHeatmapKind.blueprint,
      );
      // hat2 −5 · 2명, watch3 −5 · 3명, glove3 −5 · 3명(카탈로그가 watch 뒤).
      expect(heatmap.top.map((top) => top.view.key), ['watch3', 'glove3', 'hat2']);
      expect(heatmap.top.first.students, ['a', 'b', 'c']);
    });

    test('한 칸이 여러 재화면 충족률은 평균, 보유량 · 부족량은 더하지 않고 "n종"(FD-033)', () {
      final heatmap = inventoryHeatmap(
        _board([
          _spec('x1', 'tech_notes', school: 'M', tier: 2, owned: 2, required: 10, students: ['a']),
          _spec('x2', 'tech_notes', school: 'M', tier: 2, owned: 10, required: 10, students: ['a']),
        ]),
        const {},
        InventoryHeatmapKind.notes,
      );
      final cell = heatmap.rows.single.cells[1];
      expect(cell.items, hasLength(2));
      expect(cell.text(InventoryHeatmapValue.fulfillment, (a) => '$a'), '60%');
      expect(cell.text(InventoryHeatmapValue.owned, (a) => '$a'), '2종');
      expect(cell.text(InventoryHeatmapValue.shortage, (a) => '$a'), '2종');
      expect(heatmap.rows.single.label, 'M');
      // FE6-e 사용자 결정: 티어 2는 "일반"(시안 Inventory-Tiers · 게임 명칭).
      expect(heatmap.tierLabel(2), '일반');
    });

    test('종류별 행 id: 노트 · BD는 학교, 오파츠는 family, 다른 category는 제외', () {
      final board = _board([
        _spec('n', 'tech_notes', school: 'Gehenna', tier: 1, owned: 1, required: 2),
        _spec('b', 'tactical_bd', school: 'Gehenna', tier: 1, owned: 1, required: 2),
        _spec('o', 'oopart', family: 'oopart:Nebra', tier: 1, owned: 1, required: 2),
      ]);
      expect(inventoryHeatmapRowId(board['n']!, InventoryHeatmapKind.notes), 'Gehenna');
      expect(inventoryHeatmapRowId(board['n']!, InventoryHeatmapKind.bd), isNull);
      expect(inventoryHeatmapRowId(board['b']!, InventoryHeatmapKind.bd), 'Gehenna');
      expect(inventoryHeatmapRowId(board['o']!, InventoryHeatmapKind.oopart), 'oopart:Nebra');
      expect(inventoryHeatmap(board, const {}, InventoryHeatmapKind.notes).rows.single.label, '게헨나');
    });

    test('칸 색 불투명도는 시안 선형(0% .065 → 100% .90)', () {
      expect(inventoryHeatmapAlpha(0), closeTo(0.065, 1e-9));
      expect(inventoryHeatmapAlpha(1), closeTo(0.9, 1e-9));
      expect(inventoryHeatmapAlpha(0.5), closeTo(0.4825, 1e-9));
    });
  });
}
