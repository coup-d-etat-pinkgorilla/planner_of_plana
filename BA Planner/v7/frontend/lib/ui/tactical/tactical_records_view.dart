// FE9-a: 전술 기록 화면의 위젯 없는 모델 — 작성 초안, 목록 행, 필터, 출처 범례.
//
// - 초안([TacticalRecordDraft])은 "내 덱 · 상대 덱"으로 들고 있다가 저장할 때 종류에 따라 공격 · 방어 덱으로 옮긴다
//   (공격 = 내 공격 덱 + 상대 방어 덱, 방어 = 상대 공격 덱 + 내 방어 덱). 종류를 바꿔도 화면에 보이는 두 덱은 그대로다.
// - 칸을 고치지 않으면 읽은 관측(상태 · 출처 · 와일드카드)을 그대로 되보낸다. 학생을 고르면 `manual` 관측, "빈칸"을
//   고르면 `unknown`(모름 — 빗금)이다. 확인된 빈칸(`empty`)은 읽은 그대로만 보인다.
// - v1 기록(이관 전)은 읽기 전용 초안 · 행으로만 보인다(저장 · 삭제 없음).
// - 방어 기록 행 표기(FD-132 권장안): "내 방어덱 · vs <상대>"(v2는 상대 이름이 늘 있다).
// - 시각: `date` 정밀도는 날짜만, `instant`는 KST, 모르면 '—'(컨트롤러 [tacticalOccurredText]). 시도 횟수를 모르면 '—'.
import 'package:flutter/foundation.dart';

import '../../services/tactical_service.dart';
import '../../services/tactical_v2_service.dart';
import '../../tactical/tactical_records_controller.dart';

/// 덱 한 칸의 채움.
enum TacticalSlotFill {
  /// 학생이 있다.
  student,

  /// 모른다(빗금 "빈칸"). 와일드카드도 여기다.
  unknown,

  /// 확인된 빈칸(학생 없음).
  empty,
}

/// 칸 위치 이름: 1~4, SP1 · SP2. [index]는 0~5(스트라이커 4 + 스페셜 2).
String tacticalSlotLabel(int index) =>
    index < 4 ? '${index + 1}' : 'SP${index - 3}';

/// 덱 6칸(스트라이커 4 + 스페셜 2) 관측.
List<TacticalSlotObservation> tacticalDeckSlots(TacticalDeckV2 deck) => [
  ...deck.strikers,
  ...deck.specials,
];

TacticalSlotFill tacticalSlotFill(TacticalSlotObservation slot) =>
    slot.studentId != null
    ? TacticalSlotFill.student
    : slot.state == 'empty' && !slot.wildcard
    ? TacticalSlotFill.empty
    : TacticalSlotFill.unknown;

/// 사용자가 고친 칸의 관측. [studentId]가 null이면 모름(빗금 빈칸)이다.
TacticalSlotObservation tacticalManualSlot(int position, String? studentId) =>
    TacticalSlotObservation(
      position: position,
      studentId: studentId,
      state: studentId == null ? 'unknown' : 'manual',
      source: 'manual',
      confidence: null,
      reviewStatus: 'confirmed',
      wildcard: false,
    );

/// 6칸 모두 모름인 덱.
TacticalDeckV2 tacticalUnknownDeck() => TacticalDeckV2(
  strikers: [for (var i = 0; i < 4; i++) tacticalManualSlot(i, null)],
  specials: [for (var i = 0; i < 2; i++) tacticalManualSlot(i, null)],
);

/// [deck]의 [index](0~5)번 칸을 [studentId](null = 모름)로 바꾼 덱.
TacticalDeckV2 tacticalDeckWithSlot(
  TacticalDeckV2 deck,
  int index,
  String? studentId,
) {
  final strikers = [...deck.strikers];
  final specials = [...deck.specials];
  if (index < 4) {
    strikers[index] = tacticalManualSlot(index, studentId);
  } else {
    specials[index - 4] = tacticalManualSlot(index - 4, studentId);
  }
  return TacticalDeckV2(strikers: strikers, specials: specials);
}

