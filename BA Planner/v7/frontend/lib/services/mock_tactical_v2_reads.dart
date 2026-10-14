// FE9-b1 Mock: 전술 v2 읽기(통계 · 추이 · 추천). 각 함수는 응답 wire를 만들고, Mock 서비스는 Process와 같은 strict
// `fromWire`로 읽는다(요청도 `checkedTacticalV2Request`로 먼저 검사한다).
//
// 백엔드와 같은 계산:
// - 관측 승률 = 승 / (승 + 패), 95% Wilson 구간(z = 1.959963984540054), 표본 0이면 비율 · 구간 null
//   (docs/migration/p10-deterministic-tactical-statistics/artifacts/statistics-semantics.md, backend
//   `core/tactical_stats_v2.py` `_result`). 추천의 Wilson 하한도 같은 식이다(`core/tactical_recommend_v2.py` `_wilson_low`).
// - 덱 시그니처 = 스트라이커 4칸을 `,`로 이은 뒤 `|` + 스페셜 2칸. 칸 값은 학생 ID, 와일드카드 `*`, 빈칸 `empty`, 모름 `?`.
// - 기간 필터는 `occurred_at`(없으면 `observed_at`)으로 거르고, 기간을 주면 시각 없는 기록은 빠진다. 예측(`prediction`)
//   출처 기록은 관측에서 뺀다.
// Mock 차이(백엔드보다 단순하다. status-lane-b "FE9-b1 종료 기록 · Mock 차이"):
// - Mock에는 로비 스캔 · 후보가 없다. 통계의 노출 · 선택 · 연결 수는 0, 공개 시그니처 목록은 빈 목록이고, 공개 시그니처
//   필터를 주면 기록이 0건이다. 추이는 빈 구조(로비 관측이 없는 백엔드 응답과 같은 모양), 추천의 숨은 칸은 빈 목록이다.
// - 공격 패턴은 `exact` · `strikers` · `specials`만 세고 `cores` · `one_slot_variants`는 빈 목록이다.
// - 추천: 대상 상대의 확인된 완전 방어 스냅샷(시각이 있고 `as_of` 이전)만 방어 시나리오 근거로 쓴다(백엔드 3단계
//   `same_opponent_recent_full`에 해당, 시간 감쇠 없음 — 근거 가중치 = 스냅샷 수). 공격 추천은 같은 상대(또는 같은
//   방어 덱)와 싸운 공격 기록 중 한 번이라도 이긴 덱을 승 많은 순(같으면 패 적은 순, 시그니처 순)으로 준다.
//   점수 = Wilson 하한(표본 0이면 0), 점수 구성은 `observed_outcome` 하나. 검증(backtest)은 0건 · null, 보정 gate 미통과.
import 'dart:math' as math;

import 'tactical_v2_service.dart';

const _z = 1.959963984540054;

/// 관측 결과 묶음(백엔드 `_result`와 같은 식).
Map<String, dynamic> mockTacticalObservedResult(
  int count,
  int wins,
  int losses,
) {
  final observed = wins + losses;
  if (observed == 0) {
    return {
      'count': count,
      'wins': wins,
      'losses': losses,
      'observed_win_rate': null,
      'wilson95_low': null,
      'wilson95_high': null,
    };
  }
  final rate = wins / observed;
  final denominator = 1 + _z * _z / observed;
  final center = (rate + _z * _z / (2 * observed)) / denominator;
  final spread =
      _z *
      math.sqrt(
        rate * (1 - rate) / observed + _z * _z / (4 * observed * observed),
      ) /
      denominator;
  return {
    'count': count,
    'wins': wins,
    'losses': losses,
    'observed_win_rate': rate,
    'wilson95_low': math.max(0.0, center - spread),
    'wilson95_high': math.min(1.0, center + spread),
  };
}

String _slotKey(TacticalSlotObservation slot) =>
    slot.studentId ??
    (slot.wildcard
        ? '*'
        : slot.state == 'empty'
        ? 'empty'
        : '?');

/// 덱 시그니처(백엔드 `deck_signature`).
String mockTacticalDeckSignature(TacticalDeckV2 deck) =>
    '${deck.strikers.map(_slotKey).join(',')}|${deck.specials.map(_slotKey).join(',')}';

DateTime? _time(String? value) => value == null ? null : DateTime.parse(value);

