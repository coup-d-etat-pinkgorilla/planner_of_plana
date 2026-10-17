// FE9-b1: 전술 v2 read DTO 확장(G-pvp §7.1 "버림" 목록), 좁은 읽기 capability(`TacticalEvidenceReadService`),
// Mock 읽기(통계 · 추이 · 추천)가 같은 strict validator를 통과하는지, design-review 전술 seed.
import 'dart:math' as math;

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_design_review_scenario.dart';
import 'package:ba_planner_v7/services/mock_tactical_v2_reads.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = '000000000000000000000001';
const _stamp = '2026-10-13T12:10:00+00:00';

Map<String, dynamic> _slot(int position, String? id, {String? state}) => {
  'version': 2,
  'position': position,
  'student_id': id,
  'state': state ?? (id == null ? 'unknown' : 'manual'),
  'source': 'manual',
  'confidence': null,
  'review_status': 'confirmed',
  'wildcard': false,
};

Map<String, dynamic> _deckWire(
  List<String?> strikers,
  List<String?> specials,
) => {
  'version': 2,
  'strikers': [for (final (i, id) in strikers.indexed) _slot(i, id)],
  'specials': [for (final (i, id) in specials.indexed) _slot(i, id)],
};

TacticalDeckV2 _deck(List<String?> strikers, List<String?> specials) =>
    TacticalDeckV2.fromWire(_deckWire(strikers, specials));

final _defense = _deck(['hina', 'iori', 'aru', 'haruka'], ['hibiki', 'chise']);
final _attackX = _deck(
  ['hoshino', 'izuna', 'mika', 'kayoko'],
  ['ayane', 'chise'],
);
final _attackY = _deck(
  ['haruna', 'mutsuki', 'hoshino', 'izuna'],
  ['ayane', null],
);
final _attackZ = _deck(['aru', 'hina', 'iori', 'mika'], ['serina', 'hibiki']);

TacticalMatchInputV2 _match(
  String id, {
  required String opponent,
  required TacticalDeckV2 attack,
  String result = 'win',
  String kind = 'attack',
  String occurredAt = '2026-10-04T21:10:00+09:00',
}) => TacticalMatchInputV2(
  id: id,
  kind: kind,
  occurredAt: occurredAt,
  occurredPrecision: 'instant',
  season: '10',
  opponentIdentityId: opponent,
  opponentDisplayName: 'name-$opponent',
  result: result,
  attackDeck: attack,
  defenseDeck: _defense,
  notes: '',
  attemptCount: 1,
);

TacticalEvidenceState _emptyState() => TacticalEvidenceState.fromWire({
  'version': 2,
  'profile_id': _profile,
  'revision': 0,
  'matches': const <Object>[],
  'jokbo': const <Object>[],
  'opponents': const <Object>[],
  'snapshots': const <Object>[],
  'lobby_scans': const <Object>[],
  'lobby_candidates': const <Object>[],
  'predictions': const <Object>[],
  'import_batches': const <Object>[],
});

Map<String, dynamic> _response(String method, Map<String, dynamic> payload) => {
  'protocol': 1,
  'id': 'mock',
  'type': 'response',
  'method': method,
  'payload': payload,
};

Map<String, dynamic> _signatureWire([Map<String, dynamic> extra = const {}]) =>
    {
      'public_signature': 'hina|hibiki|?',
      'exposure_count': 3,
      'opponent_count': 2,
      'selected_count': 1,
      'linked_match_count': 1,
      'wins': 1,
      'losses': 0,
      'observed_win_rate': 1.0,
      'wilson95_low': 0.2065,
      'wilson95_high': 1.0,
      'source_counts': {'lobby_scan': 3, 'manual': 1},
      'attack_decks': [
        {
          'signature': 'hoshino,izuna,mika,kayoko|ayane,chise',
          ...mockTacticalObservedResult(1, 1, 0),
        },
      ],
      'attack_deck_total': 1,
      'full_defenses': [
        {'signature': 'hina,iori,aru,haruka|hibiki,chise', 'count': 1},
      ],
      'full_defense_total': 1,
      ...extra,
    };

