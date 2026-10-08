// 계획 만들기 2단계 목표 정하기(FE4-c) 테스트: 편집 상태([PlanFlowGoalEditor])의 v2 규칙(고르지 않은 목표 null,
// 목표 지우기는 모든 단계, 계산 결과를 되쓰지 않음), 기존 요소 편집기 동작(스테퍼 한계·뒤 단계 올림·단계 추가/삭제·
// 기본 이름 번호·프리셋 누적 펼침·성급 칸·더 보기 스테퍼)과 새 동작(한 번에 MAX·직접 입력 모드, 다른 학생에도 적용,
// 미보유 학생), 단계 비용(`stage_results`) 읽기, 위젯(학생 탭 · 단계 카드 · COST 디바운스 갱신 · 현재 → 최종 ·
// C 보조 · 의미 구조).
//
// 기존 요소 편집기(`plan_element_builder_test`)가 다루던 동작 중 흐름 2단계에 해당하는 것은 이 파일로 옮겼다(상태 문서
// FE4-c 기능 대조표). 활성 계획 "학생 추가" 경로는 기존 요소 편집기를 그대로 쓰므로 그 테스트는 남는다.
//
// 계산 디바운스·바뀐 칸 표시는 Timer라서 pumpAndSettle 대신 명시적인 pump를 쓰고, 테스트 끝에서 Timer를 모두 흘린다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_goal_editor.dart';
import 'package:ba_planner_v7/ui/models/planning_growth_rules.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart'
    show planElementCurrentTargets;
import 'package:ba_planner_v7/ui/widgets/plan_flow_goal_step.dart';
import 'package:ba_planner_v7/ui/widgets/student_form_cycle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 콘텐츠 캔버스(기준 viewport 2560×1392에서 헤더 184 아래).
const _canvas = Size(2560, 1208);

/// 단계마다 비용을 돌려주는 mock. 문서 순서 0번 단계 = 부족 1종(오파츠 −14), 나머지 = 지금 가능.
class _CostService extends MockAppService {
  _CostService() : super(fullStudentCatalog: true);

  int calls = 0;
  final documents = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    calls += 1;
    documents.add(document);
    final stages = [
      for (final phase in document['phases'] as List)
        for (final stage in (phase as Map)['stages'] as List)
          Map<String, dynamic>.from(stage as Map),
    ];
    return {
      'document_id': document['document_id'],
      'kind': document['kind'],
      'stage_results': [
        for (final (index, stage) in stages.indexed)
          {
            'stage_id': stage['stage_id'],
            'student_id': stage['student_id'],
            'name': stage['name'],
            'cost': {'credits': 1820000 + calls, 'warnings': <String>[]},
            'resources': [
              {
                'resource_key': 'credits',
                'item_id': null,
                'display_name': '크레딧',
                'category': 'credits',
                'required': 1820000 + calls,
                'owned_at_entry': 9000000,
                'shortage_at_entry': 0,
              },
              {
                'resource_key': 'Item_Icon_Material_Nebra_3',
                'item_id': 'Item_Icon_Material_Nebra_3',
                'display_name': '오파츠 · 네브라 디스크 (최상급)',
                'category': 'oopart',
                'required': 90,
                'owned_at_entry': index == 0 ? 76 : 200,
                'shortage_at_entry': index == 0 ? 14 : 0,
              },
            ],
          },
      ],
      'phase_results': const <Object>[],
      'overall': {
        'cost': {'credits': 1820000 + calls},
        'resources': const <Object>[],
      },
      'bottlenecks': const <Object>[],
      'warnings': const <Object>[],
    };
  }
}

Future<PlanFlowController> _flow(MockAppService service) async {
  final profile = (await service.listProfiles()).firstWhere(
    (profile) => profile.selected,
  );
  final state = await service.loadRepositoryState(profile.id);
  final catalog = await service.listStudents();
  final flow = PlanFlowController(
    purpose: PlanFlowPurpose.newScenario,
    context: PlanFlowContext(
      repositoryState: state,
      catalog: {for (final entry in catalog) entry.studentId: entry},
    ),
    service: service,
  );
  addTearDown(flow.dispose);
  return flow;
}

/// 학생을 고른 순서대로 넣고 2단계 편집 상태를 만든다.
Future<(PlanFlowController, PlanFlowGoalEditor)> _setup(
  MockAppService service,
  List<String> studentIds, {
  List<PlanElementPreset> presets = const [],
}) async {
  final flow = await _flow(service);
  flow.addStudents(studentIds);
  flow.goTo(PlanFlowStep.goals);
  final editor = PlanFlowGoalEditor(flow: flow, presets: presets);
  addTearDown(editor.dispose);
  return (flow, editor);
}

/// 미보유 학생(카탈로그에는 있고 프로필에는 없는 첫 학생).
String _unownedId(PlanFlowController flow) {
  final owned = {
    for (final student in flow.context.repositoryState.students)
      student.studentId,
  };
  return flow.context.catalog.keys.firstWhere((id) => !owned.contains(id));
}

