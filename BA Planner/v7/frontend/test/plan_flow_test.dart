// 계획 만들기 흐름 골격 테스트(FE4-a1, FE4-b1에서 v2 초안·새 1단계로 갱신): Studio 3-Section, 초안 컨트롤러
// (단계 이동·비활성 조건·학생 고르기), v2 목표 변환과 문서 경계 어댑터, 디바운스 계산과 레일 요약, 부족 재화
// 플라이아웃, 1단계 새 학생 고르기 · 2단계 새 목표 정하기(FE4-c)와 3단계 기존 화면(페이즈 편집기).
//
// 계산 디바운스(Timer)와 플라이아웃(OverlayPortal)이 있는 화면은 pumpAndSettle 대신 명시적인 pump를 쓴다.
import 'dart:async';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_goal_editor.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/studio/plan_flow_studio_layout.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_goal_step.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_rail.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_student_step.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:ba_planner_v7/ui/widgets/plan_student_selector.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 콘텐츠 캔버스(기준 viewport 2560×1392에서 헤더 184 아래).
const _canvas = Size(2560, 1208);

Map<String, int> _targets({int level = 50}) => {
  for (final key in planningDocumentTargetKeys) key: key == 'bond_rank' ? 1 : 0,
  'level': level,
};

PlanElementStageDraft _stage(String studentId, int number, {int level = 50}) =>
    PlanElementStageDraft(
      id: '$studentId-stage-$number',
      name: '$number단계',
      targets: _targets(level: level),
    );

/// v2 초안 단계(레벨만 목표, 나머지 18키는 null = 목표 없음).
PlanFlowStageDraft _v2Stage(
  String studentId,
  int number, {
  int level = 50,
  Map<String, int> extra = const {},
}) => PlanFlowStageDraft(
  id: '$studentId-stage-$number',
  name: '$number단계',
  targets: {'level': level, ...extra},
);

/// 학생을 고르고 2단계로 간다(이미 2단계면 그대로).
void _pick(PlanFlowController flow, String studentId) {
  flow.toggleStudent(studentId);
  flow.goTo(PlanFlowStep.goals);
}

Map<String, dynamic> _resource(
  String key,
  String name,
  String category,
  int required, {
  int? owned,
  List<String> stages = const [],
}) => {
  'resource_key': key,
  'item_id': key == 'credits' ? null : key,
  'display_name': name,
  'category': category,
  'required': required,
  'owned': owned,
  'shortage': owned == null ? null : (required - owned).clamp(0, required),
  'affected_stage_ids': stages,
};

/// `planning.document.calculate` 응답(필요 크레딧 1,234,567 · 부족 2종). 재화 id는 실제 asset이 있는 오파츠다.
Map<String, dynamic> _projection(Map<String, dynamic> document) {
  final stageIds = [
    for (final phase in document['phases'] as List)
      for (final stage in (phase as Map)['stages'] as List)
        (stage as Map)['stage_id'] as String,
  ];
  return {
    'document_id': document['document_id'],
    'kind': document['kind'],
    'stage_results': const <Object>[],
    'phase_results': const <Object>[],
    'overall': {
      'cost': {'credits': 1234567},
      'resources': [
        _resource('credits', '크레딧', 'credits', 1234567, stages: stageIds),
        _resource(
          'Item_Icon_Material_Nebra_2',
          '마모된 네브라 디스크',
          'oopart',
          60,
          owned: 42,
          stages: stageIds,
        ),
        _resource(
          'Item_Icon_Material_Nebra_1',
          '네브라 디스크 (일반)',
          'oopart',
          30,
          owned: 10,
          stages: stageIds.take(1).toList(),
        ),
        _resource(
          'Item_Icon_Material_Nebra_0',
          '네브라 디스크 (하급)',
          'oopart',
          5,
          owned: 8,
        ),
      ],
    },
    'bottlenecks': const <Object>[],
    'warnings': const <Object>[],
  };
}

/// 계산 호출 수를 세고 정한 응답을 돌려주는 mock.
class _FlowService extends MockAppService {
  int calls = 0;
  Object? error;
  final documents = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    calls += 1;
    documents.add(document);
    final error = this.error;
    if (error != null) throw error;
    return _projection(document);
  }
}