/// v1 덱(학생 ID, null = 모름) → 표시용 v2 덱. 중복 학생이 있으면 모두 모름으로 둔다(v1 읽기 전용 표시).
TacticalDeckV2 tacticalDeckFromLegacy(TacticalDeck deck) {
  try {
    return TacticalDeckV2(
      strikers: [
        for (final (index, id) in deck.strikers.indexed)
          tacticalManualSlot(index, id),
      ],
      specials: [
        for (final (index, id) in deck.specials.indexed)
          tacticalManualSlot(index, id),
      ],
    );
  } on FormatException {
    return tacticalUnknownDeck();
  }
}

/// 기록 작성 초안.
@immutable
class TacticalRecordDraft {
  const TacticalRecordDraft({
    required this.id,
    required this.kind,
    required this.result,
    required this.attemptCount,
    required this.opponentName,
    required this.opponentIdentityId,
    required this.myDeck,
    required this.opponentDeck,
    required this.notes,
    required this.season,
    required this.occurredAt,
    required this.occurredPrecision,
    this.readOnly = false,
  });

  /// 새 공격 기록(승리 · 시도 1 · 덱 모두 모름).
  factory TacticalRecordDraft.blank({String season = ''}) =>
      TacticalRecordDraft(
        id: null,
        kind: 'attack',
        result: 'win',
        attemptCount: 1,
        opponentName: '',
        opponentIdentityId: null,
        myDeck: tacticalUnknownDeck(),
        opponentDeck: tacticalUnknownDeck(),
        notes: '',
        season: season,
        occurredAt: null,
        occurredPrecision: 'unknown',
      );

  /// 저장된 v2 기록을 고친다.
  factory TacticalRecordDraft.fromMatch(TacticalMatchV2 match) {
    final attack = match.kind == 'attack';
    return TacticalRecordDraft(
      id: match.id,
      kind: match.kind,
      result: match.result,
      attemptCount: match.attemptCount,
      opponentName: match.opponentDisplayName,
      opponentIdentityId: match.opponentIdentityId,
      myDeck: attack ? match.attackDeck : match.defenseDeck,
      opponentDeck: attack ? match.defenseDeck : match.attackDeck,
      notes: match.notes,
      season: match.season,
      occurredAt: match.occurredAt,
      occurredPrecision: match.occurredPrecision,
    );
  }

  /// 이관 전 v1 기록(읽기 전용). 날짜는 `date` 정밀도로 보인다.
  factory TacticalRecordDraft.fromLegacy(TacticalMatch match) {
    final attack = match.kind == 'attack';
    final attackDeck = tacticalDeckFromLegacy(match.attackDeck);
    final defenseDeck = tacticalDeckFromLegacy(match.defenseDeck);
    return TacticalRecordDraft(
      id: match.id,
      kind: match.kind,
      result: match.result,
      attemptCount: null,
      opponentName: match.opponent,
      opponentIdentityId: null,
      myDeck: attack ? attackDeck : defenseDeck,
      opponentDeck: attack ? defenseDeck : attackDeck,
      notes: match.notes,
      season: match.season,
      occurredAt: match.occurredOn,
      occurredPrecision: match.occurredOn == null ? 'unknown' : 'legacy-date',
      readOnly: true,
    );
  }

  /// 저장된 기록 ID. null이면 새 기록(복제 포함)이다.
  final String? id;
  final String kind, result;

  /// 시도 횟수. null = 모름(이관 기록) — 정해야 저장할 수 있다(계약: 1 이상).
  final int? attemptCount;
  final String opponentName;
  final String? opponentIdentityId;
  final TacticalDeckV2 myDeck, opponentDeck;
  final String notes, season;
  final String? occurredAt;

