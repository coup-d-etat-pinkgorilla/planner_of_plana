// FE9-e: 전술대항전 분석 화면(시안 Tactical-Analysis · Tactical-Analysis-All)의 위젯 없는 모델.
//
// 값은 모두 관측 값이다(FD-127 (a)). 다수 사용자 자료(채택률 · 독립 재현 · 대체 학생 허용도 · 최초 제보자)와 확률 · 보정 · 판단
// 지표(변경 확률 · 시간 가중 점수 · "널리 알려짐 · 변경 위험" · "방어 변경 성향" · "비추천")는 만들지 않는다.
// - 분석 대상 기록: 공격 기록 중 시각을 아는(정밀도 date · instant) 최근 30일 기록이고, 상대 방어 덱에 로비 공개 칸이 있는 것
//   (공개 시그니처, FE9-d [tacticalPublicSignature]). "지금"은 고정 시계(`appClockNow`)다.
// - S1 시그니처 행: 기록에서 모은 시그니처 + 통계 응답의 시그니처(로비 관측만 있는 것). 방어 유저 = 통계 행 `opponent_count`,
//   행이 없으면 기록의 상대 수. 족보 = FD-129 시그니처 족보 수. "변경 의심 n" = 2~4번 학생이 기록 사이에 바뀐 상대 수.
//   "표본 적음"(FD-134 워커 재량): 관측 기록 5건 미만(독립 재현은 읽기 capability에 없어 쓰지 않는다 — status 발견 사항).
// - S2 족보 상세: 족보 = FD-129 시그니처 족보(합집합). 승 · 패는 통계 시그니처 행의 공격 덱 값, 행이 없으면 같은 편성(방어 ·
//   공격 덱 identity) 기록을 30일 안에서 센 값. 첫 시도 · 평균 시도 · N회 내 누적 돌파율은 그 기록의 `attempt_count`(모름은
//   분모에서 뺀다, FD-176). 상대별 결과 = 같은 편성 기록을 상대마다 센 값.
// - S3 상대 카드: 공개 방어 이력(이 상대 공격 기록의 공개 시그니처가 바뀐 구간), 2~4번에 나온 학생 비율(지난 기록에서 센 관측
//   비율 — 확률이 아니다), 변경 감지(기록 사이 2~4번 학생 변화), 이 상대에게 친 족보 승 · 패, 기억 카드(관측 부분만).
// - 전체 보기 정렬: 성공률 · 최근 성공. 채택률 · 독립 재현 정렬은 자료가 없어 꺼 둔다.
import 'package:flutter/foundation.dart';

import '../../services/tactical_v2_service.dart';
import '../../tactical/tactical_records_controller.dart';
import 'tactical_jokbo_view.dart';
import 'tactical_records_view.dart';

/// 분석 기간(시안 칩 "최근 30일").
const tacticalAnalysisWindow = Duration(days: 30);

/// "표본 적음" 기준(관측 기록 수, FD-134).
const tacticalLowSampleThreshold = 5;

/// 기록 시각(정밀도 date · instant만). 모르면 null.
DateTime? tacticalMatchTime(TacticalMatchV2 match) {
  if (match.occurredPrecision == 'unknown') return null;
  final value = match.occurredAt;
  return value == null ? null : DateTime.tryParse(value);
}

int _newestFirst(TacticalMatchV2 a, TacticalMatchV2 b) {
  final left = tacticalMatchTime(a);
  final right = tacticalMatchTime(b);
  if (left == null || right == null) {
    return left == null ? (right == null ? 0 : 1) : -1;
  }
  final order = right.compareTo(left);
  return order != 0 ? order : a.id.compareTo(b.id);
}

/// 분석 대상 기록(공격 · 시각 있음 · [now] 기준 30일 안 · 공개 시그니처 있음), 최근 순.
List<TacticalMatchV2> tacticalAnalysisMatches(
  List<TacticalMatchV2> matches,
  DateTime now,
) {
  final from = now.toUtc().subtract(tacticalAnalysisWindow);
  final picked = [
    for (final match in matches)
      if (match.kind == 'attack' &&
          tacticalPublicSignature(match.defenseDeck) != null &&
          (tacticalMatchTime(match)?.toUtc().isBefore(from) == false))
        match,
  ]..sort(_newestFirst);
  return List.unmodifiable(picked);
}

