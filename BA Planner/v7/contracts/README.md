# IPC contracts

Flutter와 Python 백엔드는 제품 버전과 별개인 protocol version을 사용합니다.
초기 protocol은 `1`이며 모든 메시지는 `protocol`, `id`, `type`, `method`,
`payload` 공통 필드를 갖습니다.

planning 수직 슬라이스는 아래 method까지 확정했습니다. scanner와 repository
이전 전에는 해당 영역의 method별 request/response/event schema, cancellation,
session generation을 별도 계약으로 고정합니다.

## 공통 envelope

모든 메시지는 `protocol-envelope-v1.schema.json`을 따릅니다.

- `protocol`은 정수 `1`로 고정합니다.
- `id`는 비어 있지 않은 문자열입니다. 응답은 성공과 오류 모두 요청과 동일한
  `id` 및 `method`를 사용합니다.
- `type`은 이번 planning 계약에서 `request` 또는 `response`입니다. 공통 envelope의
  `event`는 이후 scanner/status 계약을 위해 예약되어 있습니다.
- method별 성공 응답과 `protocol-error-v1.schema.json` 오류 응답은 모두 공통
  envelope의 하위 계약입니다.

`planning-protocol-v1.schema.json`은 현재 알려진 planning 메시지를 한 번에 검증하는
진입점입니다. 따라서 알 수 없는 method의 request는 이 schema에 맞지 않으며,
서버는 원래 method와 id를 유지한 `unknown_method` 오류로 응답해야 합니다.

## planning method

### `planning.student.get`

학생 정적 메타데이터 한 건을 ID로 조회합니다.

- request payload: `{ "student_id": <non-empty string> }`
- success response payload: `{ "student": <student metadata | null> }`
- 학생이 존재하지 않는 것은 시스템 실패가 아니므로 `student: null`입니다.
- 메타데이터 소스를 읽거나 조회하는 과정 자체가 실패하면
  `metadata_lookup_failed` 오류입니다.

스키마는 `planning-student-get-v1.schema.json`입니다. 응답 metadata는
`student_id`, `display_name`, `template_name`, `group`, `variant`를 기본 필드로
제공하며, 정적 메타데이터 확장을 위해 그 밖의 필드를 허용합니다. wire 응답을
만들 때 lookup key인 `student_id`를 metadata 객체에 추가하고,
`student_meta.get(student_id)`가 반환한 나머지 key/value는 이름이나 값의 별도
정규화 없이 그대로 전달합니다. 예를 들어 `template_name`은 현재 backend 값인
`ayane.png`이며 확장자를 제거하지 않습니다.

### `planning.student.catalog`

학생 탭·계획 학생 선택이 쓰는 전체 학생 목록입니다.

- request payload: `{}` (그 밖의 key는 `invalid_payload`)
- success response payload:
  `{ "students": [<catalog entry>...], "sort": "display_name_then_id" }`
- 학생 항목은 고정된 19개 필드(`student_id` … `kr_search_tags`, `has_favorite_item` 포함)를 가지며 알 수 없는
  필드를 거부합니다.
- **`has_favorite_item`(FB-13, 필수 bool)**: **KR 서버에서 애장품이 제공되는 학생인지**를
  `student_meta.favorite_item_enabled(student_id, server="kr")`로 판정합니다. JP 서버 제공 여부,
  프로필의 현재 보유·장착 여부, 성장 목표 `equip4_tier`와 다릅니다. 요청에 server 선택은 없으며,
  모든 항목에 JSON `true` 또는 `false`를 보냅니다. 누락·`null`·문자열 `"yes"`/`"no"`·숫자는 거부합니다.
  - Dart `StudentCatalogEntry.fromWire`에서도 필수 bool입니다. 수동 DTO 생성자는 기존 대역 호환을
    위해 생략 시 `false`로 두며, `fallback`(예: `missing-student`)도 `false`입니다. 메타데이터가
    없다는 이유로 실제 애장품 제공 학생으로 간주하지 않습니다. `metadata` getter는 bool을 전달합니다.
  - 새 backend·DTO·mock asset·fixture는 같은 slice와 배포 묶음으로 갱신합니다. 이전 wire 항목의
    누락을 허용하는 fallback은 없습니다. 번들 mock은 exporter가 runtime catalog builder를 재사용하며
    가용성과 다중 폼 목록을 함께 보존합니다.
- **`forms`(FB-5, 2026-10-07, 선택 필드)**: 폼이 2개 이상인 학생에게만 붙고 폼 순서대로
  `{ "form_id", "label", "template_name" }`을 담습니다(`minItems` 2). 폼이 1개이거나 없는
  학생은 필드 자체를 뺍니다(빈 목록을 보내지 않습니다).
  - `form_id`: canonical 폼 참조. 첫 폼은 `student_id`, 그 뒤는 `student_id#n`
    (`student_meta.format_form_ref`와 같은 규칙).
  - `label`: canonical metadata의 폼 label. 비어 있으면 1부터의 순번 문자열.
  - `template_name`: 폼 초상 파일 이름(UI는 `assets/student_portraits/<template_name>`).
    폼이 이름을 선언하지 않으면 `null`이고, UI는 기존 플레이스홀더를 그립니다.
  - 기존 필드의 의미·순서는 바꾸지 않고 `forms`는 항목 끝에 붙습니다.
  - 호환성: FE3-e 이전 Dart 클라이언트의 `StudentCatalogEntry.fromWire`는 key 집합을
    정확히 비교하므로 `forms`가 있는 항목을 거부합니다. 앱은 UI와 backend를 한 묶음으로
    배포하므로(`release/`) 구버전 UI가 새 backend와 함께 돌지 않습니다. FE3-e부터 Dart는
    `forms`를 선택 key로 받습니다.

### `planning.student.calculate` (FB-11a/b)

학생 한 명의 휘발 성장 목표를 한 번에 계산합니다. 기존 `planning.student.*` 명명 규칙을
따르며 FD-162(b)의 이름을 그대로 사용합니다. 저장된 문서 ID, 프로필 ID가 필요 없고
저장소 쓰기나 활성 계획 변경이 없습니다. 활성 계획 수치의 원천은 계속 FD-026의
`planning.document.calculate`입니다.

| 입력 | 의미 |
| --- | --- |
| `current_student` | 기존 `current_students` 항목과 같은 strict currentStudent 객체 |
| `targets` | 문서 v1과 같은 필수 19 key·정수 범위·성장 규칙. 정규화된 목표를 보내며 잘못된 조합은 `invalid_payload`. 문서 v2의 nullable 목표는 받지 않음 |
| `inventory` | 선택 inventorySnapshot. 생략하면 빈 재고로 계산하며 미확인 보유·부족은 `null` |

| 출력 | 의미 |
| --- | --- |
| `totals` | `{ "credits": <보유 차감 전 합계> }` |
| `credit_breakdown` | 아래 9범주 모두 포함. 비용이 없으면 0. 합은 `totals.credits`와 같음 |
| `resources` | 문서 계산 `overall.resources`와 같은 행·순서(크레딧 행 포함) |
| `warnings` | 기존 계산 코어의 문자열 경고 |
| `bond` | 선택 요청 bond가 있을 때만 나오는 strict FB-11b 인연 경험치·선물 3안. 기존 요청은 계속 생략 |

범주: `level`(학생 레벨), `student_star`(성급), `weapon_star`(전무 성급),
`favorite_item`(애장품), `equipment`(일반 장비 3칸의 티어·레벨), `ex_skill`(EX),
`weapon_level`(전무 레벨), `skill`(일반 스킬 3개), `potential`(능력 개방 3종).
의존 목표로 발생하는 비용도 실제 비용 범주에 들어갑니다. 범주마다 별도 정규화·재계산하지
않고 `planning_calc`가 비용을 더하는 지점에서 한 번 집계합니다.

재화 행은 `resource_key`, `item_id`, `display_name`, `category`, `required`, `owned`,
`shortage`, `affected_stage_ids`를 갖습니다. 모르는 보유와 부족은 `null`이며 명시적인 보유
0과 다릅니다. 미해결 재화도 문서 계산과 같은 `unresolved:` 키로 유지합니다.
`affected_stage_ids`는 기존 임시 계산기 문서와 일치하는 `["growth-calculator-stage"]`입니다.
이 값은 휘발 계산 출처이며 저장 ID가 아닙니다. 재고는 총 비용·범주 합에 영향을 주지 않습니다.

기존 1페이즈 1단계 계산 경로를 내부에서 재사용하므로 같은 현재값·목표·재고이면
크레딧 합계, 재화 행, 경고가 문서 계산과 같습니다. 입력 객체도 변경하지 않습니다.
오류는 `invalid_payload` 또는 `calculation_failed`입니다. 스키마는
`planning-student-calculate-v1.schema.json`, 공용 fixture는
`fixtures/planning_student_calculate_v1.json`입니다.

Dart 공개 호출은 `AppService.calculateStudent` 확장 메서드이며
`PlanningStudentCalculationService` 기능 인터페이스에 위임합니다. 기존 AppService 구현자
(프런트 위젯 테스트 대역 포함)를 깨뜨리지 않는 추가 확장입니다. ProcessAppService와
MockAppService가 같은 DTO를 반환합니다. mock은 공용 fixture의 결정론적 서비스 대역이며
성장 계산식을 Dart로 복제하지 않습니다.

#### FB-11b 인연 입력과 결과

추가 입력은 `bond: {"current_rank": 12}`입니다. 목표는 기존 필수 19-key의
`targets.bond_rank`(1~100)를 사용하므로 목표를 두 군데에 복제하지 않습니다.
current_rank는 1~100 또는 null(현재 미확인)입니다. bond를 생략한 기존 호출의 성공
필드·비용·재화·경고는 그대로입니다. 랭크 안 진행도와 추가 필드는 받지 않습니다.

응답 bond는 다음 필드만 허용합니다. 세부 schema는
`planning-student-bond-v1.schema.json`, 7건의 공용 fixture는
`fixtures/planning_student_bond_v1.json`입니다.

| 필드 | 의미 |
| --- | --- |
| current_rank / target_rank | 입력 현재 랭크 / 기존 targets의 목표 랭크 |
| assumption | 항상 `current_rank_start`: 현재 랭크 안 경험치는 0으로 가정 |
| source_version / favor_levelup_type | `jp-1.73.0` / 확인된 학생 그룹, 모르면 null |
| required_exp | 현재 L부터 목표 T 직전까지 ExpType[g−1] 합. 목표≤현재는 0; 현재·그룹 미확인은 null |
| plans.preferred_large | 선호 태그가 실제로 매칭되는 SSR(대형) 선물 안 |
| plans.normal | SR(일반) 선물 안. 선호가 있으면 그 배수도 적용 |
| plans.petting | 1회 15 경험치, 간격 3시간, 필요 횟수·최소 간격 시간·미확인 가능 횟수 |
| warnings | 인연 계산의 데이터 부족 경고. 성장 계산의 기존 warnings와 분리 |

선호 배수는 개발자 도구의 규칙을 도메인 `core.student_bond.gift_affinity`로 옮겼습니다.
preferred 또는 unique 태그가 실제 매칭될 때, 두 태그 집합과 보편 태그 BC/Bc/ew를 합쳐
선물 태그와의 매칭 수를 최대 3으로 제한합니다. 배수는 1+매칭 수(1~4), 경험치는
gift_meta.exp_value×배수입니다. 매칭이 없으면 배수 1입니다. 개발자 도구·metadata 파일은
수정하지 않았고 runtime에서 개발자 도구를 import하지 않습니다.

