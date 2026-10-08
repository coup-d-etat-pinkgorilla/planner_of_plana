---
title: "Frontend Redesign Backend Status"
summary: "Lane A 백엔드 워커의 FB-1a 문서 v2 nullable 목표·v1 회귀·인계, FB-13 catalog, FB-11a 구현 및 FB-1 설계 조사 기록입니다."
topics: [workflow, design]
sources:
  - id: workflow
    type: file
    path: almanac/workflows/frontend-redesign-workflow.md
  - id: student-contract
    type: file
    path: contracts/planning-student-calculate-v1.schema.json
  - id: student-tests
    type: file
    path: backend/tests/test_student_calculation_fb11a.py
---
백엔드 워커 전용(Lane A 병렬, 2026-10-07)

# FB-1a 계획 문서 v2 nullable 목표

## 착수 기록 (2026-10-08)

- 진행 중: FB-1a. 시작 커밋 SHA: `0fd3770234805b3e293c83a5285765a5492e0193`.
- FB-13 `fa15e87c` 커밋 후 코드 편집 재개 승인. 워크플로 FB-1 전체·오후 재개 지점·Lane A 병렬 규칙, 오케스트레이터 로그 14:05 파일 경계, 아래 FB-1 설계 조사와 FD-003·026·027·049·138을 읽었다. [@workflow]
- 범위: 문서 v2의 19-key nullable 절대 목표와 strict 학생별 goal_metadata, 계산 중 유효 상태를 넘기는 공용 코어 경계, v1/v2 문서 계산·시나리오, Dart 문서 DTO·서비스·테스트.
- 이 slice 동안 `frontend/lib/ui/models/planning_models.dart`의 문서 DTO 부분만 백엔드 소유다. 화면·위젯·golden 테스트, 스캐너·tactic·metadata M 소유 파일은 수정하지 않는다. repository 활성 문서 저장/이관/goals 파생은 FB-1b, replace는 FB-1c다.
- 기존 서비스 3파일의 스캐너 미커밋 변경을 보존한다. 수정 전 사본은 `debug/frontend_fb1a/pre/`에 둔다. 커밋·push·stage 미실시. 전체 gate는 두 워커 종료 후 사용자 PC에서 실행하며 golden 변화 0을 예상한다.

## 구현 종료 및 인계 (2026-10-08)

FB-1a의 코드·계약·직접 검증을 마쳤다. **Python 전체·두 워커 종료 후 공통 gate·커밋은 사용자 단계로 남는다.**
현재 화면이 만드는 v1 경로를 유지했으며 golden 변화는 0을 예상한다. golden 비교 자체는 아직 실행하지 않았다.

### v1/v2 계약 비교

| 계약 | 문서 v1 (유지) | 문서 v2 (추가) |
| --- | --- | --- |
| 문서 필드 | version, document_id, name, kind, phases | 같은 필드 + 필수 goal_metadata |
| targets | 19 key 전부 정수 | 같은 19 key 전부 int 또는 null |
| null / 0 | null 거부, 기존 정수 의미 유지 | null=그 항목 목표 없음, 0=명시적 실제 값 |
| bond_rank | 1~100 | null 또는 1~100 |
| 학생 메모 | 없음 | 학생 ID별 favorite bool, notes string; 두 필드만 허용 |
| 단계 검사 | 기존 성장 조합 검사와 누적 절대 목표 | 범위·19 key·누적 절대 목표 검사; 선행 성장은 계산 중에 결합 |
| 다음 단계 상태 | 기존 calculate_goal_cost + _advance | calculate_goal_transition의 유효 상태 |
| 시나리오 | 기존 문서/파일/결과 유지 | 저장·조회·목록·복제·비교·재시작에서 버전/null/메모 보존 |

- 같은 학생의 이전 정수 목표 뒤에 더 작은 정수나 null이 오면 회귀 오류다. null→정수는 허용한다. 페이즈를 넘어서도 적용한다.
- goal_metadata의 ID 집합은 단계에 등장하는 학생 집합과 정확히 일치한다. 각 값은 favorite·notes만 허용한다. false·빈 메모·메모 공백을 그대로 보존한다. 빈 문서는 phases=[], goal_metadata={}다.
- schema는 기존 문서 정의를 documentV1로 보존하고 documentV2 분기를 추가했다. 시나리오 schema가 공유 document를 참조하므로 바깥 IPC·시나리오 저장소 버전은 계속 1이다.
- 문서 계산과 시나리오 비교의 current_students에만 선택 bond_rank(null 또는 1~100)를 받는다. 공유 currentStudent와 FB-11a의 단일 학생·정수 19 key는 확장하지 않았다.
- 공용 planning_growth_rules 경계가 현재값 하한·장비 티어/레벨·전무/성급·스킬 잠금·능력 개방·애장품의 필수 인연을 계산 중에 해결한다. 장비 정규화 helper를 기존 비용 코어와 함께 사용하고, 비용식은 기존 calculate_goal_cost 하나를 재사용한다.
- 원본 nullable StudentGoal을 코어에 전달한 뒤 계산용 사본만 만든다. 계산 후 상태는 다음 단계에 전달하고 저장 targets에는 되쓰지 않는다. all-null 단계에 현재 인연 35가 있어도 성급 성장을 새로 만들지 않는다.
- 현재 성장 기준값을 모르면 계산 경고를 낸다. 모르는 인연에 1을 넣지 않는다. 애장품의 필수 인연은 계산 상태에만 반영하며 원본 bond_rank=null은 유지한다. 인연 성장 비용은 아직 가격을 계산하지 않고 경고한다(FB-11b). 다른 알려진 비용의 합은 잠정 결과다.
- repository.plan.get/save·이관·goals 파생(FB-1b), replace(FB-1c)는 구현하지 않았다. 시나리오 process 검증에서 활성 프로필 파일이 바뀌지 않는 것도 확인했다.

### 먼저 고정한 정책 fixture

`contracts/fixtures/planning_document_v2.json`: **15건(유효 12, 회귀 오류 3)**을 구현 전에 고정했다.

| fixture | 고정 정책 |
| --- | --- |
| null_bond_known / null_bond_unknown | 현재 인연 35 / 미확인이어도 bond 목표는 null 유지, 비용 0 |
| all_null | 단계 자체는 유지, 비용 0 |
| explicit_zero | level·애장품·능력 개방의 명시적 0 유지, 현재값보다 낮아도 목표를 현재값으로 쓰지 않음 |
| same_as_current | 현재와 같은 목표 비용 0 |
| partial_weapon | 전무 레벨만 20→25. 필수 성급·전무 성급은 계산 상태로 전달, 성급 비용 한 번 |
| partial_equipment | 장비 레벨만 15→20. 필요한 티어를 계산하고 다음 단계에서 티어 재과금 없음 |
| partial_favorite_known_bond | 현재 인연 20, 애장품 T2만 지정. bond null 유지, 500,000 크레딧 |
| partial_favorite_unknown_bond / partial_favorite_requires_bond | 인연 미확인 / 현재 10. 필수 인연에 대해 경고, 저장 목표 null 유지 |
| unknown_level_baseline | 현재 레벨 미확인, 목표 31. 기준값 부족 경고 |
| regresses_integer / regresses_to_null / bond_regresses_to_null | 더 낮은 정수 / 정수 뒤 null / 인연 정수 뒤 null 거부 |
| empty_document | 빈 문서, 계산 비용 0·경고 0 |

정책별 Python/schema·Dart DTO 검사 외에 불완전 19 key, bool·문자열 목표, bond=0,
메타데이터 누락·추가 학생·추가 필드·잘못된 타입도 거부한다. 전무/장비의 두 단계 합과
같은 최종 목표 단일 단계의 비용을 비교하고, 원본 입력·목표가 계산 뒤 그대로인지 확인한다.

### v1 회귀와 직접 검증