/// 통계 · 추이 질의의 기간 시작(UTC 초).
String tacticalAnalysisDateFrom(DateTime now) =>
    tacticalUtcInstant(now.toUtc().subtract(tacticalAnalysisWindow));

/// 짧은 상대 시각(시안 S1 "6h" · "1d"). 모르면 '—'.
String tacticalShortAgoText(String? timestamp, DateTime now) {
  final time = timestamp == null ? null : DateTime.tryParse(timestamp);
  if (time == null) return '—';
  final minutes = now.toUtc().difference(time.toUtc()).inMinutes;
  if (minutes < 60) return '방금';
  final hours = minutes ~/ 60;
  if (hours < 24) return '${hours}h';
  return '${hours ~/ 24}d';
}

/// KST 짧은 날짜(시안 "9/21"). 모르면 '—'.
String tacticalShortDateText(String? timestamp) {
  final text = tacticalKstDateText(timestamp);
  if (text == '—') return text;
  final parts = text.split('-');
  return '${int.parse(parts[1])}/${int.parse(parts[2])}';
}

/// 족보 짧은 이름(seg 글자, 시안 "족보 A"): 이름의 첫 " · " 앞.
String tacticalJokboShortName(String name) {
  final index = name.indexOf(' · ');
  return index < 0 ? name : name.substring(0, index);
}

/// [signature]만 아는 덱(공개 칸은 로비 공개 관측, 나머지는 모름) — 로비 관측만 있고 기록이 없는 시그니처 행 표시용.
TacticalDeckV2 tacticalSignatureDeck(String signature) {
  final parts = signature.split('|');
  TacticalSlotObservation slot(int position, String? value) {
    final known = value != null && value != '?';
    return TacticalSlotObservation(
      position: position,
      studentId: known ? value : null,
      state: known ? 'visible_lobby' : 'unknown',
      source: known ? 'lobby_scan' : 'manual',
      confidence: null,
      reviewStatus: 'confirmed',
      wildcard: false,
    );
  }

  return TacticalDeckV2(
    strikers: [
      slot(0, parts.isNotEmpty ? parts[0] : null),
      slot(1, null),
      slot(2, null),
      slot(3, null),
    ],
    specials: [
      slot(0, parts.length > 1 ? parts[1] : null),
      slot(1, parts.length > 2 ? parts[2] : null),
    ],
  );
}

// --- 변경 감지 ---------------------------------------------------------------

/// 기록 사이에 바뀐 2~4번 학생 한 칸(관측: 앞 · 뒤 기록 모두 그 칸 학생을 안다).
@immutable
class TacticalHiddenChange {
  const TacticalHiddenChange({
    required this.slotIndex,
    required this.before,
    required this.after,
    required this.lastSameAt,
    required this.changedAt,
  });

  /// 덱 칸 1~3(2~4번).
  final int slotIndex;
  final String before, after;

  /// 바뀌기 전 마지막 기록 · 바뀐 첫 기록 시각.
  final String? lastSameAt, changedAt;
}

/// [matches](한 상대의 기록)에서 가장 최근의 2~4번 변화. 없으면 null.
TacticalHiddenChange? tacticalLatestHiddenChange(
  List<TacticalMatchV2> matches,
) {
  final ordered = [
    for (final match in matches)
      if (tacticalMatchTime(match) != null) match,
  ]..sort((a, b) => _newestFirst(b, a));
  TacticalHiddenChange? latest;
  for (var index = 1; index < ordered.length; index++) {
    final before = tacticalDeckSlots(ordered[index - 1].defenseDeck);
    final after = tacticalDeckSlots(ordered[index].defenseDeck);
    for (var slot = 1; slot <= 3; slot++) {
      final from = before[slot].studentId;
      final to = after[slot].studentId;
      if (from == null || to == null || from == to) continue;
      latest = TacticalHiddenChange(
        slotIndex: slot,
        before: from,
        after: to,
        lastSameAt: ordered[index - 1].occurredAt,
        changedAt: ordered[index].occurredAt,
      );
      break;
    }
  }
  return latest;
}

