// FE9-g: 전술대항전 슬롯 통계 화면(시안 Tactical-Slots)의 위젯 없는 모델.
//
// 값은 모두 내 방어 기록(kind `defense`, 내 덱 = `defenseDeck`, 상대 덱 = `attackDeck`, 결과 승 = 방어 성공)에서 센 관측 값이다
// (FD-127 (a)). 상위 500위 모집단 통계(슬롯 사용률 · 지난주 대비 · 메타 집중도 · 대체 학생 보정 방어 · 신뢰도), 리프트, 배치 민감도,
// 기대 대비 같은 모집단 · 모델 지표는 만들지 않는다(화면은 빈 상태 설명 또는 '—').
// - 내 방어 덱(FD-133 워커 재량, 권장안): 방어 기록을 덱 identity(위치 · 모름 · 빈칸까지, [tacticalDeckSignatureText])로 묶는다.
//   순서는 기록 컨트롤러 순서(시각 최신 순, 시각 모름은 뒤)에서 그 덱이 처음 나온 자리다 — 첫 덱 = 가장 최근 방어 기록의 덱(기본).
//   화면에서 다른 덱으로 바꿔 볼 수 있지만 저장하지 않는다.
// - 슬롯 통계(S2): 고른 칸(0~5)에 놓였던 학생을 내 방어 기록 전체에서 센다(그 칸 학생을 아는 기록이 분모). 학생의 자리별 배치 ·
//   자리별 방어 성공률도 내 방어 기록 전체에서 센다.
// - 궁합 · 카운터(S3): 덱 안정성은 고른 덱의 방어 기록(같은 덱 identity)에서 센다. 뚫은 공격 학생은 tidy3(CF 결정 2026-10-17,
//   FE9-g 발견 3)부터 **고른 칸의 학생이 그 자리에 있던 내 방어 기록**의 뚫린 기록에서 센다(칸을 바꾸면 바뀐다,
//   [tacticalSlotsBreakerRecords]). 유도 공격 덱은 "공개 슬롯이 유도하는" 덱이라 내 덱의 공개 칸(1번 · SP1 · SP2) 학생이 같은 방어
//   기록 전부에서 센다(공개 칸 학생을 다 모르면 같은 덱).
// - 기간(tidy3): 화면은 최근 30일 방어 기록만 넘긴다(`tactical_window.dart`, 기록 S4 · 분석과 같은 규칙). 시각 모름 · 30일 이전
//   기록은 빠지고 S1 칩 줄에 "… 제외"로 알린다.
// - 상대 없는 방어 기록(FD-176, identity · 이름 null 쌍)은 전체 집계(평균 방어 · 공격 학생 · 유도 덱)에는 들고 상대별 묶음(재도전
//   방어 · 뚫린 상대)에서만 빠진다. 시도 횟수는 이 화면에서 쓰지 않는다.
// - 시간 순서가 필요한 값(최근 10전 · 최장 연패 · 재도전 방어)은 시각을 아는 기록(정밀도 date · instant)만 쓴다. 시각 모름 기록을
//   어느 자리에 넣을 수 없어서다. 쓸 기록이 없으면 '—'.
import 'package:flutter/foundation.dart';

import '../../services/tactical_v2_service.dart';
import 'tactical_analysis_view.dart';
import 'tactical_jokbo_view.dart';
import 'tactical_records_view.dart';
import 'tactical_window.dart';

/// "최근 10전"의 전 수.
const tacticalSlotsRecentCount = 10;

/// 결과 하나(승 · 패만 센다).
bool _win(TacticalMatchV2 match) => match.result == 'win';
bool _loss(TacticalMatchV2 match) => match.result == 'loss';

/// 관측 비율(승 / (승 + 패)), 표본이 없으면 null.
double? tacticalObservedRate(int wins, int losses) =>
    wins + losses == 0 ? null : wins / (wins + losses);

/// 내 방어 기록(컨트롤러 순서 그대로).
List<TacticalMatchV2> tacticalDefenseMatches(List<TacticalMatchV2> matches) =>
    List.unmodifiable([
      for (final match in matches)
        if (match.kind == 'defense') match,
    ]);

/// 내 방어 덱 하나(같은 덱 identity의 방어 기록 묶음).
@immutable
class TacticalSlotsDeck {
  const TacticalSlotsDeck({
    required this.key,
    required this.deck,
    required this.records,
  });

