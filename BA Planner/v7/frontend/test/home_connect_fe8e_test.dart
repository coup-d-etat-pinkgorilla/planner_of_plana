import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/home/connect_target_panel.dart';
import 'package:ba_planner_v7/ui/home/home_menu_swap.dart';
import 'package:ba_planner_v7/ui/pages/home_page.dart';
import 'package:ba_planner_v7/ui/scan/connected_target_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _game = ScannerTarget(
  id: 'ba-window',
  title: 'Blue Archive',
  status: ScannerTargetStatus.ready,
  foreground: true,
  clientWidth: 2560,
  clientHeight: 1440,
  game: ScannerTargetGame.blueArchive,
);

const _planner = ScannerTarget(
  id: 'planner',
  title: 'BA Planner v7',
  status: ScannerTargetStatus.ready,
  clientWidth: 1456,
  clientHeight: 819,
);

const _minimized = ScannerTarget(
  id: 'minimized',
  title: 'Blue Archive (최소화)',
  status: ScannerTargetStatus.minimized,
  game: ScannerTargetGame.blueArchive,
);

const _closed = ScannerTarget(
  id: 'closed',
  title: '닫힌 창',
  status: ScannerTargetStatus.closed,
);

const _unsupported = ScannerTarget(
  id: 'unsupported',
  title: '알 수 없는 창',
  status: ScannerTargetStatus.unsupported,
);

const _unknownSize = ScannerTarget(
  id: 'unknown-size',
  title: '크기 모름',
  status: ScannerTargetStatus.ready,
);

final _longTitle = ScannerTarget(
  id: 'long',
  title: '아주 긴 창 제목 ' * 12,
  status: ScannerTargetStatus.ready,
  clientWidth: 1920,
  clientHeight: 1080,
);

/// 테스트가 정한 창 목록을 내는 Mock.
class _TargetListMock extends MockAppService {
  _TargetListMock(this.targets);

  List<ScannerTarget> targets;
  int listCalls = 0;

  @override
  Future<List<ScannerTarget>> listScannerTargets() async {
    listCalls += 1;
    return targets;
  }
}

class _HomeHarness {
  _HomeHarness(this.service)
    : controller = ConnectedTargetController.forService(
        service,
        pollInterval: Duration.zero,
      );

  final MockAppService service;
  final ConnectedTargetController controller;
  final opened = <AppSection>[];
  var request = 0;

  void dispose() {
    controller.dispose();
    service.dispose();
  }

  /// 기준 viewport(2560×1392)의 머리글 아래(y=184) 콘텐츠 영역에 홈만 그린다.
  Widget build() => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 184),
          Expanded(
            child: HomePage(
              service: service,
              onOpen: opened.add,
              connectedTarget: controller,
              openTargetPickerRequest: request,
            ),
          ),
        ],
      ),
    ),
  );
}

Finder get _panel => find.byKey(const ValueKey('home-connect-panel'));
Finder _row(String id) => find.byKey(ValueKey('home-connect-panel-row-$id'));

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data;

Finder _featuredCaption(String caption) => find.descendant(
  of: find.byKey(const ValueKey('home-menu-scan')),
  matching: find.text(caption),
);

double _menuShift(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('home-menu-swap')))
    .transform
    .getTranslation()
    .x;