Map<String, List<TacticalMatchV2>> _byOpponent(List<TacticalMatchV2> matches) {
  final groups = <String, List<TacticalMatchV2>>{};
  for (final match in matches) {
    (groups[match.opponentIdentityId] ??= []).add(match);
  }
  return groups;
}

// --- S1 시그니처 -------------------------------------------------------------

/// 공개 방어 시그니처 행 하나.
@immutable
class TacticalSignatureSummary {
  const TacticalSignatureSummary({
    required this.signature,
    required this.deck,
    required this.matches,
    required this.lastObservedAt,
    required this.defenders,
    required this.jokboCount,
    required this.changeCount,
  });

  final String signature;

  /// 공개 칸 초상을 그릴 덱(가장 최근 기록의 방어 덱, 기록이 없으면 시그니처에서 만든 덱).
  final TacticalDeckV2 deck;

  /// 이 시그니처의 분석 대상 기록(최근 순).
  final List<TacticalMatchV2> matches;
  final String? lastObservedAt;

  /// 방어 유저 수(모르면 null).
  final int? defenders;
  final int jokboCount;

  /// "변경 의심 n": 2~4번이 바뀐 상대 수.
  final int changeCount;

  int get sampleCount => matches.length;

  /// FD-134: 관측 기록 5건 미만.
  bool get lowSample => sampleCount < tacticalLowSampleThreshold;
}

/// S1 행(최근 관측 순 → 기록 많은 순 → 시그니처 순).
List<TacticalSignatureSummary> tacticalSignatureSummaries({
  required List<TacticalMatchV2> matches,
  required List<TacticalJokboEntry> jokbo,
  List<TacticalPublicSignatureStats> statistics = const [],
}) {
  final groups = <String, List<TacticalMatchV2>>{};
  for (final match in matches) {
    final signature = tacticalPublicSignature(match.defenseDeck);
    if (signature == null) continue;
    (groups[signature] ??= []).add(match);
  }
  for (final row in statistics) {
    groups.putIfAbsent(row.signature, () => []);
  }
  final rows = <TacticalSignatureSummary>[];
  for (final MapEntry(key: signature, value: group) in groups.entries) {
    final ordered = [...group]..sort(_newestFirst);
    final stats = statistics
        .where((row) => row.signature == signature)
        .firstOrNull;
    final opponents = _byOpponent(ordered);
    rows.add(
      TacticalSignatureSummary(
        signature: signature,
        deck: ordered.isEmpty
            ? tacticalSignatureDeck(signature)
            : ordered.first.defenseDeck,
        matches: List.unmodifiable(ordered),
        lastObservedAt: ordered.isEmpty ? null : ordered.first.occurredAt,
        defenders:
            stats?.opponentCount ?? (ordered.isEmpty ? null : opponents.length),
        jokboCount: jokbo
            .where(
              (entry) => tacticalDeckMatchesPublicSignature(
                entry.jokbo.defenseDeck,
                signature,
              ),
            )
            .length,
        changeCount: opponents.values
            .where((items) => tacticalLatestHiddenChange(items) != null)
            .length,
      ),
    );
  }
  DateTime? latest(TacticalSignatureSummary row) =>
      row.matches.isEmpty ? null : tacticalMatchTime(row.matches.first);
  rows.sort((a, b) {
    final left = latest(a);
    final right = latest(b);
    if (left != right) {
      if (left == null) return 1;
      if (right == null) return -1;
      final order = right.compareTo(left);
      if (order != 0) return order;
    }
    final count = b.sampleCount.compareTo(a.sampleCount);
    return count != 0 ? count : a.signature.compareTo(b.signature);
  });
  return List.unmodifiable(rows);
}

