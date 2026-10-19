// fb6-dart: FB-6(전술 v2 기록·족보 쓰기, 명시적 v7-v1 이관)의 Dart 연결 검사.
//
// 계약 fixture(`contracts/fixtures/tactical_fb6_writes_v2.json`)·strict request/success·read DTO additive optional·
// tactical 오류 allowlist 8(backend 2026-10-14 08:36)·Process 요청 모양·Mock v2 의미.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = '0123456789abcdef01234567';
const _fingerprint =
    '0000000000000000000000000000000000000000000000000000000000000000';
const _allowlist8 = [
  'import_review_required',
  'import_source_changed',
  'legacy_already_migrated',
  'legacy_migration_required',
  'lineage_conflict',
  'migration_conflict',
  'opponent_alias_required',
  'tactical_v1_read_only',
];

Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            '../contracts/fixtures/tactical_fb6_writes_v2.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _case(String name) => Map<String, dynamic>.from(
  ((_fixture()['cases'] as List).cast<Map>().firstWhere(
            (item) => item['name'] == name,
          )['message']
          as Map)['payload']
      as Map,
);

Map<String, dynamic> _copy(Object? value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

bool _request(String method, Map<String, dynamic> payload) =>
    isValidTacticalV2ProtocolMessage({
      'protocol': 1,
      'id': 'request-1',
      'type': 'request',
      'method': method,
      'payload': payload,
    });

bool _response(String method, Map<String, dynamic> payload) =>
    isValidTacticalV2ProtocolMessage({
      'protocol': 1,
      'id': 'response-1',
      'type': 'response',
      'method': method,
      'payload': payload,
    });

TacticalSlotObservation _slot(
  int position,
  String? studentId, {
  bool wildcard = false,
  String? state,
}) => TacticalSlotObservation(
  position: position,
  studentId: studentId,
  state: state ?? (studentId == null ? 'unknown' : 'manual'),
  source: 'manual',
  confidence: null,
  reviewStatus: studentId == null && !wildcard ? 'unreviewed' : 'confirmed',
  wildcard: wildcard,
);

TacticalDeckV2 _deck(
  List<String?> strikers,
  List<String?> specials, {
  bool wildcardLast = false,
}) => TacticalDeckV2(
  strikers: [
    for (final (index, id) in strikers.indexed)
      wildcardLast && index == 3
          ? _slot(index, null, wildcard: true)
          : _slot(index, id),
  ],
  specials: [for (final (index, id) in specials.indexed) _slot(index, id)],
);

final _fullDeck = _deck(
  ['shiroko', 'akane', 'yuuka', 'mika'],
  ['serina', 'hibiki'],
);

TacticalMatchInputV2 _matchInput({
  String id = 'manual-one',
  String opponentName = 'Rival',
  String notes = 'original',
  int attemptCount = 3,
  TacticalDeckV2? defense,
}) => TacticalMatchInputV2(
  id: id,
  kind: 'attack',
  occurredAt: '2026-10-13T21:10:00+09:00',
  occurredPrecision: 'instant',
  season: '34',
  opponentIdentityId: 'opponent-one',
  opponentDisplayName: opponentName,
  result: 'win',
  attackDeck: _fullDeck,
  defenseDeck: defense ?? _fullDeck,
  notes: notes,
  attemptCount: attemptCount,
);

TacticalJokboInputV2 _jokboInput({
  String id = 'manual-jokbo',
  String name = 'Synthetic',
  TacticalDeckV2? attack,
  TacticalDeckV2? defense,
}) => TacticalJokboInputV2(
  id: id,
  name: name,
  attackDeck: attack ?? _fullDeck,
  defenseDeck: defense ?? _fullDeck,
  notes: 'temporary',
);

/// 기존 v2 read DTO 20키 + 선택 키.
Map<String, dynamic> _matchRecord([Map<String, dynamic> extra = const {}]) {
  final input = _copy(_case('match.upsert')['match'])
    ..remove('attempt_count')
    ..remove('occurred_precision');
  return {
    ...input,
    'observed_at': null,
    'imported_at': '2026-10-13T12:10:00+00:00',
    'created_at': '2026-10-13T12:10:00+00:00',
    'source': 'manual',
    'source_label': 'manual_record',
    'import_batch_id': 'manual',
    'source_record_id': 'manual:m1',
    'confidence': null,
    'review_status': 'confirmed',
    ...extra,
  };
}

Map<String, dynamic> _jokboRecord([Map<String, dynamic> extra = const {}]) {
  final input = _copy(_case('jokbo.upsert')['jokbo'])..remove('name');
  return {
    ...input,
    'wins': 0,
    'losses': 0,
    'created_at': '2026-10-13T12:10:00+00:00',
    'imported_at': '2026-10-13T12:10:00+00:00',
    'source': 'manual',
    'source_label': 'manual_record',
    'import_batch_id': 'manual',
    'source_record_id': 'manual:manual-j1',
    'confidence': null,
    'review_status': 'confirmed',
    ...extra,
  };
}

Matcher _remote(String code) =>
    isA<BackendRemoteException>().having((error) => error.code, 'code', code);

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

TacticalJokbo _v1Jokbo(String id) => TacticalJokbo(
  id: id,
  defenseDeck: TacticalDeck(
    strikers: const ['akane', null, null, null],
    specials: const ['hibiki', null],
  ),
  attackDeck: TacticalDeck(
    strikers: const ['shiroko', null, null, null],
    specials: const ['serina', null],
  ),
  notes: 'legacy notes',
);

const _mockProfile = '000000000000000000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contract', () {
    test('shared FB-6 fixture has matching Dart validation results', () {
      final cases = (_fixture()['cases'] as List).cast<Map>();
      expect(cases, hasLength(11));
      for (final entry in cases) {
        expect(
          isValidTacticalV2ProtocolMessage(entry['message']),
          entry['valid'],
          reason: entry['name'] as String,
        );
      }
    });

    test(
      'six requests are exact: backend-owned and renamed keys are rejected',
      () {
        for (final name in [
          'match.upsert',
          'match.delete',
          'jokbo.upsert',
          'jokbo.delete',
          'legacy.preview',
          'legacy.commit',
        ]) {
          final payload = _case(name);
          final method = 'tactical.v2.$name';
          expect(_request(method, payload), isTrue, reason: name);
          expect(
            _request(method, {...payload, 'extra': true}),
            isFalse,
            reason: '$name extra',
          );
          for (final key in payload.keys) {
            expect(
              _request(method, _copy(payload)..remove(key)),
              isFalse,
              reason: '$name without $key',
            );
          }
        }
        final match = _case('match.upsert');
        for (final owned in [
          'created_at',
          'imported_at',
          'observed_at',
          'source',
          'source_label',
          'import_batch_id',
          'source_record_id',
          'confidence',
          'review_status',
        ]) {
          final withOwned = _copy(match);
          (withOwned['match'] as Map)[owned] = null;
          expect(
            _request('tactical.v2.match.upsert', withOwned),
            isFalse,
            reason: 'backend-owned $owned',
          );
        }
        for (final owned in ['wins', 'losses', 'created_at', 'source']) {
          final withOwned = _copy(_case('jokbo.upsert'));
          (withOwned['jokbo'] as Map)[owned] = 0;
          expect(
            _request('tactical.v2.jokbo.upsert', withOwned),
            isFalse,
            reason: 'backend-owned jokbo $owned',
          );
        }
        // 08:27: commit 요청키는 expected_source_revision·expected_fingerprint(응답 이름이 아니다).
        final commit = _case('legacy.commit');
        final renamed = _copy(commit)
          ..remove('expected_source_revision')
          ..remove('expected_fingerprint')
          ..['source_revision'] = 1
          ..['source_fingerprint'] = _fingerprint;
        expect(_request('tactical.v2.legacy.commit', renamed), isFalse);
        expect(
          _request('tactical.v2.legacy.commit', {
            ...commit,
            'expected_fingerprint': 'ABC',
          }),
          isFalse,
        );
        expect(
          _request('tactical.v2.legacy.preview', {
            'profile_id': _profile,
            'expected_revision': 0,
          }),
          isFalse,
        );
        // unknown 정밀도는 시각이 null이어야 하고, 아니면 시각이 있어야 한다.
        final unknownWithTime = _copy(match);
        (unknownWithTime['match'] as Map)['occurred_precision'] = 'unknown';
        expect(_request('tactical.v2.match.upsert', unknownWithTime), isFalse);
        (unknownWithTime['match'] as Map)['occurred_at'] = null;
        expect(_request('tactical.v2.match.upsert', unknownWithTime), isTrue);
        final emptyName = _copy(_case('jokbo.upsert'));
        (emptyName['jokbo'] as Map)['name'] = '';
        expect(_request('tactical.v2.jokbo.upsert', emptyName), isFalse);
      },
    );

    test('read DTOs accept only the additive optional keys', () {
      final legacy = TacticalMatchV2.fromWire(_matchRecord());
      expect(legacy.attemptCount, isNull);
      expect(legacy.occurredPrecision, 'unknown');
      final migrated = TacticalMatchV2.fromWire(
        _matchRecord({'attempt_count': null, 'occurred_precision': 'date'}),
      );
      expect(migrated.attemptCount, isNull);
      expect(migrated.occurredPrecision, 'date');
      final manual = TacticalMatchV2.fromWire(
        _matchRecord({'attempt_count': 3, 'occurred_precision': 'instant'}),
      );
      expect(manual.attemptCount, 3);
      expect(manual.occurredPrecision, 'instant');
      for (final bad in <Map<String, dynamic>>[
        {'attempt_count': 0},
        {'attempt_count': true},
        {'attempt_count': '3'},
        {'occurred_precision': 'guess'},
        {'occurred_precision': null},
        {'legacy_v1': <String, dynamic>{}},
        {'invented': 1},
      ]) {
        expect(
          () => TacticalMatchV2.fromWire(_matchRecord(bad)),
          throwsFormatException,
          reason: '$bad',
        );
      }
      expect(TacticalJokboV2.fromWire(_jokboRecord()).name, isNull);
      expect(TacticalJokboV2.fromWire(_jokboRecord({'name': 'A'})).name, 'A');
      for (final bad in <Map<String, dynamic>>[
        {'name': ''},
        {'name': null},
        {'name': 3},
        {'invented': 1},
      ]) {
        expect(
          () => TacticalJokboV2.fromWire(_jokboRecord(bad)),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('six success payloads are exact', () {
      final match = _matchRecord({
        'attempt_count': 3,
        'occurred_precision': 'instant',
      });
      final jokbo = _jokboRecord({'name': 'Synthetic template'});
      final issue = {
        'record_kind': 'match',
        'record_id': 'm1',
        'code': 'invalid_payload',
        'message': 'slot student must be a canonical catalog identity',
      };
      final valid = <String, Map<String, dynamic>>{
        'tactical.v2.match.upsert': {
          'revision': 2,
          'match': match,
          'jokbo_ids': ['lineage-0123456789abcdef0123456789abcdef'],
        },
        'tactical.v2.match.delete': {'revision': 3, 'match_id': 'm1'},
        'tactical.v2.jokbo.upsert': {'revision': 4, 'jokbo': jokbo},
        'tactical.v2.jokbo.delete': {'revision': 5, 'jokbo_id': 'manual-j1'},
        'tactical.v2.legacy.preview': {
          'source_revision': 1,
          'source_fingerprint': _fingerprint,
          'match_count': 1,
          'jokbo_count': 0,
          'issues': [issue],
          'v1_writes_disabled': false,
        },
        'tactical.v2.legacy.commit': {
          'revision': 1,
          'imported_matches': 1,
          'imported_jokbo': 0,
          'v1_writes_disabled': true,
        },
      };
      for (final MapEntry(key: method, value: payload) in valid.entries) {
        expect(_response(method, payload), isTrue, reason: method);
        expect(
          _response(method, {...payload, 'extra': 1}),
          isFalse,
          reason: '$method extra',
        );
        for (final key in payload.keys) {
          expect(
            _response(method, _copy(payload)..remove(key)),
            isFalse,
            reason: '$method without $key',
          );
        }
        expect(
          _response(method, {...payload, 'revision': -1}),
          isFalse,
          reason: '$method negative revision',
        );
      }
      final upsert = valid['tactical.v2.match.upsert']!;
      expect(
        _response('tactical.v2.match.upsert', {
          ...upsert,
          'jokbo_ids': ['a', 'a'],
        }),
        isFalse,
      );
      expect(
        _response('tactical.v2.match.upsert', {
          ...upsert,
          'match': {...match, 'attempt_count': 0},
        }),
        isFalse,
      );
      final commit = valid['tactical.v2.legacy.commit']!;
      expect(
        _response('tactical.v2.legacy.commit', {
          ...commit,
          'v1_writes_disabled': false,
        }),
        isFalse,
      );
      final preview = valid['tactical.v2.legacy.preview']!;
      for (final badIssue in <Map<String, dynamic>>[
        {...issue, 'record_kind': 'opponent'},
        {...issue, 'record_id': ''},
        {...issue, 'code': ''},
        {...issue, 'extra': 1},
        _copy(issue)..remove('message'),
      ]) {
        expect(
          _response('tactical.v2.legacy.preview', {
            ...preview,
            'issues': [badIssue],
          }),
          isFalse,
          reason: '$badIssue',
        );
      }
      expect(
        _response('tactical.v2.legacy.preview', {
          ...preview,
          'v1_writes_disabled': 'false',
        }),
        isFalse,
      );
      final typed = TacticalLegacyPreview.fromWire(preview);
      expect(typed.sourceRevision, 1);
      expect(typed.issues.single.recordKind, 'match');
      expect(TacticalMatchUpsertResult.fromWire(upsert).match.attemptCount, 3);
    });

    test(
      'input DTOs carry only input keys and never fabricate unknown values',
      () {
        final input = _matchInput();
        expect(
          input.toWire().keys.toSet(),
          (_case('match.upsert')['match'] as Map).keys.toSet(),
        );
        expect(_jokboInput().toWire().keys.toSet(), {
          'version',
          'jokbo_id',
          'name',
          'attack_deck',
          'defense_deck',
          'notes',
        });
        expect(() => _matchInput(attemptCount: 0), throwsFormatException);
        expect(() => _jokboInput(name: ''), throwsFormatException);
        TacticalMatchInputV2 timed(String? at, String precision) =>
            TacticalMatchInputV2(
              id: 'm1',
              kind: 'defense',
              occurredAt: at,
              occurredPrecision: precision,
              season: '',
              opponentIdentityId: 'opponent-one',
              opponentDisplayName: 'Rival',
              result: 'loss',
              attackDeck: _fullDeck,
              defenseDeck: _fullDeck,
              notes: '',
              attemptCount: 1,
            );
        expect(timed(null, 'unknown').toWire()['occurred_at'], isNull);
        expect(
          timed('2026-10-13T00:00:00+09:00', 'date').occurredPrecision,
          'date',
        );
        for (final (at, precision) in [
          ('2026-10-13T00:00:00+09:00', 'unknown'),
          (null, 'date'),
          (null, 'instant'),
          ('2026-10-13T00:00:00Z', 'date'),
          ('2026-10-13T09:00:00+09:00', 'date'),
          ('2026-10-13T21:10:00', 'instant'),
          ('2026-10-13T21:10:00+09:00', 'guess'),
        ]) {
          expect(
            () => timed(at, precision),
            throwsFormatException,
            reason: '$at $precision',
          );
        }
        // 읽은 기록에서 입력을 만들 때 키가 없던 정밀도를 추측하지 않는다. 모르는 시도 횟수는 FD-176(fb6b-dart)부터
        // null 그대로 옮긴다(1로 채우지 않는다).
        final old = TacticalMatchV2.fromWire(_matchRecord());
        expect(
          () => TacticalMatchInputV2.fromRecord(old),
          throwsFormatException,
        );
        expect(
          () => TacticalMatchInputV2.fromRecord(old, attemptCount: 2),
          throwsFormatException,
        );
        final unknownAttempt = TacticalMatchInputV2.fromRecord(
          old,
          occurredPrecision: 'instant',
        );
        expect(unknownAttempt.attemptCount, isNull);
        expect(unknownAttempt.toWire().containsKey('attempt_count'), isTrue);
        expect(unknownAttempt.toWire()['attempt_count'], isNull);
        final edited = TacticalMatchInputV2.fromRecord(
          old,
          attemptCount: 2,
          occurredPrecision: 'instant',
        );
        expect(edited.toWire()['attempt_count'], 2);
        expect(edited.toWire().containsKey('created_at'), isFalse);
        final kept = TacticalMatchInputV2.fromRecord(
          TacticalMatchV2.fromWire(
            _matchRecord({'attempt_count': 4, 'occurred_precision': 'instant'}),
          ),
        );
        expect(kept.attemptCount, 4);
      },
    );
  });

  group('protocol client', () {
    test(
      'tactical allowlist 8 are typed backend errors, others stay protocol errors',
      () async {
        for (final code in [..._allowlist8, 'revision_conflict']) {
          final process = _FakeBackendProcess();
          final client = PlanningProtocolClient(() async => process);
          await client.start();
          final result = client.send(
            'tactical.v2.match.upsert',
            _case('match.upsert'),
          );
          process.respond(process.lastRequest, {
            'error': {'code': code, 'message': 'synthetic $code'},
          });
          await expectLater(result, throwsA(_remote(code)), reason: code);
          expect(client.connection.value, BackendConnection.connected);
          await client.dispose();
        }
        // v1 쓰기도 같은 tactical 집합이다(이관 뒤 read-only).
        final v1 = _FakeBackendProcess();
        final v1Client = PlanningProtocolClient(() async => v1);
        await v1Client.start();
        final v1Result = v1Client.send('tactical.match.upsert', {});
        v1.respond(v1.lastRequest, {
          'error': {
            'code': 'tactical_v1_read_only',
            'message': 'legacy tactical writes are disabled after v2 migration',
          },
        });
        await expectLater(v1Result, throwsA(_remote('tactical_v1_read_only')));
        await v1Client.dispose();
        final unknown = _FakeBackendProcess();
        final client = PlanningProtocolClient(() async => unknown);
        await client.start();
        final result = client.send('tactical.v2.legacy.preview', {
          'profile_id': _profile,
        });
        unknown.respond(unknown.lastRequest, {
          'error': {'code': 'not_a_tactical_code', 'message': 'synthetic'},
        });
        await expectLater(result, throwsA(isA<BackendProtocolException>()));
        await client.dispose();
      },
    );

    test(
      'ProcessAppService sends exact requests and validates before sending',
      () async {
        final process = _FakeBackendProcess();
        final service = ProcessAppService(
          PlanningProtocolClient(() async => process),
        );
        await service.reconnect();
        final before = process.writes.length;
        await expectLater(
          service.upsertTacticalMatchV2(
            profileId: 'not-a-profile',
            match: _matchInput(),
            expectedRevision: 0,
            idempotencyKey: 'k',
          ),
          throwsFormatException,
        );
        await expectLater(
          service.commitTacticalLegacyMigration(
            profileId: _profile,
            expectedSourceRevision: 1,
            expectedFingerprint: 'short',
            expectedRevision: 0,
            idempotencyKey: 'k',
          ),
          throwsFormatException,
        );
        await expectLater(
          service.deleteTacticalJokboV2(
            profileId: _profile,
            jokboId: 'k',
            expectedRevision: 0,
            idempotencyKey: '',
          ),
          throwsFormatException,
        );
        expect(process.writes.length, before);

        final upsert = service.upsertTacticalMatchV2(
          profileId: _profile,
          match: _matchInput(id: 'm1', opponentName: 'Synthetic Rival'),
          expectedRevision: 0,
          idempotencyKey: 'synthetic-key',
        );
        final request = process.lastRequest;
        expect(request['method'], 'tactical.v2.match.upsert');
        expect((request['payload'] as Map).keys.toSet(), {
          'profile_id',
          'expected_revision',
          'idempotency_key',
          'match',
        });
        expect(
          ((request['payload'] as Map)['match'] as Map).keys.toSet(),
          (_case('match.upsert')['match'] as Map).keys.toSet(),
        );
        process.respond(request, {
          'revision': 1,
          'match': _matchRecord({
            'attempt_count': 3,
            'occurred_precision': 'instant',
          }),
          'jokbo_ids': <String>[],
        });
        final saved = await upsert;
        expect(saved.revision, 1);
        expect(saved.match.attemptCount, 3);

        final commit = service.commitTacticalLegacyMigration(
          profileId: _profile,
          expectedSourceRevision: 1,
          expectedFingerprint: _fingerprint,
          expectedRevision: 0,
          idempotencyKey: 'synthetic-key',
        );
        expect(process.lastRequest['payload'], _case('legacy.commit'));
        process.respond(process.lastRequest, {
          'revision': 1,
          'imported_matches': 1,
          'imported_jokbo': 0,
          'v1_writes_disabled': true,
        });
        expect((await commit).importedMatches, 1);

        final preview = service.previewTacticalLegacyMigration(_profile);
        expect(process.lastRequest['payload'], _case('legacy.preview'));
        process.respond(process.lastRequest, {
          'source_revision': 1,
          'source_fingerprint': _fingerprint,
          'match_count': 1,
          'jokbo_count': 0,
          'issues': <Object>[],
          'v1_writes_disabled': true,
        });
        expect((await preview).v1WritesDisabled, isTrue);

        final deleteMatch = service.deleteTacticalMatchV2(
          profileId: _profile,
          matchId: 'm1',
          expectedRevision: 0,
          idempotencyKey: 'synthetic-key',
        );
        expect(process.lastRequest['payload'], _case('match.delete'));
        process.respond(process.lastRequest, {'revision': 2, 'match_id': 'm1'});
        expect((await deleteMatch).matchId, 'm1');

        final jokbo = service.upsertTacticalJokboV2(
          profileId: _profile,
          jokbo: TacticalJokboInputV2(
            id: 'manual-j1',
            name: 'Synthetic template',
            attackDeck: TacticalDeckV2.fromWire(
              _copy((_case('jokbo.upsert')['jokbo'] as Map)['attack_deck']),
            ),
            defenseDeck: TacticalDeckV2.fromWire(
              _copy((_case('jokbo.upsert')['jokbo'] as Map)['defense_deck']),
            ),
            notes: (_case('jokbo.upsert')['jokbo'] as Map)['notes'] as String,
          ),
          expectedRevision: 0,
          idempotencyKey: 'synthetic-key',
        );
        expect(process.lastRequest['payload'], _case('jokbo.upsert'));
        process.respond(process.lastRequest, {
          'revision': 3,
          'jokbo': _jokboRecord({'name': 'Synthetic template'}),
        });
        expect((await jokbo).jokbo.name, 'Synthetic template');

        final deleteJokbo = service.deleteTacticalJokboV2(
          profileId: _profile,
          jokboId: 'manual-j1',
          expectedRevision: 0,
          idempotencyKey: 'synthetic-key',
        );
        expect(process.lastRequest['payload'], _case('jokbo.delete'));
        // 성공 응답에 모르는 키가 있으면 연결 수준 protocol 오류다.
        process.respond(process.lastRequest, {
          'revision': 4,
          'jokbo_id': 'manual-j1',
          'deleted': true,
        });
        await expectLater(
          deleteJokbo,
          throwsA(isA<BackendProtocolException>()),
        );
        await service.dispose();
      },
    );
  });

  group('Mock v2', () {
    test(
      'v1 rows require explicit migration, then v1 becomes read-only',
      () async {
        final service = MockAppService();
        await service.saveTacticalMatch(
          _mockProfile,
          _v1Match('v1-one'),
          0,
          'a',
        );
        await service.saveTacticalJokbo(
          _mockProfile,
          _v1Jokbo('v1-jokbo'),
          1,
          'b',
        );
        await expectLater(
          service.upsertTacticalMatchV2(
            profileId: _mockProfile,
            match: _matchInput(),
            expectedRevision: 0,
            idempotencyKey: 'manual',
          ),
          throwsA(_remote('legacy_migration_required')),
        );
        await expectLater(
          service.upsertTacticalJokboV2(
            profileId: _mockProfile,
            jokbo: _jokboInput(),
            expectedRevision: 0,
            idempotencyKey: 'manual-jokbo',
          ),
          throwsA(_remote('legacy_migration_required')),
        );
        final stale = await service.previewTacticalLegacyMigration(
          _mockProfile,
        );
        expect(stale.sourceRevision, 2);
        expect((stale.matchCount, stale.jokboCount), (1, 1));
        expect(stale.issues, isEmpty);
        expect(stale.v1WritesDisabled, isFalse);
        // 미리보기 뒤 v1이 바뀌면 commit은 import_source_changed(아무것도 쓰지 않음).
        await service.saveTacticalMatch(
          _mockProfile,
          _v1Match('v1-two', occurredOn: null),
          2,
          'c',
        );
        await expectLater(
          service.commitTacticalLegacyMigration(
            profileId: _mockProfile,
            expectedSourceRevision: stale.sourceRevision,
            expectedFingerprint: stale.sourceFingerprint,
            expectedRevision: 0,
            idempotencyKey: 'migration',
          ),
          throwsA(_remote('import_source_changed')),
        );
        expect(
          (await service.loadTacticalEvidenceState(_mockProfile)).revision,
          0,
        );
        final preview = await service.previewTacticalLegacyMigration(
          _mockProfile,
        );
        expect(preview.sourceFingerprint, isNot(stale.sourceFingerprint));
        final migrated = await service.commitTacticalLegacyMigration(
          profileId: _mockProfile,
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
        // 같은 key = 원 응답(revision 검사 전), 다른 key = legacy_already_migrated.
        final replay = await service.commitTacticalLegacyMigration(
          profileId: _mockProfile,
          expectedSourceRevision: preview.sourceRevision,
          expectedFingerprint: preview.sourceFingerprint,
          expectedRevision: 0,
          idempotencyKey: 'migration',
        );
        expect(replay.revision, migrated.revision);
        await expectLater(
          service.commitTacticalLegacyMigration(
            profileId: _mockProfile,
            expectedSourceRevision: preview.sourceRevision,
            expectedFingerprint: preview.sourceFingerprint,
            expectedRevision: 1,
            idempotencyKey: 'migration-again',
          ),
          throwsA(_remote('legacy_already_migrated')),
        );
        expect(
          (await service.previewTacticalLegacyMigration(
            _mockProfile,
          )).v1WritesDisabled,
          isTrue,
        );
        for (final write in <Future<int> Function()>[
          () => service.saveTacticalMatch(_mockProfile, _v1Match('x'), 3, 'd'),
          () => service.deleteTacticalMatch(_mockProfile, 'v1-one', 3, 'e'),
          () => service.saveTacticalJokbo(_mockProfile, _v1Jokbo('y'), 3, 'f'),
          () => service.deleteTacticalJokbo(_mockProfile, 'v1-jokbo', 3, 'g'),
        ]) {
          await expectLater(write(), throwsA(_remote('tactical_v1_read_only')));
        }
        // v1 원본은 읽을 수 있고 바뀌지 않는다.
        final v1 = await service.loadTacticalState(_mockProfile);
        expect((v1.revision, v1.matches.length, v1.jokbo.length), (3, 2, 1));

        final state = await service.loadTacticalEvidenceState(_mockProfile);
        expect(state.revision, 1);
        expect(state.matches, hasLength(2));
        expect(state.matches.map((item) => item.attemptCount), [null, null]);
        expect(state.matches.map((item) => item.occurredPrecision).toSet(), {
          'date',
          'unknown',
        });
        final dated = state.matches.firstWhere(
          (item) => item.occurredPrecision == 'date',
        );
        expect(dated.occurredAt, '2026-10-13T00:00:00+09:00');
        expect(dated.sourceLabel, 'v7_v1_migration');
        expect(dated.opponentDisplayName, 'Rival');
        expect(state.opponents, hasLength(1));
        expect(state.jokbo.where((item) => item.name == null), isEmpty);
        expect(
          state.jokbo.map((item) => item.id),
          contains(startsWith('legacy-jokbo-')),
        );
        // 이관 뒤에는 v2 새 쓰기가 된다.
        final saved = await service.upsertTacticalMatchV2(
          profileId: _mockProfile,
          match: _matchInput(),
          expectedRevision: 1,
          idempotencyKey: 'manual',
        );
        expect(saved.revision, 2);
      },
    );

    test('empty v1 is claimed by the first v2 write', () async {
      final service = MockAppService();
      final saved = await service.upsertTacticalJokboV2(
        profileId: _mockProfile,
        jokbo: _jokboInput(),
        expectedRevision: 0,
        idempotencyKey: 'jokbo',
      );
      expect(saved.revision, 1);
      expect(saved.jokbo.name, 'Synthetic');
      expect(
        (await service.previewTacticalLegacyMigration(
          _mockProfile,
        )).v1WritesDisabled,
        isTrue,
      );
      await expectLater(
        service.saveTacticalMatch(_mockProfile, _v1Match('late'), 0, 'late'),
        throwsA(_remote('tactical_v1_read_only')),
      );
      await expectLater(
        service.commitTacticalLegacyMigration(
          profileId: _mockProfile,
          expectedSourceRevision: 0,
          expectedFingerprint: _fingerprint,
          expectedRevision: 1,
          idempotencyKey: 'migration',
        ),
        throwsA(_remote('legacy_already_migrated')),
      );
    });

    test(
      'failed v2 writes do not claim v1 and existing v1 Mock stays as before',
      () async {
        final service = MockAppService();
        await expectLater(
          service.upsertTacticalJokboV2(
            profileId: _mockProfile,
            jokbo: _jokboInput(
              attack: _deck([null, null, null, null], [null, null]),
            ),
            expectedRevision: 0,
            idempotencyKey: 'empty-attack',
          ),
          throwsA(_remote('invalid_payload')),
        );
        expect(
          (await service.previewTacticalLegacyMigration(
            _mockProfile,
          )).v1WritesDisabled,
          isFalse,
        );
        expect(
          await service.saveTacticalMatch(_mockProfile, _v1Match('v1'), 0, 'a'),
          1,
        );
        expect(
          await service.deleteTacticalMatch(_mockProfile, 'v1', 1, 'b'),
          2,
        );
        await expectLater(
          service.saveTacticalMatch(_mockProfile, _v1Match('v1'), 0, 'c'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'retry returns the original response and never restores a deleted record',
      () async {
        final service = MockAppService();
        final first = await service.upsertTacticalMatchV2(
          profileId: _mockProfile,
          match: _matchInput(),
          expectedRevision: 0,
          idempotencyKey: 'save',
        );
        expect(first.revision, 1);
        expect(first.match.attemptCount, 3);
        expect(first.match.occurredPrecision, 'instant');
        expect(first.match.sourceLabel, 'manual_record');
        expect(first.jokboIds, hasLength(1));
        final again = await service.upsertTacticalMatchV2(
          profileId: _mockProfile,
          match: _matchInput(),
          expectedRevision: 0,
          idempotencyKey: 'save',
        );
        expect(again.revision, 1);
        expect(again.match.createdAt, first.match.createdAt);
        await expectLater(
          service.upsertTacticalMatchV2(
            profileId: _mockProfile,
            match: _matchInput(notes: 'changed'),
            expectedRevision: 1,
            idempotencyKey: 'save',
          ),
          throwsA(_remote('idempotency_conflict')),
        );
        await expectLater(
          service.upsertTacticalMatchV2(
            profileId: _mockProfile,
            match: _matchInput(notes: 'changed'),
            expectedRevision: 0,
            idempotencyKey: 'edit',
          ),
          throwsA(_remote('revision_conflict')),
        );
        final edited = await service.upsertTacticalMatchV2(
          profileId: _mockProfile,
          match: _matchInput(notes: 'changed', attemptCount: 5),
          expectedRevision: 1,
          idempotencyKey: 'edit',
        );
        expect(edited.match.notes, 'changed');
        expect(edited.match.attemptCount, 5);
        expect(edited.match.sourceLabel, 'manual_edit');
        expect(edited.match.createdAt, first.match.createdAt);
        final deleted = await service.deleteTacticalMatchV2(
          profileId: _mockProfile,
          matchId: 'manual-one',
          expectedRevision: 2,
          idempotencyKey: 'delete',
        );
        expect(deleted.revision, 3);
        final replay = await service.upsertTacticalMatchV2(
          profileId: _mockProfile,
          match: _matchInput(),
          expectedRevision: 0,
          idempotencyKey: 'save',
        );
        expect(replay.revision, 1);
        final state = await service.loadTacticalEvidenceState(_mockProfile);
        expect(state.revision, 3);
        expect(state.matches, isEmpty);
        expect(state.snapshots, isEmpty);
        await expectLater(
          service.deleteTacticalMatchV2(
            profileId: _mockProfile,
            matchId: 'manual-one',
            expectedRevision: 3,
            idempotencyKey: 'delete-again',
          ),
          throwsA(_remote('record_not_found')),
        );
        expect(
          (await service.deleteTacticalMatchV2(
            profileId: _mockProfile,
            matchId: 'manual-one',
            expectedRevision: 2,
            idempotencyKey: 'delete',
          )).revision,
          3,
        );
      },
    );

    test('identity, lineage and snapshot rules', () async {
      final service = MockAppService();
      final full = await service.upsertTacticalMatchV2(
        profileId: _mockProfile,
        match: _matchInput(),
        expectedRevision: 0,
        idempotencyKey: 'full',
      );
      var state = await service.loadTacticalEvidenceState(_mockProfile);
      expect(state.snapshots.single.matchId, 'manual-one');
      expect(state.opponents.single.aliases, ['Rival']);
      final lineage = full.jokboIds.single;
      expect(lineage, startsWith('lineage-'));
      final derived = state.jokbo.single;
      expect(derived.id, lineage);
      expect(derived.name, startsWith('족보 '));
      // 이름 편집 뒤 같은 pair의 다른 기록은 이름을 덮지 않는다.
      await service.upsertTacticalJokboV2(
        profileId: _mockProfile,
        jokbo: _jokboInput(id: lineage, name: 'User name'),
        expectedRevision: 1,
        idempotencyKey: 'rename',
      );
      await service.upsertTacticalMatchV2(
        profileId: _mockProfile,
        match: _matchInput(id: 'manual-two'),
        expectedRevision: 2,
        idempotencyKey: 'two',
      );
      state = await service.loadTacticalEvidenceState(_mockProfile);
      expect(state.jokbo.single.name, 'User name');
      await expectLater(
        service.upsertTacticalJokboV2(
          profileId: _mockProfile,
          jokbo: _jokboInput(
            id: lineage,
            name: 'User name',
            defense: _deck(
              ['shiroko', 'akane', 'yuuka', 'mika'],
              ['serina', 'hibiki'],
              wildcardLast: true,
            ),
          ),
          expectedRevision: 3,
          idempotencyKey: 'redefine',
        ),
        throwsA(_remote('lineage_conflict')),
      );
      await expectLater(
        service.upsertTacticalMatchV2(
          profileId: _mockProfile,
          match: _matchInput(id: 'manual-three', opponentName: 'Different'),
          expectedRevision: 3,
          idempotencyKey: 'alias',
        ),
        throwsA(_remote('opponent_alias_required')),
      );
      // 부분(와일드카드) 방어 덱은 완전 스냅샷을 만들지 않고 와일드카드를 그대로 둔다.
      final partial = await service.upsertTacticalMatchV2(
        profileId: _mockProfile,
        match: _matchInput(
          id: 'manual-partial',
          defense: _deck(
            ['shiroko', 'akane', 'yuuka', 'mika'],
            ['serina', 'hibiki'],
            wildcardLast: true,
          ),
        ),
        expectedRevision: 3,
        idempotencyKey: 'partial',
      );
      expect(partial.match.defenseDeck.strikers[3].wildcard, isTrue);
      state = await service.loadTacticalEvidenceState(_mockProfile);
      expect(state.revision, 4);
      expect(state.snapshots.map((item) => item.matchId).toSet(), {
        'manual-one',
        'manual-two',
      });
      expect(state.jokbo, hasLength(2));
    });

    test('unresolved legacy conversion rejects the whole migration', () async {
      final service = MockAppService();
      await service.saveTacticalMatch(_mockProfile, _v1Match('ok'), 0, 'a');
      await service.saveTacticalMatch(
        _mockProfile,
        TacticalMatch(
          id: 'bad',
          kind: 'attack',
          occurredOn: '2026-13-40',
          season: '34',
          opponent: 'Rival',
          result: 'win',
          attackDeck: TacticalDeck.empty(),
          defenseDeck: TacticalDeck.empty(),
          notes: '',
        ),
        1,
        'b',
      );
      final preview = await service.previewTacticalLegacyMigration(
        _mockProfile,
      );
      expect(preview.issues.single.recordId, 'bad');
      expect(preview.issues.single.recordKind, 'match');
      await expectLater(
        service.commitTacticalLegacyMigration(
          profileId: _mockProfile,
          expectedSourceRevision: preview.sourceRevision,
          expectedFingerprint: preview.sourceFingerprint,
          expectedRevision: 0,
          idempotencyKey: 'migration',
        ),
        throwsA(_remote('import_review_required')),
      );
      final state = await service.loadTacticalEvidenceState(_mockProfile);
      expect(state.revision, 0);
      expect(state.matches, isEmpty);
      expect(
        await service.saveTacticalMatch(_mockProfile, _v1Match('c'), 2, 'c'),
        3,
      );
    });

    test('profile deletion clears the v2 Mock store too', () async {
      final service = MockAppService();
      final other = await service.createProfile('Other', 'create-other');
      await service.upsertTacticalMatchV2(
        profileId: other.id,
        match: _matchInput(),
        expectedRevision: 0,
        idempotencyKey: 'save',
      );
      await service.upsertTacticalMatchV2(
        profileId: _mockProfile,
        match: _matchInput(),
        expectedRevision: 0,
        idempotencyKey: 'save',
      );
      final profile = (await service.listProfiles()).firstWhere(
        (item) => item.id == other.id,
      );
      await service.deleteProfile(other.id, profile.revision, 'delete-other');
      await expectLater(
        service.loadTacticalEvidenceState(other.id),
        throwsA(isA<StateError>()),
      );
      expect(
        (await service.loadTacticalEvidenceState(_mockProfile)).matches,
        hasLength(1),
      );
    });
  });
}

class _FakeBackendProcess implements BackendProcessHandle {
  final StreamController<String> _stdout = StreamController<String>();
  final StreamController<String> _stderr = StreamController<String>();
  final Completer<int> _exit = Completer<int>();
  final List<String> writes = [];

  Map<String, dynamic> get lastRequest =>
      Map<String, dynamic>.from(jsonDecode(writes.last) as Map);

  @override
  Stream<String> get stdoutLines => _stdout.stream;

  @override
  Stream<String> get stderrLines => _stderr.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void writeLine(String line) => writes.add(line);

  @override
  Future<void> closeInput() async => _finish(0);

  @override
  bool terminate([ProcessSignal signal = ProcessSignal.sigterm]) {
    _finish(-1);
    return true;
  }

  void respond(Map<String, dynamic> request, Map<String, dynamic> payload) {
    _stdout.add(
      jsonEncode({
        'protocol': 1,
        'id': request['id'],
        'type': 'response',
        'method': request['method'],
        'payload': payload,
      }),
    );
  }

  void _finish(int code) {
    if (!_exit.isCompleted) {
      _exit.complete(code);
      unawaited(_stdout.close());
      unawaited(_stderr.close());
    }
  }
}
