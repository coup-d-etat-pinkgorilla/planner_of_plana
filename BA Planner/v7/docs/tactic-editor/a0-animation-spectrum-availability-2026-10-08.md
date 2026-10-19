# A0 애니메이션 스펙트럼 가용성 조사 — 2026-10-08

판정: **A1 조건부**. Unity `AnimationClip.m_Events`의 표본 메타데이터는 읽을 수 있다. 전체 학생·보스의 스킬 효과 시점을 채우려면 W5b의 스킬 로직 행 도구를 재사용하는 후속 kind, 애니메이션/타임라인 이벤트 kind와 캐릭터→클립 연결 검증이 필요하다. A0은 전체 추출, 저장소 등록, 화면 구현 또는 시뮬레이터 승인을 수행하지 않았다.

## 범위와 출처

- 확정 행동 범위는 오케스트레이터 로그 2026-10-08 08:40·09:05의 A0이다. `anim_event`와 `logic_effect`를 분리하고 로직 축은 30 fps다.
- v7 `ba-data.lock`의 JP `jp-1.73.0-e2baf70e`만 사용했다. 원본 6파일의 SHA-256·크기를 기존 manifest와 읽기 전용 대조했으며 모두 일치했다(L1). 기존 kind의 읽기 대상 해시도 lock과 일치했다. 이는 L2/L3 동작 검증이 아니다.
- 기존 `backend/.venv/Scripts/python.exe`의 UnityPy 1.25.3 환경을 재사용했다. 시스템 `py -3.11`에는 UnityPy·jsonschema가 없었다. 설치, 키 읽기, 네트워크, 게임 실행·입력·메모리 접근, Steam·Viewer·Arena 접근, 원본/텍스처 복사, 공용 저장소 쓰기는 0건이다.
- 기존 `motion`, `motion-npc`, `skill-timing`, `battle-tables`, `binah-extract`, 명시된 `exceldb-json` 행을 읽었고 재생성하지 않았다. W5b의 신규 미카 로직 추출을 중복 구현하지 않았다.
- 조사 라운드는 2/2다: 1은 계약·기존 자료·표본 경로 확인, 2는 3개 캐릭터의 제한된 메타데이터 읽기와 해시/규모 집계다. 원본의 전체 덤프를 만들지 않았다.
- 실제 조사 근거는 `debug/five_followup_coord_20261008/a0/artifacts/availability-evidence.json`, 재현 명령은 같은 폴더의 `audit_a0_availability.py`다. 이 둘은 조사 산출물이며 등록 kind가 아니다.

## 1. anim_event 층

전투 캐릭터의 표본은 Unity 3D `AnimationClip`이고 학생 SD 자산은 별도 Spine 바이너리다. 전투 발사·피격·VFX·SFX가 모두 Spine 이벤트에 들어 있다고 가정하면 안 된다. Unity 클립은 `m_SampleRate`, `m_MuscleClip.m_StartTime/m_StopTime`, `m_Events`를 읽을 수 있다. 객체 참조 파라미터는 이름과 별개이므로 실제 효과/오디오 대상 해석은 A1의 추가 과제다.

| 표본 | 확인된 메타데이터 | 실제 이벤트 표본(초 → 로직 프레임) | 제한 |
|---|---|---|---|
| 비나 `Binah_Original` | 20클립, 17이벤트, sourceFps 전부 30 | `Vital_Groggy`: `InstantiateFx` 0 → 0; `PlayAudio` 0.433333337 → 13, 8.833333015 → 265. `Normal_Attack`: `PlayAudio` 0.166666672 → 5, 1.666666627 → 50 | EX01/EX02 `m_Events=[]`. 빈 배열은 전투 효과 부재를 증명하지 않는다. 보스의 별도 Unity Timeline과 로직 시점을 추가로 연결해야 한다. |
| 미카, CharacterExcel ID 10059 / `CH0069` | 33클립, 54이벤트, sourceFps 전부 30 | `CH0069_Exs`: `SetMouthTile` 0 → 0, 0.433333367 → 13, 3.433333635 → 103, 5.866666794 → 176. 다른 클립에 `AniEvt_InstantiateFx` 3건 | EX 이벤트 4건은 입 모양이다(`other`). 피해 적용 프레임이 아니다. 이름만 보고 `damage`/`fire`로 바꾸지 않는다. |
| 유우카, CharacterExcel ID 13010 / `Yuuka_default` | `Yuuka_Original` 39클립, 53이벤트, sourceFps 전부 30 | `Yuuka_Original_Exs`: `SetMouthTile` 0 → 0, 1.266666770 → 38, 2.133333445 → 64 | 이 표본의 클립 이벤트는 입 모양뿐이다. 쉴드 적용은 로직 자료가 필요하다. |

