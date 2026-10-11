// FE6-d golden: 인벤토리 분석 오파츠 확장 완료(시안 Inventory-Analysis-Opa: S2만 남아 확장, 선택 오파츠 상세 열).
//
// 앱 셸 → 인벤토리 탭 → 사이드바 "분석" → S2 "확장"을 누르고 시퀀스(퇴장 → morph → 상세)가 끝날 때까지 기다린다.
// 숫자는 FE6-d 검수 fixture(`test/inventory_fe6d_fixture.dart`)다. 기본 선택은 병목 순위 1위(네브라 디스크)다.
// 게임 그림이 없는 아이콘·초상은 키트 규칙대로 빈 상자, 아이콘 id가 없는 오파츠 점은 이름 앞 두 글자다.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../inventory_fe6d_fixture.dart';
import 'golden_harness.dart';

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: 'golden navigation key $key');
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('inventory-analysis-opa', (tester) async {
    setGoldenViewport(tester);
    final service = InventoryOpaFixtureService();
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
      find.byKey(const ValueKey('inventory-oopart-scatter')),
    );
    await _tapKey(tester, 'inventory-oopart-expand');
    expect(find.byKey(const ValueKey('inventory-oopart-detail')), findsOneWidget);
    expect(find.text('네브라 디스크 · 사용 학생 6명'), findsNothing);
    expect(find.byKey(const ValueKey('inventory-mode-analysis')), findsNothing);
    await expectGoldenScene(tester, 'inventory-analysis-opa');
  }, variant: goldenPlatform);
}
