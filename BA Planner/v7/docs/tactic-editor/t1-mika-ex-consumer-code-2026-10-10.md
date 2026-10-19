불일치: [코드] 지정된 기존 Steam FromDao/FromValue/CalcDamage/CalcApplyDamageRatio 경로에서는 HpRateDamageModifier 소비 함수 연결을 확정하지 못했다. JP 전수 메타데이터에서 별도 HpRateDamageModifier.GetMultiplier를 찾았다. 표시 스탯은 조회 후보까지이며 최종 집계 경로는 미확정이다.

# W5c 미카 EX 소비 코드 — 2026-10-10

[코드] NOT_VERIFIED(부분 근거 확보). JP `jp-1.73.0-e2baf70e`에서 실행 가능 섹션·exact unwind를 만족하는 함수 본문 두 개만 읽었다. HP 입력의 clamp·선형 보간은 확인했으며 getter의 분모/정수 변환/호출 주기/피해 삽입 위치와 표시 스탯 집계는 미확정이다. 기존 계산기는 실행·수정하지 않았고 가설을 채택하지 않았다.

| 함수 | RVA / 범위 | 근거 |
|---|---|---|
| `MX.Logic.Data.HpRateDamageModifier.GetMultiplier` | [코드] `0x15bd3a0`, VA `0x1815bd3a0..0x1815bd71c`, 892 bytes | [코드] `evidence/dis/W5c_JP_HpRateDamageModifier_GetMultiplier.txt`; 입력 battle/invoker/target, 반환 BasisPoint |
| `CharacterObject.CurrentStatValue` | [코드] `0x1346a40`, VA `0x181346a40..0x181346b07`, 199 bytes | [코드] `evidence/dis/W5c_JP_CharacterObject_CurrentStatValue.txt`; 입력 StatType/representative bool, 반환 long |

[코드] DLL SHA `e2baf70eeb56fc02be00dc35e43374652282ce72dd3f1cd88a5b853e33c0afc1`, metadata SHA `df1a47ce591a66cef2a4cf9890422495ad08e4de8804536690598f23d6485d63`. 설치본·공용 manifest·v7 pin 모두 일치. 원 게임 파일 복사·실행, 프로세스 접근, 키 사용, 네트워크, 저장소 쓰기 없음.

## HP 소비 함수

[표] 미카의 `LevelOneTimeAbilityDAO.Modifiers`에 있는 HP modifier와 `LogicEffect`의 `BonusRateFirst`는 서로 다른 필드다. 기존 원 SkillLogic rowSha `644268b25e112f113c21b02f751b817644e0f0d7ead1e6577ba29571780cf0b3`; EX5 effect rowSha `052d155a847f28baaad9917410a2da93646ce86e31d29e87d1dd11220a98b1d7`. modifier: Target / MinHpRate=0 / MaxHpRate=10000 / MinDamageMultiplier=10000 / MaxDamageMultiplier=20000; effect BonusRateFirst=154036 BP.

[코드] 같은 빌드 MetadataRegistration의 fieldOffsets를 읽어 런타임 modifier의 `MinHpRate +0x18`, `MaxHpRate +0x20`, `MinDamageMultiplier +0x28`, `MaxDamageMultiplier +0x30`, `checkTarget +0x38`을 확인했다. 결과는 `debug/cm_r_w5c_20261010/artifacts/jp-field-offsets.json`에 있다.

