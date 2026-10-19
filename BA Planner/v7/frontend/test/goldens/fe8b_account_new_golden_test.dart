// FE8-b golden: 계정 추가 모달(시안 Title-Accounts-New).
//
// 타이틀 → 설정(계정 관리) → "추가"로 연 모달을 기준 viewport 2560×1392에서 찍는다. 이름 입력에 포커스가
// 있으므로 커서 깜박임을 끈다(`EditableText.debugDeterministicCursor`, 테스트 뒤 되돌린다).
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

  testWidgets('account-new', (tester) async {
    setGoldenViewport(tester);
    EditableText.debugDeterministicCursor = true;
    addTearDown(() => EditableText.debugDeterministicCursor = false);
    final service = GoldenMockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      goldenBoundary(BAPlannerApp(service: service, showTitle: true)),
    );
    await pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
    await tester.pumpAndSettle();
    await finishStudentGridWarmup(tester, service);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('title-settings')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('account-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-add')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('account-create-modal')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('account-create-name-input')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'account-new');
  }, variant: goldenPlatform);
}
