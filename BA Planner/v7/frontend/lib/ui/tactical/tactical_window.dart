// tidy3: 전술 화면 세 개(기록 S4 · 분석 · 슬롯)가 같이 쓰는 기간 · 방어 유저 수 규칙(CF 결정 2026-10-17).
//
// - 기간: 세 화면 모두 "최근 30일" 기록만 센다. "지금"은 고정 시계(`appClockNow`)다. 시각을 아는 기록(정밀도 date · instant)만
//   30일 안인지 판단할 수 있으므로 시각 모름 기록은 빠지고, 화면은 "30일 이전 n건 · 시각 모름 n건 제외"를 근거 줄에 보인다.
//   통계 · 추이 질의의 `date_from`도 같은 시작 시각이다(FE9-e 분석 규칙 그대로).
// - 방어 유저 수: 통계 응답에 그 시그니처 행이 있으면 행의 `opponent_count`, 없으면 그 기록들의 서로 다른 상대 수다. 상대를 모르는
//   기록(FD-176 identity · 이름 null 쌍)은 세지 않는다. 기록도 없으면 모른다(null → '—').
import 'package:flutter/foundation.dart';

import '../../services/tactical_v2_service.dart';
import 'tactical_records_view.dart';

/// 기간(시안 칩 "최근 30일").
const tacticalRecentWindow = Duration(days: 30);

/// 기간 칩 글자.
const tacticalRecentWindowLabel = '최근 30일';

/// 기록 시각(정밀도 date · instant만). 모르면 null.
DateTime? tacticalMatchTime(TacticalMatchV2 match) {
  if (match.occurredPrecision == 'unknown') return null;
  final value = match.occurredAt;
  return value == null ? null : DateTime.tryParse(value);
}

/// 기간 시작(UTC).
DateTime tacticalWindowStart(DateTime now) =>
    now.toUtc().subtract(tacticalRecentWindow);

/// 통계 · 추이 질의의 기간 시작(UTC 초).
String tacticalWindowDateFrom(DateTime now) =>
    tacticalUtcInstant(tacticalWindowStart(now));

/// 기간으로 거른 기록과 빠진 수.
@immutable
class TacticalWindowedMatches {
  const TacticalWindowedMatches({
    required this.matches,
    required this.older,
    required this.unknownTime,
  });

  /// 최근 30일 안 기록(넘긴 순서 그대로).
  final List<TacticalMatchV2> matches;

  /// 30일보다 오래된 기록 수.
  final int older;

  /// 시각을 몰라 판단하지 못한 기록 수.
  final int unknownTime;

  /// 근거 줄("30일 이전 n건 · 시각 모름 n건 제외"). 빠진 기록이 없으면 null.
  String? get excludedText {
    final parts = [
      if (older > 0) '30일 이전 $older건',
      if (unknownTime > 0) '시각 모름 $unknownTime건',
    ];
    return parts.isEmpty ? null : '${parts.join(' · ')} 제외';
  }
}

/// [matches]를 [now] 기준 최근 30일로 거른다(순서는 그대로). 미래 시각 기록은 30일 안으로 본다.
TacticalWindowedMatches tacticalRecentMatches(
  Iterable<TacticalMatchV2> matches,
  DateTime now,
) {
  final from = tacticalWindowStart(now);
  final picked = <TacticalMatchV2>[];
  var older = 0;
  var unknownTime = 0;
  for (final match in matches) {
    final time = tacticalMatchTime(match);
    if (time == null) {
      unknownTime++;
    } else if (time.toUtc().isBefore(from)) {
      older++;
    } else {
      picked.add(match);
    }
  }
  return TacticalWindowedMatches(
    matches: List.unmodifiable(picked),
    older: older,
    unknownTime: unknownTime,
  );
}

/// 방어 유저 수: 통계 시그니처 행 [statistics]가 있으면 그 `opponent_count`, 없으면 [matches]의 서로 다른 상대 수(상대 없는
/// 기록은 세지 않는다). 기록도 없으면 null.
int? tacticalDefenderCount({
  required TacticalPublicSignatureStats? statistics,
  required List<TacticalMatchV2> matches,
}) {
  final stats = statistics;
  if (stats != null) return stats.opponentCount;
  if (matches.isEmpty) return null;
  return {
    for (final match in matches)
      if (match.opponentIdentityId != null) match.opponentIdentityId,
  }.length;
}

/// 방어 유저 표시("n명", 모르면 '—').
String tacticalDefenderText(int? count) => count == null ? '—' : '$count명';
