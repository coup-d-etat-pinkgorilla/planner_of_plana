불일치: [표] ConstCommonExcel은 지정 JP ExcelDB에 없다. 동일 버전 Excel.zip 대체 추출은 잠정이며 ExcelDB 원 행으로 가장하지 않는다. [코드] 지정 TryGetConsumeItemFavorExpParcelInfos는 선물 친화도를 계산하지 않고 FavorExp parcel 아이템의 UsingResultAmount×소비 수량을 합산한다.

# R-M3-1 선물·친화도 원천 조사 — 2026-10-20

**[코드][표] NOT_VERIFIED — 라운드 소진. 학생 태그·선물 태그·enum 원천은 확보했으나 선물 기본 경험치와 게임 태그 배율 식은 미확정이다. 기존 canonical 적용·재생성·SchaleDB 삭제는 하지 않았다.**

| 확인 항목 | 결과 | 근거 |
|---|---|---|
| TABLES 추가 | [코드] PASS | extract_jp.py에 세 표 이름만 추가. 함수·기존 TABLES 순서는 유지 |
| CharacterAcademyTagsExcel | [표] PASS | ExcelDB 원 행 275개; 전체 태그 필드·raw Bytes SHA 보존 |
| ItemExcel | [표] PASS | 전체 1884행 추출; evidence에서는 ItemCategory=6인 선물 52행만 선택 |
| ConstCommonExcel 전체 행 | [?] NOT_VERIFIED | ExcelDB에 없음. JP Excel.zip에서 1행/202필드를 잠정 해석; 원 DB rowSha 없음. decoded row SHA와 ZIP/member SHA를 별도 표시 |
| 기존 JSON 불변 | [표] PASS | 기존 로컬 21파일 전후 바이트 SHA 동일; lock exceldb-json의 16파일도 별도 검증 |
| 선물 경험치 식 | [코드] 부분 확인 | 명시 함수는 UsingResultParcelType=FavorExp(11) 아이템에 대해서만 Amount×수량 합산. 선물 52행은 모두 type=0/amount=0이라 이 경로 밖 |
| 게임 태그 배율·unique·MaxGiftTags·CommonFavorItemTags 역할 | [?] NOT_VERIFIED | 허용된 함수 두 본문에 해당 소비 경로가 없음 |
| 학생 태그 대조 | [표] 일치265 / 불일치0 / 미판정0 | 현재 canonical의 preferred/unique 태그 집합과 JP 원 행 일치. 벡터 순서 차이는 별도 기록 |
| 선물 태그 대조 | [표] 일치45 / 불일치7 / 미판정0 | 아래 원 태그 차이 표; 수정 없음 |
| 공식 친화도·기본 경험치 대조 | [?] 미판정265학생·52선물 | 식이 미확정이므로 일치/불일치를 꾸며 내지 않음 |
| 현 로컬 규칙으로 진단 | [?] 학생265 전부·선물쌍13780 일치 | 네이티브 식 확정이나 가설 채택 근거가 아님 |
| enum 확인 | [코드] 아래 차이 표 | Tag·Rarity 및 결정2 명시값은 동일; ItemCategory와 School 전체 enum에는 차이 |

## 원천과 추출 경계

[표] 버전은 JP `jp-1.73.0-e2baf70e`다. 설치 파일 SHA를 공용 manifest 및 현재 lock과 대조했다. ExcelDB SHA `a5cfbbb9c7f00ccdd82a59e100febb7ed5eb107bc8ac93c6ed0dede14418416a`, Excel.zip SHA `f9e8e721c14486a1517b627799ea03122aaa39da4f024eda3da1da7c8347c97b`다.

[코드] 기존 dump_excel_tables를 이번 호출에서 새 세 표로 제한해 실행했다. CharacterAcademyTagsExcel·ItemExcel은 성공했으나 ConstCommonExcel은 SQL 표 매핑에서 missing이었다. 가상환경의 ConstCommon reader는 MX.Data.Excel이 아닌 FlatData에만 존재하며, 해당 생성 reader의 CommonFavorItemTags slot106도 JP metadata의 slot107과 다르다. 기존 pipeline 수정 권한은 TABLES뿐이므로 import fallback이나 decoder 변경을 제품 파일에 추가하지 않았다.

