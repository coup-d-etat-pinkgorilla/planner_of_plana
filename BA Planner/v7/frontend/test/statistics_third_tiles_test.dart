// FE7-i: 통계 3차 타일 A5 · C5(시안 Stats-Growth · Stats-Plan · Stats-Growth-Filter).
//
// projection(A5 칸 정의 · 인원, C5 점 · 미계획 · 40% 미만 = KPI)과 화면(차트 · 고른 칸 · 구간 → 근거 → 원본 탭 이동 ·
// 통계 필터 대상 학생 · 작은 창)을 본다. 학생 목록은 golden과 같이 번들 학생 목록에서 fixture id를 고른다(학교 · 편성이
// 실제 값). 시계는 이력 fixture 고정 시각이다.
import 'dart:convert';

import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_matrix_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_supply_projection.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:ba_planner_v7/ui/navigation/app_navigation_intent.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_matrix_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_growth_fixture.dart';
import 'statistics_history_fixture.dart';
import 'statistics_plan_fixture.dart';
import 'statistics_supply_fixture.dart';

const _canvas = Size(2560, 1208);
const _profileId = '0123456789abcdef01234567';

/// 번들 학생 목록에서 고른 fixture 학생(golden 학생 목록과 같다).
late List<StudentCatalogEntry> _catalog;

Future<List<StudentCatalogEntry>> _loadCatalog() async {
  final data = await rootBundle.load('assets/student_catalog.json');
  final byId = {
    for (final item
        in jsonDecode(utf8.decode(data.buffer.asUint8List())) as List)
      (item as Map)['student_id'] as String: StudentCatalogEntry.fromWire(
        Map<String, dynamic>.from(item),
      ),
  };
  return [for (final id in statisticsGrowthFixtureCatalogIds) byId[id]!];
}

/// 성장 · 재화 · 활성 문서 · 이력 fixture를 모두 주는 서비스(golden 계획 장면과 같은 숫자).
class _Service extends MockAppService implements AppClockSource {
  final RepositoryCurrentHistory _history = statisticsHistoryFixtureHistory();

  @override
  DateTime get clockNow => statisticsHistoryFixtureNow;

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
  Future<RepositoryState> loadRepositoryState(String profileId) async =>
      statisticsSupplyFixtureState(
        profileId: profileId,
        revision: statisticsHistoryFixtureRevision,
      );

  @override
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId) async =>
      statisticsPlanFixturePlan(profileId: profileId);

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async => statisticsPlanFixtureProjection();

  @override
  Future<List<StudentCatalogEntry>> listStudents() async => _catalog;

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

  @override
  Future<RepositoryHistorySummaryResult> loadRepositoryHistorySummary(
    List<String> profileIds,
  ) async => RepositoryHistorySummaryResult.fromWire({
    'profiles': [
      for (final id in profileIds)
        _history.summarize(id, statisticsHistoryFixtureRevision).toWire(),
    ],
  });

  @override
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  ) async => repositoryHistoryEvents(
    await loadRepositoryState(request.profileId),
    _history,
    request,
  );

  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async => repositoryHistoryScanLatest(
    request.profileId,
    statisticsHistoryFixtureRevision,
    _history,
    request,
  );
}

