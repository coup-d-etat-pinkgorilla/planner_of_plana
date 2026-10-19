// FE6-f 인벤토리 이력 연동 위젯 · 컨트롤러 테스트(시안 Inventory KPI · 상세 "최근 변화", Inventory-All 상세, Inventory-Analysis
// S5). 숫자는 검수 fixture(`inventory_fe6a_fixture.dart` · `inventory_fe6c_fixture.dart`)의 이력이고, 시계는 고정이다
// (2026-10-05 12:00 UTC, [AppClockSource]).
// - KPI: +3 지난 스캔 대비 · −1 · 최근 감소 6종 · 마지막 스캔 3일 전, 이력이 없으면 `—`.
// - 상세: 스캔 n회 스파크라인, 순변화 · 이전 스캔 비교 · 소진 예상, 저장 뒤 다시 읽기(수동 수정 = 속 빈 지금 점).
// - 다시 읽기: 탭을 다시 열 때 revision이 같으면 읽지 않고, 바뀌었으면(다른 탭의 쓰기) 다시 읽는다. 이력 revision이 상태와
//   다르거나 읽기에 실패하면 섞어 그리지 않고 안내한다.
// - S5: 1주 · 4주 순증감 상위 6행(증가 → 감소), 이 추세라면 2행, 작은 창.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_controller.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_history_charts.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';
import 'inventory_fe6c_fixture.dart';

const _rio = 'Item_Icon_SecretStone_rio_battle';
const _notes = 'Item_Icon_SkillBook_Gehenna_3';

Widget _subject(
  AppService service, {
  InventoryController? controller,
  bool active = true,
}) => MaterialApp(
  home: Scaffold(
    body: InventoryPage(
      service: service,
      controller: controller,
      onOpenPlan: () {},
      onOpenScan: () {},
      active: active,
    ),
  ),
);

Future<void> _surface(WidgetTester tester, [Size size = const Size(2560, 1392)]) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data;

Finder _inside(String key, String text) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.text(text),
);

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: key);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 이력 events 읽기를 세고, 필요하면 읽기 전에 저장소를 바꾸거나 실패시킨다.
class _HistoryService extends InventoryFixtureService {
  int eventCalls = 0;
  int summaryCalls = 0;
  bool writeBeforeEvents = false;
  Object? failEvents;

  @override
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  ) async {
    eventCalls += 1;
    final failure = failEvents;
    if (failure != null) throw failure;
    if (writeBeforeEvents) {
      writeBeforeEvents = false;
      await externalWrite(this, '11');
    }
    return super.loadRepositoryHistoryEvents(request);
  }

  @override
  Future<RepositoryHistorySummaryResult> loadRepositoryHistorySummary(
    List<String> profileIds,
  ) {
    summaryCalls += 1;
    return super.loadRepositoryHistorySummary(profileIds);
  }
}

/// 다른 탭(스캔 commit 등)이 인벤토리를 쓴 것처럼: 기술 노트(최상급)를 [quantity]로 저장한다.
Future<int> externalWrite(MockAppService service, String quantity) async {
  final state = await service.loadRepositoryState(inventoryFixtureProfileId);
  return service.saveRepositoryInventory(
    inventoryFixtureProfileId,
    RepositoryInventoryState.fromWire({
      'version': 1,
      'entries': [
        for (final entry in state.inventory.entries)
          if (inventoryEntryKey(entry) == _notes)
            {...entry, 'quantity': quantity}
          else
            entry,
      ],
    }),
    state.revision,
    'external-$quantity-${state.revision}',
  );
}

String inventoryEntryKey(Map<String, dynamic> entry) =>
    (entry['item_id'] ?? entry['key']) as String;

