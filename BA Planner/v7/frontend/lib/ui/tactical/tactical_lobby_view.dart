// FE9-c: 전술대항전 기록 화면 S2 로비 스캔(시안 Tactical S2 · 방어 이력 플라이아웃, G 보고서 §1)의 위젯 없는 규칙.
//
// - 카드: v2 상태에서 이 화면이 방금 저장한 로비 스캔(없으면 관측 시각이 가장 늦은 스캔)의 후보 3명(표시 순서). 이름 = 상대
//   identity 현재 이름, 순위 = 후보 `opponent_rank`(없으면 '—'), 공개 칸 = 후보 스냅숏 덱의 1번 · SP1 · SP2, 족보 줄 = 그 공개
//   시그니처의 족보(FD-129 합집합, 최근 30일 기록 기준 승 많은 순 첫 카드) + 그 편성의 마지막 승리 시각, 내 전적 = 그 상대와의
//   내 공격 기록 승 · 패(기간 없음 — 통계가 아니라 내 기록 수).
// - FD-127 (a): 시안 카드의 "방어 승률 · 30일" 큰 수치 · 막대와 플라이아웃 기간별 "방어 n%"는 확률 지표라 만들지 않는다.
//   카드 "변경 의심" 칩은 추이 응답의 `changes`가 Dart DTO에 없어 만들지 않는다(XB 요청 후보, status).
// - 플라이아웃(시안 "최근 방어 덱 5종"): 그 상대의 방어 덱 관측(로비 스냅숏 · 내 공격 기록의 상대 방어 덱)을 시각 순으로 모아
//   공개 칸(1번 · SP1 · SP2) 학생이 같은 연속 구간을 한 줄로 묶는다(최근 5줄, 최신 먼저). 줄 = 기간(KST "M/D ~ M/D", 마지막
//   구간은 "M/D ~ 현재" + "현재" 칩) · 그 구간에서 가장 많이 아는 덱(모르는 칸 "?") · 그 구간의 내 공격 전적("기록 없음").
//   아래 "변경 주기 평균 n일" = 구간 시작 간격의 평균(구간이 하나면 '—').
// - 시작 판정: 홈 스캔 팝업 · 스캔 탭과 같은 이유와 순서(진행 · 검토 대기 → 백엔드 → 스캐너 → 게임 창 → 계정 → 인식 준비)이고
//   고르기 단계가 없다(종류 = 전술 로비 하나). 그 앞에 로비 저장 서비스 · 이관 전 판정이 있다. 게임 창이 없을 때만 버튼이 창 선택
//   패널을 연다(FD-155와 같은 패널).
// - 자동 채움: 고칠 수 있는 새 초안이면 그 초안에, 아니면 새 공격 초안에 상대 이름 · identity와 공개 칸 3개(`visible_lobby` ·
//   `lobby_scan`)를 넣는다. 2~4번 칸은 그대로 둔다(공개 칸 학생이 2~4번에 있으면 그 칸은 모름으로 바꾼다 — 덱 중복 금지).
import 'package:flutter/foundation.dart';

import '../../services/scanner_service.dart';
import '../../services/tactical_lobby_scanner_service.dart';
import '../../services/tactical_v2_service.dart';
import '../../tactical/tactical_records_controller.dart';
import '../home/home_scan_popup.dart'
    show HomeScanPopupBusy, homeScanPopupBusy, homeScanPopupBusyText;
import '../scan/scan_pick_logic.dart' show ScanStartBlock, scanStartNote;
import '../scan/scan_session_controller.dart';
import 'tactical_analysis_view.dart'
    show tacticalJokboShortName, tacticalSignatureDeck;
import 'tactical_jokbo_view.dart';
import 'tactical_records_view.dart';
import 'tactical_window.dart';

/// 제목 줄 상태 글자 색.
enum TacticalLobbyTone { muted, hint, ok, warn, error }

/// 제목 줄 글자(시안 `.cap`).
const tacticalLobbyCaption = '공개 슬롯 자동 기록';

/// 카드가 있을 때 제목 줄 글자(시안 "인식된 상대 3명 · 공개 슬롯 자동 기록").
String tacticalLobbyCountCaption(int count) =>
    '인식된 상대 $count명 · $tacticalLobbyCaption';