// --- S2 족보 상세 -------------------------------------------------------------

bool _sameComposition(TacticalMatchV2 match, TacticalJokboV2 jokbo) =>
    listEquals(
      tacticalDeckIdentity(match.defenseDeck),
      tacticalDeckIdentity(jokbo.defenseDeck),
    ) &&
    listEquals(
      tacticalDeckIdentity(match.attackDeck),
      tacticalDeckIdentity(jokbo.attackDeck),
    );

/// [signature]의 족보 카드(FD-129 합집합, FE9-d 카드 순서). 승 · 패는 통계 행의 공격 덱 값, 없으면 [matches](30일 안)의
/// 같은 편성 기록.
List<TacticalJokboCard> tacticalAnalysisJokboCards({
  required String signature,
  required List<TacticalJokboEntry> jokbo,
  required List<TacticalMatchV2> matches,
  TacticalPublicSignatureStats? statistics,
}) {
  final cards = <TacticalJokboCard>[];
  for (final entry in jokbo) {
    if (!tacticalDeckMatchesPublicSignature(
      entry.jokbo.defenseDeck,
      signature,
    )) {
      continue;
    }
    final records = [
      for (final match in matches)
        if (_sameComposition(match, entry.jokbo)) match,
    ];
    var wins = records.where((match) => match.result == 'win').length;
    var losses = records.length - wins;
    final stats = statistics;
    if (stats != null) {
      final attack = tacticalDeckSignatureText(entry.jokbo.attackDeck);
      final row = stats.attackDecks
          .where((item) => item.signature == attack)
          .firstOrNull;
      wins = row?.result.wins ?? 0;
      losses = row?.result.losses ?? 0;
    }
    cards.add(
      TacticalJokboCard(
        entry: entry,
        wins: wins,
        losses: losses,
        lastObserved: records.isEmpty
            ? '—'
            : tacticalOccurredText(records.first),
        fromStatistics: stats != null,
      ),
    );
  }
  cards.sort((a, b) {
    var order = b.wins.compareTo(a.wins);
    if (order != 0) return order;
    order = a.losses.compareTo(b.losses);
    if (order != 0) return order;
    order = a.name.compareTo(b.name);
    return order != 0 ? order : a.id.compareTo(b.id);
  });
  return List.unmodifiable(cards);
}

/// 상대별 결과 한 줄.
@immutable
class TacticalJokboOpponentResult {
  const TacticalJokboOpponentResult({
    required this.identityId,
    required this.name,
    required this.wins,
    required this.losses,
    required this.lastAt,
  });

  final String identityId, name;
  final int wins, losses;
  final String? lastAt;

  double? get rate => wins + losses == 0 ? null : wins / (wins + losses);
}

/// 고른 족보 하나의 관측 값.
@immutable
class TacticalJokboAnalysis {
  const TacticalJokboAnalysis({
    required this.card,
    required this.records,
    required this.defenseUsers,
    required this.knownAttempts,
    required this.firstTryWins,
    required this.averageAttempts,
    required this.cumulative,
    required this.opponents,
    required this.firstAt,
    required this.lastAt,
    required this.lastSuccessAt,
  });

  final TacticalJokboCard card;

  /// 같은 편성 기록(30일 안, 최근 순).
  final List<TacticalMatchV2> records;

  /// 같은 방어 덱(6명 · 위치)을 쓴 상대 수.
  final int defenseUsers;

  /// 시도 횟수를 아는 기록 수 · 그중 첫 시도 승리 수.
  final int knownAttempts, firstTryWins;

  /// 이긴 기록의 평균 시도(모르면 null).
  final double? averageAttempts;

  /// 1 · 2 · 3회 안에 이긴 비율(시도를 아는 기록이 없으면 null).
  final List<double?> cumulative;
  final List<TacticalJokboOpponentResult> opponents;
  final String? firstAt, lastAt, lastSuccessAt;

  /// FD-134: 관측 표본(승 + 패) 5건 미만.
  bool get lowSample => card.wins + card.losses < tacticalLowSampleThreshold;

