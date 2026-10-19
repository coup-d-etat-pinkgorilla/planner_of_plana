# W5b 미카 EX 원 로직 추출·55타격 재계산 (2026-10-08)

**Gate: NOT_VERIFIED. 공식 판정 안0 / 밖0 / 미판정55. 확정 범위는 null이며 미판정은 통과 건수가 아니다. T1 완료 선언 없음.**

1라운드 참조 행 추출, 2라운드 구조 판독, 3라운드 조건부 재계산으로 종료했다. 기존 W5 보고서·evidence·55개 관측·JP JSON·lock을 보존했다.

## 원 행과 구조

- JP1.73.0 `CH0069Ex01` SkillLogic1행과 직접 참조 `CH0069_Ex01_Effect01` 레벨1~10 10행을 엄격 디코드했다. 전체 Bytes 소비, 실패0, 누락 그룹0. SkillExcel 기존10행을 재사용했고 각 행 SHA와 모든 필드를 [원 evidence](evidence/t1-mika-ex-logic-jp-1.73.0.json)에 보존했다.
- EX5: Amount0 / BonusSourceFirst=AttackPower / **BonusRateFirst154036BP** / CriticalCheck=Always / CanEvade=true / DefensePenetrationRate10000. 기존 툴팁 반올림154000BP와 구별한다. 모든 Apply 플래그는 evidence의 원 행에 있다.
- 작은 타격10개: release30/34/38/42/53/57/62/66/71/75, 각 DamageDistributeRate500BP. TargetProjectileEntity01, Speed2000, SpawnDelay0, FireDelayFrame0, LevelOneTimeAbility StartDelay0.
- 큰 경로: release32, SpawnerEntity03(부모5000BP, Duration100, OverrideSkillStartTimingWithSpawnerSpawn=true) → local5 Entity04(장식·ability없음·0BP) → local92 Entity05(붙은 대상, Hitscan, 자식5000BP, StartDelay0). **11개 피해 경로로 10+1 관측과 호환**된다. 큰 경로를 부모·자식 두 타격으로 세지 않았다.
- local92가 스포너 생성 기준이면32+92=124프레임이다. 정지 거리≤650·Speed2000=units/s 가정이면 마지막 작은 발사75의 도착≤84.75프레임이므로 큰 표시가 마지막인 설명이 가능하다. 정확한 시간 원점·단위·좌표·대상 이동·분배 전파 consumer 근거는 미확정이며 exact arrival로 승격하지 않는다.

## HP 함수의 확인 범위

모든 피해 ability의 `HpRateDamageModifierDAO`는 CheckTarget=Target, MinHpRate0/MaxHpRate10000, MinDamageMultiplier10000/MaxDamageMultiplier20000다. 데이터 위치는 ability.Modifiers[0]이다. 정확한 보간·절삭·HP분모/평가시점·CalcDamage 삽입 위치는 **소비 코드 근거 없음**으로 남긴다. `m=1+currentHP/maxHP`는 설정과 호환되는 선형 후보일 뿐 채택하지 않았다. 추가 dis는 이번 권한 밖이라 실행하지 않았다.

## 원 계수 재계산과 HP 분리 판정

사용자 조건 KR 최신(정확 build미기록), EX5, 시작HP7,700,000, 미카 단독, 야외A, 기존55값을 유지했다. 평타·self-effect·reset을 없다고 가정하지 않아 각 EX 직전 가능한 생존HP를 보수적으로[1,7,700,000]로 두었다. HP multiplier envelope[10000,20000]는 선형 후보의 끝점을 바깥으로 넓힌 조건부 범위다.

기존 `calculate_w5.py`의 BP kernel을 재사용해 계수만 실제154036으로 바꾸었다. 안정치7791..9999 전2209표본의 단조성을 양 끝HP에서 확인했다. 아래는 H0/H1·분배·HP삽입점·중립 runtime효과를 가정한 진단이며 확정 gate 범위가 아니다.

| 조건부 표시 해석 | ATK / Weak BP | 틱 [최소,최대] | 마지막 [최소,최대] | envelope 안 / 밖 | HP미기록 미판정 |
|---|---:|---:|---:|---:|---:|
| H0_display_final | 6900 / 21000 | 4928~12651 | 49293~126531 | 0 / 55 | 0 |
| H1_intrinsic_not_in_display | 8124 / 25940 | 7167~18400 | 71691~184022 | 55 / 0 | 55 |

H0는55개가 조건부 범위 밖이다. H1은55개가 넓은 envelope 안에 있으나 어떤 HP에서도 안에 드는 교집합이 없으므로55개 모두 **조건부 HP미기록 미판정**이다. 서로 다른 미확정 표시 스탯 해석으로 결과가 갈려 어느 쪽도 채택하지 않았다. 공식55개 각각의 최소·최대는 null, 판정은 NOT_VERIFIED로 유지했다.

HP 미기록은 소비 코드·도착/분배·정확KRbuild·표시 스탯·runtime효과 미확정과 별개다. HP 영상만으로 공식 gate가 자동 해소되지는 않는다. PASS 조건(밖0 및 미판정0)을 충족하지 않는다.

## 미확정·인계

- HpRateDamageModifier consumer interpolation/rounding/denominator/snapshot/application position
- Nested spawner DamageDistributeRate inheritance/override and exact entity arrival timing
- Observed KR exact build and JP1.73.0/Steam damage arithmetic equivalence
- Displayed-to-combat stat aggregation, exact formatter precision and active intrinsic effects
- Per-cast/per-hit HP, normal attacks/self-effects/reset chronology
- Stage4/13/14 live effect/cap/shield/immunity/evade context, as existing scope limits

SkillLogic/LogicEffect_PC는 ExcelDB FlatBuffers TABLES가 아니라 별도 MemoryPack DB다. SkillExcel은 이미 있으므로 `extract_jp.py TABLES`에 가짜 항목을 넣지 않았다(부모 확인). 신규 jp-json은 전체 표가 아닌 참조 슬라이스2개이며 각각10MB미만이다. 공유 store·status·lock·Git index·commit·push 쓰기는0이다. 부모용 import/status/commit명령 초안만 준비한다.

재현(원본/키 접근 없는 검증):

```powershell
py -3.11 -B debug/five_followup_coord_20261008/w5b/artifacts/calculate_w5b.py --verify
```

EX 5회의 시전 직전 보스 HP(영상 1개)가 있으면 해소 가능