String _stageId(PlanFlowGoalEditor editor, int index) =>
    editor.stagesOf(editor.studentId!)[index].id;

Map<String, int> _targets(PlanFlowGoalEditor editor, int index) =>
    editor.stagesOf(editor.studentId!)[index].targets;

Future<void> _pump(
  WidgetTester tester,
  PlanFlowController flow,
  PlanFlowGoalEditor editor,
) async {
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
                  child: PlanFlowGoalBody(flow: flow, editor: editor),
                ),
                Positioned.fill(
                  child: PlanFlowGoalAside(flow: flow, editor: editor),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 계산 디바운스와 바뀐 칸 표시 Timer를 흘린다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(planFlowCalculationDebounce);
  await tester.pump();
  await tester.pump(planFlowGoalPropagationHighlight);
}

Finder _nudge(String stageId, String key) =>
    find.byKey(ValueKey('plan-flow-goal-$stageId-$key-nudge'));

/// 미세 조절 ▲(올리기). 장비 티어는 ◀▶이라 [_sideIncrease]를 쓴다.
Finder _increase(String stageId, String key) => find
    .descendant(of: _nudge(stageId, key), matching: find.byType(KitPressable))
    .first;

Finder _decrease(String stageId, String key) => find
    .descendant(of: _nudge(stageId, key), matching: find.byType(KitPressable))
    .last;

Finder _sideIncrease(String stageId, String key) => _decrease(stageId, key);

