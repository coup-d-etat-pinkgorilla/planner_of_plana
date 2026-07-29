import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _slot(int position, String? studentId) => {
  'version': 2,
  'position': position,
  'student_id': studentId,
  'state': studentId == null ? 'unknown' : 'visible_lobby',
  'source': studentId == null ? 'hidden_lobby' : 'visible_lobby',
  'confidence': studentId == null ? null : 0.99,
  'review_status': studentId == null ? 'review_required' : 'confirmed',
  'wildcard': false,
};

Map<String, dynamic> _lobbyRow(
  int index,
  String name,
  String striker,
  String special,
) => {
  'index': index,
  'rank': {
    'value': index + 5,
    'proposed_value': index + 5,
    'confidence': 0.99,
    'margin': 0.1,
    'review_status': 'confirmed',
  },
  'opponent': {
    'display_name': name,
    'proposed_display_name': name,
    'confidence': 0.99,
    'margin': 0.1,
    'review_status': 'confirmed',
  },
  'public_defense': {
    'version': 2,
    'strikers': [
      _slot(0, striker),
      _slot(1, null),
      _slot(2, null),
      _slot(3, null),
    ],
    'specials': [_slot(0, special), _slot(1, null)],
  },
  'confidence': 0.99,
  'review_status': 'confirmed',
};

