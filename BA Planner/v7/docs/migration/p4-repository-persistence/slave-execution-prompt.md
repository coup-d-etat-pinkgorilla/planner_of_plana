# 슬레이브 실행 프롬프트

BA Planner v7의 P4 repository와 프로필 영구 저장을 구현하고, 다른 PC의 마스터가
검증·인수할 수 있는 cross-PC 패키지까지 생성하십시오.

작업을 시작하기 전에 슬레이브 PC 저장소에 다음 파일이 존재하는지 확인하십시오.

- `docs/migration/p4-repository-persistence/input.md`
- `docs/migration/p4-repository-persistence/slave-execution-prompt.md`
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `tools/new_cross_pc_handoff.ps1`
- `tools/send_cross_pc_handoff.ps1`
- `tools/Send-SlaveResult.ps1`
- `tools/Install-SlaveResultSender.ps1`

하나라도 없으면 임의로 대체하지 말고 `TASK_OUTPUT_BLOCKED`로 보고해 사용자에게 해당
파일들의 전달을 요청하십시오.

모두 존재하면 `docs/migration/p4-repository-persistence/input.md`를 처음부터 끝까지 읽고
가장 먼저 “P3 승인 baseline” gate를 실행하십시오. fixture 26 cases, repository parity
10 tests, 전체 Python 27 tests, confirmed-current/metadata field 교집합 `set()`과
`display_name` 거부 조건 중 하나라도 다르면 P4 구현을 시작하지 말고 실제 차이를 기록한
`TASK_OUTPUT_BLOCKED`로 반환하십시오. P3 코드를 고쳐 baseline을 억지로 맞추지 마십시오.

gate가 모두 통과하면 `input.md`의 요구사항, 제한사항, 테스트와 완료 조건에 따라 P4를
구현하십시오. 작업 결과는 같은 디렉터리의 `output.md`와 `artifacts/`에 저장하십시오.
패치는 P3 승인 baseline에 적용되는 P4 단일 증분이어야 하며 신규 파일을 모두 포함해
마스터가 재현할 수 있어야 합니다. 실제 사용자 profile/DB를 test에 사용하지 말고,
검증하지 않은 항목을 성공으로 보고하지 마십시오. 슬레이브가 상태 문서의 P4를 `완료`로
바꾸어서는 안 됩니다.

슬레이브 PC에서 송신 래퍼를 아직 설치하지 않았다면 저장소 루트에서 최초 한 번 다음을
실행하십시오.

```powershell
.\tools\Install-SlaveResultSender.ps1
```

`output.md`와 두 artifact가 완성된 뒤 다음 명령으로 외부 전달 패키지를 바탕 화면의
outbox에 생성하십시오.

```powershell
$repoRoot = git rev-parse --show-toplevel
$slaveOutbox = Join-Path ([Environment]::GetFolderPath('Desktop')) 'BA-Planner-Handoff-Outbox'

Set-Location $repoRoot
.\tools\new_cross_pc_handoff.ps1 `
  -TaskDirectory ".\docs\migration\p4-repository-persistence" `
  -DestinationDirectory $slaveOutbox `
  -TaskId "ba-planner-v7-p4-repository-persistence"
```

ZIP, `.sha256`, `.manifest.json`, `-MASTER_PROMPT.md` 네 파일이 모두 존재하고 0바이트가
아닌지 확인하십시오. 네 파일을 대화에 첨부할 수 있으면 모두 첨부하고, 그렇지 않으면
사용자가 복사할 수 있도록 정확한 outbox 절대경로를 보고하십시오.

마스터가 같은 신뢰 가능한 Wi-Fi/LAN에서 수신 래퍼를 시작했다면 다음 명령으로 자동
발견하여 네 파일을 전송하십시오. IP, port 또는 token을 사용자에게 요구하지 마십시오.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "$repoRoot" `
  -TaskId "ba-planner-v7-p4-repository-persistence" `
  -TaskDirectory "$repoRoot\docs\migration\p4-repository-persistence"
```

token은 화면, 파일, 로그, `output.md` 또는 최종 보고에 기록하지 마십시오. 마스터
수신기가 `WIRELESS_HANDOFF_RECEIVED`를 확인한 경우에만 무선 전송을 완료로 표시하십시오.

최종 보고에는 `input.md`의 `TASK_OUTPUT_READY` 필드와 함께 다음을 반드시 포함하십시오.

```text
CROSS_PC_HANDOFF_READY
task_id: ba-planner-v7-p4-repository-persistence
package: <ZIP 절대경로>
package_size: <바이트>
package_sha256: <SHA-256>
hash_file: <.sha256 절대경로>
manifest: <.manifest.json 절대경로>
master_prompt: <-MASTER_PROMPT.md 절대경로>
transfer_file_count: 4
wireless_transfer: RECEIVED, NOT_REQUESTED 또는 FAILED
```

슬레이브 로컬 소스 경로나 완료 설명만 보고하는 것은 인계 완료가 아닙니다. 네 전달
파일을 사용자가 마스터 PC의 다음 inbox로 옮길 수 있어야 합니다.

```text
C:\Users\brigh\planner_of_plana\BA Planner\v7\docs\migration\handoffs\incoming\ba-planner-v7-p4-repository-persistence\
```

마스터가 같은 ZIP의 해시, 내부 결과물, P3 baseline 유지와 P4 전체 검증을 직접 확인하기
전까지 P4를 최종 완료로 판정하지 마십시오.