  /// 덱 identity([tacticalDeckSignatureText]).
  final String key;
  final TacticalDeckV2 deck;

  /// 이 덱의 방어 기록(컨트롤러 순서 — 최근 순, 시각 모름은 뒤).
  final List<TacticalMatchV2> records;

  int get wins => records.where(_win).length;
  int get losses => records.where(_loss).length;

  /// 시각을 아는 가장 최근 기록의 시각. 모르면 null.
  String? get lastAt {
    for (final match in records) {
      if (tacticalMatchTime(match) != null) return match.occurredAt;
    }
    return null;
  }

  /// 시각을 아는 가장 오래된 기록의 시각. 모르면 null.
  String? get firstAt {
    for (final match in records.reversed) {
      if (tacticalMatchTime(match) != null) return match.occurredAt;
    }
    return null;
  }
}

/// 내 방어 덱 목록(첫 덱 = 가장 최근 방어 기록의 덱, FD-133).
List<TacticalSlotsDeck> tacticalSlotsDecks(List<TacticalMatchV2> defense) {
  final order = <String>[];
  final grouped = <String, List<TacticalMatchV2>>{};
  for (final match in defense) {
    final key = tacticalDeckSignatureText(match.defenseDeck);
    final list = grouped.putIfAbsent(key, () {
      order.add(key);
      return [];
    });
    list.add(match);
  }
  return List.unmodifiable([
    for (final key in order)
      TacticalSlotsDeck(
        key: key,
        deck: grouped[key]!.first.defenseDeck,
        records: List.unmodifiable(grouped[key]!),
      ),
  ]);
}

/// 고를 칸: [wanted]가 학생을 아는 칸이면 그 칸, 아니면 학생을 아는 첫 칸, 없으면 null.
int? tacticalSlotsDefaultSlot(TacticalDeckV2 deck, int? wanted) {
  final slots = tacticalDeckSlots(deck);
  if (wanted != null &&
      wanted >= 0 &&
      wanted < slots.length &&
      slots[wanted].studentId != null) {
    return wanted;
  }
  for (final (index, slot) in slots.indexed) {
    if (slot.studentId != null) return index;
  }
  return null;
}

// --- S2 슬롯별 통계 -------------------------------------------------------------

/// 고른 칸에 놓였던 학생 한 명(내 방어 기록에서 센 값).
@immutable
class TacticalSlotUsage {
  const TacticalSlotUsage({
    required this.studentId,
    required this.count,
    required this.total,
    required this.wins,
    required this.losses,
  });

  final String studentId;

  /// 그 칸에 이 학생이 있던 내 방어 기록 수.
  final int count;

  /// 그 칸의 학생을 아는 내 방어 기록 수(분모).
  final int total;
  final int wins, losses;

  double get share => total == 0 ? 0 : count / total;
}

/// [slotIndex] 칸 학생별 사용(많은 순 → 승 많은 순 → 처음 나온 순).
List<TacticalSlotUsage> tacticalSlotUsage(
  List<TacticalMatchV2> defense,
  int slotIndex,
) {
  final order = <String>[];
  final counts = <String, ({int count, int wins, int losses})>{};
  var total = 0;
  for (final match in defense) {
    final id = tacticalDeckSlots(match.defenseDeck)[slotIndex].studentId;
    if (id == null) continue;
    total++;
    final before = counts[id];
    if (before == null) order.add(id);
    counts[id] = (
      count: (before?.count ?? 0) + 1,
      wins: (before?.wins ?? 0) + (_win(match) ? 1 : 0),
      losses: (before?.losses ?? 0) + (_loss(match) ? 1 : 0),
    );
  }
  final items = [
    for (final id in order)
      TacticalSlotUsage(
        studentId: id,
        count: counts[id]!.count,
        total: total,
        wins: counts[id]!.wins,
        losses: counts[id]!.losses,
      ),
  ];
  final position = {for (final (index, id) in order.indexed) id: index};
  items.sort((a, b) {
    final count = b.count.compareTo(a.count);
    if (count != 0) return count;
    final wins = b.wins.compareTo(a.wins);
    if (wins != 0) return wins;
    return position[a.studentId]!.compareTo(position[b.studentId]!);
  });
  return List.unmodifiable(items);
}

/// 학생 한 명의 한 자리(내 방어 기록에서 센 값).
@immutable
class TacticalSlotPosition {
  const TacticalSlotPosition({
    required this.index,
    required this.count,
    required this.total,
    required this.wins,
    required this.losses,
  });

