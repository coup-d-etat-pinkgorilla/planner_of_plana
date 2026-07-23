import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed scanner snapshot parses envelope history and reconciles cursor', () {
    final snapshot = ScannerSessionSnapshot.fromWire({
      'session_id': 's1',
      'generation': 1,
      'scan_kind': 'student',
      'last_sequence': 2,
      'terminal': 'completed',
      'events': [
        {
          'protocol': 1,
          'type': 'event',
          'method': 'scanner.session.event',
          'payload': {
            'session_id': 's1',
            'generation': 1,
            'sequence': 1,
            'scan_kind': 'student',
            'event_kind': 'phase',
            'phase': 'capturing',
          },
        },
        {
          'protocol': 1,
          'type': 'event',
          'method': 'scanner.session.event',
          'payload': {
            'session_id': 's1',
            'generation': 1,
            'sequence': 2,
            'scan_kind': 'student',
            'event_kind': 'terminal',
            'outcome': 'completed',
          },
        },
      ],
      'candidates': <dynamic>[],
    });
    expect(snapshot.events.map((event) => event.sequence), [1, 2]);
    final cursor = ScannerEventCursor('s1', 1)
      ..reconcile(sequence: snapshot.lastSequence, isTerminal: true);
    expect(
      cursor.consume(
        ScannerEvent(
          sessionId: 's1',
          generation: 1,
          sequence: 3,
          kind: ScannerKind.student,
          eventKind: ScannerEventKind.progress,
          payload: const {},
        ),
      ),
      ScannerEventDecision.afterTerminal,
    );
  });

  test('typed scanner client buffers start race and filters duplicate stale gap', () async {
    final process = _ScannerFakeProcess();
    final transport = PlanningProtocolClient(() async => process);
    final scanner = ScannerProtocolClient(transport);
    final accepted = <ScannerEvent>[];
    final errors = <Object>[];
    final subscription = scanner.scannerEvents.listen(accepted.add, onError: errors.add);
    await transport.start();

    final started = scanner.startScannerSession(ScannerKind.student, 'w1');
    final request = jsonDecode(process.writes.single) as Map<String, dynamic>;
    process.event({'session_id':'s1','generation':1,'sequence':1,'scan_kind':'student','event_kind':'phase','phase':'capturing'});
    process.respond(request, {'session_id':'s1','generation':1,'scan_kind':'student'});
    final session = await started;
    await Future<void>.delayed(Duration.zero);
    expect(session.id, 's1');
    expect(accepted.map((item) => item.sequence), [1]);

    process.event({'session_id':'s1','generation':1,'sequence':1,'scan_kind':'student','event_kind':'phase','phase':'duplicate'});
    process.event({'session_id':'old','generation':1,'sequence':1,'scan_kind':'student','event_kind':'phase','phase':'stale'});
    process.event({'session_id':'s1','generation':1,'sequence':3,'scan_kind':'student','event_kind':'progress','current':1,'total':2,'message_key':'gap'});
    await Future<void>.delayed(Duration.zero);
    expect(accepted.map((item) => item.sequence), [1]);
    expect(errors.single, isA<StateError>());
    await subscription.cancel();
    await scanner.dispose();
    await transport.dispose();
  });

  test('target readiness review and commit APIs use strict scanner methods', () async {
    final process = _ScannerFakeProcess();
    final transport = PlanningProtocolClient(() async => process);
    final scanner = ScannerProtocolClient(transport);
    await transport.start();
    final targetsFuture = scanner.listScannerTargets();
    var request = jsonDecode(process.writes.last) as Map<String, dynamic>;
    process.respond(request, {'targets':[{'target_id':'w1','title':'BA','status':'ready','foreground':true}]});
    final targets = await targetsFuture;
    expect(targets.single.status, ScannerTargetStatus.ready);
    expect(targets.single.foreground, isTrue);
    await scanner.dispose();
    await transport.dispose();
  });
}

class _ScannerFakeProcess implements BackendProcessHandle {
  final StreamController<String> stdout = StreamController();
  final StreamController<String> stderr = StreamController();
  final Completer<int> exited = Completer();
  final List<String> writes = [];
  @override Stream<String> get stdoutLines => stdout.stream;
  @override Stream<String> get stderrLines => stderr.stream;
  @override Future<int> get exitCode => exited.future;
  @override void writeLine(String line) => writes.add(line);
  @override Future<void> closeInput() async { if (!exited.isCompleted) exited.complete(0); }
  @override bool terminate([ProcessSignal signal = ProcessSignal.sigterm]) { if (!exited.isCompleted) exited.complete(-1); return true; }
  void respond(Map<String,dynamic> request, Map<String,dynamic> payload) => stdout.add(jsonEncode({'protocol':1,'id':request['id'],'type':'response','method':request['method'],'payload':payload}));
  void event(Map<String,dynamic> payload) => stdout.add(jsonEncode({'protocol':1,'type':'event','method':'scanner.session.event','payload':payload}));
}
