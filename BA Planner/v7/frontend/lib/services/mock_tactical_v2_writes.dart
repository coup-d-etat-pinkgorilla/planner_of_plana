// FB-6 Mock: 전술 v2 기록·족보 쓰기와 명시적 v7-v1 이관(backend `core/tactical_fb6_store.py`와 같은 순서·오류 코드).
//
// - v1 기록이 있으면 새 v2 기록·족보 쓰기는 `legacy_migration_required`. 미리보기 → commit(같은 source revision·
//   fingerprint) 뒤 v1 새 쓰기는 `tactical_v1_read_only`. v1이 비어 있으면 첫 v2 쓰기가 같은 쓰기에서 빈 이관
//   표식을 남긴다.
// - 같은 key 재요청 = 원 응답(revision 검사 전), 다른 내용 = `idempotency_conflict`. 삭제 뒤 원 요청을 다시 보내도
//   레코드를 되살리지 않는다. 실패한 쓰기는 아무것도 바꾸지 않는다(사본에 적용한 뒤 성공할 때만 바꾼다).
// - 시도 횟수·시각 정밀도는 받은 그대로 둔다. v1 이관 기록은 시도 횟수 null, 날짜는 `date`(KST 자정 표기),
//   날짜가 없으면 `unknown`.
// - FB-6b(FD-176): 시도 횟수 null(모름)을 그대로 저장한다(1로 채우지 않는다). 상대 모르는 방어 기록(identity·이름
//   null 쌍)은 상대 identity·별칭을 만들지 않는다. 이관 기록의 null 시도를 고쳐 저장해도(null 그대로 포함) 된다.
// - Mock에는 학생 카탈로그·보유 학생 검사, 로비 후보 연결(`link_conflict`)이 없고 자동 족보 이름은 학생 ID를 쓴다.
//   ID 해시는 백엔드 sha256과 다른 결정적 값이다(같은 입력 → 같은 ID).
import 'dart:convert';

import 'planning_protocol_client.dart' show BackendRemoteException;
import 'tactical_service.dart';
import 'tactical_v2_service.dart';

// FB-7 엑셀·CSV 가져오기 Mock(같은 v2 저장·revision·idempotency를 쓴다).
part 'mock_tactical_v2_excel.dart';

Map<String, dynamic> _copy(Object? value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

BackendRemoteException _error(
  String code,
  String message, {
  Map<String, dynamic>? details,
}) => BackendRemoteException(code: code, message: message, details: details);

/// 결정적 16진 문자열(FNV-1a 32비트를 salt별로 이어 붙임). 암호 해시가 아니다.
String _mockHex(String text, int length) {
  final out = StringBuffer();
  for (var salt = 0; out.length < length; salt++) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode('$salt\u0000$text')) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    out.write(hash.toRadixString(16).padLeft(8, '0'));
  }
  return out.toString().substring(0, length);
}

String _stableId(String prefix, List<String> parts) =>
    '$prefix-${_mockHex(parts.join('\u0000'), 32)}';

Iterable<Map<String, dynamic>> _slots(Map<String, dynamic> deck) => [
  ...(deck['strikers'] as List).cast<Map<String, dynamic>>(),
  ...(deck['specials'] as List).cast<Map<String, dynamic>>(),
];

/// 위치가 중요하고 와일드카드·모름·확인된 빈칸을 구분한다(backend `deck_identity`).
List<String> _deckIdentity(Map<String, dynamic> deck) => [
  for (final slot in _slots(deck))
    slot['student_id'] as String? ??
        (slot['wildcard'] == true
            ? '*'
            : slot['state'] == 'empty'
            ? 'empty'
            : '?'),
];

String _lineageId(Map<String, dynamic> defense, Map<String, dynamic> attack) =>
    'lineage-${_mockHex(jsonEncode({'defense': _deckIdentity(defense), 'attack': _deckIdentity(attack)}), 32)}';

bool _reviewed(Map<String, dynamic> deck) =>
    _slots(deck).every((slot) => slot['review_status'] == 'confirmed');

bool _completeConfirmed(Map<String, dynamic> deck) => _slots(deck).every(
  (slot) =>
      slot['student_id'] != null &&
      slot['wildcard'] != true &&
      slot['review_status'] == 'confirmed',
);

