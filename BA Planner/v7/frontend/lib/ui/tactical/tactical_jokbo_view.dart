// FE9-d: S4 "이 시그니처의 족보"의 위젯 없는 모델 — 공개 시그니처, 시그니처 족보 묶음(FD-129), 관측 값, 족보 → 내 덱 복사.
//
// - 공개 시그니처: 로비가 보여 주는 세 칸(1번 = 스트라이커 0, SP1, SP2 — 백엔드 `_public_signature`와 같은 순서) 가운데
//   관측 상태가 `visible_lobby`이고 학생이 있는 칸만 공개 칸이다. 문자열은 백엔드와 같은 `1번|SP1|SP2`(공개 칸이 아니면 `?`).
//   공개 칸이 하나도 없으면 시그니처가 없다(null). 2~4번은 로비에 나오지 않으므로 `visible_lobby`여도 시그니처에 넣지 않는다.
// - 시그니처 족보(FD-129 권장안): 방어 덱이 그 공개 시그니처를 가진(공개 칸 학생이 같은 위치에 있는) 족보 전부의 합집합.
//   상대 · 완전 덱이 달라도 모은다. 공개 칸이 아닌 위치는 아무 학생이나 맞는 것으로 본다.
// - 관측 승/패(FE9-b1 발견 2, CF 결정 2026-10-15): v2 기록에서 센 값만 쓴다. 통계 응답에 이 시그니처 행이 있으면 그 행의
//   `attack_decks`(이 시그니처에 연결된 기록을 공격 덱별로 센 값)에서, 행이 없으면(로비에 연결된 기록이 없음 — Mock 포함)
//   컨트롤러가 같은 편성(방어 · 공격 덱 identity) 기록을 센 값에서 읽는다. `jokbo.wins/losses`(v6 가져오기 집계)는 0이 아니면
//   보조 글자 "가져온 집계 n승 m패"로만 보인다.
// - 마지막 관측: 추이 신선도(시그니처 · 공격 덱의 `last_battle_at`) → 추천(`last_observed_at`) → 같은 편성 기록 시각 순.
// - FD-127 (a): 채택률 · 독립 재현 · 첫 시도 · 평균 · 상대 방어 승률 · 변경 확률 · 보정 방어 · 검증 강도는 만들지 않는다.
// - 복사: 족보 공격 덱 6칸을 위치 그대로 내 덱 초안에 넣는다(저장하지 않는다). 보유하지 않은 학생 칸은 빗금 빈칸(모름)으로 두고
//   이름을 알린다. 족보의 모름 · 와일드카드 칸은 모름, 확인된 빈칸은 확인된 빈칸으로 옮긴다.
import 'package:flutter/foundation.dart';

import '../../services/tactical_v2_service.dart';
import '../../tactical/tactical_records_controller.dart';
import 'tactical_records_view.dart';

/// 로비 공개 위치(덱 칸 0~5 기준): 1번 · SP1 · SP2.
const tacticalPublicSlotIndexes = [0, 4, 5];

/// [deck]의 공개 시그니처(`1번|SP1|SP2`, 공개 칸이 아니면 `?`). 공개 칸이 없으면 null.
String? tacticalPublicSignature(TacticalDeckV2 deck) {
  final slots = tacticalDeckSlots(deck);
  final values = [
    for (final index in tacticalPublicSlotIndexes)
      slots[index].state == 'visible_lobby' ? slots[index].studentId : null,
  ];
  if (values.every((value) => value == null)) return null;
  return values.map((value) => value ?? '?').join('|');
}

/// 공개 칸 위치 이름(예 `1 · SP1 · SP2`). 시그니처가 없으면 '—'.
String tacticalPublicSlotLabels(String? signature) {
  if (signature == null) return '—';
  final parts = signature.split('|');
  final labels = [
    for (final (order, index) in tacticalPublicSlotIndexes.indexed)
      if (parts[order] != '?') tacticalSlotLabel(index),
  ];
  return labels.isEmpty ? '—' : labels.join(' · ');
}