| 질문 | 판정 | 명령 근거 |
|---|---|---|
| 대상 선택 | [코드] Target 분기는 target 인자를 사용 | [코드] `1815bd44b..458` GetConditionalModifierTarget 호출; embedded switch table의 case 1 → `1815bd4c8`, rbx(target)를 rcx로 옮겨 `1815bd4a2` get_HitPointRate 호출 |
| 입력 종류 | [코드] `BattleEntity.get_HitPointRate`의 BasisPoint 반환값 | [코드] `1815bd4a2`, 반환 rax를 r15에 저장. [?] getter 본문은 추가로 읽지 않아 현재HP/최대HP 분모·갱신 방식은 미확정. 이 소비 함수 안에는 `10000-h` 역전 계산이 없다 |
| clamp | [코드] `max(MinHpRate, min(MaxHpRate,h))` | [코드] `1815bd61c..650`; exact native 주소→메타데이터 토큰 매핑으로 `186083450=System.Math.Min(long,long)`, `186083280=System.Math.Max(long,long)` 확인 |
| 보간 | [코드] clamp 뒤 float32 선형 보간 | [코드] `1815bd655..682`: 범위 차가 양수면 `(h_clamped-MinHpRate)/(MaxHpRate-MinHpRate)`; `1815bd68c..6a9`: `(MaxDamageMultiplier-MinDamageMultiplier)*t+MinDamageMultiplier` |
| 범위 차 ≤ 0 | [코드] 보간 가중치 1.0 | [코드] `1815bd660..684` 분기; RIP float literal RVA `0x734eb80`의 데이터 1.0. [표] 미카의 양수 범위에는 해당하지 않는다 |
| 정수 변환 | [?] 변환 helper의 세부 의미 미확정 | [코드] `1815bd6af`는 `0x1807ef2f0` 호출, eax를 long으로 확장. 전수 metadata pointer 매핑에서 이 주소는 미해결. `Mathf.RoundToInt`/`System.Convert.ToInt32`라고 이름 붙이지 않았다; trunc/반올림을 확정하지 않음 |
| 매 호출 입력 평가 | [코드] 호출 때 인자 대상에서 getter를 다시 호출 | [코드] 이 함수 안에 HP snapshot cache를 읽는 경로 없음. [?] 실제 caller가 타격마다 호출하는지, 시전 때 한 번 호출해 반환 배율을 저장하는지는 미확정 |
| 피해 계산 삽입 위치 | [?] 14단계 중 어느 지점인지 미확정 | [코드] GetMultiplier는 배율을 반환하며 CalcDamage/피해 적용을 호출하지 않는다. modifier caller/Apply 경로를 본문 한도 밖에서 추가 추적하지 않음 |

[코드] 확인된 일반식(정수 변환 helper `C`의 의미만 미확정):

```text
h = target.get_HitPointRate()
h_clamped = max(minHp, min(maxHp, h))
t = float32(h_clamped-minHp) / float32(maxHp-minHp)  # maxHp>minHp
t = 1.0                                           # 그 외
m = C(float32(float32(maxDamage-minDamage)*t + float32(minDamage)))
```

[코드][표] 미카 설정을 넣으면 `C(float32(10000*t+10000))`, `t=float32(clamp(h,0,10000))/float32(10000)`다. 이는 설정 범위 안의 입력에 증가하는 선형 배율이다. [?] `h=trunc(currentHp/maxHp*10000)`와 `m=10000+h`의 정수 동일성은 getter와 `C`가 미확정이므로 채택하지 않는다. 실제 피해를 재계산하지 않았다.

[코드] dis 끝의 `1815bd704` 이후는 6개 RVA의 switch 데이터이며 `xchg`처럼 표시된 마지막 줄을 실행 명령으로 해석하지 않는다. 데이터 표의 case 0은 invoker, case 1은 target, case 2..5는 대상 목록 HP rate 평균 경로다. 평균 경로의 조건부 의미는 이번 미카 Target 판정에 사용하지 않는다. helper 주소의 광범위한 code-folding 별칭 주석도 특정 runtime dispatch 증거로 사용하지 않는다.

## 표시 스탯

[코드] 40039 타입·289328 메서드 이름 전부를 `StatusDetail|StudentInfo|CharacterStat|Display|Total`로 검사했다. 후보 15233심볼은 `artifacts/jp-consumer-symbols.json`에, 실제 학생 상세/스탯 조회에 가까운 후보는 `jp-display-refined.json`에 있다. 후보는 호출/표시 확인과 구별한다. CurrentStatValue는 첫 이름 필터에 걸리지 않아 `CharacterObject`와 UI 상세 타입 메타데이터를 추가로 좁혔다.

| 후보 | RVA | 본문 판독 |
|---|---|---|
| `CharacterObject.CurrentStatValue(StatType,bool representative)` | [코드] `0x1346a40` | [코드] 이번에 판독한 조회 후보 |
| `CharacterObject.RefreshBattleSetting` | [코드] `0x1347a60` | [?] 호출 위치/메타데이터만, 본문 미판독 |
| `UICharacterInfo.SetMainStat()` | [코드] `0x239dbd0` | [?] 메타데이터 후보, 본문 미판독 |
| `UICharacterInfo.SetMainStat(uniqueId,level,starGrade,potentialStats)` | [코드] `0x239de80` | [?] 메타데이터 후보; potentialStats 인자만으로 포함을 확정하지 않음 |
| `UICharacterDetail.SetData` | [코드] `0x2365e50` | [?] 메타데이터 후보, 본문 미판독 |
| `UIAcademyMessangerStudentInfo.SetStatList` | [코드] `0x221a620` | [?] 메타데이터 후보; 인연 화면이라 학생 상세의 집계라고 간주하지 않음 |
| `BattleEntityStatFactory.CreateCharacterStat` | [코드] `0x1545a30` | [?] 메타데이터 후보; 생성 이후 추가 집계는 미판독 |

