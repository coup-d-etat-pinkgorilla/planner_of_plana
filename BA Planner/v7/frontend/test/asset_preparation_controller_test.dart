// f2-dart: 첫 실행 · 설정 화면이 쓸 준비 컨트롤러(화면 없음). 폴더 상태 · 번들 단위 진행(total null이면 분모 없음) ·
// 결과의 null 수 · partial 재시도 · 취소 요청 중 busy · 폴더 이유 코드 · 스캔 중 거절 · 재시작 뒤 옛 작업 버림 ·
// dispose 뒤와 다른 작업의 늦은 이벤트 버림.
import 'dart:async';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/asset_preparation_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_asset_preparation.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/first_run/asset_preparation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _step = Duration(milliseconds: 2);

Future<void> _until(
  AssetPreparationController controller,
  bool Function(AssetPreparationViewState value) condition,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition(controller.value)) {
    if (DateTime.now().isAfter(deadline)) fail('condition not reached');
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

AssetPrepareJob _job(
  AssetPrepareJobRef ref, {
  required int sequence,
  AssetPrepareJobState state = AssetPrepareJobState.running,
  AssetPrepareStage stage = AssetPrepareStage.sprites,
  int done = 1,
  int? total,
}) => AssetPrepareJob(
  jobId: ref.jobId,
  generation: ref.generation,
  sequence: sequence,
  state: state,
  stage: stage,
  done: done,
  total: total,
  created: null,
  available: 0,
  reused: null,
  failed: null,
  reasonCodes: const [],
);

/// 이벤트를 직접 넣는 가짜 서비스(늦은 이벤트 · 다른 generation · null 분모를 정확히 본다).
class _FakeService implements AssetPreparationService {
  final StreamController<AssetPrepareEvent> events =
      StreamController.broadcast();
  final MockAssetPreparation status = MockAssetPreparation(
    step: const Duration(hours: 1),
  );
  AssetPrepareJobRef next = AssetPrepareJobRef(jobId: 'job-a', generation: 1);

  @override
  Stream<AssetPrepareEvent> get assetPrepareEvents => events.stream;

  @override
  Future<AssetPrepareStatus> assetPrepareStatus() async {
    final value = await status.assetPrepareStatus();
    return AssetPrepareStatus(
      gameDir: value.gameDir,
      cache: value.cache,
      busy: false,
      scannerBusy: false,
      job: null,
      lastResult: null,
      metadata: value.metadata,
    );
  }

  @override
  Future<AssetPrepareStatus> setAssetGameDir(String? path) =>
      throw UnimplementedError();

  @override
  Future<AssetPrepareJobRef> startAssetPreparation() async => next;

  @override
  Future<AssetPrepareCancelResult> cancelAssetPreparation(
    AssetPrepareJobRef job,
  ) async => AssetPrepareCancelResult(job: job, cancelRequested: true);

  @override
  Future<AssetPrepareJob> assetPrepareSnapshot(AssetPrepareJobRef job) =>
      throw UnimplementedError();
}

void main() {
  MockAppService service(MockAssetPreparationScenario scenario) =>
      MockAppService(
        assetPreparationScenario: scenario,
        assetPreparationStep: _step,
      );

  test(
    'first run: folder state, bundle progress without fixed denominator, result',
    () async {
      final app = service(MockAssetPreparationScenario.firstRun);
      addTearDown(app.dispose);
      final controller = AssetPreparationController(app, appState: app.state);
      addTearDown(controller.dispose);
      expect(controller.value.canStart, isFalse, reason: 'status not read yet');
      await controller.refresh();
      final idle = controller.value;
      expect(idle.loaded, isTrue);
      expect(idle.folderSource, AssetGameDirSource.auto);
      expect(idle.folderPath, mockAssetAutoGameDir);
      expect(idle.folderValid, isTrue);
      expect(idle.folderReason, isNull);
      expect(idle.cache?.state, AssetCacheState.missing);
      expect(idle.ready, isFalse);
      expect(idle.canStart, isTrue);
      expect(idle.canRetry, isFalse);
      expect(idle.metadata?.steamMatchesSnapshot, isNull);

      final seen = <String>[];
      void record() {
        final progress = controller.value.progress;
        if (progress == null) return;
        final label =
            '${progress.stage.wireName} ${progress.done}/${progress.total} '
            '${progress.hasDenominator} ${progress.fraction}';
        if (seen.isEmpty || seen.last != label) seen.add(label);
      }

      controller.addListener(record);
      expect(await controller.start(), isTrue);
      expect(controller.value.preparing, isTrue);
      expect(controller.value.busy, isTrue);
      expect(controller.value.canStart, isFalse);
      await _until(controller, (value) => value.ready && !value.loading);
      controller.removeListener(record);
      expect(seen, [
        'validating 0/null false null',
        'icons 0/2 true 0.0',
        'icons 2/2 true 1.0',
        'sprites 1/null false null',
        'fonts 1/1 true 1.0',
      ]);
      final done = controller.value;
      expect(done.preparing, isFalse);
      expect(done.busy, isFalse);
      expect(done.progress, isNull);
      expect(done.outcome?.succeeded, isTrue);
      expect(
        [
          done.outcome?.created,
          done.outcome?.reused,
          done.outcome?.failed,
          done.outcome?.available,
        ],
        [16, 0, 0, 16],
      );
      expect(done.canRetry, isFalse);
    },
  );

  test(
    'cancel keeps busy until terminal; counts stay unknown; retry allowed',
    () async {
      final app = service(MockAssetPreparationScenario.firstRun);
      addTearDown(app.dispose);
      final controller = AssetPreparationController(app, appState: app.state);
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.start();
      expect(controller.value.canCancel, isTrue);
      final cancel = controller.cancel();
      expect(controller.value.cancelRequested, isTrue);
      expect(controller.value.busy, isTrue);
      expect(controller.value.canCancel, isFalse);
      expect(await cancel, isTrue);
      expect(controller.value.busy, isTrue, reason: 'request, not terminal');
      await _until(
        controller,
        (value) => value.lastResult != null && !value.loading,
      );
      final value = controller.value;
      expect(value.cancelRequested, isFalse);
      expect(value.busy, isFalse);
      expect(value.outcome?.state, AssetPrepareJobState.cancelled);
      expect(
        [value.outcome?.created, value.outcome?.reused, value.outcome?.failed],
        [null, null, null],
      );
      expect(value.outcome?.reasonCodes, [AssetPrepareReasonCode.cancelled]);
      expect(value.canRetry, isTrue);
    },
  );

  test('partial is retryable and reports the failed count', () async {
    final app = service(MockAssetPreparationScenario.partial);
    addTearDown(app.dispose);
    final controller = AssetPreparationController(app, appState: app.state);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.value.cache?.state, AssetCacheState.partial);
    expect(controller.value.outcome?.failed, 2);
    expect(controller.value.canRetry, isTrue);
    await controller.start();
    await _until(controller, (value) => value.ready && !value.loading);
    expect(controller.value.canRetry, isFalse);
  });

  test(
    'folder rejection keeps the folder and exposes the reason code',
    () async {
      final app = service(MockAssetPreparationScenario.noGameDir);
      addTearDown(app.dispose);
      final controller = AssetPreparationController(app, appState: app.state);
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.value.folderSource, AssetGameDirSource.none);
      expect(controller.value.folderReason, AssetGameDirReason.gameDirNotFound);
      expect(controller.value.canStart, isFalse);
      expect(controller.value.canChangeFolder, isTrue);

      expect(await controller.setGameDir('C:/Synthetic/Missing'), isFalse);
      expect(controller.value.errorCode, AssetPrepareErrorCode.invalidGameDir);
      expect(controller.value.errorReason, AssetGameDirReason.gameDirNotFound);
      expect(controller.value.folderSource, AssetGameDirSource.none);
      expect(controller.value.busy, isFalse);

      expect(await controller.setGameDir(''), isFalse);
      expect(controller.value.errorCode, AssetPrepareErrorCode.invalidPayload);

      expect(await controller.setGameDir(mockAssetUserGameDir), isTrue);
      expect(controller.value.errorCode, isNull);
      expect(controller.value.errorReason, isNull);
      expect(controller.value.folderSource, AssetGameDirSource.user);
      expect(controller.value.canStart, isTrue);

      app.assetPreparationMock.gameDirReasons[mockAssetUserGameDir] =
          AssetGameDirReason.bundleRevisionMismatch;
      await controller.refresh();
      expect(controller.value.folderSource, AssetGameDirSource.user);
      expect(
        controller.value.folderReason,
        AssetGameDirReason.bundleRevisionMismatch,
      );
      expect(controller.value.canStart, isFalse);
    },
  );

  test('an active scan blocks preparation with scanner_busy', () async {
    final app = service(MockAssetPreparationScenario.firstRun);
    addTearDown(app.dispose);
    final controller = AssetPreparationController(app, appState: app.state);
    addTearDown(controller.dispose);
    await app.startScannerSession(ScannerKind.student, 'mock-window');
    await controller.refresh();
    expect(controller.value.scannerBusy, isTrue);
    expect(controller.value.canStart, isFalse);
    expect(await controller.start(), isFalse);
    expect(controller.value.errorCode, AssetPrepareErrorCode.scannerBusy);
    await Future<void>.delayed(const Duration(milliseconds: 80));
  });

  test(
    'backend restart drops the job and re-reads status (no recovery)',
    () async {
      final app = service(MockAssetPreparationScenario.firstRun);
      addTearDown(app.dispose);
      final controller = AssetPreparationController(app, appState: app.state);
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.start();
      expect(controller.value.preparing, isTrue);
      final restart = app.restartBackend();
      await Future<void>.delayed(Duration.zero);
      expect(controller.value.preparing, isFalse);
      expect(controller.value.loaded, isFalse);
      expect(controller.value.canStart, isFalse);
      await restart;
      await _until(controller, (value) => value.loaded && !value.loading);
      expect(controller.value.job, isNull);
      expect(controller.value.lastResult, isNull);
      expect(controller.value.canStart, isTrue);
    },
  );

  test('status shows a running job: the controller attaches to it', () async {
    final app = service(MockAssetPreparationScenario.firstRun);
    addTearDown(app.dispose);
    final job = await app.startAssetPreparation();
    final controller = AssetPreparationController(app, appState: app.state);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.value.preparing, isTrue);
    expect(controller.value.job?.ref, job);
    await _until(controller, (value) => value.ready && !value.loading);
    expect(controller.value.outcome?.succeeded, isTrue);
  });

  test(
    'late events: other generation, older sequence and after dispose are ignored',
    () async {
      final fake = _FakeService();
      addTearDown(fake.events.close);
      final controller = AssetPreparationController(fake);
      await controller.refresh();
      final ref = AssetPrepareJobRef(jobId: 'job-a', generation: 1);
      await controller.start();
      fake.events.add(
        AssetPrepareEvent(
          kind: AssetPrepareEventKind.progress,
          job: _job(ref, sequence: 3),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.value.job?.sequence, 3);
      expect(controller.value.progress?.total, isNull);
      expect(controller.value.progress?.fraction, isNull);

      final other = AssetPrepareJobRef(jobId: 'job-a', generation: 2);
      fake.events.add(
        AssetPrepareEvent(
          kind: AssetPrepareEventKind.progress,
          job: _job(other, sequence: 9),
        ),
      );
      fake.events.add(
        AssetPrepareEvent(
          kind: AssetPrepareEventKind.progress,
          job: _job(ref, sequence: 2),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.value.job?.sequence, 3);
      expect(controller.value.job?.generation, 1);

      var notified = 0;
      controller.addListener(() => notified += 1);
      controller.dispose();
      fake.events.add(
        AssetPrepareEvent(
          kind: AssetPrepareEventKind.progress,
          job: _job(ref, sequence: 4),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notified, 0);
      expect(await controller.start(), isFalse);
    },
  );

  test('a disconnect drops in-flight start responses', () async {
    final app = service(MockAssetPreparationScenario.firstRun);
    addTearDown(app.dispose);
    final controller = AssetPreparationController(app, appState: app.state);
    addTearDown(controller.dispose);
    await controller.refresh();
    final start = controller.start();
    app.setConnection(BackendConnection.disconnected);
    expect(await start, isFalse);
    expect(controller.value.job, isNull);
    expect(controller.value.requestInFlight, isFalse);
  });

  test('remote failures map to bounded codes', () {
    expect(
      AssetPrepareFailure.fromError(
        BackendRemoteException(code: 'asset_prepare_busy', message: 'busy'),
      )?.code,
      AssetPrepareErrorCode.busy,
    );
    expect(
      AssetPrepareFailure.fromError(
        BackendRemoteException(code: 'unknown', message: 'x'),
      ),
      isNull,
    );
  });
}
