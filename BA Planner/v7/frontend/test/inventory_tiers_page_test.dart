// FE6-e 인벤토리 티어별 충족률 위젯 테스트(시안 Inventory-Tiers): 사이드바 진입 · 복귀, 섹션 교체 모션, T1 · T2 · T4 히트맵
// (카탈로그 전부 · 가장 부족 · 표마다 칩), T5 부족 상위, T6 요약, 섹션 배치(Studio 문서 ±1px), 계획 없음, 작은 창.
// 숫자는 `inventory_fe6e_fixture.dart`다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis_charts.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_controller.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:ba_planner_v7/ui/studio/inventory_studio_layout.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';
import 'inventory_fe6e_fixture.dart';

Widget _subject(AppService service, {InventoryController? controller}) =>
    MaterialApp(
      home: Scaffold(
        body: InventoryPage(
          service: service,
          controller: controller,
          onOpenPlan: () {},
          onOpenScan: () {},
        ),
      ),
    );

Future<void> _surface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: key);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _inside(String key, String text) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.text(text),
);

RailButtonVariant _variant(WidgetTester tester, String key) =>
    tester.widget<RailButton>(find.byKey(ValueKey(key))).variant;

InventoryTierHeatmapPainter _painter(WidgetTester tester, String kind) =>
    tester
            .widget<CustomPaint>(
              find.byKey(ValueKey('inventory-tiers-heatmap-$kind')),
            )
            .painter!
        as InventoryTierHeatmapPainter;

Future<InventoryController> _openTiers(
  WidgetTester tester,
  AppService service,
) async {
  final controller = InventoryController(service);
  addTearDown(controller.dispose);
  await tester.pumpWidget(_subject(service, controller: controller));
  await tester.pumpAndSettle();
  await _tap(tester, 'inventory-mode-analysis');
  await _tap(tester, 'inventory-analysis-open-tiers');
  expect(controller.tiersOpen, isTrue);
  return controller;
}