변경 전 `planning_document_v1_fb1a_parity.json`에 문서 A/B wire·projection·compare 결과를,
`scenario_v1_fb1a_parity.json`에 create/get/list와 저장 파일 전체 텍스트를 고정했다.
**문서·projection·compare·시나리오 반환값은 값 단위로 같고 시나리오 저장 파일은 바이트 단위로 같다.**
기존 v6 비용 parity, FB-12 단계 비용, FB-11a 단일 학생 계약·왕복도 통과했다.

| 검사 | 결과 / 로그 |
| --- | --- |
| Python: 새 v2, 기존 문서·시나리오·계약·비용·재고/저장 parity 11모듈 | **64건 통과**, debug/frontend_fb1a/python-targeted.txt |
| Dart: 새 v2 DTO/mock, 기존 scenario_service·growth_rules·document_projection | **35건 통과**, debug/frontend_fb1a/dart-targeted.txt |
| Process: v2 문서 계산 + v2 시나리오 저장→재시작→조회→v1/v2 비교, 기존 scenario·FB-11a | **4건 통과**, debug/frontend_fb1a/dart-process.txt |
| 변경 Dart 5파일 analyze | **No issues found**, debug/frontend_fb1a/dart-analyze.txt |
| codealmanac validate | **통과**, debug/frontend_fb1a/almanac-validate.txt |
| git diff --check / 읽기 전용 slice 병합 검사 | **통과 / 수정 10파일 충돌 없음**, debug/frontend_fb1a/diff-check.txt / handoff-verification.json |

### FE4 초안 컨트롤러 연결 메모

- 현재 v1 화면·초안은 그대로 쓸 수 있다. PlanningDocument의 기본 version은 1이고 기존 stage.targets는 immutable 정수 Map이다. PlanElementStageDraft·preset·planningDocumentTargets는 변경하지 않았다.
- v2를 만드는 경계에서 PlanningDocument(version: 2, ..., goalMetadata: ...)를 명시한다. 각 단계 targets는 planningDocumentTargetKeys 19개를 전부 가진 Map<String, int?>로 만들고, 선택하지 않은 목표는 null로 둔다. 현재값으로 채우는 planningDocumentTargets를 v2 생성에 사용하지 않는다.
- v2 읽기·편집은 stage.nullableTargets를 쓴다. legacy stage.targets는 null을 포함한 단계에 대해 StateError를 내므로 v2를 기존 정수 편집기에 바로 넘기지 않는다. 선택 목표 제거는 그 학생의 모든 관련 단계에서 함께 지워 누적 회귀를 피한다.
- goalMetadata는 문서 학생 ID 집합과 맞춰 PlanningGoalMetadata(favorite: ..., notes: ...)를 구성한다. favorite=false와 메모를 초안 재생성·복제 때도 보존한다.
- 계산은 service.calculatePlanningDocument(..., document: document.toWire())를 사용한다. createScenario/compareScenarios는 v1/v2 PlanningDocument를 그대로 받는다. 반환 projection과 계산 경고를 초안에 연결하되 유효 계산 상태를 원본 targets에 넣지 않는다.
- FB-11a 계산기 호출은 계속 정수 targets로 남는다. 활성 문서 저장/로드·goals 파생 연결은 FB-1b 이후에 한다. planning_models.dart의 임시 소유 예외는 이 slice 종료와 함께 해제하되, 커밋 전 pre/post 경계를 지킨다.

### 사용자 실행 순서와 다음 배정

v7 루트 PowerShell에서 전체 Python 결과를 저장한다(아직 실행하지 않았으며 아래 결과 파일도 만들지 않았다).

```powershell
Push-Location backend
py -3.11 -m unittest discover -s tests -v 2>&1 | Tee-Object -FilePath ..\debug\frontend_fb1a\python-full.txt
$fb1aPythonExit = $LASTEXITCODE
Pop-Location
if ($fb1aPythonExit -ne 0) { throw "FB-1a Python full failed: $fb1aPythonExit" }
```

Python 전체 통과 → **두 워커가 모두 멈춘 뒤** fe_gate → fe_commit -Slice fb1a → redesigndocs.

```powershell
powershell -ExecutionPolicy Bypass -File frontend/tool/fe_gate.ps1
powershell -ExecutionPolicy Bypass -File frontend/tool/fe_commit.ps1 -Slice fb1a -DryRun
powershell -ExecutionPolicy Bypass -File frontend/tool/fe_commit.ps1 -Slice fb1a
redesigndocs
```

인계 파일: debug/frontend_fb1a/commit.json(status=false, whole=백엔드 상태 문서만),
수정 전 pre/와 고정 종료본 post/. baseline 폴더는 넣지 않았다.
종료본은 수정 10 + 추가 6 + whole 1 = 17파일이다. 읽기 전용 3-way 병합에서 mock의 기존
스캐너 변경이 커밋 후보에 섞이지 않고, Dart의 문서 DTO 밖 모델·preset·변환 helper가
pre와 같으며 Git index가 변하지 않는 것을 확인했다.
커밋·push·stage는 하지 않았다. **FB-1a 커밋까지 코드 편집을 멈춘다.**
FB-1b는 커밋 뒤 오케스트레이터 프롬프트를 받고 시작하며, 첫 작업은 legacy 이관 정책 fixture
(null bond·all-null·중복 학생 goal·부분 목표·빈 활성 문서)를 고정하는 것이다.

# FB-13 학생 catalog 애장품 가용성

## 착수 기록 (2026-10-08)

- 진행 중: FB-13. 시작 커밋 SHA: `2bcdcbd9f490a53e0bb4a0c66bd81625bfbeb895`.
- 워크플로 FB-13 행, FB-1 "분할", 실행 순서의 Lane A 병렬 규칙과 오케스트레이터 로그 08:57을 읽었다. FB-11a `facdd1d3` 이후 코드 편집 재개가 승인되었다. [@workflow]
- 범위: `planning.student.catalog`의 필수 `has_favorite_item: bool`(KR 서버 제공 여부), 계약·Python 테스트·Dart DTO/metadata·mock·번들 exporter/asset·DTO/mock/process 검증.
- 기존 미커밋 변경 있음: `mock_app_service.dart`, `planning_protocol_client.dart`, `process_app_service.dart`의 스캐너 변경. catalog 수정 전 사본은 `debug/frontend_fb13/pre/`에 보존한다. mock의 catalog 부분만 수정하고 나머지 서비스 2파일과 스캐너·tactic 소유 파일은 수정하지 않는다.
- `frontend/lib/ui/**`, 위젯·golden 테스트와 baseline PNG는 수정하지 않는다. 전체 gate는 두 워커가 모두 멈춘 뒤 사용자 PC에서 실행한다. golden 변화 시 비교 → 오케스트레이터 검토 → UpdateGoldens 및 재비교 → 커밋 순서를 따른다.
- 커밋·push·stage를 하지 않는다. FB-1a는 이 슬라이스 종료 후 준비 메모만 남기며 오케스트레이터 프롬프트를 받은 뒤 시작한다.

## 종료 기록 (2026-10-08)

FB-13 백엔드 범위의 코드·계약·직접 검증을 마쳤다. **Python 전체·공통 gate·golden 판정·커밋은 사용자 단계로 남는다.**
필수 wire 필드 누락이 확인된 프런트 소유 테스트 fixture 2곳과 범위 밖 almanac 오류 6건을
아래에 기록했다. 이 상태에서 공통 gate GREEN이나 동작 보존 완료를 주장하지 않는다.

### 구현과 계약

