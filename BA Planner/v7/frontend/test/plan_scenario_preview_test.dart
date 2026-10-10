// 시나리오 미리보기 테스트(FE5-b, 시안 Scenario-List S3, FD-089 · FD-090).
//
// - 모델: compare 응답 → KPI(모르는 값 null) · 학생 차이 칩 4종 · 부족 재화(큰 순) · 분야 다섯 줄 · 병목 위치 · 분야별 묶음.
// - 캐시 · 늦은 응답: 같은 키는 한 번만 부르고, 다른 행을 고른 사이 늦게 온 응답은 지금 행을 덮지 않는다.
// - S3 층: KPI · 학생 · 분야 행, 부족 재화 팝오버(키트 `GroupedShortageFlyout`), 열기 · 계획에 적용 꺼짐.
// - 계획 화면: 행을 고르면 getScenario + compare 한 번, 접었다 다시 펼치면 캐시(부르지 않음).
import 'dart:async';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/kit/shortage_flyout.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_preview.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_list.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

/// v1 목표(스킬 2 · 3을 올리려면 ★3이 필요하다).
Map<String, int?> _targets({
  int level = 80,
  int star = 3,
  int bond = 1,
  int tier = 0,
}) => {
  for (final key in planningDocumentTargetKeys) key: 0,
  'level': level,
  'student_star': star,
  'bond_rank': bond,
  'ex_skill': 3,
  'skill1': 7,
  'skill2': 7,
  'skill3': 7,
  'equip1_tier': tier,
  'equip2_tier': tier,
  'equip3_tier': tier,
};

/// 시나리오 문서: P1 아루 · 아야네, P2 아루(2단계).
PlanningDocument _scenarioDocument(String id) => PlanningDocument(
  id: id,
  name: id,
  kind: PlanningDocumentKind.scenario,
  phases: [
    PlanningDocumentPhase(
      id: '$id-p1',
      name: '페이즈 1',
      stages: [
        PlanningDocumentStage(
          id: '$id-aru-1',
          studentId: 'aru',
          name: '1단계',
          targets: _targets(),
        ),
        PlanningDocumentStage(
          id: '$id-ayane-1',
          studentId: 'ayane',
          name: '1단계',
          targets: _targets(),
        ),
      ],
    ),
    PlanningDocumentPhase(
      id: '$id-p2',
      name: '페이즈 2',
      stages: [
        PlanningDocumentStage(
          id: '$id-aru-2',
          studentId: 'aru',
          name: '2단계',
          targets: _targets(level: 90, tier: 9),
        ),
      ],
    ),
  ],
);

PlanningScenarioRecord _record(String id) => PlanningScenarioRecord(
  id: id,
  revision: 1,
  profileId: _profileId,
  name: '시나리오 $id',
  description: '',
  baseProfileRevision: 3,
  document: _scenarioDocument('doc-$id'),
  createdAt: '2026-09-01T00:00:00',
  updatedAt: '2026-09-22T23:10:00',
);

Map<String, dynamic> _resource(
  String key,
  String category, {
  int? shortageA,
  int? shortageB,
  int requiredA = 10,
}) => {
  'resource_key': key,
  'item_id': key,
  'display_name': '$key 이름',
  'category': category,
  'owned': shortageA == null ? null : 5,
  'required_a': requiredA,
  'required_b': 10,
  'shortage_a': shortageA,
  'shortage_b': shortageB,
};

