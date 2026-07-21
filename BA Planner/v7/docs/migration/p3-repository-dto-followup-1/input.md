# P3 후속 작업 지시 — DTO 경계와 필수 parity 사례 보완

## 작업 정보

- 작업 ID: `ba-planner-v7-p3-repository-dto-followup-1`
- 저장소: 슬레이브 PC의 BA Planner v7 저장소 루트
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p3-repository-dto-followup-1`
- 기준 상태: 원본 P3 결과가 적용된 상태에서 수행하는 증분 보완 작업
- 실행 환경: 슬레이브와 마스터는 서로 다른 PC이며 파일시스템을 공유하지 않음

## 배경

마스터는 원본 P3 패키지
`ba-planner-v7-p3-repository-dto-20260722-004020.zip`을 검증하고 patch를 적용했다.
패키지 무결성, patch scope와 전체 자동 검증은 통과했지만, 추가 부정 검증에서 P3 완료
조건을 충족하지 못한 항목이 확인됐다.

이 작업은 원본 P3를 다시 생성하거나 전체 patch를 재전달하는 작업이 아니다. 마스터에
이미 적용된 원본 P3 상태 위에 적용할 수 있는 **증분 보완 patch**만 만든다.

## 작업 전 필수 확인

다음 파일을 UTF-8로 완전히 읽는다.

1. `AGENTS.md`
2. `README.md`
3. `almanac/workflows/p0-p6-workflow-status.md`
4. `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P3 절
5. `almanac/workflows/slave-artifact-handoff.md`
6. `almanac/workflows/cross-pc-slave-handoff.md`
7. `docs/migration/v6-knowledge-baseline.md`
8. `docs/migration/p3-repository-dto/input.md`
9. 원본 P3의 `output.md`와 `artifacts/verification.txt`
10. `backend/core/repository_dto.py`
11. `backend/core/repository_merge.py`
12. `backend/core/planning.py`
13. `backend/core/planning_calc.py`
14. `backend/core/student_meta_types.py`
15. `backend/tests/test_repository_parity.py`
16. `contracts/fixtures/repository_v6_parity.json`
17. `docs/migration/p3-repository-dto/repository-characterization.md`
18. `docs/migration/p3-repository-dto/repository-protocol-draft.md`

작업 시작 전에 원본 P3 여섯 source/fixture/test 문서가 존재하고 원본 P3 결과와 같은
기준인지 확인한다. 기준이 다르거나 원본 P3가 적용되지 않았다면 임의로 합치지 말고
`BLOCKED`로 보고한다.

현재 working tree에 원본 P3 변경이 아직 uncommitted여도 원본 전체를 후속 patch에 다시
포함하지 않는다. 필요하면 원본 P3 여섯 파일만 별도의 로컬 baseline commit 또는 index
baseline으로 고정한 뒤 후속 변경분만 추출한다. 관련 없는 변경을 stage/commit하지 않는다.

## 목표

마스터 검증에서 발견된 DTO 우회 경로와 fixture 누락을 보완해 P3 완료 조건을 충족한다.

1. `StudentGoalRecord`가 잘못된 타입과 범위를 거부한다.
2. `RepositoryCommitCommand`가 target별 confirmed DTO만 수락하고 데이터 버킷 유입을 막는다.
3. 손상·누락·unknown-version 및 다섯 데이터 버킷 대표 사례를 parity fixture로 고정한다.
4. 다섯 데이터 버킷의 필드 소유권을 문서와 test에 명시한다.
5. legacy inventory name key와 item-ID key 정규화 계약의 모호성을 제거한다.

## 필수 보완 사항

### 1. StudentGoalRecord 엄격 검증

`StudentGoalRecord`의 모든 생성·역직렬화 경로에서 다음을 보장한다.

- `student_id`: 비어 있지 않은 문자열
- `favorite`: bool만 허용하며 문자열이나 정수 대체값을 허용하지 않음
- `notes`: 문자열만 허용
- 모든 `target_*`: `None` 또는 bool이 아닌 정수
- 각 target 범위는 `planning.py`의 기존 `MAX_TARGET_*` 상수를 단일 기준으로 사용
- 범위 밖 값을 clamp하거나 조용히 `None`으로 바꾸지 않고 `RepositoryDTOError`로 거부
- unknown field, 누락 `student_id`, 잘못된 version을 명시적으로 거부
- direct construction 뒤 `to_dict()`가 잘못된 wire payload를 방출할 수 없도록 생성 시점
  또는 직렬화 시점 검증을 일관되게 적용

기존 `StudentGoal` 의미와 빈 목표 `None` 의미는 바꾸지 않는다.

필수 부정 test에는 최소한 다음을 포함한다.

- `favorite: "yes"`
- `target_level: "bad"`
- `target_level: true`
- 각 대표 target의 음수 및 최대값 초과
- `notes: 7`
- 빈 `student_id`

### 2. RepositoryCommitCommand target별 payload 검증

`confirmed_payload`를 임의 dict로 수락하지 않는다.