- `protocol_v1.py`: 모든 catalog 항목에 `student_meta.favorite_item_enabled(student_id, server="kr")`의 bool을 넣는다. 요청은 계속 `{}`이고 JP 제공·보유·장착·목표 티어와 독립적이다.
- schema·README·공용 fixture: 고정 필드는 19개, `has_favorite_item` 필수 bool. true/false fixture와 누락·"yes"·"no"·null·0·1 거부 fixture를 Python/Dart 양쪽에서 검증한다.
- `StudentCatalogEntry`: immutable `hasFavoriteItem`, strict fromWire, bool `metadata` getter. 수동 생성자 생략은 기존 대역 호환을 위해 false, `missing-student` fallback도 false다. 실제 wire 누락은 거부한다.
- `MockAppService._studentCatalogWire`: bool을 보존하여 compact·long-name 사본에서도 Aru=true / Ayane=false를 유지한다. 스캐너 코드와 서비스 나머지 2파일은 변경하지 않았다.
- exporter는 runtime catalog builder를 재사용한다. 기존 exporter 재실행 시 사라지던 FB-5 `forms`도 보존하고, asset·runtime 전체 항목이 같도록 재생성한다. 265명: KR true 60명, false 205명.
- 재생성 과정에서 기존 번들의 오래된 `jp_only=true` 7건이 현재 canonical/runtime 값 false로 동기화되었다: `niko`, `rena`, `akane_school_uniform`, `otogi`, `konoka`, `koyuki_pajama`, `kurumi`. 신규 bool과 이 7개 flag 외 기존 필드·폼·순서는 동일하다. canonical metadata 자체는 수정하지 않았다.
- Python은 Aru=true / Airi=false, Ayane·Asuna의 KR=false / JP=true를 검증한다. 모든 항목의 bool 타입·KR 판정, 잘못된 값·누락 schema 거부, 번들 전체 parity, exporter 재현성, Python process 전체 응답 parity를 검사한다.
- 새 Dart 서비스 테스트는 DTO·metadata·수동 생략·missing fallback·번들 전체·폼·이름 사본을 검사한다. 별도 process E2E는 실제 Python catalog와 번들·full mock의 265명 가용성 전체를 비교한다.

### 직접 검증

| 검사 | 결과와 로그 |
| --- | --- |
| Python `tests.test_student_catalog`, `tests.test_planning_protocol_contract`, `tests.test_canonical_metadata`, `tests.test_student_calculation_fb11a` | **33건 통과**, `debug/frontend_fb13/python-targeted.txt` |
| Dart `student_catalog_service_test`, `planning_protocol_client_test`, `planning_protocol_contract_test`, `mock_student_fixture_test` | **39건 통과**, `debug/frontend_fb13/dart-targeted.txt` |
| 새 `student_catalog_process_e2e_test` | **1건 통과**, `debug/frontend_fb13/dart-process.txt` |
| 변경 서비스·테스트 5파일 analyze | **No issues found**, `debug/frontend_fb13/dart-analyze.txt` |
| 프런트 fixture 영향 확인: `student_form_cycle_test`, `student_studio_layout_test` | **46건 통과 / 9건 실패**, 모두 `Invalid student catalog entry fields`, `debug/frontend_fb13/frontend-fixture-check.txt` |
| `codealmanac validate` | **실패, 범위 밖 metadata-manager 문서 오류 6건**, `debug/frontend_fb13/almanac-validate.txt` |
| `git diff --check` | 통과, `debug/frontend_fb13/diff-check.txt` |

#### 프런트 워커 연결 요청 (이 워커는 수정하지 않음)

1. `frontend/test/student_form_cycle_test.dart`의 `_wire`(18행)와
   `frontend/test/student_studio_layout_test.dart`의 Erika `StudentCatalogEntry.fromWire` 항목(1859행)에
   필수 `has_favorite_item` bool을 넣는다. 신규 strict 계약을 완화하면 안 된다. 두 곳 누락 때문에
   폼 교대 테스트 8건과 Studio 테스트 1건이 실패한다. 테스트를 삭제하지 않는다.
2. 수동 DTO 사본은 가용성을 유지하려면 `hasFavoriteItem: source.hasFavoriteItem`을 전달해야 한다.
   예: golden harness `_withDisplayName`은 현재 Hoshino(KR=true)의 필드를 생략하여 false로 만든다.
   이 워커는 golden 테스트를 고치지 않았다. 프런트 워커가 해당 fixture의 의미를 확인한다.
3. `_calculatorMetadata`의 전체-true 폴백 제거와 실제 false 학생의 애장품 행 숨김 검증은 프런트 몫이다.
   현재 metadata는 모든 DTO에서 bool을 제공한다. `students-calculator` 장면 Aru는 KR=true라
   해당 행은 유지될 것으로 예상하지만, golden 변화 여부는 공통 gate로 확정한다.

almanac 오류는 `metadata-manager-orchestrator-log`의 topics 누락 1건,
`metadata-manager-status`의 workflow 미인용 1건,
`metadata-manager-workflow`의 canonical-export·data-lock·devtools-backend·stats-sync 미인용 4건이다.
해당 소유자가 정리해야 하며 FB-13 범위에서는 편집하지 않았다.

### 사본·커밋 준비

기존 수정 파일 10개에 `debug/frontend_fb13/pre/` 사본을 만들었다. mock 서비스의 pre→post diff는
catalog bool 전달 **1줄**뿐이다. 수정 파일 10개·신규 테스트 2개와 종료 상태의 사본은
`debug/frontend_fb13/post/`에 고정한다. `debug/frontend_fb13/commit.json`은 `status: false`,
`whole: ["almanac/workflows/frontend-redesign-status-backend.md"]`, `post_dir: "debug/frontend_fb13/post"`다.
golden은 실행·갱신하지 않았으므로 baseline 폴더는 whole에 넣지 않았다. 검토 후 실제 PNG가 바뀐
경우에만 `frontend/test/goldens/baseline`을 whole에 추가한다. 커밋·push·stage 미실시.

인계 검증(`debug/frontend_fb13/handoff-verification.json`): pre/HEAD/post의 3-way 병합 10개가
모두 충돌 없이 가능하다. mock의 예정 커밋 내용에는 catalog bool 1줄만 추가되고 기존 스캐너
미커밋 변경은 포함되지 않는다. UI·golden·해당 프런트 fixture·서비스 나머지 2파일 등
착수 시 해시를 기록한 125개 보호 파일은 그대로다. 검증은 임시 파일에서만 수행했고 index를
변경하지 않았다.

### 사용자 실행 단계

저장소 루트의 일반 PowerShell에서 먼저 Python 전체를 실행한다. 결과 파일은 지정한
`debug/frontend_fb13/python-full.txt`다. 이 워커는 전체 결과 파일을 미리 만들지 않는다.

```powershell
Push-Location backend
py -3.11 -m unittest discover -s tests -v 2>&1 | Tee-Object -FilePath ..\debug\frontend_fb13\python-full.txt
$fb13PythonExit = $LASTEXITCODE
Pop-Location
Write-Host "FB-13 Python exit: $fb13PythonExit"
```

1. **Python 전체 통과** → 프런트 소유 fixture와 almanac 오류 정리 → **두 워커가 모두 멈춘 뒤**
   `powershell -ExecutionPolicy Bypass -File frontend/tool/fe_gate.ps1`.
2. golden 변화가 없으면 동작 보존 slice로 진행한다. 변화가 있으면 **① 비교 gate → 오케스트레이터
   차이 검토 → ② `fe_gate.ps1 -UpdateGoldens` 후 다시 `fe_gate.ps1` → ③ 커밋** 순서를 따른다.
   baseline whole 추가는 이 경우에만 한다. FE3-f2b의 golden ②는 FB-13 커밋 뒤에 한다. [@workflow]
3. GREEN 확인 후 `powershell -ExecutionPolicy Bypass -File frontend/tool/fe_commit.ps1 -Slice fb13 -DryRun`,
   이어 같은 명령에서 `-DryRun`을 빼고 실행한다. 기존 스캐너 변경이 섞이지 않는지 확인한다.
4. 오케스트레이터의 공유 문서 갱신과 `fe_commit.ps1 -Slice redesigndocs`로 문서 커밋을 정리한다.

### 다음 준비: FB-1a

FB-13은 정적 가용성 데이터이므로 FB-1 저장·이관 의존성을 추가하지 않는다. 다음은 승인된
분할의 **FB-1a: 문서 v2 nullable targets·goal_metadata·v1/v2 계산 및 시나리오 호환**이다.
현재 아래 FB-1 설계 조사와 워크플로 "분할"을 인계 자료로 유지한다. FB-1b 저장·이관과
FB-1c 교체 transaction은 별도 slice다. **오케스트레이터 프롬프트를 받은 뒤 FB-1a를 착수하며,
지금은 시작하지 않는다.**