각 선물 안은 독립적으로 같은 보유량을 평가하며 다른 안에서 소비한 것으로 간주하지
않습니다. FD-164대로 보유 수가 많은 선물부터 필요한 만큼 사용합니다. 동률은 경험치
내림차순, gift ID 오름차순입니다. 부족하면 해당 안의 1개 경험치가 가장 높은 선물로
ceil(잔여 경험치/1개 경험치)개를 추가합니다. 선물 ID를 reviewed present resource_key와
연결하며, 이름 추측·numeric gift ID를 inventory identity로 취급하지 않습니다.

gift 행은 gift_id, resource_key, display_name, base_exp, multiplier, exp_per_gift,
owned, required, used_owned, shortage를 포함합니다. required는 보유 사용+추가 필요의 합,
used_owned는 확인된 보유에서 쓴 수입니다. 보유 누락/null은 미확인이므로 배분에 쓰지
않습니다. fallback 선물 보유가 미확인이면 행·안의 shortage=null, 명시적 0이면 부족 수를
표시합니다. inventory_complete는 그 안의 후보 보유가 모두 알려졌는지이며, 확인된 보유만
사용하는 잠정 결과에는 경고가 붙습니다. 선호 대형 후보가 없으면 available=false입니다.

쓰다듬기는 required_count=ceil(required_exp/15),
minimum_hours=max(required_count−1,0)×3입니다. first_interaction=`immediate`는 **첫 회를
즉시 할 수 있다고 가정한 간격만의 하한**입니다. 실제 방문·서버 제한·리셋을 판정하지
않습니다. available_count는 항상 null이며 가능 횟수는 [?]입니다. 24/3으로 하루 8회를
만들거나 시안의 하루 2회·일수를 사용하지 않습니다. 미확인 현재는 필요 경험치·횟수·시간도
null입니다. 같은/낮은 목표는 0 경험치·0회·0시간입니다.

FD-165: 선택한 안의 선물·부족 수를 totals, credit_breakdown, 성장 resources에 넣지
않습니다. 기존 성장 재화 자체의 present 행(예: 애장품 재료)은 그대로입니다. 문서 v2의
"Bond growth cost is unavailable" 경고도 유지합니다. 선물은 문서의 크레딧 계산 범위 밖입니다.

자료는 승인된 W4/W4b의 JP 1.73.0 snapshot입니다. KR/다른 빌드의 서버 동작을 검증한
것으로 해석하지 않습니다. portable runtime 사본은 core/student_bond_data.py에 있으며
공용 저장소나 data/extracted 경로에 런타임 의존하지 않습니다.

| 근거 | 꼬리표와 해시 |
| --- | --- |
| FavorLevelExcel 100행 | [표] rows SHA256 `ea46aef8d84687a66c0854b1f40a39b5d1ea5284fa80100ddb66632e24724c85` |
| FavorData.Levelup, W4b `a107c3f2`, RVA 0x1a1bae0 | [코드] L→L+1 필요량 차감, 그룹 g 유효 범위 검사 후 g−1. evidence SHA256 `5af3d6e8923cc28db3f0e0e5a20edd0dd4e6d1da3ca9299efb8c787021d3c9db` |
| CharacterExcel 그룹 | [표] file SHA256 `2ff635b1340a88c02a35ececdb16fbeb99c100c08793102c314f78ffe70f385c`; Cafe 276명 그룹=1, 현재 canonical 265명 모두 매칭 |
| CafeInteractionExcel 276행 | [표] FavorExp(11)/Id=0/Amount=15, rows SHA256 `d02f4a7d0e46ff190cb34b05e46badb5177d7f6c5b42ffd32eaa8e2f9ddcb430` |
| CafeService.get_InteractCooltime, RVA 0x1338160 | [코드] TimeSpan.FromHours(3.0), dis SHA256 `c8ceb20c2136d473dd4f1417a262e9f1527d573ea4597bebb4946d15caff2a7e` |
| 가능 횟수·서버 강제·방문/리셋 | [?] 미확인, available_count=null |
| ItemDBSchema gift ID→present identity/rarity | [표] reviewed item-rarity-v1.json SHA256 `83d3eff626ced570b3ca544b23a5f0e66109367bc77cdd7c96038c80502a11d2`, Steam 2026-09-27 식별자 근거. 경험치는 gift_meta의 Schale 최소 정의 |

원 근거: `docs/tactic-editor/evidence/favor-cafe-tables-jp-1.73.0.json` 및 W4b의
`debug/five_followup_coord_20261008/w4b/artifacts/dis/MX.Data.FavorData.Levelup.txt`.
등록된 경험치 선물은 52종이며 상자·KR 행사 선물 등 exp_value 없는 present는 추측하지
않습니다. 자료가 부족한 학생/그룹은 경고와 미확인 결과를 반환합니다.

Dart는 `AppService.calculateStudent(..., bond: StudentBondRequest(currentRank: ...))`로
한 번 호출하고 `result.bond`의 strict immutable DTO를 읽습니다. 기존 성장 전용 기능
인터페이스는 그대로이고 추가 PlanningStudentBondCalculationService에 위임합니다.
reservedBond는 검증된 wire의 호환 뷰로 남습니다. MockAppService는 공용 fixture 7개에
해당하는 학생·랭크·보유 입력만 재생하며 나머지는 UnsupportedError입니다. 임의 계산을
Dart에 복제하거나 다른 랭크 결과를 현재 요청의 결과로 돌려주지 않습니다.

### `planning.plan.validate`

저장된 계획 형태를 역직렬화하고 검사한 뒤 wire에 사용할 canonical plan을
돌려주는 경계입니다. 실제 파일 I/O를 수행하라는 의미는 아닙니다.

- request payload: `{ "plan": { "version": 1, "goals": [...] } }`
- success response payload:
  `{ "valid": true, "plan": <canonical growth plan> }`
- 잘못된 필수 필드, 타입 또는 범위는 `invalid_payload` 오류입니다.

스키마는 `planning-plan-validate-v1.schema.json`입니다. `target_*` 값의 `null`은
현재 값을 유지한다는 뜻이며 숫자 `0`과 다릅니다. canonical response는 서버가
인식하는 필드만 직렬화하므로 무시된 미래 필드는 응답에서 제거될 수 있습니다.

### `planning.plan.calculate`

현재 학생 상태와 사용자 목표로 보유량 차감 전 총 필요량을 계산합니다.

- request payload:
  `{ "current_students": [...], "plan": { "version": 1, "goals": [...] } }`
- success response payload: `{ "totals": <PlanCostSummary> }`
- 계산 실패는 `calculation_failed`, 입력 형태가 잘못된 경우는
  `invalid_payload` 오류입니다.

스키마는 `planning-plan-calculate-v1.schema.json`입니다. `current_students`는
스캔된 현재 상태, `plan.goals`는 사용자 목표, `totals`는 총 계산 결과입니다.
인벤토리 보유량과 부족량은 이 payload에 포함하지 않습니다.
`calculate_goal_cost()` 및 `calculate_plan_totals()`과 동일하게 `totals`는
보유량을 차감하지 않습니다.

### 계획 문서 v2: nullable 절대 목표 (FB-1a)

`planning.document.calculate`와 시나리오 저장·조회·비교는 문서 v1과 v2를 모두 읽습니다.
IPC envelope와 시나리오 저장소의 바깥쪽 버전은 계속 1입니다.

| 계약 | 문서 v1 | 문서 v2 |
| --- | --- | --- |
| 문서 필드 | `version`, `document_id`, `name`, `kind`, `phases` | 왼쪽 필드 + 필수 `goal_metadata` |
| 단계 `targets` | 필수 19 key, 정수 | 같은 19 key, 정수 또는 `null` |
| `bond_rank` | 1~100 | `null` 또는 1~100 |
| 학생별 메모 | 없음 | `goal_metadata[student_id] = {favorite: bool, notes: string}` |
| 성장 선행 조건 | 정규화된 목표 조합을 입력에서 검사 | 실제 현재값과 목표를 계산 중에 결합 |

v2의 `null`은 그 항목의 목표가 없다는 뜻입니다. `0`은 명시적인 실제 값이며
생략·기본값으로 바꾸지 않습니다. 문서·페이즈·단계·목표·메타데이터는 알 수 없는 필드를
거부합니다. `goal_metadata`의 학생 ID 집합은 단계에 등장하는 학생 집합과 정확히 같아야
하고, 각 항목에는 `favorite`와 `notes`만 있어야 합니다. 빈 문서는 `phases: []`,
`goal_metadata: {}`로 표현합니다. `favorite: false`와 메모의 공백도 그대로 보존합니다.

단계는 학생별 누적 절대 목표입니다. 같은 학생의 앞 단계에서 정수를 지정한 항목은
뒷 단계에서 더 작은 정수나 `null`로 바꿀 수 없습니다. `null` 뒤에 정수를 지정하는 것은
허용합니다. 이 회귀 규칙은 페이즈 경계에도 적용됩니다.

원본 nullable 목표를 기존 계산 코어로 넘기고, 공용 성장 상태 경계가 현재값·이전 단계의
계산 결과·필수 선행 성장을 계산 중에만 적용합니다. 비용식과 장비 정규화는 기존 코어를
재사용합니다. 계산용 성급·전무·장비·인연 값은 저장 `targets`에 되쓰지 않습니다.

문서 계산과 시나리오 비교의 `current_students`에만 선택 `bond_rank`(정수 1~100 또는
`null`)를 추가합니다. 현재 인연이나 성장 기준값을 모르면 경고를 반환하며, 알려진 비용만
잠정 합산합니다. 인연 성장 비용 경고는 FB-11b 뒤에도 유지합니다(선물 계산은 별도). 모르는 인연에 1을
넣지 않습니다. FB-11a의 단일 학생 정수 19 key와 기존 currentStudent 계약은 유지합니다.
활성 계획 `repository.plan.get/save`, 이관·goals 파생(FB-1b), replace(FB-1c)는 별도입니다.

Dart에서는 `PlanningDocument(version: 2, ..., goalMetadata: ...)`와 각 단계의 완전한
`Map<String, int?>`를 사용합니다. v2 편집기는 `stage.nullableTargets`를 읽고 직렬화하며,
현재값으로 빈 목표를 채우는 `planningDocumentTargets`는 호출하지 않습니다. 기존 v1
편집기의 `stage.targets`는 정수 뷰를 유지하고, nullable 단계에 접근하면 오류를 냅니다.
시나리오 DTO와 mock의 복제·비교도 문서 버전과 nullable 목표·메타데이터를 보존합니다.

스키마는 `planning-document-calculate-v1.schema.json`의 `documentV1`/`documentV2`를
공유합니다. 정책 fixture는 `fixtures/planning_document_v2.json`, 변경 전 v1 회귀 기준은
`fixtures/planning_document_v1_fb1a_parity.json`과 `fixtures/scenario_v1_fb1a_parity.json`입니다.

## 오류 형식

오류도 `type: "response"`인 정상 envelope이며 payload는 다음 형태입니다.

```json
{
  "error": {
    "code": "invalid_payload",
    "message": "target_level must be an integer or null",
    "details": { "path": "payload.plan.goals[0].target_level" }
  }
}
```

`details`는 선택적인 객체입니다. v1 오류 코드는 다음과 같습니다.

| code | 의미 |
| --- | --- |
| `unknown_method` | protocol v1에 등록되지 않은 method |
| `invalid_payload` | 필수 필드 누락, 잘못된 타입 또는 허용 범위 위반 |
| `metadata_lookup_failed` | 학생 metadata 조회 시스템 실패 |
| `calculation_failed` | 계획 총계 계산 실패 |