/// 시안 미리보기를 닮은 compare 응답.
PlanningScenarioComparisonResult _comparison({String scenarioId = 's1'}) =>
    PlanningScenarioComparisonResult(
      projectionA: {
        'bottlenecks': [
          {'resource_key': 'neb', 'phase_number': 2, 'stage_id': 'a-x'},
        ],
      },
      projectionB: {
        'bottlenecks': [
          {
            'resource_key': 'neb',
            'phase_number': 1,
            'stage_id': 'doc-$scenarioId-aru-1',
          },
        ],
      },
      comparison: {
        'credits_a': 186200000,
        'credits_b': 112800000,
        'known_shortage_type_count_a': 14,
        'known_shortage_type_count_b': 8,
        'students': [
          {
            'student_id': 'aru',
            'presence': 'b_only',
            'target_differences': <String, dynamic>{},
          },
          {
            'student_id': 'ayane',
            'presence': 'both',
            'target_differences': {
              'student_star': {'a': 3, 'b': 1},
              'bond_rank': {'a': 20, 'b': 1},
            },
          },
          {
            'student_id': 'hina',
            'presence': 'a_only',
            'target_differences': <String, dynamic>{},
          },
        ],
        'resources': [
          _resource('eleph', 'student_eleph', shortageA: 0, shortageB: 449, requiredA: 0),
          _resource('neb', 'oopart', shortageA: 20, shortageB: 14),
          _resource('pha', 'oopart', shortageA: 3, shortageB: 3),
          _resource('note', 'tech_notes', shortageA: 18, shortageB: 30),
          _resource('watch', 'equipment', shortageA: 0, shortageB: 0),
          _resource('only-a', 'equipment', shortageA: 4, shortageB: 0),
          _resource('unknown', 'activity_report'),
          _resource('credits', 'credits', shortageA: 0, shortageB: 0),
        ],
      },
    );

PlanScenarioPreview _preview({String id = 's1'}) =>
    PlanScenarioPreview.fromComparison(
      scenario: _record(id),
      result: _comparison(scenarioId: id),
      format: planScenarioPreviewAmount,
    );