Map<String, dynamic> _opponentRow([Map<String, dynamic> extra = const {}]) => {
  'opponent_identity_id': 'rival-1',
  'display_name': 'Rival',
  'exposure_count': 1,
  'selected_count': 1,
  'match_count': 2,
  'attack_results': mockTacticalObservedResult(1, 1, 0),
  'defense_results': mockTacticalObservedResult(1, 0, 1),
  'latest_public': {
    'public_signature': 'hina|hibiki|?',
    'observed_at': _stamp,
    'snapshot_id': 'snap-public',
  },
  'latest_full': null,
  ...extra,
};

Map<String, dynamic> _statsWire({
  List<Map<String, dynamic>>? signatures,
  List<Map<String, dynamic>>? opponents,
}) {
  return {
    ...mockTacticalStatisticsWire(_emptyState(), const TacticalStatsFilters()),
    'public_signatures': signatures ?? [_signatureWire()],
    'public_signature_total': 1,
    'opponents': opponents ?? [_opponentRow()],
    'opponent_total': 1,
  };
}

Map<String, dynamic> _freshness([Map<String, dynamic> extra = const {}]) => {
  'opponent_identity_id': 'rival-1',
  'public_signature': 'hina|hibiki|?',
  'attack_signature': 'hoshino,izuna,mika,kayoko|ayane,chise',
  'is_current_public_signature': true,
  'last_battle_at': _stamp,
  'last_success_at': null,
  'last_failure_at': _stamp,
  'latest_public_observed_at': _stamp,
  'latest_public_change_at': null,
  'verified_after_latest_public': true,
  'verified_after_latest_change': null,
  'age_hours': 2.0,
  'freshness_weight': 0.9,
  'stale': false,
  ...extra,
};

Map<String, dynamic> _scenario() => {
  'defense_signature': 'hina,iori,aru,haruka|hibiki,chise',
  'evidence_weight': 1.0,
  'evidence_weight_share': 1.0,
  'snapshot_count': 1,
  'target_opponent_snapshot_count': 1,
  'target_opponent_evidence_share': 1.0,
  'distinct_opponent_count': 1,
  'match_count': 1,
  'last_confirmed_at': _stamp,
  'supporting_snapshot_ids': ['snap-1'],
  'source_counts': {'manual': 1},
  'deck': _defense.toWire(),
};

Map<String, dynamic> _recommendation([Map<String, dynamic> extra = const {}]) =>
    {
      'attack_signature': 'hoshino,izuna,mika,kayoko|ayane,chise',
      'score': 0.3,
      'score_components': {'observed_outcome': 0.2},
      'observed_match_count': 2,
      'wins': 1,
      'losses': 1,
      'observed_win_rate': 0.5,
      'wilson95_low': 0.09,
      'evidence_scope': {
        'exact_defense_count': 2,
        'same_opponent_count': 2,
        'same_public_signature_count': 0,
      },
      'source_counts': {'manual': 2},
      'last_observed_at': _stamp,
      'required_student_ids': ['ayane', 'chise'],
      'missing_student_ids': <String>[],
      'all_known_students_owned': true,
      'deck': _attackX.toWire(),
      ...extra,
    };

Map<String, dynamic> _recommendWire([Map<String, dynamic> extra = const {}]) {
  final base = mockTacticalRecommendationsWire(
    _emptyState(),
    _recommendFilters(),
  );
  return {
    ...base,
    'availability': {'status': 'available', 'reason': null},
    'selected_stage': 1,
    'evidence_summary': {
      'included_snapshot_count': 3,
      'distinct_opponent_count': 2,
      'excluded_undated_snapshot_count': 1,
    },
    'scenarios': [_scenario()],
    'scenario_total': 1,
    'hidden_slots': [
      {
        'position': 'striker:2',
        'candidates': [
          {
            'value': 'aru',
            'evidence_weight_share': 0.75,
            'supporting_snapshot_count': 3,
          },
          {
            'value': '?',
            'evidence_weight_share': 0.25,
            'supporting_snapshot_count': 1,
          },
        ],
      },
    ],
    'ambiguity': {
      'grade': 'low',
      'variant_defense_possible': true,
      'top_evidence_weight_share': 0.75,
      'public_known_slot_count': 4,
    },
    'recommendations': [_recommendation()],
    'recommendation_total': 1,
    ...extra,
  };
}

