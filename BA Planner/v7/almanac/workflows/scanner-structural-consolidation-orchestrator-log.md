---
title: "Scanner Structural Consolidation — Orchestrator Log"
summary: "오케스트레이터(Claude 상위 세션) 결정·실험 기록. Opus가 소유하는 status 문서와 분리해 덮어쓰기 충돌을 막는다."
topics: [workflow, migration]
---

# 오케스트레이터 로그

status 문서(`scanner-structural-consolidation-status.md`)는 **Opus 작업자만 쓴다.** 오케스트레이터는 이 파일에만 append 한다(2026-09-27 이후).
2026-09-27 낮에 오케스트레이터가 로컬 사본으로 status를 세 번 덮어써 Opus가 복원한 사고의 재발 방지 조치다.

## 2026-09-27 (status에 있던 오케스트레이터 항목의 사본)

- 2026-09-27 (오케스트레이터, E5): 폰트 렌더링 실험 완료. **KR 클라이언트 UI 폰트는 GyeonggiTitle(MainFont/MainFont_Bold)** — Steam 카탈로그 `ui/font/bundlefontkr`,
  Preload 번들 `prologdepengroup-assets-_mx-uis-_mxcommon-_mxprolog-2024-11-18_*`. JP의 LINE Seed KR은 글리프가 달라 사용 불가(D17 폰트 예외).
  Gyeonggi Bold, em 20px @720p, shear .10, 팽창 .5px로 문자열 top-1 100/100이나 margin min .001 → 단독 키 금지, `StudioNumericBank` synth seed 계층으로만(D20 확정).
  명세 §8·JSON `fonts` 블록 추가. Opus 영향: C5e-3에 synth 계층 로더(우선순위 최하위 + 프로필 gate) 1항목 추가, 나머지 전제 불변.
- 2026-09-27 (오케스트레이터, asset 팩): KR/Steam 클라이언트에서 배포 asset 팩 추출 완료 — `backend/assets/recognition/asset_pack/`
  (아이콘 1068+200 `icons-01..03.zip`, KR 아틀라스 스프라이트 12 + 설계도 배경 `Card_Item_Bg_C`, GyeonggiTitle 폰트 2, `manifest.json` sha/출처).
  KR/JP 프리팹 기하 동일 확인(아틀라스 rect·폰트만 다름). E4 재실행 KR 팩 top-1 100 %.
  **C5b 오라벨 발견**: `tech-notes-full-c` 슬롯 44 `SkillBook_Ultimate_Piece` → 실물은 `SkillBook_Ultimate`(D18 갱신). Opus는 C5e-4에서 아이템 `_Piece` 매핑과
  golden 기대값을 ExcelDB id 기준으로 재검한다. 추출 도구 `backend/tools/asset_spec/ba_extract_pack.py`.
- 2026-09-27 (오케스트레이터, 워크플로 확정): C5e-6을 6a(생성기)·6b(캐시·드리프트)·6c(로더 계층+D18 교정)·6d(상세 폴백 순서)·6e(라벨링 UI)·6f(E4 gate 확장)로
  분해해 워크플로에 계약·완료 조건을 적었다. 오케스트레이터 입력(명세·팩·등급표·폰트·E1~E5)은 모두 확보됐고, 이후는 Opus가 C5c부터 재개 지점 순서대로 진행한다.
  다음 세션: **C5c** (착수 전 상세 경로 replay 시나리오 1개 추가, 슬롯 44 기대값 `SkillBook_Ultimate`).
- 2026-09-27 (오케스트레이터, E6 실게임): 스크롤 입력 실험. 결정론적 드래그(priming 8px + 목표 거리 + 정지 .2s) 확정 — 이동량 = 요청량, 위상 보존 ≤2px,
  릴리스 즉시 정착. 스크롤바는 숨김·비활성(폐기), 휠 tick은 가변(맨 위 복귀에만). C5e-1 항목을 이에 맞게 갱신(레지스트리 신규 3항목). 실험 기록 E6 절.
- 2026-09-27 (오케스트레이터, E6 추가): 백그라운드/최소화 입력은 불가로 확정(08-26 실측 + 타입 덤프: UICamera→Unity raw-input 마우스). 대안으로 입력 버스트 + 입력 가드(D21)를 C5e-1에 추가.
  타입 덤프 확인: `UICamera.mouseDragThreshold`(4px), `UILabel.UseKiloFormat`(K는 ≥10,000 정수), `Card_Amount` overflow = ResizeFreely(글자 크기 불변). 스크롤바 폐기 유지.
