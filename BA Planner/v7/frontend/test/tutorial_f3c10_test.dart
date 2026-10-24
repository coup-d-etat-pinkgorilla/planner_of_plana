// F3c-10: 사용자 Windows mock 튜토리얼 검수 5건(2026-10-24, 오케스트레이터 로그 13:20).
// ① 4단계: '+' 강조 + 성장 계산기 섹션 보조 강조(실제 섹션 외곽), 카드는 바뀌는 자리(목표 목록 · 크레딧 · 재화 목록)를
//   가리지 않음, '+' 뒤 늘어난 크레딧 · 재화 행 '+n' 강조 · 완료 카드 요약(실제 계산 결과, 계산 전 '—'), 실제 계산기가
//   있으면 완료 체크를 더 오래 보임. 튜토리얼이 꺼져 있으면 계산기 변화 0.
// ② 프라나 08 대사 4의 '씨'(이 문장만).
// ③ 7-2 두 하위 단계: 지금 학생 '한 번에 MAX'(①, 신호 `plan.flow.studentMaxPresetPicked`) → '고른 7명 모두 한 번에
//   MAX로'(②, 신호 `plan.flow.allMaxApplied`).
// ④ 7-2c: '단계 추가' 뒤 카드가 마키 단계 카드(새 2단계 포함)를 가리지 않음(1280 · 2560 겹침 0).
// ⑤ 밝히기 · 강조는 등록된 실제 모양(사선 = 평행사변형 경로, 비교 열 = 섹션 외곽)의 합 — 09d 열 B · C.
import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/student_calculation_service.dart';
import 'package:ba_planner_v7/ui/app_shell.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/focus_ring.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_adapter.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_goal_editor.dart';
import 'package:ba_planner_v7/ui/studio/plan_scenario_compare_studio_layout.dart';
import 'package:ba_planner_v7/ui/tutorial/plana_dialogue.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_flow.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_highlight.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_step_card.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_overlay.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_session.dart';
import 'package:ba_planner_v7/ui/tutorial_targets/tutorial_hooks.dart';
import 'package:ba_planner_v7/ui/widgets/growth_calculator_section.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_goal_step.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_compare.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/f3d_seeded_account.dart';

const _hold = Duration(milliseconds: 60);

/// 레벨 목표 1마다 크레딧 1,000 · 최상급 활동 보고서 1이 더 드는 계산(시험 전용 — Mock 기본 계산은 목표와 상관없는 고정
/// 예시라 늘어나는 것이 없다).
class _GrowingCalculationService extends MockAppService {
  _GrowingCalculationService({super.repositoryStates});

  @override
  Future<StudentCalculationResult> calculateStudent({
    required Map<String, dynamic> currentStudent,
    required Map<String, int> targets,
    Map<String, dynamic>? inventory,
  }) async {
    final base = await super.calculateStudent(
      currentStudent: currentStudent,
      targets: targets,
      inventory: inventory,
    );
    final level = targets['level'] ?? 0;
    final credits = level * 1000;
    return StudentCalculationResult(
      credits: base.credits + credits,
      creditBreakdown: {
        ...base.creditBreakdown,
        'level': (base.creditBreakdown['level'] ?? 0) + credits,
      },
      resources: [
        for (final row in base.resources)
          switch (row.resourceKey) {
            'credits' => _plus(row, credits),
            'Item_Icon_ExpItem_3' => _plus(row, level),
            _ => row,
          },
      ],
      warnings: base.warnings,
      reservedBond: base.reservedBond,
      bond: base.bond,
    );
  }

  static StudentCalculationResource _plus(
    StudentCalculationResource row,
    int amount,
  ) {
    final owned = row.owned;
    final required = row.requiredAmount + amount;
    return StudentCalculationResource(
      resourceKey: row.resourceKey,
      itemId: row.itemId,
      displayName: row.displayName,
      category: row.category,
      requiredAmount: required,
      owned: owned,
      shortage: owned == null
          ? row.shortage
          : (required > owned ? required - owned : 0),
      affectedStageIds: row.affectedStageIds,
    );
  }
}

