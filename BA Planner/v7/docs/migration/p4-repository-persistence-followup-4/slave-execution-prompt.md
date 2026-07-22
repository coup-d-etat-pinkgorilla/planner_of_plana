# 슬레이브 실행 프롬프트

BA Planner v7 P4 repository persistence follow-up-4를 수행하고 cross-PC 인계 패키지를
생성하십시오.

작업 ID:

```text
ba-planner-v7-p4-repository-persistence-followup-4
```

이 작업은 P2가 아닙니다. 원본 P4와 follow-up-1·2·3이 적용된 baseline 위에서 남은 P4
완료 gate만 해결하는 최소 증분입니다.

먼저 다음 파일을 처음부터 끝까지 읽으십시오.

- `docs/migration/p4-repository-persistence-followup-4/input.md`
- `almanac/workflows/p0-p6-workflow-status.md`의 P4 절
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- P4 원본 및 follow-up-1·2·3의 `input.md`

선행 source나 follow-up-3 변경이 없으면 임의 재구성하지 말고 `BLOCKED`로 보고하십시오.
상세 조건은 follow-up-4 `input.md`를 단일 기준으로 사용하십시오.

반드시 완료할 항목:

1. `repository_service.dart`의 analyze lint 2건을 block으로 수정
2. test 전용 immutable environment override로
   `BA_PLANNER_STORAGE_ROOT=<TemporaryDirectory>`를 실제 Python process에 전달
3. 실제 Dart `ProcessAppService`가 실제 Python child process 두 개를 순차 실행하는
   profile/goal 저장·종료·재시작·typed 복원 E2E 추가
4. 두 process 종료, timeout/stderr 진단, temporary cleanup과 사용자 storage 미접근 검증
5. `contracts/README.md`와 `repository-storage.md`를 nested strict contract, typed state와
   실제 E2E 결과에 맞게 갱신

Fake process나 Python 단독 subprocess test는 실제 cross-language E2E를 대신하지 못합니다.
test skip, 조건부 pass, lint ignore, analyzer rule 비활성화 또는 fixture/schema 기대값 약화는
금지합니다. follow-up-3에서 통과한 schema·fixture·typed-state 작업을 다시 설계하지 마십시오.

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

실제 E2E test를 별도로 단독 실행하고 두 실제 child process의 시작·종료, 같은 temporary
root에서의 profile ID/revision/goal 복원과 cleanup 증거를 `verification.txt`에 기록하십시오.

결과물:

```text
docs/migration/p4-repository-persistence-followup-4/artifacts/
├─ p4-repository-persistence-followup-4.patch
└─ verification.txt
```

patch는 follow-up-3 적용 baseline 위의 단일 증분이어야 합니다. 모든 경로는
`BA Planner/v7/...`여야 하며 input, prompt, output, artifacts, 이전 patch, build/cache/local
파일을 포함하지 마십시오. `git apply --check --verbose`에서 skipped 0을 확인하십시오.

전송:

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-4" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-4"
```

최종 보고:

```text
CROSS_PC_HANDOFF_READY
task_id: ba-planner-v7-p4-repository-persistence-followup-4
package: <ZIP 절대경로>
package_size: <바이트>
package_sha256: <SHA-256>
hash_file: <.sha256 절대경로>
manifest: <.manifest.json 절대경로>
master_prompt: <-MASTER_PROMPT.md 절대경로>
transfer_file_count: 4
wireless_transfer: RECEIVED, NOT_REQUESTED 또는 FAILED
```

필수 검증 하나라도 실패하거나 실제 Dart↔Python restart E2E가 없으면 `COMPLETED`로
보고하지 마십시오. 마스터가 결과를 직접 검증하기 전에는 P4를 완료로 판정하지 마십시오.
