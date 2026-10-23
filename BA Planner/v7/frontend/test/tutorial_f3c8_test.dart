// F3c-8:
// - Mock 스캔 재생 순서(CF gate 20261022_001305 — 일시정지 · 재개 뒤 원래 타이머가 미룬 단계보다 먼저 끝(terminal)을 내던
//   흔들림)를 가짜 시간으로 결정적으로 재현한다. 재생은 커서 하나로 한 번에 다음 단계 하나만 예약하므로, 재개 직후 원래
//   일정의 뒤 단계가 남아 있던 자리에서도 후보 수 · 순서가 그대로이고 끝이 마지막이다.
// - 카드 자리 규칙 8(피할 자리가 없으면 대사 띠 배율까지 줄임)과 줄인 카드의 누르기.
// - 9단계 카드 '왜' 줄 앞 활성 계획 적용 안내.
// - Windows 변형 5단계 실제 누르기(가상 대상은 진행 창 없이 끝 — 진행 창 한 줄은 화면 아래 가운데).
import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_card_placement.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_flow.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_step_card.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_overlay.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _main = '000000000000000000000001';

/// 세션 [sessionId] 이벤트를 짧은 이름 줄로(진행 · 후보는 번호까지).
List<String> _trace(List<ScannerEvent> events, String sessionId) => [
  for (final event in events)
    if (event.sessionId == sessionId)
      switch (event.eventKind) {
        ScannerEventKind.progress => 'progress ${event.payload['current']}',
        ScannerEventKind.candidate =>
          'candidate ${(event.payload['candidate'] as Map)['candidate_id']}',
        ScannerEventKind.terminal => 'terminal ${event.payload['outcome']}',
        final kind => kind.name,
      },
];

int _count(List<String> trace, String prefix) =>
    trace.where((line) => line.startsWith(prefix)).length;

