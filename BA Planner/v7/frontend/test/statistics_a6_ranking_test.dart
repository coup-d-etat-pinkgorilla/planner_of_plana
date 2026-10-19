// FE7-j: A6 구간 선택 → "오른 학생 순위"(Statistics-Proposal A6, FE7-h 발견 5).
//
// - projection: 두 학생 스냅샷 사이 학생별 육성도 증감(오른 학생 증감 큰 순 → 새 학생), 통계 필터 대상만, 구간을 못 찾으면 null.
// - 화면(tidy4, FE7-j 발견 1 — 시안 "두 스냅샷을 고르면"): 첫 클릭 = 시작(그 점만 분홍, 근거 없음), 둘째 클릭 = 끝(두 점 사이가
//   강조 구간 · 근거 패널 순위, 앞 점을 누르면 두 끝을 바꾼다). 시작 점을 다시 누르면 풀고, 구간을 고른 뒤 누르면 새 시작이다.
//   근거 버튼은 학생 탭 임시 목록으로 넘긴다(FE7-d). "← 통계" 복귀 뒤 이력을 읽으면 되살린다.
// 시안 숫자 이력 fixture(`statistics_history_fixture.dart`)를 쓴다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_history_projection.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_history.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:ba_planner_v7/ui/navigation/app_navigation_intent.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_growth_evidence.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_history_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_history_fixture.dart';
import 'statistics_supply_fixture.dart';

const _profile = '0123456789abcdef01234567';

/// 남은 이력 전부로 만든 통계 이력 색인(페이지 `_loadHistory`와 같은 질의).
StatisticsHistory _build() {
  final state = statisticsHistoryFixtureState();
  final history = statisticsHistoryFixtureHistory();
  final pages = <RepositoryHistoryEventsResult>[];
  var request = RepositoryHistoryEventsRequest(
    profileId: state.profileId,
    limit: inventoryHistoryPageLimit,
  );
  while (true) {
    final page = repositoryHistoryEvents(state, history, request);
    pages.add(page);
    final cursor = page.nextCursor;
    if (cursor == null) break;
    request = request.withCursor(cursor);
  }
  return StatisticsHistory.build(
    StatisticsHistoryInput(
      now: statisticsHistoryFixtureNow,
      state: state,
      pages: pages,
      students: statisticsHistoryFixtureCatalog(),
      lastStudentScanAt: null,
      lastInventoryScanAt: null,
    ),
  );
}

/// [from] 점 → [to] 점(null이면 마지막 점) 순위.
StatisticsGrowthRanking _ranking(
  StatisticsHistory history,
  int from, {
  int? to,
  Set<String>? targets,
}) {
  final trend = statisticsGrowthTrend(history, targets: targets)!;
  return statisticsGrowthRanking(
    history,
    trend,
    fromSession: trend.points[from].sessionId,
    toSession: trend.points[to ?? trend.points.length - 1].sessionId,
  )!;
}

/// 이력 fixture를 답하는 서비스(`statistics_history_view_test.dart`와 같은 질의, 고정 시계).
class _HistoryService extends MockAppService implements AppClockSource {
  final RepositoryCurrentHistory _history = statisticsHistoryFixtureHistory();
  final RepositoryState _state = statisticsHistoryFixtureState();

  @override
  DateTime get clockNow => statisticsHistoryFixtureNow;

  @override
  Future<List<RepositoryProfile>> listProfiles() async => const [
    RepositoryProfile(
      id: _profile,
      displayName: 'Main',
      revision: 1,
      selected: true,
    ),
  ];

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async => _state;

  @override
  Future<List<StudentCatalogEntry>> listStudents() async =>
      statisticsHistoryFixtureCatalog();

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
        _history.summarize(id, _state.revision).toWire(),
    ],
  });

  @override
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  ) async => repositoryHistoryEvents(_state, _history, request);

  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async => repositoryHistoryScanLatest(
    request.profileId,
    _state.revision,
    _history,
    request,
  );
}

Widget _subject(
  AppService service, {
  List<AppNavigationIntent>? intents,
  int token = 0,
}) => MaterialApp(
  theme: BAPlannerTheme.dark(),
  home: Scaffold(
    body: StatisticsPage(
      service: service,
      onOpen: (_) {},
      onNavigate: intents?.add,
      reloadToken: token,
      returnToken: token,
    ),
  ),
);