Unity `PlayAudio`는 `sfx`, `InstantiateFx`/`AniEvt_InstantiateFx`는 `vfx`라는 콜백 명칭 근거를 기록할 수 있다. 시각상 발사·명중과 로직 피해 적용을 자동으로 같다고 분류하지 않는다. 콜백의 의미 자체가 미확정이면 `other`, `[?]`, `estimated=true`로 남긴다.

정확한 containing bundle 경로와 SHA-256:

| 표본 | AssetBundles 상대경로 | SHA-256 |
|---|---|---|
| 비나 | `assets-_mx-npcs-binah_original-_mxdependency-animationclips-2025-07-02_assets_all_57421249.bundle` | `b1ab8d7bce6221bd056c07893b7b97d376ceb4fb335baa764e1d4dccb3062593` |
| 미카 | `assets-_mx-characters-ch0069-_mxdependency-animationclips-2025-07-02_assets_all_1874348671.bundle` | `2575d3f43366f7b0cb7f6f7fe1ff3bae30fc2465b8408b96811b68c2176e0bd2` |
| 유우카 | `prologdepengroup-assets-_mx-characters-yuuka_original-_mxprolog-2025-07-02_assets_all_3442561495.bundle` | `c77772601eb17a0d65b053bfa7de9d2a12f4b91712952be1a54f33d06925f80c` |

이 번들/카탈로그 해시는 이번 설치본에서 관측한 L1 근거다. 기존 클라이언트 manifest는 번들/카탈로그 해시를 사전에 pin하지 않았으므로 이전 번들 해시와의 동일성까지 주장하지 않는다.

Spine: 미카 `CH0069_spr.skel` 37,173 bytes, 유우카 `yuuka_spr.skel` 12,968 bytes는 둘 다 바이너리이며 헤더에 `4.2.33`이 나타났다. JSON `events`를 읽는 방식은 적용할 수 없다. 기존 UnityPy는 TextAsset을 읽지만 Spine binary timeline/events의 의미를 해석하는 도구는 이번 범위에서 확인되지 않았다. **Spine 이벤트 이름·시각은 [?], 미판독**이다. `.skel` 원본·atlas·텍스처를 결과물로 내보내지 않았다. 카탈로그에 별도 Spine 학생 경로가 존재하는 것과 실제 전투 Unity 클립은 구분했다.

## 2. logic_effect 층

기존 `skill-timing`은 학생 1,852스킬(1,851 full/1 partial)의 행동 `durationFrames`와 `ActionRelease` 등 요약 마커를 제공한다. `full`은 이 요약 형식의 디코드 상태이며 모든 효과 엔티티의 완전 추출을 뜻하지 않는다. `motion`은 727컨트롤러/6,144선택상태의 길이·fps이고 효과 적용 이벤트는 없다. `battle-tables`는 레벨/지형/공격·방어 상성의 4개 계산 표이며 SkillLogic/LogicEffect 타임라인이 아니다.

| 표본 EX | 기존 kind에서 채울 수 있는 것 | 실제 효과 시점의 가용성 |
|---|---|---|
| 비나 Torment slot0 `BinahTormentExSkill01` | `binah-extract`의 full SkillLogicDAO·LogicEffectDAO와 기존 T3 표: Duration 400, 영역 피해 후보 226/242/258/274, 장판 후보 317/407/497/587/707 | 표에서 조건부 후보 9점을 채울 수 있다. 행동 종료 뒤 장판 효과를 자르지 않는다. 런타임/대상 판정 확정 주장은 하지 않는다. |
| 비나 Torment slot1 `BinahInsaneExSkill02` | Duration 198, 투사체 11개 생성 123~138 | 발사·생성은 가능하지만 명중은 거리·속도 단위·비행시간 미확정. 11개 명중 시점을 0 비행시간으로 채우지 않는다. |
| 미카 `CH0069Ex01` | Duration 177, ActionRelease 30/32/34/38/42/53/57/62/66/71/75 | 11개 release 마커는 알려져도 효과 엔티티·그룹·지연·최종 피해 적용과의 연결이 요약 kind에 없다. W5b 산출 대기. |
| 유우카 `YuukaEx01` | Duration 70, ActionRelease 42 | 쉴드 LogicEffect 그룹과 적용 지연을 읽을 full 행이 필요하다. release 42를 쉴드 확정 적용으로 바꾸지 않는다. |

