import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('matches multiple reversed responses by unique request id', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();

    final first = client.send('planning.student.get', {'student_id': 'ayane'});
    final second = client.send('planning.student.get', {'student_id': 'aru'});
    final requests = process.writes.map(_decode).toList();

    process.respond(requests[1], {
      'student': {'student_id': 'aru'},
    });
    process.respond(requests[0], {
      'student': {'student_id': 'ayane'},
    });

    expect((await first)['student']['student_id'], 'ayane');
    expect((await second)['student']['student_id'], 'aru');
    expect(requests[0]['id'], isNot(requests[1]['id']));
    await client.dispose();
  });

  test(
    'student catalog response is typed and malformed entries fail closed',
    () async {
      final process = FakeBackendProcess();
      final service = ProcessAppService(
        PlanningProtocolClient(() async => process),
      );
      await service.reconnect();
      final result = service.listStudents();
      final request = process.writes
          .map(_decode)
          .singleWhere(
            (message) => message['method'] == 'planning.student.catalog',
          );
      process.respond(request, {
        'students': [
          {
            'student_id': 'aru',
            'display_name': 'Aru',
            'template_name': 'aru.png',
            'group': 'aru',
            'variant': null,
            'school': 'Gehenna',
            'rarity': '3',
            'attack_type': 'Explosive',
            'defense_type': 'Light',
            'combat_class': 'Striker',
            'role': 'Dealer',
            'position': 'Back',
            'search_tags': ['aru'],
            'kr_search_tags': <String>[],
          },
        ],
        'sort': 'display_name_then_id',
      });
      expect((await result).single.studentId, 'aru');
      await service.dispose();

      final malformedProcess = FakeBackendProcess();
      final malformedClient = PlanningProtocolClient(
        () async => malformedProcess,
      );
      await malformedClient.start();
      final malformed = malformedClient.send('planning.student.catalog', {});
      final malformedRequest = _decode(malformedProcess.writes.single);
      malformedProcess.respond(malformedRequest, {
        'students': <dynamic>[],
        'sort': 'wrong',
      });
      await expectLater(malformed, throwsA(isA<BackendProtocolException>()));
      await malformedClient.dispose();
    },
  );

  test(
    'times out and reports a late response id without reconnecting',
    () async {
      final process = FakeBackendProcess();
      final client = PlanningProtocolClient(
        () async => process,
        defaultTimeout: const Duration(milliseconds: 10),
      );
      final errors = <BackendProtocolException>[];
      final subscription = client.protocolErrors.listen(errors.add);
      await client.start();

      final result = client.send('planning.student.get', {
        'student_id': 'ayane',
      });
      final wireRequest = _decode(process.writes.single);
      await expectLater(result, throwsA(isA<TimeoutException>()));
      process.respond(wireRequest, {'student': null});
      await Future<void>.delayed(Duration.zero);

      expect(
        errors.single.message,
        contains('Unknown or duplicate response id'),
      );
      expect(client.connection.value, BackendConnection.connected);
      await subscription.cancel();
      await client.dispose();
    },
  );

  test('malformed JSON fails pending requests and disconnects', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.student.get', {'student_id': 'ayane'});
    final expectation = expectLater(
      result,
      throwsA(isA<BackendProtocolException>()),
    );

    process.stdout.add('{malformed');
    await expectation;
    expect(client.connection.value, BackendConnection.disconnected);
    await client.dispose();
  });

  test('response method mismatch is fatal to the connection', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.student.get', {'student_id': 'ayane'});
    final request = _decode(process.writes.single);

    process.respond(request, {
      'student': null,
    }, method: 'planning.plan.validate');

    await expectLater(result, throwsA(isA<BackendProtocolException>()));
    expect(client.connection.value, BackendConnection.disconnected);
    expect(process.terminated, isTrue);
    await client.dispose();
  });

  test('invalid structured error is fatal to the connection', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.student.get', {'student_id': ''});
    final request = _decode(process.writes.single);

    process.respond(request, {
      'error': {'code': 'calculation_failed', 'message': 'wrong method code'},
    });

    await expectLater(result, throwsA(isA<BackendProtocolException>()));
    expect(client.connection.value, BackendConnection.disconnected);
    await client.dispose();
  });

  test('valid method error stays request-scoped', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.student.get', {'student_id': ''});
    final request = _decode(process.writes.single);

    process.respond(request, {
      'error': {
        'code': 'invalid_payload',
        'message': 'student_id must be a non-empty string',
      },
    });

    await expectLater(
      result,
      throwsA(
        isA<BackendRemoteException>().having(
          (error) => error.code,
          'code',
          'invalid_payload',
        ),
      ),
    );
    expect(client.connection.value, BackendConnection.connected);
    await client.dispose();
  });

  test('invalid success payload is fatal to the connection', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.plan.validate', {
      'plan': {'version': 1, 'goals': <Object>[]},
    });
    final request = _decode(process.writes.single);

    process.respond(request, {'valid': true});

    await expectLater(result, throwsA(isA<BackendProtocolException>()));
    expect(client.connection.value, BackendConnection.disconnected);
    await client.dispose();
  });

  test(
    'malformed repository success is fatal and restart remains available',
    () async {
      final first = FakeBackendProcess();
      final second = FakeBackendProcess();
      var starts = 0;
      final client = PlanningProtocolClient(
        () async => starts++ == 0 ? first : second,
      );
      await client.start();
      final result = client.send('repository.profile.list', {});
      final request = _decode(first.writes.single);
      first.respond(request, {'nonsense': true});
      await expectLater(result, throwsA(isA<BackendProtocolException>()));
      expect(client.connection.value, BackendConnection.disconnected);

      await client.restart();
      final recovered = client.send('repository.profile.list', {});
      final retried = _decode(second.writes.single);
      second.respond(retried, {
        'profiles': <Object>[],
        'selected_profile_id': null,
      });
      expect((await recovered)['profiles'], isEmpty);
      expect(client.connection.value, BackendConnection.connected);
      await client.dispose();
    },
  );

  test('stdin write failure disconnects and fails the request', () async {
    final process = FakeBackendProcess()..writeError = StateError('closed');
    final client = PlanningProtocolClient(() async => process);
    await client.start();

    await expectLater(
      client.send('planning.student.get', {'student_id': 'ayane'}),
      throwsA(isA<BackendDisconnectedException>()),
    );
    expect(client.connection.value, BackendConnection.disconnected);
    expect(process.terminated, isTrue);
    await client.dispose();
  });

  test(
    'unexpected exit fails pending requests and updates connection',
    () async {
      final process = FakeBackendProcess();
      final client = PlanningProtocolClient(() async => process);
      await client.start();
      final result = client.send('planning.student.get', {
        'student_id': 'ayane',
      });
      final expectation = expectLater(
        result,
        throwsA(isA<BackendDisconnectedException>()),
      );

      process.exit(17);
      await expectation;
      expect(client.connection.value, BackendConnection.disconnected);
      await client.dispose();
    },
  );

  test('restart creates a new process and accepts new requests', () async {
    final processes = [FakeBackendProcess(), FakeBackendProcess()];
    var starts = 0;
    final client = PlanningProtocolClient(() async => processes[starts++]);
    await client.start();
    await client.restart();

    final result = client.send('planning.student.get', {'student_id': 'ayane'});
    final request = _decode(processes[1].writes.single);
    processes[1].respond(request, {'student': null});

    expect(await result, {'student': null});
    expect(starts, 2);
    expect(processes[0].inputClosed, isTrue);
    await client.dispose();
  });

  test('dispose closes the process and fails pending requests', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    await client.start();
    final result = client.send('planning.student.get', {'student_id': 'ayane'});
    final expectation = expectLater(
      result,
      throwsA(isA<BackendDisconnectedException>()),
    );

    await client.dispose();
    await expectation;
    expect(process.inputClosed, isTrue);
  });

  test('ProcessAppService reflects unexpected backend exit', () async {
    final process = FakeBackendProcess();
    final client = PlanningProtocolClient(() async => process);
    final service = ProcessAppService(client);
    await service.reconnect();
    expect(service.state.value.connection, BackendConnection.connected);

    process.exit(3);
    await Future<void>.delayed(Duration.zero);
    expect(service.state.value.connection, BackendConnection.disconnected);
    await service.dispose();
  });

  test(
    'ProcessAppService enables scanner from readiness and consumes terminal event',
    () async {
      final process = FakeBackendProcess();
      final service = ProcessAppService(
        PlanningProtocolClient(() async => process),
      );
      await service.reconnect();
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes[0]), {
        'ready': true,
        'manifest_version': 1,
        'missing': <String>[],
        'corrupt': <String>[],
      });
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes[1]), {
        'targets': [
          {'target_id': 'w1', 'title': 'BA', 'status': 'ready'},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect(service.state.value.scanAvailable, isTrue);

      final scan = service.startScan();
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes[2]), {
        'ready': true,
        'manifest_version': 1,
        'missing': <String>[],
        'corrupt': <String>[],
      });
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes[3]), {
        'targets': [
          {'target_id': 'w1', 'title': 'BA', 'status': 'ready'},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      process.respond(_decode(process.writes[4]), {
        'session_id': 's1',
        'generation': 1,
        'scan_kind': 'student',
      });
      await scan;
      expect(service.state.value.scanPhase, ScanPhase.scanning);
      process.event({
        'session_id': 's1',
        'generation': 1,
        'sequence': 1,
        'scan_kind': 'student',
        'event_kind': 'terminal',
        'outcome': 'completed',
      });
      await Future<void>.delayed(Duration.zero);
      expect(service.state.value.scanPhase, ScanPhase.succeeded);
      expect(await service.didRequestAppExit(), AppExitResponse.exit);
      expect(process.inputClosed, isTrue);
    },
  );

  test('lazy launcher resolution leaves the shell disconnected', () async {
    final service = ProcessAppService.fromLaunchOptions(
      backendDirectory: 'Z:\\path-that-does-not-exist\\ba-planner-backend',
    );

    await expectLater(service.reconnect(), throwsA(isA<StateError>()));
    expect(service.state.value.connection, BackendConnection.disconnected);
    await service.dispose();
  });

  test(
    'real Python process serves every P0 planning method through AppService',
    () async {
      final backendDirectory = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}backend',
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: backendDirectory.path,
      );
      final service = ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 10),
        ),
      );
      try {
        await service.reconnect();
        final student = await service.getStudent('ayane');
        final plan = await service.validatePlan({
          'version': 1,
          'future': true,
          'goals': [
            {'student_id': 'ayane', 'target_level': null, 'future_goal': 1},
          ],
        });
        final totals = await service.calculatePlan(
          currentStudents: [
            {'student_id': 'ayane', 'level': 1},
          ],
          plan: {
            'version': 1,
            'goals': [
              {'student_id': 'ayane', 'target_level': 2},
            ],
          },
        );

        expect(student?['student_id'], 'ayane');
        expect(plan.containsKey('future'), isFalse);
        expect(plan['goals'].single.containsKey('future_goal'), isFalse);
        expect(totals['level_exp'], greaterThan(0));
        expect(totals.containsKey('star_materials'), isTrue);
      } finally {
        await service.dispose();
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}

