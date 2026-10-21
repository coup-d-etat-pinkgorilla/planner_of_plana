// F3c-6: Mock 튜토리얼 남은 빈틈 — 카드 자리 규칙 7(빈자리 · 가장 적게 겹치는 자리), 9단계 문구(부족 1위 행 실제 이름 ·
// 조사 · 읽는 중 · 빈 목록 대체 문구), 등록표 조각 사각형 · 대상 이름, 시나리오 → 활성 계획("이걸로 바꾸기" 경로),
// 세션의 프라나 10 적용(실패 안내 포함) · 9단계 빈 목록 넘어가기 · 10단계 통계 탭 열기.
// 1~10단계 실제 화면 동작 한 바퀴(7-3 끌어 놓기 · 9 · 10 실제, 2560×1392 · 1280×720)는 `tutorial_host_f3c3_test.dart`의
// "Mock walkthrough"가 본다.
import 'dart:async';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_save.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_card_placement.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_flow.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_step_card.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_overlay.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_session.dart';
import 'package:ba_planner_v7/ui/tutorial_targets/tutorial_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _hold = Duration(milliseconds: 60);

/// 활성 계획 바꾸기가 실패하는 Mock.
class _ReplaceFailService extends MockAppService {
  @override
  Future<RepositoryPlanReplaceResult> replaceRepositoryPlan({
    required String profileId,
    required PlanningDocument document,
    PlanningAuthoring? authoring,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
    required String archiveName,
    required String archiveDescription,
  }) async => throw StateError('replace failed');
}

Future<RepositoryProfile> _origin(MockAppService service) async =>
    (await service.listProfiles()).singleWhere((profile) => profile.selected);

/// 겹친 넓이 합.
double _covered(Rect rect, List<Rect> others) {
  var area = 0.0;
  for (final other in others) {
    if (!rect.overlaps(other)) continue;
    final shared = rect.intersect(other);
    area += shared.width * shared.height;
  }
  return area;
}

/// 선택 계정에 v2 시나리오 [name](학생 [studentId] 한 명, 한 페이즈)을 만들고 id를 준다.
Future<String> _createScenario(
  MockAppService service,
  String profileId,
  String name,
  String studentId,
) async {
  final state = await service.loadRepositoryState(profileId);
  final list = await service.listScenarios(profileId);
  await service.createScenario(
    profileId: profileId,
    expectedRevision: list.revision,
    idempotencyKey: 'f3c6-$name',
    name: name,
    description: '',
    baseProfileRevision: state.revision,
    document: PlanningDocument(
      id: 'f3c6-$name',
      name: name,
      kind: PlanningDocumentKind.scenario,
      version: 2,
      goalMetadata: {studentId: planFlowDefaultGoalMetadata},
      phases: [
        PlanningDocumentPhase(
          id: 'f3c6-$name-phase',
          name: '1순위',
          stages: [
            PlanningDocumentStage(
              id: 'f3c6-$name-stage',
              studentId: studentId,
              name: '목표',
              targets: {
                for (final key in planningDocumentTargetKeys) key: null,
                'level': 2,
              },
            ),
          ],
        ),
      ],
    ),
  );
  final after = await service.listScenarios(profileId);
  return after.scenarios.singleWhere((scenario) => scenario.name == name).id;
}

/// 흐름을 [until]이 참이 될 때까지 넘긴다(대사는 다음 줄, 단계는 완료 신호 — 화면 없이).
Future<void> _advanceUntil(
  WidgetTester tester,
  TutorialSession session,
  bool Function(TutorialFlowController flow) until,
) async {
  for (var round = 0; round < 400; round++) {
    final flow = session.flow!;
    if (until(flow)) return;
    if (flow.phase == TutorialPhase.dialogue) {
      flow.advanceLine();
    } else if (flow.phase == TutorialPhase.step) {
      flow.signal(flow.step!.completeSignal);
    }
    await tester.pump(_hold * 2);
  }
  fail('flow did not reach the expected point');
}

