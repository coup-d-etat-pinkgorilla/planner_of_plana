// tidy1 후속 테스트(Lane B).
//
// - ④ 시나리오 목록 1280×720 넘침(FE5-f1 발견 1): 좁은 창에서 목록(S1 비교 담기 · S2 필터 줄 · 행)을 열어도 RenderFlex
//   넘침이 없다. 기준 viewport에서는 글자를 줄이지 않는다.
// - ⑥ idempotency key(fb10b-dart 발견 4): 같은 화면의 연속 요청은 key 끝 순번이 달라 시계가 같아도 겹치지 않는다.
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_list.dart';
import 'package:ba_planner_v7/ui/widgets/repository_profile_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

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

/// 계정 쓰기 key를 모은다.
class _KeyRecordingService extends MockAppService {
  final keys = <String>[];

  @override
  Future<RepositoryProfile> createProfile(
    String displayName,
    String idempotencyKey, {
    String avatarStudentId = 'hasumi',
  }) {
    keys.add(idempotencyKey);
    return super.createProfile(
      displayName,
      idempotencyKey,
      avatarStudentId: avatarStudentId,
    );
  }

  @override
  Future<int> selectProfile(
    String profileId,
    int expectedRevision,
    String idempotencyKey,
  ) {
    keys.add(idempotencyKey);
    return super.selectProfile(profileId, expectedRevision, idempotencyKey);
  }
}

Future<void> _openList(
  WidgetTester tester,
  MockAppService service,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PlanningPage(service: service)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
  await tester.pumpAndSettle();
  expect(find.byType(PlanScenarioListSection), findsOneWidget);
}

Finder _inRun(String text) => find.descendant(
  of: find.byKey(const ValueKey('plan-scenario-compare-run')),
  matching: find.text(text),
);

Future<void> _seed(MockAppService service) async {
  final state = await service.loadRepositoryState(_profileId);
  for (final (index, students) in [
    ['aru'],
    ['ayane', 'aru'],
  ].indexed) {
    final list = await service.listScenarios(_profileId);
    await service.createScenario(
      profileId: _profileId,
      expectedRevision: list.revision,
      idempotencyKey: 'tidy1-test-$index',
      name: '시나리오 $index',
      description: '설명 $index',
      baseProfileRevision: state.revision,
      document: _document('tidy1-$index', students),
    );
  }
}

void main() {
  group('④ 시나리오 목록 좁은 창', () {
    testWidgets('1280×720에서 목록을 열어도 넘침이 없다(비교 버튼은 아이콘만)', (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await _seed(service);
      await _openList(tester, service, const Size(1280, 720));
      expect(_inRun('나란히 비교'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('plan-scenario-compare-run')),
          matching: find.byIcon(Icons.view_column_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-scenario-stale-count')),
        findsOneWidget,
      );
      expect(find.text('메인 · 지금 쓰는 계획'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('기준 viewport는 글자를 줄이지 않는다', (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await _seed(service);
      await _openList(tester, service, const Size(2560, 1392));
      expect(_inRun('나란히 비교'), findsOneWidget);
      expect(_inRun('1개'), findsOneWidget);
      for (final key in ['plan-scenario-stale-count']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.byKey(ValueKey(key)),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: key);
      }
      final chip = tester.renderObject<RenderParagraph>(
        find.text('메인 · 지금 쓰는 계획'),
      );
      expect(chip.didExceedMaxLines, isFalse);
      final label = tester.renderObject<RenderParagraph>(_inRun('나란히 비교'));
      expect(label.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('⑥ idempotency key 순번', () {
    testWidgets('프로필 패널: 만들기 · 고르기 key가 모두 다르고 끝에 순번이 붙는다', (tester) async {
      final service = _KeyRecordingService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RepositoryProfilePanel(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      for (final name in ['Second', 'Third']) {
        await tester.tap(find.byKey(const ValueKey('profile-create')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('profile-name-input')),
          name,
        );
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
      }
      expect(service.keys, hasLength(greaterThanOrEqualTo(2)));
      expect(service.keys.toSet(), hasLength(service.keys.length));
      final pattern = RegExp(r'^(create|select)-\d+-(\d+)$');
      final numbers = [
        for (final key in service.keys)
          int.parse(pattern.firstMatch(key)!.group(2)!),
      ];
      expect(numbers, [
        for (var index = 1; index <= numbers.length; index++) index,
      ]);
      expect(tester.takeException(), isNull);
    });
  });
}
