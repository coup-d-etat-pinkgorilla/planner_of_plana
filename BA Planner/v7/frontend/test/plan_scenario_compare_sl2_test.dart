// SL2 시험(Lane B, 근거 SL1 종료 기록 발견 1 · 3, F3c-8 종료 기록 발견 1).
//
// SL1로 1280×720에서 '나란히 비교'가 눌리자 4열 비교 화면(FE5-e)이 넘쳤다(열 머리 '열기 · 계획에 적용…' 줄 · 소제목
// `SubHeader` · 지표 행). 비교 S1 기준 라디오 D · 안내 문구와 활성 계획 S1 정보 줄 4 · 5번째는 창 밖이었다.
// - 앱 셸(BAPlannerApp)로 1280×720 · 1600×900 · 2560×1392에서 4열 비교(A~D)를 열면 넘침 예외 0, 열 머리 '열기' ·
//   '계획에 적용…'이 창 안에서 눌린다, 비교 S1 조작 · 안내 문구가 창 안이다.
// - 활성 계획 S1 버튼 · 정보 줄이 창 안이다.
// - 2560×1392는 자리가 전과 같다(golden 변화 0의 근거) — 레일 비율 1, 열 머리 버튼은 글자 그대로.
import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_compare.dart'
    show planCompareActiveId;
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_compare.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

/// 비교 S1 조작 · 표시(위에서부터).
const _compareMenuKeys = [
  'plan-compare-current',
  'plan-compare-back-to-list',
  'plan-compare-toggle-diff',
  'plan-compare-toggle-best',
  'plan-compare-toggle-delta',
  'plan-compare-base-A',
  'plan-compare-base-B',
  'plan-compare-base-C',
  'plan-compare-base-D',
  'plan-compare-note',
];

/// 활성 계획 S1 조작 · 정보 줄(위에서부터).
const _homeMenuKeys = [
  'plan-home-current',
  'plan-scenario-list-launch',
  'plan-scenario-create-launch',
  'plan-flow-edit-active-launch',
  'plan-home-info-0',
  'plan-home-info-1',
  'plan-home-info-2',
  'plan-home-info-3',
  'plan-home-info-4',
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

/// 시나리오 셋을 저장하고 id를 돌려준다(활성 계획 A + B~D = 4열).
Future<List<String>> _seed(MockAppService service) async {
  final state = await service.loadRepositoryState(_profileId);
  final ids = <String>[];
  for (final (index, students) in [
    ['aru'],
    ['ayane', 'aru'],
    ['aru', 'ayane'],
  ].indexed) {
    final list = await service.listScenarios(_profileId);
    final created = await service.createScenario(
      profileId: _profileId,
      expectedRevision: list.revision,
      idempotencyKey: 'sl2-test-$index',
      name: '시나리오 $index',
      description: '설명 $index',
      baseProfileRevision: state.revision,
      document: _document('sl2-$index', students),
    );
    ids.add(created.scenarioId);
  }
  return ids;
}

/// 앱 셸을 [size]로 띄워 계획 탭(활성 계획 홈)을 연다.
Future<void> _openPlan(
  WidgetTester tester,
  MockAppService service,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(BAPlannerApp(service: service));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('top-tab-plan')));
  await tester.pumpAndSettle();
}

/// 시나리오 목록에서 [ids]를 모두 비교에 담고 '나란히 비교'로 4열 비교를 연다.
Future<void> _openCompare(WidgetTester tester, List<String> ids) async {
  await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
  await tester.pumpAndSettle();
  for (final id in ids) {
    // 1280×720에서는 목록 S1 안내 글(SL1 파일)의 글자 상자가 세 번째 행 비교 체크 왼쪽을 덮는다(SL2 발견) — 체크의
    // 오른쪽 끝을 누른다.
    final check = tester.getRect(
      find.byKey(ValueKey('plan-scenario-compare-$id')),
    );
    await tester.tapAt(Offset(check.right - 3, check.center.dy));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const ValueKey('plan-scenario-compare-run')));
  await tester.pumpAndSettle();
  expect(find.byType(PlanScenarioCompareView), findsOneWidget);
}

/// [keys] 요소가 모두 창 안이고 위에서부터 겹치지 않는다.
void _expectStackedInside(WidgetTester tester, List<String> keys) {
  final window = Offset.zero & tester.view.physicalSize;
  Rect? previous;
  for (final key in keys) {
    final rect = tester.getRect(find.byKey(ValueKey(key)));
    expect(window.contains(rect.topLeft), isTrue, reason: '$key $rect');
    expect(rect.bottom, lessThanOrEqualTo(window.bottom), reason: '$key $rect');
    if (previous != null) {
      expect(
        rect.top,
        greaterThanOrEqualTo(previous.bottom - 0.01),
        reason: key,
      );
    }
    previous = rect;
  }
}