[?] ConstCommon 대체 파일은 같은 JP Excel.zip의 constcommonexceltable.bytes에서 기존 entry XOR/필드 XOR 방법과 JP property 순서·accessor 반환형으로 scalar/vector를 해석했다. 별도 native accessor 증명은 없다. 전체 decoded 행은 data_list로 보존하며 문자열은 원 reader 방식의 바이트 문자열 해석이라 추가 난독 해제 검증이 없다. 이 파일을 검증된 ExcelDB 전체 행으로 소비하면 안 된다.

[?] 잠정 CommonFavorItemTags는 `[108,109,513]` → `BC,Bc,ew`다. 원천 위치의 필드 값 후보이며 실제 친화도 소비 역할은 미확정이다. rowSha는 격리된 DB Bytes hash가 아니라 canonical decoded-row SHA임을 evidence.c에 명시했다.

## 지정 함수 판독

| 함수 | RVA·경계 | 판독 범위 |
|---|---|---|
| CharacterDBService.TryGetConsumeItemFavorExpParcelInfos | [코드] RVA0x1363fc0, VA0x181363fc0..0x18136441f, 1119bytes | 실행 가능 섹션 + exact unwind |
| 직접 호출 helper ItemData.GetData | [코드] RVA0x1a240e0, VA0x181a240e0..0x181a24152, 114bytes | 실행 가능 섹션 + exact unwind; callsite0x181364284 |

[코드] 입력은 itemDBs, targetCharacterUniqueId, consumeServerIdAndCounts이고 출력은 parcelInfos/parcelCost다. 스택 인자를 포함한 메타데이터 서명은 artifacts/callee-metadata.json에 있다. GetData는 itemId의 ItemExcel 구조체를 반환한다. 같은 getter native 주소에 여러 타입 별칭이 접혀 있으므로, 반환형 ItemExcel의 메타데이터 심볼만 의미 판정에 사용했다.

| 분기·계산 | 명령·의미 |
|---|---|
| 아이템 조회 | [코드] 0x181364284 → MX.Data.ItemData.GetData(itemId) |
| parcelType 필터 | [코드] 0x181364298 → MX.Data.Excel.ItemExcel.get_UsingResultParcelType; 0x18136429d compare 0xb; 다르면 다음 아이템 |
| 기본 Amount 읽기 | [코드] 0x1813642ad → MX.Data.Excel.ItemExcel.get_UsingResultAmount |
| 소비 수량 곱·합 | [코드] 0x1813642b2..2ba: requestedCount 부호 확장 후 Amount 곱하여 r12 누적 |
| 최종 parcel | [코드] 0x1813643a7..3ba: targetCharacterUniqueId, 누적 Amount, FavorExp11로 생성; 양수 합계만 성공 |

```text
# [코드] 이 함수에 한정한 식; Cafe 선물 식으로 일반화하지 않음
sumExp = sum(ItemExcel.UsingResultAmount * requestedCount
             for accepted inventory items
             if ItemExcel.UsingResultParcelType == FavorExp(11))
```

[표][코드] 선물 52행의 UsingResultParcelType와 UsingResultAmount는 전부 0이다. 따라서 이 함수에서 0을 얻었다고 선물 경험치가 0이라고 판정하지 않는다. 현재 exp_value 20/60을 Rarity나 Quality에 맞춰 역산하지도 않는다. 이 함수 안에는 Tag·MaxGiftTags·CommonFavorItemTags·Rarity/Quality 읽기나 태그 수 배율이 없다.

[?] 아직 답할 수 없는 것: 실제 선물 한 개의 기본 경험치 원천, 태그 일치 1개/2개 이상/unique의 계수, MaxGiftTags의 cap 역할, CommonFavorItemTags의 보너스 역할. 후속 metadata 후보는 ItemData.SplitFavorItemIdsByTagCount(RVA0x1a260b0), UICharacterGiftMatchListPopulator.BuildFavorItems(RVA0x2367800), UICafeGiveGiftPopup의 미리보기 경로다. 이번에는 본문을 추가로 읽지 않았다.

