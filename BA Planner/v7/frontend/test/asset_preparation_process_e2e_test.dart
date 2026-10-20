// f2-dart process E2E: 실제 Python 백엔드(`core.backend_process`)로 F2 status · 폴더 지정 · 이유 코드 · start 거절을 본다.
//
// 실제 게임 설치 폴더를 열지 않는다:
// - 저장소(`BA_PLANNER_STORAGE_ROOT`)와 인식 캐시(`BA_PLANNER_EXTRACTED_ASSET_DIR`)를 임시 폴더로 돌린다.
// - 첫 F2 요청이 임시 폴더의 합성 가짜 BA 폴더(CCDB 머리 + BundleRevision 셋) 지정이다. 그 뒤 status는 사용자 지정을
//   읽으므로 Steam 자동 탐색(레지스트리 → 실제 설치 폴더 catalog 해시)을 타지 않는다.
// - `game_dir.set(null)`은 보내지 않는다(자동 탐색으로 돌아가 실제 설치 폴더를 읽는다 — fixture · Mock · 가짜 연결
//   시험에서만 다룬다).
// - start는 폴더 없음 상태의 거절만 본다(작업 · 추출 0).
import 'dart:io';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/asset_preparation_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _join(List<String> parts) => parts.join(Platform.pathSeparator);

/// 합성 가짜 BA 폴더(내용 없는 catalog 머리 + 같은 BundleRevision 셋). 실제 게임 파일이 아니다.
Directory _fakeGame(Directory root) {
  final game = Directory(_join([root.path, 'ba_fake_game']));
  final resource = _join([
    game.path,
    'BlueArchive_Data',
    'StreamingAssets',
    'PUB',
    'Resource',
  ]);
  final catalog = File(
    _join([resource, 'Catalog', 'Windows', 'catalog_Windows.bytes']),
  );
  catalog.parent.createSync(recursive: true);
  catalog.writeAsBytesSync([
    0x43,
    0x43,
    0x44,
    0x42,
    0x01,
    ...'synthetic'.codeUnits,
  ]);
  for (final section in ['Catalog', 'Preload', 'GameData']) {
    final revision = File(_join([resource, section, 'BundleRevision']));
    revision.parent.createSync(recursive: true);
    revision.writeAsStringSync('123');
  }
  return game;
}

