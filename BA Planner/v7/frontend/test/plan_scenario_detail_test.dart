// 시나리오 보기 모드 테스트(FE5-c1, 시안 Scenario-Detail-Bottleneck, FD-034 · FD-035 · FD-038 · FD-039 · FD-088).
//
// - 모델: 단계 상태(여기서 막힘 / 앞 단계 대기, 병목 단계 앞의 affected 단계는 빼기), 끝까지 가는 학생 n/m, 단계 맞춤
//   (stage_id → (학생, 순번)), 재화 ±(부족량 · 필요량 회색 · 크레딧), 병목 카드 묶음 · 채움 · 지연 단계, KPI.
// - Detail 위젯: 카드 선택 ↔ 단계 행 분홍 강조, 비교를 끄면 KPI · 활성 대비 칩이 없다.
// - 계획 화면: 목록에서 열면 미리보기 캐시를 그대로 쓴다(compare 다시 부르지 않음), 목록으로 돌아가기, 계획에 적용 2선택
//   → 계획 만들기 4단계가 고른 위치로 열린다(FE4-e 저장 경로).
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/kit/diagonal_row.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_preview.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

String _format(int value) => '$value';

Map<String, int?> _targets({int level = 80, int tier = 0}) => {
  for (final key in planningDocumentTargetKeys) key: 0,
  'level': level,
  'student_star': 3,
  'bond_rank': 1,
  'ex_skill': 3,
  'skill1': 7,
  'skill2': 7,
  'skill3': 7,
  'equip1_tier': tier,
  'equip2_tier': tier,
  'equip3_tier': tier,
};

PlanningDocumentStage _stage(
  String id,
  String studentId, {
  String name = '1단계',
  int level = 80,
  int tier = 0,
}) => PlanningDocumentStage(
  id: id,
  studentId: studentId,
  name: name,
  targets: _targets(level: level, tier: tier),
);

/// 시나리오 문서: P1 아야네 1 · 아루 1, P2 아루 2 · 호시노 1, P3 케이 1.
PlanningDocument _scenario() => PlanningDocument(
  id: 'scenario',
  name: 'scenario',
  kind: PlanningDocumentKind.scenario,
  phases: [
    PlanningDocumentPhase(
      id: 'p1',
      name: '리오 먼저',
      stages: [_stage('y1', 'ayane'), _stage('a1', 'aru')],
    ),
    PlanningDocumentPhase(
      id: 'p2',
      name: '스킬 마무리',
      stages: [
        _stage('a2', 'aru', name: '2단계', level: 90),
        _stage('h1', 'hoshino', level: 90),
      ],
    ),
    PlanningDocumentPhase(
      id: 'p3',
      name: '케이',
      stages: [_stage('k1', 'kei')],
    ),
  ],
);

/// 활성 계획: 아야네 1(같은 id, 낮은 목표 아님), 호시노 1(id 다름 · 레벨 더 높음), 아루 없음.
PlanningDocument _active() => PlanningDocument(
  id: 'active-plan',
  name: '활성 계획',
  kind: PlanningDocumentKind.plan,
  phases: [
    PlanningDocumentPhase(
      id: 'ap1',
      name: '페이즈 1',
      stages: [
        _stage('y1', 'ayane'),
        _stage('other-h1', 'hoshino', level: 100),
      ],
    ),
  ],
);

Map<String, dynamic> _resource(
  String key,
  int required, {
  int? owned,
  String category = 'oopart',
}) => {
  'resource_key': key,
  'item_id': key == 'credits' ? null : key,
  'display_name': key,
  'category': key == 'credits' ? 'credits' : category,
  'required': required,
  'owned_at_entry': owned ?? required,
  'shortage_at_entry': owned == null ? 0 : (required - owned).clamp(0, required),
};

