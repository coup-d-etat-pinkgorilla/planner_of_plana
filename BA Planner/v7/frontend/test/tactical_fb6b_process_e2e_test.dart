// fb6b-dart process E2E: 실제 백엔드(임시 저장소)에서 FB-6b(FD-176) 왕복을 본다 — 시도 횟수 null(모름) 기록과
// 상대 없는 방어 기록 저장 → 같은 key 재요청 = 원 응답 → 읽기 · 통계 · 추이에서 상대 미상 행 처리 → 재시작.
//
// 진입점은 fb6 E2E(`tactical_fb6_process_e2e_test.dart`)와 같은 inline(`-c`) guarded 진입점이다: 메인
// ApplicationProtocolV1만 띄우고, 명시적 `BA_PLANNER_STORAGE_ROOT`가 시스템 임시 폴더 아래 `ba_planner_fb6_rpc_` 폴더가
// 아니면 시작하지 않는다. backend 파일은 바꾸지 않는다.
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
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

TacticalSlotObservation _slot(int position, String id) =>
    TacticalSlotObservation(
      position: position,
      studentId: id,
      state: 'manual',
      source: 'manual',
      confidence: null,
      reviewStatus: 'confirmed',
      wildcard: false,
    );

/// 보유 학생 6명의 내 덱.
final _mine = TacticalDeckV2(
  strikers: [
    _slot(0, 'shiroko'),
    _slot(1, 'akane'),
    _slot(2, 'yuuka'),
    _slot(3, 'mika'),
  ],
  specials: [_slot(0, 'serina'), _slot(1, 'hibiki')],
);

/// 상대 덱(보유 검사 없음, 역할 검사는 있음). fb6 E2E처럼 같은 편성을 쓴다.
final _theirs = _mine;

/// 시도 모르는 공격 기록(상대 있음).
TacticalMatchInputV2 _unknownAttemptAttack() => TacticalMatchInputV2(
  id: 'attack-unknown',
  kind: 'attack',
  occurredAt: '2026-10-15T12:00:00Z',
  occurredPrecision: 'instant',
  season: '34',
  opponentIdentityId: 'opponent-one',
  opponentDisplayName: 'Rival',
  result: 'win',
  attackDeck: _mine,
  defenseDeck: _theirs,
  notes: '',
  attemptCount: null,
);

