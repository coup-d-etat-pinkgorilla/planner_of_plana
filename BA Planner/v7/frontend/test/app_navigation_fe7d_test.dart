// FE7-d: 통계 근거 → 원본 탭 이동(navigation intent) · 대상 탭 한 번 적용 · "← 통계" 복귀 칩 · 근거 "외 n종" 펼침.
//
// 통계 쪽은 시안 숫자 fixture(성장 · 재화 · 활성 문서)를 읽은 통계 페이지로, 대상 탭은 각 탭 위젯(인벤토리 페이지 ·
// 계획 흐름 3단계 편집기)과 앱 셸 전체(학생 탭 · 계획 1단계 · 복귀)로 확인한다.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_goal_projection.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_controller.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_view_model.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_order_editor.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/navigation/app_navigation_intent.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_balance_charts.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_growth_charts.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_supply_charts.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';
import 'statistics_growth_fixture.dart';
import 'statistics_plan_fixture.dart';
import 'statistics_supply_fixture.dart';

const _canvas = Size(2560, 1208);
const _profileId = '0123456789abcdef01234567';

/// 성장 · 재화 · 활성 문서 fixture를 모두 주는 통계 서비스(통계 화면 테스트들과 같은 숫자).
class _StatisticsService extends MockAppService {
  _StatisticsService({this.supply = false});

  /// true면 계정 상태가 재화 fixture(목표 · 인벤토리)다. false면 성장 fixture(보유 128명).
  final bool supply;

  @override
  Future<List<RepositoryProfile>> listProfiles() async => const [
    RepositoryProfile(
      id: _profileId,
      displayName: 'Main',
      revision: 1,
      selected: true,
    ),
  ];

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async => supply
      ? statisticsSupplyFixtureState(profileId: profileId)
      : statisticsGrowthFixtureState(profileId: profileId);

  @override
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId) async =>
      statisticsPlanFixturePlan(profileId: profileId);

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async => statisticsPlanFixtureProjection(owned: statisticsPlanFixtureOwned);

  @override
  Future<List<StudentCatalogEntry>> listStudents() async =>
      statisticsGrowthFixtureCatalog();

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      InventoryCatalogResult(
        catalogRevision: '0' * 64,
        items: statisticsSupplyFixtureCatalog,
      );

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async => statisticsSupplyFixtureShortages();
}

/// 앱 셸 테스트용: Mock 기본 계정(선택됨)에 성장 fixture 학생 · 상태를 준다.
class _ShellService extends MockAppService {
  /// revision은 Mock 계정 그대로 둔다(활성 계획 `plan.get`과 같은 revision이어야 계획 흐름이 열린다).
  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async =>
      statisticsGrowthFixtureState(
        profileId: profileId,
        revision: (await super.loadRepositoryState(profileId)).revision,
      );

  @override
  Future<List<StudentCatalogEntry>> listStudents() async =>
      statisticsGrowthFixtureCatalog();
}

/// 통계 페이지 + 바깥에서 바꾸는 reload · return 토큰.
class _Host extends StatefulWidget {
  const _Host({super.key, required this.service, required this.onNavigate});

  final AppService service;
  final ValueChanged<AppNavigationIntent> onNavigate;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int reloadToken = 0;
  int returnToken = 0;

  void reload({bool returning = false}) => setState(() {
    reloadToken += 1;
    if (returning) returnToken += 1;
  });

  @override
  Widget build(BuildContext context) => StatisticsPage(
    service: widget.service,
    onOpen: (_) {},
    onNavigate: widget.onNavigate,
    reloadToken: reloadToken,
    returnToken: returnToken,
  );
}

Future<(_StatisticsService, List<AppNavigationIntent>, GlobalKey<_HostState>)>
_pumpStatistics(WidgetTester tester, {bool supply = false}) async {
  await tester.binding.setSurfaceSize(_canvas);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final service = _StatisticsService(supply: supply);
  addTearDown(service.dispose);
  final intents = <AppNavigationIntent>[];
  final host = GlobalKey<_HostState>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _Host(key: host, service: service, onNavigate: intents.add),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (service, intents, host);
}

