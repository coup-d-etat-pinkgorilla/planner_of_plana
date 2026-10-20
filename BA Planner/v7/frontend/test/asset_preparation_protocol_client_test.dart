// f2-dart: 가짜 JSONL 프로세스로 Process 쪽 F2 연결을 본다 — RPC 5개의 wire, start 응답 전 이벤트 버퍼,
// job_id · generation · sequence 거르기, 빈틈 snapshot 복구, 재시작 뒤 옛 작업 버림, 오류 코드 해독, 스캐너 경로와의
// 분리(스캔 시작 `asset_prepare_busy`가 연결을 끊지 않고, 준비 이벤트가 스캐너 구독에 닿지 않음).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/asset_preparation_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _jobId = 'bafb93c56923472e9473be277ae35cd3';

Map<String, dynamic> _job({
  String jobId = _jobId,
  int generation = 1,
  required int sequence,
  String state = 'running',
  String stage = 'icons',
  int done = 0,
  int? total,
  int? created,
  int available = 0,
  int? reused,
  int? failed,
  List<String> reasons = const [],
}) => {
  'job_id': jobId,
  'generation': generation,
  'sequence': sequence,
  'state': state,
  'stage': stage,
  'done': done,
  'total': total,
  'unit': 'bundles',
  'created': created,
  'available': available,
  'reused': reused,
  'failed': failed,
  'reason_codes': reasons,
};

Map<String, dynamic> _progress(
  int sequence, {
  String jobId = _jobId,
  int generation = 1,
}) => {
  'event_kind': 'progress',
  ..._job(
    jobId: jobId,
    generation: generation,
    sequence: sequence,
    done: sequence,
  ),
};

Map<String, dynamic> _terminal(int sequence) => {
  'event_kind': 'terminal',
  ..._job(
    sequence: sequence,
    state: 'succeeded',
    stage: 'complete',
    done: 1,
    total: 1,
    created: 16,
    available: 16,
    reused: 0,
    failed: 0,
  ),
};

Map<String, dynamic> _status({Map<String, dynamic>? job}) => {
  'game_dir': {
    'path': null,
    'source': 'none',
    'valid': false,
    'reason': 'game_dir_not_found',
    'catalog_sha256': null,
    'bundle_revision': null,
  },
  'cache': {
    'state': 'unknown',
    'catalog_sha256': null,
    'bundle_revision': null,
    'icons': 0,
    'sprites': 0,
    'fonts': 0,
    'failed': null,
  },
  'busy': job != null,
  'scanner_busy': false,
  'job': job,
  'last_result': null,
  'metadata': {
    'data_version_id': null,
    'data_snapshot_sha256': null,
    'steam_bundle_revision': null,
    'steam_matches_snapshot': null,
    'jp_update_required': null,
  },
};

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _FakeProcess implements BackendProcessHandle {
  final StreamController<String> stdout = StreamController();
  final StreamController<String> stderr = StreamController();
  final Completer<int> exited = Completer();
  final List<Map<String, dynamic>> requests = [];

  @override
  Stream<String> get stdoutLines => stdout.stream;
  @override
  Stream<String> get stderrLines => stderr.stream;
  @override
  Future<int> get exitCode => exited.future;
  @override
  void writeLine(String line) =>
      requests.add(jsonDecode(line) as Map<String, dynamic>);
  @override
  Future<void> closeInput() async {
    if (!exited.isCompleted) exited.complete(0);
  }

  @override
  bool terminate([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!exited.isCompleted) exited.complete(-1);
    return true;
  }

  Map<String, dynamic> last(String method) =>
      requests.lastWhere((item) => item['method'] == method);

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

  void error(
    Map<String, dynamic> request,
    String code, [
    Map<String, dynamic> details = const {},
  ]) => respond(request, {
    'error': {'code': code, 'message': code, 'details': details},
  });

  void event(Map<String, dynamic> payload) => stdout.add(
    jsonEncode({
      'protocol': 1,
      'type': 'event',
      'method': 'assets.prepare.event',
      'payload': payload,
    }),
  );
}

