// FE9-b1: design-review 검수 시나리오의 전술 v2 seed(기록 6 · 자동 족보 2 · 이관 완료 상태).
//
// 계정에 v1 기록이 없으므로 첫 v2 기록 저장이 같은 쓰기에서 v2를 유일한 저장소로 만든다(이관 미리보기
// `v1_writes_disabled` = true). 기록은 시각 정밀도 세 가지(instant · date · unknown)와 시도 횟수 1 · 2 · 3, 모름 칸 · 빈칸이
// 든 부분 방어 덱을 모두 보인다. 공격 기록 3개는 편성 두 쌍이라 자동 족보(`lineage-`)가 2개 생긴다.
// 스페셜 칸(SP1 · SP2)에는 카탈로그 `combat_class`가 special인 학생만 둔다(tidy2: SP2 `chise`(스트라이커) → 공격 덱 A `hanae`,
// 게헨나 방어 덱 `ako` — 기본 Mock · 검수 시나리오 모두 보유 학생, FE9-a 발견 8).
// FE9-d: 공격 기록의 상대 방어 덱은 로비 공개 칸(1번 · SP1 · SP2)이 `visible_lobby`(출처 `lobby_scan`)다. 게헨나 선도부와
// 아비도스 대책위원회의 방어 덱이 같은 공개 시그니처(히나 | 히비키 | 아코)라, 게헨나 기록을 고르면 S4에 족보 2개(완전 덱 ·
// 부분 덱, FD-129 합집합)가 보인다. 아비도스 방어 덱은 2번이 기록, 3번이 모름, 4번이 확인된 빈칸이다. 방어 기록의 덱(내 방어 덱 ·
// 상대 공격 덱)은 공개 칸이 없다.
// FE9-b2(FD-176): 방어 기록 2개를 더한다 — 시도 횟수를 모르는 아비도스 방어 기록(`dr-match-5`)과 상대를 모르는 방어
// 기록(`dr-match-6`, identity · 이름 null 쌍). 둘 다 시각 모름이라 목록에서 `dr-match-4` 뒤(시각 모름끼리는 ID 순)에 붙고,
// 방어 기록이라 자동 족보 · 분석(공격 기록만)은 그대로다.
import '../tactical_v2_service.dart';

const designReviewTacticalOpponentA = 'dr-opponent-gehenna';
const designReviewTacticalOpponentB = 'dr-opponent-abydos';

TacticalSlotObservation _slot(
  int position,
  String? studentId, {
  String? state,
  String source = 'manual',
}) => TacticalSlotObservation(
  position: position,
  studentId: studentId,
  state: state ?? (studentId == null ? 'unknown' : 'manual'),
  source: source,
  confidence: null,
  reviewStatus: 'confirmed',
  wildcard: false,
);

/// [strikers] 4칸 · [specials] 2칸. null = 모름 칸, `'empty'` = 확인된 빈칸. [lobby]면 1번 · SP1 · SP2의 학생 칸을
/// 로비 공개 관측(`visible_lobby` · `lobby_scan`)으로 둔다.
TacticalDeckV2 _deck(
  List<String?> strikers,
  List<String?> specials, {
  bool lobby = false,
}) {
  TacticalSlotObservation slot(int position, String? value, bool public) =>
      value == 'empty'
      ? _slot(position, null, state: 'empty')
      : public && lobby && value != null
      ? _slot(position, value, state: 'visible_lobby', source: 'lobby_scan')
      : _slot(position, value);
  return TacticalDeckV2(
    strikers: [
      for (final (index, id) in strikers.indexed) slot(index, id, index == 0),
    ],
    specials: [
      for (final (index, id) in specials.indexed) slot(index, id, true),
    ],
  );
}

