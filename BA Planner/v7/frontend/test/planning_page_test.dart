import 'dart:math' as math;

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/diagonal_row.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/models/repository_plan_snapshot.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_student_step.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_detail.dart'
    show PlanDetailWorkspace;
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanElementPreset _planningTestPreset() => PlanElementPreset(
  id: 'balanced-growth',
  name: '테스트 프리셋',
  isDefault: false,
  stages: const [
    {'level': 30},
  ],
);

PlanningDocument _comparisonTestDocument(
  String id,
  PlanningDocumentKind kind, {
  int level = 1,
}) {
  final targets = {
    for (final entry in planningDocumentTargetMaximums.entries)
      entry.key: entry.key == 'bond_rank' ? 1 : 0,
    'level': level,
    'student_star': 1,
    'ex_skill': 1,
    'skill1': 1,
  };
  return PlanningDocument(
    id: id,
    name: id,
    kind: kind,
    phases: [
      PlanningDocumentPhase(
        id: '$id-phase',
        name: '페이즈 1',
        stages: [
          PlanningDocumentStage(
            id: '$id-stage',
            studentId: 'ayane',
            name: '목표',
            targets: targets,
          ),
        ],
      ),
    ],
  );
}

/// FE4-h 저장 문서 읽기 테스트의 레거시 계정. 활성 문서 없이 goals v1만 있어 첫 `plan.get`이 문서로 옮기며
/// revision을 4 → 5로 올린다(FB-1b mock).
const _legacyPlanProfileId = 'cccccccccccccccccccccccc';

Map<String, dynamic> _legacyPlanState() => {
  'profile_id': _legacyPlanProfileId,
  'revision': 4,
  'students': <dynamic>[],
  'inventory': {'version': 1, 'entries': <dynamic>[]},
  'goals': {
    'version': 1,
    'goals': [
      {'student_id': 'ayane', 'target_level': 10},
    ],
  },
};

/// 첫 `plan.get`이 돌려줄 낡은 문서(revision이 state보다 하나 작다).
PlanningDocument _stalePlanDocument() => PlanningDocument(
  id: 'active-plan',
  name: '활성 계획',
  kind: PlanningDocumentKind.plan,
  version: 2,
  goalMetadata: const {
    'hina': PlanningGoalMetadata(favorite: true, notes: ''),
  },
  phases: [
    PlanningDocumentPhase(
      id: 'stale-phase',
      name: '낡은 페이즈',
      stages: [
        PlanningDocumentStage(
          id: 'stale-hina-1',
          studentId: 'hina',
          name: '낡은 목표',
          targets: {for (final key in planningDocumentTargetKeys) key: null},
        ),
      ],
    ),
  ],
);

/// `plan.get`·`state.get`이 돌려준 revision을 기록하는 mock(FE4-h).
class _RepositoryPlanLoadService extends MockAppService {
  _RepositoryPlanLoadService({
    this.stalePlanLoads = 0,
    this.emptyDocument = false,
    this.unavailableCalculation = false,
  }) : super(
         profiles: const [
           RepositoryProfile(
             id: _legacyPlanProfileId,
             displayName: 'Legacy',
             revision: 4,
             selected: true,
           ),
         ],
         repositoryStates: {_legacyPlanProfileId: _legacyPlanState()},
       );

  /// 처음 몇 번의 `plan.get`이 낡은 revision·문서를 돌려준다.
  final int stalePlanLoads;

  /// `plan.get`이 빈 문서를 돌려준다(goals 호환 보기에는 학생이 남아 있다).
  final bool emptyDocument;

  /// 문서 계산이 실패한다. `plan.get`의 `calculation`이 null이 된다.
  final bool unavailableCalculation;

  final planRevisions = <int>[];
  final stateRevisions = <int>[];

