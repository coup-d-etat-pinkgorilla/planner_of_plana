// FE7-a: 통계 3섹션 골격의 배치(시안 Stats-Growth · Stats-Inventory · Stats-Plan, F 보고서 §2).
// FE7-b 성장 그래프 · 근거 배치는 `statistics_growth_view_test.dart`다.
//
// 기준 viewport 2560×1392의 콘텐츠 캔버스(헤더 아래 2560×1208)에서 시안 좌표(y − 184)와 비교한다.
// 섹션 path 꼭짓점은 ±1px, 섹션 안 요소(버튼 · 타일 · KPI 띠)는 ±2px.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_source.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_topics.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_workspace.dart';
import 'package:ba_planner_v7/ui/studio/statistics_studio_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _canvas = Size(2560, 1208);
const _header = 184.0;

void _expectPoint(Offset actual, double x, double y, {double tolerance = 1}) {
  expect(actual.dx, closeTo(x, tolerance), reason: 'x of $actual');
  expect(actual.dy, closeTo(y - _header, tolerance), reason: 'y of $actual');
}

void _expectRect(
  WidgetTester tester,
  String key,
  double x,
  double y,
  double width,
  double height, {
  double tolerance = 2,
}) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  expect(rect.left, closeTo(x, tolerance), reason: '$key left');
  expect(rect.top, closeTo(y - _header, tolerance), reason: '$key top');
  expect(rect.width, closeTo(width, tolerance), reason: '$key width');
  expect(rect.height, closeTo(height, tolerance), reason: '$key height');
}

const _readyData = StatisticsSourceData(
  connection: BackendConnection.connected,
  loading: false,
  profile: RepositoryProfile(
    id: '000000000000000000000001',
    displayName: 'Main',
    revision: 1,
    selected: true,
  ),
);

Widget _host(StatisticsMode mode, {ValueChanged<StatisticsMode>? onMode}) =>
    MaterialApp(
      home: Scaffold(
        body: StatisticsWorkspace(
          mode: mode,
          data: _readyData,
          onModeChanged: onMode ?? (_) {},
          onRescan: () {},
        ),
      ),
    );

Future<void> _pumpCanvas(WidgetTester tester, StatisticsMode mode) async {
  await tester.binding.setSurfaceSize(_canvas);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_host(mode));
  await tester.pumpAndSettle();
}

