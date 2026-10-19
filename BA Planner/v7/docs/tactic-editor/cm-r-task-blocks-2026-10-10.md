# CM-R 과제 블록 (2026-10-10)

공통 블록은 `docs/orchestration/codex-research-worker-prompt-2026-10-10.md`. 한 세션 = 한 블록. 결과는 CM이 `tactic-editor-orchestrator-log.md`에 판정.

## R-STORE-1 — 공용 저장소 정비: Steam revision 출처 · 패치 절차 dry-run 대본 · CHANGELOG · CM 문서 커밋

```
읽을 것: C:\Users\brigh\ba-client-data\README.md·BOOTSTRAP.md·NOTICE-for-workers.md·CHANGELOG-store.md·status/jp/*.md·status/steam/*.md·tools/*.py(전부, 수정 금지) → v7 ba-data.lock → almanac/workflows/metadata-manager-workflow.md M5 절(패치 체크리스트 7단계) → 2026-10-08 W4·W5b 인계의 import 선례(debug/w1_w5_approved_resume_20261008_01a11796/output.md "W4 registration").
원칙: 저장소에 쓰지 않는다(파일 생성·수정 0). 게임 파일 읽기만, 복사 0, 키 값 0, 네트워크 0. 라운드 한도 2.
1. Steam revision 출처: 설치본(C:\Program Files (x86)\Steam\steamapps\common\BlueArchive 또는 사용자 설정 경로; 못 찾으면 [?])에서 "464491"이 적힌 파일을 찾는다 — 후보: steamapps/appmanifest_*.acf(buildid), 게임 폴더의 버전/manifest/launcher 설정 JSON, 실행 파일 리소스 버전. 각 후보의 경로·필드·값·읽기 방법(텍스트/JSON/PE 리소스)을 표로. appmanifest buildid와 게임 내부 revision이 다른 개념이면 둘 다 적고 어느 것을 version-id에 쓸지 제안(채택은 CM). JP도 같은 표(game-launcher-config.json이 이미 출처 — 재확인만).
2. 패치 절차 dry-run 대본: docs/metadata-manager/store-patch-runbook-2026-10-XX.md — M5 7단계를 지금 도구(register_client/import_extract/diff_versions/make_lock/verify_lock + v7 extract 스크립트들)로 **실제 명령줄**까지 적는다. 단계마다 입력·출력 경로·기대 종료 코드·실패 시 중단 조건. "이미 등록된 버전이면 중단"을 현재 두 버전으로 모의 실행해(명령은 실행하되 쓰기 없는 것만: verify_lock, diff_versions 두 버전 간, register_client --dry-run이 있으면 그것) 출력 캡처. 쓰기 단계는 명령만 적고 실행하지 않는다. diff_versions가 kind별 L1(해시)/L2(행 수·행 변경)/L3(동작, 택틱 판정 필요) 중 어디까지 자동으로 내는지 표로 — 자동이 안 되는 L2는 "필요한 소형 도구"로 적는다(구현은 XB 요청 후보).
3. CHANGELOG-store.md 정리안: status 파일에 흩어진 변경(2026-10-07 가동, 10-07 S1·S2 kind 추가, 10-08 favor-cafe·mika-ex-logic)을 날짜순 항목으로 옮긴 초안을 artifacts/CHANGELOG-store.proposed.md로. 저장소 파일은 건드리지 않는다(CM이 사용자 PC에서 반영).
4. CM 소유 문서 커밋 1건: almanac/workflows/lane-charter-2026-10-10.md(CF가 lint 인용 2개 추가한 작업 트리 상태 그대로), docs/orchestration/*.md, almanac/workflows/metadata-manager-*.md, tactic/metadata 로그, docs/tactic-editor/followup-session-prompts-2026-10-08b.md·cm-r-task-blocks-2026-10-10.md 중 **미커밋 상태인 것만**. 커밋 전 git status로 다른 레인 파일(frontend/, backend/, contracts/)이 섞이지 않는지 확인하고, 섞여 있으면 CM 문서만 add. codealmanac validate 통과 필수. 메시지 "orchestration docs 2026-10-10".
산출물: debug/cm_r_store_1_<stamp>/output.md + artifacts(revision 표, runbook, CHANGELOG 초안, dry-run 캡처), 커밋 해시 1개. 완료 보고: Steam revision 출처 결론(확정/후보/미확인), 자동 L1/L2 범위, 커밋 해시.
```

