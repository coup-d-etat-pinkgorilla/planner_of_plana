// Detail S3 페이즈별 · 전체 탭 테스트(FE5-d, 시안 Scenario-Detail-Phase · -All, FD-031 (a) · FD-037 · FD-038).
//
// - 모델: 페이즈 진입/필요/종료(종료 = max(0, 진입 − 필요), FD-037), 충족률 내림 %, 전체 확보율(FD-031 (a)) · 영향
//   학생, 페이즈별 요약 행(처음 모자라는 페이즈 · 충족률이 가장 낮은 재화 · 완료 가능 학생 · 뒤 페이즈 단계), 활성 대비
//   (재화 줄 단위 FD-038 (c), 활성 계획에 없는 재화 = 이 시나리오에만, 요약 칩 "활성보다 +n 부족", 활성 확보율).
// - 위젯: 페이즈 카드 ↔ S2 페이즈 헤더 · 단계 강조, 전체 타일 ↔ S2 단계 강조(다시 누르면 해제), "한 행에" 열 수,
//   칩(재화 유형 · 충족 재화 숨기기), 비교가 있을 때 범례 · 마크 · 칩.
import 'package:ba_planner_v7/ui/kit/diagonal_row.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_preview.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart'
    show PlanResourceCategory;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _format(int value) => '$value';

const _notes = 'Item_Icon_SkillBook_Gehenna_3';
const _eleph = 'Item_Icon_SecretStone_aru';

Map<String, int?> _targets() => {
  for (final key in planningDocumentTargetKeys) key: null,
  'level': 80,
};

/// P1 아야네 1단계(y1), P2 아루 1단계(a1).
PlanningDocument _document() => PlanningDocument(
  id: 'scenario',
  name: 'scenario',
  kind: PlanningDocumentKind.scenario,
  phases: [
    PlanningDocumentPhase(
      id: 'p1',
      name: '리오 먼저',
      stages: [
        PlanningDocumentStage(
          id: 'y1',
          studentId: 'ayane',
          name: '1단계',
          targets: _targets(),
        ),
      ],
    ),
    PlanningDocumentPhase(
      id: 'p2',
      name: '스킬 마무리',
      stages: [
        PlanningDocumentStage(
          id: 'a1',
          studentId: 'aru',
          name: '1단계',
          targets: _targets(),
        ),
      ],
    ),
  ],
);

Map<String, dynamic> _row(
  String key,
  String category,
  int required,
  int? owned, {
  List<String> affected = const [],
}) => {
  'resource_key': key,
  'item_id': key == 'credits' ? null : key,
  'display_name': key == 'credits' ? '크레딧' : key,
  'category': category,
  'required': required,
  'owned': owned,
  'shortage': owned == null ? null : (required - owned).clamp(0, required),
  'affected_stage_ids': affected,
};

/// 백엔드 모양 projection: P1 진입 노트 12 / 필요 42(30 부족), 크레딧 5000 / 1000. P2 진입 노트 0 / 30, 엘레프 200 /
/// 120. 전체 노트 12 / 72(y1 · a1), 엘레프 200 / 120, 크레딧 5000 / 1000. 병목 = 노트, y1.
Map<String, dynamic> _projection() => {
  'stage_results': [
    {
      'stage_id': 'y1',
      'phase_id': 'p1',
      'student_id': 'ayane',
      'resources': [
        {
          'resource_key': 'credits',
          'category': 'credits',
          'required': 1000,
          'owned_at_entry': 5000,
          'shortage_at_entry': 0,
        },
        {
          'resource_key': _notes,
          'item_id': _notes,
          'category': 'tech_notes',
          'required': 42,
          'owned_at_entry': 12,
          'shortage_at_entry': 30,
        },
      ],
    },
    {
      'stage_id': 'a1',
      'phase_id': 'p2',
      'student_id': 'aru',
      'resources': [
        {
          'resource_key': _notes,
          'item_id': _notes,
          'category': 'tech_notes',
          'required': 30,
          'owned_at_entry': 0,
          'shortage_at_entry': 30,
        },
        {
          'resource_key': _eleph,
          'item_id': _eleph,
          'category': 'student_eleph',
          'required': 120,
          'owned_at_entry': 200,
          'shortage_at_entry': 0,
        },
      ],
    },
  ],
  'phase_results': [
    {
      'phase_id': 'p1',
      'name': '리오 먼저',
      'stage_ids': ['y1'],
      'resources': [
        _row('credits', 'credits', 1000, 5000, affected: ['y1']),
        _row(_notes, 'tech_notes', 42, 12, affected: ['y1']),
      ],
    },
    {
      'phase_id': 'p2',
      'name': '스킬 마무리',
      'stage_ids': ['a1'],
      'resources': [
        _row(_notes, 'tech_notes', 30, 0, affected: ['a1']),
        _row(_eleph, 'student_eleph', 120, 200, affected: ['a1']),
      ],
    },
  ],
  'overall': {
    'cost': {'credits': 1000},
    'resources': [
      _row('credits', 'credits', 1000, 5000, affected: ['y1']),
      _row(_notes, 'tech_notes', 72, 12, affected: ['y1', 'a1']),
      _row(_eleph, 'student_eleph', 120, 200, affected: ['a1']),
    ],
  },
  'bottlenecks': [
    {
      'resource_key': _notes,
      'item_id': _notes,
      'display_name': _notes,
      'category': 'tech_notes',
      'remaining_at_entry': 12,
      'required_at_entry': 42,
      'shortage': 30,
      'phase_id': 'p1',
      'phase_number': 1,
      'stage_id': 'y1',
      'student_id': 'ayane',
      'student_step': 1,
      'stage_name': '1단계',
      'affected_stage_ids': ['y1', 'a1'],
    },
  ],
};

