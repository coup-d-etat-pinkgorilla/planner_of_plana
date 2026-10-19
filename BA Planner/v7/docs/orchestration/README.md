# 세션 생성 프롬프트 색인 (2026-10-10)

규칙 원본: `almanac/workflows/lane-charter-2026-10-10.md`. 프론트 현재 slice가 끝나는 시점에 CM(이 대화) 외 세션은 전부 아래 프롬프트로 재생성한다.

| 세션 | 역할 | 생성 프롬프트 | 워커 프롬프트는 누가 |
|---|---|---|---|
| 클로드 마스터 **CM** | 전체 계획·실험 조율·택틱 연구·공용 저장소 | (이 대화, 재생성 없음) | CM이 과제 블록 작성 |
| 클로드 프론트 **CF** | 프론트 개편 + 개발자 도구 Flutter 화면 | `claude-frontend-orchestrator-prompt-2026-10-10.md` | CF — `frontend-redesign-workflow.md` "세션 시작 프롬프트 템플릿" |
| 코덱스 백엔드 마스터 **XB** | 백엔드·스캐너·택틱 구현·메타데이터 백엔드·릴리스 스크립트 | `codex-master-orchestrator-prompt-2026-10-10.md` | XB — `codex-backend-worker-common-block-2026-10-10.md` + 과제 블록 |
| 코덱스 연구 워커 **CM-R** (과제당 1세션) | CM의 실험 실행 | `codex-research-worker-prompt-2026-10-10.md` 공통 블록 + 과제 블록 | CM |
| 코덱스 백엔드 워커 (과제당 1세션) | XB의 slice 실행 | `codex-backend-worker-common-block-2026-10-10.md` + 과제 블록 | XB |
| 클로드 프론트 워커 (slice당 1세션) | CF의 slice 실행 | `frontend-redesign-workflow.md` 템플릿 | CF |

현재 바로 쓸 수 있는 과제 블록:
- CM-R: `docs/tactic-editor/followup-session-prompts-2026-10-08b.md` §W5b·§W4b(결과 검증)·§A0
- XB 첫 세션: 마스터 프롬프트 "지금 당장" 1~5 (S4-C6 수신, M0 — `docs/metadata-manager/session-prompts-2026-10-08.md`, scan commit 계약 초안)
- CF 첫 세션: 마스터 프롬프트 "지금 당장" 1~3

통신: 오케스트레이터 간 요청·회신·보고는 로그 끝 항목으로만. XB·CF의 세션 끝 보고는 `tactic-editor-orchestrator-log.md`에도 복사(헌장 §3-6).
