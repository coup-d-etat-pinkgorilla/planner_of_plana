// FE6-c golden: 인벤토리 분석(시안 Inventory-Analysis: 분석 모드 기본, 밀레니엄 "계획 n명" 플라이아웃 열림).
//
// 앱 셸 → 인벤토리 탭 → 사이드바 "분석" → 밀레니엄 행의 "계획 5명" 칩을 눌러 연다.
// 숫자는 FE6-c 검수 fixture(`test/inventory_fe6c_fixture.dart`)다. 게임 그림이 없는 아이콘·초상은 키트 규칙대로 빈 상자다.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 Lane A 소유라 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../inventory_fe6c_fixture.dart';
import 'golden_harness.dart';

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: 'golden navigation key $key');
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('inventory-analysis', (tester) async {
    setGoldenViewport(tester);
    final service = InventoryAnalysisFixtureService();
    addTearDown(service.dispose);

    await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'top-tab-inventory');
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('inventory-mode-analysis')),
    );
    await tester.pumpAndSettle();
    await _tapKey(tester, 'inventory-mode-analysis');
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('inventory-school-flyout-Millennium')),
    );
    await _tapKey(tester, 'inventory-school-flyout-Millennium');
    expect(find.text('밀레니엄 · 계획 학생 5명'), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-heatmap')), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-oopart-scatter')), findsOneWidget);
    await expectGoldenScene(tester, 'inventory-analysis');
  }, variant: goldenPlatform);
}