/// 비교 줄: 노트 활성 50(부족 38) → 72(부족 60), 엘레프 활성 0 → 120, 크레딧 3000 → 1000.
const _comparison = <String, dynamic>{
  'credits_a': 3000,
  'credits_b': 1000,
  'known_shortage_type_count_a': 1,
  'known_shortage_type_count_b': 1,
  'resources': [
    {
      'resource_key': 'credits',
      'category': 'credits',
      'owned': 5000,
      'required_a': 3000,
      'required_b': 1000,
      'shortage_a': 0,
      'shortage_b': 0,
    },
    {
      'resource_key': _notes,
      'category': 'tech_notes',
      'owned': 12,
      'required_a': 50,
      'required_b': 72,
      'shortage_a': 38,
      'shortage_b': 60,
    },
    {
      'resource_key': _eleph,
      'category': 'student_eleph',
      'owned': 200,
      'required_a': 0,
      'required_b': 120,
      'shortage_a': 0,
      'shortage_b': 0,
    },
  ],
  'bottlenecks': [],
};

PlanDetailData _data({bool comparison = false}) => PlanDetailData.fromProjection(
  document: _document(),
  projection: _projection(),
  format: _format,
  comparison: comparison
      ? PlanDetailComparison(
          active: PlanningDocument(
            id: 'active-plan',
            name: '활성 계획',
            kind: PlanningDocumentKind.plan,
            phases: const [],
          ),
          projectionA: const {'stage_results': [], 'bottlenecks': []},
          comparison: _comparison,
        )
      : null,
);

