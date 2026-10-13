// fb10b-dart process E2E: 실제 백엔드(임시 저장소)에서 FB-10b 확인 필요 표시의 왕복을 본다
// (XB 시나리오, `debug/xb_fb10b_product_20261012/artifacts/CF-CONNECTION.md`).
//
// 부분 스캔 commit → 재시작 → 뺀 key 표시(이전 수량 그대로, 이전 수량이 없던 key는 표시만) → B를 같은 값으로
// 확인 + B scope → 같은 key·다른 scope 오류 → 재시작 → B 해제(관계없는 key 표시 유지) → 원 revision·key·scope
// 재요청 = 원 응답 → scope 밖 수량 변경 거부. 다른 계정은 처음부터 끝까지 그대로다.
//
// 실제 게임 없이 돌리려고 기존 scanner process E2E(`tests.scanner_e2e_backend`)와 같은 방식으로 백엔드 클래스만
// 조립하는 inline 진입점을 쓴다(인벤토리 matcher가 고정 후보 하나를 낸다). backend 파일은 바꾸지 않는다.
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = 'Item_Icon_SkillBook_Abydos_0';
const _b = 'Item_Icon_SkillBook_Abydos_1';
const _c = 'Item_Icon_SkillBook_Abydos_2';
const _d = 'Item_Icon_SkillBook_Abydos_3';

Map<String, Object?> _quantities(RepositoryState state) => {
  for (final entry in state.inventory.entries)
    (entry['item_id'] ?? entry['key']) as String: entry['quantity'],
};