void _expectRect(Rect actual, Rect expected, {double tolerance = 1}) {
  expect(actual.left, closeTo(expected.left, tolerance), reason: 'left');
  expect(actual.top, closeTo(expected.top, tolerance), reason: 'top');
  expect(actual.width, closeTo(expected.width, tolerance), reason: 'width');
  expect(actual.height, closeTo(expected.height, tolerance), reason: 'height');
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('menu swap timeline', () {
    test('connect follows the Home-Connect-Effect keyframes', () {
      const timeline = HomeMenuSwapTimeline.connect;
      Duration ms(int value) => Duration(milliseconds: value);
      expect(timeline.total, ms(2800));
      // 시안 1.8s = 0. 2.05s 예비동작 끝 +14, 2.7s 퇴장 끝 −820, 2.75s 교체, 2.8s 진입 시작.
      expect(timeline.menuOffset(Duration.zero), 0);
      expect(timeline.menuOffset(ms(250)), closeTo(14, 1e-9));
      expect(timeline.menuOffset(ms(900)), closeTo(-820, 1e-9));
      expect(timeline.menuOffset(ms(980)), -820);
      expect(timeline.swapped(ms(949)), isFalse);
      expect(timeline.swapped(ms(950)), isTrue);
      // 3.6s 진입 끝 −10, 4.0s 안착 0.
      expect(timeline.menuOffset(ms(1800)), closeTo(-10, 1e-9));
      expect(timeline.menuOffset(ms(2200)), 0);
      expect(timeline.menuOffset(ms(2800)), 0);
      // flash: 3.8s부터 4.0s 최대, 4.6s 끝.
      expect(timeline.flashOpacity(ms(2000)), 0);
      expect(timeline.flashOpacity(ms(2100)), inExclusiveRange(0, 1));
      expect(timeline.flashOpacity(ms(2200)), closeTo(1, 1e-9));
      expect(timeline.flashOpacity(ms(2500)), inExclusiveRange(0, 1));
      expect(timeline.flashOpacity(ms(2800)), 0);
      // 패널: 2.0s부터 2.7s까지 +820, 그 뒤 숨김.
      expect(timeline.panelOffset(ms(200)), 0);
      expect(timeline.panelOffset(ms(900)), closeTo(820, 1e-9));
      expect(timeline.panelGone(ms(899)), isFalse);
      expect(timeline.panelGone(ms(900)), isTrue);
    });

    test('release reverses without flash or panel', () {
      const timeline = HomeMenuSwapTimeline.release;
      Duration ms(int value) => Duration(milliseconds: value);
      // 시안 7.0s = 0: 7.25 +14, 7.9 −820, 7.95 교체, 8.8 −10, 9.2 안착.
      expect(timeline.total, ms(2200));
      expect(timeline.menuOffset(ms(250)), closeTo(14, 1e-9));
      expect(timeline.menuOffset(ms(900)), closeTo(-820, 1e-9));
      expect(timeline.swapped(ms(950)), isTrue);
      expect(timeline.menuOffset(ms(1800)), closeTo(-10, 1e-9));
      expect(timeline.menuOffset(ms(2200)), 0);
      for (var value = 0; value <= 2200; value += 100) {
        expect(timeline.flashOpacity(ms(value)), 0);
        expect(timeline.panelOffset(ms(value)), 0);
      }
    });
  });

  group('home window picker panel', () {
    testWidgets('featured button opens the attached panel at the draft rect', (
      tester,
    ) async {
      await _setSurface(tester, const Size(2560, 1392));
      final harness = _HomeHarness(
        _TargetListMock([_game, _planner, _unknownSize]),
      );
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);

      await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
      await tester.pump();
      // intro 180°: 오른쪽 밖에서 들어온다.
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getRect(_panel).left, greaterThan(1822.5 + 1));
      await tester.pumpAndSettle();

      expect(harness.opened, isEmpty);
      // 시안 패널 1822.5,202 719.5×1018, 메뉴 18,202 742×1018.
      _expectRect(
        tester.getRect(_panel),
        const Rect.fromLTWH(1822.5, 202, 719.5, 1018),
      );
      _expectRect(
        tester.getRect(find.byKey(const ValueKey('home-menu-section'))),
        const Rect.fromLTWH(18, 202, 742, 1018),
      );
      // 첫 행 1990.7,364 493.3×38, 둘째 행 1983.0,408 501.0×38(왼쪽 끝이 사선을 따라감).
      _expectRect(
        tester.getRect(_row('ba-window')),
        const Rect.fromLTWH(1990.7, 364, 493.3, 38),
      );
      _expectRect(
        tester.getRect(_row('planner')),
        const Rect.fromLTWH(1983.0, 408, 501.0, 38),
      );
      // 버튼: 새로고침 1851.8,1134 200×56 / 취소 2150 130×56 / 선택한 창 사용 2292 220×56.
      _expectRect(
        tester.getRect(
          find.byKey(const ValueKey('home-connect-panel-refresh')),
        ),
        const Rect.fromLTWH(1851.8, 1134, 200, 56),
      );
      _expectRect(
        tester.getRect(find.byKey(const ValueKey('home-connect-panel-cancel'))),
        const Rect.fromLTWH(2150, 1134, 130, 56),
      );
      _expectRect(
        tester.getRect(find.byKey(const ValueKey('home-connect-panel-use'))),
        const Rect.fromLTWH(2292, 1134, 220, 56),
      );

      // 상태 줄: 선택 예정 = 첫 게임 창, 현재 선택 없음. 행1 분홍 선택 선.
      expect(_text(tester, 'home-connect-panel-planned'), 'Blue Archive');
      expect(_text(tester, 'home-connect-panel-current'), '현재 선택: 없음');
      expect(
        find.byKey(const ValueKey('home-menu-featured-selected')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row('ba-window'), matching: find.text('BA')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row('planner'), matching: find.text('BA')),
        findsNothing,
      );
      expect(
        find.descendant(of: _row('ba-window'), matching: find.text('2560×1440')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row('unknown-size'), matching: find.text('—')),
        findsOneWidget,
      );

      // 취소 → outro 0°, 선택 선도 사라진다. 연결은 그대로 없음.
      await tester.tap(find.byKey(const ValueKey('home-connect-panel-cancel')));
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
      expect(
        find.byKey(const ValueKey('home-menu-featured-selected')),
        findsNothing,
      );
      expect(harness.controller.target, isNull);
    });

    testWidgets('window states show in the size column and closed is inert', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1280, 720));
      final service = _TargetListMock([
        _planner,
        _closed,
        _minimized,
        _unsupported,
        _longTitle,
        _game,
      ]);
      final harness = _HomeHarness(service);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(
        find.descendant(of: _row('minimized'), matching: find.text('최소화됨')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row('closed'), matching: find.text('닫힘')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _row('unsupported'), matching: find.text('미지원')),
        findsOneWidget,
      );
      // 선택 예정: 닫히지 않은 첫 게임 창(최소화도 고를 수 있다).
      expect(
        _text(tester, 'home-connect-panel-planned'),
        'Blue Archive (최소화)',
      );

      await tester.tap(_row('closed'));
      await tester.pump();
      expect(
        _text(tester, 'home-connect-panel-planned'),
        'Blue Archive (최소화)',
      );

      // 긴 제목은 한 줄 말줄임이다.
      final longTitle = tester.widget<Text>(
        find.descendant(of: _row('long'), matching: find.byType(Text)).at(1),
      );
      expect(longTitle.maxLines, 1);
      expect(longTitle.overflow, TextOverflow.ellipsis);

      await tester.tap(_row('planner'));
      await tester.pump();
      expect(_text(tester, 'home-connect-panel-planned'), 'BA Planner v7');

      // 새로고침은 목록을 다시 읽는다.
      final before = service.listCalls;
      await tester.tap(
        find.byKey(const ValueKey('home-connect-panel-refresh')),
      );
      await tester.pumpAndSettle();
      expect(service.listCalls, before + 1);
      expect(_text(tester, 'home-connect-panel-planned'), 'BA Planner v7');
      expect(tester.takeException(), isNull);
    });

    testWidgets('rows follow the rail while the list scrolls', (tester) async {
      await _setSurface(tester, const Size(2560, 1392));
      final targets = [
        for (var index = 0; index < 30; index++)
          ScannerTarget(
            id: 'w$index',
            title: '창 $index',
            status: ScannerTargetStatus.ready,
            clientWidth: 1280,
            clientHeight: 720,
          ),
      ];
      final harness = _HomeHarness(_TargetListMock(targets));
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
      await tester.pumpAndSettle();

      final first = tester.getRect(_row('w0'));
      final second = tester.getRect(_row('w1'));
      // 피치 44마다 왼쪽 끝이 44/tan80 ≈ 7.76 왼쪽으로, 오른쪽 끝은 2484 고정.
      expect(first.left - second.left, closeTo(7.76, 0.05));
      expect(first.right, closeTo(2484, 1));
      expect(second.right, closeTo(2484, 1));
      expect(
        find.byKey(const ValueKey('home-connect-panel-diagonal-scrollbar')),
        findsOneWidget,
      );

      await tester.drag(
        find.byKey(const ValueKey('home-connect-panel-list')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      final scrolled = tester.getRect(_row('w5'));
      // 위로 올라온 행은 그 높이의 사선 자리로 오른쪽에 붙는다.
      expect(
        scrolled.left,
        closeTo(
          1822.5 +
              ConnectTargetPanel.edgeX(scrolled.bottom - 202) +
              ConnectTargetPanel.rowEdgeInset,
          0.5,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('using a window plays the connect swap and the release', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1280, 720));
      final harness = _HomeHarness(_TargetListMock([_planner, _game]));
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final scale =
          tester
              .getSize(find.byKey(const ValueKey('home-menu-section')))
              .height /
          1018;

      await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
      await tester.pump();
      expect(harness.controller.target?.id, 'ba-window');

      const total = 2800;
      // 예비동작 끝(+14), 교체 전 A, 0.25·0.5·0.75 지점에서 넘침 없음.
      await tester.pump(const Duration(milliseconds: 250));
      expect(_menuShift(tester), closeTo(14, 0.5));
      expect(_featuredCaption('싯딤의 상자와 연결'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: total ~/ 4 - 250));
      expect(_featuredCaption('싯딤의 상자와 연결'), findsOneWidget);
      expect(_panel, findsOneWidget);
      expect(tester.takeException(), isNull);
      // 0.5 지점(1.4s): 교체 뒤 B가 왼쪽에서 들어오는 중, 패널은 빠졌다.
      await tester.pump(const Duration(milliseconds: total ~/ 4));
      expect(_featuredCaption('스캔'), findsOneWidget);
      expect(_featuredCaption('싯딤의 상자와 연결'), findsNothing);
      expect(_panel, findsNothing);
      expect(_menuShift(tester), lessThan(-10));
      expect(tester.takeException(), isNull);
      // 0.75 지점(2.1s): 안착 중, flash가 차오른다.
      await tester.pump(const Duration(milliseconds: total ~/ 4));
      final flash = tester.widget<Opacity>(
        find.byKey(const ValueKey('home-menu-featured-flash')),
      );
      expect(flash.opacity, inExclusiveRange(0, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(_menuShift(tester), 0);
      expect(
        find.byKey(const ValueKey('home-menu-featured-flash')),
        findsNothing,
      );
      expect(scale, greaterThan(0));

      // 연결된 뒤 `스캔`은 스캔 팝업(FE8-f3) 전까지 스캔 탭으로 간다.
      await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
      await tester.pump();
      expect(harness.opened, [AppSection.scan]);

      // 해제(B → A): flash 없이 역연출.
      harness.controller.disconnect();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_menuShift(tester), closeTo(14, 0.5));
      expect(_featuredCaption('스캔'), findsOneWidget);
      for (var step = 0; step < 20; step++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.byKey(const ValueKey('home-menu-featured-flash')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(_featuredCaption('싯딤의 상자와 연결'), findsOneWidget);
      expect(harness.controller.lastRelease, ConnectedTargetRelease.user);
    });

    testWidgets('choosing another window while connected only closes', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1440, 900));
      final harness = _HomeHarness(_TargetListMock([_game, _planner]));
      addTearDown(harness.dispose);
      harness.controller.connect(_game);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      expect(_featuredCaption('스캔'), findsOneWidget);

      // 셸 요청(머리글 칩)으로 연다. 현재 선택 = 연결된 창, 선택 예정도 그 창.
      harness.request += 1;
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      expect(_panel, findsOneWidget);
      expect(_text(tester, 'home-connect-panel-current'), '현재 선택: Blue Archive');
      expect(_text(tester, 'home-connect-panel-planned'), 'Blue Archive');
      // 연결된 메뉴(B)에는 분홍 선택 선을 두지 않는다.
      expect(
        find.byKey(const ValueKey('home-menu-featured-selected')),
        findsNothing,
      );

      await tester.tap(_row('planner'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
      await tester.pump();
      expect(harness.controller.target?.id, 'planner');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_menuShift(tester), 0);
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
      expect(_featuredCaption('스캔'), findsOneWidget);
    });

    testWidgets('without a backend the panel says so and cannot connect', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1440, 900));
      final service = _TargetListMock([_game]);
      service.setConnection(BackendConnection.disconnected);
      final harness = _HomeHarness(service);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
      await tester.pumpAndSettle();
      expect(
        _text(tester, 'home-connect-panel-message'),
        '백엔드에 연결되어 있지 않습니다.',
      );
      expect(_text(tester, 'home-connect-panel-planned'), '—');
      await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
      await tester.pump();
      expect(harness.controller.target, isNull);
      expect(service.listCalls, 0);
    });
  });

  group('app shell', () {
    testWidgets('the header chip opens the home panel from another tab', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1440, 900));
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('top-tab-students')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('header-connection-chip-button')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
      expect(_panel, findsOneWidget);
      expect(tester.takeException(), isNull);

      // 패널에서 고르면 연결 연출 뒤 머리글 칩이 녹색, 메뉴 첫 버튼이 `스캔`이다.
      await tester.tap(_row('mock-window'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
      expect(_featuredCaption('스캔'), findsOneWidget);
      final chip = tester.widget<Text>(
        find.byKey(const ValueKey('header-connection-chip-label')),
      );
      expect(chip.data, '연결됨 · Blue Archive');
      expect(chip.style?.color, AppColors.success);

      await tester.tap(find.byKey(const ValueKey('home-menu-scan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scan-page')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('header metrics are bare numbers', (tester) async {
      await _setSurface(tester, const Size(1440, 900));
      final service = MockAppService(
        initialState: const AppServiceState(
          connection: BackendConnection.connected,
          scanPhase: ScanPhase.idle,
          imageLoadState: ImageLoadState.loaded,
          studentCount: 217,
          inventoryItemCount: 1284,
          hasData: true,
          scanAvailable: true,
          useLongNames: false,
          hasMissingMetadata: false,
        ),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();
      expect(find.text('217'), findsOneWidget);
      expect(find.text('1,284'), findsOneWidget);
      expect(find.text('217명'), findsNothing);
      expect(find.text('1284개'), findsNothing);
    });
  });
}
