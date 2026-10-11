// 시나리오 나란히 비교 4열 테스트(FE5-e, 시안 Scenario-Compare, FD-034 · FD-038 · FD-085 · FD-086 · FD-092 · FD-093).
//
// - 모델: 열 값(크레딧 · 부족 종 수 · 첫 병목 · 끝까지 가는 학생 · 규모 · 분야별 부족 · 학생 목표)과 기준 대비(±, 같음 ·
//   다름 n · 신규 · 포함 안 됨), 최고 값 · 차이만 보기 판정, 쌍 캐시(같은 키는 한 번, 실패 다시 읽기, 버린 뒤 늦은 응답).
// - 화면: 목록에 셋 이상 담고 "나란히 비교" → 4열(기준 대비 N−1회 호출) → 기준 바꾸기(N−1회 더, 돌아오면 캐시) →
//   토글 → 빼기(둘 남으면 A↔B 2-pane) → 시나리오 목록(슬롯 유지).
import 'dart:async';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_compare.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_preview.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_compare.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart'
    show PlanScenarioComparisonSection, PlanScenarioListSection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

String _format(int value) => '$value';

Map<String, int?> _targets({int level = 80, int skill = 7, int bond = 1}) => {
  for (final key in planningDocumentTargetKeys) key: 0,
  'level': level,
  'bond_rank': bond,
  'student_star': 3,
  'ex_skill': 5,
  'skill1': skill,
  'skill2': skill,
  'skill3': skill,
  'equip1_tier': 9,
  'equip2_tier': 9,
  'equip3_tier': 9,
  'equip4_tier': 2,
};

/// [students] 한 페이즈 문서(학생마다 단계 하나).
PlanningDocument _doc(
  String id,
  Map<String, Map<String, int?>> students, {
  PlanningDocumentKind kind = PlanningDocumentKind.scenario,
}) => PlanningDocument(
  id: id,
  name: id,
  kind: kind,
  phases: [
    PlanningDocumentPhase(
      id: '$id-p1',
      name: '페이즈 1',
      stages: [
        for (final entry in students.entries)
          PlanningDocumentStage(
            id: '$id-${entry.key}',
            studentId: entry.key,
            name: '1단계',
            targets: entry.value,
          ),
      ],
    ),
  ],
);

Map<String, dynamic> _projection(
  PlanningDocument document, {
  List<Map<String, dynamic>> bottlenecks = const [],
}) => {
  'stage_results': [
    for (final stage in document.stages)
      {'stage_id': stage.id, 'student_id': stage.studentId},
  ],
  'overall': {'resources': const <dynamic>[]},
  'bottlenecks': bottlenecks,
};

Map<String, dynamic> _resource(
  String key,
  String category, {
  required int requiredA,
  required int requiredB,
  required int? shortageA,
  required int? shortageB,
}) => {
  'resource_key': key,
  'item_id': key,
  'display_name': key,
  'category': category,
  'required_a': requiredA,
  'required_b': requiredB,
  'shortage_a': shortageA,
  'shortage_b': shortageB,
};