final _gehennaDefense = _deck(
  ['hina', 'iori', 'aru', 'haruka'],
  ['hibiki', 'ako'],
  lobby: true,
);
final _abydosDefense = _deck(
  ['hina', 'haruna', null, 'empty'],
  ['hibiki', 'ako'],
  lobby: true,
);
final _myDefense = _deck(['hina', 'iori', 'aru', 'haruka'], ['hibiki', 'ako']);
final _abydosAttack = _deck(['aru', 'haruna', null, null], ['hibiki', 'empty']);
final _anonymousAttack = _deck(
  ['mutsuki', 'kayoko', null, null],
  ['ayane', null],
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
    attackDeck: _abydosAttack,
    defenseDeck: _myDefense,
    notes: '',
    attemptCount: 1,
  ),
  TacticalMatchInputV2(
    id: 'dr-match-5',
    kind: 'defense',
    occurredAt: null,
    occurredPrecision: 'unknown',
    season: '10',
    opponentIdentityId: designReviewTacticalOpponentB,
    opponentDisplayName: '아비도스 대책위원회',
    result: 'loss',
    attackDeck: _abydosAttack,
    defenseDeck: _myDefense,
    notes: '',
    attemptCount: null,
  ),
  TacticalMatchInputV2(
    id: 'dr-match-6',
    kind: 'defense',
    occurredAt: null,
    occurredPrecision: 'unknown',
    season: '10',
    opponentIdentityId: null,
    opponentDisplayName: null,
    result: 'win',
    attackDeck: _anonymousAttack,
    defenseDeck: _myDefense,
    notes: '상대 이름을 확인하지 못했습니다.',
    attemptCount: 2,
  ),
];

/// FE9-f: 엑셀 가져오기 검수 · golden용 Mock CSV 경로(`MockAppService.debugSetTacticalExcelSource`로 넣는다).
const designReviewTacticalExcelPath = r'C:\fixtures\전술대항전_기록_9월.csv';

/// FE9-f: 엑셀 가져오기 검수 · golden용 CSV 행(머리글 1행 + 기록 4 + 빈 행 1). 머리글은 Mock 머리글 이름표와 맞아 열 연결 후보가
/// 시안처럼 A 날짜 · B 구분 · C 상대 · D–I 상대 덱 · J–O 내 덱 · P 결과 · Q 시도 · R 비고가 된다(덱 열은 Mock이 필드 이름 머리글만
/// 알아본다). 확인 필요 문자열 5종(+ 결과 · 시도로 나누면 사라지는 시도 빈칸 1종): 기존 상대 이름 "게헨나 선도부"(3칸, 기존 상대
/// 제안), 상대 덱 4번 "?"(2칸), 결과 "승(2트)"(제안 승 · 2회), 학생 이름 "수영복 히나"(Mock은 학생 이름을 읽지 않음), 새 상대
/// "C 유저". 시안 숫자(48행 · 41건 등)는 예시라 맞추지 않는다.
List<List<String>> designReviewTacticalExcelRows() => const [
  [
    '날짜', '구분', '상대', //
    'opponent_striker_1', 'opponent_striker_2', 'opponent_striker_3',
    'opponent_striker_4', 'opponent_special_1', 'opponent_special_2',
    'own_striker_1', 'own_striker_2', 'own_striker_3', 'own_striker_4',
    'own_special_1', 'own_special_2', //
    '결과', '시도', '비고',
  ],
  [
    '2026-09-22', '공격', '게헨나 선도부', //
    'hina', 'iori', 'aru', '?', 'hibiki', 'ako', //
    'hoshino', 'izuna', 'mika', 'kayoko', 'ayane', 'hanae', //
    '승(2트)', '', '',
  ],
  [
    '2026-09-22', '공격', '게헨나 선도부', //
    '수영복 히나', 'iori', 'aru', 'haruka', 'hibiki', 'ako', //
    'hoshino', 'izuna', 'mika', 'kayoko', 'ayane', 'hanae', //
    '패', '1', '',
  ],
  [
    '2026-09-21', '방어', 'C 유저', //
    'aru', 'haruna', '', '?', 'hibiki', '', //
    'hina', 'iori', 'aru', 'haruka', 'hibiki', 'ako', //
    '승', '1', '상대 2번 확인 못 함',
  ],
  [
    '2026-09-20', '공격', '게헨나 선도부', //
    'hina', 'iori', 'aru', 'haruka', 'hibiki', 'ako', //
    'hoshino', 'izuna', 'mika', 'kayoko', 'ayane', 'hanae', //
    '승', '1', '',
  ],
  ['', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
];
