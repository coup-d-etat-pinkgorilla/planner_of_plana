// F3c-10 golden: 튜토리얼 비교 밝히기(앱 셸 위, Mock 임시 계정 — 움직임 줄이기로 대사 띠 · 숨쉬기를 멈춘다).
//
// - `tutorial-compare-reveal`: 프라나 09d 대사 2 / 3 — 나란히 비교 화면(A 활성 계획 · B '총력전 비나 대비' · C '비나 대비 ·
//   한 번에 MAX')이 검정 64%로 어둡고, 열 B · C만 **사선 판 모양 그대로** 밝다. 두 열의 바깥 사각형은 서로 겹치지만 구멍은
//   두 열 모양의 합이라 B · C 사이 틈(사선 판 밖)은 어둡고 겹친 곳이 다시 어두워지지 않는다. 하늘색 테두리는 합의 외곽을 한
//   번 따라간다(사각형 테두리 · 이웃 열을 가르는 세로선 없음). 아래 대사 띠 '튜토리얼 · 비교 · 대사 2 / 3', 대사 "마키 씨를
//   두 단계로 나누고 …". C열 오른쪽 변의 분홍 사선은 비교 본문의 사선 스크롤바 썸(#e5a0ea)이다(강조 잔상 아님).
// 1~3 · 7-1 · 7-2 · 7-2c 추가 · 7-6 · 8은 실제 누르기, 4 · 5 · 6 · 7-3 ~ 7-5는 hooks 출구(이 장면의 대상은 비교 밝히기),
// 스킬 값은 편집기로 간다. 서비스는 시각을 고정한 Mock. 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는
// 고치지 않는다).
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
@Tags(['golden'])
library;

import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/tutorial/plana_dialogue.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_flow.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_session.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_goal_step.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// 고정 시각(스캔 진행 · 앱 시계가 실행 시각에 따라 바뀌지 않게).
final _now = DateTime.utc(2026, 10, 5, 3);

/// 시나리오 수정 시각(비교 열 머리)은 [GoldenMockAppService]가 고정한다.
class _TutorialGoldenService extends GoldenMockAppService
    implements AppClockSource {
  @override
  DateTime get clockNow => _now;
}

/// [count] × 100ms를 10ms씩(움직임 줄이기의 짧은 탭 전환 중간 시점을 지나치지 않게).
Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var index = 0; index < count * 10; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// 대사 장면들을 넘겨 다음 단계 카드까지.
Future<void> _toStep(
  WidgetTester tester,
  TutorialSession session,
  String stepId,
) async {
  while (session.flow!.phase == TutorialPhase.dialogue) {
    final index = session.flow!.flowIndex;
    while (session.flow?.phase == TutorialPhase.dialogue &&
        session.flow?.flowIndex == index) {
      session.flow!.advanceLine();
      await tester.pump();
    }
    await _frames(tester);
  }
  await _frames(tester, 4);
  expect(session.flow!.step!.id, stepId);
}

/// 단계 완료 체크까지 짧게 넘기고 다음 칸으로.
Future<void> _waitDone(WidgetTester tester, TutorialSession session) async {
  for (
    var round = 0;
    round < 200 && session.flow!.phase == TutorialPhase.step;
    round++
  ) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pump();
  expect(session.flow!.phase, TutorialPhase.stepComplete);
  for (
    var round = 0;
    round < 200 && session.flow!.phase == TutorialPhase.stepComplete;
    round++
  ) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await _frames(tester);
}

Future<void> _setSkills(
  WidgetTester tester,
  String stageId,
  List<int> values,
) async {
  final editor = tester
      .widget<PlanFlowGoalBody>(find.byType(PlanFlowGoalBody))
      .editor;
  for (final (index, key) in const [
    'ex_skill',
    'skill1',
    'skill2',
    'skill3',
  ].indexed) {
    editor.setTarget(stageId, key, values[index]);
    await tester.pump();
  }
}

