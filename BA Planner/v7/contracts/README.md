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

## scanner protocol v1

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
