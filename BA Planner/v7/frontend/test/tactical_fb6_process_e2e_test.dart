// fb6-dart process E2E: 실제 백엔드(임시 저장소)에서 FB-6 전술 v2 쓰기와 명시적 v7-v1 이관의 왕복을 본다
// (XB guarded JSONL 시나리오, backend 로그 2026-10-14 08:43, `debug/xb_fb6_main_overlay_20261014/artifacts/`).
//
// v1 기록 → v2 새 쓰기 `legacy_migration_required` → 미리보기 → v1 변경 뒤 commit `import_source_changed` → 새 미리보기로
// commit → v1 새 쓰기 `tactical_v1_read_only`(원 v1 재요청은 원 응답) → v2 기록·족보 upsert/delete(별칭·lineage·
// idempotency·revision 오류 포함) → 재시작 → 원 요청 재전송이 삭제된 레코드를 되살리지 않음.
//
// 진입점은 XB `fb6_rpc_fixture_backend.py`와 같은 내용을 inline(`-c`)으로 둔다: 메인 ApplicationProtocolV1만 띄우고
// 스캐너는 붙이지 않으며, 명시적 `BA_PLANNER_STORAGE_ROOT`가 시스템 임시 폴더 아래 `ba_planner_fb6_rpc_` 폴더가 아니면
// 시작하지 않는다. XB 공용 진입점이 메인에 생기면 그쪽으로 옮긴다(fb10c 선례). backend 파일은 바꾸지 않는다.
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _backendScript = r'''
import os
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, os.getcwd())

from core.application_protocol_v1 import ApplicationProtocolV1
from core.stdio_server import serve

raw = os.environ.get('BA_PLANNER_STORAGE_ROOT')
if not raw:
    raise RuntimeError('synthetic FB6 fixture requires an explicit storage root')
root = Path(raw).resolve()
if (not root.is_relative_to(Path(tempfile.gettempdir()).resolve())
        or not root.name.startswith('ba_planner_fb6_rpc_') or not root.is_dir()):
    raise RuntimeError('synthetic FB6 fixture refuses non-temporary/non-owned root')
sys.stdin.reconfigure(encoding='utf-8')
sys.stdout.reconfigure(encoding='utf-8')
serve(protocol=ApplicationProtocolV1(storage_root=root))
''';

Matcher _remote(String code) =>
    isA<BackendRemoteException>().having((error) => error.code, 'code', code);

TacticalSlotObservation _slot(
  int position,
  String? id, {
  bool wildcard = false,
}) => TacticalSlotObservation(
  position: position,
  studentId: id,
  state: id == null ? 'unknown' : 'manual',
  source: 'manual',
  confidence: null,
  reviewStatus: id == null && !wildcard ? 'unreviewed' : 'confirmed',
  wildcard: wildcard,
);

TacticalDeckV2 _deck({bool wildcardLast = false}) => TacticalDeckV2(
  strikers: [
    _slot(0, 'shiroko'),
    _slot(1, 'akane'),
    _slot(2, 'yuuka'),
    wildcardLast ? _slot(3, null, wildcard: true) : _slot(3, 'mika'),
  ],
  specials: [_slot(0, 'serina'), _slot(1, 'hibiki')],
);

TacticalMatchInputV2 _match(String id, {String name = 'Rival'}) =>
    TacticalMatchInputV2(
      id: id,
      kind: 'attack',
      occurredAt: '2026-10-13T21:10:00+09:00',
      occurredPrecision: 'instant',
      season: '34',
      opponentIdentityId: 'opponent-one',
      opponentDisplayName: name,
      result: 'win',
      attackDeck: _deck(),
      defenseDeck: _deck(),
      notes: 'original',
      attemptCount: 3,
    );