# FB-11a 단일 학생 성장 계산

## 착수 기록

- 진행 중: FB-11a. 시작 커밋 SHA: `f2cf4fb81c07b30188a49d1240b3169ccc9fbf33`.
- 지정 문서의 불변식, Lane A 앞뒤 병렬, FD-162(b)·FD-163(a)·FD-026, runtime 경계, FE3-f1 계산 어댑터 및 FB-12 종료 기록을 읽었다. [@workflow]
- 범위: Python 계산·프로토콜, 계약, Dart 서비스·DTO, 서비스 테스트·process E2E. FB-11b는 저장소 데이터원 조사만 한다.
- 기존 미커밋 변경 있음: `mock_app_service.dart`, `process_app_service.dart`, `planning_protocol_client.dart`의 스캐너 변경. 수정 전 사본을 `debug/frontend_fb11a/pre/`에 보존했다. 스캐너 부분·프런트 UI·위젯/golden 테스트·공유 상태 문서는 수정하지 않는다.
- 전체 gate는 두 워커가 모두 멈춘 뒤 사용자가 실행한다. 커밋·push·stage를 하지 않는다.
- 사용자 확인: codealmanac가 topics를 읽을 수 있도록 YAML 메타데이터 뒤 **본문 첫 줄**에 지정 문구를 배치한다(2026-10-08 답변).

## FB-11a 종료 기록 (2026-10-08)

코드·계약·직접 검증 완료. **사용자 Python 전체 실행과 두 워커 종료 후 공통 gate·커밋은 대기**한다.
FB-11b 구현은 이번 슬라이스에서 하지 않았으며, 데이터 수치가 없는 부분을 아래에 명시했다.

### 바뀐 파일

| 파일 | 변경 |
| --- | --- |
| `backend/core/planning_calc.py` | 선택적인 크레딧 집계 인자와 9범주 상수. 기존 비용을 더하는 지점에서 집계, 기존 PlanCostSummary와 wire 불변 |
| `backend/core/planning_document.py` | 선택적인 집계 인자를 계산 코어에 전달. 기존 문서 계산·자원 행·현재값 이월 로직 재사용 |
| `backend/core/protocol_v1.py` | `planning.student.calculate` 등록·검증·읽기 전용 계산 응답 |
| `backend/tests/test_planning_protocol_contract.py` | 알려진 스키마 목록에 새 메서드 추가 |
| `backend/tests/test_student_calculation_fb11a.py` (추가) | Python 새 테스트 10건: fixture, 문서 일치, 9범주 고정값, 오류·strict 계약·입력 불변 |
| `contracts/planning-student-calculate-v1.schema.json` (추가) | currentStudent·19 key targets·optional inventory·totals·9범주·재화 행·warnings·예약 bond |
| `contracts/planning-protocol-v1.schema.json`, `contracts/protocol-error-v1.schema.json` | 알려진 메서드·오류 조합 등록 |
| `contracts/fixtures/planning_student_calculate_v1.json` (추가) | Python/Dart 공용 고정 fixture 4쌍 |
| `contracts/README.md` | 계약·범주·재고 의미·예약 bond·AppService 확장 방식 문서화 |
| `frontend/lib/services/student_calculation_service.dart` (추가) | strict DTO fromWire, 범주 합 검사, 재화 부족 일관성·중복 키 검사, immutable 예약 bond 객체 |
| `frontend/lib/services/app_service.dart` | DTO export와 `AppService.calculateStudent` 확장 메서드 |
| `frontend/lib/services/planning_protocol_client.dart` | 새 메서드의 응답 DTO 검사·오류 코드 등록 |
| `frontend/lib/services/process_app_service.dart` | 기능 인터페이스 구현, 한 번의 IPC 요청으로 DTO 반환 |
| `frontend/lib/services/mock_app_service.dart` | 기능 인터페이스 구현, 고정 fixture 비용 + 전달된 재고 보유/부족. 기존 스캐너 부분 수정 없음 |
| `frontend/lib/services/mock_student_calculation_fixture.dart` (추가) | 공용 fixture mixed_growth와 같은 canned 응답. Dart 비용 계산식 없음 |
| `frontend/test/student_calculation_service_test.dart` (추가) | 새 서비스 테스트 8건(DTO·reserved bond·strict 응답·오류·mock 저장소 불변) |
| `frontend/test/student_calculation_process_e2e_test.dart` (추가) | 새 실제 Dart↔Python 왕복 1건, 문서 계산과 일치·파일 바이트 불변 |
| 이 문서 | 백엔드 전용 기록. 공유 status·오케스트레이터 로그는 수정하지 않음 |

기존 파일 11개에 pre 사본이 있다. commit.json은 modified 11, added 7, `status: false`,
`whole: ["almanac/workflows/frontend-redesign-status-backend.md"]`다. slice 종료 사본은
`post_dir: "debug/frontend_fb11a/post"`로 고정하여 이후 다른 워커의 서비스 편집이 섞이지 않게 한다.
debug 로그·생성/검증 도구·사본은 커밋하지 않는다.

### 계약 요약

기존 `planning.student.*`에 맞는 **`planning.student.calculate`**를 그대로 채택했다(FD-162(b)).
입력·출력은 protocol v1의 추가 메서드이며 기존 메서드를 삭제하거나 기존 응답에 필드를 붙이지 않는다. [@student-contract]

| 방향 | 필드 | 계약 |
| --- | --- | --- |
| 입력 | `current_student` | 기존 current_students 항목 그대로. student_id 필수, 인연 현재 진행도 필드 없음 |
| 입력 | `targets` | 기존 계산기/문서 목표의 완전한 19 key. 정수 범위·성장 규칙을 기존 문서 검증기로 검사 |
| 입력 | `inventory` | 선택 inventorySnapshot. 생략은 `{version:1, entries:[]}`이며 보유를 0으로 가정하지 않음 |
| 출력 | `totals` | `{credits: int}`. 보유를 차감하지 않은 총 크레딧 |
| 출력 | `credit_breakdown` | 9범주 각각 nonnegative integer. 비용이 없는 범주도 0으로 포함, 합 = totals.credits |
| 출력 | `resources` | planning.document.calculate의 overall.resources와 같은 행·순서, 크레딧 행 포함 |
| 출력 | `warnings` | 기존 코어의 문자열 목록, 문서 계산과 같음 |
| 예약 | `bond` | 선택 객체로 예약. FB-11a Python/mock 모두 내보내지 않음. Dart는 객체만 허용하며 깊게 불변화해 보존, 의미 해석은 FB-11b |

범주 목록은 다음과 같다. 별도 부분 목표를 정규화하거나 비용을 다시 계산하지 않는다.

| key | 계산 코어의 단위 |
| --- | --- |
| `level` | 학생 레벨 |
| `student_star` | 학생 성급. 전무 해금 때문에 성급을 올리는 비용도 이 범주 |
| `weapon_star` | 전용무기 성급 |
| `favorite_item` | 애장품(기존 코어의 Tier2 비용) |
| `equipment` | 일반 장비 3칸 티어 + 레벨 |
| `ex_skill` | EX 스킬 |
| `weapon_level` | 전용무기 레벨 |
| `skill` | 일반 스킬 3개 |
| `potential` | 능력 개방 HP/ATK/HEAL |

재화 행 key는 `resource_key, item_id, display_name, category, required, owned, shortage,
affected_stage_ids`다. 재고 미확인/누락은 owned·shortage 둘 다 null, 명시적 0은 전체 필요량이
부족량이다. 부족량은 보유를 차감하고 0 아래로 내려가지 않는다. `unresolved:` 행도 보존한다.
affected_stage_ids는 기존 계산기 임시 문서와 같은 `["growth-calculator-stage"]`이며 저장 ID가 아니다.
서버 내부에서 기존 단일 단계 문서 검증·goal 변환·자원 projection을 재사용한다. 비용은 기존
planning_calc에서 한 번만 계산하며, 입력과 저장소·활성 계획을 변경하지 않는다.

