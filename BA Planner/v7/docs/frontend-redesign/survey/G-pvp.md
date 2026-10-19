> 오케스트레이터 조사 보고서(2026-10-05, 읽기 전용 조사). 본문의 `/mnt/user-data/uploads/v7/`는 저장소 루트, `.../scratchpad/canvas/project/`는 `docs/frontend-redesign/prototype/2026-10-05/`에 해당한다. [확인]은 grep·파싱으로 확인한 사실, (추정)·[추정]은 해석이다. 결정은 `docs/frontend-redesign/decision-register.md`가 우선한다.

# G — 전술대항전(PvP) 탭: 시안 ↔ Flutter 매핑 조사

범위: `Tactical.dc.html`, `Tactical-Analysis.dc.html`, `Tactical-Analysis-All.dc.html`, `Tactical-Slots.dc.html`, `Tactical-Import-Excel.dc.html` (canvas page id `pvp`).
제외: 택틱(타임라인 에디터) — `Tactic-*`, `Boss-*`, `Tactical-Timeline.dc.html`(canvas page `tactic`, 제목 "(이전 초안) 택틱 · 타임라인").

표기: **[확인]** = 파일을 grep/읽기로 직접 확인한 사실. **[추정]** = 확인 근거가 부족한 해석. 백엔드 Python 코드와 `almanac/workflows/p7-p13-tactical-backend-workflow.md`(및 `-status`)는 로컬에 없다. README.md 38~43행과 p0-p6-workflow.md 264~267행이 이 문서를 참조한다는 것만 확인했다.

---

## 0. 공통 관찰

- **[확인] 다섯 artboard 모두 script 로직이 없다.** `<script type="text/x-dc">` 내용은 `class Component extends DCLogic { renderVals() { return {}; } }` 하나뿐이다. 상태는 정적 스냅샷이고, hover/focus 동작은 CSS로만 표현된다(`.flyw:hover .fly`, `.rsr-rec:hover`, `.pop`).
- **[확인] canvas.json 노트**: page `pvp` 제목은 "전술대항전 — 공개 방어 시그니처 → 족보 → 상대 · 슬롯 통계 (ChatGPT 대화 반영)"이다. 즉 기능 요구는 ChatGPT 대화에서 왔고, almanac의 P7–P13 계약에서 온 것이 아니다.
- **[확인] 헤더**: 탭 제목은 "전술대항전"이고 부제는 화면마다 다르다. 기록="전술대항전 기록과 편성"(이 문구는 `AppSection.pvp` 설명과 같다, `ui/app_section.dart:8`), 분석="공개 방어 시그니처별 족보 분석", 슬롯="슬롯별 사용률 · 위치 선호 · 궁합 · 카운터". 헤더나 섹션 어디에도 세 화면을 오가는 하위 탭·세그먼트가 **없다**. 이동 수단으로 보이는 것은 "상대 카드 보기"(link 버튼)와 플라이아웃의 "상대 카드 열기 →" 두 개뿐이다(→ 6장 모호점 A1).
- **[확인] 섹션 시작 y = 209.2**: 메인 레이어는 `clip-path:inset(184px 0 0 0)`이다. 모든 기본 섹션은 그림자 4겹 SVG path와 글라스(fill rgba(29,42,58,.76)) 위에, `clip-path:path(...)`로 둥근 80° 사선을 만든다.
- **공통 반복 컴포넌트 이름**(이 보고서에서 쓰는 이름):
  - `DeckSlotRow`: 6칸 덱(`.deck` + `.pos` 라벨 1/2/3/4/SP1/SP2, 초상 + 이름). 비어 있는 칸은 빗금 처리하고 `aria-label="빈칸"`을 붙인다.
  - `MiniDeckStrip`: 기록 행 안의 "상대 덱 / 내 덱" 소형 초상 6개 두 줄.
  - `KpiTile`: `.kv`(`.cap` 라벨 + `.dsp` 큰 수치 + 보조 문구).
  - `BarRow`: `.bar2` 사선 막대. 비율·누적 돌파율·슬롯 사용률에 쓴다.
  - `Chip`: `.chip` + 색 `ok/dg/wn/gy/pk`.
  - `Seg`: `.seg/.seg.on` + `.su`, skewX(-10°).
  - 버튼: `.tonal`, `.tonal.pri`, `.btn.ghost`, 스테퍼 `.stp`, 링크 `.link`.
  - `InfoButton`: `.ib`. 누르면 `.pop` 툴팁(role=tooltip)이 열린다.
  - `DiagonalRow`: `.row`/`.srow`. 섹션 사선을 따라 행마다 x가 줄어드는 평행사변형 행이다.

---

## 1. `Tactical.dc.html` — 기록 + 편성 + 로비 스캔

### 1.1 목적과 섹션 구성 [확인]

목적: 지난 전적 목록을 보면서 로비 스캔으로 상대를 고르고, 상대 방어 덱(공개 슬롯 + 지난 기록 + 빈칸)과 내 공격 덱을 구성해 결과·시도 횟수·메모를 저장한다. 오른쪽에는 같은 시그니처의 족보를 띄우고, 끌어다 놓아 덱을 복사한다.

| # | 섹션 | rect (x,y,w,h) | 형상 | 부착면 (intro/outro, 설계 문서 1.4) |
|---|---|---|---|---|
| S1 | 기록 목록 | 0, 209, 800, 1183 | 사다리꼴(우측 사선) | 왼쪽 (0/180) |
| S2 | 로비 스캔 | 788, 209, 1131, 204 | 평행사변형(얕음) | 위(헤더 하단) (260/80) |
| S3 | 기록 작성(편성) | 615, 437, 1263, 955 | 평행사변형 | 아래 (80/260) |
| S4 | 이 시그니처의 족보 | 1734, 209, 826, 1183 | 사다리꼴(좌측 사선) | 오른쪽 (180/0) |

중앙은 S2(위)와 S3(아래)로 나뉜다. 설계 문서 1.1에 따르면 "중앙도 위·아래 평행사변형으로 분할 가능"하므로 규칙을 지킨다.

### 1.2 사용 요소

