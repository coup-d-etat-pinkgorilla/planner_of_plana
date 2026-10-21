// F3a 튜토리얼 부품 단독 시험(시안 W-Tutorial-Card · W-Plana-Dialogue · Tutorial-Plana-Script, FD-182 · FD-183).
//
// 앱에 붙이지 않은 부품만 시험한다: 대본 데이터 · 상태 기계(가짜 신호) · 단계 카드 상태 · 카드 자리 규칙 ·
// 강조 테두리 입력 통과 · 대사 띠(한 글자씩 · 클릭 전체 · 움직임 줄이기 · 밝히기 구멍 · 그림 없음 · 그만두기) ·
// 그만두기 확인 · 1280×720 넘침 0 · golden 보드 2장 렌더(비교는 CF gate 몫).
import 'package:ba_planner_v7/ui/tutorial/plana_dialogue.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_card_placement.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_flow.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_highlight.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_quit_dialog.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_step_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/tutorial_f3a_fixture.dart';

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 흐름을 끝까지 밟으며 지난 칸을 적는다(대사는 넘기고, 단계는 완료 신호 → 1.2초).
Future<List<String>> _walkFlow(
  WidgetTester tester,
  TutorialFlowController controller,
) async {
  final visited = <String>[];
  controller.start();
  var guard = 0;
  while (controller.phase != TutorialPhase.ended && guard++ < 500) {
    final item = controller.currentItem;
    switch (controller.phase) {
      case TutorialPhase.dialogue:
        if (controller.lineIndex == 0) visited.add(item.toString());
        controller.advanceLine();
      case TutorialPhase.step:
        visited.add(item.toString());
        controller.signal(controller.step!.completeSignal);
        expect(controller.phase, TutorialPhase.stepComplete);
        await tester.pump(controller.completeHold);
      case TutorialPhase.doneScreen:
        visited.add(item.toString());
        controller.finish();
      default:
        fail('unexpected phase ${controller.phase}');
    }
  }
  return visited;
}