void main() {
  group('미리보기 모델', () {
    test('KPI · 학생 차이 · 부족 재화 · 분야 다섯 줄 · 병목 위치', () {
      final preview = _preview();
      expect(preview.credits.a, 186200000);
      expect(preview.credits.b, 112800000);
      expect(preview.shortageKinds.a, 14);
      expect(preview.shortageKinds.b, 8);
      expect(preview.firstBottleneck.a, 2);
      expect(preview.firstBottleneck.b, 1);

      // 시나리오 문서 학생만(처음 나온 순서). 활성 계획에만 있는 히나는 없다.
      expect(preview.students.map((student) => student.studentId), [
        'aru',
        'ayane',
      ]);
      final aru = preview.students.first;
      expect(aru.stages, [(phase: 1, name: '1단계'), (phase: 2, name: '2단계')]);
      expect(aru.finalTargets['level'], 90);
      expect(
        aru.delta,
        const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only),
      );
      expect(
        preview.students[1].delta,
        const PlanScenarioDelta('활성보다 낮은 목표', PlanScenarioDeltaTone.better),
      );

      // 부족(b > 0)만, 큰 순. 보유를 모르는 재화는 빠진다.
      expect(preview.shortages.map((item) => item.resourceKey), [
        'eleph',
        'note',
        'neb',
        'pha',
      ]);
      final eleph = preview.shortages.first;
      expect(
        eleph.delta,
        const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only),
      );
      final neb = preview.shortages.firstWhere((item) => item.resourceKey == 'neb');
      expect(neb.delta, const PlanScenarioDelta('−6', PlanScenarioDeltaTone.better));
      expect(neb.location, (phase: 1, studentId: 'aru', step: 1));
      final note = preview.shortages.firstWhere(
        (item) => item.resourceKey == 'note',
      );
      expect(note.delta, const PlanScenarioDelta('+12', PlanScenarioDeltaTone.worse));
      expect(note.location, isNull);
      expect(
        preview.shortages.firstWhere((item) => item.resourceKey == 'pha').delta,
        const PlanScenarioDelta('활성 계획과 같음', PlanScenarioDeltaTone.same),
      );
      expect(preview.activeOnlyShortageKinds, 1);

      // 분야 다섯 줄: 장비는 부족 없음(보유를 앎), 크레딧은 충분.
      expect(
        preview.fields.map((row) => row.field),
        PlanScenarioResourceField.shown,
      );
      final byField = {for (final row in preview.fields) row.field: row};
      expect(byField[PlanScenarioResourceField.eleph]!.top?.resourceKey, 'eleph');
      expect(byField[PlanScenarioResourceField.ooparts]!.top?.resourceKey, 'neb');
      expect(byField[PlanScenarioResourceField.notes]!.top?.resourceKey, 'note');
      expect(byField[PlanScenarioResourceField.equipment]!.top, isNull);
      expect(byField[PlanScenarioResourceField.equipment]!.known, isTrue);
      expect(byField[PlanScenarioResourceField.credits]!.top, isNull);
      expect(byField[PlanScenarioResourceField.credits]!.known, isTrue);

      // 팝오버 묶음: 분야 순서, 분야 안 큰 순.
      expect(
        preview.shortageGroups.map((group) => group.$1),
        [
          PlanScenarioResourceField.eleph,
          PlanScenarioResourceField.ooparts,
          PlanScenarioResourceField.notes,
        ],
      );
      expect(
        preview.shortageGroups[1].$2.map((item) => item.resourceKey),
        ['neb', 'pha'],
      );
    });

    test('응답에 값이 없으면 모름(null)이고 0으로 채우지 않는다', () {
      final preview = PlanScenarioPreview.fromComparison(
        scenario: _record('s2'),
        result: const PlanningScenarioComparisonResult(
          projectionA: {},
          projectionB: {'bottlenecks': <dynamic>[]},
          comparison: {},
        ),
        format: planScenarioPreviewAmount,
      );
      expect(preview.credits.a, isNull);
      expect(preview.credits.b, isNull);
      expect(preview.shortageKinds.b, isNull);
      expect(preview.firstBottleneck.a, isNull);
      expect(preview.firstBottleneck.b, 0);
      expect(preview.shortages, isEmpty);
      expect(preview.fields.every((row) => row.top == null && !row.known), isTrue);
      // 학생 줄은 문서에서 나오고, compare에 없으면 칩이 없다.
      expect(preview.students.every((student) => student.delta == null), isTrue);
      expect(planScenarioBottleneckValue(null), '—');
      expect(planScenarioBottleneckValue(0), '없음');
      expect(planScenarioBottleneckValue(2), 'P2');
    });

    test('칩 규칙과 목표 요약', () {
      expect(
        planScenarioStudentDelta(presence: 'both', differences: const {}),
        const PlanScenarioDelta('활성 계획과 같음', PlanScenarioDeltaTone.same),
      );
      expect(
        planScenarioStudentDelta(
          presence: 'both',
          differences: const {
            'level': (a: 80, b: 90),
            'skill1': (a: null, b: 7),
          },
        ),
        const PlanScenarioDelta('목표 다름 2', PlanScenarioDeltaTone.differs),
      );
      expect(
        planScenarioShortageDelta(
          shortageA: null,
          shortageB: 3,
          requiredA: 5,
          format: planScenarioPreviewAmount,
        ),
        isNull,
      );
      expect(
        planScenarioShortageDelta(
          shortageA: 20000,
          shortageB: 5000,
          requiredA: 30000,
          format: planScenarioPreviewAmount,
        ),
        const PlanScenarioDelta('−15K', PlanScenarioDeltaTone.better),
      );
      expect(
        planScenarioTargetSummary(_targets(level: 90, tier: 9)),
        'Lv.90 · ★3 · 스킬 3/7/7/7 · T9',
      );
      expect(
        planScenarioTargetSummary({
          for (final key in planningDocumentTargetKeys) key: null,
          'ex_skill': 5,
          'bond_rank': 20,
        }),
        'EX M · 인연 20',
      );
      expect(
        planScenarioTargetSummary({
          for (final key in planningDocumentTargetKeys) key: null,
        }),
        '정한 목표 없음',
      );
    });
  });

  group('캐시 · 늦은 응답(FD-089)', () {
    PlanScenarioPreviewKey key(String id, {int revision = 1}) => (
      scenarioId: id,
      scenarioRevision: revision,
      activeRevision: 4,
      profileRevision: 3,
    );

    test('같은 키는 한 번만 부르고, 늦게 온 이전 응답은 지금 행을 덮지 않는다', () async {
      final pending = <String, Completer<PlanScenarioPreview>>{};
      final loader = PlanScenarioPreviewLoader(
        fetch: (key) =>
            (pending[key.scenarioId] = Completer<PlanScenarioPreview>()).future,
      );
      addTearDown(loader.dispose);
      var notified = 0;
      loader.addListener(() => notified += 1);

      loader.select(key('s1'));
      expect(loader.status, PlanScenarioPreviewStatus.loading);
      loader.select(key('s2'));
      expect(loader.fetchCount, 2);

      // s1이 늦게 온다: 지금 고른 s2는 여전히 읽는 중이다.
      final before = notified;
      pending['s1']!.complete(_preview(id: 's1'));
      await Future<void>.delayed(Duration.zero);
      expect(loader.current, key('s2'));
      expect(loader.status, PlanScenarioPreviewStatus.loading);
      expect(loader.preview, isNull);
      expect(notified, before);

      pending['s2']!.complete(_preview(id: 's2'));
      await Future<void>.delayed(Duration.zero);
      expect(loader.status, PlanScenarioPreviewStatus.ready);
      expect(loader.preview!.scenario.id, 's2');

      // s1로 돌아가면 캐시를 쓴다(부르지 않음).
      loader.select(key('s1'));
      expect(loader.status, PlanScenarioPreviewStatus.ready);
      expect(loader.preview!.scenario.id, 's1');
      loader.select(key('s2'));
      expect(loader.fetchCount, 2);

      // revision이 바뀌면 다른 키다.
      loader.select(key('s2', revision: 2));
      expect(loader.fetchCount, 3);
      expect(loader.status, PlanScenarioPreviewStatus.loading);

      loader.select(null);
      expect(loader.status, PlanScenarioPreviewStatus.none);
    });

    test('활성 계획 문서가 바뀌면 캐시를 버리고, 그 전에 보낸 응답은 넣지 않는다', () async {
      final pending = <Completer<PlanScenarioPreview>>[];
      final loader = PlanScenarioPreviewLoader(
        fetch: (key) {
          final completer = Completer<PlanScenarioPreview>();
          pending.add(completer);
          return completer.future;
        },
      );
      addTearDown(loader.dispose);
      loader.select(key('s1'));
      loader.invalidate();
      expect(loader.fetchCount, 2);
      pending.first.complete(_preview(id: 'old'));
      await Future<void>.delayed(Duration.zero);
      expect(loader.status, PlanScenarioPreviewStatus.loading);
      pending.last.complete(_preview(id: 's1'));
      await Future<void>.delayed(Duration.zero);
      expect(loader.preview!.scenario.id, 's1');
    });

    test('실패는 그 키에 남고 다시 읽기로 한 번 더 부른다', () async {
      var calls = 0;
      final loader = PlanScenarioPreviewLoader(
        fetch: (key) async {
          calls += 1;
          if (calls == 1) throw StateError('repository_busy');
          return _preview(id: key.scenarioId);
        },
      );
      addTearDown(loader.dispose);
      loader.select(key('s1'));
      await Future<void>.delayed(Duration.zero);
      expect(loader.status, PlanScenarioPreviewStatus.failed);
      expect(loader.error, isA<StateError>());
      loader.retry();
      expect(loader.status, PlanScenarioPreviewStatus.loading);
      await Future<void>.delayed(Duration.zero);
      expect(loader.status, PlanScenarioPreviewStatus.ready);
      expect(calls, 2);
    });
  });

  group('S3 층', () {
    Future<void> pumpLayer(
      WidgetTester tester, {
      PlanScenarioPreview? preview,
      PlanScenarioPreviewStatus status = PlanScenarioPreviewStatus.ready,
      bool compared = false,
      VoidCallback? onToggleCompare,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final record = _record('s1');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: PlanScenarioPreviewLayer(
                    leftAt: (y) => 220 - y * 0.1763,
                    top: 0,
                    right: 1360,
                    selected: PlanningScenarioSummary(
                      id: record.id,
                      revision: record.revision,
                      name: record.name,
                      description: '설명',
                      baseProfileRevision: 3,
                      phaseCount: 2,
                      stageCount: 3,
                      studentCount: 2,
                      studentIds: const ['aru', 'ayane'],
                      calculation: null,
                      createdAt: record.createdAt,
                      updatedAt: record.updatedAt,
                    ),
                    status: status,
                    preview: preview,
                    error: status == PlanScenarioPreviewStatus.failed
                        ? StateError('repository_busy')
                        : null,
                    comparable: true,
                    compared: compared,
                    studentName: (id) => id == 'aru' ? '아루' : id,
                    onToggleCompare: onToggleCompare,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('KPI · 학생 · 분야 행과 부족 재화 팝오버', (tester) async {
      var toggled = 0;
      await pumpLayer(
        tester,
        preview: _preview(),
        onToggleCompare: () => toggled += 1,
      );
      String plain(String key) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data ?? '')
          .join(' ');
      expect(plain('plan-scenario-preview-kpi-credits'), contains('186.2M'));
      expect(plain('plan-scenario-preview-kpi-credits'), contains('112.8M'));
      expect(plain('plan-scenario-preview-kpi-shortage'), contains('14종'));
      expect(plain('plan-scenario-preview-kpi-shortage'), contains('8종'));
      expect(plain('plan-scenario-preview-kpi-bottleneck'), contains('P2'));
      expect(plain('plan-scenario-preview-kpi-bottleneck'), contains('P1'));
      expect(
        find.byKey(const ValueKey('plan-scenario-preview-student-aru')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('plan-scenario-preview-student-aru-targets'),
              ),
            )
            .data,
        'Lv.90 · ★3 · 스킬 3/7/7/7 · T9',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('plan-scenario-preview-field-ooparts-amount'),
              ),
            )
            .data,
        '−14',
      );
      expect(find.text('P1 아루 1단계'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('plan-scenario-preview-field-credits-amount'),
              ),
            )
            .data,
        '충분',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('plan-scenario-preview-field-equipment-amount'),
              ),
            )
            .data,
        '부족 없음',
      );

      // 열기 · 계획에 적용은 꺼져 있고 비교에 담기만 동작한다.
      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-preview-compare-toggle')),
      );
      await tester.tap(find.byKey(const ValueKey('plan-scenario-preview-open')));
      await tester.tap(find.byKey(const ValueKey('plan-scenario-preview-apply')));
      await tester.pump();
      expect(toggled, 1);
      expect(find.text('비교에 담기'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-preview-kpi-shortage')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GroupedShortageRow), findsNWidgets(4));
      expect(find.text('부족 재화 4종'), findsOneWidget);
      expect(find.text('활성 계획 14종 · 활성 계획에만 부족 1종'), findsOneWidget);
      // 엘레프는 분야 행과 팝오버 행에 함께 보인다.
      expect(
        find.descendant(
          of: find.byType(GroupedShortageRow),
          matching: find.text('−449'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('읽는 중 · 실패', (tester) async {
      await pumpLayer(tester, status: PlanScenarioPreviewStatus.loading);
      expect(
        find.byKey(const ValueKey('plan-scenario-preview-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-scenario-preview-kpi-credits')),
        findsNothing,
      );
      await pumpLayer(tester, status: PlanScenarioPreviewStatus.failed);
      expect(find.textContaining('repository_busy'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-scenario-preview-retry')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('계획 화면: 행을 고르면 getScenario + compare 한 번, 다시 고르면 캐시', (
    tester,
  ) async {
    final service = _CountingMockAppService();
    addTearDown(service.dispose);
    final state = await service.loadRepositoryState(_profileId);
    final created = await service.createScenario(
      profileId: _profileId,
      expectedRevision: 0,
      idempotencyKey: 'fe5b-preview',
      name: '미리보기 후보',
      description: '',
      baseProfileRevision: state.revision,
      document: _scenarioDocument('fe5b-preview-doc'),
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
    expect(find.byType(PlanScenarioListSection), findsOneWidget);
    expect(service.compareCalls, 0);

    await tester.tap(find.byKey(ValueKey('plan-scenario-row-$id')));
    await tester.pumpAndSettle();
    expect(service.compareCalls, 1);
    expect(service.getCalls, 1);
    expect(
      find.byKey(const ValueKey('plan-scenario-preview-kpi-credits')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-scenario-preview-student-aru')),
      findsOneWidget,
    );

    // 접었다 다시 펼친다: 같은 키라 다시 부르지 않는다.
    await tester.tap(find.byKey(ValueKey('plan-scenario-row-$id')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan-scenario-preview-kpi-credits')),
      findsNothing,
    );
    await tester.tap(find.byKey(ValueKey('plan-scenario-row-$id')));
    await tester.pumpAndSettle();
    expect(service.compareCalls, 1);
    expect(
      find.byKey(const ValueKey('plan-scenario-preview-kpi-credits')),
      findsOneWidget,
    );

    // S3 "비교에 담기"는 행 액션과 같다.
    await tester.tap(
      find.byKey(const ValueKey('plan-scenario-preview-compare-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// getScenario · compare 호출 수를 센다.
class _CountingMockAppService extends MockAppService {
  int getCalls = 0;
  int compareCalls = 0;

  @override
  Future<PlanningScenarioGetResult> getScenario(
    String profileId,
    String scenarioId,
  ) {
    getCalls += 1;
    return super.getScenario(profileId, scenarioId);
  }

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
