// 성장 계산기 → 계획 넘김 테스트(FE4-g, FD-171 (a); FE4-g2 "나중에" 칸 앞에 넣기).
//
// 계산기가 넘긴 목표(현재값보다 올린 키만)를 계획 만들기 초안의 다음 단계로 바꾸는 규칙을 본다: 초안 없음 /
// 초안 있음·학생 없음 / 초안에 학생 있음 / 활성 계획에 학생 있음, 고르지 않은 키는 null로 남는다. 화면에서
// 버튼을 눌러 계획 탭 2단계로 가는 길은 `growth_calculator_view_test.dart`가 본다.
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_authoring.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_goal_editor.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_save.dart';
import 'package:ba_planner_v7/ui/models/planning_growth_rules.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PlanFlowContext> _context(
  MockAppService service, {
  PlanningDocument? activePlan,
}) async {
  final profile = (await service.listProfiles()).firstWhere(
    (profile) => profile.selected,
  );
  final state = await service.loadRepositoryState(profile.id);
  final catalog = await service.listStudents();
  return PlanFlowContext(
    repositoryState: state,
    catalog: {for (final entry in catalog) entry.studentId: entry},
    activePlan: activePlan,
  );
}

Future<PlanFlowController> _controller(
  MockAppService service, {
  PlanFlowDraft? draft,
  PlanningDocument? activePlan,
  PlanFlowPurpose purpose = PlanFlowPurpose.newScenario,
  PlanFlowStep step = PlanFlowStep.students,
}) async {
  final flow = PlanFlowController(
    purpose: purpose,
    context: await _context(service, activePlan: activePlan),
    service: service,
    initialDraft: draft,
    initialStep: step,
    // 디바운스 계산은 이 테스트의 관심사가 아니다. 길게 두고 dispose에서 취소한다.
    debounce: const Duration(hours: 1),
  );
  addTearDown(flow.dispose);
  return flow;
}

/// 계산기가 넘기는 시드. [targets]는 계산기가 현재값보다 올린 키만이다.
PlanningStudentSeed _handoff(String studentId, Map<String, int>? targets) =>
    PlanningStudentSeed(
      handoffId: 'growth-calculator-$studentId-test',
      studentId: studentId,
      metadata: const {},
      // 계산기 쪽 현재값(직접 입력일 수 있음)은 계획 쪽에서 쓰지 않는다.
      currentValues: const {'level': 85},
      targets: targets,
    );

/// v2 초안 단계(주어진 키만 목표, 나머지 null).
PlanFlowStageDraft _v2Stage(String id, Map<String, int> targets) =>
    PlanFlowStageDraft(id: id, name: '1단계', targets: targets);

/// [wireValid]면 v2 wire 규칙(문서 학생마다 goal_metadata)을 채워 authoring 검증에 쓸 수 있게 한다.
PlanningDocument _activePlan(
  Map<String, int?> aruTargets, {
  bool wireValid = false,
}) => PlanningDocument(
  id: 'active-plan',
  name: '활성 계획',
  kind: PlanningDocumentKind.plan,
  version: 2,
  goalMetadata: wireValid ? {'aru': planFlowDefaultGoalMetadata} : const {},
  phases: [
    PlanningDocumentPhase(
      id: 'active-p1',
      name: '1순위',
      stages: [
        PlanningDocumentStage(
          id: 'active-aru-1',
          studentId: 'aru',
          name: '1단계',
          targets: {
            for (final key in planningDocumentTargetKeys) key: aruTargets[key],
          },
        ),
      ],
    ),
  ],
);

Map<String, int> _floor(Map<String, int> values) => {
  for (final key in planningDocumentTargetKeys)
    key: values[key] ?? planElementTargetMinimums[key] ?? 0,
};