채움률의 분모를 명시한다. 위 **표본 EX 3종(비나 Torment slot0, 미카 EX, 유우카 EX)**에서 행동 Duration·release/생성 후보 요약은 3/3(100%) 제공되지만 full 효과 DAO 근거가 있는 것은 비나 1/3(33.3%)다. `skill-timing`/`battle-tables`/`motion` 세 kind만으로 최종 피해·버프 적용을 확정할 수 있는 학생 EX는 0/2(0%). 비나 두 EX의 알려진 명중 후보 20점(영역 9 + 투사체 11) 중 시간식까지 채울 수 있는 후보는 9/20(45%); 나머지 11/20(55%)은 비행시간 미확정이다. 이는 이 제한된 표본의 **표 후보 커버리지**이지 전체 캐릭터의 효과 채움률이나 실전 정확도가 아니다. 전체 분모/분자는 A1에서 측정해야 하므로 [?]다.

A1에 필요한 자료:

1. 캐릭터/스킬 연결: 기존 `CharacterExcel`, `CharacterSkillListExcel`, `SkillExcel`, 현지화 표를 재사용하고 난도/변형/더미 캐릭터를 구분한다.
2. full `SkillLogicDAO` 행: pinned `LevelSkillDataDBSchema.db`의 학생/적 스킬. `EntityTimeline`, `SpawnDelay`, `HitFrames`, `Abilities.StartDelay`, 투사체/소환/후속 엔티티가 필요하다. **W5b 도구 재사용 대상**이며 A0에서 새 디코더를 만들지 않았다.
3. 연결된 full `LogicEffectDAO` 행: pinned `LogicEffectDataDBSchema.db`의 그룹/타입/조건과 효과 적용 의미. 둘을 묶은 신규 kind가 필요하다. 이번 A0에서 등록하거나 기존 kind를 재추출하지 않았다.
4. Unity `AnimationClip.m_Events`와 별도 Timeline 메타데이터의 신규 `animation-events`(제안명) 또는 최종 `animation-spectrum` kind. 원본 clip→state→logic 스킬 대응을 검증해야 한다. 이름 비슷함만으로 연결하지 않는다.
5. Spine 범위가 A1에 포함되면 기존 설치 도구를 먼저 확인하고 4.2.33 binary reader가 없을 경우 별도 도구/범위 결정을 받는다. 키·설치·네트워크를 A0 승인에서 추론하지 않는다.

## 3. 프레임/초, 모션 길이와 로직 길이

`frame=round(timeSeconds*30)`이다. `sourceFps`는 원본 샘플링률이고 로직 환산률의 대체값이 아니다. 반올림 오차는 `abs(timeSeconds*30-frame)`으로 표시한다. 표본 이벤트들은 0.5 f 미만이어서 float 저장 오차만으로 추정으로 바꾸지 않는다. 오차 ≥0.5 f 또는 근거가 추정이면 `estimated=true`다. 동률 0.5 f에서의 구체적인 tie-breaking은 09:05 문구에 없으며 A1 변환기에서 언어 간 일치 규칙을 정해야 한다([?]). 스키마 모양 검증과 산술/출처 의미 검증은 구분한다.

| 실제 클립 | sourceFps | 원본 lengthSeconds | lengthLogicFrames | 독립 로직 정보 |
|---|---:|---:|---:|---|
| `Binah_Original_Normal_Attack` | 30 | 4.6666669845581055 | 140 | T3의 AttackIng 140은 평타 주기 구성값이다. DAO 전체 Duration 2147483647은 무기한이며 같은 값이 아니다. |
| `Binah_Original_Vital_Groggy` | 30 | 11.333333969116211 | 340 | T3의 GroggyTime 10000ms=300f는 그로기 로직 clock이다. 스킬 행동 Duration과 별개이므로 확인되지 않은 `logicDurationFrames`에는 null을 사용한다. |
| `Binah_Original_Exs_01` | 30 | 13.333333969116211 | 400 | Torment EX1 Duration400과 수치가 맞아도 연결 근거 없이 같은 스킬로 붙이지 않는다. |
| `Binah_Original_Exs_02` | 30 | 6.6666669845581055 | 200 | Torment slot1 Duration198과 다르다. 원본 length를198로 바꾸지 않는다. |
| `CH0069_Exs` | 30 | 5.900000095367432 | 177 | 기존 미카 Duration177과 수치가 맞는다. effects timeline은 W5b 대기. |
| `Yuuka_Original_Exs` | 30 | 2.3333334922790527 | 70 | 기존 유우카 Duration70과 수치가 맞는다. 기존 motion Exs1은 클립 없는1.0s 자리값이므로 길이로 쓰지 않는다. |