- `target_kind == "student"`이면 `ConfirmedStudent` canonical payload만 허용한다.
- `target_kind == "inventory"`이면 `InventorySnapshot` canonical payload만 허용한다.
- target kind와 payload DTO가 다르면 거부한다.
- `metadata`, `goals`, `plan`, `costs`, `total_cost`, `required_materials`, `shortage`,
  `shortages`가 commit 경계를 통해 유입되지 않게 한다.
- top-level 이름 검사만으로 끝내지 말고 target DTO를 실제로 역직렬화해 unknown field,
  누락 필드와 잘못된 타입을 검증한다.
- `to_dict()`는 target DTO의 canonical 표현을 반환한다.
- inventory commit의 `profile_ids`, student commit의 replace 의미가 모호하지 않게 test와
  protocol draft에 기록한다.

다음 마스터 재현 입력이 모두 `RepositoryDTOError`가 돼야 한다.

```python
StudentGoalRecord.from_dict({
    "version": 1,
    "goal": {
        "student_id": "s1",
        "favorite": "yes",
        "target_level": "bad",
        "notes": 7,
    },
})

RepositoryCommitCommand.from_dict({
    "version": 1,
    "command_id": "cmd",
    "candidate_id": "cand",
    "target_kind": "student",
    "confirmed_payload": {
        "shortages": {"credit": 1},
        "costs": {"credit": 2},
    },
    "replace": False,
    "profile_ids": [],
})
```

### 3. 필수 fixture 사례 추가

`contracts/fixtures/repository_v6_parity.json`에 명시적인 ID와 기대 결과/오류를 가진
사례를 추가하고 `test_all_fixture_cases`가 모두 재생하게 한다.

최소한 다음 의미를 각각 fixture로 고정한다.

- 누락 필수 field 거부
- unknown DTO version 거부
- unknown field 거부
- 잘못된 goal 타입/범위 거부
- commit payload의 bucket leak 거부
- target kind와 confirmed payload 불일치 거부
- 다섯 데이터 버킷 대표 mapping/round-trip
- 손상된 object/array/type 입력 정책

오류 fixture는 단순히 “예외가 발생함”만 확인하지 말고 DTO 종류와 안정적인 오류 분류
또는 핵심 메시지를 확인한다. 전체 오류 문자열에 과도하게 결합하지 않는다.

원본 fixture case 14개는 삭제하거나 의미를 약화하지 않는다.

### 4. 다섯 데이터 버킷 field mapping

`repository-characterization.md`에 명시적인 표를 추가한다. 표에는 최소한 다음 열을 둔다.

| 버킷 | 소유 type/module | 대표 field 또는 field group | 원본/파생 | P3/P4 저장 여부 | 금지된 유입 경계 |

다음 버킷을 모두 포함한다.

1. 확정된 현재 학생/인벤토리 상태
2. `StudentMeta` 정적 메타데이터
3. `StudentGoal` 사용자 목표
4. `PlanCostSummary` 보유량 차감 전 총 필요량
5. 인벤토리 기반 파생 부족량

같은 mapping을 test에서 기계적으로 확인한다. 동일한 의미의 DTO를 새로 만들지 말고
`dataclasses.fields`, `StudentMeta.__annotations__`, 기존 field 상수 등 코드의 단일 기준을
재사용한다. 부족량은 아직 저장 DTO를 만들지 않고 파생값이며 current/goal/commit에
저장할 수 없다는 계약을 검증한다.

### 5. legacy inventory key 계약 명확화

원본 `inventory-id-unifies-name` case는 이름과 달리 name-only entry와 item-ID entry를
두 항목으로 유지한다. 다음과 같이 계약을 명확히 한다.

- legacy map key가 display name이어도 entry 내부에 `item_id`가 있으면 item ID로
  canonicalize되는 사례를 fixture에 추가한다.
- entry에 `item_id`가 전혀 없는 name-only 데이터는 profile/catalog 근거 없이 같은
  display name의 ID entry로 추측 병합하지 않는다.
- name-only 제한을 보존한다면 기존 case ID를 실제 의미에 맞게 변경하고 문서에 제한과
  P4 migration/catalog 연결 필요성을 기록한다.
- 이름만 같다는 이유로 서로 다른 item을 손실 병합하지 않는다.

## 테스트 및 코드 품질

- 모든 새 부정 test는 보완 전 코드에서 실제로 실패하고 보완 후 통과해야 한다.
- fixture case ID가 subtest 실패 메시지에 나타나야 한다.
- Python 3.11 표준 라이브러리만 사용한다.
- `../v6`, scanner, GUI, DB, filesystem runtime import를 추가하지 않는다.
- 실제 profile/DB/local 상태를 읽거나 쓰지 않는다.
- P0 planning protocol, Flutter와 P2 UI를 변경하지 않는다.
- 원본 P3 범위를 넘어 P4 persistence 또는 P5 scanner session을 구현하지 않는다.

## 필수 검증

저장소 루트에서 다음을 실행한다.

```powershell
cd backend
py -3.11 -m unittest tests.test_repository_parity -v
py -3.11 -m unittest discover -s tests -v

cd ..\frontend
flutter analyze
flutter test
flutter build windows --release

cd ..
codealmanac validate
git diff --check
```