void main() {
  group('Studio sections', () {
    test('scope · widgets · evidence paths match the artboard within 1px', () {
      final scope = statisticsSectionPolygon(_canvas, statisticsScopeSectionId);
      _expectPoint(scope[0], 0, 209.2);
      _expectPoint(scope[1], 586.7, 209.2);
      _expectPoint(scope[2], 378.1, 1392);
      _expectPoint(scope[3], 0, 1392);

      final widgets = statisticsSectionPolygon(
        _canvas,
        statisticsWidgetsSectionId,
      );
      _expectPoint(widgets[0], 608.6, 209.2);
      _expectPoint(widgets[1], 2101.9, 209.2);
      _expectPoint(widgets[2], 1893.3, 1392);
      _expectPoint(widgets[3], 400, 1392);

      final evidence = statisticsSectionPolygon(
        _canvas,
        statisticsEvidenceSectionId,
      );
      _expectPoint(evidence[0], 2560, 209.2);
      _expectPoint(evidence[1], 2560, 1392);
      _expectPoint(evidence[2], 1920, 1392);
      _expectPoint(evidence[3], 2128.6, 209.2);
    });

    test('viewport matches the artboard scroll box and scrollbar track', () {
      final geometry = StatisticsViewportGeometry.of(_canvas);
      expect(geometry.rect.left, closeTo(400, 0.1));
      expect(geometry.rect.top, closeTo(281.2 - _header, 0.1));
      expect(geometry.rect.height, closeTo(1100.8, 0.1));
      // 공용 스크롤바 트랙은 viewport 오른쪽 10에서 시작한다: 1683.2 − 10 − 12 × tan 10° ≈ 1671.1(시안 트랙 위 끝).
      expect(geometry.rect.width, closeTo(1683.2, 0.1));
      expect(geometry.horizontalInset, closeTo(31.76, 0.05));
      expect(geometry.scrollbarReserve, closeTo(32.24, 0.05));
    });

    test('tile slots keep the artboard widths and a 20px slanted gap', () {
      final slots = statisticsTileSlots(
        rowWidth: 1450.1,
        height: 322,
        widths: const [791.4, 695.5],
      );
      expect(slots[0].left, 0);
      expect(slots[0].width, closeTo(791.4, 0.1));
      expect(slots[1].left, closeTo(903.9 - 149.3, 0.1));
      expect(slots[1].width, closeTo(695.5, 0.1));
      final single = statisticsTileSlots(
        rowWidth: 1455.2,
        height: 351,
        widths: const [1455.2],
      );
      expect(single.single.width, closeTo(1455.2, 1e-9));
    });

    test('every topic lists the artboard tiles in order', () {
      List<String> ids(StatisticsMode mode) => [
        for (final row in mode.rows) ...[for (final tile in row.tiles) tile.id],
      ];
      expect(ids(StatisticsMode.students), ['A1', 'A2', 'A4', 'A6', 'A3', 'A5']);
      expect(ids(StatisticsMode.inventory), ['B1', 'B2', 'B3']);
      expect(ids(StatisticsMode.plan), ['C1', 'C2', 'C3', 'C4', 'C5']);
      for (final mode in StatisticsMode.values) {
        expect(mode.kpiLabels, hasLength(5));
      }
    });
  });

  // 시안 타일 머리(dc_outline): 제목 · seg 글자 · 차수 칩. seg만 있는 타일은 칩이 없고, B3은 둘 다다.
  const headers = <String, (String, List<String>, String?)>{
    'A1': ('육성도 분포', ['육성도', '레벨', '스킬', '장비'], null),
    'A2': ('항목별 완성도', [], '1차'),
    'A4': ('학교 비교', ['학교', '역할'], null),
    'A6': ('성장 추이', [], '2차'),
    'A3': ('성작 · 전용무기', [], '2차'),
    'A5': ('스킬 · 장비 매트릭스', [], '3차'),
    'B1': ('카테고리별 충족률', [], '1차'),
    'B2': ('부족 · 과잉', ['부족 순', '과잉 순'], null),
    'B3': ('주요 재화 변화', ['스냅샷 6회', '4주', '전체'], '3차'),
    'C1': ('필요량 vs 보유', ['부족 큰 순', '페이즈 순'], null),
    'C2': ('병목 매트릭스', [], '1차'),
    'C3': ('페이즈별 누적 부족', [], '2차'),
    'C4': ('학생별 목표 진행', [], '2차'),
    'C5': ('미계획 학생', [], '3차'),
  };

  testWidgets('tile headers follow the artboard title, seg and order chip', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(_canvas);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final mode in StatisticsMode.values) {
      await tester.pumpWidget(_host(mode));
      await tester.pumpAndSettle();
      for (final row in mode.rows) {
        for (final tile in row.tiles) {
          final (title, segments, chip) = headers[tile.id]!;
          final id = tile.id;
          final idText = tester.widget<Text>(
            find.byKey(ValueKey('statistics-tile-$id-id')),
          );
          expect(idText.data, id);
          expect(idText.style?.fontSize, 13);
          expect(idText.style?.color, AppColors.textMuted);
          final titleText = tester.widget<Text>(
            find.byKey(ValueKey('statistics-tile-$id-title')),
          );
          expect(titleText.data, title, reason: id);
          expect(titleText.style?.fontSize, 16);
          expect(titleText.style?.color, AppColors.text);
          final seg = find.byKey(ValueKey('statistics-tile-$id-seg'));
          if (segments.isEmpty) {
            expect(seg, findsNothing, reason: id);
          } else {
            final widget = tester.widget<SkewSegmented<int>>(seg);
            expect([for (final s in widget.segments) s.label], segments);
            expect(widget.selected, 0);
            expect(widget.onChanged, isNull, reason: '$id seg is a placeholder');
            expect(widget.height, 26);
          }
          final order = find.byKey(ValueKey('statistics-tile-$id-order'));
          if (chip == null) {
            expect(order, findsNothing, reason: id);
          } else {
            expect(
              find.descendant(of: order, matching: find.text(chip)),
              findsOneWidget,
              reason: id,
            );
          }
        }
      }
    }
  });

  testWidgets('scope section elements sit on the artboard rail', (
    tester,
  ) async {
    await _pumpCanvas(tester, StatisticsMode.students);
    _expectRect(tester, 'statistics-topic-growth', 14, 281.2, 538, 64);
    _expectRect(tester, 'statistics-topic-inventory', 14, 355.2, 524.9, 64);
    _expectRect(tester, 'statistics-topic-plan', 14, 429.2, 511.9, 64);
    _expectRect(tester, 'statistics-filter', 14, 551.2, 490.4, 52);
    _expectRect(tester, 'statistics-base-student-scan', 14, 693.2, 465.3, 44);
    _expectRect(tester, 'statistics-base-inventory-scan', 14, 743.2, 456.5, 44);
    _expectRect(tester, 'statistics-base-snapshots', 14, 793.2, 447.7, 44);
    _expectRect(tester, 'statistics-rescan', 14, 1322, 354.4, 52);
    expect(find.text('필터 · 학생 성장에만 적용'), findsOneWidget);
    expect(find.text('없음 · 보유 —명 전체'), findsOneWidget);
  });

  testWidgets('evidence section keeps the title, empty state and two actions', (
    tester,
  ) async {
    await _pumpCanvas(tester, StatisticsMode.students);
    _expectRect(tester, 'statistics-evidence-secondary', 1959.2, 1248, 578.8, 58);
    _expectRect(tester, 'statistics-evidence-primary', 1948.2, 1316, 589.8, 52);
    expect(find.text('근거 확인'), findsOneWidget);
    expect(find.text(statisticsEvidenceEmptyText), findsOneWidget);
    expect(find.text('학생 탭에서 보기'), findsOneWidget);
    expect(find.text('이 구간 학생을 계획에 추가'), findsOneWidget);
  });

  testWidgets('growth tiles and KPI band reproduce the artboard staircase', (
    tester,
  ) async {
    await _pumpCanvas(tester, StatisticsMode.students);
    _expectRect(tester, 'statistics-kpis-growth', 627.4, 287.2, 1373.3, 84);
    _expectRect(tester, 'statistics-tile-A1', 549.3, 393.2, 791.4, 322);
    _expectRect(tester, 'statistics-tile-A2', 1303.9, 393.2, 695.5, 322);
    _expectRect(tester, 'statistics-tile-A4', 480.6, 737.2, 751.6, 368);
    _expectRect(tester, 'statistics-tile-A6', 1187.2, 737.2, 751.6, 368);
    _expectRect(tester, 'statistics-tile-A3', 421.5, 1127.2, 741.9, 313);
    _expectRect(tester, 'statistics-tile-A5', 1128.2, 1127.2, 741.9, 313);
    expect(find.text('육성도 분포'), findsOneWidget);
    // FE7-b: A1 · A2는 그래프 자리(자료를 못 읽었으면 '—'), 나머지 4장은 "준비 중"(FD-106 사용자 결정 10-13).
    expect(find.text(statisticsTilePendingText), findsNWidgets(4));
    for (final id in ['A1', 'A2']) {
      expect(
        tester.widget<Text>(find.byKey(ValueKey('statistics-tile-$id-empty'))).data,
        '—',
      );
    }
    expect(find.text('보유 —명 기준 · 지난 스냅샷 대비'), findsOneWidget);
    // 제목 줄(시안 (635.9, 229.2, 1425.3×36)): 제목은 왼쪽, 범위 글자는 오른쪽 끝.
    final title = tester.getRect(find.byKey(const ValueKey('statistics-topic-title')));
    expect(title.left, closeTo(635.9, 2));
    final scope = tester.getRect(find.byKey(const ValueKey('statistics-scope-label')));
    expect(scope.right, closeTo(635.9 + 1425.3, 2));
  });

  testWidgets('inventory and plan tiles reproduce their artboards', (
    tester,
  ) async {
    await _pumpCanvas(tester, StatisticsMode.inventory);
    _expectRect(tester, 'statistics-tile-B1', 550.9, 393.2, 725.1, 313);
    _expectRect(tester, 'statistics-tile-B2', 1240.8, 393.2, 758.6, 313);
    _expectRect(tester, 'statistics-tile-B3', 485.2, 728.2, 1455.2, 351);
    expect(find.text('인벤토리 · 계획 집계는 항상 전체'), findsOneWidget);
    // FE7-c: B1은 그래프 자리(계정 상태 · 부족 계산이 없으면 '—'), B2 · B3은 "준비 중"(FD-106 사용자 결정 10-13).
    expect(find.text(statisticsTilePendingText), findsNWidgets(2));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('statistics-tile-B1-empty'))).data,
      '—',
    );
    expect(find.text(statisticsInventoryEvidenceEmptyText), findsOneWidget);

    await tester.pumpWidget(_host(StatisticsMode.plan));
    await tester.pumpAndSettle();
    _expectRect(tester, 'statistics-tile-C1', 543.0, 393.2, 749.8, 358);
    _expectRect(tester, 'statistics-tile-C2', 1249.7, 393.2, 749.8, 358);
    _expectRect(tester, 'statistics-tile-C3', 481.5, 773.2, 777.0, 327);
    _expectRect(tester, 'statistics-tile-C4', 1220.8, 773.2, 711.6, 327);
    _expectRect(tester, 'statistics-tile-C5', 422.4, 1122.2, 1448.5, 313);
    expect(find.text('활성 계획 · —명 · 페이즈 —'), findsOneWidget);
    // FE7-c: C1 · C2는 그래프 자리, C3 · C4 · C5는 "준비 중".
    expect(find.text(statisticsTilePendingText), findsNWidgets(3));
    for (final id in ['C1', 'C2']) {
      expect(
        tester.widget<Text>(find.byKey(ValueKey('statistics-tile-$id-empty'))).data,
        '—',
      );
    }
    expect(find.text(statisticsPlanEvidenceEmptyText), findsOneWidget);
  });

  testWidgets('scrolling slides rows along the rail and topics keep their own scroll', (
    tester,
  ) async {
    await _pumpCanvas(tester, StatisticsMode.students);
    final before = tester.getRect(find.byKey(const ValueKey('statistics-tile-A1')));
    await tester.drag(
      find.byKey(const ValueKey('statistics-growth-scroll')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byKey(const ValueKey('statistics-tile-A1')));
    // 시안: 스크롤 범위 90.2px 동안 콘텐츠가 오른쪽으로 15.9px 민다.
    expect(after.top - before.top, closeTo(-90.2, 0.5));
    expect(after.left - before.left, closeTo(15.9, 0.2));

    await tester.pumpWidget(_host(StatisticsMode.inventory));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('statistics-viewport-growth')), findsNothing);
    await tester.pumpWidget(_host(StatisticsMode.students));
    await tester.pumpAndSettle();
    final back = tester.getRect(find.byKey(const ValueKey('statistics-tile-A1')));
    expect(back.topLeft, before.topLeft);
  });

  testWidgets('topic buttons report the chosen topic', (tester) async {
    await tester.binding.setSurfaceSize(_canvas);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final chosen = <StatisticsMode>[];
    await tester.pumpWidget(_host(StatisticsMode.students, onMode: chosen.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statistics-topic-growth')));
    await tester.tap(find.byKey(const ValueKey('statistics-topic-plan')));
    await tester.pump();
    expect(chosen, [StatisticsMode.plan]);
  });

  for (final size in const [Size(1280, 720), Size(800, 600)]) {
    testWidgets('all topics lay out at ${size.width}x${size.height} without overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final mode in StatisticsMode.values) {
        await tester.pumpWidget(_host(mode));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: mode.name);
        expect(
          find.byKey(ValueKey('statistics-viewport-${mode.key}')),
          findsOneWidget,
        );
      }
    });
  }
}