/// 로비 스캔 기록이 없을 때 카드 자리 글자.
const tacticalLobbyEmptyText = '아직 로비 스캔 기록이 없습니다. 지금 스캔으로 로비의 상대 3명을 읽습니다.';

const tacticalLobbyScanLabel = '지금 스캔';
const tacticalLobbyNoServiceText = '로비 스캔 저장 서비스가 제공되지 않습니다.';
const tacticalLobbyMigrationText = '이전 형식 기록을 가져온 뒤에 로비 스캔을 저장할 수 있습니다.';
const tacticalLobbyRecordsBusyText = '전술 기록을 읽거나 저장하는 중입니다.';
const tacticalLobbyHint = '로비에 보이는 상대 3명의 순위와 공개 슬롯(1번 · SP1 · SP2)을 읽어 저장합니다.';
const tacticalLobbyScanningText = '로비를 읽는 중입니다.';
const tacticalLobbySavingText = '로비 스캔을 저장하는 중입니다.';
const tacticalLobbyStartFailedText = '로비 스캔을 시작하지 못했습니다.';
const tacticalLobbyNoResultText = '로비 스캔이 끝났지만 읽은 결과가 없습니다.';
const tacticalLobbyFailedText = '로비 스캔이 실패했습니다.';
const tacticalLobbyCancelledText = '로비 스캔을 중지했습니다.';
const tacticalLobbyDecodeText = '로비 스캔 결과를 읽지 못했습니다. 다시 스캔해 주십시오.';
const tacticalLobbyReviewText =
    '로비 스캔 결과에 확인이 필요한 값(순위 · 이름)이 있어 저장하지 않았습니다. 다시 스캔해 주십시오.';
const tacticalLobbyConnectText = '게임 창을 연결하면 로비를 스캔할 수 있습니다.';
const tacticalLobbyLinkedText = '로비 관측과 이 기록을 이었습니다.';
const tacticalLobbyUnresolvedText =
    '같은 상대 · 공개 칸의 최근 로비 관측이 없어 잇지 않았습니다. 기록은 저장했습니다.';

/// 저장한 뒤 글자.
String tacticalLobbySavedText(int count) =>
    '로비 상대 $count명을 저장했습니다. 카드를 고르면 기록 작성에 상대가 채워집니다.';

/// 카드를 고른 뒤 글자.
String tacticalLobbyFilledText(String name) =>
    '고른 상대: $name · 저장하면 이 로비 관측과 잇습니다.';

/// 맞는 로비 관측이 여럿일 때.
String tacticalLobbyAmbiguousText(int? count) =>
    '맞는 로비 관측이 ${count ?? '여러'}개라 잇지 않았습니다. 기록은 저장했습니다.';

/// 로비 쓰기 종류(오류 문구가 다르다).
enum TacticalLobbyAction { commit, select, link }

/// 로비 쓰기 오류 → S2 글자. 기록 쓰기와 같은 코드(revision 충돌 · 이관 필요)는 컨트롤러 표 문구를 쓴다.
String tacticalLobbyErrorText(
  TacticalLobbyAction action,
  TacticalRecordsError error,
) {
  final specific = switch (error.code) {
    'review_required' => tacticalLobbyReviewText,
    'identity_ambiguous' =>
      '같은 이름의 상대가 여럿이라 로비 스캔을 저장하지 않았습니다. 상대 이름을 확인해 주십시오.',
    'opponent_not_found' => '이어 줄 상대를 찾지 못해 로비 스캔을 저장하지 않았습니다.',
    'candidate_not_found' => '고른 로비 상대를 찾지 못했습니다. 로비를 다시 스캔해 주십시오.',
    'link_review_required' => '기록 시각을 몰라 로비 관측과 잇지 않았습니다. 기록은 저장했습니다.',
    'link_conflict' => '이 로비 관측은 다른 기록과 이어져 있어 잇지 않았습니다. 기록은 저장했습니다.',
    'match_not_found' => '저장한 기록을 찾지 못해 로비 관측과 잇지 않았습니다.',
    'connection_failed' => switch (action) {
      TacticalLobbyAction.commit => '백엔드의 답을 받지 못해 로비 스캔을 저장하지 못했습니다.',
      TacticalLobbyAction.select => '백엔드의 답을 받지 못해 고른 상대를 남기지 못했습니다.',
      TacticalLobbyAction.link => '백엔드의 답을 받지 못해 로비 관측과 잇지 못했습니다. 기록은 저장했습니다.',
    },
    _ => null,
  };
  if (specific != null) return specific;
  final shared = tacticalRecordsErrorMessages[error.code];
  if (shared != null) return shared;
  return switch (action) {
    TacticalLobbyAction.commit => '로비 스캔을 저장하지 못했습니다.',
    TacticalLobbyAction.select => '고른 상대를 남기지 못했습니다. 저장해도 로비 관측과 잇지 못할 수 있습니다.',
    TacticalLobbyAction.link => '로비 관측과 기록을 잇지 못했습니다. 기록은 저장했습니다.',
  };
}

