// F3c-3: 튜토리얼 한 바퀴(FD-182) — Mock 임시 계정으로 처음부터 끝까지, 중간 그만두기, 설정 다시 하기(reset), 미지원 안내,
// 남은 임시 계정 정리 실패 표시, 끝 정리 실패 · 다시 시도, 타이틀 위 시작, 1280×720 넘침 0.
// 신호는 실제 화면 동작(연결 패널 · 스캔 시작 · 결과 적용 · 계산기 · 아이템 스캔 · 아이템 적용)으로 내고, 계획 7-x · 8 ·
// 9 · 10은 hooks 출구로 낸다(계획 신호는 Lane B F3c-4, 부족 · 성장 추이는 계획 저장 · 이력 뒤라 이 Mock 한 바퀴에서는
// 화면 조건이 없다 — status F3c-3 종료 기록).
import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/app_shell.dart';
import 'package:ba_planner_v7/ui/pages/title_page.dart';
import 'package:ba_planner_v7/ui/tutorial/plana_dialogue.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_flow.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_highlight.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_quit_dialog.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_step_card.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_overlay.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_session.dart';
import 'package:ba_planner_v7/ui/tutorial_targets/tutorial_header_chip_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _hold = Duration(milliseconds: 60);

/// 남은 임시 계정 정리가 실패하는 Mock.
class _RecoverFailService extends MockAppService {
  @override
  Future<PracticeRecoveryResult> recoverPractice(
    PracticeRecoverRequest request,
  ) async => throw StateError('recover failed');
}

/// 첫 끝 요청이 실패하는 Mock.
class _EndFailOnceService extends MockAppService {
  bool failed = false;

  @override
  Future<PracticeEndResult> endPractice(PracticeEndRequest request) async {
    if (!failed) {
      failed = true;
      throw StateError('end failed');
    }
    return super.endPractice(request);
  }
}

