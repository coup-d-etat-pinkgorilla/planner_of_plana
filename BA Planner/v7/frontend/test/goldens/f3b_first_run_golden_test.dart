// F3b golden: 첫 실행 ①~③ 모달(시안 FirstRun-1-Game · FirstRun-2-Images · FirstRun-3-Account).
//
// 계정이 없는 Mock(새 설치) 타이틀에 첫 실행을 켜고(`FirstRunLaunch.auto`) 기준 viewport 2560×1392에서 찍는다.
// - first-run-game: ① 자동으로 찾음(Mock 합성 경로).
// - first-run-images: ② 스캔용 그림 단계(번들 1, total null — 분모 · % 숨김, 막대 빗금). Mock 단계 간격을 1시간으로 두고
//   그 단계까지만 시계를 넘긴다(장면이 흔들리지 않게). 끝에 서비스를 닫아 남은 타이머를 지운다.
// - first-run-account: ③ 계정 이름 `메인 계정`(입력 포커스 — 커서 깜박임을 끈다).
// 공용 도구는 golden_harness.dart의 공개 함수만 쓴다.
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/first_run/first_run_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

const _hour = Duration(hours: 1);

Future<MockAppService> _openFirstRun(
  WidgetTester tester, {
  Duration step = _hour,
}) async {
  setGoldenViewport(tester);
  EditableText.debugDeterministicCursor = true;
  addTearDown(() => EditableText.debugDeterministicCursor = false);
  final service = MockAppService(
    profiles: const [],
    assetPreparationStep: step,
  );
  await tester.pumpWidget(
    goldenBoundary(
      BAPlannerApp(
        service: service,
        showTitle: true,
        firstRun: FirstRunLaunch.auto,
      ),
    ),
  );
  await pumpUntilFound(tester, find.byKey(const ValueKey('first-run-game')));
  await finishStudentGridWarmup(tester, service);
  await tester.pumpAndSettle();
  return service;
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('first-run-game', (tester) async {
    final service = await _openFirstRun(tester);
    addTearDown(service.dispose);
    expect(find.text('찾음 · Steam'), findsOneWidget);
    await expectGoldenScene(tester, 'first-run-game');
  }, variant: goldenPlatform);

  testWidgets('first-run-images', (tester) async {
    final service = await _openFirstRun(tester);
    await tester.tap(find.byKey(const ValueKey('first-run-next')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('first-run-images')),
    );
    // validating → icons 0/2 → icons 2/2 → sprites 1/null.
    for (var step = 0; step < 4; step++) {
      await tester.pump(_hour);
    }
    await tester.pump();
    expect(find.text('개 번들'), findsOneWidget);
    expect(find.text('전체 수를 아직 모름 · 스캔용 그림을 만드는 중'), findsOneWidget);
    await expectGoldenScene(tester, 'first-run-images');
    // 남은 Mock 단계 타이머를 지운다(시험 끝 타이머 검사).
    await service.dispose();
  }, variant: goldenPlatform);

  testWidgets('first-run-account', (tester) async {
    final service = await _openFirstRun(
      tester,
      step: const Duration(milliseconds: 10),
    );
    addTearDown(service.dispose);
    await tester.tap(find.byKey(const ValueKey('first-run-next')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('first-run-images')),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('first-run-next')));
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('first-run-account')),
    );
    await tester.pumpAndSettle();
    expect(find.text('만들고 튜토리얼 시작'), findsOneWidget);
    await expectGoldenScene(tester, 'first-run-account');
  }, variant: goldenPlatform);
}
