// f2-dart: Mock F2 준비가 백엔드와 같은 의미인지 본다 — 번들 단위 진행 · 캐시 재사용 · partial 재시도 · 실패/취소의
// null 수와 캐시 보존 · 폴더 자동/지정/이유 · 패치로 stale · 스캔과 준비의 배타 · 빈틈 복구 · 재시작 뒤 옛 작업 버림.
import 'dart:async';

import 'package:ba_planner_v7/services/asset_preparation_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_asset_preparation.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _step = Duration(milliseconds: 2);

Matcher _remote(String code) => throwsA(
  isA<BackendRemoteException>().having((error) => error.code, 'code', code),
);

Future<List<AssetPrepareEvent>> _run(
  AssetPreparationService service, {
  void Function(AssetPrepareJobRef job)? afterStart,
}) async {
  final events = <AssetPrepareEvent>[];
  final done = Completer<void>();
  final subscription = service.assetPrepareEvents.listen((event) {
    events.add(event);
    if (event.isTerminal && !done.isCompleted) done.complete();
  });
  try {
    final job = await service.startAssetPreparation();
    afterStart?.call(job);
    await done.future.timeout(const Duration(seconds: 5));
    // 복구 snapshot 뒤의 진짜 terminal까지 기다린다.
    await Future<void>.delayed(_step * 3);
  } finally {
    await subscription.cancel();
  }
  return events;
}

MockAppService _service(MockAssetPreparationScenario scenario) =>
    MockAppService(
      assetPreparationScenario: scenario,
      assetPreparationStep: _step,
    );

