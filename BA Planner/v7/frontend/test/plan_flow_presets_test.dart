// 단계 프리셋·내 그룹 저장 연결 테스트(FE4-i, FB-14): 저장소 상태([RepositoryPresetsController])의 전체 교체·
// revision·idempotency·실패 처리(revision_conflict → 다시 읽고 편집을 남김, 재시도 가능 → 같은 요청, idempotency_conflict
// → 새 키 없음), 단계 프리셋 원본(19키 nullable·단계 이름) 저장과 적용(단계 이름), 내 그룹(목록에 없는 학생 보존),
// 2단계 프리셋 바·C 행(저장·이름 바꾸기·삭제), 1단계 내 그룹(저장·불러오기·삭제), 계산기 빠른 목표의 프리셋 항목.
//
// 2단계 계산 디바운스는 Timer라서 위젯 테스트 끝에서 흘린다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_rules.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_state.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_goal_editor.dart';
import 'package:ba_planner_v7/ui/models/planning_growth_rules.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/models/repository_presets_controller.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_goal_step.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_student_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

/// 콘텐츠 캔버스(기준 viewport 2560×1392에서 헤더 184 아래).
const _canvas = Size(2560, 1208);

/// 저장 요청을 기록하고, [failures]가 있으면 그 오류를 하나씩 먼저 던지는 mock.
class _PresetsService extends MockAppService {
  _PresetsService({super.fullStudentCatalog});

  final saves = <RepositoryPresetsSaveRequest>[];
  final failures = <Object>[];
  int loads = 0;

  @override
  Future<RepositoryPresetsState> loadRepositoryPresets(String profileId) {
    loads += 1;
    return super.loadRepositoryPresets(profileId);
  }

  @override
  Future<int> saveRepositoryPresets(RepositoryPresetsSaveRequest request) {
    saves.add(request);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return super.saveRepositoryPresets(request);
  }
}

/// 19키 목표(적지 않은 키는 null).
Map<String, int?> _targets(Map<String, int> values) => {
  for (final key in planningDocumentTargetKeys) key: values[key],
};

RepositoryPresetStage _stage(String name, Map<String, int> values) =>
    RepositoryPresetStage(name: name, targets: _targets(values));

Future<RepositoryPresetsController> _store(MockAppService service) async {
  final store = RepositoryPresetsController(
    service: service,
    profileId: _profileId,
  );
  addTearDown(store.dispose);
  await store.load();
  return store;
}

/// 다른 곳(다른 창)에서 묶음을 저장한다.
Future<int> _saveElsewhere(
  MockAppService service, {
  List<RepositoryStagePreset> presets = const [],
  List<RepositoryStudentGroup> groups = const [],
}) async {
  final current = await service.loadRepositoryPresets(_profileId);
  return service.saveRepositoryPresets(
    RepositoryPresetsSaveRequest(
      profileId: _profileId,
      expectedRevision: current.revision,
      idempotencyKey: 'elsewhere-${current.revision}',
      stagePresets: [...current.stagePresets, ...presets],
      studentGroups: [...current.studentGroups, ...groups],
    ),
  );
}

