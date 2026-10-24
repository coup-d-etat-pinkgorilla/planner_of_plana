// SU1(contracts/startup-user-data-v1): 사용자 데이터 이관 실패 전역 시작 오류.
// XB 예시 4종 응답 해독(strict 거부 포함), ProcessAppService 상태 전이(재연결 · 재시작 무효), 셸 덮개 · 머리글 칩 ·
// 설정 연결 판 표시, 1280×720 · 2560×1392 넘침 0. 실제 이관 실패 process 시험은 하지 않는다(실제 사용자 폴더 필요 — 금지).
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/ui/app_shell.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/widgets/empty_backend_overlay.dart';
import 'package:ba_planner_v7/ui/widgets/recovery_banner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'planning_protocol_client_test.dart' show FakeBackendProcess;

const _message =
    '사용자 자료 이관을 완료하지 못했습니다. 기존 자료는 보존되어 있습니다. 오류 원인을 해결한 뒤 앱을 다시 실행해 주세요.';

/// XB `debug/xb_x3_long_paths_20261023/artifacts/startup-error-examples.json`의 네 응답(method만 다르다) 사본.
const _exampleMethods = [
  'planning.student.get',
  'repository.profile.list',
  'scanner.target.list',
  'assets.prepare.status',
];

const _examplesPath =
    '../debug/xb_x3_long_paths_20261023/artifacts/startup-error-examples.json';

Map<String, dynamic> _exampleResponse(String method) => {
  'protocol': 1,
  'id': 'startup-$method',
  'type': 'response',
  'method': method,
  'payload': {
    'error': {
      'code': 'user_data_migration_failed',
      'message': _message,
      'details': {
        'reason': 'user_data_busy',
        'source_kept': true,
        'restart_required': true,
      },
    },
  },
};

Map<String, dynamic> _error({
  Object? reason = 'user_data_busy',
  Map<String, Object?> extraDetails = const {},
  Map<String, Object?> extraError = const {},
  Set<String> dropDetails = const {},
  Object? sourceKept = true,
  Object? restartRequired = true,
  Object? message = _message,
}) {
  final details = <String, Object?>{
    'reason': reason,
    'source_kept': sourceKept,
    'restart_required': restartRequired,
    ...extraDetails,
  }..removeWhere((key, _) => dropDetails.contains(key));
  return {
    'code': 'user_data_migration_failed',
    'message': message,
    'details': details,
    ...extraError,
  };
}

Map<String, dynamic> _decode(String line) =>
    Map<String, dynamic>.from(jsonDecode(line) as Map);

/// 셸 시험용 가짜 서비스: Mock의 상태를 그대로 비추고, [block] 뒤에는 이관 실패를 얹는다(시험 전용 — Mock 파일은 Lane A).
class _BlockableMockService extends MockAppService {
  _BlockableMockService() {
    _view = ValueNotifier(super.state.value);
    super.state.addListener(_mirror);
  }

  late final ValueNotifier<AppServiceState> _view;
  UserDataMigrationFailure? _failure;

  @override
  ValueListenable<AppServiceState> get state => _view;

  void _mirror() => _view.value = super.state.value.copyWith(
    userDataMigrationFailure: _failure,
  );