void main() {
  group('모델', () {
    final active = _doc('active', {
      'aru': _targets(),
      'hoshino': _targets(skill: 10),
    }, kind: PlanningDocumentKind.plan);
    final b = _doc('b', {'aru': _targets(bond: 20), 'ayane': _targets()});
    final c = _doc('c', {'hoshino': _targets(skill: 10)});
    final targets = [
      PlanCompareTarget(id: planCompareActiveId, name: '활성 계획', document: active),
      PlanCompareTarget(id: 'b', name: 'B 계획', document: b, revision: 1),
      PlanCompareTarget(id: 'c', name: 'C 계획', document: c, revision: 1),
    ];
    final activeProjection = _projection(
      active,
      bottlenecks: [
        {
          'resource_key': 'eleph',
          'display_name': '아루의 엘레프',
          'phase_number': 1,
          'stage_id': 'active-aru',
          'shortage': 10,
        },
      ],
    );
    final pairs = {
      'b': PlanningScenarioComparisonResult(
        projectionA: activeProjection,
        projectionB: _projection(
          b,
          bottlenecks: [
            {
              'resource_key': 'eleph',
              'display_name': '아루의 엘레프',
              'phase_number': 1,
              'stage_id': 'b-aru',
              'shortage': 60,
            },
          ],
        ),
        comparison: {
          'credits_a': 300,
          'credits_b': 200,
          'known_shortage_type_count_a': 2,
          'known_shortage_type_count_b': 1,
          'resources': [
            _resource(
              'eleph',
              'student_eleph',
              requiredA: 100,
              requiredB: 150,
              shortageA: 10,
              shortageB: 60,
            ),
            _resource(
              'nebra',
              'oopart',
              requiredA: 50,
              requiredB: 20,
              shortageA: 5,
              shortageB: 0,
            ),
          ],
          'students': [
            {
              'student_id': 'aru',
              'presence': 'both',
              'target_differences': {
                'bond_rank': {'a': 1, 'b': 20},
              },
            },
            {
              'student_id': 'ayane',
              'presence': 'b_only',
              'target_differences': <String, dynamic>{},
            },
            {
              'student_id': 'hoshino',
              'presence': 'a_only',
              'target_differences': <String, dynamic>{},
            },
          ],
        },
      ),
      'c': PlanningScenarioComparisonResult(
        projectionA: activeProjection,
        projectionB: _projection(c),
        comparison: {
          'credits_a': 300,
          'credits_b': 300,
          'known_shortage_type_count_a': 2,
          'known_shortage_type_count_b': 0,
          'resources': [
            _resource(
              'eleph',
              'student_eleph',
              requiredA: 100,
              requiredB: 0,
              shortageA: 10,
              shortageB: 0,
            ),
            _resource(
              'nebra',
              'oopart',
              requiredA: 50,
              requiredB: 0,
              shortageA: 5,
              shortageB: 0,
            ),
          ],
          'students': [
            {
              'student_id': 'aru',
              'presence': 'a_only',
              'target_differences': <String, dynamic>{},
            },
            {
              'student_id': 'hoshino',
              'presence': 'both',
              'target_differences': <String, dynamic>{},
            },
          ],
        },
      ),
    };
    final table = PlanCompareTable.build(
      targets: targets,
      baseId: planCompareActiveId,
      pairs: pairs,
      format: _format,
    );
    PlanCompareColumn column(String id) =>
        table.columns.firstWhere((item) => item.target.id == id);

    test('열 값과 기준 대비(FD-038 크레딧 · 종 수 · 부족량)', () {
      expect(table.columns.map((item) => item.letter), ['A', 'B', 'C']);
      expect(table.base.target.id, planCompareActiveId);
      expect(column(planCompareActiveId).credits, 300);
      expect(column(planCompareActiveId).shortageKinds, 2);
      expect(
        column(planCompareActiveId).creditsDelta,
        const PlanScenarioDelta('기준과 같음', PlanScenarioDeltaTone.same),
      );
      expect(column('b').credits, 200);
      expect(
        column('b').creditsDelta,
        const PlanScenarioDelta('−100', PlanScenarioDeltaTone.better),
      );
      expect(
        column('b').shortageDelta,
        const PlanScenarioDelta('−1종', PlanScenarioDeltaTone.better),
      );
      expect(column('c').creditsDelta?.label, '기준과 같음');
      // 첫 병목: 가장 이른 페이즈 줄의 재화 · 부족량. 병목 목록이 비면 0(없음).
      expect(column('b').firstBottleneckPhase, 1);
      expect(column('b').firstBottleneck?.name, '아루의 엘레프');
      expect(column('b').firstBottleneck?.shortage, 60);
      expect(column('c').firstBottleneckPhase, 0);
      // 끝까지 가는 학생(FD-034 (a)): 병목 단계의 학생은 막힌다.
      expect(column('b').finishing, 1);
      expect(column('b').studentTotal, 2);
      expect(column('c').finishing, 1);
      expect(column('c').studentTotal, 1);
      expect(column('b').scale, (students: 2, phases: 1, stages: 2));
      // 부족 재화(기준 대비 칩은 부족량 차이, 기준 열은 칩 없음).
      final eleph = column('b').fieldShortages(PlanScenarioResourceField.eleph);
      expect(eleph.single.shortage, 60);
      expect(eleph.single.delta?.label, '+50');
      expect(eleph.single.location?.studentId, 'aru');
      expect(
        column(planCompareActiveId)
            .fieldShortages(PlanScenarioResourceField.eleph)
            .single
            .delta,
        isNull,
      );
      expect(column('b').baseOnlyShortageKinds, 1);
      expect(
        column('c').knownFields,
        contains(PlanScenarioResourceField.ooparts),
      );
      expect(column('c').shortages, isEmpty);
    });

    test('학생 칸: 같음 · 다름 n · 신규 · 포함 안 됨, 칩 값과 분홍 칩', () {
      expect(table.studentIds, ['aru', 'hoshino', 'ayane']);
      final aru = column('b').students['aru']!;
      expect(aru.mark, PlanCompareStudentMark.differs);
      expect(aru.markLabel, '다름 1');
      expect(aru.differs(PlanCompareTargetChip.bond), isTrue);
      expect(aru.differs(PlanCompareTargetChip.level), isFalse);
      expect(column('b').students['ayane']!.markLabel, '신규');
      expect(column('b').students['hoshino']!.markLabel, '포함 안 됨');
      expect(column('b').students['hoshino']!.included, isFalse);
      expect(column('c').students['hoshino']!.markLabel, '같음');
      // 기준 열: 있는 학생은 표시 없음, 없는 학생은 "포함 안 됨".
      expect(column(planCompareActiveId).students['aru']!.markLabel, isNull);
      expect(
        column(planCompareActiveId).students['ayane']!.markLabel,
        '포함 안 됨',
      );
      final values = _targets(skill: 10);
      expect(PlanCompareTargetChip.level.value(values), '80');
      // 최대값은 M(EX 5 · 스킬 10, FE5-b 목표 요약과 같은 규칙).
      expect(PlanCompareTargetChip.skills.value(values), 'M·M·M·M');
      expect(PlanCompareTargetChip.skills.value(_targets()), 'M·7·7·7');
      expect(PlanCompareTargetChip.tiers.value(values), '9·9·9·2');
      expect(PlanCompareTargetChip.weapon.value(values), '—');
      expect(PlanCompareTargetChip.bond.value(_targets(bond: 20)), '20');
    });

    test('최고 값 · 차이만 보기 판정', () {
      const credits = PlanCompareMetricRow(PlanCompareMetric.credits);
      const shortage = PlanCompareMetricRow(PlanCompareMetric.shortage);
      const bottleneck = PlanCompareMetricRow(PlanCompareMetric.bottleneck);
      const scale = PlanCompareMetricRow(PlanCompareMetric.scale);
      expect(table.best(credits), {'b'});
      expect(table.best(shortage), {'c'});
      // 병목 없음(0)이 가장 좋다.
      expect(table.best(bottleneck), {'c'});
      expect(table.best(scale), isEmpty);
      expect(
        table.best(const PlanCompareFieldRow(PlanScenarioResourceField.ooparts)),
        {'b', 'c'},
      );
      expect(table.isSame(credits), isFalse);
      expect(table.isSame(const PlanCompareStudentRow('aru')), isFalse);
      // 모든 열이 같으면 칠하지 않는다.
      final same = PlanCompareTable.build(
        targets: [targets[0], targets[2]],
        baseId: planCompareActiveId,
        pairs: {'c': pairs['c']!},
        format: _format,
      );
      expect(same.isSame(credits), isTrue);
      expect(same.best(credits), isEmpty);
      expect(same.isSame(const PlanCompareStudentRow('hoshino')), isTrue);
    });

    test('기준을 바꾸면 그 기준 대비로 다시 계산한다', () {
      final rebased = PlanCompareTable.build(
        targets: targets,
        baseId: 'b',
        pairs: {
          planCompareActiveId: PlanningScenarioComparisonResult(
            projectionA: pairs['b']!.projectionB,
            projectionB: activeProjection,
            comparison: {'credits_a': 200, 'credits_b': 300},
          ),
          'c': PlanningScenarioComparisonResult(
            projectionA: pairs['b']!.projectionB,
            projectionB: pairs['c']!.projectionB,
            comparison: {'credits_a': 200, 'credits_b': 300},
          ),
        },
        format: _format,
      );
      expect(rebased.base.target.id, 'b');
      expect(rebased.base.credits, 200);
      expect(
        rebased.columns.first.creditsDelta,
        const PlanScenarioDelta('+100', PlanScenarioDeltaTone.worse),
      );
      // 응답에 없는 값은 모른다(0으로 채우지 않는다).
      expect(rebased.base.shortageKinds, isNull);
      expect(rebased.columns.first.shortageDelta, isNull);
    });

    test('쌍 캐시: 같은 키는 한 번, 실패는 다시 읽기, 버린 뒤 늦은 응답은 넣지 않는다', () async {
      final completers = <PlanComparePairKey, Completer<PlanningScenarioComparisonResult>>{};
      final loader = PlanComparePairLoader(
        fetch: (key) => (completers[key] = Completer()).future,
      );
      addTearDown(loader.dispose);
      PlanComparePairKey key(String column, {int profile = 3}) => (
        baseId: planCompareActiveId,
        baseRevision: 1,
        columnId: column,
        columnRevision: 2,
        profileRevision: profile,
      );
      const empty = PlanningScenarioComparisonResult(
        projectionA: {},
        projectionB: {},
        comparison: {},
      );
      loader.request([key('b'), key('c')]);
      loader.request([key('b')]);
      expect(loader.fetchCount, 2);
      expect(loader.status([key('b'), key('c')]), PlanComparePairStatus.loading);
      completers[key('b')]!.complete(empty);
      completers[key('c')]!.completeError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(loader.result(key('b')), same(empty));
      expect(loader.status([key('b'), key('c')]), PlanComparePairStatus.failed);
      loader.retry([key('c')]);
      expect(loader.fetchCount, 3);
      completers[key('c')]!.complete(empty);
      await Future<void>.delayed(Duration.zero);
      expect(loader.status([key('b'), key('c')]), PlanComparePairStatus.ready);
      // 프로필 revision이 다르면 다른 키다.
      loader.request([key('b', profile: 4)]);
      expect(loader.fetchCount, 4);
      loader.invalidate();
      completers[key('b', profile: 4)]!.complete(empty);
      await Future<void>.delayed(Duration.zero);
      expect(loader.result(key('b', profile: 4)), isNull);
      expect(loader.result(key('b')), isNull);
    });
  });

  group('화면', () {
    testWidgets(
      '셋 이상 담으면 4열 비교: N−1회 호출 · 기준 바꾸기 · 캐시 · 토글 · 빼면 A↔B · 목록 슬롯 유지',
      (tester) async {
        final service = _CountingService();
        addTearDown(service.dispose);
        final ids = await _seed(service, {
          '하나': ['aru'],
          '둘': ['ayane'],
          '셋': ['aru', 'ayane'],
        });
        await _pumpPlanning(tester, service);
        for (final name in const ['하나', '둘', '셋']) {
          await tester.tap(
            find.byKey(ValueKey('plan-scenario-compare-${ids[name]}')),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('4 / 4'), findsOneWidget);
        service.calls = 0;
        await tester.tap(find.byKey(const ValueKey('plan-scenario-compare-run')));
        await tester.pumpAndSettle();

        expect(find.byType(PlanScenarioCompareView), findsOneWidget);
        expect(find.byType(PlanScenarioListSection), findsNothing);
        expect(find.byType(PlanScenarioComparisonSection), findsNothing);
        // FD-092: 기준(활성 계획) 대비 나머지 세 열 = 3회.
        expect(service.calls, 3);
        for (final id in [planCompareActiveId, ...ids.values]) {
          expect(
            find.byKey(ValueKey('plan-compare-column-$id')),
            findsOneWidget,
          );
          expect(
            find.byKey(ValueKey('plan-compare-cell-$id-credits')),
            findsOneWidget,
          );
        }
        expect(find.text('나란히 비교 · 4개'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey('plan-compare-column-$planCompareActiveId'),
            ),
            matching: find.byKey(const ValueKey('plan-compare-base-chip')),
          ),
          findsOneWidget,
        );
        // 열 B(하나 = 단계 1개)의 크레딧은 활성 계획과 다르다(대역: 단계 수 × 1,000).
        expect(
          find.byKey(ValueKey('plan-compare-delta-${ids['하나']}-credits')),
          findsOneWidget,
        );

        // 기준을 B로: 새 기준 대비 3회 더. A로 돌아오면 캐시라 부르지 않는다.
        await tester.tap(find.byKey(const ValueKey('plan-compare-base-B')));
        await tester.pumpAndSettle();
        expect(service.calls, 6);
        expect(find.text('기준 B · 하나'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(ValueKey('plan-compare-column-${ids['하나']}')),
            matching: find.byKey(const ValueKey('plan-compare-base-chip')),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('plan-compare-base-A')));
        await tester.pumpAndSettle();
        expect(service.calls, 6);

        // ± 표시를 끄면 크레딧 차이가 사라진다.
        await tester.tap(find.byKey(const ValueKey('plan-compare-toggle-delta')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('plan-compare-delta-${ids['하나']}-credits')),
          findsNothing,
        );

        // 셋에서 하나를 빼면 3열(호출 없음), 하나 더 빼면 A↔B 상세 비교로 바뀐다.
        await tester.tap(find.byKey(ValueKey('plan-compare-remove-${ids['셋']}')));
        await tester.pumpAndSettle();
        expect(find.byType(PlanScenarioCompareView), findsOneWidget);
        expect(find.byKey(ValueKey('plan-compare-column-${ids['셋']}')), findsNothing);
        expect(find.text('나란히 비교 · 3개'), findsOneWidget);
        expect(service.calls, 6);
        await tester.tap(find.byKey(ValueKey('plan-compare-remove-${ids['둘']}')));
        await tester.pumpAndSettle();
        expect(find.byType(PlanScenarioCompareView), findsNothing);
        expect(find.byType(PlanScenarioComparisonSection), findsOneWidget);

        // 목록으로 돌아가면 뺀 시나리오가 슬롯에서도 빠져 있다(활성 계획 + 하나).
        await tester.tap(
          find.byKey(const ValueKey('plan-comparison-back-to-list')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PlanScenarioListSection), findsOneWidget);
        expect(find.text('2 / 4'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('열 헤더 "열기"는 그 시나리오 보기 모드, 시나리오 목록은 슬롯을 그대로 둔다', (
      tester,
    ) async {
      final service = _CountingService();
      addTearDown(service.dispose);
      final ids = await _seed(service, {
        '하나': ['aru'],
        '둘': ['ayane'],
      });
      await _pumpPlanning(tester, service);
      for (final name in const ['하나', '둘']) {
        await tester.tap(
          find.byKey(ValueKey('plan-scenario-compare-${ids[name]}')),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('plan-scenario-compare-run')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioCompareView), findsOneWidget);
      expect(service.calls, 2);

      await tester.tap(find.byKey(const ValueKey('plan-compare-back-to-list')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioListSection), findsOneWidget);
      expect(find.text('3 / 4'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('plan-scenario-compare-run')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('plan-compare-open-${ids['둘']}')));
      await tester.pumpAndSettle();
      final list = tester.widget<PlanScenarioListSection>(
        find.byType(PlanScenarioListSection),
      );
      expect(list.viewingScenarioId, ids['둘']);
      expect(tester.takeException(), isNull);
    });
  });
}

/// 비교 호출 수를 세고, 대역 값(단계 수 × 1,000 크레딧, 단계 수 = 부족 종 수)을 붙이는 mock.
class _CountingService extends MockAppService {
  int calls = 0;

  @override
  Future<PlanningScenarioComparisonResult> compareScenarios({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required PlanningDocument documentA,
    required PlanningDocument documentB,
  }) async {
    calls += 1;
    final base = await super.compareScenarios(
      currentStudents: currentStudents,
      inventory: inventory,
      documentA: documentA,
      documentB: documentB,
    );
    return PlanningScenarioComparisonResult(
      projectionA: base.projectionA,
      projectionB: base.projectionB,
      comparison: {
        ...base.comparison,
        'credits_a': documentA.stages.length * 1000,
        'credits_b': documentB.stages.length * 1000,
        'known_shortage_type_count_a': documentA.stages.length,
        'known_shortage_type_count_b': documentB.stages.length,
      },
    );
  }
}

/// 선택 계정에 시나리오를 만든다(학생마다 Lv.80 단계 하나). 이름 → id.
Future<Map<String, String>> _seed(
  MockAppService service,
  Map<String, List<String>> scenarios,
) async {
  final state = await service.loadRepositoryState(_profileId);
  final ids = <String, String>{};
  for (final (index, entry) in scenarios.entries.indexed) {
    final list = await service.listScenarios(_profileId);
    final created = await service.createScenario(
      profileId: _profileId,
      expectedRevision: list.revision,
      idempotencyKey: 'fe5e-test-$index',
      name: entry.key,
      description: '',
      baseProfileRevision: state.revision,
      document: _doc('fe5e-$index', {
        // v1 성장 규칙을 지킨다(장비 2칸은 Lv.10, T2 애장품은 인연 20 필요).
        for (final student in entry.value)
          student: _targets(level: 80, bond: 20),
      }),
    );
    ids[entry.key] = created.scenarioId;
  }
  return ids;
}

/// 계획 화면(새 홈, 저장된 활성 계획을 읽음)을 열고 시나리오 목록을 연다.
Future<void> _pumpPlanning(WidgetTester tester, MockAppService service) async {
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
}
