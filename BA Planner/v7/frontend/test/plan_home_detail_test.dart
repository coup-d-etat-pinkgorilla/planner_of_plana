// 계획 홈 = Detail 3섹션 테스트(FE5-c2, FD-082 (a) · FD-070 · FD-035).
//
// - Detail 위젯: seg를 켜면 페이즈별 · 전체 탭이 FE5-d 새 본문(페이즈 카드 · 전체 목록)으로 바뀌고, resourcePlaceholder가
//   있으면 S3에 안내만 보인다(활성 계획 홈이 쓰는 매개변수).
// - 계획 화면: 첫 화면이 비교 없는 Detail 홈이다(KPI · 활성 대비 칩 없음). S1은 시나리오 목록 · 계획 만들기 · 페이즈
//   편집 + 정보 줄이고, 옛 섹션 1 진입 버튼은 없다(FE5-f1에서 옛 홈 코드째 지웠다). S3 seg 페이즈별 · 전체는 FE5-d
//   새 위젯이다.
// - 계정 없음(FE5-f2, 사용자 결정 2026-10-12 21:45): 홈 S2 · S3에 인벤토리 방식 안내, S1은 꺼짐, 계산기에서 넘어온 학생은
//   SnackBar로 알린다. 계정을 고르면(앱 셸이 `plan-<profileGeneration>` 키로 다시 만든다) 정상 홈이다.
// - 계산 응답에 `overall`이 없으면 "계산 오류"다(FE5-f1 발견 3).
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart'
    show RepositoryPlanState;
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_list.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart'
    show planNoProfileHandoffMessage, planNoProfileMessage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _format(int value) => '$value';

Map<String, int?> _level(int value) => {
  for (final key in planningDocumentTargetKeys)
    key: key == 'level' ? value : null,
};

PlanningDocument _document(String id) => PlanningDocument(
  id: id,
  name: id,
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
          targets: _level(50),
        ),
      ],
    ),
  ],
  goalMetadata: const {
    'ayane': PlanningGoalMetadata(favorite: false, notes: ''),
  },
);

/// 활성 계획(아야네 1단계)을 저장한 mock.
Future<MockAppService> _seededService([MockAppService? base]) async {
  final service = base ?? MockAppService();
  addTearDown(service.dispose);
  final profile = (await service.listProfiles()).firstWhere(
    (profile) => profile.selected,
  );
  final initial = await service.loadRepositoryPlan(profile.id);
  await service.saveRepositoryPlan(
    profileId: profile.id,
    document: _document(initial.document.id),
    expectedRevision: initial.revision,
    idempotencyKey: 'fe5c2-home',
  );
  return service;
}

Future<void> _pumpHome(
  WidgetTester tester,
  MockAppService service, {
  Key? key,
  PlanningStudentSeed? seed,
}) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PlanningPage(
          key: key,
          service: service,
          initialSeed: seed,
          loadRepositoryPlan: true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 계획 화면의 계산 응답에서 `overall`을 뺀 mock(FE5-f1 발견 3). mock `plan.get`도 같은 계산으로 요약을 만들므로
/// 그 안에서는 빼지 않는다.
class _NoOverallService extends MockAppService {
  bool _loadingPlan = false;

  @override
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId) async {
    _loadingPlan = true;
    try {
      return await super.loadRepositoryPlan(profileId);
    } finally {
      _loadingPlan = false;
    }
  }

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    final projection = Map<String, dynamic>.of(
      await super.calculatePlanningDocument(
        currentStudents: currentStudents,
        inventory: inventory,
        document: document,
      ),
    );
    if (!_loadingPlan) projection.remove('overall');
    return projection;
  }
}

const _noProfileActions = [
  'plan-scenario-list-launch',
  'plan-scenario-create-launch',
  'plan-flow-edit-active-launch',
];

void _expectActions(WidgetTester tester, {required bool enabled}) {
  for (final key in _noProfileActions) {
    expect(
      tester.widget<RailButton>(find.byKey(ValueKey(key))).onPressed != null,
      enabled,
      reason: key,
    );
  }
}

