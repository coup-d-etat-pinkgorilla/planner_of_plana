// fb10a-dart: FB-10a(스캔 일시정지·이어서)의 Dart 연결.
// 근거: XB FB-10a source10 메인 반영(backend 로그 2026-10-11 20:55), CF 로그 2026-10-11 18:15 Dart 목록,
// 인계 debug/xb_fb10a_resume_input_v2_20261011/artifacts/CF-HANDOFF.md.
// 공유 fixture(contracts/fixtures/scanner_pause_fb10a_v1.json, 41 cases)는 Python 테스트와 같은 파일을 읽는다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixturePath = '../contracts/fixtures/scanner_pause_fb10a_v1.json';

List<Map<String, dynamic>> _cases() =>
    ((jsonDecode(File(_fixturePath).readAsStringSync())
                as Map<String, dynamic>)['cases']
            as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _message(Map<String, dynamic> testCase) =>
    testCase['message'] as Map<String, dynamic>;

Map<String, dynamic> _payload(Map<String, dynamic> testCase) =>
    Map<String, dynamic>.from(_message(testCase)['payload'] as Map);

bool _isControlResponse(Map<String, dynamic> testCase) =>
    _message(testCase)['type'] == 'response' &&
    !_payload(testCase).containsKey('error');

bool _isErrorResponse(Map<String, dynamic> testCase) =>
    _message(testCase)['type'] == 'response' &&
    _payload(testCase).containsKey('error');

const _session = ScannerSession(
  id: 's1',
  generation: 1,
  kind: ScannerKind.student,
);

/// 가짜 backend 위의 실제 transport·scanner client.
class _Harness {
  _Harness() {
    transport = PlanningProtocolClient(() async => process);
    scanner = ScannerProtocolClient(transport);
  }

  final process = _FakeScannerProcess();
  late final PlanningProtocolClient transport;
  late final ScannerProtocolClient scanner;

  Future<void> start() => transport.start();

  Map<String, dynamic> get lastRequest =>
      jsonDecode(process.writes.last) as Map<String, dynamic>;

  /// 세션 s1(generation 1)을 시작하고 sequence 1 phase 이벤트까지 받는다(커서를 만든다).
  Future<void> startSession() async {
    final started = scanner.startScannerSession(ScannerKind.student, 'w1');
    process.respond(lastRequest, {
      'session_id': 's1',
      'generation': 1,
      'scan_kind': 'student',
    });
    await started;
    process.event({
      'session_id': 's1',
      'generation': 1,
      'sequence': 1,
      'scan_kind': 'student',
      'event_kind': 'phase',
      'phase': 'capturing',
    });
    await Future<void>.delayed(Duration.zero);
  }

  Future<ScannerSessionControl> control(String method) =>
      method == 'scanner.session.pause'
      ? scanner.pauseScannerSession(_session)
      : scanner.resumeScannerSession(_session);

  Future<void> dispose() async {
    await scanner.dispose();
    await transport.dispose();
  }
}

Future<ScannerEvent> _waitFor(
  List<ScannerEvent> events,
  ScannerEventKind kind,
) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    final found = events.where((event) => event.eventKind == kind);
    if (found.isNotEmpty) return found.first;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('no ${kind.name} event');
}