/// 시나리오 projection: a1에서 r1 · r2 · r3 · r4가 모자라고(카드 1장, 타일 3 + 숨김 1), a2에서 r5(affected 없음 →
/// 전체 줄의 것)가 모자란다. r1은 y1(앞) · a1 · h1을 쓴다 → h1 대기. 케이는 어디에도 없다.
Map<String, dynamic> _projection() => {
  'stage_results': [
    {
      'stage_id': 'y1',
      'phase_id': 'p1',
      'student_id': 'ayane',
      'resources': [_resource('r1', 3)],
    },
    {
      'stage_id': 'a1',
      'phase_id': 'p1',
      'student_id': 'aru',
      'resources': [
        _resource('credits', 1000),
        _resource('r1', 10, owned: 2),
        _resource('r2', 10, owned: 5),
        _resource('r3', 10, owned: 6),
        _resource('r4', 10, owned: 7),
      ],
    },
    {
      'stage_id': 'a2',
      'phase_id': 'p2',
      'student_id': 'aru',
      'resources': [_resource('credits', 500), _resource('r5', 4, owned: 1)],
    },
    {
      'stage_id': 'h1',
      'phase_id': 'p2',
      'student_id': 'hoshino',
      'resources': [_resource('r1', 3)],
    },
    {
      'stage_id': 'k1',
      'phase_id': 'p3',
      'student_id': 'kei',
      'resources': [_resource('credits', 100)],
    },
  ],
  'overall': {
    'cost': {'credits': 1600},
    'resources': [
      {
        'resource_key': 'r5',
        'shortage': 3,
        'affected_stage_ids': ['a2', 'h1'],
      },
      {'resource_key': 'credits', 'shortage': 0},
    ],
  },
  'bottlenecks': [
    for (final (key, shortage) in const [
      ('r1', 8),
      ('r2', 5),
      ('r3', 4),
      ('r4', 3),
    ])
      {
        'resource_key': key,
        'item_id': key,
        'display_name': key,
        'category': 'oopart',
        'remaining_at_entry': 10 - shortage,
        'required_at_entry': 10,
        'shortage': shortage,
        'phase_number': 1,
        'stage_id': 'a1',
        'affected_stage_ids': key == 'r1'
            ? const ['y1', 'a1', 'h1']
            : const ['a1'],
      },
    {
      'resource_key': 'r5',
      'item_id': 'r5',
      'display_name': 'r5',
      'category': 'oopart',
      'remaining_at_entry': 1,
      'required_at_entry': 4,
      'shortage': 3,
      'phase_number': 2,
      'stage_id': 'a2',
    },
  ],
};