void main() {
  group('카드 자리 규칙 7(F3c-6)', () {
    const card = Size(620, 220);
    const bounds = Rect.fromLTRB(0, 184, 2560, 1392);
    const target = Rect.fromLTWH(600, 330, 400, 150);

    test('네 후보가 모두 막히면 대상 · 피할 자리와 겹치지 않는 가장 가까운 빈자리', () {
      final avoid = <Rect>[
        const Rect.fromLTWH(1020, 330, 800, 150), // 오른쪽 카드 줄
        const Rect.fromLTWH(450, 500, 1400, 150), // 아래 카드 줄
        const Rect.fromLTWH(0, 184, 560, 1208), // 왼쪽 레일
      ];
      final first = placeTutorialCard(
        target: target,
        card: card,
        bounds: bounds,
      );
      expect(avoid.any(first.rect.overlaps), isTrue, reason: 'F3a 자리는 가린다');
      final placement = placeTutorialCard(
        target: target,
        card: card,
        bounds: bounds,
        avoid: avoid,
      );
      expect(placement.rect.overlaps(target), isFalse);
      for (final rect in avoid) {
        expect(placement.rect.overlaps(rect), isFalse, reason: '$rect');
      }
      expect(bounds.contains(placement.rect.topLeft), isTrue);
      expect(bounds.contains(placement.rect.bottomRight), isTrue);
      expect(placement.nubSide, isNotNull);
    });

    test('빈자리가 없으면 피할 자리와 가장 적게 겹치는 자리(대상은 덮지 않음)', () {
      // 화면 대부분을 덮는 칸 셋(오른쪽 끝 띠만 조금 비어 있음).
      final avoid = <Rect>[
        const Rect.fromLTWH(480, 200, 1500, 400),
        const Rect.fromLTWH(480, 610, 1500, 400),
        const Rect.fromLTWH(480, 1020, 1500, 360),
      ];
      final first = placeTutorialCard(
        target: target,
        card: card,
        bounds: bounds,
      );
      final placement = placeTutorialCard(
        target: target,
        card: card,
        bounds: bounds,
        avoid: avoid,
      );
      expect(placement.rect.overlaps(target), isFalse);
      expect(
        _covered(placement.rect, avoid),
        lessThan(_covered(first.rect, avoid)),
      );
      expect(placement.nubSide, isNotNull);
    });

    test('피할 자리가 없으면 F3a 자리 그대로', () {
      expect(
        placeTutorialCard(target: target, card: card, bounds: bounds),
        placeTutorialCard(
          target: target,
          card: card,
          bounds: bounds,
          avoid: const [],
        ),
      );
    });

    test('7-3 · 7-4 · 7-5만 피할 자리를 가진다', () {
      expect(tutorialSteps['7-3']!.avoidKeys, [
        TutorialTargets.planOrderCards,
        TutorialTargets.planOrderRankColumns,
      ]);
      expect(tutorialSteps['7-4']!.avoidKeys, [TutorialTargets.planOrderCards]);
      expect(tutorialSteps['7-5']!.avoidKeys, [
        TutorialTargets.planOrderCards,
        TutorialTargets.planOrderLaterLane,
      ]);
      for (final step in tutorialSteps.values) {
        if (const {'7-3', '7-4', '7-5'}.contains(step.id)) continue;
        expect(step.avoidKeys, isEmpty, reason: step.id);
      }
    });
  });

  group('9단계 문구(FD-182 보충 ⑤)', () {
    test('목적격 조사: 받침 · 괄호 · 한글 아님', () {
      expect(koreanEulReul(tutorialTopShortageSample), '를');
      expect(koreanEulReul('기술 노트 (최상급)'), '을');
      expect(koreanEulReul('크레딧'), '을');
      expect(koreanEulReul('다목적 헤어핀'), '을');
      expect(koreanEulReul('엘리그마'), '를');
      expect(koreanEulReul('BD'), '(을)를');
      expect(koreanEulReul(''), '(을)를');
    });

    test('대본 데이터는 그대로(예시 이름이 자리 표시), 보일 때 실제 이름으로', () {
      final step = tutorialSteps['9']!;
      expect(step.title, "맨 위 '$tutorialTopShortageSample'를 눌러 보십시오.");
      final named = tutorialStepForShortage(step, topName: '기술 노트 (최상급)');
      expect(named.title, "맨 위 '기술 노트 (최상급)'을 눌러 보십시오.");
      expect(named.why, step.why);
      expect(named.highlightKey, step.highlightKey);
      expect(named.doneTitle, step.doneTitle);
      expect(named.cardWidth, step.cardWidth);
      expect(tutorialStepForShortage(step).title, tutorialTopShortagePending);
      final empty = tutorialStepForShortage(step, topName: '무시됨', empty: true);
      expect(empty.title, tutorialShortageEmptyTitle);
      expect(empty.why, tutorialShortageEmptyWhy);
      expect(empty.doneTitle, tutorialShortageEmptyDone);
      // 다른 단계는 같은 객체.
      final other = tutorialSteps['10']!;
      expect(
        identical(tutorialStepForShortage(other, topName: 'x'), other),
        isTrue,
      );
    });
  });

  group('등록표 조각 · 이름(F3c-6)', () {
    testWidgets('조각마다 사각형, 보이는 대상의 이름, 이름이 바뀌면 알림', (tester) async {
      final hooks = TutorialHooks();
      addTearDown(hooks.dispose);
      var notified = 0;
      hooks.registry.addListener(() => notified += 1);
      Widget tree(String label) => Directionality(
        textDirection: TextDirection.ltr,
        child: TutorialHooksScope(
          hooks: hooks,
          child: Stack(
            children: [
              Positioned(
                left: 10,
                top: 10,
                width: 100,
                height: 40,
                child: TutorialTarget(
                  id: 'cards',
                  group: true,
                  child: TutorialTarget(
                    id: 'row',
                    label: label,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const Positioned(
                left: 300,
                top: 10,
                width: 100,
                height: 40,
                child: TutorialTarget(
                  id: 'cards',
                  group: true,
                  child: SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree('첫 이름'));
      await tester.pump();
      expect(hooks.registry.rectsOf('cards'), [
        const Rect.fromLTWH(10, 10, 100, 40),
        const Rect.fromLTWH(300, 10, 100, 40),
      ]);
      expect(
        hooks.registry.geometryOf('cards')!.rect,
        const Rect.fromLTRB(10, 10, 400, 50),
      );
      expect(hooks.registry.rectsOf('row'), [
        const Rect.fromLTWH(10, 10, 100, 40),
      ]);
      expect(hooks.registry.rectsOf('missing'), isEmpty);
      expect(hooks.registry.labelOf('row'), '첫 이름');
      expect(hooks.registry.labelOf('cards'), isNull);
      final before = notified;
      await tester.pumpWidget(tree('둘째 이름'));
      await tester.pump();
      expect(hooks.registry.labelOf('row'), '둘째 이름');
      expect(notified, greaterThan(before));
      expect(hooks.registry.duplicateWarnings, isEmpty);
    });
  });

  group('시나리오 → 활성 계획(이걸로 바꾸기 경로)', () {
    test('시나리오 문서를 활성 계획으로, 기존 활성 계획이 있으면 시나리오로 옮겨 둔다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final origin = await _origin(service);
      final first = await _createScenario(service, origin.id, '첫 안', 'aru');
      final before = await service.loadRepositoryPlan(origin.id);
      expect(before.document.phases, isEmpty);
      final archived = await planFlowReplaceActivePlanWithScenario(
        service,
        profileId: origin.id,
        scenarioId: first,
        idempotencyKey: 'f3c6-apply-1',
      );
      expect(archived, isNull, reason: '빈 활성 계획은 옮기지 않는다');
      final plan = await service.loadRepositoryPlan(origin.id);
      expect(plan.document.kind, PlanningDocumentKind.plan);
      expect(plan.document.id, before.document.id);
      expect(plan.document.name, before.document.name);
      expect(plan.document.phases.single.stages.single.studentId, 'aru');

      final second = await _createScenario(service, origin.id, '둘째 안', 'hina');
      final moved = await planFlowReplaceActivePlanWithScenario(
        service,
        profileId: origin.id,
        scenarioId: second,
        idempotencyKey: 'f3c6-apply-2',
      );
      expect(moved, isNotNull);
      final names = [
        for (final scenario in (await service.listScenarios(
          origin.id,
        )).scenarios)
          scenario.name,
      ];
      expect(names, contains(planFlowDefaultArchiveName));
      expect(
        (await service.loadRepositoryPlan(
          origin.id,
        )).document.phases.single.stages.single.studentId,
        'hina',
      );
    });

    test('계획 저장소가 아니면 보내지 않는다', () async {
      expect(
        () => planFlowReplaceActivePlanWithScenario(
          Object(),
          profileId: 'p',
          scenarioId: 's',
          idempotencyKey: 'k',
        ),
        throwsStateError,
      );
    });
  });

  group('세션: 프라나 10 적용 · 9 빈 목록 · 10 통계 탭', () {
    testWidgets('프라나 10에서 임시 계정에만 시나리오를 활성 계획으로 적용하고 인벤토리를 연다', (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final session = TutorialSession(service: service, completeHold: _hold);
      addTearDown(session.dispose);
      final origin = await _origin(service);
      unawaited(session.start(origin));
      await tester.pump(_hold);
      await _advanceUntil(
        tester,
        session,
        (flow) => flow.scene?.id == tutorialPlanApplyScene,
      );
      await tester.pump(_hold);
      await tester.pump(_hold);
      // 7-6 저장이 없으면(화면 없이 넘김) 임시 계정의 가장 늦게 고친 시나리오(예시 안 — v1 문서라 v2 계획으로 옮긴다)를 쓴다.
      expect(session.planApplied, isTrue, reason: session.notice);
      expect(session.notice, isNull);
      expect(session.navigation!.section, AppSection.inventory);
      final practiceId = session.practice!.profileId;
      expect(
        (await service.loadRepositoryPlan(practiceId)).document.phases,
        isNotEmpty,
      );
      expect(
        (await service.loadRepositoryPlan(origin.id)).document.phases,
        isEmpty,
      );
      // 10은 앞 장면이 없어 단계가 통계 탭을 연다.
      await _advanceUntil(tester, session, (flow) => flow.step?.id == '10');
      await tester.pump();
      expect(session.navigation!.section, AppSection.statistics);
    });

    testWidgets('적용이 실패하면 안내를 보이고 인벤토리는 그대로 연다', (tester) async {
      final service = _ReplaceFailService();
      addTearDown(service.dispose);
      final session = TutorialSession(service: service, completeHold: _hold);
      addTearDown(session.dispose);
      unawaited(session.start(await _origin(service)));
      await tester.pump(_hold);
      await _advanceUntil(
        tester,
        session,
        (flow) => flow.scene?.id == tutorialPlanApplyScene,
      );
      await tester.pump(_hold);
      await tester.pump(_hold);
      expect(session.planApplied, isFalse);
      expect(session.notice, startsWith(tutorialPlanApplyFailedNotice));
      expect(session.navigation!.section, AppSection.inventory);
    });

    testWidgets('9단계: 1위 행 이름을 카드에 쓰고, 목록이 비면 대체 문구로 넘어간다', (tester) async {
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
      final session = TutorialSession(service: service, completeHold: _hold);
      addTearDown(session.dispose);
      unawaited(session.start(await _origin(service)));
      await tester.pump(_hold);
      await _advanceUntil(tester, session, (flow) => flow.step?.id == '9');

      Widget screen({required bool rows}) => MediaQuery(
        data: const MediaQueryData(size: Size(2560, 1392)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TutorialHost(
            session: session,
            child: TutorialHooksScope(
              hooks: session.hooks,
              child: Stack(
                children: [
                  Positioned(
                    left: 600,
                    top: 500,
                    width: 900,
                    height: 58,
                    child: rows
                        ? const TutorialTarget(
                            id: TutorialTargets.inventoryShortageTopRow,
                            label: '기술 노트 (최상급)',
                            child: SizedBox.expand(),
                          )
                        : const TutorialTarget(
                            id: TutorialTargets.inventoryShortageEmpty,
                            child: SizedBox.expand(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(rows: true));
      await tester.pump();
      await tester.pump();
      expect(find.text("맨 위 '기술 노트 (최상급)'을 눌러 보십시오."), findsOneWidget);
      expect(session.shortageEmpty, isFalse);
      expect(session.flow!.phase, TutorialPhase.step);

      await tester.pumpWidget(screen(rows: false));
      await tester.pump();
      await tester.pump();
      expect(session.shortageEmpty, isTrue);
      expect(session.flow!.phase, TutorialPhase.stepComplete);
      expect(find.text(tutorialShortageEmptyDone), findsOneWidget);
      expect(find.byType(TutorialStepCard), findsOneWidget);
      await tester.pump(_hold * 2);
      await tester.pump();
      expect(session.flow!.step?.id, '10');
      expect(tester.takeException(), isNull);
      // 덧그림을 내린다(세션 dispose 전에).
      await tester.pumpWidget(const SizedBox());
    });
  });
}