void main() {
  testWidgets('sidebar opens the tiers screen and every exit returns', (tester) async {
    await _surface(tester, const Size(2560, 1392));
    final service = InventoryTiersFixtureService();
    addTearDown(service.dispose);
    final controller = await _openTiers(tester, service);

    // 사이드바는 분석과 같고, 티어 버튼만 선택(분홍), 분석 버튼 4개는 고르지 않은 모양이다.
    expect(_variant(tester, 'inventory-analysis-open-tiers'), RailButtonVariant.selectedPink);
    for (final focus in InventoryAnalysisFocus.values) {
      expect(
        _variant(tester, 'inventory-analysis-focus-${focus.name}'),
        RailButtonVariant.ghost,
      );
    }
    expect(find.text('비교 기준'), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-tiers-surfaces')), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-analysis-surfaces')), findsNothing);
    // 분석 네 섹션 대신 다섯 섹션.
    expect(find.text('학교별 BD · 기술 노트 충족률'), findsNothing);
    expect(find.text('기술 노트 · 학교 × 티어 충족률'), findsOneWidget);
    expect(find.text('전술 교육 BD · 학교 × 티어 충족률'), findsOneWidget);
    expect(find.text('오파츠 · 종류 × 티어 충족률'), findsOneWidget);
    expect(find.text('티어 품목 · 부족 상위'), findsOneWidget);
    expect(find.text('티어 충족 요약'), findsOneWidget);
    expect(find.text('계획 필요량 기준'), findsNWidgets(2));
    // FD-097: 과잉 재화 버튼은 여기서도 없다.
    expect(find.text('과잉 재화'), findsNothing);

    // 다시 누르면 분석으로.
    await _tap(tester, 'inventory-analysis-open-tiers');
    expect(controller.tiersOpen, isFalse);
    expect(find.byKey(const ValueKey('inventory-analysis-surfaces')), findsOneWidget);
    expect(find.text('학교별 BD · 기술 노트 충족률'), findsOneWidget);
    expect(_variant(tester, 'inventory-analysis-open-tiers'), RailButtonVariant.ghost);

    // 분석 버튼을 누르면 분석으로 돌아가며 그 섹션을 강조한다.
    await _tap(tester, 'inventory-analysis-open-tiers');
    await _tap(tester, 'inventory-analysis-focus-ooparts');
    expect(controller.tiersOpen, isFalse);
    expect(controller.analysisFocus, InventoryAnalysisFocus.ooparts);
    expect(
      find.byKey(const ValueKey('inventory-analysis-highlight-inventory-analysis-ooparts')),
      findsOneWidget,
    );
    expect(_variant(tester, 'inventory-analysis-focus-ooparts'), RailButtonVariant.selectedPink);

    // "목록"으로 가면 닫히고, 다시 "분석"을 누르면 분석 첫 화면이다.
    await _tap(tester, 'inventory-analysis-open-tiers');
    await _tap(tester, 'inventory-mode-list');
    expect(controller.screenMode, InventoryScreenMode.list);
    expect(controller.tiersOpen, isFalse);
    expect(find.byKey(const ValueKey('inventory-surfaces')), findsOneWidget);
    await _tap(tester, 'inventory-mode-analysis');
    expect(find.byKey(const ValueKey('inventory-analysis-surfaces')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analysis <-> tiers swap moves sections out then in', (tester) async {
    await _surface(tester, const Size(2560, 1392));
    final service = InventoryTiersFixtureService();
    addTearDown(service.dispose);
    final controller = InventoryController(service);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_subject(service, controller: controller));
    await tester.pumpAndSettle();
    await _tap(tester, 'inventory-mode-analysis');

    await tester.tap(find.byKey(const ValueKey('inventory-analysis-open-tiers')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // 앞 절반: 분석 섹션이 나간다(위 면 S1은 위로, 오른쪽 면 S2는 오른쪽으로).
    expect(find.byKey(const ValueKey('inventory-motion-surfaces')), findsOneWidget);
    final schools = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('inventory-motion-inventory-analysis-schools')),
        matching: find.byType(Transform),
      ).first,
    );
    final ooparts = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('inventory-motion-inventory-analysis-ooparts')),
        matching: find.byType(Transform),
      ).first,
    );
    expect(schools.transform.getTranslation().y, lessThan(0));
    expect(ooparts.transform.getTranslation().x, greaterThan(0));
    // 뒤 절반: 티어 섹션이 들어온다(T2 부유 패널은 아래에서 위로, T4는 오른쪽에서).
    await tester.pump(const Duration(milliseconds: 360));
    final bd = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey('inventory-motion-inventory-tiers-bd')),
        matching: find.byType(Transform),
      ).first,
    );
    expect(bd.transform.getTranslation().y, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inventory-motion-surfaces')), findsNothing);
    expect(find.byKey(const ValueKey('inventory-tiers-surfaces')), findsOneWidget);
    // 돌아갈 때도 같은 규칙.
    await tester.tap(find.byKey(const ValueKey('inventory-analysis-open-tiers')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('inventory-motion-inventory-tiers-notes')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inventory-analysis-surfaces')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T1 · T2 · T4 heatmaps: catalog rows, weakest cell, per-table chips', (
    tester,
  ) async {
    await _surface(tester, const Size(2560, 1392));
    final service = InventoryTiersFixtureService();
    addTearDown(service.dispose);
    final controller = await _openTiers(tester, service);

    final notes = _painter(tester, 'notes');
    expect(notes.heatmap.rows.map((row) => row.label), [
      '백귀야행', '붉은겨울', '트리니티', '게헨나', '아비도스', '밀레니엄', '아리우스', '산해경', '발키리',
    ]);
    expect([for (var tier = 1; tier <= 4; tier++) notes.heatmap.tierLabel(tier)], [
      '초급', '일반', '상급', '최상급',
    ]);
    expect(notes.labelWidth, 96);
    expect(notes.trailingWidth, 128);
    expect(notes.trailingHeader, '가장 부족');
    expect(notes.rowLabels, isFalse);
    String percent(InventoryTierHeatmapPainter painter, int row, int tier) =>
        painter.heatmap.rows[row].cells[tier - 1].text(
          InventoryHeatmapValue.fulfillment,
          (value) => '$value',
        );
    // 시안 T1 백귀야행 95 · 89 · 52 · 10.
    expect([for (var tier = 1; tier <= 4; tier++) percent(notes, 0, tier)], [
      '95%', '89%', '52%', '10%',
    ]);
    expect(_inside('inventory-tiers-notes-row-Hyakkiyako', '백귀야행'), findsOneWidget);
    expect(_inside('inventory-tiers-notes-weakest-Gehenna', '최상급 −30'), findsOneWidget);
    expect(_inside('inventory-tiers-notes-weakest-Millennium', '최상급 −18'), findsOneWidget);

    final bd = _painter(tester, 'bd');
    // 시안 T2 트리니티 100 · 96 · 38 · 57, 가장 부족 상급 −31.
    expect([for (var tier = 1; tier <= 4; tier++) percent(bd, 2, tier)], [
      '100%', '96%', '38%', '57%',
    ]);
    expect(_inside('inventory-tiers-bd-weakest-Trinity', '상급 −31'), findsOneWidget);

    final ooparts = _painter(tester, 'oopart');
    expect(ooparts.heatmap.rows, hasLength(13));
    expect(ooparts.heatmap.rows.first.label, '네브라 디스크');
    expect(ooparts.heatmap.tierLabel(3), 'T3');
    expect(ooparts.labelWidth, 150);
    expect([for (var tier = 1; tier <= 4; tier++) percent(ooparts, 0, tier)], [
      '100%', '90%', '26%', '28%',
    ]);
    expect(_inside('inventory-tiers-oopart-weakest-oopart:Nebra', 'T3 −37'), findsOneWidget);
    expect(_inside('inventory-tiers-oopart-row-oopart:Nebra', '네브라 디스크'), findsOneWidget);

    // 칩은 표마다 따로다.
    await _tap(tester, 'inventory-tiers-notes-value-shortage');
    expect(controller.tierValue(InventoryHeatmapKind.notes), InventoryHeatmapValue.shortage);
    expect(_painter(tester, 'notes').value, InventoryHeatmapValue.shortage);
    expect(_painter(tester, 'bd').value, InventoryHeatmapValue.fulfillment);
    await _tap(tester, 'inventory-tiers-oopart-value-owned');
    expect(_painter(tester, 'oopart').value, InventoryHeatmapValue.owned);
    expect(_painter(tester, 'notes').value, InventoryHeatmapValue.shortage);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T5 top shortages and T6 summary', (tester) async {
    await _surface(tester, const Size(2560, 1392));
    final service = InventoryTiersFixtureService();
    addTearDown(service.dispose);
    await _openTiers(tester, service);

    const rows = [
      ('오파츠 · 네브라 디스크 T3', '−37 · 학생 3명'),
      ('BD · 트리니티 상급', '−31 · 학생 2명'),
      ('기술 노트 · 게헨나 최상급', '−30 · 학생 6명'),
      ('기술 노트 · 아비도스 최상급', '−30 · 학생 3명'),
      ('오파츠 · 로혼치 사본 T4', '−27 · 학생 2명'),
      ('기술 노트 · 붉은겨울 최상급', '−24 · 학생 1명'),
    ];
    for (final (index, (title, amount)) in rows.indexed) {
      expect(_inside('inventory-tiers-top-$index', title), findsOneWidget, reason: title);
      expect(_inside('inventory-tiers-top-$index', amount), findsOneWidget, reason: amount);
    }
    expect(find.byKey(const ValueKey('inventory-tiers-top-6')), findsNothing);
    // 게헨나 6명 = 초상 5 + "…+1".
    expect(_inside('inventory-tiers-top-2', '…+1'), findsOneWidget);
    // 행은 사선을 따라 아래로 갈수록 왼쪽으로 간다.
    final first = tester.getTopLeft(find.byKey(const ValueKey('inventory-tiers-top-0')));
    final last = tester.getTopLeft(find.byKey(const ValueKey('inventory-tiers-top-5')));
    expect(last.dy, greaterThan(first.dy));
    expect(last.dx, lessThan(first.dx));

    Text kpi(String id) =>
        tester.widget<Text>(find.byKey(ValueKey('inventory-tiers-kpi-$id')));
    expect(kpi('notes').data, '66%');
    expect(kpi('bd').data, '75%');
    expect(kpi('ooparts').data, '64%');
    expect(kpi('top-tier').data, '31종');
    expect(find.text('최상급 부족 품목'), findsOneWidget);
    // 세 충족률 중 가장 낮은 오파츠와 최상급 부족 품목이 분홍이다.
    expect(kpi('ooparts').style!.color, const Color(0xfff2b3ef));
    expect(kpi('top-tier').style!.color, const Color(0xfff2b3ef));
    expect(kpi('notes').style!.color, isNot(const Color(0xfff2b3ef)));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory-tiers-distribution-caption'))).data,
      '부족 품목 100종 · 티어 분포',
    );
    for (final (tier, label) in const [(1, '초급 7'), (2, '일반 31'), (3, '상급 31'), (4, '최상급 31')]) {
      final text = tester.widget<Text>(
        find.byKey(ValueKey('inventory-tiers-distribution-$tier')),
      );
      expect(text.textSpan!.toPlainText(), label);
    }
    expect(find.byKey(const ValueKey('inventory-tiers-distribution-bar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Studio section corners match the artboard (T2 bottom −2.6px, grid rows)', () {
    const canvas = Size(2560, 1208);
    // 시안 path의 직선 교점(위 왼 · 위 오 · 아래 오 · 아래 왼), 기준 viewport 좌표.
    const expected = <String, List<Offset>>{
      inventoryTiersNotesSectionId: [
        Offset(717.3, 209.2), Offset(1560.0, 209.2), Offset(1483.2, 645.2), Offset(640.5, 645.2),
      ],
      inventoryTiersBdSectionId: [
        Offset(636.1, 669.2), Offset(1478.8, 669.2), Offset(1402.0, 1105.2), Offset(559.3, 1105.2),
      ],
      inventoryTiersOopartsSectionId: [
        Offset(1583.9, 209.2), Offset(2560, 209.2), Offset(2560, 800.0), Offset(1479.8, 800.0),
      ],
      inventoryTiersTopSectionId: [
        Offset(1475.5, 824.0), Offset(2560, 824.0), Offset(2560, 1392), Offset(1375.4, 1392),
      ],
      inventoryTiersSummarySectionId: [
        Offset(555.1, 1129.2), Offset(1397.8, 1129.2), Offset(1351.5, 1392), Offset(508.8, 1392),
      ],
    };
    for (final MapEntry(key: id, value: corners) in expected.entries) {
      final section = inventoryTiersSection(id);
      final rect = sectionCanvasElementRect(canvas, section);
      final points = [
        for (final point in buildAttachedSectionPolygon(rect.size, section.spec))
          point + rect.topLeft + const Offset(0, 184),
      ]..sort((a, b) => a.dy.compareTo(b.dy));
      final top = [points[0], points[1]]..sort((a, b) => a.dx.compareTo(b.dx));
      final bottom = [points[2], points[3]]..sort((a, b) => a.dx.compareTo(b.dx));
      final actual = [top[0], top[1], bottom[1], bottom[0]];
      for (var index = 0; index < 4; index++) {
        final tolerance = id == inventoryTiersBdSectionId && index >= 2 ? 2.7 : 1.0;
        expect((actual[index].dx - corners[index].dx).abs(), lessThanOrEqualTo(1.0),
            reason: '$id corner $index x');
        expect((actual[index].dy - corners[index].dy).abs(), lessThanOrEqualTo(tolerance),
            reason: '$id corner $index y');
      }
    }
    // 사이드바는 분석 모드와 같은 element다.
    expect(
      inventoryTiersSection(inventorySidebarSectionId).rect.x,
      inventoryAnalysisSection(inventorySidebarSectionId).rect.x,
    );
  });

  testWidgets('without a plan the tiers sections show the plan notice', (tester) async {
    await _surface(tester, const Size(2560, 1392));
    final service = InventoryFixtureService(plan: false);
    addTearDown(service.dispose);
    await _openTiers(tester, service);
    expect(find.byKey(const ValueKey('inventory-tiers-notes-blocked')), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-tiers-top-blocked')), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-tiers-heatmap-notes')), findsNothing);
    expect(find.byKey(const ValueKey('inventory-tiers-kpi-notes')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small window keeps the tiers screen without exceptions', (tester) async {
    await _surface(tester, const Size(1280, 720));
    final service = InventoryTiersFixtureService();
    addTearDown(service.dispose);
    await _openTiers(tester, service);
    expect(find.byKey(const ValueKey('inventory-tiers-heatmap-notes')), findsOneWidget);
    await _tap(tester, 'inventory-analysis-open-tiers');
    await _tap(tester, 'inventory-analysis-open-tiers');
    expect(tester.takeException(), isNull);
  });
}