/// 링크 결과 → S2 글자 · 색.
({String text, TacticalLobbyTone tone}) tacticalLobbyLinkNotice(
  TacticalLinkResult result,
) => switch (result.status) {
  'automatic' ||
  'manual' => (text: tacticalLobbyLinkedText, tone: TacticalLobbyTone.ok),
  'ambiguous' => (
    text: tacticalLobbyAmbiguousText(result.candidateCount),
    tone: TacticalLobbyTone.warn,
  ),
  _ => (text: tacticalLobbyUnresolvedText, tone: TacticalLobbyTone.warn),
};

// --- 후보 -----------------------------------------------------------------------

/// 저장하기 전에 막을 이유(null = 보낼 수 있다). 백엔드는 `confirmed`가 아닌 후보 · 이름 없는 행을 `review_required`로 거부하고,
/// 순위가 없는 후보는 읽기 DTO(순위 ≥ 1 필수)를 깨므로 보내지 않는다.
String? tacticalLobbyCandidateBlocker(TacticalLobbyScanCandidate candidate) {
  if (candidate.reviewStatus != 'confirmed' ||
      candidate.currentRank == null ||
      candidate.rows.any(
        (row) => row.rank == null || (row.displayName?.trim().isEmpty ?? true),
      )) {
    return tacticalLobbyReviewText;
  }
  return null;
}

// --- 카드 -----------------------------------------------------------------------

/// 내 전적 칩 색(시안: 패 0 = ok, 승 0 = dg, 그 밖 = 파랑, 기록 없음 = gy).
enum TacticalLobbyRecordTone { none, ok, danger, info }

TacticalLobbyRecordTone tacticalLobbyRecordTone(int wins, int losses) {
  if (wins + losses == 0) return TacticalLobbyRecordTone.none;
  if (losses == 0) return TacticalLobbyRecordTone.ok;
  if (wins == 0) return TacticalLobbyRecordTone.danger;
  return TacticalLobbyRecordTone.info;
}

/// 승 · 패 글자("3승 0패", 없으면 "기록 없음").
String tacticalLobbyRecordText(int wins, int losses) =>
    wins + losses == 0 ? '기록 없음' : '$wins승 $losses패';

/// 로비 상대 카드 하나.
@immutable
class TacticalLobbyCard {
  const TacticalLobbyCard({
    required this.candidateId,
    required this.scanId,
    required this.displayIndex,
    required this.identityId,
    required this.name,
    required this.rank,
    required this.deck,
    required this.signature,
    required this.jokboText,
    required this.wins,
    required this.losses,
    required this.selectedAt,
  });

  final String candidateId, scanId, identityId, name;
  final int displayIndex;
  final int? rank;

  /// 로비 공개 덱(스냅숏). 2~4번은 보통 모름이다.
  final TacticalDeckV2 deck;

  /// 백엔드 공개 시그니처(`1번|SP1|SP2`, 모르면 `?`).
  final String signature;
  final String jokboText;
  final int wins, losses;

  /// 이 후보를 고른 시각(백엔드 `selected_at`). 고르지 않았으면 null.
  final String? selectedAt;

  /// 시안 "A 유저 · 23위".
  String get title => '$name · ${rank == null ? '—' : '$rank위'}';

  String get recordText => tacticalLobbyRecordText(wins, losses);
  TacticalLobbyRecordTone get recordTone =>
      tacticalLobbyRecordTone(wins, losses);