/// [deck]이 [signature]의 공개 칸 학생을 같은 위치에 갖고 있는가(공개 칸이 아닌 위치는 무엇이든 맞다).
bool tacticalDeckMatchesPublicSignature(TacticalDeckV2 deck, String signature) {
  final parts = signature.split('|');
  if (parts.length != tacticalPublicSlotIndexes.length) return false;
  final slots = tacticalDeckSlots(deck);
  for (final (order, index) in tacticalPublicSlotIndexes.indexed) {
    final want = parts[order];
    if (want == '?') continue;
    if (slots[index].studentId != want) return false;
  }
  return true;
}

/// 덱 시그니처(백엔드 `deck_signature`: 스트라이커 4칸 `,` + `|` + 스페셜 2칸, 칸 = 학생 · `*` · `empty` · `?`).
String tacticalDeckSignatureText(TacticalDeckV2 deck) {
  final identity = tacticalDeckIdentity(deck);
  return '${identity.take(4).join(',')}|${identity.skip(4).join(',')}';
}

/// 대상 덱 빈칸 안내(시안 "4번 빈칸"): 모르는 칸 위치. 없으면 "빈칸 없음", 모두 모르면 "모두 빈칸".
String tacticalBlankSlotText(TacticalDeckV2 deck) {
  final labels = [
    for (final (index, slot) in tacticalDeckSlots(deck).indexed)
      if (tacticalSlotFill(slot) == TacticalSlotFill.unknown)
        tacticalSlotLabel(index),
  ];
  if (labels.isEmpty) return '빈칸 없음';
  if (labels.length == 6) return '모두 빈칸';
  final numbered = labels.every((label) => !label.startsWith('SP'));
  return '${labels.join(' · ')}${numbered ? '번' : ''} 빈칸';
}

/// 족보 카드 하나.
@immutable
class TacticalJokboCard {
  const TacticalJokboCard({
    required this.entry,
    required this.wins,
    required this.losses,
    required this.lastObserved,
    required this.fromStatistics,
  });

  final TacticalJokboEntry entry;

  /// 관측 승 · 패(v2 기록에서 센 값).
  final int wins, losses;

  /// 마지막 관측 시각 표시(KST, 모르면 '—').
  final String lastObserved;

  /// 승 · 패를 통계 응답(시그니처 행)에서 읽었는가. false면 컨트롤러의 같은 편성 기록 집계다.
  final bool fromStatistics;

  TacticalJokboV2 get jokbo => entry.jokbo;
  String get id => jokbo.id;

  /// 족보 이름(없으면 '족보 —').
  String get name {
    final value = jokbo.name?.trim() ?? '';
    return value.isEmpty ? '족보 —' : value;
  }

  /// 관측 승률 = 승 / (승 + 패). 표본이 없으면 null.
  double? get observedWinRate {
    final total = wins + losses;
    return total == 0 ? null : wins / total;
  }

  String get recordText => '$wins승 $losses패';

  String get rateText {
    final rate = observedWinRate;
    return rate == null ? '—' : '${(rate * 100).round()}%';
  }

  /// v6 가져오기 집계(0이 아닐 때만).
  String? get importedText => jokbo.wins + jokbo.losses == 0
      ? null
      : '가져온 집계 ${jokbo.wins}승 ${jokbo.losses}패';

  /// 기록을 지워 같은 편성 기록이 0개가 된 자동 족보(fb6-dart 발견 1) — 흐리게 보인다.
  bool get noRecords => entry.hasNoRecords;

  /// 시안 aria "족보 A · 호시노 중심 — 끌어서 내 공격 덱에 놓으면 복사".
  String get semanticLabel => '$name — 끌어서 내 공격 덱에 놓으면 복사';
}

DateTime? _parse(String? value) =>
    value == null ? null : DateTime.tryParse(value);