AppService 자체의 기존 구현자(프런트 소유 widget 대역)를 깨뜨리지 않기 위해
`AppServiceStudentCalculation` 확장 메서드가 `PlanningStudentCalculationService`에 위임한다.
ProcessAppService·MockAppService가 기능 인터페이스를 구현하므로 AppService 타입에서도
`service.calculateStudent(...)`로 바로 호출한다. 이전 서비스 대역이 새 기능을 호출하면
UnsupportedError가 나며, 기존 메서드 사용은 그대로 가능하다.

mock은 mixed_growth 고정 비용·재화 fixture를 사용하고 재고 보유/부족만 입력에 맞춘다.
임의 목표를 실제로 계산하지 않으며, 기존 mock 문서 계산의 빈 결과도 그대로 둔다(FE3-f1의
기존 동작 테스트 유지). 실제 수치의 문서 일치 검증은 Python 및 process E2E에서 수행했다.

### 일관성 테스트와 검증

새 Python 테스트에서 같은 입력의 크레딧 합계·재화 행 전체·순서·경고를 기존 1페이즈
1단계 문서 계산과 비교하며, 모든 경우에 범주 합 = totals를 검사한다. [@student-tests]

- 공용 fixture 4쌍: 변경 없음, 레벨 30→31, 9범주 동시 성장, 같은 성장 + 0/충분/명시적 미확인 재고.
- 현재 목표보다 낮은 레벨·장비 목표: 비용 0, 재화 행 없음.
- ★5·해금 후 미장착 전무 ★2 Lv30, 장비 `Tier2`·애장품 T2 현재값: 이미 달성한 범주 비용 0, 전무 레벨 증분만 계산.
- 전 항목 최대 목표 1건 + 고정 seed 무작위 유효 목표 50건(장비 부분 레벨·스킬·전무·능력 개방 조합).
- 메타데이터 미존재 학생: 기존 경고 및 unresolved 행을 유지.
- mixed_growth 고정 수치: 총 14,000,529. 범주 순서대로 8,683,465 / 1,200,000 / 1,000,000 /
  500,000 / 31,164 / 80,000 / 2,115,900 / 90,000 / 300,000.
- invalid payload 11종(불필요 저장 ID, missing current/target, null inventory, bool 정수,
  unknown key, 전무/장비 성장 규칙 위반), 계산 예외의 correlated error, 예약 bond 객체 계약.
- Dart는 DTO strict 키·타입·범주 합·재화 부족 산식·중복 resource_key·예약 bond 깊은 불변을 검사.
- 실제 프로세스 왕복은 fixture와 일치하고 기존 문서 계산과도 일치한다. repository revision·goals·
  시나리오 목록이 그대로이며 테스트 저장 루트의 모든 파일 바이트도 동일하다.

직접 실행한 결과:

| 검사 | 결과 / 로그 |
| --- | --- |
| `py -3.11 debug/frontend_fb11a/run-python-worker.py` | **97건 통과**, 24.135초. 새 10건 + 계획/문서/FB-12/parity/계약/shortage/repository/scenario/metadata/gift 회귀. `debug/frontend_fb11a/python-worker.txt` |
| `flutter test --no-pub --concurrency=1 test/student_calculation_service_test.dart test/student_calculation_process_e2e_test.dart` | **9건 통과**(서비스 8 + 새 process 1). `debug/frontend_fb11a/dart-worker.txt` |
| 위 두 파일 + `planning_protocol_contract_test.dart`, `planning_protocol_client_test.dart`, `repository_protocol_contract_test.dart` | **34건 통과**. `debug/frontend_fb11a/dart-worker-regression.txt` |
| `dart analyze lib/services` | **No issues found**. `debug/frontend_fb11a/dart-analyze-services.txt` |
| `codealmanac validate` | **validate: ok**, 39 pages. YAML 뒤 본문 첫 줄 배치로 사용자와 합의한 메타데이터 형식 반영 |
| `git diff --check -- .` | 통과(기존 LF/CRLF 안내만 있음) |

Python 전체 약 26분, 전체 fe_gate·golden·Windows release는 직접 실행하지 않았다.
UI·위젯/golden 테스트는 수정하지 않았다. 스캐너 서비스 3개는 pre 대비 이번 계산 기능 추가만
있는 것을 확인했다. 기존 스캐너 변경·새로 생긴 다른 워커 파일은 커밋 목록에서 제외한다.

### FB-11b 사전 조사 (코드 수정 없음)

| 필요한 데이터 | 저장소 근거 / 판정 |
| --- | --- |
| 인연 랭크별 누적 경험치 수치 | **없음**. backend metadata/planning, SchaleDB adapter, data/extracted의 현재 JSON에는 랭크 경험치 표가 없다 |
| 쓰다듬기 경험치 수치·하루 가능 횟수 | **없음**. 현재 Python/메타데이터/추출 JSON에서 수치를 확인하지 못함. 임의 상수를 넣지 않았다 |
| 선물 기본 exp_value | **있음**: `backend/core/gift_meta_data.py`의 GIFT_ITEMS(52종, 저장된 exp_value 값은 20·60). `gift_meta.py:exp_value()`가 읽는다 |
| 학생 gift_affinities | **있음**: `backend/data/metadata/v1/student_catalog.json`의 gift_affinities(265명), preferred_tags·unique_tags. Ayane는 BB/bB. `canonical_metadata.py`가 검증·분리 보관, `student_meta.py:157~162`가 호환 accessor 제공 |
| SchaleDB 변환·쓰기 | `schaledb_metadata_adapter.py:89` adapt_gifts가 Favor 아이템의 ExpValue→exp_value, Tags→tags 변환. `schaledb_provider.py`는 students/items JSON만 읽음. `tools/developer_tools.py:991`가 별도 gift_meta_data GIFT_ITEMS를 원자적으로 갱신 |
| 기존 선호 배수 계산 근거 | `tools/developer_tools.py:833` _student_gift_affinities: preferred/unique 태그 + UNIVERSAL_GIFT_TAGS(BC/Bc/ew), match_count 최대 3, multiplier=1+match_count, points=exp_value*multiplier. 개발 도구 전용이며 FB-11b에서 도메인 경계로 분리할 후보 |

인연 보상 추출표와 경험치 표는 구분해야 한다:

- `data/extracted/jp-json/FavorLevelRewardExcel.json`은 13,750행이고 key는
  `character_id, favor_level, stat_type, stat_value`뿐이다. 인연 **능력치 보상**이며 경험치 표가 아니다.
  public-json의 동명 파일 및 student-stats-jp.json도 이 통계 경로라 누적 경험치 근거로 쓰지 않는다.
- `debug/il2cpp_types/types-steam-bbe68ad3.json`에는
  `MX.Data.Excel.FavorLevelExcel` 타입(Level·ExpType vector),
  `MX.Data.Excel.CafeInteractionExcel` 타입(FavorEmoticonRewardParcelType·Id·Amount)이 있다.
  **타입/필드 이름만 있고 실제 행 수치가 없다.** 따라서 이름을 발견했다고 경험치 숫자가 확보된 것은 아니다.
- FB-11b에 필요한 데이터원: 같은 클라이언트 버전의 FavorLevelExcel 실제 행과 ExpType 값의
  해석 근거(랭크 경험치·누적 변환), CafeInteractionExcel 실제 보상 행과 parcel type 확인,
  쓰다듬기 횟수/재사용 간격의 설정·행 근거. 현재 추출 pipeline의 표 목록에는 이 두 표가 없다.
  데이터를 확보하기 전 FB-11b의 경험치/일수 계산을 구현하지 않는다. 외부 숫자·시안 예시를 채택하지 않았다.
- 조사 중 어떤 메타데이터·SchaleDB 동기화·추출 pipeline·스캐너/tactic 파일도 고치지 않았다.
  로컬 조사 결과만 `debug/frontend_fb11a/bond-type-survey.json`, `bond-field-survey.json`에 남겼다.

### 프런트 워커 연결 메모 (프런트 소유, 이번에 수정하지 않음)