## R-VERIFY-W5b — W5b 결과 수신 검증 (W5b 워커와 다른 세션)

```
읽을 것: docs/tactic-editor/followup-session-prompts-2026-10-08b.md §W5b(과제 원문·판정 기준) → debug/ 아래 W5b 세션 폴더(이름에 mika_ex 또는 w5b, 2026-10-08 이후) output.md·artifacts → docs/tactic-editor/t1-mika-ex-gate-2026-10-08b.md(있으면) → docs/tactic-editor/evidence/t1-mika-ex-logic-jp-1.73.0.json → C:\Users\brigh\ba-client-data\extracts\jp\jp-1.73.0-e2baf70e\mika-ex-logic\provenance.json(읽기만).
원칙: 재계산·재추출 금지. 읽고 대조만. 라운드 1.
표로 답할 것: (1) 과제 1~4 각각 수행 여부와 산출 경로 (2) 구조 판정(10틱+1타 일치/불일치) 근거 꼬리표 (3) 틱·마지막 [최소,최대] 범위와 55건 안/밖/HP-미기록-미판정 건수 — output.md 수치와 evidence JSON 수치가 같은지 (4) PASS/FAIL/NOT_VERIFIED 선언이 기준(범위 밖 0 && 미판정 0 → PASS)과 맞는지 (5) 계수 보정·가설 채택 흔적 유무 (6) 저장소 provenance sha와 evidence sha 일치 (7) 커밋 해시와 변경 파일이 과제 허용 범위(extract_jp.py TABLES·evidence·보고서) 안인지 (8) 남은 입력(보스 HP 영상 필요 여부).
산출물: debug/cm_r_verify_w5b_<stamp>/output.md 1개. 결론 한 줄: "수용 / 조건부 수용(사유) / 반려(사유)".
```

## R-VERIFY-W4b — W4b 결과 수신 검증

```
읽을 것: followup-session-prompts-2026-10-08b.md §W4b → 커밋 a107c3f2의 변경 파일과 debug/ W4b 세션 폴더 output.md → docs/tactic-editor/evidence/favor-cafe-tables-jp-1.73.0.json ExpType 절(버전 올린 것) → dis 텍스트.
원칙: 재역어셈블 금지. 라운드 1.
표로: (1) 결론이 ①랭크별 필요 / ②누적 임계 / 미확정 중 무엇이며 근거 [코드] 꼬리표(심볼·RVA·명령 라인) (2) FavorLevelupType → 원소 인덱스 변환 확인 여부 (3) 실행 가능 섹션 + exact unwind 기준 충족 (4) 변경 파일이 허용 범위(evidence·dis) 안인지, 프론트 로그 미수정 (5) 미확정이면 "사용자 인연 화면 1장" 교차 확인 안내가 있는지.
산출물: debug/cm_r_verify_w4b_<stamp>/output.md. 결론 한 줄 + 프론트에 전달할 3줄(ExpType 해석 확정값 또는 미확정).
```

---
# 2026-10-10 14:30 추가 블록 (R-STORE-1·R-VERIFY-W5b·R-VERIFY-W4b는 완료·판정됨 — 택틱 로그 14:30)

## A1 — 애니메이션 스펙트럼 전체 추출 (3단계, 각 단계 = 세션 1개, 순서대로)

공통: JP `jp-1.73.0-e2baf70e`만. 계약 `contracts/animation-spectrum-v1.schema.json`(커밋 `987c0d0a`)과 fixture `contracts/fixtures/animation-spectrum/binah-sample.json`을 바꾸지 않는다(필요한 변경은 output.md에 제안만). 도구는 전부 `backend/tools/battle_spec/animation_spectrum/` 아래 새 파일. 저장소 쓰기는 명령 준비까지(import 명령 1줄을 MASTER_REQUIRED에). **Spine `.skel`은 이번 범위 밖**(미판독 [?]로 index에 표기만). 비행시간 가정 금지 — 투사체 명중은 명시 HitFrames/StartDelay가 있을 때만, 없으면 release/spawn만 기록하고 `estimated=true`·note "arrival unknown". 라운드 한도 3/단계.

