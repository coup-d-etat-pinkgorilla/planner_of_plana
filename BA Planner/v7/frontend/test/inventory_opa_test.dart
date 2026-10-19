// FE6-d 오파츠 확장 집계(`inventory_analysis.dart`) · 배치 단위 테스트: 가장 부족한 티어, 병목 순위(오파츠마다 한 줄, 서로
// 다른 재화 수량을 더하지 않음 FD-033), 기본 선택(FD-103), 선택 오파츠 상세(티어별 보유 / 필요, 학생별 티어 부족 FD-101),
// 확장 S2 Studio element 꼭짓점.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_view_model.dart';
import 'package:ba_planner_v7/ui/kit/section_morph.dart';
import 'package:ba_planner_v7/ui/studio/inventory_studio_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 오파츠 한 티어: (family 키, 티어, 보유(null = 항목 없음), 필요(null = 계획 밖), 사용 학생).
typedef _Tier = (String, int, int?, int?, List<String>);

InventoryBoard _board(List<_Tier> tiers) {
  String key(_Tier tier) => 'Item_Icon_Material_${tier.$1}_${tier.$2 - 1}';
  final catalog = [
    for (final (index, tier) in tiers.indexed)
      InventoryCatalogEntry(
        resourceKey: key(tier),
        itemId: key(tier),
        displayName: '${tier.$1} 이름 T${tier.$2}',
        category: 'oopart',
        profileId: 'ooparts',
        orderIndex: index,
        zeroFillAllowed: true,
        school: null,
        family: 'oopart:${tier.$1}',
        tier: tier.$2,
      ),
  ];
  final inventory = RepositoryInventoryState.fromWire({
    'version': 1,
    'entries': [
      for (final tier in tiers)
        if (tier.$3 != null)
          {'key': key(tier), 'item_id': key(tier), 'quantity': '${tier.$3}'},
    ],
  });
  final shortages = InventoryShortageResult([
    for (final tier in tiers)
      if (tier.$4 case final required?)
        InventoryShortageRow(
          resourceKey: key(tier),
          itemId: key(tier),
          displayName: '${tier.$1} 이름 T${tier.$2}',
          category: 'oopart',
          requiredAmount: required,
          owned: tier.$3,
          shortage: tier.$3 == null
              ? null
              : (tier.$3! >= required ? 0 : required - tier.$3!),
          affectedStudentIds: tier.$5,
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

InventoryItemView _view(InventoryBoard board, String family, int tier) =>
    board.items.firstWhere(
      (view) => view.item.family == 'oopart:$family' && view.item.tier == tier,
    );

const _six = ['a', 'b', 'c', 'd', 'e', 'f'];

/// 시안 Inventory-Analysis-Opa 병목 순위 다섯 + 모자람 없는 하나.
List<_Tier> _opaTiers() => [
  ('Nebra', 1, 210, 180, _six),
  ('Nebra', 2, 160, 120, _six),
  ('Nebra', 3, 96, 133, _six),
  ('Nebra', 4, 12, 58, _six),
  ('Rohonc', 3, 50, 60, _six),
  ('Rohonc', 4, 19, 50, _six),
  ('Phaistos', 3, 58, 80, const ['a', 'b']),
  ('Phaistos', 4, 40, 40, const ['a', 'b']),
  ('Antikythera', 4, 30, 48, const ['c']),
  ('Aurum', 1, 300, 240, _six),
  ('Torino', 3, 36, 45, const ['d', 'e']),
  ('Torino', 4, 60, 50, const ['d', 'e']),
];

void main() {
  group('가장 부족한 티어', () {
    test('충족률 가장 낮은 티어 → 높은 티어 → 부족량 큰 것, 모자람 없으면 null', () {
      final board = _board(_opaTiers());
      final nebra = [for (var t = 1; t <= 4; t++) _view(board, 'Nebra', t)];
      // T3 96/133 = 72% · T4 12/58 = 21% → T4.
      expect(inventoryOopartWeakestTier(nebra)?.item.tier, 4);
      expect(
        inventoryOopartWeakestTier([_view(board, 'Aurum', 1)]),
        isNull,
      );
      // 충족률이 같으면 높은 티어.
      final tie = _board([
        ('X', 1, 5, 10, const ['a']),
        ('X', 2, 10, 20, const ['a']),
      ]);
      expect(
        inventoryOopartWeakestTier(tie.items)?.item.tier,
        2,
      );
      // 보유를 모르는 티어는 건너뛴다.
      final unknown = _board([
        ('X', 1, null, 10, const ['a']),
        ('X', 2, 19, 20, const ['a']),
      ]);
      expect(inventoryOopartWeakestTier(unknown.items)?.item.tier, 2);
    });
  });

  group('병목 순위', () {
    test('오파츠마다 가장 부족한 티어 한 줄, 부족량 큰 순 5행(시안 −46 · −31 · −22 · −18 · −9)', () {
      final board = _board(_opaTiers());
      final analysis = inventoryOopartAnalysis(board, const {});
      final ranking = inventoryOopartRanking(analysis);
      expect([for (final rank in ranking) rank.family], [
        'oopart:Nebra',
        'oopart:Rohonc',
        'oopart:Phaistos',
        'oopart:Antikythera',
        'oopart:Torino',
      ]);
      expect([for (final rank in ranking) rank.shortage], [46, 31, 22, 18, 9]);
      expect([for (final rank in ranking) rank.tier], [4, 4, 3, 4, 3]);
      // 네브라 T3 −37과 T4 −46을 더하지 않는다(FD-033).
      expect(ranking.first.shortage, 46);
      expect(ranking.first.label, 'Nebra 이름');
      // 핵심 병목(보유율 50% 미만 + 학생 6명 > 최대 6명의 절반): 네브라 T4 · 로혼치 T4.
      expect([for (final rank in ranking) rank.bottleneck], [true, true, false, false, false]);
      expect(inventoryOopartRanking(analysis, limit: 2), hasLength(2));
    });

    test('부족량이 같으면 충족률 낮은 순 → 카탈로그 순서', () {
      final board = _board([
        ('A', 1, 90, 100, const ['a']), // −10, 90%
        ('B', 1, 10, 20, const ['a']), // −10, 50%
        ('C', 1, 90, 100, const ['a']), // −10, 90%
      ]);
      final ranking = inventoryOopartRanking(
        inventoryOopartAnalysis(board, const {}),
      );
      expect([for (final rank in ranking) rank.family], [
        'oopart:B',
        'oopart:A',
        'oopart:C',
      ]);
    });
  });

  group('기본 선택(FD-103)', () {
    test('병목 순위 1위, 없으면 산점도 첫 오파츠, 둘 다 없으면 null', () {
      final board = _board(_opaTiers());
      final analysis = inventoryOopartAnalysis(board, const {});
      expect(
        inventoryDefaultOopartFamily(analysis, inventoryOopartRanking(analysis)),
        'oopart:Nebra',
      );
      final enough = inventoryOopartAnalysis(
        _board([
          ('Aurum', 1, 300, 240, _six),
          ('Orb', 1, 80, 60, const ['a']),
        ]),
        const {},
      );
      expect(
        inventoryDefaultOopartFamily(enough, inventoryOopartRanking(enough)),
        'oopart:Aurum',
      );
      final empty = inventoryOopartAnalysis(_board(const []), const {});
      expect(inventoryDefaultOopartFamily(empty, const []), isNull);
    });
  });

  group('선택 오파츠 상세', () {
    test('티어별 보유 / 필요(계획 밖 · 모름 포함), 머리 아이콘, 핵심 병목', () {
      final board = _board([
        ('Nebra', 1, 210, 180, const ['a']),
        ('Nebra', 2, 160, null, const []), // 계획 밖
        ('Nebra', 3, null, 133, const ['a']), // 보유 모름
        ('Nebra', 4, 12, 58, const ['a']),
      ]);
      final analysis = inventoryOopartAnalysis(board, const {});
      final detail = inventoryOopartDetail(
        board,
        const {},
        'oopart:Nebra',
        analysis: analysis,
      )!;
      expect(detail.label, 'Nebra 이름');
      expect([for (final view in detail.tiers) view.item.tier], [1, 2, 3, 4]);
      expect(detail.tiers[1].requiredAmount, isNull);
      expect(detail.tiers[2].owned, isNull);
      expect(detail.tiers[3].shortageAmount, 46);
      expect(detail.icon.item.tier, 4);
      expect(detail.bottleneck, analysis.series.single.bottleneck);
      expect(
        inventoryOopartDetail(board, const {}, 'oopart:None', analysis: analysis),
        isNull,
      );
    });

    test('학생별 티어 부족(FD-101): 같은 재화 안에서만 더하고, 모자람 큰 학생이 위', () {
      final students = ['rio', 'toki', 'kurumi', 'hoshino', 'aru', 'mika'];
      final board = _board([
        ('Nebra', 3, 96, 133, [for (final s in students) if (s != 'kurumi') s]),
        ('Nebra', 4, 12, 58, students),
      ]);
      final t3 = _view(board, 'Nebra', 3).key;
      final t4 = _view(board, 'Nebra', 4).key;
      final uses = {
        t3: [
          _use('rio', 104, 8),
          _use('toki', 6, 6),
          _use('hoshino', 4, 4),
          _use('aru', 12, 12),
          _use('mika', 7, 7),
        ],
        t4: [
          _use('rio', 24, 12),
          _use('toki', 10, 10),
          _use('kurumi', 8, 8),
          _use('hoshino', 6, 6),
          _use('aru', 4, 4),
          _use('mika', 4, 2),
          _use('mika', 4, 4), // 같은 재화의 두 단계는 더한다(2 + 4 = 6)
        ],
      };
      const names = {
        'rio': '리오',
        'toki': '토키',
        'kurumi': '쿠루미',
        'hoshino': '호시노',
        'aru': '아루',
        'mika': '미카',
      };
      final detail = inventoryOopartDetail(
        board,
        uses,
        'oopart:Nebra',
        analysis: inventoryOopartAnalysis(board, uses),
        studentName: (id) => names[id] ?? id,
      )!;
      // 가장 높은 티어(T4) 부족량 큰 순, 같으면 이름순(미카 6 · 호시노 6).
      expect([for (final s in detail.students) s.studentId], [
        'rio',
        'toki',
        'kurumi',
        'mika',
        'hoshino',
        'aru',
      ]);
      final rio = detail.students.first;
      expect(rio.need(4), 12);
      expect(rio.need(3), 8);
      expect(detail.students[2].need(3), isNull); // 쿠루미는 T3를 쓰지 않는다
      expect(detail.students[3].need(4), 6);
      expect(detail.studentTiers, [4, 3]);
      // 학생별 부족의 합은 그 티어 부족량과 같다(재화 하나 안에서만 더함).
      expect(
        detail.students.fold<int>(0, (sum, s) => sum + (s.need(4) ?? 0)),
        46,
      );
    });

    test('단계 정보가 없으면 학생 몫을 모른다', () {
      final board = _board([
        ('Nebra', 4, 12, 58, const ['a', 'b']),
      ]);
      final detail = inventoryOopartDetail(
        board,
        const {},
        'oopart:Nebra',
        analysis: inventoryOopartAnalysis(board, const {}),
      )!;
      expect([for (final s in detail.students) s.studentId], ['a', 'b']);
      expect(detail.students.every((s) => s.unknown && !s.short), isTrue);
      expect(detail.studentTiers, isEmpty);
    });
  });

  group('확장 S2 배치(Studio)', () {
    const size = Size(2560, 1208);

    test('확장 섹션은 오른쪽 · 위 부착, 시안 대비 왼쪽 사선 변만 −12px', () {
      final points = sectionCanvasElementPolygon(
        size,
        inventoryAnalysisOopartsExpandedSection,
      );
      // 시안(헤더 아래 기준 y − 184): (220.6, 25.2) · (2560, 25.2) · (2560, 1208) · (12, 1208).
      final topRight = points[0];
      final bottomRight = points[1];
      final bottomLeft = points[2];
      final topLeft = points[3];
      expect(topRight.dx, closeTo(2560, 1e-6));
      expect(topRight.dy, closeTo(25.2, 1));
      expect(bottomRight, const Offset(2560, 1208));
      expect(bottomLeft.dx, closeTo(12 - 12, 1e-6));
      expect(bottomLeft.dy, closeTo(1208, 1e-6));
      expect(topLeft.dx, closeTo(220.6 - 12, 0.1));
      expect(topLeft.dy, closeTo(25.2, 1));
    });

    test('접힌 S2에서 확장 S2로 같은 꼴(오른쪽 면 사다리꼴) morph', () {
      final from = inventoryAnalysisSection(inventoryAnalysisOopartsSectionId);
      final to = inventoryAnalysisOopartsExpandedSection;
      expect(from.spec.mode, to.spec.mode);
      expect(from.spec.face, to.spec.face);
      final mid = sectionMorphPolygon(size, from, to, 0.5);
      // 위 · 오른쪽 변은 그대로 붙어 있다(오른쪽 · 위 부착 유지).
      expect(mid[0].dx, closeTo(2560, 1e-6));
      expect(mid[0].dy, closeTo(25.17, 0.1));
      expect(mid[1].dx, closeTo(2560, 1e-6));
    });
  });
}
