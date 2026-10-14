// FE7-b: 통계 학생 성장 화면(KPI · A1 · A2 · 구간 선택 → 근거, 시안 Stats-Growth).
//
// 시안 숫자 fixture(`statistics_growth_fixture.dart`)를 읽은 통계 페이지로 확인한다. 기준 viewport 콘텐츠 캔버스
// 2560×1208에서 시안 좌표(y − 184)와 비교하고, 섹션 안 요소는 ±2px.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:ba_planner_v7/ui/kit/kpi_tile.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_growth_charts.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_growth_evidence.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_growth_fixture.dart';

const _canvas = Size(2560, 1208);
const _header = 184.0;

class _GrowthService extends MockAppService {
  _GrowthService({this.empty = false});

  final bool empty;

  @override
  Future<List<RepositoryProfile>> listProfiles() async => const [
    RepositoryProfile(
      id: '0123456789abcdef01234567',
      displayName: 'Main',
      revision: 1,
      selected: true,
    ),
  ];

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async => empty
      ? RepositoryState.fromWire({
          'profile_id': profileId,
          'revision': 1,
          'students': <Object>[],
          'inventory': {'version': 1, 'entries': <Object>[]},
          'goals': {'version': 1, 'goals': <Object>[]},
        })
      : statisticsGrowthFixtureState(profileId: profileId);

  @override
  Future<List<StudentCatalogEntry>> listStudents() async =>
      statisticsGrowthFixtureCatalog();
}

