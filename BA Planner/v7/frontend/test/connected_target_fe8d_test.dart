import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:ba_planner_v7/ui/scan/connected_target_controller.dart';
import 'package:ba_planner_v7/ui/scan/header_connection_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ready = ScannerTarget(
  id: 'ba-window',
  title: 'Blue Archive',
  status: ScannerTargetStatus.ready,
  foreground: true,
  clientWidth: 2560,
  clientHeight: 1440,
  game: ScannerTargetGame.blueArchive,
);

const _other = ScannerTarget(
  id: 'other-window',
  title: 'Blue Archive (2)',
  status: ScannerTargetStatus.ready,
  clientWidth: 1920,
  clientHeight: 1080,
  game: ScannerTargetGame.blueArchive,
);

ScannerTarget _copy(
  ScannerTarget target, {
  ScannerTargetStatus? status,
  int? clientWidth,
  int? clientHeight,
}) => ScannerTarget(
  id: target.id,
  title: target.title,
  status: status ?? target.status,
  foreground: target.foreground,
  clientWidth: clientWidth ?? target.clientWidth,
  clientHeight: clientHeight ?? target.clientHeight,
  game: target.game,
);

const _baseState = AppServiceState(
  connection: BackendConnection.connected,
  scanPhase: ScanPhase.idle,
  imageLoadState: ImageLoadState.loaded,
  studentCount: 0,
  inventoryItemCount: 0,
  hasData: true,
  scanAvailable: true,
  useLongNames: false,
  hasMissingMetadata: false,
);

/// 창 목록을 테스트가 바꿀 수 있는 Mock(그 밖의 동작은 [MockAppService]와 같다).
class _TargetListMock extends MockAppService {
  _TargetListMock() : super();

  List<ScannerTarget> targets = const [_ready];
  int listCalls = 0;

  @override
  Future<List<ScannerTarget>> listScannerTargets() async {
    listCalls += 1;
    return targets;
  }
}

Finder get _chipLabel =>
    find.byKey(const ValueKey('header-connection-chip-label'));

String _chipText(WidgetTester tester) =>
    tester.widget<Text>(_chipLabel).data ?? '';

Color? _chipColor(WidgetTester tester) =>
    tester.widget<Text>(_chipLabel).style?.color;

Future<void> _pickTargetInScanTab(WidgetTester tester, String text) async {
  await tester.tap(find.byKey(const ValueKey('top-tab-scan')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('scan-target')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(text).last);
  await tester.pumpAndSettle();
}

String? _scanDropdownValue(WidgetTester tester) => tester
    .widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('scan-target'), skipOffstage: false),
    )
    .initialValue;