- 2026-09-27 (오케스트레이터): 사용자 결정 — 그리드 스캔은 포그라운드 유지, 입력 버스트 폐기(D21 축소). 학생 스캔 백그라운드 키 탐색은 `press_key` 순서 변경으로 C5f 신설(게이트: `backend/tools/probe_background_key.py` 사용자 실행 결과).
  4:3 예비 관찰: 같은 폭이면 s·타일·pitch 동일, 세로 앵커만 이동 → D22 레이아웃 리졸버(프리팹 앵커 기반 ROI). 게임 옵션은 4:3/16:9만.
- 2026-09-27 (오케스트레이터): C5f 게이트 통과 — PostMessage 방향키가 백그라운드에서 소비되고 포그라운드 불변(probe 2회). C5f 구현 항목 확정(키 우선·프레임 확인·클릭 폴백만 잠깐 포그라운드 후 복원). D22(4:3)는 보류.
- 2026-09-27 (오케스트레이터, 정렬): 정렬 규칙 반영 현황 점검 — X09(기본 정렬 강제)·카탈로그 `order_index`·`verify_profile_order`(사후 단조 검사, zero-fill gate)는 있음. 식별 단계의 사전(prior)으로는 미사용 → C5e-2에 "order prior" 추가.
  게임 기본 정렬 로직은 `ItemSortingService.GetDefaultSortingOrder`(타입 덤프에 이름만)라 ExcelDB 컬럼만으로 재현 안 됨(기술 노트 T1 6001x가 학교 그룹 안에 정렬됨). 현재의 실측 기반 `order_index` 유지.
  D18 원인: `inventory_catalog.py`가 `SkillBook_Ultimate_Piece`를 "비의서"로 등록(실제 9998=비의서 조각, 9999=비의서).
- 2026-09-27 (오케스트레이터): 사용자 우려(신규 아이템 시 정렬 사전 고장) → D23 추가: 사전은 좁히기만, 실패 시 전체 은행→합성 상세(팩 전체)→라벨링으로 강등, LIS 기반 단조 검사, 카탈로그 identity는 ExcelDB 파생·순서만 관측 계층.
- 2026-09-27 (오케스트레이터): 정렬 규칙을 세 스캔(tech notes 45, presents 56, equipment 95)에서 귀납 — 기술 노트: 학교 enum × 티어↑(신형 T1도 학교 자리), 선물: 등급↑ × id↑, 장비: 강화석 등급↓ → 카테고리 × 티어↓(T2+) → 전 카테고리 T1 → 무기 성장. D23에 기록.
  신규 아이템 후보 우주는 프로필 필터 범주(ExcelDB ItemCategory/Tags)로 제한(사용자 제안) 후 팩 전체로 확대.
- 2026-09-27 (오케스트레이터, 배포): 사용자 결정 — 게임 자산 비배포, 최초 실행 시 Steam 설치 폴더에서 로컬 추출(D24, 6a-0 추출기 신설). asset_pack 바이너리는 개발용 git-ignore 경로 유지, manifest는 정답지. 1차 Steam/KR만, JP·다국어는 D22와 함께 후순위.
- 2026-09-27 (오케스트레이터, D24 확정): 클라이언트 로컬 추출은 키 불필요 파일(카탈로그·아이콘·스프라이트·폰트)만, ExcelDB 파생 등급표는 배포자 갱신 스냅샷. 스냅샷 미포함 아이콘은 4등급 합성 + 스캔 시 등급 판정. 배포자 유지보수 항목: 게임 업데이트마다 `fb_excel.py`로 `item-rarity-vN.json` 재생성(D23(4) 절차와 함께).
- 2026-09-27 (오케스트레이터): 6a-0/6b를 증분 갱신으로 명시 — 추출은 번들 sha 단위, 합성 캐시는 identity별 입력 sha 튜플 단위로 변경분만 재생성(사용자 결정).
- 2026-09-27 (오케스트레이터, E8): 합성 템플릿은 해상도별 저장 없이 정규화 한 벌(D25, 720p 검증 top-1 100 %/p10 .949). 학생 화면 합성 범위 D26(장비·무기·별·숫자·스킬 아이콘; identity는 캡처 유지 + 이름 렌더 E9 예정). 오케스트레이터 남은 입력: 무기·스킬 아이콘·이름 localize 카탈로그 키 규칙.