추가로 위 두 마스터 재현 입력을 독립 실행해 모두 `RepositoryDTOError`인지 기록한다.
금지된 v6/scanner/GUI runtime import와 생성/local 파일 유입을 `rg`, `git status`로
검사한다. 실행하지 못한 검증은 통과로 쓰지 않고 `NOT_VERIFIED`와 이유를 기록한다.

## 완료 조건

다음이 모두 충족돼야 `COMPLETED`로 보고한다.

- goal과 commit DTO의 알려진 우회 입력이 모두 거부된다.
- target별 confirmed payload가 canonical round-trip한다.
- 원본 14 case와 새 오류·mapping fixture가 모두 재생된다.
- 다섯 데이터 버킷 field mapping이 문서와 test에 고정된다.
- legacy inventory key 동작과 제한이 fixture 이름·기대값·문서에서 일치한다.
- v6/scanner/GUI runtime import, 실제 persistence, Flutter/wire 변경이 없다.
- 전체 Python/Flutter/Almanac/release/diff 검증이 통과한다.
- 아래 증분 patch와 검증 기록이 인계 계약대로 준비됐다.

## 증분 patch 요구사항

마스터에는 원본 P3 patch가 이미 적용돼 있다. 따라서 결과 patch는 반드시 그 상태 위에
적용 가능한 증분이어야 한다.

예상 변경 범위:

- `backend/core/repository_dto.py`
- `backend/tests/test_repository_parity.py`
- `contracts/fixtures/repository_v6_parity.json`
- `docs/migration/p3-repository-dto/repository-characterization.md`
- 필요 시 `docs/migration/p3-repository-dto/repository-protocol-draft.md`
- 정말 필요한 경우에만 `backend/core/repository_merge.py`

원본 P3 파일을 `new file mode`로 다시 추가하는 combined patch는 허용하지 않는다. 후속
patch의 각 대상은 기존 파일 수정으로 나타나야 하며, 마스터의 원본 P3 적용 상태에서
`git apply --check`가 성공해야 한다.

## 결과물 및 인계 계약

```text
docs/migration/p3-repository-dto-followup-1/
├─ input.md                                  # 이 파일: 수정·삭제·덮어쓰기 금지
├─ output.md                                 # 모든 결과물이 준비된 뒤 마지막에 작성
└─ artifacts/
   ├─ p3-repository-dto-followup-1.patch
   └─ verification.txt
```

- 결과물 표에는 실제로 `artifacts/` 아래 존재하는 전달 파일만 기록한다.
- source 파일은 수행 내용과 변경 목록에 기록하되 별도 artifact인 것처럼 크기/해시 표에
  넣지 않는다.
- patch에는 이 follow-up `input.md`, `output.md`, `artifacts/`, 원본 P3 전체 patch,
  생성/local 파일과 관련 없는 변경을 포함하지 않는다.
- `verification.txt`에는 명령, 종료 코드, 핵심 결과, 전체 fixture/test 개수와 마스터
  재현 입력 결과를 기록한다.
- 두 artifact의 존재, 0보다 큰 크기, 바이트 크기와 SHA-256을 확인한다.
- `output.md`는 `almanac/workflows/slave-artifact-handoff.md` 형식을 그대로 따른다.

## cross-PC 전달

원본 P3와 혼동하지 않도록 새 Task ID를 사용한다.

패키지만 수동 생성할 때:

```powershell
cd "<SLAVE_REPOSITORY_ROOT>"
.\tools\new_cross_pc_handoff.ps1 `
  -TaskDirectory ".\docs\migration\p3-repository-dto-followup-1" `
  -DestinationDirectory "<SLAVE_OUTBOX_OR_MOUNTED_MASTER_INBOX>" `
  -TaskId "ba-planner-v7-p3-repository-dto-followup-1"
```

같은 신뢰 가능한 사설 Wi-Fi/LAN에서 기존 sender를 사용할 때:

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p3-repository-dto-followup-1" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p3-repository-dto-followup-1"
```

Task ID와 TaskDirectory 인자를 생략하지 않는다. 현재 sender 기본값은 P2다. 마스터의
`WIRELESS_HANDOFF_RECEIVED` 확인 전에는 무선 전달 완료로 보고하지 않는다.

완료 보고:

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p3-repository-dto-followup-1
status: COMPLETED
output_md: <슬레이브 PC의 output.md 절대경로>
artifacts_dir: <슬레이브 PC의 artifacts 절대경로>
artifact_count: 2
handoff_package: <ZIP 절대경로>
handoff_package_size: <바이트>
handoff_package_sha256: <SHA-256>
master_prompt: <-MASTER_PROMPT.md 절대경로>
wireless_transfer: `RECEIVED`, `NOT_REQUESTED` 또는 `FAILED`
```

완료할 수 없으면 `TASK_OUTPUT_BLOCKED`로 보고하고 구체적인 이유를 기록한다. 마스터가
새 package, 내부 artifact, 증분 diff와 전체 검증을 직접 확인하기 전에는 P3 완료로
간주하지 않는다.
