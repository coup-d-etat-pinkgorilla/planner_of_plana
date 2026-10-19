// FE6-c 인벤토리 분석 모드 위젯 테스트(시안 Inventory-Analysis): 사이드바 분석 메뉴, S1 학교 행 · 플라이아웃,
// S2 산점도 · 티어 토글, S4 히트맵 · 부족 상위, S5 최근 변화(FE6-f, 행 값은 inventory_history_page_test), 목록 ↔ 분석
// 전환, 작은 창.
// 숫자는 `inventory_fe6c_fixture.dart`다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis_charts.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_controller.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';
import 'inventory_fe6c_fixture.dart';

Widget _subject(
  AppService service, {
  InventoryController? controller,
  VoidCallback? onOpenPlan,
}) => MaterialApp(
  home: Scaffold(
    body: InventoryPage(
      service: service,
      controller: controller,
      onOpenPlan: onOpenPlan ?? () {},
      onOpenScan: () {},
    ),
  ),
);

Future<void> _standardSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: key);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapSegment(WidgetTester tester, String key, String label) async {
  final finder = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.text(label),
  );
  expect(finder, findsOneWidget, reason: '$key / $label');
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _inside(String key, String text) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.text(text),
);

InventoryTierHeatmapPainter _heatmapPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const ValueKey('inventory-heatmap'))).painter!
        as InventoryTierHeatmapPainter;

InventoryOopartScatterPainter _scatterPainter(WidgetTester tester) =>
    tester
            .widget<StatChartFrame>(
              find.byKey(const ValueKey('inventory-oopart-scatter')),
            )
            .painter
        as InventoryOopartScatterPainter;

Future<InventoryController> _openAnalysis(
  WidgetTester tester,
  AppService service, {
  VoidCallback? onOpenPlan,
}) async {
  final controller = InventoryController(service);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    _subject(service, controller: controller, onOpenPlan: onOpenPlan),
  );
  await tester.pumpAndSettle();
  await _tap(tester, 'inventory-mode-analysis');
  expect(controller.screenMode, InventoryScreenMode.analysis);
  return controller;
}