Map<String, dynamic> _decode(String line) {
  return Map<String, dynamic>.from(jsonDecode(line) as Map);
}

class FakeBackendProcess implements BackendProcessHandle {
  final StreamController<String> stdout = StreamController<String>();
  final StreamController<String> stderr = StreamController<String>();
  final Completer<int> _exit = Completer<int>();
  final List<String> writes = [];
  bool inputClosed = false;
  bool terminated = false;
  Object? writeError;

  @override
  Stream<String> get stdoutLines => stdout.stream;

  @override
  Stream<String> get stderrLines => stderr.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void writeLine(String line) {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    writes.add(line);
  }

  @override
  Future<void> closeInput() async {
    inputClosed = true;
    exit(0);
  }

  @override
  bool terminate([ProcessSignal signal = ProcessSignal.sigterm]) {
    terminated = true;
    exit(-1);
    return true;
  }

  void respond(
    Map<String, dynamic> request,
    Map<String, dynamic> payload, {
    String? method,
  }) {
    stdout.add(
      jsonEncode({
        'protocol': 1,
        'id': request['id'],
        'type': 'response',
        'method': method ?? request['method'],
        'payload': payload,
      }),
    );
  }

  void event(Map<String, dynamic> payload) {
    stdout.add(
      jsonEncode({
        'protocol': 1,
        'type': 'event',
        'method': 'scanner.session.event',
        'payload': payload,
      }),
    );
  }

  void exit(int code) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
    }
  }
}