  double? get firstTryRate =>
      knownAttempts == 0 ? null : firstTryWins / knownAttempts;
}

/// [card]의 관측 값. [matches]는 분석 대상 기록(30일 안), [freshness]는 추이 신선도(마지막 승리 시각).
TacticalJokboAnalysis tacticalJokboAnalysis({
  required TacticalJokboCard card,
  required List<TacticalMatchV2> matches,
  List<TacticalFreshnessEvidence> freshness = const [],
}) {
  final jokbo = card.jokbo;
  final records = [
    for (final match in matches)
      if (_sameComposition(match, jokbo)) match,
  ]..sort(_newestFirst);
  final defense = tacticalDeckIdentity(jokbo.defenseDeck);
  final defenseUsers = {
    for (final match in matches)
      if (listEquals(tacticalDeckIdentity(match.defenseDeck), defense))
        match.opponentIdentityId,
  }.length;
  final known = [
    for (final match in records)
      if (match.attemptCount != null) match,
  ];
  final wonAttempts = [
    for (final match in known)
      if (match.result == 'win') match.attemptCount!,
  ];
  final cumulative = [
    for (var limit = 1; limit <= 3; limit++)
      known.isEmpty
          ? null
          : wonAttempts.where((value) => value <= limit).length / known.length,
  ];
  final opponents = <TacticalJokboOpponentResult>[];
  for (final MapEntry(key: id, value: group) in _byOpponent(records).entries) {
    final wins = group.where((match) => match.result == 'win').length;
    opponents.add(
      TacticalJokboOpponentResult(
        identityId: id,
        name: group.first.opponentDisplayName,
        wins: wins,
        losses: group.length - wins,
        lastAt: group.first.occurredAt,
      ),
    );
  }
  opponents.sort((a, b) {
    final order = (b.wins + b.losses).compareTo(a.wins + a.losses);
    if (order != 0) return order;
    return (b.lastAt ?? '').compareTo(a.lastAt ?? '');
  });
  String? lastSuccess = records
      .where((match) => match.result == 'win')
      .firstOrNull
      ?.occurredAt;
  final attack = tacticalDeckSignatureText(jokbo.attackDeck);
  for (final item in freshness) {
    if (item.attackSignature != attack) continue;
    final time = DateTime.tryParse(item.lastSuccessAt ?? '');
    final best = DateTime.tryParse(lastSuccess ?? '');
    if (time != null && (best == null || time.isAfter(best))) {
      lastSuccess = item.lastSuccessAt;
    }
  }
  return TacticalJokboAnalysis(
    card: card,
    records: List.unmodifiable(records),
    defenseUsers: defenseUsers,
    knownAttempts: known.length,
    firstTryWins: wonAttempts.where((value) => value == 1).length,
    averageAttempts: wonAttempts.isEmpty
        ? null
        : wonAttempts.reduce((a, b) => a + b) / wonAttempts.length,
    cumulative: List.unmodifiable(cumulative),
    opponents: List.unmodifiable(opponents),
    firstAt: records.lastOrNull?.occurredAt,
    lastAt: records.firstOrNull?.occurredAt,
    lastSuccessAt: lastSuccess,
  );
}

/// 기본으로 고를 족보: 관측 표본이 가장 많은 카드(같으면 카드 순서).
String? tacticalDefaultAnalysisJokbo(List<TacticalJokboCard> cards) {
  TacticalJokboCard? best;
  for (final card in cards) {
    if (best == null || card.wins + card.losses > best.wins + best.losses) {
      best = card;
    }
  }
  return best?.id;
}

/// 비율 표시(반올림 %, 모르면 '—').
String tacticalPercentText(double? value) =>
    value == null ? '—' : '${(value * 100).round()}%';

/// 검증 강도(FD-134 워커 재량): 추천 신뢰 등급 high/medium/low → A/B/C, 그 밖 '—'.
String tacticalVerificationGrade(String? grade) => switch (grade) {
  'high' => 'A',
  'medium' => 'B',
  'low' => 'C',
  _ => '—',
};

