// FE8-f3 golden: 홈 스캔 팝업(시안 Home-Connected-Scan — 연결됨, 스캔 팝업 열림).
//
// 홈 창 선택 패널로 Mock 창을 연결해 메뉴가 연결 메뉴(첫 버튼 `스캔`)로 안착한 뒤 `스캔`을 눌러 팝업을 연다. 타일 그림은
// 연 횟수(첫 번째 = 씨앗 1)로 고르므로 같은 그림이다. 머리글은 스크림 위에 그대로 보인다.
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다.
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('home-scan-popup', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenMockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('home-connect-panel-row-mock-window')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-scan-popup')), findsOneWidget);
    await expectGoldenScene(tester, 'home-scan-popup');
  }, variant: goldenPlatform);
}