void main() {
  group('단계 상태(FD-035) · 끝까지 가는 학생(FD-034 (a))', () {
    test('병목 단계 앞의 affected 단계는 기다리지 않고, 병목 줄에 없으면 전체 줄을 쓴다', () {
      final states = PlanDetailStageStates.fromProjection(_projection())!;
      expect(states.stateOf('a1'), PlanDetailStageState.blockedHere);
      expect(states.stateOf('a2'), PlanDetailStageState.blockedHere);
      // y1은 r1을 a1보다 먼저 쓴다(대기 아님). h1은 r1(a1 뒤) · r5(a2 뒤, 전체 줄)로 대기.
      expect(states.stateOf('y1'), PlanDetailStageState.clear);
      expect(states.stateOf('h1'), PlanDetailStageState.waiting);
      expect(states.stateOf('k1'), PlanDetailStageState.clear);
      // 아루(막힘) · 호시노(대기)는 끝까지 가지 못한다. 아야네 · 케이는 간다.
      expect(states.finishingStudents, 2);
      expect(states.students, ['ayane', 'aru', 'hoshino', 'kei']);
    });

    test('자기 단계가 병목이면서 앞 병목을 기다리면 앞 단계 대기다', () {
      final states = PlanDetailStageStates.fromProjection({
        'stage_results': [
          {'stage_id': 's1', 'student_id': 'aru'},
          {'stage_id': 's2', 'student_id': 'hoshino'},
        ],
        'bottlenecks': [
          {
            'resource_key': 'x',
            'stage_id': 's1',
            'affected_stage_ids': ['s1', 's2'],
          },
          {
            'resource_key': 'y',
            'stage_id': 's2',
            'affected_stage_ids': ['s2'],
          },
        ],
      })!;
      expect(states.stateOf('s2'), PlanDetailStageState.waiting);
      expect(states.finishingStudents, 0);
    });

    test('stage_results가 없으면 모른다', () {
      expect(PlanDetailStageStates.fromProjection(const {}), isNull);
    });
  });

  group('단계 맞춤(FD-039) · 재화 ±(FD-038 (c)) · 병목 칩', () {
    test('stage_id가 먼저, 없으면 (학생, 학생 안 순번)', () {
      final matches = planScenarioStageMatches(
        active: _active(),
        scenario: _scenario(),
      );
      expect(matches['y1']?.id, 'y1');
      expect(matches['h1']?.id, 'other-h1');
      expect(matches['a1'], isNull);
      expect(matches['a2'], isNull);
      final scenario = _scenario();
      final h1 = scenario.stages.firstWhere((stage) => stage.id == 'h1');
      expect(
        planScenarioStageDelta(h1, matches['h1']),
        const PlanScenarioDelta('활성보다 낮은 목표', PlanScenarioDeltaTone.better),
      );
      final a1 = scenario.stages.firstWhere((stage) => stage.id == 'a1');
      expect(
        planScenarioStageDelta(a1, null),
        const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only),
      );
    });

    test('부족량 차이, 둘 다 부족 0이면 필요량 차이(회색), 크레딧은 필요량 차이', () {
      expect(
        planScenarioResourceDelta(const {
          'category': 'oopart',
          'required_a': 30,
          'required_b': 42,
          'shortage_a': 18,
          'shortage_b': 30,
        }, format: _format, prefix: '활성보다 '),
        const PlanScenarioDelta('활성보다 +12', PlanScenarioDeltaTone.worse),
      );
      expect(
        planScenarioResourceDelta(const {
          'category': 'student_eleph',
          'required_a': 272,
          'required_b': 212,
          'shortage_a': 0,
          'shortage_b': 0,
        }, format: _format),
        const PlanScenarioDelta('−60', PlanScenarioDeltaTone.same),
      );
      expect(
        planScenarioResourceDelta(const {
          'category': 'credits',
          'required_a': 100,
          'required_b': 40,
          'shortage_a': 0,
          'shortage_b': 0,
        }, format: _format),
        const PlanScenarioDelta('−60', PlanScenarioDeltaTone.better),
      );
      expect(
        planScenarioResourceDelta(const {
          'category': 'oopart',
          'required_a': 0,
          'required_b': 5,
          'shortage_a': 0,
          'shortage_b': 5,
        }, format: _format, prefix: '활성보다 '),
        const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only),
      );
      expect(planScenarioResourceDelta(null, format: _format), isNull);
    });

    test('병목 칩: 이 시나리오에만 · 빨리 · 늦게 · 줄어듦 · 같음', () {
      expect(
        planScenarioBottleneckDelta(const {'first_phase_b': 1}),
        const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only),
      );
      expect(
        planScenarioBottleneckDelta(const {
          'first_phase_a': 2,
          'first_phase_b': 1,
        })?.label,
        '활성보다 1페이즈 빨리',
      );
      expect(
        planScenarioBottleneckDelta(const {
          'first_phase_a': 1,
          'first_phase_b': 3,
        })?.label,
        '활성보다 2페이즈 늦게',
      );
      expect(
        planScenarioBottleneckDelta(const {
          'first_phase_a': 2,
          'first_phase_b': 2,
          'shortage_a': 9,
          'shortage_b': 3,
        }),
        const PlanScenarioDelta('부족 줄어듦', PlanScenarioDeltaTone.better),
      );
      expect(
        planScenarioBottleneckDelta(const {
          'first_phase_a': 2,
          'first_phase_b': 2,
          'shortage_a': 3,
          'shortage_b': 3,
        })?.label,
        '활성 계획과 같음',
      );
      expect(planScenarioBottleneckDelta(const {'first_phase_a': 1}), isNull);
    });
  });

  group('Detail 데이터', () {
    PlanDetailData data({bool comparison = true}) =>
        PlanDetailData.fromProjection(
          document: _scenario(),
          projection: _projection(),
          format: _format,
          comparison: comparison
              ? PlanDetailComparison(
                  active: _active(),
                  projectionA: const {
                    'stage_results': [
                      {'stage_id': 'y1', 'student_id': 'ayane'},
                      {'stage_id': 'other-h1', 'student_id': 'hoshino'},
                    ],
                    'bottlenecks': [
                      {
                        'resource_key': 'r1',
                        'phase_number': 1,
                        'stage_id': 'y1',
                        'affected_stage_ids': ['y1'],
                      },
                    ],
                  },
                  comparison: const {
                    'credits_a': 2000,
                    'credits_b': 1600,
                    'known_shortage_type_count_a': 3,
                    'known_shortage_type_count_b': 5,
                    'resources': [
                      {
                        'resource_key': 'r1',
                        'category': 'oopart',
                        'required_a': 0,
                        'required_b': 16,
                        'shortage_a': 0,
                        'shortage_b': 8,
                      },
                      {
                        'resource_key': 'credits',
                        'category': 'credits',
                        'required_a': 2000,
                        'required_b': 1600,
                        'shortage_a': 0,
                        'shortage_b': 0,
                      },
                    ],
                    'bottlenecks': [
                      {
                        'resource_key': 'r1',
                        'first_phase_a': 1,
                        'first_phase_b': 1,
                        'shortage_a': 8,
                        'shortage_b': 8,
                      },
                      {'resource_key': 'r5', 'first_phase_b': 2},
                      {'resource_key': 'r9', 'first_phase_a': 1},
                    ],
                  },
                )
              : null,
        );

    test('같은 단계 병목은 카드 한 장, 타일 3개 + 숨김, 충분한 재화로 채우기, 지연 단계', () {
      final value = data();
      expect(value.cards, hasLength(2));
      final first = value.cards.first;
      expect(first.number, 1);
      expect(first.stageId, 'a1');
      expect(first.phase, 1);
      expect(first.resources.map((item) => item.resourceKey), [
        'r1',
        'r2',
        'r3',
      ]);
      expect(first.hiddenShortages, 1);
      expect(first.primary.shortage, 8);
      expect(first.primary.ownedAtEntry, 2);
      expect(first.delayed.map((stage) => stage.stageId), ['h1']);
      expect(first.delayed.single.phase, 2);
      expect(
        first.primary.delta,
        const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only),
      );
      expect(first.delta?.label, '활성 계획과 같음');
      final second = value.cards.last;
      expect(second.stageId, 'a2');
      // 모자란 재화 하나라 크레딧(충분)으로 채운다.
      expect(second.resources.map((item) => item.resourceKey), [
        'r5',
        'credits',
      ]);
      expect(second.resources.last.shortage, 0);
      expect(second.resources.last.delta?.label, '활성보다 −400');
      expect(second.delayed.map((stage) => stage.stageId), ['h1']);
      expect(second.delta?.label, '이 시나리오에만');
    });

    test('페이즈 · 단계 행, 활성 대비 칩, KPI 4개', () {
      final value = data();
      expect(value.phaseCount, 3);
      expect(value.stageCount, 5);
      expect(value.studentCount, 4);
      expect(value.phases.first.shortageKinds, 4);
      expect(value.phases.last.shortageKinds, 0);
      final a1 = value.phases.first.stages.last;
      expect(a1.state, PlanDetailStageState.blockedHere);
      expect(a1.bottleneckNumber, 1);
      expect(a1.delta?.label, '이 시나리오에만');
      final y1 = value.phases.first.stages.first;
      expect(y1.state, PlanDetailStageState.clear);
      expect(y1.delta?.label, '활성 계획과 같음');
      // a1 · a2 · k1(이 시나리오에만) + h1(활성보다 낮은 목표) = 4.
      expect(value.differentStageCount, 4);
      expect(value.differentBottlenecks, 1);
      expect(value.activeOnlyBottlenecks, 1);
      expect(value.kpis.credits.a, 2000);
      expect(value.kpis.credits.b, 1600);
      expect(value.kpis.shortageKinds.b, 5);
      expect(value.kpis.firstBottleneck.a, 1);
      expect(value.kpis.firstBottleneck.b, 1);
      expect(value.kpis.finishing.b, (finishing: 2, total: 4));
      // 활성: 아야네 막힘, 호시노 감.
      expect(value.kpis.finishing.a, (finishing: 1, total: 2));
    });

    test('비교 없음: 칩 · a쪽 KPI 없이 문서 계산만으로', () {
      final value = data(comparison: false);
      expect(value.hasComparison, isFalse);
      expect(value.differentStageCount, isNull);
      expect(value.kpis.credits.a, isNull);
      expect(value.kpis.credits.b, 1600);
      expect(value.kpis.shortageKinds.b, 1);
      expect(value.cards.first.delta, isNull);
      expect(value.phases.first.stages.first.delta, isNull);
    });
  });

  group('Detail 위젯', () {
    Future<void> pump(
      WidgetTester tester, {
      required PlanDetailData data,
      required bool showComparison,
      int? selected,
      ValueChanged<int>? onSelect,
    }) async {
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 2560,
              height: 1208,
              child: PlanDetailWorkspace(
                keyPrefix: 'detail',
                animation: const AlwaysStoppedAnimation(1),
                data: data,
                studentName: (id) => id,
                menuBuilder: (frame) => const SizedBox.shrink(),
                showComparison: showComparison,
                selectedCard: selected,
                onSelectCard: onSelect,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    DiagonalRowMark mark(WidgetTester tester, String key) => tester
        .widget<DiagonalRow>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(DiagonalRow),
            matchRoot: true,
          ),
        )
        .mark;

    testWidgets('카드를 고르면 그 단계 행이 분홍 테두리, 단계 행을 눌러도 카드가 골라진다', (tester) async {
      final value = PlanDetailData.fromProjection(
        document: _scenario(),
        projection: _projection(),
        format: _format,
      );
      int? selected = 0;
      Future<void> rebuild() => pump(
        tester,
        data: value,
        showComparison: false,
        selected: selected,
        onSelect: (index) => selected = index,
      );
      await rebuild();
      expect(mark(tester, 'detail-card-1'), DiagonalRowMark.selected);
      expect(mark(tester, 'detail-stage-a1'), DiagonalRowMark.selected);
      expect(mark(tester, 'detail-stage-a2'), DiagonalRowMark.none);
      expect(find.text('병목 1 · 여기서 막힘'), findsOneWidget);
      expect(find.text('앞 단계 대기'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('detail-card-2')));
      expect(selected, 1);
      await rebuild();
      expect(mark(tester, 'detail-stage-a2'), DiagonalRowMark.selected);
      expect(mark(tester, 'detail-stage-a1'), DiagonalRowMark.none);

      await tester.tap(find.byKey(const ValueKey('detail-stage-a1')));
      expect(selected, 0);
      // 비교를 끄면 KPI · 활성 대비 칩이 없다(FE5-c2 활성 계획 홈).
      expect(find.byKey(const ValueKey('detail-kpis')), findsNothing);
      expect(find.byKey(const ValueKey('detail-stage-a1-delta')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('비교가 있으면 KPI 4칸과 활성 대비 칩', (tester) async {
      final value = PlanDetailData.fromProjection(
        document: _scenario(),
        projection: _projection(),
        format: _format,
        comparison: PlanDetailComparison(
          active: _active(),
          projectionA: const {'stage_results': [], 'bottlenecks': []},
          comparison: const {'credits_a': 10, 'credits_b': 5},
        ),
      );
      await pump(tester, data: value, showComparison: true, selected: 0);
      for (final key in const [
        'detail-kpi-credits',
        'detail-kpi-shortage',
        'detail-kpi-bottleneck',
        'detail-kpi-finishing',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-kpi-finishing')),
          matching: find.text('2 / 4'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('detail-stage-a1-delta')), findsOneWidget);
      expect(find.text('활성 계획과 다른 단계 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('계획 화면: 열기 · 목록으로 · 계획에 적용(이걸로 바꾸기)', (tester) async {
    final service = _CountingMockAppService();
    addTearDown(service.dispose);
    final state = await service.loadRepositoryState(_profileId);
    final created = await service.createScenario(
      profileId: _profileId,
      expectedRevision: 0,
      idempotencyKey: 'fe5c1-detail',
      name: '보기 후보',
      description: '',
      baseProfileRevision: state.revision,
      document: _scenario(),
    );
    final id = created.scenarioId;
    await tester.binding.setSurfaceSize(const Size(2560, 1392));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningPage(service: service, loadRepositoryPlan: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('plan-scenario-row-$id')));
    await tester.pumpAndSettle();
    expect(service.compareCalls, 1);

    // 열기: 같은 목록 위젯이 보기 모드가 된다. 미리보기 캐시를 쓰므로 다시 비교하지 않는다.
    await tester.tap(find.byKey(ValueKey('plan-scenario-open-$id')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan-scenario-detail-view')),
      findsOneWidget,
    );
    expect(service.compareCalls, 1);
    expect(find.text('보기 후보'), findsWidgets);
    expect(
      find.byKey(const ValueKey('plan-scenario-detail-cards-empty')),
      findsOneWidget,
    );

    // 목록으로 돌아가기.
    await tester.tap(find.byKey(const ValueKey('plan-scenario-detail-back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan-scenario-detail-view')),
      findsNothing,
    );
    expect(find.byKey(ValueKey('plan-scenario-row-$id')), findsOneWidget);
    expect(service.compareCalls, 1);

    // 다시 열고 계획에 적용 → 이걸로 바꾸기: 계획 만들기 4단계가 그 위치로 열린다.
    await tester.tap(find.byKey(const ValueKey('plan-scenario-preview-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-scenario-detail-apply')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan-scenario-apply-modal')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('plan-scenario-apply-replace')));
    await tester.pumpAndSettle();
    expect(find.byType(PlanScenarioListSection), findsNothing);
    expect(
      find.byKey(const ValueKey('plan-flow-workspace-view')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plan-flow-save-body')), findsOneWidget);
    expect(
      tester
          .widget<DiagonalRow>(
            find.byKey(const ValueKey('plan-flow-save-target-replace')),
          )
          .mark,
      DiagonalRowMark.selected,
    );
    expect(tester.takeException(), isNull);
  });
}

/// compare 호출 수를 센다.
class _CountingMockAppService extends MockAppService {
  int compareCalls = 0;

  @override
  Future<PlanningScenarioComparisonResult> compareScenarios({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required PlanningDocument documentA,
    required PlanningDocument documentB,
  }) {
    compareCalls += 1;
    return super.compareScenarios(
      currentStudents: currentStudents,
      inventory: inventory,
      documentA: documentA,
      documentB: documentB,
    );
  }
}