Future<TutorialSession> _pumpApp(
  WidgetTester tester,
  MockAppService service, {
  Size size = const Size(2560, 1392),
  bool showTitle = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // 대사 띠 · 도는 표시의 반복 움직임을 멈춘다(F3a 시험과 같이 움직임 줄이기).
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  addTearDown(service.dispose);
  final session = TutorialSession(service: service, completeHold: _hold);
  addTearDown(session.dispose);
  await tester.pumpWidget(
    BAPlannerApp(
      service: service,
      showTitle: showTitle,
      tutorial: true,
      tutorialSession: session,
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<RepositoryProfile> _origin(MockAppService service) async =>
    (await service.listProfiles()).singleWhere((profile) => profile.selected);

Future<void> _start(
  WidgetTester tester,
  TutorialSession session,
  RepositoryProfile origin,
) async {
  unawaited(session.start(origin));
  await _frames(tester, 4);
}

/// 지금 대사 장면을 끝까지 넘긴다(대사 띠의 클릭과 같은 [TutorialFlowController.advanceLine]).
Future<void> _finishScene(WidgetTester tester, TutorialSession session) async {
  final flow = session.flow!;
  expect(flow.phase, TutorialPhase.dialogue, reason: '${flow.currentItem}');
  final index = flow.flowIndex;
  while (session.flow?.phase == TutorialPhase.dialogue &&
      session.flow?.flowIndex == index) {
    session.flow!.advanceLine();
    await tester.pump();
  }
  await _frames(tester);
}

/// 단계 완료 체크 뒤 다음 칸으로.
Future<void> _afterComplete(WidgetTester tester, String doneTitle) async {
  await tester.pump();
  expect(find.text(doneTitle), findsOneWidget);
  await tester.pump(_hold * 2);
  await _frames(tester);
}

/// 지금 단계가 완료 체크([doneTitle])가 될 때까지 짧게 넘기고(실제 Mock 스캔 · 적용), 다음 칸으로.
Future<void> _waitDone(
  WidgetTester tester,
  TutorialSession session,
  String doneTitle,
) async {
  for (
    var round = 0;
    round < 200 && session.flow!.phase == TutorialPhase.step;
    round++
  ) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  final scan = session.scanSession.value;
  expect(
    session.flow!.phase,
    TutorialPhase.stepComplete,
    reason:
        'stage ${scan?.stage} ${scan?.progressCurrent}/${scan?.progressTotal}',
  );
  expect(find.text(doneTitle), findsOneWidget);
  await tester.pump(_hold * 2);
  await _frames(tester);
}

String? _stepId(TutorialSession session) => session.flow?.step?.id;

AppShell _shell(WidgetTester tester) =>
    tester.widget<AppShell>(find.byType(AppShell));

void main() {
  testWidgets(
    'Mock walkthrough: start → 1~10 → done → back to the first account',
    (tester) async {
      final service = MockAppService();
      final session = await _pumpApp(tester, service);
      final origin = await _origin(service);
      final hooks = session.hooks;
      await _start(tester, session, origin);

      expect(session.status, TutorialSessionStatus.running);
      expect(session.practiceProfile!.isPractice, isTrue);
      expect(find.byKey(PlanaDialogueOverlay.overlayKey), findsOneWidget);
      expect(find.byKey(tutorialHeaderChipKey), findsOneWidget);
      expect(hooks.signals.listener, isNotNull);

      // 프라나 01 → 02(바탕: 홈 연결 패널).
      await _finishScene(tester, session);
      expect(session.flow!.scene!.id, 'plana-02');
      expect(find.byKey(const ValueKey('home-connect-panel')), findsOneWidget);
      await _finishScene(tester, session);

      // 1단계: 가상 게임 창 고르기 → 선택한 창 사용(실제 화면 동작).
      expect(_stepId(session), '1');
      expect(find.text(tutorialSteps['1']!.title!), findsOneWidget);
      expect(
        hooks.registry.geometryOf(TutorialTargets.connectUseSelectedWindow),
        isNotNull,
      );
      expect(find.byType(TutorialHighlightRing), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey('home-connect-panel-row-$practiceVirtualTargetId'),
        ),
      );
      await tester.pump();
      expect(session.flow!.checkStates.first, TutorialCheckState.done);
      await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
      await _afterComplete(tester, '연결했습니다');

      // 프라나 03(바탕: 스캔 탭) → 2단계: 학생 전체 → 스캔 시작 → 기다림(진행 수) → 끝.
      expect(session.flow!.scene!.id, 'plana-03');
      await _finishScene(tester, session);
      expect(_stepId(session), '2');
      // 바탕 장면이 이미 스캔 탭을 열었다 → '스캔 탭 열기' 체크.
      expect(session.flow!.checkStates.first, TutorialCheckState.done);
      expect(
        hooks.registry.geometryOf(TutorialTargets.scanStudentStartFullScan),
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('scan-pick-student-full')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(session.flow!.cardMode, TutorialCardMode.waiting);
      expect(find.text(tutorialSteps['2']!.waitTitle!), findsOneWidget);
      await _waitDone(tester, session, '스캔을 마쳤습니다');

      // 프라나 04(바탕: 학생 결과 검토) — 대사 2가 확인 필요 묶음을 밝힌다.
      expect(session.flow!.scene!.id, 'plana-04');
      session.flow!.advanceLine();
      await _frames(tester, 3);
      expect(
        session.flow!.revealKeys,
        contains(TutorialTargets.studentReviewUncertainGroup),
      );
      expect(
        hooks.registry.geometryOf(TutorialTargets.studentReviewUncertainGroup),
        isNotNull,
      );
      await _finishScene(tester, session);

      // 3단계: 6명 한 번에 적용.
      expect(_stepId(session), '3');
      expect(
        hooks.registry.geometryOf(TutorialTargets.studentReviewApplyChanged),
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('scan-review-bulk-apply')));
      await _waitDone(tester, session, '적용했습니다');
      // 남은 후보(새 학생 1 · 확인 필요 2)가 검토 대기면 스캔 탭이 고르기로 돌아가지 않는다(발견 — status). 시험은 남은
      // 후보를 폐기해 5단계 고르기 화면으로 간다.
      final scan = session.scanSession.value!;
      for (final candidate in scan.candidates.values.toList()) {
        if (scan.candidateResolution(candidate) != null) continue;
        unawaited(scan.discardStudentCandidate(candidate));
        await tester.pump();
      }
      await _frames(tester, 3);

      // 프라나 05(바탕: 학생 탭) → 4단계: 학생 · 상세 · 계산기 · 목표 +.
      expect(session.flow!.scene!.id, 'plana-05');
      await _finishScene(tester, session);
      expect(_stepId(session), '4');
      // 학생 · 상세 · 계산기 · 목표 신호는 hooks 출구로(실제 화면 신호는 tutorial_targets_f3c2_test의 계산기 시험이 본다 —
      // 임시 계정 그리드는 전체 카탈로그라 첫 화면에 보유 학생 카드가 없다).
      for (final signal in const [
        TutorialSignals.studentOpened,
        TutorialSignals.studentDetailOpened,
        TutorialSignals.studentCalculatorOpened,
      ]) {
        hooks.signals.emit(signal);
        await tester.pump();
      }
      expect(
        session.flow!.checkStates.take(3),
        everyElement(TutorialCheckState.done),
      );
      hooks.signals.emit(TutorialSignals.studentCalculatorTargetChanged);
      await _afterComplete(tester, '목표를 바꿨습니다');

      // 프라나 06(바탕: 스캔 탭) → 5단계: 카드(아이템 2종 고르기 · 시작 강조) → 진행 창 한 줄 → 끝.
      expect(session.flow!.scene!.id, 'plana-06');
      await _finishScene(tester, session);
      expect(_stepId(session), '5');
      expect(find.text('아이템 2종을 고르고 스캔을 시작해 주십시오'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scan-pick-item-tech_notes')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('scan-pick-item-tactical_bd')),
      );
      await _frames(tester, 2);
      expect(
        hooks.registry.geometryOf(TutorialTargets.scanItemStart),
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(session.flow!.cardMode, TutorialCardMode.waiting);
      expect(find.byKey(TutorialOverlay.inlineKey), findsOneWidget);
      await _waitDone(tester, session, '아이템 스캔을 마쳤습니다');
      expect(session.flow!.scene?.id, 'plana-07');
      await _finishScene(tester, session);

      // 6단계: 승인한 칸 적용(확인 필요 2칸 승인은 hooks 출구 — 칸 고르기 · 승인 순서는 아이템 검토 시험 몫).
      expect(_stepId(session), '6');
      hooks.signals.emit(TutorialSignals.itemReviewUncertainApproved);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('scan-item-apply')));
      await _waitDone(tester, session, '적용했습니다');

      // 7-1 ~ 8: 바탕은 계획 탭, 완료 신호는 hooks 출구(Lane B F3c-4가 계획 신호 5개를 붙인다).
      const planSteps = {
        '7-1': (TutorialSignals.planStudentsConfirmed, '학생을 골랐습니다'),
        '7-2': (TutorialSignals.planAllMaxApplied, 'MAX로 맞췄습니다'),
        '7-2b': (TutorialSignals.planMakiStage1Set, '1단계를 정했습니다'),
        '7-2c': (TutorialSignals.planMakiStage2Set, '2단계를 더했습니다'),
        '7-3': (TutorialSignals.planRanksPlaced, '순위를 정했습니다'),
        '7-4': (TutorialSignals.planKannaAkaneLinked, '이어 붙였습니다'),
        '7-5': (TutorialSignals.planLaterMoved, '나중으로 옮겼습니다'),
        '7-6': (TutorialSignals.planSavedAsScenario, '시나리오로 저장했습니다'),
        '8': (TutorialSignals.scenarioCompareOpened, '나란히 비교했습니다'),
        '9': (TutorialSignals.inventoryTopShortageOpened, '확인했습니다'),
        '10': (TutorialSignals.statisticsGrowthTrendViewed, '확인했습니다'),
      };
      for (final MapEntry(key: id, value: (signal, title))
          in planSteps.entries) {
        while (session.flow!.phase == TutorialPhase.dialogue) {
          await _finishScene(tester, session);
        }
        expect(_stepId(session), id);
        if (id == '9') {
          expect(_shell(tester), isNotNull);
        }
        hooks.signals.emit(signal);
        await _afterComplete(tester, title);
      }

      // 프라나 11: 실제 첫 계정 이름('Main' → "'Main' 계정으로").
      expect(session.flow!.scene!.id, 'plana-11');
      session.flow!.advanceLine();
      await tester.pump();
      expect(
        session.flow!.line!.text,
        contains("'메인 계정'으로"),
        reason: '대본 데이터는 그대로',
      );
      final shown = tutorialSceneForAccount(
        session.flow!.scene!,
        session.accountName,
      );
      expect(shown.lines[1].text, contains("'Main' 계정으로"));
      await _finishScene(tester, session);

      // 끝 화면 → 돌아가기 → 임시 계정 지움 → 첫 계정 홈.
      expect(session.flow!.phase, TutorialPhase.doneScreen);
      expect(find.byKey(const ValueKey('tutorial-done-panel')), findsOneWidget);
      expect(find.text('Main으로 돌아가기'), findsNothing);
      expect(find.text('Main${koreanEuro('Main')} 돌아가기'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tutorial-done-finish')));
      await _frames(tester, 6);
      expect(session.status, TutorialSessionStatus.idle);
      expect(session.practice, isNull);
      expect(hooks.active.value, isFalse);
      expect(hooks.signals.listener, isNull);
      expect((await service.currentPractice()).practice, isNull);
      expect((await _origin(service)).id, origin.id);
      expect(find.byKey(tutorialHeaderChipKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('quit midway deletes the practice account and returns', (
    tester,
  ) async {
    final service = MockAppService();
    final session = await _pumpApp(tester, service);
    final origin = await _origin(service);
    await _start(tester, session, origin);
    await _finishScene(tester, session);
    await _finishScene(tester, session);
    expect(_stepId(session), '1');

    await tester.tap(find.byKey(TutorialStepCard.quitKey));
    await tester.pump();
    expect(find.byKey(TutorialQuitPanel.panelKey), findsOneWidget);
    expect(find.text("그만두면 임시 계정을 지우고 'Main' 계정으로 돌아갑니다."), findsOneWidget);
    // 계속하기 → 하던 단계.
    await tester.tap(find.byKey(TutorialQuitPanel.continueKey));
    await tester.pump();
    expect(_stepId(session), '1');
    await tester.tap(find.byKey(TutorialStepCard.quitKey));
    await tester.pump();
    await tester.tap(find.byKey(TutorialQuitPanel.quitKey));
    await tester.pump();
    expect(session.flow!.phase, TutorialPhase.quitDialogue);
    while (session.flow?.phase == TutorialPhase.quitDialogue) {
      session.flow!.advanceLine();
      await tester.pump();
    }
    await _frames(tester, 6);
    expect(session.practice, isNull);
    expect((await service.currentPractice()).practice, isNull);
    expect((await _origin(service)).id, origin.id);
    expect(session.hooks.active.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings restart resets the active practice account', (
    tester,
  ) async {
    final service = MockAppService();
    final session = await _pumpApp(tester, service);
    final origin = await _origin(service);
    await _start(tester, session, origin);
    final practiceId = session.practice!.profileId;
    await _finishScene(tester, session);
    await _finishScene(tester, session);
    expect(_stepId(session), '1');
    expect(session.practiceEpoch, 1);

    // 설정 탭의 튜토리얼 다시 하기(임시 계정 동안은 돌아갈 계정 = 세션의 첫 계정).
    await tester.tap(find.byKey(const ValueKey('top-tab-settings')));
    await _frames(tester, 10);
    final restart = find.byKey(
      const ValueKey('settings-tutorial-restart-button'),
    );
    expect(restart, findsOneWidget);
    await tester.tap(restart);
    await _frames(tester, 4);
    expect(session.practiceEpoch, 2);
    expect(session.practice!.profileId, practiceId, reason: 'reset은 같은 계정');
    expect(session.flow!.flowIndex, 0);
    expect(session.origin!.id, origin.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported backend: no tutorial, short notice, home', (
    tester,
  ) async {
    final service = MockAppService(tutorialPracticeSupported: false);
    final session = await _pumpApp(tester, service);
    await tester.tap(find.byKey(const ValueKey('top-tab-students')));
    await tester.pumpAndSettle();
    await _start(tester, session, await _origin(service));
    expect(session.flow, isNull);
    expect(session.practice, isNull);
    expect(find.byKey(TutorialOverlay.noticeKey), findsOneWidget);
    expect(find.text(tutorialUnsupportedNotice), findsOneWidget);
    expect(find.byKey(PlanaDialogueOverlay.overlayKey), findsNothing);
    await tester.tap(find.byKey(TutorialOverlay.noticeCloseKey));
    await tester.pump();
    expect(find.byKey(TutorialOverlay.noticeKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recover failure on start is shown, not treated as success', (
    tester,
  ) async {
    final service = _RecoverFailService();
    await _pumpApp(tester, service);
    expect(find.byKey(TutorialOverlay.noticeKey), findsOneWidget);
    expect(find.textContaining(tutorialRecoverFailedNotice), findsOneWidget);
  });

  testWidgets('end failure keeps the error and retries with the same request', (
    tester,
  ) async {
    final service = _EndFailOnceService();
    final session = await _pumpApp(tester, service);
    await _start(tester, session, await _origin(service));
    await _finishScene(tester, session);
    await _finishScene(tester, session);
    await tester.tap(find.byKey(TutorialStepCard.quitKey));
    await tester.pump();
    await tester.tap(find.byKey(TutorialQuitPanel.quitKey));
    await tester.pump();
    while (session.flow?.phase == TutorialPhase.quitDialogue) {
      session.flow!.advanceLine();
      await tester.pump();
    }
    await _frames(tester, 4);
    expect(session.status, TutorialSessionStatus.ending);
    expect(find.byKey(TutorialOverlay.endErrorKey), findsOneWidget);
    expect(session.practice, isNotNull);
    expect((await service.currentPractice()).practice, isNotNull);
    await tester.tap(find.byKey(TutorialOverlay.endRetryKey));
    await _frames(tester, 4);
    expect(session.status, TutorialSessionStatus.idle);
    expect((await service.currentPractice()).practice, isNull);
    expect(find.byKey(TutorialOverlay.endErrorKey), findsNothing);
  });

  testWidgets('first run ③ path: dialogue over the title, then the shell', (
    tester,
  ) async {
    final service = MockAppService();
    final session = await _pumpApp(tester, service, showTitle: true);
    final title = tester.widget<TitlePage>(find.byType(TitlePage));
    expect(title.onStartTutorial, isNotNull);
    title.onStartTutorial!(
      tester.element(find.byType(TitlePage)),
      await _origin(service),
    );
    await _frames(tester, 4);
    expect(find.byType(TitlePage), findsOneWidget);
    expect(find.byKey(PlanaDialogueOverlay.overlayKey), findsOneWidget);
    expect(session.flow!.scene!.id, 'plana-01');
    await _finishScene(tester, session);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byKey(const ValueKey('home-connect-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '1280x720: dialogue, card, quit and done lay out without overflow',
    (tester) async {
      final service = MockAppService();
      final session = await _pumpApp(
        tester,
        service,
        size: const Size(1280, 720),
      );
      await _start(tester, session, await _origin(service));
      expect(tester.takeException(), isNull);
      await _finishScene(tester, session);
      await _finishScene(tester, session);
      expect(find.byType(TutorialStepCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(TutorialStepCard.quitKey));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(TutorialQuitPanel.continueKey));
      await tester.pump();
      // 끝 화면까지 건너뛴다(신호는 순서대로 낸다).
      while (session.flow!.phase != TutorialPhase.doneScreen) {
        final flow = session.flow!;
        if (flow.phase == TutorialPhase.dialogue) {
          flow.advanceLine();
        } else if (flow.phase == TutorialPhase.step) {
          flow.signal(flow.step!.completeSignal);
        }
        await tester.pump(_hold * 2);
      }
      await _frames(tester, 3);
      expect(find.byKey(const ValueKey('tutorial-done-panel')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('tutorial-done-finish')));
      await _frames(tester, 6);
      expect(session.practice, isNull);
    },
  );
}