  /// 시안 aria "A 유저 · 23위 최근 방어 덱 5종 보기"(카드는 누르면 고르고, 올리면 이력이 보인다).
  String get semanticLabel => '$title · 최근 방어 덱 보기 · 누르면 기록 작성의 상대로 고릅니다';
}

/// 백엔드 `_public_signature`와 같은 문자열: 1번 · SP1 · SP2 학생(상태와 무관), 없으면 `?`.
String tacticalLobbySignature(TacticalDeckV2 deck) {
  final slots = tacticalDeckSlots(deck);
  return [
    for (final index in tacticalPublicSlotIndexes)
      slots[index].studentId ?? '?',
  ].join('|');
}

DateTime? _time(String? value) =>
    value == null ? null : DateTime.tryParse(value)?.toUtc();

/// 보일 로비 스캔: [preferredScanId](이 화면이 방금 저장한 것)가 있으면 그것, 없으면 관측 시각이 가장 늦은 것(같으면 ID 순 뒤).
TacticalLobbyScan? tacticalLobbyLatestScan(
  TacticalEvidenceState state, {
  String? preferredScanId,
}) {
  final preferred = state.lobbyScans
      .where((scan) => scan.id == preferredScanId)
      .firstOrNull;
  if (preferred != null) return preferred;
  TacticalLobbyScan? best;
  DateTime? bestTime;
  for (final scan in state.lobbyScans) {
    final time = _time(scan.observedAt);
    final current = bestTime;
    if (best == null ||
        (time != null && (current == null || time.isAfter(current))) ||
        (time != null &&
            current != null &&
            time.isAtSameMomentAs(current) &&
            scan.id.compareTo(best.id) > 0)) {
      best = scan;
      bestTime = time;
    }
  }
  return best;
}

/// [scan]의 카드(표시 순서). [matches]는 컨트롤러 기록 전체, [now]는 고정 시계다.
List<TacticalLobbyCard> tacticalLobbyCards({
  required TacticalEvidenceState state,
  required TacticalLobbyScan scan,
  required List<TacticalJokboEntry> jokbo,
  required List<TacticalMatchV2> matches,
  required DateTime now,
}) {
  final attacks = [
    for (final match in matches)
      if (match.kind == 'attack') match,
  ];
  final recent = tacticalRecentMatches(attacks, now).matches;
  final candidates = [
    for (final candidate in state.lobbyCandidates)
      if (candidate.scanId == scan.id) candidate,
  ]..sort((a, b) => a.displayIndex.compareTo(b.displayIndex));
  return [
    for (final candidate in candidates)
      () {
        final snapshot = state.snapshots
            .where((item) => item.id == candidate.snapshotId)
            .firstOrNull;
        final identity = state.opponents
            .where((item) => item.id == candidate.opponentIdentityId)
            .firstOrNull;
        final mine = [
          for (final match in attacks)
            if (match.opponentIdentityId == candidate.opponentIdentityId) match,
        ];
        return TacticalLobbyCard(
          candidateId: candidate.id,
          scanId: candidate.scanId,
          displayIndex: candidate.displayIndex,
          identityId: candidate.opponentIdentityId,
          name: identity?.currentDisplayName ?? '—',
          rank: candidate.opponentRank,
          deck:
              snapshot?.deck ??
              tacticalSignatureDeck(candidate.publicSignature),
          signature: candidate.publicSignature,
          jokboText: tacticalLobbyJokboText(
            signature: candidate.publicSignature,
            jokbo: jokbo,
            matches: recent,
            now: now,
          ),
          wins: mine.where((match) => match.result == 'win').length,
          losses: mine.where((match) => match.result == 'loss').length,
          selectedAt: candidate.selectedAt,
        );
      }(),
  ];
}