Future<TutorialSession> _pumpApp(
  WidgetTester tester,
  MockAppService service,
  Size size, {
  Duration hold = _hold,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  addTearDown(service.dispose);
  final session = TutorialSession(service: service, completeHold: hold);
  addTearDown(session.dispose);
  await tester.pumpWidget(
    BAPlannerApp(service: service, tutorial: true, tutorialSession: session),
  );
  await tester.pumpAndSettle();
  return session;
}

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var index = 0; index < count * 10; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

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

/// 완료 체크([doneTitle])가 될 때까지 넘기고, 완료 체크가 끝나 다음 칸으로 갈 때까지 넘긴다.
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
  await tester.pump();
  expect(session.flow!.phase, TutorialPhase.stepComplete);
  expect(find.text(doneTitle), findsOneWidget);
  for (
    var round = 0;
    round < 200 && session.flow!.phase == TutorialPhase.stepComplete;
    round++
  ) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await _frames(tester);
}

Future<void> _toStep(
  WidgetTester tester,
  TutorialSession session,
  String stepId,
) async {
  while (session.flow!.phase == TutorialPhase.dialogue) {
    await _finishScene(tester, session);
  }
  await _frames(tester, 6);
  expect(session.flow?.step?.id, stepId);
}

Rect _cardRect(WidgetTester tester) =>
    tester.getRect(find.byType(TutorialStepCard));

/// 카드가 [key] 대상(조각마다)과 겹치지 않는다.
void _expectCardClear(
  WidgetTester tester,
  TutorialSession session,
  String key,
) {
  final card = _cardRect(tester);
  final rects = session.hooks.registry.rectsOf(key);
  expect(rects, isNotEmpty, reason: key);
  for (final rect in rects) {
    expect(card.overlaps(rect), isFalse, reason: '$key $rect · card $card');
  }
}

/// 화면 크기: 기준 viewport · 1280×720.
final _sizes = ValueVariant<Size>({
  const Size(2560, 1392),
  const Size(1280, 720),
});

