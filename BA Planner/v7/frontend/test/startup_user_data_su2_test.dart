// SU2(contracts/startup-user-data-v1 "restart the backend/app", XB 2026-10-24 12:40): 사용자 데이터 이관 실패 상태에서
// 단순 재연결은 계속 막고, 명시적 'Backend 재시작'만 실패를 비우고 새 프로세스로 다시 시도한다(또 실패하면 같은 상태).
// 개발 상태 패널의 Mock 토글(켜기 · 끄기 · 실제 백엔드에서는 숨김), 1280×720 넘침 0. 실제 이관 실패 process 시험은 하지
// 않는다(실제 사용자 폴더 필요 — 금지). 가짜 프로세스([FakeBackendProcess])만 쓴다.
import 'dart:convert';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/ui/app_shell.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/widgets/development_panel.dart';
import 'package:ba_planner_v7/ui/widgets/empty_backend_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'planning_protocol_client_test.dart' show FakeBackendProcess;

const _message = '사용자 자료 이관을 완료하지 못했습니다. 기존 자료는 보존되어 있습니다.';

Map<String, dynamic> _error(String reason) => {
  'code': 'user_data_migration_failed',
  'message': _message,
  'details': {'reason': reason, 'source_kept': true, 'restart_required': true},
};

const _probeOk = {'profiles': <Object>[], 'selected_profile_id': null};

Map<String, dynamic> _decode(String line) =>
    Map<String, dynamic>.from(jsonDecode(line) as Map);

/// 시작할 때마다 새 가짜 프로세스를 내준다(재시작 = 새 프로세스).
class _Starter {
  final List<FakeBackendProcess> processes = [];

  Future<BackendProcessHandle> call() async {
    final process = FakeBackendProcess();
    processes.add(process);
    return process;
  }

  /// [index]번째 프로세스의 시작 probe에 답한다.
  Future<void> answerProbe(int index, Map<String, dynamic> payload) async {
    await Future<void>.delayed(Duration.zero);
    final process = processes[index];
    process.respond(_decode(process.writes.single), payload);
  }
}

/// 셸 시험용 가짜: 처음엔 이관 실패로 막히고(재연결은 같은 오류), 원인을 해결한 뒤의 'Backend 재시작'은 실패를 비우고
/// Mock의 정상 재시작을 탄다.
class _ResolvedRestartService extends MockAppService {
  _ResolvedRestartService() {
    _view = ValueNotifier(super.state.value);
    super.state.addListener(_mirror);
    setConnection(BackendConnection.disconnected);
  }

  late final ValueNotifier<AppServiceState> _view;
  UserDataMigrationFailure? _failure = const UserDataMigrationFailure(
    reason: UserDataMigrationReason.userDataBusy,
    message: _message,
  );
  var restarts = 0;

  @override
  ValueListenable<AppServiceState> get state => _view;

  void _mirror() => _view.value = super.state.value.copyWith(
    userDataMigrationFailure: _failure,
  );

  @override
  Future<void> reconnect() {
    final failure = _failure;
    if (failure != null) {
      return Future.error(
        BackendRemoteException(
          code: userDataMigrationFailedCode,
          message: failure.message,
          details: failure.toWireDetails(),
        ),
      );
    }
    return super.reconnect();
  }

  @override
  Future<void> restartBackend() {
    restarts += 1;
    _failure = null;
    _view.value = super.state.value;
    return super.restartBackend();
  }

  @override
  Future<void> dispose() async {
    super.state.removeListener(_mirror);
    _view.dispose();
    await super.dispose();
  }
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpShell(WidgetTester tester, AppService service) async {
  _setSize(tester, const Size(1280, 720));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BAPlannerTheme.dark(),
      home: AppShell(service: service),
    ),
  );
  await tester.pumpAndSettle();
}

TonalButton _button(WidgetTester tester, String label) =>
    tester.widget<TonalButton>(find.widgetWithText(TonalButton, label));