Future<List<AppNavigationIntent>> _pump(
  WidgetTester tester, {
  Size size = _canvas,
  String topic = 'growth',
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final service = _Service();
  addTearDown(service.dispose);
  final intents = <AppNavigationIntent>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatisticsPage(
          service: service,
          onOpen: (_) {},
          onNavigate: intents.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (topic != 'growth') {
    await tester.tap(find.byKey(ValueKey('statistics-topic-$topic')));
    await tester.pumpAndSettle();
  }
  return intents;
}

/// 보유 학생 성장(번들 학생 목록, 인벤토리 · 계획 fixture 계정 상태 — 화면과 같은 값).
StatisticsGrowth _growth() => buildStatisticsGrowth(
  state: statisticsSupplyFixtureState(),
  catalog: _catalog,
)!;

T _painter<T extends StatChartPainter>(WidgetTester tester, String key) =>
    tester
            .widget<StatChartFrame>(
              find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(StatChartFrame),
                matchRoot: true,
              ),
            )
            .painter
        as T;

Offset _chartPoint(
  WidgetTester tester,
  String key,
  Size viewBox,
  Offset point,
) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  return rect.topLeft + point * (rect.width / viewBox.width);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Finder _inside(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

/// A5 칸 [row] · [column]의 가운데(설계 좌표).
Offset _cellCenter(int row, int column) => Offset(
  StatisticsA5Geometry.valueX(row, column),
  StatisticsA5Geometry.bottomOf(row) - StatisticsA5Geometry.cellHeight / 2,
);

/// 가운데 viewport를 아래로 민다(A5 · C5 줄이 보이게).
Future<void> _scrollDown(WidgetTester tester, String tile) async {
  await tester.drag(find.byKey(ValueKey(tile)), const Offset(0, -600));
  await tester.pumpAndSettle();
}

StatisticsStudentGrowth _student(
  String id, {
  Map<String, dynamic> values = const {},
  bool planned = false,
  String? combatClass,
}) => statisticsGrowthOfValues(
  id,
  {
    'level': 90,
    'ex_skill': 5,
    'skill1': 10,
    'skill2': 10,
    'skill3': 10,
    'equip1': 'T10',
    'equip2': 'T10',
    'equip3': 'T10',
    'student_star': 5,
    'weapon_star': 4,
    ...values,
  },
  catalog: StudentCatalogEntry(
    studentId: id,
    displayName: id,
    templateName: '$id.png',
    group: id,
    variant: null,
    school: null,
    rarity: null,
    attackType: null,
    defenseType: null,
    combatClass: combatClass,
    role: null,
    position: null,
    hasFavoriteItem: false,
    searchTags: const [],
    krSearchTags: const [],
  ),
  planned: planned,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _catalog = await _loadCatalog();
  });

  group('projection', () {
    test('A5 columns: skills 1–3 · 4–6 · 7–8 · 9 · M, EX 1–3 · 4 · M', () {
      const skill = StatisticsMatrixRow.normal;
      expect(
        [for (var v = 0; v <= 10; v++) skill.columnOf(v)],
        [
          0, 0, 0, 0, 1, 1, 1, 2, 2, 3, 4, //
        ],
      );
      const ex = StatisticsMatrixRow.ex;
      expect([for (var v = 1; v <= 5; v++) ex.columnOf(v)], [0, 0, 0, 1, 4]);
      expect(
        [for (var c = 0; c < 5; c++) ex.appliesTo(c)],
        [true, true, false, false, true],
      );
      expect(StatisticsMatrixRow.equipment.appliesTo(2), isTrue);
      expect(
        const StatisticsMatrixCell(StatisticsMatrixRow.ex, 4).title,
        'EX 스킬 M',
      );
      expect(
        const StatisticsMatrixCell(StatisticsMatrixRow.equipment, 2).title,
        '장비 T7–8',
      );
      expect(
        const StatisticsMatrixCell(StatisticsMatrixRow.sub, 0).title,
        '서브 스킬 0–3',
      );
    });

    test(
      'A5 counts students per row, lowest equipment tier, unknown left out',
      () {
        final growth = StatisticsGrowth(
          catalogCount: 4,
          students: [
            _student('a', values: {'ex_skill': 4, 'skill2': 0, 'equip2': 'T3'}),
            _student('b', values: {'skill1': 9, 'equip1': 'T8'}),
            _student('c', values: {'skill3': null, 'equip3': null}),
            _student('d'),
          ],
        );
        final matrix = StatisticsSkillMatrix.of(growth);
        expect(
          [for (var c = 0; c < 5; c++) matrix.count(StatisticsMatrixRow.ex, c)],
          [0, 1, 0, 0, 3],
        );
        expect(matrix.count(StatisticsMatrixRow.normal, 3), 1);
        // 강화 0(미개방)은 첫 칸이다.
        expect(matrix.count(StatisticsMatrixRow.enhanced, 0), 1);
        // 서브 · 장비는 c를 모른다(그 행에서만 빠진다).
        expect(
          [for (var c = 0; c < 5; c++) matrix.count(StatisticsMatrixRow.sub, c)]
              .fold<int>(0, (sum, value) => sum + value),
          3,
        );
        // 장비는 3칸 중 가장 낮은 칸: a T3 → 첫 칸, b T8 → 7–8.
        expect(matrix.count(StatisticsMatrixRow.equipment, 0), 1);
        expect(matrix.count(StatisticsMatrixRow.equipment, 2), 1);
        expect(matrix.count(StatisticsMatrixRow.equipment, 4), 1);
        expect(matrix.unknownCount, 1);
        expect(matrix.maxCount, 3);
        expect(
          matrix[const StatisticsMatrixCell(StatisticsMatrixRow.ex, 1)]
              .single
              .studentId,
          'a',
        );
      },
    );

    test('A5 on the fixture: every row counts each owned student once', () {
      final growth = _growth();
      final matrix = StatisticsSkillMatrix.of(growth);
      for (final row in StatisticsMatrixRow.values) {
        final total = [
          for (var c = 0; c < 5; c++) matrix.count(row, c),
        ].fold<int>(0, (sum, value) => sum + value);
        expect(total, growth.ownedCount - matrix.unknownCount, reason: '$row');
      }
      expect(matrix.count(StatisticsMatrixRow.ex, 2), 0);
      expect(matrix.count(StatisticsMatrixRow.ex, 3), 0);
    });

    test('C5 band uses the KPI function; unknown class has no dot', () {
      final growth = StatisticsGrowth(
        catalogCount: 4,
        students: [
          _student(
            'low',
            values: {
              'level': 1,
              'ex_skill': 1,
              'skill1': 1,
              'skill2': 0,
              'skill3': 0,
              'equip1': 'T0',
              'equip2': 'T0',
              'equip3': 'T0',
              'student_star': 1,
              'weapon_star': 0,
            },
            combatClass: 'striker',
          ),
          _student(
            'lowplanned',
            values: {
              'level': 1,
              'ex_skill': 1,
              'skill1': 1,
              'skill2': 0,
              'skill3': 0,
              'equip1': 'T0',
              'equip2': 'T0',
              'equip3': 'T0',
              'student_star': 1,
              'weapon_star': 0,
            },
            planned: true,
            combatClass: 'special',
          ),
          _student(
            'lownoclass',
            values: {
              'level': 1,
              'ex_skill': 1,
              'skill1': 1,
              'skill2': 0,
              'skill3': 0,
              'equip1': 'T0',
              'equip2': 'T0',
              'equip3': 'T0',
              'student_star': 1,
              'weapon_star': 0,
            },
          ),
          _student('high', combatClass: 'special'),
        ],
      );
      final strip = StatisticsUnplannedStrip.of(growth);
      expect(strip.dots.map((dot) => dot.student.studentId), [
        'low',
        'lowplanned',
        'high',
      ]);
      expect(strip.unknownCount, 1);
      expect(strip.low.map((student) => student.studentId), [
        'low',
        'lownoclass',
      ]);
      expect(strip.low.length, statisticsUnplannedLowCount(growth));
      expect(
        strip.dots.where((dot) => dot.low).single.student.studentId,
        'low',
      );
      expect(
        strip.dots
            .firstWhere((dot) => dot.student.studentId == 'lowplanned')
            .row,
        1,
      );
    });

    test('C5 dot height is fixed per student and stays in its row', () {
      for (final id in ['aru', 'hina', 'noa', 'x']) {
        for (final row in [0, 1]) {
          final y = StatisticsC5Geometry.yOf(row, id);
          expect(y, StatisticsC5Geometry.yOf(row, id));
          final center =
              StatisticsC5Geometry.rowLines[row] - StatisticsC5Geometry.dotRise;
          expect((y - center).abs(), lessThanOrEqualTo(11.0001));
        }
      }
    });
  });

  group('growth A5', () {
    testWidgets('A5 draws the matrix and a cell opens its students', (
      tester,
    ) async {
      final intents = await _pump(tester);
      await _scrollDown(tester, 'statistics-tile-A1');
      expect(find.byKey(const ValueKey('statistics-a5-chart')), findsOneWidget);
      final painter = _painter<StatisticsSkillMatrixPainter>(
        tester,
        'statistics-a5-chart',
      );
      final matrix = StatisticsSkillMatrix.of(_growth());
      expect(painter.counts, [
        for (final row in StatisticsMatrixRow.values)
          [for (var c = 0; c < 5; c++) matrix.count(row, c)],
      ]);
      expect(find.text('3차'), findsWidgets);
      // 해당 없는 칸(EX 7–8)은 누르지 않는다.
      await tester.tapAt(
        _chartPoint(
          tester,
          'statistics-a5-chart',
          statisticsA5ViewBox,
          _cellCenter(0, 2),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A5에서 고른 칸 · 낮은 항목 순'), findsNothing);
      // 장비 M 칸을 누른다.
      const cell = StatisticsMatrixCell(StatisticsMatrixRow.equipment, 4);
      await tester.tapAt(
        _chartPoint(
          tester,
          'statistics-a5-chart',
          statisticsA5ViewBox,
          _cellCenter(4, 4),
        ),
      );
      await tester.pumpAndSettle();
      expect(_inside('statistics-evidence-title', cell.title), findsOneWidget);
      expect(
        _inside('statistics-evidence-count', '${matrix[cell].length}명'),
        findsOneWidget,
      );
      expect(find.text('A5에서 고른 칸 · 낮은 항목 순'), findsOneWidget);
      expect(find.text('칸 요약'), findsOneWidget);
      expect(
        _painter<StatisticsSkillMatrixPainter>(
          tester,
          'statistics-a5-chart',
        ).selected,
        cell,
      );
      expect(find.text('필터: ${cell.title}'), findsOneWidget);
      await _tapKey(tester, 'statistics-evidence-secondary');
      final intent = intents.single as StudentsNavigationIntent;
      expect(intent.studentIds, [
        for (final student in matrix[cell]) student.studentId,
      ]);
      expect(intent.label, '통계: ${cell.title} · ${matrix[cell].length}명');
      expect(tester.takeException(), isNull);
    });

    testWidgets('filtered A5 counts only the target students (FE7-e 발견 4)', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('statistics-filter')));
      await tester.pumpAndSettle();
      for (final chip in const [
        'student-filter-chip-school-Millennium',
        'student-filter-chip-combat_class-striker',
      ]) {
        await tester.tap(find.byKey(ValueKey(chip)));
        await tester.pumpAndSettle();
      }
      await _tapKey(tester, 'student-filter-apply');
      await _scrollDown(tester, 'statistics-tile-A1');
      final growth = _growth();
      final targets = StatisticsGrowth(
        catalogCount: growth.catalogCount,
        students: [
          for (final student in growth.students)
            if (student.school == 'Millennium' &&
                student.combatClass == 'striker')
              student,
        ],
      );
      expect(targets.ownedCount, greaterThan(0));
      expect(targets.ownedCount, lessThan(growth.ownedCount));
      final matrix = StatisticsSkillMatrix.of(targets);
      final painter = _painter<StatisticsSkillMatrixPainter>(
        tester,
        'statistics-a5-chart',
      );
      expect(painter.counts, [
        for (final row in StatisticsMatrixRow.values)
          [for (var c = 0; c < 5; c++) matrix.count(row, c)],
      ]);
      expect(
        painter.counts.first.fold<int>(0, (sum, value) => sum + value),
        targets.ownedCount - matrix.unknownCount,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('plan C5', () {
    testWidgets('C5 strip: band text = KPI, band opens students, plan step 1', (
      tester,
    ) async {
      final intents = await _pump(tester, topic: 'plan');
      await _scrollDown(tester, 'statistics-tile-C1');
      expect(find.byKey(const ValueKey('statistics-c5-chart')), findsOneWidget);
      final growth = _growth();
      final strip = StatisticsUnplannedStrip.of(growth);
      final low = statisticsUnplannedLowCount(growth)!;
      expect(strip.low.length, low);
      final painter = _painter<StatisticsUnplannedStripPainter>(
        tester,
        'statistics-c5-chart',
      );
      expect(painter.lowCount, low);
      expect(painter.dots, hasLength(strip.dots.length));
      expect(
        painter.dots.where((dot) => dot.tone == 2),
        hasLength(strip.dots.where((dot) => dot.low).length),
      );
      expect(
        painter.dots.where((dot) => dot.tone == 1),
        hasLength(strip.dots.where((dot) => dot.planned).length),
      );
      expect(painter.selected, isFalse);
      // KPI 다섯째 칸과 같은 수.
      expect(statisticsC5BandText(low), '미계획 · 40% 미만 $low명');
      await tester.tapAt(
        _chartPoint(
          tester,
          'statistics-c5-chart',
          statisticsC5ViewBox,
          StatisticsC5Geometry.band.center,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _painter<StatisticsUnplannedStripPainter>(
          tester,
          'statistics-c5-chart',
        ).selected,
        isTrue,
      );
      expect(
        _inside('statistics-evidence-title', '미계획 · 40% 미만'),
        findsOneWidget,
      );
      expect(_inside('statistics-evidence-count', '$low명'), findsOneWidget);
      expect(find.text('C5에서 고른 구간 · 육성도 낮은 순'), findsOneWidget);
      expect(find.text('구간 요약'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey('statistics-evidence-row-${strip.low.first.studentId}'),
        ),
        findsOneWidget,
      );
      expect(find.text(statisticsUnplannedActionLabel), findsOneWidget);
      expect(find.text('미리 선택 · $low명'), findsOneWidget);
      await _tapKey(tester, 'statistics-evidence-primary');
      final intent = intents.single as PlanNavigationIntent;
      expect(intent.target, PlanNavigationTarget.students);
      expect(intent.studentIds, [
        for (final student in strip.low) student.studentId,
      ]);
      // 다시 누르면 푼다.
      await tester.tapAt(
        _chartPoint(
          tester,
          'statistics-c5-chart',
          statisticsC5ViewBox,
          StatisticsC5Geometry.band.center,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('C5에서 고른 구간 · 육성도 낮은 순'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('C5 ignores the statistics filter (FD-104)', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('statistics-filter')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('student-filter-chip-school-Millennium')),
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, 'student-filter-apply');
      await _tapKey(tester, 'statistics-topic-plan');
      await _scrollDown(tester, 'statistics-tile-C1');
      final painter = _painter<StatisticsUnplannedStripPainter>(
        tester,
        'statistics-c5-chart',
      );
      expect(painter.lowCount, statisticsUnplannedLowCount(_growth()));
      expect(
        painter.dots,
        hasLength(StatisticsUnplannedStrip.of(_growth()).dots.length),
      );
    });
  });

  testWidgets('A5 and C5 evidence fit 1280x720', (tester) async {
    const size = Size(1280, 720 - 88);
    await _pump(tester, size: size);
    await _scrollDown(tester, 'statistics-tile-A1');
    await tester.tapAt(
      _chartPoint(
        tester,
        'statistics-a5-chart',
        statisticsA5ViewBox,
        _cellCenter(1, 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A5에서 고른 칸 · 낮은 항목 순'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tapKey(tester, 'statistics-topic-plan');
    await _scrollDown(tester, 'statistics-tile-C1');
    await tester.tapAt(
      _chartPoint(
        tester,
        'statistics-c5-chart',
        statisticsC5ViewBox,
        StatisticsC5Geometry.band.center,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('C5에서 고른 구간 · 육성도 낮은 순'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