void main() {
  setUp(() => StudentFormClock.instance.freeze(0));
  tearDown(() => StudentFormClock.instance.freeze(null));

  group('편집 상태', () {
    test('처음에는 고른 순서의 첫 학생, 직접 입력 빈 1단계이고 초안에는 아무것도 없다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['aru', 'hoshino']);
      expect(editor.studentIds, ['aru', 'hoshino']);
      expect(editor.studentId, 'aru');
      expect(editor.modeOf('aru'), planFlowGoalModeDirect);
      expect(editor.stagesOf('aru'), hasLength(1));
      expect(editor.stagesOf('aru').single.name, '1단계');
      expect(editor.stagesOf('aru').single.targets, editor.currentOf('aru'));
      expect(editor.isEffective('aru', _stageId(editor, 0)), isFalse);
      expect(flow.draft.stagesByStudent, isEmpty);
      expect(editor.tabStateOf('aru'), PlanFlowGoalTabState.editing);
      expect(editor.tabStateOf('hoshino'), PlanFlowGoalTabState.unset);

      editor.selectStudent('hoshino');
      expect(editor.studentId, 'hoshino');
      expect(editor.tabStateOf('aru'), PlanFlowGoalTabState.unset);
    });

    test('v2: 지금 값보다 올린 키만 목표이고 나머지는 null, 계산 문서에도 null로 간다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['aru']);
      final current = editor.currentOf('aru');
      final stageId = _stageId(editor, 0);
      editor.setTarget(stageId, 'level', current['level']! + 9);

      final drafted = flow.draft.stagesByStudent['aru']!;
      expect(drafted.single.id, stageId);
      expect(drafted.single.targets.keys.toSet(), planningDocumentTargetKeys);
      expect(drafted.single.goalKeys, {'level'});
      expect(drafted.single.targets['level'], current['level']! + 9);
      expect(drafted.single.targets['skill1'], isNull);
      expect(drafted.single.targets.containsKey('skill1'), isTrue);
      expect(editor.tabStateOf('aru'), PlanFlowGoalTabState.editing);
      expect(flow.draft.completedStudentCount, 1);

      final wire = PlanFlowDocumentBoundary.calculationWire(
        flow.draft,
        id: 'doc',
      );
      expect(wire['version'], 2);
      final targets =
          ((((wire['phases'] as List).single as Map)['stages'] as List).single
                  as Map)['targets']
              as Map;
      expect(targets.keys.toSet(), planningDocumentTargetKeys);
      expect(targets['level'], current['level']! + 9);
      expect(targets['ex_skill'], isNull);
      expect(PlanningDocument.fromWire(wire).stages.single.nullableTargets, {
        for (final key in planningDocumentTargetKeys)
          key: key == 'level' ? current['level']! + 9 : null,
      });
    });

    testWidgets('값 바꾸기: 아래 한계는 앞 단계, 올린 값은 뒤 단계로 이어지고 900ms 동안 표시한다', (
      tester,
    ) async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['aru']);
      final first = _stageId(editor, 0);
      editor.setTarget(first, 'level', 20);
      editor.addStage();
      final second = _stageId(editor, 1);
      expect(editor.selectedStageIdOf('aru'), second);
      expect(_targets(editor, 1)['level'], 20);
      // 앞 단계(20)보다 낮출 수 없고, 최댓값(90)보다 올릴 수 없다.
      editor.setTarget(second, 'level', 5);
      expect(_targets(editor, 1)['level'], 20);
      editor.setTarget(second, 'level', 99);
      expect(_targets(editor, 1)['level'], planElementTargetMaximums['level']);
      editor.setTarget(second, 'level', 30);
      expect(flow.draft.stagesByStudent['aru'], hasLength(2));

      // 1단계를 2단계보다 올리면 2단계도 올라간다(이어받은 칸 표시).
      editor.setTarget(first, 'level', 40);
      expect(_targets(editor, 1)['level'], 40);
      expect(editor.isPropagated(second, 'level'), isTrue);
      // 2단계는 이제 1단계보다 올린 것이 없어 초안에서 빠진다(기존 요소 편집기 확정 규칙).
      expect(editor.isEffective('aru', second), isFalse);
      expect(flow.draft.stagesByStudent['aru']!.map((stage) => stage.id), [
        first,
      ]);
      await tester.pump(planFlowGoalPropagationHighlight);
      expect(editor.isPropagated(second, 'level'), isFalse);
      await tester.pump(planFlowCalculationDebounce);
    });

    test('성장 규칙: 전용무기를 올리면 5성이 되고, 애장품이 없는 학생은 애장품 최댓값이 0이다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final (_, editor) = await _setup(service, ['aru']);
      final stageId = _stageId(editor, 0);
      editor.setTarget(stageId, 'weapon_level', 1);
      expect(_targets(editor, 0)['student_star'], 5);
      expect(_targets(editor, 0)['weapon_star'], greaterThanOrEqualTo(1));
      expect(
        editor.maximumOf('aru', 'equip4_tier'),
        editor.hasFavoriteItem('aru') ? planElementTargetMaximums['equip4_tier'] : 0,
      );
    });

    test('단계 추가는 고른 단계 바로 뒤 복사본, 기본 이름은 번호를 다시 매기고, 삭제는 하나를 남긴다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final (_, editor) = await _setup(service, ['aru']);
      final first = _stageId(editor, 0);
      editor.setTarget(first, 'level', 20);
      editor.addStage();
      final last = _stageId(editor, 1);
      editor.selectStage(first);
      editor.addStage();
      final middle = _stageId(editor, 1);
      expect([for (final stage in editor.stagesOf('aru')) stage.id], [
        first,
        middle,
        last,
      ]);
      expect([for (final stage in editor.stagesOf('aru')) stage.name], [
        '1단계',
        '2단계',
        '3단계',
      ]);
      expect(_targets(editor, 1), _targets(editor, 0));

      // 이름을 고친 단계는 번호를 다시 매기지 않는다. 비우면 기본 이름으로 돌아간다(FD-073).
      editor.renameStage(last, '마무리');
      editor.removeStage(middle);
      expect([for (final stage in editor.stagesOf('aru')) stage.name], [
        '1단계',
        '마무리',
      ]);
      expect(editor.selectedStageIdOf('aru'), first);
      editor.renameStage(last, '  ');
      expect(editor.stagesOf('aru').last.name, '2단계');
      editor.removeStage(first);
      editor.removeStage(last);
      expect(editor.stagesOf('aru'), hasLength(1));
    });

    test('프리셋: 듬성한 단계를 앞 단계에 누적해 펼치고 올린 것이 없는 단계는 버린다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final preset = PlanElementPreset(
        id: 'p',
        name: '두 단계',
        isDefault: false,
        stages: const [
          {'level': 30},
          {'level': 20},
          {'ex_skill': 3},
        ],
      );
      final (flow, editor) = await _setup(service, [
        'aru',
      ], presets: [preset]);
      editor.applyMode(planFlowGoalPresetMode('p'));
      expect(editor.modeOf('aru'), planFlowGoalPresetMode('p'));
      expect(editor.modeLabel(planFlowGoalPresetMode('p')), '두 단계');
      final stages = editor.stagesOf('aru');
      expect([for (final stage in stages) stage.name], ['1단계', '2단계']);
      expect(stages[0].targets['level'], 30);
      expect(stages[1].targets['level'], 30);
      expect(stages[1].targets['ex_skill'], 3);
      final drafted = flow.draft.stagesByStudent['aru']!;
      expect(drafted.map((stage) => stage.goalKeys), [
        {'level'},
        {'level', 'ex_skill'},
      ]);
      // 값을 고쳐도 고른 프리셋은 남는다.
      editor.setTarget(stages[1].id, 'skill1', 5);
      expect(editor.modeOf('aru'), planFlowGoalPresetMode('p'));
    });

    test('한 번에 MAX는 1단계에 모든 목표 최댓값, 직접 입력은 빈 1단계(초안에서 빠짐)다(FD-075)', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['aru']);
      editor.applyMode(planFlowGoalModeMax);
      expect(editor.modeOf('aru'), planFlowGoalModeMax);
      final maximum = editor.stagesOf('aru').single.targets;
      for (final key in const [
        'level',
        'student_star',
        'weapon_level',
        'ex_skill',
        'skill1',
        'skill2',
        'skill3',
        'equip1_tier',
        'bond_rank',
        'stat_hp',
      ]) {
        expect(maximum[key], planElementTargetMaximums[key], reason: key);
      }
      expect(planningGrowthRuleViolation(maximum), isNull);
      expect(flow.draft.stagesByStudent['aru'], hasLength(1));

      editor.applyMode(planFlowGoalModeDirect);
      expect(editor.modeOf('aru'), planFlowGoalModeDirect);
      expect(editor.stagesOf('aru').single.targets, editor.currentOf('aru'));
      expect(flow.draft.stagesByStudent['aru'], isNull);
    });

    test('목표 지우기: 그 학생의 모든 단계에서 지우고(v2 null), 묶인 목표도 함께 내려간다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final preset = PlanElementPreset(
        id: 'star',
        name: '성급',
        isDefault: false,
        stages: const [
          {'level': 30, 'student_star': 3},
          {'student_star': 5, 'weapon_level': 20},
        ],
      );
      final (flow, editor) = await _setup(service, [
        'aru',
      ], presets: [preset]);
      expect(editor.currentOf('aru')['student_star'], lessThan(3));
      editor.applyMode(planFlowGoalPresetMode('star'));
      expect(flow.draft.stagesByStudent['aru'], hasLength(2));
      expect(editor.hasGoal('aru', PlanFlowGoalGroup.star.keys), isTrue);

      editor.clearGoal(PlanFlowGoalGroup.star.keys);
      final current = editor.currentOf('aru');
      for (final stage in editor.stagesOf('aru')) {
        expect(stage.targets['student_star'], current['student_star']);
        // 전용무기는 5성이 필요해서 함께 내려간다.
        expect(stage.targets['weapon_level'], current['weapon_level']);
      }
      expect(editor.hasGoal('aru', PlanFlowGoalGroup.star.keys), isFalse);
      final drafted = flow.draft.stagesByStudent['aru']!;
      // 2단계는 이제 1단계보다 올린 것이 없어 빠지고, 남은 단계의 성급·전용무기는 null이다.
      expect(drafted, hasLength(1));
      for (final stage in drafted) {
        expect(stage.targets['student_star'], isNull);
        expect(stage.targets['weapon_level'], isNull);
        expect(stage.targets['level'], 30);
      }
      // 레벨 목표를 지우면 그 학생은 미설정이 된다.
      editor.clearGoal(PlanFlowGoalGroup.level.keys);
      expect(flow.draft.stagesByStudent['aru'], isNull);
    });

    test('다른 학생에도 적용: 프리셋·MAX만 적용하고, 직접 입력은 적용하지 않는다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['aru', 'hoshino', 'hina']);
      editor.applyCurrentModeTo(['hoshino']);
      expect(flow.draft.stagesByStudent['hoshino'], isNull);

      editor.applyMode(planFlowGoalModeMax);
      editor.applyCurrentModeTo(['hoshino']);
      expect(editor.modeOf('hoshino'), planFlowGoalModeMax);
      expect(flow.draft.stagesByStudent['hoshino'], hasLength(1));
      expect(flow.draft.stagesByStudent['hina'], isNull);
      editor.applyCurrentModeTo(editor.studentIds);
      expect(editor.modeOf('hina'), planFlowGoalModeMax);
      expect(flow.draft.completedStudentCount, 3);
      // 지금 학생은 그대로다.
      expect(editor.studentId, 'aru');
    });

    test('미보유 학생은 목표 최솟값에서 시작한다(FD-076)', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final flow = await _flow(service);
      final unowned = _unownedId(flow);
      flow.addStudents([unowned]);
      flow.goTo(PlanFlowStep.goals);
      final editor = PlanFlowGoalEditor(flow: flow);
      addTearDown(editor.dispose);
      expect(editor.isOwned(unowned), isFalse);
      expect(editor.currentOf(unowned)['level'], 1);
      editor.setTarget(_stageId(editor, 0), 'level', 10);
      expect(flow.draft.stagesByStudent[unowned]!.single.goalKeys, {'level'});
    });

    test('1단계에서 학생을 빼면 작업 단계를 버리고, 다시 고르면 빈 1단계로 시작한다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['aru', 'hoshino']);
      editor.applyMode(planFlowGoalModeMax);
      flow.removeStudent('aru');
      expect(editor.studentIds, ['hoshino']);
      expect(editor.studentId, 'hoshino');
      flow.addStudents(['aru']);
      expect(editor.modeOf('aru'), planFlowGoalModeDirect);
      expect(editor.stagesOf('aru').single.targets, editor.currentOf('aru'));
    });

    test('초안의 기존 단계(시나리오 편집)를 작업 단계로 열고, 지금 값으로 채운 키는 다시 null로 둔다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final flow = await _flow(service);
      flow.addStudents(['aru']);
      final current = planElementCurrentTargets(flow.draft.seedOf('aru')!);
      flow.setStudentStages('aru', [
        PlanElementStageDraft(
          id: 'aru-a',
          name: '성장',
          targets: {...current, 'level': 40},
        ),
      ]);
      flow.goTo(PlanFlowStep.goals);
      final editor = PlanFlowGoalEditor(flow: flow);
      addTearDown(editor.dispose);
      expect(editor.stagesOf('aru').single.id, 'aru-a');
      expect(editor.stagesOf('aru').single.name, '성장');
      expect(editor.modeOf('aru'), isNull);
      expect(editor.tabStateOf('aru'), PlanFlowGoalTabState.editing);
      editor.setTarget('aru-a', 'ex_skill', current['ex_skill']! + 1);
      expect(flow.draft.stagesByStudent['aru']!.single.goalKeys, {
        'level',
        'ex_skill',
      });
    });
  });

  group('초안 연결', () {
    test('setStudentStages: 단계 id가 그대로면 칸 배치를 두고, 바뀌면 그 학생 단계를 칸에서 뺀다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final flow = await _flow(service);
      flow.addStudents(['aru', 'hoshino']);
      final aru = planElementCurrentTargets(flow.draft.seedOf('aru')!);
      final hoshino = planElementCurrentTargets(flow.draft.seedOf('hoshino')!);
      PlanElementStageDraft stage(String id, Map<String, int> base, int level) =>
          PlanElementStageDraft(
            id: id,
            name: id,
            targets: {...base, 'level': level},
          );
      flow.setStudentStages('aru', [stage('a1', aru, 30), stage('a2', aru, 40)]);
      flow.setStudentStages('hoshino', [stage('h1', hoshino, 90)]);
      flow.completeOrder([
        PlanFlowPhase(id: 'p1', name: '1', stageIds: const ['a1', 'h1']),
        PlanFlowPhase(id: 'p2', name: '2', stageIds: const ['a2']),
      ]);
      expect(flow.draft.allStagesAssigned, isTrue);

      // 목표 값만 바뀜: 칸 배치 그대로.
      flow.setStudentStages('aru', [stage('a1', aru, 35), stage('a2', aru, 40)]);
      expect(flow.draft.phases.map((phase) => phase.stageIds), [
        ['a1', 'h1'],
        ['a2'],
      ]);
      // 단계를 더하면 그 학생의 단계는 모두 다시 배치해야 한다(다른 학생은 그대로).
      flow.setStudentStages('aru', [
        stage('a1', aru, 35),
        stage('a3', aru, 38),
        stage('a2', aru, 40),
      ]);
      expect(flow.draft.phases.map((phase) => phase.stageIds), [
        ['h1'],
        <String>[],
      ]);
      expect(flow.draft.unassignedStages.map((stage) => stage.id), [
        'a1',
        'a3',
        'a2',
      ]);
      // 빈 목록이면 그 학생의 단계가 없어진다.
      flow.setStudentStages('aru', const []);
      expect(flow.draft.stagesByStudent['aru'], isNull);
      expect(flow.draft.goalMetadata['aru'], isNotNull);
    });

    test('계산 결과: stage_results에서 단계 비용·들어설 때 부족·경고를 읽는다', () {
      final calculation = PlanFlowCalculation.fromProjection({
        'overall': {
          'cost': {'credits': 10},
          'resources': const <Object>[],
        },
        'stage_results': [
          {
            'stage_id': 'a1',
            'cost': {
              'credits': 1200,
              'warnings': ['주의'],
            },
            'resources': [
              {
                'resource_key': 'x',
                'item_id': 'x',
                'display_name': '재화 X',
                'category': 'oopart',
                'required': 9,
                'owned_at_entry': 4,
                'shortage_at_entry': 5,
              },
              {
                'resource_key': 'y',
                'item_id': 'y',
                'display_name': '재화 Y',
                'category': 'oopart',
                'required': 3,
                'owned_at_entry': 8,
                'shortage_at_entry': 0,
              },
            ],
          },
          {
            'stage_id': 'a2',
            'cost': <String, Object>{},
            'resources': [
              {
                'resource_key': 'credits',
                'item_id': null,
                'display_name': '크레딧',
                'category': 'credits',
                'required': 700,
                'owned_at_entry': null,
                'shortage_at_entry': null,
              },
            ],
          },
          {'cost': <String, Object>{}},
        ],
      }, stageLookup: (_) => null);
      expect(calculation.stageCosts.keys, ['a1', 'a2']);
      final first = calculation.stageCosts['a1']!;
      expect(first.credits, 1200);
      expect(first.shortageKinds, 1);
      expect(first.warnings, ['주의']);
      expect(planFlowGoalCostRows(first).map((row) => row.resourceKey), [
        'x',
        'credits',
        'y',
      ]);
      expect(planFlowGoalCostLine(first), '크레딧 1.2K · 재화 X 9');
      final second = calculation.stageCosts['a2']!;
      expect(second.credits, 700);
      expect(second.shortageKinds, isNull);
      expect(
        planFlowGoalStageStatus(
          effective: true,
          owned: true,
          cost: first,
          calculating: false,
        ).label,
        '부족 1종',
      );
      expect(
        planFlowGoalStageStatus(
          effective: true,
          owned: false,
          cost: first,
          calculating: false,
        ).label,
        '모집 필요',
      );
      expect(
        planFlowGoalStageStatus(
          effective: false,
          owned: true,
          cost: null,
          calculating: false,
        ).label,
        '목표 없음',
      );
    });

    test('현재 → 최종 글자와 막대', () {
      final current = {
        for (final key in planningDocumentTargetKeys) key: 0,
        'level': 45,
        'ex_skill': 3,
        'skill1': 10,
        'skill2': 7,
        'skill3': 4,
        'equip1_tier': 8,
        'equip2_tier': 8,
        'equip3_tier': 8,
      };
      final target = {
        ...current,
        'level': 90,
        'ex_skill': 5,
        'equip1_tier': 9,
        'equip2_tier': 9,
        'equip3_tier': 9,
      };
      expect(planFlowGoalGroupText(PlanFlowGoalGroup.skill, current), '3/M/7/4');
      expect(planFlowGoalGroupText(PlanFlowGoalGroup.skill, target), 'M/M/7/4');
      expect(
        planFlowGoalGroupText(PlanFlowGoalGroup.equipment, current),
        'T8 ×3',
      );
      expect(planFlowGoalGroupText(PlanFlowGoalGroup.weapon, current), '—');
      expect(
        planFlowGoalGroupProgress(PlanFlowGoalGroup.level, current, target),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('화면', () {
    testWidgets('학생 탭은 고른 순서이고, 누르면 그 학생의 카드와 현재 → 최종으로 바뀐다', (tester) async {
      final service = _CostService();
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['hoshino', 'aru']);
      await _pump(tester, flow, editor);

      final hoshinoTab = find.byKey(const ValueKey('plan-flow-goal-tab-hoshino'));
      final aruTab = find.byKey(const ValueKey('plan-flow-goal-tab-aru'));
      expect(
        tester.getTopLeft(hoshinoTab).dx,
        lessThan(tester.getTopLeft(aruTab).dx),
      );
      expect(
        find.descendant(of: hoshinoTab, matching: find.text('설정 중')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: aruTab, matching: find.text('미설정')),
        findsOneWidget,
      );
      final hoshinoName = flow.context.displayName('hoshino');
      expect(find.text('$hoshinoName · 현재 → 최종'), findsOneWidget);

      // 호시노에게 목표를 하나 주고 아루 탭으로: 호시노는 완료, 카드는 아루의 빈 1단계.
      editor.applyMode(planFlowGoalModeMax);
      await tester.pump();
      await tester.tap(aruTab);
      await tester.pump();
      expect(editor.studentId, 'aru');
      expect(
        find.descendant(of: hoshinoTab, matching: find.text('완료')),
        findsOneWidget,
      );
      expect(
        find.text('${flow.context.displayName('aru')} · 현재 → 최종'),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('plan-flow-goal-card-${_stageId(editor, 0)}')),
        findsOneWidget,
      );
      await _settle(tester);
    });

    testWidgets('미세 조절 → 디바운스 계산 한 번 → 카드 COST·상태·비용 한 줄이 바뀐다', (tester) async {
      final handle = tester.ensureSemantics();
      final service = _CostService();
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['aru']);
      await _pump(tester, flow, editor);
      final stageId = _stageId(editor, 0);
      final level = editor.currentOf('aru')['level']!;
      final cost = find.byKey(ValueKey('plan-flow-goal-$stageId-cost'));
      expect(
        find.descendant(of: cost, matching: find.text('목표를 올리면 비용을 계산합니다')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('plan-flow-goal-$stageId-status')),
          matching: find.text('목표 없음'),
        ),
        findsOneWidget,
      );

      for (var count = 0; count < 3; count++) {
        await tester.tap(_increase(stageId, 'level'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(service.calls, 0);
      expect(
        tester
            .widget<Text>(find.byKey(ValueKey('plan-flow-goal-$stageId-level-value')))
            .data,
        'Lv.${level + 3}',
      );
      await tester.pump(planFlowCalculationDebounce);
      await tester.pump();
      expect(service.calls, 1);
      expect(flow.calculation?.stageCosts[stageId], isNotNull);
      expect(
        find.descendant(of: cost, matching: find.text('오파츠 · 네브라 디스크 (최상급)')),
        findsOneWidget,
      );
      expect(find.descendant(of: cost, matching: find.text('−14')), findsOneWidget);
      expect(find.descendant(of: cost, matching: find.text('충분')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('plan-flow-goal-$stageId-status')),
          matching: find.text('부족 1종'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(ValueKey('plan-flow-goal-$stageId-summary')))
            .data,
        '크레딧 1.8M · 네브라 디스크 (최상급) 90',
      );
      // 계산 결과(유효 상태)를 작업 단계·초안 목표에 되쓰지 않는다.
      expect(_targets(editor, 0)['level'], level + 3);
      expect(flow.draft.stagesByStudent['aru']!.single.goalKeys, {'level'});

      // 의미 구조: 값 + 올리기·낮추기 값(Semantics value 3종)과 동작.
      expect(
        tester.getSemantics(
          find.byKey(ValueKey('plan-flow-goal-$stageId-level-value')),
        ),
        isSemantics(
          label: '레벨 목표',
          value: 'Lv.${level + 3}',
          increasedValue: 'Lv.${level + 4}',
          decreasedValue: 'Lv.${level + 2}',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      // ▼는 앞 단계(지금 값)까지만 내려간다.
      for (var count = 0; count < 4; count++) {
        await tester.tap(_decrease(stageId, 'level'));
        await tester.pump();
      }
      expect(_targets(editor, 0)['level'], level);
      expect(flow.draft.stagesByStudent['aru'], isNull);
      await _settle(tester);
      handle.dispose();
    });

    testWidgets('단계 추가·삭제 버튼과 카드 고르기', (tester) async {
      final service = _CostService();
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['aru']);
      await _pump(tester, flow, editor);
      final first = _stageId(editor, 0);
      expect(
        tester
            .widget<IconButton>(find.byKey(ValueKey('plan-flow-goal-$first-remove')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('plan-flow-goal-add-stage')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-flow-goal-add-stage')));
      await tester.pump();
      expect(editor.stagesOf('aru'), hasLength(3));
      final third = _stageId(editor, 2);
      expect(find.byKey(ValueKey('plan-flow-goal-card-$third')), findsOneWidget);
      expect(
        tester.widget<TextField>(
          find.descendant(
            of: find.byKey(ValueKey('plan-flow-goal-$third-name')),
            matching: find.byType(TextField),
          ),
        ).controller!.text,
        '3단계',
      );
      // 카드 머리 이름 인라인 편집(FD-073).
      await tester.enterText(
        find.byKey(ValueKey('plan-flow-goal-$third-name')),
        '성급 · 전용무기',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(editor.stagesOf('aru')[2].name, '성급 · 전용무기');

      // 카드를 누르면 그 단계를 고르고, 단계 추가는 그 뒤에 넣는다.
      await tester.tap(find.byKey(ValueKey('plan-flow-goal-$first-summary')));
      await tester.pump();
      expect(editor.selectedStageIdOf('aru'), first);
      await tester.tap(
        find.byKey(ValueKey('plan-flow-goal-${_stageId(editor, 1)}-remove')),
      );
      await tester.pump();
      expect(editor.stagesOf('aru').map((stage) => stage.name), [
        '1단계',
        '성급 · 전용무기',
      ]);
      await _settle(tester);
    });

    testWidgets('한 번에 MAX · 직접 입력 세그먼트와 프리셋 세그먼트', (tester) async {
      final service = _CostService();
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(
        service,
        ['aru'],
        presets: [
          PlanElementPreset(
            id: 'balanced-growth',
            name: '테스트 프리셋',
            isDefault: false,
            stages: const [
              {'level': 30},
              {'ex_skill': 4},
            ],
          ),
        ],
      );
      await _pump(tester, flow, editor);
      SkewSegmented<String> segment(String key) =>
          tester.widget<SkewSegmented<String>>(find.byKey(ValueKey(key)));
      expect(segment('plan-flow-goal-mode-direct').selected, isNotNull);
      expect(segment('plan-flow-goal-mode-max').selected, isNull);
      expect(find.text('지금 구성을 프리셋으로'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('plan-flow-goal-mode-max')));
      await tester.pump();
      expect(segment('plan-flow-goal-mode-max').selected, planFlowGoalModeMax);
      final maxStage = _stageId(editor, 0);
      expect(
        tester
            .widget<Text>(find.byKey(ValueKey('plan-flow-goal-$maxStage-level-value')))
            .data,
        'Lv.90',
      );

      await tester.tap(
        find.byKey(const ValueKey('plan-flow-goal-preset-balanced-growth')),
      );
      await tester.pump();
      expect(editor.stagesOf('aru'), hasLength(2));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('plan-flow-goal-aside-preset-balanced-growth')),
          matching: find.text('적용 중'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('plan-flow-goal-mode-direct')));
      await tester.pump();
      expect(editor.stagesOf('aru'), hasLength(1));
      expect(flow.draft.stagesByStudent['aru'], isNull);
      // C 프리셋 행으로도 적용한다.
      await tester.tap(
        find.byKey(const ValueKey('plan-flow-goal-aside-preset-balanced-growth')),
      );
      await tester.pump();
      expect(editor.modeOf('aru'), planFlowGoalPresetMode('balanced-growth'));
      await _settle(tester);
    });

    testWidgets('현재 → 최종 × 는 그 목표를 모든 단계에서 지운다', (tester) async {
      final service = _CostService();
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(
        service,
        ['aru'],
        presets: [
          PlanElementPreset(
            id: 'p',
            name: '두 단계',
            isDefault: false,
            stages: const [
              {'level': 30, 'ex_skill': 3},
              {'level': 50},
            ],
          ),
        ],
      );
      editor.applyMode(planFlowGoalPresetMode('p'));
      await _pump(tester, flow, editor);
      expect(
        find.byKey(const ValueKey('plan-flow-goal-clear-level')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('plan-flow-goal-clear-bond')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('plan-flow-goal-clear-level')));
      await tester.pump();
      final drafted = flow.draft.stagesByStudent['aru']!;
      expect(drafted, hasLength(1));
      expect(drafted.single.targets['level'], isNull);
      expect(drafted.single.targets['ex_skill'], 3);
      expect(find.byKey(const ValueKey('plan-flow-goal-clear-level')), findsNothing);
      await _settle(tester);
    });

    testWidgets('성급 9칸 · 장비 티어 ◀▶ · 더 보기 스테퍼(FD-072)', (tester) async {
      final service = _CostService();
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['aru']);
      await _pump(tester, flow, editor);
      final stageId = _stageId(editor, 0);
      final star = editor.currentOf('aru')['student_star']!;
      expect(star, lessThan(4));
      await tester.tap(
        find.byKey(ValueKey('plan-flow-goal-$stageId-student-star-4')),
      );
      await tester.pump();
      expect(_targets(editor, 0)['student_star'], 4);
      // 고른 칸을 다시 누르면 한 칸 아래까지(기존 성급 스트립과 같다).
      await tester.tap(
        find.byKey(ValueKey('plan-flow-goal-$stageId-student-star-4')),
      );
      await tester.pump();
      expect(_targets(editor, 0)['student_star'], 3);
      // 전용무기 칸은 5성이 필요해서 학생 성급도 함께 오른다.
      await tester.tap(
        find.byKey(ValueKey('plan-flow-goal-$stageId-weapon-star-2')),
      );
      await tester.pump();
      expect(_targets(editor, 0)['weapon_star'], 2);
      expect(_targets(editor, 0)['student_star'], 5);

      final tier = _targets(editor, 0)['equip1_tier']!;
      await tester.tap(_sideIncrease(stageId, 'equip1_tier'));
      await tester.pump();
      expect(_targets(editor, 0)['equip1_tier'], tier + 1);

      // 더 보기: 장비 레벨 · 애장품 · 추가 능력치 · 무기 성급을 스테퍼로 고친다.
      await tester.tap(find.byKey(ValueKey('plan-flow-goal-$stageId-more')));
      await tester.pump();
      expect(editor.expandedStageId, stageId);
      final levelBefore = _targets(editor, 0)['equip1_level']!;
      await tester.tap(
        find.byKey(ValueKey('plan-flow-goal-$stageId-equip1_level-increase')),
      );
      await tester.pump();
      expect(_targets(editor, 0)['equip1_level'], levelBefore + 1);
      await tester.tap(
        find.byKey(ValueKey('plan-flow-goal-$stageId-stat_hp-max')),
      );
      await tester.pump();
      expect(_targets(editor, 0)['stat_hp'], planElementTargetMaximums['stat_hp']);
      // 추가 능력치는 레벨 90 · 5성이 필요하다.
      expect(_targets(editor, 0)['level'], 90);
      await tester.tap(find.byKey(ValueKey('plan-flow-goal-$stageId-less')));
      await tester.pump();
      expect(editor.expandedStageId, isNull);
      expect(find.byKey(ValueKey('plan-flow-goal-$stageId-cost')), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('C 보조: 다른 학생에도 적용 · 모두 적용 · 이 학생 재화 요약', (tester) async {
      final service = _CostService();
      addTearDown(service.dispose);
      final (flow, editor) = await _setup(service, ['aru', 'hoshino', 'hina']);
      await _pump(tester, flow, editor);
      final apply = find.byKey(const ValueKey('plan-flow-goal-apply-hoshino'));
      // 직접 입력은 다른 학생에게 적용하지 않는다.
      expect(tester.widget<TonalButton>(apply).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('plan-flow-goal-mode-max')));
      await tester.pump();
      await tester.tap(apply);
      await tester.pump();
      expect(editor.modeOf('hoshino'), planFlowGoalModeMax);
      expect(editor.studentId, 'aru');
      await tester.tap(find.byKey(const ValueKey('plan-flow-goal-apply-all')));
      await tester.pump();
      expect(flow.draft.completedStudentCount, 3);
      await tester.pump(planFlowCalculationDebounce);
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('plan-flow-goal-aside-resources')))
            .data,
        '2종',
      );
      await _settle(tester);
    });

    testWidgets('미보유 학생: 탭 · 지금 상태 카드 · 단계 상태에 모집 필요를 단다(FD-076)', (tester) async {
      final service = _CostService();
      addTearDown(service.dispose);
      final flow = await _flow(service);
      final unowned = _unownedId(flow);
      flow.addStudents([unowned]);
      flow.goTo(PlanFlowStep.goals);
      final editor = PlanFlowGoalEditor(flow: flow);
      addTearDown(editor.dispose);
      await _pump(tester, flow, editor);
      expect(find.byKey(const ValueKey('plan-flow-goal-recruit')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('plan-flow-goal-tab-$unowned')),
          matching: find.text('미보유'),
        ),
        findsOneWidget,
      );
      final stageId = _stageId(editor, 0);
      await tester.tap(_increase(stageId, 'level'));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(ValueKey('plan-flow-goal-$stageId-status')),
          matching: find.text('모집 필요'),
        ),
        findsOneWidget,
      );
      await _settle(tester);
    });
  });
}
