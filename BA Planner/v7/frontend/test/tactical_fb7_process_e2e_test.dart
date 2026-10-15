// fb7-dart process E2E: 실제 백엔드(임시 저장소)에서 FB-7 CSV 가져오기 왕복을 본다(XB `810a15f2`,
// `debug/xb_fb7_interpreter_prepare_20261014/artifacts/dart-handoff-final.md`).
//
// 임시 UTF-8 CSV → 매핑 없는 미리보기(후보만) → 확정 매핑 미리보기(확인 필요 문자열 그룹) → 미해결 commit 거부 →
// resolution → commit → 같은 요청 재전송 = 원 응답 → 원본 파일을 지운 뒤 재전송도 원 응답 → v2 상태에 기록·묶음 반영 →
// 같은 바이트를 다시 두면 replay(재가져오기 0) → 원본·해석 변경 거부 → 재시작 뒤 원 요청 = 원 응답.
// XLSX는 계약 fixture에 바이트가 없어 이 E2E에서 만들지 않는다(status "미검증").
//
// 진입점은 fb6 E2E와 같은 inline(`-c`) 가드다: 메인 ApplicationProtocolV1만 띄우고 스캐너는 붙이지 않으며, 명시적
// `BA_PLANNER_STORAGE_ROOT`가 시스템 임시 폴더 아래 `ba_planner_fb7_rpc_` 폴더가 아니면 시작하지 않는다.
// 실제 사용자 프로필·게임·공용 저장소에 접근하지 않는다. backend 파일은 바꾸지 않는다.
import 'dart:convert';
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
    raise RuntimeError('synthetic FB7 fixture requires an explicit storage root')
root = Path(raw).resolve()
if (not root.is_relative_to(Path(tempfile.gettempdir()).resolve())
        or not root.name.startswith('ba_planner_fb7_rpc_') or not root.is_dir()):
    raise RuntimeError('synthetic FB7 fixture refuses non-temporary/non-owned root')
