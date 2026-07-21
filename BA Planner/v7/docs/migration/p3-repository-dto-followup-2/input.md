# P3 후속 작업 지시 2 — current/metadata 비중첩 완결

## 작업 정보

- 작업 ID: `ba-planner-v7-p3-repository-dto-followup-2`
- 저장소: 슬레이브 PC의 BA Planner v7 저장소 루트
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p3-repository-dto-followup-2`
- 기준 상태: 원본 P3와 `followup-1`이 모두 적용된 상태
- 실행 환경: 슬레이브와 마스터는 서로 다른 PC이며 파일시스템을 공유하지 않음

## 배경

마스터는 원본 P3와 followup-1 패키지의 무결성, 증분 patch, 전체 Python/Flutter test,
Windows release, Almanac, 실제 backend 및 Mock 흐름을 검증했다. followup-1은 goal 검증,
target별 commit DTO, 오류 fixture, 다섯 bucket 문서와 legacy inventory key 계약을
보완했다.

그러나 최종 field-set 대조에서 다음 잔여 위반이 확인됐다.

```text
set(repository_dto.STUDENT_VALUE_FIELDS)
  & set(StudentMeta.__annotations__)
== {"display_name"}
```

현재 `ConfirmedStudent.from_dict()`는 다음 payload를 수락하며, 같은 payload가 student
`RepositoryCommitCommand`에도 들어갈 수 있다.

```python
{
    "version": 1,
    "student_id": "s1",
    "values": {"display_name": "Static metadata copied into current"},
}
```

이는 “현재 상태 DTO에 정적 메타데이터를 저장하지 않는다”는 P3 핵심 불변식과
followup-1의 field mapping 문서에 어긋난다. 현재 bucket mapping test는 대표 field의
부분집합 여부만 검사하고 집합 간 비중첩을 확인하지 않아 이 문제를 놓친다.

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
9. `docs/migration/p3-repository-dto-followup-1/input.md`
10. 원본 P3와 followup-1의 `output.md`, patch와 검증 기록
11. `backend/core/repository_dto.py`
12. `backend/core/repository_merge.py`
13. `backend/core/student_meta_types.py`
14. `backend/tests/test_repository_parity.py`
15. `contracts/fixtures/repository_v6_parity.json`
16. `docs/migration/p3-repository-dto/repository-characterization.md`

원본 P3와 followup-1이 모두 적용된 exact baseline이 아니면 임의로 합치지 말고
`BLOCKED`로 보고한다. 최종 patch는 이 baseline 위에 적용되는 증분이어야 한다.

## 목표

v6 병합 parity와 v7 confirmed-current 계약을 분리해 `display_name`이 v7 현재 상태나
repository commit으로 유입되지 않게 하고, 다섯 데이터 버킷의 비중첩을 자동 테스트로
고정한다.

## 필수 구현

### 1. v6 merge field와 v7 current DTO field 분리

- `backend/core/repository_merge.py`의 `STUDENT_FIELDS`는 v6 merge parity에 필요한 legacy
  필드 집합이므로 `display_name`을 유지할 수 있다.
- `backend/core/repository_dto.py`의 confirmed-current 허용 필드는 정적 metadata와
  분리한다.
- `ConfirmedStudent.values`에서 `display_name`을 제거하고 unknown/bucket boundary 오류로
  거부한다.
- 문자열 필드 검증 집합에서도 current DTO에 더 이상 허용되지 않는 `display_name`을
  제거한다.
- 이름이 모호하다면 public constant를 `CONFIRMED_STUDENT_VALUE_FIELDS`처럼 책임이
  드러나는 이름으로 분리한다. 기존 `STUDENT_VALUE_FIELDS`를 유지해야 한다면 그 값과
  문서가 v7 confirmed-current만 의미하도록 한다.
- `display_name`은 `student_meta` lookup/API에서 얻는 정적 metadata이며 current snapshot에
  복제하지 않는다는 결정을 코드와 문서에 일치시킨다.

v6 merge fixture가 `display_name`을 병합하는 동작은 characterization 목적으로 유지할 수
있지만, 그 결과를 v7 `ConfirmedStudent`로 저장할 때는 metadata field가 제외돼야 한다.
병합 parity와 저장 DTO를 같은 field constant로 다시 합치지 않는다.

### 2. ConfirmedStudent와 commit 거부 fixture

`contracts/fixtures/repository_v6_parity.json`에 최소 다음 두 case를 명시적 ID로 추가한다.

1. `ConfirmedStudent.values.display_name` 거부
2. student `RepositoryCommitCommand.confirmed_payload.values.display_name` 거부

fixture replay test가 두 case 모두 `RepositoryDTOError`와 안정적인 핵심 오류 분류를
확인해야 한다. 기존 24 case는 삭제하거나 의미를 약화하지 않는다.

### 3. 실제 비중첩 invariant test

bucket mapping test가 merge parity field가 아니라 v7 DTO 허용 field를 사용하도록 고친다.

최소 다음을 직접 assert한다.

```python
confirmed_current_fields = set(<v7 ConfirmedStudent 허용 field constant>)
metadata_fields = set(StudentMeta.__annotations__)
self.assertTrue(confirmed_current_fields.isdisjoint(metadata_fields))
```

추가로 다음을 검증한다.

- `display_name`은 metadata field에는 존재함
- `display_name`은 confirmed-current field에는 존재하지 않음
- 대표 current field인 `level`은 confirmed-current에 계속 존재함
- valid `ConfirmedStudent`와 student commit round-trip은 계속 통과함
- `repository_merge.STUDENT_FIELDS`의 v6 parity 목적과 DTO field set이 의도적으로 다름

현재 test의 다음 패턴은 충분하지 않다.

```python
self.assertTrue(set(expected["current"]) <= current_fields)
self.assertTrue(set(expected["metadata"]) <= meta_fields)
```

부분집합 확인은 유지할 수 있지만 반드시 비중첩 assertion을 추가한다.

### 4. 문서 정합성

`repository-characterization.md`의 다섯 bucket mapping과 P3 경계에 다음을 명시한다.

- `display_name`의 owner는 `StudentMeta`
- v6 repository/merge에 남아 있는 `display_name`은 legacy parity 특성화 대상
- v7 `ConfirmedStudent`와 repository commit에는 저장하지 않음
- UI에서 current와 display metadata를 함께 보여도 view 조합일 뿐 저장 bucket을 합치지 않음

별도 protocol 변경은 필요하지 않다. `repository-protocol-draft.md` 수정이 정말 필요할
때만 최소 범위로 변경한다.

## 마스터 재현 조건

보완 후 다음 검사가 모두 통과해야 한다.

```python
from core.repository_dto import (
    ConfirmedStudent,
    RepositoryCommitCommand,
    RepositoryDTOError,
)
from core.student_meta_types import StudentMeta