Future<_GrowthService> _pump(
  WidgetTester tester, {
  Size size = _canvas,
  bool empty = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final service = _GrowthService(empty: empty);
  addTearDown(service.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatisticsPage(service: service, onOpen: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void _expectRect(
  WidgetTester tester,
  Finder finder,
  double x,
  double y,
  double width,
  double height, {
  double tolerance = 2,
  String? reason,
}) {
  final rect = tester.getRect(finder);
  expect(rect.left, closeTo(x, tolerance), reason: '$reason left');
  expect(rect.top, closeTo(y - _header, tolerance), reason: '$reason top');
  expect(rect.width, closeTo(width, tolerance), reason: '$reason width');
  expect(rect.height, closeTo(height, tolerance), reason: '$reason height');
}

/// 차트 설계 좌표 [point]의 화면 좌표.
Offset _chartPoint(
  WidgetTester tester,
  String key,
  Size viewBox,
  Offset point,
) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  return rect.topLeft + point * (rect.width / viewBox.width);
}

Future<void> _tapBin(WidgetTester tester, int bin) async {
  final slot = StatisticsA1Geometry.barSlot(bin);
  await tester.tapAt(
    _chartPoint(
      tester,
      'statistics-a1-chart',
      statisticsA1ViewBox,
      Offset(slot.center.dx + 1, StatisticsA1Geometry.baseline - 6),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapItem(WidgetTester tester, StatisticsGrowthItem item) async {
  const rows = 7;
  final baseline = StatisticsA2Geometry.baselineOf(item.index, rows);
  await tester.tapAt(
    _chartPoint(
      tester,
      'statistics-a2-chart',
      statisticsA2ViewBox,
      Offset(200, baseline - 8),
    ),
  );
  await tester.pumpAndSettle();
}

String _note(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('statistics-evidence-note')))
    .data!;

void main() {
  test('A1 · A2 design coordinates follow the artboard SVG', () {
    // A1: 막대 왼쪽 40.1 + 43.7 · n, 폭 31.5, 밑변 177, 최다 막대 141, 평균선 위 끝 50.1.
    expect(StatisticsA1Geometry.barSlot(0).left, closeTo(40.1, 0.05));
    expect(StatisticsA1Geometry.barSlot(6).left, closeTo(302.3, 0.05));
    expect(StatisticsA1Geometry.barSlot(9).left, closeTo(433.5, 0.15));
    expect(StatisticsA1Geometry.barSlot(6).width, 31.5);
    expect(StatisticsA1Geometry.baseline - StatisticsA1Geometry.plotTop, 141);
    expect(StatisticsA1Geometry.meanLineTop, closeTo(50.1, 0.05));
    expect(StatisticsA1Geometry.xOf(0.634), closeTo(311.1, 0.1));
    // A2: 시안 6행이면 행 간격 28 · 사선 밀림 4.94, 7행이면 23.3. 60% 기준선 (268.5, 2) → (239.8, 166).
    expect(StatisticsA2Geometry.baselineOf(1, 6), 51);
    expect(StatisticsA2Geometry.shiftOf(1, 6), closeTo(4.9, 0.05));
    expect(StatisticsA2Geometry.baselineOf(6, 7), 163);
    expect(StatisticsA2Geometry.thresholdX(2), closeTo(268.5, 0.5));
    expect(StatisticsA2Geometry.thresholdX(166), closeTo(239.8, 0.5));
  });

  testWidgets(
    'KPI band, scope and filter note use the artboard fixture numbers',
    (tester) async {
      await _pump(tester);
      final kpis = [
        for (var index = 0; index < 5; index++)
          tester.widget<KpiTile>(
            find.descendant(
              of: find.byKey(ValueKey('statistics-kpi-growth-$index')),
              matching: find.byType(KpiTile),
            ),
          ),
      ];
      expect(
        [for (final kpi in kpis) kpi.label],
        ['보유 학생', '평균 육성도', '최대 레벨', '완전 육성', '계획 등록'],
      );
      expect(
        [for (final kpi in kpis) kpi.value],
        ['128', '63.4%', '64명', '8명', '9명'],
      );
      // 지난 스냅샷 대비 증감은 FE7-h 전이라 '—'(회색).
      expect(kpis.first.delta, '/ 170 · —');
      for (final kpi in kpis.skip(1)) {
        expect(kpi.delta, '—');
        expect(kpi.deltaTone, KpiDeltaTone.unknown);
      }
      expect(find.text('보유 128명 기준 · 지난 스냅샷 대비'), findsOneWidget);
      expect(find.text('없음 · 보유 128명 전체'), findsOneWidget);
      // 그리지 않는 타일은 "준비 중" 자리를 유지한다(FD-106 사용자 결정 10-13). A6은 FE7-h, A3 · A4는 FE7-f 그래프
      // 자리다. 남은 것은 A5(FE7-i)뿐이다.
      expect(find.text(statisticsTilePendingText), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A1 · A2 charts fill the artboard chart boxes', (tester) async {
    await _pump(tester);
    // A1 타일 (549.3, 393.2) 안쪽 66.8 + 12, 머리 34 + 간격 10 → 차트 634×254.
    _expectRect(
      tester,
      find.byKey(const ValueKey('statistics-a1-chart')),
      628.1,
      449.2,
      634,
      254,
      reason: 'A1 chart',
    );
    // A2 타일 (1303.9, 393.2), 머리 32(칩) + 10, 남는 256 안 세로 가운데 → 538×245.
    _expectRect(
      tester,
      find.byKey(const ValueKey('statistics-a2-chart')),
      1382.7,
      452.7,
      538,
      245,
      reason: 'A2 chart',
    );
    final seg = tester.widget<SkewSegmented<int>>(
      find.byKey(const ValueKey('statistics-tile-A1-seg')),
    );
    expect(seg.onChanged, isNotNull, reason: 'A1 seg works with growth data');
    expect(seg.selected, 0);
    final a4 = tester.widget<SkewSegmented<int>>(
      find.byKey(const ValueKey('statistics-tile-A4-seg')),
    );
    // FE7-f: A4 seg(학교 · 역할)도 성장 자료가 있으면 동작한다.
    expect(a4.onChanged, isNotNull);
    expect(a4.selected, 0);
  });

  testWidgets('selecting the 60~70% bin lists its students like the artboard', (
    tester,
  ) async {
    await _pump(tester);
    expect(_note(tester), statisticsEvidenceEmptyText);
    await _tapBin(tester, 6);
    expect(find.text('육성도 60~70%'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('statistics-evidence-count')),
        matching: find.text('22명'),
      ),
      findsOneWidget,
    );
    expect(_note(tester), 'A1에서 고른 구간 · 낮은 항목 순');
    final note = tester.getRect(
      find.byKey(const ValueKey('statistics-evidence-note')),
    );
    expect(note.left, closeTo(2160, 2));
    final rows = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'statistics-evidence-row-',
          ),
    );
    expect(rows, findsNWidgets(7));
    const rects = [
      (2125.8, 309.2, 412.2),
      (2115.5, 367.2, 422.5),
      (2105.3, 425.2, 432.7),
      (2095.1, 483.2, 442.9),
      (2084.9, 541.2, 453.1),
      (2074.6, 599.2, 463.4),
      (2064.4, 657.2, 473.6),
    ];
    final ordered = rows.evaluate().toList()
      ..sort(
        (a, b) => tester
            .getRect(find.byWidget(a.widget))
            .top
            .compareTo(tester.getRect(find.byWidget(b.widget)).top),
      );
    for (final (index, (x, y, width)) in rects.indexed) {
      _expectRect(
        tester,
        find.byWidget(ordered[index].widget),
        x,
        y,
        width,
        52,
        reason: 'row $index',
      );
    }
    _expectRect(
      tester,
      find.byKey(const ValueKey('statistics-evidence-more')),
      2058.1,
      715.2,
      479.9,
      30,
      reason: 'more',
    );
    expect(find.text('나머지 15명'), findsOneWidget);
    expect(find.text('모두 보기'), findsOneWidget);
    // 요약 머리(시안 (2067.9, 763.2, 452.1×34)): 왼쪽 · 폭 · 세로 가운데.
    final summaryTitle = tester.getRect(
      find.byKey(const ValueKey('statistics-evidence-summary-title')),
    );
    expect(summaryTitle.left, closeTo(2067.9, 2));
    expect(summaryTitle.width, closeTo(452.1, 2));
    expect(summaryTitle.center.dy, closeTo(763.2 + 17 - _header, 2));
    expect(find.text('구간 요약'), findsOneWidget);
    for (final (index, (key, x)) in const [
      ('level', 2038.7),
      ('lowest', 2029.5),
      ('planned', 2020.3),
    ].indexed) {
      _expectRect(
        tester,
        find.byKey(ValueKey('statistics-evidence-summary-$key')),
        x,
        807.2 + 52 * index,
        2538 - x,
        48,
        reason: 'summary $key',
      );
    }
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('statistics-evidence-summary-planned-value'),
            ),
          )
          .data,
      '2명',
    );
    // 같은 구간을 다시 누르면 고르기를 푼다.
    await _tapBin(tester, 6);
    expect(_note(tester), statisticsEvidenceEmptyText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"모두 보기" scrolls every student of the bin', (tester) async {
    await _pump(tester);
    await _tapBin(tester, 6);
    await tester.tap(find.byKey(const ValueKey('statistics-evidence-more')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('statistics-evidence-more')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('statistics-evidence-scroll')),
      findsOneWidget,
    );
    final rows = find.descendant(
      of: find.byKey(const ValueKey('statistics-evidence-scroll')),
      matching: find.byType(StatisticsEvidenceStudentRow),
    );
    expect(rows, findsNWidgets(22));
    await tester.drag(
      find.byKey(const ValueKey('statistics-evidence-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 다른 구간을 고르면 접힌다.
    await _tapBin(tester, 5);
    expect(
      find.byKey(const ValueKey('statistics-evidence-more')),
      findsOneWidget,
    );
  });

  testWidgets('A2 item selection lists students with the lowest value first', (
    tester,
  ) async {
    await _pump(tester);
    await _tapItem(tester, StatisticsGrowthItem.weapon);
    expect(find.text('전용무기 완성도'), findsOneWidget);
    expect(_note(tester), 'A2에서 고른 항목 · 낮은 학생 순');
    expect(find.text('항목 요약'), findsOneWidget);
    expect(find.text('평균 완성도'), findsOneWidget);
    // A1에서 구간을 고르면 A2 선택은 풀린다(한 번에 하나).
    await _tapBin(tester, 6);
    expect(find.text('육성도 60~70%'), findsOneWidget);
    expect(find.text('전용무기 완성도'), findsNothing);
  });

  testWidgets('A1 seg switches the metric and clears the selection', (
    tester,
  ) async {
    await _pump(tester);
    await _tapBin(tester, 6);
    await tester.tap(find.text('레벨').first);
    await tester.pumpAndSettle();
    final seg = tester.widget<SkewSegmented<int>>(
      find.byKey(const ValueKey('statistics-tile-A1-seg')),
    );
    expect(seg.selected, 1);
    expect(_note(tester), statisticsEvidenceEmptyText);
    final chart = tester.widget<StatChartFrame>(
      find.byKey(const ValueKey('statistics-a1-chart')),
    );
    expect(chart.semanticLabel, '레벨 분포');
  });

  testWidgets('a KPI tap scrolls the growth viewport to the graphs', (
    tester,
  ) async {
    await _pump(tester);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('statistics-growth-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, 0);
    await tester.tap(find.byKey(const ValueKey('statistics-kpi-growth-1')));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('no owned students shows the empty state in A1 and A2', (
    tester,
  ) async {
    await _pump(tester, empty: true);
    // A1 · A2 · A3 · A4(FE7-f)가 같은 빈 상태다.
    expect(find.text(statisticsGrowthNoStudentsText), findsNWidgets(4));
    final value = tester.widget<KpiTile>(
      find.descendant(
        of: find.byKey(const ValueKey('statistics-kpi-growth-1')),
        matching: find.byType(KpiTile),
      ),
    );
    expect(value.value, '—');
    expect(find.text('보유 0명 기준 · 지난 스냅샷 대비'), findsOneWidget);
    expect(
      tester
          .widget<SkewSegmented<int>>(
            find.byKey(const ValueKey('statistics-tile-A1-seg')),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('a reload or a topic change clears the selection', (
    tester,
  ) async {
    final service = await _pump(tester);
    await _tapBin(tester, 6);
    expect(_note(tester), 'A1에서 고른 구간 · 낮은 항목 순');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatisticsPage(
            service: service,
            onOpen: (_) {},
            reloadToken: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_note(tester), statisticsEvidenceEmptyText);
    await _tapBin(tester, 6);
    await tester.tap(find.byKey(const ValueKey('statistics-topic-inventory')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statistics-topic-growth')));
    await tester.pumpAndSettle();
    expect(_note(tester), statisticsEvidenceEmptyText);
  });

  for (final size in const [Size(1280, 720), Size(800, 600)]) {
    testWidgets(
      'selected and expanded evidence fits ${size.width}x${size.height}',
      (tester) async {
        await _pump(tester, size: size);
        await _tapBin(tester, 6);
        await tester.tap(
          find.byKey(const ValueKey('statistics-evidence-more')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _tapItem(tester, StatisticsGrowthItem.level);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
