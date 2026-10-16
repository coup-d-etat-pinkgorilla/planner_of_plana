// fb6b-dart: FB-6b(FD-176) Dart 데이터 계층 검사 — 시도 횟수 null(모름) 저장, 방어 기록 한정 상대 null 쌍.
//
// 계약 fixture(`contracts/fixtures/tactical_fb6b_nulls_v2.json` 13 cases, `tactical_fb6_writes_v2.json`의
// `unknown_manual_attempt`)·strict request/read DTO·Mock 쓰기/읽기 의미·컨트롤러·기존 화면 집계의 null 안전.
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:ba_planner_v7/tactical/tactical_records_controller.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_analysis_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_jokbo_view.dart';
import 'package:ba_planner_v7/ui/tactical/tactical_records_view.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = '0123456789abcdef01234567';
const _mockProfile = '000000000000000000000001';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _copy(Object? value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

bool _upsertRequest(Object? match) => isValidTacticalV2ProtocolMessage({
  'protocol': 1,
  'id': 'request-1',
  'type': 'request',
  'method': 'tactical.v2.match.upsert',
  'payload': {
    'profile_id': _profile,
    'expected_revision': 0,
    'idempotency_key': 'synthetic-key',
    'match': match,
  },
});

TacticalSlotObservation _slot(int position, String? id, {bool lobby = false}) =>
    TacticalSlotObservation(
      position: position,
      studentId: id,
      state: id == null
          ? 'unknown'
          : lobby
          ? 'visible_lobby'
          : 'manual',
      source: lobby ? 'lobby_scan' : 'manual',
      confidence: null,
      reviewStatus: 'confirmed',
      wildcard: false,
    );

/// [lobby]면 공개 칸(1번 · SP1 · SP2)을 로비 공개 관측으로 둔다(분석 화면 공개 시그니처).
TacticalDeckV2 _deck(
  List<String?> strikers,
  List<String?> specials, {
  bool lobby = false,
}) => TacticalDeckV2(
  strikers: [
    for (final (i, id) in strikers.indexed)
      _slot(i, id, lobby: lobby && i == 0),
  ],
  specials: [
    for (final (i, id) in specials.indexed) _slot(i, id, lobby: lobby),
  ],
);

final _mine = _deck(['hina', 'iori', 'aru', 'haruka'], ['hibiki', 'chise']);
final _theirs = _deck(
  ['hoshino', 'izuna', 'mika', 'kayoko'],
  ['ayane', 'serina'],
  lobby: true,
);

TacticalMatchInputV2 _input(
  String id, {
  String kind = 'attack',
  String? opponentId = 'rival-1',
  String? opponentName = 'Rival',
  int? attempt = 2,
  String result = 'win',
  String occurredAt = '2026-10-14T03:00:00Z',
  TacticalDeckV2? attack,
  TacticalDeckV2? defense,
}) => TacticalMatchInputV2(
  id: id,
  kind: kind,
  occurredAt: occurredAt,
  occurredPrecision: 'instant',
  season: '10',
  opponentIdentityId: opponentId,
  opponentDisplayName: opponentName,
  result: result,
  attackDeck: attack ?? (kind == 'attack' ? _mine : _theirs),
  defenseDeck: defense ?? (kind == 'attack' ? _theirs : _mine),
  notes: '',
  attemptCount: attempt,
);

/// 상대 모르는 방어 기록(FD-176 null 쌍).
TacticalMatchInputV2 _anonymousDefense(
  String id, {
  int? attempt,
  String result = 'loss',
  String occurredAt = '2026-10-14T02:00:00Z',
}) => _input(
  id,
  kind: 'defense',
  opponentId: null,
  opponentName: null,
  attempt: attempt,
  result: result,
  occurredAt: occurredAt,
);

/// v2 read DTO 20키 + 선택 2키.
Map<String, dynamic> _record(Map<String, dynamic> extra) => {
  ..._input('m1').toWire(),
  'observed_at': null,
  'imported_at': '2026-10-14T03:00:00+00:00',
  'created_at': '2026-10-14T03:00:00+00:00',
  'source': 'manual',
  'source_label': 'manual_record',
  'import_batch_id': 'manual',
  'source_record_id': 'manual:m1',
  'confidence': null,
  'review_status': 'confirmed',
  ...extra,
};

Future<int> _upsert(
  MockAppService service,
  TacticalMatchInputV2 match,
  int revision,
  String key,
) async => (await service.upsertTacticalMatchV2(
  profileId: _mockProfile,
  match: match,
  expectedRevision: revision,
  idempotencyKey: key,
)).revision;

TacticalRecordsController _controller(MockAppService service) {
  final controller = TacticalRecordsController(
    service,
    now: () => DateTime.utc(2026, 10, 14, 6),
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('contract', () {
    test('FD-176 fixture: 13 cases match Dart request validation', () {
      final fixture = _json(
        '../contracts/fixtures/tactical_fb6b_nulls_v2.json',
      );
      expect(fixture['decision'], 'FD-176');
      final cases = (fixture['cases'] as List).cast<Map>();
      expect(cases, hasLength(13));
      expect(
        cases
            .where((item) => item['valid'] == true)
            .map((item) => item['name']),
        [
          'known-attack-positive',
          'known-attack-unknown-attempt',
          'anonymous-defense',
        ],
      );
      for (final entry in cases) {
        final name = entry['name'] as String;
        final input = Map<String, dynamic>.from(entry['input'] as Map);
        expect(_upsertRequest(input), entry['valid'], reason: name);
        if (entry['valid'] == true) {
          final typed = TacticalMatchInputV2.fromWire(input);
          // null을 0·1·가짜 상대로 바꾸지 않고 그대로 되보낸다.
          expect(typed.toWire(), input, reason: name);
        } else {
          expect(
            () => TacticalMatchInputV2.fromWire(input),
            throwsFormatException,
            reason: name,
          );
        }
      }
    });

    test('FB-6 writes fixture: unknown_manual_attempt is now valid', () {
      final fixture = _json(
        '../contracts/fixtures/tactical_fb6_writes_v2.json',
      );
      final entry = (fixture['cases'] as List).cast<Map>().firstWhere(
        (item) => item['name'] == 'unknown_manual_attempt',
      );
      expect(entry['valid'], isTrue);
      expect(isValidTacticalV2ProtocolMessage(entry['message']), isTrue);
      final match = Map<String, dynamic>.from(
        ((entry['message'] as Map)['payload'] as Map)['match'] as Map,
      );
      expect(match['attempt_count'], isNull);
      expect(TacticalMatchInputV2.fromWire(match).attemptCount, isNull);
    });

    test('input DTO: required nullable attempt and defense-only null pair', () {
      final anonymous = _anonymousDefense('d1');
      expect(anonymous.toWire()['attempt_count'], isNull);
      expect(anonymous.toWire().containsKey('attempt_count'), isTrue);
      expect(anonymous.toWire()['opponent_identity_id'], isNull);
      expect(anonymous.toWire()['opponent_display_name'], isNull);
      expect(_upsertRequest(anonymous.toWire()), isTrue);
      expect(_input('a1', attempt: null).attemptCount, isNull);
      for (final (label, build) in <(String, TacticalMatchInputV2 Function())>[
        (
          'attack null pair',
          () => _input('x', opponentId: null, opponentName: null),
        ),
        (
          'defense half name',
          () => _input('x', kind: 'defense', opponentId: null),
        ),
        (
          'defense half id',
          () => _input('x', kind: 'defense', opponentName: null),
        ),
        ('blank name', () => _input('x', kind: 'defense', opponentName: '')),
        ('blank id', () => _input('x', kind: 'defense', opponentId: '')),
        ('zero attempt', () => _input('x', attempt: 0)),
        ('negative attempt', () => _input('x', attempt: -1)),
      ]) {
        expect(build, throwsFormatException, reason: label);
      }
      // 키 누락·bool·실수·문자열 시도는 요청 검사가 거부한다.
      final wire = anonymous.toWire();
      for (final (label, change) in <(String, void Function(Map))>[
        ('missing', (match) => match.remove('attempt_count')),
        ('bool', (match) => match['attempt_count'] = true),
        ('float', (match) => match['attempt_count'] = 1.5),
        ('text', (match) => match['attempt_count'] = '1'),
      ]) {
        final bad = _copy(wire);
        change(bad);
        expect(_upsertRequest(bad), isFalse, reason: label);
      }
    });

    test('read DTO: nullable attempt and defense-only null opponent pair', () {
      final anonymous = TacticalMatchV2.fromWire(
        _record({
          'kind': 'defense',
          'opponent_identity_id': null,
          'opponent_display_name': null,
          'attempt_count': null,
          'occurred_precision': 'instant',
        }),
      );
      expect(anonymous.opponentIdentityId, isNull);
      expect(anonymous.opponentDisplayName, isNull);
      expect(anonymous.attemptCount, isNull);
      final known = TacticalMatchV2.fromWire(_record({'attempt_count': null}));
      expect((known.opponentIdentityId, known.attemptCount), ('rival-1', null));
      for (final bad in <Map<String, dynamic>>[
        {'opponent_identity_id': null, 'opponent_display_name': null},
        {
          'kind': 'defense',
          'opponent_identity_id': null,
          'opponent_display_name': 'Rival',
        },
        {'kind': 'defense', 'opponent_display_name': null},
        {'kind': 'defense', 'opponent_display_name': ''},
        {'kind': 'defense', 'opponent_identity_id': ''},
        {'attempt_count': 0},
        {'attempt_count': -2},
        {'attempt_count': true},
      ]) {
        expect(
          () => TacticalMatchV2.fromWire(_record(bad)),
          throwsFormatException,
          reason: '$bad',
        );
      }
      // 성공 응답의 기록도 같은 규칙(익명 방어는 자동 족보 없음).
      final response = {
        'revision': 1,
        'match': _record({
          'kind': 'defense',
          'opponent_identity_id': null,
          'opponent_display_name': null,
          'attempt_count': null,
          'occurred_precision': 'instant',
        }),
        'jokbo_ids': <String>[],
      };
      expect(
        isValidTacticalV2ProtocolMessage({
          'protocol': 1,
          'id': 'response-1',
          'type': 'response',
          'method': 'tactical.v2.match.upsert',
          'payload': response,
        }),
        isTrue,
      );
      expect(
        TacticalMatchUpsertResult.fromWire(response).match.opponentIdentityId,
        isNull,
      );
    });
  });

  group('Mock v2', () {
    test(
      'anonymous defense and unknown attempt are stored as null without a fake opponent',
      () async {
        final service = MockAppService();
        var revision = await _upsert(
          service,
          _input('a1', attempt: null),
          0,
          'k1',
        );
        expect(revision, 1);
        final first = await service.upsertTacticalMatchV2(
          profileId: _mockProfile,
          match: _anonymousDefense('d1'),
          expectedRevision: revision,
          idempotencyKey: 'k2',
        );
        expect(first.revision, 2);
        expect(first.jokboIds, isEmpty);
        expect(first.match.opponentIdentityId, isNull);
        expect(first.match.opponentDisplayName, isNull);
        expect(first.match.attemptCount, isNull);
        // 같은 key 재요청 = 원 응답(revision 검사 전).
        final replay = await service.upsertTacticalMatchV2(
          profileId: _mockProfile,
          match: _anonymousDefense('d1'),
          expectedRevision: 0,
          idempotencyKey: 'k2',
        );
        expect(replay.revision, 2);
        expect(replay.match.opponentIdentityId, isNull);
        final state = await service.loadTacticalEvidenceState(_mockProfile);
        expect(state.revision, 2);
        expect(state.matches, hasLength(2));
        expect(state.opponents.map((item) => item.id), ['rival-1']);
        expect(state.opponents.single.aliases, ['Rival']);
        final attack = state.matches.firstWhere((item) => item.id == 'a1');
        expect(attack.attemptCount, isNull);
        // 상대 모르는 방어 기록은 스냅샷 · 족보를 만들지 않는다.
        expect(state.jokbo, hasLength(1));
        expect(state.snapshots.where((item) => item.matchId == 'd1'), isEmpty);
        // 다시 고쳐 시도를 알게 되면 정수로, 다시 null로도 저장된다.
        revision = await _upsert(
          service,
          _anonymousDefense('d1', attempt: 3),
          2,
          'k3',
        );
        revision = await _upsert(
          service,
          _anonymousDefense('d1'),
          revision,
          'k4',
        );
        final after = await service.loadTacticalEvidenceState(_mockProfile);
        expect(after.revision, 4);
        expect(
          after.matches.firstWhere((item) => item.id == 'd1').attemptCount,
          isNull,
        );
        expect(after.opponents, hasLength(1));
      },
    );

    test('migrated null attempt can be edited and saved as null', () async {
      final service = MockAppService();
      await service.saveTacticalMatch(
        _mockProfile,
        TacticalMatch(
          id: 'v1-one',
          kind: 'attack',
          occurredOn: '2026-10-13',
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
        ),
        0,
        'v1',
      );
      final preview = await service.previewTacticalLegacyMigration(
        _mockProfile,
      );
      await service.commitTacticalLegacyMigration(
        profileId: _mockProfile,
        expectedSourceRevision: preview.sourceRevision,
        expectedFingerprint: preview.sourceFingerprint,
        expectedRevision: 0,
        idempotencyKey: 'migrate',
      );
      final migrated = (await service.loadTacticalEvidenceState(
        _mockProfile,
      )).matches.single;
      expect(migrated.attemptCount, isNull);
      final edit = TacticalMatchInputV2.fromRecord(migrated);
      expect(edit.attemptCount, isNull);
      final saved = await service.upsertTacticalMatchV2(
        profileId: _mockProfile,
        match: edit,
        expectedRevision: 1,
        idempotencyKey: 'edit',
      );
      expect(saved.match.attemptCount, isNull);
      expect(saved.match.sourceLabel, 'manual_edit');
      expect(saved.match.opponentIdentityId, migrated.opponentIdentityId);
    });

    test(
      'statistics keep anonymous rows in totals but not in opponent rows',
      () async {
        final service = MockAppService();
        var revision = 0;
        for (final (key, match) in [
          ('s1', _input('a1', attempt: 1)),
          ('s2', _input('a2', attempt: null, result: 'loss')),
          ('s3', _input('k1', kind: 'defense', attempt: null)),
          // 같은 내용의 익명 방어 2건: 같은 상대로 묶지 않으므로 중복 의심이 아니다.
          ('s4', _anonymousDefense('d1')),
          ('s5', _anonymousDefense('d2')),
        ]) {
          revision = await _upsert(service, match, revision, key);
        }
        final stats = await service.queryTacticalStatistics(
          _mockProfile,
          const TacticalStatsFilters(),
        );
        expect(stats.population.matchCount, 5);
        expect(stats.population.attackMatchCount, 2);
        expect(stats.population.defenseMatchCount, 3);
        expect(stats.population.opponentCount, 1);
        expect(stats.opponentTotal, 1);
        final rival = stats.opponents.single;
        expect(rival.opponentIdentityId, 'rival-1');
        expect(rival.matchCount, 3);
        expect(rival.defenseResults.count, 1);
        expect(stats.quality['distinct_opponent_count'], 1);
        expect(stats.quality['match_kind_counts'], {'attack': 2, 'defense': 3});
        expect(stats.quality['suspected_duplicate_count'], 0);
        // 상대 필터는 익명 행을 고르지 않는다.
        final filtered = await service.queryTacticalStatistics(
          _mockProfile,
          const TacticalStatsFilters(opponentIdentityId: 'rival-1'),
        );
        expect(filtered.population.matchCount, 3);
      },
    );
  });

  group('controller and screen aggregates', () {
    test('controller saves null attempt and anonymous defense as-is', () async {
      final service = MockAppService();
      final controller = _controller(service);
      await controller.load(_mockProfile);
      expect(await controller.saveMatch(_input('a1', attempt: null)), isTrue);
      expect(await controller.saveMatch(_anonymousDefense('d1')), isTrue);
      expect(controller.error, isNull);
      expect(controller.revision, 2);
      final anonymous = controller.matches.firstWhere(
        (item) => item.id == 'd1',
      );
      expect(anonymous.opponentIdentityId, isNull);
      expect(anonymous.attemptCount, isNull);
      expect(
        controller.matches.firstWhere((item) => item.id == 'a1').attemptCount,
        isNull,
      );
      // 족보 집계는 공격 기록만 센다(익명 방어는 영향 없음).
      expect(controller.jokbo, hasLength(1));
      expect(
        (
          controller.jokbo.single.recordCount,
          controller.jokbo.single.recordWins,
        ),
        (1, 1),
      );
      // 화면 목록 행: FD-132 "내 방어덱", 시도 모름은 '—'.
      final row = tacticalRecordRows(
        controller.matches,
      ).firstWhere((item) => item.key == 'v2:d1');
      expect(row.opponentLabel, '내 방어덱');
      expect(row.opponentName, '');
      expect(row.draft.opponentIdentityId, isNull);
      expect(row.metaText, startsWith('— · '));
      expect(
        tacticalAttemptNote(row.result, row.draft.attemptCount),
        '시도 횟수 모름',
      );
    });

    test(
      'analysis aggregates exclude unknown opponents from groups and counts',
      () async {
        final service = MockAppService();
        var revision = 0;
        for (final (key, match) in [
          ('a', _input('a1', attempt: 1)),
          ('b', _input('a2', attempt: null, result: 'loss')),
          // 같은 편성(내 덱 = 공격, 상대 덱 = 방어)의 익명 기록이 섞여 들어와도 상대 묶음에 끼지 않는다.
          (
            'c',
            _input(
              'd1',
              kind: 'defense',
              opponentId: null,
              opponentName: null,
              attempt: null,
              attack: _mine,
              defense: _theirs,
            ),
          ),
        ]) {
          revision = await _upsert(service, match, revision, key);
        }
        final controller = _controller(service);
        await controller.load(_mockProfile);
        final matches = controller.matches;
        expect(matches, hasLength(3));
        // 분석 대상은 공격 기록만이다.
        expect(
          tacticalAnalysisMatches(
            matches,
            DateTime.utc(2026, 10, 14, 6),
          ).map((item) => item.id).toSet(),
          {'a1', 'a2'},
        );
        final summaries = tacticalSignatureSummaries(
          matches: matches,
          jokbo: controller.jokbo,
        );
        final summary = summaries.single;
        expect(summary.sampleCount, 3);
        expect(summary.defenders, 1);
        final card = TacticalJokboCard(
          entry: controller.jokbo.single,
          wins: 1,
          losses: 1,
          lastObserved: '—',
          fromStatistics: false,
        );
        final analysis = tacticalJokboAnalysis(card: card, matches: matches);
        expect(analysis.records, hasLength(3));
        expect(analysis.defenseUsers, 1);
        expect(analysis.knownAttempts, 1);
        expect(analysis.firstTryWins, 1);
        expect(analysis.opponents.map((item) => (item.identityId, item.name)), [
          ('rival-1', 'Rival'),
        ]);
        expect(
          (analysis.opponents.single.wins, analysis.opponents.single.losses),
          (1, 1),
        );
        final opponent = tacticalOpponentAnalysis(
          identityId: 'rival-1',
          allMatches: matches,
          signatureMatches: matches,
          cards: [card],
        );
        expect(opponent?.name, 'Rival');
        expect(opponent?.records.map((item) => item.id).toSet(), {'a1', 'a2'});
      },
    );
  });
}