## 현재 canonical 전수 대조

[표] identity join은 CM 결정대로 기존 crosswalk 후보의 existing_numeric_id와 현재 provider_refs.schaledb.student_ids 일치를 확인한 뒤 사용했다. 후보 catalog canonical SHA는 현재와 같고 lock canonical SHA는 현재와 다르다. student-stats 추가 뒤 새 crosswalk 바인딩은 XB 후속 작업이며 이 워커가 파일을 고치지 않았다.

| 비교 | 일치 | 불일치 | 미판정 |
|---|---:|---:|---:|
| 학생 preferred/unique 태그 집합 [표] | 265 | 0 | 0 |
| 선물 태그 집합 [표] | 45 | 7 | 0 |
| 공식 게임 친화도 학생 단위 [?] | 0 | 0 | 265 |
| 공식 게임 친화도 학생×선물 [?] | 0 | 0 | 13780 |
| 선물 기본 exp_value [?] | 0 | 0 | 52 |
| 현재 로컬 배율 규칙을 양쪽 원천에 적용한 진단 [?] | 13780 | 0 | 0 |

[?] 마지막 진단은 현재 규칙 `preferred ? 1+min(3,공통·선호·고유 태그 교집합수) : 1`과 JP MaxGiftTags/잠정 common 값을 사용하는 입력 대조다. 게임 공식 일치나 source 전환 승인이 아니다. 선호 태그 일치가 없으면 공통 태그만으로 배율을 올리지 않는 것도 현 로컬 규칙이며 소비 코드로 검증하지 않았다.

### 불일치 사례 (최대 10건)

[표] 학생 태그와 배율 진단에 불일치가 없어 학생별 배율 차이 사례는 없다. 실제 선물 메타데이터 차이 7건을 아래에 그대로 적는다. 추가된 JP 태그는 현재 265학생의 선호·고유 태그에서 사용되지 않아 진단 배율은 바뀌지 않았다. 원인이 SchaleDB 오류인지 버전 차이인지 식 해석 문제인지는 단정하지 않는다.

| 학생 범위 | 선물 ID | 현재 태그만 | JP 태그만 | 원인 후보 |
|---|---:|---|---|---|
| [표] 현재265에서 배율 차이 없음 | 5004 | [] | ['iK', 'ij'] | [?] 선물 태그 snapshot 차이 |
| [표] 현재265에서 배율 차이 없음 | 5015 | [] | ['iJ', 'ii'] | [?] 선물 태그 snapshot 차이 |
| [표] 현재265에서 배율 차이 없음 | 5017 | [] | ['iB', 'iC', 'ia', 'ib', 'ic'] | [?] 선물 태그 snapshot 차이 |
| [표] 현재265에서 배율 차이 없음 | 5101 | [] | ['iI', 'iK', 'ih', 'ij'] | [?] 선물 태그 snapshot 차이 |
| [표] 현재265에서 배율 차이 없음 | 5105 | [] | ['iC', 'iD', 'ib', 'ic'] | [?] 선물 태그 snapshot 차이 |
| [표] 현재265에서 배율 차이 없음 | 5110 | [] | ['iJ', 'ii'] | [?] 선물 태그 snapshot 차이 |
| [표] 현재265에서 배율 차이 없음 | 5111 | [] | ['iB', 'ia'] | [?] 선물 태그 snapshot 차이 |

[표] 전체 현재 태그·계산 입력·원 행 SHA와 공식 미판정 사유는 evidence.f에 보존했다. canonical 및 generated gift/student 데이터 파일은 수정하지 않았다.

## enum: JP global-metadata 대 Steam r464491

| enum | JP 상수 수 | Steam 차이 수 | 결론 |
|---|---:|---:|---|
| Tag | [코드] 3004 | [코드] 0 | 동일 |
| ItemCategory | [코드] 12 | [코드] 5 | JP 값 사용; 아래 차이 |
| Rarity | [코드] 4 | [코드] 0 | 동일 |
| School | [코드] 18 | [코드] 1 | JP 값 사용; 아래 차이 |
| BulletType | [코드] 8 | [코드] 0 | 동일 |
| ArmorType | [코드] 7 | [코드] 0 | 동일 |
| TacticRole | [코드] 6 | [코드] 0 | 동일 |
| WeaponType | [코드] 22 | [코드] 0 | 동일 |
| TacticRange | [코드] 3 | [코드] 0 | 동일 |