### A1-a — kind `skill-logic-full` (전 캐릭터 SkillLogic + 참조 LogicEffect 원 행)
```
읽을 것: debug/five_followup_coord_20261008/w5b/artifacts/extract_mika_logic.py(+memorypack_strict.py), docs/tactic-editor/evidence/t1-mika-ex-logic-jp-1.73.0.json(출력 모양), data/extracted/README.md, 저장소 status/jp(LevelSkillDataDBSchema.db 410185d9…, LogicEffectDataDBSchema.db ff352000… 출처), CharacterExcel·CharacterSkillListExcel·SkillExcel(jp-json).
1. extract_mika_logic.py를 backend/tools/battle_spec/animation_spectrum/extract_skill_logic_full.py로 옮겨 일반화: 입력 = 캐릭터 목록(CharacterExcel의 학생 전부 + CharacterSkillListExcel에 스킬이 있는 모든 적/보스 ID; 더미·변형은 index에 kind 표기), 출력 = 캐릭터별 JSON `data/extracted/skill-logic-full/jp-1.73.0-e2baf70e/<characterId>.json`(skillId → SkillLogic 행 + 참조 LogicEffect 행 전 레벨, rowSha) + index.json(캐릭터 수·스킬 수·strict/partial 수·파일 sha). strict 디코드 실패는 partial로 표기하고 멈추지 않는다.
2. 검증: 미카 CH0069Ex01 출력이 기존 evidence(t1-mika-ex-logic)와 행·sha 동일(회귀). 비나 Torment 29스킬이 binah-extract와 동일.
3. 규모 보고: 캐릭터 수, 스킬 수, strict/partial, 총 바이트, 소요 시간. 10 MB 넘는 파일이 있으면 압축 여부 제안만.
산출물: 도구 + 출력 폴더 + docs/tactic-editor/evidence/skill-logic-full-index-jp-1.73.0.json(index 사본) + 커밋 1건. MASTER_REQUIRED: import_extract 명령(--kind skill-logic-full; 폴더 import가 도구에 없으면 그 사실과 대안).
```

### A1-b — kind `animation-events` (전투 캐릭터 Unity AnimationClip m_Events)
```
읽을 것: debug/five_followup_coord_20261008/a0/artifacts/audit_a0_availability.py·availability-evidence.json(3표본 읽기 방법·번들 경로), backend/tools/asset_spec/README.md·ba_catalog.py(카탈로그 → 번들), motion-jp.json·motion-jp-npc.json(컨트롤러/상태 이름 — 클립 ↔ 상태 연결의 1차 열쇠).
1. 캐릭터 → animationclips 번들 해석: 카탈로그에서 `_mxdependency-animationclips` 류 번들을 캐릭터 DevName/CH 코드로 해석(A0 3표본 규칙을 일반화). 못 찾는 캐릭터는 index에 `clipsBundle: null` + 사유.
2. 번들마다 AnimationClip 전부: name, m_SampleRate, start/stop, m_Events(time, functionName, stringParameter, intParameter, floatParameter; objectReference는 path_id만). 텍스처·메시·.skel 등은 열지 않는다. 출력 `data/extracted/animation-events/jp-1.73.0-e2baf70e/<characterId>.json` + index(번들 sha, 클립 수, 이벤트 수).
3. 클립 ↔ 모션 상태 연결: motion-jp(.npc).json의 상태 이름과 클립 이름을 **정확 일치 또는 접두 규칙 1개**로만 연결하고 규칙을 index에 적는다. 이름 유사도 추측 금지(미연결은 unmapped).
4. 규모·소요 보고. UnityPy는 기존 backend/.venv의 것만, 설치 0.
산출물: 도구 + 출력 + index evidence 사본 + 커밋 1건. MASTER_REQUIRED: import 명령.
```