TacticalMatch _v1Match(String id, {String? occurredOn = '2026-10-13'}) =>
    TacticalMatch(
      id: id,
      kind: 'attack',
      occurredOn: occurredOn,
      season: '34',
      opponent: 'Rival',
      result: 'win',
      attackDeck: TacticalDeck(
        strikers: const ['shiroko', null, null, null],
        specials: const ['serina', null],
      ),
      defenseDeck: TacticalDeck(
        strikers: const ['akane', null, null, null],
        specials: const ['hibiki', null],
      ),
      notes: 'retain',
    );

List<String> _ids(Iterable<String> values) => values.toList()..sort();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'explicit v1 migration, v2 writes and restart replay never restore deleted records',
    () async {
      final created = await Directory.systemTemp.createTemp(
        'ba_planner_fb6_rpc_',
      );
      final storageRoot = Directory(created.resolveSymbolicLinksSync());
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
          '-c',
          _backendScript,
        ],
        workingDirectory: backendDirectory.absolute.path,
        environment: {
          'BA_PLANNER_STORAGE_ROOT': storageRoot.path,
          'PYTHONDONTWRITEBYTECODE': '1',
        },
      );
      final startedProcesses = <BackendProcessHandle>[];
      final service = ProcessAppService(
        PlanningProtocolClient(() async {
          final process = await startBackendProcess(config);
          startedProcesses.add(process);
          return process;
        }, defaultTimeout: const Duration(seconds: 20)),
      );

      var completed = false;
      try {
        await service.reconnect();
        final profile = await service.createProfile(
          'Synthetic FB6 RPC',
          'fb6-dart-e2e-profile',
          avatarStudentId: 'airi',
        );
        final pid = profile.id;
        await service.saveRepositoryStudents(
          pid,
          [
            for (final id in [
              'shiroko',
              'akane',
              'yuuka',
              'mika',
              'serina',
              'hibiki',
            ])
              ConfirmedStudentState.fromValues(id, {}),
          ],
          0,
          'fb6-owned',
        );

        // v1 기록 2개(기록·족보) → v2 새 쓰기는 명시적 이관이 먼저다.
        expect(
          await service.saveTacticalMatch(
            pid,
            _v1Match('m1'),
            0,
            'legacy-seed',
          ),
          1,
        );
        expect(
          await service.saveTacticalJokbo(
            pid,
            TacticalJokbo(
              id: 'j1',
              defenseDeck: TacticalDeck(
                strikers: const ['akane', null, null, null],
                specials: const ['hibiki', null],
              ),
              attackDeck: TacticalDeck(
                strikers: const ['shiroko', null, null, null],
                specials: const ['serina', null],
              ),
              notes: 'legacy notes',
            ),
            1,
            'legacy-jokbo',
          ),
          2,
        );
        await expectLater(
          service.upsertTacticalMatchV2(
            profileId: pid,
            match: _match('manual-one'),
            expectedRevision: 0,
            idempotencyKey: 'manual',
          ),
          throwsA(_remote('legacy_migration_required')),
        );
        final stale = await service.previewTacticalLegacyMigration(pid);
        expect(
          (
            stale.sourceRevision,
            stale.matchCount,
            stale.jokboCount,
            stale.issues.length,
            stale.v1WritesDisabled,
          ),
          (2, 1, 1, 0, false),
        );
        // 미리보기 뒤 v1이 바뀌면 commit은 거부된다(아무것도 쓰지 않음).
        expect(
          await service.saveTacticalMatch(
            pid,
            _v1Match('m2', occurredOn: null),
            2,
            'legacy-late',
          ),
          3,
        );
        await expectLater(
          service.commitTacticalLegacyMigration(
            profileId: pid,
            expectedSourceRevision: stale.sourceRevision,
            expectedFingerprint: stale.sourceFingerprint,
            expectedRevision: 0,
            idempotencyKey: 'migration',
          ),
          throwsA(_remote('import_source_changed')),
        );
        final preview = await service.previewTacticalLegacyMigration(pid);
        expect(preview.sourceRevision, 3);
        expect(preview.sourceFingerprint, isNot(stale.sourceFingerprint));
        final migrated = await service.commitTacticalLegacyMigration(
          profileId: pid,
          expectedSourceRevision: preview.sourceRevision,
          expectedFingerprint: preview.sourceFingerprint,
          expectedRevision: 0,
          idempotencyKey: 'migration',
        );
        expect(
          (
            migrated.revision,
            migrated.importedMatches,
            migrated.importedJokbo,
            migrated.v1WritesDisabled,
          ),
          (1, 2, 1, true),
        );
        expect(
          (await service.previewTacticalLegacyMigration(pid)).v1WritesDisabled,
          isTrue,
        );
        await expectLater(
          service.commitTacticalLegacyMigration(
            profileId: pid,
            expectedSourceRevision: preview.sourceRevision,
            expectedFingerprint: preview.sourceFingerprint,
            expectedRevision: 1,
            idempotencyKey: 'migration-again',
          ),
          throwsA(_remote('legacy_already_migrated')),
        );

        // v1 새 쓰기는 read-only, 원 v1 재요청은 원 응답, v1 읽기는 그대로.
        await expectLater(
          service.saveTacticalMatch(pid, _v1Match('m3'), 3, 'new-v1'),
          throwsA(_remote('tactical_v1_read_only')),
        );
        expect(
          await service.saveTacticalMatch(
            pid,
            _v1Match('m1'),
            0,
            'legacy-seed',
          ),
          1,
        );
        final v1 = await service.loadTacticalState(pid);
        expect((v1.revision, v1.matches.length, v1.jokbo.length), (3, 2, 1));

        final imported = await service.loadTacticalEvidenceState(pid);
        expect(imported.revision, 1);
        expect(imported.matches, hasLength(2));
        expect(imported.matches.map((item) => item.attemptCount), [null, null]);
        expect(imported.matches.map((item) => item.occurredPrecision).toSet(), {
          'date',
          'unknown',
        });
        expect(
          imported.matches
              .firstWhere((item) => item.occurredPrecision == 'date')
              .occurredAt,
          startsWith('2026-10-13T00:00:00+09:00'),
        );
        expect(imported.matches.map((item) => item.sourceLabel).toSet(), {
          'v7_v1_migration',
        });
        expect(imported.jokbo.where((item) => item.name == null), isEmpty);

        // v2 기록 쓰기: 시도 횟수·정밀도 보존, 자동 족보 1개.
        final saved = await service.upsertTacticalMatchV2(
          profileId: pid,
          match: _match('manual-one'),
          expectedRevision: 1,
          idempotencyKey: 'manual',
        );
        expect(saved.revision, 2);
        expect(saved.match.attemptCount, 3);
        expect(saved.match.occurredPrecision, 'instant');
        expect(saved.match.sourceLabel, 'manual_record');
        expect(saved.jokboIds, hasLength(1));
        final lineage = saved.jokboIds.single;
        expect(lineage, startsWith('lineage-'));
        await expectLater(
          service.upsertTacticalMatchV2(
            profileId: pid,
            match: _match('manual-two', name: 'Different'),
            expectedRevision: 2,
            idempotencyKey: 'alias',
          ),
          throwsA(_remote('opponent_alias_required')),
        );

        final jokbo = TacticalJokboInputV2(
          id: 'manual-jokbo',
          name: 'Synthetic',
          attackDeck: _deck(),
          defenseDeck: _deck(),
          notes: 'temporary',
        );
        final savedJokbo = await service.upsertTacticalJokboV2(
          profileId: pid,
          jokbo: jokbo,
          expectedRevision: 2,
          idempotencyKey: 'jokbo',
        );
        expect((savedJokbo.revision, savedJokbo.jokbo.name), (3, 'Synthetic'));
        await expectLater(
          service.upsertTacticalJokboV2(
            profileId: pid,
            jokbo: TacticalJokboInputV2(
              id: lineage,
              name: 'Redefined',
              attackDeck: _deck(),
              defenseDeck: _deck(wildcardLast: true),
              notes: '',
            ),
            expectedRevision: 3,
            idempotencyKey: 'redefine',
          ),
          throwsA(_remote('lineage_conflict')),
        );
        await expectLater(
          service.upsertTacticalJokboV2(
            profileId: pid,
            jokbo: TacticalJokboInputV2(
              id: 'manual-jokbo',
              name: 'Other',
              attackDeck: _deck(),
              defenseDeck: _deck(),
              notes: 'temporary',
            ),
            expectedRevision: 3,
            idempotencyKey: 'jokbo',
          ),
          throwsA(_remote('idempotency_conflict')),
        );
        await expectLater(
          service.deleteTacticalJokboV2(
            profileId: pid,
            jokboId: 'manual-jokbo',
            expectedRevision: 2,
            idempotencyKey: 'stale-delete',
          ),
          throwsA(_remote('revision_conflict')),
        );
        expect(
          (await service.deleteTacticalJokboV2(
            profileId: pid,
            jokboId: 'manual-jokbo',
            expectedRevision: 3,
            idempotencyKey: 'jokbo-delete',
          )).revision,
          4,
        );
        expect(
          (await service.deleteTacticalMatchV2(
            profileId: pid,
            matchId: 'manual-one',
            expectedRevision: 4,
            idempotencyKey: 'match-delete',
          )).revision,
          5,
        );
        final before = await service.loadTacticalEvidenceState(pid);
        expect(before.revision, 5);
        expect(
          before.matches.map((item) => item.id),
          isNot(contains('manual-one')),
        );
        expect(
          before.jokbo.map((item) => item.id),
          isNot(contains('manual-jokbo')),
        );
        expect(
          before.snapshots.map((item) => item.matchId),
          isNot(contains('manual-one')),
        );

        // 재시작 뒤 같은 상태, 원 요청 재전송은 원 응답이고 삭제된 레코드를 되살리지 않는다.
        await service.restartBackend();
        final restored = await service.loadTacticalEvidenceState(pid);
        expect(restored.revision, before.revision);
        expect(
          _ids(restored.matches.map((item) => item.id)),
          _ids(before.matches.map((item) => item.id)),
        );
        expect(
          _ids(restored.jokbo.map((item) => item.id)),
          _ids(before.jokbo.map((item) => item.id)),
        );
        expect(
          _ids(restored.opponents.map((item) => item.id)),
          _ids(before.opponents.map((item) => item.id)),
        );
        final replayMigration = await service.commitTacticalLegacyMigration(
          profileId: pid,
          expectedSourceRevision: preview.sourceRevision,
          expectedFingerprint: preview.sourceFingerprint,
          expectedRevision: 0,
          idempotencyKey: 'migration',
        );
        expect(replayMigration.revision, migrated.revision);
        final replayMatch = await service.upsertTacticalMatchV2(
          profileId: pid,
          match: _match('manual-one'),
          expectedRevision: 1,
          idempotencyKey: 'manual',
        );
        expect(replayMatch.revision, saved.revision);
        expect(replayMatch.match.id, 'manual-one');
        expect(
          (await service.upsertTacticalJokboV2(
            profileId: pid,
            jokbo: jokbo,
            expectedRevision: 2,
            idempotencyKey: 'jokbo',
          )).revision,
          3,
        );
        final after = await service.loadTacticalEvidenceState(pid);
        expect(after.revision, 5);
        expect(
          after.matches.map((item) => item.id),
          isNot(contains('manual-one')),
        );
        expect(
          after.jokbo.map((item) => item.id),
          isNot(contains('manual-jokbo')),
        );
        completed = true;
      } finally {
        await service.dispose();
        final exitCodes = <int>[];
        for (final process in startedProcesses) {
          exitCodes.add(
            await process.exitCode.timeout(const Duration(seconds: 10)),
          );
        }
        if (created.existsSync()) {
          await created.delete(recursive: true);
        }
        expect(created.existsSync(), isFalse);
        if (completed) {
          expect(startedProcesses, hasLength(2));
          expect(exitCodes, everyElement(0));
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