current_fields = set(<v7 ConfirmedStudent 허용 field constant>)
assert current_fields.isdisjoint(StudentMeta.__annotations__)

try:
    ConfirmedStudent.from_dict({
        "version": 1,
        "student_id": "s1",
        "values": {"display_name": "must not persist"},
    })
except RepositoryDTOError:
    pass
else:
    raise AssertionError("display_name entered ConfirmedStudent")

try:
    RepositoryCommitCommand.from_dict({
        "version": 1,
        "command_id": "cmd",
        "candidate_id": "cand",
        "target_kind": "student",
        "confirmed_payload": {
            "version": 1,
            "student_id": "s1",
            "values": {"display_name": "must not persist"},
        },
        "replace": False,
        "profile_ids": [],
    })
except RepositoryDTOError:
    pass
else:
    raise AssertionError("display_name entered student commit")
```

`<v7 ConfirmedStudent 허용 field constant>`는 구현에서 선택한 실제 constant로 교체한다.

## 금지 및 제외 범위

- v6 merge parity 동작을 이유 없이 변경하지 않는다.
- `display_name`을 current에서 제거하는 대신 별도 복제 metadata field를 만들지 않는다.
- `StudentMeta` 생성 데이터나 `backend/core/student_meta_data.py`를 수정하지 않는다.
- P4 persistence, migration, profile catalog 연결을 구현하지 않는다.
- scanner/session/event, Flutter, AppService와 planning wire를 변경하지 않는다.
- 원본 P3 또는 followup-1 전체 patch를 다시 포함하지 않는다.
- 관련 없는 리팩터링, formatting, 생성/local 파일을 포함하지 않는다.

예상 source 변경 범위는 다음으로 제한한다.

- `backend/core/repository_dto.py`
- `backend/tests/test_repository_parity.py`
- `contracts/fixtures/repository_v6_parity.json`
- `docs/migration/p3-repository-dto/repository-characterization.md`

`backend/core/repository_merge.py`는 v6 parity field 주석 또는 명확화가 정말 필요한 경우에만
수정한다.

## 필수 검증

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

추가로 다음을 기록한다.

- 전체 P3 fixture case 수
- 위 마스터 재현 조건의 성공 결과
- `STUDENT_VALUE_FIELDS` 또는 새 confirmed-current constant와
  `StudentMeta.__annotations__`의 실제 교집합
- 금지된 v6/scanner/GUI runtime import 검색 결과
- patch 대상과 current working tree의 중첩 여부

실행하지 못한 검증은 통과로 쓰지 말고 `NOT_VERIFIED`와 이유를 기록한다.

## 완료 조건

다음이 모두 충족돼야 `COMPLETED`로 보고한다.

- confirmed-current와 static metadata field 교집합이 비어 있다.
- `display_name`이 `ConfirmedStudent`와 student commit에서 거부된다.
- valid current/commit round-trip과 기존 merge parity가 유지된다.
- 기존 24 case와 새 display-name 거부 fixture가 모두 재생된다.
- field mapping 문서와 실제 DTO/test가 일치한다.
- Python/Flutter/release/Almanac/diff 전체 검증이 통과한다.
- P4/P5/Flutter/wire 범위가 추가되지 않았다.
- 아래 증분 patch와 검증 기록이 인계 계약대로 준비됐다.

## 증분 patch 및 인계 계약

```text
docs/migration/p3-repository-dto-followup-2/
├─ input.md                                  # 이 파일: 수정·삭제·덮어쓰기 금지
├─ output.md                                 # 모든 결과물이 준비된 뒤 마지막에 작성
└─ artifacts/
   ├─ p3-repository-dto-followup-2.patch
   └─ verification.txt