/// 카드 족보 줄(시안 "족보 A · 6h 전 검증" · "족보 없음"). 검증 = 그 편성의 마지막 승리 기록 시각.
String tacticalLobbyJokboText({
  required String signature,
  required List<TacticalJokboEntry> jokbo,
  required List<TacticalMatchV2> matches,
  required DateTime now,
}) {
  if (signature.split('|').every((part) => part == '?')) return '족보 없음';
  final cards = tacticalSignatureJokboCards(
    signature: signature,
    jokbo: jokbo,
    matches: matches,
  );
  final card = cards.firstOrNull;
  if (card == null) return '족보 없음';
  String? lastWin;
  DateTime? lastTime;
  for (final match in matches) {
    if (match.kind != 'attack' ||
        match.result != 'win' ||
        !tacticalMatchesJokboComposition(match, card.jokbo)) {
      continue;
    }
    final time = _time(match.occurredAt);
    final current = lastTime;
    if (time != null && (current == null || time.isAfter(current))) {
      lastTime = time;
      lastWin = match.occurredAt;
    }
  }
  final name = tacticalJokboShortName(card.name);
  return lastWin == null
      ? '$name · 검증 기록 없음'
      : '$name · ${tacticalAgoText(lastWin, now)} 검증';
}

/// 고른 카드: 이 화면에서 고른 것([localId])이 있으면 그것, 없으면 백엔드 `selected_at`이 가장 늦은 카드.
String? tacticalLobbySelectedId(
  List<TacticalLobbyCard> cards,
  String? localId,
) {
  if (cards.any((card) => card.candidateId == localId)) return localId;
  TacticalLobbyCard? best;
  DateTime? bestTime;
  for (final card in cards) {
    final time = _time(card.selectedAt);
    final current = bestTime;
    if (time != null && (current == null || time.isAfter(current))) {
      best = card;
      bestTime = time;
    }
  }
  return best?.candidateId;
}

// --- 플라이아웃(방어 이력) ----------------------------------------------------------

/// 플라이아웃 한 줄(공개 칸이 같은 연속 구간).
@immutable
class TacticalLobbyHistoryRow {
  const TacticalLobbyHistoryRow({
    required this.period,
    required this.current,
    required this.deck,
    required this.wins,
    required this.losses,
  });

  final String period;

  /// 가장 최근 구간(시안 "현재" 칩 · 왼쪽 분홍 막대).
  final bool current;
  final TacticalDeckV2 deck;
  final int wins, losses;

  String get recordText => tacticalLobbyRecordText(wins, losses);
  TacticalLobbyRecordTone get recordTone =>
      tacticalLobbyRecordTone(wins, losses);
}

/// 플라이아웃 값.
@immutable
class TacticalLobbyHistory {
  const TacticalLobbyHistory({
    required this.title,
    required this.rows,
    required this.cycleText,
  });

  /// 시안 "A 유저 · 23위 · 최근 방어 덱 5종".
  final String title;
  final List<TacticalLobbyHistoryRow> rows;

  /// 시안 "변경 주기 평균 6일"(구간이 하나면 "변경 주기 평균 —").
  final String cycleText;
}

/// 플라이아웃에 보이는 최대 줄 수(시안 5종).
const tacticalLobbyHistoryLimit = 5;

/// 플라이아웃 머리 오른쪽 글자(시안 "방어 승률 · 내 전적 · ? = 비공개", FD-127로 방어 승률을 뺐다).
const tacticalLobbyHistoryLegend = '내 전적 · ? = 비공개';

String _shortDate(DateTime utc) {
  final kst = utc.add(const Duration(hours: 9));
  return '${kst.month}/${kst.day}';
}

int _knownSlots(TacticalDeckV2 deck) =>
    tacticalDeckSlots(deck).where((slot) => slot.studentId != null).length;

