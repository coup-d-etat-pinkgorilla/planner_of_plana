// 계획 만들기 1단계 한 명 모드(FE4-b2, 시안 Flow-1-Students-One, FD-177 (a)) 테스트: 전환 규칙, 한 명 모양 Studio
// 좌표(±1px), "이미 잡혀 있는 목표" 읽기(활성 계획 문서, 읽기만), 흐름 화면의 360ms 보간 · 짧은 C · 학생 탭 S3 겹침,
// "이 학생 목표 정하기", 빈 상태, 1280×720 넘침 없음.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_student_fixture.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_order_editor.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/studio/plan_flow_studio_layout.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_order_step.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_rail.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_student_one.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_student_step.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:ba_planner_v7/ui/widgets/student_form_cycle.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 콘텐츠 캔버스(기준 viewport 2560×1392에서 헤더 184 아래).
const _canvas = Size(2560, 1208);

PlanningDocumentStage _stage(
  String id,
  String studentId,
  Map<String, int?> targets,
) => PlanningDocumentStage(
  id: id,
  studentId: studentId,
  name: '목표',
  targets: {
    for (final key in planningDocumentTargetKeys) key: null,
    ...targets,
  },
);

/// [studentId]의 두 단계(P1 레벨 → P2 EX·인연)와 다른 학생 한 단계를 가진 활성 계획.
PlanningDocument _activePlan(String studentId, {String other = 'other'}) =>
    PlanningDocument(
      id: 'active-plan',
      name: '활성 계획',
      kind: PlanningDocumentKind.plan,
      version: 2,
      phases: [
        PlanningDocumentPhase(
          id: 'p1',
          name: '페이즈 1',
          stages: [
            _stage('$other-1', other, {'level': 90}),
            _stage('$studentId-1', studentId, {'level': 90}),
          ],
        ),
        PlanningDocumentPhase(
          id: 'p2',
          name: '페이즈 2',
          stages: [
            _stage('$studentId-2', studentId, {
              'ex_skill': 5,
              'bond_rank': 100,
            }),
          ],
        ),
      ],
    );

class _Fixture {
  _Fixture(this.service, this.flow, this.owned, this.other);

  final MockAppService service;
  final PlanFlowController flow;

  /// 보유 학생(아루, 인연 1 · 레벨 1 · EX 1) — 활성 계획에 두 단계가 있다.
  final String owned;

  /// 활성 계획에 단계가 없는 학생.
  final String other;
}

Future<_Fixture> _fixture({bool withPlan = true}) async {
  final service = MockAppService();
  addTearDown(service.dispose);
  final profile = (await service.listProfiles()).firstWhere(
    (profile) => profile.selected,
  );
  // 보유 학생 하나(아루, mock 고정 값: 레벨 1 · 인연 1 · EX 1)를 확정 현재값으로 저장한다.
  const owned = 'aru';
  final values = Map<String, dynamic>.from(
    buildMockOwnedStudents().firstWhere(
          (wire) => wire['student_id'] == owned,
        )['values']
        as Map,
  );
  await service.saveRepositoryStudents(
    profile.id,
    [ConfirmedStudentState.fromValues(owned, values)],
    (await service.loadRepositoryState(profile.id)).revision,
    'plan-flow-student-one-students',
  );
  final state = await service.loadRepositoryState(profile.id);
  final catalog = await service.listStudents();
  final other = catalog
      .firstWhere((entry) => entry.studentId != owned)
      .studentId;
  final context = PlanFlowContext(
    repositoryState: state,
    catalog: {for (final entry in catalog) entry.studentId: entry},
    activePlan: withPlan ? _activePlan(owned, other: 'not-in-catalog') : null,
  );
  final flow = PlanFlowController(
    purpose: PlanFlowPurpose.newScenario,
    context: context,
    service: service,
  );
  addTearDown(flow.dispose);
  return _Fixture(service, flow, owned, other);
}

Future<void> _pumpWorkspace(
  WidgetTester tester,
  _Fixture fixture, {
  Size view = const Size(2560, 1392),
  Size? canvas = _canvas,
}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = PlanFlowWorkspace(
    flow: fixture.flow,
    service: fixture.service,
    onClosed: (_) {},
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: canvas == null
            ? workspace
            : Align(
                alignment: Alignment.topLeft,
                child: SizedBox.fromSize(size: canvas, child: workspace),
              ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(AppMotion.section);
  await tester.pump();
}

Future<void> _tapCard(WidgetTester tester, String studentId) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('plan-flow-student-grid')),
      matching: find.byKey(ValueKey('student-$studentId')),
    ),
  );
  await tester.pump();
}