### A1-c — 합치기: `animation-spectrum` 캐릭터별 JSON + 표본 검수
```
읽을 것: A1-a·A1-b output.md와 index, 계약·fixture, docs/tactic-editor/t3-binah-skill-frames-2026-10-07.md(비나 프레임표, 대조용), skill-timing-jp.json(release 마커).
1. 변환기 build_animation_spectrum.py: 캐릭터마다 clips[] = A1-b 클립(sourceFps, lengthSeconds, lengthLogicFrames=round(len×30)) + logicDurationFrames(스킬 Duration이 클립에 연결될 때만, 아니면 null); events[] = anim_event 층(m_Events → kind: PlayAudio→sfx, *InstantiateFx→vfx, SetMouthTile→other, 그 외 other, estimated=false, evidence.clipPath) + logic_effect 층(A1-a의 release/spawn/HitFrames/StartDelay/Duration → kind damage|buff|debuff|groggy|summon|fire|other, frame은 로직 프레임 그대로, evidence.table+rowSha; 비행시간 미확정이면 estimated=true). 클립 ↔ 스킬 연결은 A1-b 규칙 + SkillExcel의 애니메이션/상태 이름 필드(있으면)로만.
2. 출력 `data/extracted/animation-spectrum/jp-1.73.0-e2baf70e/<characterId>.json` + index.json(계약 §파일 단위). 전 파일 schema 검증 통과 필수(실패 파일은 index에 invalid로 남기고 제외).
3. 표본 검수 2건: 비나(fixture 2클립과 값 일치해야 함 — 다르면 fixture가 아니라 변환기를 의심) + 미카(EX 11 release 30/32/34/38/42/53/57/62/66/71/75가 logic_effect 층에 있고 anim 층 SetMouthTile 4건이 other로 있는지). 결과를 docs/tactic-editor/a1-animation-spectrum-samples-2026-10-XX.md에 표로.
4. 규모(파일 수·총 바이트)와 unmapped 통계.
산출물: 변환기 + 출력 + 표본 문서 + 커밋 1건. MASTER_REQUIRED: import 명령(--kind animation-spectrum). CF에 줄 A2 입력(표본 2 파일 경로·index 경로)을 output.md 끝에.
```

## W5c — 미카 EX HP 의존 배율의 소비 코드 + 표시 스탯 집계 규칙 (역어셈블 2함수, 라운드 2)
```
읽을 것: debug/cm_r_verify_w5b_20261010/output.md(미확정 목록), docs/tactic-editor/t1-mika-ex-gate-2026-10-08b.md, evidence/t1-mika-ex-logic-jp-1.73.0.json(LogicEffect Lv5 행: Amount, BonusRateFirst 154036, HP 관련 필드명), 저장소 steam dis: DamageEffect_FromValue.txt·DamageEffectValue_FromDao.txt·CalcDamage.txt·CalcApplyDamageRatio*.txt(기존 역어셈블), docs/tactic-editor/boss-mechanics-foundation-2026-09-30.md(14단계 파이프라인), il2cpp-symbols JP.
목표 두 개, 각 1함수 역어셈블(JP, 실행 가능 섹션 + exact unwind):
1. **HP 의존 배율 소비**: LogicEffect의 BonusRateFirst/HP 관련 필드를 읽어 배율을 만드는 함수를 기존 Steam dis에서 먼저 찾고(DamageEffectValue_FromDao → DamageEffect_FromValue 경로의 어느 단계에서 대상 HP 비율이 들어가는지), JP 동일 심볼 1개를 역어셈블. 답할 것: 식(선형/구간/clamp), 입력이 "현재 HP/최대 HP"인지 "잃은 HP"인지, 적용 위치(14단계 중 몇 번째), 틱마다 재평가인지 시전 시 1회인지.
2. **표시 스탯 집계**: 학생 화면 "공격력 6900"이 장비·전용무기·인연·능력개방을 포함한 최종값인지 — 표시 함수(이름에 StatusDetail/StudentInfo/CharacterStat·Display·Total 포함)를 심볼 목록에서 전수 열거하고 1함수 역어셈블로 합산 항목 확인. 못 찾으면 후보 목록만.
3. 두 결과로 W5b calculate_w5b.py의 조건부 가정(H0/H1, HP 삽입점) 중 **배제되는 것**만 표로(재계산은 다음 블록). 영상(EX 직전 보스 HP) 필요 여부를 1의 답으로 결론.
산출물: docs/tactic-editor/t1-mika-ex-consumer-code-2026-10-XX.md + dis 텍스트 2개(evidence/dis/) + 커밋 1건. 코드 변경 0.
```

---
# 2026-10-19 22:30 추가 블록

## R-M3-1 — 선물·친화도 원천 kind `gift-affinity` 추출 + exp 식 확인 + 265 대조 (라운드 2)

