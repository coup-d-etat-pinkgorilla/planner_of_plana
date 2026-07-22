# 슬레이브 실행 프롬프트

BA Planner v7 P4 repository persistence follow-up-3를 수행하고 cross-PC 인계 패키지를
생성하십시오.

작업 ID:

```text
ba-planner-v7-p4-repository-persistence-followup-3
```

이 작업은 P2가 아닙니다. 원본 P4와 follow-up-1·2가 적용된 baseline 위에서 nested
contract, Dart runtime/typed state와 실제 process restart E2E를 완성하는 마지막 P4
증분입니다.

다음 파일을 확인하십시오.

- `docs/migration/p4-repository-persistence-followup-3/input.md`
- `docs/migration/p4-repository-persistence-followup-3/slave-execution-prompt.md`
- P4 원본 및 follow-up-1·2 `input.md`
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `tools/Send-SlaveResult.ps1`

선행 source나 문서가 없으면 임의 재구성하지 말고 `BLOCKED`로 보고하십시오. 모두 있으면
상세 `input.md`를 처음부터 끝까지 읽고 baseline gate부터 실행하십시오.

반드시 완료할 항목:

1. ConfirmedStudent/Inventory/Goal nested schema를 Python DTO와 일치
2. 기존 28 cases 보존 및 metadata·shortage·goal999·junk·empty nested invalid fixture 추가
3. Dart가 모든 fixture의 `valid` 값을 실제 판정
4. Runtime client의 repository wildcard success 제거와 malformed-success fatal 처리
5. Immutable typed `RepositoryState` 및 PlanningPage raw map cast 제거
6. Temporary `BA_PLANNER_STORAGE_ROOT`에서 실제 Dart `ProcessAppService` ↔ Python child
   process 저장·종료·재시작·복원 E2E

`flutter`, `py -3.11`, `codealmanac` 중 하나라도 사용할 수 없거나 real process E2E를
실행할 수 없으면 `COMPLETED`로 보고하지 마십시오. Fake process만으로 E2E를 대체하거나
test/schema 기대값을 약화하지 마십시오.

필수 검증:

```powershell
cd backend
py -3.11 -m unittest tests.test_repository_parity tests.test_repository_persistence tests.test_repository_protocol_contract -v
py -3.11 -m unittest discover -s tests -v

cd ..\frontend
flutter analyze
flutter test
flutter build windows --release

cd ..
codealmanac validate
git diff --check
```

작업 결과:

```text
docs/migration/p4-repository-persistence-followup-3/artifacts/
├─ p4-repository-persistence-followup-3.patch
└─ verification.txt
```

patch는 follow-up-2 baseline 위 증분이고 모든 경로가 `BA Planner/v7/...`여야 합니다.
input, prompt, output, artifacts와 이전 patch를 포함하지 마십시오. apply-check에서 skip 0을
확인하십시오.

전송:

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-3" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-3"
```

최종 보고:

```text
CROSS_PC_HANDOFF_READY
task_id: ba-planner-v7-p4-repository-persistence-followup-3
package: <ZIP 절대경로>
package_size: <바이트>
package_sha256: <SHA-256>
hash_file: <.sha256 절대경로>
manifest: <.manifest.json 절대경로>
master_prompt: <-MASTER_PROMPT.md 절대경로>
transfer_file_count: 4
wireless_transfer: RECEIVED, NOT_REQUESTED 또는 FAILED
```

마스터가 검증하기 전에는 P4를 완료로 판정하지 마십시오.