class MockTacticalV2Writes {
  MockTacticalV2Writes({required this.legacyState, required this.clock});

  /// Mock v1 상태(프로필 검사 포함). 이관 원본이다.
  final TacticalState Function(String profileId) legacyState;
  final DateTime Function() clock;
  final Map<String, Map<String, dynamic>> _values = {};

  /// v2가 유일한 쓰기 저장소인가(이관 완료 또는 빈 v1 claim).
  bool v1WritesDisabled(String profileId) =>
      _values[profileId]?.containsKey('legacy_v1') ?? false;

  /// Mock v1 쓰기 앞에서 부른다. 이관 뒤에는 `tactical_v1_read_only`.
  void requireV1Writable(String profileId) {
    if (v1WritesDisabled(profileId)) {
      throw _error(
        'tactical_v1_read_only',
        'legacy tactical writes are disabled after v2 migration',
      );
    }
  }

  void remove(String profileId) => _values.remove(profileId);

  Map<String, dynamic> _value(String profileId) =>
      _values[profileId] ??
      {
        'revision': 0,
        'matches': <Object>[],
        'jokbo': <Object>[],
        'opponents': <Object>[],
        'snapshots': <Object>[],
        'idempotency': <String, Object>{},
      };

  TacticalEvidenceState state(String profileId) {
    legacyState(profileId);
    final value = _copy(_value(profileId));
    return TacticalEvidenceState.fromWire({
      'version': 2,
      'profile_id': profileId,
      'revision': value['revision'],
      'matches': value['matches'],
      'jokbo': value['jokbo'],
      'opponents': value['opponents'],
      'snapshots': value['snapshots'],
      'lobby_scans': const <Object>[],
      'lobby_candidates': const <Object>[],
      'predictions': const <Object>[],
      'import_batches': const <Object>[],
    });
  }

  Map<String, dynamic> _metadata(
    String recordId, {
    String label = 'manual_record',
    String? now,
  }) {
    final stamp = now ?? clock().toUtc().toIso8601String();
    return {
      'created_at': stamp,
      'imported_at': stamp,
      'source': 'manual',
      'source_label': label,
      'import_batch_id': label == 'v7_v1_migration' ? 'legacy-v1' : 'manual',
      'source_record_id': recordId,
      'confidence': null,
      'review_status': 'confirmed',
    };
  }

  Map<String, dynamic> _mutation(
    String profileId,
    int expectedRevision,
    String idempotencyKey,
    Map<String, dynamic> operation,
    Map<String, dynamic> Function(Map<String, dynamic> value) apply,
  ) {
    legacyState(profileId);
    final value = _copy(_value(profileId));
    final fingerprint = jsonEncode(operation);
    final cache = value['idempotency'] as Map<String, dynamic>;
    final cached = cache[idempotencyKey];
    if (cached is Map) {
      if (cached['fingerprint'] != fingerprint) {
        throw _error(
          'idempotency_conflict',
          'idempotency key was used for another tactical v2 mutation',
        );
      }
      return _copy(cached['response']);
    }
    if (value['revision'] != expectedRevision) {
      throw _error(
        'revision_conflict',
        'expected tactical v2 revision is stale',
        details: {'current_revision': value['revision']},
      );
    }
    final changed = apply(value);
    // FB-7: 가져올 행·바뀐 규칙이 없는 commit은 revision을 올리지 않는다(백엔드 `_no_change`).
    if (changed.remove('_no_change') != true) {
      value['revision'] = (value['revision'] as int) + 1;
    }
    final response = {'revision': value['revision'], ...changed};
    cache[idempotencyKey] = {'fingerprint': fingerprint, 'response': response};
    _values[profileId] = value;
    return _copy(response);
  }