- **S1 기록 목록**
  - 제목 "기록"과 tonal 버튼 2개("엑셀 가져오기", "스캔 파일 가져오기").
  - 필터 칩 행: 전체(on)/공격/방어/이번 시즌/상대: 전체.
  - `MatchRecordRow` 12개. 결과 칩(승 ok/패 dg), "vs X 유저" 또는 "내 방어덱", 종류 아이콘 칩(aria 공격/방어), "N회 · 오늘 21:10", `MiniDeckStrip` 2줄(빈칸 aria 포함).
  - 행 구조는 `rsr-rec`(사선 배경 `.rb` + 내용 `.rc`)이다. 선택 행 1개는 `.rsr-rec.on`(분홍 그라데이션 + 왼쪽 3px 바).
  - 사선 스크롤: `rsw/rsv/rst/rsft/rsfb-rec`. scroll-timeline으로 행 폭이 558.6→766.5px로 변하므로 사선 우측 경계를 따른다. 사선 스크롤바는 SVG line(753,10→635,677, 8px, #e5a0ea)이고, 위·아래 스크롤 포그 페이드가 있다.
- **S2 로비 스캔**
  - 제목, "인식된 상대 3명 · 공개 슬롯 자동 기록", "지금 스캔" 버튼.
  - `LobbyOpponentCard` 3개: 평행사변형 행 356×104. 이름·순위, 공개 3칸 초상(1 | SP1 SP2, 구분선), "족보 A · 6h 전 검증", "방어 승률 · 30일" 큰 수치와 미니 막대, "내 전적" 칩, B에는 "변경 의심"(wn) 칩.
  - 카드마다 `.flyw.lc` 래퍼와 `.flyt` 버튼(aria "X 유저 · N위 최근 방어 덱 5종 보기")이 있다.
  - `DefenseHistoryFlyout`(`.fly.dl`, role=dialog, 폭 540, 카드 아래 12px, 화살표 포함): hover/focus-within/.open일 때 표시된다. 기간별 5행(기간, "현재" 칩, 6칸 초상(비공개 칸은 "?"), 방어 승률, 내 전적 칩/"기록 없음"), "변경 주기 평균 6일", "상대 카드 열기 →".
- **S3 기록 작성**
  - 상단 바: "공격 기록 · 오늘 21:10", "시즌 34" 칩, 공격/방어 토글 칩(pk/gy).
  - "상대 방어 덱": (i) `InfoButton`이 있다. 팝오버 문구는 "1번·SP1·SP2는 로비 스캔 공개 슬롯, 2~4번은 지난 공격 기록, 없는 칸은 빗금 빈칸(빈칸 저장 가능), 족보는 빈칸을 아무 학생이나 일치로 보고 찾음, 칸을 누르면 직접 선택"이다.
  - 상대 유저 드롭다운("A 유저 ▾", "순위 23 · 최근 대전 3회")과 `DeckSlotRow`(4번 빈칸).
  - 출처 범례 칩: 공개=1·SP 로비 스캔 / 기록=2·3 지난 기록 / 빈칸=4 기록 없음.
  - "내 공격 덱 · 위치 포함": `DeckSlotRow`와 버튼 2개("지난 기록 덱 복사", "족보에서 가져오기").
  - 결과 `Seg`(승리/패배). 시도 횟수 스테퍼(− 1 +)와 "첫 시도 성공" 보조 문구.
  - 메모 한 줄. "저장"(pri), "복제해서 새 기록", 안내 "같은 시그니처 족보에 자동 연결됨".
- **S4 이 시그니처의 족보**
  - "대상 방어 덱"(A 유저, 4번 빈칸 강조, "빈칸은 아무 학생이나 일치로 보고 족보를 찾았습니다").
  - `KpiTile` 4개: 방어 유저 6명 / 연결 족보 4개 / 최신 검증 6시간 전 / 숨은 편성 다양성 높음·유형 7.
  - 안내 "족보를 끌어 내 공격 덱에 놓으면 6명과 위치가 그대로 복사됩니다".
  - `JokboRow` 4개(div.row, aria "족보 X · … — 끌어서 내 공격 덱에 놓으면 복사", 첫 행 `.cur`): 채택률, 관측 성공률, 독립 재현, 첫 시도, 평균.
  - 하단 경고 "B 유저에게는 족보 A가 2승 5패 · 숨은 편성 차이 가능성"과 "상대 카드 보기"(link).
- **드래그 중 상태**: 고스트 카드("족보 D · 히나 화력", 448×104, rotate −2.5°, drop-shadow)가 (1162,739)에 있다. 드롭 힌트 알약 "놓으면 족보 D 덱으로 복사 · 위치 포함"(분홍, skew)은 (783,679)에 있다.

### 1.3 상태·상호작용

이 artboard 하나에 다음 상태가 함께 그려져 있다:
- 기록 행 1개 선택
- 공격 모드
- 승리 선택
- 시도 1
- 족보 A 현재(.cur)
- 족보 D 드래그 중(내 공격 덱 위)

플라이아웃은 CSS로 hover/focus 시 열린다(마크업은 3개 모두 존재). 애니메이션 방향 지정은 없으므로 부착면 표를 적용한다.

### 1.4 현재 코드 대응

- `ui/pages/tactical_page.dart` [확인]: `enum TacticalMode { records, jokbo }`, `TacticalPage`, `_TacticalPageState`, `_DeckEditor`, `_Message`. 화면은 `DiagonalSection` 하나 안에 다음을 담는다:
  - `SegmentedButton`(대전 기록/족보)
  - 검색 `TextField`, 종류·승패 `DropdownButton`, `showDateRangePicker`
  - `ListView.builder` + `Card/ListTile`
  - 편집은 `AlertDialog` + `_DeckEditor`(슬롯별 `DropdownButtonFormField`)
- 분류:
  - **화면 구조·위젯은 폐기 대상**(전부 재작성). 사선 4섹션, 드래그, 플라이아웃, 사선 스크롤 목록이 대응물 없이 새로 필요하다.
  - **로직은 재사용·수정 대상**:
    - `_reload`: 세대 가드, `RepositoryService.listProfiles` → `loadRepositoryState` + `loadTacticalState` + `listStudents` 병렬 호출.
    - `_connection` 리스너.
    - `_matches` 필터·정렬: 종류/결과/기간/텍스트 → 시안 필터 칩에 대응.
    - `_candidates(combatClass, own:)`: 보유 학생 필터.
    - `_mutation`: expectedRevision + idempotencyKey 패턴.
    - `_editMatch(source, copy)`: "복제해서 새 기록" / "지난 기록 덱 복사"에 대응.
    - `_copyJokboToMatch`: "족보에서 가져오기"와 드롭 복사에 대응.
  - `_DeckEditor`는 **폐기**한다. `DeckSlotRow`와 학생 선택기(시안은 "칸을 누르면 직접 고를 수 있습니다")로 대체한다.
- 공통 위젯 후보 [확인]:
  - `ui/widgets/scroll_viewport_fog.dart` `ScrollViewportFog`
  - 사선 스크롤바는 파일마다 사본이 있다: `PlanDiagonalScrollbar`(plan_section_layout.dart:8243, public), `_StudentDiagonalScrollbar`, `_DiagonalScrollbar`(account_section_cluster.dart).
  - `AnimatedSectionStack` / `DirectionalSectionEntrance` (animated_section_stack.dart)
  - `AttachedSectionTemplateSurface` / `SectionTemplateSurface` (section_template_surface.dart)
  - `DiagonalMediaListItem`, `BondRankPortrait`
  - 행 폭이 사선을 따라 변하는 사선 스크롤 목록은 다른 그룹(학생·계획)과 공통화해야 한다.
- 스캔 인계 [확인]:
  - `app_shell.dart` `_handoffCandidate`는 `ScannerKind.tacticalLobby` 후보를 받으면 `_section = AppSection.pvp`로 전환만 한다. `TacticalPage`는 후보를 받는 파라미터가 없다(생성자: `service`, `reloadToken`).
  - `TacticalLobbyScannerService`(tactical_lobby_scanner_service.dart:176, 주석 "P8 boundary: capture/review only. Tactical persistence is deliberately P9.")는 UI 어디에서도 사용되지 않는다.
  - `scan_page.dart`는 tactical lobby 후보를 요약해 "Review tactical capture" 버튼으로 넘길 뿐이다.
  - → 로비 스캔 검토·저장 UI는 **신규**다.

### 1.5 데이터 요구

현재 페이지는 **v1 `TacticalService`만** 사용한다(`tactical.state.get/match.upsert/match.delete/jokbo.upsert/jokbo.delete`). `ProcessAppService`는 `TacticalService`와 `TacticalEvidenceService`(v2)를 둘 다 구현한다. `MockAppService`는 **v1만** 구현한다(`implements` 목록에 `TacticalEvidenceService` 없음, 확인).

| 시안 값 | 현재 제공 | 판단 |
|---|---|---|
| 기록 목록(상대, 결과, 종류, 덱 6칸, 시즌, 날짜) | v1 `TacticalMatch`(occurredOn=날짜만, opponent=자유 문자열). v2 `TacticalMatchV2`(occurredAt 타임스탬프, opponentIdentityId/DisplayName, provenance) | 표시 가능. "오늘 21:10" 같은 시각은 v2만 있다 |
| 시도 횟수 "1회/3회", "첫 시도 성공" | **없음.** v1·v2 match 모두 attempt 필드가 없다. `attempt_index`/`attempt_session_id`는 `TacticalSharePayload`(공유 페이로드)에만 있다 | **프로토콜·백엔드 추가 필요** |
| 상대 덱 슬롯 출처(공개/기록/빈칸) | v2 `TacticalSlotObservation.state`(`visible_lobby`, `revealed_after_battle`, `manual`, `unknown`…), `wildcard` bool | 모델은 맞다. 단 **v2에는 match 저장(upsert) 메서드가 없다**(v2 메서드 목록: state.get, import.preview/commit, lobby.commit, candidate.select, match.link, lobby.delete, opponent.alias, stats/trends/recommend/share). 빈칸·출처를 보존하는 저장 경로가 **신규로 필요**하다. v1 `TacticalDeck`은 null 슬롯만 표현한다 |
| 상대 유저 선택 + 순위 + 최근 대전 수 | v2 `TacticalOpponentIdentity`(id, currentDisplayName, aliases). 순위는 `TacticalLobbyCandidateRecord.opponentRank`. 대전 수는 matches에서 계산 | 가능(v2 소비 필요) |
| 로비 스캔 실행·3명 인식 | `ScannerService.startScannerSession(ScannerKind.tacticalLobby, …)`, `TacticalLobbyScanCandidate`(rows 3, 4+2 슬롯 관측, rank), `commitTacticalLobby`, `selectTacticalLobbyCandidate` | 백엔드 있음, UI 신규 |
| "같은 시그니처 족보에 자동 연결됨" | `linkTacticalMatch(mode: auto/manual/unlink)` → `TacticalLinkResult.status` | 있음 |
| 로비 카드 "방어 승률 · 30일 41%" | **없음.** 로비 후보에는 rank와 public_signature만 있다. 상대의 전체 방어 승률은 내 기록으로 관측할 수 없다 | **출처 불명**(6장 A4) |
| 로비 카드 "내 전적 3승 0패" | matches를 opponent_identity_id로 집계 | 클라이언트 계산 가능 |
| "변경 의심" | `TacticalTrendsResult.changes`(Map, 타입 미정), `TacticalFreshnessEvidence.verifiedAfterLatestPublic`. wire의 `verified_after_latest_change`는 Dart 모델에 노출되지 않는다 | 부분. Dart DTO 확장 필요 |
| 플라이아웃 "최근 방어 덱 5종(기간, 6칸, ?, 방어 승률, 내 전적)", "변경 주기 평균 6일" | `TacticalDefenseSnapshot`(deck, opponentIdentityId). wire의 `occurred_at/observed_at`는 검증만 하고 **Dart 필드로 보존하지 않는다** | 기간 표시에 DTO 확장 필요. 기간별 방어 승률은 출처 불명 |
| S4 방어 유저 6명 / 연결 족보 4개 | `TacticalPublicSignatureStats.opponentCount`, `attack_decks`(wire 리스트, Dart 비노출) | DTO 확장 |
| 최신 검증 6시간 전 | `TacticalFreshnessEvidence.ageHours`. `last_success_at`은 Dart 비노출 | DTO 확장 |
| 숨은 편성 다양성 "유형 7" | `TacticalRecommendationResult.scenarioTotal` | 있음(해석 일치는 [추정]) |
| 족보 행: 채택률/관측 성공률/독립 재현/첫 시도/평균 | 관측 성공률 = `observed_win_rate`(terminology 고정 라벨, 확인). 독립 재현은 share analytics `min_independent_contributors` 계열로 [추정]하며 `groups`는 타입 없는 Map이다. 채택률은 직접 필드 없음. 첫 시도·평균은 attempt 데이터가 없다 | 대부분 **백엔드 집계 추가** |
| 족보 이름 "족보 A · 호시노 중심" | v1 `TacticalJokbo`(id, decks, notes), v2 `TacticalJokboV2`(id, decks. wire의 wins/losses/notes는 Dart 비노출) | 이름 필드 없음. 자동 명명인지 사용자 입력인지 결정 필요 |

### 1.6 모호점

6장 A1–A6, A9, A10을 본다.

---

## 2. `Tactical-Analysis.dc.html` — 공개 방어 시그니처 · 족보 · 상대 카드

### 2.1 목적과 섹션 구성 [확인]

목적: 공개 방어 시그니처(1·SP1·SP2) 목록에서 하나를 고르고, 그 시그니처의 완전 방어 덱을 깨는 족보를 상세 분석하고, 특정 상대(B 유저)의 이력·숨은 슬롯 추정·변경 감지를 본다.

| # | 섹션 | rect | 형상 | 부착면 |
|---|---|---|---|---|
| S1 | 공개 방어 시그니처 목록 | 0, 209, 560, 1183 | 사다리꼴(우측 사선) | 왼쪽 |
| S2 | 족보 상세 | 375, 209, 1569, 1183 | 평행사변형(전체 높이) | 위·아래 모두 닿음. 주 부착면 미지정(A7) |
| S3 | 상대 카드(B 유저 · 31위) | 1760, 209, 800, 1183 | 사다리꼴(좌측 사선) | 오른쪽 |

### 2.2 사용 요소

- **S1**
  - 제목 "공개 방어 시그니처"와 "최근 30일" 칩.
  - `SignatureRow` 5개: 공개 3칸 초상, 최근 관측 "6h/1d/3d/5d/2d", 방어 유저 N, 족보 N, 최다 채택 "족보 X", 경고 칩("변경 의심 1", "표본 적음"). 첫 행이 선택 상태다.
  - 스크롤 구조(rs*)는 없다(5행 고정).
- **S2**
  - 제목 "족보 A · 호시노 중심". "족보 편집" tonal 버튼(aria). 칩 "검증 강도 A"(ok), "널리 알려짐 · 변경 위험"(wn).
  - "상대 방어 덱 · 족보가 지정한 6명 · 위치 포함": `DeckSlotRow`와 `KpiTile` "이 방어 덱 사용 6명 · 최근 30일 · 같은 6명 · 같은 위치".
  - "이 방어 덱을 깨는 족보 7개 · 상위 4개": `Seg`(족보 A on/B/C/D)와 "전체 보기 (7)" 버튼(`tonal pri`, `aria-haspopup="dialog"`, Analysis-All에서 `aria-expanded="true"`).
  - "족보 A · 공격 덱": `DeckSlotRow`와 ghost 버튼 "공격 기록에 복사", "내 보유로 대체 찾기".
  - `KpiTile` 6개: 채택률 52%(28명 중), 관측 성공률 71%(43승 18패), 첫 시도 성공 57%, 평균 시도 1.7회, 독립 재현 12명(방어 8명 상대), 최근 검증 6h 전.
  - "N회 내 누적 돌파율": `BarRow` 3개(1회 58%, 2회 79%, 3회 89%).
  - "상대별 결과 · 같은 방어 덱을 쓰는 유저": 4행(A 8승1패 안정 / B 2승5패 비추천 / C 6승2패 / D 4승0패 최근 검증).
  - "대체 학생 허용도": 3행(미카→이오리 11명 중 7명 재현 +0.6회 보통 / 아루→히나 6/6 +0.1회 높음 / 호시노→? 대체 사례 없음 불가).
  - "수명 · 신선도": 최초 7/3, 전성기 7/5~9, 최근 성공률 76%→71%, 시간 가중 점수 68, 최초 제보자 9승1패 / 타 사용자 34승17패.
  - 행들은 x가 614→438로 줄어들며 사선을 따라 배치된다.
- **S3**
  - "B 유저 · 31위"와 "방어 변경 성향 높음"(wn).
  - "공개 방어 · 이력": 2행(9/21~현재, 9/14~9/20).
  - "추정 숨은 스트라이커 2~4번 (추정값)": 4행(슌(수영복) 74%, 토키(무장) 61%, 쿠루미 43%, 오토기 28%), 근거 문구.
  - "변경 감지": "비공개 슬롯 변경 의심", 족보 A 성공률 76%→28%, 마지막 정상 9/20, 추정 시점 9/21 밤.
  - "이 유저에게 유효한 족보": 족보 C(변경 이후 4승 1패, ok), 족보 A(최근 3연속 실패, dg).
  - "기억 카드": 최근 14일 변경 2회, 평균 유지 1.8일, 연속 2회 뚫린 뒤 12시간 내 변경 확률 63%, 마지막 대전 3시간 전.

### 2.3 상태·상호작용

시그니처 1 선택, 족보 A 선택(seg), 상대 카드 B가 열린 상태다. 상대 카드가 B인 이유는 Tactical S4의 "상대 카드 보기"에서 넘어왔기 때문으로 [추정]한다. 스크립트는 없다.

### 2.4 현재 코드 대응

**대응 화면 없음 → 신규.** 현재 `TacticalMode.jokbo` 목록(수동 족보 `ListTile`)은 폐기한다. "공격 기록에 복사"는 `_copyJokboToMatch` 로직을 재사용한다. "족보 편집"은 `_editJokbo`(v1 `saveTacticalJokbo`)를 대체할 신규 편집 UI다.

### 2.5 데이터 요구 (v2 대비)

| 시안 | 대응 후보 [확인된 이름] | 상태 |
|---|---|---|
| 시그니처 목록, 방어 유저 수, 족보 수 | `queryTacticalStatistics` → `TacticalStatisticsResult.publicSignatures: List<TacticalPublicSignatureStats>`(signature, exposureCount, opponentCount, wins, losses, observedWinRate, wilson95Low/High). `attack_decks`, `full_defenses`, `source_counts`는 Dart 비노출 | DTO 확장 |
| 최근 관측 6h/1d | `TacticalTrendsResult.freshness[].ageHours`, `TacticalLobbyScan.observedAt` | 있음 |
| 표본 적음 경고 | `TacticalStatisticsResult.populationWarning`, `quality`(Map), `wilson95Low` | 기준값 정의 필요 |
| 검증 강도 A | `TacticalRecommendationResult.confidenceGrade`(high/medium/low/unavailable), `calibrationGatePassed` | 등급 문자(A) 매핑 결정 필요 |
| 널리 알려짐·변경 위험 | 없음 | 신규 |
| 이 방어 덱 사용 6명 | `TacticalDefenseScenario.distinctOpponentCount`(+ `snapshotCount`, `evidenceWeightShare`) | 있음(scenario의 `deck`은 Dart 비노출) |
| 족보 7개 목록·공격 덱 | `TacticalRecommendationResult.recommendations: TacticalAttackRecommendation`(attackSignature, score, observedMatchCount, observedWinRate, missingStudentIds, allKnownStudentsOwned). `deck`, `wins/losses`, `last_observed_at`은 Dart 비노출. `top_k` ≤ 10 | DTO 확장 |
| 내 보유로 대체 찾기 | `TacticalRecommendationFilters.ownedStudentIds` → `missingStudentIds` | 있음 |
| 채택률 | 직접 필드 없음 | 백엔드 집계 신규 |
| 관측 성공률 43승 18패 | observed_win_rate + wins/losses | 있음(DTO 확장) |
| 첫 시도 성공 / 평균 시도 / N회 내 누적 돌파율 | attempt 데이터 없음(로컬 match). share payload에만 `attempt_index` | **신규(데이터 모델부터)** |
| 독립 재현 12명(방어 8명 상대) | `queryTacticalShareAnalytics` → `groups`(타입 없는 Map), 필터 `minIndependentContributors`/`minIndependentOpponents` | 개념은 일치 [추정], 그룹 스키마는 Dart 미정 |
| 상대별 결과 | stats `opponents`(wire 리스트, Dart 비노출)나 matches 집계 | DTO 확장 또는 클라이언트 집계 |
| 대체 학생 허용도 | `TacticalShareAnalyticsResult.substitutions`(`one_slot_substitutions`, Map 리스트) | 개념 일치 [추정], 필드 스키마 미정 |
| 수명·신선도(최초·전성기·시간 가중 점수·최초 제보자) | `TacticalFreshnessEvidence.freshnessWeight/stale`. 그 밖의 항목은 없음 | 대부분 신규 |
| 공개 방어 이력 | `TacticalDefenseSnapshot`(날짜 Dart 비노출) | DTO 확장 |
| 추정 숨은 스트라이커 % | `recommend.query` 응답 `hidden_slots`(wire 존재, Dart 비노출) | DTO 확장(값 의미 확인 필요) |
| 변경 감지 | `TacticalTrendsResult.changes`(Map), freshness `verified_after_latest_change`(Dart 비노출) | DTO 확장 |
| 이 유저에게 유효한 족보 | `TacticalRecommendationFilters.opponentIdentityId`로 질의 | 있음 |
| 기억 카드(변경 확률 63%) | 없음(예측 확률) | 신규. v2 terminology가 "evidence_weight_share_not_probability"를 강제하는 점과 충돌 가능(A8) |

---

## 3. `Tactical-Analysis-All.dc.html` — 족보 전체 보기 팝업

### 3.1 구성 [확인]

바탕은 Analysis와 동일한 3섹션이다. 그 위에 오버레이가 놓인다:
- scrim `rgba(6,10,16,.35)`(z50)
- `role="dialog" aria-label="족보 전체"` 패널. left 941, top 467, **w 940**, 높이는 내용 맞춤, radius 12, 직사각형, z60
- 상단 화살표(right:120px, top:−7px). "전체 보기 (7)" 버튼에 앵커된 **앵커형 팝오버 모달**이다.

### 3.2 요소

- 제목 "족보 전체 · 7개"와 "상대 방어 덱: 유우카 · 슌(수영복) · 토키(무장) · 쿠루미 | 노아 · 시로코"(텍스트 요약).
- 정렬 `Seg`(성공률 on / 채택률 / 독립 재현 / 최근 성공)와 닫기 버튼(aria "닫기").
- `JokboRankRow` 7개: 순위 번호(dsp), 이름, 관측 성공률, 채택률, 독립 재현, 최근 성공, 아이콘 초상(덱), "표본 적음"(gy) 칩, "공격 기록에 복사" 버튼. 2위 행은 "족보 A · 호시노 중심 · 보는 중"(현재 선택).
- 각주: "독립 재현 5명 미만은 흐리게 표시합니다 · 줄을 누르면 그 족보로 바뀝니다 · 결과(승패 · 시도 횟수)만으로 계산".

### 3.3 상태·상호작용

성공률 내림차순 정렬 상태다(B 83% > A 71% > C 66% …). 행을 클릭하면 S2의 선택 족보가 바뀌고, 독립 재현이 5명 미만인 행은 흐리게 표시한다. 정렬 전환은 클라이언트에서 처리할 수 있다(top_k ≤ 10이므로 7개 전부 수신 가능).

### 3.4 코드 대응 / 데이터

신규다. 앵커형 팝오버 모달 셸은 공통 위젯 후보다(다른 그룹의 W-Info-Popover와 같은 계열로 [추정]). 데이터는 2.5절의 recommendations와 같다. 단 "최근 성공"(`last_observed_at`, 실패 포함 여부 불명)과 "독립 재현"은 DTO 확장이나 share 집계가 필요하다. 각주가 "시도 횟수"로 계산한다고 하므로 attempt 데이터가 선행 조건이다.

---

## 4. `Tactical-Slots.dc.html` — 슬롯 통계 · 궁합 · 카운터

### 4.1 구성 [확인]

| # | 섹션 | rect | 형상 | 부착면 |
|---|---|---|---|---|
| S1 | 내 방어 덱 · 슬롯 클릭 | 0, 209, 800, 1183 | 사다리꼴(우측 사선) | 왼쪽 |
| S2 | 슬롯별 통계 | 615, 209, 1329, 1183 | 평행사변형(전체 높이) | 위·아래(주 부착면 미지정) |
| S3 | 궁합 · 카운터 | 1760, 209, 800, 1183 | 사다리꼴(좌측 사선) | 오른쪽 |

### 4.2 요소

- **S1**
  - `DeckSlotRow`: 리오(무장)/토키(무장)/쿠루미/오토기 | 히마리(무장)/노아. 1번이 선택 상태다.
  - 칩: "1번 리오(무장) 선택"(pk), "최근 30일", "상위 500위".
  - "이 자리의 대체 학생 (나머지 5명 동일 기준)": 3행(호시노 43회 보정 방어 54.1 ok / 유우카 28회 51.0 / 시로코 11회 47.3 wn).
  - 각주 "표본 34경기 · 신뢰도 낮음. 사용률과 성과, 신뢰도는 따로 읽어 주십시오."
- **S2**
  - 제목, `InfoButton`(aria "슬롯별 통계 도움말"). 팝오버 문구는 "최근 30일 · 상위 500위 방어 덱 가운데 1번 슬롯을 쓴 덱을 모두 세어… %p는 지난주 같은 기간과의 차이… 비율은 성능이 아님".
  - "신뢰도 보통" 칩.
  - `BarRow` 5개(유우카 34.2% −0.4%p, 호시노 27.8% +2.1%p, 리오(무장) 16.4%, 토키(무장) 8.1%, 시로코 5.0%).
  - "선택한 캐릭터의 자리별 배치 통계 · 리오(무장)": 1~4번 막대(61/24/11/4%).
  - "위치별 방어 성공률 · 배치 민감도": `KpiTile` 5개(1번 56.3% 34경기 / 2번 49.1% 12경기 / 차이 +7.2%p / 배치 민감도 높음 / 기대 대비 +3.8%p 초과 성과).
  - "1번 메타 집중도 · 상위 3명 78%".
- **S3**
  - "리오(무장)와 자주 같이 쓰이는 학생 (리프트)": 4행(동시 %, 리프트 1.72 등).
  - "이 방어 덱을 가장 자주 뚫은 공격 학생": 3행.
  - "공개 슬롯이 유도하는 상대 공격 덱 · Top 3 · 최근 30일 방어 34전": 3행(순위, 덱 초상, 상대 공격 중 %, 내 방어 N승 M패, 방어 % 칩).
  - "덱 안정성 · 방어 결과 기준": `KpiTile` 4개(평균 방어 53% 34전 18승, 최근 10전 6승4패, 최장 연패 3회 9/18~9/19, 재도전 방어 41% 뚫린 상대 12명).

### 4.3 상태

슬롯 1 선택 상태다. 슬롯을 누르면 S2·S3이 그 학생 기준으로 바뀌는 것으로 [추정]한다(스크립트 없음).

### 4.4 코드 대응 / 데이터

**전부 신규.** 대응 코드는 없다.

| 시안 | 출처 판단 |
|---|---|
| "상위 500위 방어 덱" 모집단 슬롯 사용률, 지난주 대비 %p, 자리별 배치, 메타 집중도 | **v2에 없음.** 로비 스캔은 갱신마다 3명의 공개 슬롯만 관측한다(`TacticalLobbyScanCandidate.rows.length == 3` 검증). 2~4번 비공개 슬롯은 `revealed_after_battle`일 때만 알 수 있으므로 "상위 500위 1번 슬롯 전수"는 로컬 데이터로 만들 수 없다. **출처 결정이 필수다**(A5) |
| 보정 방어 54.1, 기대 대비 +3.8%p, 배치 민감도, 리프트 | 없음. 모델링된 지표다(v2 terminology의 "observed" 원칙과 충돌 가능, A8) |
| 이 덱을 뚫은 공격 학생, 유도 공격 덱 Top3, 덱 안정성(평균 방어·최근 10전·최장 연패) | 내 **방어 기록**(kind=defense, attackDeck)으로 클라이언트 집계 가능(v1이나 v2 matches) |
| 재도전 방어 41%, 뚫린 상대 12명 | 상대별 연속 대전 시퀀스가 필요하다. opponent identity(v2)와 시각 순서가 있으면 계산 가능 [추정] |
| 내 방어 덱 | 현재 내 방어 덱 저장 위치가 없다. v1/v2 모두 match 단위만 있다. 최근 defense 기록에서 유추할지, 별도 저장할지 결정 필요 |

---

## 5. `Tactical-Import-Excel.dc.html` — 엑셀 가져오기 → 해석 결과 승인

### 5.1 구성 [확인]

- 바탕: `Tactical.dc.html`과 4섹션·드래그 고스트까지 동일하다(diff 결과 제목과 마지막 dialog만 추가됨).
- 오버레이: scrim `rgba(5,9,14,.62)`(z80)와 `role="dialog" aria-modal="true" aria-label="엑셀 가져오기 해석 결과"`. 패널은 **(500, 348, 1560, 880)**, radius 14, **직사각형**, z81이다. 헤더 아래 작업영역 기준으로 중앙 정렬된다(x 중심 1280, y 중심 788).

### 5.2 요소(위→아래)

1. 헤더: "엑셀 가져오기 · 해석 결과 확인", "전술대항전_기록_9월.xlsx · 시트 '기록'", 닫기.
2. 요약 `KpiTile`(`.ihdr`) 4개: 읽은 행 48(머리글 1행 제외) / 기록으로 인식 41 / 확인 필요 문자열 5종(11칸) / 건너뜀 2(빈 행·합계 행).
3. "열 연결" + "열 바꾸기" 버튼: 8개 매핑 A '날짜'→날짜, B '구분'→공격/방어, C '상대'→상대 유저, D–I '상대1~6'→상대 덱 6칸, J–O '내덱1~6'→내 덱 6칸, P '결과'→승/패, Q '시도'→시도 횟수, R '비고'→메모.
4. "플래너가 이해하지 못한 문자열 · 5종"과 "모두 처리됨 5 / 5"(ok). 표는 6열 그리드(150/150/1fr/266/190/120)다: 엑셀 원문(모노스페이스, 주황 하이라이트) / 나온 곳 / 플래너가 본 것 / **처리 방법 드롭다운** / 근거 / "모두 적용" 체크박스.
   - 수영복 슌 → 학생: 슌(수영복) (이름 일부 일치)
   - 무장리오 → 학생: 리오(무장) (띄어쓰기·순서 차이)
   - ? → 빈칸으로 두기 · 빗금 빈칸으로 저장
   - 승(2트) → 결과 '승' + 시도 2회로 나누기 (규칙: 괄호 안 숫자 = 시도)
   - B유저 → 기존 상대 'B 유저'로 합치기 (공백만 다름)
   - 처리 방법 범례 7종: 학생으로 연결(검색) / 기존 상대로 합치기 / 빈칸으로 두기 / 결과·시도로 나누기 / 메모로 옮기기 / 이 칸 무시 / 이 행 건너뛰기.
5. "가져올 기록 미리보기 · 41건 중 3건 · 분홍 줄 = 위 처리 방법이 적용된 기록": 3행(날짜, 종류 아이콘, 상대, `MiniDeckStrip` 2개, "승 · 2회", 칩 "처리 반영"(pk)/"그대로"(gy)).
6. 체크박스 2개: "이 처리 방법을 저장해 다음 가져오기에도 쓰기", "같은 날짜 · 상대 기록이 이미 있으면 덮어쓰기".
7. 액션: "취소"(tonal)와 "46건 가져오기"(pri).

### 5.3 상태·상호작용

모든 문자열이 처리 완료된 승인 직전 상태다. 진입점은 S1 "엑셀 가져오기" 버튼이다. 그 전 단계인 파일 선택·시트 선택 화면은 시안에 **없다**.

### 5.4 현재 코드 대응 — 완전 신규인가?

- **[확인] Flutter UI는 완전 신규다.** `tactical_page.dart`에 가져오기 진입점이 없다.
- **[확인] 기존 가져오기 계약은 "v6 가져오기"이고 엑셀이 아니다.**
  - `TacticalEvidenceService.previewTacticalV6Import(profileId, sourcePath, importBatchId)` → `TacticalImportPreview`(batchId, sourceFingerprint(sha256), matchCount, jokboCount, validRecordCount, `issues: List<TacticalImportIssue>{id, sourceRecordId, code, message}`)
  - `commitTacticalV6Import(…, expectedFingerprint, acceptedIssueIds, expectedRevision, idempotencyKey)` → `TacticalImportCommitResult`(importedMatches, importedJokbo, skippedIssues, **skippedExisting**)
  - 프로토콜은 `tactical.v2.import.preview` / `tactical.v2.import.commit`, payload는 `source_path`.
  - 이 메서드를 호출하는 UI는 없다(grep 결과 `process_app_service.dart` 구현뿐).
  - source 형식(v6 DB/JSON/xlsx 여부)은 백엔드 코드가 로컬에 없어 **확인 불가**다. 이름(`V6Import`, source enum `v6_import`)으로 보아 v6 앱 데이터 이관용으로 [추정]한다.
- **재사용 가능한 패턴**: 2단계 preview → commit, 파일 지문(fingerprint)으로 commit 시점 파일 변경 감지, `import_batch_id` + provenance(`source`, `source_label`, `import_batch_id`, `source_record_id`, `review_status`)로 가져온 기록 추적, idempotency.
- **시안이 요구하는데 기존 계약에 없는 것**:
  1. 열 매핑 결과와 사용자 재매핑("열 바꾸기")
  2. 이슈를 "원문 문자열 그룹" 단위로 묶고, 그룹별 처리 방법(7종)과 파라미터(연결할 student_id, 병합할 opponent_identity_id, 분리 규칙)를 지정하는 기능. 기존에는 issue를 accept할지 말지(`acceptedIssueIds`)만 정한다.
  3. 처리 반영 미리보기 행
  4. 처리 규칙 저장(다음 가져오기 재사용)
  5. 덮어쓰기 옵션. 기존에는 `skippedExisting`, 즉 건너뛰기만 있다.
  6. 시도 횟수와 빈칸(wildcard) 저장. match 모델에 attempt가 없다.
  7. 시트 선택
- **pubspec [확인]**: `dependencies`는 `flutter`, `cupertino_icons ^1.0.8`, `file_selector ^1.1.0`뿐이다. **excel/spreadsheet 패키지가 없다.** 파일 선택용 `file_selector`는 이미 쓰인다(`ui/studio/section_studio_file_service.dart`, `developer_tools_main.dart`의 `openFile` + `XTypeGroup`).

### 5.5 파서 위치 판단: **Python 백엔드 권장**

근거:
1. **[확인] 경계 문서**: `almanac/architecture/runtime-boundaries.md`. "Flutter는 화면, view state, 입력과 접근성을 소유합니다. Python 객체나 프로필 파일을 직접 읽지 않고 versioned local protocol을 통해 use case를 요청합니다." "Python backend는 계산, 저장 … 을 소유합니다." AGENTS.md: "Keep Flutter and Python in separate processes with a versioned local protocol."
2. **[확인] 선례**: 기존 tactical 가져오기(`tactical.v2.import.preview/commit`)와 계정 가져오기(`importV6Account`)는 모두 Flutter가 **경로만 넘기고** 백엔드가 파싱·검증·지문 계산을 한다.
3. **해석에 백엔드 데이터가 필요하다**: 학생 이름 퍼지 매칭(별칭, 정규 학생 catalog는 `backend/data/metadata/v1/student_catalog.json`, runtime-boundaries 확인), 기존 상대 identity 병합(`TacticalOpponentIdentity.aliases`, 백엔드 state), 중복 판정(`skippedExisting`). 모두 백엔드가 이미 소유한다.
4. Dart 쪽에 넣으려면 새 의존성(pub `excel` 등)이 필요하고, 학생·상대 매칭 로직이 이중화된다.
5. 반대 근거(Dart 파싱의 장점): 미리보기 응답 속도, 백엔드 미연결 시에도 동작. 그러나 저장은 어차피 백엔드가 해야 하므로 이점이 작다.
6. **확인 불가 사항**: 백엔드에 openpyxl 등 xlsx 라이브러리가 이미 있는지, PyInstaller 등 배포 형태가 무엇인지(백엔드 미보유). `.xls`(구형)·`.csv` 지원 범위도 결정해야 한다.

제안 프로토콜(초안, [추정]):
- `tactical.v2.sheet_import.preview {profile_id, source_path, sheet?, column_mapping?, resolutions?}` → {sheets, detected_mapping, row_counts{read, recognized, skipped}, unresolved_groups[{raw, locations, cell_count, interpretation, suggested_action, evidence}], preview_rows, fingerprint}
- `…commit {…, resolutions, save_rules, on_conflict: skip|overwrite, expected_fingerprint, expected_revision, idempotency_key}`

preview를 재호출하는 방식으로 "열 바꾸기"·처리 방법 변경을 반영하는 형태다.

### 5.6 데이터 정합 메모

읽은 48 − 건너뜀 2 = 46 = "46건 가져오기"는 맞는다. 그런데 미리보기는 "41건 중 3건"이라고 쓰면서 "처리 반영" 행(인식 41건에 속하지 않을 행)을 보여 준다. 분모가 46이어야 하는지 확인이 필요하다(A10).

---

## 6. 사용자 확인이 필요한 모호점

- **A1. 화면 간 이동 수단이 없다.** 기록(Tactical) / 분석(Analysis) / 슬롯(Slots) 세 화면을 바꾸는 UI(하위 탭, 세그먼트, 헤더 버튼)가 시안에 없다. Slots로 가는 진입점은 하나도 없다. 계획 탭처럼 "같은 화면에서 뷰 전환"으로 할지, 헤더에 하위 탭을 둘지 정해야 한다.
- **A2. 족보 개수 충돌.** Tactical S4 "이 시그니처의 족보 · 연결 족보 4개"와 Analysis S1 시그니처 1행 "족보 4"가 있는데, Analysis S2 "이 방어 덱(같은 시그니처의 완전 덱)을 깨는 족보 7개"가 있다. 완전 덱 ⊂ 시그니처이므로 시그니처 족보 수가 더 작을 수 없다. "시그니처 족보"와 "완전 덱 족보"의 정의를 확정해야 한다.
- **A3. 독립 재현 수치 충돌.** Tactical S4 족보 A는 "독립 재현 28명"이고, Analysis는 족보 A "독립 재현 12명(방어 8명 상대)"·"채택률 52% 28명 중"이다. Tactical 쪽 28명이 채택 모수를 잘못 표기한 것으로 [추정]한다. 또 "첫 시도 성공 57%"와 "1회 내 58%"가 같은 의미인데 수치가 다르다.
- **A4. 상대(로비) "방어 승률 · 30일", 플라이아웃 기간별 방어 승률의 출처.** 내 기록과 로비 스캔으로는 상대의 전체 방어 승률을 관측할 수 없다. 공유(share) 데이터를 전제하는지, 게임 화면에 표시되는 값을 스캔하는지 확인해야 한다. 현재 `TacticalLobbyScanCandidate` wire에는 이 값이 없다.
- **A5. 슬롯 통계 모집단 "최근 30일 · 상위 500위 방어 덱".** 로컬 관측으로는 만들 수 없다. 외부·커뮤니티 데이터원(공유 import? 서버?)을 확정해야 한다. 정해지지 않으면 Slots 화면은 "내 방어 기록 기반" 부분(S3 하단 일부)만 구현할 수 있다.
- **A6. 공유(커뮤니티) 데이터 의존 범위.** 채택률, 독립 재현, 대체 학생 허용도, 최초 제보자, 방어 유저 N명 등 Analysis 대부분이 다수 사용자 데이터를 전제한다. v2 share는 동의 기반 payload를 준비(`prepareTacticalShare`)·가져오기(`importTacticalShares`)·철회하는 구조다. 데이터가 어떻게 모이는지(파일 교환? 서버?)는 p7-p13 문서가 로컬에 없어 확인하지 못했다.
- **A7. 전체 높이 중앙 평행사변형의 주 부착면.** Analysis S2와 Slots S2는 위·아래에 모두 닿는다. 설계 문서 1.4는 "여러 면에 닿는 섹션은 주 부착면을 명시"하라고 하는데 시안에 지정이 없다(intro 80 또는 260).
- **A8. 지표 철학 충돌.** v2 계약은 terminology로 `observed_win_rate`, `evidence_weight_share_not_probability`를 강제하고 `population_warning`을 반드시 싣는다(Dart 검증에서 확인). 시안에는 "12시간 내 변경 확률 63%", "보정 방어 54.1", "기대 대비 +3.8%p", "시간 가중 점수 68", "검증 강도 A" 같은 확률·보정 지표가 있다. 반면 Analysis-All 각주는 "결과(승패·시도 횟수)만으로 계산"이라고 한다. 어느 쪽을 따를지 정해야 한다. 또 `frontend-section-direction-and-user-flows.md` 7절은 "P6 범위… 고급 추천과 승률 분석은 별도 범위"라고 적혀 있으므로, 13절 규칙에 따라 문서를 먼저 갱신해야 한다.
- **A9. 기록 저장 모델.**
  - 시도 횟수, 빈칸(wildcard), 슬롯 출처, opponent identity를 저장하려면 v2 match upsert(신규)가 필요하다. 현재 쓰기는 v1(`tactical.match.upsert`, 자유 문자열 opponent, null 슬롯)뿐이다.
  - v1 state와 v2 state가 같은 저장소를 보는지는 백엔드 미보유로 미확인이다.
  - 족보: 수동 족보(v1 jokbo)를 유지할지, 기록에서 자동 도출할지 정해야 한다. 시안의 "족보 편집" 버튼과 "족보 A · 호시노 중심" 같은 이름의 출처(자동 명명/사용자 입력)도 미정이다.
- **A10. 엑셀 가져오기 세부.**
  - 미리보기 분모(41 vs 46).
  - 파일·시트 선택 단계 시안 부재.
  - "덮어쓰기"의 중복 키(날짜+상대만? 시각·덱 포함?).
  - "처리 방법 저장"의 저장 위치(프로필별/전역).
  - "스캔 파일 가져오기" 버튼의 의미. 저장된 로비 스크린샷 폴더 일괄 인식으로 [추정]하며, 설계 문서 7절 "캡처·붙여넣기·폴더·Excel 같은 v6 입력 경로" 범위 결정과 연결된다.
- **A11. 방어 기록 행 표기.** 기록 목록의 방어 기록은 "내 방어덱"으로만 표시되고 공격한 상대 이름이 없다. v1은 `opponent` 비어 있지 않음을 강제한다.
- **A12. 팝업 형상.** Analysis-All 팝오버와 Import 모달은 직사각형이다. 설계 문서 1.2 "모든 섹션은 적어도 한 면에 사선" 규칙에서 팝업이 예외인지 확인해야 한다(다른 그룹 팝업과 일관성 확인).
- **A13. "내 방어 덱"(Slots S1) 저장처.** 현재 모델에 "현재 내 방어 편성"이라는 개체가 없다.

---

## 7. 그룹 전체 요약 — 구현 단위(vertical slice) 제안

### 7.1 핵심 결론: tactical_v2_service가 이미 주는 것과 시안 차이

- **이미 있음(백엔드 계약 + Dart DTO)**:
  - 출처·신뢰도·검토 상태가 붙은 슬롯 관측(`TacticalSlotObservation`: state·source·wildcard)
  - 상대 identity와 별칭(`TacticalOpponentIdentity`, `aliasTacticalOpponent`)
  - 방어 스냅샷, 로비 스캔·후보 저장·선택·기록 링크(`commitTacticalLobby`, `selectTacticalLobbyCandidate`, `linkTacticalMatch`)
  - 시그니처 통계(관측 승률 + Wilson 구간), 추이·신선도(`queryTacticalTrends`)
  - 예상 방어 시나리오와 공격 추천(보유 학생 반영, `queryTacticalRecommendations`), 예측 저장
  - 공유 준비·가져오기·철회·집계(`queryTacticalShareAnalytics`)
  - v6 가져오기 preview/commit
- **wire에는 있으나 Dart DTO가 버림(프론트만 수정하면 됨)**:
  - snapshot·identity의 날짜
  - jokbo wins/losses/notes
  - signature `attack_decks`/`full_defenses`/`source_counts`
  - stats `opponents`
  - recommendation `deck`/`wins`/`losses`/`last_observed_at`/`hidden_slots`/`ambiguity`/`evidence_summary`
  - scenario `deck`
  - freshness `last_success_at`/`verified_after_latest_change`
  - trends `changes`/`exposure`, share `groups`/`one_slot_substitutions`는 타입 없는 Map이라 스키마 확정이 필요하다.
- **없음(백엔드·프로토콜 신규)**:
  - v2 match/jokbo 쓰기(wildcard·출처 보존)
  - **시도 횟수**(첫 시도, 평균, N회 누적의 기반)
  - 채택률
  - 족보 이름
  - 상대 방어 승률(30일)
  - 상위 500위 모집단 슬롯 통계·리프트·보정 방어
  - 변경 확률
  - 엑셀 시트 가져오기(열 매핑, 문자열 그룹 처리, 규칙 저장, 덮어쓰기)
- **UI 사용 현황**: v2 전체를 현재 UI 어디에서도 쓰지 않는다. `MockAppService`는 v2를 구현하지 않는다. 그래서 기본 실행인 mock 모드(runtime-boundaries: "기본 UI 실행은 mock을 유지")에서는 v2 화면에 데이터가 없다. **mock v2 구현과 fixture가 선행 조건이다.**

### 7.2 슬라이스와 순서

| 순서 | 슬라이스 | 내용 | 난이도 | 선행 의존 |
|---|---|---|---|---|
| 0 | 공통 위젯(타 그룹과 공유) | 4섹션 레이아웃(중앙 위·아래 분할 포함) + 부착면 intro/outro. `DeckSlotRow`(빗금 빈칸, 탭하여 선택), `MiniDeckStrip`, `KpiTile`, `BarRow`, `Chip`, `Seg`, 스테퍼, `InfoButton` + 팝오버. 사선 스크롤 목록(행 폭 보간 + 사선 스크롤바 + 포그. 기존 `PlanDiagonalScrollbar`·`ScrollViewportFog` 일반화). 앵커형 플라이아웃·팝오버 모달, 중앙 모달 셸, 드래그 앤 드롭 고스트 | M~L | 디자인 토큰, 다른 그룹 합의 |
| 1 | 기록 화면 v1 이식 | Tactical S1(목록·필터) + S3(작성·저장·복제·족보 가져오기)를 기존 v1 `TacticalService`로 구현. `_reload`/`_mutation`/`_matches`/`_candidates` 로직을 재사용하고 `_DeckEditor`·AlertDialog는 폐기 | M | 0 |
| 2 | 데이터 계층 v2 전환 | `TacticalEvidenceService` 소비, Dart DTO 확장(7.1 "버림" 목록), `MockAppService` v2 구현과 fixture. **백엔드**: v2 match upsert(wildcard·출처·opponent identity·attempts), jokbo 이름·편집 결정 | L | 1, A9 결정 |
| 3 | 로비 스캔 섹션 | "지금 스캔" → `ScannerService` 세션 → 후보 검토 → `commitTacticalLobby` → 카드 선택 시 `selectTacticalLobbyCandidate` + S3 자동 채움 → 저장 시 `linkTacticalMatch(auto)`. `app_shell._handoffCandidate`가 후보를 `TacticalPage`로 넘기도록 수정. 방어 이력 플라이아웃 | M~L | 2, A4 결정 |
| 4 | 시그니처 족보 패널 + 드래그 복사 | Tactical S4. stats/recommend/freshness 질의, 드래그로 공격 덱 복사 | M | 2, 0(DnD), A2·A3 |
| 5 | 분석 화면 + 전체 보기 팝업 | Analysis S1~S3 + Analysis-All. 지표 대부분 백엔드 집계 추가 | L | 2, 4, A1·A6·A8 결정 |
| 6 | 엑셀 가져오기 | `file_selector`로 경로 선택 → Python 파서 preview/commit(신규 프로토콜) → 승인 모달 | L | 2(attempts·wildcard 저장), 0(모달) |
| 7 | 슬롯 통계 화면 | 내 방어 기록 기반 부분(S3 카운터·유도 덱·안정성)은 M. 모집단 통계(S2, S1 대체 학생)는 데이터원 결정 전 착수 불가 | M / 차단 | 2, A5·A13 결정 |

권장 진행: 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7. 6은 백엔드 파서 작업이 독립적이라 2 직후 병렬 진행이 가능하다. 테스트 `tactical_page_test`는 1단계에서 전면 개정이 필요하다(테스트 파일은 로컬에 없어 내용 미확인).