`growth_calculator_adapter.dart`의 `calculateGrowthTargets`에서 임시 문서 생성/호출 대신 다음을
한 번 호출한다. 기존 250ms 디바운스·요청 번호/늦은 응답 버림·취소·오류 상태는 그대로 둔다.

```dart
final result = await service.calculateStudent(
  currentStudent: request.currentStudent,
  targets: request.targets,
  inventory: request.inventory,
);
```

- import는 기존 `services/app_service.dart`면 DTO·확장 메서드가 함께 보인다. 기능 판별이
  필요하면 `service is PlanningStudentCalculationService`를 사용한다.
- 총 크레딧은 `result.credits`, 경고는 `result.warnings`다. `result.resources`에서
  resourceKey가 credits인 행을 빼면 기존 성장 재화 목록이다. `row.toWire()`를 기존
  GrowthCalculatorResourceRow.fromWire에 넘길 수 있고 requiredAmount·owned·shortage를 직접 매핑해도 된다.
- `creditBreakdown`은 현재 `GrowthCalculatorCreditBreakdown.unavailable` enum/getter뿐이므로
  프런트에서 available 상태 + `Map<String,int>`를 담는 형태로 확장하고 `result.creditBreakdown`을 채운다.
  9범주를 그대로 그리거나 EX+일반 스킬, 전무 성급+레벨처럼 표시용으로 합칠 수 있다.
  모든 비용 범주가 합계에 포함되도록 학생 성급·애장품·능력 개방을 빠뜨리지 않는다.
- 필요 재화 수량을 더해 한 숫자로 만들지 않는다. unknown owned/shortage는 지금처럼 Unknown으로
  매핑한다. 크레딧 보유·계획 포함·스캔 시각의 FD-172 정책은 별도 기존 상태를 유지한다.
- 이번 DTO의 reservedBond가 null인 것은 FB-11a의 정상 응답이다. 인연 타일은 FB-11b 전까지 기존
  빈 상태를 유지한다. 인연 현재값/진행도 입력 계약을 이번에 늘리지 않았다.
- frontend 위젯 대역은 기존 AppService만 구현해도 계속 컴파일된다. 새 기능을 쓰는 대역은
  기능 인터페이스도 구현하거나 MockAppService의 calculateStudent를 override한다.

### 사용자 실행 단계

① 사용자 PC Python 전체 테스트. 결과 파일은 **debug/frontend_fb11a/python-full.txt**다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7\backend"
py -3.11 -m unittest discover -s tests -v *> ..\debug\frontend_fb11a\python-full.txt
Get-Content ..\debug\frontend_fb11a\python-full.txt -Tail 5
```

② **프런트·백엔드 두 워커 모두 멈춘 뒤** 아래 순서로 실행한다. gate GREEN 전 커밋하지 않는다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fb11a -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fb11a
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesigndocs
```

실행 실패가 있으면 해당 로그로 확인한다. 전체 검사 통과·커밋 결과는 이 백엔드 상태 문서에
추가한다. 다음 행동: 사용자 전체 검증 → FB-11a 커밋 → 프런트 계산기 어댑터 연결,
FB-11b는 누락 데이터원을 먼저 확보한다.

## FB-1 읽기 전용 설계 조사 (2026-10-08)

**FB-11a 사용자 승인. 프런트 수정 → gate GREEN → fb11a 커밋까지 코드 편집 중지.**
이번 작업은 아래 조사 기록만 추가한다. Python·Dart·계약·fixture·commit manifest·프로필은
수정하지 않았고, FB-1 구현을 시작하거나 gate를 실행하지 않았다. 조사 시 HEAD는
`f2cf4fb81c07b30188a49d1240b3169ccc9fbf33`다. 아래 계약과 문서 v2는 **제안**이며 구현된 계약이 아니다.

### 요구와 현재 경로

워크플로의 **FB-1 절 전체**를 읽었다. `repository.plan.*` 신설, goals-only 프로필의 첫 로드
영속 이관, 저장과 같은 revision의 goals v1 파생, **문서에서 명시적인 "목표 없음"**, Python·계약·
Dart·mock·계약 테스트·process E2E 한 슬라이스, v6 가져오기·시나리오 저장·통계 회귀 0이 요구다. [@workflow]
FD-003·026·027·049·050·065·066·067·083·138도 함께 확인했다
(`docs/frontend-redesign/decision-register.md`). FD-067의 기존 활성 계획 자동 시나리오 보존과
FD-083의 활성 계획 계산 요약을 계약 초안에 포함한다.

- `backend/core/repository_store.py`: 프로필에는 students·inventory·goals·idempotency만 있다.
  `_profile`이 키 집합을 정확히 검사하므로 active document를 파일에 덧붙이기만 하면 corrupt_data다.
  `get_state`/Dart `RepositoryState.fromWire`도 현재 다섯 응답 키를 고정한다.
- `frontend/lib/ui/widgets/plan_section_layout.dart::_loadRepositoryPlan`: goals 순서로 학생당 단계 1개,
  페이즈 1개를 메모리에서 만든다. 문서 ID `active-plan`, 페이즈 ID `v6-imported-plan`,
  단계 ID `v6-<student_id>-1`, 이름은 notes 또는 "v6 목표"다. 빈 goals는 phases=[]다.
- `frontend/lib/ui/models/planning_models.dart::planningDocumentTargets`: null/없는 goal 값을 현재값으로
  채우고, 인연은 현재값 또는 1을 넣은 뒤 정규화한다. **이 반환값을 그대로 저장해서는 안 된다.**
- `backend/core/planning_document.py`: 현재 문서 v1은 19개 key의 정수 targets를 요구하며
  bond_rank도 1~100이다. `_goal`은 18개만 StudentGoal로 매핑한다. goals v1에는 인연 필드가 없다.
- `frontend/lib/ui/models/active_plan_bond_target.dart`: 지금은 ActivePlanDocumentSource가 없으면
  null이다. goals에서 인연 목표를 만들지 않으며 마지막 단계 목표를 조회한다. FB-1 연결 경계다.
- `backend/core/scenario_store.py::_calculation_summary`: 문서 projection으로 목록 KPI를 만든다.
  active get도 이 로직을 공용화해서 사용한다. Python이 계산·저장을 소유한다
  (`almanac/architecture/runtime-boundaries.md`).

### "목표 없음"의 계약 초안

권장안은 **PlanningDocument v2의 19-key nullable targets**다. key는 모두 존재해야 하며,
값은 int 또는 null이다. `null`은 해당 항목의 목표 없음이고, 0은 그 필드에서 허용되는 실제
수치다. bond_rank는 null 또는 1~100이다. 예를 들어 현재 인연 35라도 목표가 없으면
`"bond_rank": null`로 저장하고, 현재 인연을 몰라도 null로 저장한다.
현재값과 같거나 낮은 정수 목표는 달성한 명시적 목표이며 null과 다르다.

- 단계 없음, 단계의 특정 목표 없음, 모든 targets가 null인 단계, 빈 활성 계획(phases=[])을
  구분한다. 빈 문서도 저장된 활성 문서이므로 재로드 때 예전 goals로 되살리지 않는다.
  이관 시 all-null goal 항목은 보존하고, 새 편집기의 무성장 단계 제거 정책과 구분한다.
- 단계는 계속 누적 절대 목표다. 같은 학생의 이전 명시적 목표는 후속 단계에도 유지한다.
  int 이후 더 작은 int나 null로 지우는 입력은 회귀 오류로 처리한다. 목표 제거는 그 학생의
  관련 모든 단계에서 해당 목표를 지우는 문서 편집으로 표현한다. 처음 null이던 필드는
  후속 단계에서 처음 정수 목표를 가질 수 있다.
- 계산은 null을 원본 목표로 보존한 채 기존 StudentGoal/계산 코어에 전달한다. 현재값·이전
  단계의 계산 후 상태 및 전무/장비의 필수 선행 성장은 계산 중에만 적용한다. 이 유효 상태를
  다음 단계에 넘기는 공용 코어 경계를 마련하고, 계산용 현재값을 저장 targets로 되쓰지 않는다.
  비용식·정규화는 복제하지 않는다. 현재 `_advance`를 nullable 목표에 그대로 쓰면 안 된다.
