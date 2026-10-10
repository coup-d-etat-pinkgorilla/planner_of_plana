---
title: "Lane Charter 2026-10-10"
summary: "v7 작업을 세 오케스트레이터(클로드 마스터·클로드 프론트·코덱스 백엔드)로 나눈 교통정리: 레인별 소유 워크플로, 파일 소유, 인계·회신 규칙, 공용 gate."
topics: [workflow, orchestration]
sources:
  - id: agents
    type: file
    path: AGENTS.md
  - id: handoff
    type: file
    path: almanac/workflows/slave-artifact-handoff.md
---

# Lane Charter (2026-10-10)

사용자 결정: **클로드 = 프론트, 코덱스 = 백엔드·스캐너, 전체 계획·실험·조사·택틱 연구 = 클로드 마스터 세션.** 이 문서가 워크플로 간 우선 규칙이며, 각 워크플로 문서의 "세션 운영" 절과 충돌하면 이 문서가 이긴다.

## 1. 세 오케스트레이터

| 레인 | 주체 | 소유 워크플로·트랙 | 로그 |
|---|---|---|---|
| **CM** 클로드 마스터 | 이 대화(사용자와 직접). 실행은 **코덱스 연구 전용 워커(CM-R)** — 프롬프트 `docs/orchestration/codex-research-worker-prompt-2026-10-10.md`; CM은 계획·판정만 하고 직접 추출·역어셈블·결과 파일 판독을 하지 않는다 | 전체 개발 계획·우선순위·실험·조사 / 택틱 **연구**(T3·T4a·TD 결정, W5b·W4b 같은 추출·역어셈블·관측 대조, A0·A1) / 공용 저장소 `ba-client-data` 단일 쓰기 주체 / 레인 간 중재·계약 승인 | `tactic-editor-orchestrator-log.md`(연구), `metadata-manager-orchestrator-log.md`(결정만) |
| **CF** 클로드 프론트 | 프론트 오케스트레이터 세션 | 프론트 개편(FE·FD), 개발자 도구 Flutter 화면(M2, M4~M6의 탭 UI, A2), 프론트 쪽 FB 소비 변경 | `frontend-redesign-orchestrator-log.md` |
| **XB** 코덱스 백엔드 | 코덱스 마스터 세션(프롬프트: `docs/orchestration/codex-master-orchestrator-prompt-2026-10-10.md`) | 스캐너 전부(post-consolidation O2/O3·S4-C6·O3-4·S-FB1b·S-FB2b) / 백엔드 FB 슬라이스(FB-1b·FB-2a 커밋 이후의 FB-* 백엔드) / 택틱 **구현**(DTO·battle_rules 코드·T-FB1b·T-FB2d·T4 stage 구현) / 메타데이터 관리자 백엔드(M0·M1·M3·M5·M6의 Python·데이터·계약) / 릴리스 번들 스크립트 | `backend-orchestrator-log.md`(신설) |

연구와 구현의 경계: CM이 "무엇이 사실인가"(근거·수치·귀속·계약 초안)를 내고, XB가 "코드에 어떻게 넣는가"를 한다. CM 산출은 `docs/**`·`evidence/**`·`data/extracted/**`, XB 산출은 `backend/**`·`contracts/**`·`backend/data/**`.

## 2. 파일 소유 (쓰기 권한)

| 경로 | 소유 | 다른 레인은 |
|---|---|---|
| `frontend/lib/**`(개발자 도구 포함), `frontend/test/**`, golden | CF | 요청만. 예외: A2 폴더 `frontend/lib/developer_tools/animation_spectrum/`는 CF가 CM 계약(09:05)대로 만든다 |
| `backend/core/**`, `backend/tools/**`, `backend/tests/**`, `backend/data/**`, `contracts/**` | XB | CM은 `backend/tools/battle_spec/**`·`backend/data/battle_rules/**`의 **연구 산출(JSON·dis 텍스트)** 만 추가 가능, 코드는 XB |
| `data/extracted/**`, `docs/tactic-editor/**`, `docs/metadata-manager/*-source-map*`, `almanac/workflows/*tactic*` | CM | XB는 읽기. `data/extracted/pipeline/extract_jp.py` TABLES 추가는 CM 승인 1회 단위(D8 선례) |
| `almanac/workflows/metadata-manager-*` | CM(결정) + XB(상태) | status 파일은 XB가 갱신, workflow 문서는 CM |
| `almanac/workflows/frontend-redesign-*` | CF | — |
| `almanac/workflows/post-consolidation-*`, `scanner-*` | XB | — |
| `C:\Users\brigh\ba-client-data\**` | CM(사용자 PC에서 실행) | XB·CF는 명령 준비까지만. `ba-data.lock` 갱신은 CM 승인 + 사용자 실행 |
| `release/**`, `frontend/tool/*.ps1` | XB(빌드 스크립트) / CF(fe_gate) | — |

