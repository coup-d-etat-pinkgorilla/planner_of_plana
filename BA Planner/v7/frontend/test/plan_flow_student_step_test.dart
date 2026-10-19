// 계획 만들기 1단계 학생 고르기(FE4-b1) 위젯 테스트: 고르기·해제·고른 순서 배지, C 목록 ↔ 압축 그리드 7명 경계
// (FD-077), 필터 모달 초안 → 적용(계획 칩 그룹, FD-104), 빠른 칩·적용 칩, 역할군 칩과 "보이는 학생 모두 고르기",
// 검색, 의미 구조.
//
// 기존 학생 고르기(`PlanStudentSelector`)가 다루던 동작(검색·속성 필터·보유/계획 필터·성장 범위·고른 순서·확정)은
// 이 파일과 `plan_flow_test`·`planning_page_test`의 흐름 테스트로 옮겼다(상태 문서 FE4-b1 기능 대조표).
//
// 다중 폼 초상 시계는 고정한다(Timer 없음). 모달·팝오버(OverlayPortal)가 있는 화면은 명시적인 pump를 쓴다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/student_filter_selection.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_student_step.dart';
import 'package:ba_planner_v7/ui/widgets/student_form_cycle.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 콘텐츠 캔버스(기준 viewport 2560×1392에서 헤더 184 아래).
const _canvas = Size(2560, 1208);

/// 계획(저장된 활성 계획 문서)에 넣어 둘 학생. PLAN 배지·계획 칩 그룹에 쓴다.
const _plannedIds = ['hoshino', 'hina'];

Future<(PlanFlowController, PlanFlowStudentPicker)> _setup(
  MockAppService service,
) async {
  final profile = (await service.listProfiles()).firstWhere(
    (profile) => profile.selected,
  );
  var state = await service.loadRepositoryState(profile.id);
  await service.saveRepositoryGoals(
    profile.id,
    {
      'version': 1,
      'goals': [
        for (final id in _plannedIds) {'student_id': id},
      ],
    },
    state.revision,
    'plan-flow-student-step-goals',
  );
  // FE4-h: 계획 학생은 저장된 활성 계획 문서(plan.get)에서 읽는다. goals 저장(legacy write)은 그 문서도 바꾼다.
  final plan = await service.loadRepositoryPlan(profile.id);
  state = await service.loadRepositoryState(profile.id);
  final catalog = await service.listStudents();
  final context = PlanFlowContext(
    repositoryState: state,
    catalog: {for (final entry in catalog) entry.studentId: entry},
    activePlan: plan.document,
  );
  final flow = PlanFlowController(
    purpose: PlanFlowPurpose.newScenario,
    context: context,
    service: service,
  );
  final picker = PlanFlowStudentPicker(context: context);
  addTearDown(flow.dispose);
  addTearDown(picker.dispose);
  return (flow, picker);
}