/// 1 · 2 · 3단계(실제 동작)를 지나 4단계 카드까지.
Future<TutorialSession> _toCalculatorStep(
  WidgetTester tester,
  MockAppService service,
  Size size, {
  Duration hold = _hold,
}) async {
  final session = await _pumpApp(tester, service, size, hold: hold);
  final origin = (await service.listProfiles()).singleWhere(
    (profile) => profile.selected,
  );
  unawaited(session.start(origin));
  await _frames(tester, 4);
  await _finishScene(tester, session); // 01
  await _finishScene(tester, session); // 02
  await tester.tap(
    find.byKey(
      const ValueKey('home-connect-panel-row-$practiceVirtualTargetId'),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
  await _waitDone(tester, session, '연결했습니다');
  await _toStep(tester, session, '2');
  await tester.tap(find.byKey(const ValueKey('scan-pick-student-full')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
  await _waitDone(tester, session, '스캔을 마쳤습니다');
  await _toStep(tester, session, '3');
  await tester.tap(find.byKey(const ValueKey('scan-review-bulk-apply')));
  await _waitDone(tester, session, '적용했습니다');
  await _toStep(tester, session, '4');
  return session;
}

PlanFlowGoalEditor _goalEditor(WidgetTester tester) =>
    tester.widget<PlanFlowGoalBody>(find.byType(PlanFlowGoalBody)).editor;

String _firstStageId(WidgetTester tester, String studentId) => tester
    .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
    .flow
    .draft
    .stages
    .firstWhere((stage) => stage.studentId == studentId)
    .id;

Future<void> _setSkills(
  WidgetTester tester,
  String stageId,
  List<int> values,
) async {
  final editor = _goalEditor(tester);
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

/// 비교 열 섹션 다각형의 [y]에서 왼쪽 · 오른쪽 변 x(꼭짓점 0 · 3 = 왼쪽 변, 1 · 2 = 오른쪽 변).
({double left, double right}) _columnEdges(List<Offset> polygon, double y) {
  double at(Offset a, Offset b) =>
      a.dx + (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy);
  return (left: at(polygon[0], polygon[3]), right: at(polygon[1], polygon[2]));
}

void main() {
  group('script · flow', () {
    test("plana-08 line 4 drops '씨' in that sentence only", () {
      final line = tutorialScenes['plana-08']!.lines[3];
      expect(
        line.text,
        '비나전에 쓸 일곱 명을 골라 주십시오. 아카네, 칸나(수영복), 마키, 미카, 히마리(무장), 시로코(수영복), '
        '네루(교복)입니다.',
      );
      expect(line.revealKeys, [TutorialTargets.planSelectedStudents]);
      // 다른 대사의 '씨'는 그대로(사용자 결정 대기).
      expect(tutorialScenes['plana-08d']!.lines[1].text, contains('칸나(수영복) 씨'));
      expect(tutorialScenes['plana-09d']!.lines[1].text, contains('마키 씨'));
    });

    test('7-2: the lead (one student MAX) comes first, then the all-MAX '
        'button; the step completes on the all-MAX signal', () {
      final controller = TutorialFlowController(
        flow: const [TutorialStepItem('7-2'), TutorialDoneItem()],
        completeHold: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);
      controller.start();
      final step = controller.step!;
      expect(controller.leadActive, isTrue);
      expect(controller.highlightKey, TutorialTargets.planStudentMaxPreset);
      final shown = tutorialStepForLead(step, leadActive: true);
      expect(shown.title, "먼저 지금 학생의 '한 번에 MAX'를 눌러 주십시오.");
      expect(shown.why, contains('아래 버튼이 꺼져 있습니다'));
      // 다른 신호는 앞 하위 단계를 넘기지 않는다.
      controller.signal(TutorialSignals.planMakiStage1Set);
      expect(controller.leadActive, isTrue);
      controller.signal(TutorialSignals.planStudentMaxPresetPicked);
      expect(controller.leadActive, isFalse);
      expect(controller.phase, TutorialPhase.step);
      expect(controller.highlightKey, TutorialTargets.planAllMaxPreset);
      expect(tutorialStepForLead(step, leadActive: false), same(step));
      // 대본 데이터(F3a 부품 golden의 7-2 카드)는 그대로.
      expect(step.title, "'고른 7명 모두 한 번에 MAX로'를 눌러 주십시오.");
      controller.signal(TutorialSignals.planAllMaxApplied);
      expect(controller.phase, TutorialPhase.stepComplete);
      expect(controller.highlightKey, isNull);
    });

    testWidgets('extendCompleteHold keeps the done card longer once', (
      tester,
    ) async {
      final controller = TutorialFlowController(
        flow: const [TutorialStepItem('4'), TutorialDoneItem()],
        completeHold: const Duration(milliseconds: 100),
      );
      addTearDown(controller.dispose);
      controller.start();
      controller.extendCompleteHold(const Duration(seconds: 1)); // 진행 중엔 무시
      controller.signal(TutorialSignals.studentCalculatorTargetChanged);
      controller.extendCompleteHold(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.phase, TutorialPhase.stepComplete);
      await tester.pump(const Duration(milliseconds: 120));
      expect(controller.phase, TutorialPhase.doneScreen);
    });

    test('calculator change text: pending, values, nothing, rest count', () {
      expect(
        tutorialCalculatorChangeText(
          const TutorialCalculatorChange(targets: ['레벨 목표 +1']),
        ),
        '레벨 목표 +1 → 크레딧 — · 재화 —',
      );
      expect(
        tutorialCalculatorChangeText(
          const TutorialCalculatorChange(
            targets: ['레벨 목표 +1'],
            credits: 12400,
            resources: [(name: '최상급 활동 보고서', amount: 3)],
          ),
        ),
        '레벨 목표 +1 → 크레딧 +12,400 · 최상급 활동 보고서 +3',
      );
      expect(
        tutorialCalculatorChangeText(
          const TutorialCalculatorChange(
            targets: ['레벨 목표 +1'],
            credits: 0,
            resources: [],
          ),
        ),
        '레벨 목표 +1 → 늘어난 재화가 없습니다',
      );
      expect(
        tutorialCalculatorChangeText(
          const TutorialCalculatorChange(
            targets: ['EX 스킬 목표 +1', '기본 스킬 목표 +2'],
            credits: 1000000,
            resources: [
              (name: 'A', amount: 1),
              (name: 'B', amount: 2),
              (name: 'C', amount: 3),
              (name: 'D', amount: 4),
            ],
          ),
        ),
        'EX 스킬 목표 +1 · 기본 스킬 목표 +2 → 크레딧 +1,000,000 · A +1 · B +2 외 2종',
      );
      // 계산기 단계가 아니거나 변화가 없으면 카드는 그대로.
      final step4 = tutorialSteps['4']!;
      expect(tutorialStepForCalculator(step4, null), same(step4));
      expect(
        tutorialStepForCalculator(
          tutorialSteps['3']!,
          const TutorialCalculatorChange(targets: []),
        ),
        same(tutorialSteps['3']),
      );
    });
  });

  group('shapes', () {
    testWidgets('registry: fragments keep their own shape; an outline target '
        'uses its path and its bounds', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final hooks = TutorialHooks();
      addTearDown(hooks.dispose);
      Path diamond(Size size) => Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TutorialHooksScope(
            hooks: hooks,
            child: Stack(
              children: [
                for (final (x, y) in const [(100.0, 100.0), (130.0, 160.0)])
                  Positioned(
                    left: x,
                    top: y,
                    width: 200,
                    height: 40,
                    child: const TutorialTarget(
                      id: 'rows',
                      group: true,
                      child: SizedBox.expand(),
                    ),
                  ),
                Positioned(
                  left: 400,
                  top: 300,
                  width: 200,
                  height: 200,
                  child: TutorialTarget(
                    id: 'diamond',
                    outline: diamond,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final rows = hooks.registry.geometriesOf('rows');
      expect(rows.map((geometry) => geometry.rect), [
        const Rect.fromLTWH(100, 100, 200, 40),
        const Rect.fromLTWH(130, 160, 200, 40),
      ]);
      // 합친 사각형(옛 geometryOf)은 그대로 둔다(카드 자리 · 대사 띠 계산).
      expect(
        hooks.registry.geometryOf('rows')!.rect,
        const Rect.fromLTRB(100, 100, 330, 200),
      );
      final union = tutorialUnionPath([for (final row in rows) row.ringPath])!;
      expect(union.contains(const Offset(200, 120)), isTrue);
      expect(union.contains(const Offset(230, 180)), isTrue);
      // 사선 판: 바깥 사각형의 왼쪽 위 · 오른쪽 아래 모서리는 구멍 밖, 조각 사이 빈 줄(위 조각 아래 5px 테두리 밖)도 밖.
      expect(union.contains(const Offset(101, 101)), isFalse);
      expect(union.contains(const Offset(329, 199)), isFalse);
      expect(union.contains(const Offset(200, 150)), isFalse);
      final diamondGeometry = hooks.registry.geometryOf('diamond')!;
      expect(diamondGeometry.outline, isNotNull);
      expect(diamondGeometry.rect, const Rect.fromLTWH(400, 300, 200, 200));
      expect(diamondGeometry.ringPath.contains(const Offset(500, 400)), isTrue);
      expect(
        diamondGeometry.ringPath.contains(const Offset(410, 310)),
        isFalse,
      );
    });

    test('reveal holes are the union of the shapes (overlap stays lit, the '
        'bounding corners stay dark); a plain rect keeps the F3a hole', () {
      const size = Size(1000, 800);
      Path slanted(Rect rect) => tutorialHighlightPath(rect);
      const a = Rect.fromLTRB(100, 100, 500, 700);
      const b = Rect.fromLTRB(300, 100, 700, 700);
      final reveals = [
        PlanaReveal(a, outline: slanted(a)),
        PlanaReveal(b, outline: slanted(b)),
      ];
      final dim = planaDimPathFor(size, reveals);
      final holes = planaRevealHoles(reveals)!;
      // 두 모양이 겹친 곳은 밝다(evenodd로 다시 어두워지지 않는다).
      const overlap = Offset(400, 400);
      expect(
        slanted(a).contains(overlap) && slanted(b).contains(overlap),
        isTrue,
      );
      expect(holes.contains(overlap), isTrue);
      expect(dim.contains(overlap), isFalse);
      // 위쪽에서 b의 사선 밖이지만 a 안인 곳은 밝다(모양의 합).
      const upper = Offset(320, 104);
      expect(slanted(b).contains(upper), isFalse);
      expect(dim.contains(upper), isFalse);
      // 바깥 사각형 모서리(사선 밖)는 어둡다.
      expect(dim.contains(Offset(a.left + 2, a.top + 2)), isTrue);
      expect(dim.contains(Offset(b.right - 2, b.bottom - 2)), isTrue);
      // 모양 없는 사각형 하나는 F3a 둥근 사각형 구멍 그대로.
      const plain = Rect.fromLTRB(565, 342, 860, 581);
      final legacy = planaDimPath(size, const [plain]);
      final shaped = planaDimPathFor(size, const [PlanaReveal(plain)]);
      for (final point in const [
        Offset(566, 343),
        Offset(570, 350),
        Offset(700, 400),
        Offset(10, 10),
        Offset(859, 580),
      ]) {
        expect(
          shaped.contains(point),
          legacy.contains(point),
          reason: '$point',
        );
      }
    });
  });

  testWidgets(
    'tutorial off: the calculator shows no increases and announces nothing; '
    'on (hooks active) it marks the grown rows',
    (tester) async {
      tester.view.physicalSize = const Size(2560, 1392);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = _GrowingCalculationService(
        repositoryStates: f3dOwnedStudentStates(const ['airi']),
      );
      addTearDown(service.dispose);
      final hooks = TutorialHooks();
      addTearDown(hooks.dispose);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BAPlannerTheme.dark(),
          home: AppShell(service: service, tutorialHooks: hooks),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('top-tab-students')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('student-open-calculator')));
      await tester.pumpAndSettle();
      await tester.pump(growthCalculatorDebounce);
      await tester.pump();
      final increases = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            RegExp(
              r'^calculator-(credits|resource-.+)-increase$',
            ).hasMatch((widget.key! as ValueKey<String>).value),
      );
      final plus = find.byKey(const ValueKey('calculator-row-level-increase'));

      // 꺼짐: 대상 등록은 되지만(렌더 변화 0) 늘어난 표시 · 알림 없음.
      expect(
        hooks.registry.geometryOf(TutorialTargets.calculatorSection)?.outline,
        isNotNull,
      );
      await tester.tap(plus);
      await tester.pump();
      await tester.pump(growthCalculatorDebounce);
      await tester.pump();
      expect(increases, findsNothing);
      expect(
        find.descendant(
          of: find.byType(GrowthCalculatorSection),
          matching: find.byType(KitFocusRing),
        ),
        findsNothing,
      );
      expect(hooks.calculatorChange.value, isNull);

      // 켜짐: 다음 '+'부터 늘어난 행 '+n' · 알림.
      hooks.active.value = true;
      await tester.tap(plus);
      await tester.pump();
      expect(hooks.calculatorChange.value?.calculated, isFalse);
      await tester.pump(growthCalculatorDebounce);
      await tester.pump();
      final change = hooks.calculatorChange.value!;
      expect(change.targets, ['레벨 목표 +1']);
      expect(change.credits, 1000);
      expect(change.resources, [(name: '최상급 활동 보고서', amount: 1)]);
      expect(
        find.byKey(const ValueKey('calculator-credits-increase')),
        findsOneWidget,
      );
      expect(find.text('+1,000'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('calculator-resource-Item_Icon_ExpItem_3-increase'),
        ),
        findsOneWidget,
      );
      // 강조는 잠깐(약 5초) 뒤 걷힌다.
      await tester.pump(growthCalculatorIncreaseHold);
      await tester.pump();
      expect(increases, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('step 4: section + "+" highlighted, card clear of the change area, '
      'grown rows marked and summarised on the done card', (tester) async {
    final size = _sizes.currentValue!;
    // 완료 체크 200ms(계산기가 있으면 ×3 = 600ms) — 디바운스(250ms) 뒤 계산 결과가 완료 카드에 들어오는지 본다.
    const hold = Duration(milliseconds: 200);
    final service = _GrowingCalculationService();
    final session = await _toCalculatorStep(tester, service, size, hold: hold);
    final hooks = session.hooks;
    // 계산기를 열기 전: 섹션이 없어 보조 강조 없음.
    expect(find.byKey(TutorialOverlay.sectionRingKey), findsNothing);
    await tester.tap(find.byKey(const ValueKey('student-open-calculator')));
    await _frames(tester, 4);
    await tester.pump(growthCalculatorDebounce);
    await _frames(tester, 2);

    final section = hooks.registry.geometryOf(
      TutorialTargets.calculatorSection,
    )!;
    final plus = hooks.registry.geometryOf(
      TutorialTargets.calculatorLevelTargetPlus,
    )!;
    expect(section.outline, isNotNull);
    expect(section.ringPath.contains(plus.rect.center), isTrue);
    // 섹션 보조 강조 = 섹션 외곽 경로(사각형이 아니다 — 사선 판 아래 왼쪽 모서리 밖).
    final ring = tester.widget<TutorialPathRing>(
      find.byKey(TutorialOverlay.sectionRingKey),
    );
    expect(ring.secondary, isTrue);
    expect(ring.path.getBounds(), section.rect);
    expect(
      ring.path.contains(section.rect.topLeft + const Offset(2, 2)),
      isFalse,
    );
    // '+'는 주 강조 하나.
    final plusRing = tester.widget<TutorialHighlightRing>(
      find.byType(TutorialHighlightRing),
    );
    expect(plusRing.target, plus.rect);
    // 카드가 바뀌는 자리(목표 목록 · 크레딧 · 재화 목록)를 가리지 않는다.
    final card = _cardRect(tester);
    final area = hooks.registry.rectsOf(TutorialTargets.calculatorChangeArea);
    expect(area, hasLength(3));
    debugPrint('[$size] step4 card $card plus ${plus.rect} area $area');
    if (size == const Size(2560, 1392)) {
      _expectCardClear(tester, session, TutorialTargets.calculatorChangeArea);
    } else {
      // 1280×720: 섹션이 화면 대부분이라 '+'와 크레딧 · 재화 목록만은 가리지 않는다(목표 목록 아래쪽은 덮을 수 있다).
      expect(card.overlaps(plus.rect), isFalse);
      for (final rect in area.skip(1)) {
        expect(card.overlaps(rect), isFalse, reason: '$rect · card $card');
      }
    }

    // '+' → 완료 체크 + 계산 전 요약('—') → 계산 뒤 실제 늘어난 값.
    await tester.tap(
      find.byKey(const ValueKey('calculator-row-level-increase')),
    );
    await tester.pump();
    expect(session.flow!.phase, TutorialPhase.stepComplete);
    expect(find.text('목표를 바꿨습니다'), findsOneWidget);
    expect(find.text('레벨 목표 +1 → 크레딧 — · 재화 —'), findsOneWidget);
    await tester.pump(growthCalculatorDebounce);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    expect(session.flow!.phase, TutorialPhase.stepComplete);
    expect(find.text('레벨 목표 +1 → 크레딧 +1,000 · 최상급 활동 보고서 +1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calculator-credits-increase')),
      findsOneWidget,
    );
    final grown = find.byKey(
      const ValueKey('calculator-resource-Item_Icon_ExpItem_3-increase'),
    );
    expect(grown, findsOneWidget);
    // 늘어난 행은 강조 테두리로 감싼다(카드가 가리지 않음).
    expect(
      find.ancestor(of: grown, matching: find.byType(KitFocusRing)),
      findsOneWidget,
    );
    expect(_cardRect(tester).overlaps(tester.getRect(grown)), isFalse);
    // 섹션 보조 강조는 완료 체크 동안에도 있다.
    expect(find.byKey(TutorialOverlay.sectionRingKey), findsOneWidget);
    // 완료 체크는 계산기가 있으면 hold × 3(시험 600ms).
    await tester.pump(hold);
    expect(session.flow!.phase, TutorialPhase.stepComplete);
    await tester.pump(hold * 2);
    await tester.pump();
    expect(session.flow!.scene?.id, 'plana-06');
    expect(find.byKey(TutorialOverlay.sectionRingKey), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: _sizes);

  testWidgets(
    'plan walk: 7-2 two sub-steps, 7-2c card clear of the Maki stage cards, '
    '09d reveals follow the slanted columns',
    (tester) async {
      final size = _sizes.currentValue!;
      final service = MockAppService();
      final session = await _toCalculatorStep(tester, service, size);
      final hooks = session.hooks;
      // 4 · 5 · 6은 hooks 출구(이 시험의 대상은 계획 장면).
      hooks.signals.emit(TutorialSignals.studentCalculatorTargetChanged);
      await _waitDone(tester, session, '목표를 바꿨습니다');
      await _toStep(tester, session, '5');
      hooks.signals.emit(TutorialSignals.scanItemStarted);
      hooks.signals.emit(TutorialSignals.scanItemFinished);
      await _waitDone(tester, session, '아이템 스캔을 마쳤습니다');
      await _toStep(tester, session, '6');
      hooks.signals.emit(TutorialSignals.itemReviewApplied);
      await _waitDone(tester, session, '적용했습니다');
      await _toStep(tester, session, '7-1');
      await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
      await _waitDone(tester, session, '학생을 골랐습니다');

      // ③ 7-2 ①: 지금 학생의 '한 번에 MAX' 강조, '고른 7명 모두'는 꺼져 있다.
      await _toStep(tester, session, '7-2');
      final flow = session.flow!;
      final segment = find.byKey(const ValueKey('plan-flow-goal-mode-max'));
      final applyAll = find.byKey(const ValueKey('plan-flow-goal-apply-all'));
      expect(flow.leadActive, isTrue);
      expect(flow.highlightKey, TutorialTargets.planStudentMaxPreset);
      expect(find.text("먼저 지금 학생의 '한 번에 MAX'를 눌러 주십시오."), findsOneWidget);
      expect(
        tester
            .widget<TutorialHighlightRing>(find.byType(TutorialHighlightRing))
            .target,
        tester.getRect(segment),
      );
      expect(tester.widget<TonalButton>(applyAll).onPressed, isNull);
      expect(_cardRect(tester).overlaps(tester.getRect(segment)), isFalse);
      await tester.tap(applyAll, warnIfMissed: false); // 꺼진 버튼 — 그대로
      await tester.pump();
      expect(flow.phase, TutorialPhase.step);
      expect(flow.leadActive, isTrue);
      // ① 끝 → ②: '고른 7명 모두 한 번에 MAX로' 강조(이제 켜짐).
      await tester.tap(segment);
      await _frames(tester, 2);
      expect(flow.leadActive, isFalse);
      expect(flow.phase, TutorialPhase.step);
      expect(flow.highlightKey, TutorialTargets.planAllMaxPreset);
      expect(find.text(tutorialSteps['7-2']!.title!), findsOneWidget);
      expect(tester.widget<TonalButton>(applyAll).onPressed, isNotNull);
      expect(
        tester
            .widget<TutorialHighlightRing>(find.byType(TutorialHighlightRing))
            .target,
        hooks.registry.geometryOf(TutorialTargets.planAllMaxPreset)!.rect,
      );
      expect(_cardRect(tester).overlaps(tester.getRect(applyAll)), isFalse);
      await tester.tap(applyAll);
      await _waitDone(tester, session, 'MAX로 맞췄습니다');

      // ④ 08g 대사 2 밝히기(마키 1단계 스킬 칸)는 대사 띠와 겹치지 않는다.
      expect(session.flow!.scene?.id, 'plana-08g');
      session.flow!.advanceLine();
      await _frames(tester, 3);
      final stage1 = hooks.registry.geometryOf(
        TutorialTargets.planMakiStage1Skills,
      )!;
      final band = tester.getRect(find.byKey(PlanaDialogueOverlay.bandKey));
      expect(stage1.rect.overlaps(band), isFalse, reason: '$stage1 · $band');
      await _toStep(tester, session, '7-2b');
      await _setSkills(tester, _firstStageId(tester, 'maki'), [5, 10, 1, 1]);
      await _waitDone(tester, session, '1단계를 정했습니다');

      // ④ 7-2c: '단계 추가' 전 · 뒤 모두 카드가 마키 단계 카드(새 2단계 포함)를 가리지 않는다.
      expect(session.flow!.step?.id, '7-2c');
      _expectCardClear(tester, session, TutorialTargets.planMakiStageCards);
      await tester.tap(find.byKey(const ValueKey('plan-flow-goal-add-stage')));
      await _frames(tester, 3);
      final stages = _goalEditor(tester).stagesOf('maki');
      expect(stages, hasLength(2));
      expect(
        hooks.registry.rectsOf(TutorialTargets.planMakiStageCards),
        hasLength(2),
      );
      final stage2 = tester.getRect(
        find.byKey(ValueKey('plan-flow-goal-card-${stages.last.id}')),
      );
      debugPrint('[$size] 7-2c card ${_cardRect(tester)} stage2 $stage2');
      _expectCardClear(tester, session, TutorialTargets.planMakiStageCards);
      expect(_cardRect(tester).overlaps(stage2), isFalse);
      expect(
        _cardRect(tester).overlaps(
          hooks.registry.geometryOf(TutorialTargets.planMakiAddStage)!.rect,
        ),
        isFalse,
      );
      await _setSkills(tester, stages.last.id, [5, 10, 7, 7]);
      await _waitDone(tester, session, '2단계를 더했습니다');

      // 7-3 ~ 7-5는 hooks 출구, 7-6 · 8은 실제.
      for (final (step, signal, done) in const [
        ('7-3', TutorialSignals.planRanksPlaced, '순위를 정했습니다'),
        ('7-4', TutorialSignals.planKannaAkaneLinked, '이어 붙였습니다'),
        ('7-5', TutorialSignals.planLaterMoved, '나중으로 옮겼습니다'),
      ]) {
        await _toStep(tester, session, step);
        hooks.signals.emit(signal);
        await _waitDone(tester, session, done);
      }
      await _toStep(tester, session, '7-6');
      await tester.tap(find.byKey(const ValueKey('plan-flow-save-confirm')));
      await _waitDone(tester, session, '시나리오로 저장했습니다');
      await _toStep(tester, session, '8');
      final compare = find.byKey(const ValueKey('plan-scenario-compare-run'));
      if (tester.getRect(compare).bottom <= size.height) {
        await tester.tap(compare);
      } else {
        hooks.signals.emit(TutorialSignals.scenarioCompareOpened);
      }
      await _waitDone(tester, session, '나란히 비교했습니다');

      // ⑤ 09d 대사 2: 열 B · C 밝히기 = 두 열 섹션 외곽의 합.
      expect(session.flow!.scene?.id, 'plana-09d');
      session.flow!.advanceLine();
      await _frames(tester, 3);
      expect(session.flow!.revealKeys, [
        TutorialTargets.scenarioCompareColumnB,
        TutorialTargets.scenarioCompareColumnC,
      ]);
      final overlay = tester.widget<PlanaDialogueOverlay>(
        find.byType(PlanaDialogueOverlay),
      );
      expect(overlay.revealRects, isEmpty);
      expect(overlay.reveals, hasLength(2));
      expect(overlay.reveals.every((reveal) => reveal.outline != null), isTrue);
      final holes = planaRevealHoles(overlay.reveals)!;
      final dim = planaDimPathFor(size, overlay.reveals);
      final view = tester.getRect(find.byType(PlanScenarioCompareView));
      final b = [
        for (final point in planCompareSectionPolygon(
          view.size,
          planCompareColumnSectionId(1),
        ))
          point + view.topLeft,
      ];
      final c = [
        for (final point in planCompareSectionPolygon(
          view.size,
          planCompareColumnSectionId(2),
        ))
          point + view.topLeft,
      ];
      final geometryB = hooks.registry.geometryOf(
        TutorialTargets.scenarioCompareColumnB,
      )!;
      final geometryC = hooks.registry.geometryOf(
        TutorialTargets.scenarioCompareColumnC,
      )!;
      debugPrint(
        '[$size] 09d B ${geometryB.rect} C ${geometryC.rect} band '
        '${tester.getRect(find.byKey(PlanaDialogueOverlay.bandKey))}',
      );
      final y = (geometryB.rect.top + geometryB.rect.bottom) / 2;
      final edgesB = _columnEdges(b, y);
      final edgesC = _columnEdges(c, y);
      // 열 안은 밝다.
      expect(
        holes.contains(Offset((edgesB.left + edgesB.right) / 2, y)),
        isTrue,
      );
      expect(
        holes.contains(Offset((edgesC.left + edgesC.right) / 2, y)),
        isTrue,
      );
      expect(
        dim.contains(Offset((edgesB.left + edgesB.right) / 2, y)),
        isFalse,
      );
      // 두 열 사이 틈(사선 판 밖)은 어둡다 — 직사각형 구멍이면 밝았던 곳.
      final gap = Offset((edgesB.right + edgesC.left) / 2, y);
      expect(edgesC.left - edgesB.right, greaterThan(4));
      expect(
        geometryB.rect.contains(gap) || geometryC.rect.contains(gap),
        isTrue,
      );
      expect(holes.contains(gap), isFalse);
      expect(dim.contains(gap), isTrue);
      // 바깥 사각형의 사선 밖 모서리는 어둡다.
      final topLeftB = geometryB.rect.topLeft + const Offset(4, 4);
      expect(dim.contains(topLeftB), isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: _sizes,
  );
}