sys.stdin.reconfigure(encoding='utf-8')
sys.stdout.reconfigure(encoding='utf-8')
serve(protocol=ApplicationProtocolV1(storage_root=root))
''';

const _deck = ['shiroko', 'akane', 'yuuka', 'mika', 'serina', 'hibiki'];

TypeMatcher<BackendRemoteException> _remote(String code) =>
    isA<BackendRemoteException>().having((error) => error.code, 'code', code);

/// 머리글(영문 필드 이름) + 날짜만 있는 행 + 확인이 필요한 행(한글 종류·`승(3트)`·빈 시도·오타 학생) + 빈 행.
String _csv() {
  final rows = [
    tacticalExcelFields,
    [
      '2026-10-14',
      'attack',
      '라이벌',
      '34',
      'win',
      '2',
      'keep original',
      ..._deck,
      ..._deck,
    ],
    [
      '2026-10-15T21:10:00+09:00',
      '공격',
      '라이벌',
      '34',
      '승(3트)',
      '',
      '',
      'shirok',
      ..._deck.skip(1),
      ..._deck,
    ],
    [for (final _ in tacticalExcelFields) ''],
  ];
  return '﻿${rows.map((row) => row.join(',')).join('\r\n')}\r\n';
}

TacticalExcelStringGroup _group(TacticalExcelPreview preview, String field) =>
    preview.stringGroups.singleWhere((group) => group.field == field);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'CSV preview, explicit resolutions, atomic commit and original retries',
    () async {
      final created = await Directory.systemTemp.createTemp(
        'ba_planner_fb7_rpc_',
      );
      final storageRoot = Directory(created.resolveSymbolicLinksSync());
      final sourceDirectory = await Directory.systemTemp.createTemp(
        'ba_planner_fb7_src_',
      );
      final source = File(
        '${sourceDirectory.resolveSymbolicLinksSync()}'
        '${Platform.pathSeparator}records.csv',
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
          'Synthetic FB7 RPC',
          'fb7-dart-e2e-profile',
          avatarStudentId: 'airi',
        );
        final pid = profile.id;
        await service.saveRepositoryStudents(
          pid,
          [for (final id in _deck) ConfirmedStudentState.fromValues(id, {})],
          0,
          'fb7-owned',
        );
        final bytes = utf8.encode(_csv());
        await source.writeAsBytes(bytes, flush: true);

        TacticalExcelImportChoices choices({
          TacticalExcelColumnMapping? mapping,
          List<TacticalExcelResolution> resolutions = const [],
          String onConflict = 'skip',
        }) => TacticalExcelImportChoices(
          profileId: pid,
          sourcePath: source.path,
          sheetName: null,
          delimiter: ',',
          columnMapping: mapping,
          resolutions: resolutions,
          rowDecisions: const [],
          onConflict: onConflict,
        );

        // 매핑을 정하지 않으면 후보만 준다(확인 필요). 원본·저장소는 바뀌지 않는다.
        final unmapped = await service.previewTacticalExcelImport(choices());
        expect(unmapped.issues.map((item) => item.code), [
          'mapping_confirmation_required',
        ]);
        expect((unmapped.format, unmapped.selectedSheet), ('csv', 'CSV'));
        expect(unmapped.rows, isEmpty);
        final candidate = unmapped.mappingCandidates.single;
        expect(candidate.headerRow, 1);
        expect(candidate.ambiguousFields, isEmpty);
        final mapping = TacticalExcelColumnMapping(
          headerRow: candidate.headerRow,
          columns: candidate.columns,
        );
        expect(mapping.columns, {
          for (final (index, field) in tacticalExcelFields.indexed)
            field: index + 1,
        });

        final first = await service.previewTacticalExcelImport(
          choices(mapping: mapping),
        );
        expect(first.fingerprint, unmapped.fingerprint);
        expect(first.rows.map((row) => row.status), [
          'unresolved',
          'unresolved',
          'empty',
        ]);
        expect(
          (
            first.summary.readRows,
            first.summary.emptyRows,
            first.summary.unresolvedRows,
            first.summary.eligibleRows,
            first.currentRevision,
            first.legacyMigrationRequired,
          ),
          (3, 1, 2, 0, 0, false),
        );
        final opponent = _group(first, 'opponent');
        expect(
          (opponent.code, opponent.count, opponent.raw),
          ('opponent_resolution_required', 2, '라이벌'),
        );
        expect(opponent.rawKey, '{"type":"str","value":"라이벌"}');
        expect(_group(first, 'own_striker_1').code, 'student_unknown');
        expect(_group(first, 'attempts').code, 'positive_attempts_required');
        final result = _group(first, 'result');
        expect(result.code, 'result_resolution_required');
        expect(
          result.suggestions.single,
          isA<TacticalExcelResultSuggestion>().having(
            (item) => item.attemptCount,
            'attemptCount',
            3,
          ),
        );
        await expectLater(
          service.commitTacticalExcelImport(
            choices: choices(mapping: mapping),
            saveRules: false,
            expectedFingerprint: first.fingerprint,
            expectedInterpretationFingerprint: first.interpretationFingerprint,
            expectedRevision: 0,
            idempotencyKey: 'unresolved',
          ),
          throwsA(_remote('import_review_required')),
        );

        final resolved = choices(
          mapping: mapping,
          resolutions: [
            TacticalExcelResolution(
              field: 'opponent',
              raw: opponent.rawKey,
              action: 'value',
              value: TacticalExcelNewOpponentValue(
                identityId: 'rival-one',
                displayName: '라이벌',
              ),
            ),
            TacticalExcelResolution(
              field: 'own_striker_1',
              raw: _group(first, 'own_striker_1').rawKey,
              action: 'value',
              value: const TacticalExcelTextValue('shiroko'),
            ),
            TacticalExcelResolution(
              field: 'result',
              raw: result.rawKey,
              action: 'value',
              value: const TacticalExcelTextValue('win'),
              row: 3,
            ),
            TacticalExcelResolution(
              field: 'attempts',
              raw: _group(first, 'attempts').rawKey,
              action: 'value',
              value: const TacticalExcelIntegerValue(3),
              row: 3,
            ),
          ],
        );
        final preview = await service.previewTacticalExcelImport(resolved);
        expect(preview.stringGroups, isEmpty);
        expect(preview.rows.map((row) => row.status), [
          'eligible',
          'eligible',
          'empty',
        ]);
        expect(preview.summary.eligibleRows, 2);
        final dated = preview.rows[0].match!;
        final instant = preview.rows[1].match!;
        expect(
          (dated.occurredPrecision, dated.occurredAt, dated.attemptCount),
          ('date', '2026-10-14T00:00:00+09:00', 2),
        );
        expect(
          (
            instant.occurredPrecision,
            DateTime.parse(instant.occurredAt!),
            instant.attemptCount,
            instant.opponentIdentityId,
          ),
          ('instant', DateTime.utc(2026, 10, 15, 12, 10), 3, 'rival-one'),
        );
        // 다른 미리보기 지문으로는 commit할 수 없다.
        await expectLater(
          service.commitTacticalExcelImport(
            choices: resolved,
            saveRules: true,
            expectedFingerprint: preview.fingerprint,
            expectedInterpretationFingerprint: first.interpretationFingerprint,
            expectedRevision: 0,
            idempotencyKey: 'stale-interpretation',
          ),
          throwsA(_remote('import_interpretation_changed')),
        );

        Future<TacticalExcelCommitResult> commit() =>
            service.commitTacticalExcelImport(
              choices: resolved,
              saveRules: true,
              expectedFingerprint: preview.fingerprint,
              expectedInterpretationFingerprint:
                  preview.interpretationFingerprint,
              expectedRevision: 0,
              idempotencyKey: 'excel-import',
            );
        final committed = await commit();
        expect(
          (
            committed.revision,
            committed.importedCount,
            committed.overwrittenCount,
            committed.skippedCount,
            committed.rulesSaved,
          ),
          (1, 2, 0, 0, true),
        );
        expect(committed.matchIds, [dated.id, instant.id]);

        // 미리보기·commit은 원본 파일을 바꾸지 않는다.
        expect(await source.readAsBytes(), bytes);

        // 같은 요청 = 원 응답, 원본을 지운 뒤에도 원 응답(원본을 다시 읽기 전에 돌려준다).
        expect((await commit()).toWire(), committed.toWire());
        await source.delete();
        expect((await commit()).toWire(), committed.toWire());
        await expectLater(
          service.commitTacticalExcelImport(
            choices: resolved,
            saveRules: false,
            expectedFingerprint: preview.fingerprint,
            expectedInterpretationFingerprint:
                preview.interpretationFingerprint,
            expectedRevision: 0,
            idempotencyKey: 'excel-import',
          ),
          throwsA(_remote('idempotency_conflict')),
        );
        await expectLater(
          service.previewTacticalExcelImport(resolved),
          throwsA(
            _remote('import_source_unreadable').having(
              (error) => error.details?['reason'],
              'reason',
              'source_unavailable',
            ),
          ),
        );

        final state = await service.loadTacticalEvidenceState(pid);
        expect(state.revision, 1);
        expect(state.matches.map((item) => item.id), [dated.id, instant.id]);
        expect(state.matches.map((item) => item.sourceLabel).toSet(), {
          'csv_import',
        });
        expect(state.matches.map((item) => item.sourceRecordId), [
          preview.rows[0].rowId,
          preview.rows[1].rowId,
        ]);
        expect(state.matches.map((item) => item.attemptCount), [2, 3]);
        expect(state.matches.map((item) => item.notes), ['keep original', '']);
        expect(state.opponents.map((item) => item.id), ['rival-one']);
        expect(
          state.importBatches.single.sourceFingerprint,
          preview.fingerprint,
        );

        // 같은 바이트를 다시 두면 이미 가져온 원본 행은 replay이고 저장된 규칙이 돌아온다.
        await source.writeAsBytes(bytes, flush: true);
        final again = await service.previewTacticalExcelImport(resolved);
        expect(again.fingerprint, preview.fingerprint);
        expect(again.rows.take(2).map((row) => row.status), [
          'replay',
          'replay',
        ]);
        expect(again.rows.first.targetMatchId, dated.id);
        expect(
          (
            again.summary.eligibleRows,
            again.currentRevision,
            again.rulesRevision,
          ),
          (0, 1, 1),
        );
        expect(again.savedMapping?.toWire(), mapping.toWire());
        final unchanged = await service.commitTacticalExcelImport(
          choices: resolved,
          saveRules: true,
          expectedFingerprint: again.fingerprint,
          expectedInterpretationFingerprint: again.interpretationFingerprint,
          expectedRevision: 1,
          idempotencyKey: 'excel-replay',
        );
        expect(
          (
            unchanged.revision,
            unchanged.importedCount,
            unchanged.skippedCount,
            unchanged.rulesSaved,
          ),
          (1, 0, 2, false),
        );

        // 미리보기 뒤 원본 바이트가 바뀌면 거부, 다른 선택으로 바꿔도 거부(아무것도 쓰지 않음).
        await source.writeAsBytes(
          utf8.encode(_csv().replaceFirst('keep original', 'edited')),
          flush: true,
        );
        await expectLater(
          service.commitTacticalExcelImport(
            choices: resolved,
            saveRules: false,
            expectedFingerprint: again.fingerprint,
            expectedInterpretationFingerprint: again.interpretationFingerprint,
            expectedRevision: 1,
            idempotencyKey: 'changed-source',
          ),
          throwsA(_remote('import_source_changed')),
        );
        await source.writeAsBytes(bytes, flush: true);
        await expectLater(
          service.commitTacticalExcelImport(
            choices: TacticalExcelImportChoices(
              profileId: pid,
              sourcePath: source.path,
              sheetName: null,
              delimiter: ',',
              columnMapping: mapping,
              resolutions: resolved.resolutions,
              rowDecisions: const [],
              onConflict: 'overwrite',
            ),
            saveRules: false,
            expectedFingerprint: again.fingerprint,
            expectedInterpretationFingerprint: again.interpretationFingerprint,
            expectedRevision: 1,
            idempotencyKey: 'changed-choice',
          ),
          throwsA(_remote('import_interpretation_changed')),
        );
        expect((await service.loadTacticalEvidenceState(pid)).revision, 1);

        // v1 기록이 남은 프로필은 FB-6 명시 이관이 먼저다(자동 이관·쓰기 없음).
        final legacyProfile = await service.createProfile(
          'Synthetic FB7 legacy',
          'fb7-dart-e2e-legacy',
          avatarStudentId: 'airi',
        );
        await service.saveRepositoryStudents(
          legacyProfile.id,
          [for (final id in _deck) ConfirmedStudentState.fromValues(id, {})],
          0,
          'fb7-legacy-owned',
        );
        await service.saveTacticalMatch(
          legacyProfile.id,
          TacticalMatch(
            id: 'v1-one',
            kind: 'attack',
            occurredOn: '2026-10-12',
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
            notes: '',
          ),
          0,
          'legacy-seed',
        );
        final legacyChoices = TacticalExcelImportChoices(
          profileId: legacyProfile.id,
          sourcePath: source.path,
          sheetName: null,
          delimiter: ',',
          columnMapping: mapping,
          resolutions: const [],
          rowDecisions: const [],
          onConflict: 'skip',
        );
        final legacy = await service.previewTacticalExcelImport(legacyChoices);
        expect(legacy.legacyMigrationRequired, isTrue);
        expect(legacy.issues.map((item) => (item.code, item.sourceRevision)), [
          ('legacy_migration_required', 1),
        ]);
        await expectLater(
          service.commitTacticalExcelImport(
            choices: legacyChoices,
            saveRules: true,
            expectedFingerprint: legacy.fingerprint,
            expectedInterpretationFingerprint: legacy.interpretationFingerprint,
            expectedRevision: legacy.currentRevision,
            idempotencyKey: 'legacy-import',
          ),
          throwsA(_remote('legacy_migration_required')),
        );
        expect(
          (await service.loadTacticalEvidenceState(legacyProfile.id)).revision,
          0,
        );

        // 재시작 뒤 같은 상태, 원본이 없어도 원 요청은 원 응답이다.
        await source.delete();
        await service.restartBackend();
        final restored = await service.loadTacticalEvidenceState(pid);
        expect(restored.revision, 1);
        expect(restored.matches.map((item) => item.id), [dated.id, instant.id]);
        expect((await commit()).toWire(), committed.toWire());
        expect(
          (await service.loadTacticalEvidenceState(pid)).matches,
          hasLength(2),
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
        for (final directory in [created, sourceDirectory]) {
          if (directory.existsSync()) {
            await directory.delete(recursive: true);
          }
          expect(directory.existsSync(), isFalse);
        }
        if (completed) {
          expect(startedProcesses, hasLength(2));
          expect(exitCodes, everyElement(0));
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