  @override
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId) async {
    final real = await super.loadRepositoryPlan(profileId);
    final stale = planRevisions.length < stalePlanLoads;
    final result = stale || emptyDocument
        ? RepositoryPlanState.fromWire({
            'profile_id': profileId,
            'revision': stale ? real.revision - 1 : real.revision,
            'document': stale
                ? _stalePlanDocument().toWire()
                : PlanningDocument(
                    id: 'active-plan',
                    name: '활성 계획',
                    kind: PlanningDocumentKind.plan,
                    version: 2,
                    phases: const [],
                  ).toWire(),
            // 낡은 응답은 버려지므로 계산 요약이 없다. 빈 문서는 계산할 수 있다(빈 요약).
            'calculation': stale
                ? null
                : {
                    'credits': 0,
                    'required_resource_type_count': 0,
                    'known_shortage_type_count': 0,
                    'inventory_complete': true,
                    'first_bottleneck_phase_number': null,
                    'representative_shortage': null,
                  },
          })
        : real;
    planRevisions.add(result.revision);
    return result;
  }

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async {
    final state = await super.loadRepositoryState(profileId);
    stateRevisions.add(state.revision);
    return state;
  }

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) {
    if (unavailableCalculation) {
      return Future.error(StateError('calculation unavailable'));
    }
    return super.calculatePlanningDocument(
      currentStudents: currentStudents,
      inventory: inventory,
      document: document,
    );
  }
}

/// FE5-c2 Detail 홈 S2의 단계 행(`plan-home-stage-<stage id>`, 상태 · 칩 하위 키 제외).
Finder _homeStageRows() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('plan-home-stage-') &&
      !key.value.endsWith('-state') &&
      !key.value.endsWith('-delta');
});

