# 후속 세션 프롬프트 2차 (2026-10-08 08:30, 오케스트레이터)

W1~W5 결과(`debug/w1_w5_20261008_01a11796`, `w1_w5_approved_resume_…`) 수신 후 사용자와 합의한 세 과제. 셋은 파일 범위가 겹치지 않아 **병렬 가능**. 각 프롬프트 앞에 `docs/migration/scanner-consolidation/o3-holdout-session-prompts-2026-10-02.md` 공통 전문을 붙인다. 유지: 완료 선언(T1·T3·T4·O3 승격) 금지, 시뮬레이터 중단, 키 값 기록 금지, 게임 실행·프로세스 접근 금지, Steam/Viewer/Arena 접근 금지, holdout 자료 접근 금지.

## 결정
- **D8. W5b 신규 추출 slice 승인** — W5의 "신규 추출 금지"를 이 slice에 한해 해제. 범위는 미카 EX(CH0069Ex01) 로직 행뿐. 추출 후 W5 재계산은 같은 세션이 이어서 한다(라운드 3).
- **D9. W4b ExpType 확정은 코드 경로(1함수)** — 사용자 인연 화면 스크린샷은 교차 확인용 선택지로만 남긴다(요청하지 않음).
- **D11. 애니메이션 스펙트럼 도구(A 트랙)**: 택틱 보조 트랙으로 채택, A0 즉시 병렬 배정, 계약은 로그 09:05 항목.
- **D10. S4-C6 오프라인 비교 착수**(D2 그대로) — 구현·활성화·holdout은 결과 표를 본 뒤.
- 프론트 baseline PNG 5장 변경은 프론트 로그 통지로 종료(택틱 범위 밖).

## W5b — 미카 EX 로직 행 추출 + T1 gate 재계산 (택틱)

```
읽을 것: docs/tactic-editor/t1-user-mika-ex-observations-2026-10-08.md(§6 포함) → t1-mika-ex-gate-2026-10-08.md → t1-mika-ex-context-followup-2026-10-08.md(남은 입력 4개) → post-c-session-prompts-2026-10-07.md S2 ②(추출 절차 선례) → C:\Users\brigh\ba-client-data\NOTICE-for-workers.md.
원칙: 기존 로컬 JP 키 절차만(네트워크 0, 키 값 기록 0). 기존 jp-json·골든 변경 없음. 관측값에 맞춘 계수 보정 금지. 라운드 한도 3.
1. 추출(1라운드): data/extracted/pipeline/extract_jp.py TABLES에 미카 EX 로직에 필요한 표만 추가 — 후보: SkillExcel(CH0069Ex01 행, 이미 있으면 생략), SkillLogic 계열, LogicEffect 계열(LogicEffect_PC 등), 엔티티/투사체 DAO(타격 도착에 필요한 것). **CH0069Ex01이 참조하는 행만** 걸러 docs/tactic-editor/evidence/t1-mika-ex-logic-jp-1.73.0.json에 넣는다(참조 체인: SkillExcel → SkillLogic → LogicEffect → Entity, 각 단계 id·필드 전부, 행별 sha). 전체 표 JSON은 jp-json에 두되 크기가 10 MB를 넘으면 참조 행만 둔다(보고). 공용 저장소 import(--kind mika-ex-logic, 절차는 W4와 동일) 후 status에 kind 추가.
2. 구조 확정(2라운드): 타격 수·타격별 Amount/배율·BonusRateFirst·HP 의존 함수(툴팁 "1~2배")의 정확한 식과 적용 위치·플래그, 엔티티 → 11타격 도착 순서(큰 타격 release 32 f vs 표시상 마지막 — 비행/StartDelay로 설명되는지). 관측 "10틱 + 마지막 1타"와 구조가 다르면 보고로 끝.
3. 재계산(3라운드): W5 calculate_w5.py를 원 행 입력으로 다시 돌려 틱/마지막 각각 [최소, 최대] 범위와 55건 안/밖 건수. HP 의존 배율이 있으면 EX마다 보스 HP가 필요하다 — 시작 HP 7,700,000·단독 편성·EX 사이 평타 수 미기록이므로 **HP 범위를 [EX 직전 가능 최소, 최대]로 잡아 보수적 범위**를 내고, 그래도 판정이 갈리는 건수를 "HP 미기록으로 미판정"으로 분리 보고. PASS는 범위 밖 0건이면서 미판정 0건일 때만.
4. 사용자 요청 목록은 만들지 않는다. 단, 3에서 "HP 미기록 미판정"이 1건 이상이면 보고 끝에 "EX 5회의 시전 직전 보스 HP(영상 1개)가 있으면 해소 가능"이라고 한 줄만 적는다.
산출물: evidence JSON, docs/tactic-editor/t1-mika-ex-gate-2026-10-08b.md(이전 보고서 보존), 커밋 1건(추출 도구 변경 + evidence + 보고서). 완료 보고: 구조 일치 여부, 범위, 건수(안/밖/미판정), 미확정 목록. "T1 완료" 선언 금지.
```