  /// 칸(0~5).
  final int index;

  /// 이 자리에 이 학생이 있던 내 방어 기록 수.
  final int count;

  /// 이 학생이 덱 어딘가에 있던 내 방어 기록 수(분모).
  final int total;
  final int wins, losses;

  double get share => total == 0 ? 0 : count / total;

  /// 이 자리 방어 성공률(관측). 표본이 없으면 null.
  double? get rate => tacticalObservedRate(wins, losses);
}

/// [studentId]의 자리별 배치(스트라이커면 1~4번, 스페셜이면 SP1 · SP2 — [slotIndex]가 속한 쪽).
List<TacticalSlotPosition> tacticalSlotPositions(
  List<TacticalMatchV2> defense,
  String studentId,
  int slotIndex,
) {
  final indexes = slotIndex < 4 ? const [0, 1, 2, 3] : const [4, 5];
  final counts = {for (final index in indexes) index: (0, 0, 0)};
  var total = 0;
  for (final match in defense) {
    final slots = tacticalDeckSlots(match.defenseDeck);
    if (!slots.any((slot) => slot.studentId == studentId)) continue;
    total++;
    for (final index in indexes) {
      if (slots[index].studentId != studentId) continue;
      final (count, wins, losses) = counts[index]!;
      counts[index] = (
        count + 1,
        wins + (_win(match) ? 1 : 0),
        losses + (_loss(match) ? 1 : 0),
      );
    }
  }
  return List.unmodifiable([
    for (final index in indexes)
      TacticalSlotPosition(
        index: index,
        count: counts[index]!.$1,
        total: total,
        wins: counts[index]!.$2,
        losses: counts[index]!.$3,
      ),
  ]);
}

/// 위치별 방어 성공률 비교: 고른 칸 자리와, 이 학생이 놓였던 다른 자리 중 기록이 가장 많은 자리(같으면 앞 자리).
({TacticalSlotPosition current, TacticalSlotPosition? other})
tacticalSlotPositionCompare(
  List<TacticalSlotPosition> positions,
  int slotIndex,
) {
  final current = positions.firstWhere((item) => item.index == slotIndex);
  TacticalSlotPosition? other;
  for (final item in positions) {
    if (item.index == slotIndex || item.count == 0) continue;
    if (other == null || item.count > other.count) other = item;
  }
  return (current: current, other: other);
}

/// 두 관측 비율의 차이(%p, 앞 − 뒤). 하나라도 모르면 null.
double? tacticalRateDifference(double? a, double? b) =>
    a == null || b == null ? null : (a - b) * 100;

/// %p 표시(부호 · 소수 한 자리, 시안 "+7.2%p"). 모르면 '—'.
String tacticalPointText(double? value) {
  if (value == null) return '—';
  final rounded = (value * 10).round() / 10;
  final sign = rounded > 0 ? '+' : (rounded < 0 ? '−' : '');
  return '$sign${rounded.abs().toStringAsFixed(1)}%p';
}

// --- S3 궁합 · 카운터 -----------------------------------------------------------

/// 이 방어 덱을 뚫은 공격 학생 한 명.
@immutable
class TacticalSlotBreaker {
  const TacticalSlotBreaker({
    required this.studentId,
    required this.count,
    required this.losses,
  });

  final String studentId;

  /// 이 학생이 공격 덱에 있던, 이 덱이 뚫린 기록 수.
  final int count;

  /// 이 덱이 뚫린 기록 수(분모).
  final int losses;

  double get share => losses == 0 ? 0 : count / losses;
}

/// 뚫은 공격 학생을 셀 방어 기록: [defense] 중 [slotIndex] 칸에 [studentId]가 있던 기록(덱 나머지 칸은 무엇이든).
List<TacticalMatchV2> tacticalSlotsBreakerRecords(
  List<TacticalMatchV2> defense,
  int slotIndex,
  String studentId,
) => List.unmodifiable([
  for (final match in defense)
    if (tacticalDeckSlots(match.defenseDeck)[slotIndex].studentId == studentId)
      match,
]);

