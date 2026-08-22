# S3B exact 1280x720 장비 전수 검증표

## 입력 승인 규칙

실캡처 검증에는 PNG pixel size가 정확히 1280x720인 화면만 사용한다. 1275x720 client crop,
1276x752 window frame, 16:9가 아닌 화면, title bar·window border·padding·letterbox가 들어간
화면은 calibration, validation, promotion 근거에서 모두 제외한다. PNG는 lossless RGB/RGBA,
UI scale과 emulator renderer는 한 run 안에서 고정하고, 장비 상태를 바꾸기 전에 안정된
동일 화면을 3회 캡처한다.

이 규칙에 따라 이전 1275x720 Aris Lv65→Lv6 결과는 scale 진단 참고일 뿐 production 실패
표본으로 세지 않는다. Exact 1280x720에서 같은 상태를 다시 캡처해 재현 여부를 판정한다.

## 일반 장비의 원자 경우 수

장비 슬롯과 family는 다음과 같이 고정된다.

| 슬롯 | family |
|---|---|
| 1 | Hat, Gloves, Shoes |
| 2 | Bag, Badge, Hairpin |
| 3 | Charm, Watch, Necklace |

Tier별 허용 level은 T1 1~10, T2 1~20, T3 1~30, T4 1~40, T5 1~45,
T6 1~50, T7 1~55, T8 1~60, T9 1~65, T10 1~70이다. 한 family가 가져야 하는
tier-level pair는 `10+20+30+40+45+50+55+60+65+70 = 445`개다.

- Equipped: 9 families x 445 = **4,005 원자 판독 경우**
- Empty: slot별 1개 = **3 원자 판독 경우**
- Level locked: unlock level이 있는 slot 2와 3 = **2 원자 판독 경우**
- 일반 장비 합계: **4,010 원자 판독 경우**

애용품 6개 상태까지 포함한 live atomic state는 **4,016개**다. Unresolved mask와 정상
게임에서 만들 수 없는 negative는 이 live 원자 상태 합계와 정확도 분모에 포함하지 않는다.

세 슬롯의 상태를 무조건 Cartesian product로 곱하지 않는다. Runtime이 slot ROI를 독립
판독하고 마지막에 결합하므로, 모든 원자 경우를 각 slot에서 한 번 이상 재생하고 별도의
14개 물리적 empty/locked pattern과 7개 unresolved mask로 슬롯 상호작용을 검증한다.

## v6 계정 상태로 9종을 중복 없이 덮는 세 학생

| 대표 학생 | slot 1 | slot 2 | slot 3 |
|---|---|---|---|
| 아이리(밴드) (`airi_band`) | Hat | Hairpin | Charm |
| 하루나(체육복) (`haruna_sportswear`) | Shoes | Bag | Necklace |
| 칸나 (`kanna`) | Gloves | Badge | Watch |

세 학생은 v6 계정 DB에 실제 존재하며 9 family를 정확히 한 번씩 덮는다. 2026-07-03
마지막 학생 스캔 기준 아이리(밴드)는 T1/Lv1 3칸, 하루나(체육복)는 empty 3칸,
칸나는 T1/Lv1·empty·empty다. 모두 학생 Lv20 이상이라 세 슬롯이 열려 있고 T1부터
되돌림 없이 행렬을 촬영할 수 있다. 호시노·시로코·아코는 이미 성장한 계정 상태이므로
실행 대표에서 제외한다.

독립 validation은 다음 계정 내 세 학생을 쓴다.

- 치히로 (`chihiro`): Hat / Badge / Necklace, T1/Lv1 3칸
- 마리나(치파오) (`marina_qipao`): Gloves / Hairpin / Watch, empty 3칸
- 츠루기(수영복) (`tsurugi_swimsuit`): Shoes / Bag / Charm, T1/Lv1 3칸

두 세트는 학생 identity가 겹치지 않으며 각자 9 family를 정확히 한 번씩 덮는다. 근거는
v6 `profile_dd633a06/ba_planner.db`의 읽기 전용 snapshot SHA-256
`4b5a2052cf45cd89117eb4d219bef4cfb4e6bf1e8c5129de03e9c8d5a099f011`이다.