Future<_HistoryService> _pump(
  WidgetTester tester, {
  Size size = const Size(2560, 1208),
  List<AppNavigationIntent>? intents,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final service = _HistoryService();
  addTearDown(service.dispose);
  await tester.pumpWidget(_subject(service, intents: intents));
  await tester.pumpAndSettle();
  return service;
}

const _chart = ValueKey('statistics-a6-chart');

StatisticsGrowthTrendPainter _painter(WidgetTester tester) =>
    tester.widget<StatChartFrame>(find.byKey(_chart)).painter
        as StatisticsGrowthTrendPainter;

/// A6 [index] 점(6점 중)의 세로 칸 안을 누른다(점보다 30 아래, 설계 좌표).
Future<void> _tapPoint(WidgetTester tester, int index) async {
  await tester.ensureVisible(find.byKey(_chart));
  await tester.pumpAndSettle();
  final frame = tester.widget<StatChartFrame>(find.byKey(_chart));
  final origin = tester.getTopLeft(find.byKey(_chart));
  await tester.tapAt(
    origin +
        frame.toLocal(
          Offset(
            StatisticsA6Geometry.xOf(index, 6),
            StatisticsA6Geometry.baseline - 30,
          ),
        ),
  );
  await tester.pumpAndSettle();
}

/// A6 두 점을 차례로 누른다(첫 클릭 = 시작, 둘째 클릭 = 끝, tidy4).
Future<void> _tapRange(WidgetTester tester, int first, int second) async {
  await _tapPoint(tester, first);
  await _tapPoint(tester, second);
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

String _title(WidgetTester tester) => tester
    .widget<RichText>(
      find
          .descendant(
            of: find.byKey(const ValueKey('statistics-evidence-title')),
            matching: find.byType(RichText),
          )
          .first,
    )
    .text
    .toPlainText();

void main() {
  group('statisticsGrowthRanking', () {
    test('9/29 → 10/05: risen students by change, then new students', () {
      final ranking = _ranking(_build(), 4);
      expect(ranking.title, '9/29 → 10/05');
      expect(ranking.averageText, '+1.2%p');
      expect(ranking.newCount, statisticsHistoryNewStudents.length);
      final news = [
        for (final row in ranking.rows)
          if (row.isNew) row.student.studentId,
      ];
      expect(news.toSet(), statisticsHistoryNewStudents.toSet());
      // 새 학생은 오른 학생 뒤다.
      expect(
        ranking.rows.skip(ranking.risenCount).every((row) => row.isNew),
        isTrue,
      );
      final risen = ranking.rows.take(ranking.risenCount).toList();
      expect(risen, isNotEmpty);
      for (final row in risen) {
        expect(row.tenths, greaterThan(0));
      }
      for (var index = 1; index < risen.length; index++) {
        expect(
          risen[index - 1].tenths,
          greaterThanOrEqualTo(risen[index].tenths!),
        );
      }
      final ids = {for (final row in risen) row.student.studentId};
      // 레벨 85 → 90 · 완전 육성이 된 학생은 올랐다.
      expect(ids, containsAll(statisticsHistoryLeveledStudents));
      expect(ids, contains(statisticsHistoryCompletedStudent));
      expect(ranking.unknownCount, 0);
    });

    test('a longer range compares the start snapshot with the last one', () {
      final history = _build();
      final ranking = _ranking(history, 3);
      expect(ranking.title, '9/22 → 10/05');
      expect(ranking.averageText, '+2.0%p');
      final trend = statisticsGrowthTrend(history)!;
      final before = {
        for (final student in history.growthAt(trend.points[3].states).students)
          student.studentId: student,
      };
      final after = history.growthAt(trend.points.last.states).students;
      for (final row in ranking.rows.where((row) => !row.isNew)) {
        final then = before[row.student.studentId]!;
        final now = after.firstWhere(
          (student) => student.studentId == row.student.studentId,
        );
        expect(
          row.tenths,
          (now.growth! * 1000).round() - (then.growth! * 1000).round(),
        );
      }
      // 그대로인 학생은 순위에 없다.
      final unchanged = after.where((student) {
        final then = before[student.studentId];
        return then != null &&
            (student.growth! * 1000).round() == (then.growth! * 1000).round();
      });
      expect(unchanged, isNotEmpty);
      for (final student in unchanged) {
        expect(
          ranking.rows.any((row) => row.student.studentId == student.studentId),
          isFalse,
        );
      }
    });

    test('the statistics filter keeps only target students', () {
      final targets = {
        statisticsHistoryNewStudents.first,
        statisticsHistoryLeveledStudents.first,
      };
      final ranking = _ranking(_build(), 4, targets: targets);
      expect(
        [for (final row in ranking.rows) row.student.studentId],
        [
          statisticsHistoryLeveledStudents.first,
          statisticsHistoryNewStudents.first,
        ],
      );
      expect(ranking.risenCount, 1);
      expect(ranking.newCount, 1);
      expect(ranking.rows.last.isNew, isTrue);
    });

    test('a middle range compares its own two snapshots (tidy4)', () {
      final history = _build();
      final trend = statisticsGrowthTrend(history)!;
      final ranking = _ranking(history, 1, to: 3);
      expect(ranking.from, same(trend.points[1]));
      expect(ranking.to, same(trend.points[3]));
      expect(
        ranking.title,
        '${statisticsDateText(trend.points[1].at)} → '
        '${statisticsDateText(trend.points[3].at)}',
      );
      final before = {
        for (final student in history.growthAt(trend.points[1].states).students)
          student.studentId: student,
      };
      final after = {
        for (final student in history.growthAt(trend.points[3].states).students)
          student.studentId: student,
      };
      for (final row in ranking.rows) {
        final then = before[row.student.studentId];
        final now = after[row.student.studentId]!;
        if (row.isNew) {
          expect(then, isNull);
          continue;
        }
        expect(
          row.tenths,
          (now.growth! * 1000).round() - (then!.growth! * 1000).round(),
        );
        expect(row.tenths, greaterThan(0));
      }
      // 강조 글자도 같은 두 끝이다. 시작만 고른 강조(시작 = 끝)는 글자가 없다.
      final shown = trend.withHighlight(1, end: 3);
      expect(shown.highlightEnd, 3);
      expect(shown.highlightText, '${ranking.title} ${ranking.averageText}');
      expect(trend.withHighlight(2, end: 2).highlightText, isNull);
      expect(trend.withHighlight(3).highlightText, trend.highlightText);
    });

    test('an unknown or reversed range has no ranking', () {
      final history = _build();
      final trend = statisticsGrowthTrend(history)!;
      expect(
        statisticsGrowthRanking(
          history,
          trend,
          fromSession: 'missing',
          toSession: trend.points.last.sessionId,
        ),
        isNull,
      );
      expect(
        statisticsGrowthRanking(
          history,
          trend,
          fromSession: trend.points.last.sessionId,
          toSession: trend.points.first.sessionId,
        ),
        isNull,
      );
      expect(
        statisticsGrowthRanking(
          null,
          trend,
          fromSession: trend.points.first.sessionId,
          toSession: trend.points.last.sessionId,
        ),
        isNull,
      );
    });
  });

  group('A6 range selection', () {
    testWidgets('first click = start, second click = end, start again clears', (
      tester,
    ) async {
      await _pump(tester);
      expect(_painter(tester).highlightStart, 3);
      expect(_painter(tester).highlightEnd, isNull);
      expect(_title(tester), '근거 확인');

      // 첫 클릭: 그 점만 분홍(구간 · 글자 · 근거 없음).
      await _tapPoint(tester, 4);
      var painter = _painter(tester);
      expect(painter.highlightStart, 4);
      expect(painter.highlightEnd, 4);
      expect(painter.highlightText, isNull);
      expect(_title(tester), '근거 확인');

      // 둘째 클릭: 두 점 사이가 구간이다.
      await _tapPoint(tester, 5);
      painter = _painter(tester);
      expect(painter.highlightStart, 4);
      expect(painter.highlightEnd, 5);
      expect(painter.highlightText, '9/29 → 10/05 +1.2%p');
      final ranking = _ranking(_build(), 4);
      expect(_title(tester), contains('9/29 → 10/05'));
      expect(
        tester
            .widget<BaChip>(
              find.byKey(const ValueKey('statistics-evidence-count')),
            )
            .label,
        '${ranking.rows.length}명',
      );
      expect(_text(tester, 'statistics-evidence-note'), 'A6에서 고른 구간 · 오른 학생 순');
      final first = ranking.rows.first;
      final row = find.byKey(
        ValueKey('statistics-evidence-row-${first.student.studentId}'),
      );
      expect(row, findsOneWidget);
      expect(
        tester
            .widget<BaChip>(
              find.descendant(of: row, matching: find.byType(BaChip)),
            )
            .label,
        '${statisticsSignedTenths(first.tenths!)}%p',
      );
      expect(
        _text(tester, 'statistics-evidence-summary-change-value'),
        '+1.2%p',
      );
      expect(
        _text(tester, 'statistics-evidence-summary-risen-value'),
        '${ranking.risenCount}명',
      );
      expect(
        _text(tester, 'statistics-evidence-summary-new-value'),
        '${ranking.newCount}명',
      );

      // 셋째 클릭: 새 시작(구간 · 근거가 풀린다). 같은 점을 다시 누르면 시작도 풀려 기본 강조로 돌아간다.
      await _tapPoint(tester, 2);
      painter = _painter(tester);
      expect(painter.highlightStart, 2);
      expect(painter.highlightEnd, 2);
      expect(painter.highlightText, isNull);
      expect(_title(tester), '근거 확인');
      await _tapPoint(tester, 2);
      expect(_painter(tester).highlightStart, 3);
      expect(_painter(tester).highlightEnd, isNull);
      expect(_title(tester), '근거 확인');
      expect(tester.takeException(), isNull);
    });

    testWidgets('an earlier second point swaps the ends; any end is allowed', (
      tester,
    ) async {
      await _pump(tester);
      // 9/22 → 그보다 앞 점: 끝이 마지막 점이 아닌 구간.
      await _tapRange(tester, 3, 1);
      final painter = _painter(tester);
      final ranking = _ranking(_build(), 1, to: 3);
      expect(painter.highlightStart, 1);
      expect(painter.highlightEnd, 3);
      expect(painter.highlightText, '${ranking.title} ${ranking.averageText}');
      expect(_title(tester), contains(ranking.title));
      expect(
        tester
            .widget<BaChip>(
              find.byKey(const ValueKey('statistics-evidence-count')),
            )
            .label,
        '${ranking.rows.length}명',
      );
      expect(
        _text(tester, 'statistics-evidence-summary-change-value'),
        ranking.averageText,
      );

      // 구간 끝 점을 눌러도 셋째 클릭은 새 시작이다.
      await _tapPoint(tester, 3);
      expect(_painter(tester).highlightStart, 3);
      expect(_painter(tester).highlightEnd, 3);
      expect(_title(tester), '근거 확인');
      expect(tester.takeException(), isNull);
    });

    testWidgets('new students are marked and the rest opens on demand', (
      tester,
    ) async {
      await _pump(tester);
      await _tapRange(tester, 3, 5);
      expect(_painter(tester).highlightText, '9/22 → 10/05 +2.0%p');
      final ranking = _ranking(_build(), 3);
      expect(ranking.rows.length, greaterThan(7));
      expect(
        find.byKey(const ValueKey('statistics-evidence-more')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('statistics-evidence-more')));
      await tester.pumpAndSettle();
      final last = ranking.rows.last;
      expect(last.isNew, isTrue);
      final scroll = find.byKey(const ValueKey('statistics-evidence-scroll'));
      await tester.scrollUntilVisible(
        find.byKey(
          ValueKey('statistics-evidence-row-${last.student.studentId}'),
        ),
        200,
        scrollable: find.descendant(
          of: scroll,
          matching: find.byType(Scrollable),
        ),
      );
      final row = find.byKey(
        ValueKey('statistics-evidence-row-${last.student.studentId}'),
      );
      final chip = tester.widget<BaChip>(
        find.descendant(of: row, matching: find.byType(BaChip)),
      );
      expect(chip.label, statisticsNewStudentText);
      expect(chip.tone, AppTones.info);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'evidence buttons pass the ranked students to the student tab',
      (tester) async {
        final intents = <AppNavigationIntent>[];
        await _pump(tester, intents: intents);
        await _tapRange(tester, 4, 5);
        await tester.tap(
          find.byKey(const ValueKey('statistics-evidence-secondary')),
        );
        await tester.pumpAndSettle();
        final intent = intents.single as StudentsNavigationIntent;
        final ranking = _ranking(_build(), 4);
        expect(intent.studentIds, [
          for (final row in ranking.rows) row.student.studentId,
        ]);
        expect(intent.label, '통계: 9/29 → 10/05 · ${ranking.rows.length}명');
      },
    );

    testWidgets('another tile selection replaces the range', (tester) async {
      await _pump(tester);
      await _tapRange(tester, 4, 5);
      expect(_painter(tester).highlightStart, 4);
      await tester.tap(
        find.byKey(const ValueKey('statistics-topic-inventory')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('statistics-topic-growth')));
      await tester.pumpAndSettle();
      // 주제를 바꾸면 고른 것을 지운다(다른 타일과 같다).
      expect(_painter(tester).highlightStart, 3);
      expect(_painter(tester).highlightEnd, isNull);
      expect(_title(tester), '근거 확인');
    });

    testWidgets(
      'returning to statistics restores the range after the history',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(2560, 1208));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final service = _HistoryService();
        addTearDown(service.dispose);
        await tester.pumpWidget(_subject(service));
        await tester.pumpAndSettle();
        await _tapRange(tester, 4, 5);
        expect(_title(tester), contains('9/29 → 10/05'));

        // "← 통계" 복귀(FE7-d): 다시 읽은 뒤 고른 구간을 되살린다. 이력은 보드 뒤에 읽는다.
        await tester.pumpWidget(_subject(service, token: 1));
        await tester.pumpAndSettle();
        expect(_painter(tester).highlightStart, 4);
        expect(_painter(tester).highlightEnd, 5);
        expect(_title(tester), contains('9/29 → 10/05'));
      },
    );

    for (final size in const [Size(1280, 720), Size(1440, 900)]) {
      testWidgets('selected range fits ${size.width}x${size.height}', (
        tester,
      ) async {
        await _pump(tester, size: size);
        await _tapRange(tester, 3, 5);
        expect(_painter(tester).highlightStart, 3);
        expect(_title(tester), contains('9/22 → 10/05'));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