/// 뚫린 기록(결과 패)의 공격 덱 학생(많은 순 → 처음 나온 순). 같은 기록 안 같은 학생은 한 번.
List<TacticalSlotBreaker> tacticalSlotBreakers(List<TacticalMatchV2> records) {
  final lost = records.where(_loss).toList();
  final order = <String>[];
  final counts = <String, int>{};
  for (final match in lost) {
    final seen = <String>{};
    for (final slot in tacticalDeckSlots(match.attackDeck)) {
      final id = slot.studentId;
      if (id == null || !seen.add(id)) continue;
      if (!counts.containsKey(id)) order.add(id);
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  final position = {for (final (index, id) in order.indexed) id: index};
  final items =
      [
        for (final id in order)
          TacticalSlotBreaker(
            studentId: id,
            count: counts[id]!,
            losses: lost.length,
          ),
      ]..sort((a, b) {
        final count = b.count.compareTo(a.count);
        return count != 0
            ? count
            : position[a.studentId]!.compareTo(position[b.studentId]!);
      });
  return List.unmodifiable(items);
}

/// 공개 칸(1번 · SP1 · SP2) 학생 열쇠. 하나라도 모르면 null.
String? tacticalSlotsPublicKey(TacticalDeckV2 deck) {
  final slots = tacticalDeckSlots(deck);
  final ids = [
    for (final index in tacticalPublicSlotIndexes) slots[index].studentId,
  ];
  return ids.any((id) => id == null) ? null : ids.join('|');
}

/// 유도 공격 덱을 셀 방어 기록: 내 덱의 공개 칸 학생이 같은 방어 기록 전부. 공개 칸 학생을 다 모르면 같은 덱 기록.
List<TacticalMatchV2> tacticalSlotsPublicRecords(
  List<TacticalMatchV2> defense,
  TacticalSlotsDeck deck,
) {
  final key = tacticalSlotsPublicKey(deck.deck);
  if (key == null) return deck.records;
  return List.unmodifiable([
    for (final match in defense)
      if (tacticalSlotsPublicKey(match.defenseDeck) == key) match,
  ]);
}

/// 상대가 들고 온 공격 덱 하나(공개 슬롯이 유도한 덱).
@immutable
class TacticalInducedDeck {
  const TacticalInducedDeck({
    required this.deck,
    required this.count,
    required this.total,
    required this.wins,
    required this.losses,
  });

  final TacticalDeckV2 deck;

  /// 이 공격 덱을 만난 방어 기록 수.
  final int count;

  /// 센 방어 기록 수(분모, "상대 공격 중 n%").
  final int total;

  /// 내 방어 승 · 패.
  final int wins, losses;

  double get share => total == 0 ? 0 : count / total;

  /// 이 덱 상대 방어 성공률(관측). 표본이 없으면 null.
  double? get rate => tacticalObservedRate(wins, losses);
}

/// 유도 공격 덱(만난 횟수 많은 순 → 패 많은 순 → 처음 나온 순). 공격 덱은 덱 identity로 묶는다.
List<TacticalInducedDeck> tacticalInducedDecks(List<TacticalMatchV2> records) {
  final order = <String>[];
  final grouped = <String, List<TacticalMatchV2>>{};
  for (final match in records) {
    final key = tacticalDeckSignatureText(match.attackDeck);
    grouped
        .putIfAbsent(key, () {
          order.add(key);
          return [];
        })
        .add(match);
  }
  final position = {for (final (index, key) in order.indexed) key: index};
  final items =
      [
        for (final key in order)
          (
            key: key,
            deck: TacticalInducedDeck(
              deck: grouped[key]!.first.attackDeck,
              count: grouped[key]!.length,
              total: records.length,
              wins: grouped[key]!.where(_win).length,
              losses: grouped[key]!.where(_loss).length,
            ),
          ),
      ]..sort((a, b) {
        final count = b.deck.count.compareTo(a.deck.count);
        if (count != 0) return count;
        final losses = b.deck.losses.compareTo(a.deck.losses);
        if (losses != 0) return losses;
        return position[a.key]!.compareTo(position[b.key]!);
      });
  return List.unmodifiable([for (final item in items) item.deck]);
}

/// 덱 안정성(방어 결과 기준). 모르는 값은 null.
@immutable
class TacticalDeckStability {
  const TacticalDeckStability({
    required this.wins,
    required this.losses,
    required this.unknownTime,
    required this.recentWins,
    required this.recentLosses,
    required this.longestLosingStreak,
    required this.streakFrom,
    required this.streakTo,
    required this.retryHeld,
    required this.retryTotal,
    required this.brokenOpponents,
  });

  /// 이 덱 방어 기록 전체(상대 없는 기록 포함)의 승 · 패.
  final int wins, losses;

  /// 시각을 모르는 기록 수(시간 순서 값에서 빠진다).
  final int unknownTime;

  /// 시각을 아는 최근 10전의 승 · 패. 시각을 아는 기록이 없으면 null.
  final int? recentWins, recentLosses;

  /// 시각을 아는 기록에서 가장 긴 연패(없으면 0). 시각을 아는 기록이 없으면 null.
  final int? longestLosingStreak;
  final String? streakFrom, streakTo;

  /// 재도전 방어: 이 덱을 뚫은 상대가 다음에 다시 왔을 때 막은 수 / 다시 온 수(시각을 아는 기록 · 상대를 아는 기록만).
  final int retryHeld, retryTotal;

  /// 이 덱을 뚫은 상대 수(상대를 아는 기록만, 시각 무관).
  final int brokenOpponents;

  int get total => wins + losses;

  /// 평균 방어(관측 방어 성공률). 표본이 없으면 null.
  double? get rate => tacticalObservedRate(wins, losses);

  /// 재도전 방어 비율. 다시 온 상대가 없으면 null.
  double? get retryRate => retryTotal == 0 ? null : retryHeld / retryTotal;
}

/// [records](한 덱의 방어 기록)의 안정성.
TacticalDeckStability tacticalDeckStability(List<TacticalMatchV2> records) {
  final timed =
      [
        for (final match in records)
          if (tacticalMatchTime(match) != null) match,
      ]..sort((a, b) {
        final order = tacticalMatchTime(a)!.compareTo(tacticalMatchTime(b)!);
        return order != 0 ? order : a.id.compareTo(b.id);
      });
  final recent = timed.reversed.take(tacticalSlotsRecentCount).toList();
  int? streak;
  String? streakFrom, streakTo;
  if (timed.isNotEmpty) {
    streak = 0;
    var run = 0;
    TacticalMatchV2? runStart;
    for (final match in timed) {
      if (_loss(match)) {
        if (run == 0) runStart = match;
        run++;
        if (run > streak!) {
          streak = run;
          streakFrom = runStart?.occurredAt;
          streakTo = match.occurredAt;
        }
      } else {
        run = 0;
      }
    }
  }
  var retryHeld = 0;
  var retryTotal = 0;
  for (final (index, match) in timed.indexed) {
    final opponent = match.opponentIdentityId;
    if (opponent == null || !_loss(match)) continue;
    final next = timed
        .skip(index + 1)
        .where((item) => item.opponentIdentityId == opponent)
        .firstOrNull;
    if (next == null || !(_win(next) || _loss(next))) continue;
    retryTotal++;
    if (_win(next)) retryHeld++;
  }
  return TacticalDeckStability(
    wins: records.where(_win).length,
    losses: records.where(_loss).length,
    unknownTime: records.length - timed.length,
    recentWins: timed.isEmpty ? null : recent.where(_win).length,
    recentLosses: timed.isEmpty ? null : recent.where(_loss).length,
    longestLosingStreak: streak,
    streakFrom: streakFrom,
    streakTo: streakTo,
    retryHeld: retryHeld,
    retryTotal: retryTotal,
    brokenOpponents: {
      for (final match in records)
        if (_loss(match) && match.opponentIdentityId != null)
          match.opponentIdentityId,
    }.length,
  );
}

/// 이름 뒤 "와/과"(받침 기준, 끝 괄호 부분은 뺀다 — 시안 "리오(무장)와"). 한글이 아니면 "와".
String tacticalWithParticle(String name) {
  var base = name.trim();
  final open = base.lastIndexOf('(');
  if (open > 0 && base.endsWith(')')) base = base.substring(0, open).trim();
  if (base.isEmpty) return '$name와';
  final code = base.codeUnitAt(base.length - 1);
  if (code < 0xac00 || code > 0xd7a3) return '$name와';
  return (code - 0xac00) % 28 == 0 ? '$name와' : '$name과';
}

/// 날짜 구간("9/18 ~ 9/19", 같은 날이면 하나). 모르면 '—'.
String tacticalDateRangeText(String? from, String? to) {
  final left = tacticalShortDateText(from);
  final right = tacticalShortDateText(to);
  if (left == '—' || right == '—') return '—';
  return left == right ? left : '$left ~ $right';
}