## 최소 factorized capture: 30 설정

> 2026-08-23 범위 보정: 아래 30설정은 family별 tier icon과 전체 end-to-end 독립 split을
> 검증하는 계획으로 계속 유효하다. 숫자 glyph 자체의 production bank는 게임의 고정
> 폰트·기울기·배치와 과거 v6 mask 육안 검증을 사용자 보증으로 받아, 첫 자리 1~9와 둘째
> 자리 0~9의 19개 위치 template로 닫았다. `S3B_1280_DIGITS`의 exact 1280x720 네 장에서
> 10~19/일의 자리 0~9를 세 slot으로 재생했으며, 숫자 bank를 위해 tier별 모든 자릿수를
> 다시 조합 촬영할 필요는 없다. 아래 행렬은 숫자 template 생성 요구가 아니라 tier 및
> 전체 scanner 검증 요구다.

> 2026-08-23 tier-ROI 후속 결정: 아이리(밴드), 하루나(체육복), 칸나의 exact 1280x720
> T1~T10 화면으로 9 family x 10 tier 실제 inner ROI bank를 완성했다. 게임의 아이콘 고정
> 위치가 v6에서 검증됐다는 사용자 결정에 따라 이 bank만을 위한 별도 30-screen identity
> validation은 생략한다. 기존 쿠루미 T2와 Mika/Hibiki T10 독립 regression 30 ROI는 모두
> 통과했다. 이 면제는 숫자·학생 identity·다른 해상도나 전체 scanner 검증으로 확대하지 않는다.

Runtime에서 tier icon은 family별로 판독하지만 level glyph는 family를 입력으로 받지 않고
slot geometry별로 판독한다. 따라서 family×tier와 slot×digit/layout을 독립 축으로 검증할 수
있다. Family-tier는 9×10=90개이고 한 화면에서 세 slot을 읽으므로 **최소 30장**이 필요하다.
아래 matrix는 정확히 30장으로 90개를 한 번씩 덮으므로 이 하한을 달성한다.

각 slot은 30장 동안 다음 level set을 모두 한 번씩 본다.

`1~14(15 제외), 16~20, 23, 30, 34, 40, 45, 50, 55, 56, 60, 65, 70`

이 set은 한 자리 layout 1~9, 두 자리 십의 자리 1~7, 일의 자리 0~9, 모든 tier max,
`12/23/34`, `56/65` 혼동쌍을 포함한다. Tier는 한 학생 안에서 세 slot 모두 T1→T10으로
단조 증가하므로 실제 성장 순서로 촬영할 수 있다.

| Tier | 아이리(밴드) slot 1/2/3 | 하루나(체육복) slot 1/2/3 | 칸나 slot 1/2/3 |
|---|---|---|---|
| T1 | 10 / 8 / 9 | 9 / 10 / 8 | 8 / 9 / 10 |
| T2 | 20 / 18 / 19 | 19 / 20 / 18 | 18 / 19 / 20 |
| T3 | 30 / 16 / 23 | 23 / 30 / 17 | 17 / 17 / 30 |
| T4 | **12 / 23 / 34** | 40 / 40 / 16 | 34 / 34 / 40 |
| T5 | 45 / 13 / 14 | 16 / 45 / 13 | 14 / 14 / 45 |
| T6 | 50 / 11 / 12 | 13 / 50 / 11 | 11 / 12 / 50 |
| T7 | 55 / 6 / 7 | 7 / 55 / 6 | 6 / 7 / 55 |
| T8 | 60 / 5 / 56 | 56 / 60 / 5 | 5 / 56 / 60 |
| T9 | 65 / 3 / 4 | 4 / 65 / 3 | 3 / 4 / 65 |
| T10 | 70 / 1 / 2 | 2 / 70 / 1 | 1 / 2 / 70 |

한 calibration split은 30 설정이며 설정당 stable repeat 3회면 90 PNG다. 같은 학생·같은
화면을 validation으로 재사용하지 않는다. 독립 validation은 치히로, 마리나(치파오),
츠루기(수영복)에 같은 30행을 적용한다. 따라서 production용 최소 독립 2-split은
**60 설정, 180 PNG**다.