/// 보간과 디바운스 계산을 끝낸다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(planFlowOneModeDuration);
  await tester.pump(planFlowCalculationDebounce);
  await tester.pumpAndSettle();
}

double _modeValue(WidgetTester tester) => tester
    .widget<PlanFlowStudentBody>(find.byType(PlanFlowStudentBody))
    .oneMode!
    .value;

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 1));
  expect(actual.top, closeTo(expected.top, 1));
  expect(actual.right, closeTo(expected.right, 1));
  expect(actual.bottom, closeTo(expected.bottom, 1));
}

void main() {
  setUp(() => StudentFormClock.instance.freeze(0));
  tearDown(() => StudentFormClock.instance.freeze(null));

  test('한 명 모드는 1단계에서 정확히 한 명을 골랐을 때만이다', () async {
    final fixture = await _fixture();
    final flow = fixture.flow;
    expect(planFlowOneMode(flow), isFalse);
    flow.toggleStudent(fixture.owned);
    expect(planFlowOneMode(flow), isTrue);
    flow.toggleStudent(fixture.other);
    expect(planFlowOneMode(flow), isFalse);
    flow.removeStudent(fixture.other);
    expect(planFlowOneMode(flow), isTrue);
    flow.goTo(PlanFlowStep.goals);
    expect(flow.step, PlanFlowStep.goals);
    expect(planFlowOneMode(flow), isFalse);
  });

  test('한 명 모양 B·C는 시안 Flow-1-Students-One 섹션과 ±1px 안이다', () {
    // 시안 path(헤더 184 아래로 옮김, 둥글리기 전 꼭짓점):
    // B `M 222.6 0.0 … L 1581.2 0.0 … 1386.7 1182.8 … 14.0 1182.8` + (400, 209.2) → 윗변 608.6~1995.2, 아랫변 400~1786.7.
    // C `M 604.7 14.0 … L 14.0 352.3 … L 59.7 13.8 Q 62.1 0.0` + (1955.3, 209.2) → 위 2017.4, 아래 1955.3, 바닥 377.5.
    void expectPoints(List<Offset> actual, List<Offset> expected) {
      expect(actual, hasLength(expected.length));
      for (var index = 0; index < expected.length; index++) {
        expect(actual[index].dx, closeTo(expected[index].dx, 1));
        expect(actual[index].dy, closeTo(expected[index].dy, 1));
      }
    }

    expectPoints(planFlowSectionPolygon(_canvas, planFlowBodyOneSectionId), [
      const Offset(608.6, 25.2),
      const Offset(1995.2, 25.2),
      const Offset(1786.7, 1208),
      const Offset(400, 1208),
    ]);
    expectPoints(planFlowSectionPolygon(_canvas, planFlowAsideOneSectionId), [
      const Offset(2560, 25.2),
      const Offset(2560, 377.5),
      const Offset(1955.3, 377.5),
      const Offset(2017.4, 25.2),
    ]);
    final aside = planFlowSectionPath(
      _canvas,
      planFlowAsideOneSectionId,
    ).getBounds();
    expect(aside.top, closeTo(25.2, 1));
    expect(aside.bottom, closeTo(377.5, 1));
    expect(aside.right, closeTo(2560, 1));
    // 학생 탭 S3 자리(시안 `.stusec` 1813.3, 586.7, 746.7, 780.2).
    _expectRect(
      studentSectionRect(_canvas, 'element-3'),
      const Rect.fromLTWH(1813.3, 402.7, 746.7, 780.2),
    );
    // 보간 끝값은 Studio path 그대로다.
    expect(
      planFlowModeSectionPath(
        _canvas,
        planFlowAsideSectionId,
        planFlowAsideOneSectionId,
        0,
      ).getBounds(),
      planFlowSectionPath(_canvas, planFlowAsideSectionId).getBounds(),
    );
    final half = planFlowModeSectionPath(
      _canvas,
      planFlowAsideSectionId,
      planFlowAsideOneSectionId,
      0.5,
    ).getBounds();
    // 아랫변: 여러 명 1208 ↔ 한 명 377.5의 가운데.
    expect(half.bottom, closeTo((1208 + 377.5) / 2, 2));
  });

  test('"이미 잡혀 있는 목표"는 활성 계획 문서에서 그 학생 단계만 읽고 문서를 바꾸지 않는다', () async {
    final fixture = await _fixture();
    final context = fixture.flow.context;
    final before = context.activePlan!.toWire().toString();
    final stages = context.activeStagesOf(fixture.owned);
    expect(stages, hasLength(2));
    expect(
      [for (final stage in stages) (stage.phaseNumber, stage.stageNumber)],
      [(1, 1), (2, 2)],
    );
    expect(stages.first.targets['level'], 90);
    // 2단계 목표의 null 레벨은 앞 단계 값(90)이다. 앞 단계 snapshot이 다음 줄의 기준이다.
    expect(stages.last.before, stages.first.targets);
    expect(stages.last.targets['level'], 90);
    expect(stages.last.targets['ex_skill'], 5);
    expect(
      planFlowOrderGoalSummary(
        planFlowGoalChanges(stages.first.before, stages.first.targets),
        owned: true,
      ),
      'Lv.90',
    );
    expect(
      planFlowOrderGoalSummary(
        planFlowGoalChanges(stages.last.before, stages.last.targets),
        owned: true,
      ),
      startsWith('EX5'),
    );
    expect(context.activeStagesOf(fixture.other), isEmpty);
    expect(
      planFlowActiveStudentStages(
        null,
        fixture.owned,
        context.seedFor(fixture.owned),
      ),
      isEmpty,
    );
    expect(context.activePlan!.toWire().toString(), before);
    // 초안은 비어 있다(읽기만).
    expect(fixture.flow.draft.hasStages, isFalse);
  });

  testWidgets('한 명을 고르면 B·C가 360ms 동안 한 명 모양으로 바뀌고 학생 탭 S3가 겹친다', (
    tester,
  ) async {
    final fixture = await _fixture();
    await _pumpWorkspace(tester, fixture);
    expect(_modeValue(tester), 0);
    expect(find.byKey(const ValueKey('plan-flow-one-aside')), findsNothing);
    expect(find.byKey(const ValueKey('plan-flow-one-detail')), findsNothing);

    await _tapCard(tester, fixture.owned);
    await tester.pump(planFlowOneModeDuration ~/ 2);
    final halfway = _modeValue(tester);
    expect(halfway, greaterThan(0));
    expect(halfway, lessThan(1));
    final gridHalf = tester.getSize(
      find.byKey(const ValueKey('plan-flow-student-grid-container')),
    );
    await _settle(tester);
    expect(_modeValue(tester), 1);
    final gridOne = tester.getSize(
      find.byKey(const ValueKey('plan-flow-student-grid-container')),
    );
    // 시안 그리드 폭 1647.6 → 1540.9.
    expect(gridOne.width, closeTo(1540.9, 1));
    expect(gridHalf.width, greaterThan(gridOne.width));

    expect(find.byKey(const ValueKey('plan-flow-one-aside')), findsOneWidget);
    expect(find.text('선택한 학생'), findsOneWidget);
    expect(find.text('활성 계획 P1에 있음'), findsOneWidget);
    expect(find.text('이미 잡혀 있는 목표'), findsOneWidget);
    expect(find.text('P1 · 1단계'), findsOneWidget);
    expect(find.text('P2 · 2단계'), findsOneWidget);
    expect(find.text('Lv.90'), findsOneWidget);
    // 여러 명 C 내용(고른 학생 목록 · 역할군 칩)은 없다.
    expect(find.text('고른 학생'), findsNothing);
    expect(
      find.byKey(ValueKey('plan-flow-selected-${fixture.owned}')),
      findsNothing,
    );
    // 한 명 카드는 순서 배지가 없다.
    expect(
      tester
          .widget<StudentDiagonalGrid>(
            find.byKey(const ValueKey('plan-flow-student-grid')),
          )
          .selectionOrder,
      isEmpty,
    );

    // 학생 탭 S3: 같은 위젯, 인연 목표는 활성 계획 마지막 단계(100) 빗금 · →100.
    final detail = find.byKey(const ValueKey('plan-flow-one-detail'));
    expect(detail, findsOneWidget);
    expect(
      find.descendant(
        of: detail,
        matching: find.byType(StudentStatusIndicators),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text('→100')),
      findsOneWidget,
    );
    final indicators = tester.widget<StudentStatusIndicators>(
      find.byType(StudentStatusIndicators),
    );
    expect(indicators.bondTarget, 100);
    expect(indicators.values, isNotNull);

    // 둘째 학생을 더 고르면 여러 명 모양으로 돌아가고 S3가 사라진다.
    await _tapCard(tester, fixture.other);
    await _settle(tester);
    expect(_modeValue(tester), 0);
    expect(find.byKey(const ValueKey('plan-flow-one-aside')), findsNothing);
    expect(find.byKey(const ValueKey('plan-flow-one-detail')), findsNothing);
    expect(
      find.byKey(ValueKey('plan-flow-selected-${fixture.owned}')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<StudentDiagonalGrid>(
            find.byKey(const ValueKey('plan-flow-student-grid')),
          )
          .selectionOrder,
      {fixture.owned: 1, fixture.other: 2},
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('plan-flow-student-grid-container')),
          )
          .width,
      closeTo(1647.6, 1),
    );
  });

  testWidgets('"이 학생 목표 정하기"는 레일 "다음"처럼 2단계를 열고 B·C는 여러 명 모양이다', (
    tester,
  ) async {
    final fixture = await _fixture();
    await _pumpWorkspace(tester, fixture);
    await _tapCard(tester, fixture.owned);
    await _settle(tester);
    expect(fixture.flow.draft.hasStages, isFalse);
    await tester.tap(find.byKey(const ValueKey('plan-flow-one-next')));
    await tester.pump();
    await tester.pump(AppMotion.section);
    await _settle(tester);
    expect(fixture.flow.step, PlanFlowStep.goals);
    expect(fixture.flow.selectedStudentIds, [fixture.owned]);
    expect(find.byKey(const ValueKey('plan-flow-goal-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-flow-one-aside')), findsNothing);
    expect(find.byKey(const ValueKey('plan-flow-one-detail')), findsNothing);
  });

  testWidgets('활성 계획에 단계가 없으면 빈 상태 줄이고 활성 계획 칩이 없다', (tester) async {
    final fixture = await _fixture(withPlan: false);
    await _pumpWorkspace(tester, fixture);
    await _tapCard(tester, fixture.owned);
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('plan-flow-one-stages-empty')),
      findsOneWidget,
    );
    expect(find.text('활성 계획에 이 학생의 단계가 없습니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-flow-one-plan-chip')), findsNothing);
    expect(
      tester
          .widget<StudentStatusIndicators>(find.byType(StudentStatusIndicators))
          .bondTarget,
      isNull,
    );
  });

  testWidgets('한 명 모드는 1280×720에서도 넘침 예외가 없다', (tester) async {
    final fixture = await _fixture();
    await _pumpWorkspace(
      tester,
      fixture,
      view: const Size(1280, 720),
      canvas: null,
    );
    await _tapCard(tester, fixture.owned);
    await _settle(tester);
    expect(find.byKey(const ValueKey('plan-flow-one-aside')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-flow-one-detail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('흐름 화면 밖에서 그린 1단계 B·C(한 명 모드 진행 없음)는 여러 명 배치 그대로다', (
    tester,
  ) async {
    final fixture = await _fixture();
    final picker = PlanFlowStudentPicker(context: fixture.flow.context);
    addTearDown(picker.dispose);
    fixture.flow.toggleStudent(fixture.owned);
    tester.view.physicalSize = const Size(2560, 1392);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: _canvas,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PlanFlowStudentBody(
                      flow: fixture.flow,
                      picker: picker,
                    ),
                  ),
                  Positioned.fill(
                    child: PlanFlowStudentAside(
                      flow: fixture.flow,
                      picker: picker,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('plan-flow-one-aside')), findsNothing);
    expect(
      find.byKey(ValueKey('plan-flow-selected-${fixture.owned}')),
      findsOneWidget,
    );
    await tester.pump(planFlowCalculationDebounce);
    await tester.pumpAndSettle();
  });
}