오류 code는 method별로 제한합니다. 알 수 없는 method만 `unknown_method`를,
`planning.student.get`은 `invalid_payload` 또는 `metadata_lookup_failed`를,
`planning.plan.validate`는 `invalid_payload`만,
`planning.plan.calculate`는 `invalid_payload` 또는 `calculation_failed`를
사용할 수 있습니다. 이 조합은 `protocol-error-v1.schema.json`에서 강제합니다.

protocol 값이 `1`이 아니거나 envelope 자체를 해석할 수 없는 경우에는 v1 메시지로
간주하지 않습니다. stdio server는 malformed JSON, version mismatch와 신뢰할 수
없는 envelope를 stderr에 기록하고 응답 없이 다음 JSONL 입력을 처리합니다. 알려진
v1 envelope의 알 수 없는 method만 원래 id/method를 유지한 `unknown_method` 응답을
반환합니다.

## unknown-field 호환성

planning plan과 각 goal의 알 수 없는 필드는 향후 호환성을 위해 허용하고
수신자가 무시합니다. canonical 직렬화 응답은 알려진 필드만 반환할 수 있습니다.
이 정책은 기존 `load_plan()`이 알 수 없는 goal 필드를 버리는 동작과 같습니다.
알 수 없는 필드 여부는 이름 접두사가 아니라 schema의 `growthPlan.properties`와
`studentGoal.properties`에 등록되었는지로 판단합니다.

공통 envelope, method payload의 바로 아래, `current_students` 항목,
`PlanCostSummary`, 오류 객체의 알 수 없는 필드는 오타를 조기에 찾기 위해
거부합니다. 학생 정적 metadata 응답은 metadata 자체의 점진적 확장을 위해 알 수
없는 필드를 허용합니다.

## fixture와 contract test

`fixtures/planning_protocol_v1.json`은 정상 조회, 학생 미존재, plan round-trip,
계산, 빈 목표, 미래 필드, invalid payload, unknown method, version 불일치, 오류와
ID 대응 사례를 포함합니다. Python과 Dart contract test가 이 동일한 파일을 읽어
protocol 규칙을 검증합니다.

Python contract test는 `jsonschema`의 `Draft202012Validator`와 로컬 schema `$id`
registry를 사용해 모든 fixture message를 실제
`planning-protocol-v1.schema.json`에 검증합니다. 따라서 로컬 `$ref` 오타,
`required`, `additionalProperties` 또는 method별 오류 code 제약 변경은 테스트
실패로 이어집니다. 재현 가능한 test dependency는 `backend/pyproject.toml`의
`test` optional dependency에 `jsonschema>=4.18,<5`로 명시했습니다.

```powershell
cd backend
py -3.11 -m pip install -e ".[test]"
py -3.11 -m unittest discover -s tests -v
```

Python test는 schema 검증에 더해 정상 비용과 빈 목표 결과를 실제
`calculate_plan_totals()` 결과와 비교하고, metadata fixture를 실제
`student_meta.get()` 값과 비교합니다. 정상 plan 및 future-field correlation은
request와 canonical response를 `GrowthPlan`/`StudentGoal`로 역직렬화한 의미가
같은지도 확인합니다.

Dart 쪽은 별도의 Draft 2020-12 validator dependency를 도입하지 않았습니다.
동일 fixture를 읽어 envelope, payload shape, method별 오류 code, request/response
상관관계와 canonical plan wire 의미를 검증하는 작은 구조 검사기를 유지합니다.
실제 JSON Schema와 모든 로컬 `$ref` 검증은 Python test가 단일 책임으로 수행하며,
Dart test는 Flutter client가 소비할 wire 규칙과 공용 fixture drift를 탐지합니다.

## P1 transport 구현과 제외 범위

Python stdio/process 서버, Dart process client와 Flutter `ProcessAppService`가 이
계약을 구현합니다. transport는 JSONL framing, 요청 timeout, process 종료,
restart/dispose를 담당합니다. repository, scanner/matcher, request cancellation과
event/session generation은 아직 범위 밖입니다. v6는 fixture/parity 참조일 뿐
런타임 import 대상이 아닙니다.

Dart client는 response ID와 method를 pending request에 대조하고 method별 성공
payload의 최상위 shape 및 허용 오류 code를 확인합니다. timeout 뒤 도착한 response는
진단만 남기고 연결을 유지하지만 malformed JSON, 잘못된 envelope·method·payload와
stdin 쓰기 실패는 process 연결 전체를 실패시킵니다. 세 planning method는 실제
Python child process를 사용하는 Flutter test에서 종단간 검증합니다.

## repository protocol v1

P4는 `repository-protocol-v1.schema.json`과 공유 fixture
`fixtures/repository_protocol_v1.json`을 사용합니다. method는 profile
`list/create/current/select/rename`, `repository.state.get`, current student/inventory
update, goal save와 명시적 migration preview 경계입니다. 모든 mutation은 비어 있지 않은
`idempotency_key`를 사용하고 기존 profile mutation은 `expected_revision`을 요구합니다.
성공 mutation은 새 monotonic `revision`을 반환합니다.

Repository payload는 unknown field와 잘못된 protocol version을 거부합니다. 주요 오류는
`profile_not_found`, `profile_name_conflict`, `revision_conflict`,
`idempotency_conflict`, `repository_busy`, `corrupt_data`, `migration_required`,
`persistence_failed`, `migration_not_supported`이며 `retryable` boolean을 포함합니다.
Planning protocol v1 method와 기존 오류 의미는 변경하지 않습니다.

Confirmed student, inventory와 goal의 nested payload도 exact-key 계약을 사용합니다.
Confirmed current는 P3가 소유하는 field와 nullable type만 허용하며 metadata, 계산 총계와
shortage를 거부합니다. Inventory entry는 canonical key/quantity 및 허용된 nullable field만,
goal은 nullable target과 Python planning 최대 범위를 검증합니다. Request update와 state
response는 같은 nested 정의를 재사용합니다.

공용 `repository_protocol_v1.json` fixture는 40 cases(valid 14, invalid 26)이며 Python
JSON Schema test와 DTO drift test, Dart repository validator가 각 case의 `valid` 판정을 함께
확인합니다. Dart runtime client는 repository success를 method별로 검사합니다. Unknown,
missing, method-mismatched 또는 malformed nested success는 fatal protocol error로 연결을
종료하며 명시적 restart 뒤에만 새 요청을 받습니다.

`ProcessAppService`는 wire state를 즉시 immutable `RepositoryState`와 typed nested state로
변환합니다. Widget은 이 typed service 경계만 사용하고 repository JSON, storage path 또는
raw state map을 직접 읽지 않습니다. 실제 process test는 Dart가 실행한 Python child
process를 종료한 뒤 같은 격리 storage root로 새 process를 시작해 profile, revision과 goal
복원을 검증합니다.

### 활성 계획 저장·첫 로드 이관 (FB-1b)

활성 계획의 저장 원천은 문서 v2(`kind: "plan"`)입니다. IPC envelope와 profile/catalog
파일의 바깥 `version`은 계속 1입니다. profile의 명시적 `plan` 필드 유무로 legacy를
구분합니다. `plan`이 있으면 빈 문서도 이관 완료 상태이며 goals로 되살리지 않습니다.
`repository.state.get`의 기존 다섯 응답 필드는 그대로입니다.

| 메서드 | 정확한 입력 payload | 성공 payload |
| --- | --- | --- |
| `repository.plan.get` | `{profile_id}` | `{profile_id, revision, document, calculation}` |
| `repository.plan.save` | `{profile_id, expected_revision, idempotency_key, document}` | `{revision}` |

plan save는 v1 문서와 kind=scenario를 거부합니다. 문서·페이즈·단계 ID, 학생별 누적 목표
회귀, 19개의 int/null 목표, 학생별 favorite/notes를 기존 v2 parser로 엄격하게 검사합니다.
현재값·필수 선행 성장·계산 결과를 저장 목표에 되쓰지 않습니다.

`calculation`은 `PlanningScenarioCalculationSummary`와 같은 여섯 필드입니다:
`credits`, `required_resource_type_count`, `known_shortage_type_count`, `inventory_complete`,
nullable `first_bottleneck_phase_number`, nullable `representative_shortage`(resource_key,
item_id, display_name, category, shortage). scenario.list와 active get은 공용 Python
`planning_summary.calculation_summary`를 사용합니다. 같은 profile 파일 snapshot의
document/students/inventory로 계산하며, 계산 실패는 `calculation: null`입니다. 저장 문서는
계속 조회할 수 있습니다. null 요약을 비용 0으로 해석하지 않습니다.

문서 저장 transaction 안에서 phase→stage 순으로 학생별 마지막 단계의 18개 목표를
goals v1에 파생합니다. 첫 등장 학생 순서, nullable 목표, 명시적 0, favorite와 원래 notes를
보존합니다. bond_rank는 문서에만 있고 goals v1에는 새 키가 없습니다. 빈 문서는 goals=[]입니다.
목표·파생 goals·idempotency가 같은 profile의 atomic write에 들어가고 profile/catalog revision을
같이 갱신합니다. 잡힌 저장 실패에는 두 원본 파일의 바이트를 rollback합니다.

동시 편집은 `expected_revision`으로 막습니다. 동일 key/동일 canonical 문서/동일 expected
revision 재시도는 최초 `{revision}`을 반환하며 추가 저장을 하지 않습니다. key가 같아도
문서나 expected revision, 작업 종류가 다르면 `idempotency_conflict`입니다. 최초 성공 뒤
계획이 바뀌었어도 기존 재시도는 최초 응답을 반환하므로 이후 현재 revision은 재조회합니다.

legacy 첫 state.get 또는 plan.get은 repository lock 아래에서 필드 유무를 재확인하고,
한 번만 document/goals와 revision을 저장합니다. 이미 저장된 legacy profile은 revision이
정확히 한 번 증가합니다. 경합하는 첫 읽기는 retryable repository_busy로 재시도할 수 있습니다.
mutation이 먼저 legacy profile에 닿아도 이관 후 revision이 권위값이며 오래된 expected
revision은 revision_conflict입니다. profile.list/current의 요약 revision을 계속 쓰지 않습니다.
신규 profile 생성과 v6 import는 최초 생성 transaction에서 문서를 함께 저장하여 revision 0을
유지합니다. v6 원본 파일은 읽기 전용입니다.

legacy goal은 순서대로 한 페이즈/학생당 한 단계로 변환합니다. 18개 목표를 원래 int/null로
옮기고 bond_rank는 현재 인연이 알려져 있어도 **항상 null**입니다. 현재 학생 상태로 빈 목표를
채우지 않습니다. all-null goal도 단계와 metadata를 보존합니다. 같은 학생의 중복 goal은
기존 비용 계산에서 각 항목을 합산하므로 누적 단계나 마지막 항목으로 자동 접지 않습니다.
`legacy_goals_conflict`(details.student_ids)로 차단하고 원본을 보존합니다. 이 오류는 legacy
첫 조회, goals.save, v6 import, profile 이관을 먼저 수행하는 scenario 호출에도 적용됩니다.
손상된 파일이나 변환 불가능한 저장 데이터는 corrupt_data이며 빈 문서로 덮지 않습니다.

legacy `repository.goals.save`도 동일 변환·저장 transaction을 사용합니다. 기존 활성 문서의
페이즈가 둘 이상, 같은 학생의 단계가 여러 개, 또는 명시적 인연 목표가 하나라도 있으면
`plan_lossy_write`(details.reasons: multiple_phases / multiple_student_stages / bond_target)로
막습니다. 빈 문서와 학생별 단일 단계·인연 없는 한 페이즈는 이 호환 writer를 사용할 수 있습니다.
목표를 지우려는 빈 goals 쓰기도 같은 손실 방지 검사를 받습니다.