## 2026-09-27 밤 — Opus 진행 점검 (오케스트레이터)

- 점검 범위: status의 C5c~C5e-4(일부) 절. 판정: **워크플로 계약대로 진행됨.** 특기 사항은 아래.
- C5e-1b 정지 시간 .8 s(E6의 .2 s와 다름): E6은 computer-use 배치의 액션 간 지연이 실질 정지를 늘렸던 것으로 판단, Opus 실측 채택. 선택 최적화(C7 후보):
  NGUI는 누른 채로 있을 때 관성이 e^(−10t)로 감쇠하므로 이동을 더 잘게(예: 8~10스텝, 120~150 ms)로 나누면 초기 관성이 작아져 .3 s 정지로도 ±1px이 될 수 있다. 페이지당 .5 s 절감.
- 6a-0의 `ccdb_catalog_reference.py` 출처 질문: **사용자의 다른 프로젝트(BA Viewer 0.1)에서 사용자가 만든 코드**라 라이선스 문제 없음. 다만 Opus의 자체 리더로도 정답지 일치가 확인됐으므로 그대로 둔다.
- `backend/assets/recognition/spec/`(등급 스냅샷·기하 명세·앵커 덤프)은 **추적한다**(D24: 배포 스냅샷). `asset_pack` 바이너리만 git-ignore.
- 남은 오케스트레이터 입력: D26 학생 화면 카탈로그 키(무기·스킬 아이콘·이름 localize) — 다음 오케스트레이터 세션.
- 남은 사용자 입력: 정렬 비교 람다 디스어셈블(`capstone`·`pefile` 설치 후 재실행), C5e-1d ②(스캔 중 실제 마우스 조작 시험), 실게임 두 번째 스캔(C5e-2/3 생략 비율·소요).

## 2026-09-27 밤 — 정렬 비교 함수 디스어셈블 판독 (사용자 실행 `dump_remaining_native.py`, JP GameAssembly sha bbe68ad3…)

- `ItemSortingService.<>c__DisplayClass3_0.<Sort>b__0`(0x181fd0aa0): 클로저 `[+0x10]`=SortingRule, `[+0x14]`=내림차순 플래그. `GetSortingRule(rule)`의 하위 규칙을 순회하며
  **UniqueId(17)**: `ItemObject.get_Category()==4(Consumable)` bool 비교 → `SecureLong.CompareTo(x.UniqueId, y.UniqueId)`(AssetObjectBase +0x18 = UniqueId = ItemExcel Id);
  **Name(5)**: 가상 호출 get_Name → 문자열 비교; **Count(18)**: get_StackCount → SecureLong 비교; **ExpirationTime(22)**: `+0x90` DateTime 비교. 그 외 규칙은 no-op.
  `GetDefaultSortingOrder`(0x181fd0780): Name/UniqueId는 오름차순, 나머지 내림차순 기본.
- `UIItemSort.<>c.<Sort>b__27_0`(0x180b02570)은 비교 함수가 아니라 **필터 술어** `ItemFilters.IsInInventoryFilter`. `UINonEquipmentInventory.OnSort`(0x1826b8180)는 정렬된 목록에
  LINQ(제네릭이라 심볼 없음)로 그룹화·스크롤 정보(`InventoryScrollInfo`) 생성. 관측과 합치면 그룹 키 = 태그(학교), 그룹 순서 = 첫 등장(=최소 Id), 그룹 안 Quality 오름차순.
- `EquipmentSortingService.CompareCategory`(0x181fc8da0): 정적 Dictionary(카테고리 → 순위) 조회 + WeaponExpGrowthZ(14) 특례. `<Sort>b__0`: 규칙 순회 후 `SecureLong.CompareTo`(UniqueId).
- D23(1) 문구를 이 결과로 갱신(선물은 등급이 아니라 **Id** 오름차순 — 새 SSR 선물은 등급과 무관하게 Id 자리).
- 미해결: OnSort의 그룹화 LINQ 인스턴스 본문(심볼 없음). 그룹 순서·그룹 내 정렬은 관측 귀납. 새 학교/새 태그가 추가되면 첫 스캔에서 재검증.
