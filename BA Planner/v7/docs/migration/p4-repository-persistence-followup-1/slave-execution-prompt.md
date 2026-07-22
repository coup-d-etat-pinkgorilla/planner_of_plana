# 슬레이브 실행 프롬프트

BA Planner v7의 P4 repository persistence 보완 작업 1을 수행하고, 다른 PC의 마스터가
검증할 수 있는 cross-PC 인계 패키지를 생성하십시오.

작업 ID는 반드시 다음 값을 사용하십시오.

```text
ba-planner-v7-p4-repository-persistence-followup-1
```

이 작업은 P2가 아니며 원본 P4 전체 재인계도 아닙니다. 원본 P4가 적용된 baseline 위에서
마스터가 확인한 profile UI lifecycle, corruption fail-closed와 repository contract 결함만
수정하는 증분 follow-up입니다.

작업 전에 다음 파일의 존재를 확인하십시오.

- `docs/migration/p4-repository-persistence-followup-1/input.md`
- `docs/migration/p4-repository-persistence-followup-1/slave-execution-prompt.md`
- `docs/migration/p4-repository-persistence/input.md`
- `docs/migration/p4-repository-persistence/repository-storage.md`
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `tools/new_cross_pc_handoff.ps1`
- `tools/Send-SlaveResult.ps1`
- `tools/Install-SlaveResultSender.ps1`

하나라도 없거나 원본 P4 source 21개가 적용되어 있지 않으면 임의로 재구성하지 말고
`TASK_OUTPUT_BLOCKED`로 보고하십시오.

모두 존재하면 `docs/migration/p4-repository-persistence-followup-1/input.md`를 처음부터
끝까지 읽고 승인 baseline gate부터 실행하십시오. 특히 Flutter toolchain이 없으면 이번
작업을 `COMPLETED`로 보고할 수 없습니다. `flutter analyze`, 전체 `flutter test`와 Windows
release build를 실제로 실행할 수 있어야 합니다.

다음 결함을 모두 수정하고 regression test를 추가하십시오.

1. profile dialog의 disposed `TextEditingController` 재사용과 Widget test 실패
2. malformed catalog entry가 raw `KeyError`로 누출되는 문제
3. malformed profile idempotency가 raw `AttributeError`로 누출되는 문제
4. repository success schema가 `{ "nonsense": true }`를 허용하는 문제
5. Dart contract test가 fixture의 `valid` 기대값을 검사하지 않는 문제
6. runtime client가 모든 `repository.*` success payload를 무조건 허용하는 문제

수정 뒤 실제 Python process + `ProcessAppService` persistence flow와 Mock profile/planning
flow를 모두 검증하십시오. test skip, expectation 약화, timer로 lifecycle 오류 숨김,
P3/P5/P6 변경은 금지합니다.

작업 결과는 다음 위치에만 준비하십시오.

```text
docs/migration/p4-repository-persistence-followup-1/
├─ output.md
└─ artifacts/
   ├─ p4-repository-persistence-followup-1.patch
   └─ verification.txt
```

patch는 원본 P4 baseline에 적용되는 증분이어야 하며 모든 diff path가
`BA Planner/v7/...` prefix를 사용해야 합니다. `git apply --check --verbose`에서 0개도
skip되지 않음을 확인하십시오. input, prompt, output, artifacts와 원본 P4 patch를 증분
patch 안에 포함하지 마십시오.

필수 검증은 다음과 같습니다.

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

하나라도 실패하거나 실행할 수 없으면 `COMPLETED`가 아니라 `BLOCKED`입니다.

모든 결과물이 완성되면 다음 명령으로 패키징·전송하십시오.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-1" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-1"
```

IP, port 또는 token을 사용자에게 요구하거나 token을 출력·저장하지 마십시오. 마스터의
`WIRELESS_HANDOFF_RECEIVED` 확인 전에는 무선 전달 완료로 표시하지 마십시오.

최종 보고에는 `input.md`의 `TASK_OUTPUT_READY`와 다음을 함께 포함하십시오.

```text
CROSS_PC_HANDOFF_READY
task_id: ba-planner-v7-p4-repository-persistence-followup-1
package: <ZIP 절대경로>
package_size: <바이트>
package_sha256: <SHA-256>
hash_file: <.sha256 절대경로>
manifest: <.manifest.json 절대경로>
master_prompt: <-MASTER_PROMPT.md 절대경로>
transfer_file_count: 4
wireless_transfer: RECEIVED, NOT_REQUESTED 또는 FAILED
```

마스터가 같은 package와 내부 artifact를 직접 검증하기 전에는 P4를 완료로 판정하지
마십시오.