void main() {
  // 가짜 시간(testWidgets의 FakeAsync 영역)에서 Mock 타이머를 민다.
  testWidgets(
    'practice replay: a resume right before the end keeps the order and every candidate',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final pid = (await service.createPractice(
        PracticeCreateRequest(
          originProfileId: _main,
          expectedOriginRevision: 0,
          idempotencyKey: 'start-1',
        ),
      )).practice!.profileId;
      final events = <ScannerEvent>[];
      final subscription = service.scannerEvents.listen(events.add);
      addTearDown(subscription.cancel);

      final session = await service.startScannerSession(
        ScannerKind.student,
        practiceVirtualTargetId,
        profileId: pid,
        studentScanMode: StudentScanMode.full,
      );
      // 학생 재생 = 진행 9 · 후보 9 · 끝(10ms 간격). 후보 8개가 나온 뒤(170ms) 일시정지를 걸면 9번째 후보 자리에서 멈춘다.
      await tester.pump(const Duration(milliseconds: 175));
      expect(_count(_trace(events, session.id), 'candidate'), 8);
      final pause = await service.pauseScannerSession(session);
      expect(pause.controlState, ScannerControlState.pauseRequested);
      await tester.pump(const Duration(milliseconds: 7));
      expect(_trace(events, session.id).last, 'paused');
      // 원래 일정의 끝 자리(190ms)보다 앞에서 재개한다.
      final resume = await service.resumeScannerSession(session);
      expect(resume.accepted, isTrue);
      await tester.pump(const Duration(milliseconds: 300));

      final trace = _trace(events, session.id);
      expect(_count(trace, 'candidate'), 9, reason: '$trace');
      expect(trace.last, 'terminal completed', reason: '$trace');
      expect(_count(trace, 'terminal'), 1);
      // 진행 1~9 → 후보 1~9(재생 목록 순서) → 끝. 일시정지 · 재개는 8번째와 9번째 후보 사이.
      final kinds = [
        for (final line in trace)
          if (line.startsWith('progress') || line.startsWith('candidate')) line,
      ];
      expect(kinds, [
        for (var index = 1; index <= 9; index++) 'progress $index',
        for (var index = 1; index <= 9; index++)
          'candidate tutorial-${session.generation}-$index',
      ]);
      final lastCandidate = trace.lastIndexWhere(
        (line) => line.startsWith('candidate'),
      );
      expect(trace.indexOf('paused'), lessThan(trace.indexOf('resumed')));
      expect(trace.indexOf('resumed'), lastCandidate - 1);
    },
  );

  testWidgets(
    'plain Mock scan: a resume before the original end still emits the candidate first',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final events = <ScannerEvent>[];
      final subscription = service.scannerEvents.listen(events.add);
      addTearDown(subscription.cancel);

      final session = await service.startScannerSession(
        ScannerKind.student,
        'mock-window',
      );
      // 일반 Mock = 진행 · 후보 · 끝(10ms 간격). 진행 뒤 일시정지 → 후보 자리에서 멈춤 → 원래 끝 자리(30ms) 앞에서 재개.
      await tester.pump(const Duration(milliseconds: 15));
      expect(_trace(events, session.id), contains('progress 1'));
      await service.pauseScannerSession(session);
      await tester.pump(const Duration(milliseconds: 7));
      expect(_trace(events, session.id).last, 'paused');
      final resume = await service.resumeScannerSession(session);
      expect(resume.accepted, isTrue);
      await tester.pump(const Duration(milliseconds: 100));

      final trace = _trace(events, session.id);
      expect(_count(trace, 'candidate'), 1, reason: '$trace');
      expect(trace.last, 'terminal completed', reason: '$trace');
      expect(
        trace.indexOf('resumed'),
        lessThan(trace.indexWhere((line) => line.startsWith('candidate'))),
      );
    },
  );

  testWidgets('a pause right at the start holds every step until resume', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final events = <ScannerEvent>[];
    final subscription = service.scannerEvents.listen(events.add);
    addTearDown(subscription.cancel);

    final session = await service.startScannerSession(
      ScannerKind.student,
      'mock-window',
    );
    await service.pauseScannerSession(session);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_trace(events, session.id), ['phase', 'paused']);
    await service.resumeScannerSession(session);
    await tester.pump(const Duration(milliseconds: 100));
    final trace = _trace(events, session.id);
    expect(trace.sublist(2, 4), ['resumed', 'progress 1']);
    expect(_count(trace, 'candidate'), 1);
    expect(trace.last, 'terminal completed');
  });

  group('카드 자리 규칙 8', () {
    // 1280×720의 7-3과 비슷한 자리: 보드(피할 자리)가 화면 대부분, 대상은 보드 안 카드.
    const bounds = Rect.fromLTRB(0, 184, 1280, 720);
    const board = Rect.fromLTRB(230, 229, 923, 672);
    const target = Rect.fromLTRB(300, 250, 480, 317);
    const card = Size(620, 220);

    test('빈자리가 없으면 겹침 0인 가장 큰 배율로 줄인다', () {
      final chosen = placeTutorialCardScaled(
        target: target,
        card: card,
        bounds: bounds,
        avoid: const [board],
        minScale: 0.5,
      );
      expect(chosen.scale, 0.55);
      expect(chosen.placement.rect.width, closeTo(620 * 0.55, 1e-6));
      expect(chosen.placement.rect.height, closeTo(220 * 0.55, 1e-6));
      expect(tutorialCardCovered(chosen.placement.rect, const [board]), 0);
      expect(chosen.placement.rect.overlaps(target), isFalse);
      expect(bounds.contains(chosen.placement.rect.topLeft), isTrue);
      // 한 단계 큰 배율(0.6)은 보드 오른쪽 빈 곳(357px)에 들어가지 않아 겹친다.
      final larger = placeTutorialCard(
        target: target,
        card: card * 0.6,
        bounds: bounds,
        avoid: const [board],
      );
      expect(tutorialCardCovered(larger.rect, const [board]), greaterThan(0));
    });

    test('하한이 1이거나 피할 자리가 없거나 배율 1 자리가 비면 배율 1(F3c-6 그대로)', () {
      for (final (avoid, minScale) in const [
        (<Rect>[board], 1.0),
        (<Rect>[], 0.5),
        (<Rect>[Rect.fromLTRB(1000, 600, 1100, 700)], 0.5),
      ]) {
        final chosen = placeTutorialCardScaled(
          target: target,
          card: card,
          bounds: bounds,
          avoid: avoid,
          minScale: minScale,
        );
        expect(chosen.scale, 1.0, reason: '$avoid $minScale');
        expect(
          chosen.placement,
          placeTutorialCard(
            target: target,
            card: card,
            bounds: bounds,
            avoid: avoid,
          ),
        );
      }
    });

    test('하한까지 줄여도 겹치면 가장 적게 겹치는 배율', () {
      final chosen = placeTutorialCardScaled(
        target: target,
        card: card,
        bounds: bounds,
        avoid: const [bounds],
        minScale: 0.5,
      );
      expect(chosen.scale, 0.5);
    });

    testWidgets('1280×720에서 줄인 카드: 자리 · 크기 · 그만두기 누르기', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var quit = 0;
      Widget layer(List<Rect> avoid) => MediaQuery(
        data: const MediaQueryData(size: Size(1280, 720)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            type: MaterialType.transparency,
            child: TutorialCardLayer(
              target: target,
              avoid: avoid,
              card: TutorialStepCard(
                step: tutorialSteps['7-3']!,
                onQuit: () => quit++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(layer(const [board]));
      final scaled = tester.getRect(find.byType(TutorialStepCard));
      expect(scaled.width, closeTo(620 * 0.55, 0.01));
      expect(scaled.overlaps(board), isFalse);
      await tester.tap(find.byKey(TutorialStepCard.quitKey));
      expect(quit, 1);
      // 꼭지는 줄인 카드 변 위.
      final nub = tester.getCenter(find.byType(TutorialCardNub));
      expect(scaled.inflate(TutorialCardNub.size).contains(nub), isTrue);

      // 피할 자리가 없으면 배율 1.
      await tester.pumpWidget(layer(const []));
      expect(tester.getRect(find.byType(TutorialStepCard)).width, 620);
      await tester.tap(find.byKey(TutorialStepCard.quitKey));
      expect(quit, 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('9단계 활성 계획 적용 안내', () {
    final step = tutorialSteps['9']!;

    test("적용했으면 '왜' 줄 앞에 한 줄(이름 · 읽는 중 · 빈 목록 모두)", () {
      final named = tutorialStepForShortage(
        step,
        topName: '기술 노트 (최상급)',
        planApplied: true,
      );
      expect(named.title, "맨 위 '기술 노트 (최상급)'을 눌러 보십시오.");
      expect(named.why, '$tutorialPlanAppliedLine\n${step.why}');
      expect(
        tutorialStepForShortage(step, planApplied: true).why,
        '$tutorialPlanAppliedLine\n${step.why}',
      );
      final empty = tutorialStepForShortage(
        step,
        empty: true,
        planApplied: true,
      );
      expect(empty.why, '$tutorialPlanAppliedLine\n$tutorialShortageEmptyWhy');
      expect(empty.doneTitle, tutorialShortageEmptyDone);
    });

    test('적용하지 않았으면(실패 · 다른 단계) 그대로', () {
      expect(
        tutorialStepForShortage(step, topName: '기술 노트 (최상급)').why,
        step.why,
      );
      final other = tutorialSteps['10']!;
      expect(
        identical(tutorialStepForShortage(other, planApplied: true), other),
        isTrue,
      );
    });
  });

  testWidgets(
    'Windows: step 5 by real taps — two kinds, start, done, inline line at the bottom',
    (tester) async {
      tester.view.physicalSize = const Size(2560, 1392);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final service = MockAppService();
      addTearDown(service.dispose);
      const hold = Duration(milliseconds: 60);
      final session = TutorialSession(service: service, completeHold: hold);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        BAPlannerApp(
          service: service,
          tutorial: true,
          tutorialSession: session,
        ),
      );
      await tester.pumpAndSettle();
      Future<void> frames([int count = 8]) async {
        for (var index = 0; index < count * 10; index++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
      }

      Future<void> toStep(String id) async {
        while (session.flow!.phase == TutorialPhase.dialogue) {
          final index = session.flow!.flowIndex;
          while (session.flow?.phase == TutorialPhase.dialogue &&
              session.flow?.flowIndex == index) {
            session.flow!.advanceLine();
            await tester.pump();
          }
          await frames();
        }
        await frames(4);
        expect(session.flow!.step!.id, id);
      }

      Future<void> waitDone() async {
        for (
          var round = 0;
          round < 200 && session.flow!.phase == TutorialPhase.step;
          round++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pump();
        expect(session.flow!.phase, TutorialPhase.stepComplete);
        await tester.pump(hold * 2);
        await frames();
      }

      final origin = (await service.listProfiles()).singleWhere(
        (profile) => profile.selected,
      );
      unawaited(session.start(origin));
      await frames(4);
      await toStep('1');
      await tester.tap(
        find.byKey(
          const ValueKey('home-connect-panel-row-$practiceVirtualTargetId'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
      await waitDone();
      await toStep('2');
      await tester.tap(find.byKey(const ValueKey('scan-pick-student-full')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
      await waitDone();
      await toStep('3');
      await tester.tap(find.byKey(const ValueKey('scan-review-bulk-apply')));
      await waitDone();
      await toStep('4');
      session.hooks.signals.emit(
        TutorialSignals.studentCalculatorTargetChanged,
      );
      await waitDone();

      // 5: 실제 누르기.
      await toStep('5');
      await tester.tap(find.byKey(const ValueKey('scan-pick-item-tech_notes')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('scan-pick-item-tactical_bd')),
      );
      await frames(2);
      await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(session.flow!.cardMode, TutorialCardMode.waiting);
      // 가상 대상은 진행 창(dock)이 없다 → 진행 창 한 줄은 화면 아래 가운데(F3c-3 발견 6).
      final line = tester.getRect(find.byKey(TutorialOverlay.inlineKey));
      expect(line.bottom, 1392 - 24);
      expect(line.center.dx, closeTo(1280, 1));
      await waitDone();
      expect(session.flow!.scene?.id, 'plana-07');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
