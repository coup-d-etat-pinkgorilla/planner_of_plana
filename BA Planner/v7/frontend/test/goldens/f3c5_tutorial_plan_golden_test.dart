// F3c-5 golden: 튜토리얼 계획 장면 1(앱 셸 위, Mock 임시 계정 — 움직임 줄이기로 대사 띠 · 도는 표시를 멈춘다).
//
// - `tutorial-plan-order`: 7-3 카드(계획 만들기 · 7 / 10, "카드를 끌어 칸나(수영복) · 마키 · 미카는 1순위, …" 두 줄, why,
//   하위 체크 ○ 1 · 2순위에 놓기 · 아카네 3순위 · 칸나와 잇기 · 네루 · 마키 2단계 나중에)가 계획 만들기 3단계(단계 순서
//   칸 보드 — 대본 7명 · 마키 2단계, 아직 놓지 않은 카드) 위, '아카네' 카드 둘레 하늘색 강조 테두리, 머리글 '계획' 옆 칩
//   '튜토리얼 · 임시 계정'. 왼쪽 레일은 4단계 진행(1 · 2 완료, 3 지금).
//   F3c-6: 튜토리얼 보드는 칸 3개(1 · 2 · 3순위, 3순위는 빈 칸)로 시작하고(사용자 결정 ⑥), 카드는 보드 카드 · 순위 칸을
//   피한 자리(카드 자리 규칙 7 — 빈자리가 없으면 가장 적게 겹치는 자리)에 놓인다.
// 1~3단계는 실제 화면 동작(가상 창 연결 · 학생 스캔 · 적용), 4단계는 hooks 출구, 5단계는 실제 누르기(F3c-8 — 아이템
// 2종 고르기 → 시작 → 끝, Windows 변형도 가상 대상은 진행 창 없이 끝난다: F3c-7), 6단계는 승인 hooks 출구 · '적용' 실제
// 누르기(한 바퀴 시험과 같음 — 적용하지 않으면 머리글 '스캔' 옆 검토 대기 점이 남는다), 7-1 · 7-2 · 7-2c 추가는 실제 누르기,
// 스킬 값은 편집기로 간다. 서비스는 시각을 고정한 Mock. 공용 도구는 golden_harness.dart의 공개 함수만 쓴다(harness는 고치지
// 않는다).
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
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_session.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_goal_step.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// 고정 시각(임시 계정 지난 스캔 · 진행 시각이 실행 시각에 따라 바뀌지 않게).
final _now = DateTime.utc(2026, 10, 5, 3);

class _TutorialGoldenService extends MockAppService implements AppClockSource {
  _TutorialGoldenService() : super(historyClock: () => _now);

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

/// 지금 단계가 끝날 때까지 기다리고 다음 칸으로.
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
  await tester.pump(const Duration(milliseconds: 150));
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

  testWidgets('tutorial-plan-order', (tester) async {
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

    // 4: hooks 출구(학생 · 상세 · 계산기 · 목표 — 실제 동작은 walkthrough 시험 몫).
    await _toStep(tester, session, '4');
    hooks.signals.emit(TutorialSignals.studentCalculatorTargetChanged);
    await _waitDone(tester, session);
    // 5: 기술 노트 · 전술 교육 BD 고르기 → 스캔 시작 → 가상 아이템 스캔 끝(실제 누르기).
    await _toStep(tester, session, '5');
    await tester.tap(find.byKey(const ValueKey('scan-pick-item-tech_notes')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('scan-pick-item-tactical_bd')));
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
    await _waitDone(tester, session);
    // 6: 확인 필요 2칸 승인은 hooks 출구, '적용'은 실제 누르기.
    await _toStep(tester, session, '6');
    hooks.signals.emit(TutorialSignals.itemReviewUncertainApproved);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('scan-item-apply')));
    await _waitDone(tester, session);

    // 7-1 · 7-2 · 7-2b · 7-2c(계획 만들기 1 · 2).
    await _toStep(tester, session, '7-1');
    await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
    await _waitDone(tester, session);
    await _toStep(tester, session, '7-2');
    await tester.tap(find.byKey(const ValueKey('plan-flow-goal-mode-max')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-flow-goal-apply-all')));
    await _waitDone(tester, session);
    await _toStep(tester, session, '7-2b');
    final flow = tester
        .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
        .flow;
    final maki = flow.draft.stages.singleWhere(
      (stage) => stage.studentId == 'maki',
    );
    await _setSkills(tester, maki.id, [5, 10, 1, 1]);
    await _waitDone(tester, session);
    expect(session.flow!.step!.id, '7-2c');
    await tester.tap(find.byKey(const ValueKey('plan-flow-goal-add-stage')));
    await tester.pump();
    final stage2 = tester
        .widget<PlanFlowGoalBody>(find.byType(PlanFlowGoalBody))
        .editor
        .stagesOf('maki')
        .last
        .id;
    await _setSkills(tester, stage2, [5, 10, 7, 7]);
    await _waitDone(tester, session);

    // 프라나 08d(바탕: 계획 만들기 3) → 7-3 카드 + 아카네 카드 강조.
    await _toStep(tester, session, '7-3');
    await _frames(tester, 4);
    expect(find.textContaining('칸나(수영복) · 마키 · 미카는 1순위'), findsOneWidget);
    expect(find.text('튜토리얼 · 임시 계정'), findsOneWidget);
    expect(
      hooks.registry.geometryOf(TutorialTargets.planOrderCardAkane),
      isNotNull,
    );
    await expectGoldenScene(tester, 'tutorial-plan-order');
  }, variant: goldenPlatform);
}