| enum / 상수 | JP | Steam |
|---|---:|---:|
| ItemCategory.BattlePass | [코드] 9 | [코드] 10 |
| ItemCategory.InvisibleToken | [코드] 8 | [코드] 9 |
| ItemCategory.MonthlyBonus | [코드] None | [코드] 8 |
| ItemCategory.ProductDailyRecord | [코드] 11 | [코드] 12 |
| ItemCategory.ProductSelect | [코드] 10 | [코드] 11 |
| School.Odyssey | [코드] 17 | [코드] None |

[코드] ItemCategory.Favor=6, Rarity N0/R1/SR2/SSR3 및 Tag 상수는 양 빌드에서 같다. ItemCategory 후반부에는 실제 숫자 차이가 있으므로 Steam 번호 전체를 JP로 복사하지 않는다. School.Odyssey=17은 JP 추가 상수다.

### 결정2 번역 표

| enum | 22:30 명시 매핑과 JP 차이 | 표에 빠진 JP 상수 |
|---|---|---|
| School | [코드] 0건 | [코드] {'None': 0, 'Odyssey': 17} |
| BulletType | [코드] 0건 | [코드] {'None': 5} |
| ArmorType | [코드] 0건 | [코드] {} |
| TacticRole | [코드] 0건 | [코드] {'None': 0} |
| WeaponType | [코드] 0건 | [코드] {'None': 0, 'Binah': 16, 'Akemi': 20, 'KetherCannon': 21} |
| TacticRange | [코드] 0건 | [코드] {} |

[코드] 명시된 School/BulletType/ArmorType/TacticRole/WeaponType/TacticRange 매핑은 모두 동일하다. 표에 빠진 None/Binah/Akemi/KetherCannon/Odyssey 등은 추가 상수이며 기존 매핑의 숫자 충돌이 아니다. 해당 local 라벨을 자동 승인하거나 crosswalk를 쓰지 않았다.

## 시도·한도 및 후속

[코드] 라운드 한도2 소진. 원천 단계의 ConstCommon 부재·리더 namespace/slot 차이를 기록하고 두 DB 표 원 행 SHA를 확보했다. 소비 단계는 지정 본문1개와 직접 호출 114bytes helper1개만 판독했다. 추가 후보 본문 판독·관측 기반 보정은 하지 않았다.

[코드] 원천 위치 검사에서 불필요한 표 버퍼 repr이 로그에 포함됐으나 인계 전에 제거했다. JP/Steam 키 값은 출력되지 않았다. Windows SQLite 연결이 열린 채로 임시 폴더 정리가 실패한 실행은 로그로 보존하고, 프로세스 종료 뒤 같은 임시 DB로 행 SHA를 수집한 후 명시적으로 닫고 지웠다. 인계 artifacts에 원 게임 파일이나 임시 평문 DB는 없다.

[?] MASTER_REQUIRED: 실제 선물 소비/배율 함수를 별도 블록으로 지정해 기본 경험치와 태그 계수·공통 태그/MaxGiftTags 역할을 확인한다. ConstCommon 전체행을 정식 소비하려면 JP layout/문자열·벡터 디코드 검증과 Excel.zip 출처 승인이 필요하다. evidence 전체의 상태를 PASS로 승격하지 않는다.

[코드] 기존 함수는 TABLES 외 변경하지 않아 일반 extract_jp.py 전체 실행에 ConstCommon namespace/미존재 표 문제가 남는다. 후속 pipeline 지원 수정은 별도 권한이며 이번 블록을 이유로 범위를 확장하지 않는다.

[?] 저장소 import 명령은 worker output.md에 준비만 남겼다. evidence의 NOT_VERIFIED와 ConstCommon 잠정 출처를 검토한 뒤 CM 승인·사용자 실행이 필요하다.


## R-M3-2 보충

