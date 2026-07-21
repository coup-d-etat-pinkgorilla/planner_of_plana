---
title: "Cross-PC Slave Handoff"
summary: "서로 다른 PC의 슬레이브와 마스터 사이에서 결과 ZIP, SHA-256 및 마스터 실행 프롬프트를 전달하는 절차입니다."
topics: [workflow, architecture, migration]
sources:
  - id: slave-artifact-handoff
    type: file
    path: almanac/workflows/slave-artifact-handoff.md
  - id: package-script
    type: file
    path: tools/new_cross_pc_handoff.ps1
  - id: inspect-script
    type: file
    path: tools/inspect_cross_pc_handoff.ps1
---

# Cross-PC Slave Handoff

슬레이브와 마스터가 서로 다른 PC를 사용하면 슬레이브의 절대경로는 인계 수단이
아니다. `output.md`와 `artifacts/`를 ZIP으로 만들고 ZIP 자체의 크기와 SHA-256,
manifest 및 마스터 실행 프롬프트를 함께 전달한다. 기존
[Slave Artifact Handoff](slave-artifact-handoff)의 내부 결과물 계약은 그대로
유지한다. [@slave-artifact-handoff]

## 전달 단위

슬레이브가 만드는 외부 전달 단위는 다음 네 파일이다.

```text
<task-id>-<timestamp>.zip
<task-id>-<timestamp>.sha256
<task-id>-<timestamp>.manifest.json
<task-id>-<timestamp>-MASTER_PROMPT.md
```

ZIP에는 `output.md`와 `artifacts/`만 들어간다. ZIP 바깥의 sidecar는 전송 중 ZIP
손상을 판별하고 마스터가 올바른 검증 프롬프트를 실행하도록 한다. 슬레이브 PC의
절대경로는 진단 정보일 뿐 완료 결과를 대신하지 않는다.

## 슬레이브 패키징

슬레이브는 먼저 일반 인계 계약에 따라 `output.md`와 0바이트가 아닌 모든 결과물을
완성한다. 그 다음 저장소의 패키징 스크립트를 실행한다. [@package-script]

```powershell
cd "<SLAVE_REPOSITORY_ROOT>"
.\tools\new_cross_pc_handoff.ps1 `
  -TaskDirectory ".\docs\migration\p2-planning-screen" `
  -DestinationDirectory "<SLAVE_OUTBOX_OR_MOUNTED_MASTER_INBOX>" `
  -TaskId "ba-planner-v7-p2-planning-screen"
```

`DestinationDirectory`가 마스터 PC의 네트워크·동기화 공유 폴더라면 스크립트 실행으로
전달까지 끝난다. 공유 폴더가 아니라면 사용자가 생성된 네 파일을 USB, 파일 첨부 또는
승인된 클라우드로 마스터 PC의 inbox에 복사한다. 네 파일을 일부만 전달하면 인계가
완료되지 않는다.

## 사용자 전달 절차

1. 슬레이브가 보고한 ZIP 이름, 크기와 SHA-256을 기록한다.
2. ZIP과 세 sidecar를 같은 전송 수단으로 마스터 PC에 옮긴다.
3. 마스터 PC의 고정 inbox인
   `<MASTER_REPOSITORY_ROOT>/docs/migration/handoffs/incoming/<task-id>/`에 네 파일을
   함께 둔다. 이 디렉터리는 전송용 local 상태이므로 Git에 포함하지 않는다.
4. `MASTER_PROMPT.md` 내용을 기존 P0~P6 마스터 대화에 전달하고 ZIP의 실제 마스터
   경로를 함께 알려 준다.
5. 마스터의 직접 검증이 끝날 때까지 슬레이브 결과를 P2 완료로 판정하지 않는다.

## 마스터 수신

마스터는 저장소에 바로 압축을 풀거나 패치를 자동 적용하지 않는다. 검사 스크립트로
ZIP 자체의 SHA-256을 확인한 뒤 고유 staging 디렉터리에만 압축을 푼다.
[@inspect-script]

```powershell
cd "<MASTER_REPOSITORY_ROOT>"
.\tools\inspect_cross_pc_handoff.ps1 `
  -PackagePath ".\docs\migration\handoffs\incoming\<task-id>\<package>.zip"
```

검사 스크립트는 ZIP을 검증하고 내부 결과물의 크기와 SHA-256을 출력하지만 패치를
적용하거나 저장소 파일을 덮어쓰지 않는다. 이후 마스터가 `output.md`, 내부 해시,
diff와 `git apply --check`를 직접 확인한다. 기존 사용자 변경과 겹치지 않을 때만
패치를 적용하고 전체 단계 검증을 수행한다.

## 실패와 재인계

- ZIP 또는 내부 결과물 해시가 다르면 적용하지 않는다.
- 누락 파일이 있으면 마스터가 직접 만들지 않고 기존 슬레이브에게 재인계를 요청한다.
- 재전송은 가능하지만 결과물 재생성은 마스터의 명시적 지시가 있을 때만 수행한다.
- `BLOCKED` 결과도 저장 가능한 `output.md`가 있으면 같은 방식으로 전달하되 완료로
  표시하지 않는다.
- 마스터가 동일 파일을 검증하기 전까지 상태는 `인계 대기` 또는 `검증 중`이다.