/// [card] 상대의 방어 덱 이력(최신 먼저, 최대 [tacticalLobbyHistoryLimit]줄).
TacticalLobbyHistory tacticalLobbyHistory({
  required TacticalLobbyCard card,
  required TacticalEvidenceState state,
  required List<TacticalMatchV2> matches,
}) {
  final observations = <({DateTime time, TacticalDeckV2 deck, String? result})>[
    for (final snapshot in state.snapshots)
      if (snapshot.opponentIdentityId == card.identityId)
        if (_time(snapshot.observedAt ?? snapshot.occurredAt) case final time?)
          (time: time, deck: snapshot.deck, result: null),
    for (final match in matches)
      if (match.kind == 'attack' && match.opponentIdentityId == card.identityId)
        if (_time(match.occurredAt) case final time?)
          (time: time, deck: match.defenseDeck, result: match.result),
  ]..sort((a, b) => a.time.compareTo(b.time));
  final groups =
      <
        ({
          String signature,
          DateTime start,
          DateTime end,
          TacticalDeckV2 deck,
          int wins,
          int losses,
        })
      >[];
  for (final item in observations) {
    final signature = tacticalLobbySignature(item.deck);
    if (signature.split('|').every((part) => part == '?')) continue;
    final win = item.result == 'win' ? 1 : 0;
    final loss = item.result == 'loss' ? 1 : 0;
    final last = groups.lastOrNull;
    if (last != null && last.signature == signature) {
      groups[groups.length - 1] = (
        signature: signature,
        start: last.start,
        end: item.time,
        // 그 구간에서 가장 많이 아는 덱(같으면 나중 관측).
        deck: _knownSlots(item.deck) >= _knownSlots(last.deck)
            ? item.deck
            : last.deck,
        wins: last.wins + win,
        losses: last.losses + loss,
      );
    } else {
      groups.add((
        signature: signature,
        start: item.time,
        end: item.time,
        deck: item.deck,
        wins: win,
        losses: loss,
      ));
    }
  }
  final rows = <TacticalLobbyHistoryRow>[
    for (final (index, group) in groups.reversed.indexed)
      if (index < tacticalLobbyHistoryLimit)
        TacticalLobbyHistoryRow(
          period: index == 0
              ? '${_shortDate(group.start)} ~ 현재'
              : '${_shortDate(group.start)} ~ ${_shortDate(group.end)}',
          current: index == 0,
          deck: group.deck,
          wins: group.wins,
          losses: group.losses,
        ),
  ];
  String cycle = '—';
  if (groups.length >= 2) {
    final span = groups.last.start.difference(groups.first.start);
    final days = span.inMinutes / Duration.minutesPerDay / (groups.length - 1);
    cycle = days < 1 ? '1일 미만' : '${days.round()}일';
  }
  return TacticalLobbyHistory(
    title: '${card.title} · 최근 방어 덱 ${rows.length}종',
    rows: List.unmodifiable(rows),
    cycleText: '변경 주기 평균 $cycle',
  );
}

// --- 시작 판정 ----------------------------------------------------------------------

/// "지금 스캔"을 막는 이유. [none]이면 시작할 수 있고, [noTarget]이면 버튼이 창 선택 패널을 연다.
enum TacticalLobbyStartBlock {
  none,
  noService,
  migration,
  recordsBusy,
  session,
  review,
  backend,
  unavailable,
  noTarget,
  targetNotReady,
  profile,
  checkingRecognition,
  recognition,
  busy,
}

/// 홈 스캔 팝업 · 스캔 탭과 같은 판정(고르기 없음). [lobbyAvailable]은 로비 저장 서비스가 있는가, [recordsBusy]는 전술
/// 컨트롤러가 읽거나 쓰는 중인가다.
TacticalLobbyStartBlock tacticalLobbyStartBlock(
  ScanSessionController? scan, {
  required bool lobbyAvailable,
  required bool migrationRequired,
  required bool recordsBusy,
  Set<String> appliedElsewhere = const {},
}) {
  if (scan == null || !lobbyAvailable) return TacticalLobbyStartBlock.noService;
  if (migrationRequired) return TacticalLobbyStartBlock.migration;
  final busy = homeScanPopupBusy(scan, appliedElsewhere: appliedElsewhere);
  if (busy == HomeScanPopupBusy.session) return TacticalLobbyStartBlock.session;
  if (busy == HomeScanPopupBusy.review) return TacticalLobbyStartBlock.review;
  if (!scan.connected) return TacticalLobbyStartBlock.backend;
  if (!scan.scannerAvailable || !scan.repositoryAvailable) {
    return TacticalLobbyStartBlock.unavailable;
  }
  final target = scan.selectedTarget;
  if (target == null) return TacticalLobbyStartBlock.noTarget;
  if (target.status != ScannerTargetStatus.ready) {
    return TacticalLobbyStartBlock.targetNotReady;
  }
  if (scan.profile == null) return TacticalLobbyStartBlock.profile;
  if (!scan.recognitionReady) {
    return scan.readinessLoading
        ? TacticalLobbyStartBlock.checkingRecognition
        : TacticalLobbyStartBlock.recognition;
  }
  if (recordsBusy) return TacticalLobbyStartBlock.recordsBusy;
  if (!scan.canStart) return TacticalLobbyStartBlock.busy;
  return TacticalLobbyStartBlock.none;
}