void main() {
  group('controller', () {
    test('fe6a fixture: KPI deltas, last scan and sparklines (시안 값)', () async {
      final service = InventoryFixtureService();
      addTearDown(service.dispose);
      final controller = InventoryController(service);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.historyError, isNull);
      expect(controller.history, isNotNull);
      final deltas = controller.kpiDeltas;
      expect(deltas.shortage, 3);
      expect(deltas.excess, -1);
      expect(deltas.decline, 6);
      expect(deltas.lastScanDays, 3);

      final rio = controller.sparklineFor(_rio)!;
      expect([for (final p in rio.points) p.value], [0, 0, 1, 1]);
      expect([for (final p in rio.points) p.label], ['3주 전', '2주 전', '1주 전', '지금']);
      expect(rio.header, '최근 변화 · 스캔 4회');
      expect(rio.summary, '순변화 +1 · 이전 스캔과 이상 없음');

      final notes = controller.sparklineFor(_notes)!;
      expect([for (final p in notes.points) p.value], [31, 24, 18, 12]);
      expect(notes.summary, '순변화 −19 · 2주 뒤 소진 예상');
      expect(notes.warning, isTrue);

      // 스캔하지 않은 재화(보유 모름)는 점이 없다.
      expect(
        controller.sparklineFor('Item_Icon_ExpItem_2')!.points,
        isEmpty,
      );
    });

    test('a manual save re-reads history at the new revision (hollow 지금 point)', () async {
      final service = _HistoryService();
      addTearDown(service.dispose);
      final controller = InventoryController(service);
      addTearDown(controller.dispose);
      await controller.load();
      expect(service.eventCalls, 1);
      final before = controller.repositoryState!.revision;

      expect(await controller.saveQuantity(_notes, '10'), isTrue);
      expect(controller.repositoryState!.revision, before + 1);
      expect(service.eventCalls, 2);
      final notes = controller.sparklineFor(_notes)!;
      expect([for (final p in notes.points) p.value], [31, 24, 18, 12, 10]);
      expect([for (final p in notes.points) p.scan], [true, true, true, true, false]);
      expect(notes.scanCount, 4);
      expect(notes.summary, '순변화 −21 · 2주 뒤 소진 예상');

      // 같은 revision이면 다시 읽지 않는다.
      await controller.refreshIfChanged();
      expect(service.eventCalls, 2);
    });

    test('a history snapshot from another revision is never mixed in', () async {
      final service = _HistoryService()..writeBeforeEvents = true;
      addTearDown(service.dispose);
      final controller = InventoryController(service);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.history, isNull);
      expect(controller.historyError, contains('이력을 맞추지 못했습니다'));
      expect(controller.kpiDeltas.shortage, isNull);
      expect(controller.sparklineFor(_notes), isNull);
      // 다시 열면 revision이 달라 전부 다시 읽고 이번에는 맞는다.
      await controller.refreshIfChanged();
      expect(controller.historyError, isNull);
      expect(controller.history, isNotNull);
      expect(service.eventCalls, 2);
    });

    test('a failed history read keeps the board and reports the error', () async {
      final service = _HistoryService()..failEvents = StateError('boom');
      addTearDown(service.dispose);
      final controller = InventoryController(service);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.board.items, isNotEmpty);
      expect(controller.history, isNull);
      expect(controller.historyError, '변화 기록을 불러오지 못했습니다: Bad state: boom');
      expect(controller.kpiDeltas.lastScanDays, isNull);
    });

    test('fe6c fixture: S5 windows and forecasts', () async {
      final service = InventoryAnalysisFixtureService();
      addTearDown(service.dispose);
      final controller = InventoryController(service);
      addTearDown(controller.dispose);
      await controller.load();
      List<(String, int)> rows() => [
        for (final row in controller.netChanges!.rows)
          (row.view.item.displayName, row.delta),
      ];
      expect(rows(), [
        ('상급 활동 보고서', 120),
        ('로혼치 사본 T1', 36),
        ('밀레니엄 BD (최상급)', 24),
        ('트리니티 기술 노트 (최상급)', -7),
        ('시계 T8 설계도', -9),
        ('게헨나 기술 노트 (최상급)', -14),
      ]);
      controller.setChangeWindow(InventoryChangeWindow.week4);
      expect(rows(), [
        ('상급 활동 보고서', 240),
        ('밀레니엄 BD (최상급)', 30),
        ('로혼치 사본 T1', 28),
        ('밀레니엄 BD (상급)', 21),
        ('게헨나 기술 노트 (최상급)', -23),
        ('트리니티 기술 노트 (최상급)', -29),
      ]);
      expect([for (final row in controller.forecasts) (row.text, row.chip)], [
        ('트리니티 기술 노트 (최상급) 부족이 커지는 중', '4주 뒤 −66'),
        ('밀레니엄 BD (상급)은 곧 충분', '2주 뒤 0'),
      ]);
    });
  });

  group('widgets', () {
    testWidgets('KPI strip and detail sparkline (Inventory)', (tester) async {
      await _surface(tester);
      final service = InventoryFixtureService();
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(_text(tester, 'inventory-kpi-shortage-delta'), '+3 지난 스캔 대비');
      expect(_text(tester, 'inventory-kpi-excess-delta'), '−1');
      expect(_text(tester, 'inventory-kpi-decline'), '6종');
      expect(_text(tester, 'inventory-kpi-last-scan'), '3일 전');
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('inventory-kpi-last-scan')))
            .style
            ?.color,
        const Color(0xffffc66d),
      );

      // 기본 선택 = 리오(무장)의 엘레프.
      expect(find.text('최근 변화 · 스캔 4회'), findsOneWidget);
      expect(
        _text(tester, 'inventory-history-summary'),
        '순변화 +1 · 이전 스캔과 이상 없음',
      );
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('inventory-history-sparkline-paint')),
      );
      final painter = paint.painter! as InventorySparklinePainter;
      expect([for (final p in painter.points) p.value], [0, 0, 1, 1]);
      final size = tester.getSize(
        find.byKey(const ValueKey('inventory-history-sparkline-paint')),
      );
      expect(size.height, InventorySparklineMetrics.height);
      // svg 폭 = 줄 폭 − 70.
      final row = tester.getSize(
        find.byKey(const ValueKey('inventory-history-sparkline')),
      );
      expect(size.width, closeTo(row.width - 70, 0.5));

      // 기술 노트(최상급): 소진 예상은 분홍.
      await _tap(tester, 'inventory-row-$_notes');
      expect(
        _text(tester, 'inventory-history-summary'),
        '순변화 −19 · 2주 뒤 소진 예상',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('inventory-history-summary')))
            .style
            ?.color,
        const Color(0xfff2b3ef),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no history: KPI dashes and empty detail row', (tester) async {
      await _surface(tester);
      final service = InventoryFixtureService(history: false);
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(_text(tester, 'inventory-kpi-shortage-delta'), '— 지난 스캔 대비');
      expect(_text(tester, 'inventory-kpi-excess-delta'), '—');
      expect(_text(tester, 'inventory-kpi-decline'), '—');
      expect(_text(tester, 'inventory-kpi-last-scan'), '—');
      expect(find.byKey(const ValueKey('inventory-history-empty')), findsOneWidget);
      expect(find.text('4주 안에 이 재화를 스캔한 기록이 없습니다.'), findsOneWidget);
      expect(find.byKey(const ValueKey('inventory-history-sparkline')), findsNothing);
    });

    testWidgets('a failed read shows the reason in the detail row', (tester) async {
      await _surface(tester);
      final service = _HistoryService()..failEvents = StateError('boom');
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(
        _inside(
          'inventory-history-empty',
          '변화 기록을 불러오지 못했습니다: Bad state: boom',
        ),
        findsOneWidget,
      );
      expect(_text(tester, 'inventory-kpi-last-scan'), '—');
    });

    testWidgets('re-opening the tab re-reads only after an outside write', (tester) async {
      await _surface(tester);
      final service = _HistoryService();
      addTearDown(service.dispose);
      final controller = InventoryController(service);
      addTearDown(controller.dispose);
      var active = true;
      late StateSetter setActive;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setActive = setState;
            return _subject(service, controller: controller, active: active);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(service.eventCalls, 1);
      final revision = controller.repositoryState!.revision;

      Future<void> reopen() async {
        setActive(() => active = false);
        await tester.pumpAndSettle();
        setActive(() => active = true);
        await tester.pumpAndSettle();
      }

      await reopen();
      expect(service.summaryCalls, 1);
      expect(service.eventCalls, 1);

      // 다른 탭(스캔 commit 등)이 쓴 뒤 다시 열면 상태 · 이력을 다시 읽는다.
      await tester.runAsync(() => externalWrite(service, '11'));
      await reopen();
      expect(service.summaryCalls, 2);
      expect(service.eventCalls, 2);
      expect(controller.repositoryState!.revision, revision + 1);
      expect(
        [for (final p in controller.sparklineFor(_notes)!.points) p.value],
        [31, 24, 18, 12, 11],
      );
    });

    testWidgets('S5: 1주 rows, diverging bars, forecasts; 4주; small window', (tester) async {
      await _surface(tester);
      final service = InventoryAnalysisFixtureService();
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      await _tap(tester, 'inventory-mode-analysis');

      expect(find.byKey(const ValueKey('inventory-analysis-changes-empty')), findsNothing);
      expect(_text(tester, 'inventory-change-caption'), '주간 순증감 상위 (오른쪽 증가 · 왼쪽 감소)');
      const names = [
        '상급 활동 보고서',
        '로혼치 사본 T1',
        '밀레니엄 BD (최상급)',
        '트리니티 기술 노트 (최상급)',
        '시계 T8 설계도',
        '게헨나 기술 노트 (최상급)',
      ];
      for (final (index, name) in names.indexed) {
        expect(_inside('inventory-change-row-$index', name), findsOneWidget);
      }
      expect(
        _inside('inventory-change-bar-Item_Icon_ExpItem_2', '+120'),
        findsOneWidget,
      );
      expect(
        _inside('inventory-change-bar-Item_Icon_SkillBook_Gehenna_3', '−14'),
        findsOneWidget,
      );
      // 가장 긴 막대 156px, 증가는 축 오른쪽 · 감소는 축 왼쪽.
      final axis = tester.getRect(find.byKey(const ValueKey('inventory-change-axis')));
      Rect bar(String key) => tester.getRect(
        find.descendant(
          of: find.byKey(ValueKey('inventory-change-bar-$key')),
          matching: find.byType(DecoratedBox),
        ),
      );
      final up = bar('Item_Icon_ExpItem_2');
      final down = bar('Item_Icon_SkillBook_Gehenna_3');
      expect(up.width, closeTo(156, 0.01));
      expect(up.left, closeTo(axis.left, 0.01));
      expect(down.width, closeTo(156 * 14 / 120, 0.01));
      expect(down.right, closeTo(axis.left - 2, 0.01));
      // 행 y는 34 간격, 막대 칸은 사선을 따라 밀리지 않는다.
      final first = tester.getRect(find.byKey(const ValueKey('inventory-change-bar-Item_Icon_ExpItem_2')));
      final last = tester.getRect(
        find.byKey(const ValueKey('inventory-change-bar-Item_Icon_SkillBook_Gehenna_3')),
      );
      expect(last.top - first.top, closeTo(34 * 5, 0.01));
      expect(last.left, first.left);

      expect(find.text('이 추세라면'), findsOneWidget);
      expect(
        _inside('inventory-forecast-0', '트리니티 기술 노트 (최상급) 부족이 커지는 중'),
        findsOneWidget,
      );
      expect(_inside('inventory-forecast-0', '4주 뒤 −66'), findsOneWidget);
      expect(_inside('inventory-forecast-1', '밀레니엄 BD (상급)은 곧 충분'), findsOneWidget);
      expect(_inside('inventory-forecast-1', '2주 뒤 0'), findsOneWidget);

      final segment = find.descendant(
        of: find.byKey(const ValueKey('inventory-change-window')),
        matching: find.text('4주'),
      );
      await tester.tap(segment);
      await tester.pumpAndSettle();
      expect(_text(tester, 'inventory-change-caption'), '4주 순증감 상위 (오른쪽 증가 · 왼쪽 감소)');
      expect(_inside('inventory-change-row-0', '상급 활동 보고서'), findsOneWidget);
      expect(_inside('inventory-change-bar-Item_Icon_ExpItem_2', '+240'), findsOneWidget);
      expect(
        tester.widget<SkewSegmented<InventoryChangeWindow>>(
          find.byKey(const ValueKey('inventory-change-window')),
        ).selected,
        InventoryChangeWindow.week4,
      );

      await tester.binding.setSurfaceSize(const Size(1280, 720));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('S5 without history keeps the empty notice', (tester) async {
      await _surface(tester);
      final service = InventoryAnalysisFixtureService(history: false);
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      await _tap(tester, 'inventory-mode-analysis');
      expect(find.byKey(const ValueKey('inventory-analysis-changes-empty')), findsOneWidget);
      expect(find.text('변화 기록이 아직 없습니다.'), findsOneWidget);
      expect(find.text('이 추세라면'), findsNothing);
    });
  });
}