Matcher _remote(String code, [String? reason]) => isA<BackendRemoteException>()
    .having((error) => error.code, 'code', code)
    .having((error) => error.details?['reason'], 'reason', reason ?? anything);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'partial scan flags survive restart, unchanged acknowledgement clears only B, replay keeps the original response',
    () async {
      final storageRoot = await Directory.systemTemp.createTemp(
        'ba_planner_v7_fb10b_e2e_',
      );
      final backendDirectory = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}backend',
      );
      final virtualEnvironmentPython = File(
        '${backendDirectory.path}${Platform.pathSeparator}.venv'
        '${Platform.pathSeparator}${Platform.isWindows ? 'Scripts' : 'bin'}'
        '${Platform.pathSeparator}${Platform.isWindows ? 'python.exe' : 'python'}',
      );
      final executable = virtualEnvironmentPython.existsSync()
          ? virtualEnvironmentPython.absolute.path
          : Platform.isWindows
          ? 'py'
          : 'python3';
      final usesPyLauncher =
          executable.split(RegExp(r'[/\\]')).last.toLowerCase() == 'py';
      final config = BackendProcessConfig(
        executable: executable,
        arguments: [
          if (Platform.isWindows && usesPyLauncher) '-3.11',
          // XB 공용 test-only 진입점(실제 저장소·프로토콜·스캐너 세션 + 고정 인벤토리 matcher A 7, B 99, C 70, D 5).
          '-m',
          'tests.inventory_e2e_backend',
        ],
        workingDirectory: backendDirectory.absolute.path,
        environment: {
          'BA_PLANNER_STORAGE_ROOT': storageRoot.path,
          'BA_PLANNER_ASSET_DIR': backendDirectory.absolute.path,
        },
      );
      final startedProcesses = <BackendProcessHandle>[];
      Future<BackendProcessHandle> startTrackedProcess() async {
        final process = await startBackendProcess(config);
        startedProcesses.add(process);
        return process;
      }

      final service = ProcessAppService(
        PlanningProtocolClient(
          startTrackedProcess,
          defaultTimeout: const Duration(seconds: 10),
        ),
      );

      var completed = false;
      try {
        await service.reconnect();
        final main = await service.createProfile(
          'FB10b E2E',
          'fb10b-e2e-main',
          avatarStudentId: 'airi',
        );
        final other = await service.createProfile(
          'FB10b Other',
          'fb10b-e2e-other',
          avatarStudentId: 'airi',
        );
        final seed = RepositoryInventoryState.fromWire({
          'version': 1,
          'entries': [
            for (final (key, quantity) in [(_a, '3'), (_b, '9'), (_c, '7')])
              {'key': key, 'item_id': key, 'quantity': quantity},
          ],
        });
        for (final profile in [main, other]) {
          final state = await service.loadRepositoryState(profile.id);
          await service.saveRepositoryInventory(
            profile.id,
            seed,
            state.revision,
            'fb10b-e2e-seed-${profile.id}',
          );
        }
        final otherBefore = await service.loadRepositoryState(other.id);
        final initial = await service.loadRepositoryState(main.id);
        expect(
          (await service.loadRepositoryInventoryReview(main.id)).needsReviewKeys,
          isEmpty,
        );

        // 1. 부분 스캔: 후보 A·B·C·D 중 A만 승인한다.
        final target = (await service.listScannerTargets()).single;
        final session = await service.startScannerSession(
          ScannerKind.inventory,
          target.id,
          profileId: main.id,
          inventoryScanProfile: InventoryScanProfile.techNotes,
        );
        await service.scannerEvents
            .firstWhere(
              (event) =>
                  event.sessionId == session.id &&
                  event.eventKind == ScannerEventKind.terminal,
            )
            .timeout(const Duration(seconds: 10));
        final candidate = (await service.scannerSnapshot(session)).candidates.single;
        expect(
          [
            for (final entry in candidate.payload['entries'] as List)
              (entry as Map)['key'],
          ],
          [_a, _b, _c, _d],
        );
        final approved = await service.reviewScannerCandidate(
          session,
          candidate,
          {
            'version': 1,
            'catalog_revision': candidate.payload['catalog_revision'],
            'entries': [
              {'key': _a, 'item_id': _a, 'quantity': '7'},
            ],
          },
          approve: true,
          reason: 'fb10b_e2e_partial',
        );
        final committed = await service.commitScannerCandidate(
          session,
          approved,
          profileId: main.id,
          expectedRepositoryRevision: initial.revision,
          idempotencyKey: 'fb10b-e2e-scan',
        );
        expect(committed['revision'], initial.revision + 1);

        // 2. 재시작 뒤: 승인 A만 바뀌고, 뺀 B·C는 이전 수량 + 표시, 이전 수량이 없던 D는 표시만.
        await service.restartBackend();
        var state = await service.loadRepositoryState(main.id);
        var review = await service.loadRepositoryInventoryReview(main.id);
        expect(state.revision, initial.revision + 1);
        expect(review.revision, state.revision);
        expect(review.profileId, main.id);
        expect(review.needsReviewKeys, [_b, _c, _d]);
        expect(review.needsReview(_a), isFalse);
        expect(_quantities(state), {_a: '7', _b: '9', _c: '7'});

        // 3. B를 같은 값으로 확인(scope = B): 수량 그대로, B만 해제.
        final unchanged = state.inventory;
        final acknowledged = await service.saveRepositoryInventory(
          main.id,
          unchanged,
          state.revision,
          'fb10b-e2e-ack-b',
          appliedResourceKeys: const [_b],
        );
        expect(acknowledged, state.revision + 1);
        // 같은 key·다른 scope = idempotency_conflict.
        await expectLater(
          service.saveRepositoryInventory(
            main.id,
            unchanged,
            state.revision,
            'fb10b-e2e-ack-b',
            appliedResourceKeys: const [_b, _c],
          ),
          throwsA(_remote('idempotency_conflict')),
        );

        // 4. 재시작 뒤: B 해제, 관계없는 C·D는 그대로, 수량도 그대로.
        await service.restartBackend();
        final afterAck = await service.loadRepositoryState(main.id);
        review = await service.loadRepositoryInventoryReview(main.id);
        expect(afterAck.revision, acknowledged);
        expect(review.revision, acknowledged);
        expect(review.needsReviewKeys, [_c, _d]);
        expect(_quantities(afterAck), {_a: '7', _b: '9', _c: '7'});

        // 5. 원 revision·key·scope 재요청 = 원 응답(두 번 쓰지 않는다).
        expect(
          await service.saveRepositoryInventory(
            main.id,
            unchanged,
            state.revision,
            'fb10b-e2e-ack-b',
            appliedResourceKeys: const [_b],
          ),
          acknowledged,
        );
        expect((await service.loadRepositoryState(main.id)).revision, acknowledged);

        // 6. scope 밖 수량 변경은 쓰지 않고 거부한다.
        await expectLater(
          service.saveRepositoryInventory(
            main.id,
            RepositoryInventoryState.fromWire({
              ...afterAck.inventory.toWire(),
              'entries': [
                for (final entry in afterAck.inventory.entries)
                  {...entry, if (entry['key'] == _c) 'quantity': '8'},
              ],
            }),
            acknowledged,
            'fb10b-e2e-outside',
            appliedResourceKeys: const [_d],
          ),
          throwsA(_remote('invalid_payload', 'scan_scope_mismatch')),
        );
        state = await service.loadRepositoryState(main.id);
        expect(state.revision, acknowledged);
        expect(
          (await service.loadRepositoryInventoryReview(main.id)).needsReviewKeys,
          [_c, _d],
        );

        // 다른 계정은 수량·revision·표시 모두 그대로다.
        final otherAfter = await service.loadRepositoryState(other.id);
        expect(otherAfter.revision, otherBefore.revision);
        expect(_quantities(otherAfter), _quantities(otherBefore));
        expect(
          (await service.loadRepositoryInventoryReview(other.id)).needsReviewKeys,
          isEmpty,
        );
        completed = true;
      } finally {
        await service.dispose();
        final exitCodes = <int>[];
        for (final process in startedProcesses) {
          exitCodes.add(
            await process.exitCode.timeout(const Duration(seconds: 5)),
          );
        }
        if (storageRoot.existsSync()) {
          await storageRoot.delete(recursive: true);
        }
        expect(storageRoot.existsSync(), isFalse);
        if (completed) {
          expect(startedProcesses, hasLength(3));
          expect(exitCodes, everyElement(0));
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