void main() {
  test(
    'scenario rows use the standard height-derived 80 degree silhouette',
    () {
      const size = Size(900, 142);
      final depth = planScenarioParallelogramDepth(size.height);
      final expected = size.height / math.tan(80 * math.pi / 180);
      final path = planScenarioParallelogramPath(size);

      expect(depth, closeTo(expected, 0.001));
      expect(depth, greaterThan(14));
      expect(path.contains(const Offset(1, 71)), isFalse);
      expect(path.contains(Offset(depth / 2 + 4, 71)), isTrue);
      expect(path.contains(const Offset(899, 71)), isFalse);
      expect(path.contains(Offset(900 - depth / 2 - 4, 71)), isTrue);
    },
  );

  testWidgets('scenario viewport fog is clipped to the same parallelogram', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 220,
            child: PlanDiagonalScrollbar(
              keyPrefix: 'scenario-fog-test',
              controller: controller,
              contentExtent: 600,
              fogClipper: const PlanScenarioParallelogramClipper(),
              child: SingleChildScrollView(
                controller: controller,
                child: const SizedBox(height: 600),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final clip = tester.widget<ClipPath>(
      find.byKey(const ValueKey('scenario-fog-test-fog-clip')),
    );
    expect(clip.clipper, isA<PlanScenarioParallelogramClipper>());
    expect(
      find.byKey(const ValueKey('scenario-fog-test-viewport-fog-bottom')),
      findsOneWidget,
    );
    final path = clip.clipper!.getClip(const Size(500, 220));
    final depth = planScenarioParallelogramDepth(220);
    expect(path.contains(const Offset(1, 110)), isFalse);
    expect(path.contains(Offset(depth / 2 + 4, 110)), isTrue);
    expect(path.contains(const Offset(499, 110)), isFalse);
  });

  testWidgets('scenario list row exposes identity calculation and portraits', (
    tester,
  ) async {
    // FE5-a: 시나리오 행은 시안 Scenario-List `srow`(100px, 고른 행 146px + 행 액션)다.
    PlanningScenarioSummary summary({required String id, required int base}) =>
        PlanningScenarioSummary(
          id: id,
          revision: 1,
          name: id == 'current' ? '빠른 성장 후보' : '총력전 대비',
          description: id == 'current' ? '딜러를 먼저 육성' : '다음 시즌 후보',
          baseProfileRevision: base,
          phaseCount: 2,
          stageCount: 7,
          studentCount: 5,
          studentIds: const ['ayane', 'hasumi', 'aru', 'shiroko', 'hoshino'],
          calculation: const PlanningScenarioCalculationSummary(
            credits: 18200000,
            requiredResourceTypeCount: 6,
            knownShortageTypeCount: 4,
            inventoryComplete: true,
            firstBottleneckPhaseNumber: 2,
            representativeShortage: PlanningScenarioRepresentativeShortage(
              resourceKey: 'Item_Icon_ExpReport_4',
              itemId: 'Item_Icon_ExpReport_4',
              displayName: '최상급 활동 보고서',
              category: 'report',
              shortage: 84,
            ),
          ),
          createdAt: '2026-08-12T10:00:00',
          updatedAt: '2026-08-13T14:32:00',
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1250,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 100,
                    child: PlanScenarioListRow(
                      scenario: summary(id: 'current', base: 3),
                      stale: false,
                      expanded: false,
                      compared: false,
                      onTap: () {},
                    ),
                  ),
                  SizedBox(
                    height: 146,
                    child: PlanScenarioListRow(
                      scenario: summary(id: 'stale', base: 2),
                      stale: true,
                      expanded: true,
                      compared: true,
                      onTap: () {},
                      onToggleCompare: () {},
                      onDuplicate: () {},
                      onRename: () {},
                      onDelete: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('빠른 성장 후보'), findsOneWidget);
    expect(find.text('딜러를 먼저 육성'), findsOneWidget);
    String metrics(String id) => tester
        .widget<Text>(find.byKey(ValueKey('plan-scenario-calculation-$id')))
        .textSpan!
        .toPlainText();
    for (final id in const ['current', 'stale']) {
      expect(metrics(id), contains('크레딧 18.2M'));
      expect(metrics(id), contains('부족 4종'));
      expect(metrics(id), contains('첫 병목 P2'));
      expect(metrics(id), contains('학생 5 · 페이즈 2 · 단계 7'));
    }
    expect(find.text('최상급 활동 보고서'), findsNWidgets(2));
    expect(find.text('−84'), findsNWidgets(2));
    // 초상 3명 + "…+2" 칩.
    expect(find.text('…+2'), findsNWidgets(2));
    expect(find.text('현재 데이터 기준'), findsOneWidget);
    expect(find.text('저장 시점과 다름'), findsOneWidget);
    expect(find.text('수정 8.13 14:32'), findsNWidgets(2));
    // 고른 행만 행 액션이 보인다. 열기(시나리오 보기, FE5-c)는 아직 비활성이다.
    expect(find.byKey(const ValueKey('plan-scenario-open-current')), findsNothing);
    expect(find.byKey(const ValueKey('plan-scenario-open-stale')), findsOneWidget);
    expect(find.text('비교에서 빼기'), findsOneWidget);
    expect(find.text('복제'), findsOneWidget);
    expect(find.text('이름 · 설명'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // FE5-f1: 옛 섹션 3 필터(`filterPlanConsumptionGroups`)는 지웠다. 분류 함수는 Detail 홈 · 시나리오 보기 칩이 쓴다.
  test('resource categories classify the Detail filter chip data', () {
    expect(PlanResourceCategory.values, hasLength(10));
    expect(
      PlanResourceCategory.values.map((category) => category.label).toSet(),
      hasLength(10),
    );
    expect(
      planResourceCategory(
        id: 'phase-1-basic-bd',
        iconAsset: planBasicTacticalBdIconAsset,
      ),
      PlanResourceCategory.tacticalBd,
    );
    expect(
      planResourceCategory(
        id: 'phase-2-nebra-t3',
        iconAsset: planPrimaryBottleneckIconAsset,
      ),
      PlanResourceCategory.ooparts,
    );
    expect(
      planResourceCategory(
        id: 'phase-2-hairpin-t10',
        iconAsset: 'assets/equipment_icons/hairpin_t10.png',
        equipmentTier: 10,
      ),
      PlanResourceCategory.equipment,
    );
    expect(
      planResourceCategory(
        id: 'phase-1-credits',
        iconAsset: planCreditIconAsset,
      ),
      PlanResourceCategory.credits,
    );
  });

  Future<void> pumpPage(
    WidgetTester tester,
    AppService service, {
    Size size = const Size(900, 900),
    List<PlanElementPreset> presets = const [],
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningPage(service: service, initialPresets: presets),
        ),
      ),
    );
  }

  testWidgets(
    // FE5-e(FD-085): 비교 화면의 후보 목록을 없앴다. 두 대상은 시나리오 목록 비교 슬롯에서 담아 넘긴다(initialSelectedIds).
    'scenario comparison opens the two given plans and exposes side-by-side actions',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final profile = (await service.listProfiles()).firstWhere(
        (profile) => profile.selected,
      );
      final state = await service.loadRepositoryState(profile.id);
      final created = await service.createScenario(
        profileId: profile.id,
        expectedRevision: 0,
        idempotencyKey: 'comparison-create',
        name: '비교 후보',
        description: '',
        baseProfileRevision: state.revision,
        document: _comparisonTestDocument(
          'scenario-compare',
          PlanningDocumentKind.scenario,
          level: 2,
        ),
      );
      var incorporated = false;
      var edited = false;
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanScenarioComparisonSection(
              service: service,
              repositoryState: state,
              activePlan: _comparisonTestDocument(
                'active-plan',
                PlanningDocumentKind.plan,
              ),
              section1Bounds: const Rect.fromLTWH(16, 20, 360, 940),
              active: true,
              initialSelectedIds: ['active-plan', created.scenarioId],
              onEdit: (_, _) async => edited = true,
              onIncorporate: (_) async => incorporated = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('plan-scenario-compare-candidates')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('plan-scenario-compare-confirm')),
        findsNothing,
      );
      expect(find.text('활성 계획  ↔  비교 후보'), findsOneWidget);
      expect(find.text('전체 결과'), findsOneWidget);
      final firstSummaryRow = tester.getRect(
        find.byKey(const ValueKey('plan-comparison-a-summary-row-0')),
      );
      final secondSummaryRow = tester.getRect(
        find.byKey(const ValueKey('plan-comparison-a-summary-row-1')),
      );
      expect(secondSummaryRow.left, lessThan(firstSummaryRow.left));
      expect(secondSummaryRow.right, lessThan(firstSummaryRow.right));
      final comparisonPath = planScenarioListSectionPath(
        const Size(1600, 1000),
        const Rect.fromLTWH(16, 20, 360, 940),
      );
      for (final key in const [
        'plan-scenario-comparison-back',
        'plan-scenario-a-move',
        'plan-scenario-b-move',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key))).deflate(1);
        expect(
          [
            rect.topLeft,
            rect.topRight,
            rect.bottomRight,
            rect.bottomLeft,
          ].every(comparisonPath.contains),
          isTrue,
          reason: '$key must remain inside the 80-degree result section',
        );
      }
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('plan-scenario-a-edit')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-b-incorporate')),
      );
      await tester.pump();
      expect(incorporated, isTrue);
      await tester.tap(find.byKey(const ValueKey('plan-scenario-b-edit')));
      await tester.pump();
      expect(edited, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'comparison workspace incorporates a scenario after the active plan',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final profile = (await service.listProfiles()).firstWhere(
        (profile) => profile.selected,
      );
      final state = await service.loadRepositoryState(profile.id);
      final created = await service.createScenario(
        profileId: profile.id,
        expectedRevision: 0,
        idempotencyKey: 'incorporate-create',
        name: '편입 후보',
        description: '',
        baseProfileRevision: state.revision,
        document: _comparisonTestDocument(
          'scenario-incorporate',
          PlanningDocumentKind.scenario,
          level: 2,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanningPage(service: service, loadRepositoryPlan: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // FE5-f1: Detail 홈 S1 "시나리오 목록" → 비교 슬롯에 담기 → "나란히 비교"(FE5-e, FD-085) → 편입.
      expect(
        tester
            .widget<RailButton>(
              find.byKey(const ValueKey('plan-scenario-list-launch')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioListSection), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('plan-scenario-compare-${created.scenarioId}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-compare-run')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioComparisonSection), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-b-incorporate')),
      );
      await tester.pumpAndSettle();

      expect(find.text('편입 후보 · 페이즈 1'), findsOneWidget);
      expect(find.byType(PlanScenarioComparisonSection), findsNothing);
      expect(find.text('"편입 후보" 시나리오를 현재 계획에 편입했습니다.'), findsOneWidget);
      // FE4-f2: 편입은 활성 계획 문서(v2) + authoring 전체로 plan.save한다.
      final saved = await service.loadRepositoryPlan(profile.id);
      expect(saved.hasAuthoring, isTrue);
      expect(saved.document.version, 2);
      expect(
        saved.document.phases.map((phase) => phase.name),
        contains('편입 후보 · 페이즈 1'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    // FE5-c2: Detail 홈 S1 "페이즈 편집"(FD-070)이 FE4-f2 아이콘 버튼과 같은 동작이라 하나로 합쳤다(같은 키).
    'plan home "phase edit" opens the saved active plan in flow step 3 (FE4-f2 · FE5-c2)',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final profile = (await service.listProfiles()).firstWhere(
        (profile) => profile.selected,
      );
      final initial = await service.loadRepositoryPlan(profile.id);
      Map<String, int?> level(int value) => {
        for (final key in planningDocumentTargetKeys)
          key: key == 'level' ? value : null,
      };
      final document = PlanningDocument(
        id: initial.document.id,
        name: initial.document.name,
        kind: PlanningDocumentKind.plan,
        version: 2,
        phases: [
          PlanningDocumentPhase(
            id: 'p1',
            name: '먼저',
            stages: [
              PlanningDocumentStage(
                id: 'ayane-stage-1',
                studentId: 'ayane',
                name: '1단계',
                targets: level(50),
              ),
            ],
          ),
        ],
        goalMetadata: const {
          'ayane': PlanningGoalMetadata(favorite: false, notes: ''),
        },
      );
      await service.saveRepositoryPlan(
        profileId: profile.id,
        document: document,
        authoring: PlanningAuthoring.fromWire({
          'version': 1,
          'prerequisites': const <Object>[],
          'deferred_stages': [
            PlanningDocumentStage(
              id: 'ayane-stage-2',
              studentId: 'ayane',
              name: '2단계',
              targets: level(60),
            ).toWire(),
          ],
          'student_order': const ['ayane'],
          'stage_order_by_student': const {
            'ayane': ['ayane-stage-1', 'ayane-stage-2'],
          },
          'goal_metadata': const <String, Object>{},
        }, document),
        expectedRevision: initial.revision,
        idempotencyKey: 'seed-edit-active-flow',
      );
      final saved = await service.loadRepositoryPlan(profile.id);
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanningPage(service: service, loadRepositoryPlan: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('plan-flow-edit-active-launch')),
      );
      await tester.pumpAndSettle();
      final flow = tester
          .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
          .flow;
      expect(flow.purpose, PlanFlowPurpose.editActivePlan);
      expect(flow.step, PlanFlowStep.order);
      expect(flow.activePlanRevision, saved.revision);
      expect(flow.draft.phases.single.name, '먼저');
      expect(flow.draft.phases.single.stageIds, ['ayane-stage-1']);
      expect(flow.draft.deferredStageIds, ['ayane-stage-2']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scenario list replaces the plan home with its three sections and returns to the active plan',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(tester, service, size: const Size(2560, 1392));
      await tester.pumpAndSettle();

      Animation<double> homeAnimation() => tester
          .widget<PlanDetailWorkspace>(
            find.byKey(const ValueKey('plan-home-view')),
          )
          .animation;
      expect(homeAnimation().value, 1);
      await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
      await tester.pumpAndSettle();

      // FE5-a: 목록은 S1 메뉴 · S2 목록 · S3 미리보기로 Detail 홈(S1 포함)을 대신한다(FE5-f1: 옛 홈 → Detail 홈).
      expect(find.byType(PlanScenarioListSection), findsOneWidget);
      expect(homeAnimation().value, 0);
      expect(
        find.text('저장된 시나리오가 없습니다.\n왼쪽 "새 시나리오"로 시작할 수 있습니다.'),
        findsOneWidget,
      );
      for (final (key, intro, outro) in const [
        ('plan-scenario-menu-motion', 0.0, 180.0),
        ('plan-scenario-list-motion', 80.0, 260.0),
        ('plan-scenario-preview-motion', 180.0, 0.0),
      ]) {
        final motion = tester.widget<PlanSectionMotion>(find.byKey(ValueKey(key)));
        expect(motion.introDegrees, intro, reason: key);
        expect(motion.outroDegrees, outro, reason: key);
      }
      expect(
        find.byKey(const ValueKey('plan-scenario-list-foundation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-scenario-active-row')),
        findsOneWidget,
      );
      expect(find.text('1 / 4'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('plan-scenario-menu-back')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioListSection), findsNothing);
      expect(homeAnimation().value, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scenario creation opens the plan flow step 1 and quitting plays the flow outro',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(tester, service, size: const Size(2560, 1392));
      await tester.pumpAndSettle();

      Offset motionOffset(String key) {
        final transform = tester.widget<Transform>(
          find
              .descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Transform),
              )
              .first,
        );
        final translation = transform.transform.getTranslation();
        return Offset(translation.x, translation.y);
      }

      // FE4-a: S1 "계획 만들기"는 계획 만들기 1단계를 연다. FE4-b1부터 1단계는 B 본문·C 보조의 새 학생 고르기다.
      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-create-launch')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-flow-rail')), findsOneWidget);
      expect(find.byType(PlanFlowStudentBody), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-scenario-create-launch')),
        findsNothing,
      );
      // 학생 그리드는 레일 오른쪽(B 본문 안)에서 시작한다.
      final railRight = tester
          .getRect(find.byKey(const ValueKey('plan-flow-step-1')))
          .right;
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey('plan-flow-student-grid-container')),
            )
            .left,
        greaterThan(railRight - 220),
      );

      // 1단계의 "그만두기"는 섹션을 부착면 쪽으로 내보낸 뒤 흐름을 닫는다(FD-078: B 260°, 레일 180°, C 0°).
      await tester.tap(find.byKey(const ValueKey('plan-flow-previous')));
      await tester.pump();
      await tester.pump(
        Duration(milliseconds: AppMotion.section.inMilliseconds ~/ 2),
      );
      expect(find.byType(PlanFlowStudentBody), findsOneWidget);
      final body = motionOffset('plan-flow-body-motion');
      expect(body.dx, lessThan(0));
      expect(body.dy, greaterThan(0));
      expect(motionOffset('plan-flow-rail-motion').dx, lessThan(0));
      expect(motionOffset('plan-flow-aside-motion').dx, greaterThan(0));
      await tester.pumpAndSettle();

      expect(find.byType(PlanFlowStudentBody), findsNothing);
      expect(find.byKey(const ValueKey('plan-flow-rail')), findsNothing);
      expect(
        tester
            .widget<RailButton>(
              find.byKey(const ValueKey('plan-scenario-create-launch')),
            )
            .onPressed,
        isNotNull,
      );

      // 흐름을 닫은 뒤에는 시나리오 목록이 그대로 열린다.
      await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioListSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scenario creation builds goals and orders stages in the plan flow',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(
        tester,
        service,
        size: const Size(2560, 1392),
        presets: [_planningTestPreset()],
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-create-launch')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlanFlowStudentBody), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-scenario-bulk-apply')),
        findsNothing,
      );

      // 1단계(FE4-b1): 그리드에서 고르고 레일 "다음"으로 2단계를 연다.
      final gridFinder = find.byKey(const ValueKey('plan-flow-student-grid'));
      final grid = tester.widget<StudentDiagonalGrid>(gridFinder);
      await tester.tap(
        find.descendant(
          of: gridFinder,
          matching: find.byKey(
            ValueKey('student-${grid.students.first.studentId}'),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
      await tester.pumpAndSettle();
      // 2단계(FE4-c): 새 목표 정하기를 레일 옆 B·C에 그린다(기존 요소 편집기 아님).
      expect(find.byType(PlanElementBuilder), findsNothing);
      expect(find.byKey(const ValueKey('plan-flow-goal-body')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-flow-rail')), findsOneWidget);

      // 한 번에 MAX가 고른 학생의 1단계를 만들고(바로 초안에 들어간다) 레일 "다음"으로 3단계를 연다.
      await tester.tap(find.byKey(const ValueKey('plan-flow-goal-mode-max')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
      await tester.pumpAndSettle();
      // 3단계(FE4-d1): 새 칸 보드가 단계를 "1순위" 칸에 넣고, 레일 "다음"으로 4단계를 연다.
      expect(find.byKey(const ValueKey('plan-flow-order-body')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-phase-editor')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
      await tester.pumpAndSettle();

      // 4단계(FE4-e): 저장 위치·이름은 C 패널 안에서 정한다(다이얼로그 없음). 레일 primary는 C에서 고른 위치
      // ("시나리오로 저장")와 같은 동작·같은 글자다(FD-079). "저장한 뒤 · 시나리오 보기로 이동"이 켜져 있으면
      // 저장한 뒤 시나리오 목록이 열린다.
      expect(
        find.byKey(const ValueKey('plan-flow-save-counts')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-scenario-save-dialog')),
        findsNothing,
      );
      final saveButton = tester.widget<RailButton>(
        find.byKey(const ValueKey('plan-flow-save-confirm')),
      );
      expect(saveButton.semanticLabel, '시나리오로 저장');
      expect(
        tester
            .widget<RailButton>(find.byKey(const ValueKey('plan-flow-next')))
            .semanticLabel,
        '시나리오로 저장',
      );
      await tester.enterText(
        find.byKey(const ValueKey('plan-flow-save-name-field')),
        '빠른 성장 후보',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-flow-next')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plan-scenario-save-dialog')),
        findsNothing,
      );

      final list = await service.listScenarios('000000000000000000000001');
      expect(list.scenarios, hasLength(1));
      expect(list.scenarios.single.name, '빠른 성장 후보');
      expect(list.scenarios.single.description, '');
      expect(list.scenarios.single.phaseCount, 1);
      expect(find.byKey(const ValueKey('plan-flow-rail')), findsNothing);
      expect(find.text('빠른 성장 후보'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-scenario-diagonal-scroll')),
        findsOneWidget,
      );
      // FE5-a: 행은 공용 사선 행(`srow`), 목록은 공용 사선 스크롤 뷰포트 + 포그(FD-087)다.
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey('plan-scenario-row-${list.scenarios.single.id}'),
          ),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ClipPath && widget.clipper is DiagonalRowClipper,
          ),
        ),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('plan-scenario-diagonal-fog')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scenario selector accepts the upper-right of fourth-column portraits in rows 1-4',
    (tester) async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(
        tester,
        service,
        size: const Size(2560, 1392),
        presets: [_planningTestPreset()],
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-create-launch')),
      );
      await tester.pumpAndSettle();

      // FE4-b1: 계획 만들기 1단계 그리드(8열)로 옮겼다. 4번째 열 카드 오른쪽 위를 1~4행에서 누른다.
      final gridFinder = find.byKey(const ValueKey('plan-flow-student-grid'));
      final grid = tester.widget<StudentDiagonalGrid>(gridFinder);
      final students = grid.students;
      expect(students.length, greaterThanOrEqualTo(grid.columns * 4));

      for (var row = 0; row < 4; row++) {
        final student = students[row * grid.columns + 3];
        final target = find.descendant(
          of: gridFinder,
          matching: find.byKey(ValueKey('student-${student.studentId}')),
        );
        final bounds = tester.getRect(target);
        final fitted = studentGridCardFittedRect(Offset.zero & bounds.size);
        final tapPoint = bounds.topLeft + fitted.topRight + const Offset(-2, 2);
        await tester.tapAt(tapPoint);
        await tester.pump();
        expect(
          tester.widget<StudentDiagonalGrid>(gridFinder).selectedIds,
          contains(student.studentId),
          reason: 'row ${row + 1}, column 4 upper-right must be tappable',
        );
      }

      expect(tester.takeException(), isNull);
    },
  );

  group('FE4-h 저장 문서 읽기', () {
    Future<void> pumpRepositoryPlan(
      WidgetTester tester,
      MockAppService service,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanningPage(service: service, loadRepositoryPlan: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('레거시 프로필 첫 로드는 이관된 문서를 이관 revision으로 읽는다', (tester) async {
      final service = _RepositoryPlanLoadService();
      addTearDown(service.dispose);
      await pumpRepositoryPlan(tester, service);

      // plan.get이 먼저 goals를 문서로 옮기며 revision 4 → 5. state.get도 같은 5다(한 snapshot).
      expect(service.planRevisions, [5]);
      expect(service.stateRevisions, [5]);
      expect(
        find.byKey(const ValueKey('plan-home-stage-v6-ayane-1')),
        findsOneWidget,
      );
      expect(_homeStageRows(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-calculation-unavailable')),
        findsNothing,
      );
      expect(find.textContaining('계산 오류'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('빈 저장 문서는 goals가 있어도 빈 계획이다', (tester) async {
      final service = _RepositoryPlanLoadService(emptyDocument: true);
      addTearDown(service.dispose);
      await pumpRepositoryPlan(tester, service);

      // goals 호환 보기에는 아야네가 있지만 문서가 비었으므로 되살리지 않는다(더미 계획도 그리지 않는다).
      final state = await service.loadRepositoryState(_legacyPlanProfileId);
      expect(state.goals.map((goal) => goal.studentId), ['ayane']);
      expect(_homeStageRows(), findsNothing);
      expect(find.byKey(const ValueKey('plan-home-empty')), findsWidgets);
      expect(
        find.byKey(const ValueKey('plan-calculation-unavailable')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('calculation이 null이면 계산할 수 없음을 보이고 문서는 그대로 보인다', (tester) async {
      final service = _RepositoryPlanLoadService(unavailableCalculation: true);
      addTearDown(service.dispose);
      await pumpRepositoryPlan(tester, service);

      expect(
        find.byKey(const ValueKey('plan-calculation-unavailable')),
        findsOneWidget,
      );
      expect(find.text(planCalculationUnavailableMessage), findsOneWidget);
      // 자세한 계산을 다시 부르지 않는다(불렀다면 계산 오류가 보인다).
      expect(find.textContaining('계산 오류'), findsNothing);
      expect(
        find.byKey(const ValueKey('plan-home-stage-v6-ayane-1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('plan.get과 state.get의 revision이 다르면 다시 읽어 맞춘다', (tester) async {
      final service = _RepositoryPlanLoadService(stalePlanLoads: 1);
      addTearDown(service.dispose);
      await pumpRepositoryPlan(tester, service);

      expect(service.planRevisions, [4, 5]);
      expect(service.stateRevisions, [5, 5]);
      // 낡은 문서는 버리고 같은 revision의 문서를 보인다.
      expect(
        find.byKey(const ValueKey('plan-home-stage-stale-hina-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('plan-home-stage-v6-ayane-1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('revision이 끝내 맞지 않으면 문서를 쓰지 않고 오류를 보인다', (tester) async {
      final service = _RepositoryPlanLoadService(
        stalePlanLoads: repositoryPlanSnapshotAttempts,
      );
      addTearDown(service.dispose);
      await pumpRepositoryPlan(tester, service);

      expect(service.planRevisions, hasLength(repositoryPlanSnapshotAttempts));
      expect(find.textContaining('revision이 맞지 않습니다'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-home-stage-stale-hina-1')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('시나리오 만들기 1단계의 계획 학생은 저장 문서와 같다', (tester) async {
      final service = _RepositoryPlanLoadService();
      addTearDown(service.dispose);
      await pumpRepositoryPlan(tester, service);
      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-create-launch')),
      );
      await tester.pumpAndSettle();

      // 흐름은 계획 화면이 읽은 snapshot을 그대로 쓴다(다시 읽지 않는다).
      expect(service.planRevisions, [5]);
      final body = tester.widget<PlanFlowStudentBody>(
        find.byType(PlanFlowStudentBody),
      );
      expect(body.picker.plannedIds, {'ayane'});
      expect(body.picker.context.activePlan?.stages.single.studentId, 'ayane');
      expect(tester.takeException(), isNull);
    });
  });
}