## W4b — FavorLevelExcel.ExpType 해석 확정 (택틱, 코드 1함수)

```
읽을 것: debug/favor_cafe_w4_20261008_01a11796/output.md → artifacts/favor-structure-analysis.json → docs/tactic-editor/evidence/favor-cafe-tables-jp-1.73.0.json(ExpType 판정 절) → W4의 dis 절차(artifacts/dis/…get_InteractCooltime.txt, 같은 도구·같은 cap).
목표: ExpType 벡터를 **읽는 쪽** 코드로 후보 ①(랭크별 필요 경험치) / ②(누적 임계값)를 가른다. 라운드 한도 2.
1. JP 메타데이터에서 FavorLevelExcel/ExpType을 소비하는 메서드 심볼 전수 열거(이름에 Favor·Exp·Level·Rank 포함, FavorLevelupType 인덱싱 포함). 표: symbol, RVA, 호출 관계 후보.
2. 그중 "현재 경험치 ↔ 다음 랭크" 비교를 하는 1함수만 역어셈블(1회, 실행 가능 섹션 + exact unwind 기준). 판정 근거: 벡터 원소를 (a) 랭크 인덱스로 직접 읽고 현재 exp와 비교하면 ② 누적, (b) 랭크마다 더해 가거나 차감하면 ① 필요치. FavorLevelupType → 원소 인덱스 변환(그룹 1 → 원소 0?)도 같은 함수 또는 직전 호출자에서 확인.
3. 결론은 ①/②/미확정 중 하나 + 근거 [코드] 꼬리표. 미확정이면 "사용자 인연 화면 1장(랭크 n의 현재/다음 숫자)으로 교차 확인 가능"을 한 줄 적고 종료(요청 자체는 오케스트레이터가 한다).
산출물: evidence JSON의 ExpType 절 갱신(버전 올림, 이전 판정 보존) + dis 텍스트 1개, 커밋 1건. 프론트 로그는 수정하지 않는다(오케스트레이터가 옮김). 쓰다듬기 횟수는 이 과제 범위 아님.
```

## S4-C6 — 이름 shadow 짝수 패딩(C6/v3) 오프라인 비교 (스캐너)

```
읽을 것: debug/scanner_s4_margin_diagnosis_20261007_8dc614e2/output.md(홀수 폭 글리프 반 배율 진단, C6/v3 후보 정의) → debug/scanner_s4_public_retry_20261007_64ba19df/output.md(NOT_PASSED 기준) → debug/scanner_o3_offline_comparison_20261002/(eval.py, results_basic.json, results_raqm.json, 표 형식) → o3-confusion-offline-comparison-2026-10-02.md §4 수용 기준.
범위: **오프라인 비교만**. 운영 코드·골든·테스트·holdout 접근 없음. 구현은 eval.py와 같은 스크래치 모듈(C6 변형 함수 1개)로 한정.
1. C6/v3를 진단 문서의 정의 그대로 구현(짝수 패딩; 그 외 C5와 동일). 정의가 모호한 점은 [?]로 적고 가장 보수적인 해석 1개만 쓴다(변형 여러 개 금지).
2. C0~C5와 같은 표본·같은 표로 BASIC(Windows venv, production) 결과 1회. RAQM은 이 세션에서 돌리지 않는다(오케스트레이터 컨테이너 담당) — 대신 RAQM 실행에 필요한 입력·명령을 results_raqm 형식으로 고정해 둔다.
3. 보고 표: 해상도(720/1080/1440)별 top-1 정답, 여유값(margin) 최소/평균, C5 대비 여유값 비감소 여부, 정답 후보 탈락 수, 미확정 수. 기준은 §4 그대로(실패는 건수 0). 통과/미통과만 적고 채택·구현 제안은 하지 않는다.
산출물: debug/scanner_s4_c6_offline_<stamp>/output.md + results_basic_c6.json + c6 모듈. 커밋 없음(스크래치). 완료 보고 끝에 RAQM 실행 명령 1줄.
```