  ({
    TacticalState state,
    String fingerprint,
    List<Map<String, dynamic>> matches,
    List<Map<String, dynamic>> jokbo,
    List<Map<String, dynamic>> opponents,
    List<Map<String, dynamic>> issues,
  })
  _convert(String profileId) {
    final state = legacyState(profileId);
    final fingerprint = _mockHex(
      jsonEncode({
        'revision': state.revision,
        'matches': [for (final item in state.matches) item.toWire()],
        'jokbo': [for (final item in state.jokbo) item.toWire()],
      }),
      64,
    );
    final stamp = clock().toUtc().toIso8601String();
    Map<String, dynamic> deck(TacticalDeck source) => {
      'version': 2,
      for (final (role, items) in [
        ('strikers', source.strikers),
        ('specials', source.specials),
      ])
        role: [
          for (final (position, studentId) in items.indexed)
            {
              'version': 2,
              'position': position,
              'student_id': studentId,
              'state': studentId == null ? 'unknown' : 'manual',
              'source': 'manual',
              'confidence': null,
              'review_status': studentId == null ? 'unreviewed' : 'confirmed',
              'wildcard': false,
            },
        ],
    };
    Map<String, dynamic> date(String? value) {
      if (value == null) {
        return {'occurred_at': null, 'occurred_precision': 'unknown'};
      }
      // DateTime.parse는 2026-13-40 같은 값을 넘겨 버리므로 되돌린 표기와 같아야 한다.
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          !(DateTime.tryParse(value)?.toIso8601String().startsWith(value) ??
              false)) {
        throw const FormatException('legacy date must be YYYY-MM-DD or null');
      }
      return {
        'occurred_at': '${value}T00:00:00+09:00',
        'occurred_precision': 'date',
      };
    }