void main() {
  group('header connection chip state', () {
    test('connected label shows game name and client size', () {
      expect(connectedTargetLabel(_ready), '연결됨 · Blue Archive · 2560×1440');
      expect(
        connectedTargetLabel(
          const ScannerTarget(
            id: 'unknown-game',
            title: 'Window',
            status: ScannerTargetStatus.ready,
            clientWidth: 1600,
            clientHeight: 900,
          ),
        ),
        '연결됨 · 1600×900',
      );
      expect(
        connectedTargetLabel(
          const ScannerTarget(
            id: 'minimized',
            title: 'Blue Archive',
            status: ScannerTargetStatus.minimized,
            game: ScannerTargetGame.blueArchive,
          ),
        ),
        '연결됨 · Blue Archive · —',
      );
      // 폭만 알거나 둘 다 모르면 크기는 '—'다(0으로 채우지 않는다).
      expect(
        connectedTargetLabel(
          const ScannerTarget(
            id: 'width-only',
            title: 'Window',
            status: ScannerTargetStatus.ready,
            clientWidth: 2560,
          ),
        ),
        '연결됨 · —',
      );
      // 머리글 칩은 크기를 빼고 쓴다(시안 머리글 `연결됨 · Blue Archive`, FE8-e).
      expect(
        connectedTargetLabel(_ready, includeSize: false),
        '연결됨 · Blue Archive',
      );
      expect(
        connectedTargetLabel(
          const ScannerTarget(
            id: 'unknown-game',
            title: 'Window',
            status: ScannerTargetStatus.ready,
            clientWidth: 1600,
            clientHeight: 900,
          ),
          includeSize: false,
        ),
        '연결됨',
      );
    });

    test('backend loss outranks the game window connection', () {
      final down = HeaderConnectionChipState.resolve(
        BackendConnection.disconnected,
        _ready,
      );
      expect(down.kind, HeaderConnectionKind.backendDisconnected);
      expect(down.label, '백엔드 끊김');
      expect(down.foreground, AppColors.danger);
      expect(down.opensTargetPicker, isFalse);

      final connecting = HeaderConnectionChipState.resolve(
        BackendConnection.connecting,
        null,
      );
      expect(connecting.kind, HeaderConnectionKind.backendConnecting);
      expect(connecting.label, '백엔드 연결 중');
      expect(connecting.foreground, AppColors.warning);

      final idle = HeaderConnectionChipState.resolve(
        BackendConnection.connected,
        null,
      );
      expect(idle.kind, HeaderConnectionKind.targetDisconnected);
      expect(idle.label, '연결 안 됨');
      // 시안 미연결 칩: 글자 #c3cfdb, 점 #9eb0c2, 채움 .12, 안쪽 선 .45.
      expect(idle.foreground, const Color(0xffc3cfdb));
      expect(idle.dot, const Color(0xff9eb0c2));
      expect(idle.background, const Color(0xff9eb0c2).withValues(alpha: 0.12));
      expect(idle.outline, const Color(0xff9eb0c2).withValues(alpha: 0.45));
      expect(idle.opensTargetPicker, isTrue);

      final connected = HeaderConnectionChipState.resolve(
        BackendConnection.connected,
        _ready,
      );
      expect(connected.kind, HeaderConnectionKind.targetConnected);
      expect(connected.label, '연결됨 · Blue Archive');
      // 시안 연결됨 칩: #58d6a7, 채움 .12, 안쪽 선 .55.
      expect(connected.foreground, const Color(0xff58d6a7));
      expect(connected.dot, const Color(0xff58d6a7));
      expect(
        connected.background,
        const Color(0xff58d6a7).withValues(alpha: 0.12),
      );
      expect(
        connected.outline,
        const Color(0xff58d6a7).withValues(alpha: 0.55),
      );
    });

    testWidgets('chip text stays on one line inside a narrow slot', (
      tester,
    ) async {
      final backend = ValueNotifier(_baseState);
      addTearDown(backend.dispose);
      final controller = ConnectedTargetController(
        backendState: backend,
        pollInterval: Duration.zero,
      );
      addTearDown(controller.dispose);
      controller.connect(_ready);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 120,
              child: Row(
                children: [
                  Flexible(
                    child: HeaderConnectionChip(
                      backend: BackendConnection.connected,
                      connectedTarget: controller,
                      onOpenTargetPicker: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final label = tester.widget<Text>(_chipLabel);
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSize(find.byKey(const ValueKey('header-connection-chip'))),
        isA<Size>().having(
          (size) => size.width,
          'width',
          lessThanOrEqualTo(120),
        ),
      );
    });
  });

  group('connected target controller', () {
    test('state transitions follow FD-116 (a)', () {
      final backend = ValueNotifier(_baseState);
      addTearDown(backend.dispose);
      final controller = ConnectedTargetController(
        backendState: backend,
        pollInterval: Duration.zero,
      );
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      // 미연결 → 고름 → 연결됨.
      expect(controller.target, isNull);
      controller.connect(_ready);
      expect(controller.target?.id, 'ba-window');
      expect(controller.isConnected, isTrue);
      expect(notifications, 1);

      // 같은 창을 다시 고르면 바뀌지 않는다.
      controller.connect(_ready);
      expect(notifications, 1);

      // 최소화는 해제가 아니라 창 정보만 바뀐다(크기 모름).
      final minimized = ScannerTarget(
        id: _ready.id,
        title: _ready.title,
        status: ScannerTargetStatus.minimized,
        foreground: false,
        game: _ready.game,
      );
      controller.updateTargets([_other, minimized]);
      expect(controller.target?.status, ScannerTargetStatus.minimized);
      expect(controller.target?.hasClientSize, isFalse);
      expect(controller.lastRelease, isNull);
      expect(notifications, 2);

      // 목록이 같으면 알리지 않는다.
      controller.updateTargets([_other, minimized]);
      expect(notifications, 2);

      // 창이 닫힘 → 해제.
      controller.updateTargets([
        _copy(_ready, status: ScannerTargetStatus.closed),
      ]);
      expect(controller.target, isNull);
      expect(controller.lastRelease, ConnectedTargetRelease.targetClosed);

      // 다시 고르면 해제 사유가 지워진다. 목록에서 사라짐 → 해제.
      controller.connect(_ready);
      expect(controller.lastRelease, isNull);
      controller.updateTargets(const [_other]);
      expect(controller.target, isNull);
      expect(controller.lastRelease, ConnectedTargetRelease.targetMissing);

      // 다른 창으로 바꾸고 사용자 해제.
      controller.connect(_ready);
      controller.connect(_other);
      expect(controller.target?.id, 'other-window');
      controller.disconnect();
      expect(controller.target, isNull);
      expect(controller.lastRelease, ConnectedTargetRelease.user);

      // 백엔드 끊김(재시작 포함) → 해제. 다시 붙어도 연결은 돌아오지 않는다.
      controller.connect(_ready);
      backend.value = _baseState.copyWith(
        connection: BackendConnection.disconnected,
      );
      expect(controller.target, isNull);
      expect(
        controller.lastRelease,
        ConnectedTargetRelease.backendDisconnected,
      );
      backend.value = _baseState.copyWith(
        connection: BackendConnection.connecting,
      );
      backend.value = _baseState;
      expect(controller.target, isNull);

      // 미연결 상태의 목록 갱신·해제는 아무것도 하지 않는다.
      final before = notifications;
      controller.updateTargets(const [_ready]);
      controller.disconnect();
      expect(notifications, before);
    });

    testWidgets('periodic check runs only while connected', (tester) async {
      final backend = ValueNotifier(_baseState);
      addTearDown(backend.dispose);
      var calls = 0;
      var targets = const <ScannerTarget>[_ready];
      Object? failure;
      final controller = ConnectedTargetController(
        backendState: backend,
        listTargets: () async {
          calls += 1;
          final error = failure;
          if (error != null) throw error;
          return targets;
        },
        pollInterval: const Duration(seconds: 5),
      );
      addTearDown(controller.dispose);

      await tester.pump(const Duration(seconds: 12));
      expect(calls, 0, reason: '미연결이면 목록을 읽지 않는다');

      controller.connect(_ready);
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 1);
      expect(controller.target?.id, 'ba-window');

      // 목록 읽기 실패는 연결을 바꾸지 않는다.
      failure = StateError('list failed');
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 2);
      expect(controller.target?.id, 'ba-window');

      // 백엔드가 끊긴 동안은 읽지 않는다(끊김이 이미 해제했다).
      failure = null;
      backend.value = _baseState.copyWith(
        connection: BackendConnection.disconnected,
      );
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 2);
      expect(controller.target, isNull);

      // 다시 연결 → 창이 사라지면 다음 확인에서 해제되고 확인을 멈춘다.
      backend.value = _baseState;
      controller.connect(_ready);
      targets = const [_other];
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 3);
      expect(controller.target, isNull);
      expect(controller.lastRelease, ConnectedTargetRelease.targetMissing);
      await tester.pump(const Duration(seconds: 15));
      expect(calls, 3);
    });
  });

  group('app shell', () {
    testWidgets('scan tab choice drives the header chip on every tab', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();

      expect(_chipText(tester), '연결 안 됨');
      expect(_chipColor(tester), AppColors.textSecondary);

      await _pickTargetInScanTab(tester, 'mock-window');
      expect(_chipText(tester), '연결됨 · Blue Archive');
      expect(_chipColor(tester), AppColors.success);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('top-tab-home')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
      expect(_chipText(tester), '연결됨 · Blue Archive');
      expect(tester.takeException(), isNull);

      // 칩을 누르면 홈의 창 선택 패널이 열린다(FE8-e). 현재 선택은 연결된 창이다.
      await tester.tap(
        find.byKey(const ValueKey('header-connection-chip-button')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-connect-panel')), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('home-connect-panel-current')),
            )
            .data,
        '현재 선택: Mock Blue Archive',
      );
      expect(_scanDropdownValue(tester), 'mock-window');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a target written elsewhere is the scan selection too', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();

      // 홈의 창 선택 패널(FE8-e)이 쓸 경로: 셸이 스캔 화면에 준 같은 컨트롤러에 쓴다.
      final controller = tester
          .widget<ScanPage>(find.byType(ScanPage, skipOffstage: false))
          .connectedTarget;
      expect(controller, isNotNull);
      controller!.connect(
        const ScannerTarget(
          id: 'mock-window',
          title: 'Mock Blue Archive',
          status: ScannerTargetStatus.ready,
          foreground: true,
          clientWidth: 2560,
          clientHeight: 1440,
          game: ScannerTargetGame.blueArchive,
        ),
      );
      await tester.pumpAndSettle();
      expect(_chipText(tester), '연결됨 · Blue Archive');

      await tester.tap(find.byKey(const ValueKey('top-tab-scan')));
      await tester.pumpAndSettle();
      expect(_scanDropdownValue(tester), 'mock-window');
      final start = tester.widget<FilledButton>(
        find.byKey(const ValueKey('scan-start')),
      );
      expect(start.onPressed, isNotNull);

      controller.disconnect();
      await tester.pumpAndSettle();
      expect(_scanDropdownValue(tester), isNull);
      expect(_chipText(tester), '연결 안 됨');
    });

    testWidgets('a vanished window and a lost backend release the target', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _TargetListMock();
      addTearDown(service.dispose);
      await tester.pumpWidget(BAPlannerApp(service: service));
      await tester.pumpAndSettle();

      await _pickTargetInScanTab(tester, 'ba-window');
      expect(_chipText(tester), '연결됨 · Blue Archive');

      // 창이 목록에서 사라짐 → 다음 주기 확인에서 미연결.
      service.targets = const [_other];
      final callsBefore = service.listCalls;
      await tester.pump(ConnectedTargetController.defaultPollInterval);
      await tester.pumpAndSettle();
      expect(service.listCalls, greaterThan(callsBefore));
      expect(_chipText(tester), '연결 안 됨');
      expect(_scanDropdownValue(tester), isNull);

      // 백엔드 끊김이 게임 창 연결보다 앞서고, 다시 붙으면 미연결로 돌아온다.
      service.targets = const [_ready, _other];
      await tester.tap(find.byKey(const ValueKey('scan-refresh')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scan-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('other-window').last);
      await tester.pumpAndSettle();
      expect(_chipText(tester), '연결됨 · Blue Archive');

      service.setConnection(BackendConnection.disconnected);
      await tester.pump();
      expect(_chipText(tester), '백엔드 끊김');
      expect(_chipColor(tester), AppColors.danger);
      expect(
        find.byKey(const ValueKey('header-connection-chip-button')),
        findsNothing,
      );

      service.setConnection(BackendConnection.connected);
      await tester.pumpAndSettle();
      expect(_chipText(tester), '연결 안 됨');
      expect(_scanDropdownValue(tester), isNull);
    });
  });
}