void main() {
  setUpAll(loadGoldenFonts);

  testWidgets('tutorial-compare-reveal', (tester) async {
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
        BAPlannerApp(
          service: service,
          tutorial: true,
          tutorialSession: session,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final origin = (await service.listProfiles()).singleWhere(
      (profile) => profile.selected,
    );
    final hooks = session.hooks;
    unawaited(session.start(origin));
    await _frames(tester, 4);

    // 1 · 2 · 3: 가상 창 연결 → 학생 전체 스캔 → 바뀐 6명 적용.
    await _toStep(tester, session, '1');
    await tester.tap(
      find.byKey(
        const ValueKey('home-connect-panel-row-$practiceVirtualTargetId'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
    await _waitDone(tester, session);
    await _toStep(tester, session, '2');
    session.scanSession.value!.now = () => _now;
    await tester.tap(find.byKey(const ValueKey('scan-pick-student-full')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
    await _waitDone(tester, session);
    await _toStep(tester, session, '3');
    await tester.tap(find.byKey(const ValueKey('scan-review-bulk-apply')));
    await _waitDone(tester, session);

    // 4 · 5 · 6: hooks 출구.
    await _toStep(tester, session, '4');
    hooks.signals.emit(TutorialSignals.studentCalculatorTargetChanged);
    await _waitDone(tester, session);
    await _toStep(tester, session, '5');
    hooks.signals.emit(TutorialSignals.scanItemStarted);
    hooks.signals.emit(TutorialSignals.scanItemFinished);
    await _waitDone(tester, session);
    await _toStep(tester, session, '6');
    hooks.signals.emit(TutorialSignals.itemReviewApplied);
    await _waitDone(tester, session);

    // 7-1 · 7-2(① 한 번에 MAX → ② 7명 모두) · 7-2b · 7-2c.
    await _toStep(tester, session, '7-1');
    await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
    await _waitDone(tester, session);
    await _toStep(tester, session, '7-2');
    await tester.tap(find.byKey(const ValueKey('plan-flow-goal-mode-max')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-flow-goal-apply-all')));
    await _waitDone(tester, session);
    await _toStep(tester, session, '7-2b');
    final editor = tester
        .widget<PlanFlowGoalBody>(find.byType(PlanFlowGoalBody))
        .editor;
    final flow = tester
        .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
        .flow;
    await _setSkills(
      tester,
      flow.draft.stages.firstWhere((stage) => stage.studentId == 'maki').id,
      [5, 10, 1, 1],
    );
    await _waitDone(tester, session);
    await tester.tap(find.byKey(const ValueKey('plan-flow-goal-add-stage')));
    await tester.pump();
    await _setSkills(tester, editor.stagesOf('maki').last.id, [5, 10, 7, 7]);
    await _waitDone(tester, session);

    // 7-3 ~ 7-5: hooks 출구, 7-6 · 8: 실제.
    for (final (step, signal) in const [
      ('7-3', TutorialSignals.planRanksPlaced),
      ('7-4', TutorialSignals.planKannaAkaneLinked),
      ('7-5', TutorialSignals.planLaterMoved),
    ]) {
      await _toStep(tester, session, step);
      hooks.signals.emit(signal);
      await _waitDone(tester, session);
    }
    await _toStep(tester, session, '7-6');
    await tester.tap(find.byKey(const ValueKey('plan-flow-save-confirm')));
    await _waitDone(tester, session);
    await _toStep(tester, session, '8');
    await tester.tap(find.byKey(const ValueKey('plan-scenario-compare-run')));
    await _waitDone(tester, session);

    // 프라나 09d 대사 2: 열 B · C 밝히기.
    expect(session.flow!.scene!.id, 'plana-09d');
    session.flow!.advanceLine();
    await _frames(tester, 4);
    expect(find.text('튜토리얼 · 비교 · 대사 2 / 3'), findsOneWidget);
    expect(
      tester
          .widget<PlanaDialogueOverlay>(find.byType(PlanaDialogueOverlay))
          .reveals,
      hasLength(2),
    );
    await expectGoldenScene(tester, 'tutorial-compare-reveal');
  }, variant: goldenPlatform);
}