String? _recordTime(TacticalMatchV2 match) =>
    match.occurredAt ?? match.observedAt;

String? _snapshotTime(TacticalDefenseSnapshot snapshot) =>
    snapshot.occurredAt ?? snapshot.observedAt;

bool _inPeriod(String? value, String? from, String? to) {
  if (from == null && to == null) return true;
  final parsed = _time(value);
  if (parsed == null) return false;
  return (from == null || !parsed.isBefore(DateTime.parse(from))) &&
      (to == null || !parsed.isAfter(DateTime.parse(to)));
}

Map<String, int> _sourceCounts(Iterable<String> sources) {
  final counts = <String, int>{};
  for (final source in sources) {
    counts[source] = (counts[source] ?? 0) + 1;
  }
  return Map.fromEntries(
    counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

List<Map<String, dynamic>> _ranked(
  Map<String, List<int>> values,
  String patternType,
  int limit,
) {
  final rows = [
    for (final MapEntry(:key, :value) in values.entries)
      {
        'pattern_type': patternType,
        'key': key,
        ...mockTacticalObservedResult(value[0], value[1], value[2]),
      },
  ];
  rows.sort((a, b) {
    final count = (b['count'] as int).compareTo(a['count'] as int);
    return count != 0
        ? count
        : (a['key'] as String).compareTo(b['key'] as String);
  });
  return rows.take(limit).toList();
}

/// Mock `tactical.v2.stats.query` 응답 payload.
Map<String, dynamic> mockTacticalStatisticsWire(
  TacticalEvidenceState state,
  TacticalStatsFilters filters,
) {
  final limit = filters.limit;
  final matches = [
    for (final item in state.matches)
      if ((filters.season == null || item.season == filters.season) &&
          item.source != 'prediction' &&
          (filters.sources.isEmpty || filters.sources.contains(item.source)) &&
          (filters.opponentIdentityId == null ||
              item.opponentIdentityId == filters.opponentIdentityId) &&
          _inPeriod(_recordTime(item), filters.dateFrom, filters.dateTo) &&
          // Mock에는 로비 후보가 없어 공개 시그니처에 연결된 기록이 없다.
          filters.publicSignature == null)
        item,
  ];
  final matchIds = {for (final item in matches) item.id};
  final fullSnapshots = [
    for (final item in state.snapshots)
      if (item.source != 'lobby_scan' &&
          matchIds.contains(item.matchId) &&
          (filters.sources.isEmpty || filters.sources.contains(item.source)))
        item,
  ];
  final names = {
    for (final item in state.opponents) item.id: item.currentDisplayName,
  };
  final attack = [
    for (final item in matches)
      if (item.kind == 'attack') item,
  ];
  final defense = [
    for (final item in matches)
      if (item.kind == 'defense') item,
  ];

  Map<String, dynamic> results(List<TacticalMatchV2> rows) =>
      mockTacticalObservedResult(
        rows.length,
        rows.where((item) => item.result == 'win').length,
        rows.where((item) => item.result == 'loss').length,
      );

  final opponentIds = {for (final item in matches) item.opponentIdentityId};
  final opponentRows = <Map<String, dynamic>>[];
  for (final id in opponentIds) {
    final own = [
      for (final item in matches)
        if (item.opponentIdentityId == id) item,
    ];
    TacticalDefenseSnapshot? complete;
    for (final item in fullSnapshots) {
      final time = _time(_snapshotTime(item));
      if (item.opponentIdentityId != id || time == null) continue;
      final best = complete;
      if (best == null || time.isAfter(_time(_snapshotTime(best))!)) {
        complete = item;
      }
    }
    final latest = complete;
    opponentRows.add({
      'opponent_identity_id': id,
      'display_name': names[id] ?? '',
      'exposure_count': 0,
      'selected_count': 0,
      'match_count': own.length,
      'attack_results': results([
        for (final item in own)
          if (item.kind == 'attack') item,
      ]),
      'defense_results': results([
        for (final item in own)
          if (item.kind == 'defense') item,
      ]),
      'latest_public': null,
      'latest_full': latest == null
          ? null
          : {
              'deck_signature': mockTacticalDeckSignature(latest.deck),
              'observed_at': _snapshotTime(latest),
              'snapshot_id': latest.id,
            },
    });
  }
  opponentRows.sort((a, b) {
    final count = (b['match_count'] as int).compareTo(a['match_count'] as int);
    return count != 0
        ? count
        : (a['opponent_identity_id'] as String).compareTo(
            b['opponent_identity_id'] as String,
          );
  });

  final exact = <String, List<int>>{};
  final strikers = <String, List<int>>{};
  final specials = <String, List<int>>{};
  for (final item in attack) {
    final signature = mockTacticalDeckSignature(item.attackDeck);
    final parts = signature.split('|');
    for (final (target, key) in [
      (exact, signature),
      (strikers, parts[0]),
      (specials, parts[1]),
    ]) {
      final bucket = target.putIfAbsent(key, () => [0, 0, 0]);
      bucket[0] += 1;
      bucket[1] += item.result == 'win' ? 1 : 0;
      bucket[2] += item.result == 'loss' ? 1 : 0;
    }
  }
  final dated = matches.where((item) => _recordTime(item) != null).length;
  final fingerprints = <String, int>{};
  for (final item in matches) {
    final key = [
      item.kind,
      item.opponentIdentityId,
      item.occurredAt,
      item.result,
      mockTacticalDeckSignature(item.attackDeck),
      mockTacticalDeckSignature(item.defenseDeck),
      item.source,
    ].join('\u0000');
    fingerprints[key] = (fingerprints[key] ?? 0) + 1;
  }
  return {
    'version': 2,
    'filters': filters.toWire(),
    'population': {
      'refresh_count': 0,
      'exposure_count': 0,
      'selected_count': 0,
      'linked_match_count': 0,
      'match_count': matches.length,
      'attack_match_count': attack.length,
      'defense_match_count': defense.length,
      'opponent_count': opponentIds.length,
    },
    'public_signatures': const <Object>[],
    'public_signature_total': 0,
    'opponents': opponentRows.take(limit).toList(),
    'opponent_total': opponentRows.length,
    'attack_patterns': {
      'exact': _ranked(exact, 'exact', limit),
      'exact_total': exact.length,
      'strikers': _ranked(strikers, 'strikers', limit),
      'strikers_total': strikers.length,
      'specials': _ranked(specials, 'specials', limit),
      'specials_total': specials.length,
      'cores': const <Object>[],
      'cores_total': 0,
      'one_slot_variants': const <Object>[],
      'one_slot_variants_total': 0,
    },
    'quality': {
      'dated_match_count': dated,
      'undated_match_count': matches.length - dated,
      'date_coverage': matches.isEmpty ? null : dated / matches.length,
      'distinct_opponent_count': opponentIds.length,
      'match_kind_counts': {'attack': attack.length, 'defense': defense.length},
      'source_counts': _sourceCounts(matches.map((item) => item.source)),
      'suspected_duplicate_count': fingerprints.values.fold<int>(
        0,
        (sum, count) => sum + (count > 1 ? count - 1 : 0),
      ),
    },
    'terminology': {
      'rate_label': 'observed_win_rate',
      'population_warning':
          'Observed attack records are not the population win rate or defense success rate.',
    },
  };
}

/// Mock `tactical.v2.trends.query` 응답 payload. Mock에는 로비 관측이 없어 노출 · 변경 · 신선도가 모두 비어 있다.
Map<String, dynamic> mockTacticalTrendsWire(
  TacticalEvidenceState state,
  TacticalTrendFilters filters,
) => {
  'version': 2,
  'filters': filters.toWire(),
  'funnel': {
    'refresh_count': 0,
    'opponent_count': 0,
    'exposures_per_refresh': null,
    'exposure_count': 0,
    'selection_count': 0,
    'selection_rate': null,
    'battle_count': 0,
    'result_count': 0,
    'wins': 0,
    'losses': 0,
    'observed_win_rate': null,
  },
  'exposure': {
    'by_opponent': const <Object>[],
    'by_public_signature': const <Object>[],
    'by_rank_difference': const <Object>[],
    'retention': {
      'eligible_transition_count': 0,
      'retained_transition_count': 0,
      'retention_rate': null,
      'by_opponent': const <Object>[],
    },
  },
  'changes': {
    'public_signature': const <Object>[],
    'public_signature_total': 0,
    'public_runs': const <Object>[],
    'public_run_total': 0,
    'public_reuse': const <Object>[],
    'public_reuse_total': 0,
    'full_defense_while_public_stable': const <Object>[],
    'full_defense_change_total': 0,
  },
  'freshness': const <Object>[],
  'freshness_total': 0,
  'terminology': {
    'exposure_rate_label': 'observed_exposure_rate',
    'selection_rate_label': 'observed_selection_rate',
    'win_rate_label': 'observed_win_rate',
    'population_warning':
        'Exposure describes choices shown to this user, not server-wide meta share.',
  },
};

const _stages = [
  'same_opponent_signature_season',
  'same_opponent_signature',
  'same_opponent_recent_full',
  'same_season_signature',
  'same_rank_condition_signature',
  'all_opponents_signature',
];

/// Mock이 쓰는 근거 단계(백엔드 3단계 `same_opponent_recent_full`).
const _mockStage = 3;

List<String> _knownStudents(TacticalDeckV2 deck) => ({
  for (final slot in [...deck.strikers, ...deck.specials]) ?slot.studentId,
}.toList()..sort());

/// Mock `tactical.v2.recommend.query` 응답 payload.
Map<String, dynamic> mockTacticalRecommendationsWire(
  TacticalEvidenceState state,
  TacticalRecommendationFilters filters,
) {
  final asOf = DateTime.parse(filters.asOf);
  final target = filters.opponentIdentityId;
  var undated = 0;
  final evidence = <TacticalDefenseSnapshot>[];
  for (final item in state.snapshots) {
    if (item.source == 'lobby_scan' ||
        item.source == 'prediction' ||
        item.reviewStatus != 'confirmed') {
      continue;
    }
    final time = _time(_snapshotTime(item));
    if (time == null) {
      undated += 1;
      continue;
    }
    if (time.isAfter(asOf) || item.opponentIdentityId != target) continue;
    evidence.add(item);
  }
  final groups = <String, List<TacticalDefenseSnapshot>>{};
  for (final item in evidence) {
    groups
        .putIfAbsent(mockTacticalDeckSignature(item.deck), () => [])
        .add(item);
  }
  final allScenarios = [
    for (final MapEntry(key: signature, value: group) in groups.entries)
      () {
        final latest = group.reduce((a, b) {
          final order = _time(
            _snapshotTime(a),
          )!.compareTo(_time(_snapshotTime(b))!);
          return order > 0 || (order == 0 && a.id.compareTo(b.id) > 0) ? a : b;
        });
        return {
          'defense_signature': signature,
          'evidence_weight': group.length.toDouble(),
          'evidence_weight_share': group.length / evidence.length,
          'snapshot_count': group.length,
          'target_opponent_snapshot_count': group.length,
          'target_opponent_evidence_share': 1.0,
          'distinct_opponent_count': 1,
          'match_count': {for (final item in group) ?item.matchId}.length,
          'last_confirmed_at': _snapshotTime(latest),
          'supporting_snapshot_ids': [for (final item in group) item.id]
            ..sort(),
          'source_counts': _sourceCounts(group.map((item) => item.source)),
          'deck': latest.deck.toWire(),
        };
      }(),
  ];
  allScenarios.sort((a, b) {
    final weight = (b['evidence_weight'] as double).compareTo(
      a['evidence_weight'] as double,
    );
    return weight != 0
        ? weight
        : (a['defense_signature'] as String).compareTo(
            b['defense_signature'] as String,
          );
  });
  final scenarios = allScenarios.take(filters.topK).toList();
  final scenarioSignatures = {
    for (final item in scenarios) item['defense_signature'],
  };
  final owned = filters.ownedStudentIds.toSet();
  final attackGroups = <String, List<TacticalMatchV2>>{};
  if (scenarios.isNotEmpty) {
    for (final match in state.matches) {
      final time = _time(_recordTime(match));
      if (match.kind != 'attack' ||
          match.source == 'prediction' ||
          time == null ||
          time.isAfter(asOf) ||
          _knownStudents(match.attackDeck).isEmpty) {
        continue;
      }
      final exact = scenarioSignatures.contains(
        mockTacticalDeckSignature(match.defenseDeck),
      );
      if (!exact && match.opponentIdentityId != target) continue;
      attackGroups
          .putIfAbsent(mockTacticalDeckSignature(match.attackDeck), () => [])
          .add(match);
    }
  }
  final recommendations = <Map<String, dynamic>>[];
  for (final MapEntry(key: signature, value: group) in attackGroups.entries) {
    final wins = group.where((item) => item.result == 'win').length;
    final losses = group.where((item) => item.result == 'loss').length;
    if (wins == 0) continue;
    final observed = mockTacticalObservedResult(group.length, wins, losses);
    final low = observed['wilson95_low'] as double?;
    final deck = group.first.attackDeck;
    final required = _knownStudents(deck);
    final latest = group
        .map((item) => _recordTime(item)!)
        .reduce((a, b) => _time(a)!.isAfter(_time(b)!) ? a : b);
    recommendations.add({
      'attack_signature': signature,
      'score': low ?? 0.0,
      'score_components': {'observed_outcome': low ?? 0.0},
      'observed_match_count': group.length,
      'wins': wins,
      'losses': losses,
      'observed_win_rate': observed['observed_win_rate'],
      'wilson95_low': low,
      'evidence_scope': {
        'exact_defense_count': group
            .where(
              (item) => scenarioSignatures.contains(
                mockTacticalDeckSignature(item.defenseDeck),
              ),
            )
            .length,
        'same_opponent_count': group
            .where((item) => item.opponentIdentityId == target)
            .length,
        'same_public_signature_count': 0,
      },
      'source_counts': _sourceCounts(group.map((item) => item.source)),
      'last_observed_at': latest,
      'required_student_ids': required,
      'missing_student_ids': [
        for (final id in required)
          if (!owned.contains(id)) id,
      ],
      'all_known_students_owned': required.every(owned.contains),
      'deck': deck.toWire(),
    });
  }
  recommendations.sort((a, b) {
    final wins = (b['wins'] as int).compareTo(a['wins'] as int);
    if (wins != 0) return wins;
    final losses = (a['losses'] as int).compareTo(b['losses'] as int);
    if (losses != 0) return losses;
    return (a['attack_signature'] as String).compareTo(
      b['attack_signature'] as String,
    );
  });
  final top = recommendations.take(filters.topK).toList();
  final available = scenarios.isNotEmpty;
  final topShare = available
      ? scenarios.first['evidence_weight_share'] as double
      : null;
  final confidence = topShare == null
      ? 'unavailable'
      : evidence.length >= 5 && topShare >= 0.7
      ? 'high'
      : evidence.length >= 2
      ? 'medium'
      : 'low';
  final ambiguity = topShare == null
      ? 'unavailable'
      : topShare >= 0.75
      ? 'low'
      : topShare >= 0.5
      ? 'medium'
      : 'high';
  return {
    'version': 2,
    'filters': filters.toWire(),
    'availability': {
      'status': available ? 'available' : 'unavailable',
      'reason': available ? null : 'no_observed_full_defense_evidence',
    },
    'selected_stage': available ? _mockStage : null,
    'fallback_path': [
      for (final (index, name) in _stages.indexed)
        {
          'stage': index + 1,
          'name': name,
          'eligible_snapshot_count': index + 1 == _mockStage
              ? evidence.length
              : 0,
          'contributed_snapshot_count': available && index + 1 == _mockStage
              ? evidence.length
              : 0,
          'weight_discount': available && index + 1 == _mockStage ? 1.0 : 0.0,
        },
    ],
    'evidence_summary': {
      'included_snapshot_count': available ? evidence.length : 0,
      'distinct_opponent_count': available ? 1 : 0,
      'excluded_undated_snapshot_count': undated,
    },
    'scenarios': scenarios,
    'scenario_total': allScenarios.length,
    'hidden_slots': const <Object>[],
    'ambiguity': {
      'grade': ambiguity,
      'variant_defense_possible': allScenarios.length > 1,
      'top_evidence_weight_share': topShare,
      'public_known_slot_count': 0,
    },
    'confidence': {
      'grade': confidence,
      'calibration_gate_passed': false,
      'precise_probability_available': false,
    },
    'recommendations': top,
    'recommendation_total': top.length,
    'validation': {
      'evaluated_case_count': 0,
      'top1_accuracy': null,
      'topk_accuracy': null,
      'hidden_slot_accuracy': null,
      'brier_score': null,
      'log_loss': null,
      'time_ordered': true,
      'same_snapshot_train_test_overlap': false,
      'calibration_gate_passed': false,
    },
    'terminology': {
      'scenario_share_label': 'evidence_weight_share_not_probability',
      'win_rate_label': 'observed_win_rate',
      'warning':
          'Scenarios are observed full defenses, not generated slot combinations or guaranteed counters.',
    },
  };
}