[코드] JP 동일 pin을 정적 조사했다. 라운드 한도 2, native 본문 한도 3을 모두 사용했다. 아래 내용은 앞의 R-M3-1 미확정 결론을 부분 보충하며, 기존 본문·원 evidence는 수정하지 않았다.

| 항목 | 결과 | 근거 |
|---|---|---|
| 기본 경험치 원천 | [코드] **ItemExcel.StackableFunction** | CanGiveGiftToCharacter, RVA `0x1334320`; getter 호출 VA `0x1813347be` |
| 현재 exp_value 대조 | [표][코드] **일치 52 / 불일치 0 / 미판정 0** | 전체 Favor 행의 해당 필드와 현재 GIFT_ITEMS를 전수 비교 |
| 캐시 입력 이후 경험치 식 | [코드] PASS | 아래 식; 지급 함수와 계수 overload 두 개가 같은 교집합·상한 연산 사용 |
| 원천 표부터의 완전한 경험치 식 | [?] **NOT_VERIFIED** | AcademyData의 학생 태그 캐시 구성 미판독 |
| 학생 전체 조합 판정 | [?] 학생 일치 0 / 불일치 0 / 미판정 265; 선물쌍 일치 0 / 불일치 0 / 미판정 13,780 | unique·공통 태그가 캐시에 들어가는 조건을 추정으로 메우지 않음 |

### 확인한 지급 경로와 식

[코드] 실제 경로는 `MX.GameLogic.Service.CafeService.CanGiveGiftToCharacter` 중 CharacterDB·ConsumeRequestDB·itemDBs·rewards/out·cost/out 서명의 overload다. RVA `0x1334320`, 크기 1,639 bytes, 실행 가능 섹션과 exact unwind를 확인했다. ItemData.TryGetValue/TryGetTags와 AcademyData.TryGetCharacterFavorItemTags의 결과를 사용한다. `UsingResultAmount`나 Rarity별 표를 읽는 계산이 아니다.

[코드] 캐시에서 받은 학생 태그 목록을 C, 아이템 태그를 T라고 놓으면, 선물 한 개의 지급 경험치는 다음과 같다. C를 원천 행의 특정 태그 벡터와 같다고 가정하지 않는다.

```text
[코드] n = Count(Intersect<FlatData.Tag>(C, T))
[코드] coefficient = 1 + Math.Min(n, ItemExcel.MaxGiftTags)
[코드] expOne = ItemExcel.StackableFunction * coefficient
```

[코드] `Intersect<Tag>`와 `Count<Tag>`는 encoded metadata methodSpec과 실제 호출 직전 MethodInfo 슬롯을 함께 읽어 확인했다. 교집합은 중복을 제거한 태그 수다. `System.Math.Min(int,int)`는 VA `0x1860833d0`의 metadata method pointer로 확인했다. 별도의 helper 본문 판독은 하지 않았다. C가 null이면 교집합 개수 0, T가 null이면 빈 태그 열거를 사용한다.

[코드] 지급 함수의 핵심은 VA `0x181334778` Intersect, `0x181334787` Count, `0x1813347b0` Min, `0x1813347be` StackableFunction, `0x1813347c3` +1, `0x1813347c9` 요청 수량 곱, `0x1813347d0` 기본 경험치 곱이다. VA `0x18133486a..0x18133487d`에서 계산 결과를 FavorExp(parcel type 11)에 넣는다. 여러 소비 항목의 누적 parcel 동작은 별도 일반화하지 않고 과제의 선물 한 개 범위로 판정했다.

[코드] 계수 overload는 `CalcGiveGiftTagCoefficient(ParcelInfo,long)` RVA `0x1333db0` / 598 bytes와 `CalcGiveGiftTagCoefficient(List<Tag>,List<Tag>,int)` RVA `0x1334010` / 272 bytes다. 둘 다 같은 Count(Intersect) → Min(maxGiftTags) → +1을 사용한다. 판독 본문은 이 둘과 지급 함수로 총 3개다. UI 호출부·AcademyData 전처리·추가 getter 본문은 판독하지 않았다.