Fixture 표본은 T3 §4의 실제 `Normal_Attack`과 `Vital_Groggy` 2클립을 사용한다. Torment EX와의 미확인 연결을 만들지 않는다. `logicDurationFrames=null`은 0이 아니며, 클립 이벤트 note에 결핍을 명시한다. 실제 애니메이션 콜백 5개를 옮길 수 있다. 비나의 별도 shot62 로직은 해당 clip과의 대응을 이번 범위에서 확정하지 않았으므로 피해 이벤트로 합성하지 않는다.

## 4. 규모와 A1 1회 소요의 근거

카탈로그의 `assets/_mx/characters/` 및 `assets/_mx/npcs/` 아래 `.anim` 주소는 12,484개, 캐릭터 asset 폴더296개, NPC asset 폴더336개다. containing bundle695개가 모두 설치되어 있고 그 합계는2,242,770,874 bytes(약2.09GiB)다. 주소/폴더 수는 플레이 가능한 학생 또는 보스 수가 아니며 중복·의상·컷인·카페·NPC를 포함한다. CharacterExcel은7,792행이고 단순 `is_playable` true466행에는 더미/변형이 섞이므로 화면의 ~265명과 그대로 비교할 수 없다. 확정 캐릭터 목록은 A1에서 기존 학생 카탈로그·보스 분류와 조인해야 한다([?]).

3개 containing bundle의 메타데이터 읽기는20/33/39클립, 총92클립/124이벤트였다. 측정값은 각각0.105/0.072/0.064초(기존 환경, 로컬 캐시 상태)이며 세 번들 합계13,694,917 bytes다. 이 작은 표본을 단순695개 번들로 늘리면 약56초지만 번들 구조·타임라인·효과 조인·Spine에 대한 대표성이 없으므로 **A1 실행시간 보장으로 쓰지 않는다**. Unity 메타데이터 부분의 임시 운영 예산은1~5분([?]); 전체 로직 join/Spine 포함 A1 1회의 시간은 W5b 산출과 범위 확정 후 측정해야 한다([?]).

결과 크기도 아직 추정이다. 현재 조사 JSON은 메타데이터92클립/124이벤트와 검증 기록을 포함한77,934 bytes다. 주소12,484개에 표본 평균을 적용하면 클립 약1만~3만개·단순 이벤트 JSON 약5~25MiB 수준이지만 게임/컷인 중복 및 full 로직 효과를 포함하면 늘어난다([?]). 최종 캐릭터별파일·index 크기는 A1이 실제 조인 후 기록한다. 화면은 확정 계약대로 부분 적재·검색·가상 스크롤을 사용한다.

## 5. 계약 및 다음 조건

09:05의 required fields/layer/event kind/30fps/모션과 로직 길이 분리는 확인했다. 표현상 물질적 모호성인 `sourceHashes.bundles[]` 요소 구조, `evidence.kind` 실제 enum 및 근거위치/rowSha/rva 규칙을 부모에게 보고했고, 응답 전 canonical schema/fixture/test 편집은 보류했다. 해시·근거가 없는 상수나 가짜 경로로 채우지 않는다. **A0 상태는 BLOCKED(독립 조사 완료, 계약 3파일 미실행)**이다.

A1 진행 조건은 다음과 같다: schema 표현 결정과 fixture 검증 완료; W5b 도구/산출 인계 후 같은 버전의 full 스킬·효과 자료 연결; 신규 kind·카탈로그/번들 해시 pin 범위 결정; 보스·학생·Spine·Timeline 범위와 클립 매핑 규칙 결정. **A1의 full SkillLogic/LogicEffect 추출은 이번 A0 승인 범위 밖이다.** A1 전체 추출/공용 저장소 등록은 부모의 별도 승인과 직렬화가 필요하다. A2 화면과 A3 통합은 미시작이다. 기존 T1/T3/T4/O3 또는 P0-P6 단계의 승격/완료를 주장하지 않는다.

재현 명령(출력 파일은 기존 증거 파일을 덮어쓰지 않는 새 경로여야 한다):

```powershell
& backend/.venv/Scripts/python.exe debug/five_followup_coord_20261008/a0/artifacts/audit_a0_availability.py debug/five_followup_coord_20261008/a0/artifacts/availability-evidence-recheck.json
```

라운드 한도2/2를 사용했으므로 위 명령의 추가 실행은 부모가 필요성을 확인한 뒤 수행한다.