FD-026대로 새 활성 화면의 수치는 저장 문서 projection이 원천입니다. 파생 goals는 호환
소비용이며 다중 단계의 재화 배분이나 인연 목표의 필수 성급 성장을 표현하지 않습니다.
따라서 새 문서에서 goals 계산과 projection이 항상 같다고 가정하지 않습니다. 기존 단일
성장 목표의 비용·재화·부족량은 process E2E로 일치를 확인합니다. 문서의 인연 비용 미계산
경고는 유지합니다. `repository.plan.replace`와 기존 계획의 시나리오 보존은 FB-1c 범위입니다.

fixture는 `fixtures/repository_plan_migration_v1.json`(8개 정책)과
`fixtures/repository_plan_v1.json`(16개 wire 판정)입니다. Dart는 기존 RepositoryService 대역을
보존하는 추가 `RepositoryPlanService` capability와 strict `RepositoryPlanState`,
`RepositoryPlanSaveRequest`를 제공합니다. ProcessAppService/MockAppService가 이를 구현합니다.
mock은 목표 변환·revision·idempotency·손실 방지를 재현하고 기존 빈 mock document projection을
요약합니다. 실제 성장 계산식을 Dart에 복제하지 않습니다. mock 계산 실패도 요약 null로 보존합니다.

### 활성 계획 교체·보존 (FB-1c)

FD-067(a)·FD-088의 교체는 `repository.plan.replace` 한 호출입니다. `save`와 scenario.create를
클라이언트가 이어 호출하지 않습니다. 추가 fixture `fixtures/repository_plan_replace_v1.json`의
20개 판정을 Python schema와 Dart strict DTO/validator가 공유합니다.

| 방향 | payload |
| --- | --- |
| 요청 | `{profile_id, expected_revision, expected_scenario_revision, idempotency_key, document, archive_name, archive_description}` |
| 성공 | `{revision, scenario_revision, archived_scenario_id}` |

document는 v2/kind=plan이고 기존 save와 같은 nullable 목표·metadata·누적 회귀 검사를 받습니다.
두 expected revision은 0 이상 정수입니다. expected_revision은 profile, expected_scenario_revision은
**시나리오 collection** revision(개별 scenario revision 아님)입니다. archive_name은 공백뿐인 값을
거부하고 description은 빈 문자열을 허용하며 둘 다 trim합니다. key는 비어 있으면 거부합니다.

기존 활성 문서의 phases가 있으면 새 시나리오로 보존합니다. kind=scenario, document_id는 새
scenario ID이며 원래 문서 이름·phase/stage ID·순서·19개 int/null 목표·goal_metadata는 보존합니다.
고유 document_id는 기존 comparison의 서로 다른 문서 ID 조건을 충족하여 반복 교체의 보존본끼리도
비교할 수 있게 합니다. outer record의 name/description은 archive 입력, base_profile_revision은
교체 **직전** revision, 개별 scenario revision은 0입니다. collection revision은 한 번 증가합니다.
all-null 단계나 단계가 없는 phase도 phases가 있으므로 보존 대상입니다. phases=[]면 archive ID는
null이고 collection revision과 scenario 파일은 그대로입니다(파일이 없으면 만들지 않습니다).
빈 경우에도 두 expected revision을 검사합니다. 새 활성 문서와 최종 단계 goals 파생은 profile
revision +1 안에 함께 저장합니다. 현재 학생·인벤토리나 다른 시나리오를 변경하지 않습니다.

충돌 코드는 기존 `revision_conflict`이며 details는
`{revision_scope: "profile"|"scenario"|"both", current_revision, current_scenario_revision}`입니다.
멱등 fingerprint에는 새 canonical 문서·trim한 보존 정보·두 expected revision·작업 종류가 들어갑니다.
같은 key/fingerprint의 재시도는 현재 두 revision을 검사하기 전에 최초 세 필드 응답을 반환합니다.
후속 편집이나 archive 삭제 후에도 최초 응답을 재사용하고 시나리오를 다시 만들지 않습니다.
다른 작업·문서·보존 정보·revision이면 `idempotency_conflict`입니다. profile 캐시는 기존 `{revision}`
응답과 새 세 필드 응답을 모두 엄격히 읽습니다. scenario 자체 CRUD 캐시 형식은 바꾸지 않습니다.

공용 `repository_transaction` 경계는 root별 OS guard → `.repository.lock` 호환 marker → journal
복구 → 파일 접근 순서입니다. 한 guard를 JsonRepository와 ScenarioStore가 같이 쓰며 같은 thread/root의
중첩 callback은 재사용합니다. 다른 thread/process 경합은 retryable `repository_busy`입니다.
Windows byte-range lock(다른 OS는 flock)은 프로세스 종료 시 풀립니다. guard를 얻은 뒤에만
이 구현의 잔여 marker를 교체합니다. 과거/수동/알 수 없는 lock은 owner를 추측하여 삭제하지 않습니다.

replace는 `.repository.transaction.json`에 profile/catalog/scenario의 원본 바이트와 완성본,
checksum을 fsync한 prepared journal을 먼저 저장합니다. 각 파일은 fsync+atomic replace하고,
모두 끝난 뒤 committed journal을 fsync+atomic replace한 다음 journal을 지웁니다.
준비 상태 중단은 **교체 전 전부**, committed 이후 중단은 **교체 후 전부**로 복구합니다.
복구 자체가 중단되어도 journal이 남아 다음 접근에서 반복합니다. rollback/recovery는 원본 바이트를
보존하며 없었던 scenario 파일은 복구 때 제거합니다. 잡힌 오류는 `persistence_failed`로 드러내고
같은 요청을 재시도할 수 있습니다. committed 이후 오류도 최초 응답 캐시가 보존됩니다.
손상된 journal은 `corrupt_data`로 차단하고 빈 문서나 혼합 snapshot을 반환하지 않습니다.

plan.get/state.get/scenario.list/get은 guard 안에서 미완료 transaction을 복구한 뒤 읽습니다.
profile.list/current와 모든 repository/scenario writer도 같은 guard에서 먼저 복구합니다.
기존 단일 파일 atomic 쓰기, FB-1b의 두 파일 예외 rollback·legacy 이관 정책은 유지합니다.
이 journal의 다중 파일 중단 복구 보장은 replace transaction에 적용됩니다.

Dart는 `RepositoryPlanReplaceRequest`, `RepositoryPlanReplaceResult`,
`RepositoryPlanService.replaceRepositoryPlan`을 추가합니다. Process는 실제 Python 경계를 호출하고,
Mock은 검증 후 동기 commit으로 동일 문서 보존·두 revision·멱등성을 재현합니다. Mock의 replace
오류는 details가 있는 BackendRemoteException이며 실제 파일/journal 복구와 성장 비용 검증은 Python/
process 테스트가 담당합니다. UI 연결과 golden 변경은 이 계약 slice에 포함하지 않습니다.

## scanner protocol v1

### FB-4 target metadata

`scanner.target.list` keeps the existing required `target_id`, `title`, and
`status` keys and accepts three additive optional fields. Production Windows
enumeration emits all three; legacy/custom providers may omit them.
`client_width` / `client_height` are positive integer **physical client-area
pixels**, excluding title bars and borders, or a null pair when minimized,
closed, invalid or unreadable. A temporary per-monitor-v2 **thread** DPI context
is restored in `finally`; unavailable DPI awareness yields null sizes rather
than guessed scaled values. No process-global DPI setting is changed.

`game` is `"blue_archive"` or null. The conservative heuristic requires a
visible window with exact class `UnityWndClass` and executable basename
`BlueArchive.exe` (case-insensitive). Title text alone is insufficient. Only
`OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` plus
`QueryFullProcessImageNameW` reads the OS process image name; the handle is
always closed and the full path is transient, never returned or saved. The
heuristic is not authenticated identity and has not been observed against a
live game in FB-4. Null means unknown/unverified, not a negative assertion.
No server/region is inferred from title, basename or path. A non-16:9 or
unknown-server client can have the same game value; it does **not** imply
scanner eligibility. Existing **KR Steam-only** scanner support, target title
filter, readiness/diagnose status, capture/input and attachment behavior are
unchanged. This field introduces no attach session or protocol method.

PID/thread identity is checked before and after metadata queries, against the
identity sampled at enumeration; closed/reused windows return null metadata.
Geometry and identity queries fail independently: process-name permission
denial preserves available dimensions, and DPI/rectangle failure preserves
available game classification. Optional query failures introduce no new wire
errors or target-list failure. Shared examples and invalid field types are in
`fixtures/scanner_target_metadata_fb4_v1.json`; real game dimensions remain
unverified until the master observes them. The schema is additive protocol v1,
finalized by XB. CF `fb4-dart` consumption and gate remain the frontend follow-up.
Win32 API references: [GetClientRect](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getclientrect),
[SetThreadDpiAwarenessContext](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setthreaddpiawarenesscontext),
and [QueryFullProcessImageNameW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-queryfullprocessimagenamew).

P5 scanner 계약은 `scanner-protocol-v1.schema.json`과 공유 fixture
`fixtures/scanner_protocol_v1.json`에서 시작합니다. 요청 method는 target 목록,
recognition readiness, session start/cancel/snapshot, candidate get/review/commit입니다.
이벤트에는 요청 ID가 없고 `scanner.session.event` method 아래 session ID, generation,
strict sequence, scan kind와 phase/progress/candidate/diagnostic/terminal 종류를 가집니다.

후보 생성과 repository commit은 별도 operation입니다. 불확실하거나 실패/region 누락
evidence가 있는 후보는 review approval 없이는 commit할 수 없으며, review는 candidate
revision과 audit를 증가시킵니다. commit은 P4 repository expected revision과 idempotency
key를 요구합니다. stale generation과 종료 뒤 이벤트는 무시하고, sequence gap은
snapshot 재동기화를 요구합니다.

P5 follow-up transport는 `JsonlMultiplexer` 한 곳에서 response와 event를 직렬화한다.
session start의 response가 queue에 들어가기 전 발생한 event는 session별로 보류되며,
bounded backpressure에서는 progress만 최신 값으로 합쳐진다. response, candidate와 terminal은
drop하지 않는다. Dart `PlanningProtocolClient`는 response와 event envelope를 분리하고
scanner method별 success shape를 검사하며, `ScannerProtocolClient`가 typed model과
generation/sequence cursor, start-race buffer를 소유한다.

Production recognition asset은 `backend/assets/recognition/v1/manifest.json`에서 버전,
source, scan kind, 용도, 크기와 SHA-256으로 고정한다. Flutter UI asset 또는 사용자 adaptive
sample 경로를 recognition catalog로 사용하지 않는다.

P8은 `tactical_lobby` scan kind를 추가한다. 16:9 로비의 ratio ROI에서 현재 순위와 세 상대의
순위·등록 이름·공개 striker 1명·special 2명을 template matching하고, 안정 프레임 하나를
review 가능한 후보 하나로 만든다. 확정값과 제안값을 분리하며 낮은 score/margin, 가림 또는
미등록 이름은 자동 확정하지 않는다. 의미가 같은 비율 축소 화면은 동일한
`refresh_generation`을 가지며 원본 픽셀 근거는 `screen_hash`로 별도 보존한다.

P9은 확정된 P8 후보를 `tactical.v2.lobby.commit`으로 scan·candidate·공개 snapshot에
저장한다. `candidate.select`는 선택 시각을, `match.link`는 자동·수동·해제 연결을,
`lobby.delete`는 scan 범위 삭제를, `opponent.alias`는 이름·template 이력을 소유한다.
자동 연결은 상대 identity, 6시간 범위, season과 공개 3슬롯이 일치하는 후보가 유일할 때만
성공한다. 모호한 후보는 저장된 원본을 바꾸지 않고 review 상태로 남는다.

