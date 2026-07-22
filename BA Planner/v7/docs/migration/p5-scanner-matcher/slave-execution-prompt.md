# 슬레이브 실행 프롬프트

BA Planner v7의 P5 scanner/matcher session protocol과 backend 이전을 수행하고, 다른 PC의
마스터가 검증·인수할 수 있는 cross-PC 패키지까지 생성하십시오.

작업 ID:

```text
ba-planner-v7-p5-scanner-matcher
```

이 작업은 P4 repository를 다시 설계하거나 P6 스캔 화면을 만드는 작업이 아닙니다. 승인된
P4 typed repository/process baseline 위에서 scanner candidate 생성, versioned event,
검토·수정·명시적 commit, 실제 student/inventory adapter와 recognition asset 경계만 P5
단일 증분으로 구현합니다.

작업을 시작하기 전에 다음 파일이 존재하는지 확인하고 처음부터 끝까지 읽으십시오.

- `docs/migration/p5-scanner-matcher/input.md`
- `docs/migration/p5-scanner-matcher/slave-execution-prompt.md`
- `almanac/workflows/p0-p6-workflow-status.md`
- `almanac/workflows/p0-p6-workflow.md`의 P4·P5 절
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `docs/migration/v6-knowledge-baseline.md`
- `docs/migration/p4-repository-persistence/repository-storage.md`
- `tools/new_cross_pc_handoff.ps1`
- `tools/send_cross_pc_handoff.ps1`
- `tools/Send-SlaveResult.ps1`
- `tools/Install-SlaveResultSender.ps1`

하나라도 없으면 임의로 대체하지 말고 `TASK_OUTPUT_BLOCKED`로 보고해 사용자에게 파일 전달을
요청하십시오. 상세 요구사항, 제한, 테스트와 완료 조건은 P5 `input.md`를 단일 기준으로
사용하십시오.

가장 먼저 `input.md`의 P4 승인 baseline gate를 실행하십시오. repository fixture 40
cases(valid 14/invalid 26), P3/P4 집중 Python 23, 전체 Python 40, Flutter 43,
`flutter analyze`, 실제 Dart-launched Python process restart E2E, Windows release,
Almanac와 diff gate 중 하나라도 다르면 P4 코드를 억지로 고쳐 맞추거나 선행 patch를
재구성하지 마십시오. 실제 차이를 기록하고 안전하게 계속할 수 없으면 `BLOCKED`로
반환하십시오.

gate가 통과하면 다음 순서를 지키십시오.

1. v6 student/inventory scanner 호출자, callback, 취소, confidence, repository 저장, ROI와
   recognition asset을 조사해 `scanner-characterization.md` 작성
2. Python·Dart가 공유하는 scanner request/response/event schema와 fixture 확정
3. generation·sequence·정확히 하나의 terminal을 소유하는 headless session service 구현
4. student/inventory candidate, field별 confidence와 review-required 경계 구현
5. review·수정과 P4 expected revision/idempotency를 사용하는 명시적 commit 분리
6. 실제 Windows student/inventory capture/matcher adapter를 작은 port/adapter로 이전
7. recognition template/region을 UI asset과 분리하고 manifest/hash/release path 검증
8. Python JSONL response/event multiplex와 Dart typed event client/service 구현
9. 취소, stale/duplicate/out-of-order, 낮은 confidence, commit 보존과 restart/dispose를
   headless 및 실제 Dart↔Python E2E로 검증

낮은 confidence candidate 자동 저장, scanner의 repository 파일 직접 접근, stdout/stderr
문자열 파싱, generation/sequence 없는 callback, v6/Qt runtime import, student 또는 inventory
fake/placeholder 잔존, test skip과 P6 production UI 구현은 금지합니다.

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
codealmanac health
git diff --check
```

P5 scanner fixture와 Python/Dart contract test, headless student/inventory session E2E, 실제
image matcher 회귀, 실제 Dart↔Python event E2E를 각각 단독 실행하십시오. 명령, exit code,
fixture/event/asset 수, cancel latency, stale event 차단, 낮은 confidence commit 거부 전후
repository hash/revision과 cleanup 결과를 `verification.txt`에 기록하십시오. 실제 게임 창
smoke를 실행하지 못했다면 통과로 쓰지 말고 `NOT_VERIFIED`로 기록하십시오.

결과물:

```text
docs/migration/p5-scanner-matcher/
├─ output.md
└─ artifacts/
   ├─ p5-scanner-matcher.patch
   └─ verification.txt
```

patch는 승인된 P4 baseline 위의 단일 P5 증분이어야 합니다. 모든 경로는
`BA Planner/v7/...`여야 하며 input, prompt, output, artifacts, 이전 patch, build/cache/local
파일, debug crop과 사용자 adaptive sample을 포함하지 마십시오. `git apply --check --verbose`
에서 모든 path가 Checking되고 skipped 0인지 확인하십시오. 슬레이브가 workflow status의
P5를 `완료`로 바꾸어서는 안 됩니다.

송신 wrapper가 없으면 저장소 루트에서 최초 한 번 설치하십시오.

```powershell
.\tools\Install-SlaveResultSender.ps1
```

결과가 모두 준비된 뒤 전송하십시오.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p5-scanner-matcher" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p5-scanner-matcher"
```

IP, port 또는 token을 사용자에게 요구하거나 token을 화면, 파일, 로그, `output.md`에
기록하지 마십시오. 마스터 수신기가 `WIRELESS_HANDOFF_RECEIVED`를 확인한 경우에만 무선
전송을 완료로 표시하십시오.

최종 보고에는 `TASK_OUTPUT_READY`와 함께 다음을 포함하십시오.

```text
CROSS_PC_HANDOFF_READY
task_id: ba-planner-v7-p5-scanner-matcher
package: <ZIP 절대경로>
package_size: <바이트>
package_sha256: <SHA-256>
hash_file: <.sha256 절대경로>
manifest: <.manifest.json 절대경로>
master_prompt: <-MASTER_PROMPT.md 절대경로>
transfer_file_count: 4
wireless_transfer: RECEIVED, NOT_REQUESTED 또는 FAILED
```

필수 자동 검증 하나라도 실패하거나 실제 student/inventory adapter 중 하나가
fake/placeholder로 남으면 `COMPLETED`로 보고하지 마십시오. 마스터가 ZIP, artifact, patch,
P4 baseline 유지와 P5 전체 완료 조건을 직접 검증하기 전에는 P5를 완료로 판정하지 마십시오.