  void block(UserDataMigrationFailure failure) {
    _failure = failure;
    setConnection(BackendConnection.disconnected);
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

Future<void> _pumpShell(
  WidgetTester tester,
  AppService service, {
  Size size = const Size(1280, 720),
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BAPlannerTheme.dark(),
      home: AppShell(service: service),
    ),
  );
  await tester.pumpAndSettle();
}

const _busy = UserDataMigrationFailure(
  reason: UserDataMigrationReason.userDataBusy,
  message: _message,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decode', () {
    test('every contract reason decodes; details are exact', () {
      expect(UserDataMigrationReason.values.map((reason) => reason.wire), [
        'user_data_busy',
        'user_data_link_not_migrated',
        'user_data_folder_invalid',
        'v7_user_root_invalid',
        'v7_destination_unrecognised',
        'legacy_repository_recovery_required',
        'user_data_changed_during_migration',
        'user_data_io_error',
        'user_data_migration_failed',
      ]);
      for (final reason in UserDataMigrationReason.values) {
        final failure = UserDataMigrationFailure.fromWireError(
          _error(reason: reason.wire),
        );
        expect(failure?.reason, reason);
        expect(failure?.message, _message);
        expect(failure?.toWireDetails(), {
          'reason': reason.wire,
          'source_kept': true,
          'restart_required': true,
        });
      }
    });

    final rejected = <String, Map<String, dynamic>>{
      'unknown reason': _error(reason: 'user_data_unknown'),
      'reason not a string': _error(reason: 3),
      'missing reason': _error(dropDetails: {'reason'}),
      'missing source_kept': _error(dropDetails: {'source_kept'}),
      'missing restart_required': _error(dropDetails: {'restart_required'}),
      'source_kept false': _error(sourceKept: false),
      'source_kept as string': _error(sourceKept: 'true'),
      'restart_required false': _error(restartRequired: false),
      'restart_required as 1': _error(restartRequired: 1),
      'extra details key': _error(extraDetails: {'path': 'x'}),
      'retryable present': _error(extraError: {'retryable': false}),
      'extra error key': _error(extraError: {'hint': 'x'}),
      'empty message': _error(message: ''),
      'message not a string': _error(message: 1),
      'details not a map': {
        'code': 'user_data_migration_failed',
        'message': _message,
        'details': 'user_data_busy',
      },
      'details missing': {
        'code': 'user_data_migration_failed',
        'message': _message,
      },
      'other code': {..._error(), 'code': 'repository_busy'},
    };
    for (final entry in rejected.entries) {
      test('rejects ${entry.key}', () {
        expect(UserDataMigrationFailure.fromWireError(entry.value), isNull);
      });
    }

    test(
      'embedded examples equal the XB artifact',
      () {
        final file = jsonDecode(File(_examplesPath).readAsStringSync()) as Map;
        final cases = (file['cases'] as List).cast<Map>();
        expect(cases.map((item) => item['response']).toList(), [
          for (final method in _exampleMethods) _exampleResponse(method),
        ]);
      },
      skip: File(_examplesPath).existsSync()
          ? false
          : 'XB example artifact not present in this checkout',
    );
  });

  group('client', () {
    for (final method in _exampleMethods) {
      test(
        'example response for $method is a request-scoped remote error',
        () async {
          final process = FakeBackendProcess();
          final client = PlanningProtocolClient(() async => process);
          addTearDown(client.dispose);
          await client.start();
          final result = client.send(method, const {});
          final request = _decode(process.writes.single);
          process.stdout.add(
            jsonEncode({..._exampleResponse(method), 'id': request['id']}),
          );

          await expectLater(
            result,
            throwsA(
              isA<BackendRemoteException>()
                  .having(
                    (error) => error.code,
                    'code',
                    'user_data_migration_failed',
                  )
                  .having((error) => error.message, 'message', _message)
                  .having((error) => error.retryable, 'retryable', isFalse)
                  .having((error) => error.details, 'details', {
                    'reason': 'user_data_busy',
                    'source_kept': true,
                    'restart_required': true,
                  }),
            ),
          );
          expect(client.connection.value, BackendConnection.connected);
          expect(client.startupFailure.value, _busy);
          expect(process.terminated, isFalse);
        },
      );
    }

    test(
      'first failure is kept; a later different reason does not replace it',
      () async {
        final process = FakeBackendProcess();
        final client = PlanningProtocolClient(() async => process);
        addTearDown(client.dispose);
        await client.start();
        for (final reason in ['user_data_busy', 'user_data_io_error']) {
          final result = client.send('planning.student.get', const {});
          process.respond(_decode(process.writes.last), {
            'error': _error(reason: reason),
          });
          await expectLater(result, throwsA(isA<BackendRemoteException>()));
        }
        expect(client.startupFailure.value, _busy);
      },
    );

    test('a strict-invalid global error is a fatal protocol error', () async {
      final process = FakeBackendProcess();
      final client = PlanningProtocolClient(() async => process);
      addTearDown(client.dispose);
      await client.start();
      final result = client.send('repository.profile.list', const {});
      process.respond(_decode(process.writes.single), {
        'error': _error(extraDetails: {'path': 'C:/x'}),
      });

      await expectLater(result, throwsA(isA<BackendProtocolException>()));
      expect(client.connection.value, BackendConnection.disconnected);
      expect(client.startupFailure.value, isNull);
    });

    test('startup probe failure blocks start, reconnect and restart', () async {
      var starts = 0;
      final process = FakeBackendProcess();
      final client = PlanningProtocolClient(() async {
        starts += 1;
        return process;
      }, waitForStartupProbe: true);
      addTearDown(client.dispose);

      final start = client.start();
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes.single), {'error': _error()});
      await expectLater(start, throwsA(isA<BackendRemoteException>()));
      expect(client.connection.value, BackendConnection.disconnected);
      expect(client.startupFailure.value, _busy);
      expect(
        client.diagnostics.value.lifecycle.join('\n'),
        contains('user data migration failed: user_data_busy'),
      );

      await expectLater(
        client.start(),
        throwsA(
          isA<BackendRemoteException>().having(
            (error) => error.code,
            'code',
            'user_data_migration_failed',
          ),
        ),
      );
      await expectLater(
        client.restart(),
        throwsA(isA<BackendRemoteException>()),
      );
      expect(starts, 1);
      expect(client.startupFailure.value, _busy);
    });
  });

  group('process service state', () {
    test(
      'failure reaches AppServiceState and reconnect/restart stay blocked',
      () async {
        var starts = 0;
        final process = FakeBackendProcess();
        final service = ProcessAppService(
          PlanningProtocolClient(() async {
            starts += 1;
            return process;
          }, waitForStartupProbe: true),
        );
        addTearDown(service.dispose);
        expect(service.state.value.userDataMigrationFailure, isNull);

        final reconnect = service.reconnect();
        await Future<void>.delayed(Duration.zero);
        process.respond(_decode(process.writes.single), {
          'error': _error(reason: 'legacy_repository_recovery_required'),
        });
        await expectLater(reconnect, throwsA(isA<BackendRemoteException>()));

        final blocked = service.state.value;
        expect(
          blocked.userDataMigrationFailure?.reason,
          UserDataMigrationReason.legacyRepositoryRecoveryRequired,
        );
        expect(blocked.connection, BackendConnection.disconnected);

        await expectLater(
          service.reconnect(),
          throwsA(isA<BackendRemoteException>()),
        );
        await expectLater(
          service.restartBackend(),
          throwsA(isA<BackendRemoteException>()),
        );
        expect(starts, 1);
        expect(
          service.state.value.userDataMigrationFailure?.reason,
          UserDataMigrationReason.legacyRepositoryRecoveryRequired,
        );
        // copyWith로는 풀리지 않는다.
        expect(
          service.state.value.copyWith().userDataMigrationFailure,
          isNotNull,
        );
      },
    );
  });

  group('shell', () {
    for (final size in const [Size(1280, 720), Size(2560, 1392)]) {
      testWidgets('blocked state shows at once, with no reconnect, at $size', (
        tester,
      ) async {
        final service = _BlockableMockService();
        addTearDown(service.dispose);
        await _pumpShell(tester, service, size: size);
        expect(find.byKey(EmptyBackendOverlay.overlayKey), findsNothing);
        expect(find.byType(RecoveryBanner), findsOneWidget);

        service.block(_busy);
        await tester.pump();
        // 대기 시간(emptyBackendGrace) 없이 바로 뜬다.
        expect(find.byKey(EmptyBackendOverlay.panelKey), findsOneWidget);
        expect(find.text(userDataBlockedTitle), findsOneWidget);
        expect(
          find.text(
            userDataMigrationReasonText(UserDataMigrationReason.userDataBusy),
          ),
          findsOneWidget,
        );
        expect(find.text(userDataBlockedNote), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(EmptyBackendOverlay.statusKey)).data,
          userDataBlockedStatus,
        );
        expect(find.byKey(EmptyBackendOverlay.reconnectKey), findsNothing);
        expect(
          find.byKey(EmptyBackendOverlay.restartRequiredKey),
          findsOneWidget,
        );
        expect(find.text(userDataRestartRequired), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(RecoveryBanner), findsNothing);
        expect(find.text(EmptyBackendHeaderChip.userDataLabel), findsOneWidget);
        expect(find.text(EmptyBackendHeaderChip.label), findsNothing);
        expect(
          tester.getRect(find.byKey(EmptyBackendOverlay.overlayKey)).top,
          184,
        );
        expect(tester.takeException(), isNull);

        // 다른 경로로 연결이 돌아와도(재연결) 풀리지 않는다.
        service.setConnection(BackendConnection.connected);
        await tester.pump(emptyBackendGrace);
        expect(find.byKey(EmptyBackendOverlay.panelKey), findsOneWidget);
        expect(find.text(userDataBlockedTitle), findsOneWidget);

        // 설정 열기: 덮개는 설정 탭에서 숨고, 칩 · 연결 판이 같은 상태를 보인다.
        await tester.tap(find.byKey(EmptyBackendOverlay.settingsKey));
        await tester.pumpAndSettle();
        expect(find.byKey(EmptyBackendOverlay.overlayKey), findsNothing);
        expect(find.byType(RecoveryBanner), findsNothing);
        expect(find.byKey(EmptyBackendHeaderChip.chipKey), findsOneWidget);
        final status = find.byKey(const ValueKey('settings-backend-status'));
        expect(
          find.descendant(
            of: status,
            matching: find.text(EmptyBackendHeaderChip.userDataLabel),
          ),
          findsOneWidget,
        );
        for (final label in ['재연결', 'Backend 재시작']) {
          expect(
            tester
                .widget<TonalButton>(find.widgetWithText(TonalButton, label))
                .onPressed,
            isNull,
          );
        }
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('top-tab-home')));
        await tester.pumpAndSettle();
        expect(find.byKey(EmptyBackendOverlay.panelKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('every reason renders one line without overflow at 1280x720', (
      tester,
    ) async {
      for (final reason in UserDataMigrationReason.values) {
        final service = MockAppService(
          initialState: AppServiceState(
            connection: BackendConnection.disconnected,
            scanPhase: ScanPhase.idle,
            imageLoadState: ImageLoadState.loaded,
            studentCount: 0,
            inventoryItemCount: 0,
            hasData: false,
            scanAvailable: false,
            useLongNames: false,
            hasMissingMetadata: false,
            userDataMigrationFailure: UserDataMigrationFailure(
              reason: reason,
              message: _message,
            ),
          ),
        );
        await _pumpShell(tester, service);
        final text = userDataMigrationReasonText(reason);
        expect(text, isNot(contains(RegExp(r'[\\/:]'))));
        final finder = find.text(text);
        expect(finder, findsOneWidget, reason: reason.wire);
        final painter = TextPainter(
          text: TextSpan(text: text, style: tester.widget<Text>(finder).style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: 860);
        expect(painter.didExceedMaxLines, isFalse, reason: reason.wire);
        painter.dispose();
        expect(tester.takeException(), isNull, reason: reason.wire);
        await tester.pumpWidget(const SizedBox());
        await service.dispose();
      }
    });
  });
}