void main() {
  group('모델', () {
    test('페이즈 진입/필요/종료와 충족률(FD-037)', () {
      final data = _data();
      expect(data.phaseResources.map((phase) => phase.number), [1, 2]);
      final p1 = data.phaseResources.first;
      expect(p1.studentIds, ['ayane']);
      final credits = p1.credits!;
      expect((credits.owned, credits.required, credits.exit), (5000, 1000, 4000));
      final notes = p1.tiles.single;
      expect((notes.owned, notes.required, notes.exit), (12, 42, 0));
      expect(notes.percent, 28);
      expect(notes.shortage, 30);
      expect(p1.shortageKinds, 1);
      final p2 = data.phaseResources.last;
      expect(p2.credits, isNull);
      expect(p2.tiles.map((tile) => tile.percent), [0, 100]);
      expect(p2.tiles.last.exit, 80);
      expect(p2.shortageKinds, 1);
    });

    test('전체 확보율(FD-031 (a)) · 영향 학생', () {
      final overall = _data().overall!;
      expect(overall.credits?.resourceKey, 'credits');
      expect(overall.tiles.map((tile) => tile.resourceKey), [_notes, _eleph]);
      // (1 + 12/72 + 1) / 3.
      expect(overall.rate, closeTo((1 + 12 / 72 + 1) / 3, 1e-9));
      expect(overall.shortageKinds, 1);
      expect(overall.unknownKinds, 0);
      expect((overall.affectedStudents, overall.totalStudents), (2, 2));
      expect(overall.activeRate, isNull);
    });

    test('페이즈별 요약 행: P1 노트, 1명 중 0명, 뒤 페이즈 단계 1개', () {
      final summary = _data().phaseSummary!;
      expect(summary.tile.resourceKey, _notes);
      expect(summary.phase, 1);
      expect((summary.students, summary.completable), (1, 0));
      expect(summary.laterStages, 1);
      expect(summary.delta, isNull);
    });

    test('활성 대비: 재화 줄 단위 · 이 시나리오에만 · 요약 칩 · 활성 확보율', () {
      final data = _data(comparison: true);
      final notes = data.phaseResources.first.tiles.single;
      expect(
        notes.delta,
        const PlanScenarioDelta('+22', PlanScenarioDeltaTone.worse),
      );
      expect(
        data.phaseResources.last.tiles.last.delta,
        const PlanScenarioDelta('이 시나리오에만', PlanScenarioDeltaTone.only),
      );
      expect(
        data.phaseSummary!.delta,
        const PlanScenarioDelta('활성보다 +22 부족', PlanScenarioDeltaTone.worse),
      );
      expect(
        data.overall!.credits!.delta,
        const PlanScenarioDelta('−2000', PlanScenarioDeltaTone.better),
      );
      // 활성: 크레딧 1, 노트 12/50 → (1 + 0.24) / 2. 엘레프는 활성 필요 0이라 뺀다.
      expect(data.overall!.activeRate, closeTo(0.62, 1e-9));
    });
  });

  group('위젯', () {
    Future<void> pump(
      WidgetTester tester, {
      required PlanDetailResourceTab tab,
      PlanDetailData? data,
      bool showComparison = false,
      PlanDetailResourceFilter filter = const PlanDetailResourceFilter(),
      ValueChanged<PlanDetailResourceFilter>? onFilter,
      int? selectedPhase,
      ValueChanged<int>? onSelectPhase,
      String? selectedResource,
      ValueChanged<String?>? onSelectResource,
      ValueChanged<int>? onColumns,
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
                keyPrefix: 'detail',
                animation: const AlwaysStoppedAnimation(1),
                data: data ?? _data(),
                studentName: (id) => id,
                menuBuilder: (frame) => const SizedBox.shrink(),
                showComparison: showComparison,
                resourceTab: tab,
                onResourceTab: (_) {},
                filter: filter,
                onFilter: onFilter,
                selectedPhase: selectedPhase,
                onSelectPhase: onSelectPhase,
                selectedResource: selectedResource,
                onSelectResource: onSelectResource,
                onOverallColumns: onColumns,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    DiagonalRowMark mark(WidgetTester tester, String key) => tester
        .widget<DiagonalRow>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(DiagonalRow),
            matchRoot: true,
          ),
        )
        .mark;

    testWidgets('페이즈별: 카드 · 타일 값, 카드 ↔ S2 페이즈 강조', (tester) async {
      int? selected = 1;
      Future<void> rebuild() => pump(
        tester,
        tab: PlanDetailResourceTab.byPhase,
        selectedPhase: selected,
        onSelectPhase: (number) => selected = number,
      );
      await rebuild();
      expect(find.byKey(const ValueKey('detail-phase-card-2')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('detail-phase-card-1-credits')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('detail-phase-card-1-resource-$_notes-amounts'),
          ),
          matching: find.text('진입 12 · 필요 42 · 종료 0'),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('detail-phase-card-1-resource-$_notes-coverage'),
          ),
          matching: find.text('28%'),
        ),
        findsOneWidget,
      );
      expect(mark(tester, 'detail-phase-card-1'), DiagonalRowMark.selected);
      expect(mark(tester, 'detail-phase-1'), DiagonalRowMark.selected);
      expect(mark(tester, 'detail-stage-y1'), DiagonalRowMark.selected);
      expect(mark(tester, 'detail-stage-a1'), DiagonalRowMark.none);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-summary-byPhase-detail')),
          matching: find.text('P1 종료 시 0개 남아서 뒤 페이즈 단계 1개가 막힙니다'),
          matchRoot: true,
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('detail-phase-card-2')));
      expect(selected, 2);
      await rebuild();
      expect(mark(tester, 'detail-stage-a1'), DiagonalRowMark.selected);
      expect(mark(tester, 'detail-stage-y1'), DiagonalRowMark.none);
      await tester.tap(find.byKey(const ValueKey('detail-stage-y1')));
      expect(selected, 1);
      // 비교가 없으면 타일 칩 · 요약 칩이 없다.
      expect(
        find.byKey(const ValueKey('detail-phase-card-1-resource-$_notes-delta')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('detail-summary-byPhase-delta')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('전체: 크레딧 행 · 분야 그룹, 타일 ↔ S2 단계 강조, 열 수', (tester) async {
      String? selected;
      int? columns;
      Future<void> rebuild() => pump(
        tester,
        tab: PlanDetailResourceTab.overall,
        selectedResource: selected,
        onSelectResource: (key) => selected = key,
        onColumns: (value) => columns = value,
      );
      await rebuild();
      expect(find.byKey(const ValueKey('detail-overall-credits')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('detail-overall-group-notes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('detail-overall-group-eleph')),
        findsOneWidget,
      );
      expect(find.text('재화 2종'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-overall-tile-$_notes-amounts')),
          matching: find.text('12 / 72'),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-summary-overall-title')),
          matching: find.text('필요량의 72% 확보 · 1종 부족 · 2명 중 2명의 계획에 영향'),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('detail-overall-legend')), findsNothing);
      expect(
        find.byKey(const ValueKey('detail-overall-tile-$_notes-mark')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('detail-overall-tile-$_notes')));
      expect(selected, _notes);
      await rebuild();
      expect(mark(tester, 'detail-stage-y1'), DiagonalRowMark.selected);
      expect(mark(tester, 'detail-stage-a1'), DiagonalRowMark.selected);
      await tester.tap(find.byKey(const ValueKey('detail-overall-tile-$_notes')));
      expect(selected, isNull);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('detail-overall-columns')),
          matching: find.text('2'),
        ),
      );
      expect(columns, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('칩: 재화 유형 · 충족 재화 숨기기가 전체 타일을 거른다', (tester) async {
      PlanDetailResourceFilter? changed;
      await pump(
        tester,
        tab: PlanDetailResourceTab.overall,
        onFilter: (value) => changed = value,
      );
      await tester.tap(find.byKey(const ValueKey('detail-hide-satisfied')));
      expect(changed?.hideSatisfied, isTrue);

      // 숨기기: 크레딧 · 엘레프(충분)는 빠지고 노트만 남는다.
      await pump(
        tester,
        tab: PlanDetailResourceTab.overall,
        filter: const PlanDetailResourceFilter(hideSatisfied: true),
        onFilter: (value) => changed = value,
      );
      expect(find.byKey(const ValueKey('detail-overall-credits')), findsNothing);
      expect(
        find.byKey(const ValueKey('detail-overall-group-eleph')),
        findsNothing,
      );
      expect(find.text('재화 1종'), findsOneWidget);

      // 재화 유형 = 크레딧만: 크레딧 행만 남는다.
      await pump(
        tester,
        tab: PlanDetailResourceTab.overall,
        filter: const PlanDetailResourceFilter(
          categories: {PlanResourceCategory.credits},
        ),
        onFilter: (value) => changed = value,
      );
      expect(find.byKey(const ValueKey('detail-overall-credits')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-overall-group-notes')), findsNothing);
      expect(find.text('재화 0종'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('비교: 범례 · 마크(±n · 신규) · 활성 대비 칩', (tester) async {
      await pump(
        tester,
        tab: PlanDetailResourceTab.overall,
        data: _data(comparison: true),
        showComparison: true,
      );
      expect(find.byKey(const ValueKey('detail-overall-legend')), findsOneWidget);
      for (final (key, label) in const [(_notes, '+22'), (_eleph, '신규')]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('detail-overall-tile-$key-mark')),
            matching: find.text(label),
            matchRoot: true,
          ),
          findsOneWidget,
          reason: key,
        );
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-overall-credits-delta')),
          matching: find.text('활성보다 −2000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-summary-overall-delta')),
          matching: find.text('활성 62% → 72%'),
        ),
        findsOneWidget,
      );

      await pump(
        tester,
        tab: PlanDetailResourceTab.byPhase,
        data: _data(comparison: true),
        showComparison: true,
        selectedPhase: 1,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('detail-phase-card-1-resource-$_notes-delta'),
          ),
          matching: find.text('+22'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('detail-summary-byPhase-delta')),
          matching: find.text('활성보다 +22 부족'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