## tactical evidence protocol v2

P7은 P6 UI가 사용하는 `tactical.*` v1 CRUD를 변경하지 않고 `tactical.v2.*` namespace를
추가합니다. 공통 JSONL envelope의 `protocol`은 여전히 1이며, tactical evidence payload의
도메인 version만 2입니다.

- `tactical.v2.state.get`: provenance를 가진 match, jokbo, opponent identity, defense
  snapshot과 import batch를 조회합니다.
- `tactical.v2.import.preview`: v6 SQLite를 read-only로 특성화하고 fingerprint, 개수와
  review issue를 반환합니다.
- `tactical.v2.import.commit`: preview fingerprint와 issue 승인 집합을 다시 검증한 뒤
  atomic하게 import합니다.

슬롯은 `unknown`과 실제 `empty`를 분리하며 공개 로비, 전투 후 확인, 수동 입력과 커뮤니티
제보를 서로 다른 state로 보존합니다. 학생은 canonical ID로만 저장하고 wildcard는 null
학생과 별도 boolean으로 유지합니다. 같은 import batch/source record는 중복 생성하지 않으며
preview 이후 원본 DB가 바뀌면 commit을 거부합니다.

공용 fixture `fixtures/tactical_protocol_v2.json`은 Python JSON Schema와 Dart 구조 검사가
같은 valid/invalid 판정을 내리는 기준입니다. `fixtures/tactical_v6_import_v2.json`은 날짜
없음, 방향별 빈 덱, wildcard와 검토가 필요한 중복 슬롯을 포함하는 비식별 v6 parity
fixture입니다.

P10은 같은 v2 namespace에 읽기 전용 `tactical.v2.stats.query`를 추가합니다. 요청은 season,
source, opponent identity, 공개 signature, 기간과 결과 제한을 모두 명시하는 strict filter를
사용합니다. 응답은 필터가 적용된 모집단, 공개 signature·상대·공격덱 패턴, 표본 품질과
`observed_win_rate` 용어 경고를 반환합니다. 공격과 방어 결과는 섞지 않으며 prediction은
관측 결과에서 제외합니다. `fixtures/tactical_statistics_v2.json`은 P7 import와 P9 lobby
연결을 이은 결정론적 기준값입니다.

P11은 `tactical.v2.trends.query` 읽기 전용 경계를 추가합니다. 요청의 필수 `as_of`와
`stale_after_hours`가 신선도 감쇠를 재현 가능하게 만들며 rank difference 범위를 포함한
strict filter를 사용합니다. 응답은 노출→선택→전투→결과 funnel, 상대·공개 signature·순위
차이별 관측률, 연속 refresh 잔류, 공개/완전 방어 변경 구간, 과거 공개 덱 재사용과 공격 근거
신선도를 분리합니다. `fixtures/tactical_trends_v2.json`은 네 번의 반복 관측과 두 번의
공개 변경을 고정한 독립 기준값입니다.

P12는 `tactical.v2.recommend.query`에 6단계 완전 방어 근거 탐색과 설명 가능한 공격 추천을
추가합니다. 결과의 `evidence_weight_share`는 calibration 전 확률이 아니며, 관측된 완전 덱
시나리오만 반환합니다. `recommend.save/get`은 파생 예측을 `snapshots`와 분리된
`predictions` 컬렉션에 state revision·filter·근거 결과와 함께 보존합니다. 공용
`fixtures/tactical_recommendation_v2.json`은 좁은 상대 근거를 더 넓은 실제 관측으로
보정하는 경우와 시간순 holdout gate를 고정합니다.

# Repository stage presets and student groups (FB-14)

`repository.presets.get {profile_id}` returns
`{profile_id, revision, stage_presets, student_groups}`.
`repository.presets.save {profile_id, expected_revision, idempotency_key,
stage_presets, student_groups}` replaces both complete lists and returns `{revision}`.
This revision belongs only to the preset collection. Profile, active plan and
scenario writes do not change it, and preset writes do not change those revisions.
An existing/new/v6-imported profile without a collection file has empty lists and
revision 0. Reading presets does not trigger legacy plan migration. Deleting a
profile deletes its collection under the same repository lock.

Stage presets are `{preset_id, name, stages: [{name, targets}]}`. Every targets
object has all 19 document-v2 keys, with the same ranges. `null` means no target;
`0` is an explicit value (except bond_rank, which is null or 1–100). Targets are
cumulative absolute values: a non-null integer followed by null or a smaller
integer is invalid. Partial growth targets are stored verbatim; current values,
growth prerequisites, normalization and costs are application/calculation concerns.
Groups are `{group_id, name, student_ids}`. Unknown catalog IDs are retained in
order; IDs may overlap across groups. Preset and group IDs have separate namespaces;
within each list IDs are unique, and student IDs within one group are unique.
Names need not be unique. IDs are opaque and preserved; names are trimmed.

Limits: 100 presets, 50 stages per preset, 1,000 total stages; 100 groups,
1,000 IDs per group, 10,000 total memberships; names at most 120 and IDs at most
128 Unicode code points. These generous personal-list bounds limit transport and
validation work; they are not game/catalog counts. Empty lists, empty preset stages,
empty groups and all-null stages are valid. Blank names/IDs, extra fields, duplicate
IDs, limit violations and target regression produce `invalid_payload`.
The schema validates shape, ranges and per-array bounds; duplicate object IDs,
cumulative regression and total nested bounds require semantic validation in
Python/Dart. `fixtures/repository_presets_v1.json` pins both `schema_valid` and
semantic `valid` expectations.

`revision_conflict` details contain this collection's `current_revision`.
An idempotency key identifies the canonical entire save including expected_revision;
the same request replays its original `{revision}`, even after later saves/restart.
Reusing the key with different content/revision produces `idempotency_conflict`.
`repository_busy` and `persistence_failed` retain existing retryability rules.
Both lists, revision and replay cache are atomically written to one profile-scoped
file. The shared repository guard serializes collection saves with profile deletion
and recovers pending plan transactions before reads. A corrupt collection is an
error and is never silently replaced with an empty one. Filter presets are excluded.

# Scenario authoring v1 (FB-8b)

`repository.scenario.create/update` accept optional typed `authoring` beside
`document`, reusing `planning-authoring-v1.schema.json` and the complete bundle
validator below. Explicit null is `invalid_payload`, `details.reason=invalid_shape`.
Create omission uses a document-derived default and keeps the stored field absent.
Update omission preserves existing authoring; incompatible incoming documents fail
with `invalid_payload`, `details.reason=authoring_required` and
`details.authoring_reason` naming the shared validation failure. An explicit object
replaces all metadata; send the document-derived default object to clear it.

Get returns the optional stored sidecar. Duplicate preserves document version,
targets, selected order, deferred stages, chains, goal metadata and prerequisites;
only record identity/name/timestamps and document identity/name are regenerated.
The duplicate request keeps its existing identity/revision fields. Metadata-only
updates increment both record and scenario collection revision once and leave
profile revision, active plan and goals unchanged. Bundle, revisions and idempotency
cache share the existing atomic scenario file write and repository lock/recovery.

Authoring-omitted create/update keep the exact old fingerprint. Explicit authoring
joins the canonical operation fingerprint. Matching retries return the first
`{revision, scenario_id}` response before current revision or omitted-authoring
compatibility checks, including after later edits or deletion. Different content
with the same key fails with `idempotency_conflict`. Revision conflicts retain
`current_revision` (collection) or `current_scenario_revision` (record) details.

`planning.scenario.compare` continues to receive only the two calculation documents.
Authoring lives outside their phases, so deferred targets cannot enter calculation,
comparison, phase/stage/student counts or calculation summaries. Same-phase stage
array order remains the allocation order; metadata validates that order without
changing calculation semantics. Restore authoring from get for editing, and pass
only each record's document to compare. See `fixtures/scenario_authoring_v1.json`
for strict wire cases and `fixtures/planning_authoring_v1.json` for semantic policies.

# Active plan authoring v1 (FB-8a; FD-068(b), FD-069, FD-071)

Calculation documents remain v2. Optional `authoring` lives beside `document` in
`repository.plan.get/save/replace`, beside `plan` as `plan_authoring` in the profile
file, and beside the archived document in a scenario record. Profile/scenario file
versions and calculation protocol shapes stay unchanged. The strict sidecar schema
is `planning-authoring-v1.schema.json`; all six keys are required:

```json
{
  "version": 1,
  "prerequisites": [{"stage_id": "dependent", "requires_stage_id": "prerequisite"}],
  "deferred_stages": [],
  "student_order": [],
  "stage_order_by_student": {},
  "goal_metadata": {}
}
```

The example shows field shapes; actual references must exist in the paired bundle.
Deferred stages contain the complete `{stage_id, student_id, name, targets}` object.
Targets have all 19 document-v2 keys with their existing ranges: null means no goal,
zero is a real goal, and bond_rank is null or 1–100. Saved targets never incorporate
current state or calculation prerequisites. Deferred stages are excluded from
calculation, goals v1 derivation, scenario comparison and list calculation/counts.
Selected students without any goals and unknown catalog IDs are preserved.

Stage IDs are unique across document and deferred stages. `student_order` is the
unique selected order and includes every stage student. `stage_order_by_student`
has exactly these student keys, each covering exactly its own stages once. For each
student, placed stages are the chain's prefix and deferred stages its suffix, both
in chain order. Targets are monotonic over that whole chain: an integer followed
by a smaller integer or null is rejected. Equal targets and all-null stages are
allowed. Names/IDs use non-blank trimmed text; metadata notes are preserved verbatim.
`goal_metadata` contains exactly selected students absent from the placed document,
including deferred-only students. Each value has only `favorite: bool` and
`notes: string`. Placed students use only document.goal_metadata.

Direct prerequisite pairs are cross-student only, point `requires_stage_id → stage_id`,
and cannot reference an absent stage, themselves or duplicate another pair. The
whole graph, including implicit adjacent same-student edges, must be a DAG.
Prerequisites cannot occupy a later lane; deferred stages form the final lane.
Within the same phase/deferred array, the prerequisite must already precede its
dependent. The backend validates the supplied order and never reorders it. The
frontend applies stable topological ordering before saving. Calculation consumes
document phase/stage order as before; direct edges do not gate cost calculation.
Prerequisite pairs are canonicalized as a sorted set; selected, chain and deferred
array orders retain their meaning.

| Optional field | Meaning |
|---|---|
| get, stored field absent | Preserve the old response shape and file bytes; Dart exposes a document-derived default and `hasAuthoring=false`. No authoring migration/revision bump |
| save, field absent | Preserve existing authoring and validate against incoming document; absent stored metadata follows the old path. Incompatibility rejects with `invalid_payload`, `details.reason=authoring_required` |
| replace, field absent | New active plan uses its document-derived default; old authoring belongs only to the archived bundle |
| explicit object | Full replacement; pass the document-derived default object to clear metadata |
| explicit null | Rejected; null never clears metadata |

Defaults use document first-appearance student order and flattened student chains;
prerequisites/deferred stages/extra metadata are empty. They never depend on current
state or catalog ordering. Authoring-only saves increment profile revision and its
catalog mirror once. Preset and scenario collection revisions are unaffected by
plan.save. All plan data, derived goals, revision and cache share the existing save
transaction. Replacement archives the entire old document+authoring and writes the
new bundle/goals/cache under the existing profile/catalog/scenario journal and lock.
Only a completely empty document and authoring skip archival: deferred-only or
selected-only bundles produce an empty-calculation scenario and increment the
scenario collection revision. Recovery restores all before or all after, including
the sidecars. Related reads recover unfinished replacements before returning.

