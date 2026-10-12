// fb2d-dart process E2E: 실제 Python 백엔드(임시 저장소)에서 FB-2d 7경로 삭제를 확인한다.
// 지울 계정에 프로필·전술 v1·전술 v2(v6 가져오기 fixture)·시나리오·프리셋·로컬 전술 공유 파일을 만들고, 남길
// 계정에도 같은 종류를 만든다. 삭제 뒤 7번째 파일(`tactical-share/{id}.v1.json`)까지 없어지고 남길 계정은
// 그대로인지, 재시작 뒤 같은 key·원 revision 재요청이 원 revision을 주는지, 같은 key·다른 revision은
// idempotency_conflict, 다른 key는 profile_not_found, 옛 create key로는 다시 만들 수 없는지 본다.
// 실제 게임·사용자 프로필은 쓰지 않는다.
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _createV6Database = r'''
import json, sqlite3, sys
fixture=json.load(open(sys.argv[1], encoding='utf-8'))
connection=sqlite3.connect(sys.argv[2])
connection.executescript("""
CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE matches(id TEXT PRIMARY KEY, date TEXT NOT NULL, season TEXT NOT NULL, opponent TEXT NOT NULL, result TEXT NOT NULL, my_attack TEXT NOT NULL, opponent_defense TEXT NOT NULL, my_defense TEXT NOT NULL, opponent_attack TEXT NOT NULL, source TEXT NOT NULL, notes TEXT NOT NULL, created_at TEXT NOT NULL);
CREATE TABLE jokbo(id TEXT PRIMARY KEY, defense TEXT NOT NULL, attack TEXT NOT NULL, wins INTEGER NOT NULL, losses INTEGER NOT NULL, notes TEXT NOT NULL, updated_at TEXT NOT NULL);
""")
connection.executemany('INSERT INTO settings(key,value) VALUES(?,?)', fixture['settings'].items())
connection.executemany('INSERT INTO matches VALUES(:id,:date,:season,:opponent,:result,:my_attack,:opponent_defense,:my_defense,:opponent_attack,:source,:notes,:created_at)', fixture['matches'])
connection.executemany('INSERT INTO jokbo VALUES(:id,:defense,:attack,:wins,:losses,:notes,:updated_at)', fixture['jokbo'])
connection.commit()
connection.close()
''';

Map<String, int> _targets(int level) => {
  'level': level,
  'bond_rank': 1,
  'student_star': 1,
  'weapon_level': 0,
  'weapon_star': 0,
  'ex_skill': 1,
  'skill1': 1,
  'skill2': 0,
  'skill3': 0,
  'equip1_tier': 0,
  'equip2_tier': 0,
  'equip3_tier': 0,
  'equip1_level': 0,
  'equip2_level': 0,
  'equip3_level': 0,
  'equip4_tier': 0,
  'stat_hp': 0,
  'stat_atk': 0,
  'stat_heal': 0,
};

PlanningDocument _scenarioDocument(String id) => PlanningDocument(
  id: id,
  name: id,
  kind: PlanningDocumentKind.scenario,
  phases: [
    PlanningDocumentPhase(
      id: '$id-phase',
      name: '페이즈 1',
      stages: [
        PlanningDocumentStage(
          id: '$id-stage',
          studentId: 'ayane',
          name: '목표',
          targets: _targets(8),
        ),
      ],
    ),
  ],
);