/// 응답 시점을 테스트가 정하는 mock(늦은 응답 버리기).
class _ControlledService extends MockAppService {
  final completers = <Completer<Map<String, dynamic>>>[];

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) {
    final completer = Completer<Map<String, dynamic>>();
    completers.add(completer);
    return completer.future;
  }
}

Future<PlanFlowContext> _context(MockAppService service) async {
  final profile = (await service.listProfiles()).firstWhere(
    (profile) => profile.selected,
  );
  final state = await service.loadRepositoryState(profile.id);
  final catalog = await service.listStudents();
  return PlanFlowContext(
    repositoryState: state,
    catalog: {for (final entry in catalog) entry.studentId: entry},
  );
}

Future<PlanFlowController> _controller(
  MockAppService service, {
  PlanFlowDraft? draft,
  PlanFlowStep step = PlanFlowStep.students,
}) async {
  final flow = PlanFlowController(
    purpose: PlanFlowPurpose.newScenario,
    context: await _context(service),
    service: service,
    initialDraft: draft,
    initialStep: step,
  );
  addTearDown(flow.dispose);
  return flow;
}

Future<void> _pumpRail(
  WidgetTester tester,
  PlanFlowController flow, {
  VoidCallback? onNext,
  VoidCallback? onPrevious,
  ValueChanged<PlanFlowStep>? onSelectStep,
}) async {
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
            child: ListenableBuilder(
              listenable: flow,
              builder: (context, _) => PlanFlowRail(
                flow: flow,
                onSelectStep: onSelectStep ?? flow.goTo,
                onNext: onNext ?? flow.goNext,
                onPrevious: onPrevious ?? flow.goPrevious,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

RailButton _railButton(WidgetTester tester, String key) {
  final finder = find.byKey(ValueKey(key));
  return tester.widget<RailButton>(
    tester.widget(finder) is RailButton
        ? finder
        : find.descendant(of: finder, matching: find.byType(RailButton)),
  );
}

String _text(WidgetTester tester, Finder within) => tester
    .widgetList<Text>(find.descendant(of: within, matching: find.byType(Text)))
    .map((text) => text.data)
    .join(' ');

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(planFlowCalculationDebounce);
  await tester.pump();
}

void main() {
  test('Studio 3-Section 꼭짓점은 시안 Flow 섹션과 1px 안에서 맞는다(C 보고서 §0-1)', () {
    // 시안 좌표(2560×1392)에서 헤더 184를 뺀 값.
    const top = 209.2 - 184;
    const bottom = 1392.0 - 184;
    void expectPolygon(String id, List<Offset> expected) {
      final actual = planFlowSectionPolygon(_canvas, id);
      expect(actual, hasLength(expected.length), reason: id);
      for (var index = 0; index < expected.length; index++) {
        expect(actual[index].dx, closeTo(expected[index].dx, 1), reason: id);
        expect(actual[index].dy, closeTo(expected[index].dy, 1), reason: id);
      }
    }

    expectPolygon(planFlowRailSectionId, const [
      Offset(0, top),
      Offset(586.7, top),
      Offset(378.1, bottom),
      Offset(0, bottom),
    ]);
    expectPolygon(planFlowBodySectionId, const [
      Offset(400 + 208.6, top),
      Offset(400 + 1701.9, top),
      Offset(400 + 1493.3, bottom),
      Offset(400, bottom),
    ]);
    expectPolygon(planFlowAsideSectionId, const [
      Offset(2560, top),
      Offset(2560, bottom),
      Offset(1920, bottom),
      Offset(1920 + 208.6, top),
    ]);
    // 레일 오른쪽 사선: 시안 스텝 1 윗변(y 287.2)에서 572.9.
    expect(planFlowRailRightAt(_canvas, 287.2 - 184), closeTo(572.9, 1));
  });

  group('초안 컨트롤러', () {
    test('단계 이동과 비활성 조건: 학생 → 목표 → 순서 → 저장', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      expect(flow.step, PlanFlowStep.students);
      expect(flow.canGoNext, isFalse);
      expect(flow.canEnter(PlanFlowStep.goals), isFalse);
      expect(flow.canEnter(PlanFlowStep.order), isFalse);
      expect(flow.canEnter(PlanFlowStep.save), isFalse);
      expect(flow.stateOf(PlanFlowStep.students), PlanFlowStepState.current);
      expect(flow.stateOf(PlanFlowStep.goals), PlanFlowStepState.remaining);

      // 그리드에서 고르면 바로 초안에 들어가고 "다음"이 열린다.
      flow.toggleStudent('aru');
      expect(flow.selectedStudentIds, ['aru']);
      expect(flow.canGoNext, isTrue);
      flow.goNext();
      expect(flow.step, PlanFlowStep.goals);
      expect(flow.draft.students.map((seed) => seed.studentId), ['aru']);
      expect(flow.goalSeed?.studentId, 'aru');
      expect(flow.stateOf(PlanFlowStep.students), PlanFlowStepState.done);
      expect(flow.canGoNext, isFalse, reason: '단계가 없으면 순서로 못 간다');

      flow.confirmStudentStages('aru', [_stage('aru', 1), _stage('aru', 2)]);
      expect(flow.draft.stageCount, 2);
      // 시안 Flow-1(학생 3명을 고른 1단계도 "지금")·Flow-4(1~3 "완료", 4 "지금")처럼 지금 단계는 할 일을 마쳐도
      // "지금"이고, 다음 단계로 넘어간 뒤에 "완료"가 된다.
      expect(flow.stateOf(PlanFlowStep.goals), PlanFlowStepState.current);
      expect(flow.canGoNext, isTrue);
      flow.goNext();
      expect(flow.step, PlanFlowStep.order);
      expect(flow.stateOf(PlanFlowStep.goals), PlanFlowStepState.done);
      expect(flow.stateOf(PlanFlowStep.order), PlanFlowStepState.current);
      expect(flow.canGoNext, isFalse, reason: '칸에 넣지 않은 단계가 있다');

      flow.completeOrder([
        PlanFlowPhase(
          id: 'p1',
          name: '1순위',
          stageIds: const ['aru-stage-1', 'aru-stage-2'],
        ),
      ]);
      expect(flow.step, PlanFlowStep.save);
      expect(flow.stateOf(PlanFlowStep.order), PlanFlowStepState.done);
      expect(flow.canGoNext, isTrue, reason: 'MockAppService는 시나리오 저장소다');

      flow.goPrevious();
      expect(flow.step, PlanFlowStep.order);
      flow.goTo(PlanFlowStep.students);
      expect(flow.step, PlanFlowStep.students);

      // 학생 단계를 다시 확정하면 그 학생은 칸에서 빠지고 4단계는 다시 닫힌다.
      flow.goTo(PlanFlowStep.goals);
      flow.confirmStudentStages('aru', [_stage('aru', 1, level: 60)]);
      expect(flow.draft.assignedStageIds, isEmpty);
      expect(flow.canEnter(PlanFlowStep.save), isFalse);
      expect(flow.stateOf(PlanFlowStep.order), PlanFlowStepState.remaining);
    });

    test('고른 학생은 고른 순서대로 붙고, 다시 누르면 단계와 함께 빠진다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      flow.toggleStudent('aru');
      flow.goNext();
      flow.confirmStudentStages('aru', [_stage('aru', 1)]);
      flow.goTo(PlanFlowStep.students);
      // 이미 고른 학생은 그대로 두고 새 학생만 뒤에 붙는다("보이는 학생 모두 고르기").
      flow.addStudents(['ayane', 'aru']);
      expect(flow.selectedStudentIds, ['aru', 'ayane']);
      // 2단계는 아직 단계가 없는 첫 학생부터 연다.
      flow.goNext();
      expect(flow.goalSeed?.studentId, 'ayane');
      expect(flow.editorStagesFor('aru'), hasLength(1));

      // 다시 누르면 그 학생의 단계·goal_metadata도 초안에서 빠지고 계산을 다시 부른다.
      flow.goTo(PlanFlowStep.students);
      flow.toggleStudent('aru');
      expect(flow.selectedStudentIds, ['ayane']);
      expect(flow.draft.stagesByStudent.containsKey('aru'), isFalse);
      expect(flow.draft.goalMetadata.containsKey('aru'), isFalse);
      expect(flow.canEnter(PlanFlowStep.order), isFalse);

      flow.clearStudents();
      expect(flow.selectedStudentIds, isEmpty);
      expect(flow.canGoNext, isFalse);
    });

    test('2단계 확정은 정수 단계를 v2(고르지 않은 목표 null)로 바꾸고 goal_metadata를 둔다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      _pick(flow, 'aru');
      final current = planElementCurrentTargets(flow.draft.seedOf('aru')!);
      final skill = current['skill1']! + 1;
      flow.confirmStudentStages('aru', [
        PlanElementStageDraft(
          id: 'aru-1',
          name: '1단계',
          targets: {...current, 'level': 90},
        ),
        PlanElementStageDraft(
          id: 'aru-2',
          name: '2단계',
          targets: {...current, 'level': 90, 'skill1': skill},
        ),
      ]);
      final stages = flow.draft.stagesByStudent['aru']!;
      expect(stages.first.targets.keys.toSet(), planningDocumentTargetKeys);
      expect(stages.first.goalKeys, {'level'});
      expect(stages.first.targets['skill1'], isNull);
      expect(stages.last.goalKeys, {'level', 'skill1'});
      expect(stages.last.targets['skill1'], skill);
      expect(
        flow.draft.goalMetadata['aru'],
        isA<PlanningGoalMetadata>()
            .having((item) => item.favorite, 'favorite', isFalse)
            .having((item) => item.notes, 'notes', ''),
      );
      // 정수 편집기 보기: null은 지금 값(첫 단계) · 앞 단계 값으로 채워 원래 입력과 같다.
      final editor = flow.editorStagesFor('aru');
      expect(editor.first.targets, {...current, 'level': 90});
      expect(editor.last.targets, {...current, 'level': 90, 'skill1': skill});
    });
  });

  group('v2 목표 변환', () {
    final seed = PlanningStudentSeed(
      handoffId: 'seed',
      studentId: 'aru',
      metadata: const {},
      currentValues: const {'level': 30, 'skill1': 4, 'bond_rank': 10},
    );

    test('지금 값보다 처음 올라간 단계부터 목표로 보고 뒤 단계에도 남긴다', () {
      final current = planElementCurrentTargets(seed);
      final stages = PlanFlowGoalCodec.fromEditor(seed, [
        PlanElementStageDraft(
          id: 's1',
          name: '1',
          targets: {...current, 'level': 50},
        ),
        PlanElementStageDraft(
          id: 's2',
          name: '2',
          targets: {...current, 'level': 50, 'skill1': 7},
        ),
      ]);
      expect(stages[0].goalKeys, {'level'});
      expect(stages[1].goalKeys, {'level', 'skill1'});
      expect(stages[1].targets['level'], 50);
      expect(stages[0].targets['bond_rank'], isNull);
      final editor = PlanFlowGoalCodec.toEditor(seed, stages);
      expect(editor[0].targets['skill1'], 4);
      expect(editor[1].targets['skill1'], 7);
      expect(editor[0].targets['bond_rank'], 10);
    });

    test('정수만 다루는 기존 화면에는 v2 문서의 null을 앞 단계 값으로 채워 준다', () {
      final document = PlanningDocument(
        id: 'v2',
        name: '후보',
        kind: PlanningDocumentKind.scenario,
        version: 2,
        goalMetadata: const {'aru': planFlowDefaultGoalMetadata},
        phases: [
          PlanningDocumentPhase(
            id: 'p1',
            name: '1',
            stages: [
              PlanningDocumentStage(
                id: 's1',
                studentId: 'aru',
                name: '1',
                targets: {
                  for (final key in planningDocumentTargetKeys) key: null,
                  'level': 50,
                },
              ),
            ],
          ),
        ],
      );
      final integers = planFlowDocumentIntegerTargets(
        document,
        seedFor: (_) => seed,
      );
      expect(integers['s1']!['level'], 50);
      expect(integers['s1']!['skill1'], 4);
      expect(integers['s1']!.keys.toSet(), planningDocumentTargetKeys);
    });
  });

  group('문서 경계 어댑터', () {
    final draft = PlanFlowDraft(
      students: [
        PlanningStudentSeed(
          handoffId: 'a',
          studentId: 'aru',
          metadata: const {},
          currentValues: const {},
        ),
        PlanningStudentSeed(
          handoffId: 'b',
          studentId: 'ayane',
          metadata: const {},
          currentValues: const {},
        ),
      ],
      stagesByStudent: {
        'aru': [_v2Stage('aru', 1), _v2Stage('aru', 2, level: 60)],
        'ayane': [
          _v2Stage('ayane', 1, extra: const {'skill1': 4}),
        ],
      },
      phases: [
        PlanFlowPhase(id: 'p1', name: '1순위', stageIds: const ['ayane-stage-1']),
      ],
      goalMetadata: const {
        'ayane': PlanningGoalMetadata(favorite: true, notes: '메모'),
      },
    );

    test('계산 문서는 칸에 없는 단계를 단계 번호마다 임시 페이즈에 넣는다', () {
      final wire = PlanFlowDocumentBoundary.calculationWire(draft, id: 'flow');
      final phases = [
        for (final phase in wire['phases'] as List)
          [
            (phase as Map)['phase_id'],
            [
              for (final stage in phase['stages'] as List)
                (stage as Map)['stage_id'],
            ],
          ],
      ];
      expect(phases, [
        [
          'p1',
          ['ayane-stage-1'],
        ],
        [
          'flow-draft-step-1',
          ['aru-stage-1'],
        ],
        [
          'flow-draft-step-2',
          ['aru-stage-2'],
        ],
      ]);
      expect(wire['version'], 2);
      expect(wire['kind'], 'scenario');
      // 문서 학생과 같은 키의 goal_metadata, 고르지 않은 목표는 null.
      expect((wire['goal_metadata'] as Map).keys.toSet(), {'aru', 'ayane'});
      final aruStage =
          ((wire['phases'] as List)[1] as Map)['stages'] as List;
      final aruTargets = (aruStage.single as Map)['targets'] as Map;
      expect(aruTargets.keys.toSet(), planningDocumentTargetKeys);
      expect(aruTargets['level'], 50);
      expect(aruTargets['skill1'], isNull);
      // 서버 쪽과 같은 규칙으로 다시 읽을 수 있다.
      expect(PlanningDocument.fromWire(wire).version, 2);
    });

    test('저장 문서는 칸 배치만 담고, 불러오면 같은 초안이 된다', () {
      final document = PlanFlowDocumentBoundary.toScenarioDocument(
        draft,
        id: 'scenario-1',
        name: '후보',
      );
      expect(document.kind, PlanningDocumentKind.scenario);
      expect(document.version, 2);
      expect(document.phases.map((phase) => phase.id), ['p1']);
      expect(document.stages.map((stage) => stage.id), ['ayane-stage-1']);
      expect(document.goalMetadata.keys, ['ayane']);

      final reopened = PlanFlowDocumentBoundary.fromDocument(
        document,
        seedFor: (studentId) => PlanningStudentSeed(
          handoffId: 'seed-$studentId',
          studentId: studentId,
          metadata: const {},
          currentValues: const {},
        ),
      );
      expect(reopened.students.map((seed) => seed.studentId), ['ayane']);
      expect(reopened.phases.single.stageIds, ['ayane-stage-1']);
      expect(reopened.allStagesAssigned, isTrue);
      expect(
        reopened.stagesByStudent['ayane']!.single.targets,
        draft.stagesByStudent['ayane']!.single.targets,
      );
      expect(reopened.goalMetadata['ayane']?.favorite, isTrue);
      expect(reopened.goalMetadata['ayane']?.notes, '메모');
    });
  });

  test('계산 결과: 크레딧은 cost에서, 없으면 크레딧 행에서 읽고 보유를 모르면 부족 수는 "—"다', () {
    final known = PlanFlowCalculation.fromProjection(
      _projection({
        'document_id': 'flow',
        'kind': 'scenario',
        'phases': [
          {
            'phase_id': 'p1',
            'stages': [
              {'stage_id': 'aru-stage-1'},
            ],
          },
        ],
      }),
      stageLookup: (id) => id == 'aru-stage-1'
          ? const PlanFlowShortageUse(
              studentId: 'aru',
              displayName: '아루',
              step: 1,
            )
          : null,
    );
    expect(known.credits, 1234567);
    expect(known.shortageKinds, 2);
    expect(known.shortages.map((item) => item.shortage), [20, 18]);
    expect(known.shortages.first.uses.single.displayName, '아루');

    final unknown = PlanFlowCalculation.fromProjection({
      'overall': {
        'resources': [_resource('credits', '크레딧', 'credits', 900)],
      },
    }, stageLookup: (_) => null);
    expect(unknown.credits, 900);
    expect(unknown.shortageKinds, isNull);
  });

  testWidgets('레일: 스텝 상태·부제, 갈 수 없는 스텝과 "다음"은 비활성', (tester) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final flow = await _controller(service);
    var nextCount = 0;
    await _pumpRail(tester, flow, onNext: () => nextCount += 1);

    expect(find.text('다음 · 목표 정하기'), findsOneWidget);
    expect(find.text('그만두기'), findsOneWidget);
    expect(_railButton(tester, 'plan-flow-next').onPressed, isNull);
    expect(_railButton(tester, 'plan-flow-step-2').onPressed, isNull);
    expect(_railButton(tester, 'plan-flow-step-4').onPressed, isNull);
    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-step-1'))),
      contains('아직 고르지 않았습니다'),
    );
    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-step-1-state'))),
      '지금',
    );

    flow.toggleStudent('aru');
    await tester.pump();
    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-step-1'))),
      contains('1명 · 여러 명 모드'),
    );
    expect(_railButton(tester, 'plan-flow-next').onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
    await tester.pump();
    expect(nextCount, 1);

    flow.goNext();
    await tester.pump();
    expect(find.text('다음 · 단계 순서'), findsOneWidget);
    expect(find.text('이전 · 학생 고르기'), findsOneWidget);
    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-step-1-state'))),
      '완료',
    );
    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-step-2'))),
      contains('1명 중 0명 완료'),
    );
    // 지난 스텝은 눌러서 돌아갈 수 있다.
    await tester.tap(find.byKey(const ValueKey('plan-flow-step-1')));
    await tester.pump();
    expect(flow.step, PlanFlowStep.students);
    await _settle(tester);
  });

  testWidgets('레일 의미 구조: 스텝 버튼과 요약 행이 이름 · 값 · 안내를 알린다', (tester) async {
    final handle = tester.ensureSemantics();
    final service = _FlowService();
    addTearDown(service.dispose);
    final flow = await _controller(service);
    _pick(flow, 'aru');
    flow.confirmStudentStages('aru', [_stage('aru', 1)]);
    await _pumpRail(tester, flow);
    await _settle(tester);

    expect(
      tester.getSemantics(find.byKey(const ValueKey('plan-flow-step-1'))),
      isSemantics(
        label: '1단계 학생 고르기',
        value: '완료, 1명 · 여러 명 모드',
        hint: '이 단계로 갑니다',
        isButton: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('plan-flow-step-2'))),
      isSemantics(
        label: '2단계 목표 정하기',
        value: '지금, 1명 중 1명 완료',
        hint: '지금 단계입니다',
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('plan-flow-step-4'))),
      isSemantics(
        label: '4단계 계획으로 만들기',
        value: '남음, 시나리오로 저장',
        hint: '앞 단계를 먼저 마칩니다',
      ),
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('plan-flow-summary-credits')),
      ),
      isSemantics(label: '필요 크레딧', value: '1.2M'),
    );
    handle.dispose();
  });

  testWidgets('디바운스: 연달아 고쳐도 계산은 한 번이고 레일 요약이 바뀐다', (tester) async {
    final service = _FlowService();
    addTearDown(service.dispose);
    final flow = await _controller(service);
    await _pumpRail(tester, flow);
    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-summary-credits'))),
      contains('—'),
    );
    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-summary-shortage'))),
      contains('—'),
    );

    _pick(flow, 'aru');
    flow.confirmStudentStages('aru', [_stage('aru', 1)]);
    await tester.pump(const Duration(milliseconds: 100));
    flow.confirmStudentStages('aru', [_stage('aru', 1), _stage('aru', 2)]);
    await tester.pump(const Duration(milliseconds: 100));
    _pick(flow, 'ayane');
    flow.confirmStudentStages('ayane', [_stage('ayane', 1)]);
    await tester.pump(
      planFlowCalculationDebounce - const Duration(milliseconds: 1),
    );
    expect(service.calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(service.calls, 1);
    expect(flow.calculationRequests, 1);
    // 마지막 초안(아루 2단계 + 아야네 1단계)을 보냈다.
    final sent = [
      for (final phase in service.documents.single['phases'] as List)
        for (final stage in (phase as Map)['stages'] as List)
          (stage as Map)['stage_id'],
    ];
    expect(sent, unorderedEquals(['aru-stage-1', 'aru-stage-2', 'ayane-stage-1']));

    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-summary-students'))),
      contains('2명'),
    );
    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-summary-stages'))),
      contains('3개'),
    );
    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-summary-credits'))),
      contains('1.2M'),
    );
    expect(
      _text(tester, find.byKey(const ValueKey('plan-flow-summary-shortage'))),
      contains('2종'),
    );

    // 계산 오류는 레일에 문구로 보이고, 단계를 모두 지우면 요약은 "—"로 돌아간다.
    service.error = StateError('계산 실패');
    flow.deleteStage('ayane-stage-1');
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('plan-flow-calculation-error')),
      findsOneWidget,
    );
    expect(service.calls, 2);
  });

  testWidgets('늦게 온 앞 계산 응답은 버린다', (tester) async {
    final service = _ControlledService();
    addTearDown(service.dispose);
    final flow = await _controller(service);
    _pick(flow, 'aru');
    flow.confirmStudentStages('aru', [_stage('aru', 1)]);
    await tester.pump(planFlowCalculationDebounce);
    expect(service.completers, hasLength(1));
    flow.confirmStudentStages('aru', [_stage('aru', 1), _stage('aru', 2)]);
    await tester.pump(planFlowCalculationDebounce);
    expect(service.completers, hasLength(2));

    service.completers.last.complete(
      _projection({'document_id': 'b', 'kind': 'scenario', 'phases': []}),
    );
    await tester.pump();
    expect(flow.calculation?.credits, 1234567);
    expect(flow.calculating, isFalse);

    // 앞 요청이 나중에 오류로 끝나도 결과를 덮지 않는다.
    service.completers.first.completeError(StateError('늦은 응답'));
    await tester.pump();
    expect(flow.calculationError, isNull);
    expect(flow.calculation?.credits, 1234567);
  });

  testWidgets('부족 재화 행은 플라이아웃을 열고 Esc로 닫는다', (tester) async {
    final service = _FlowService();
    addTearDown(service.dispose);
    final flow = await _controller(service);
    _pick(flow, 'aru');
    flow.confirmStudentStages('aru', [_stage('aru', 1)]);
    await _pumpRail(tester, flow);
    await _settle(tester);

    final title = find.text('부족 재화 2종');
    expect(title, findsNothing);
    await tester.tap(find.byKey(const ValueKey('plan-flow-summary-shortage')));
    await tester.pump();
    await tester.pump();
    expect(title, findsOneWidget);
    // 부족량이 큰 순.
    final names = [
      for (final name in const ['네브라 디스크 (일반)', '마모된 네브라 디스크'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(names.first, lessThan(names.last));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(title, findsNothing);
  });

  testWidgets('1단계는 새 학생 고르기, 2단계는 새 목표 정하기이고, 3단계는 기존 페이즈 편집기를 연다', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    tester.view.physicalSize = const Size(2560, 1392);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: PlanningPage(
            service: service,
            initialPresets: [
              PlanElementPreset(
                id: 'balanced-growth',
                name: '테스트 프리셋',
                isDefault: false,
                stages: const [
                  {'level': 30},
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('plan-scenario-create-launch')),
    );
    await tester.pumpAndSettle();
    // FE4-b1: 1단계는 기존 선택기가 아니라 B 본문·C 보조에 그리는 새 학생 고르기다.
    expect(find.byType(PlanStudentSelector), findsNothing);
    expect(find.byType(PlanFlowStudentBody), findsOneWidget);
    expect(find.byType(PlanFlowStudentAside), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-flow-legacy-slot')), findsNothing);

    // 그리드에서 고르고 레일 "다음"으로 2단계.
    final gridFinder = find.byKey(const ValueKey('plan-flow-student-grid'));
    final grid = tester.widget<StudentDiagonalGrid>(gridFinder);
    final firstId = grid.students.first.studentId;
    await tester.tap(
      find.descendant(
        of: gridFinder,
        matching: find.byKey(ValueKey('student-$firstId')),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(ValueKey('plan-flow-selected-$firstId')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
    await tester.pumpAndSettle();
    expect(find.byType(PlanFlowStudentBody), findsNothing);
    // FE4-c: 2단계는 B 본문·C 보조에 그리는 새 목표 정하기다. 기존 요소 편집기를 축소해 넣지 않는다.
    expect(find.byType(PlanFlowGoalBody), findsOneWidget);
    expect(find.byType(PlanFlowGoalAside), findsOneWidget);
    expect(find.byType(PlanElementBuilder), findsNothing);
    expect(find.byKey(const ValueKey('plan-flow-legacy-slot')), findsNothing);
    expect(find.byKey(ValueKey('plan-flow-goal-tab-$firstId')), findsOneWidget);
    // 프리셋 바: 계획 화면 프리셋 관리의 인메모리 프리셋 + 한 번에 MAX + 직접 입력(FD-075). 저장 버튼은 없다(FD-074).
    expect(
      find.byKey(const ValueKey('plan-flow-goal-preset-balanced-growth')),
      findsOneWidget,
    );
    expect(find.text('지금 구성을 프리셋으로'), findsNothing);
    // 기존 미배정 목록은 없다.
    expect(find.text('미배정'), findsNothing);

    // 레일 1단계 버튼으로 돌아갔다가 "다음"으로 다시 온다.
    await tester.tap(find.byKey(const ValueKey('plan-flow-step-1')));
    await tester.pumpAndSettle();
    expect(find.byType(PlanFlowStudentBody), findsOneWidget);
    // 돌아와도 고른 학생은 그대로다.
    expect(
      find.byKey(ValueKey('plan-flow-selected-$firstId')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
    await tester.pumpAndSettle();
    expect(find.byType(PlanFlowGoalBody), findsOneWidget);

    // 한 번에 MAX → 초안에 단계가 생겨 "다음"(3단계)으로 갈 수 있다.
    await tester.tap(find.byKey(const ValueKey('plan-flow-goal-mode-max')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
    await tester.pumpAndSettle();
    expect(find.byType(PlanFlowGoalBody), findsNothing);
    final editor = find.byKey(const ValueKey('plan-phase-editor'));
    expect(editor, findsOneWidget);
    // 페이즈 편집기는 원래 캔버스 크기로 배치한 뒤 B 안쪽 사각형에 맞춰 통째로 줄인다(넘침 없음).
    final workspace = find.byKey(const ValueKey('plan-flow-workspace'));
    final canvas = tester.getSize(workspace);
    final origin = tester.getTopLeft(workspace);
    expect(tester.getSize(editor).width, closeTo(canvas.width, 0.01));
    expect(tester.getSize(editor).height, closeTo(canvas.height, 0.01));
    final fitted = planFlowLegacyFittedRect(canvas).shift(origin);
    final drawn = tester.getRect(editor);
    expect(drawn.left, closeTo(fitted.left, 0.5));
    expect(drawn.top, closeTo(fitted.top, 0.5));
    expect(drawn.right, closeTo(fitted.right, 0.5));
    expect(drawn.bottom, closeTo(fitted.bottom, 0.5));
    // A 레일 윗변 오른쪽 끝·C 보조 왼쪽 사선 아랫끝과 겹치지 않는다.
    final rail = planFlowSectionPolygon(canvas, planFlowRailSectionId);
    final aside = planFlowSectionPolygon(canvas, planFlowAsideSectionId);
    expect(drawn.left - origin.dx, greaterThan(rail[1].dx));
    expect(drawn.right - origin.dx, lessThan(aside[2].dx));

    // 페이즈 편집기 "이전"은 2단계로 돌아가고, 고른 모드가 남아 있다.
    await tester.tap(find.byKey(const ValueKey('plan-flow-previous')));
    await tester.pumpAndSettle();
    expect(find.byType(PlanFlowGoalBody), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-phase-editor')), findsNothing);
    expect(
      tester
          .widget<SkewSegmented<String>>(
            find.byKey(const ValueKey('plan-flow-goal-mode-max')),
          )
          .selected,
      planFlowGoalModeMax,
    );
    expect(tester.takeException(), isNull);
  });
}