- 문서 구조·값 범위·학생별 단계 순서는 저장 시 검사한다. null이 낀 잠금/선행 조건 검사는
  실제 현재 상태와 공용 성장 규칙을 함께 사용해야 한다. 현재 인연을 모른다고 1을 만들거나,
  애장품 목표가 있다고 사용자가 정하지 않은 인연 목표를 만들지 않는다. 데이터가 부족하면
  계산 경고로 드러낸다. 이관의 애장품/전무/부분 목표 fixture로 정책을 먼저 고정한다.
- 기존 문서 v1과 FB-11a 단일 학생의 완전한 정수 targets는 계속 받는다. 문서 v2를 새로운
  schema 분기로 추가하고 `planning.document.calculate`·scenario 저장/비교가 같이 읽도록 한다.
  기존 v1의 정수 의미를 바꾸거나 FB-11a 계약을 nullable로 바꾸지 않는다.

문서 버전 선택은 FB-1 구현 착수 때 확정할 사항이다. 현재 v1만으로는 목표 없음의
lossless 저장이 불가능하므로, schema·Python·Dart 문서 DTO·시나리오 경로의 동시 확장이 필요하다.

### repository 계약 초안 (protocol 1)

| 메서드 | 입력 payload | 성공 출력 payload | 의미 |
|---|---|---|---|
| `repository.plan.get` | `{profile_id}` | `{profile_id, revision, document, calculation}` | kind=plan인 저장 문서와 현재 profile revision, 계산 요약. legacy 첫 로드는 이관 후 revision을 반환 |
| `repository.plan.save` | `{profile_id, expected_revision, idempotency_key, document}` | `{revision}` | 전체 활성 문서와 파생 goals를 같은 profile revision으로 저장 |
| `repository.plan.replace` | `{profile_id, expected_revision, expected_scenario_revision, idempotency_key, document, archive_name, archive_description}` | `{revision, scenario_revision, archived_scenario_id}` | 기존 활성 문서를 kind=scenario로 보존하고 새 활성 문서/goals 저장을 단일 transaction으로 수행 |

`document`는 위 문서 v2 제안이며 활성 입력은 kind=plan만 받는다. 새 프로필과 이관 완료
프로필에는 빈 경우에도 문서가 존재한다. replace에서 기존 phases가 비었으면 보존할 계획이
없으므로 archived_scenario_id=null, scenario_revision은 증가하지 않는 안을 권장한다.
페이즈로 추가는 프런트가 활성 문서와 새 페이즈를 합쳐 save하는 기존 FD-080 방향이다.
ID 중복·학생별 단계 회귀를 백엔드에서 검사하고 expected_revision으로 동시 편집을 막는다.

`calculation`은 scenario.list의 PlanningScenarioCalculationSummary와 같은 모양이다:
credits, required_resource_type_count, known_shortage_type_count, inventory_complete,
first_bottleneck_phase_number(null 허용), representative_shortage(null 또는
resource_key·item_id·display_name·category·shortage). 문서와 같은 revision의 students/inventory로
계산한다. 요약 계산 실패는 calculation=null로 드러내되 저장 문서는 조회 가능하게 유지한다.
상세 활성 계획 수치는 FD-026대로 저장 문서의 `planning.document.calculate` 결과를 쓴다.

기존 repository.state.get 응답에 문서를 몰래 추가하지 않는다. 새 plan get/save DTO와
RepositoryService 기능을 추가하고 ProcessAppService·MockAppService·strict fromWire를 맞춘다.
state와 plan을 따로 읽을 때 revision이 다르면 재조회하여 같은 snapshot으로 계산한다.
기존 invalid_payload·revision_conflict·idempotency_conflict·repository_busy·persistence_failed
오류 규칙을 재사용하고, replace의 두 revision을 오류 details에서 구별한다.
재시도는 최초 응답을 그대로 반환하고 시나리오를 두 번 만들지 않아야 한다.

저장상의 주의: `_catalog_mutation`은 profile+catalog 두 파일을 순서대로 쓰고 **잡힌 예외**에
rollback한다. ScenarioStore는 별도 파일·lock·collection revision을 쓴다. 기존 `scenario.create`
후 `plan.save`를 호출하는 조합으로 FD-067을 충족했다고 볼 수 없다. 공통 transaction 경계,
고정 lock 순서, 중단 후 journal 복구를 설계하고 모든 관련 읽기가 미완료 transaction을
복구한 뒤 보도록 한다. 문서/goals/idempotency는 한 profile payload, archive는 scenario payload,
revision 요약은 catalog에 함께 반영한다. 기존 idempotency 응답 검사는 `{revision}`만 허용하므로
replace 응답 저장 형식을 확장할 때 기존 캐시도 계속 읽어야 한다.

### goals v1 파생 방식

문서 순서(phase 순서 → stage 순서)에서 학생별 **마지막 단계**를 선택한다. 첫 등장 학생
순서를 유지하여 학생당 goal 하나를 만든다. 마지막 단계의 누적 targets를 쓰고, 단계 비용을
더하거나 필드별 최대값을 임의로 합치지 않는다.

| 문서 target | goals v1 field |
|---|---|
| level / student_star | target_level / target_star |
| weapon_level / weapon_star | target_weapon_level / target_weapon_star |
| ex_skill / skill1·2·3 | target_ex_skill / target_skill1·2·3 |
| equip1·2·3_tier / equip1·2·3_level | target_equip1·2·3_tier / target_equip1·2·3_level |
| equip4_tier | target_equip4_tier |
| stat_hp / stat_atk / stat_heal | target_stat_hp / target_stat_atk / target_stat_heal |
| bond_rank | 대응 필드 없음. 활성 문서에만 보존하고 goals v1에 새 key를 넣지 않음 |

nullable 값은 대응 target_*에도 null로 남긴다. student_id를 넣고, 단계가 사라진 학생의
파생 goal은 제거한다. 빈 문서는 `{version:1, goals:[]}`다. all-null 학생도 호환 목록에서
보존하지만, 인연 게이지/구체적 목표 유무는 숫자를 채워서 유도하지 않는다.
기존 favorite와 notes의 lossless 보존이 필요하다. 권장 초안은 문서의 학생별 `goal_metadata`
(student_id → favorite·notes)로 보존하고, 새 학생은 favorite=true, notes는 최종 단계 이름을
기본값으로 삼는 것이다. 이 metadata의 strict schema도 문서 v2 안에 포함한다.

파생은 저장 transaction 안에서 백엔드만 수행한다. students/inventory 스캔·수동 수정은
사용자 targets를 다시 만들지 않고 projection만 바꾼다. goals v1은 호환 소비용 결과이며
활성 문서 수치의 새 원천이 아니다(FD-026·138).
기존 `repository.goals.save`도 영향받는다.
두 저장 원천을 남기지 않도록 legacy writer를 같은 goals→문서 변환/transaction으로 연결하는
안이 필요하다. empty/legacy 단일 페이즈는 이 경로를 허용하고, 다중 페이즈·인연 목표를 가진
문서의 손실성 덮어쓰기는 명시적 오류로 막는 안을 권장한다. 정확한 오류 계약은 FB-1에서 확정한다.

### 기존 프로필의 첫 로드 이관

1. 저장 형식 v1 reader를 유지하고, active document가 없는 legacy 프로필만 대상으로 한다.
   profile의 새 저장 버전/명시적 active 필드로 이관 완료를 구별한다. catalog·inventory·protocol
   버전은 각각 따로 취급한다. 문서가 빈 것은 미이관 상태가 아니다.
2. 목표 순서·학생당 단계 1·페이즈 1·기존 표시 이름 규칙을 재사용한다. 18개 goal target은
   원래 정수/null 그대로 매핑하고 bond_rank는 **항상 null**이다. 현재 students에서 목표를
   채우지 않는다. favorite·원래 notes도 보존한다. goals가 비면 empty active document를 저장한다.
