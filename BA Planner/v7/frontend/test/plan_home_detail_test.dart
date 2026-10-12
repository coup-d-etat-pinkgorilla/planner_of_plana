// 계획 홈 = Detail 3섹션 테스트(FE5-c2, FD-082 (a) · FD-070 · FD-035).
//
// - Detail 위젯: seg를 켜면 페이즈별 · 전체 탭이 FE5-d 새 본문(페이즈 카드 · 전체 목록)으로 바뀌고, resourcePlaceholder가
//   있으면 S3에 안내만 보인다(활성 계획 홈이 쓰는 매개변수).
// - 계획 화면: 첫 화면이 비교 없는 Detail 홈이다(KPI · 활성 대비 칩 없음). S1은 시나리오 목록 · 계획 만들기 · 페이즈
//   편집 + 정보 줄이고, 옛 섹션 1 진입 버튼은 없다(FE5-f1에서 옛 홈 코드째 지웠다). S3 seg 페이즈별 · 전체는 FE5-d
//   새 위젯이다.
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_list.dart';
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
Future<MockAppService> _seededService() async {
  final service = MockAppService();
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

Future<void> _pumpHome(WidgetTester tester, MockAppService service) async {
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
}
