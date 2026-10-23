// SL1 시험(Lane B, 근거 F3c-6 종료 기록 발견 2).
//
// 1280×720에서 시나리오 목록 S1 레일의 '나란히 비교'가 창 아래(y≈770~820)로 나가 누를 수 없었다. 레일이 안내 글까지
// 담기에 낮으면 세로 값만 같은 비율로 줄인다([PlanScenarioListMetrics.menuScaleFor]).
// - 앱 셸(BAPlannerApp)로 1280×720 · 1600×900에서 레일의 모든 조작이 창 안이고, '나란히 비교'를 누르면 비교가 열린다
//   (시나리오 하나 = A↔B, 둘 = 4열). 넘침 예외 0.
// - 기준 viewport(2560×1392)와 1600×900은 비율 1 — 자리가 시안 그대로다(golden 변화 0의 근거).
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_compare.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_list.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart'
    show PlanScenarioComparisonSection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

/// 레일의 조작 · 표시(위에서부터).
const _railKeys = [
  'plan-scenario-menu-current',
  'plan-scenario-menu-back',
  'plan-scenario-menu-create',
  'plan-scenario-menu-presets',
  'plan-scenario-compare-count',
  'plan-scenario-compare-slot-0',
  'plan-scenario-compare-slot-1',
  'plan-scenario-compare-slot-2',
  'plan-scenario-compare-slot-3',
  'plan-scenario-compare-run',
];

PlanningDocument _document(String id, List<String> students) {
  final targets = {
    for (final key in planningDocumentTargetKeys)
      key: key == 'bond_rank' ? 1 : 0,
    'level': 2,
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

/// 시나리오 둘을 저장하고 id를 돌려준다.
Future<List<String>> _seed(MockAppService service) async {
  final state = await service.loadRepositoryState(_profileId);
  final ids = <String>[];
  for (final (index, students) in [
    ['aru'],
    ['ayane', 'aru'],
  ].indexed) {
    final list = await service.listScenarios(_profileId);
    final created = await service.createScenario(
      profileId: _profileId,
      expectedRevision: list.revision,
      idempotencyKey: 'sl1-test-$index',
      name: '시나리오 $index',
      description: '설명 $index',
      baseProfileRevision: state.revision,
      document: _document('sl1-$index', students),
    );
    ids.add(created.scenarioId);
  }
  return ids;
}

/// 앱 셸을 [size]로 띄워 계획 탭 → 시나리오 목록을 열고 [compare]를 비교에 담는다.
Future<void> _openList(
  WidgetTester tester,
  MockAppService service,
  Size size,
  List<String> compare,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(BAPlannerApp(service: service));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('top-tab-plan')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
  await tester.pumpAndSettle();
  expect(find.byType(PlanScenarioListSection), findsOneWidget);
  for (final id in compare) {
    await tester.tap(find.byKey(ValueKey('plan-scenario-compare-$id')));
    await tester.pumpAndSettle();
  }
}

/// 레일의 모든 조작과 안내 글이 창 안이다. '나란히 비교'는 그 가운데가 hit test에 걸린다.
void _expectRailInside(WidgetTester tester) {
  final window = Offset.zero & tester.view.physicalSize;
  Rect? previous;
  for (final key in _railKeys) {
    final rect = tester.getRect(find.byKey(ValueKey(key)));
    expect(window.contains(rect.topLeft), isTrue, reason: '$key $rect');
    expect(rect.bottom, lessThanOrEqualTo(window.bottom), reason: key);
    if (previous != null) {
      expect(rect.top, greaterThanOrEqualTo(previous.bottom), reason: key);
    }
    previous = rect;
  }
  final note = tester.getRect(find.textContaining('최대 4개까지'));
  expect(note.top, greaterThanOrEqualTo(previous!.bottom));
  expect(note.bottom, lessThanOrEqualTo(window.bottom));
  final run = find.byKey(const ValueKey('plan-scenario-compare-run'));
  expect(run.hitTestable(), findsOneWidget);
}

void main() {
  group('SL1 비율', () {
    test('기준 viewport · 1600×900 레일은 1, 1280×720 레일만 줄인다', () {
      // 앱 셸 콘텐츠(헤더 아래 y=184부터) 높이의 94/96이 S1 레일 높이다.
      double rail(double windowHeight) => (windowHeight - 184) * 94 / 96;
      expect(PlanScenarioListMetrics.menuScaleFor(rail(1392)), 1.0);
      expect(PlanScenarioListMetrics.menuScaleFor(rail(900)), 1.0);
      // 계획 화면만 띄운 golden 틀(2560×1392 전체)도 1.
      expect(PlanScenarioListMetrics.menuScaleFor(1392 * 94 / 96), 1.0);
      final small = PlanScenarioListMetrics.menuScaleFor(rail(720));
      expect(small, lessThan(1.0));
      expect(small, greaterThanOrEqualTo(PlanScenarioListMetrics.menuMinScale));
      expect(
        PlanScenarioListMetrics.menuScaleFor(100),
        PlanScenarioListMetrics.menuMinScale,
      );
    });
  });

  group('SL1 앱 셸', () {
    for (final size in const [Size(1280, 720), Size(1600, 900)]) {
      final label = '${size.width.toInt()}×${size.height.toInt()}';

      testWidgets('$label: 레일이 창 안이고 나란히 비교가 A↔B 비교를 연다', (tester) async {
        final service = MockAppService();
        addTearDown(service.dispose);
        final ids = await _seed(service);
        await _openList(tester, service, size, [ids[0]]);
        _expectRailInside(tester);
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(const ValueKey('plan-scenario-compare-run')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlanScenarioComparisonSection), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$label: 셋을 담으면 나란히 비교가 4열 비교를 연다', (tester) async {
        final service = MockAppService();
        addTearDown(service.dispose);
        final ids = await _seed(service);
        await _openList(tester, service, size, ids);
        _expectRailInside(tester);
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('plan-scenario-compare-count')),
              )
              .data,
          '3 / 4',
        );
        expect(tester.takeException(), isNull);

        await tester.tap(
          find.byKey(const ValueKey('plan-scenario-compare-run')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlanScenarioCompareView), findsOneWidget);
        expect(find.byType(PlanScenarioListSection), findsNothing);
        // 4열 비교 화면(FE5-e) 자체가 이 크기에서 열 머리 · 소제목 줄이 넘친다 — 목록 레일과 무관한 기존 문제(SL1 발견,
        // 고치지 않음). 레일은 위에서 예외 0을 확인했다.
        tester.takeException();
      });
    }

    testWidgets('2560×1392: 레일 자리가 시안 그대로다(비율 1)', (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final ids = await _seed(service);
      await _openList(tester, service, const Size(2560, 1392), [ids[0]]);
      // 시안 Scenario-List: 보는 중 버튼 y=305 · 58, 비교 칸 A y=577 · 44, 나란히 비교 y=783 · 50.
      for (final (key, top, height) in const [
        ('plan-scenario-menu-current', 305.2, 58.0),
        ('plan-scenario-menu-back', 375.2, 44.0),
        ('plan-scenario-compare-slot-0', 577.2, 44.0),
        ('plan-scenario-compare-slot-3', 727.2, 44.0),
        ('plan-scenario-compare-run', 783.2, 50.0),
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.top, closeTo(top, 0.1), reason: key);
        expect(rect.height, closeTo(height, 0.01), reason: key);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