    final matches = <Map<String, dynamic>>[];
    final jokbo = <Map<String, dynamic>>[];
    final opponents = <String, Map<String, dynamic>>{};
    final issues = <Map<String, dynamic>>[];
    for (final source in state.matches) {
      try {
        final opponentId = _stableId('legacy-opponent', [
          profileId,
          source.opponent,
        ]);
        final item = {
          ..._metadata(
            'v7-v1:match:${source.id}',
            label: 'v7_v1_migration',
            now: stamp,
          ),
          'version': 2,
          'match_id': _stableId('legacy-match', [profileId, source.id]),
          'kind': source.kind,
          ...date(source.occurredOn),
          'observed_at': null,
          'season': source.season,
          'opponent_identity_id': opponentId,
          'opponent_display_name': source.opponent,
          'result': source.result,
          'attack_deck': deck(source.attackDeck),
          'defense_deck': deck(source.defenseDeck),
          'notes': source.notes,
          'attempt_count': null,
        };
        item['review_status'] =
            _reviewed(item['attack_deck'] as Map<String, dynamic>) &&
                _reviewed(item['defense_deck'] as Map<String, dynamic>)
            ? 'confirmed'
            : 'review_required';
        TacticalMatchV2.fromWire(_copy(item));
        matches.add(item);
        opponents.putIfAbsent(
          opponentId,
          () => {
            'version': 2,
            'identity_id': opponentId,
            'current_display_name': source.opponent,
            'aliases': [source.opponent],
            'first_observed_at': null,
            'last_observed_at': null,
            'review_status': 'review_required',
            'name_template_ids': <String>[],
          },
        );
      } on FormatException catch (error) {
        issues.add({
          'record_kind': 'match',
          'record_id': source.id.isEmpty ? '?' : source.id,
          'code': 'invalid_payload',
          'message': error.message,
        });
      }
    }
    for (final source in state.jokbo) {
      try {
        final id = _stableId('legacy-jokbo', [profileId, source.id]);
        final item = {
          ..._metadata(
            'v7-v1:jokbo:${source.id}',
            label: 'v7_v1_migration',
            now: stamp,
          ),
          'version': 2,
          'jokbo_id': id,
          'name': '족보 ${id.substring(id.length - 6)}',
          'attack_deck': deck(source.attackDeck),
          'defense_deck': deck(source.defenseDeck),
          'wins': 0,
          'losses': 0,
          'notes': source.notes,
        };
        TacticalJokboV2.fromWire(_copy(item));
        jokbo.add(item);
      } on FormatException catch (error) {
        issues.add({
          'record_kind': 'jokbo',
          'record_id': source.id.isEmpty ? '?' : source.id,
          'code': 'invalid_payload',
          'message': error.message,
        });
      }
    }
    return (
      state: state,
      fingerprint: fingerprint,
      matches: matches,
      jokbo: jokbo,
      opponents: opponents.values.toList(),
      issues: issues,
    );
  }

  void _ensureWriteMode(String profileId, Map<String, dynamic> value) {
    if (value.containsKey('legacy_v1')) return;
    final legacy = _convert(profileId);
    if (legacy.state.matches.isNotEmpty || legacy.state.jokbo.isNotEmpty) {
      throw _error(
        'legacy_migration_required',
        'preview and migrate existing v1 records before a new v2 record write',
      );
    }
    // 빈 v1은 첫 v2 쓰기가 같은 쓰기에서 유일한 쓰기 저장소로 claim한다.
    value['legacy_v1'] = {
      'version': 1,
      'source_revision': legacy.state.revision,
      'source_fingerprint': legacy.fingerprint,
      'match_count': 0,
      'jokbo_count': 0,
    };
  }

  List<String> _derivedJokbo(
    Map<String, dynamic> value,
    Map<String, dynamic> match,
  ) {
    if (match['kind'] != 'attack') return const [];
    final attack = match['attack_deck'] as Map<String, dynamic>;
    final defense = match['defense_deck'] as Map<String, dynamic>;
    final id = _lineageId(defense, attack);
    final jokbo = value['jokbo'] as List;
    if (!jokbo.any((item) => (item as Map)['jokbo_id'] == id)) {
      final first = (attack['strikers'] as List)
          .map((slot) => (slot as Map)['student_id'] as String?)
          .whereType<String>()
          .firstOrNull;
      jokbo.add({
        ..._metadata('derived:$id'),
        'version': 2,
        'jokbo_id': id,
        'name': '족보 ${id.substring(8, 14)} · ${first ?? '미확인 편성'}',
        'attack_deck': _copy(attack),
        'defense_deck': _copy(defense),
        'wins': 0,
        'losses': 0,
        'notes': '',
        'review_status': match['review_status'],
      });
    }
    return [id];
  }

  TacticalMatchUpsertResult upsertMatch({
    required String profileId,
    required TacticalMatchInputV2 match,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    final input = match.toWire();
    if (input['occurred_precision'] == 'instant') {
      input['occurred_at'] = DateTime.parse(
        input['occurred_at'] as String,
      ).toUtc().toIso8601String();
    }
    final response = _mutation(
      profileId,
      expectedRevision,
      idempotencyKey,
      {'method': 'match.upsert', 'match': input},
      (value) {
        _ensureWriteMode(profileId, value);
        return _applyMatch(value, input);
      },
    );
    return TacticalMatchUpsertResult.fromWire(response);
  }

  /// 기록 하나를 [value](사본)에 적용한다(backend `apply_match`). [recordMetadata]가 있으면(FB-7 원본 행) 출처를
  /// 그것으로 두고 덮어쓸 때 `created_at`만 유지한다. 없으면 수동 기록의 원래 출처 규칙 그대로다.
  Map<String, dynamic> _applyMatch(
    Map<String, dynamic> value,
    Map<String, dynamic> input, {
    Map<String, dynamic>? recordMetadata,
  }) {
    final opponents = (value['opponents'] as List).cast<Map<String, dynamic>>();
    final opponent = opponents
        .where((item) => item['identity_id'] == input['opponent_identity_id'])
        .firstOrNull;
    if (opponent != null &&
        !{
          opponent['current_display_name'],
          ...(opponent['aliases'] as List),
        }.contains(input['opponent_display_name'])) {
      throw _error(
        'opponent_alias_required',
        'name must match explicit identity or recorded alias',
      );
    }
    final matches = (value['matches'] as List).cast<Map<String, dynamic>>();
    final old = matches
        .where((item) => item['match_id'] == input['match_id'])
        .firstOrNull;
    final record = {
      ...(recordMetadata == null
          ? _metadata('manual:${input['match_id']}')
          : _copy(recordMetadata)),
      ..._copy(input),
      'observed_at': null,
    };
    if (old != null) {
      for (final field
          in recordMetadata == null
              ? [
                  'created_at',
                  'imported_at',
                  'import_batch_id',
                  'source_record_id',
                ]
              : ['created_at']) {
        record[field] = old[field];
      }
      if (recordMetadata == null) record['source_label'] = 'manual_edit';
    }
    final attack = record['attack_deck'] as Map<String, dynamic>;
    final defense = record['defense_deck'] as Map<String, dynamic>;
    record['review_status'] = _reviewed(attack) && _reviewed(defense)
        ? 'confirmed'
        : 'review_required';
    // FD-176: 상대 모르는 방어 기록(null 쌍)은 상대 identity·별칭을 만들지 않는다(backend `apply_match`).
    if (opponent == null && input['opponent_identity_id'] != null) {
      opponents.add({
        'version': 2,
        'identity_id': input['opponent_identity_id'],
        'current_display_name': input['opponent_display_name'],
        'aliases': [input['opponent_display_name']],
        'first_observed_at': input['occurred_at'],
        'last_observed_at': input['occurred_at'],
        'review_status': 'confirmed',
        'name_template_ids': <String>[],
      });
    }
    value['matches'] = [
      ...matches.where((item) => item['match_id'] != input['match_id']),
      record,
    ];
    final snapshots = [
      ...(value['snapshots'] as List).cast<Map<String, dynamic>>().where(
        (item) => item['match_id'] != input['match_id'],
      ),
    ];
    // 확인된 완전 방어 덱만 관측 스냅샷이 된다(부분·와일드카드 덱은 만들지 않는다).
    if (record['kind'] == 'attack' &&
        record['review_status'] == 'confirmed' &&
        _completeConfirmed(defense)) {
      snapshots.add({
        'version': 2,
        'snapshot_id': _stableId('snapshot', [
          'fb6',
          input['match_id'] as String,
        ]),
        'opponent_identity_id': record['opponent_identity_id'],
        'occurred_at': record['occurred_at'],
        'observed_at': null,
        'imported_at': record['imported_at'],
        'source': 'manual',
        'source_record_id': record['source_record_id'],
        'confidence': null,
        'review_status': 'confirmed',
        'season': record['season'],
        'deck': _copy(defense),
        'match_id': record['match_id'],
      });
    }
    value['snapshots'] = snapshots;
    return {'match': record, 'jokbo_ids': _derivedJokbo(value, record)};
  }

  TacticalMatchDeleteResult deleteMatch({
    required String profileId,
    required String matchId,
    required int expectedRevision,
    required String idempotencyKey,
  }) => TacticalMatchDeleteResult.fromWire(
    _mutation(
      profileId,
      expectedRevision,
      idempotencyKey,
      {'method': 'match.delete', 'match_id': matchId},
      (value) {
        final matches = value['matches'] as List;
        if (!matches.any((item) => (item as Map)['match_id'] == matchId)) {
          throw _error('record_not_found', 'match does not exist');
        }
        value['matches'] = [
          ...matches.where((item) => (item as Map)['match_id'] != matchId),
        ];
        value['snapshots'] = [
          ...(value['snapshots'] as List).where(
            (item) => (item as Map)['match_id'] != matchId,
          ),
        ];
        return {'match_id': matchId};
      },
    ),
  );

  TacticalJokboUpsertResult upsertJokbo({
    required String profileId,
    required TacticalJokboInputV2 jokbo,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    final input = jokbo.toWire();
    return TacticalJokboUpsertResult.fromWire(
      _mutation(
        profileId,
        expectedRevision,
        idempotencyKey,
        {'method': 'jokbo.upsert', 'jokbo': input},
        (value) {
          _ensureWriteMode(profileId, value);
          final attack = input['attack_deck'] as Map<String, dynamic>;
          final defense = input['defense_deck'] as Map<String, dynamic>;
          if (!_slots(attack).any((slot) => slot['student_id'] != null)) {
            throw _error(
              'invalid_payload',
              'jokbo requires at least one known attack student',
            );
          }
          final id = input['jokbo_id'] as String;
          final rows = (value['jokbo'] as List).cast<Map<String, dynamic>>();
          final old = rows.where((item) => item['jokbo_id'] == id).firstOrNull;
          if (id.startsWith('lineage-') && _lineageId(defense, attack) != id) {
            throw _error(
              'lineage_conflict',
              'copy to a new ID to change a derived lineage pair',
            );
          }
          final record = {
            ...(old != null ? _copy(old) : _metadata('manual:$id')),
            'wins': old?['wins'] ?? 0,
            'losses': old?['losses'] ?? 0,
            ..._copy(input),
          };
          value['jokbo'] = [
            ...rows.where((item) => item['jokbo_id'] != id),
            record,
          ];
          return {'jokbo': record};
        },
      ),
    );
  }

  TacticalJokboDeleteResult deleteJokbo({
    required String profileId,
    required String jokboId,
    required int expectedRevision,
    required String idempotencyKey,
  }) => TacticalJokboDeleteResult.fromWire(
    _mutation(
      profileId,
      expectedRevision,
      idempotencyKey,
      {'method': 'jokbo.delete', 'jokbo_id': jokboId},
      (value) {
        final rows = value['jokbo'] as List;
        if (!rows.any((item) => (item as Map)['jokbo_id'] == jokboId)) {
          throw _error('record_not_found', 'jokbo does not exist');
        }
        value['jokbo'] = [
          ...rows.where((item) => (item as Map)['jokbo_id'] != jokboId),
        ];
        return {'jokbo_id': jokboId};
      },
    ),
  );

  TacticalLegacyPreview preview(String profileId) {
    final legacy = _convert(profileId);
    return TacticalLegacyPreview.fromWire({
      'source_revision': legacy.state.revision,
      'source_fingerprint': legacy.fingerprint,
      'match_count': legacy.state.matches.length,
      'jokbo_count': legacy.state.jokbo.length,
      'issues': legacy.issues,
      'v1_writes_disabled': v1WritesDisabled(profileId),
    });
  }

  TacticalLegacyCommitResult commit({
    required String profileId,
    required int expectedSourceRevision,
    required String expectedFingerprint,
    required int expectedRevision,
    required String idempotencyKey,
  }) {
    legacyState(profileId);
    final value = _copy(_value(profileId));
    final fingerprint = jsonEncode({
      'method': 'legacy.commit',
      'source_revision': expectedSourceRevision,
      'fingerprint': expectedFingerprint,
    });
    final cache = value['idempotency'] as Map<String, dynamic>;
    final cached = cache[idempotencyKey];
    if (cached is Map) {
      if (cached['fingerprint'] != fingerprint) {
        throw _error('idempotency_conflict', 'key belongs to another mutation');
      }
      return TacticalLegacyCommitResult.fromWire(_copy(cached['response']));
    }
    if (value['revision'] != expectedRevision) {
      throw _error(
        'revision_conflict',
        'expected tactical v2 revision is stale',
        details: {'current_revision': value['revision']},
      );
    }
    if (value.containsKey('legacy_v1')) {
      throw _error(
        'legacy_already_migrated',
        'v1 migration already committed; use its original retry key',
      );
    }
    final legacy = _convert(profileId);
    if (legacy.state.revision != expectedSourceRevision ||
        legacy.fingerprint != expectedFingerprint) {
      throw _error(
        'import_source_changed',
        'v1 revision or fingerprint changed after preview',
      );
    }
    if (legacy.issues.isNotEmpty) {
      throw _error(
        'import_review_required',
        'legacy conversion issues must be resolved in v1 before migration',
        details: {'issues': legacy.issues},
      );
    }
    for (final (field, idField, rows) in [
      ('matches', 'match_id', legacy.matches),
      ('jokbo', 'jokbo_id', legacy.jokbo),
      ('opponents', 'identity_id', legacy.opponents),
    ]) {
      final existing = {
        for (final item in value[field] as List) (item as Map)[idField],
      };
      if (rows.any((item) => existing.contains(item[idField]))) {
        throw _error(
          'migration_conflict',
          'namespaced legacy IDs already exist',
        );
      }
      (value[field] as List).addAll(rows);
    }
    for (final match in legacy.matches) {
      _derivedJokbo(value, match);
    }
    value['legacy_v1'] = {
      'version': 1,
      'source_revision': expectedSourceRevision,
      'source_fingerprint': expectedFingerprint,
      'match_count': legacy.matches.length,
      'jokbo_count': legacy.jokbo.length,
    };
    value['revision'] = (value['revision'] as int) + 1;
    final response = {
      'revision': value['revision'],
      'imported_matches': legacy.matches.length,
      'imported_jokbo': legacy.jokbo.length,
      'v1_writes_disabled': true,
    };
    cache[idempotencyKey] = {'fingerprint': fingerprint, 'response': response};
    _values[profileId] = value;
    return TacticalLegacyCommitResult.fromWire(_copy(response));
  }
}