Future<void> _tapTab(WidgetTester tester, String prefix, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey('$prefix-tab')),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Detail 위젯(활성 계획 홈 매개변수)', () {
    final data = PlanDetailData.fromProjection(
      document: _document('doc'),
      projection: const {},
      format: _format,
    );

    Future<void> pump(
      WidgetTester tester, {
      required PlanDetailResourceTab tab,
      required ValueChanged<PlanDetailResourceTab> onTab,
      Widget? resourcePlaceholder,
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
                keyPrefix: 'home',
                animation: const AlwaysStoppedAnimation(1),
                data: data,
                studentName: (id) => id,
                menuBuilder: (frame) => const SizedBox.shrink(),
                showComparison: false,
                resourceTab: tab,
                onResourceTab: onTab,
                resourcePlaceholder: resourcePlaceholder,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('seg가 켜지고 페이즈별 · 전체는 FE5-d 본문 · 요약 행으로 바뀐다', (tester) async {
      var tab = PlanDetailResourceTab.bottleneck;
      await pump(tester, tab: tab, onTab: (value) => tab = value);
      expect(find.byKey(const ValueKey('home-tab-later')), findsNothing);
      expect(find.byKey(const ValueKey('home-cards-empty')), findsOneWidget);
      await _tapTab(tester, 'home', '페이즈별');
      expect(tab, PlanDetailResourceTab.byPhase);

      // 이 데이터는 계산 응답이 비어 있어(projection {}) 페이즈 카드 대신 "계산하지 못했습니다"다.
      await pump(tester, tab: tab, onTab: (value) => tab = value);
      expect(
        find.byKey(const ValueKey('home-phase-cards-empty')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-summary-byPhase')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-cards-empty')), findsNothing);
      expect(find.byKey(const ValueKey('home-summary')), findsNothing);

      await pump(
        tester,
        tab: PlanDetailResourceTab.overall,
        onTab: (value) => tab = value,
      );
      expect(find.byKey(const ValueKey('home-overall-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-summary-overall')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('resourcePlaceholder가 있으면 S3에 안내만 보인다', (tester) async {
      await pump(
        tester,
        tab: PlanDetailResourceTab.overall,
        onTab: (_) {},
        resourcePlaceholder: const Text('계산 중', key: ValueKey('notice')),
      );
      expect(find.byKey(const ValueKey('notice')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-overall-list')), findsNothing);
      expect(find.byKey(const ValueKey('home-overall-header')), findsNothing);
      // 요약 행은 빈 행("—")이다.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-summary-overall-title')),
          matching: find.text('—'),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      // S2 단계 행은 그대로 보인다.
      expect(
        find.byKey(const ValueKey('home-stage-ayane-stage-1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('계획 화면 첫 화면(FE5-c2)', () {
    testWidgets('비교 없는 Detail 홈: S1 메뉴 · 정보 줄, 옛 진입 버튼 없음', (tester) async {
      final service = await _seededService();
      await _pumpHome(tester, service);

      expect(find.byKey(const ValueKey('plan-home-view')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-home-stage-ayane-stage-1')),
        findsOneWidget,
      );
      // 비교 KPI · 활성 대비 칩 · "활성 계획과 다른 단계"는 없다.
      expect(find.byKey(const ValueKey('plan-home-kpis')), findsNothing);
      expect(
        find.byKey(const ValueKey('plan-home-phase-different')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('plan-home-stage-ayane-stage-1-delta')),
        findsNothing,
      );
      for (final key in const [
        'plan-scenario-list-launch',
        'plan-scenario-create-launch',
        'plan-flow-edit-active-launch',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      for (final key in const [
        'plan-phase-editor-launch',
        'plan-student-selector-launch',
        'plan-preset-manager-launch',
        'plan-scenario-compare-launch',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('plan-home-info-0')),
          matching: find.text('1명'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('S3 seg 페이즈별 · 전체는 FE5-d 새 위젯이다', (tester) async {
      final service = await _seededService();
      await _pumpHome(tester, service);

      // mock 계산은 재화 줄이 없다: 페이즈 카드 · 전체 목록 대신 "필요한 재화가 없습니다".
      await _tapTab(tester, 'plan-home', '페이즈별');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('plan-home-phase-cards-empty')),
          matching: find.text('이 계획에 필요한 재화가 없습니다.'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-home-summary-byPhase')),
        findsOneWidget,
      );
      await _tapTab(tester, 'plan-home', '전체');
      expect(
        find.byKey(const ValueKey('plan-home-overall-header')),
        findsOneWidget,
      );
      expect(find.text('재화 0종'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-home-overall-empty')), findsOneWidget);
      // 칩 3개는 홈에서 누를 수 있다(옛 홈 필터 상태).
      expect(
        tester
            .widget<PopupMenuButton<int>>(
              find.byKey(const ValueKey('plan-home-filter-category')),
            )
            .enabled,
        isTrue,
      );
      await _tapTab(tester, 'plan-home', '병목');
      expect(find.byKey(const ValueKey('plan-home-summary')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('S1: 시나리오 목록 · 계획 만들기 · 페이즈 편집(흐름 3단계, FD-070)', (tester) async {
      final service = await _seededService();
      await _pumpHome(tester, service);

      await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioListSection), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan-scenario-menu-back')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioListSection), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('plan-flow-edit-active-launch')),
      );
      await tester.pumpAndSettle();
      final flow = tester
          .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
          .flow;
      expect(flow.purpose, PlanFlowPurpose.editActivePlan);
      expect(flow.step, PlanFlowStep.order);
      expect(tester.takeException(), isNull);
    });
  });

  group('계정 없음 빈 상태(FE5-f2)', () {
    testWidgets('S2 · S3 안내 문구, "읽는 중"에 머물지 않고 S1은 꺼진다', (tester) async {
      final service = MockAppService(profiles: const []);
      addTearDown(service.dispose);
      await _pumpHome(tester, service);

      expect(find.byKey(const ValueKey('plan-home-view')), findsOneWidget);
      // S2 · S3 두 자리 모두 같은 문구다.
      expect(
        find.byKey(const ValueKey('plan-home-no-profile')),
        findsNWidgets(2),
      );
      expect(
        find.text('선택된 계정이 없습니다. 설정에서 계정을 고르면 계획이 보입니다.'),
        findsNWidgets(2),
      );
      final notice = tester.widget<Text>(
        find.byKey(const ValueKey('plan-home-no-profile')).first,
      );
      expect(notice.style?.color, AppColors.textSecondary);
      expect(find.byKey(const ValueKey('plan-home-loading')), findsNothing);
      expect(find.byKey(const ValueKey('plan-home-not-loaded')), findsNothing);
      _expectActions(tester, enabled: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('계산기에서 넘어온 학생은 SnackBar로 알리고 흐름 · 요소 편집기를 열지 않는다', (
      tester,
    ) async {
      final service = MockAppService(profiles: const []);
      addTearDown(service.dispose);
      await _pumpHome(
        tester,
        service,
        seed: PlanningStudentSeed(
          handoffId: 'calculator-ayane',
          studentId: 'ayane',
          metadata: const {'student_id': 'ayane', 'display_name': '아야네'},
          currentValues: const {},
          owned: true,
        ),
      );

      expect(find.text(planNoProfileHandoffMessage), findsOneWidget);
      expect(find.text('계정을 먼저 골라야 계획에 추가할 수 있습니다.'), findsOneWidget);
      expect(find.byType(PlanFlowWorkspace), findsNothing);
      expect(
        find.byKey(const ValueKey('plan-element-builder-calculator-ayane')),
        findsNothing,
      );
      // 홈은 계정 없음 빈 상태로 돌아온다.
      expect(find.byKey(const ValueKey('plan-home-view')), findsOneWidget);
      expect(find.text(planNoProfileMessage), findsNWidgets(2));
      _expectActions(tester, enabled: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('계정을 고르면 다시 만든 계획 화면은 바로 정상 홈이다', (tester) async {
      final service = MockAppService(profiles: const []);
      addTearDown(service.dispose);
      await _pumpHome(tester, service, key: const ValueKey('plan-0'));
      expect(find.byKey(const ValueKey('plan-home-no-profile')), findsWidgets);

      final profile = await service.createProfile('새 계정', 'fe5f2-create');
      await service.selectProfile(profile.id, profile.revision, 'fe5f2-select');
      // 앱 셸은 계정이 바뀌면 `plan-<profileGeneration>` 키로 계획 화면을 새로 만든다.
      await _pumpHome(tester, service, key: const ValueKey('plan-1'));

      expect(find.byKey(const ValueKey('plan-home-no-profile')), findsNothing);
      expect(find.byKey(const ValueKey('plan-home-empty')), findsWidgets);
      _expectActions(tester, enabled: true);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('계산 응답에 overall이 없으면 계산 오류다(FE5-f1 발견 3)', (tester) async {
    final service = await _seededService(_NoOverallService());
    await _pumpHome(tester, service);

    expect(find.byKey(const ValueKey('plan-calculation-error')), findsWidgets);
    expect(find.textContaining('overall'), findsWidgets);
    // 문서 내용(S2 단계 행)은 그대로다.
    expect(
      find.byKey(const ValueKey('plan-home-stage-ayane-stage-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