/// 버튼 툴팁 · 막힌 이유 글자. 스캔 판정은 스캔 탭 글자(`scanStartNote`)와 같다.
String tacticalLobbyStartText(
  TacticalLobbyStartBlock block,
  ScanSessionController? scan,
) {
  if (scan == null) return tacticalLobbyNoServiceText;
  String note(ScanStartBlock value) => scanStartNote(value, scan);
  return switch (block) {
    TacticalLobbyStartBlock.none => tacticalLobbyHint,
    TacticalLobbyStartBlock.noService => tacticalLobbyNoServiceText,
    TacticalLobbyStartBlock.migration => tacticalLobbyMigrationText,
    TacticalLobbyStartBlock.recordsBusy => tacticalLobbyRecordsBusyText,
    TacticalLobbyStartBlock.session => homeScanPopupBusyText(
      HomeScanPopupBusy.session,
      scan,
    ),
    TacticalLobbyStartBlock.review => homeScanPopupBusyText(
      HomeScanPopupBusy.review,
      scan,
    ),
    TacticalLobbyStartBlock.backend => note(ScanStartBlock.backend),
    TacticalLobbyStartBlock.unavailable => note(ScanStartBlock.unavailable),
    TacticalLobbyStartBlock.noTarget => tacticalLobbyConnectText,
    TacticalLobbyStartBlock.targetNotReady => note(
      ScanStartBlock.targetNotReady,
    ),
    TacticalLobbyStartBlock.profile => note(ScanStartBlock.profile),
    TacticalLobbyStartBlock.checkingRecognition => note(
      ScanStartBlock.checkingRecognition,
    ),
    TacticalLobbyStartBlock.recognition => note(ScanStartBlock.recognition),
    TacticalLobbyStartBlock.busy => note(ScanStartBlock.busy),
  };
}

// --- 자동 채움 ------------------------------------------------------------------------

/// [draft]에 [card]의 상대 이름 · identity와 공개 칸(1번 · SP1 · SP2)을 넣은 공격 초안. 공개 칸은 로비 관측(`visible_lobby` ·
/// `lobby_scan`)이고, 로비에서 모른 공개 칸은 모름이다. 공개 칸 학생이 2~4번에 있으면 그 칸을 모름으로 바꾼다.
TacticalRecordDraft tacticalDraftWithLobby(
  TacticalRecordDraft draft,
  TacticalLobbyCard card,
) {
  final source = tacticalDeckSlots(card.deck);
  final slots = [...tacticalDeckSlots(draft.opponentDeck)];
  final public = <String>{};
  for (final index in tacticalPublicSlotIndexes) {
    final position = index < 4 ? index : index - 4;
    final from = source[index];
    final studentId = from.studentId;
    if (studentId == null) {
      slots[index] = tacticalManualSlot(position, null);
      continue;
    }
    public.add(studentId);
    slots[index] = TacticalSlotObservation(
      position: position,
      studentId: studentId,
      state: 'visible_lobby',
      source: 'lobby_scan',
      confidence: from.confidence,
      reviewStatus: 'confirmed',
      wildcard: false,
    );
  }
  for (var index = 1; index < 4; index++) {
    if (public.contains(slots[index].studentId)) {
      slots[index] = tacticalManualSlot(index, null);
    }
  }
  return draft.copyWith(
    kind: 'attack',
    opponentName: card.name,
    opponentIdentityId: card.identityId,
    opponentDeck: TacticalDeckV2(
      strikers: slots.sublist(0, 4),
      specials: slots.sublist(4),
    ),
  );
}

/// 후보 하나의 열쇠(세션 · generation · id · revision) — 같은 후보를 두 번 저장하지 않는다.
String tacticalLobbyCandidateKey(ScannerCandidate candidate) =>
    '${candidate.sessionId}#${candidate.generation}#${candidate.id}#${candidate.revision}';

/// 스캔 탭에서 넘긴 전술 로비 후보(셸 `_handoffCandidate`, FE9-c). 전술 화면이 받으면 저장한다(같은 후보는 한 번).
@immutable
class TacticalLobbyHandoff {
  const TacticalLobbyHandoff({required this.session, required this.candidate});

  final ScannerSession session;
  final ScannerCandidate candidate;
}