## 3. 인계·회신 규칙

1. 레인 간 요청은 **상대 레인 로그 맨 끝에 항목**으로 쓴다(제목에 "요청" 또는 "알림", 작성 레인 명시). 회신은 같은 로그에 새 항목. 사용자가 중계하지 않아도 되게, 각 오케스트레이터는 세션 시작 때 세 로그의 자기 앞 미회신 항목을 먼저 읽는다.
2. **계약·커밋은 XB 자율(2026-10-10 13:50 사용자 결정).** `contracts/*.schema.json`과 백엔드 커밋은 XB가 자기 gate(전체 Python·codealmanac·diff --check, Flutter 영향 시 CF gate)를 통과하면 **CM 승인 없이 확정·커밋**한다. CM의 역할은 인지다: XB 보고를 읽고 이의가 있으면 **사후에** 로그로 적고, 그때 XB가 후속 커밋으로 고친다. "승인 요청"은 CM 소유 영역을 건드릴 때만 쓴다 — 공용 저장소 쓰기·`ba-data.lock`·`data/extracted/pipeline/*`·`docs/tactic-editor/**`·택틱 연구 결론(scope engine/observed 변경)·사용자 결정이 필요한 되돌릴 수 없는 일. CF는 XB가 **커밋한** 계약부터 실제 연결한다(커밋 전엔 mock).
   2-1. **FB 백엔드 이관 규칙(2026-10-10 02:17 사용자 승인)**: CF는 FB-1b·FB-2a 커밋 때 인계 메모를 `frontend-redesign-status-backend.md` 끝에 남긴다. XB는 FB 요청서를 스캐너·메타데이터보다 우선 처리한다. 첫 이관 slice는 작은 것 하나로 왕복을 검증한다. 왕복 지연이 프론트를 반복해서 멈추게 하면 CM 결정으로 "FB 전용 백엔드 워커 1명을 CF가 유지"로 되돌릴 수 있다(헌장 §1 한 줄 수정).
3. 워커 산출은 `slave-artifact-handoff.md` 형식(`debug/<task>/output.md` + artifacts + 해시). 오케스트레이터가 받아 커밋 범위를 정한다. 푸시는 사용자만. [@handoff]
4. 사용자 PC에서만 되는 일(게임 파일 읽기·저장소 쓰기·gate 실행·golden 갱신)은 워커가 **명령과 기대 결과**를 적고 사용자가 실행한다. 워커 샌드박스 실패를 재시도·우회하지 않는다.
5. 완료 선언은 각 워크플로의 완료 조건으로만. "T1/T3/T4 완료", "O3 승격", "SchaleDB 제거 완료"는 CM만 선언.
6. 금지(전 레인): 게임 프로세스 후킹·메모리·주입, 키 값 기록·전송, 원본 복사, Viewer/Arena 접근, holdout 자료 접근(평가 세션 외), `../v6` 런타임 import, Qt/Tk 코드 반입. [@agents]

## 4. 공용 gate

- Python: `cd backend; py -3.11 -m unittest discover -s tests -v` 전체 녹색.
- Flutter: `frontend/tool/fe_gate.ps1`(CF 소유; XB 변경이 Flutter에 닿으면 CF에 gate 요청).
- `codealmanac validate`, `git diff --check`.
- 커밋 메시지에 근거 `debug/.../output.md` 경로. 한 커밋 = 한 레인.

## 5. 현재 진행 중인 것의 귀속 (2026-10-10 01:30 기준)

| 항목 | 상태 | 귀속 |
|---|---|---|
| W5b 미카 EX 로직 행 추출 + gate 재계산 | 배정됨 | CM(연구). 결과의 DTO 반영은 XB |
| W4b ExpType 1함수 dis | 배정됨(결과 `a107c3f2` 보고됨) | CM |
| S4-C6 짝수 패딩 오프라인 비교 | 배정됨 | **XB로 이관**(결과 수신부터) |
| O3-4 holdout 안내·평가 | S4 뒤 | XB(평가 세션 분리 규칙 유지) |
| A0 스펙트럼 계약·가용성 | 배정됨 | CM. A1 추출 CM, A2 화면 CF |
| M0 출처 지도·inventory | 배정됨 | **XB로 이관**. M1·M3·M5·M6 백엔드 XB, M2·탭 UI CF |
| FB-1b, FB-2a | CF 레인 백엔드 워커 진행 중 | 커밋까지 CF, 이후 FB-* 백엔드는 XB |
| S-FB1b·S-FB2b·T-FB1b·T-FB2d | FB 커밋 대기 | XB(네 개 모두 백엔드·스캐너·택틱 구현) |
| T3·T4a 연구, TD 결정, 공용 저장소 | 진행 | CM |
| 프론트 개편 FE/FD | 진행 | CF |