[코드] CurrentStatValue는 `characters +0x128` 캐시를 확인하고 필요 시 `RefreshBattleSetting`을 호출(`181346a80..a9c`)한다. representative=true이면 key 0, 아니면 `Style +0x88`의 값을 key로 사용(`181346aa1..ab9`)한다. 캐시에서 Character를 얻어 `get_CurrentStat`(`181346adb`) → `BattleEntityStat.get_Item(statType)` tail call(`181346afc`)로 long 값을 반환한다. 이 조회 함수 안에서 장비/무기/인연/능력개방 수치를 따로 더하는 명령은 없다.

| 집계 항목 / 결론 | 상태 | 이유 |
|---|---|---|
| 캐시된 전투 Character CurrentStat 조회 | [코드] 확인 | getter와 StatType item 조회 연결 |
| 장비 | [?] NOT_VERIFIED | 캐시 생성/갱신 본문 미판독 |
| 전용무기 | [?] NOT_VERIFIED | 같은 이유 |
| 인연 | [?] NOT_VERIFIED | 같은 이유 |
| 능력개방 | [?] NOT_VERIFIED | 이름·인자만으로 포함 여부를 확정하지 않음 |
| UI의 실제 공격력 6900이 이 반환값인지 | [?][지식] NOT_VERIFIED | UI formatter/SetMainStat와의 본문 호출 연결·정확 KR build 미확인 |
| 고유 패시브·상성 배율이 표시값에 포함되는지 | [?] NOT_VERIFIED | CurrentStat 생성과 UI 값 선택, 활성 스킬 초기화가 미판독 |

## W5b 가정 중 배제 범위

| 가정 | 이번 결과로 배제? | 근거 |
|---|---|---|
| HP modifier 자체가 범위 안에서 비선형 곡선을 적용 | [코드] 배제(Target 정상 경로) | clamp 뒤 명시 float32 선형 보간 |
| HP modifier 자체가 입력을 `1-h`로 뒤집음 | [코드] 배제(소비 함수 내부에 한정) | getter 반환을 그대로 clamp. [?] getter의 ratio 정의는 여전히 미확정 |
| 시전 때 HP를 고정하는 cache가 GetMultiplier 안에 있음 | [코드] 배제 | 매 호출 getter 사용. [?] caller의 시전/타격별 호출·반환값 저장 방식은 미확정 |
| H0_display_final(6900/21000) | [?] 배제 불가 | 표시 집계·고유 효과 반영이 미확정 |
| H1_intrinsic_not_in_display(8124/25940) | [?] 배제 불가 | 같은 이유; H1 채택 없음 |
| HP multiplier를 W5b kernel의 약점 배율 직전 위치에 곱함 | [?] 배제/확정 불가 | modifier 적용 caller와 14단계 삽입점 미확정 |
| HP BP와 최종 multiplier의 trunc 연산 | [?] 배제/확정 불가 | getter와 native 정수 변환 helper의 본문 한도 밖 |

[코드] 2라운드 종료, 함수 본문 한도 2개 소진. 추가 getter/helper/caller나 UI 집계 함수는 이번에 판독하지 않았다. Round 1 메타데이터 도구 준비 과정의 field tuple 해석 오류 2회는 실패 로그로 보존했고 본문 판독은 Round 2에만 수행했다.

[?] 보스 HP 영상은 여전히 필요하다. EX 직전 HP만으로 충분한지는 소비 함수 호출 주기가 미확정이므로 단정할 수 없다. 후속 caller 확인에서 타격별 평가로 드러나면 각 타격 직전 HP와 평타/reset 이력까지 필요하다. HP 영상만으로 표시 스탯·분배·도착·KR/JP 동등성의 미확정이 해소되지는 않는다.

[?] 최소 후속 조사 후보: `get_HitPointRate`와 native 변환 helper, modifier 적용 caller, `RefreshBattleSetting`/캐시 생성과 UI `SetMainStat`의 실제 연결. 새 블록의 함수 한도 안에서 나눠 확인해야 한다. T1 완료나 공식 피해 PASS를 선언하지 않는다.