Future<void> _pumpStep(
  WidgetTester tester,
  PlanFlowController flow,
  PlanFlowStudentPicker picker,
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
                  child: PlanFlowStudentBody(flow: flow, picker: picker),
                ),
                Positioned.fill(
                  child: PlanFlowStudentAside(flow: flow, picker: picker),
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

final _grid = find.byKey(const ValueKey('plan-flow-student-grid'));
final _selectedGrid = find.byKey(const ValueKey('plan-flow-selected-grid'));

StudentDiagonalGrid _gridWidget(WidgetTester tester, [Finder? finder]) =>
    tester.widget<StudentDiagonalGrid>(finder ?? _grid);

Future<void> _tapCard(
  WidgetTester tester,
  String studentId, {
  Finder? grid,
}) async {
  await tester.tap(
    find.descendant(
      of: grid ?? _grid,
      matching: find.byKey(ValueKey('student-$studentId')),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => StudentFormClock.instance.freeze(0));
  tearDown(() => StudentFormClock.instance.freeze(null));

  test('계획 칩 그룹은 학교 다음에 오고, 프로필 목표에 있는 학생을 "계획"으로 본다', () {
    final groups = planFlowStudentFilterGroups({'hina'});
    expect(groups.map((group) => group.key).take(2), [
      'school',
      planFlowPlanFilterKey,
    ]);
    expect(groups, hasLength(studentCatalogFilterGroups.length + 1));
    expect(
      studentFilterChipLabel(planFlowPlanFilterKey, planFlowUnplannedValue),
      '계획에 없는 학생만',
    );
    expect(
      planFlowSelectedSummary({
        'level': 78,
        'student_star': 3,
        'ex_skill': 3,
        'skill1': 7,
        'skill2': 7,
        'skill3': 4,
      }),
      'Lv.78 · ★3 · 스킬 3/7/7/4',
    );
    expect(planFlowSelectedSummary(null), '미보유 · 모집 후 목표 적용');
    expect(
      planFlowSelectionWarning(unowned: 1, planned: 2),
      '미보유 1명 · 이미 계획에 있는 학생 2명',
    );
  });

  testWidgets('계획 학생은 저장된 활성 계획 문서 기준이다(goals를 보지 않는다, FE4-h)', (
    tester,
  ) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    final (_, picker) = await _setup(service);
    expect(picker.plannedIds, _plannedIds.toSet());
    expect(picker.context.activePlan, isNotNull);

    // 같은 계정 상태(goals에 두 학생이 있다)라도 문서를 주지 않으면 계획 학생이 없다.
    final withoutPlan = PlanFlowContext(
      repositoryState: picker.context.repositoryState,
      catalog: picker.context.catalog,
    );
    expect(
      withoutPlan.repositoryState.goals.map((goal) => goal.studentId),
      containsAll(_plannedIds),
    );
    expect(withoutPlan.plannedStudentIds, isEmpty);
    final bare = PlanFlowStudentPicker(context: withoutPlan);
    addTearDown(bare.dispose);
    expect(bare.plannedIds, isEmpty);
  });

  testWidgets('그리드에서 고르면 고른 순서 배지가 붙고, 다시 누르거나 ×로 빼면 순서가 당겨진다', (
    tester,
  ) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    final (flow, picker) = await _setup(service);
    await _pumpStep(tester, flow, picker);

    final ids = [
      for (final student in _gridWidget(tester).students.take(3))
        student.studentId,
    ];
    for (final id in ids) {
      await _tapCard(tester, id);
    }
    expect(flow.selectedStudentIds, ids);
    expect(_gridWidget(tester).selectionOrder, {
      ids[0]: 1,
      ids[1]: 2,
      ids[2]: 3,
    });
    expect(_gridWidget(tester).selectedIds, ids.toSet());
    for (final id in ids) {
      expect(find.byKey(ValueKey('plan-flow-selected-$id')), findsOneWidget);
    }
    expect(find.text('3명 골랐습니다'), findsOneWidget);

    // 카드를 한 번 더 누르면 빠지고 뒤 학생의 번호가 당겨진다.
    await _tapCard(tester, ids[0]);
    expect(_gridWidget(tester).selectionOrder, {ids[1]: 1, ids[2]: 2});
    expect(find.byKey(ValueKey('plan-flow-selected-${ids[0]}')), findsNothing);

    // C 목록의 ×.
    await tester.tap(find.byKey(ValueKey('plan-flow-selected-${ids[1]}-remove')));
    await tester.pump();
    expect(flow.selectedStudentIds, [ids[2]]);
    expect(_gridWidget(tester).selectionOrder, {ids[2]: 1});
    expect(tester.takeException(), isNull);
  });

  testWidgets('고른 학생이 7명부터 C는 압축 그리드가 되고, 6명 이하로 줄면 목록으로 돌아간다(FD-077)', (
    tester,
  ) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    final (flow, picker) = await _setup(service);
    await _pumpStep(tester, flow, picker);
    final ids = [
      for (final student in picker.students.take(7)) student.studentId,
    ];

    flow.addStudents(ids.take(planFlowCompactSelectionThreshold - 1));
    await tester.pump();
    expect(_selectedGrid, findsNothing);
    for (final id in ids.take(6)) {
      expect(find.byKey(ValueKey('plan-flow-selected-$id')), findsOneWidget);
    }

    flow.addStudents([ids.last]);
    await tester.pump();
    expect(_selectedGrid, findsOneWidget);
    expect(find.byKey(ValueKey('plan-flow-selected-${ids.first}')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('plan-flow-selected-count'))).data,
      '7',
    );
    final compact = _gridWidget(tester, _selectedGrid);
    expect(compact.columns, 4);
    expect(compact.showRemoveMarks, isTrue);
    expect(compact.students.map((student) => student.studentId), ids);
    expect(compact.selectionOrder[ids.last], 7);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('plan-flow-selected-warning')))
          .data,
      planFlowSelectionWarning(
        unowned: [
          for (final id in ids)
            if (!picker.ownedIds.contains(id)) id,
        ].length,
        planned: [
          for (final id in ids)
            if (picker.plannedIds.contains(id)) id,
        ].length,
      ),
    );

    // 정렬 "이름": 압축 그리드 순서만 바뀌고 고른 순서 배지는 그대로다.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('plan-flow-selected-sort')),
        matching: find.text('이름'),
      ),
    );
    await tester.pump();
    final byName = _gridWidget(tester, _selectedGrid);
    final names = [for (final student in byName.students) student.displayName];
    expect(names, [...names]..sort());
    expect(byName.selectionOrder[ids.first], 1);

    // 압축 카드를 누르면 빠지고 6명이 되면 목록으로 돌아간다.
    await _tapCard(tester, ids.first, grid: _selectedGrid);
    expect(flow.selectedStudentIds, ids.skip(1));
    expect(_selectedGrid, findsNothing);
    expect(find.byKey(ValueKey('plan-flow-selected-${ids[1]}')), findsOneWidget);

    // 다시 7명으로 만든 뒤 "모두 비우기".
    flow.addStudents([ids.first]);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-flow-selected-clear')));
    await tester.pump();
    expect(flow.selectedStudentIds, isEmpty);
    expect(find.byKey(const ValueKey('plan-flow-selected-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('필터 모달: 초안은 적용 전까지 그리드에 걸리지 않고, 적용하면 계획 칩까지 걸린다', (
    tester,
  ) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    final (flow, picker) = await _setup(service);
    await _pumpStep(tester, flow, picker);
    final total = _gridWidget(tester).students.length;
    expect(total, picker.students.length);

    final modal = find.byKey(const ValueKey('plan-flow-student-filter-modal'));
    await tester.tap(find.byKey(const ValueKey('plan-flow-student-filter')));
    await tester.pump();
    await tester.pump();
    expect(modal, findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-filter-chip-plan-unplanned')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('student-filter-chip-school-Millennium')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('student-filter-chip-plan-unplanned')),
    );
    await tester.pump();
    // 초안: 그리드는 그대로다.
    expect(_gridWidget(tester).students, hasLength(total));
    // FE4-c: 학생 탭 S1 필터 버튼 자리의 "필터 · n" 배지는 그리지 않는다(개수는 B 오른쪽 위 필터 버튼이 보인다).
    expect(
      find.byKey(const ValueKey('student-filter-modal-badge')),
      findsNothing,
    );

    // 닫으면(적용 안 함) 초안을 버린다.
    await tester.tap(find.byKey(const ValueKey('student-filter-close')));
    await tester.pump();
    await tester.pump();
    expect(modal, findsNothing);
    expect(picker.filter.activeCount, 0);
    expect(_gridWidget(tester).students, hasLength(total));

    // 다시 열어 고르고 "적용".
    await tester.tap(find.byKey(const ValueKey('plan-flow-student-filter')));
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('student-filter-chip-school-Millennium')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('student-filter-chip-plan-unplanned')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('student-filter-apply')));
    await tester.pump();
    await tester.pump();
    expect(modal, findsNothing);
    final filtered = _gridWidget(tester).students;
    expect(filtered, isNotEmpty);
    expect(filtered.length, lessThan(total));
    for (final student in filtered) {
      expect(student.school, 'Millennium');
      expect(_plannedIds, isNot(contains(student.studentId)));
    }
    expect(picker.filter.activeCount, 2);
    // "계획에 없는 학생만"은 빠른 칩으로 보이고, 학교는 적용 칩(×)으로 보인다.
    expect(
      tester
          .widget<SkewToggleChip>(
            find.byKey(const ValueKey('plan-flow-quick-unplanned')),
          )
          .selected,
      isTrue,
    );
    final schoolChip = find.byKey(
      const ValueKey('plan-flow-applied-school-Millennium'),
    );
    expect(schoolChip, findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-flow-applied-plan-unplanned')),
      findsNothing,
    );

    // 적용 칩 ×와 빠른 칩으로 푼다.
    await tester.tap(
      find.descendant(of: schoolChip, matching: find.byType(KitPressable)),
    );
    await tester.pump();
    expect(picker.filter.activeCount, 1);
    await tester.tap(find.byKey(const ValueKey('plan-flow-quick-unplanned')));
    await tester.pump();
    expect(picker.filter.activeCount, 0);
    expect(_gridWidget(tester).students, hasLength(total));

    // "보유만" 빠른 칩.
    await tester.tap(find.byKey(const ValueKey('plan-flow-quick-owned')));
    await tester.pump();
    for (final student in _gridWidget(tester).students) {
      expect(picker.ownedIds, contains(student.studentId));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('역할군 칩은 그리드 필터로 걸리고, "보이는 학생 모두 고르기"가 보이는 학생을 순서대로 붙인다', (
    tester,
  ) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    final (flow, picker) = await _setup(service);
    await _pumpStep(tester, flow, picker);

    await tester.tap(find.byKey(const ValueKey('plan-flow-role-role-healer')));
    await tester.pump();
    final healers = _gridWidget(tester).students;
    expect(healers, isNotEmpty);
    for (final student in healers) {
      expect(student.role, 'healer');
    }
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('plan-flow-visible-status')))
          .data,
      '힐러 ${healers.length}명 · 필터를 그리드에 적용 중',
    );
    expect(
      tester
          .widget<SkewToggleChip>(
            find.byKey(const ValueKey('plan-flow-role-role-healer')),
          )
          .count,
      picker.students.where((student) => student.role == 'healer').length,
    );

    await tester.tap(find.byKey(const ValueKey('plan-flow-select-visible')));
    await tester.pump();
    expect(flow.selectedStudentIds, [
      for (final student in healers) student.studentId,
    ]);

    // 다른 역할군 칩은 앞 칩을 끄고 하나만 켠다. 같은 칩을 다시 누르면 끈다.
    await tester.tap(find.byKey(const ValueKey('plan-flow-role-combat_class-special')));
    await tester.pump();
    expect(picker.activeRoleChip?.label, '스페셜');
    expect(picker.filter.applied.catalog['role'] ?? const <String>{}, isEmpty);
    await tester.tap(find.byKey(const ValueKey('plan-flow-role-combat_class-special')));
    await tester.pump();
    expect(picker.activeRoleChip, isNull);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('plan-flow-visible-status')))
          .data,
      '보이는 학생 ${picker.students.length}명',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('검색은 이름에 더해 학교·역할 이름으로도 찾는다', (tester) async {
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    final (flow, picker) = await _setup(service);
    await _pumpStep(tester, flow, picker);

    await tester.enterText(
      find.byKey(const ValueKey('plan-flow-student-search')),
      '밀레니엄',
    );
    await tester.pump();
    final found = _gridWidget(tester).students;
    expect(found, isNotEmpty);
    for (final student in found) {
      expect(student.school, 'Millennium');
    }

    await tester.enterText(
      find.byKey(const ValueKey('plan-flow-student-search')),
      '조건에 맞는 학생이 없는 검색어',
    );
    await tester.pump();
    expect(_grid, findsNothing);
    expect(find.text('조건에 맞는 학생이 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('의미 구조: 고른 학생 행은 이름·값·안내를, 압축 카드는 "빼기"를 알린다', (tester) async {
    final handle = tester.ensureSemantics();
    final service = MockAppService(fullStudentCatalog: true);
    addTearDown(service.dispose);
    final (flow, picker) = await _setup(service);
    await _pumpStep(tester, flow, picker);
    final first = picker.students.first;
    flow.addStudents([first.studentId]);
    await tester.pump();

    expect(
      find.bySemanticsLabel('1번째 ${first.displayName}'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('1번째 ${first.displayName}'),
      ),
      isSemantics(
        label: '1번째 ${first.displayName}',
        value: planFlowSelectedSummary(
          picker.studentValuesById[first.studentId],
        ),
        hint: '× 버튼으로 뺍니다',
      ),
    );
    expect(find.byTooltip('${first.displayName} 빼기'), findsOneWidget);

    flow.addStudents([
      for (final student in picker.students.skip(1).take(6)) student.studentId,
    ]);
    await tester.pump();
    expect(
      find.bySemanticsLabel('${first.displayName} 빼기'),
      findsWidgets,
    );
    handle.dispose();
  });
}