/// [signature]의 족보 카드(FD-129 합집합). 승 많은 순 → 패 적은 순 → 이름 순 → ID 순.
List<TacticalJokboCard> tacticalSignatureJokboCards({
  required String signature,
  required List<TacticalJokboEntry> jokbo,
  required List<TacticalMatchV2> matches,
  TacticalPublicSignatureStats? statistics,
  List<TacticalFreshnessEvidence> freshness = const [],
  List<TacticalAttackRecommendation> recommendations = const [],
}) {
  final cards = <TacticalJokboCard>[];
  for (final entry in jokbo) {
    if (!tacticalDeckMatchesPublicSignature(
      entry.jokbo.defenseDeck,
      signature,
    )) {
      continue;
    }
    final attack = tacticalDeckSignatureText(entry.jokbo.attackDeck);
    var wins = entry.recordWins;
    var losses = entry.recordLosses;
    final stats = statistics;
    if (stats != null) {
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
        lastObserved: _lastObserved(
          entry,
          signature: signature,
          attack: attack,
          matches: matches,
          freshness: freshness,
          recommendations: recommendations,
        ),
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

String _lastObserved(
  TacticalJokboEntry entry, {
  required String signature,
  required String attack,
  required List<TacticalMatchV2> matches,
  required List<TacticalFreshnessEvidence> freshness,
  required List<TacticalAttackRecommendation> recommendations,
}) {
  DateTime? battle;
  String? battleText;
  for (final item in freshness) {
    if (item.publicSignature != signature || item.attackSignature != attack) {
      continue;
    }
    final time = _parse(item.lastBattleAt);
    final best = battle;
    if (time != null && (best == null || time.isAfter(best))) {
      battle = time;
      battleText = item.lastBattleAt;
    }
  }
  if (battleText != null) return tacticalKstInstantText(battleText);
  final recommended = recommendations
      .where((item) => item.attackSignature == attack)
      .firstOrNull;
  if (recommended != null) {
    return tacticalKstInstantText(recommended.lastObservedAt);
  }
  final defense = tacticalDeckIdentity(entry.jokbo.defenseDeck);
  final attackIdentity = tacticalDeckIdentity(entry.jokbo.attackDeck);
  TacticalMatchV2? latest;
  for (final match in matches) {
    if (match.kind != 'attack' ||
        !listEquals(tacticalDeckIdentity(match.defenseDeck), defense) ||
        !listEquals(tacticalDeckIdentity(match.attackDeck), attackIdentity)) {
      continue;
    }
    final time = _parse(match.occurredAt);
    if (time == null) continue;
    final best = latest;
    if (best == null || time.isAfter(_parse(best.occurredAt)!)) {
      latest = match;
    }
  }
  final found = latest;
  return found == null ? '—' : tacticalOccurredText(found);
}

/// [card]가 지금 내 덱과 같은 공격 덱인가(복사한 뒤 · 이 족보로 친 기록).
bool tacticalJokboMatchesDeck(TacticalJokboCard card, TacticalDeckV2 myDeck) =>
    listEquals(
      tacticalDeckIdentity(card.jokbo.attackDeck),
      tacticalDeckIdentity(myDeck),
    );

/// 화면이 고를 카드: [selectedId]가 목록에 있으면 그것, 없으면 지금 내 덱과 같은 카드, 그것도 없으면 첫 카드.
String? tacticalEffectiveJokboSelection(
  List<TacticalJokboCard> cards,
  String? selectedId,
  TacticalDeckV2 myDeck,
) {
  if (cards.isEmpty) return null;
  if (selectedId != null && cards.any((card) => card.id == selectedId)) {
    return selectedId;
  }
  return (cards
              .where((card) => tacticalJokboMatchesDeck(card, myDeck))
              .firstOrNull ??
          cards.first)
      .id;
}

/// 족보 공격 덱을 내 덱 초안으로 옮긴 결과와 보유하지 않아 빈칸으로 둔 학생 ID(칸 순서).
({TacticalDeckV2 deck, List<String> missing}) tacticalCopyJokboDeck(
  TacticalDeckV2 attack,
  Set<String> owned,
) {
  final missing = <String>[];
  TacticalSlotObservation copy(TacticalSlotObservation slot) {
    final studentId = slot.studentId;
    if (studentId != null) {
      if (owned.contains(studentId)) {
        return tacticalManualSlot(slot.position, studentId);
      }
      missing.add(studentId);
      return tacticalManualSlot(slot.position, null);
    }
    if (tacticalSlotFill(slot) == TacticalSlotFill.empty) {
      return TacticalSlotObservation(
        position: slot.position,
        studentId: null,
        state: 'empty',
        source: 'manual',
        confidence: null,
        reviewStatus: 'confirmed',
        wildcard: false,
      );
    }
    return tacticalManualSlot(slot.position, null);
  }

  final deck = TacticalDeckV2(
    strikers: [for (final slot in attack.strikers) copy(slot)],
    specials: [for (final slot in attack.specials) copy(slot)],
  );
  return (deck: deck, missing: List.unmodifiable(missing));
}

/// 상대 시각 표시("방금" · "n시간 전" · "어제" · "n일 전", 시안 "6시간 전"). [now]는 고정 시계(`appClockNow`)다.
String tacticalAgoText(String? timestamp, DateTime now) {
  final time = _parse(timestamp);
  if (time == null) return '—';
  final minutes = now.toUtc().difference(time.toUtc()).inMinutes;
  if (minutes < 60) return '방금';
  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours시간 전';
  if (hours < 48) return '어제';
  return '${hours ~/ 24}일 전';
}

/// 숨은 편성 다양성(추천 응답 `ambiguity.grade`): 높음 · 보통 · 낮음, 근거가 없으면 null.
String? tacticalDiversityText(String grade) => switch (grade) {
  'high' => '높음',
  'medium' => '보통',
  'low' => '낮음',
  _ => null,
};

/// S4 상단 KPI 값(모르면 '—').
@immutable
class TacticalJokboKpis {
  const TacticalJokboKpis({
    required this.defenders,
    required this.linked,
    required this.verified,
    required this.diversity,
    required this.diversityDetail,
  });

  /// 방어 유저(통계 시그니처 행 `opponent_count` — 이 시그니처를 내 로비에서 보인 상대 수).
  final String defenders;

  /// 연결 족보(FD-129 시그니처 족보 수).
  final String linked;

  /// 최신 검증(추이 신선도의 마지막 승리 시각, 상대 시각).
  final String verified;

  /// 숨은 편성 다양성(추천 모호도 등급)과 "유형 n"(관측된 완전 방어 덱 수).
  final String diversity;
  final String? diversityDetail;
}

/// 공개 시그니처 질의 결과(통계 · 추이 · 추천). 각각 없을 수 있다.
@immutable
class TacticalJokboReads {
  const TacticalJokboReads({
    required this.signature,
    required this.statistics,
    required this.freshness,
    required this.recommendation,
  });

  final String signature;

  /// 통계 응답의 이 시그니처 행(로비에 연결된 기록이 없으면 null).
  final TacticalPublicSignatureStats? statistics;

  /// 추이 응답의 이 시그니처 신선도 행.
  final List<TacticalFreshnessEvidence> freshness;

  /// 추천 응답(상대 identity · 시즌을 모르면 질의하지 않아 null).
  final TacticalRecommendationResult? recommendation;
}

/// [reads]와 카드 수로 KPI를 만든다.
TacticalJokboKpis tacticalJokboKpis({
  required TacticalJokboReads? reads,
  required int cardCount,
  required DateTime now,
}) {
  final statistics = reads?.statistics;
  String? verifiedAt;
  for (final item in reads?.freshness ?? const <TacticalFreshnessEvidence>[]) {
    final time = _parse(item.lastSuccessAt);
    if (time == null) continue;
    final best = _parse(verifiedAt);
    if (best == null || time.isAfter(best)) verifiedAt = item.lastSuccessAt;
  }
  final recommendation = reads?.recommendation;
  final diversity = recommendation == null
      ? null
      : tacticalDiversityText(recommendation.ambiguity.grade);
  return TacticalJokboKpis(
    defenders: statistics == null ? '—' : '${statistics.opponentCount}명',
    linked: '$cardCount개',
    verified: tacticalAgoText(verifiedAt, now),
    diversity: diversity ?? '—',
    diversityDetail: diversity == null || recommendation == null
        ? null
        : '유형 ${recommendation.scenarioTotal}',
  );
}