void main() {
  group('대본 데이터', () {
    test('장면 18개 + 그만둘 때, 대사 수는 대본 보드와 같다', () {
      const expected = {
        'plana-01': 5,
        'plana-02': 2,
        'plana-03': 2,
        'plana-04': 5,
        'plana-05': 2,
        'plana-06': 2,
        'plana-07': 2,
        'plana-08': 4,
        'plana-08c': 3,
        'plana-08g': 3,
        'plana-08d': 3,
        'plana-08e': 3,
        'plana-08f': 3,
        'plana-09': 3,
        'plana-09c': 3,
        'plana-09d': 3,
        'plana-10': 2,
        'plana-11': 3,
        'plana-quit': 2,
      };
      expect(tutorialScenes.keys.toList(), expected.keys.toList());
      for (final entry in expected.entries) {
        expect(
          tutorialScenes[entry.key]!.lines,
          hasLength(entry.value),
          reason: entry.key,
        );
      }
      expect(tutorialScenes.length - 1, 18);
    });

    test('대표 대사 · 표정 · 장면 이름이 시안 그대로다', () {
      final intro = tutorialScenes['plana-01']!;
      expect(
        intro.lines[2].text,
        '그래서 선배와 따로 움직이는 프로세스를 마련했습니다. 학생 육성, 재화, 계획은 앞으로 이쪽에서 관리합니다.',
      );
      expect(intro.counterText(2), '튜토리얼 · 시작 · 대사 3 / 5');
      expect(intro.lines[1].expression, PlanaExpression.troubled);
      expect(intro.lines[1].expression.label, '곤란');
      final review = tutorialScenes['plana-04']!;
      expect(review.counterText(1), '튜토리얼 · 학생 검토 · 대사 2 / 5');
      expect(review.lines[1].revealKeys, [
        TutorialTargets.studentReviewUncertainGroup,
      ]);
      expect(
        tutorialScenes['plana-08f']!.counterText(1),
        '튜토리얼 · 계획 · 나중에 · 대사 2 / 3',
      );
      expect(
        tutorialScenes['plana-11']!.lines.last.expression,
        PlanaExpression.smile,
      );
      // 표정 이름 6개(대본 보드 범례).
      expect(PlanaExpression.values.map((e) => e.label), [
        '기본',
        '살짝 미소',
        '미소',
        '곤란',
        '진지',
        '생각',
      ]);
    });

    test('밝힐 대상 · 강조 대상 · 신호 이름은 목록 안에 있다', () {
      for (final scene in tutorialScenes.values) {
        for (final line in scene.lines) {
          for (final key in line.revealKeys) {
            expect(
              TutorialTargets.revealKeys,
              contains(key),
              reason: '${scene.id} $key',
            );
          }
          if (line.revealKeys.isNotEmpty) {
            expect(
              line.boardDrawn,
              isTrue,
              reason: '${scene.id} 밝히기는 보드에 그린 대사만',
            );
          }
        }
        expect(scene.figureLeftFor(0), isNotNull, reason: scene.id);
      }
      for (final step in tutorialSteps.values) {
        final key = step.highlightKey;
        if (key != null) expect(TutorialTargets.highlightKeys, contains(key));
        expect(TutorialSignals.all, contains(step.completeSignal));
        for (final check in step.checks) {
          final signal = check.signal;
          if (signal != null) expect(TutorialSignals.all, contains(signal));
        }
      }
      expect(
        TutorialSignals.all.toSet(),
        hasLength(TutorialSignals.all.length),
      );
      expect(
        TutorialTargets.highlightKeys.toSet(),
        hasLength(TutorialTargets.highlightKeys.length),
      );
      expect(
        TutorialTargets.revealKeys.toSet(),
        hasLength(TutorialTargets.revealKeys.length),
      );
    });

    test('장면의 다음 단계는 흐름 순서와 맞다', () {
      for (var index = 0; index < tutorialFlow.length; index++) {
        final item = tutorialFlow[index];
        if (item is! TutorialSceneItem) continue;
        final next = index + 1 < tutorialFlow.length
            ? tutorialFlow[index + 1]
            : null;
        final scene = tutorialScenes[item.sceneId]!;
        expect(
          scene.nextStepId,
          next is TutorialStepItem ? next.stepId : null,
          reason: scene.id,
        );
      }
      // 흐름에 장면 18개 · 단계 17개(1~10 + 7-1~7-6 · 7-2b · 7-2c) · 끝 화면 1.
      expect(tutorialFlow.whereType<TutorialSceneItem>(), hasLength(18));
      expect(
        tutorialFlow.whereType<TutorialStepItem>(),
        hasLength(tutorialSteps.length),
      );
      expect(tutorialFlow.last, isA<TutorialDoneItem>());
    });

    test('끝 화면 · 그만두기 문구', () {
      expect(tutorialDoneFeatures, [
        '가상 게임 창에 연결',
        '학생 가상 스캔',
        '학생 결과 적용',
        '학생 상세 · 성장 계산기',
        '아이템 가상 스캔',
        '아이템 결과 적용',
        '계획 만들기',
        '시나리오 저장 · 비교',
        '부족한 재화 확인',
        '통계에서 변화 확인',
      ]);
      expect(TutorialCopy.doneButton('메인 계정'), '메인 계정으로 돌아가기');
      expect(TutorialCopy.doneButton('아로나'), '아로나로 돌아가기');
      expect(TutorialCopy.doneButton('선생'), '선생으로 돌아가기');
      expect(TutorialCopy.doneButton('하늘'), '하늘로 돌아가기');
      expect(
        TutorialCopy.quitBody('메인 계정'),
        // F3c-3(CF 결정): 이름이 '계정'으로 끝나면 '계정'을 한 번만.
        "그만두면 임시 계정을 지우고 '메인 계정'으로 돌아갑니다.",
      );
      expect(
        TutorialCopy.quitBody('Main'),
        "그만두면 임시 계정을 지우고 'Main' 계정으로 돌아갑니다.",
      );
      expect(TutorialCopy.stepCounter(7), '7 / 10');
    });
  });

  group('상태 기계', () {
    testWidgets('장면 → 단계 → 다음 장면 순서가 흐름(frFlow1~9)과 같다', (tester) async {
      final controller = TutorialFlowController();
      addTearDown(controller.dispose);
      final visited = await _walkFlow(tester, controller);
      expect(visited, [for (final item in tutorialFlow) item.toString()]);
      expect(controller.phase, TutorialPhase.ended);
      expect(controller.outcome, TutorialOutcome.completed);
    });

    testWidgets('완료 체크는 약 1.2초 보인 뒤 다음으로 넘어간다', (tester) async {
      final controller = TutorialFlowController();
      addTearDown(controller.dispose);
      controller.start();
      controller.advanceLine();
      expect(controller.scene!.id, 'plana-01');
      for (var i = 0; i < 4; i++) {
        controller.advanceLine();
      }
      expect(controller.scene!.id, 'plana-02');
      controller
        ..advanceLine()
        ..advanceLine();
      expect(controller.step!.id, '1');
      expect(controller.highlightKey, TutorialTargets.connectUseSelectedWindow);
      controller.signal(TutorialSignals.connectVirtualWindowConnected);
      expect(controller.cardMode, TutorialCardMode.complete);
      expect(controller.highlightKey, isNull);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.phase, TutorialPhase.stepComplete);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.phase, TutorialPhase.dialogue);
      expect(controller.scene!.id, 'plana-03');
    });

    testWidgets('하위 체크 · 기다림 · 상관없는 신호 무시', (tester) async {
      final controller = TutorialFlowController(
        flow: const [TutorialStepItem('2'), TutorialDoneItem()],
      );
      addTearDown(controller.dispose);
      controller.start();
      expect(controller.checkStates, [
        TutorialCheckState.current,
        TutorialCheckState.pending,
        TutorialCheckState.pending,
      ]);
      controller.signal(TutorialSignals.planLaterMoved);
      expect(controller.phase, TutorialPhase.step);
      controller.signal(TutorialSignals.scanTabOpened);
      expect(controller.checkStates, [
        TutorialCheckState.done,
        TutorialCheckState.current,
        TutorialCheckState.pending,
      ]);
      controller.signal(TutorialSignals.scanStudentAllSelected);
      expect(controller.cardMode, TutorialCardMode.progress);
      expect(controller.highlightKey, TutorialTargets.scanStudentStartFullScan);
      controller.signal(TutorialSignals.scanStudentStarted);
      expect(controller.cardMode, TutorialCardMode.waiting);
      expect(controller.highlightKey, isNull, reason: '기다림은 강조 없음');
      controller.signal(TutorialSignals.scanStudentFinished);
      expect(controller.cardMode, TutorialCardMode.complete);
      await tester.pump(controller.completeHold);
      expect(controller.phase, TutorialPhase.doneScreen);
    });

    testWidgets('그만두기 → 확인 → 계속하기 / 그만두기 → 프라나 그만둘 때 → 끝', (tester) async {
      final controller = TutorialFlowController(
        flow: const [
          TutorialStepItem('3'),
          TutorialStepItem('4'),
          TutorialDoneItem(),
        ],
      );
      addTearDown(controller.dispose);
      controller.start();
      controller.requestQuit();
      expect(controller.phase, TutorialPhase.confirmingQuit);
      controller.cancelQuit();
      expect(controller.phase, TutorialPhase.step);
      expect(controller.step!.id, '3');

      // 완료 체크 중 그만두기: 시간이 멈추고, 계속하면 다시 1.2초 뒤 다음.
      controller.signal(TutorialSignals.studentReviewApplied);
      controller.requestQuit();
      await tester.pump(const Duration(seconds: 3));
      expect(controller.phase, TutorialPhase.confirmingQuit);
      expect(controller.cardMode, TutorialCardMode.complete);
      controller.cancelQuit();
      expect(controller.phase, TutorialPhase.stepComplete);
      await tester.pump(controller.completeHold);
      expect(controller.step!.id, '4');

      controller.requestQuit();
      controller.confirmQuit();
      expect(controller.phase, TutorialPhase.quitDialogue);
      expect(controller.scene!.id, tutorialQuitSceneId);
      expect(controller.line!.expression, PlanaExpression.troubled);
      controller.signal(TutorialSignals.studentCalculatorTargetChanged);
      expect(
        controller.phase,
        TutorialPhase.quitDialogue,
        reason: '그만둘 때는 신호 무시',
      );
      controller.advanceLine();
      expect(controller.isLastLine, isTrue);
      controller.advanceLine();
      expect(controller.phase, TutorialPhase.ended);
      expect(controller.outcome, TutorialOutcome.quit);
    });

    testWidgets('대사 중 그만두기 확인 · 밝힐 대상', (tester) async {
      final controller = TutorialFlowController(
        flow: const [TutorialSceneItem('plana-04'), TutorialDoneItem()],
      );
      addTearDown(controller.dispose);
      controller.start();
      expect(controller.revealKeys, isEmpty);
      controller.advanceLine();
      expect(controller.revealKeys, [
        TutorialTargets.studentReviewUncertainGroup,
      ]);
      controller.requestQuit();
      expect(controller.revealKeys, isEmpty);
      expect(controller.scene!.id, 'plana-04', reason: '확인 창 뒤에 대사 장면이 남는다');
      controller.cancelQuit();
      expect(controller.phase, TutorialPhase.dialogue);
      expect(controller.lineIndex, 1);
    });
  });

  group('단계 카드', () {
    testWidgets('진행 · 하위 체크 · 기다림 · 완료 체크 상태 전이', (tester) async {
      _setView(tester, const Size(1600, 900));
      final semantics = tester.ensureSemantics();
      final controller = TutorialFlowController(
        flow: const [TutorialStepItem('2'), TutorialDoneItem()],
      );
      addTearDown(controller.dispose);
      var quits = 0;
      controller.start();
      await tester.pumpWidget(
        tutorialTestApp(
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final step = controller.step;
              if (step == null) return const SizedBox();
              return Center(
                child: TutorialStepCard(
                  step: step,
                  mode: controller.cardMode,
                  checkStates: controller.checkStates,
                  waitDone: 34,
                  waitTotal: 128,
                  onQuit: () => quits++,
                ),
              );
            },
          ),
          reduceMotion: true,
        ),
      );
      expect(find.text("'학생 전체 스캔 시작'을 눌러 주십시오."), findsOneWidget);
      expect(find.text('2 / 10'), findsOneWidget);
      expect(find.text('스캔 탭 열기'), findsOneWidget);
      expect(find.bySemanticsLabel('스캔 탭 열기 · 지금'), findsOneWidget);
      controller.signal(TutorialSignals.scanTabOpened);
      await tester.pump();
      expect(find.bySemanticsLabel('스캔 탭 열기 · 완료'), findsOneWidget);
      expect(find.bySemanticsLabel('학생 전체 고르기 · 지금'), findsOneWidget);
      controller.signal(TutorialSignals.scanStudentStarted);
      await tester.pump();
      expect(find.text('가상 스캔이 끝날 때까지 기다려 주십시오.'), findsOneWidget);
      expect(find.text('가상 스캔 중… 34 / 128'), findsOneWidget);
      expect(find.byType(TutorialSpinner), findsOneWidget);
      controller.signal(TutorialSignals.scanStudentFinished);
      await tester.pump();
      expect(find.text('곧 다음 단계로 넘어갑니다.'), findsOneWidget);
      // F3c-3(CF 결정): 2단계 완료 제목.
      expect(find.text('스캔을 마쳤습니다'), findsOneWidget);
      await tester.tap(find.byKey(TutorialStepCard.quitKey));
      expect(quits, 1);
      await tester.pump(controller.completeHold);
      expect(controller.phase, TutorialPhase.doneScreen);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('완료 체크 문구 · 얼굴 칩 그림 없음/있음', (tester) async {
      _setView(tester, const Size(1600, 900));
      await tester.pumpWidget(
        tutorialTestApp(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TutorialStepCard(
                step: tutorialSteps['3']!,
                mode: TutorialCardMode.complete,
              ),
              TutorialStepCard(
                step: tutorialSteps['3']!,
                face: tutorialFakeImage,
              ),
            ],
          ),
          reduceMotion: true,
        ),
      );
      expect(find.text('적용했습니다'), findsOneWidget);
      expect(find.byKey(TutorialFaceChip.placeholderKey), findsOneWidget);
      expect(find.text('프'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('기다림 수를 모르면 분모 · 막대를 숨긴다', (tester) async {
      await tester.pumpWidget(
        tutorialTestApp(
          Center(
            child: TutorialStepCard(
              step: tutorialSteps['2']!,
              mode: TutorialCardMode.waiting,
            ),
          ),
          reduceMotion: true,
        ),
      );
      expect(find.text('가상 스캔 중…'), findsOneWidget);
      expect(find.textContaining('/ 128'), findsNothing);
    });

    testWidgets('진행 창 한 줄(아이템 스캔)', (tester) async {
      var quits = 0;
      await tester.pumpWidget(
        tutorialTestApp(
          Center(
            child: SizedBox(
              width: 347,
              child: TutorialInlineStepLine(
                step: tutorialSteps['5']!,
                onQuit: () => quits++,
              ),
            ),
          ),
          reduceMotion: true,
        ),
      );
      expect(find.text('5 / 10'), findsOneWidget);
      expect(find.text('끝나면 결과 검토로 넘어갑니다'), findsOneWidget);
      await tester.tap(find.byKey(TutorialInlineStepLine.quitKey));
      expect(quits, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('카드 자리 규칙', () {
    const card = Size(560, 134);
    const bounds = Rect.fromLTRB(0, 184, 2560, 1392);

    test('오른쪽 끝 대상 → 왼쪽에 34px 띄워 붙고, 세로 가운데 · 꼭지는 오른쪽', () {
      const target = Rect.fromLTWH(2230, 730, 160, 56);
      final placement = placeTutorialCard(
        target: target,
        card: card,
        bounds: bounds,
      );
      expect(placement.rect.right, target.left - 34);
      expect(placement.rect.center.dy, target.center.dy);
      expect(placement.nubSide, TutorialNubSide.right);
      expect(placement.nubOffset, closeTo(card.height / 2, 0.001));
    });

    test('왼쪽 끝 대상 → 오른쪽, 좌우 폭이 없으면 아래, 아래도 없으면 위', () {
      const leftTarget = Rect.fromLTWH(9, 1255, 376, 66);
      final right = placeTutorialCard(
        target: leftTarget,
        card: card,
        bounds: bounds,
      );
      expect(right.rect.left, leftTarget.right + 34);
      expect(right.nubSide, TutorialNubSide.left);
      expect(
        right.rect.bottom,
        lessThanOrEqualTo(bounds.bottom),
        reason: '화면 밖으로 밀어 넣음',
      );

      const narrow = Rect.fromLTRB(0, 184, 1100, 1392);
      const wide = Rect.fromLTWH(100, 300, 900, 60);
      final below = placeTutorialCard(target: wide, card: card, bounds: narrow);
      expect(below.nubSide, TutorialNubSide.top);
      expect(below.rect.top, wide.bottom + 34);

      const low = Rect.fromLTWH(100, 1300, 900, 60);
      final above = placeTutorialCard(target: low, card: card, bounds: narrow);
      expect(above.nubSide, TutorialNubSide.bottom);
      expect(above.rect.bottom, low.top - 34);
    });

    test('머리글(184px) 위로 나가지 않는다', () {
      const top = Rect.fromLTWH(1200, 190, 160, 40);
      final placement = placeTutorialCard(
        target: top,
        card: card,
        bounds: bounds,
      );
      expect(placement.rect.top, greaterThanOrEqualTo(184));
      expect(tutorialCardBounds(const Size(1280, 720)).top, 184);
    });

    test('가리면 안 되는 자리는 피해 다음 후보로 옮기고 꼭지는 대상 쪽', () {
      const target = Rect.fromLTWH(1200, 600, 160, 56);
      final first = placeTutorialCard(
        target: target,
        card: card,
        bounds: bounds,
      );
      final moved = placeTutorialCard(
        target: target,
        card: card,
        bounds: bounds,
        avoid: [first.rect],
      );
      expect(moved.rect.overlaps(first.rect), isFalse);
      expect(moved.rect.overlaps(target), isFalse);
      expect(moved.nubSide, isNotNull);
    });

    testWidgets('카드 층: 꼭지는 대상 쪽 변, 기다림은 직전 자리', (tester) async {
      _setView(tester, const Size(2560, 1392));
      const target = Rect.fromLTWH(2230, 730, 160, 56);
      Widget layer(Rect? target) => tutorialTestApp(
        Stack(
          children: [
            Positioned.fill(
              child: TutorialCardLayer(
                target: target,
                card: TutorialStepCard(step: tutorialSteps['3']!),
              ),
            ),
          ],
        ),
        reduceMotion: true,
      );
      await tester.pumpWidget(layer(target));
      final cardRect = tester.getRect(find.byType(TutorialStepCard));
      expect(cardRect.right, closeTo(target.left - 34, 0.01));
      final nubCenter = tester.getCenter(find.byType(TutorialCardNub));
      expect(nubCenter.dx, greaterThan(cardRect.center.dx));
      expect(nubCenter.dy, closeTo(target.center.dy, 0.5));
      await tester.pumpWidget(layer(null));
      expect(tester.getRect(find.byType(TutorialStepCard)), cardRect);
    });
  });

  group('강조 테두리', () {
    testWidgets('어둡게 하지 않고 대상 입력을 그대로 통과시킨다', (tester) async {
      var taps = 0;
      var ringTaps = 0;
      await tester.pumpWidget(
        tutorialTestApp(
          Stack(
            children: [
              Positioned(
                left: 100,
                top: 100,
                width: 300,
                height: 60,
                child: TutorialHighlight(
                  child: FakeSlantTarget(
                    size: const Size(300, 60),
                    label: '학생 전체 스캔 시작',
                    onTap: () => taps++,
                  ),
                ),
              ),
              Positioned(
                left: 100,
                top: 300,
                width: 200,
                height: 60,
                child: GestureDetector(
                  key: const ValueKey('ring-target'),
                  onTap: () => ringTaps++,
                  child: const ColoredBox(color: Colors.blueGrey),
                ),
              ),
              const TutorialHighlightRing(
                target: Rect.fromLTWH(100, 300, 200, 60),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.tap(find.text('학생 전체 스캔 시작'));
      expect(taps, 1);
      await tester.tap(find.byKey(const ValueKey('ring-target')));
      expect(ringTaps, 1);
      // 테두리 가장자리(빛 위)를 눌러도 덧그림은 받지 않는다.
      await tester.tapAt(const Offset(101, 301));
      expect(ringTaps, 2);
      expect(
        find.byKey(PlanaDialogueOverlay.dimKey),
        findsNothing,
        reason: '어둡게 덮지 않음',
      );
      // 움직임(1.8초 숨쉬기)은 dispose 때 정리된다.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    test('테두리는 대상을 5px 바깥으로 옮긴 모양이다', () {
      const target = Rect.fromLTWH(800, 294, 300, 60);
      final bounds = tutorialHighlightPath(target).getBounds();
      expect(bounds.top, closeTo(289, 0.01));
      expect(bounds.height, closeTo(70, 0.01));
      expect(bounds.left, closeTo(794.04, 0.1));
      expect(bounds.width, closeTo(311.9, 0.1));
      final tile = tutorialHighlightPath(
        const Rect.fromLTWH(800, 604, 260, 160),
        shape: TutorialHighlightShape.roundedRect,
      ).getBounds();
      expect(tile, const Rect.fromLTWH(795, 599, 270, 170));
    });
  });

  group('프라나 대사 띠', () {
    testWidgets('한 글자씩(초당 약 40자) · 클릭하면 전체 · 다시 누르면 다음', (tester) async {
      _setView(tester, const Size(2560, 1392));
      var next = 0;
      await tester.pumpWidget(
        tutorialTestApp(
          PlanaDialogueOverlay(
            scene: tutorialScenes['plana-01']!,
            lineIndex: 0,
            onNext: () => next++,
          ),
        ),
      );
      final state = tester.state<PlanaDialogueOverlayState>(
        find.byType(PlanaDialogueOverlay),
      );
      final length =
          tutorialScenes['plana-01']!.lines[0].text.characters.length;
      expect(state.visibleCharacters, 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.visibleCharacters, inInclusiveRange(9, 11));
      expect(find.byKey(PlanaDialogueOverlay.nextHintKey), findsNothing);
      await tester.tapAt(const Offset(1280, 500));
      await tester.pump();
      expect(state.visibleCharacters, length);
      expect(next, 0, reason: '나오는 중 클릭은 전체 보이기만');
      expect(find.byKey(PlanaDialogueOverlay.nextHintKey), findsOneWidget);
      await tester.tapAt(const Offset(1280, 500));
      expect(next, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('글자가 다 나오는 시간은 글자 수 / 40초', (tester) async {
      _setView(tester, const Size(2560, 1392));
      await tester.pumpWidget(
        tutorialTestApp(
          PlanaDialogueOverlay(
            scene: tutorialScenes['plana-02']!,
            lineIndex: 0,
            onNext: () {},
          ),
        ),
      );
      final state = tester.state<PlanaDialogueOverlayState>(
        find.byType(PlanaDialogueOverlay),
      );
      final length =
          tutorialScenes['plana-02']!.lines[0].text.characters.length;
      await tester.pump(
        Duration(milliseconds: (length / 40 * 1000).round() - 100),
      );
      expect(state.lineComplete, isFalse);
      await tester.pump(const Duration(milliseconds: 120));
      expect(state.lineComplete, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Space · Enter로 다음, 마지막 대사는 0.3초 걷힌 뒤', (tester) async {
      _setView(tester, const Size(2560, 1392));
      var next = 0;
      var line = 0;
      late StateSetter setLine;
      await tester.pumpWidget(
        tutorialTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              setLine = setState;
              return PlanaDialogueOverlay(
                scene: tutorialScenes['plana-03']!,
                lineIndex: line,
                onNext: () => next++,
              );
            },
          ),
          reduceMotion: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(next, 1);
      setLine(() => line = 1);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(next, 2, reason: '움직임 줄이기면 걷힘 없이 바로');
    });

    testWidgets('마지막 대사: 걷힘 0.3초 뒤 onNext', (tester) async {
      _setView(tester, const Size(2560, 1392));
      var next = 0;
      await tester.pumpWidget(
        tutorialTestApp(
          PlanaDialogueOverlay(
            scene: tutorialScenes['plana-03']!,
            lineIndex: 1,
            onNext: () => next++,
          ),
        ),
      );
      await tester.tapAt(const Offset(1280, 600));
      await tester.pump();
      await tester.tapAt(const Offset(1280, 600));
      await tester.pump(); // 걷힘 시작 프레임
      await tester.pump(const Duration(milliseconds: 200));
      expect(next, 0);
      await tester.tapAt(const Offset(1280, 600));
      await tester.pump(const Duration(milliseconds: 150));
      expect(next, 1, reason: '걷히는 중 다시 눌러도 한 번만');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('움직임 줄이기면 처음부터 전체 · 캐럿 없음', (tester) async {
      _setView(tester, const Size(2560, 1392));
      await tester.pumpWidget(
        tutorialTestApp(
          PlanaDialogueOverlay(
            scene: tutorialScenes['plana-01']!,
            lineIndex: 2,
            onNext: () {},
          ),
          reduceMotion: true,
        ),
      );
      final state = tester.state<PlanaDialogueOverlayState>(
        find.byType(PlanaDialogueOverlay),
      );
      expect(state.lineComplete, isTrue);
      expect(find.byKey(PlanaDialogueOverlay.nextHintKey), findsOneWidget);
      expect(find.text('튜토리얼 · 시작 · 대사 3 / 5'), findsOneWidget);
      expect(find.text('싯딤의 상자'), findsOneWidget);
      expect(find.text('클릭 · Space · Enter로 다음'), findsOneWidget);
      // 숨쉬기 · ▼ · 캐럿이 모두 멈춰 있어 정착한다(무한 움직임이면 시간 초과).
      await tester.pumpAndSettle();
    });

    testWidgets('뒤 화면 입력을 막고 클릭은 모두 다음 대사', (tester) async {
      _setView(tester, const Size(2560, 1392));
      var back = 0;
      var next = 0;
      var quit = 0;
      await tester.pumpWidget(
        tutorialTestApp(
          PlanaDialogueBoard(
            onBackButton: () => back++,
            onNext: () => next++,
            onQuit: () => quit++,
          ),
          reduceMotion: true,
        ),
      );
      await tester.tap(
        find.byKey(FakeAppScreen.buttonKey),
        warnIfMissed: false,
      );
      expect(back, 0);
      expect(next, 1);
      await tester.tap(find.byKey(PlanaDialogueOverlay.quitKey));
      expect(quit, 1);
      expect(next, 1, reason: '그만두기는 다음 대사로 넘기지 않는다');
    });

    testWidgets('밝히기: 구멍 자리는 어둡지 않고, 아래쪽 대상이면 대사 띠를 반대쪽까지만', (tester) async {
      _setView(tester, const Size(2560, 1392));
      const hole = Rect.fromLTRB(565, 342, 1860, 581);
      final dim = planaDimPath(const Size(2560, 1392), const [hole]);
      expect(dim.contains(hole.center), isFalse);
      expect(dim.contains(const Offset(100, 100)), isTrue);

      await tester.pumpWidget(
        tutorialTestApp(const PlanaDialogueBoard(), reduceMotion: true),
      );
      expect(
        tester.getRect(find.byKey(PlanaDialogueOverlay.bandKey)),
        const Rect.fromLTRB(0, 1030, 2560, 1392),
      );

      // 04b: 오른쪽 아래 대상 → 띠는 왼쪽까지만(대상 왼쪽 − 60).
      const low = Rect.fromLTRB(1800, 993, 2555, 1199);
      await tester.pumpWidget(
        tutorialTestApp(
          const PlanaDialogueBoard(lineIndex: 3, revealRects: [low]),
          reduceMotion: true,
        ),
      );
      final band = tester.getRect(find.byKey(PlanaDialogueOverlay.bandKey));
      expect(band.left, 0);
      expect(band.right, 1740);
      // 08f: 왼쪽 아래 대상 → 띠는 오른쪽에서.
      const lowLeft = Rect.fromLTRB(489, 1003, 911, 1177);
      await tester.pumpWidget(
        tutorialTestApp(
          const PlanaDialogueBoard(
            sceneId: 'plana-08f',
            revealRects: [lowLeft],
          ),
          reduceMotion: true,
        ),
      );
      final right = tester.getRect(find.byKey(PlanaDialogueOverlay.bandKey));
      expect(right.left, 971);
      expect(right.right, 2560);
      expect(tester.takeException(), isNull);
    });

    testWidgets('그림 없음 = 대사 띠만, 그림 있음 = 서 있는 그림 자리', (tester) async {
      _setView(tester, const Size(2560, 1392));
      await tester.pumpWidget(
        tutorialTestApp(const PlanaDialogueBoard(), reduceMotion: true),
      );
      expect(find.byKey(PlanaDialogueOverlay.figureKey), findsNothing);
      await tester.pumpWidget(
        tutorialTestApp(
          PlanaDialogueBoard(figure: tutorialFakeImage),
          reduceMotion: true,
        ),
      );
      expect(find.byKey(PlanaDialogueOverlay.figureKey), findsOneWidget);
      final figure = tester.getRect(find.byKey(PlanaDialogueOverlay.figureKey));
      expect(figure.left, 1950, reason: '04 대사 2 보드 자리');
      expect(figure.size, planaFigureSize);
      expect(tester.takeException(), isNull);
    });
  });

  group('그만두기 확인', () {
    testWidgets('계속하기(기본 · Esc · 스크림) / 그만두기', (tester) async {
      _setView(tester, const Size(2560, 1392));
      var continued = 0;
      var quit = 0;
      await tester.pumpWidget(
        tutorialTestApp(
          TutorialQuitOverlay(
            onContinue: () => continued++,
            onQuit: () => quit++,
          ),
          reduceMotion: true,
        ),
      );
      expect(find.text('튜토리얼을 그만두시겠습니까?'), findsOneWidget);
      expect(find.text("그만두면 임시 계정을 지우고 '메인 계정'으로 돌아갑니다."), findsOneWidget);
      await tester.tap(find.byKey(TutorialQuitPanel.continueKey));
      expect(continued, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(continued, 2);
      await tester.tapAt(const Offset(50, 50));
      expect(continued, 3);
      await tester.tap(find.byKey(TutorialQuitPanel.quitKey));
      expect(quit, 1);
      expect(
        tester.getRect(find.byKey(TutorialQuitPanel.panelKey)),
        const Rect.fromLTWH(790, 550, 980, 290),
      );
    });
  });

  group('1280×720 넘침 0', () {
    testWidgets('카드 4상태 · 한 줄 · 대사 띠(가장 긴 대사) · 확인 창', (tester) async {
      _setView(tester, const Size(1280, 720));
      Future<void> pumpAndCheck(Widget child) async {
        await tester.pumpWidget(tutorialTestApp(child, reduceMotion: true));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      for (final stepId in ['1', '2', '4', '7-2', '7-3', '8']) {
        for (final mode in TutorialCardMode.values) {
          await pumpAndCheck(
            Stack(
              children: [
                Positioned.fill(
                  child: TutorialCardLayer(
                    target: const Rect.fromLTWH(1000, 400, 160, 56),
                    card: TutorialStepCard(
                      step: tutorialSteps[stepId]!,
                      mode: mode,
                      waitDone: 34,
                      waitTotal: 128,
                      onQuit: () {},
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
      await pumpAndCheck(
        Center(
          child: SizedBox(
            width: 347,
            child: TutorialInlineStepLine(
              step: tutorialSteps['5']!,
              onQuit: () {},
            ),
          ),
        ),
      );
      for (final scene in tutorialScenes.values) {
        for (var index = 0; index < scene.lines.length; index++) {
          await pumpAndCheck(
            PlanaDialogueOverlay(
              scene: scene,
              lineIndex: index,
              revealRects: const [Rect.fromLTWH(900, 500, 300, 150)],
              figure: tutorialFakeImage,
              onNext: () {},
              onQuit: () {},
            ),
          );
        }
      }
      await pumpAndCheck(TutorialQuitOverlay(onContinue: () {}, onQuit: () {}));
    });

    testWidgets('대사는 두 줄 안에 들어간다(기준 viewport, 줄임표 없이)', (tester) async {
      _setView(tester, const Size(2560, 1392));
      for (final scene in tutorialScenes.values) {
        for (var index = 0; index < scene.lines.length; index++) {
          await tester.pumpWidget(
            tutorialTestApp(
              PlanaDialogueOverlay(
                scene: scene,
                lineIndex: index,
                onNext: () {},
              ),
              reduceMotion: true,
            ),
          );
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byKey(PlanaDialogueOverlay.textKey),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '${scene.id} 대사 ${index + 1}',
          );
        }
      }
    });
  });

  group('golden 보드 렌더(비교는 CF gate)', () {
    testWidgets('tutorial-card-parts 보드', (tester) async {
      _setView(tester, const Size(2560, 1392));
      await tester.pumpWidget(
        tutorialTestApp(const TutorialCardPartsBoard(), reduceMotion: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TutorialStepCard), findsNWidgets(5));
      expect(find.text('튜토리얼 · 임시 계정'), findsOneWidget);
      expect(find.text('적용했습니다'), findsOneWidget);
      expect(find.text('가상 스캔 중… 34 / 128'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('plana-dialogue 보드', (tester) async {
      _setView(tester, const Size(2560, 1392));
      await tester.pumpWidget(
        tutorialTestApp(const PlanaDialogueBoard(), reduceMotion: true),
      );
      await tester.pumpAndSettle();
      expect(
        find.text("다만 2명은 읽은 값을 확신할 수 없어, '확인 필요'로 따로 모아 두었습니다."),
        findsOneWidget,
      );
      expect(find.text('튜토리얼 · 학생 검토 · 대사 2 / 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