```

- patch는 원본 P3와 followup-1이 적용된 baseline 위에 적용 가능한 증분이어야 한다.
- 기존 P3 파일은 `new file mode`가 아니라 기존 파일 수정으로 나타나야 한다.
- followup-2 `input.md`, `output.md`, `artifacts/`, 이전 patch와 관련 없는 변경을 patch에
  포함하지 않는다.
- 결과물 표에는 실제 `artifacts/` 아래 두 파일만 기록한다.
- `verification.txt`에는 명령, 종료 코드, test/fixture 수, field 교집합과 마스터 재현
  결과를 기록한다.
- 모든 artifact의 존재, 0보다 큰 크기, 바이트 크기와 SHA-256을 확인한다.
- `output.md`는 `almanac/workflows/slave-artifact-handoff.md` 계약을 따른다.

## cross-PC 전달

마스터에서 receiver를 먼저 실행한다.

```powershell
& "$HOME\.codex\ba-planner-slave\Receive-SlaveResult.ps1" `
  -TaskId "ba-planner-v7-p3-repository-dto-followup-2"
```

슬레이브에서 결과 준비 후 기존 sender를 사용한다.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p3-repository-dto-followup-2" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p3-repository-dto-followup-2"
```

Task ID와 TaskDirectory를 생략하지 않는다. 현재 wrapper 기본값은 P2다. 마스터의
`WIRELESS_HANDOFF_RECEIVED` 확인 전에는 무선 전달 완료로 보고하지 않는다.

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p3-repository-dto-followup-2
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

완료할 수 없으면 `TASK_OUTPUT_BLOCKED`로 보고한다. 마스터가 package, artifact, 증분 patch,
field 교집합과 전체 검증을 직접 확인하기 전에는 P3를 완료로 간주하지 않는다.