/// 상대 없는 방어 기록(FD-176 null 쌍).
TacticalMatchInputV2 _anonymousDefense(String id, {int? attempt}) =>
    TacticalMatchInputV2(
      id: id,
      kind: 'defense',
      occurredAt: '2026-10-15T13:00:00Z',
      occurredPrecision: 'instant',
      season: '34',
      opponentIdentityId: null,
      opponentDisplayName: null,
      result: 'loss',
      attackDeck: _theirs,
      defenseDeck: _mine,
      notes: '',
      attemptCount: attempt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unknown attempt and anonymous defense round-trip through the real backend',
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
          'Synthetic FB6b RPC',
          'fb6b-dart-e2e-profile',
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
          'fb6b-owned',
        );

        // 시도 모르는 공격 기록: null 그대로 저장, 상대 identity와 자동 족보는 생긴다.
        final attack = await service.upsertTacticalMatchV2(
          profileId: pid,
          match: _unknownAttemptAttack(),
          expectedRevision: 0,
          idempotencyKey: 'unknown-attempt',
        );
        expect(attack.revision, 1);
        expect(attack.match.attemptCount, isNull);
        expect(attack.match.opponentIdentityId, 'opponent-one');
        expect(attack.jokboIds, hasLength(1));

        // 상대 없는 방어 기록: null 쌍 그대로, 자동 족보 없음.
        final anonymous = await service.upsertTacticalMatchV2(
          profileId: pid,
          match: _anonymousDefense('defense-anonymous'),
          expectedRevision: 1,
          idempotencyKey: 'anonymous',
        );
        expect(anonymous.revision, 2);
        expect(anonymous.match.kind, 'defense');
        expect(anonymous.match.opponentIdentityId, isNull);
        expect(anonymous.match.opponentDisplayName, isNull);
        expect(anonymous.match.attemptCount, isNull);
        expect(anonymous.jokboIds, isEmpty);

        // 같은 key 재요청 = 원 응답.
        final replay = await service.upsertTacticalMatchV2(
          profileId: pid,
          match: _anonymousDefense('defense-anonymous'),
          expectedRevision: 1,
          idempotencyKey: 'anonymous',
        );
        expect(replay.revision, anonymous.revision);
        expect(replay.match.id, anonymous.match.id);
        expect(replay.match.opponentIdentityId, isNull);
        expect(replay.match.createdAt, anonymous.match.createdAt);

        // 같은 내용의 두 번째 익명 방어(다른 ID): 같은 상대로 묶이지 않는다.
        final second = await service.upsertTacticalMatchV2(
          profileId: pid,
          match: _anonymousDefense('defense-anonymous-2'),
          expectedRevision: 2,
          idempotencyKey: 'anonymous-2',
        );
        expect(second.revision, 3);

        final state = await service.loadTacticalEvidenceState(pid);
        expect(state.revision, 3);
        expect(state.matches, hasLength(3));
        expect(state.opponents.map((item) => item.id), ['opponent-one']);
        expect(state.opponents.single.aliases, ['Rival']);
        final anonymousRows = state.matches
            .where((item) => item.opponentIdentityId == null)
            .toList();
        expect(anonymousRows, hasLength(2));
        expect(
          anonymousRows.every(
            (item) =>
                item.kind == 'defense' &&
                item.opponentDisplayName == null &&
                item.attemptCount == null,
          ),
          isTrue,
        );
        expect(
          state.snapshots.map((item) => item.matchId),
          isNot(contains(startsWith('defense-anonymous'))),
        );

        // 통계: 전체 · 방어 수에는 남고 상대별 행 · 상대 수에서는 빠진다.
        final stats = await service.queryTacticalStatistics(
          pid,
          const TacticalStatsFilters(),
        );
        expect(stats.population.matchCount, 3);
        expect(stats.population.attackMatchCount, 1);
        expect(stats.population.defenseMatchCount, 2);
        expect(stats.population.opponentCount, 1);
        expect(stats.opponentTotal, 1);
        expect(stats.opponents.single.opponentIdentityId, 'opponent-one');
        expect(stats.opponents.single.matchCount, 1);
        expect(stats.quality['distinct_opponent_count'], 1);
        expect(stats.quality['match_kind_counts'], {'attack': 1, 'defense': 2});
        expect(stats.quality['suspected_duplicate_count'], 0);
        // 추이도 strict DTO로 읽힌다(로비 관측이 없어 상대 행 0).
        final trends = await service.queryTacticalTrends(
          pid,
          const TacticalTrendFilters(asOf: '2026-10-16T00:00:00+09:00'),
        );
        expect(trends.freshness, isEmpty);

        // 고쳐서 시도를 알게 된다(상대는 여전히 모름).
        final edited = await service.upsertTacticalMatchV2(
          profileId: pid,
          match: _anonymousDefense('defense-anonymous', attempt: 2),
          expectedRevision: 3,
          idempotencyKey: 'anonymous-edit',
        );
        expect(edited.revision, 4);
        expect(edited.match.attemptCount, 2);
        expect(edited.match.opponentIdentityId, isNull);

        // 재시작 뒤 같은 상태, 원 요청 재전송은 원 응답이고 고친 값을 되돌리지 않는다.
        await service.restartBackend();
        final restored = await service.loadTacticalEvidenceState(pid);
        expect(restored.revision, 4);
        final restoredReplay = await service.upsertTacticalMatchV2(
          profileId: pid,
          match: _anonymousDefense('defense-anonymous'),
          expectedRevision: 1,
          idempotencyKey: 'anonymous',
        );
        expect(restoredReplay.revision, 2);
        expect(restoredReplay.match.attemptCount, isNull);
        final after = await service.loadTacticalEvidenceState(pid);
        expect(after.revision, 4);
        expect(
          after.matches
              .firstWhere((item) => item.id == 'defense-anonymous')
              .attemptCount,
          2,
        );
        expect(after.opponents, hasLength(1));
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
