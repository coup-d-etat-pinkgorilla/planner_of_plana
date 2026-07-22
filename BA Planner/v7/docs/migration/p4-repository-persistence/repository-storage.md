# P4 repository storage contract

## Layout and ownership

Injected storage root 아래 `catalog.json`은 profile ID, display name, 선택 profile과 노출
revision을 소유한다. `profiles/<profile-id>.json`은 format version, monotonic revision,
P3 confirmed students, canonical inventory snapshot, user goals와 idempotency receipts를
소유한다. Static `StudentMeta`, `PlanCostSummary`, shortage는 저장하지 않는다. Import 시에는
어떤 경로도 생성하거나 읽지 않는다.

## Atomicity and concurrency

Writer는 storage root의 `.repository.lock`을 exclusive-create하여 process 간 single-writer
경계를 만든다. 충돌은 `repository_busy`이며 retryable이다. JSON은 대상과 같은 filesystem의
temporary file에 deterministic canonical JSON으로 기록하고 flush/fsync 후 `os.replace`한다.
실패한 temporary file은 제거하고 마지막 정상 대상 파일을 보존한다. crash로 남은 hidden
`.tmp` 파일은 authoritative file로 읽지 않는다. JSON parse/shape 오류는 `corrupt_data`,
unknown format version은 `migration_required`로 fail-closed 처리한다.

Profile data mutation은 expected revision이 현재 revision과 같을 때만 적용한다. 동일
idempotency key와 동일 fingerprint 재시도는 저장된 response를 반환하여 revision을 다시
증가시키지 않는다. 같은 key의 다른 mutation은 `idempotency_conflict`다.

## Inventory and migration

P4 저장 값은 이미 P3 `InventorySnapshot` 경계로 canonicalized된 snapshot이다. SQLite/JSON
raw snapshot 선택 adapter는 P3 `resolve_inventory_snapshot()` 결과의 source와 error를
숨기지 않아야 한다. P4 core는 실제 v6 DB나 profile을 자동 탐색하지 않는다. v6 import
preview는 현재 `migration_not_supported` 구조화 오류로 고정하며 원본 파일을 읽거나 수정하지
않는다. Catalog 기반 name-only inventory migration은 후속 명시적 설계가 필요하다.

## Recovery

정상 catalog/profile은 손상 입력이나 write/replace 실패로 덮지 않는다. Catalog와 profile
사이 불일치는 corruption으로 취급하며 자동 추측 복구하지 않는다. 사용자는 마지막 정상
백업 또는 향후 migration 도구로 명시적으로 복구해야 한다.

## Flutter typed boundary

Flutter는 repository 파일, JSON 또는 storage root를 직접 읽지 않는다.
`ProcessAppService`가 protocol success payload를 method별로 검증하고 state response를
immutable `RepositoryState`, `ConfirmedStudentState`, `RepositoryInventoryState`와
`RepositoryGoalState`로 변환한다. Planning UI와 `MockAppService`도 같은 typed service
계약을 사용한다. Static metadata, 계산 총계와 shortage는 typed repository state에 없다.

Confirmed current, inventory와 goal의 nested request/state shape는 Python DTO와 공용 schema가
소유한다. 공용 fixture 40 cases(valid 14, invalid 26)를 Python schema·DTO와 Dart validator가
함께 판정하며 malformed repository success는 Dart process 연결을 fatal error로 종료한다.

## Cross-language restart verification

Flutter process E2E는 `Directory.systemTemp.createTemp()`로 고유 root를 만들고 test-only
`BackendProcessConfig.environment`를 통해서만 `BA_PLANNER_STORAGE_ROOT`를 전달한다.
`Process.start()`는 부모 environment를 유지하며 production의 빈 environment override와
기본 repository 경로 선택은 바뀌지 않는다.

Test는 첫 Dart `ProcessAppService`가 실제 Python child process에서 profile을 생성·rename·
select하고 canonical goal을 저장한 뒤 typed state와 revision을 확인한다. Service dispose로
첫 process의 정상 종료를 기다리고, 같은 temporary root에 두 번째 실제 Python process를
시작해 같은 profile ID, display name, revision과 goal을 복원한다. 두 번째 process도 정상
종료한 뒤 temporary root를 `finally`에서 삭제한다. 따라서 실제 사용자 profile, DB나 home
storage는 test 대상이 아니다. Public Flutter service에 아직 current/inventory mutation이
없으므로 그 두 bucket의 process 재시작 보존은 Python repository persistence suite가 별도로
검증한다.