30장은 factorized matcher equivalence class의 최소값이다. “모든 family에서 모든 level을
직접 관찰”하는 Cartesian exhaustive 요구를 유지하면 아래 1,335 설정이 필요하다.

한 학생의 세 슬롯을 같은 tier-level로 순차 성장시키면 학생당 445 설정, 세 학생 합계
**1,335 capture configurations**이다. 설정마다 3 stable repeats를 찍으면 **4,005 PNG**이며,
각 PNG는 세 slot observation을 제공한다. 장비 성장은 되돌릴 수 없으므로 각 tier에서
Lv1부터 max까지 빠짐없이 저장한 뒤 다음 tier로 올린다.

## 상태와 경계 supplement

학생 level에 따라 물리적으로 가능한 empty/equipped 조합은 다음 14개다.

- Student Lv1~9: slot 1의 empty/equipped 2개, slot 2/3 locked
- Student Lv10~19: slot 1/2의 4개 조합, slot 3 locked
- Student Lv20+: 세 slot의 empty/equipped 8개 조합

Unlock 경계는 student Lv1, 9, 10, 19, 20을 별도 anchor로 둔다. Empty는 orange-dot ROI가
각 slot에서 한 번 이상 나타나야 하고, equipped 상태에서는 같은 ROI가 empty로 오검출되지
않아야 한다. 14 patterns와 5 boundary probes는 가능한 경우 같은 화면을 공유하되 manifest에
둘 다 태그한다.

애용품은 일반 장비와 독립적으로 다음 6개 원자 상태를 둔다.

1. KR unsupported
2. supported + empty
3. supported + relationship/growth locked
4. T1
5. T2
6. supported but uncertain/invalid crop

Fallback orchestration은 unresolved slot mask `[1]`, `[2]`, `[3]`, `[1,2]`, `[1,3]`,
`[2,3]`, `[1,2,3]`의 7개를 재생해 어떤 mask에서도 equipment menu를 한 번만 열고
해당 slot만 읽는지 확인한다. 이는 실캡처가 아니라 deterministic transport/fixture 검증으로
만들어도 된다.

## 실화면으로 만들 수 없는 negative

Blank crop, 0, 각 tier의 max+1, 70 초과, 잘린 두 번째 digit, 숫자 아닌 icon contamination,
tier-level pair unresolved는 정상 게임 상태로 만들지 않는다. 이들은 synthetic negative로
분리하며 실캡처 정확도 분모에 넣지 않는다. 특히 T1=11, T2=21, ..., T9=66, T10=71은
각 tier 상한 거부를 확인한다.

## 캡처량과 실행 순서

| 구간 | 설정 수 | 3회 반복 PNG | 비고 |
|---|---:|---:|---|
| Equipped exhaustive | 1,335 | 4,005 | 4,005 family-tier-level 원자 경우 |
| Empty/locked patterns | 14 | 42 | family와 무관한 slot geometry |
| Unlock boundary anchors | 5 | 15 | 상태 pattern과 중복 가능 |
| Favorite states | 6 | 18 | 지원/잠금/T1/T2/uncertain |
| 합계 상한 | 1,360 | 4,080 | 중복 화면을 재사용하지 않은 상한 |

권장 기본 순서는 입력 환경 고정 → empty/locked boundary → 30장 factorized calibration →
다른 학생 세트의 30장 validation → favorite 상태 → synthetic negative/fallback mask다.
Cartesian exhaustive가 별도로 필요할 때만 세 대표 학생을 T1 Lv1부터 T10 Lv70까지
순차 캡처한다. 각 파일은
`{student}_T{tier:02}_L{level:02}_r{repeat:02}.png`로 저장하고 source SHA-256, student,
slot/family/tier/level, student level, UI scale, renderer, stable-frame 여부를 metadata에 둔다.

기계 판독용 전체 1,335행과 30+30 최소행은 각 handoff artifact에 저장한다.
Production gate는 이 matrix의 calibration subset과 frozen validation subset을 학생·상태 단위로
분리하고, validation에서 accepted wrong 0을 확인한 뒤에만 다시 검토한다.
