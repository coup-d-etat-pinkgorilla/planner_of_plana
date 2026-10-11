// FE6-d 오파츠 확장 위젯 테스트(시안 Inventory-Analysis-Opa): 확장 시퀀스(퇴장 → morph → 상세), 축소(역순), 확장 전 점
// 선택이 상세에 이어짐, 상세 열 내용(티어별 보유 / 필요 · 사용 학생 플라이아웃 · 병목 순위 · 계획 이동), "축소" 의미 라벨,
// 애니메이션 중간(0.25 · 0.5 · 0.75)과 작은 창에서 예외 없음. 숫자는 `inventory_fe6d_fixture.dart`다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis_charts.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_controller.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:ba_planner_v7/ui/studio/inventory_studio_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6d_fixture.dart';

/// 확장 시퀀스 합계(퇴장 360 + morph 360 + 상세 220).
const _total = Duration(milliseconds: 940);

Widget _subject(
  AppService service, {
  required InventoryController controller,
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
  return controller;
}

InventoryOopartScatterPainter _scatter(WidgetTester tester) =>
    tester
            .widget<StatChartFrame>(
              find.byKey(const ValueKey('inventory-oopart-scatter')),
            )
            .painter
        as InventoryOopartScatterPainter;

/// 확장 때 빠지는 섹션 [id]의 지금 이동량.
Offset _exitOffset(WidgetTester tester, String id) {
  final transform = tester.widget<Transform>(
    find
        .descendant(
          of: find.byKey(ValueKey('inventory-opa-exit-$id')),
          matching: find.byType(Transform),
        )
        .first,
  );
  final translation = transform.transform.getTranslation();
  return Offset(translation.x, translation.y);
}

Finder _inside(String key, String text) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.text(text),
);

