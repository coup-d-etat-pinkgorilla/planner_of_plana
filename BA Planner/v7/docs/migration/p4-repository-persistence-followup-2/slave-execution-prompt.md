# 슬레이브 실행 프롬프트

BA Planner v7 P4 repository persistence follow-up-2를 수행하고 cross-PC 인계 패키지를
생성하십시오.

작업 ID:

```text
ba-planner-v7-p4-repository-persistence-followup-2
```

이 작업은 P2가 아닙니다. 원본 P4와 follow-up-1이 적용된 baseline 위에서 남은 repository
contract, Dart typed state와 실제 process E2E만 완성하는 마지막 P4 증분입니다.

작업 전 다음 파일을 확인하십시오.

- `docs/migration/p4-repository-persistence-followup-2/input.md`
- `docs/migration/p4-repository-persistence-followup-2/slave-execution-prompt.md`
- `docs/migration/p4-repository-persistence-followup-1/input.md`
- `docs/migration/p4-repository-persistence/repository-storage.md`
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `tools/Send-SlaveResult.ps1`

원본 P4+follow-up-1 source가 없거나 파일이 누락되면 임의 재구성하지 말고 `BLOCKED`로
보고하십시오. 모두 있으면 상세 `input.md`를 처음부터 끝까지 읽고 baseline gate부터
실행하십시오.

반드시 완료할 항목:

1. 모든 repository method의 strict success response schema
2. 기존 16 cases를 보존한 valid/invalid fixture 확장
3. Dart가 모든 fixture의 `valid` 기대값을 실제 판정
4. runtime client의 method별 malformed-success 거부
5. typed repository state와 PlanningPage의 raw map cast 제거
6. temporary `BA_PLANNER_STORAGE_ROOT`를 사용한 실제 Dart `ProcessAppService` ↔ Python
   child process 저장·종료·재시작·복원 E2E

`flutter`, `py -3.11`, `codealmanac` 중 하나라도 실행할 수 없으면 `COMPLETED`로 보고하지
마십시오. fake process만으로 실제 process E2E를 대체하거나, schema/test 기대값을
약화하거나, 이미 승인된 lifecycle/corruption 코드를 다시 설계하지 마십시오.

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

작업 결과는 다음 두 artifact로만 인계하십시오.

```text
docs/migration/p4-repository-persistence-followup-2/artifacts/
├─ p4-repository-persistence-followup-2.patch
└─ verification.txt
```

patch는 follow-up-1 baseline 위 증분이며 모든 diff path가 `BA Planner/v7/...`를 사용해야
합니다. input, prompt, output, artifacts와 이전 patch를 patch에 포함하지 마십시오.
`git apply --check --verbose`에서 `Skipped patch`가 0인지 기록하십시오.

완료 후 전송:

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-2" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-2"
```

최종 보고:

```text
CROSS_PC_HANDOFF_READY
task_id: ba-planner-v7-p4-repository-persistence-followup-2
package: <ZIP 절대경로>
package_size: <바이트>
package_sha256: <SHA-256>
hash_file: <.sha256 절대경로>
manifest: <.manifest.json 절대경로>
master_prompt: <-MASTER_PROMPT.md 절대경로>
transfer_file_count: 4
wireless_transfer: RECEIVED, NOT_REQUESTED 또는 FAILED
```

마스터가 같은 package를 직접 검증하기 전에는 P4를 완료로 판정하지 마십시오.