void main() {
  test('shared FB-10a fixture holds 15 valid and 26 invalid cases', () {
    final cases = _cases();
    expect(cases, hasLength(41));
    expect(cases.where((item) => item['valid'] == true), hasLength(15));
    int count(bool Function(Map<String, dynamic>) where, bool valid) => cases
        .where((item) => where(item) && item['valid'] == valid)
        .length;
    bool request(Map<String, dynamic> item) =>
        _message(item)['type'] == 'request';
    bool event(Map<String, dynamic> item) => _message(item)['type'] == 'event';
    expect(count(request, true), 2);
    expect(count(request, false), 8);
    expect(count(_isControlResponse, true), 7);
    expect(count(_isControlResponse, false), 10);
    expect(count(_isErrorResponse, true), 2);
    expect(count(event, true), 4);
    expect(count(event, false), 8);
  });

  group('requests', () {
    for (final method in ['scanner.session.pause', 'scanner.session.resume']) {
      test('$method sends exactly the valid fixture payload', () async {
        final harness = _Harness();
        await harness.start();
        final pending = harness.control(method);
        final request = harness.lastRequest;
        harness.process.respond(request, {
          'accepted': false,
          'control_state': 'running',
          'reason': null,
          'terminal': null,
        });
        await pending;
        final requests = _cases().where(
          (item) =>
              _message(item)['type'] == 'request' &&
              _message(item)['method'] == method,
        );
        final valid = requests.singleWhere((item) => item['valid'] == true);
        expect(request['method'], method);
        expect(request['payload'], _payload(valid));
        // 잘못된 요청(generation 0·bool·문자열·추가 키)은 typed 세션으로는 만들 수 없다.
        for (final invalid in requests.where((item) => item['valid'] == false)) {
          expect(
            request['payload'],
            isNot(_payload(invalid)),
            reason: invalid['name'] as String,
          );
        }
        await harness.dispose();
      });
    }
  });

  group('control responses through the protocol client (shared fixture)', () {
    for (final testCase in _cases().where(_isControlResponse)) {
      final name = testCase['name'] as String;
      final valid = testCase['valid'] as bool;
      test('$name is ${valid ? 'accepted' : 'rejected'}', () async {
        final harness = _Harness();
        await harness.start();
        final method = _message(testCase)['method'] as String;
        final pending = harness.control(method);
        harness.process.respond(harness.lastRequest, _payload(testCase));
        if (valid) {
          final control = await pending;
          final wire = _payload(testCase);
          expect(control.accepted, wire['accepted']);
          expect(control.controlState.wireName, wire['control_state']);
          expect(control.reason?.wireName, wire['reason']);
          expect(control.terminal, wire['terminal']);
        } else {
          await expectLater(pending, throwsA(isA<BackendProtocolException>()));
        }
        await harness.dispose();
      });
    }
  });

  test('fixture error responses keep the existing scanner error codes', () async {
    for (final testCase in _cases().where(_isErrorResponse)) {
      final harness = _Harness();
      await harness.start();
      final pending = harness.control(_message(testCase)['method'] as String);
      harness.process.respond(harness.lastRequest, _payload(testCase));
      await expectLater(
        pending,
        throwsA(
          isA<BackendRemoteException>().having(
            (error) => error.code,
            'code',
            'stale_generation',
          ),
        ),
      );
      await harness.dispose();
    }
  });

  test('ScannerSessionControl.fromWire matches the fixture and stays strict', () {
    for (final testCase in _cases().where(_isControlResponse)) {
      final wire = _payload(testCase);
      if (testCase['valid'] == true) {
        final control = ScannerSessionControl.fromWire(wire);
        expect(control.controlState.wireName, wire['control_state']);
      } else {
        expect(
          () => ScannerSessionControl.fromWire(wire),
          throwsFormatException,
          reason: testCase['name'] as String,
        );
      }
    }
    const base = {
      'accepted': true,
      'control_state': 'pause_requested',
      'reason': 'user',
      'terminal': null,
    };
    final control = ScannerSessionControl.fromWire(base);
    expect(control.accepted, isTrue);
    expect(control.controlState, ScannerControlState.pauseRequested);
    expect(control.reason, ScannerPauseReason.user);
    for (final invalid in <Map<String, dynamic>>[
      {...base, 'extra': true},
      Map.of(base)..remove('terminal'),
      {...base, 'accepted': 'true'},
      {...base, 'control_state': 'stopped'},
      {...base, 'reason': null},
      {...base, 'terminal': 'completed'},
      {...base, 'control_state': 'running'},
    ]) {
      expect(
        () => ScannerSessionControl.fromWire(invalid),
        throwsFormatException,
        reason: '$invalid',
      );
    }
  });

  group('events through the protocol client (shared fixture)', () {
    for (final testCase in _cases().where(
      (item) => _message(item)['type'] == 'event',
    )) {
      final name = testCase['name'] as String;
      final valid = testCase['valid'] as bool;
      test('$name is ${valid ? 'accepted' : 'rejected'}', () async {
        final harness = _Harness();
        final accepted = <ScannerEvent>[];
        final subscription = harness.scanner.scannerEvents.listen(
          accepted.add,
        );
        final protocolErrors = <BackendProtocolException>[];
        final errorSubscription = harness.transport.protocolErrors.listen(
          protocolErrors.add,
        );
        await harness.start();
        await harness.startSession();
        harness.process.event(_payload(testCase));
        await Future<void>.delayed(Duration.zero);
        if (valid) {
          final event = accepted.last;
          expect(event.sequence, 2);
          expect(event.eventKind.name, _payload(testCase)['event_kind']);
          expect(event.pauseReason?.wireName, _payload(testCase)['reason']);
          expect(
            ScannerEvent.fromPayload(_payload(testCase)).eventKind,
            event.eventKind,
          );
        } else {
          expect(accepted.map((event) => event.sequence), [1]);
          expect(protocolErrors, isNotEmpty);
          expect(
            harness.transport.connection.value,
            BackendConnection.disconnected,
          );
          expect(
            () => ScannerEvent.fromPayload(_payload(testCase)),
            throwsFormatException,
          );
        }
        await subscription.cancel();
        await errorSubscription.cancel();
        await harness.dispose();
      });
    }
  });

  test('snapshot control fields are required and paired (schema allOf)', () {
    Map<String, dynamic> snapshot(Map<String, dynamic> control) => {
      'session_id': 's1',
      'generation': 1,
      'scan_kind': 'student',
      'last_sequence': 2,
      'events': <dynamic>[],
      'candidates': <dynamic>[],
      ...control,
    };
    final paused = ScannerSessionSnapshot.fromWire(
      snapshot({
        'control_state': 'paused',
        'reason': 'input_detected',
        'terminal': null,
      }),
    );
    expect(paused.controlState, ScannerControlState.paused);
    expect(paused.reason, ScannerPauseReason.inputDetected);
    expect(paused.terminal, isNull);
    final done = ScannerSessionSnapshot.fromWire(
      snapshot({
        'control_state': 'terminal',
        'reason': null,
        'terminal': 'cancelled',
      }),
    );
    expect(done.controlState, ScannerControlState.terminal);
    expect(done.terminal, 'cancelled');
    for (final invalid in <Map<String, dynamic>>[
      {'reason': null, 'terminal': null},
      {'control_state': 'running', 'terminal': null},
      {'control_state': 'running', 'reason': null},
      {'control_state': 'running', 'reason': 'user', 'terminal': null},
      {'control_state': 'paused', 'reason': null, 'terminal': null},
      {'control_state': 'running', 'reason': null, 'terminal': 'completed'},
      {'control_state': 'terminal', 'reason': null, 'terminal': null},
      {'control_state': 'stopped', 'reason': null, 'terminal': null},
    ]) {
      expect(
        () => ScannerSessionSnapshot.fromWire(snapshot(invalid)),
        throwsFormatException,
        reason: '$invalid',
      );
    }
    // 생성자는 기본값을 terminal 유무로 정한다(기존 호출 그대로).
    final constructed = ScannerSessionSnapshot(
      sessionId: 's1',
      generation: 1,
      kind: ScannerKind.student,
      lastSequence: 0,
      terminal: null,
      events: const [],
      candidates: const [],
    );
    expect(constructed.controlState, ScannerControlState.running);
    expect(constructed.reason, isNull);
  });

  test('paused and resumed are sequenced and never end the cursor', () {
    ScannerEvent event(int sequence, ScannerEventKind kind) => ScannerEvent(
      sessionId: 's1',
      generation: 1,
      sequence: sequence,
      kind: ScannerKind.student,
      eventKind: kind,
      payload: {
        'reason': kind == ScannerEventKind.paused ? 'user' : null,
      },
    );
    final cursor = ScannerEventCursor('s1', 1);
    expect(
      cursor.consume(event(1, ScannerEventKind.paused)),
      ScannerEventDecision.accepted,
    );
    expect(
      cursor.consume(event(1, ScannerEventKind.resumed)),
      ScannerEventDecision.duplicateOrOutOfOrder,
    );
    expect(
      cursor.consume(event(2, ScannerEventKind.resumed)),
      ScannerEventDecision.accepted,
    );
    expect(cursor.terminal, isFalse);
    expect(event(3, ScannerEventKind.paused).pauseReason, ScannerPauseReason.user);
    expect(event(3, ScannerEventKind.resumed).pauseReason, isNull);
  });

  group('Mock pause/resume parity', () {
    test('pause waits for the next safe point and never resumes by itself', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final events = <ScannerEvent>[];
      final subscription = service.scannerEvents.listen(events.add);
      addTearDown(subscription.cancel);
      final session = await service.startScannerSession(
        ScannerKind.student,
        'mock-window',
      );

      final pause = await service.pauseScannerSession(session);
      expect(pause.accepted, isTrue);
      expect(pause.controlState, ScannerControlState.pauseRequested);
      expect(pause.reason, ScannerPauseReason.user);
      // 요청 수락은 멈춤이 아니다. 아직 resume은 받지 않는다.
      final early = await service.resumeScannerSession(session);
      expect(early.accepted, isFalse);
      expect(early.controlState, ScannerControlState.pauseRequested);
      final duplicate = await service.pauseScannerSession(session);
      expect(duplicate.accepted, isFalse);

      final paused = await _waitFor(events, ScannerEventKind.paused);
      expect(paused.pauseReason, ScannerPauseReason.user);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        events.map((event) => event.eventKind),
        [ScannerEventKind.phase, ScannerEventKind.paused],
      );
      final snapshot = await service.scannerSnapshot(session);
      expect(snapshot.controlState, ScannerControlState.paused);
      expect(snapshot.reason, ScannerPauseReason.user);
      expect(snapshot.terminal, isNull);

      final resume = await service.resumeScannerSession(session);
      expect(resume.accepted, isTrue);
      expect(resume.controlState, ScannerControlState.running);
      expect(resume.reason, isNull);
      await _waitFor(events, ScannerEventKind.terminal);
      expect(events.map((event) => event.eventKind), [
        ScannerEventKind.phase,
        ScannerEventKind.paused,
        ScannerEventKind.resumed,
        ScannerEventKind.progress,
        ScannerEventKind.candidate,
        ScannerEventKind.terminal,
      ]);
      expect(
        events.map((event) => event.sequence),
        List.generate(events.length, (index) => index + 1),
      );
      expect(events.last.payload['outcome'], 'completed');

      final after = await service.pauseScannerSession(session);
      expect(after.accepted, isFalse);
      expect(after.controlState, ScannerControlState.terminal);
      expect(after.terminal, 'completed');
      final finished = await service.scannerSnapshot(session);
      expect(finished.controlState, ScannerControlState.terminal);
    });

    test('automatic input pause keeps its reason and cancel ends a paused session', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final events = <ScannerEvent>[];
      final subscription = service.scannerEvents.listen(events.add);
      addTearDown(subscription.cancel);
      final session = await service.startScannerSession(
        ScannerKind.student,
        'mock-window',
      );
      final running = await service.resumeScannerSession(session);
      expect(running.accepted, isFalse);
      expect(running.controlState, ScannerControlState.running);

      service.debugRequestScannerPause(
        session.id,
        ScannerPauseReason.inputDetected,
      );
      final paused = await _waitFor(events, ScannerEventKind.paused);
      expect(paused.pauseReason, ScannerPauseReason.inputDetected);
      expect(paused.payload['reason'], 'input_detected');

      final cancel = await service.cancelScannerSession(session);
      expect(cancel['accepted'], isTrue);
      final terminal = await _waitFor(events, ScannerEventKind.terminal);
      expect(terminal.payload['outcome'], 'cancelled');
      expect(
        events.where((event) => event.eventKind == ScannerEventKind.resumed),
        isEmpty,
      );
      expect(
        events.where((event) => event.eventKind == ScannerEventKind.candidate),
        isEmpty,
      );
    });

    test('unknown sessions are refused', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await expectLater(
        service.pauseScannerSession(_session),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        service.resumeScannerSession(_session),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeScannerProcess implements BackendProcessHandle {
  final StreamController<String> stdout = StreamController();
  final StreamController<String> stderr = StreamController();
  final Completer<int> exited = Completer();
  final List<String> writes = [];
  @override
  Stream<String> get stdoutLines => stdout.stream;
  @override
  Stream<String> get stderrLines => stderr.stream;
  @override
  Future<int> get exitCode => exited.future;
  @override
  void writeLine(String line) => writes.add(line);
  @override
  Future<void> closeInput() async {
    if (!exited.isCompleted) exited.complete(0);
  }

  @override
  bool terminate([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!exited.isCompleted) exited.complete(-1);
    return true;
  }

  void respond(Map<String, dynamic> request, Map<String, dynamic> payload) =>
      stdout.add(
        jsonEncode({
          'protocol': 1,
          'id': request['id'],
          'type': 'response',
          'method': request['method'],
          'payload': payload,
        }),
      );

  void event(Map<String, dynamic> payload) => stdout.add(
    jsonEncode({
      'protocol': 1,
      'type': 'event',
      'method': 'scanner.session.event',
      'payload': payload,
    }),
  );
}