Requests omitting authoring use the exact pre-FB-8a fingerprint, including legacy
`{revision}` replay caches. Explicit authoring joins the canonical request
fingerprint. Cache replay precedes omitted-metadata compatibility and revision
checks; retries return the original response and never create another archive.
Revision/idempotency conflicts, repository_busy and persistence_failed retain
their existing semantics. Legacy repository.goals.save refuses any non-default
authoring with `plan_lossy_write`, `details.reasons` including `authoring_metadata`.

Authoring input errors use `invalid_payload` with `details.reason`:

| reason | Violation |
|---|---|
| invalid_shape / unsupported_version | Wrong strict shape/types or unsupported authoring version |
| targets / target_regression | Invalid deferred 19-key targets/ranges/types, or whole-chain regression |
| student_order / stage_set / stage_chain | Selected/order keys incomplete or duplicate; own-stage coverage wrong; placed prefix/deferred suffix mismatch |
| goal_metadata | Wrong selected-only metadata set or strict favorite/notes types |
| stage_reference / self_reference / same_student_prerequisite / duplicate_prerequisite | Invalid direct pair |
| cycle / lane_order / stage_order | Whole graph cycle, prerequisite in later lane, or inverted same-lane array |
| authoring_required | Omitted existing authoring cannot match the new document; `authoring_reason` identifies the underlying violation |

Stored malformed authoring is corrupt_data; unsupported stored authoring version is
migration_required. Neither silently defaults or erases data. JSON Schema checks
strict shapes/ranges; paired stage references, chain/metadata coverage, regression
and graph/lane rules are validated in Python and Dart. Both strict parsers reject
booleans, strings and floating-point tokens for integer targets/versions.
`fixtures/planning_authoring_v1.json` pins semantic verdicts/reasons and canonical
results; `fixtures/repository_plan_authoring_v1.json` pins optional wire shapes.

FB-8a adds only the scenario record path needed by replacement: archive append,
get/list strict reading, duplication preservation, and a legacy update guard that
preserves compatible metadata or rejects incompatible omission as authoring_required.
The common validator preserves nested v1/v2 document versions and their existing
target semantics; the active-plan boundary continues to require v2 kind=plan.
Scenario create/update request authoring, complete CRUD omission/fingerprint tests
and editor integration are FB-8b. Comparison still receives only document_a/b.

## FB-2a confirmed current history v1

Profile format v1 accepts optional `current_history`, validated by
`current-history-v1.schema.json` and the strict Python/Dart parsers. The public
`repository.state.get` payload remains unchanged. History records confirmed
students and inventory quantities; goals, plans, costs, shortages, catalog order
and recognition images do not belong in this bucket.

The history object has eight required keys: `version`, `next_sequence`,
`baseline`, `events`, `total_counts`, `last_applied_at`, `scan_session_ids`, and
`latest_scans`. Baseline holds `{sequence, recorded_at, origin, students,
inventory}`; inventory baseline rows are `{resource_key, quantity}`. Origin is
`empty`, `legacy`, or `compacted`. Sequence starts at 1 and orders applications
independently of profile revision. A legacy baseline has unknown time (`null`),
never an inferred scan date. Reads neither create history nor migrate the plan.

Each event stores sequence, backend UTC `recorded_at` (exactly six fractional
digits and `Z`), source, before/after revisions, raw scan metadata, approved scope,
student/inventory changes and nullable catalog SHA. Ordinary applications are
revision n→n+1; the single initial import seed is 0→0. The backend samples its
clock after revision/cache validation. An unsuccessful prepared transaction has
no recorded application; replay or journal recovery returns/preserves the first
committed timestamp and the original `{revision}` response.

Student changes are **whole confirmed student records** under
`{student_id,before:{present,value},after:{present,value}}`. This retains missing
versus null fields, form objects and optional provenance without maintaining a
second field vocabulary. Inventory changes use
`{resource_key,before:{present,quantity},after:{present,quantity}}`. A missing row
is `{present:false,quantity:null}`; an unknown observed quantity is
`{present:true,quantity:null}`; zero is `{present:true,quantity:"0"}`. Quantities
remain arbitrary-size canonical decimal strings. Student order and inventory
names/positions are not value changes. Known inventory aliases use the existing
`canonical_resource_key(item_id or key)` boundary; unknown IDs are retained.

Sources:

| source | Application / scan counting |
|---|---|
| manual | Public repository.students.update / inventory.update; full submitted bucket scope (old/new union), including no-change applications |
| import | Successful v6 import time, one seed, excluded from scan counts/freshness |
| scan | Server-internal ScanHistoryContext only, approved non-empty scope; no-change applications also update freshness |
| unattributed | Temporary compatibility path for old internal scanner calls without context; preserves reconstruction, excluded from manual/import/scan counts and freshness |

`JsonRepository.update_students/update_inventory(..., history_context=None)`
remain callable with the old four positional arguments. Public RPC dispatch sets
`manual=True`; internal scan wiring must instead pass `ScanHistoryContext.from_wire`
with `{source:"scan",scan_kind,inventory_scan_profile,scan_context:{session_id,
generation,candidate_id,candidate_revision},applied_scope:{student_ids,
resource_keys}}`. Scope must refer to identities in the submitted bucket. It is
never derived from the merged bucket or accepted from a frontend RPC payload.
Raw kind/profile text is 1..1024 **UTF-8 bytes**, unchanged, with no trim/case/enum
conversion; nullable scan profile stays null, never a catalog profile fallback.
FB-2a leaves scanner-owned commit blocks unchanged. A Mock repository-map
observer also records contextless writes as unattributed, including no-change
applications, so following manual writes retain a valid reconstruction chain.
FB-2b will wire the actual approved scope and reuse a Mock history helper together
with upsert and idempotent scanner replay.

Storage unit is one commit. Display unit (`스냅샷 n회`, trend points, A6) is one
unique scan session, including its last applied state. `scan_session_ids` retains
lifetime session identities for exact deduplication after compaction. Raw commit
counts remain separate. Manual/import/unattributed records never become scan
sessions. `latest_scans` has by_kind (raw kind/profile tuple), by_student_id and
by_resource_key arrays; pruned records do not erase their last successful scan.

On a current write, fold only an old contiguous prefix into baseline until the
history fits **365 days / 10,000 events / 16 MiB canonical UTF-8**, whichever limit
is reached first. Baseline, latest indexes and session identities count toward
the byte limit. Lifetime source counts and last application times survive.
Always retain the newest application. If baseline/index plus this application
cannot fit, reject before persistence with `invalid_payload`,
`details.reason=history_capacity_exceeded`; never silently drop it. Reads do not
prune. Equal times use sequence; clock rollback is kept and reported in coverage.
Compacted/legacy coverage cannot claim complete past history.

Current writes, profile create/import, and existing two-file profile writes use
the shared before/after journal: OS guard → compatibility marker → recovery →
profile/catalog. A prepared journal restores all before, a committed journal all
after, including current/history/revision/cache. Related reads recover first.
Plan migration/save/replace/goals/profile metadata preserve history and emit no
current event. Profile deletion still deletes its inline history; durable deletion
across tactical v1/v2 and other collections is explicitly deferred to FB-2d.

Minimum query: `repository.history.summary {profile_ids:[1..128 unique IDs]}` →
`{profiles:[{profile_id,revision,history_sequence,last_manual_at,last_import_at,
total_event_count,retained_event_count,total_counts,retained_counts,
total_scan_session_count,retained_scan_session_count,coverage}]}`. Source-count
objects have all four keys. Coverage has `origin` (also `unrecorded`),
`baseline_sequence`, `baseline_at`, `first_retained_at`, `complete`, and
`timestamps_monotonic`. This query does not expose raw history, last scan/item
timestamps or events/diff; full scan summary is FB-2b and period queries FB-2c.

Malformed new inputs use invalid_payload; duplicate student identity is
`details.reason=duplicate_identity`. Stored duplicate students or broken history
use corrupt_data, and a supported-shape unknown history version uses
migration_required. Existing v6 conversion can produce duplicate student IDs
from distinct source keys; import now rejects these rather than last-wins.
Context/scope failures use invalid_history, empty_scan_scope or scan_scope_mismatch.
Existing fingerprints and `{revision}` caches are unchanged for requests without
scan context. Explicit context joins the fingerprint; replay precedes clock,
compatibility and revision checks. Conflicts/busy/persistence failures reuse
existing error codes.

`fixtures/current_history_v1.json` pins missing/null/zero/delete, form/provenance,
no-change scan/session counts, compaction and strict schema/runtime verdicts.
`backend/tests/fixtures/current_history_profile_shape.json` is the anonymous
structure of an actual 217-student/614-item profile, with no account identifiers
or original quantities; targeted tests measure full apply and 10,000 commits.

### Internal scan commit provenance v1 (H1)

`scan-commit-history-context-v1.schema.json` fixes the server-internal ten keys
`source`, `session_id`, `generation`, `candidate_id`, `candidate_revision`,
`scan_kind`, `inventory_scan_profile`, `applied_keys`, `excluded_keys`, and
`retry_of`. No version property or public RPC payload field is added.
`ScanCommitHistoryContext.from_wire(value, bucket="students"|"inventory")`
returns an immutable validated object. Pass it only to the internal
`JsonRepository.update_students/update_inventory(..., history_context=context)`
port. The writer bucket must match the object's bucket; raw kind never selects
it. `to_history_context()` returns the existing nested `ScanHistoryContext`.

Source is scan; generation is an exact integer >=1 and candidate revision an
exact integer >=0 (scanner public commit remains >=1). All raw identifiers and
new flat applied/excluded/retry IDs must encode as valid UTF-8 1..1024 bytes;
profile and retry may be null. No trimming, case folding or kind/profile enum
conversion occurs. Schema maxLength counts characters, so runtime additionally
rejects byte overflow, invalid surrogates and bool/float integers. Existing
stored events, old nested context and old caches retain their previous bounds.

Student keys are student_id; inventory keys pass through canonical_resource_key
before uniqueness and applied/excluded disjointness checks. Unknown resource
identities remain unchanged. Applied keys must be nonempty, are the actual
approved scope and retain their order. Excluded keys are identified entries,
never fabricated IDs for unknown slots. Their current values and scan freshness
must remain untouched. Diff outside approved scope is still rejected by the
existing event validator. An unchanged approved application records one scan.

The flat object's complete canonical provenance, including excluded_keys and
retry_of, joins the new scan-only request fingerprint. Stored event/public DTO
shapes stay unchanged: no excluded/retry field is persisted. Contextless/manual
and old nested context fingerprints and `{revision}` replay remain unchanged.
retry_of is nullable opaque provenance, not retry authority. Reusing the same
idempotency key with different excluded keys or retry_of conflicts. Exact replay
keeps the first canonical submitted bucket, expected revision, context and array
order, including original null retry_of; restart or an intervening write returns
the original response without creating another event or overwriting current.
Capturing the first scanner request and preventing re-merge on retry is the next
S-FB2b slice; H1 does not wire scanner commits, change Mock, or extend summary.
Shared policy cases are `fixtures/scan_commit_history_context_v1.json`.

### Current history period queries (FB-2c)

`repository-history-query-v1.schema.json` defines strict payloads/results for
`repository.history.events` and `repository.history.diff`; both are routed by
`repository-protocol-v1.schema.json`. They recover the common journal under the
repository guard before reading. They do not migrate a legacy plan, create or
prune history, sample a clock, emit an event, or change any revision/cache.