// --- S3 상대 카드 -------------------------------------------------------------

/// 공개 방어 이력 한 구간.
@immutable
class TacticalPublicPeriod {
  const TacticalPublicPeriod({
    required this.deck,
    required this.fromAt,
    required this.toAt,
    required this.current,
  });

  final TacticalDeckV2 deck;
  final String? fromAt, toAt;

  /// 가장 최근 구간("~ 현재").
  final bool current;

  String get rangeText => current
      ? '${tacticalShortDateText(fromAt)} ~ 현재'
      : '${tacticalShortDateText(fromAt)} ~ ${tacticalShortDateText(toAt)}';
}

/// 2~4번에 나온 학생 한 명(지난 기록에서 센 비율).
@immutable
class TacticalHiddenCandidate {
  const TacticalHiddenCandidate({
    required this.studentId,
    required this.count,
    required this.share,
  });

  final String studentId;
  final int count;
  final double share;
}

/// 이 상대에게 친 족보 한 줄.
@immutable
class TacticalOpponentJokbo {
  const TacticalOpponentJokbo({
    required this.card,
    required this.wins,
    required this.losses,
  });

  final TacticalJokboCard card;
  final int wins, losses;
}

/// 상대 카드.
@immutable
class TacticalOpponentAnalysis {
  const TacticalOpponentAnalysis({
    required this.identityId,
    required this.name,
    required this.records,
    required this.periods,
    required this.hidden,
    required this.change,
    required this.effective,
  });

  final String identityId, name;

  /// 이 상대 · 이 시그니처 기록(30일 안, 최근 순).
  final List<TacticalMatchV2> records;

  /// 공개 방어 이력(최근 구간 먼저).
  final List<TacticalPublicPeriod> periods;
  final List<TacticalHiddenCandidate> hidden;
  final TacticalHiddenChange? change;
  final List<TacticalOpponentJokbo> effective;

  /// 공개 덱 변경 횟수(이력 구간 수 − 1).
  int get publicChanges => periods.isEmpty ? 0 : periods.length - 1;

  String? get lastBattleAt => records.firstOrNull?.occurredAt;
}