void main() {
  test(
    'first run: bundle stages, no fixed denominator, then cache reuse',
    () async {
      final service = _service(MockAssetPreparationScenario.firstRun);
      addTearDown(service.dispose);
      final before = await service.assetPrepareStatus();
      expect(before.gameDir.source, AssetGameDirSource.auto);
      expect(before.gameDir.path, mockAssetAutoGameDir);
      expect(before.gameDir.valid, isTrue);
      expect(before.cache.state, AssetCacheState.missing);
      expect(before.cache.failed, isNull);
      expect(before.job, isNull);
      expect(before.lastResult, isNull);

      final events = await _run(service);
      expect(events.map((event) => event.job.sequence), [1, 2, 3, 4, 5, 6]);
      expect(
        events.map(
          (event) =>
              '${event.job.stage.wireName} ${event.job.done}/${event.job.total}',
        ),
        [
          'validating 0/null',
          'icons 0/2',
          'icons 2/2',
          'sprites 1/null',
          'fonts 1/1',
          'complete 1/1',
        ],
      );
      expect(
        events.take(5).every((event) => event.job.created == null),
        isTrue,
      );
      final terminal = events.last.job;
      expect(terminal.state, AssetPrepareJobState.succeeded);
      expect(
        [
          terminal.created,
          terminal.available,
          terminal.reused,
          terminal.failed,
        ],
        [16, 16, 0, 0],
      );

      final after = await service.assetPrepareStatus();
      expect(after.cache.state, AssetCacheState.ready);
      expect(after.busy, isFalse);
      expect(after.job?.state, AssetPrepareJobState.succeeded);
      expect(after.lastResult?.sequence, terminal.sequence);

      final again = await _run(service);
      expect(again.map((event) => event.job.stage), [
        AssetPrepareStage.validating,
        AssetPrepareStage.complete,
      ]);
      expect(again.last.job.generation, 2);
      expect([again.last.job.created, again.last.job.reused], [0, 16]);
    },
  );

  test(
    'preparation, folder change and scan start exclude each other',
    () async {
      final service = _service(MockAssetPreparationScenario.firstRun);
      addTearDown(service.dispose);
      final done = Completer<void>();
      final subscription = service.assetPrepareEvents.listen((event) {
        if (event.isTerminal) done.complete();
      });
      addTearDown(subscription.cancel);
      await service.startAssetPreparation();
      expect((await service.assetPrepareStatus()).busy, isTrue);
      await expectLater(
        service.startAssetPreparation(),
        _remote('asset_prepare_busy'),
      );
      await expectLater(
        service.setAssetGameDir(null),
        _remote('asset_prepare_busy'),
      );
      await expectLater(
        service.startScannerSession(ScannerKind.student, 'mock-window'),
        _remote('asset_prepare_busy'),
      );
      await done.future.timeout(const Duration(seconds: 5));
      expect((await service.assetPrepareStatus()).busy, isFalse);

      final session = await service.startScannerSession(
        ScannerKind.student,
        'mock-window',
      );
      expect((await service.assetPrepareStatus()).scannerBusy, isTrue);
      await expectLater(
        service.startAssetPreparation(),
        _remote('scanner_busy'),
      );
      await expectLater(service.setAssetGameDir(null), _remote('scanner_busy'));
      await service.cancelScannerSession(session);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect((await service.assetPrepareStatus()).scannerBusy, isFalse);
    },
  );

  test(
    'cancel is a request: busy until terminal, unknown counts stay null',
    () async {
      final service = _service(MockAssetPreparationScenario.stale);
      addTearDown(service.dispose);
      AssetPrepareCancelResult? cancel;
      final events = await _run(
        service,
        afterStart: (job) => unawaited(
          service.cancelAssetPreparation(job).then((value) => cancel = value),
        ),
      );
      expect(cancel?.cancelRequested, isTrue);
      final terminal = events.last.job;
      expect(terminal.state, AssetPrepareJobState.cancelled);
      expect(terminal.reasonCodes, [AssetPrepareReasonCode.cancelled]);
      expect(
        [terminal.created, terminal.reused, terminal.failed],
        [null, null, null],
      );
      expect(terminal.available, 0);
      final status = await service.assetPrepareStatus();
      expect(
        status.cache.state,
        AssetCacheState.stale,
        reason: 'old cache kept',
      );
      final late = await service.cancelAssetPreparation(terminal.ref);
      expect(late.cancelRequested, isFalse);
    },
  );

  test(
    'cancelling state is visible in status before the terminal event',
    () async {
      final service = _service(MockAssetPreparationScenario.firstRun);
      addTearDown(service.dispose);
      final job = await service.startAssetPreparation();
      await service.cancelAssetPreparation(job);
      final status = await service.assetPrepareStatus();
      expect(status.job?.state, AssetPrepareJobState.cancelling);
      expect(status.busy, isTrue);
    },
  );

  test(
    'partial result is retryable and the retry fills the missing icons',
    () async {
      final service = _service(MockAssetPreparationScenario.extractPartial);
      addTearDown(service.dispose);
      final first = (await _run(service)).last.job;
      expect(first.state, AssetPrepareJobState.partial);
      expect(first.reasonCodes, [AssetPrepareReasonCode.assetsMissing]);
      expect([first.failed, first.available], [2, 14]);
      final partial = await service.assetPrepareStatus();
      expect(partial.cache.state, AssetCacheState.partial);
      expect(partial.cache.failed, 2);

      final retry = await _run(service);
      expect(
        retry.length,
        6,
        reason: 'partial is re-extracted, not a cache hit',
      );
      expect([retry.last.job.created, retry.last.job.reused], [2, 14]);
      expect(
        (await service.assetPrepareStatus()).cache.state,
        AssetCacheState.ready,
      );
    },
  );

  test('failure keeps counts unknown and the previous cache', () async {
    final service = _service(MockAssetPreparationScenario.extractFails);
    addTearDown(service.dispose);
    final terminal = (await _run(service)).last.job;
    expect(terminal.state, AssetPrepareJobState.failed);
    expect(terminal.reasonCodes, [AssetPrepareReasonCode.assetExtractFailed]);
    expect(
      [terminal.created, terminal.reused, terminal.failed],
      [null, null, null],
    );
    expect(
      (await service.assetPrepareStatus()).cache.state,
      AssetCacheState.missing,
    );
    expect(
      (await _run(service)).last.job.state,
      AssetPrepareJobState.succeeded,
    );
  });

  test(
    'folder: automatic, user, invalid reasons and return to automatic',
    () async {
      final service = _service(MockAssetPreparationScenario.noGameDir);
      addTearDown(service.dispose);
      final none = await service.assetPrepareStatus();
      expect(none.gameDir.source, AssetGameDirSource.none);
      expect(none.gameDir.path, isNull);
      expect(none.gameDir.reason, AssetGameDirReason.gameDirNotFound);
      expect(none.cache.state, AssetCacheState.unknown);
      Object? rejected;
      try {
        await service.startAssetPreparation();
      } catch (error) {
        rejected = error;
      }
      expect(
        AssetPrepareFailure.fromError(rejected!)?.reason,
        AssetGameDirReason.gameDirNotFound,
      );

      await expectLater(
        service.setAssetGameDir('C:/Synthetic/Missing'),
        _remote('invalid_game_dir'),
      );
      expect(
        (await service.assetPrepareStatus()).gameDir.source,
        AssetGameDirSource.none,
      );
      await expectLater(service.setAssetGameDir(''), throwsFormatException);

      final user = await service.setAssetGameDir(mockAssetUserGameDir);
      expect(user.gameDir.source, AssetGameDirSource.user);
      expect(user.gameDir.valid, isTrue);
      expect(user.cache.state, AssetCacheState.missing);

      service.assetPreparationMock.gameDirReasons[mockAssetUserGameDir] =
          AssetGameDirReason.bundleRevisionMismatch;
      final mismatch = await service.assetPrepareStatus();
      expect(
        mismatch.gameDir.source,
        AssetGameDirSource.user,
        reason: 'override kept',
      );
      expect(mismatch.gameDir.valid, isFalse);
      expect(
        mismatch.gameDir.reason,
        AssetGameDirReason.bundleRevisionMismatch,
      );
      expect(mismatch.gameDir.catalogSha256, mockAssetCatalogSha256);
      expect(mismatch.cache.state, AssetCacheState.unknown);

      final automatic = await service.setAssetGameDir(null);
      expect(automatic.gameDir.source, AssetGameDirSource.none);
    },
  );

  test('a game patch makes the cache stale until prepared again', () async {
    final service = _service(MockAssetPreparationScenario.ready);
    addTearDown(service.dispose);
    final ready = await service.assetPrepareStatus();
    expect(ready.cache.state, AssetCacheState.ready);
    expect(ready.lastResult?.state, AssetPrepareJobState.succeeded);
    service.assetPreparationMock.simulatePatch();
    final stale = await service.assetPrepareStatus();
    expect(stale.gameDir.bundleRevision, '124');
    expect(stale.cache.state, AssetCacheState.stale);
    expect(stale.cache.failed, isNull);
    expect((await _run(service)).length, 6);
    expect((await service.assetPrepareStatus()).cache.bundleRevision, '124');
  });

  test(
    'dropped progress events are recovered with the snapshot cursor',
    () async {
      final service = _service(MockAssetPreparationScenario.firstRun);
      addTearDown(service.dispose);
      final events = await _run(
        service,
        afterStart: (_) =>
            service.assetPreparationMock.dropNextProgressEvents(2),
      );
      final sequences = events.map((event) => event.job.sequence).toList();
      expect(sequences.first, greaterThan(1));
      expect(events.first.recovered, isTrue);
      for (var index = 1; index < sequences.length; index += 1) {
        expect(sequences[index], greaterThan(sequences[index - 1]));
      }
      expect(events.last.isTerminal, isTrue);
    },
  );

  test(
    'backend restart loses the running job; status is the way back',
    () async {
      final service = _service(MockAssetPreparationScenario.partial);
      addTearDown(service.dispose);
      final saved = (await service.assetPrepareStatus()).lastResult;
      final job = await service.startAssetPreparation();
      await service.restartBackend();
      final status = await service.assetPrepareStatus();
      expect(status.job, isNull);
      expect(status.busy, isFalse);
      expect(status.lastResult?.jobId, saved?.jobId);
      expect(status.cache.state, AssetCacheState.partial);
      await expectLater(
        service.assetPrepareSnapshot(job),
        _remote('asset_prepare_job_not_found'),
      );
      final next = await service.startAssetPreparation();
      expect(next.generation, 1);
      expect(next.jobId, isNot(job.jobId));
    },
  );
}