TacticalRecommendationFilters _recommendFilters({
  String opponent = 'rival-1',
  int topK = 5,
  List<String> owned = const [
    'hoshino',
    'izuna',
    'mika',
    'kayoko',
    'ayane',
    'chise',
  ],
}) => TacticalRecommendationFilters(
  season: '10',
  opponentIdentityId: opponent,
  publicSignature: 'hina|hibiki|?',
  asOf: '2026-10-05T12:00:00+09:00',
  topK: topK,
  ownedStudentIds: owned,
);

bool _valid(String method, Map<String, dynamic> payload) =>
    isValidTacticalV2ProtocolMessage(_response(method, payload));

/// 백엔드 `_result`의 Wilson 식을 테스트에서 따로 계산한다.
(double, double) _wilson(int wins, int losses) {
  const z = 1.959963984540054;
  final n = wins + losses;
  final p = wins / n;
  final d = 1 + z * z / n;
  final c = (p + z * z / (2 * n)) / d;
  final s = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d;
  return (math.max(0, c - s), math.min(1, c + s));
}

void main() {
  group('read DTO extension', () {
    test(
      'snapshot, identity and jokbo keep dates, notes, counts and provenance',
      () {
        final snapshot = TacticalDefenseSnapshot.fromWire({
          'version': 2,
          'snapshot_id': 'snap-1',
          'opponent_identity_id': 'rival-1',
          'occurred_at': '2026-10-04T12:10:00+00:00',
          'observed_at': null,
          'imported_at': _stamp,
          'source': 'manual',
          'source_record_id': 'manual:m1',
          'confidence': null,
          'review_status': 'confirmed',
          'season': '10',
          'deck': _defense.toWire(),
          'match_id': 'm1',
        });
        expect(snapshot.occurredAt, '2026-10-04T12:10:00+00:00');
        expect(snapshot.observedAt, isNull);
        expect(snapshot.importedAt, _stamp);
        expect((snapshot.source, snapshot.season), ('manual', '10'));
        expect(snapshot.reviewStatus, 'confirmed');

        final identity = TacticalOpponentIdentity.fromWire({
          'version': 2,
          'identity_id': 'rival-1',
          'current_display_name': 'Rival',
          'aliases': ['Rival'],
          'first_observed_at': null,
          'last_observed_at': _stamp,
          'review_status': 'review_required',
          'name_template_ids': const <String>[],
        });
        expect(identity.firstObservedAt, isNull);
        expect(identity.lastObservedAt, _stamp);
        expect(identity.reviewStatus, 'review_required');

        final jokboWire = {
          'version': 2,
          'jokbo_id': 'v6-jokbo-1',
          'defense_deck': _defense.toWire(),
          'attack_deck': _attackX.toWire(),
          'wins': 7,
          'losses': 2,
          'notes': 'v6 메모',
          'created_at': _stamp,
          'imported_at': _stamp,
          'source': 'v6_import',
          'source_label': 'v6 sqlite',
          'import_batch_id': 'batch-1',
          'source_record_id': 'v6:jokbo:1',
          'confidence': 0.9,
          'review_status': 'confirmed',
        };
        final jokbo = TacticalJokboV2.fromWire(jokboWire);
        expect((jokbo.wins, jokbo.losses, jokbo.notes), (7, 2, 'v6 메모'));
        expect(jokbo.name, isNull);
        expect(
          (jokbo.source, jokbo.sourceLabel, jokbo.importBatchId),
          ('v6_import', 'v6 sqlite', 'batch-1'),
        );
        expect((jokbo.sourceRecordId, jokbo.confidence), ('v6:jokbo:1', 0.9));
        expect((jokbo.createdAt, jokbo.importedAt), (_stamp, _stamp));
        // 저장할 때 notes를 그대로 되보낼 수 있다(입력 6키).
        final input = TacticalJokboInputV2(
          id: jokbo.id,
          name: '족보 A',
          attackDeck: jokbo.attackDeck,
          defenseDeck: jokbo.defenseDeck,
          notes: jokbo.notes,
        );
        expect(input.toWire()['notes'], 'v6 메모');
        for (final bad in [
          {...jokboWire, 'wins': -1},
          {...jokboWire, 'notes': null},
          {...jokboWire, 'created_at': null},
          {...jokboWire, 'source': 'unknown_source'},
        ]) {
          expect(() => TacticalJokboV2.fromWire(bad), throwsFormatException);
        }
      },
    );

    test(
      'statistics keep signature decks, source counts and opponent rows',
      () {
        final wire = _statsWire();
        expect(_valid('tactical.v2.stats.query', wire), isTrue);
        final result = TacticalStatisticsResult.fromWire(wire);
        final signature = result.publicSignatures.single;
        expect(signature.sourceCounts, {'lobby_scan': 3, 'manual': 1});
        expect(signature.attackDecks.single.result.wins, 1);
        expect(signature.attackDecks.single.result.observedWinRate, 1.0);
        expect(signature.attackDeckTotal, 1);
        expect(signature.fullDefenses.single.count, 1);
        expect(signature.fullDefenseTotal, 1);
        final opponent = result.opponents.single;
        expect(opponent.displayName, 'Rival');
        expect(opponent.attackResults.wins, 1);
        expect(opponent.defenseResults.losses, 1);
        expect(opponent.latestPublic!.signature, 'hina|hibiki|?');
        expect(opponent.latestPublic!.snapshotId, 'snap-public');
        expect(opponent.latestFull, isNull);

        for (final bad in [
          _statsWire(
            signatures: [
              _signatureWire({
                'source_counts': {'ocr': 1},
              }),
            ],
          ),
          _statsWire(
            signatures: [
              _signatureWire({
                'attack_decks': [
                  {'signature': 'x', 'count': 1},
                ],
              }),
            ],
          ),
          _statsWire(
            signatures: [
              _signatureWire({
                'full_defenses': [
                  {'signature': 'x', 'count': -1},
                ],
              }),
            ],
          ),
          _statsWire(
            opponents: [
              _opponentRow({'extra': 1}),
            ],
          ),
          _statsWire(
            opponents: [
              _opponentRow({'latest_full': 'x'}),
            ],
          ),
          _statsWire(
            opponents: [
              _opponentRow({
                'attack_results': {
                  ...mockTacticalObservedResult(1, 1, 0),
                  'x': 1,
                },
              }),
            ],
          ),
        ]) {
          expect(_valid('tactical.v2.stats.query', bad), isFalse);
        }
      },
    );

    test(
      'freshness keeps last success and the nullable change verification',
      () {
        final unknown = TacticalFreshnessEvidence.fromWire(_freshness());
        expect(unknown.lastSuccessAt, isNull);
        expect(unknown.verifiedAfterLatestChange, isNull);
        final known = TacticalFreshnessEvidence.fromWire(
          _freshness({
            'last_success_at': _stamp,
            'verified_after_latest_change': false,
          }),
        );
        expect(known.lastSuccessAt, _stamp);
        expect(known.verifiedAfterLatestChange, isFalse);
        for (final bad in [
          _freshness({'verified_after_latest_change': 'yes'}),
          _freshness({'last_success_at': 'yesterday'}),
          _freshness({'last_battle_at': 'never'}),
        ]) {
          expect(
            () => TacticalFreshnessEvidence.fromWire(bad),
            throwsFormatException,
          );
        }
      },
    );

    test(
      'recommendation keeps decks, counts, hidden slots, ambiguity and summary',
      () {
        final wire = _recommendWire();
        expect(_valid('tactical.v2.recommend.query', wire), isTrue);
        final result = TacticalRecommendationResult.fromWire(wire);
        expect(
          mockTacticalDeckSignature(result.scenarios.single.deck),
          'hina,iori,aru,haruka|hibiki,chise',
        );
        final recommendation = result.recommendations.single;
        expect(
          mockTacticalDeckSignature(recommendation.deck),
          recommendation.attackSignature,
        );
        expect((recommendation.wins, recommendation.losses), (1, 1));
        expect(recommendation.lastObservedAt, _stamp);
        final hidden = result.hiddenSlots.single;
        expect(hidden.position, 'striker:2');
        expect(hidden.candidates.map((item) => item.value), ['aru', '?']);
        expect(hidden.candidates.first.evidenceWeightShare, 0.75);
        expect(hidden.candidates.first.supportingSnapshotCount, 3);
        expect(result.ambiguity.grade, 'low');
        expect(result.ambiguity.variantDefensePossible, isTrue);
        expect(result.ambiguity.topEvidenceWeightShare, 0.75);
        expect(result.ambiguity.publicKnownSlotCount, 4);
        expect(result.evidenceSummary.includedSnapshotCount, 3);
        expect(result.evidenceSummary.distinctOpponentCount, 2);
        expect(result.evidenceSummary.excludedUndatedSnapshotCount, 1);

        for (final bad in [
          _recommendWire({
            'hidden_slots': [
              {'position': 'striker:4', 'candidates': const <Object>[]},
            ],
          }),
          _recommendWire({
            'ambiguity': {
              'grade': 'certain',
              'variant_defense_possible': false,
              'top_evidence_weight_share': null,
              'public_known_slot_count': 0,
            },
          }),
          _recommendWire({
            'evidence_summary': {
              'included_snapshot_count': 1,
              'distinct_opponent_count': 1,
            },
          }),
          _recommendWire({
            'recommendations': [
              _recommendation({'last_observed_at': null}),
            ],
          }),
          _recommendWire({
            'recommendations': [
              _recommendation({'wins': -1}),
            ],
          }),
        ]) {
          expect(_valid('tactical.v2.recommend.query', bad), isFalse);
        }
      },
    );

    test('untyped maps stay maps', () {
      final trends = TacticalTrendsResult.fromWire(
        mockTacticalTrendsWire(
          _emptyState(),
          const TacticalTrendFilters(asOf: '2026-10-05T12:00:00+09:00'),
        ),
      );
      expect(trends.changes['public_signature_total'], 0);
      expect(trends.exposure['retention'], isA<Map<dynamic, dynamic>>());
    });
  });

  group('read capability', () {
    test(
      'Process declares and Mock implements TacticalEvidenceReadService',
      () {
        // 컴파일 시점 검사: ProcessAppService는 선언만 더했다.
        TacticalEvidenceReadService process(ProcessAppService service) =>
            service;
        expect(process, isNotNull);
        expect(MockAppService(), isA<TacticalEvidenceReadService>());
        expect(MockAppService(), isNot(isA<TacticalEvidenceService>()));
      },
    );

    test(
      'empty Mock answers strict empty statistics, trends and recommendations',
      () async {
        final service = MockAppService();
        final state = await service.loadTacticalEvidenceState(_profile);
        expect(state.revision, 0);
        expect(state.matches, isEmpty);
        expect(state.jokbo, isEmpty);
        expect(
          _valid(
            'tactical.v2.stats.query',
            mockTacticalStatisticsWire(state, const TacticalStatsFilters()),
          ),
          isTrue,
        );
        expect(
          _valid(
            'tactical.v2.trends.query',
            mockTacticalTrendsWire(
              state,
              const TacticalTrendFilters(asOf: '2026-10-05T12:00:00+09:00'),
            ),
          ),
          isTrue,
        );
        expect(
          _valid(
            'tactical.v2.recommend.query',
            mockTacticalRecommendationsWire(state, _recommendFilters()),
          ),
          isTrue,
        );
        final stats = await service.queryTacticalStatistics(
          _profile,
          const TacticalStatsFilters(),
        );
        expect(stats.population.matchCount, 0);
        expect(stats.quality['date_coverage'], isNull);
        final trends = await service.queryTacticalTrends(
          _profile,
          const TacticalTrendFilters(asOf: '2026-10-05T12:00:00+09:00'),
        );
        expect(trends.freshness, isEmpty);
        expect(trends.funnel.observedWinRate, isNull);
        final recommendation = await service.queryTacticalRecommendations(
          _profile,
          _recommendFilters(),
        );
        expect(recommendation.available, isFalse);
        expect(
          recommendation.unavailableReason,
          'no_observed_full_defense_evidence',
        );
        expect(recommendation.selectedStage, isNull);
        expect(recommendation.ambiguity.grade, 'unavailable');
        expect(recommendation.confidenceGrade, 'unavailable');
      },
    );

    test('Mock requests are checked like Process requests', () async {
      final service = MockAppService();
      await expectLater(
        service.queryTacticalRecommendations(
          _profile,
          _recommendFilters(topK: 11),
        ),
        throwsFormatException,
      );
      await expectLater(
        service.queryTacticalStatistics(
          _profile,
          const TacticalStatsFilters(limit: 0),
        ),
        throwsFormatException,
      );
      await expectLater(
        service.queryTacticalStatistics(
          'not-a-profile',
          const TacticalStatsFilters(),
        ),
        throwsFormatException,
      );
    });

    test(
      'Mock statistics: observed rate, Wilson interval and opponent rows',
      () async {
        final service = MockAppService();
        final inputs = [
          _match('m1', opponent: 'rival-1', attack: _attackX),
          _match(
            'm2',
            opponent: 'rival-1',
            attack: _attackX,
            result: 'loss',
            occurredAt: '2026-10-03T20:00:00+09:00',
          ),
          _match('m3', opponent: 'rival-2', attack: _attackY, kind: 'defense'),
        ];
        for (final (revision, input) in inputs.indexed) {
          await service.upsertTacticalMatchV2(
            profileId: _profile,
            match: input,
            expectedRevision: revision,
            idempotencyKey: 'k-${input.id}',
          );
        }
        final state = await service.loadTacticalEvidenceState(_profile);
        final wire = mockTacticalStatisticsWire(
          state,
          const TacticalStatsFilters(),
        );
        expect(_valid('tactical.v2.stats.query', wire), isTrue);
        final stats = await service.queryTacticalStatistics(
          _profile,
          const TacticalStatsFilters(),
        );
        expect(stats.population.matchCount, 3);
        expect(stats.population.attackMatchCount, 2);
        expect(stats.population.defenseMatchCount, 1);
        expect(stats.population.opponentCount, 2);
        expect(stats.publicSignatures, isEmpty);
        final rival = stats.opponents.firstWhere(
          (item) => item.opponentIdentityId == 'rival-1',
        );
        expect(rival.displayName, 'name-rival-1');
        expect(rival.matchCount, 2);
        expect(rival.attackResults.observedWinRate, 0.5);
        final (low, high) = _wilson(1, 1);
        expect(rival.attackResults.wilson95Low, closeTo(low, 1e-12));
        expect(rival.attackResults.wilson95High, closeTo(high, 1e-12));
        expect(rival.attackResults.wilson95Low, closeTo(0.0945, 1e-4));
        expect(rival.defenseResults.observedWinRate, isNull);
        // 확인된 완전 방어 덱이 있는 공격 기록이 최근 완전 방어로 보인다.
        expect(
          rival.latestFull!.signature,
          mockTacticalDeckSignature(_defense),
        );
        final exact = stats.attackPatterns['exact'] as List;
        expect((exact.single as Map)['count'], 2);
        // 기간 필터: 10-04 이후만.
        final recent = await service.queryTacticalStatistics(
          _profile,
          const TacticalStatsFilters(dateFrom: '2026-10-04T00:00:00+09:00'),
        );
        expect(recent.population.matchCount, 2);
        // 공개 시그니처 필터: Mock에는 로비 연결이 없어 0건.
        final bySignature = await service.queryTacticalStatistics(
          _profile,
          const TacticalStatsFilters(publicSignature: 'hina|hibiki|?'),
        );
        expect(bySignature.population.matchCount, 0);
      },
    );

    test(
      'Mock recommendations: winning attack decks against the same defense, by wins',
      () async {
        final service = MockAppService();
        final inputs = [
          _match('x1', opponent: 'rival-1', attack: _attackX),
          _match(
            'x2',
            opponent: 'rival-1',
            attack: _attackX,
            occurredAt: '2026-10-03T10:00:00+09:00',
          ),
          _match(
            'x3',
            opponent: 'rival-1',
            attack: _attackX,
            result: 'loss',
            occurredAt: '2026-10-02T10:00:00+09:00',
          ),
          _match(
            'y1',
            opponent: 'rival-1',
            attack: _attackY,
            occurredAt: '2026-10-01T10:00:00+09:00',
          ),
          _match('z1', opponent: 'rival-1', attack: _attackZ, result: 'loss'),
          // as_of 뒤의 기록은 근거가 아니다.
          _match(
            'late',
            opponent: 'rival-1',
            attack: _attackZ,
            occurredAt: '2026-10-06T10:00:00+09:00',
          ),
        ];
        for (final (revision, input) in inputs.indexed) {
          await service.upsertTacticalMatchV2(
            profileId: _profile,
            match: input,
            expectedRevision: revision,
            idempotencyKey: 'k-${input.id}',
          );
        }
        final state = await service.loadTacticalEvidenceState(_profile);
        final wire = mockTacticalRecommendationsWire(
          state,
          _recommendFilters(),
        );
        expect(_valid('tactical.v2.recommend.query', wire), isTrue);
        final result = await service.queryTacticalRecommendations(
          _profile,
          _recommendFilters(),
        );
        expect(result.available, isTrue);
        expect(result.selectedStage, 3);
        expect(result.scenarios.single.snapshotCount, 5);
        expect(result.scenarios.single.deck.strikers.first.studentId, 'hina');
        expect(result.evidenceSummary.includedSnapshotCount, 5);
        expect(result.ambiguity.grade, 'low');
        expect(result.confidenceGrade, 'high');
        expect(result.calibrationGatePassed, isFalse);
        expect(result.hiddenSlots, isEmpty);
        // X(2승 1패) → Y(1승 0패). Z는 이긴 적이 없어 빠진다.
        expect(result.recommendations.map((item) => item.attackSignature), [
          mockTacticalDeckSignature(_attackX),
          mockTacticalDeckSignature(_attackY),
        ]);
        final x = result.recommendations.first;
        expect((x.wins, x.losses, x.observedMatchCount), (2, 1, 3));
        expect(x.lastObservedAt, startsWith('2026-10-04'));
        expect(x.missingStudentIds, isEmpty);
        expect(x.allKnownStudentsOwned, isTrue);
        expect(x.score, closeTo(_wilson(2, 1).$1, 1e-12));
        final y = result.recommendations.last;
        expect(y.missingStudentIds, ['haruna', 'mutsuki']);
        expect(y.allKnownStudentsOwned, isFalse);
        // 다른 상대는 근거가 없다.
        final other = await service.queryTacticalRecommendations(
          _profile,
          _recommendFilters(opponent: 'rival-9'),
        );
        expect(other.available, isFalse);
        expect(other.recommendations, isEmpty);
        // top_k.
        final top1 = await service.queryTacticalRecommendations(
          _profile,
          _recommendFilters(topK: 1),
        );
        expect(top1.recommendations, hasLength(1));
      },
    );
  });

  group('design-review tactical seed', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('default Mock keeps an empty v2 state', () async {
      final service = createMockAppService();
      final profiles = await service.listProfiles();
      for (final profile in profiles) {
        final state = await service.loadTacticalEvidenceState(profile.id);
        expect(state.revision, 0);
        expect(state.matches, isEmpty);
        expect(state.jokbo, isEmpty);
      }
    });

    test(
      'design-review has 7 records, 2 derived jokbo and a finished migration',
      () async {
        final service = MockDesignReviewScenario();
        addTearDown(service.dispose);
        final state = await service.loadTacticalEvidenceState(
          designReviewProfileId,
        );
        // FE9-b2: 시도 모름 방어 · 상대 없는 방어(FD-176)가 더해졌다. tidy3: 30일 밖 방어 기록(8/28, 날짜만)이 더해졌다.
        expect(state.revision, 7);
        expect(state.matches, hasLength(7));
        expect(state.matches.map((item) => item.occurredPrecision).toSet(), {
          'instant',
          'date',
          'unknown',
        });
        expect(state.matches.map((item) => item.attemptCount).toSet(), {
          1,
          2,
          3,
          null,
        });
        expect(state.jokbo, hasLength(2));
        expect(
          state.jokbo.every((item) => item.id.startsWith('lineage-')),
          isTrue,
        );
        final preview = await service.previewTacticalLegacyMigration(
          designReviewProfileId,
        );
        expect(preview.v1WritesDisabled, isTrue);
        expect((preview.matchCount, preview.jokboCount), (0, 0));
        final stats = await service.queryTacticalStatistics(
          designReviewProfileId,
          const TacticalStatsFilters(),
        );
        // 상대 없는 방어 기록은 전체 수에는 들고 상대별 행에서는 빠진다.
        expect(stats.population.matchCount, 7);
        expect(stats.opponents, hasLength(2));
        final recommendation = await service.queryTacticalRecommendations(
          designReviewProfileId,
          _recommendFilters(opponent: 'dr-opponent-gehenna'),
        );
        expect(recommendation.available, isTrue);
        expect(recommendation.recommendations, hasLength(1));
      },
    );
  });
}