배경: 백엔드 로그 2026-10-19 22:30 회신(CM→XB) 결정 1·2. JP `jp-1.73.0-e2baf70e`만. 기존 로컬 JP 키 절차(네트워크 0, 키 값 기록 0). 추출 도구는 `backend/tools/battle_spec/`가 아니라 **`data/extracted/pipeline/extract_jp.py` TABLES 추가(CM 승인 1회, 이 블록)**로 한다 — 이 표들은 메타데이터 소비용이므로 pipeline 소속이 맞다. 저장소 쓰기는 명령 준비까지.

```
읽을 것: 백엔드 로그 2026-10-19 22:30 항목(결정 1·2 전체) → debug/xb_m3_store_prepare_20261015/artifacts/crosswalk-candidates-review.json(265 후보 구조) → backend/core/student_meta_data.py의 FAVORITE/gift 관련 선언과 backend/data/metadata/v1 catalog의 gift·gift_affinities 필드(현재 SchaleDB 유래 값, 읽기만) → data/extracted/pipeline/extract_jp.py → 저장소 status/jp.
1. 추출: extract_jp.py TABLES에 `CharacterAcademyTagsExcel`, `ItemExcel`(전체 행 — Favor 행만 고르는 건 evidence 단계에서), `ConstCommonExcel`(CommonFavorItemTags 포함 전체 1행)을 추가해 jp-json에 생성. 기존 16표 JSON 바이트 불변 확인.
2. evidence `docs/tactic-editor/evidence/gift-affinity-jp-1.73.0.json`: (a) 학생별 {characterId, favorItemTags[], favorItemUniqueTags[], favorTags[]} 전 행 + rowSha, (b) 선물 아이템 = ItemExcel에서 ItemCategory==Favor(=6) 행만 {id, rarity, quality, tags[], maxGiftTags, usingResultParcelType/Id/Amount, localizeEtcId, icon, isCollaboration} + rowSha, (c) commonFavorItemTags, (d) enum 표: FlatData.Tag·ItemCategory·Rarity 상수를 **JP global-metadata에서 읽어**(il2cpp 메타데이터 문자열/상수, 기존 il2cpp-symbols 도구 경로) Steam r464491 값과 같은지 표로 — 다르면 JP 값 채택.
3. exp 식: `MX.GameLogic.Service.CharacterDBService.TryGetConsumeItemFavorExpParcelInfos` JP 1함수 역어셈블(실행 가능 섹션 + exact unwind; 호출되는 작은 helper 1개까지 허용). 답할 것: 선물 1개의 기본 경험치가 어느 필드인지(UsingResultAmount? Rarity/Quality 테이블?), 태그 일치 수에 따른 배율(1개/2개 이상/unique 태그)과 MaxGiftTags의 역할, CommonFavorItemTags의 역할. 식을 evidence (e)에 [코드] 꼬리표로.
4. 265 대조: (a)·(b)·(e)로 학생별 선물 친화도(선물 → 배율 등급)와 선물 exp_value를 계산해 **현재 canonical 값**(SchaleDB 유래)과 전수 비교. 결과 표: 학생 수 265 중 일치/불일치, 선물 수 중 일치/불일치, 불일치 사례 상위 10개(학생·선물·현재값·계산값·원인 후보). 보정 금지 — 불일치는 그대로 보고(SchaleDB가 틀렸을 수도, 식 해석이 틀렸을 수도 있다는 것만 적는다).
5. enum 번역 JP 확인(결정 2): School·BulletType·ArmorType·TacticRole·WeaponType·TacticRange 상수를 JP global-metadata에서 읽어 22:30 표와 비교, 차이 표.
산출물: jp-json 3표 + evidence + dis 텍스트 1~2개 + docs/metadata-manager/gift-affinity-source-2026-10-XX.md(식·대조 결과·enum 확인) + 커밋 1건(extract_jp.py TABLES 변경 포함, 다른 레인 파일 제외). MASTER_REQUIRED: `import_extract.py --kind gift-affinity --src <evidence JSON>` 명령 1줄.
완료 보고: 식 확정/미확정, 265 대조 수치, enum 차이 유무. 재생성·canonical 적용·SchaleDB 삭제는 하지 않는다.
```