Future<PlanFlowController> _flow(MockAppService service) async {
  final state = await service.loadRepositoryState(_profileId);
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

Future<void> _pumpCanvas(WidgetTester tester, List<Widget> layers) async {
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
                for (final layer in layers) Positioned.fill(child: layer),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 계산 디바운스 Timer를 흘린다.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(planFlowCalculationDebounce);
  await tester.pump(planFlowGoalPropagationHighlight);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('저장소 상태(FB-14 연결)', () {
    test('단계 프리셋은 이름과 19키 nullable 원본 그대로 두 목록 전체 교체로 저장하고 다시 읽는다', () async {
      final service = _PresetsService();
      addTearDown(service.dispose);
      await _saveElsewhere(
        service,
        groups: [
          RepositoryStudentGroup(
            groupId: 'g1',
            name: '그대로 둘 그룹',
            studentIds: const ['aru'],
          ),
        ],
      );
      final store = await _store(service);
      expect(store.state!.revision, 1);
      final loadsBefore = service.loads;
      final saved = await store.addStagePreset(
        name: '총력전 2단계',
        stages: [
          _stage('성장 기반', {'level': 90}),
          _stage('스킬', {'level': 90, 'ex_skill': 5}),
        ],
      );
      expect(saved, isTrue);
      final request = service.saves.last;
      expect(request.expectedRevision, 1);
      expect(request.idempotencyKey, isNotEmpty);
      // 바꾸지 않은 그룹 목록도 함께 보낸다(전체 교체).
      expect(request.studentGroups.single.groupId, 'g1');
      final stage = request.stagePresets.single.stages.first;
      expect(stage.name, '성장 기반');
      expect(stage.targets.length, planningDocumentTargetKeys.length);
      expect(stage.targets['level'], 90);
      expect(stage.targets['ex_skill'], isNull);
      // 저장한 뒤 돌려받은 revision만 믿지 않고 다시 읽는다.
      expect(service.loads, loadsBefore + 1);
      expect(store.state!.revision, 2);
      expect(store.stagePresets.single.name, '총력전 2단계');
      expect(store.message!.error, isFalse);
      expect(store.pendingRequest, isNull);
    });

    test('이름 바꾸기·삭제는 다른 프리셋과 그룹을 그대로 둔다', () async {
      final service = _PresetsService();
      addTearDown(service.dispose);
      final store = await _store(service);
      await store.addStagePreset(name: '하나', stages: [_stage('1', {'level': 10})]);
      await store.addStagePreset(name: '둘', stages: [_stage('1', {'level': 20})]);
      await store.addStudentGroup(name: '그룹', studentIds: const ['aru']);
      final first = store.stagePresets.first.presetId;
      expect(await store.renameStagePreset(first, '  새 이름  '), isTrue);
      expect(store.stagePresets.map((preset) => preset.name), ['새 이름', '둘']);
      expect(await store.renameStagePreset(first, '   '), isFalse);
      expect(await store.deleteStagePreset(first), isTrue);
      expect(store.stagePresets.map((preset) => preset.name), ['둘']);
      expect(store.studentGroups.single.name, '그룹');
      expect(store.state!.revision, 5);
    });

    test('그룹은 카탈로그에 없는 학생 ID도 순서 그대로 저장하고, 지워도 다른 그룹은 남는다', () async {
      final service = _PresetsService();
      addTearDown(service.dispose);
      final store = await _store(service);
      await store.addStudentGroup(
        name: '미래 학생 포함',
        studentIds: const ['hoshino', 'future_student_kr', 'aru', 'hoshino'],
      );
      await store.addStudentGroup(name: '둘째', studentIds: const ['aru']);
      expect(store.studentGroups.first.studentIds, [
        'hoshino',
        'future_student_kr',
        'aru',
      ]);
      final reloaded = await service.loadRepositoryPresets(_profileId);
      expect(reloaded.studentGroups.first.studentIds, contains('future_student_kr'));
      await store.deleteStudentGroup(store.studentGroups.first.groupId);
      expect(store.studentGroups.single.name, '둘째');
    });

    test('revision_conflict: 최신 묶음을 다시 읽고 편집을 남겨 두었다가 다시 저장에 최신 목록 위로 적용한다', () async {
      final service = _PresetsService();
      addTearDown(service.dispose);
      final store = await _store(service);
      await _saveElsewhere(
        service,
        presets: [
          RepositoryStagePreset(
            presetId: 'elsewhere',
            name: '다른 창',
            stages: [_stage('1', {'level': 30})],
          ),
        ],
      );
      final saved = await store.addStagePreset(
        name: '내 편집',
        stages: [_stage('1', {'level': 40})],
      );
      expect(saved, isFalse);
      expect(store.message!.error, isTrue);
      expect(store.message!.text, contains('최신 목록을 다시 읽었습니다'));
      // 다시 읽은 최신 목록(다른 창의 프리셋), 하려던 편집은 아직 저장되지 않았다.
      expect(store.state!.revision, 1);
      expect(store.stagePresets.map((preset) => preset.name), ['다른 창']);
      expect(store.canRetry, isTrue);
      final conflictKey = service.saves.last.idempotencyKey;
      expect(await store.retry(), isTrue);
      expect(service.saves.last.expectedRevision, 1);
      expect(service.saves.last.idempotencyKey, isNot(conflictKey));
      expect(store.stagePresets.map((preset) => preset.name), ['다른 창', '내 편집']);
      expect(store.canRetry, isFalse);
    });

    test('재시도할 수 있는 실패는 같은 키·같은 내용으로 다시 보낸다', () async {
      final service = _PresetsService();
      addTearDown(service.dispose);
      final store = await _store(service);
      service.failures.add(
        BackendRemoteException(
          code: 'repository_busy',
          message: 'busy',
          retryable: true,
        ),
      );
      expect(
        await store.addStudentGroup(name: '그룹', studentIds: const ['aru']),
        isFalse,
      );
      final pending = store.pendingRequest;
      expect(pending, isNotNull);
      expect(store.canRetry, isTrue);
      expect(store.message!.text, contains('같은 요청을 그대로'));
      expect(await store.retry(), isTrue);
      expect(service.saves, hasLength(2));
      expect(service.saves.last, same(pending));
      expect(service.saves.last.idempotencyKey, service.saves.first.idempotencyKey);
      expect(store.studentGroups.single.name, '그룹');
    });

    test('idempotency_conflict: 새 키를 저절로 만들지 않고 다시 읽는다', () async {
      final service = _PresetsService();
      addTearDown(service.dispose);
      final store = await _store(service);
      service.failures.add(
        BackendRemoteException(
          code: 'idempotency_conflict',
          message: 'Key belongs to another preset save',
        ),
      );
      expect(
        await store.addStagePreset(name: 'p', stages: [_stage('1', {'level': 5})]),
        isFalse,
      );
      expect(service.saves, hasLength(1));
      expect(store.pendingRequest, isNull);
      expect(store.canRetry, isFalse);
      expect(store.message!.error, isTrue);
      expect(store.stagePresets, isEmpty);
    });

    test('저장소가 아닌 서비스는 쓸 수 없고 목록은 비어 있다', () async {
      final store = RepositoryPresetsController(
        service: Object(),
        profileId: _profileId,
      );
      addTearDown(store.dispose);
      await store.load();
      expect(store.available, isFalse);
      expect(store.canEdit, isFalse);
      expect(store.stagePresets, isEmpty);
    });
  });

  group('단계 프리셋 적용(FD-074)', () {
    test('저장된 프리셋은 non-null 목표만 듬성한 목표로, 단계 이름과 함께 적용 모델이 된다', () {
      final preset = planElementPresetFromRepository(
        RepositoryStagePreset(
          presetId: 'p1',
          name: '총력전',
          stages: [
            _stage('성장 기반', {'level': 90}),
            _stage('스킬', {'level': 90, 'ex_skill': 5}),
          ],
        ),
      );
      expect(preset.id, 'stored:p1');
      expect(preset.repositoryPresetId, 'p1');
      expect(preset.stages, [
        {'level': 90},
        {'level': 90, 'ex_skill': 5},
      ]);
      expect(preset.stageNames, ['성장 기반', '스킬']);
      expect(preset.stageNameAt(2), isNull);
    });

    test('2단계에서 저장된 프리셋을 적용하면 카드 이름이 저장된 단계 이름이다', () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final flow = await _flow(service);
      flow.addStudents(['aru']);
      flow.goTo(PlanFlowStep.goals);
      final preset = planElementPresetFromRepository(
        RepositoryStagePreset(
          presetId: 'p1',
          name: '총력전',
          stages: [
            _stage('성장 기반', {'level': 90}),
            _stage('스킬', {'level': 90, 'ex_skill': 5}),
          ],
        ),
      );
      final editor = PlanFlowGoalEditor(flow: flow, presets: [preset]);
      addTearDown(editor.dispose);
      editor.applyMode(planFlowGoalPresetMode(preset.id));
      expect(editor.stagesOf('aru').map((stage) => stage.name), [
        '성장 기반',
        '스킬',
      ]);
      // 저장에 쓰는 단계는 초안 v2 원본이다(올리지 않은 키는 null).
      final stages = editor.presetStagesOf('aru');
      expect(stages.map((stage) => stage.name), ['성장 기반', '스킬']);
      expect(stages.first.targets['ex_skill'], isNull);
      expect(stages.last.targets['ex_skill'], 5);
    });
  });

  testWidgets('2단계: 지금 구성을 프리셋으로 저장하고 C에서 이름 바꾸기·지우기', (tester) async {
    final service = _PresetsService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    final flow = await _flow(service);
    flow.addStudents(['aru']);
    flow.goTo(PlanFlowStep.goals);
    final store = await _store(service);
    final editor = PlanFlowGoalEditor(flow: flow);
    addTearDown(editor.dispose);
    void sync() => editor.updatePresets([
      for (final preset in store.stagePresets)
        planElementPresetFromRepository(preset),
    ]);
    store.addListener(sync);
    addTearDown(() => store.removeListener(sync));
    await _pumpCanvas(tester, [
      PlanFlowGoalBody(flow: flow, editor: editor, presets: store),
      PlanFlowGoalAside(flow: flow, editor: editor, presets: store),
    ]);
    // 단계가 없으면 저장할 수 없다.
    final saveFinder = find.byKey(const ValueKey('plan-flow-goal-preset-save'));
    expect(tester.widget<TonalButton>(saveFinder).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('plan-flow-goal-mode-max')));
    await _settle(tester);
    expect(tester.widget<TonalButton>(saveFinder).onPressed, isNotNull);
    await tester.tap(saveFinder);
    await _settle(tester);
    final saved = service.saves.single.stagePresets.single;
    expect(saved.name, endsWith('목표 1단계'));
    expect(saved.stages.single.name, '1단계');
    expect(
      saved.stages.single.targets,
      flow.draft.stagesByStudent['aru']!.single.targets,
    );
    final presetId = 'stored:${saved.presetId}';
    expect(
      find.byKey(ValueKey('plan-flow-goal-aside-preset-$presetId')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plan-flow-goal-presets-message')), findsOneWidget);

    // 이름 바꾸기: 행 안 입력.
    await tester.tap(find.byKey(ValueKey('plan-flow-goal-aside-preset-$presetId-rename')));
    await tester.pump();
    await tester.enterText(
      find.byKey(ValueKey('plan-flow-goal-aside-preset-$presetId-name-field')),
      '아루 육성',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    expect(store.stagePresets.single.name, '아루 육성');
    expect(find.text('아루 육성'), findsWidgets);

    // 지우기.
    await tester.tap(find.byKey(ValueKey('plan-flow-goal-aside-preset-$presetId-delete')));
    await _settle(tester);
    expect(store.stagePresets, isEmpty);
    expect(
      find.byKey(ValueKey('plan-flow-goal-aside-preset-$presetId')),
      findsNothing,
    );
  });

  testWidgets('1단계: 지금 고른 학생으로 그룹을 만들고, 눌러 고르고, 지운다', (tester) async {
    final service = _PresetsService();
    addTearDown(service.dispose);
    await _saveElsewhere(
      service,
      groups: [
        RepositoryStudentGroup(
          groupId: 'saved',
          name: '저장된 그룹',
          studentIds: const ['ayane', 'future_student_kr'],
        ),
      ],
    );
    final flow = await _flow(service);
    final picker = PlanFlowStudentPicker(context: flow.context);
    addTearDown(picker.dispose);
    final store = await _store(service);
    await _pumpCanvas(tester, [
      PlanFlowStudentAside(flow: flow, picker: picker, presets: store),
    ]);
    // 목록에 없는 학생은 고르지 않지만 그룹에는 남는다.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('plan-flow-group-saved-count')))
          .data,
      '1명 · 목록에 없음 1',
    );
    final saveFinder = find.byKey(const ValueKey('plan-flow-group-save'));
    expect(tester.widget<TonalButton>(saveFinder).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('plan-flow-group-saved')));
    await tester.pump();
    expect(flow.selectedStudentIds, ['ayane']);

    flow.addStudents(['aru']);
    await tester.pump();
    await tester.tap(saveFinder);
    await tester.pumpAndSettle();
    final request = service.saves.last;
    // 다른 그룹(목록에 없는 학생 포함)은 그대로 보낸다.
    expect(request.studentGroups.first.studentIds, ['ayane', 'future_student_kr']);
    expect(request.studentGroups.last.studentIds, ['ayane', 'aru']);
    expect(store.studentGroups, hasLength(2));

    final newId = store.studentGroups.last.groupId;
    await tester.tap(find.byKey(ValueKey('plan-flow-group-$newId-delete')));
    await tester.pumpAndSettle();
    expect(store.studentGroups.single.groupId, 'saved');
    expect(store.studentGroups.single.studentIds, ['ayane', 'future_student_kr']);
  });

  group('계산기 빠른 목표의 프리셋 항목(FD-169)', () {
    test('프리셋 마지막 단계가 정한 키만 올리고 나머지는 현재값이다', () {
      final current = {...planElementTargetMinimums, 'level': 40};
      final result = growthCalculatorPresetTargets(
        current: current,
        presetTargets: _targets({'level': 70, 'skill1': 4}),
        hasFavoriteItem: false,
      );
      expect(result['level'], 70);
      expect(result['skill1'], 4);
      expect(result['ex_skill'], current['ex_skill']);
      expect(result['equip1_tier'], current['equip1_tier']);
      // 현재값보다 낮은 목표는 현재값이다.
      final lower = growthCalculatorPresetTargets(
        current: current,
        presetTargets: _targets({'level': 10}),
        hasFavoriteItem: false,
      );
      expect(lower['level'], 40);
    });

    test('계산기 상태에 프리셋 항목을 적용한다', () {
      final current = {...planElementTargetMinimums, 'level': 40};
      final state = GrowthCalculatorState(
        studentId: 'aru',
        confirmedCurrent: current,
        hasFavoriteItem: false,
      );
      addTearDown(state.dispose);
      final preset = GrowthCalculatorPresetTarget(
        id: 'p1',
        name: '총력전',
        targets: _targets({'level': 70}),
      );
      expect(preset.hasTargets, isTrue);
      state.applyPresetTarget(preset);
      expect(state.targets['level'], 70);
      expect(
        GrowthCalculatorPresetTarget(
          id: 'p2',
          name: '빈 단계',
          targets: _targets(const {}),
        ).hasTargets,
        isFalse,
      );
    });
  });
}