Offset _chartPoint(
  WidgetTester tester,
  String key,
  Size viewBox,
  Offset point,
) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  return rect.topLeft + point * (rect.width / viewBox.width);
}

Future<void> _tapBin(WidgetTester tester, int bin) async {
  final slot = StatisticsA1Geometry.barSlot(bin);
  await tester.tapAt(
    _chartPoint(
      tester,
      'statistics-a1-chart',
      statisticsA1ViewBox,
      Offset(slot.center.dx + 1, StatisticsA1Geometry.baseline - 6),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapB1(WidgetTester tester, int row) async {
  await tester.tapAt(
    _chartPoint(
      tester,
      'statistics-b1-chart',
      statisticsB1ViewBox,
      Offset(200, StatisticsB1Geometry.baselineOf(row, 6) - 8),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapC1(WidgetTester tester, int row) async {
  await tester.tapAt(
    _chartPoint(
      tester,
      'statistics-c1-chart',
      statisticsC1ViewBox,
      Offset(200, StatisticsC1Geometry.baselineOf(row) - 8),
    ),
  );
  await tester.pumpAndSettle();
}

/// C2 기술 노트 (최상급) 점(충족 96 / 120 = 80% · 학생 6명, 세로축 8).
Future<void> _tapTechNote(WidgetTester tester) async {
  await tester.tapAt(
    _chartPoint(
      tester,
      'statistics-c2-chart',
      statisticsC2ViewBox,
      Offset(StatisticsC2Geometry.xOf(0.8), StatisticsC2Geometry.yOf(6, 8)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: key);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 근거 패널 이동 버튼의 바탕 키트 버튼(누를 수 있는가).
VoidCallback? _onPressed(WidgetTester tester, String key) => tester
    .widget<RailButton>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(RailButton),
      ),
    )
    .onPressed;

Finder _inside(String key, String text) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.text(text),
);

/// 화면에 있는 키 중 [prefix]로 시작하는 것(위에서 아래 순서).
List<String> _keysWithPrefix(WidgetTester tester, String prefix) {
  final found = <(double, String)>[];
  for (final element in find
      .byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(prefix),
      )
      .evaluate()) {
    final key = (element.widget.key! as ValueKey<String>).value;
    found.add((tester.getRect(find.byKey(ValueKey(key))).top, key));
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final item in found) item.$2];
}

void main() {
  testWidgets('evidence buttons stay disabled until something is selected', (
    tester,
  ) async {
    await _pumpStatistics(tester);
    for (final key in [
      'statistics-evidence-secondary',
      'statistics-evidence-primary',
    ]) {
      expect(_onPressed(tester, key), isNull, reason: key);
    }
    expect(_inside('statistics-evidence-secondary', '학생 탭에서 보기'), findsOneWidget);
    expect(find.textContaining('필터: '), findsNothing);
  });

  testWidgets('growth bin buttons pass the bin students to students and plan', (
    tester,
  ) async {
    final (_, intents, _) = await _pumpStatistics(tester);
    await _tapBin(tester, 6);
    expect(
      _inside('statistics-evidence-secondary', '필터: 육성도 60~70%'),
      findsOneWidget,
    );
    expect(_onPressed(tester, 'statistics-evidence-secondary'), isNotNull);
    expect(_onPressed(tester, 'statistics-evidence-primary'), isNotNull);

    await _tapKey(tester, 'statistics-evidence-secondary');
    final students = intents.single as StudentsNavigationIntent;
    expect(students.section, AppSection.students);
    expect(students.studentIds, hasLength(22));
    expect(students.label, '통계: 육성도 60~70% · 22명');
    expect(students.returnLabel, '← 통계');

    await _tapKey(tester, 'statistics-evidence-primary');
    final plan = intents.last as PlanNavigationIntent;
    expect(plan.target, PlanNavigationTarget.students);
    expect(plan.studentIds, students.studentIds);
    expect(plan.id, isNot(students.id));
  });

  testWidgets('inventory category buttons: lowest row and tiers for notes', (
    tester,
  ) async {
    final (_, intents, _) = await _pumpStatistics(tester, supply: true);
    await _tapKey(tester, 'statistics-topic-inventory');

    // 장비 설계도: 티어별 충족률 표가 없어 ghost는 비활성, primary는 충족률 가장 낮은 행(장갑 T6 11 / 20).
    await _tapB1(tester, 0);
    expect(_onPressed(tester, 'statistics-evidence-secondary'), isNull);
    expect(
      _inside('statistics-evidence-primary', '해당 행 선택 · 획득처'),
      findsOneWidget,
    );
    await _tapKey(tester, 'statistics-evidence-primary');
    final row = intents.single as InventoryNavigationIntent;
    expect(row.target, InventoryNavigationTarget.row);
    final first = _keysWithPrefix(tester, 'statistics-evidence-resource-')
        .first
        .substring('statistics-evidence-resource-'.length);
    expect(row.resourceKey, first);
    expect(row.resourceKey, contains('Gloves'));

    // 기술 노트: 티어별 충족률로 간다.
    await _tapB1(tester, 1);
    expect(_onPressed(tester, 'statistics-evidence-secondary'), isNotNull);
    await _tapKey(tester, 'statistics-evidence-secondary');
    expect(
      (intents.last as InventoryNavigationIntent).target,
      InventoryNavigationTarget.tiers,
    );
  });

  testWidgets('category evidence "외 n종" expands like the growth list', (
    tester,
  ) async {
    await _pumpStatistics(tester, supply: true);
    await _tapKey(tester, 'statistics-topic-inventory');
    await _tapB1(tester, 0);
    expect(_keysWithPrefix(tester, 'statistics-evidence-resource-'), hasLength(7));
    expect(_inside('statistics-evidence-rest', '외 2종'), findsOneWidget);
    expect(_inside('statistics-evidence-rest', '모두 보기'), findsOneWidget);

    await _tapKey(tester, 'statistics-evidence-rest');
    expect(find.byKey(const ValueKey('statistics-evidence-rest')), findsNothing);
    expect(find.byKey(const ValueKey('statistics-evidence-scroll')), findsOneWidget);
    expect(_keysWithPrefix(tester, 'statistics-evidence-resource-'), hasLength(9));
    // 요약은 그대로 아래에 있다.
    expect(
      find.byKey(const ValueKey('statistics-evidence-summary-title')),
      findsOneWidget,
    );

    // 다른 카테고리를 고르면 접힌다.
    await _tapB1(tester, 1);
    expect(find.byKey(const ValueKey('statistics-evidence-scroll')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan resource buttons: inventory row and the first blocking stage', (
    tester,
  ) async {
    final (_, intents, _) = await _pumpStatistics(tester, supply: true);
    await _tapKey(tester, 'statistics-topic-plan');

    await _tapTechNote(tester);
    expect(
      _inside('statistics-evidence-primary', '계획 만들기 3 · 단계 순서'),
      findsOneWidget,
    );
    expect(
      _inside('statistics-evidence-primary', 'P2 선택 · 순서 바꾸기'),
      findsOneWidget,
    );
    await _tapKey(tester, 'statistics-evidence-primary');
    final order = intents.single as PlanNavigationIntent;
    expect(order.target, PlanNavigationTarget.order);
    final stages = _keysWithPrefix(tester, 'statistics-evidence-stage-');
    expect(stages.first, 'statistics-evidence-stage-${order.stageId}');

    await _tapKey(tester, 'statistics-evidence-secondary');
    final row = intents.last as InventoryNavigationIntent;
    expect(row.target, InventoryNavigationTarget.row);
    expect(row.resourceKey, isNotNull);

    // 크레딧은 활성 문서 계산에서 막히는 단계가 없어 계획 버튼은 비활성, 인벤토리 버튼은 켜진다.
    await _tapC1(tester, 0);
    expect(_onPressed(tester, 'statistics-evidence-primary'), isNull);
    expect(find.text('P2 선택 · 순서 바꾸기'), findsNothing);
    expect(_onPressed(tester, 'statistics-evidence-secondary'), isNotNull);
  });

  testWidgets('returning restores the selection and expansion after reload', (
    tester,
  ) async {
    final (_, _, host) = await _pumpStatistics(tester);
    await _tapBin(tester, 6);
    await _tapKey(tester, 'statistics-evidence-more');
    expect(find.byKey(const ValueKey('statistics-evidence-scroll')), findsOneWidget);

    host.currentState!.reload(returning: true);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('statistics-evidence-title')),
        matching: find.text('육성도 60~70%'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('statistics-evidence-scroll')), findsOneWidget);

    // 평소 다시 읽기(탭을 다시 열기)는 고른 것을 지운다(FE7-b 그대로).
    host.currentState!.reload();
    await tester.pumpAndSettle();
    expect(find.text('구간을 고르면 근거가 보입니다.'), findsOneWidget);
    expect(_onPressed(tester, 'statistics-evidence-secondary'), isNull);
  });

  testWidgets('inventory applies a row intent once after the first load', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2560, 1392));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = InventoryFixtureService();
    addTearDown(service.dispose);
    final controller = InventoryController(service);
    addTearDown(controller.dispose);
    InventoryCatalogEntry entry(bool Function(InventoryCatalogEntry) test) =>
        inventoryFixtureCatalog.firstWhere(test);
    final hairpin = entry((item) => item.displayName.contains('헤어핀'));
    final stone = entry((item) => item.displayName == '최상급 강화석');
    final credits = entry((item) => item.category == 'credits');

    Future<void> open(InventoryNavigationIntent? intent) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InventoryPage(
              service: service,
              controller: controller,
              onOpenPlan: () {},
              onOpenScan: () {},
              navigation: intent,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // 장비 헤어핀(부족): 장비 모드 · 부족한 것 보기 · 장비 종류 · 그 행.
    final first = InventoryNavigationIntent.row(hairpin.resourceKey);
    await open(first);
    expect(controller.screenMode, InventoryScreenMode.list);
    expect(controller.mode, InventoryListMode.equipment);
    expect(controller.view, InventoryView.shortage);
    expect(controller.category, hairpin.category);
    expect(controller.selectedKey, hairpin.resourceKey);

    // 같은 의도는 다시 적용하지 않는다(사용자가 바꾼 선택을 되돌리지 않는다).
    controller.select(stone.resourceKey);
    await open(first);
    expect(controller.selectedKey, stone.resourceKey);

    // 계획과 무관한 강화석: 전체 보기로 그 행.
    controller.setScreenMode(InventoryScreenMode.analysis);
    await open(InventoryNavigationIntent.row(stone.resourceKey));
    expect(controller.screenMode, InventoryScreenMode.list);
    expect(controller.view, InventoryView.all);
    expect(controller.selectedKey, stone.resourceKey);

    // 재화는 주요 재화 카드라 고르기만 한다.
    await open(InventoryNavigationIntent.row(credits.resourceKey));
    expect(controller.selectedKey, credits.resourceKey);

    // 티어별 충족률.
    await open(InventoryNavigationIntent.tiers());
    expect(controller.tiersOpen, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('order editor opens on the stage the flow was asked to select', () {
    final plan = statisticsPlanFixturePlan(profileId: _profileId);
    final catalog = {
      for (final entry in statisticsGrowthFixtureCatalog())
        entry.studentId: entry,
    };
    PlanningStudentSeed seedFor(String id) => PlanningStudentSeed(
      handoffId: 'test-$id',
      studentId: id,
      metadata: catalog[id]?.metadata ?? const {},
      currentValues: const {},
    );
    final draft = PlanFlowDocumentBoundary.fromDocument(
      plan.document,
      seedFor: seedFor,
    );
    final stages = [for (final stage in plan.document.stages) stage.id];
    expect(stages.length, greaterThan(1));
    final context = PlanFlowContext(
      repositoryState: statisticsGrowthFixtureState(profileId: _profileId),
      catalog: catalog,
      activePlan: plan.document,
    );
    PlanFlowOrderEditor editorFor(String? stageId) {
      final flow = PlanFlowController(
        purpose: PlanFlowPurpose.editActivePlan,
        context: context,
        initialDraft: draft,
        initialStep: PlanFlowStep.order,
        initialOrderStageId: stageId,
      );
      addTearDown(flow.dispose);
      final editor = PlanFlowOrderEditor(flow: flow);
      addTearDown(editor.dispose);
      return editor;
    }

    final fallback = editorFor(null).selectedStageId;
    final target = stages.firstWhere((id) => id != fallback);
    expect(editorFor(target).selectedStageId, target);
    expect(editorFor('missing-stage').selectedStageId, fallback);
  });

  testWidgets('shell: students intent, return chip and leaving clears it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2560, 1392));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _ShellService();
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'top-tab-statistics');
    expect(find.byKey(const ValueKey('page-header-return-chip')), findsNothing);
    await _tapBin(tester, 6);
    await _tapKey(tester, 'statistics-evidence-secondary');

    // 학생 탭: 머리말 "← 통계", S4 적용 필터 줄 맨 앞 임시 목록 칩, 22명만.
    expect(find.byKey(const ValueKey('student-page')), findsOneWidget);
    expect(_inside('page-header-return-chip', '← 통계'), findsOneWidget);
    expect(
      _inside(
        'student-applied-filter-navigation-statistics',
        '통계: 육성도 60~70% · 22명',
      ),
      findsOneWidget,
    );
    expect(_inside('student-result-count', '22'), findsOneWidget);

    // "← 통계": 통계로 돌아가 같은 구간을 다시 보인다.
    await _tapKey(tester, 'page-header-return-chip');
    expect(find.byKey(const ValueKey('page-header-return-chip')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('statistics-evidence-title')),
        matching: find.text('육성도 60~70%'),
      ),
      findsOneWidget,
    );

    // 다시 넘긴 뒤 다른 탭으로 가면 칩이 사라지고, 학생 탭을 다시 열면 임시 목록도 없다.
    await _tapKey(tester, 'statistics-evidence-secondary');
    expect(find.byKey(const ValueKey('page-header-return-chip')), findsOneWidget);
    await _tapKey(tester, 'top-tab-home');
    expect(find.byKey(const ValueKey('page-header-return-chip')), findsNothing);
    await _tapKey(tester, 'top-tab-students');
    expect(find.byKey(const ValueKey('page-header-return-chip')), findsNothing);
    expect(
      find.byKey(const ValueKey('student-applied-filter-navigation-statistics')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell: the restriction chip clears with "모두 지우기"', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2560, 1392));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _ShellService();
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'top-tab-statistics');
    await _tapBin(tester, 6);
    await _tapKey(tester, 'statistics-evidence-secondary');
    expect(_inside('student-result-count', '22'), findsOneWidget);

    await _tapKey(tester, 'student-filter-clear-all');
    expect(
      find.byKey(const ValueKey('student-applied-filter-navigation-statistics')),
      findsNothing,
    );
    expect(_inside('student-result-count', '22'), findsNothing);
    // 복귀 칩은 탭을 떠날 때까지 남는다.
    expect(find.byKey(const ValueKey('page-header-return-chip')), findsOneWidget);
  });

  testWidgets('shell: "이 구간 학생을 계획에 추가" opens plan step 1 preselected', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2560, 1392));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _ShellService();
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'top-tab-statistics');
    await _tapBin(tester, 6);
    await _tapKey(tester, 'statistics-evidence-primary');

    final workspace = tester.widget<PlanFlowWorkspace>(
      find.byType(PlanFlowWorkspace),
    );
    expect(workspace.flow.purpose, PlanFlowPurpose.newScenario);
    expect(workspace.flow.step, PlanFlowStep.students);
    expect(workspace.flow.selectedStudentIds, hasLength(22));
    expect(_inside('page-header-return-chip', '← 통계'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell: "계획 만들기 3 · 단계 순서" opens the phase editor on the stage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2560, 1392));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _StatisticsService(supply: true);
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'top-tab-statistics');
    await _tapKey(tester, 'statistics-topic-plan');
    await _tapTechNote(tester);
    final stage = _keysWithPrefix(
      tester,
      'statistics-evidence-stage-',
    ).first.substring('statistics-evidence-stage-'.length);
    await _tapKey(tester, 'statistics-evidence-primary');

    final workspace = tester.widget<PlanFlowWorkspace>(
      find.byType(PlanFlowWorkspace),
    );
    expect(workspace.flow.purpose, PlanFlowPurpose.editActivePlan);
    expect(workspace.flow.step, PlanFlowStep.order);
    expect(workspace.flow.initialOrderStageId, stage);
    expect(workspace.flow.draft.stageById(stage), isNotNull);
    expect(_inside('page-header-return-chip', '← 통계'), findsOneWidget);

    // 복귀하면 같은 재화 근거가 다시 보인다(흐름 초안은 계획 탭에 그대로 남는다).
    await _tapKey(tester, 'page-header-return-chip');
    expect(
      find.byKey(ValueKey('statistics-evidence-stage-$stage')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell: C4 "계획 만들기 2 · 목표 정하기" opens goals on the student', (
    tester,
  ) async {
    // FE7-f: 통계 C4 행 → 활성 계획 편집 흐름 2단계(목표 정하기)에서 그 학생(계산기 넘기기와 같은 초점).
    await tester.binding.setSurfaceSize(const Size(2560, 1392));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _StatisticsService(supply: true);
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'top-tab-statistics');
    await _tapKey(tester, 'statistics-topic-plan');
    final first = StatisticsGoalProgressSet.of(
      state: statisticsSupplyFixtureState(),
      catalog: statisticsGrowthFixtureCatalog(),
    ).rows.first;
    await tester.tapAt(
      _chartPoint(
        tester,
        'statistics-c4-chart',
        statisticsC4ViewBox,
        Offset(200, StatisticsC4Geometry.yOf(0)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(statisticsGoalActionLabel), findsOneWidget);
    await _tapKey(tester, 'statistics-evidence-primary');

    final workspace = tester.widget<PlanFlowWorkspace>(
      find.byType(PlanFlowWorkspace),
    );
    expect(workspace.flow.purpose, PlanFlowPurpose.editActivePlan);
    expect(workspace.flow.step, PlanFlowStep.goals);
    expect(workspace.flow.goalFocusStudentId, first.studentId);
    expect(workspace.flow.goalSeed?.studentId, first.studentId);
    expect(_inside('page-header-return-chip', '← 통계'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 1280x720 window shows the buttons, list and chip without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _StatisticsService(supply: true);
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'top-tab-statistics');
    await _tapBin(tester, 6);
    expect(tester.takeException(), isNull);
    await _tapKey(tester, 'statistics-topic-inventory');
    await _tapB1(tester, 0);
    await _tapKey(tester, 'statistics-evidence-rest');
    expect(tester.takeException(), isNull);
    await _tapKey(tester, 'statistics-topic-plan');
    await _tapTechNote(tester);
    expect(find.text('P2 선택 · 순서 바꾸기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tapKey(tester, 'statistics-evidence-secondary');
    expect(_inside('page-header-return-chip', '← 통계'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