  /// `date` · `instant` · `unknown`, v1 읽기 전용 날짜는 `legacy-date`.
  final String occurredPrecision;
  final bool readOnly;

  bool get attack => kind == 'attack';
  bool get isNew => id == null;

  TacticalRecordDraft copyWith({
    String? kind,
    String? result,
    int? attemptCount,
    bool clearAttempt = false,
    String? opponentName,
    String? opponentIdentityId,
    bool clearIdentity = false,
    TacticalDeckV2? myDeck,
    TacticalDeckV2? opponentDeck,
    String? notes,
  }) => TacticalRecordDraft(
    id: id,
    kind: kind ?? this.kind,
    result: result ?? this.result,
    attemptCount: clearAttempt ? null : attemptCount ?? this.attemptCount,
    opponentName: opponentName ?? this.opponentName,
    opponentIdentityId: clearIdentity
        ? null
        : opponentIdentityId ?? this.opponentIdentityId,
    myDeck: myDeck ?? this.myDeck,
    opponentDeck: opponentDeck ?? this.opponentDeck,
    notes: notes ?? this.notes,
    season: season,
    occurredAt: occurredAt,
    occurredPrecision: occurredPrecision,
    readOnly: readOnly,
  );

  /// "복제해서 새 기록": ID · 시각을 비운 같은 내용의 새 초안(아직 저장하지 않는다).
  TacticalRecordDraft duplicate() => TacticalRecordDraft(
    id: null,
    kind: kind,
    result: result,
    attemptCount: attemptCount,
    opponentName: opponentName,
    opponentIdentityId: opponentIdentityId,
    myDeck: myDeck,
    opponentDeck: opponentDeck,
    notes: notes,
    season: season,
    occurredAt: null,
    occurredPrecision: 'unknown',
  );

  /// 저장 입력. 새 기록은 [newId] · [now](UTC, `instant`)를 쓴다. [identityId]는 이름으로 고른 상대 identity다.
  TacticalMatchInputV2 toInput({
    required String Function() newId,
    required String identityId,
    required DateTime now,
  }) {
    final attempt = attemptCount;
    if (attempt == null || readOnly) {
      throw StateError('draft is not savable');
    }
    final name = opponentName.trim();
    return TacticalMatchInputV2(
      id: id ?? newId(),
      kind: kind,
      occurredAt: isNew ? tacticalUtcInstant(now) : occurredAt,
      occurredPrecision: isNew ? 'instant' : occurredPrecision,
      season: season,
      opponentIdentityId: identityId,
      opponentDisplayName: name,
      result: result,
      attackDeck: attack ? myDeck : opponentDeck,
      defenseDeck: attack ? opponentDeck : myDeck,
      notes: notes,
      attemptCount: attempt,
    );
  }

  /// 머리 줄: "공격 기록 · 2026-10-04 21:10", 새 기록은 "새 공격 기록".
  String get headerText {
    final kindText = attack ? '공격' : '방어';
    if (isNew) return '새 $kindText 기록';
    return '$kindText 기록 · ${occurredText(occurredAt, occurredPrecision)}';
  }
}