void main() {
  late _FakeProcess process;
  late PlanningProtocolClient transport;
  late AssetPreparationProtocolClient client;
  late List<AssetPrepareEvent> accepted;
  late List<Object> errors;
  late StreamSubscription<AssetPrepareEvent> subscription;

  setUp(() async {
    process = _FakeProcess();
    transport = PlanningProtocolClient(() async => process);
    client = AssetPreparationProtocolClient(transport);
    accepted = [];
    errors = [];
    subscription = client.assetPrepareEvents.listen(
      accepted.add,
      onError: errors.add,
    );
    await transport.start();
  });

  tearDown(() async {
    await subscription.cancel();
    await client.dispose();
    await transport.dispose();
  });

  Future<AssetPrepareJobRef> startJob() async {
    final started = client.startAssetPreparation();
    await _flush();
    process.respond(process.last(assetPrepareStartMethod), {
      'job_id': _jobId,
      'generation': 1,
    });
    return started;
  }

  test('RPC wire payloads are exact and responses decode strictly', () async {
    final status = client.assetPrepareStatus();
    await _flush();
    expect(
      process.last(assetPrepareStatusMethod)['payload'],
      <String, dynamic>{},
    );
    process.respond(process.last(assetPrepareStatusMethod), _status());
    final value = await status;
    expect(value.gameDir.source, AssetGameDirSource.none);
    expect(value.gameDir.reason, AssetGameDirReason.gameDirNotFound);
    expect(value.cache.failed, isNull);

    final reset = client.setAssetGameDir(null);
    await _flush();
    expect(process.last(assetPrepareGameDirSetMethod)['payload'], {
      'path': null,
    });
    process.respond(process.last(assetPrepareGameDirSetMethod), _status());
    await reset;

    final count = process.requests.length;
    await expectLater(client.setAssetGameDir(''), throwsFormatException);
    expect(process.requests, hasLength(count), reason: 'nothing is sent');

    final ref = await startJob();
    expect(
      process.last(assetPrepareStartMethod)['payload'],
      <String, dynamic>{},
    );
    expect(ref, AssetPrepareJobRef(jobId: _jobId, generation: 1));

    final cancel = client.cancelAssetPreparation(ref);
    await _flush();
    expect(process.last(assetPrepareCancelMethod)['payload'], {
      'job_id': _jobId,
      'generation': 1,
    });
    process.respond(process.last(assetPrepareCancelMethod), {
      'job_id': _jobId,
      'generation': 1,
      'cancel_requested': true,
    });
    expect((await cancel).cancelRequested, isTrue);

    final snapshot = client.assetPrepareSnapshot(ref);
    await _flush();
    expect(process.last(assetPrepareSnapshotMethod)['payload'], ref.toWire());
    process.respond(process.last(assetPrepareSnapshotMethod), {
      'job': _job(sequence: 0, state: 'cancelling', stage: 'validating'),
    });
    final job = await snapshot;
    expect(job.state, AssetPrepareJobState.cancelling);
    expect(job.total, isNull);
    expect(transport.connection.value, BackendConnection.connected);
  });

  test(
    'events before the start response are held, then filtered by cursor',
    () async {
      final started = client.startAssetPreparation();
      await _flush();
      // 앱이 응답보다 먼저 이벤트를 받는 경합(백엔드는 순서를 지키지만 Dart microtask 순서는 다를 수 있다).
      process.event(_progress(1));
      process.event(_progress(1, jobId: 'oldjob', generation: 1));
      await _flush();
      expect(accepted, isEmpty);
      process.respond(process.last(assetPrepareStartMethod), {
        'job_id': _jobId,
        'generation': 1,
      });
      await started;
      await _flush();
      expect(accepted.map((item) => item.job.sequence), [1]);

      process.event(_progress(1)); // 중복
      process.event(_progress(2, generation: 2)); // 다른 generation
      process.event(_progress(2));
      process.event(_terminal(3));
      process.event(_progress(4)); // terminal 뒤
      await _flush();
      expect(accepted.map((item) => item.job.sequence), [1, 2, 3]);
      expect(accepted.last.isTerminal, isTrue);
      expect(accepted.every((item) => !item.recovered), isTrue);
      expect(errors, isEmpty);
    },
  );

  test(
    'a sequence gap is recovered from snapshot and the snapshot cursor wins',
    () async {
      final ref = await startJob();
      process.event(_progress(1));
      await _flush();
      process.event(_progress(3)); // 2가 합쳐져 빠졌다
      await _flush();
      final snapshotRequest = process.last(assetPrepareSnapshotMethod);
      expect(snapshotRequest['payload'], ref.toWire());
      process.event(_progress(4)); // 복구 중에 온 이벤트는 잡아 둔다
      process.event(_progress(5));
      await _flush();
      expect(accepted.map((item) => item.job.sequence), [1]);
      process.respond(snapshotRequest, {
        'job': _job(sequence: 4, stage: 'sprites', done: 1),
      });
      await _flush();
      await _flush();
      expect(accepted.map((item) => item.job.sequence), [1, 4, 5]);
      expect(accepted[1].recovered, isTrue);
      expect(accepted[1].job.stage, AssetPrepareStage.sprites);
      expect(accepted[1].job.total, isNull);
      expect(errors, isEmpty);
    },
  );

  test(
    'a terminal snapshot does not swallow the later terminal event',
    () async {
      await startJob();
      process.event(_progress(1));
      process.event(_terminal(3));
      await _flush();
      process.respond(process.last(assetPrepareSnapshotMethod), {
        'job': _job(
          sequence: 2,
          state: 'succeeded',
          stage: 'complete',
          done: 1,
          total: 1,
          created: 16,
          available: 16,
          reused: 0,
          failed: 0,
        ),
      });
      await _flush();
      await _flush();
      expect(accepted.map((item) => item.job.sequence), [1, 2, 3]);
      expect(accepted[1].recovered && accepted[1].isTerminal, isTrue);
      expect(accepted[2].recovered, isFalse);
    },
  );

  test('a failed gap recovery drops the cursor and reports an error', () async {
    await startJob();
    process.event(_progress(1));
    process.event(_progress(3));
    await _flush();
    process.error(
      process.last(assetPrepareSnapshotMethod),
      'asset_prepare_job_not_found',
    );
    await _flush();
    await _flush();
    expect(errors.single, isA<BackendRemoteException>());
    process.event(_progress(4));
    await _flush();
    expect(accepted.map((item) => item.job.sequence), [1]);
    expect(transport.connection.value, BackendConnection.connected);
  });

  test('restart drops the old job: its late events are ignored', () async {
    await startJob();
    process.event(_progress(1));
    await _flush();
    await transport.stop();
    process = _FakeProcess();
    await transport.start();
    process.event(_progress(2));
    await _flush();
    expect(accepted.map((item) => item.job.sequence), [1]);
  });

  test('bounded errors decode with reasons and keep the connection', () async {
    final start = client.startAssetPreparation();
    await _flush();
    process.error(process.last(assetPrepareStartMethod), 'invalid_game_dir', {
      'reason': 'bundle_revision_mismatch',
    });
    Object? failure;
    try {
      await start;
    } catch (error) {
      failure = error;
    }
    final decoded = AssetPrepareFailure.fromError(failure!);
    expect(decoded?.code, AssetPrepareErrorCode.invalidGameDir);
    expect(decoded?.reason, AssetGameDirReason.bundleRevisionMismatch);

    for (final code in assetPrepareErrorWireCodes) {
      final status = client.assetPrepareStatus();
      await _flush();
      process.error(process.last(assetPrepareStatusMethod), code);
      await expectLater(
        status,
        throwsA(
          isA<BackendRemoteException>().having((e) => e.code, 'code', code),
        ),
      );
    }
    final busy = AssetPrepareFailure.fromError(
      BackendRemoteException(code: 'scanner_busy', message: 'busy'),
    );
    expect(busy?.code, AssetPrepareErrorCode.scannerBusy);
    expect(busy?.reason, isNull);
    expect(transport.connection.value, BackendConnection.connected);
  });

  test('out-of-contract payloads are protocol errors', () async {
    final status = client.assetPrepareStatus();
    await _flush();
    process.error(
      process.last(assetPrepareStatusMethod),
      'asset_prepare_cancelled',
    );
    await expectLater(status, throwsA(isA<BackendProtocolException>()));
    await _flush();
    expect(transport.connection.value, BackendConnection.disconnected);
  });

  test('an invalid preparation event is a fatal protocol error', () async {
    await startJob();
    process.event({..._progress(1), 'unit': 'icons'});
    await _flush();
    await _flush();
    expect(transport.connection.value, BackendConnection.disconnected);
    expect(accepted, isEmpty);
  });

  test(
    'scanner path: asset_prepare_busy start and preparation events stay apart',
    () async {
      final scanner = ScannerProtocolClient(transport);
      final scannerEvents = <ScannerEvent>[];
      final scannerErrors = <Object>[];
      final scannerSubscription = scanner.scannerEvents.listen(
        scannerEvents.add,
        onError: scannerErrors.add,
      );
      try {
        final scan = scanner.startScannerSession(ScannerKind.student, 'w1');
        await _flush();
        process.error(
          process.last('scanner.session.start'),
          'asset_prepare_busy',
        );
        await expectLater(
          scan,
          throwsA(
            isA<BackendRemoteException>().having(
              (e) => e.code,
              'code',
              'asset_prepare_busy',
            ),
          ),
        );
        await startJob();
        process.event(_progress(1));
        await _flush();
        await _flush();
        expect(accepted, hasLength(1));
        expect(scannerEvents, isEmpty);
        expect(scannerErrors, isEmpty);
        expect(transport.connection.value, BackendConnection.connected);
      } finally {
        await scannerSubscription.cancel();
        await scanner.dispose();
      }
    },
  );

  test('snapshot adopts a running job seen in status', () async {
    final status = client.assetPrepareStatus();
    await _flush();
    process.respond(
      process.last(assetPrepareStatusMethod),
      _status(job: _job(sequence: 2)),
    );
    final running = (await status).job!;
    final snapshot = client.assetPrepareSnapshot(running.ref);
    await _flush();
    process.respond(process.last(assetPrepareSnapshotMethod), {
      'job': _job(sequence: 2),
    });
    await snapshot;
    process.event(_progress(2)); // 이미 본 sequence
    process.event(_progress(3));
    await _flush();
    expect(accepted.map((item) => item.job.sequence), [3]);
  });
}
