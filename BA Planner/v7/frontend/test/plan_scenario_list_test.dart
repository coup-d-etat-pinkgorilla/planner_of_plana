// 시나리오 목록 v2 테스트(FE5-a, 시안 Scenario-List, FD-083·FD-084·FD-087).
//
// - 상태 모델: 정렬 4종 · 현재 데이터 기준만 · 학생 · 검색 · 오래된 개수 · 비교 담기(슬롯 A 고정, 최대 4) · 다시 읽은 뒤 정리.
// - Studio 3섹션: S1은 시안과 같고, S2·S3는 96 grid 정수 칸 근사(차이는 문서에 적은 범위 안).
// - 화면: 계획 화면에서 목록을 열어 고정 행 · 정렬 · 검색 · 펼침 행 액션(복제 · 이름·설명 · 삭제) · 비교 담기 → A↔B 비교 ·
//   새 시나리오 · 활성 계획으로 돌아가기.
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_list_state.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/studio/plan_scenario_list_studio_layout.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_list.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart'
    show PlanScenarioComparisonSection, PlanSectionMotion;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

PlanningScenarioSummary _summary(
  String id, {
  String? name,
  String description = '',
  int base = 3,
  List<String> students = const ['aru'],
  PlanningScenarioCalculationSummary? calculation,
  String updatedAt = '2026-09-20T12:00:00',
}) => PlanningScenarioSummary(
  id: id,
  revision: 1,
  name: name ?? id,
  description: description,
  baseProfileRevision: base,
  phaseCount: 1,
  stageCount: students.length,
  studentCount: students.length,
  studentIds: students,
  calculation: calculation,
  createdAt: '2026-09-01T00:00:00',
  updatedAt: updatedAt,
);

PlanningScenarioCalculationSummary _calculation({
  required int credits,
  required int shortage,
  int? bottleneck,
}) => PlanningScenarioCalculationSummary(
  credits: credits,
  requiredResourceTypeCount: shortage + 2,
  knownShortageTypeCount: shortage,
  inventoryComplete: true,
  firstBottleneckPhaseNumber: bottleneck,
  representativeShortage: null,
);

/// 시나리오 문서(v1, [students] 한 페이즈, 레벨 [level]).
PlanningDocument _document(String id, List<String> students, {int level = 2}) {
  final targets = {
    for (final key in planningDocumentTargetKeys)
      key: key == 'bond_rank' ? 1 : 0,
    'level': level,
    'student_star': 1,
    'ex_skill': 1,
    'skill1': 1,
  };
  return PlanningDocument(
    id: id,
    name: id,
    kind: PlanningDocumentKind.scenario,
    phases: [
      PlanningDocumentPhase(
        id: '$id-phase',
        name: '페이즈 1',
        stages: [
          for (final student in students)
            PlanningDocumentStage(
              id: '$id-$student',
              studentId: student,
              name: '목표',
              targets: targets,
            ),
        ],
      ),
    ],
  );
}

/// 선택 계정에 시나리오를 만든다. 이름 → id.
Future<Map<String, String>> _seed(
  MockAppService service,
  List<(String, String, List<String>)> scenarios,
) async {
  final state = await service.loadRepositoryState(_profileId);
  final ids = <String, String>{};
  for (final (index, (name, description, students)) in scenarios.indexed) {
    final list = await service.listScenarios(_profileId);
    final created = await service.createScenario(
      profileId: _profileId,
      expectedRevision: list.revision,
      idempotencyKey: 'fe5a-test-$index',
      name: name,
      description: description,
      baseProfileRevision: state.revision,
      document: _document('fe5a-$index', students),
    );
    ids[name] = created.scenarioId;
  }
  return ids;
}