[표][코드] 현재 Favor 아이템 52개는 모두 MaxGiftTags=3이다. **C에 포함된 태그 기준**으로 일치 0/1/2/3개 이상일 때 계수는 1/2/3/4다. 이 결과만으로 원천 unique 태그의 계수나 친화도 명칭을 확정할 수는 없다.

### 기본값 전수 대조

[표][코드] `data/extracted/jp-json/ItemExcel.json` 전체 행의 `stackable_function`을 기존 evidence의 아이템 ID·raw rowSha와 결합했다. 현재 `backend/core/gift_meta_data.py`의 GIFT_ITEMS literal을 실행 없이 AST로 읽어 52개 전체를 비교했다. 일치 52, 불일치 0, 미판정 0이다. 상세는 `debug/cm_r_m3_2_20261020/artifacts/base-exp-comparison.json`에 있다.

| Rarity / Quality | 아이템 수 | StackableFunction | 현재 exp_value와 대조 |
|---|---:|---:|---|
| [표] SR(2) / 3 | [표] 35 | [표] 20 | [표][코드] 전부 일치 |
| [표] SSR(3) / 4 | [표] 15 | [표] 60 | [표][코드] 전부 일치 |
| [표] SSR(3) / 4, ID 5998·5999 | [표] 2 | [표] 20 | [표][코드] 전부 일치 |

[표][코드] Rarity/Quality만으로 기본값을 만들면 마지막 예외를 잃는다. 이 지급 함수는 행의 StackableFunction을 직접 읽는다. canonical·동결 snapshot·원 evidence를 재생성하거나 적용하지 않았다.

### 남은 불확실성과 전수 비교의 한계

[코드] 세 판독 본문에는 unique 태그 전용 가산/배율 분기와 ConstCommon 필드 직접 읽기가 없다. 학생 태그는 `AcademyData.TryGetCharacterFavorItemTags` 호출에서 받아온다. metadata에는 characterFavorItemTags 캐시가 있으나 그 내용이 `FavorItemTags`, `FavorItemUniqueTags`, `CommonFavorItemTags`에서 어떻게 구성되는지는 확인되지 않았다. 따라서 unique를 무시한다거나 common이 사용되지 않는다고 결론 내리지 않는다.

[?] 현재 canonical 265명 × Favor 52개의 13,780쌍은 모두 원 행 ID·rowSha에 결합했다. 현재 등급·배율·점수는 `pair-comparison.csv`에 기록하되, 게임 캐시 입력이 미확정이므로 native 배율·점수는 비워 두었다. 학생 기준 일치 0 / 불일치 0 / 미판정 265, 쌍 기준 일치 0 / 불일치 0 / 미판정 13,780이다. 불일치 상위 10개는 판정 가능한 쌍이 없어서 빈 목록이며, 완전 일치를 뜻하지 않는다. 이전 로컬 규칙 진단의 13,780 일치를 native 판정으로 승격하지 않았다.

[코드][?] ConstCommon의 실제 필드 읽기가 이번 본문에서 확인되지 않아 조건부 교차 검증은 수행하지 않았다(대상 필드 0). 이전 ZIP decoder의 PROVISIONAL_DECODER 상태도 유지한다. 전체 202필드를 다시 읽거나 검증하지 않았다.

[코드] 후속 본문 후보 3개: `AcademyData.TryGetCharacterFavorItemTags` RVA `0x19a9b50` / 100 bytes, `AcademyData.PreprocessCommon` RVA `0x19a8420` / 5,936 bytes, `AcademyData.PrepareInitialData` RVA `0x19a6930` / 6,884 bytes. 현재는 metadata 후보이며 내부 내용이나 호출 관계를 확정한 것이 아니다. 새 블록이 허용하면 캐시 쓰기 경로를 확인하고, 실제 CommonFavorItemTags 읽기가 나오는 경우에만 해당 필드 디코드를 교차 검증해야 한다.

[?] **라운드 소진, 후속 후보 3개, 원천 표부터의 전체 식 미확정.** 기본 경험치 원천과 캐시 입력 이후의 정수 산식은 [코드]로 확인했다. 적재·canonical 적용·네트워크 요청·키 접근은 수행하지 않았다.
