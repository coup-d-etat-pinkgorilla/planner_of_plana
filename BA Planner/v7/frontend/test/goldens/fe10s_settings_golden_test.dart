// FE10-s golden: 새 스타일 설정 탭(FD-179 (a) — 시안 없음, 옛 카드 내용 · 순서 그대로 사선 섹션 · 키트로 다시 그림).
//
// 앱 셸 → 설정 탭. Mock 기본값 그대로: 연결됨, 계정 `Main`(현재 적용) 1개, 인식 asset 준비됨, 감지된 대상
// `Mock Blue Archive`(ready · foreground) 1개, process 진단(protocol 1 · generation 1 · mock-python, lifecycle 1건).
// - `settings`: 위 머리 띠(`SETTINGS / RECOVERY` · 분홍 막대 + `프로필과 연결` · `Main · connected` · 새로고침), 아래 2×2 섹션
//   (프로필 · Backend 연결 / Scanner 준비 상태 · 고급 진단)이 하나의 80° 사선으로 맞물린다. 프로필 행은 분홍 레일 선택 행 +
//   `현재 적용` 칩, 버튼은 각 섹션 아래 줄(`새 프로필` 분홍 · 나머지 tonal · ghost).
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지 않는다).
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

  testWidgets('settings', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenMockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
    await tester.pumpAndSettle();
    final tab = find.byKey(const ValueKey('top-tab-settings'));
    expect(
      tab,
      findsOneWidget,
      reason: 'golden navigation key top-tab-settings',
    );
    await tester.tap(tab);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Mock Blue Archive'));
    expect(
      find.byKey(const ValueKey('settings-header-surface')),
      findsOneWidget,
    );
    for (final id in const [
      'settings-profiles',
      'settings-backend',
      'settings-scanner',
      'settings-diagnostics',
    ]) {
      expect(find.byKey(ValueKey('$id-surface')), findsOneWidget);
    }
    expect(find.text('현재 적용'), findsOneWidget);
    expect(find.text('인식 asset 준비됨'), findsOneWidget);
    await expectGoldenScene(tester, 'settings');
  }, variant: goldenPlatform);
}
