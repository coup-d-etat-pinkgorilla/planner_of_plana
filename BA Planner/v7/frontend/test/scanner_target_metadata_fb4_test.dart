// fb4-dart: FB-4 `scanner.target.list` optional metadata(client_width·client_height·game)의 Dart 연결.
// 근거: XB 커밋 b685d9ac, 연결 메모
// debug/xb_fb4_target_metadata_20261010/artifacts/dart-connection-memo.md.
// 공유 fixture는 Python 테스트와 같은 파일을 읽는다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixturePath = '../contracts/fixtures/scanner_target_metadata_fb4_v1.json';

Map<String, dynamic> _fixture() =>
    jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _cases() =>
    (_fixture()['cases'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _caseNamed(String name) =>
    _cases().singleWhere((item) => item['name'] == name);

List<Map<String, dynamic>> _wireTargets(Map<String, dynamic> testCase) =>
    (((testCase['message'] as Map)['payload'] as Map)['targets'] as List)
        .cast<Map<String, dynamic>>();

void _expectMatchesWire(ScannerTarget target, Map<String, dynamic> wire) {
  expect(target.id, wire['target_id']);
  expect(target.title, wire['title']);
  expect(target.status.name, wire['status']);
  expect(target.foreground, wire['foreground'] == true);
  // 생략(구 provider)과 null(측정 불가)은 둘 다 null이다. 0이나 기본값으로 채우지 않는다.
  expect(target.clientWidth, wire['client_width']);
  expect(target.clientHeight, wire['client_height']);
  expect(target.game?.wireName, wire['game']);
  expect(
    target.hasClientSize,
    wire['client_width'] != null && wire['client_height'] != null,
  );
}

/// 공유 fixture의 응답 envelope를 그대로 돌려주는 가짜 backend(요청 id만 맞춘다).
Future<List<ScannerTarget>> _listThroughClient(
  Map<String, dynamic> message,
) async {
  final process = _FakeScannerProcess();
  final transport = PlanningProtocolClient(() async => process);
  final scanner = ScannerProtocolClient(transport);
  await transport.start();
  try {
    final result = scanner.listScannerTargets();
    final request = jsonDecode(process.writes.last) as Map<String, dynamic>;
    expect(request['method'], 'scanner.target.list');
    process.stdout.add(jsonEncode({...message, 'id': request['id']}));
    return await result;
  } finally {
    await scanner.dispose();
    await transport.dispose();
  }
}

void main() {
  test('shared FB-4 fixture holds 9 valid and 5 invalid target list cases', () {
    final fixture = _fixture();
    expect(fixture['version'], 1);
    final cases = _cases();
    expect(cases, hasLength(14));
    expect(cases.where((item) => item['valid'] == true), hasLength(9));
    expect(cases.where((item) => item['valid'] == false), hasLength(5));
    for (final testCase in cases) {
      final message = testCase['message'] as Map<String, dynamic>;
      expect(message['method'], 'scanner.target.list', reason: '$testCase');
      expect(message['type'], 'response', reason: '$testCase');
    }
  });

  group('scanner.target.list through the protocol client (shared fixture)', () {
    for (final testCase in _cases()) {
      final name = testCase['name'] as String;
      final valid = testCase['valid'] as bool;
      test('$name is ${valid ? 'accepted' : 'rejected'}', () async {
        final message = testCase['message'] as Map<String, dynamic>;
        if (valid) {
          final targets = await _listThroughClient(message);
          final wire = _wireTargets(testCase);
          expect(targets, hasLength(wire.length));
          for (var index = 0; index < wire.length; index += 1) {
            _expectMatchesWire(targets[index], wire[index]);
          }
        } else {
          await expectLater(
            _listThroughClient(message),
            throwsA(isA<BackendProtocolException>()),
          );
        }
      });
    }
  });

  test('valid fixture rows keep unknown metadata unknown', () {
    ScannerTarget single(String name) =>
        ScannerTarget.fromWire(_wireTargets(_caseNamed(name)).single);

    final ready = single('ready2560x1440');
    expect(ready.clientWidth, 2560);
    expect(ready.clientHeight, 1440);
    expect(ready.game, ScannerTargetGame.blueArchive);
    expect(ready.hasClientSize, isTrue);

    final legacy = single('legacy-omitted-metadata');
    expect(legacy.clientWidth, isNull);
    expect(legacy.clientHeight, isNull);
    expect(legacy.game, isNull);
    expect(legacy.hasClientSize, isFalse);

    final minimized = single('minimized-null-size');
    expect(minimized.status, ScannerTargetStatus.minimized);
    expect(minimized.hasClientSize, isFalse);
    expect(minimized.game, ScannerTargetGame.blueArchive);

    // 제목만 같은 창은 game을 모른다(null). 게임 아님으로 단정하지 않는다.
    final impostor = single('unknown-title-impostor');
    expect(impostor.game, isNull);
    expect(impostor.hasClientSize, isTrue);

    // 같은 game이어도 지원하지 않는 비율은 기존 status로만 전달된다.
    final unsupported = single('unsupported-ratio-same-identity');
    expect(unsupported.status, ScannerTargetStatus.unsupported);
    expect(unsupported.game, ScannerTargetGame.blueArchive);
    expect(unsupported.clientWidth, 1600);
    expect(unsupported.clientHeight, 1000);
  });

  test('ScannerTarget.fromWire rejects invalid metadata values directly', () {
    for (final testCase in _cases().where((item) => item['valid'] == false)) {
      final row = _wireTargets(testCase).single;
      expect(
        () => ScannerTarget.fromWire(row),
        throwsFormatException,
        reason: testCase['name'] as String,
      );
    }
    const base = {'target_id': 'w1', 'title': 'BA', 'status': 'ready'};
    for (final invalid in <Map<String, dynamic>>[
      {...base, 'client_height': true},
      {...base, 'client_width': 1280.0},
      {...base, 'client_height': 0},
      {...base, 'game': 1},
      {...base, 'game': ''},
      {...base, 'game': 'BLUE_ARCHIVE'},
    ]) {
      expect(
        () => ScannerTarget.fromWire(invalid),
        throwsFormatException,
        reason: '$invalid',
      );
    }
  });

  test('the response check rejects non-integer metadata and allows extra keys', () async {
    Map<String, dynamic> response(Map<String, dynamic> row) => {
      'protocol': 1,
      'id': 'unused',
      'type': 'response',
      'method': 'scanner.target.list',
      'payload': {
        'targets': [row],
      },
    };
    const base = {'target_id': 'w1', 'title': 'BA', 'status': 'ready'};
    for (final invalid in <Map<String, dynamic>>[
      {...base, 'client_width': 1280.0},
      {...base, 'client_height': '720'},
      {...base, 'game': false},
    ]) {
      await expectLater(
        _listThroughClient(response(invalid)),
        throwsA(isA<BackendProtocolException>()),
        reason: '$invalid',
      );
    }
    // schema additionalProperties: true — 모르는 추가 키는 지금처럼 통과한다.
    final targets = await _listThroughClient(
      response({
        ...base,
        'client_width': 1920,
        'client_height': null,
        'future_key': {'any': 'value'},
      }),
    );
    expect(targets.single.clientWidth, 1920);
    expect(targets.single.clientHeight, isNull);
    expect(targets.single.game, isNull);
    expect(targets.single.hasClientSize, isFalse);
  });

  test('mock default scanner target carries the FB-4 memo example metadata', () async {
    final service = MockAppService();
    addTearDown(service.dispose);
    final target = (await service.listScannerTargets()).single;
    expect(target.id, 'mock-window');
    expect(target.title, 'Mock Blue Archive');
    expect(target.status, ScannerTargetStatus.ready);
    expect(target.foreground, isTrue);
    expect(target.clientWidth, 2560);
    expect(target.clientHeight, 1440);
    expect(target.game, ScannerTargetGame.blueArchive);
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
}
