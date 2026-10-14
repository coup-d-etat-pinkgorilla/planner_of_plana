// FE9-b1: design-review 검수 시나리오의 전술 v2 seed(기록 4 · 자동 족보 2 · 이관 완료 상태).
//
// 계정에 v1 기록이 없으므로 첫 v2 기록 저장이 같은 쓰기에서 v2를 유일한 저장소로 만든다(이관 미리보기
// `v1_writes_disabled` = true). 기록은 시각 정밀도 세 가지(instant · date · unknown)와 시도 횟수 1 · 2 · 3, 모름 칸 · 빈칸이
// 든 부분 방어 덱을 모두 보인다. 공격 기록 3개는 편성 두 쌍이라 자동 족보(`lineage-`)가 2개 생긴다.
// 스페셜 칸(SP1 · SP2)에는 카탈로그 `combat_class`가 special인 학생만 둔다(tidy2: SP2 `chise`(스트라이커) → 공격 덱 A `hanae`,
// 게헨나 방어 덱 `ako` — 기본 Mock · 검수 시나리오 모두 보유 학생, FE9-a 발견 8).
import '../tactical_v2_service.dart';

const designReviewTacticalOpponentA = 'dr-opponent-gehenna';
const designReviewTacticalOpponentB = 'dr-opponent-abydos';

TacticalSlotObservation _slot(
  int position,
  String? studentId, {
  String? state,
}) => TacticalSlotObservation(
  position: position,
  studentId: studentId,
  state: state ?? (studentId == null ? 'unknown' : 'manual'),
  source: 'manual',
  confidence: null,
  reviewStatus: 'confirmed',
  wildcard: false,
);

/// [strikers] 4칸 · [specials] 2칸. null = 모름 칸, `'empty'` = 확인된 빈칸.
TacticalDeckV2 _deck(List<String?> strikers, List<String?> specials) {
  TacticalSlotObservation slot(int position, String? value) => value == 'empty'
      ? _slot(position, null, state: 'empty')
      : _slot(position, value);
  return TacticalDeckV2(
    strikers: [for (final (index, id) in strikers.indexed) slot(index, id)],
    specials: [for (final (index, id) in specials.indexed) slot(index, id)],
  );
}

final _gehennaDefense = _deck(
  ['hina', 'iori', 'aru', 'haruka'],
  ['hibiki', 'ako'],
);
final _abydosDefense = _deck(
  ['aru', 'haruna', null, null],
  ['hibiki', 'empty'],
);
final _attackA = _deck(
  ['hoshino', 'izuna', 'mika', 'kayoko'],
  ['ayane', 'hanae'],
);
final _attackB = _deck(
  ['haruna', 'mutsuki', 'hoshino', 'izuna'],
  ['ayane', 'hibiki'],
);

/// 저장 순서대로의 seed 기록(첫 저장 revision 0, 하나씩 오른다).
List<TacticalMatchInputV2> designReviewTacticalMatches() => [
  TacticalMatchInputV2(
    id: 'dr-match-1',
    kind: 'attack',
    occurredAt: '2026-10-04T21:10:00+09:00',
    occurredPrecision: 'instant',
    season: '10',
    opponentIdentityId: designReviewTacticalOpponentA,
    opponentDisplayName: '게헨나 선도부',
    result: 'win',
    attackDeck: _attackA,
    defenseDeck: _gehennaDefense,
    notes: '첫 시도에 돌파했습니다.',
    attemptCount: 1,
  ),
  TacticalMatchInputV2(
    id: 'dr-match-2',
    kind: 'attack',
    occurredAt: '2026-10-03T20:30:00+09:00',
    occurredPrecision: 'instant',
    season: '10',
    opponentIdentityId: designReviewTacticalOpponentA,
    opponentDisplayName: '게헨나 선도부',
    result: 'loss',
    attackDeck: _attackA,
    defenseDeck: _gehennaDefense,
    notes: '',
    attemptCount: 3,
  ),
  TacticalMatchInputV2(
    id: 'dr-match-3',
    kind: 'attack',
    occurredAt: '2026-10-02T00:00:00+09:00',
    occurredPrecision: 'date',
    season: '10',
    opponentIdentityId: designReviewTacticalOpponentB,
    opponentDisplayName: '아비도스 대책위원회',
    result: 'win',
    attackDeck: _attackB,
    defenseDeck: _abydosDefense,
    notes: '',
    attemptCount: 2,
  ),
  TacticalMatchInputV2(
    id: 'dr-match-4',
    kind: 'defense',
    occurredAt: null,
    occurredPrecision: 'unknown',
    season: '10',
    opponentIdentityId: designReviewTacticalOpponentB,
    opponentDisplayName: '아비도스 대책위원회',
    result: 'win',
    attackDeck: _abydosDefense,
    defenseDeck: _gehennaDefense,
    notes: '',
    attemptCount: 1,
  ),
];