void main() {
  // MockAppService.listStudents()가 asset 번들에서 catalog를 읽는다.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('새 단계 목표(planFlowHandoffStageTargets)', () {
    test('바닥 snapshot을 복제하고 바닥보다 높은 계산기 값만 올린다(퇴행 없음)', () {
      final floor = _floor({'level': 70, 'skill1': 4, 'student_star': 3});
      final next = planFlowHandoffStageTargets(
        floor: floor,
        raised: const {'level': 60, 'skill1': 7},
        hasFavoriteItem: true,
      )!;
      expect(next['level'], 70, reason: '바닥보다 낮은 계산기 값은 쓰지 않는다');
      expect(next['skill1'], 7);
      expect(next['student_star'], 3);
    });

    test('올린 키는 바뀐 키로 정규화해 선행 조건이 함께 오른다', () {
      final floor = _floor({'level': 90, 'student_star': 3});
      final next = planFlowHandoffStageTargets(
        floor: floor,
        raised: const {'weapon_star': 1, 'weapon_level': 30},
        hasFavoriteItem: true,
      )!;
      expect(next['weapon_level'], 30);
      expect(next['weapon_star'], 1);
      expect(next['student_star'], 5, reason: '전용무기 목표는 ★5가 필요하다');
      expect(planningGrowthRuleViolation(next), isNull);
    });

    test('바닥보다 오르는 키가 없으면 단계를 만들지 않는다', () {
      final floor = _floor({'level': 70});
      expect(
        planFlowHandoffStageTargets(
          floor: floor,
          raised: const {'level': 70},
          hasFavoriteItem: true,
        ),
        isNull,
      );
      expect(
        planFlowHandoffStageTargets(
          floor: floor,
          raised: const {},
          hasFavoriteItem: true,
        ),
        isNull,
      );
    });
  });

  group('초안에 넣기(receiveHandoff)', () {
    test('초안 없음: 그 학생 1단계 = 계산기 목표, 고르지 않은 키는 null, 2단계에서 그 학생을 연다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      final result = flow.receiveHandoff(
        _handoff('aru', const {'level': 60, 'skill1': 10}),
      );
      expect(result.kind, PlanFlowHandoffKind.added);
      expect(result.step, 1);
      expect(flow.step, PlanFlowStep.goals);
      expect(flow.draft.studentIds, ['aru']);
      expect(flow.goalSeed?.studentId, 'aru');
      expect(flow.goalFocusStudentId, 'aru');
      final stage = flow.draft.stagesByStudent['aru']!.single;
      expect(stage.id, 'aru-calc-1');
      expect(stage.name, '1단계');
      expect(stage.targets['level'], 60);
      expect(stage.targets['skill1'], 10);
      // 고르지 않은 키는 0이나 현재값으로 채우지 않는다.
      expect(stage.targets['ex_skill'], isNull);
      expect(stage.targets['bond_rank'], isNull);
      expect(stage.targets['weapon_level'], isNull);
      expect(flow.draft.goalMetadata['aru'], planFlowDefaultGoalMetadata);
    });

    test('초안 있음·학생 없음: 학생을 뒤에 덧붙이고 다른 학생의 단계·칸은 그대로 둔다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final ayane = _v2Stage('ayane-stage-1', const {'level': 50});
      final flow = await _controller(
        service,
        step: PlanFlowStep.order,
        draft: PlanFlowDraft(
          students: [
            (await _context(service)).seedFor('ayane'),
          ],
          stagesByStudent: {
            'ayane': [ayane],
          },
          phases: [
            PlanFlowPhase(id: 'p1', name: '1순위', stageIds: const ['ayane-stage-1']),
          ],
        ),
      );
      final result = flow.receiveHandoff(
        _handoff('aru', const {'skill1': 5}),
      );
      expect(result.kind, PlanFlowHandoffKind.added);
      expect(flow.step, PlanFlowStep.goals);
      expect(flow.draft.studentIds, ['ayane', 'aru']);
      expect(flow.draft.stagesByStudent['ayane']!.single.targets['level'], 50);
      expect(flow.draft.phases.single.stageIds, ['ayane-stage-1']);
      expect(flow.draft.stagesByStudent['aru']!.single.targets['skill1'], 5);
      expect(flow.draft.stagesByStudent['aru']!.single.targets['level'], isNull);
      expect(flow.goalSeed?.studentId, 'aru');
    });

    test('초안에 학생 있음: 마지막 단계 뒤 새 단계(누적 snapshot), 그 학생 단계는 다시 배치한다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final seed = (await _context(service)).seedFor('aru');
      final flow = await _controller(
        service,
        step: PlanFlowStep.order,
        draft: PlanFlowDraft(
          students: [seed],
          stagesByStudent: {
            'aru': [_v2Stage('aru-stage-1', const {'level': 50})],
          },
          phases: [
            PlanFlowPhase(id: 'p1', name: '1순위', stageIds: const ['aru-stage-1']),
          ],
        ),
      );
      final result = flow.receiveHandoff(
        _handoff('aru', const {'level': 40, 'skill1': 10}),
      );
      expect(result.kind, PlanFlowHandoffKind.appendedToDraft);
      expect(result.step, 2);
      final stages = flow.draft.stagesByStudent['aru']!;
      expect([for (final stage in stages) stage.id], [
        'aru-stage-1',
        'aru-calc-1',
      ]);
      expect(stages.first.targets['level'], 50);
      expect(stages.first.targets['skill1'], isNull);
      // 앞 단계에서 정한 레벨은 이어 받고(40으로 낮추지 않음), 새로 올린 스킬만 더한다.
      expect(stages.last.name, '2단계');
      expect(stages.last.targets['level'], 50);
      expect(stages.last.targets['skill1'], 10);
      expect(stages.last.targets['ex_skill'], isNull);
      // 단계가 늘면 그 학생 단계는 칸에서 빠진다(2단계 편집과 같은 규칙).
      expect(flow.draft.phases.single.stageIds, isEmpty);
    });

    test('초안 마지막 단계에 이미 들어 있는 목표면 새 단계를 만들지 않는다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final seed = (await _context(service)).seedFor('aru');
      final flow = await _controller(
        service,
        step: PlanFlowStep.order,
        draft: PlanFlowDraft(
          students: [seed],
          stagesByStudent: {
            'aru': [_v2Stage('aru-stage-1', const {'level': 50})],
          },
          phases: [
            PlanFlowPhase(id: 'p1', name: '1순위', stageIds: const ['aru-stage-1']),
          ],
        ),
      );
      final result = flow.receiveHandoff(_handoff('aru', const {'level': 45}));
      expect(result.kind, PlanFlowHandoffKind.nothingNew);
      expect(result.step, isNull);
      expect(flow.draft.stagesByStudent['aru']!.single.id, 'aru-stage-1');
      expect(flow.draft.phases.single.stageIds, ['aru-stage-1']);
      expect(flow.step, PlanFlowStep.goals);
    });

    test('활성 계획에 학생 있음: 활성 계획 마지막 단계 snapshot 뒤 새 단계, 정하지 않은 키는 null', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(
        service,
        activePlan: _activePlan(const {'level': 70}),
      );
      final result = flow.receiveHandoff(
        _handoff('aru', const {'level': 60, 'skill1': 10}),
      );
      expect(result.kind, PlanFlowHandoffKind.appendedAfterActive);
      expect(result.step, 1);
      final stage = flow.draft.stagesByStudent['aru']!.single;
      // 활성 계획 레벨 70 snapshot을 이어 받고(60으로 낮추지 않음), 계산기가 올린 스킬을 더한다.
      expect(stage.targets['level'], 70);
      expect(stage.targets['skill1'], 10);
      expect(stage.targets['ex_skill'], isNull);
      expect(stage.targets['bond_rank'], isNull);
    });

    test('활성 계획 snapshot에 이미 들어 있으면 학생만 더한다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(
        service,
        activePlan: _activePlan(const {'level': 70}),
      );
      final result = flow.receiveHandoff(_handoff('aru', const {'level': 65}));
      expect(result.kind, PlanFlowHandoffKind.nothingNew);
      expect(flow.draft.studentIds, ['aru']);
      expect(flow.draft.stagesByStudent['aru'], isNull);
    });

    test('활성 계획을 고치는 흐름은 초안만 본다(활성 문서 snapshot을 다시 쓰지 않는다)', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(
        service,
        purpose: PlanFlowPurpose.editActivePlan,
        activePlan: _activePlan(const {'level': 70}),
      );
      final result = flow.receiveHandoff(
        _handoff('aru', const {'level': 60}),
      );
      expect(result.kind, PlanFlowHandoffKind.added);
      expect(flow.draft.stagesByStudent['aru']!.single.targets['level'], 60);
    });

    test('넘긴 목표가 없으면 학생만 더하고 2단계에서 그 학생을 연다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      final result = flow.receiveHandoff(_handoff('aru', null));
      expect(result.kind, PlanFlowHandoffKind.noTargets);
      expect(flow.draft.studentIds, ['aru']);
      expect(flow.draft.hasStages, isFalse);
      expect(flow.step, PlanFlowStep.goals);
    });

    test('이미 있는 2단계 편집기도 넘긴 학생 탭으로 바뀐다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      flow.toggleStudent('ayane');
      flow.goTo(PlanFlowStep.goals);
      final editor = PlanFlowGoalEditor(flow: flow);
      addTearDown(editor.dispose);
      expect(editor.studentId, 'ayane');
      flow.receiveHandoff(_handoff('aru', const {'skill1': 3}));
      expect(editor.studentId, 'aru');
      expect(editor.selectedStageIdOf('aru'), 'aru-calc-1');
      expect(flow.draft.studentIds, ['ayane', 'aru']);
    });
  });

  // FE4-g2: 같은 학생 체인 = 배치 prefix + 나중에 suffix. 새 단계는 나중에 단계 앞에 들어가고, 바닥은 그 자리 바로
  // 앞 단계다(나중에 단계가 바닥이 되지 않는다).
  group('"나중에" 칸 단계 앞에 넣기(FE4-g2)', () {
    test('넣을 자리는 나중에가 아닌 마지막 단계 바로 뒤다', () {
      expect(planFlowHandoffInsertIndex(const [], const {}), 0);
      expect(planFlowHandoffInsertIndex(const ['a', 'b'], const {}), 2);
      expect(planFlowHandoffInsertIndex(const ['a', 'b', 'c'], const {'c'}), 2);
      expect(
        planFlowHandoffInsertIndex(const ['a', 'b', 'c'], const {'b', 'c'}),
        1,
      );
      expect(planFlowHandoffInsertIndex(const ['a', 'b'], const {'a', 'b'}), 0);
    });

    test('뒤 단계는 새 단계보다 낮은 키만 새 단계 값으로 오른다(성장 규칙 정규화)', () {
      final later = PlanElementStageDraft(
        id: 'later',
        name: '3단계',
        targets: _floor({'level': 80, 'skill1': 4, 'student_star': 3}),
      );
      final untouched = PlanElementStageDraft(
        id: 'untouched',
        name: '4단계',
        targets: _floor({'level': 90, 'skill1': 9, 'student_star': 3}),
      );
      final inserted = _floor({
        'level': 70,
        'skill1': 7,
        'student_star': 5,
        'weapon_star': 1,
        'weapon_level': 30,
      });
      final raised = planFlowRaiseLaterStages(
        [later, untouched],
        _floor({'level': 70, 'skill1': 7, 'student_star': 3}),
        hasFavoriteItem: true,
      );
      expect(raised.first.targets['level'], 80, reason: '새 단계 이상인 값은 그대로');
      expect(raised.first.targets['skill1'], 7);
      expect(identical(raised.last, untouched), isTrue);
      final weapon = planFlowRaiseLaterStages(
        [later],
        inserted,
        hasFavoriteItem: true,
      ).single;
      expect(weapon.targets['weapon_level'], 30);
      expect(weapon.targets['student_star'], 5);
      expect(planningGrowthRuleViolation(weapon.targets), isNull);
    });

    Future<PlanFlowController> deferredDraftFlow(MockAppService service) async {
      final seed = (await _context(service)).seedFor('aru');
      return _controller(
        service,
        step: PlanFlowStep.order,
        draft: PlanFlowDraft(
          students: [seed],
          stagesByStudent: {
            'aru': [
              _v2Stage('aru-stage-1', const {'level': 50}),
              PlanFlowStageDraft(
                id: 'aru-stage-2',
                name: '2단계',
                targets: const {'level': 80},
              ),
            ],
          },
          phases: [
            PlanFlowPhase(id: 'p1', name: '1순위', stageIds: const ['aru-stage-1']),
          ],
          deferredStageIds: const ['aru-stage-2'],
        ),
      );
    }

    test('초안에 나중에 단계가 있는 학생: 새 단계는 나중에 단계 앞, 바닥은 배치 마지막 단계', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await deferredDraftFlow(service);
      expect(flow.orderIssues, isEmpty);
      final result = flow.receiveHandoff(
        _handoff('aru', const {'level': 60, 'skill1': 10}),
      );
      expect(result.kind, PlanFlowHandoffKind.appendedToDraft);
      expect(result.step, 2);
      final stages = flow.draft.stagesByStudent['aru']!;
      expect([for (final stage in stages) stage.id], [
        'aru-stage-1',
        'aru-calc-1',
        'aru-stage-2',
      ]);
      // 기본 이름은 넣은 자리에 맞춰 번호를 다시 매긴다.
      expect([for (final stage in stages) stage.name], ['1단계', '2단계', '3단계']);
      // 바닥 = 배치 마지막 단계(레벨 50): 계산기 60이 그대로 목표가 된다.
      expect(stages[1].targets['level'], 60);
      expect(stages[1].targets['skill1'], 10);
      // 뒤 나중에 단계는 새 단계 아래로 내려가지 않게 오른다(레벨 80은 그대로).
      expect(stages[2].targets['level'], 80);
      expect(stages[2].targets['skill1'], 10);
      // 나중에 단계는 나중에 칸에 남고, 칸 배치는 풀린다(3단계에서 다시 배치).
      expect(flow.draft.deferredStageIds, ['aru-stage-2']);
      expect(flow.draft.phases.single.stageIds, isEmpty);
      expect(flow.orderIssues, isEmpty);
      // 3단계: 앞 단계와 새 단계를 칸에 넣을 수 있다(체인 규칙을 어기지 않는다).
      expect(flow.moveStage('aru-stage-1', phaseId: 'p1'), isNull);
      expect(flow.moveStage('aru-calc-1', phaseId: 'p1'), isNull);
      expect(flow.draft.phases.single.stageIds, ['aru-stage-1', 'aru-calc-1']);
      expect(flow.orderReady, isTrue);
    });

    test('나중에 단계가 바닥이 되지 않는다: 나중에 단계에만 있는 값도 새 단계로 넣는다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await deferredDraftFlow(service);
      // 예전에는 바닥이 나중에 단계(레벨 80)여서 "이미 들어 있음"으로 끝났다.
      final result = flow.receiveHandoff(_handoff('aru', const {'level': 75}));
      expect(result.kind, PlanFlowHandoffKind.appendedToDraft);
      expect(result.step, 2);
      final stages = flow.draft.stagesByStudent['aru']!;
      expect(stages[1].id, 'aru-calc-1');
      expect(stages[1].targets['level'], 75);
      expect(stages[2].id, 'aru-stage-2');
      expect(stages[2].targets['level'], 80);
    });

    test('초안 단계가 모두 나중에면 새 단계가 1단계(바닥 = 지금 값)로 앞에 들어간다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final seed = (await _context(service)).seedFor('aru');
      final flow = await _controller(
        service,
        step: PlanFlowStep.order,
        activePlan: _activePlan(const {'level': 70}),
        draft: PlanFlowDraft(
          students: [seed],
          stagesByStudent: {
            'aru': [_v2Stage('aru-stage-1', const {'level': 80})],
          },
          deferredStageIds: const ['aru-stage-1'],
        ),
      );
      final result = flow.receiveHandoff(_handoff('aru', const {'level': 60}));
      expect(result.kind, PlanFlowHandoffKind.appendedToDraft);
      expect(result.step, 1);
      final stages = flow.draft.stagesByStudent['aru']!;
      expect([for (final stage in stages) stage.id], [
        'aru-calc-1',
        'aru-stage-1',
      ]);
      expect([for (final stage in stages) stage.name], ['1단계', '2단계']);
      // 초안에 그 학생이 있으면 초안 체인만 본다(활성 계획 레벨 70을 바닥으로 쓰지 않는다).
      expect(stages.first.targets['level'], 60);
      expect(stages.last.targets['level'], 80);
      expect(flow.draft.deferredStageIds, ['aru-stage-1']);
    });

    test('활성 계획에 나중에 단계가 있는 학생: 바닥은 활성 배치 마지막 단계, 페이즈로 추가하면 활성 나중에 단계 앞', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final active = _activePlan(const {'level': 70}, wireValid: true);
      // 활성 계획 authoring(`plan.get`): 배치 1단계(레벨 70) 뒤 나중에 2단계(레벨 90).
      final activeAuthoring = PlanningAuthoring.fromWire({
        'version': 1,
        'prerequisites': const <Object>[],
        'deferred_stages': [
          {
            'stage_id': 'active-aru-2',
            'student_id': 'aru',
            'name': '2단계',
            'targets': {
              for (final key in planningDocumentTargetKeys)
                key: key == 'level' ? 90 : null,
            },
          },
        ],
        'student_order': const ['aru'],
        'stage_order_by_student': const {
          'aru': ['active-aru-1', 'active-aru-2'],
        },
        'goal_metadata': const <String, Object>{},
      }, active);
      // 흐름 문맥은 지금처럼 문서만 싣는다(문서 페이즈 = 배치된 단계, 나중에 단계는 문서에 없다).
      final flow = await _controller(service, activePlan: active);
      final result = flow.receiveHandoff(_handoff('aru', const {'level': 85}));
      expect(result.kind, PlanFlowHandoffKind.appendedAfterActive);
      expect(result.step, 1);
      final stage = flow.draft.stagesByStudent['aru']!.single;
      // 바닥 = 활성 배치 마지막 단계(레벨 70). 활성 나중에 단계(레벨 90)가 바닥이면 "이미 들어 있음"이었다.
      expect(stage.targets['level'], 85);
      expect(stage.targets['skill1'], isNull);
      // 3단계에서 칸에 넣은 뒤 "활성 계획에 페이즈로 추가": 체인은 활성 배치 → 새 단계 → 활성 나중에.
      final draft = flow.draft.copyWith(
        phases: [
          PlanFlowPhase(id: 'p1', name: '1순위', stageIds: [stage.id]),
        ],
      );
      final merged = planFlowMergedPlanDocument(
        active: active,
        draft: draft,
        id: active.id,
        name: active.name,
        activeAuthoring: activeAuthoring,
      );
      expect(merged.blocked, isFalse);
      expect(merged.authoring!.stageOrderByStudent['aru'], [
        'active-aru-1',
        merged.stageIds[stage.id],
        'active-aru-2',
      ]);
      expect([
        for (final item in merged.authoring!.deferredStages) item.id,
      ], ['active-aru-2']);
    });
  });
}
