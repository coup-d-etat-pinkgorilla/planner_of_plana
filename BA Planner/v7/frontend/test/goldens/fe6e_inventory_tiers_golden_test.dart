// FE6-e golden: 인벤토리 티어별 충족률(시안 Inventory-Tiers: 분석 사이드바 "티어별 충족률" 선택, 칩은 모두 충족률).
//
// 앱 셸 → 인벤토리 탭 → 사이드바 "분석" → "따로 여는 화면 → 티어별 충족률"(섹션 교체 모션이 끝날 때까지 기다린다).
// 숫자는 FE6-e 검수 fixture(`test/inventory_fe6e_fixture.dart`)다. 게임 그림이 없는 아이콘 · 엠블럼은 키트 규칙대로 빈
// 상자 · 이름 글자다. 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 Lane A 소유라 고치지 않는다).
//
// PNG 생성(CF, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                   .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../inventory_fe6e_fixture.dart';
import 'golden_harness.dart';

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: 'golden navigation key $key');
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('inventory-tiers', (tester) async {
    setGoldenViewport(tester);
    final service = InventoryTiersFixtureService();
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
      find.byKey(const ValueKey('inventory-analysis-open-tiers')),
    );
    await _tapKey(tester, 'inventory-analysis-open-tiers');
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('inventory-tiers-heatmap-notes')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inventory-tiers-surfaces')), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-tiers-heatmap-bd')), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory-tiers-heatmap-oopart')), findsOneWidget);
    expect(find.text('오파츠 · 네브라 디스크 T3'), findsOneWidget);
    await expectGoldenScene(tester, 'inventory-tiers');
  }, variant: goldenPlatform);
}
