// F3c-3 golden: 튜토리얼 장면 2(앱 셸 위, Mock 임시 계정 — 움직임 줄이기로 대사 띠 · 도는 표시를 멈춘다).
//
// - `tutorial-step-scan`: 2단계 카드(학생 가상 스캔 — 진행 칸 하늘 1 · 분홍 1, 하위 체크 스캔 탭 열기 ✓ · 학생 전체 고르기 ·
//   스캔 시작)가 스캔 탭 고르기 화면 위, '학생 전체 스캔 시작' 버튼 둘레 하늘색 강조 테두리, 머리글 '스캔' 옆 칩
//   '튜토리얼 · 임시 계정', 머리글 연결 칩은 '가상 게임 창 · 튜토리얼'.
// - `tutorial-dialogue-review`: 프라나 04 대사 2(확인 필요 2명)가 학생 결과 검토 위 — 검정 막, '확인 필요' 묶음에 밝히기
//   구멍 + 하늘 테두리, 아래 대사 띠('튜토리얼 · 학생 검토 · 대사 2 / 5', 글자 전부).
// 서비스는 시각을 고정한 Mock(임시 계정 이력 '어제 …'가 실행 날짜와 상관없게). 공용 도구는 golden_harness.dart의 공개 함수만
// 쓴다(harness는 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_flow.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// 고정 시각(임시 계정 지난 스캔 '어제 …' · 진행 시각이 실행 시각에 따라 바뀌지 않게).
final _now = DateTime.utc(2026, 10, 5, 3);

class _TutorialGoldenService extends MockAppService implements AppClockSource {
  _TutorialGoldenService() : super(historyClock: () => _now);

  @override
  DateTime get clockNow => _now;
}

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 지금 장면만 끝까지 넘긴다.
Future<void> _finishScene(WidgetTester tester, TutorialSession session) async {
  final index = session.flow!.flowIndex;
  while (session.flow?.phase == TutorialPhase.dialogue &&
      session.flow?.flowIndex == index) {
    session.flow!.advanceLine();
    await tester.pump();
  }
  await _frames(tester);
}

/// 셸 · 튜토리얼을 띄우고 2단계(학생 가상 스캔) 카드까지 간다.
Future<TutorialSession> _toStudentScanStep(WidgetTester tester) async {
  setGoldenViewport(tester);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final service = _TutorialGoldenService();
  addTearDown(service.dispose);
  final session = TutorialSession(
    service: service,
    completeHold: const Duration(milliseconds: 60),
  );
  addTearDown(session.dispose);
  await tester.pumpWidget(
    goldenBoundary(
      BAPlannerApp(service: service, tutorial: true, tutorialSession: session),
    ),
  );
  await tester.pumpAndSettle();
  final origin = (await service.listProfiles()).singleWhere(
    (profile) => profile.selected,
  );
  unawaited(session.start(origin));
  await _frames(tester, 4);
  await _finishScene(tester, session); // 프라나 01
  await _finishScene(tester, session); // 프라나 02
  await tester.tap(
    find.byKey(
      const ValueKey('home-connect-panel-row-$practiceVirtualTargetId'),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  await _frames(tester);
  await _finishScene(tester, session); // 프라나 03
  expect(session.flow!.step!.id, '2');
  return session;
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('tutorial-step-scan', (tester) async {
    final session = await _toStudentScanStep(tester);
    expect(find.text("'학생 전체 스캔 시작'을 눌러 주십시오."), findsOneWidget);
    expect(find.text('튜토리얼 · 임시 계정'), findsOneWidget);
    expect(session.flow!.highlightKey, isNotNull);
    await expectGoldenScene(tester, 'tutorial-step-scan');
  }, variant: goldenPlatform);

  testWidgets('tutorial-dialogue-review', (tester) async {
    final session = await _toStudentScanStep(tester);
    // 진행 · 검토 머리의 스캔 시각도 고정한다(컨트롤러 기본은 기기 시계).
    session.scanSession.value!.now = () => _now;
    await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
    for (
      var round = 0;
      round < 200 && session.flow!.phase == TutorialPhase.step;
      round++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 150));
    await _frames(tester);
    expect(session.flow!.scene!.id, 'plana-04');
    session.flow!.advanceLine();
    await _frames(tester, 4);
    expect(find.text('튜토리얼 · 학생 검토 · 대사 2 / 5'), findsOneWidget);
    await expectGoldenScene(tester, 'tutorial-dialogue-review');
  }, variant: goldenPlatform);
}