void main() {
  testWidgets('sidebar analysis menu: compare basis, focus buttons, separate screens', (
    tester,
  ) async {
    await _standardSurface(tester);
    final service = InventoryAnalysisFixtureService();
    addTearDown(service.dispose);
    final controller = await _openAnalysis(tester, service);

    // 목록 모드의 아이템 · 장비 seg와 종류 버튼은 분석 모드에 없다(§3.6-1).
    expect(find.byKey(const ValueKey('inventory-kind')), findsNothing);
    expect(find.byKey(const ValueKey('inventory-view-shortage')), findsNothing);
    expect(find.text('비교 기준'), findsOneWidget);
    expect(find.text('활성 계획의 학생·목표에 필요한 양과 비교합니다'), findsOneWidget);
    final plan = tester.widget<SkewSegmented<String>>(
      find.byKey(const ValueKey('inventory-compare-plan')),
    );
    expect(plan.selected, 'plan');
    // FD-097: 이론상 전체 요구량은 비활성, 넘치는 재화 정리는 숨김.
    final theory = tester.widget<SkewSegmented<String>>(
      find.byKey(const ValueKey('inventory-compare-theory')),
    );
    expect(theory.onChanged, isNull);
    expect(find.text('과잉 재화'), findsNothing);
    expect(find.text('넘치는 재화 정리'), findsNothing);
    // 티어별 충족률(FE6-e): 켜져 있고 고르지 않은 모양이다(여는 동작은 inventory_tiers_page_test.dart).
    final tiers = tester.widget<RailButton>(
      find.byKey(const ValueKey('inventory-analysis-open-tiers')),
    );
    expect(tiers.onPressed, isNotNull);
    expect(tiers.variant, RailButtonVariant.ghost);
    expect(find.text('기술 노트 · BD · 오파츠'), findsOneWidget);
    for (final focus in InventoryAnalysisFocus.values) {
      expect(find.text(focus.label), findsOneWidget);
    }

    // 강조: 버튼 → 섹션 외곽선, 다시 누르면 풀림. 장비 설계도는 S4를 설계도로 돌린다.
    await _tapSegment(tester, 'inventory-heatmap-kind', 'BD');
    expect(controller.heatmapKind, InventoryHeatmapKind.bd);
    await _tap(tester, 'inventory-analysis-focus-blueprints');
    expect(controller.analysisFocus, InventoryAnalysisFocus.blueprints);
    expect(controller.heatmapKind, InventoryHeatmapKind.blueprint);
    expect(
      find.byKey(const ValueKey('inventory-analysis-highlight-inventory-analysis-tiers')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<RailButton>(
            find.byKey(const ValueKey('inventory-analysis-focus-blueprints')),
          )
          .variant,
      RailButtonVariant.selectedPink,
    );
    await _tap(tester, 'inventory-analysis-focus-schools');
    expect(
      find.byKey(const ValueKey('inventory-analysis-highlight-inventory-analysis-schools')),
      findsOneWidget,
    );
    await _tap(tester, 'inventory-analysis-focus-schools');
    expect(controller.analysisFocus, isNull);
    expect(
      find.byKey(const ValueKey('inventory-analysis-highlight-inventory-analysis-schools')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('S1 school rows: plan-only schools, lowest fulfillment first, flyout', (
    tester,
  ) async {
    await _standardSurface(tester);
    final service = InventoryAnalysisFixtureService();
    addTearDown(service.dispose);
    var openedPlan = 0;
    await _openAnalysis(tester, service, onOpenPlan: () => openedPlan += 1);

    expect(find.text('학교별 BD · 기술 노트 충족률'), findsOneWidget);
    // FD-100: 환산 칩 숨김.
    expect(find.text('계획 필요 환산량 기준'), findsNothing);
    // FD-099: 계획에 안 쓰는 붉은겨울은 행이 없다.
    expect(find.byKey(const ValueKey('inventory-school-RedWinter')), findsNothing);
    const order = ['Hyakkiyako', 'Shanhaijing', 'Gehenna', 'Trinity', 'Millennium', 'Abydos'];
    final tops = [
      for (final school in order)
        tester.getTopLeft(find.byKey(ValueKey('inventory-school-$school'))),
    ];
    for (var index = 1; index < tops.length; index++) {
      expect(tops[index].dy, greaterThan(tops[index - 1].dy), reason: order[index]);
      // 행은 사선을 따라 아래로 갈수록 왼쪽으로 간다.
      expect(tops[index].dx, lessThan(tops[index - 1].dx), reason: order[index]);
    }
    expect(_inside('inventory-school-Millennium-bd', '91%'), findsOneWidget);
    expect(_inside('inventory-school-Millennium-notes', '76%'), findsOneWidget);
    expect(_inside('inventory-school-Gehenna-bd', '81%'), findsOneWidget);
    expect(_inside('inventory-school-Gehenna-notes', '41%'), findsOneWidget);
    expect(_inside('inventory-school-Abydos-notes', '88%'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory-school-Millennium-shortage'))).data,
      '부족 상급 BD 외 1',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory-school-Gehenna-shortage'))).data,
      '부족 최상급 노트 외 1',
    );
    expect(_inside('inventory-school-Millennium', '계획 5명'), findsOneWidget);
    expect(_inside('inventory-school-Gehenna', '계획 7명'), findsOneWidget);
    expect(find.text('밀레니엄'), findsOneWidget);

    await _tap(tester, 'inventory-school-flyout-Millennium');
    expect(find.text('밀레니엄 · 계획 학생 5명'), findsOneWidget);
    // 부족 큰 순(유우카 BD 상급 9 · 노트 일반 20 → 노아 노트 4 → 나머지 이름순).
    final rows = [
      for (final id in const ['yuuka', 'noa', 'rio_battle', 'toki_battle', 'himari_battle'])
        find.byKey(ValueKey('inventory-school-Millennium-student-$id')),
    ];
    for (final row in rows) {
      expect(row, findsOneWidget);
    }
    for (var index = 1; index < rows.length; index++) {
      expect(
        tester.getTopLeft(rows[index]).dy,
        greaterThan(tester.getTopLeft(rows[index - 1]).dy),
      );
    }
    expect(find.descendant(of: rows[0], matching: find.text('상급 BD 9')), findsOneWidget);
    expect(find.descendant(of: rows[0], matching: find.text('일반 노트 20')), findsOneWidget);
    expect(find.descendant(of: rows[1], matching: find.text('—')), findsOneWidget);
    expect(find.descendant(of: rows[1], matching: find.text('일반 노트 4')), findsOneWidget);
    await tester.tap(find.text('계획에서 보기 →'));
    await tester.pumpAndSettle();
    expect(openedPlan, 1);

    // 7명은 5명 + "외 2명".
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await _tap(tester, 'inventory-school-flyout-Gehenna');
    expect(find.text('게헨나 · 계획 학생 7명'), findsOneWidget);
    expect(find.text('… 외 2명'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S2 scatter: series, bottleneck, tier toggles, expand enabled, point select', (
    tester,
  ) async {
    await _standardSurface(tester);
    final service = InventoryAnalysisFixtureService();
    addTearDown(service.dispose);
    final controller = await _openAnalysis(tester, service);

    expect(find.text('오파츠 · 보유율 × 수요'), findsOneWidget);
    expect(find.text('왼쪽 위 = 핵심 병목'), findsOneWidget);
    // FE6-d: "확장"이 켜지고 시안 aria-label을 가진다(확장 동작은 inventory_opa_page_test.dart).
    final expand = tester.widget<TonalButton>(
      find.byKey(const ValueKey('inventory-oopart-expand')),
    );
    expect(expand.onPressed, isNotNull);
    expect(expand.label, '확장');
    expect(expand.semanticLabel, '오파츠 패널 확장');
    var painter = _scatterPainter(tester);
    expect(painter.analysis.series, hasLength(8));
    expect(painter.analysis.series.first.label, '네브라 디스크');
    expect(painter.analysis.maxStudents, 7);
    final nebra = painter.analysis.series.first.points;
    expect(nebra.last.tier, 4);
    expect(nebra.last.bottleneck, isTrue); // 8% · 7명
    expect(nebra.first.bottleneck, isFalse); // 70%
    expect(painter.tiers, {1, 2, 3, 4});
    expect(painter.visiblePoints(), hasLength(32));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory-oopart-legend'))).data,
      '핵심 병목 · 선은 같은 오파츠',
    );

    await _tapSegment(tester, 'inventory-oopart-tier-4', 'T4');
    expect(controller.oopartTiers, {1, 2, 3});
    painter = _scatterPainter(tester);
    expect(painter.visiblePoints(), hasLength(24));
    await _tapSegment(tester, 'inventory-oopart-tier-4', 'T4');
    expect(_scatterPainter(tester).visiblePoints(), hasLength(32));

    // 점 위를 누르면(마우스 hover와 같은 hit) 말풍선이 뜨고, 그 오파츠를 고른다(FD-103). 고르기 전에는 선택 표시가 없다.
    expect(controller.oopartSelectionExplicit, isFalse);
    expect(_scatterPainter(tester).selectedFamily, isNull);
    final (point, center) = _scatterPainter(tester).visiblePoints().first;
    final frame = find.byKey(const ValueKey('inventory-oopart-scatter'));
    await tester.tapAt(tester.getTopLeft(frame) + center);
    await tester.pumpAndSettle();
    expect(
      find.text(
        '네브라 디스크 T${point.tier} · 보유율 ${(point.fulfillment * 100).round()}% · '
        '학생 ${point.students}명',
      ),
      findsOneWidget,
    );
    expect(controller.selectedOopartFamily, 'oopart:Nebra');
    expect(controller.oopartSelectionExplicit, isTrue);
    expect(_scatterPainter(tester).selectedFamily, 'oopart:Nebra');
    expect(tester.takeException(), isNull);
  });

  testWidgets('S4 heatmap: kinds, value chips, top shortages; S5 recent changes', (
    tester,
  ) async {
    await _standardSurface(tester);
    final service = InventoryAnalysisFixtureService();
    addTearDown(service.dispose);
    final controller = await _openAnalysis(tester, service);

    var painter = _heatmapPainter(tester);
    expect(painter.heatmap.kind, InventoryHeatmapKind.blueprint);
    expect(painter.heatmap.tiers, 10);
    expect(painter.heatmap.rows.map((row) => row.label), [
      '모자', '장갑', '신발', '가방', '배지', '헤어핀', '시계', '목걸이', '부적',
    ]);
    // 계획은 T5~T10, 목걸이 T9는 보유 모름.
    expect(painter.heatmap.rows.first.cells[0].planned, isFalse);
    expect(painter.heatmap.rows.first.cells[4].planned, isTrue);
    expect(painter.heatmap.rows[7].cells[8].coverage.fulfillment, isNull);
    expect(painter.value, InventoryHeatmapValue.fulfillment);
    expect(find.text('100% 충족'), findsOneWidget);

    expect(_inside('inventory-top-shortage-0', '시계 T8 설계도'), findsOneWidget);
    expect(_inside('inventory-top-shortage-0', '−36 · 학생 7명'), findsOneWidget);
    expect(_inside('inventory-top-shortage-1', '가방 T10 설계도'), findsOneWidget);
    expect(_inside('inventory-top-shortage-1', '−22 · 학생 2명'), findsOneWidget);
    expect(_inside('inventory-top-shortage-2', '헤어핀 T10 설계도'), findsOneWidget);
    expect(_inside('inventory-top-shortage-2', '−12 · 학생 1명'), findsOneWidget);

    await _tap(tester, 'inventory-heatmap-value-shortage');
    expect(controller.heatmapValue, InventoryHeatmapValue.shortage);
    expect(_heatmapPainter(tester).value, InventoryHeatmapValue.shortage);

    await _tapSegment(tester, 'inventory-heatmap-kind', 'BD');
    painter = _heatmapPainter(tester);
    expect(painter.heatmap.kind, InventoryHeatmapKind.bd);
    expect(painter.heatmap.tierLabel(3), '상급');
    expect(painter.heatmap.rows.map((row) => row.label), [
      '백귀야행', '트리니티', '게헨나', '아비도스', '밀레니엄', '산해경',
    ]);
    // 부족량 같은 26이면 학생 많은 게헨나(7명)가 트리니티(4명)보다 앞.
    expect(_inside('inventory-top-shortage-0', '백귀야행 BD (상급)'), findsOneWidget);
    expect(_inside('inventory-top-shortage-0', '−42 · 학생 3명'), findsOneWidget);
    expect(_inside('inventory-top-shortage-1', '게헨나 BD (상급)'), findsOneWidget);
    expect(_inside('inventory-top-shortage-2', '트리니티 BD (상급)'), findsOneWidget);

    // S5(FE6-f): 기간 순증감 상위(행 값은 inventory_history_page_test). seg를 바꾸면 캡션이 기간을 따른다.
    expect(find.text('최근 변화'), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-analysis-changes-empty')), findsNothing);
    expect(find.text('주간 순증감 상위 (오른쪽 증가 · 왼쪽 감소)'), findsOneWidget);
    await _tapSegment(tester, 'inventory-change-window', '4주');
    expect(controller.changeWindow, InventoryChangeWindow.week4);
    expect(find.text('4주 순증감 상위 (오른쪽 증가 · 왼쪽 감소)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list <-> analysis switches keep list state and raise no exception', (
    tester,
  ) async {
    await _standardSurface(tester);
    final service = InventoryFixtureService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    await _tap(tester, 'inventory-view-all');
    for (var round = 0; round < 2; round++) {
      await _tap(tester, 'inventory-mode-analysis');
      expect(find.byKey(const ValueKey('inventory-analysis-surfaces')), findsOneWidget);
      expect(find.byKey(const ValueKey('inventory-tiles-viewport')), findsNothing);
      await _tap(tester, 'inventory-mode-list');
      expect(find.byKey(const ValueKey('inventory-surfaces')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inventory-tile-Item_Icon_SkillBook_Gehenna_3')),
        findsOneWidget,
      );
    }
    await _tap(tester, 'inventory-view-shortage');
    await _tap(tester, 'inventory-mode-analysis');
    await _tap(tester, 'inventory-mode-list');
    expect(
      find.byKey(const ValueKey('inventory-row-Item_Icon_SecretStone_rio_battle')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a plan the analysis sections show the plan notice', (
    tester,
  ) async {
    await _standardSurface(tester);
    final service = InventoryFixtureService(plan: false);
    addTearDown(service.dispose);
    await _openAnalysis(tester, service);
    expect(find.byKey(const ValueKey('inventory-analysis-blocked')), findsOneWidget);
    expect(find.textContaining('저장된 계획이 없습니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-heatmap')), findsNothing);
    expect(find.byKey(const ValueKey('inventory-oopart-scatter')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // FE8-g5b: 스캔 후보는 인벤토리 탭으로 오지 않는다(스캔 탭 아이템 결과 검토 보드가 적용한다, I-scan §9.1). 예전 "새 후보가
  // 오면 후보 띠가 있는 목록 보기로 돌린다" 대신, 다시 그려도 분석 모드가 그대로이고 후보 띠 자리가 없는지 본다.
  testWidgets('scan candidates no longer reach the page: analysis stays', (
    tester,
  ) async {
    await _standardSurface(tester);
    final service = InventoryFixtureService();
    addTearDown(service.dispose);
    final controller = InventoryController(service);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_subject(service, controller: controller));
    await tester.pumpAndSettle();
    await _tap(tester, 'inventory-mode-analysis');
    await tester.pumpWidget(_subject(service, controller: controller));
    await tester.pumpAndSettle();
    expect(controller.screenMode, InventoryScreenMode.analysis);
    expect(find.byKey(const ValueKey('inventory-candidate-panel')), findsNothing);
    expect(find.byKey(const ValueKey('inventory-candidate-band')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analysis lays out at small windows without exceptions', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [Size(1280, 720), Size(1440, 900), Size(2560, 1392)]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      final service = InventoryAnalysisFixtureService();
      final controller = InventoryController(service);
      await tester.pumpWidget(_subject(service, controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inventory-mode-analysis')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventory-heatmap')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport $size');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await service.dispose();
    }
  });
}
