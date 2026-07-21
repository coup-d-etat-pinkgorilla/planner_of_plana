# 슬레이브 실행 프롬프트

BA Planner v7의 P2 실제 계획 화면 수직 슬라이스를 구현하고, 다른 PC의 마스터가
검증·인수할 수 있는 cross-PC 패키지까지 생성하십시오.

작업을 시작하기 전에 슬레이브 PC 저장소에 다음 파일이 존재하는지 확인하십시오.

- `docs/migration/p2-planning-screen/input.md`
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `tools/new_cross_pc_handoff.ps1`

하나라도 없으면 임의로 대체하지 말고 `TASK_OUTPUT_BLOCKED`로 보고해 사용자에게 해당
파일들의 전달을 요청하십시오.

모두 존재하면 `docs/migration/p2-planning-screen/input.md`를 처음부터 끝까지 읽고
그 요구사항, 제한사항, 테스트와 완료 조건에 따라 P2를 구현하십시오. 작업 결과는
같은 디렉터리의 `output.md`와 `artifacts/`에 저장하십시오. 패치는 신규 파일을
포함하여 마스터가 재현할 수 있어야 하며, 검증하지 않은 항목을 성공으로 보고하지
마십시오.

`output.md`와 모든 artifacts가 완성된 뒤 다음 명령으로 외부 전달 패키지를
슬레이브 바탕 화면의 outbox에 생성하십시오.

```powershell
$repoRoot = git rev-parse --show-toplevel
$slaveOutbox = Join-Path ([Environment]::GetFolderPath('Desktop')) 'BA-Planner-Handoff-Outbox'

Set-Location $repoRoot
.\tools\new_cross_pc_handoff.ps1 `
  -TaskDirectory ".\docs\migration\p2-planning-screen" `
  -DestinationDirectory $slaveOutbox `
  -TaskId "ba-planner-v7-p2-planning-screen"
```

ZIP, `.sha256`, `.manifest.json`, `-MASTER_PROMPT.md` 네 파일이 모두 존재하고 0바이트가
아닌지 확인하십시오. 네 파일을 대화에 첨부할 수 있으면 모두 첨부하고, 첨부할 수
없으면 사용자가 그대로 복사할 수 있도록 정확한 outbox 절대경로를 보고하십시오.

최종 보고에는 `input.md`의 `TASK_OUTPUT_READY` 필드와 함께 다음을 반드시 포함하십시오.

```text
CROSS_PC_HANDOFF_READY
task_id: ba-planner-v7-p2-planning-screen
package: <ZIP 절대경로>
package_size: <바이트>
package_sha256: <SHA-256>
hash_file: <.sha256 절대경로>
manifest: <.manifest.json 절대경로>
master_prompt: <-MASTER_PROMPT.md 절대경로>
transfer_file_count: 4
```

슬레이브 로컬 소스 경로나 완료 설명만 보고하는 것은 인계 완료가 아닙니다. 네 전달
파일을 사용자가 마스터 PC의 다음 inbox로 옮길 수 있어야 합니다.

```text
C:\Users\brigh\planner_of_plana\BA Planner\v7\docs\migration\handoffs\incoming\ba-planner-v7-p2-planning-screen\
```

마스터가 같은 ZIP의 해시와 내부 결과물을 직접 확인하기 전까지 P2를 최종 완료로
판정하지 마십시오.