`events {profile_id, from_at?, to_at?, source?, scan_kind?,
inventory_scan_profile?, student_ids?, resource_keys?, cursor?, limit?}` returns
`{profile_id, revision, history_sequence, coverage, events,
matching_event_count, scan_commit_count, scan_session_count, scan_points,
trend_eligible, next_cursor}`. Events ascend by application sequence. UTC RFC3339
query times accept `Z` or `+00:00` with 0..6 fractional digits and normalize to
six-digit `Z`; calendar errors, non-UTC offsets and reversed intervals are
invalid. The interval is **[from_at,to_at)**. Equal boundaries select no events.
Optional filters AND together; supplying both target lists matches either
approved scope (student OR resource). No-change applications still match their
scope. Each target list has 0..256 unique, nonempty IDs (at most 1024 UTF-8 bytes);
omission means all, an empty list selects none. Unknown IDs are not discarded or
matched through catalog positions/aliases.

Raw kind/profile strings are exact, including whitespace/case, with 1..1024
UTF-8 bytes and no enum/membership check. `inventory_scan_profile:null` searches
explicit stored null; omission includes all profiles. Non-scan events have null
scan metadata, so add `source:scan` when selecting null-profile scans only.
Explicit null for other optional fields is invalid. Limit defaults to 100 and
is 1..200. `matching_event_count` and raw `scan_commit_count` describe the entire
anchored filter result, rather than the current page.

The cursor is opaque to clients. It binds normalized profile/filters, first-read
`history_sequence` and retained baseline. Continue with identical filters and the
returned cursor; limit may change. New applications after that anchor are never
mixed into pages/counts/points; response revision is the revision at this read.
Encoded cursors are bounded at 8 MiB to accommodate both maximum target filters
even when their valid raw characters require JSON escaping.
Malformed or mismatched cursors use `invalid_payload` with
`details.reason=invalid_history_query`. If compaction removes the original
required prefix, use `invalid_payload`, `details.reason=history_cursor_expired`
(not retryable): restart from the first page. The original prefix is required
even after its rows have been paged, because cohort counts and session scope/end
points still depend on it. Reads alone never expire a cursor by pruning.

Display points and FD-042 sample counts use **distinct scan session IDs**. For
each retained session, union its approved scopes and select its **last scan
application within the anchor**, including when the requested item/student was
applied earlier in that session. Raw kind/profile and time filters apply to this
last point; scope filters apply to the union. If a session ends outside the time
window it has no point there, even if an earlier raw commit is in the window.
Thus raw commits and display points can have different counts. Reappearing
session IDs still produce one point. `latest`/`previous` select distinct sessions,
not adjacent candidate commits.

`scan_points` is the complete anchored metadata index (at most 10,000 retained
sessions), repeated unchanged across event pages:
`[{session_id,sequence,recorded_at,scan_kind,inventory_scan_profile}]`. It contains
no repeated full current snapshots. Use its **sequence endpoint in diff** to
read a point's actual confirmed state, including intervening manual/import/
unattributed applications. `trend_eligible = coverage.complete &&
scan_session_count >= 3`; fewer than three sessions never enable a trend.
Frontend owns the trend formula and can further require known values. The
raw commit count remains a diagnostic. Manual/import/unattributed never add a
scan point or scan count. Actual scanner context wiring remains FB-2b; FB-2c's
scan fixtures inject valid stored source=scan events without changing scanner
code or reclassifying old unattributed events.

`diff {profile_id, from, to, student_ids?, resource_keys?}` returns
`{profile_id,revision,history_sequence,coverage,from_point,to_point,
student_changes,inventory_changes,scan_commit_count,scan_session_count,
scan_points,trend_eligible}`. Each endpoint is exactly one of:

- `{at:UTC}`: state immediately **before** the boundary; all events with equal
  timestamps are excluded, with sequence preserving their order.
- `{sequence:nonnegative integer}`: state immediately **after** that application;
  the retained baseline sequence is valid. Beyond the anchor is invalid.
- `{scan:latest|previous, scan_kind?, inventory_scan_profile?,
  student_id?|resource_key?}`: selected session's last application state. The
  singular target selectors are mutually exclusive; raw/null/omission rules
  match events. Omitting kind/profile selects across them.
- `{current:true}`: confirmed current at this guarded query anchor.

Resolved reverse endpoints are invalid. Equal endpoints are valid zero change
when both quantities are known. Points have `{selector,sequence,recorded_at,
available,students,inventory}`. An unavailable point has null sequence/time and
empty arrays; it is not an invented empty snapshot. Target list omission reads
the entire bucket; `student_ids:[]` or `resource_keys:[]` disables that bucket.
The common baseline + `apply_event` restores **all sources** before filtering
point projections. Time endpoints at/before a compacted baseline are unavailable;
legacy sequence 0 has the actual baseline state but its time is unknown.

Comparison rows include unchanged requested IDs too. Student rows preserve the
whole confirmed-record presence/value on each side (field missing/null,
form/provenance remain distinct); frontend derives growth metrics only from
known fields. Resource rows have `{resource_key,before:{present,quantity},
after:{present,quantity},delta}`. Delta is a signed canonical decimal string,
including `"0"`, only when both quantities are present/known and temporal
coverage permits comparison. Large quantities do not pass through float/int
limits. Missing/deleted/unknown rows have null delta, never substituted zero.
Raw scans in `(from_sequence,to_sequence]` are diagnostics; display points in
that interval use session ends and union scope, so they can differ in count.

Query coverage adds `reasons` to the minimum-summary fields. Unlike summary's
lifetime `complete`, query `complete` means this requested range/targets are
covered. A compacted range entirely after the baseline can be complete.
Reasons are `unrecorded`, `before_retention`, `legacy_time_unknown`,
`clock_rollback`, `scan_not_found`, `unknown_quantity`, `unknown_student`.
Clock rollback is never corrected: time endpoints are unavailable, sequence
states remain readable, all deltas/trend are suppressed. Unknown quantity marks
overall coverage incomplete and only that row's delta null; independently known
rows remain available. No scan match or missing previous session returns an
unavailable point, rather than an error or fake state. After prefix compaction,
an unavailable scan selector conservatively reports before_retention.

History stores no past plans/goals/static metadata. Historical plan KPIs are
outside FB-2c, and current statistics `snapshot_count` retains its inventory-entry
meaning. `fixtures/repository_history_query_v1.json` is shared by Python schema/
policy and strict Dart/Mock/Process tests, including raw/null filters, no-change
scans, session ends, pagination, unknown values, compaction and clock rollback.


## S-FB2b scanner current commit

Public scanner commit request7/success4 and student/inventory DTOs are unchanged.
The server binds approved scope and raw session metadata to the H1 flat context,
canonicalizes identities before merging, and freezes the original complete
bucket/expected/public request/context for pending response-loss retries. Same
session/key changed generation/candidate/profile/expected fields conflict before
new candidate/session validation. Exact successful receipt replay does not read
current, remerge, rereview, write, sample clock, train or repeat cleanup.

Success stores the original public signature and exact response then releases
the large frozen submission before specimen cleanup. Pending requests retain
the frozen submission, including retry_of=null. No eviction/new response or
persistent scanner sessions are added. Actual process restart has no old session.
The existing inventory rebasing function is unchanged in repository_inventory;
repository_store re-exports its existing name and scanner imports the pure helper.
Old4arg callbacks are decided before calling; internal TypeError is never retried
as a compatibility fallback. Unknown signatures fail persistence_deferred before
writing. Empty scope rejects before state read; manual/history events unchanged.


## Repository scan latest query v1 (FB-2b)

`repository.history.summary` items now have thirteen required fields, including
nullable `last_scan_at` from `last_applied_at.scan` (null iff total scan count is
zero). The existing request, other summary fields, and current history events
are unchanged. The same CF gate must include strict summary consumers.

`repository.history.scan_latest` uses
`repository-history-scan-latest-v1.schema.json` and shared
`fixtures/repository_history_scan_latest_v1.json`. Its one required request
field is `profile_id`; six optional fields are `student_ids`, `resource_keys`,
`include_by_kind`, `by_kind_limit`, `by_kind_after_sequence`, and
`anchor_history_sequence`. Targets default to [], at most 256 each, valid UTF-8
1..1024 bytes; resource aliases canonicalize before duplicate rejection.
Unknown raw IDs, kinds, sessions, nullable profiles, and whitespace are retained.
Kinds default off, limit defaults 100 and is at most 200. Explicit paging
controls require include_by_kind=true; positive after requires anchor and
after<=anchor. A changed history sequence returns invalid_payload, reason
stale_scan_latest, retryable=false; discard accumulated pages and restart.

Success has exactly profile_id/revision/history_sequence/last_scan_at/by_kind/
by_student_id/by_resource_key/by_kind_next_after_sequence. Scan entries have
sequence/recorded_at/session_id/scan_kind/inventory_scan_profile. Entity rows
have student_id or resource_key, latest_scan, reason. Requested canonical IDs
are unique and Unicode scalar sorted; null entries use unrecorded (no history)
or scan_not_found. A null profile scan time keeps requested rows as null scans
and empties kinds. Empty filters/results never imply a null profile scan time.

Latest follows apply sequence, including clock rollback and no-change approved
scope; excluded targets retain prior scan or null. Kinds sort by latest sequence
ASC, after is exclusive, and next-after is this page's last sequence only if
more rows remain. Replay/goal revision changes keep the history anchor.
Persisted latest indices survive pruning; never recompute them from events.
Impossible duplicate kind latest sequences are corrupt_data without repair.
New UTF-8 checks apply to this endpoint boundary; legacy stored validators and
cache semantics remain unchanged. Reads use the existing common lock/recovery
and _profile, never migrate/prune/sample clock/create history or cache.

The fixture separates validated full in-memory current-history inputs from
independent metadata policy oracles; the latter are not persisted profiles.
Full in-memory fixture cases and metadata policy oracles remain distinct.
Actual store/RPC/stdio integration and matching Dart gates are verified separately.

## M1 developer tools metadata manager (basic read-only infrastructure)

Developer tools retain the short-lived `{version:1,method,params}` JSON envelope.
Six read-only dotted methods: store.status, store.versions, store.diff,
metadata.source.view, asset_map.list, asset_map.check. M1 local structure/existence
checks never imply physical bundle/texture validation (M4). Existing report-only
diff is missing/null when no report exists; no store tool subprocess is invoked.
Unattributed current field provenance stays null; field regeneration/removal is M3.

## FB-10a cooperative pause and resume

`scanner.session.pause` and `scanner.session.resume` use exact session_id/generation.
Replies contain accepted/control_state/reason/terminal. States are running,
pause_requested, paused, terminal. Reasons are user, input_detected, target_minimized,
or null when running/terminal. Pause acknowledgement is asynchronous: wait for the
sequenced paused event before treating native capture/input as stopped. A bounded
in-flight port operation may finish first. Duplicates do not emit transitions.
Resume only accepts an acknowledged pause after checking the original target;
non-ready targets remain paused/target_minimized. There is no automatic resume.
Cancellation wakes paused workers; already collected candidates retain legacy behavior.
Snapshot adds control_state/reason and continues to recover event sequence gaps.
Events paused require a non-null reason; resumed requires reason=null.
Fixture: contracts/fixtures/scanner_pause_fb10a_v1.json. Existing history attribution
continues to use contracts/scan-commit-history-context-v1.schema.json unchanged.

Explicit start/resume consumes already detected command input; later user input still pauses.

## FB-2d durable seven-path profile deletion

`repository.profile.delete` keeps its exact request
`{profile_id, expected_revision, idempotency_key}` and exact response `{revision}`.
No `deleted_paths` field is added. CF's confirmation text includes local tactical
sharing under the existing consent; absent optional files are skipped.