/// [identityId] 상대의 카드. [allMatches]는 분석 대상 기록 전체(공개 이력은 시그니처와 상관없이 이 상대 기록으로 만든다),
/// [signatureMatches]는 고른 시그니처의 기록, [cards]는 그 시그니처 족보.
TacticalOpponentAnalysis? tacticalOpponentAnalysis({
  required String identityId,
  required List<TacticalMatchV2> allMatches,
  required List<TacticalMatchV2> signatureMatches,
  required List<TacticalJokboCard> cards,
}) {
  final records = [
    for (final match in signatureMatches)
      if (match.opponentIdentityId == identityId) match,
  ];
  final mine = [
    for (final match in allMatches)
      if (match.opponentIdentityId == identityId) match,
  ];
  if (mine.isEmpty) return null;
  // 이력: 오래된 순으로 같은 공개 시그니처가 이어지는 구간.
  final ascending = [...mine]..sort((a, b) => _newestFirst(b, a));
  final periods = <TacticalPublicPeriod>[];
  String? currentSignature;
  TacticalMatchV2? first;
  TacticalMatchV2? last;
  void close({required bool current}) {
    final start = first;
    final end = last;
    if (start == null || end == null) return;
    periods.add(
      TacticalPublicPeriod(
        deck: end.defenseDeck,
        fromAt: start.occurredAt,
        toAt: end.occurredAt,
        current: current,
      ),
    );
  }

  for (final match in ascending) {
    final signature = tacticalPublicSignature(match.defenseDeck);
    if (signature != currentSignature && first != null) {
      close(current: false);
      first = null;
    }
    currentSignature = signature;
    first ??= match;
    last = match;
  }
  close(current: true);
  // 2~4번 학생 비율(한 기록에서 한 번만 센다).
  final counts = <String, int>{};
  for (final match in records) {
    final slots = tacticalDeckSlots(match.defenseDeck);
    final seen = <String>{
      for (var index = 1; index <= 3; index++) ?slots[index].studentId,
    };
    for (final id in seen) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  final hidden =
      [
        for (final MapEntry(key: id, value: count) in counts.entries)
          TacticalHiddenCandidate(
            studentId: id,
            count: count,
            share: count / records.length,
          ),
      ]..sort((a, b) {
        final order = b.count.compareTo(a.count);
        return order != 0 ? order : a.studentId.compareTo(b.studentId);
      });
  final effective = <TacticalOpponentJokbo>[];
  for (final card in cards) {
    final attack = tacticalDeckIdentity(card.jokbo.attackDeck);
    final versus = [
      for (final match in records)
        if (listEquals(tacticalDeckIdentity(match.attackDeck), attack)) match,
    ];
    if (versus.isEmpty) continue;
    final wins = versus.where((match) => match.result == 'win').length;
    effective.add(
      TacticalOpponentJokbo(
        card: card,
        wins: wins,
        losses: versus.length - wins,
      ),
    );
  }
  effective.sort((a, b) {
    final order = b.wins.compareTo(a.wins);
    return order != 0 ? order : a.losses.compareTo(b.losses);
  });
  return TacticalOpponentAnalysis(
    identityId: identityId,
    name: (records.firstOrNull ?? mine.first).opponentDisplayName,
    records: List.unmodifiable(records),
    periods: List.unmodifiable(periods.reversed),
    hidden: List.unmodifiable(hidden),
    change: tacticalLatestHiddenChange(records),
    effective: List.unmodifiable(effective),
  );
}

// --- 전체 보기 ------------------------------------------------------------------

/// 전체 보기 정렬(시안 seg 4). 채택률 · 독립 재현은 자료가 없어 꺼진다(FD-127).
enum TacticalJokboSort {
  successRate('성공률'),
  adoption('채택률'),
  reproduction('독립 재현'),
  recentSuccess('최근 성공');

  const TacticalJokboSort(this.label);

  final String label;

  bool get available =>
      this == TacticalJokboSort.successRate ||
      this == TacticalJokboSort.recentSuccess;
}

/// [analyses]를 [sort]로 줄 세운다(모르는 값은 뒤, 같으면 카드 순서).
List<TacticalJokboAnalysis> tacticalJokboRanking(
  List<TacticalJokboAnalysis> analyses,
  TacticalJokboSort sort,
) {
  final indexed = [...analyses.indexed];
  // 큰 값 먼저, 모르는 값(null)은 뒤.
  int descending(Comparable<Object>? a, Comparable<Object>? b) {
    if (a == null || b == null) return a == null ? (b == null ? 0 : 1) : -1;
    return b.compareTo(a);
  }

  Comparable<Object>? key(TacticalJokboAnalysis item) => switch (sort) {
    TacticalJokboSort.recentSuccess => DateTime.tryParse(
      item.lastSuccessAt ?? '',
    )?.microsecondsSinceEpoch,
    _ => item.card.observedWinRate,
  };

  indexed.sort((a, b) {
    final order = descending(key(a.$2), key(b.$2));
    if (order != 0) return order;
    final wins = b.$2.card.wins.compareTo(a.$2.card.wins);
    return wins != 0 ? wins : a.$1.compareTo(b.$1);
  });
  return List.unmodifiable([for (final (_, item) in indexed) item]);
}

/// 덱 학생 이름 요약(시안 "유우카 · 슌(수영복) · 토키(무장) · 쿠루미 | 노아 · 시로코", 모름 "빈칸").
String tacticalDeckNamesText(
  TacticalDeckV2 deck,
  String Function(String id) name,
) {
  String part(Iterable<TacticalSlotObservation> slots) => slots
      .map((slot) {
        final id = slot.studentId;
        if (id != null) return name(id);
        return tacticalSlotFill(slot) == TacticalSlotFill.empty ? '비움' : '빈칸';
      })
      .join(' · ');
  final slots = tacticalDeckSlots(deck);
  return '${part(slots.take(4))} | ${part(slots.skip(4))}';
}