3. repository lock 아래 이관 여부를 재확인하고 문서+파생 goals+profile/catalog revision을
   한 번만 저장한다. get_state와 plan.get 등 공개 profile-state 로드가 같은 이관 함수를 쓴다.
   동시 첫 로드·재시작은 한 번만 이관한다. 기존 파일과 idempotency 내역을 보존하고,
   실패 시 corrupt legacy를 빈 문서로 덮어쓰지 않는다.
4. 이미 저장된 프로필의 이관은 revision을 한 번 증가시키고 반환 revision이 권위값이다.
   listProfiles에서 받은 이전 revision을 이후 저장에 쓰지 않는다. 기존 시나리오의
   base_profile_revision은 과거 기준으로 유지되어 stale 표기가 생길 수 있음을 소비자에 전달한다.
  신규 생성/v6 import는 가능하면 최초 profile 생성 transaction에 문서를 함께 넣어 별도 이관을 피한다.
  `backend/tools/seed_ui_test_profile.py`는 v6 import 후 get_state의 revision으로 scenario를 만들므로
  이관 후 반환 revision과 기존 시나리오 seed의 반복 실행을 회귀 검사한다.
5. 현재 임시 변환의 `v6-<student_id>-1` ID는 중복 student goal에 충돌한다. 기존 schema는 중복
   goals를 명시적으로 막지 않고 calculate_plan_totals는 각 항목을 더한다. 마지막 항목으로
   조용히 접으면 기존 비용이 바뀔 수 있다. 중복 fixture와 이관 오류/정리 정책을 먼저 정해야 한다.
   스캔에 없는 학생·부분 목표·잠금 조건이 맞지 않는 legacy 목표도 삭제/가짜 목표 생성으로 처리하지 않는다.

필수 회귀 fixture: null bond(현재 알려짐/모름), all-null goals, 명시적 0, 현재와 같은 목표,
부분 목표/전무의 필수 성급/애장품, 빈 계획 저장 후 재로드, 여러 단계의 최종 파생,
v6 가져오기 후 비용·재화 parity, 재시작·동시 첫 로드, stale revision, idempotent replay,
replace 중 저장 실패/프로세스 중단 복구, 기존 v1 scenario 저장·비교·통계 경로.
process E2E는 legacy 첫 get→새 문서 save→재시작 get→goals/문서 계산 및 교체 보존까지 묶는다.
이번 조사에서는 테스트를 작성하거나 실행하지 않았다.

### 영향받는 소비자 목록

| 소비자/경계 | FB-1 영향 |
|---|---|
| JsonRepository, RepositoryProtocolV1, repository DTO/schema/fixtures, ProcessAppService, MockAppService | 새 문서 저장/이관/파생, 엄격한 키 검사, revision·idempotency·transaction 일치 |
| planning_document.py, 문서 calculate schema/fixture, Dart planning_models.dart | 목표 없음/문서 v2, 단계 진행 상태, v1 호환 |
| ScenarioStore, scenario protocol/DTO, compareScenarios | 문서 v2 round-trip, 원자적 archive, 공용 활성 요약, 기존 v1 scenario 호환 |
| plan_section_layout.dart, plan_student_selector.dart, FE4 저장 흐름 | `_loadRepositoryPlan` 메모리 변환을 plan get으로 교체, save/append/replace 연결 |
| active_plan_bond_target.dart, student_page.dart/학생 인디케이터 | 저장 문서의 마지막 nullable bond 조회; 현재 plannedIds는 state.goals 기준이므로 문서로 연결 |
| growth_calculator_adapter.dart | 현재 계획 포함 판정은 goals 기준. FB-1 후 문서로 연결; 단일 학생 계산 자체는 FB-11a 유지 |
| inventory_page.dart | 현재 state.goals→calculateShortages. 호환 경로 유지, 새 활성 화면은 FD-026 문서 projection으로 연결 |
| statistics_page.dart, 통계 view model/fixture | 현재 goals→calculatePlan/calculateShortages와 goals.length. 새 계획 수치는 저장 문서 projection으로 연결 |
| scenario 목록/비교의 활성 행, FE5/FE6/FE7 | get.calculation 공용 KPI, 현재 상태 변경 때 재계산, 문서 저장 때 revision 갱신 |
| title_page.dart, account_section_cluster.dart, scan_page.dart, tactical_page.dart, 프로필 전환 | state 로드에 이관 revision 변화가 생김. 갱신 revision 전파/캐시 재조회 검사; scanner/tactic 파일은 별도 소유자 협의 |
| seed_ui_test_profile.py, repository/v6 migration/parity/process E2E, 계획·학생·통계·인벤토리 service/widget 대역 | legacy writer 정책과 첫 로드 부작용, 신규 RepositoryService capability, strict DTO fixture 갱신 |

프런트 파일은 조사만 했다. 코드 동결 해제 후에도 백엔드 워커가 UI·위젯/golden 테스트를
편집하지 않고, 문서 버전/새 서비스 계약을 프런트 워커에게 연결 메모로 전달해야 한다.

### 다음 백엔드 요청: 학생 catalog has_favorite_item

프런트 요청 **`planning.student.catalog` 항목에 `has_favorite_item: bool` 추가**를 접수한다.
**권장: FB-1과 분리한 작은 catalog 확장 slice**로, fb11a 커밋 이후 먼저 진행한다.
이 필드는 정적 가용성 데이터이고 프로필 저장·이관·목표 없음과 독립적이다. 계산기 애장품 행의
현재 전체-true 폴백을 해소하는 데 FB-1의 저장 설계를 기다릴 필요가 없다. slice 번호는
오케스트레이터가 배정하며 이번 조사에서 FB 표/결정 등록부를 수정하지 않는다.

- 근거: `backend/core/student_meta.py::favorite_item_enabled(student_id, server="kr")`가 bool을
  반환한다. 내부 `has_favorite_item`은 "yes"/"no" 문자열이며 서버별 필드 → 공유 필드 →
  favorite 학생 집합 순서로 판정한다. source of truth는
  `backend/data/metadata/v1/student_catalog.json`이고 generated student_meta_data.py는 수정 대상이 아니다.
- 제안 의미: 현재 catalog 요청이 `{}`이고 profile server 입력이 없으므로 **KR 서버에서 애장품이
  제공되는 학생인지**로 고정한다. JP 제공 여부, 현재 보유/장착 여부, 목표 equip4_tier와 구분해
  README에 적는다. JP 지원은 별도 server 선택 계약이 생길 때 확장한다.
- 범위: protocol_v1.py catalog builder, catalog schema·fixture·README/Python contract tests,
  StudentCatalogEntry 필드·strict fromWire·metadata getter, MockAppService `_studentCatalogWire`,
  `frontend/tool/export_student_catalog_asset.py`와 재생성한 `frontend/assets/student_catalog.json`,
  DTO/mock/process 검증을 같은 작은 slice에 넣는다. bool은 모든 신규 catalog 항목에 제공하고
  문자열 "yes"/"no"/null을 wire bool 대신 보내지 않는다. 기존 UI+backend 동시 배포 원칙을 따르며,
  기존 fixture/수동 DTO 생성자의 누락·fallback 처리도 계약에서 명시한다.
- 검증: true/false 및 KR/JP 가용성 차이 사례, 잘못된 bool 타입 거부, runtime catalog↔bundled mock
  값 parity, process 왕복. 아직 폴백인 missing-student를 실제 가용 학생으로 간주하지 않는다.
- 프런트 연결: `StudentCatalogEntry.metadata`에 bool을 넣으면 student_page.dart의
  `_calculatorMetadata`가 이미 해당 key를 우선한다. 폴백 제거/애장품 행 숨김 검증은 프런트 워커
  몫이며 이번에 고치지 않았다. FB-1에는 이 필드를 의존 조건으로 묶지 않는다.

조사 문서 검증: `codealmanac validate` OK. 변경 대상은 이 상태 문서뿐이며, 코드 동결을 유지한다.