The transaction updates catalog selection and removes profile JSON (including
inline history), tactical v1/v2, scenarios, presets and tactical-share v1 under
root guard -> v1 -> v2 -> local-share markers, released in reverse. Its durable
before/after journal includes these seven targets plus the infrastructure retry
tombstone image. Prepared records restore exact before bytes/presence, committed
records complete deletion. Normal repository/tactical/scenario/preset reads and
writers recover first under the root guard. Known owned crash markers are reclaimed
only under the OS guard; unknown/manual markers remain `repository_busy`.

Deletion tombstones live in `.profile-delete.tombstones.json` outside the deleted
profile. Same key and original revision replay the original response even after
restart. Changed revision for that key is `idempotency_conflict`; a different key
for a deleted profile is `profile_not_found`. A previously used create key cannot
recreate that deleted stable ID (`idempotency_conflict`). Tombstones contain only
ID, retry key/fingerprint and response revision, no deleted account contents.

All journal targets/images and catalog/tombstone transitions are validated before
recovery writes; corrupt journals are retained for diagnosis, interrupted recovery
retains the journal and is repeatable. Process-crash restart is tested using temporary
profiles. Windows directory-entry durability under power loss and real user-profile
deletion are separate acceptance boundaries. Fixture: `fixtures/profile_delete_fb2d_v1.json`.

## FB10b durable inventory review flags v1

`repository.inventory.review.get` request exact `{profile_id}` returns exact
`{version:1,profile_id,revision,needs_review_keys}`. The sorted sparse canonical-key
list is authoritative at that revision; absent keys have no review flag. The read
does not migrate legacy plan/history or persist an empty field. State/quantity/
history/scanner-success DTOs stay unchanged. Optional private `inventory_review`
v1 resides in the profile file, within the same revision, idempotency and journal;
FB2d deletion includes it without a new owned path.

Validated scanner applied keys clear flags; identified excluded keys retain their
previous quantities and gain/keep flags. Quantity changes outside applied scope
are rejected. Unresolved slots have no resource identity and add no key. Empty
approved scope remains a non-commit under the established scanner context contract.
Review alone, cancellation, discarded candidates and answer-sample training cannot
write these flags. Partial commit and response-loss replay share one durable write.

Manual `repository.inventory.update` accepts optional `applied_resource_keys`.
Explicit keys clear only those flags, including an unchanged value acknowledged
by the user; changed quantities outside this scope are invalid_payload with
reason scan_scope_mismatch. Retry uses original expected_revision/key/scope, and
changing scope with the same key conflicts. Legacy calls without scope clear only
actual quantity-change keys, preserving unrelated flags in full snapshots. Keys
are bounded/unique after alias canonicalization. Manual/import never fabricate a
scan timestamp. Existing v6 import creates a fresh profile, initially unflagged;
there is no in-place import writer. Internal unattributed writes do not clear flags.

Shared policy fixture: fixtures/inventory_review_fb10b_v1.json. This slice does
not freeze the entire FB10 format or establish native/currency/crop behavior.


## FB-6a tactical v2 writes and explicit v7-v1 migration

Six new methods: tactical.v2.match.upsert/delete, jokbo.upsert/delete,
legacy.preview/commit. They share the existing v2 file/revision/idempotency with
lobby commit/link. Their exact payloads are in tactical-protocol-v2.schema.json.
Manual match input includes attempt_count (explicit positive integer), zoned
occurred_at and occurred_precision (instant/date/unknown); provider audit fields
are backend-owned. Date precision means KST midnight representation, not a known
battle time. Match read fields are additive/optional for old v2 records; missing
attempt count means unknown, never one. V7-v1 imports explicitly store null count
and date/unknown precision. Jokbo name is optional in old records and required in
new edit input. Preserve existing read provenance, counts and notes in clients.

One record is one entered outcome with an explicitly reported count, not N
fabricated prior outcomes. No new adoption, opponent whole-population winrate or
P13 per-attempt/share semantics are defined here. Private legacy_v1 marker is
stored only in v2, never in public state. No new profile-deletion owned path.

Legacy preview/commit operate on existing owned tactical/{profile_id}.json under
root→v1→v2 locks. Commit checks source revision and byte fingerprint; unresolved
conversion issues reject the entire mutation. Stable namespaced IDs preserve
v2 existing records. Unknown old catalog IDs are surfaced for resolution in v1,
not silently omitted. V1 bytes are never rewritten or deleted. A single atomic
v2 replacement records converted rows and the migration marker; then v1 new
mutations fail tactical_v1_read_only. Old exact idempotent v1 retries retain their
original receipt; reads stay available. The migration's original retry key also
returns its original response before revision checking.

Automatic lineage- IDs derive from ordered attack/defense identities, preserving
wildcard/unknown/empty distinctions and edited names. Metadata/observed source
changes do not fragment pair identity. A reserved derived pair cannot be changed
under the same ID; copy to a new manual template ID to alter composition. Matches
and imported jokbo aggregate wins/losses are not double counted. Editing templates
does not rewrite observations. Unknown/wildcard partial defense never fabricates
a full confirmed snapshot. Linked match identity/signature changes require explicit
unlink first; delete clears its lobby link and match-scoped snapshots atomically.

Fixture: fixtures/tactical_fb6_writes_v2.json. New contracts require same-source
CF fb6-dart gate and paired commits before frontend adoption.

Before new v2 match/jokbo upserts, existing v1 rows require explicit migration
(legacy_migration_required). If v1 has no rows, the first manual v2 write records
the empty legacy migration marker in the same atomic replacement, disabling
future v1 writes. legacy.preview also returns v1_writes_disabled so the client
can avoid proposing another migration after the sole v2 write store is active.

## FB7 Excel / UTF-8 CSV import (isolated candidate)

`tactical.v2.excel.preview` reads .xlsx and UTF-8/BOM .csv without modifying the
source or the durable store. Explicit sheet/delimiter and column mapping are
required choices; candidates and saved mappings are suggestions only. Resolutions
bind semantic field, typed raw key and optionally source row. Canonical exact
student names must be unique and role-valid; fuzzy names and opponent display
names require explicit canonical/identity selections. Blank slots preserve unknown;
an explicit wildcard remains distinct. Missing date/result/positive attempts is an
issue. Date-only values retain `occurred_precision=date` (KST midnight transport);
zoned instants retain `instant`. No default now, attempt one or inferred outcome rows.

`tactical.v2.excel.commit` binds the source bytes and interpretation fingerprints,
expected v2 revision and exact idempotency payload. Cached original retries return
before source reread/revision checking. Every unresolved/conflict row must be
resolved or explicitly skipped. All accepted rows, derived lineage/snapshots,
private rules/row receipts and one batch record use one atomic replacement and one
revision increment. Existing v1 records need explicit FB6 migration first.

Duplicates compare kind + occurred value/precision + explicit opponent identity +
season + ordered attack/defense decks. Result, attempts and notes are correction
fields. Date+opponent alone never collapses separate battles. Coarse/ambiguous
overwrite requires an explicit conflicting match ID; same-workbook duplicates need
explicit keep-separate/skip/target decisions. Original file/sheet/row receipts avoid
re-importing a previously imported row, including after manual deletion. Skip keeps
existing records intact. Summary counts actual rows and commit-eligible decisions;
blank rows are separate from skipped record rows.

Rules (`excel_import_rules`) and row receipts (`excel_import_receipts`) are private
fields inside the existing profile v2 file, not new deletion paths or public state
DTOs. Rules store only explicit mappings/resolutions, never workbook paths/bytes.
Stale student/opponent IDs or role mismatch remain review issues. Record source is
the existing `manual` category with `xlsx_import`/`csv_import` source_label and an
explicit source-row ID; observed_at is never invented. The candidate pins
openpyxl 3.1.5 + defusedxml 0.7.1 (et_xmlfile transitively) and includes the existing
HEAD UnityPy dependency missing from its old lock. Existing main project WIP and
runtime stay intact. Parser libraries must load from the copied runtime in smoke
verification; native Windows publication and CF paired gate remain separate.

FB7 reads profile existence/current ownership under the existing root guard without
automatically adding a missing active plan. Preview, rejected commit, accepted
commit and exact cached retry leave planning profile/catalog bytes untouched.
Existing v1/v2 callers retain their default plan-read behavior. Merged saved rules
are validated against the same 4096-entry bound before any row application; overflow
rejects the whole operation and retains every prior rule. Native time-only and
duration cells keep their typed raw identity and a JSON-safe text representation;
they remain review issues until explicitly resolved, with no invented battle date.
The interpretation fingerprint also binds profile ownership and reader format/
CSV delimiter; identical bytes or owned rosters do not authorize switching these
choices after preview.


## Typed tactical read arrays (2026-10-15)

Statistics public signatures/opponents, trend freshness, and recommendation rows,
hidden-slot candidates, ambiguity and evidence summary have explicit nested
properties and reject unknown keys. Null rates/timestamps and unavailable
responses remain supported. This tightens validation only: runtime responses,
statistics definitions and Dart behavior are unchanged. Actual read responses
are frozen in fixtures/tactical_typed_read_responses_v2.json and recomputed by
test_tactical_typed_reads.py without altering their canonical bytes.


## FB-10 FE8-g2 fixed student progress subset (2026-10-15)

`scanner-student-progress-fe8g2-v1.schema.json` references the existing scanner
event definition without adding or changing wire keys. The synthetic timeline is
`fixtures/scanner_student_progress_fe8g2_v1.json`. This fixes the previously
accepted FE8-g2 baseline, not the entire FB-10 scanner or item/result redesign.

- Envelope protocol/type/method and payload session_id/generation/sequence/
  scan_kind/event_kind retain their existing meanings; discard stale/replayed
  events and request a snapshot on sequence gaps. Terminal closes the stream.
- `progress.current` is the producer's nonnegative counter, not approved/changed
  student count; `total=null` means unknown. Preserve a known zero as zero.
  UI estimates are explicitly separate (FD-154); never invent a server total.
- `phase`/`message_key` are extensible strings. `feedback.student_id/field/values`
  describe observed progress; identify feedback currently has `values={}`.
  Resolve display names from canonical metadata; no producer display-name key.
  Treat missing live growth/KPI values as unknown. A feedback event is not a
  persisted record or an approvable candidate. Candidate events retain the
  existing batch-final/context-complete behavior and their separate revision.
- Pause requests remain requests until the `paused` event/snapshot. `paused`
  carries user/input_detected/target_minimized; `resumed.reason` is explicit null.
  Existing candidate review/partial commit/crop ownership contracts are unchanged.
- History attribution remains `contracts/scan-commit-history-context-v1.schema.json`.

No new Dart method or runtime producer is required for this agreed baseline.
Dart consumers may add comparisons against this fixture later. Live five growth
values, early candidate streaming, credits/eligma capture, and full FE8-g3/g4/g5
format closure remain separate tasks; this declaration does not promise them.


## FB-6b FD-176 unknown attempts and anonymous defense (isolated proposal)

The write attempt_count key remains required; null is unknown, never zero/one,
while known values remain positive integers (bool/zero/negative rejected).
Defense alone permits both opponent_identity_id and opponent_display_name null;
attack, half-null and blank names/IDs remain invalid. No fake opponent/alias is
created. Anonymous defense records stay in overall counts but do not form an
opponent or duplicate-person cohort. Existing trends/recommendation evidence
and observed-attack sharing boundaries remain intact; shared identities never
come from stringifying null. Old retry responses and legacy unknown attempts
are preserved. Excel imports still require explicit attempts/review.

Storage remains version2 and the same profile file/path, with no automatic
rewriting of existing records, aliases or shared tombstones. This is an additive
nullable field extension requiring paired strict Dart request/read DTO and Mock
updates. Main adoption waits for CF fb6b-dart same-source gate.