Map<String, dynamic> _lobbyPayload() => {
  'version': 1,
  'roi_profile_id': 'tactical-lobby-2560x1440-v1',
  'observed_at': '2026-03-23T00:10:00+09:00',
  'screen_hash': 'a' * 64,
  'refresh_generation': 'refresh-111111111111111111111111',
  'frame_complete': true,
  'current_rank': {
    'value': 8,
    'proposed_value': 8,
    'confidence': 0.99,
    'margin': 0.1,
    'review_status': 'confirmed',
  },
  'rows': [
    _lobbyRow(0, 'Fixture Rival Renamed', 'shiroko', 'serina'),
    _lobbyRow(1, 'Unbattled A', 'eimi', 'hibiki'),
    _lobbyRow(2, 'Unbattled B', 'tsubaki', 'michiru_dress'),
  ],
  'overall_confidence': 0.99,
  'review_status': 'confirmed',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real Dart to Python process previews and commits v6 tactical data',
    () async {
      final storage = await Directory.systemTemp.createTemp(
        'ba_planner_v7_tactical_v2_e2e_',
      );
      final backend = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}backend',
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: backend.path,
        environment: {'BA_PLANNER_STORAGE_ROOT': storage.path},
      );
      final source = File('${storage.path}${Platform.pathSeparator}legacy.db');
      final fixture = File(
        '${Directory.current.parent.path}${Platform.pathSeparator}contracts'
        '${Platform.pathSeparator}fixtures${Platform.pathSeparator}'
        'tactical_v6_import_v2.json',
      );
      const createDatabase = r'''
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
      final created = await Process.run('py', [
        '-3.11',
        '-c',
        createDatabase,
        fixture.path,
        source.path,
      ]);
      expect(created.exitCode, 0, reason: created.stderr.toString());
      final service = ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 10),
        ),
      );
      try {
        await service.reconnect();
        final profile = await service.createProfile(
          'Tactical v2 E2E',
          'tactical-v2-e2e-profile',
        );
        final state = await service.loadTacticalEvidenceState(profile.id);
        expect(state.profileId, profile.id);
        expect(state.revision, 0);
        expect(state.matches, isEmpty);
        expect(state.importBatches, isEmpty);
        final preview = await service.previewTacticalV6Import(
          profile.id,
          source.path,
          'dart-e2e-batch',
        );
        expect(preview.matchCount, 3);
        expect(preview.jokboCount, 1);
        expect(preview.issues.single.code, 'duplicate_student');
        final committed = await service.commitTacticalV6Import(
          profileId: profile.id,
          sourcePath: source.path,
          importBatchId: preview.batchId,
          expectedFingerprint: preview.sourceFingerprint,
          acceptedIssueIds: preview.issues.map((item) => item.id).toList(),
          expectedRevision: state.revision,
          idempotencyKey: 'dart-e2e-commit',
        );
        expect(committed.revision, 1);
        expect(committed.importedMatches, 2);
        expect(committed.importedJokbo, 1);
        final restored = await service.loadTacticalEvidenceState(profile.id);
        expect(restored.matches, hasLength(2));
        expect(restored.jokbo, hasLength(1));
        expect(restored.snapshots, hasLength(1));
        expect(restored.importBatches.single.id, preview.batchId);
        final rival = restored.opponents.firstWhere(
          (item) => item.currentDisplayName == 'Fixture Rival',
        );
        final lobby = await service.commitTacticalLobby(
          profileId: profile.id,
          candidatePayload: _lobbyPayload(),
          season: '10',
          map: 'urban',
          identityBindings: {0: rival.id},
          expectedRevision: restored.revision,
          idempotencyKey: 'dart-e2e-lobby',
        );
        expect(lobby.created, isTrue);
        expect(lobby.candidateIds, hasLength(3));
        final selectedRevision = await service.selectTacticalLobbyCandidate(
          profileId: profile.id,
          candidateId: lobby.candidateIds.first,
          selectedAt: '2026-03-23T00:20:00+09:00',
          expectedRevision: lobby.revision,
          idempotencyKey: 'dart-e2e-select',
        );
        final attack = restored.matches.firstWhere(
          (item) => item.kind == 'attack',
        );
        final linked = await service.linkTacticalMatch(
          profileId: profile.id,
          matchId: attack.id,
          candidateId: null,
          mode: 'auto',
          expectedRevision: selectedRevision,
          idempotencyKey: 'dart-e2e-link',
        );
        expect(linked.status, 'automatic');
        expect(linked.candidateId, lobby.candidateIds.first);
        final history = await service.loadTacticalEvidenceState(profile.id);
        expect(history.lobbyScans, hasLength(1));
        expect(history.lobbyCandidates, hasLength(3));
        expect(
          history.snapshots.where((item) => item.matchId == null),
          hasLength(3),
        );
        expect(
          history.opponents.firstWhere((item) => item.id == rival.id).aliases,
          contains('Fixture Rival Renamed'),
        );
        final statistics = await service.queryTacticalStatistics(
          profile.id,
          TacticalStatsFilters(
            season: '10',
            opponentIdentityId: rival.id,
            publicSignature: 'shiroko|serina|?',
          ),
        );
        expect(statistics.population.exposureCount, 1);
        expect(statistics.population.matchCount, 1);
        expect(statistics.publicSignatures.single.linkedMatchCount, 1);
        expect(statistics.publicSignatures.single.observedWinRate, 1.0);
        expect(statistics.populationWarning, contains('not the population'));
        final trends = await service.queryTacticalTrends(
          profile.id,
          TacticalTrendFilters(
            season: '10',
            opponentIdentityId: rival.id,
            publicSignature: 'shiroko|serina|?',
            asOf: '2026-03-24T00:00:00+09:00',
            staleAfterHours: 12,
          ),
        );
        expect(trends.funnel.refreshCount, 1);
        expect(trends.funnel.exposureCount, 1);
        expect(trends.funnel.selectionCount, 1);
        expect(trends.funnel.battleCount, 1);
        expect(trends.funnel.observedWinRate, 1.0);
        expect(trends.freshness.single.stale, isTrue);
        expect(trends.populationWarning, contains('not server-wide'));
        final recommendation = await service.queryTacticalRecommendations(
          profile.id,
          TacticalRecommendationFilters(
            season: '10',
            opponentIdentityId: rival.id,
            publicSignature: 'shiroko|serina|?',
            rankDifference: -3,
            asOf: '2026-03-24T00:00:00+09:00',
            halfLifeHours: 24,
            minTargetSamples: 1,
            ownedStudentIds: const ['ayane', 'hoshino'],
          ),
        );
        expect(recommendation.available, isTrue);
        expect(recommendation.selectedStage, 1);
        expect(recommendation.scenarios, hasLength(1));
        expect(recommendation.confidenceGrade, 'low');
        expect(recommendation.calibrationGatePassed, isFalse);
        expect(recommendation.recommendations, hasLength(1));
        expect(
          recommendation.recommendations.single.allKnownStudentsOwned,
          isTrue,
        );
        expect(recommendation.warning, contains('not generated'));
        final savedPrediction = await service.saveTacticalRecommendation(
          profileId: profile.id,
          filters: TacticalRecommendationFilters(
            season: '10',
            opponentIdentityId: rival.id,
            publicSignature: 'shiroko|serina|?',
            rankDifference: -3,
            asOf: '2026-03-24T00:00:00+09:00',
            minTargetSamples: 1,
            ownedStudentIds: const ['ayane', 'hoshino'],
          ),
          expectedRevision: history.revision,
          idempotencyKey: 'dart-e2e-prediction-save',
        );
        final savedAgain = await service.saveTacticalRecommendation(
          profileId: profile.id,
          filters: TacticalRecommendationFilters(
            season: '10',
            opponentIdentityId: rival.id,
            publicSignature: 'shiroko|serina|?',
            rankDifference: -3,
            asOf: '2026-03-24T00:00:00+09:00',
            minTargetSamples: 1,
            ownedStudentIds: const ['ayane', 'hoshino'],
          ),
          expectedRevision: history.revision,
          idempotencyKey: 'dart-e2e-prediction-save',
        );
        expect(savedAgain.prediction.id, savedPrediction.prediction.id);
        final restoredPrediction = await service.getTacticalRecommendation(
          profile.id,
          savedPrediction.prediction.id,
        );
        expect(restoredPrediction.result.available, isTrue);
        final stateWithPrediction = await service.loadTacticalEvidenceState(
          profile.id,
        );
        expect(stateWithPrediction.predictions, hasLength(1));
        expect(
          stateWithPrediction.snapshots,
          hasLength(history.snapshots.length),
        );
      } finally {
        await service.dispose();
        if (storage.existsSync()) await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