/// `2026-10-14T12:00:00Z`(초까지, UTC).
String tacticalUtcInstant(DateTime now) {
  final utc = now.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
      '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}

/// 시각 표시(정밀도 규칙). v1 날짜(`legacy-date`)는 저장된 문자열 그대로다.
String occurredText(String? occurredAt, String precision) =>
    switch (precision) {
      'date' => tacticalKstDateText(occurredAt),
      'instant' => tacticalKstInstantText(occurredAt),
      'legacy-date' => occurredAt ?? '—',
      _ => '—',
    };

/// 시도 횟수 보조 문구(시안 "첫 시도 성공").
String tacticalAttemptNote(String result, int? attempt) {
  if (attempt == null) return '시도 횟수 모름';
  if (result == 'win') return attempt == 1 ? '첫 시도 성공' : '$attempt번째 시도에 성공';
  return '$attempt회 시도 · 패배';
}

/// 목록 행 하나.
@immutable
class TacticalRecordRow {
  const TacticalRecordRow({
    required this.key,
    required this.draft,
    required this.legacy,
    this.sourceRecordId,
  });

  /// `v2:<id>` · `v1:<id>`.
  final String key;
  final TacticalRecordDraft draft;
  final bool legacy;

  /// v2 기록의 원본 ID(이관 기록은 `v7-v1:match:<v1 ID>`). v1 행은 null.
  final String? sourceRecordId;

  String get kind => draft.kind;
  String get result => draft.result;
  String get season => draft.season;
  String get opponentName => draft.opponentName;

  /// FD-132: 공격 "vs <상대>", 방어 "내 방어덱 · vs <상대>". 상대 이름이 없으면(v1) "내 방어덱".
  String get opponentLabel {
    final name = draft.opponentName.trim();
    if (draft.attack) return name.isEmpty ? 'vs —' : 'vs $name';
    return name.isEmpty ? '내 방어덱' : '내 방어덱 · vs $name';
  }

  /// "1회 · 2026-10-04 21:10"(시도 모름은 '—').
  String get metaText {
    final attempt = draft.attemptCount;
    return '${attempt == null ? '—' : '$attempt회'} · '
        '${occurredText(draft.occurredAt, draft.occurredPrecision)}';
  }
}

/// 컨트롤러의 v2 기록(시각 최신 순) 뒤에 이관 전 v1 기록(날짜 최신 순, 읽기 전용)을 붙인다.
List<TacticalRecordRow> tacticalRecordRows(
  List<TacticalMatchV2> matches, {
  List<TacticalMatch> legacy = const [],
}) {
  final old = [...legacy]
    ..sort((a, b) {
      final order = (b.occurredOn ?? '').compareTo(a.occurredOn ?? '');
      return order != 0 ? order : a.id.compareTo(b.id);
    });
  return [
    for (final match in matches)
      TacticalRecordRow(
        key: 'v2:${match.id}',
        draft: TacticalRecordDraft.fromMatch(match),
        legacy: false,
        sourceRecordId: match.sourceRecordId,
      ),
    for (final match in old)
      TacticalRecordRow(
        key: 'v1:${match.id}',
        draft: TacticalRecordDraft.fromLegacy(match),
        legacy: true,
      ),
  ];
}

/// 목록 필터(시안 칩: 전체 · 공격 · 방어 · 이번 시즌 · 상대, + 결과 승 · 패).
@immutable
class TacticalRecordFilter {
  const TacticalRecordFilter({
    this.kind,
    this.result,
    this.currentSeason = false,
    this.opponent,
  });

  /// `attack` · `defense`, null = 전체.
  final String? kind;

  /// `win` · `loss`, null = 전체.
  final String? result;

  /// "이번 시즌": 가장 최근 기록의 시즌만.
  final bool currentSeason;

  /// 상대 이름, null = 전체.
  final String? opponent;

  bool get isAll =>
      kind == null && result == null && !currentSeason && opponent == null;

  TacticalRecordFilter copyWith({
    String? kind,
    bool clearKind = false,
    String? result,
    bool clearResult = false,
    bool? currentSeason,
    String? opponent,
    bool clearOpponent = false,
  }) => TacticalRecordFilter(
    kind: clearKind ? null : kind ?? this.kind,
    result: clearResult ? null : result ?? this.result,
    currentSeason: currentSeason ?? this.currentSeason,
    opponent: clearOpponent ? null : opponent ?? this.opponent,
  );
}

/// "이번 시즌": 목록 맨 위(가장 최근)부터 처음 나오는 비어 있지 않은 시즌. 없으면 null.
String? tacticalCurrentSeason(List<TacticalRecordRow> rows) {
  for (final row in rows) {
    if (row.season.trim().isNotEmpty) return row.season;
  }
  return null;
}

List<TacticalRecordRow> tacticalFilterRows(
  List<TacticalRecordRow> rows,
  TacticalRecordFilter filter,
) {
  final season = filter.currentSeason ? tacticalCurrentSeason(rows) : null;
  return [
    for (final row in rows)
      if ((filter.kind == null || row.kind == filter.kind) &&
          (filter.result == null || row.result == filter.result) &&
          (season == null || row.season == season) &&
          (filter.opponent == null || row.opponentName == filter.opponent))
        row,
  ];
}

/// 상대 이름 목록(목록에 나온 순서, 중복 없음)과 기록 수.
List<({String name, int count})> tacticalOpponentOptions(
  List<TacticalRecordRow> rows,
) {
  final counts = <String, int>{};
  for (final row in rows) {
    final name = row.opponentName.trim();
    if (name.isEmpty) continue;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  return [
    for (final entry in counts.entries) (name: entry.key, count: entry.value),
  ];
}

/// 이름에 맞는 상대 identity(현재 이름 또는 별칭이 같다). 없으면 null.
String? tacticalIdentityForName(
  List<TacticalOpponentIdentity> opponents,
  String name,
) {
  final trimmed = name.trim();
  for (final opponent in opponents) {
    if (opponent.currentDisplayName == trimmed ||
        opponent.aliases.contains(trimmed)) {
      return opponent.id;
    }
  }
  return null;
}

/// 출처 범례 칩 하나(시안 "공개 · 1 · SP 로비 스캔", "기록 · 2 · 3 지난 기록", "빈칸 · 4 기록 없음").
@immutable
class TacticalSourceLegendItem {
  const TacticalSourceLegendItem({
    required this.label,
    required this.positions,
    required this.description,
  });

  final String label;

  /// 위치 이름(없으면 '—').
  final String positions;
  final String description;

  String get text => '$positions $description';
}

/// [deck]의 출처 범례: 공개 = 로비 스캔 공개 슬롯(`visible_lobby`), 기록 = 학생이 있는 그 밖의 칸, 빈칸 = 학생 없는 칸.
List<TacticalSourceLegendItem> tacticalSourceLegend(TacticalDeckV2 deck) {
  final slots = tacticalDeckSlots(deck);
  String names(bool Function(TacticalSlotObservation slot) test) {
    final labels = [
      for (final (index, slot) in slots.indexed)
        if (test(slot)) tacticalSlotLabel(index),
    ];
    return labels.isEmpty ? '—' : labels.join(' · ');
  }

  return [
    TacticalSourceLegendItem(
      label: '공개',
      positions: names(
        (slot) => slot.studentId != null && slot.state == 'visible_lobby',
      ),
      description: '로비 스캔',
    ),
    TacticalSourceLegendItem(
      label: '기록',
      positions: names(
        (slot) => slot.studentId != null && slot.state != 'visible_lobby',
      ),
      description: '지난 기록',
    ),
    TacticalSourceLegendItem(
      label: '빈칸',
      positions: names((slot) => slot.studentId == null),
      description: '기록 없음',
    ),
  ];
}

/// [draft]와 같은 편성(방어 · 공격 덱 identity)의 족보가 있는가(시안 "같은 시그니처 족보에 자동 연결됨").
bool tacticalDraftLinked(
  TacticalRecordDraft draft,
  List<TacticalJokboEntry> jokbo,
) {
  if (draft.isNew || draft.readOnly || !draft.attack) return false;
  final defense = tacticalDeckIdentity(draft.opponentDeck);
  final attack = tacticalDeckIdentity(draft.myDeck);
  return jokbo.any(
    (entry) =>
        listEquals(tacticalDeckIdentity(entry.jokbo.defenseDeck), defense) &&
        listEquals(tacticalDeckIdentity(entry.jokbo.attackDeck), attack),
  );
}