void main() {
  testWidgets('expand: sections exit by attachment face, S2 grows, detail appears; collapse reverses', (
    tester,
  ) async {
    await _surface(tester, const Size(2560, 1392));
    final service = InventoryOpaFixtureService();
    addTearDown(service.dispose);
    final controller = await _openAnalysis(tester, service);

    expect(find.byKey(const ValueKey('inventory-oopart-detail')), findsNothing);
    final expand = tester.widget<TonalButton>(
      find.byKey(const ValueKey('inventory-oopart-expand')),
    );
    expect(expand.label, '확장');
    expect(expand.semanticLabel, '오파츠 패널 확장');

    await tester.tap(find.byKey(const ValueKey('inventory-oopart-expand')));
    await tester.pump();
    expect(controller.oopartExpanded, isTrue);

    // 퇴장 구간 중간: 사이드바 180°(왼쪽) · S1 80°(위) · S4 0°(오른쪽) · S5 260°(아래).
    await tester.pump(const Duration(milliseconds: 180));
    final sidebar = _exitOffset(tester, inventorySidebarSectionId);
    final schools = _exitOffset(tester, inventoryAnalysisSchoolsSectionId);
    final tiers = _exitOffset(tester, inventoryAnalysisTiersSectionId);
    final changes = _exitOffset(tester, inventoryAnalysisChangesSectionId);
    expect(sidebar.dx, lessThan(0));
    expect(sidebar.dy.abs(), lessThan(1e-6));
    expect(schools.dy, lessThan(0));
    expect(schools.dx, greaterThan(0));
    expect(tiers.dx, greaterThan(0));
    expect(tiers.dy.abs(), lessThan(1e-6));
    expect(changes.dy, greaterThan(0));
    expect(changes.dx, lessThan(0));
    expect(tester.takeException(), isNull);

    // morph 구간 중간: 다른 섹션은 없고 산점도는 접힘과 확장 사이 크기, 점과 아이콘이 함께 보인다.
    await tester.pump(const Duration(milliseconds: 360));
    expect(find.byKey(const ValueKey('inventory-opa-exit-inventory-sidebar')), findsNothing);
    final midSize = tester.getSize(find.byKey(const ValueKey('inventory-oopart-scatter')));
    expect(midSize.width, greaterThan(1012));
    expect(midSize.width, lessThan(1974));
    final midIcons = _scatter(tester).icons;
    expect(midIcons, greaterThan(0));
    expect(midIcons, lessThan(1));
    expect(find.byKey(const ValueKey('inventory-oopart-detail')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    // 확장 완료: S2 하나 + 상세 열. 사이드바 · S1 · S4 · S5 내용은 없다.
    expect(find.byKey(const ValueKey('inventory-mode-analysis')), findsNothing);
    expect(find.text('종류 × 티어 충족률'), findsNothing);
    expect(find.text('최근 변화'), findsNothing);
    expect(find.byKey(const ValueKey('inventory-oopart-detail')), findsOneWidget);
    final size = tester.getSize(find.byKey(const ValueKey('inventory-oopart-scatter')));
    expect(size.width, closeTo(1974, 0.01));
    expect(size.height, closeTo(1034.8, 0.01));
    final painter = _scatter(tester);
    expect(painter.icons, 1);
    expect(painter.selectedFamily, isNull); // 기본 선택은 표시하지 않는다(시안)
    expect(painter.iconSlots(), hasLength(32));
    expect(find.byKey(const ValueKey('inventory-oopart-icon-Item_Icon_Material_Nebra_3')), findsOneWidget);
    // 아이콘 id가 없는 오파츠는 이름 앞 두 글자(시안 "아우").
    expect(
      find.byKey(const ValueKey('inventory-oopart-initials-Item_Icon_Material_AurumCoin_0')),
      findsOneWidget,
    );
    expect(_inside('inventory-oopart-icon-Item_Icon_Material_AurumCoin_0', '아우'), findsOneWidget);
    final collapse = tester.widget<TonalButton>(
      find.byKey(const ValueKey('inventory-oopart-expand')),
    );
    expect(collapse.label, '축소');
    expect(collapse.semanticLabel, '오파츠 패널 축소');

    // 축소: 역순(상세가 먼저 사라지고, morph, 마지막에 섹션이 돌아온다).
    await tester.tap(find.byKey(const ValueKey('inventory-oopart-expand')));
    await tester.pump();
    expect(controller.oopartExpanded, isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('inventory-oopart-detail')), findsNothing);
    expect(find.byKey(const ValueKey('inventory-opa-exit-inventory-sidebar')), findsNothing);
    await tester.pump(const Duration(milliseconds: 460));
    final back = _exitOffset(tester, inventorySidebarSectionId);
    expect(back.dx, lessThan(0)); // 왼쪽에서 돌아오는 중
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inventory-mode-analysis')), findsOneWidget);
    expect(find.text('종류 × 티어 충족률'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('inventory-oopart-scatter'))).width,
      closeTo(1012, 0.01),
    );
    expect(_scatter(tester).icons, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail column: tiers, students flyout, bottleneck ranking, plan link', (
    tester,
  ) async {
    await _surface(tester, const Size(2560, 1392));
    final service = InventoryOpaFixtureService();
    addTearDown(service.dispose);
    var openedPlan = 0;
    final controller = await _openAnalysis(
      tester,
      service,
      onOpenPlan: () => openedPlan++,
    );
    await _tap(tester, 'inventory-oopart-expand');

    // 기본 선택 = 병목 순위 1위(네브라 디스크).
    expect(controller.selectedOopartFamily, 'oopart:Nebra');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory-oopart-detail-name'))).data,
      '네브라 디스크',
    );
    expect(find.text('선택한 오파츠'), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-oopart-detail-bottleneck')), findsOneWidget);
    expect(find.text('티어별 보유 / 필요 (계획 요구량)'), findsOneWidget);
    const statuses = {1: '충분', 2: '충분', 3: '−37', 4: '−46'};
    for (final entry in statuses.entries) {
      expect(
        tester
            .widget<Text>(
              find.byKey(ValueKey('inventory-oopart-detail-tier-${entry.key}-status')),
            )
            .data,
        entry.value,
      );
    }
    expect(_inside('inventory-oopart-detail-tier-1', '보유 210 / 필요 180'), findsOneWidget);
    expect(_inside('inventory-oopart-detail-tier-4', '보유 12 / 필요 58'), findsOneWidget);

    // 병목 순위: 시안 −46 · −31 · −22 · −18 · −9.
    const ranks = [
      ('네브라 디스크', 'T4', '−46'),
      ('로혼치 사본', 'T4', '−31'),
      ('파에스토스 원반', 'T3', '−22'),
      ('안티키테라 장치', 'T4', '−18'),
      ('토리노 수의', 'T3', '−9'),
    ];
    for (final (index, (name, tier, value)) in ranks.indexed) {
      for (final text in [name, tier, value, '${index + 1}']) {
        expect(_inside('inventory-oopart-rank-$index', text), findsOneWidget, reason: text);
      }
    }
    expect(find.byKey(const ValueKey('inventory-oopart-rank-5')), findsNothing);

    // 사용 학생 플라이아웃(FD-101): 6명, 학생별 T4 · T3 부족.
    await _tap(tester, 'inventory-oopart-students-flyout');
    expect(find.text('네브라 디스크 · 사용 학생 6명'), findsOneWidget);
    expect(find.text('부족한 티어별 필요량'), findsOneWidget);
    const rio = 'inventory-oopart-student-rio_battle';
    expect(_inside(rio, '리오(무장)'), findsOneWidget);
    expect(_inside(rio, 'T4 12'), findsOneWidget);
    expect(_inside(rio, 'T3 8'), findsOneWidget);
    expect(_inside('inventory-oopart-student-kurumi', 'T4 8'), findsOneWidget);
    expect(_inside('inventory-oopart-student-aru', 'T3 12'), findsOneWidget);
    final rows = [
      for (final id in const ['rio_battle', 'toki_battle', 'kurumi', 'mika', 'hoshino', 'aru'])
        find.byKey(ValueKey('inventory-oopart-student-$id')),
    ];
    for (var index = 1; index < rows.length; index++) {
      expect(
        tester.getTopLeft(rows[index]).dy,
        greaterThan(tester.getTopLeft(rows[index - 1]).dy),
      );
    }
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // 병목 순위 행을 누르면 그 오파츠를 고른다(고른 오파츠는 산점도에 표시).
    await _tap(tester, 'inventory-oopart-rank-1');
    expect(controller.selectedOopartFamily, 'oopart:Rohonc');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory-oopart-detail-name'))).data,
      '로혼치 사본',
    );
    expect(_scatter(tester).selectedFamily, 'oopart:Rohonc');

    // 계획에서 쓰는 단계 보기 → 계획 탭 이동만.
    await _tap(tester, 'inventory-oopart-open-plan');
    expect(openedPlan, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a point picked before expanding stays selected in the detail column', (
    tester,
  ) async {
    await _surface(tester, const Size(2560, 1392));
    final service = InventoryOpaFixtureService();
    addTearDown(service.dispose);
    final controller = await _openAnalysis(tester, service);

    final (point, center) = _scatter(tester).visiblePoints().firstWhere(
      (entry) =>
          entry.$1.view.item.family == 'oopart:Antikythera' && entry.$1.tier == 4,
    );
    final frame = find.byKey(const ValueKey('inventory-oopart-scatter'));
    await tester.tapAt(tester.getTopLeft(frame) + center);
    await tester.pumpAndSettle();
    expect(point.view.item.family, 'oopart:Antikythera');
    expect(controller.selectedOopartFamily, 'oopart:Antikythera');
    expect(_scatter(tester).selectedFamily, 'oopart:Antikythera');

    await _tap(tester, 'inventory-oopart-expand');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('inventory-oopart-detail-name'))).data,
      '안티키테라 장치',
    );
    expect(find.byKey(const ValueKey('inventory-oopart-detail-bottleneck')), findsNothing);
    // 고른 오파츠는 순위 4위 행이 굵게(나머지 일반).
    expect(_scatter(tester).selectedFamily, 'oopart:Antikythera');

    // 확장 산점도에서도 점을 고를 수 있다.
    final (_, nebra) = _scatter(tester).visiblePoints().firstWhere(
      (entry) => entry.$1.view.item.family == 'oopart:Nebra' && entry.$1.tier == 4,
    );
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('inventory-oopart-scatter'))) + nebra,
    );
    await tester.pumpAndSettle();
    expect(controller.selectedOopartFamily, 'oopart:Nebra');

    // 목록으로 가면 접힌다(탭 안 로컬 상태).
    controller.setScreenMode(InventoryScreenMode.list);
    await tester.pumpAndSettle();
    expect(controller.oopartExpanded, isFalse);
    controller.setScreenMode(InventoryScreenMode.analysis);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inventory-oopart-detail')), findsNothing);
    expect(
      tester.widget<TonalButton>(find.byKey(const ValueKey('inventory-oopart-expand'))).label,
      '확장',
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(2560, 1392), Size(1280, 720)]) {
    testWidgets('no overflow at 0.25 · 0.5 · 0.75 of the sequence ($size)', (
      tester,
    ) async {
      await _surface(tester, size);
      final service = InventoryOpaFixtureService();
      addTearDown(service.dispose);
      await _openAnalysis(tester, service);

      await tester.tap(find.byKey(const ValueKey('inventory-oopart-expand')));
      await tester.pump();
      for (var step = 0; step < 3; step++) {
        await tester.pump(_total ~/ 4);
        expect(tester.takeException(), isNull, reason: 'expand ${step + 1}/4');
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventory-oopart-detail')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('inventory-oopart-expand')));
      await tester.pump();
      for (var step = 0; step < 3; step++) {
        await tester.pump(_total ~/ 4);
        expect(tester.takeException(), isNull, reason: 'collapse ${step + 1}/4');
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inventory-mode-analysis')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('expand is refused while the tiers screen is open and folds when it opens', (
    tester,
  ) async {
    await _surface(tester, const Size(2560, 1392));
    final service = InventoryOpaFixtureService();
    addTearDown(service.dispose);
    final controller = await _openAnalysis(tester, service);

    await _tap(tester, 'inventory-analysis-open-tiers');
    controller.setOopartExpanded(true);
    expect(controller.oopartExpanded, isFalse);
    await _tap(tester, 'inventory-analysis-open-tiers');
    controller.setOopartExpanded(true);
    await tester.pumpAndSettle();
    expect(controller.oopartExpanded, isTrue);
    // 확장 중에 티어 화면을 열면(코드 경로) 접힌다.
    controller.toggleTiers();
    expect(controller.oopartExpanded, isFalse);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