Future<void> _pumpPlanning(
  WidgetTester tester,
  MockAppService service, {
  bool loadRepositoryPlan = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlanningPage(
          service: service,
          loadRepositoryPlan: loadRepositoryPlan,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
  await tester.pumpAndSettle();
  expect(find.byType(PlanScenarioListSection), findsOneWidget);
}

double _rowTop(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(ValueKey('plan-scenario-row-$id'))).dy;

/// 계획 홈 섹션 모션 값(1 = 들어옴, 0 = 내려감).
double _homeSectionValue(WidgetTester tester, String id) => tester
    .widget<PlanSectionMotion>(find.byKey(ValueKey('plan-$id-motion')))
    .animation
    .value;

/// 스낵바 타이머를 흘려보낸다.
Future<void> _drainSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  group('상태 모델', () {
    final a = _summary(
      'a',
      name: '나 계획',
      calculation: _calculation(credits: 300, shortage: 2),
      updatedAt: '2026-09-21T10:00:00',
    );
    final b = _summary(
      'b',
      name: '가 계획',
      description: '총력전 대비',
      base: 2,
      students: const ['ayane', 'aru'],
      calculation: _calculation(credits: 100, shortage: 5, bottleneck: 1),
      updatedAt: '2026-09-22T10:00:00',
    );
    final c = _summary(
      'c',
      name: '다 계획',
      students: const ['hoshino'],
      updatedAt: '2026-09-20T10:00:00',
    );
    final all = [a, b, c];

    List<String> ids(List<PlanningScenarioSummary> items) => [
      for (final item in items) item.id,
    ];

    test('정렬 4종: 최근 수정 · 부족 적은 순 · 크레딧 적은 순 · 이름(요약 없으면 맨 뒤)', () {
      List<String> sorted(PlanScenarioSort sort) => ids(
        planScenarioVisible(all, currentProfileRevision: 3, sort: sort),
      );
      expect(sorted(PlanScenarioSort.recent), ['b', 'a', 'c']);
      expect(sorted(PlanScenarioSort.shortage), ['a', 'b', 'c']);
      expect(sorted(PlanScenarioSort.credits), ['b', 'a', 'c']);
      expect(sorted(PlanScenarioSort.name), ['b', 'a', 'c']);
      expect(PlanScenarioSort.values.map((sort) => sort.label), [
        '최근 수정',
        '부족 적은 순',
        '크레딧 적은 순',
        '이름',
      ]);
    });

    test('필터: 현재 데이터 기준만 · 학생 · 이름·설명 검색, 오래된 개수', () {
      expect(planScenarioStaleCount(all, 3), 1);
      expect(planScenarioIsStale(b, 3), isTrue);
      expect(
        ids(
          planScenarioVisible(
            all,
            currentProfileRevision: 3,
            sort: PlanScenarioSort.recent,
            currentOnly: true,
          ),
        ),
        ['a', 'c'],
      );
      expect(
        ids(
          planScenarioVisible(
            all,
            currentProfileRevision: 3,
            sort: PlanScenarioSort.recent,
            studentId: 'aru',
          ),
        ),
        ['b', 'a'],
      );
      expect(
        ids(
          planScenarioVisible(
            all,
            currentProfileRevision: 3,
            sort: PlanScenarioSort.recent,
            query: '  총력 ',
          ),
        ),
        ['b'],
      );
      expect(planScenarioStudentIds(all), ['aru', 'ayane', 'hoshino']);
    });

    test('비교 담기: 슬롯 A는 활성 계획, 시나리오는 3개까지(모두 4), 없어진 시나리오는 빠진다', () {
      final state = PlanScenarioListController();
      addTearDown(state.dispose);
      expect(state.compareCount, 1);
      expect(state.toggleCompare('a'), PlanScenarioCompareToggle.added);
      expect(state.toggleCompare('b'), PlanScenarioCompareToggle.added);
      expect(state.toggleCompare('c'), PlanScenarioCompareToggle.added);
      expect(state.compareCount, planScenarioCompareCapacity);
      expect(state.toggleCompare('d'), PlanScenarioCompareToggle.full);
      expect(state.compareIds, ['a', 'b', 'c']);
      expect(state.toggleCompare('b'), PlanScenarioCompareToggle.removed);
      expect(state.compareIds, ['a', 'c']);

      state
        ..toggleExpanded('c')
        ..setStudent('hoshino');
      state.retainExisting([a, b]);
      expect(state.compareIds, ['a']);
      expect(state.expandedId, isNull);
      expect(state.studentId, isNull);
    });

    test('펼친 행은 하나이고 다시 누르면 접힌다, 조건 지우기는 정렬을 둔다', () {
      final state = PlanScenarioListController();
      addTearDown(state.dispose);
      state.toggleExpanded('a');
      expect(state.expandedId, 'a');
      state.toggleExpanded('b');
      expect(state.expandedId, 'b');
      state.toggleExpanded('b');
      expect(state.expandedId, isNull);
      state
        ..setSort(PlanScenarioSort.name)
        ..setCurrentOnly(true)
        ..setQuery('x');
      expect(state.filtering, isTrue);
      state.clearFilters();
      expect(state.filtering, isFalse);
      expect(state.sort, PlanScenarioSort.name);
    });

    test('표기: 크레딧 줄임 · 부족량 · 수정 시각 · 개수', () {
      expect(planScenarioCredits(186200000), '186.2M');
      expect(planScenarioCredits(0), '0');
      expect(planScenarioShortageAmount(449), '−449');
      expect(planScenarioShortageAmount(12000), '−12K');
      expect(planScenarioUpdatedLabel('2026-09-22T23:10:00'), '수정 9.22 23:10');
      expect(planScenarioUpdatedLabel('?'), '수정 시각 미상');
      expect(
        planScenarioCountsLabel(students: 3, phases: 3, stages: 5),
        '학생 3 · 페이즈 3 · 단계 5',
      );
    });
  });

  test('Studio 3섹션: S1은 시안과 같고 S2·S3는 정수 칸 근사다', () {
    const size = Size(2560, 1208);
    final menu = planScenarioSectionPolygon(size, planScenarioMenuSectionId);
    final list = planScenarioSectionPolygon(size, planScenarioListSectionId);
    final preview = planScenarioSectionPolygon(
      size,
      planScenarioPreviewSectionId,
    );
    // 시안 y는 기준 viewport(머리말 184 포함) 값이다.
    expect(menu[0].dy + 184, closeTo(209, 1));
    expect(menu[1].dx, closeTo(400, 1));
    expect(menu[2].dx, closeTo(191.4, 1));
    expect(menu[2].dy + 184, closeTo(1392, 1));
    // S2: 아랫변 왼쪽 시안 215.4(−2.1), 윗변 오른쪽 시안 1720(+8.6).
    expect(list[3].dx, closeTo(215.4, 2.2));
    expect(list[1].dx, closeTo(1720, 8.7));
    // S3: 왼쪽 변 아래 시안 1535.4(+11.3), 오른쪽은 화면 끝.
    expect(preview[2].dx, closeTo(1535.4, 11.4));
    expect(preview[0].dx, closeTo(2560, 0.5));
    expect(
      planScenarioListStudioDocument.elements.map((element) => element.id),
      [
        planScenarioMenuSectionId,
        planScenarioListSectionId,
        planScenarioPreviewSectionId,
      ],
    );
  });

  group('화면', () {
    testWidgets('고정 행 · 정렬 · 검색 · 학생 필터 · 펼친 행 미리보기', (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final ids = await _seed(service, [
        ('나 시나리오', '딜러 먼저', ['aru']),
        ('가 시나리오', '총력전 대비', ['ayane']),
      ]);
      await _pumpPlanning(tester, service);

      expect(find.text('2개'), findsOneWidget);
      expect(find.text('오래된 시나리오 없음'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-scenario-active-row')),
        findsOneWidget,
      );
      expect(find.text('활성 계획'), findsWidgets);
      expect(find.text('메인 · 지금 쓰는 계획'), findsOneWidget);
      // 나중에 만든 "가 시나리오"가 최근 수정 순으로 위다(같은 시각이면 이름 순).
      final first = ids['가 시나리오']!;
      final second = ids['나 시나리오']!;
      expect(
        _rowTop(tester, first),
        lessThanOrEqualTo(_rowTop(tester, second)),
      );

      await tester.tap(find.text('이름'));
      await tester.pumpAndSettle();
      expect(_rowTop(tester, first), lessThan(_rowTop(tester, second)));

      await tester.enterText(
        find.byKey(const ValueKey('plan-scenario-search')),
        '딜러',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('plan-scenario-row-$second')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('plan-scenario-row-$first')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('plan-scenario-search')),
        '없는 말',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plan-scenario-list-filtered-empty')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('plan-scenario-filter-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('plan-scenario-row-$first')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('plan-scenario-filter-student')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-filter-student-ayane')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('plan-scenario-row-$first')), findsOneWidget);
      expect(find.byKey(ValueKey('plan-scenario-row-$second')), findsNothing);

      expect(
        find.byKey(const ValueKey('plan-scenario-preview-empty')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ValueKey('plan-scenario-row-$first')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('plan-scenario-delete-$first')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('plan-scenario-preview-name')),
            )
            .data,
        '가 시나리오',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('행 액션: 복제 · 이름·설명 · 삭제는 서비스로 저장하고 목록을 다시 읽는다', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final ids = await _seed(service, [
        ('원본 시나리오', '설명 하나', ['aru']),
      ]);
      final id = ids['원본 시나리오']!;
      await _pumpPlanning(tester, service);
      await tester.tap(find.byKey(ValueKey('plan-scenario-row-$id')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('plan-scenario-duplicate-$id')));
      await tester.pumpAndSettle();
      expect((await service.listScenarios(_profileId)).scenarios, hasLength(2));
      expect(find.text('2개'), findsOneWidget);
      expect(find.textContaining('복제했습니다'), findsOneWidget);
      await _drainSnackBars(tester);

      // 복제본이 펼쳐졌으므로 원본을 다시 고른다.
      await tester.tap(find.byKey(ValueKey('plan-scenario-row-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('plan-scenario-rename-$id')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plan-scenario-rename-modal')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('plan-scenario-rename-name')),
        '바꾼 이름',
      );
      await tester.enterText(
        find.byKey(const ValueKey('plan-scenario-rename-description')),
        '바꾼 설명',
      );
      await tester.tap(find.byKey(const ValueKey('plan-scenario-rename-save')));
      await tester.pumpAndSettle();
      final renamed = (await service.getScenario(_profileId, id)).scenario;
      expect(renamed.name, '바꾼 이름');
      expect(renamed.description, '바꾼 설명');
      expect(renamed.document.stages.single.studentId, 'aru');
      expect(
        find.byKey(const ValueKey('plan-scenario-rename-modal')),
        findsNothing,
      );
      await _drainSnackBars(tester);

      await tester.tap(find.byKey(ValueKey('plan-scenario-delete-$id')));
      await tester.pumpAndSettle();
      expect(find.textContaining('되돌릴 수 없습니다'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan-scenario-delete-confirm')));
      await tester.pumpAndSettle();
      final remaining = (await service.listScenarios(_profileId)).scenarios;
      expect(remaining, hasLength(1));
      expect(remaining.single.id, isNot(id));
      expect(find.byKey(ValueKey('plan-scenario-row-$id')), findsNothing);
      await _drainSnackBars(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('비교 담기: 슬롯 B~D, 넷이 넘으면 안내, 둘이면 A↔B 비교 화면을 그 둘로 연다', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final ids = await _seed(service, [
        ('하나', '', ['aru']),
        ('둘', '', ['ayane']),
        ('셋', '', ['aru']),
        ('넷', '', ['ayane']),
      ]);
      await _pumpPlanning(tester, service, loadRepositoryPlan: true);
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.text('기준 · 뺄 수 없습니다'), findsOneWidget);
      expect(find.text('목록에서 체크해서 담기'), findsNWidgets(3));

      Finder run() => find.byKey(const ValueKey('plan-scenario-compare-run'));
      bool runEnabled() => tester.widget<RailButton>(run()).onPressed != null;

      await tester.tap(find.byKey(ValueKey('plan-scenario-compare-${ids['하나']}')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 4'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('plan-scenario-compare-slot-1')),
          matching: find.text('하나'),
        ),
        findsOneWidget,
      );
      expect(runEnabled(), isTrue);

      for (final name in const ['둘', '셋']) {
        await tester.tap(
          find.byKey(ValueKey('plan-scenario-compare-${ids[name]}')),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('4 / 4'), findsOneWidget);
      expect(runEnabled(), isFalse);
      await tester.tap(find.byKey(ValueKey('plan-scenario-compare-${ids['넷']}')));
      await tester.pumpAndSettle();
      expect(find.textContaining('4개까지 담을 수 있습니다'), findsOneWidget);
      await _drainSnackBars(tester);

      // 슬롯의 ×로 빼서 하나만 남기면 A↔B 비교를 연다.
      await tester.tap(find.byKey(const ValueKey('plan-scenario-compare-slot-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-scenario-compare-slot-2')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 4'), findsOneWidget);
      await tester.tap(run());
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioListSection), findsNothing);
      expect(find.byType(PlanScenarioComparisonSection), findsOneWidget);
      // 비교 화면은 계획 홈 섹션 1을 둔다(목록에서 내렸던 섹션 1이 다시 들어온다).
      expect(_homeSectionValue(tester, 'element-1'), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('S1: 새 시나리오는 계획 만들기 1단계, 활성 계획으로는 계획 홈으로 돌아간다', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await _pumpPlanning(tester, service);
      await tester.tap(find.byKey(const ValueKey('plan-scenario-menu-create')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioListSection), findsNothing);
      expect(find.byKey(const ValueKey('plan-flow-rail')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('plan-flow-previous')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-flow-rail')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
      await tester.pumpAndSettle();
      expect(_homeSectionValue(tester, 'element-1'), 0);
      await tester.tap(find.byKey(const ValueKey('plan-scenario-menu-back')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioListSection), findsNothing);
      for (final id in const [
        'element-1',
        'element-2',
        'element-3',
        'element-4',
        'element-5',
      ]) {
        expect(_homeSectionValue(tester, id), 1, reason: id);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