Matcher _remote(String code) => throwsA(
  isA<BackendRemoteException>().having((error) => error.code, 'code', code),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real backend deletes all seven paths, keeps the other profile and replays the original revision after restart',
    () async {
      final storage = await Directory.systemTemp.createTemp(
        'ba_planner_v7_fb2d_e2e_',
      );
      final contracts =
          '${Directory.current.parent.path}${Platform.pathSeparator}contracts'
          '${Platform.pathSeparator}fixtures${Platform.pathSeparator}';
      final config = BackendProcessConfig.resolve(
        backendDirectory:
            '${Directory.current.parent.path}${Platform.pathSeparator}backend',
        environment: {'BA_PLANNER_STORAGE_ROOT': storage.path},
      );
      ProcessAppService start() => ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 30),
          waitForStartupProbe: true,
          startupProbeTimeout: const Duration(seconds: 30),
        ),
      );
      final source = File('${storage.path}${Platform.pathSeparator}legacy.db');
      final created = await Process.run('py', [
        '-3.11',
        '-c',
        _createV6Database,
        '${contracts}tactical_v6_import_v2.json',
        source.path,
      ]);
      expect(created.exitCode, 0, reason: created.stderr.toString());
      final shareFixture =
          jsonDecode(
                File('${contracts}tactical_share_v1.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final importCase = (shareFixture['cases'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere(
            (item) =>
                (item['message'] as Map)['method'] ==
                'tactical.v2.share.import',
          );
      // fixture의 음성 예는 원문 이름 필드 하나만 더 있다. 그 필드를 빼면 정상 공유 기록이다.
      final shareWire = Map<String, dynamic>.from(
        ((importCase['message'] as Map)['payload'] as Map)['shares'][0] as Map,
      )..remove('opponent_display_name');
      final presetsFixture =
          jsonDecode(
                File(
                  '${contracts}repository_presets_v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final presetsSource = Map<String, dynamic>.from(
        presetsFixture['cases'][0]['message']['payload'] as Map,
      );

      String path(String relative) =>
          '${storage.path}${Platform.pathSeparator}'
          '${relative.replaceAll('/', Platform.pathSeparator)}';
      List<String> targets(String id) => [
        'profiles/$id.json',
        'tactical/$id.json',
        'tactical/$id.v2.json',
        'scenarios/$id.json',
        'presets/$id.json',
        'tactical-share/$id.v1.json',
      ];

      Future<void> fill(
        ProcessAppService service,
        String id,
        String tag,
      ) async {
        final studentsRevision = await service.saveRepositoryStudents(
          id,
          [
            ConfirmedStudentState.fromValues('ayane', {'level': 1}),
            ConfirmedStudentState.fromValues('hoshino', {}),
          ],
          0,
          '$tag-students',
        );
        await service.saveTacticalMatch(
          id,
          TacticalMatch(
            id: '$tag-match',
            kind: 'attack',
            occurredOn: null,
            season: 'S1',
            opponent: 'Rival',
            result: 'win',
            attackDeck: TacticalDeck(
              strikers: const ['hoshino', null, null, null],
              specials: const ['ayane', null],
            ),
            defenseDeck: TacticalDeck(
              strikers: const ['shiroko', null, null, null],
              specials: const ['serika_new_year', null],
            ),
            notes: tag,
          ),
          0,
          '$tag-match',
        );
        final evidence = await service.loadTacticalEvidenceState(id);
        final preview = await service.previewTacticalV6Import(
          id,
          source.path,
          '$tag-batch',
        );
        await service.commitTacticalV6Import(
          profileId: id,
          sourcePath: source.path,
          importBatchId: preview.batchId,
          expectedFingerprint: preview.sourceFingerprint,
          acceptedIssueIds: preview.issues.map((item) => item.id).toList(),
          expectedRevision: evidence.revision,
          idempotencyKey: '$tag-v6-import',
        );
        await service.createScenario(
          profileId: id,
          expectedRevision: 0,
          idempotencyKey: '$tag-scenario',
          name: '후보 $tag',
          description: '',
          baseProfileRevision: studentsRevision,
          document: _scenarioDocument('$tag-scenario'),
        );
        expect(
          await service.saveRepositoryPresets(
            RepositoryPresetsSaveRequest.fromWire({
              ...presetsSource,
              'profile_id': id,
              'expected_revision': 0,
              'idempotency_key': '$tag-presets',
            }),
          ),
          1,
        );
        final shared = await service.importTacticalShares(
          profileId: id,
          shares: [TacticalSharePayload.fromWire(shareWire)],
          expectedRevision: 0,
          idempotencyKey: '$tag-share',
        );
        expect(shared.imported, 1);
      }

      var service = start();
      try {
        await service.reconnect();
        final kept = await service.createProfile('FB2d Kept', 'fb2d-e2e-kept');
        final gone = await service.createProfile('FB2d Gone', 'fb2d-e2e-gone');
        await fill(service, kept.id, 'kept');
        await fill(service, gone.id, 'gone');
        for (final relative in [...targets(kept.id), ...targets(gone.id)]) {
          expect(File(path(relative)).existsSync(), isTrue, reason: relative);
        }
        final keptState = await service.loadRepositoryState(kept.id);
        final keptShare = await service.loadTacticalShareState(kept.id);
        final keptScenarios = await service.listScenarios(kept.id);
        final goneRevision = (await service.loadRepositoryState(
          gone.id,
        )).revision;
        expect(
          (await service.listProfiles())
              .singleWhere((item) => item.id == kept.id)
              .selected,
          isTrue,
        );

        final deleted = await service.deleteProfile(
          gone.id,
          goneRevision,
          'fb2d-e2e-delete',
        );
        expect(deleted, goneRevision + 1);
        for (final relative in targets(gone.id)) {
          expect(File(path(relative)).existsSync(), isFalse, reason: relative);
        }
        final catalog =
            jsonDecode(File(path('catalog.json')).readAsStringSync()) as Map;
        expect(
          (catalog['profiles'] as List).map(
            (item) => (item as Map)['profile_id'],
          ),
          [kept.id],
        );
        expect(catalog['selected_profile_id'], kept.id);

        // 응답을 잃은 것으로 보고 재시작한 뒤 같은 key·원 revision으로 다시 보낸다.
        service.dispose();
        service = start();
        await service.reconnect();
        expect(
          await service.deleteProfile(gone.id, goneRevision, 'fb2d-e2e-delete'),
          goneRevision + 1,
        );
        await expectLater(
          service.deleteProfile(gone.id, goneRevision + 1, 'fb2d-e2e-delete'),
          _remote('idempotency_conflict'),
        );
        await expectLater(
          service.deleteProfile(gone.id, goneRevision, 'fb2d-e2e-other-key'),
          _remote('profile_not_found'),
        );
        await expectLater(
          service.loadRepositoryState(gone.id),
          _remote('profile_not_found'),
        );
        await expectLater(
          service.createProfile('FB2d Gone', 'fb2d-e2e-gone'),
          _remote('idempotency_conflict'),
        );
        for (final relative in targets(gone.id)) {
          expect(File(path(relative)).existsSync(), isFalse, reason: relative);
        }

        // 남긴 계정은 그대로다.
        for (final relative in targets(kept.id)) {
          expect(File(path(relative)).existsSync(), isTrue, reason: relative);
        }
        final keptAfter = await service.loadRepositoryState(kept.id);
        expect(keptAfter.revision, keptState.revision);
        expect(
          keptAfter.students.map((item) => item.studentId),
          keptState.students.map((item) => item.studentId),
        );
        final keptShareAfter = await service.loadTacticalShareState(kept.id);
        expect(keptShareAfter.revision, keptShare.revision);
        expect(
          keptShareAfter.records.map((item) => item.id),
          keptShare.records.map((item) => item.id),
        );
        expect(
          (await service.listScenarios(
            kept.id,
          )).scenarios.map((item) => item.id),
          keptScenarios.scenarios.map((item) => item.id),
        );

        // 새 create key는 새 ID를 만든다.
        final again = await service.createProfile(
          'FB2d Gone',
          'fb2d-e2e-gone-again',
        );
        expect(again.id, isNot(gone.id));
        expect(
          File(path('tactical-share/${again.id}.v1.json')).existsSync(),
          isFalse,
        );
      } finally {
        service.dispose();
        if (storage.existsSync()) await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