Future<AssetPrepareFailure?> _failure(Future<Object?> future) async {
  try {
    await future;
  } catch (error) {
    return AssetPrepareFailure.fromError(error);
  }
  fail('expected a bounded asset preparation error');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real backend: status, folder override, reason codes, start rejection',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ba_planner_v7_f2dart_',
      );
      final storage = Directory(_join([root.path, 'repository']))..createSync();
      final cache = _join([root.path, 'user', 'recognition-assets']);
      final game = _fakeGame(root);
      final config = BackendProcessConfig.resolve(
        backendDirectory:
            '${Directory.current.parent.path}${Platform.pathSeparator}backend',
        environment: {
          'BA_PLANNER_STORAGE_ROOT': storage.path,
          'BA_PLANNER_EXTRACTED_ASSET_DIR': cache,
        },
      );
      ProcessAppService start() => ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 30),
          waitForStartupProbe: true,
        ),
      );
      final service = start();
      final events = <AssetPrepareEvent>[];
      final errors = <Object>[];
      final subscription = service.assetPrepareEvents.listen(
        events.add,
        onError: errors.add,
      );
      try {
        await service.reconnect();

        // 1) 첫 F2 요청: 합성 폴더 지정(검증 통과 → 저장 → status).
        final user = await service.setAssetGameDir(game.path);
        expect(user.gameDir.source, AssetGameDirSource.user);
        expect(user.gameDir.valid, isTrue);
        expect(user.gameDir.reason, isNull);
        expect(user.gameDir.path?.toLowerCase(), endsWith('ba_fake_game'));
        expect(user.gameDir.bundleRevision, '123');
        expect(user.gameDir.catalogSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(user.cache.state, AssetCacheState.missing);
        expect(user.cache.failed, isNull);
        expect(user.busy, isFalse);
        expect(user.scannerBusy, isFalse);
        expect(user.job, isNull);
        expect(user.lastResult, isNull);
        final settings = File(_join([storage.path, 'asset-preparation.json']));
        expect(settings.existsSync(), isTrue);

        final status = await service.assetPrepareStatus();
        expect(status.toWire(), user.toWire());

        // 2) 존재하지 않는 폴더 · BA가 아닌 폴더: 저장하지 않고 이유 코드.
        final missing = await _failure(
          service.setAssetGameDir(_join([root.path, 'does-not-exist'])),
        );
        expect(missing?.code, AssetPrepareErrorCode.invalidGameDir);
        expect(missing?.reason, AssetGameDirReason.gameDirNotFound);
        final notGame = await _failure(service.setAssetGameDir(storage.path));
        expect(notGame?.reason, AssetGameDirReason.notBlueArchive);
        expect((await service.assetPrepareStatus()).gameDir.valid, isTrue);
        await expectLater(service.setAssetGameDir(''), throwsFormatException);

        // 3) 세 BundleRevision 불일치: 사용자 지정은 남고 이유가 바뀐다.
        File(
          _join([
            game.path,
            'BlueArchive_Data',
            'StreamingAssets',
            'PUB',
            'Resource',
            'Preload',
            'BundleRevision',
          ]),
        ).writeAsStringSync('124');
        final mismatch = await service.assetPrepareStatus();
        expect(mismatch.gameDir.source, AssetGameDirSource.user);
        expect(mismatch.gameDir.valid, isFalse);
        expect(
          mismatch.gameDir.reason,
          AssetGameDirReason.bundleRevisionMismatch,
        );
        expect(mismatch.gameDir.bundleRevision, isNull);
        expect(mismatch.cache.state, AssetCacheState.unknown);

        // 4) 폴더 없음(이름을 바꿔 치움): start는 작업 없이 거절된다.
        game.renameSync(_join([root.path, 'ba_fake_game_moved']));
        final gone = await service.assetPrepareStatus();
        expect(gone.gameDir.source, AssetGameDirSource.user);
        expect(gone.gameDir.reason, AssetGameDirReason.gameDirNotFound);
        final rejected = await _failure(service.startAssetPreparation());
        expect(rejected?.code, AssetPrepareErrorCode.invalidGameDir);
        expect(rejected?.reason, AssetGameDirReason.gameDirNotFound);
        expect((await service.assetPrepareStatus()).job, isNull);

        // 5) 옛 cursor는 job_not_found.
        final stale = AssetPrepareJobRef(
          jobId: 'f2d0000000000000000000000000dead',
          generation: 1,
        );
        expect(
          (await _failure(service.assetPrepareSnapshot(stale)))?.code,
          AssetPrepareErrorCode.jobNotFound,
        );
        expect(
          (await _failure(service.cancelAssetPreparation(stale)))?.code,
          AssetPrepareErrorCode.jobNotFound,
        );

        // 6) 재시작 뒤: 사용자 지정은 남고 작업 · 결과는 없다.
        await service.restartBackend();
        final restarted = await service.assetPrepareStatus();
        expect(restarted.gameDir.source, AssetGameDirSource.user);
        expect(restarted.gameDir.reason, AssetGameDirReason.gameDirNotFound);
        expect(restarted.job, isNull);
        expect(restarted.lastResult, isNull);
        expect(restarted.metadata.toWire()['jp_update_required'], isNull);

        expect(events, isEmpty);
        expect(errors, isEmpty);
        expect(service.state.value.connection, BackendConnection.connected);
        expect(
          Directory(cache).existsSync(),
          isFalse,
          reason: 'no extraction ran',
        );
      } finally {
        await subscription.cancel();
        await service.dispose();
        try {
          await root.delete(recursive: true);
        } on FileSystemException {
          // Windows가 파일을 늦게 놓으면 임시 폴더는 남겨 둔다.
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