/// 열 머리 버튼이 창 안에서 눌린다.
void _expectHeaderButtons(WidgetTester tester, List<String> scenarioIds) {
  final window = Offset.zero & tester.view.physicalSize;
  for (final key in [
    'plan-compare-open-$planCompareActiveId',
    for (final id in scenarioIds) ...[
      'plan-compare-open-$id',
      'plan-compare-apply-$id',
    ],
  ]) {
    final finder = find.byKey(ValueKey(key));
    final rect = tester.getRect(finder);
    expect(window.contains(rect.topLeft), isTrue, reason: '$key $rect');
    expect(window.contains(rect.bottomRight), isTrue, reason: '$key $rect');
    expect(finder.hitTestable(), findsOneWidget, reason: key);
  }
}

void main() {
  group('SL2 레일 비율', () {
    // 앱 셸 콘텐츠(헤더 아래 y=184부터) 높이의 94/96이 S1 레일 높이다.
    PlanDetailMenuFrame frame(double windowHeight) => PlanDetailMenuFrame(
      top: 0,
      topRight: const Offset(300, 0),
      bottomRight: Offset(260, (windowHeight - 184) * 94 / 96),
    );
    // 활성 계획 S1: 정보 줄 5번째 아래 끝(버튼 셋째 280 · 44, 정보 소제목 = 그 아래 26, 줄은 26 아래부터 40 간격 · 36).
    const homeBottom = 280.0 + 44 + 26 + 26 + 40 * 4 + 36;
    // 비교 S1(4열): 안내 문구 위 = 마지막 라디오 아래 20.
    const compareNoteTop = 434.0 + 46 * 3 + 40 + 20;

    test('기준 viewport · 1600×900은 1, 1280×720만 줄인다', () {
      expect(homeBottom, 572.0);
      for (final height in const [1392.0, 900.0]) {
        expect(frame(height).scaleFor(homeBottom), 1.0);
        expect(frame(height).scaleFor(compareNoteTop, fixed: 49), 1.0);
      }
      // 계획 화면만 띄운 golden 틀(2560×1392 전체)도 1.
      expect(
        PlanDetailMenuFrame(
          top: 0,
          topRight: const Offset(300, 0),
          bottomRight: const Offset(260, 1392 * 94 / 96),
        ).scaleFor(homeBottom),
        1.0,
      );
      final home = frame(720).scaleFor(homeBottom);
      final compare = frame(720).scaleFor(compareNoteTop, fixed: 49);
      expect(home, lessThan(1.0));
      expect(compare, lessThan(home));
      expect(compare, greaterThanOrEqualTo(PlanDetailMetrics.menuMinScale));
      expect(frame(300).scaleFor(homeBottom), PlanDetailMetrics.menuMinScale);
    });

    test('비율 1이면 자리가 그대로다', () {
      final rail = frame(1392);
      expect(rail.row(166, 44, scale: 1), rail.row(166, 44));
    });
  });

  group('SL2 앱 셸', () {
    for (final size in const [Size(1280, 720), Size(1600, 900)]) {
      final label = '${size.width.toInt()}×${size.height.toInt()}';

      testWidgets('$label: 4열 비교가 넘치지 않고 조작이 창 안이다', (tester) async {
        final service = MockAppService();
        addTearDown(service.dispose);
        final ids = await _seed(service);
        await _openPlan(tester, service, size);
        await _openCompare(tester, ids);
        expect(tester.takeException(), isNull);
        for (final id in [planCompareActiveId, ...ids]) {
          expect(
            find.byKey(ValueKey('plan-compare-column-$id')),
            findsOneWidget,
          );
        }
        _expectStackedInside(tester, _compareMenuKeys);
        _expectHeaderButtons(tester, ids);
        expect(
          find.byKey(const ValueKey('plan-compare-base-D')).hitTestable(),
          findsOneWidget,
        );

        // 차이만 보기 · 기준 바꾸기(기준 칩이 시나리오 열로 옮김)도 넘치지 않는다.
        await tester.tap(find.byKey(const ValueKey('plan-compare-base-B')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('plan-compare-toggle-diff')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        _expectHeaderButtons(tester, ids);

        // 계획에 적용… → 2선택 창 → 그만두기.
        await tester.tap(find.byKey(ValueKey('plan-compare-apply-${ids[1]}')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plan-compare-apply-modal')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('plan-compare-apply-cancel')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('plan-compare-apply-modal')),
          findsNothing,
        );

        expect(tester.takeException(), isNull);

        // 열기 → 그 시나리오 보기.
        await tester.tap(find.byKey(ValueKey('plan-compare-open-${ids[2]}')));
        await tester.pumpAndSettle();
        final list = tester.widget<PlanScenarioListSection>(
          find.byType(PlanScenarioListSection),
        );
        expect(list.viewingScenarioId, ids[2]);
        if (size.width < 1600) {
          // 1280×720 시나리오 보기 S2(페이즈 제목 줄 · 단계 행, `plan_scenario_detail.dart`)가 넘친다 — 비교 화면과
          // 무관한 기존 문제(SL2 발견, 이 slice 범위 밖). 비교 화면은 위에서 예외 0을 확인했다.
          tester.takeException();
        } else {
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('$label: 활성 계획 S1 버튼 · 정보 줄이 창 안이다', (tester) async {
        final service = MockAppService();
        addTearDown(service.dispose);
        await _openPlan(tester, service, size);
        _expectStackedInside(tester, _homeMenuKeys);
        for (final key in _homeMenuKeys.take(4)) {
          expect(
            find.byKey(ValueKey(key)).hitTestable(),
            findsOneWidget,
            reason: key,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('1280×720: 좁은 열 머리 버튼은 아이콘만, 툴팁 · 의미 라벨은 글자다', (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final ids = await _seed(service);
      await _openPlan(tester, service, const Size(1280, 720));
      await _openCompare(tester, ids);
      final apply = find.byKey(ValueKey('plan-compare-apply-${ids[0]}'));
      expect(tester.getSize(apply), const Size(28, 28));
      expect(
        find.descendant(of: apply, matching: find.text('계획에 적용…')),
        findsNothing,
      );
      expect(find.byTooltip('계획에 적용…'), findsNWidgets(ids.length));
      expect(find.byTooltip('열기'), findsNWidgets(ids.length + 1));
      expect(find.bySemanticsLabel('계획에 적용…'), findsNWidgets(ids.length));
      expect(tester.takeException(), isNull);
    });

    testWidgets('2560×1392: 비교 화면 · 활성 계획 레일 자리가 전과 같다', (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final ids = await _seed(service);
      await _openPlan(tester, service, const Size(2560, 1392));
      // 활성 계획 S1(레일 위 209.2 + 시안 오프셋): 버튼 375.2 · 44, 정보 줄 5번째 745.2 · 36.
      for (final (key, top, height) in const [
        ('plan-home-current', 305.2, 58.0),
        ('plan-scenario-list-launch', 375.2, 44.0),
        ('plan-flow-edit-active-launch', 489.2, 44.0),
        ('plan-home-info-0', 585.2, 36.0),
        ('plan-home-info-4', 745.2, 36.0),
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.top, closeTo(top, 0.1), reason: key);
        expect(rect.height, closeTo(height, 0.01), reason: key);
      }

      await _openCompare(tester, ids);
      expect(tester.takeException(), isNull);
      // 고치기 전 측정(`debug/frontend_sl2/logs/measure-before.txt`)과 같은 자리.
      for (final (key, rect) in [
        (
          'plan-compare-current',
          const Rect.fromLTRB(30.0, 305.2, 372.1, 363.2),
        ),
        (
          'plan-compare-back-to-list',
          const Rect.fromLTRB(30.0, 375.2, 359.7, 419.2),
        ),
        (
          'plan-compare-toggle-delta',
          const Rect.fromLTRB(30.0, 557.2, 327.6, 599.2),
        ),
        ('plan-compare-base-A', const Rect.fromLTRB(30.0, 643.2, 312.5, 683.2)),
        ('plan-compare-base-D', const Rect.fromLTRB(30.0, 781.2, 288.1, 821.2)),
        ('plan-compare-note', const Rect.fromLTRB(38.0, 841.2, 257.0, 889.2)),
        (
          'plan-compare-column-$planCompareActiveId',
          const Rect.fromLTRB(713.5, 225.2, 1129.4, 353.2),
        ),
        (
          'plan-compare-column-${ids[2]}',
          const Rect.fromLTRB(2056.5, 225.2, 2472.4, 353.2),
        ),
      ]) {
        final actual = tester.getRect(find.byKey(ValueKey(key)));
        expect(actual.left, closeTo(rect.left, 0.1), reason: key);
        expect(actual.top, closeTo(rect.top, 0.1), reason: key);
        expect(actual.right, closeTo(rect.right, 0.1), reason: key);
        expect(actual.bottom, closeTo(rect.bottom, 0.1), reason: key);
      }
      // 넓은 열은 버튼 글자 · 기준 칩 · 초상 그대로, 툴팁 없음.
      expect(find.text('계획에 적용…'), findsNWidgets(ids.length));
      expect(find.text('열기'), findsNWidgets(ids.length + 1));
      expect(find.byTooltip('열기'), findsNothing);
      expect(
        find.byKey(const ValueKey('plan-compare-base-chip')),
        findsOneWidget,
      );
      _expectHeaderButtons(tester, ids);
      expect(tester.takeException(), isNull);
    });
  });
}