/// 한 줄 · 두 줄 문구가 주어진 폭 안에 들어가는지(ellipsis로 잘리지 않는지).
void _expectFits(WidgetTester tester, Finder finder, double width, int lines) {
  final text = tester.widget<Text>(finder);
  final painter = TextPainter(
    text: TextSpan(text: text.data, style: text.style),
    textDirection: TextDirection.ltr,
    maxLines: lines,
  )..layout(maxWidth: width);
  expect(painter.didExceedMaxLines, isFalse, reason: text.data);
  painter.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('client', () {
    test(
      'restart clears the failure and a healthy new process connects',
      () async {
        final starter = _Starter();
        final client = PlanningProtocolClient(
          starter.call,
          waitForStartupProbe: true,
        );
        addTearDown(client.dispose);

        final start = client.start();
        await starter.answerProbe(0, {'error': _error('user_data_busy')});
        await expectLater(start, throwsA(isA<BackendRemoteException>()));
        expect(client.startupFailure.value?.reason.wire, 'user_data_busy');

        // 단순 재연결(start)은 계속 막힌다 — 새 프로세스 없음.
        await expectLater(
          client.start(),
          throwsA(isA<BackendRemoteException>()),
        );
        expect(starter.processes, hasLength(1));

        final restart = client.restart();
        await Future<void>.delayed(Duration.zero);
        expect(client.startupFailure.value, isNull);
        expect(client.connection.value, BackendConnection.connecting);
        await starter.answerProbe(1, _probeOk);
        await restart;

        expect(starter.processes, hasLength(2));
        expect(client.connection.value, BackendConnection.connected);
        expect(client.startupFailure.value, isNull);
        expect(
          client.diagnostics.value.lifecycle.join('\n'),
          contains('user data migration retry requested'),
        );
      },
    );

    test(
      'a new process that fails again returns to the blocked state',
      () async {
        final starter = _Starter();
        final client = PlanningProtocolClient(
          starter.call,
          waitForStartupProbe: true,
        );
        addTearDown(client.dispose);

        final start = client.start();
        await starter.answerProbe(0, {'error': _error('user_data_busy')});
        await expectLater(start, throwsA(isA<BackendRemoteException>()));

        final restart = client.restart();
        await starter.answerProbe(1, {
          'error': _error('legacy_repository_recovery_required'),
        });
        await expectLater(
          restart,
          throwsA(
            isA<BackendRemoteException>().having(
              (error) => error.code,
              'code',
              'user_data_migration_failed',
            ),
          ),
        );
        expect(starter.processes, hasLength(2));
        expect(client.connection.value, BackendConnection.disconnected);
        // 새 프로세스가 돌려준 실패가 다시 잡힌다(원본 보존 · restart_required 그대로).
        expect(
          client.startupFailure.value?.reason,
          UserDataMigrationReason.legacyRepositoryRecoveryRequired,
        );
        await expectLater(
          client.start(),
          throwsA(isA<BackendRemoteException>()),
        );
        expect(starter.processes, hasLength(2));
      },
    );

    test('restart without a failure keeps its old behavior', () async {
      final starter = _Starter();
      final client = PlanningProtocolClient(
        starter.call,
        waitForStartupProbe: true,
      );
      addTearDown(client.dispose);
      final start = client.start();
      await starter.answerProbe(0, _probeOk);
      await start;

      final restart = client.restart();
      await starter.answerProbe(1, _probeOk);
      await restart;
      expect(client.connection.value, BackendConnection.connected);
      expect(
        client.diagnostics.value.lifecycle.join('\n'),
        isNot(contains('user data migration retry requested')),
      );
    });
  });

  group('process service state', () {
    test(
      'reconnect stays blocked; restartBackend retries and clears',
      () async {
        final starter = _Starter();
        final service = ProcessAppService(
          PlanningProtocolClient(starter.call, waitForStartupProbe: true),
        );
        addTearDown(service.dispose);

        final reconnect = service.reconnect();
        await starter.answerProbe(0, {'error': _error('user_data_io_error')});
        await expectLater(reconnect, throwsA(isA<BackendRemoteException>()));
        expect(
          service.state.value.userDataMigrationFailure?.reason,
          UserDataMigrationReason.userDataIoError,
        );

        await expectLater(
          service.reconnect(),
          throwsA(isA<BackendRemoteException>()),
        );
        expect(starter.processes, hasLength(1));
        expect(service.state.value.userDataMigrationFailure, isNotNull);

        final restart = service.restartBackend();
        await Future<void>.delayed(Duration.zero);
        expect(service.state.value.userDataMigrationFailure, isNull);
        await starter.answerProbe(1, _probeOk);
        await restart;
        expect(starter.processes, hasLength(2));
        expect(service.state.value.connection, BackendConnection.connected);
        expect(service.state.value.userDataMigrationFailure, isNull);
      },
    );

    test(
      'restartBackend that fails again restores the blocked state',
      () async {
        final starter = _Starter();
        final service = ProcessAppService(
          PlanningProtocolClient(starter.call, waitForStartupProbe: true),
        );
        addTearDown(service.dispose);

        final reconnect = service.reconnect();
        await starter.answerProbe(0, {'error': _error('user_data_busy')});
        await expectLater(reconnect, throwsA(isA<BackendRemoteException>()));

        final restart = service.restartBackend();
        await starter.answerProbe(1, {'error': _error('user_data_busy')});
        await expectLater(restart, throwsA(isA<BackendRemoteException>()));
        expect(
          service.state.value.userDataMigrationFailure?.reason,
          UserDataMigrationReason.userDataBusy,
        );
        expect(service.state.value.connection, BackendConnection.disconnected);
        await expectLater(
          service.reconnect(),
          throwsA(isA<BackendRemoteException>()),
        );
        expect(starter.processes, hasLength(2));
      },
    );
  });

  group('mock toggle', () {
    test(
      'on blocks reconnect and restart; off restores the connection',
      () async {
        final service = MockAppService();
        addTearDown(service.dispose);
        expect(service.state.value.connection, BackendConnection.connected);

        // 꺼져 있을 때 끄기는 아무것도 바꾸지 않는다.
        final before = service.state.value;
        service.setUserDataMigrationFailure(null);
        expect(identical(service.state.value, before), isTrue);

        service.setUserDataMigrationFailure(
          UserDataMigrationReason.v7DestinationUnrecognised,
        );
        expect(
          service.state.value.userDataMigrationFailure,
          const UserDataMigrationFailure(
            reason: UserDataMigrationReason.v7DestinationUnrecognised,
            message: mockUserDataMigrationFailureMessage,
          ),
        );
        expect(service.state.value.connection, BackendConnection.disconnected);

        await expectLater(
          service.reconnect(),
          throwsA(
            isA<BackendRemoteException>()
                .having(
                  (error) => error.code,
                  'code',
                  userDataMigrationFailedCode,
                )
                .having((error) => error.details, 'details', {
                  'reason': 'v7_destination_unrecognised',
                  'source_kept': true,
                  'restart_required': true,
                }),
          ),
        );
        expect(service.state.value.connection, BackendConnection.disconnected);

        // 토글이 켜져 있으면(원인 그대로) 재시작해도 다시 실패한다.
        await expectLater(
          service.restartBackend(),
          throwsA(isA<BackendRemoteException>()),
        );
        expect(
          service.state.value.userDataMigrationFailure?.reason,
          UserDataMigrationReason.v7DestinationUnrecognised,
        );
        expect(service.state.value.connection, BackendConnection.disconnected);
        expect(
          service.diagnostics.value.lifecycle.join('\n'),
          contains(
            'scenario user_data_migration_failed=v7_destination_unrecognised',
          ),
        );

        service.setUserDataMigrationFailure(null);
        expect(service.state.value.userDataMigrationFailure, isNull);
        expect(service.state.value.connection, BackendConnection.connected);
        await service.reconnect();
        expect(service.state.value.connection, BackendConnection.connected);
      },
    );
  });

  group('development panel', () {
    testWidgets('Mock panel toggles the failure on and off', (tester) async {
      _setSize(tester, const Size(1280, 720));
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 331,
                child: DevelopmentPanel(
                  service: service,
                  onOpenDiagnostics: () {},
                  onOpenSectionTemplateStudio: () {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('사용자 데이터 이관 실패'), findsOneWidget);
      expect(find.text('없음'), findsOneWidget);

      await tester.tap(find.text('없음'));
      await tester.pumpAndSettle();
      // 가장 긴 reason도 판 폭 안에서 넘치지 않는다.
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('legacy_repository_recovery_required').last);
      await tester.pumpAndSettle();
      expect(
        service.state.value.userDataMigrationFailure?.reason,
        UserDataMigrationReason.legacyRepositoryRecoveryRequired,
      );
      expect(service.state.value.connection, BackendConnection.disconnected);
      expect(find.text('legacy_repository_recovery_required'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('legacy_repository_recovery_required'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('없음').last);
      await tester.pumpAndSettle();
      expect(service.state.value.userDataMigrationFailure, isNull);
      expect(service.state.value.connection, BackendConnection.connected);
      expect(find.text('없음'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the real backend panel hides the toggle', (tester) async {
      _setSize(tester, const Size(1280, 720));
      final service = ProcessAppService(
        PlanningProtocolClient(() async => FakeBackendProcess()),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 331,
              child: DevelopmentPanel(
                service: service,
                onOpenDiagnostics: () {},
                onOpenSectionTemplateStudio: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('사용자 데이터 이관 실패'), findsNothing);
      expect(find.textContaining('실제 백엔드 서비스가 사용 중입니다'), findsOneWidget);
    });
  });

  group('shell at 1280x720', () {
    testWidgets(
      'Mock toggle in the shell panel; Backend 재시작 fails again while on',
      (tester) async {
        final service = MockAppService();
        addTearDown(service.dispose);
        await _pumpShell(tester, service);
        await tester.tap(find.byIcon(Icons.developer_board_outlined));
        await tester.pumpAndSettle();
        expect(find.text('사용자 데이터 이관 실패'), findsOneWidget);

        await tester.tap(find.text('없음'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('user_data_busy').last);
        await tester.pump();
        expect(find.byKey(EmptyBackendOverlay.panelKey), findsOneWidget);
        expect(find.text(userDataBlockedTitle), findsOneWidget);
        expect(find.text(userDataBlockedNote), findsOneWidget);
        _expectFits(tester, find.text(userDataBlockedNote), 860, 2);
        _expectFits(
          tester,
          find.byKey(EmptyBackendOverlay.statusKey),
          tester.getSize(find.byKey(EmptyBackendOverlay.statusKey)).width,
          1,
        );
        expect(find.text(userDataRestartRequired), findsOneWidget);
        expect(find.byKey(EmptyBackendOverlay.reconnectKey), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        // 설정: 재연결은 꺼지고 'Backend 재시작'만 켜진다.
        await tester.tap(find.byKey(EmptyBackendOverlay.settingsKey));
        await tester.pumpAndSettle();
        expect(_button(tester, '재연결').onPressed, isNull);
        expect(_button(tester, 'Backend 재시작').onPressed, isNotNull);
        final status = find.byKey(const ValueKey('settings-backend-status'));
        expect(
          find.descendant(
            of: status,
            matching: find.textContaining("'Backend 재시작'으로 다시 시도합니다"),
          ),
          findsOneWidget,
        );

        // 토글이 켜져 있으면(원인 그대로) 재시작이 다시 실패하고 같은 상태로 돌아온다.
        await tester.tap(find.widgetWithText(TonalButton, 'Backend 재시작'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(
          service.state.value.userDataMigrationFailure?.reason,
          UserDataMigrationReason.userDataBusy,
        );
        expect(find.byKey(EmptyBackendHeaderChip.chipKey), findsOneWidget);
        expect(_button(tester, '재연결').onPressed, isNull);
        expect(_button(tester, 'Backend 재시작').onPressed, isNotNull);
        expect(tester.takeException(), isNull);

        // 토글 끄기: 덮개 · 칩이 사라지고 정상으로 돌아온다.
        await tester.tap(find.text('user_data_busy'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('없음').last);
        await tester.pumpAndSettle();
        expect(service.state.value.userDataMigrationFailure, isNull);
        // 판의 고르기 제목도 같은 글자라 칩은 key로 찾는다.
        expect(find.byKey(EmptyBackendHeaderChip.chipKey), findsNothing);
        await tester.tap(find.byKey(const ValueKey('top-tab-home')));
        await tester.pumpAndSettle();
        expect(find.byKey(EmptyBackendOverlay.overlayKey), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Backend 재시작 after the cause is resolved clears the overlay', (
      tester,
    ) async {
      final service = _ResolvedRestartService();
      addTearDown(service.dispose);
      await _pumpShell(tester, service);
      expect(find.byKey(EmptyBackendOverlay.panelKey), findsOneWidget);
      expect(find.text(userDataBlockedTitle), findsOneWidget);

      await tester.tap(find.byKey(EmptyBackendOverlay.settingsKey));
      await tester.pumpAndSettle();
      expect(_button(tester, '재연결').onPressed, isNull);
      await tester.tap(find.widgetWithText(TonalButton, 'Backend 재시작'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(service.restarts, 1);
      expect(service.state.value.userDataMigrationFailure, isNull);
      expect(service.state.value.connection, BackendConnection.connected);
      expect(find.text(EmptyBackendHeaderChip.userDataLabel), findsNothing);
      expect(_button(tester, '재연결').onPressed, isNotNull);
      expect(_button(tester, 'Backend 재시작').onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('top-tab-home')));
      await tester.pumpAndSettle();
      expect(find.byKey(EmptyBackendOverlay.overlayKey), findsNothing);
      expect(find.text(userDataBlockedTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