## A0 — 애니메이션 스펙트럼 도구: 계약 schema + 가용성 조사 (택틱 보조 트랙, 읽기·문서·schema만)

배경: `tactic-editor-orchestrator-log.md` 2026-10-08 08:40(사용자 과제·프론트 경계)·09:05(확정 계약). 코드 변경은 schema 파일 1개뿐.

```
읽을 것: almanac/workflows/tactic-editor-orchestrator-log.md 08:40·09:05 항목 → docs/tactic-editor/t3-binah-skill-frames-2026-10-07.md(§3 모션 길이≠로직 Duration) → data/extracted/README.md(motion·skill-timing kind) → backend/tools/asset_spec/README.md(카탈로그·번들 읽기) → C:\Users\brigh\ba-client-data\NOTICE-for-workers.md.
원칙: 게임 파일 읽기만(복사 0, 키 값 0, 네트워크 0). JP pinned 버전만. 프론트 파일 수정 0. 라운드 한도 2.
1. schema: contracts/animation-spectrum-v1.schema.json을 09:05 계약 그대로 작성(JSON Schema draft 2020-12, 모든 필수 필드·enum 고정). fixture 1개: 비나 Torment의 기존 t3-binah-skill-frames 표에서 클립 2개를 계약 형식으로 옮긴 contracts/fixtures/animation-spectrum/binah-sample.json. Python 검증 테스트 1개(schema로 fixture 검증).
2. 가용성 조사 → docs/tactic-editor/a0-animation-spectrum-availability-2026-10-XX.md:
   (a) anim_event 층: 학생·보스 애니메이션이 Spine인지 Unity Animation인지 종류별로 확인하고, 이벤트(발사·피격·VFX·SFX)가 어디에 있는지 — Spine .skel/.json의 events, Unity AnimationClip의 m_Events, 또는 Excel 표(모션·VFX 표) — 표본 3개(비나, 미카, 학생 1명 더)로 실제 읽어 이벤트 수·이름·시각을 표로. 번들은 asset_spec 절차(UnityPy, 읽기 전용)로 연다.
   (b) logic_effect 층: 기존 kind(skill-timing·battle-tables·motion)만으로 표본 3개의 스킬별 효과 프레임을 몇 %나 채울 수 있는지, 전체 캐릭터로 넓히려면 어떤 표(SkillLogic/LogicEffect 전수)가 필요한지 — W5b가 만드는 추출과 겹치면 "W5b 도구 재사용"으로 적고 중복 구현하지 않는다.
   (c) 초↔프레임: 클립 fps·길이와 로직 Duration을 표본에서 나란히 적고 estimated 규칙이 실제로 몇 건에 걸리는지.
   (d) 규모 추정: 캐릭터 수·클립 수·예상 파일 크기, A1 추출 1회 소요 추정.
3. 결론은 "A1 착수 가능 / 조건부(필요 kind 목록) / 불가(사유)" 셋 중 하나. 추정은 [?].
산출물: schema + fixture + 테스트 + 조사 문서, 커밋 1건. 프론트 로그는 수정하지 않는다.
```

## 사용자 목록
없음. (W5b·W4b 결과에 따라 "EX 직전 보스 HP 영상 1개" 또는 "인연 화면 1장"이 생길 수 있음 — 그때 오케스트레이터가 요청.)
