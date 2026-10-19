# CM-R 과제 블록 (2026-10-10)

공통 블록은 `docs/orchestration/codex-research-worker-prompt-2026-10-10.md`. 한 세션 = 한 블록. 결과는 CM이 `tactic-editor-orchestrator-log.md`에 판정.

## R-STORE-1 — 공용 저장소 정비: Steam revision 출처 · 패치 절차 dry-run 대본 · CHANGELOG · CM 문서 커밋

```
읽을 것: C:\Users\brigh\ba-client-data\README.md·BOOTSTRAP.md·NOTICE-for-workers.md·CHANGELOG-store.md·status/jp/*.md·status/steam/*.md·tools/*.py(전부, 수정 금지) → v7 ba-data.lock → almanac/workflows/metadata-manager-workflow.md M5 절(패치 체크리스트 7단계) → 2026-10-08 W4·W5b 인계의 import 선례(debug/w1_w5_approved_resume_20261008_01a11796/output.md "W4 registration").
원칙: 저장소에 쓰지 않는다(파일 생성·수정 0). 게임 파일 읽기만, 복사 0, 키 값 0, 네트워크 0. 라운드 한도 2.
1. Steam revision 출처: 설치본(C:\Program Files (x86)\Steam\steamapps\common\BlueArchive 또는 사용자 설정 경로; 못 찾으면 [?])에서 "464491"이 적힌 파일을 찾는다 — 후보: steamapps/appmanifest_*.acf(buildid), 게임 폴더의 버전/manifest/launcher 설정 JSON, 실행 파일 리소스 버전. 각 후보의 경로·필드·값·읽기 방법(텍스트/JSON/PE 리소스)을 표로. appmanifest buildid와 게임 내부 revision이 다른 개념이면 둘 다 적고 어느 것을 version-id에 쓸지 제안(채택은 CM). JP도 같은 표(game-launcher-config.json이 이미 출처 — 재확인만).
2. 패치 절차 dry-run 대본: docs/metadata-manager/store-patch-runbook-2026-10-XX.md — M5 7단계를 지금 도구(register_client/import_extract/diff_versions/make_lock/verify_lock + v7 extract 스크립트들)로 **실제 명령줄**까지 적는다. 단계마다 입력·출력 경로·기대 종료 코드·실패 시 중단 조건. "이미 등록된 버전이면 중단"을 현재 두 버전으로 모의 실행해(명령은 실행하되 쓰기 없는 것만: verify_lock, diff_versions 두 버전 간, register_client --dry-run이 있으면 그것) 출력 캡처. 쓰기 단계는 명령만 적고 실행하지 않는다. diff_versions가 kind별 L1(해시)/L2(행 수·행 변경)/L3(동작, 택틱 판정 필요) 중 어디까지 자동으로 내는지 표로 — 자동이 안 되는 L2는 "필요한 소형 도구"로 적는다(구현은 XB 요청 후보).
3. CHANGELOG-store.md 정리안: status 파일에 흩어진 변경(2026-10-07 가동, 10-07 S1·S2 kind 추가, 10-08 favor-cafe·mika-ex-logic)을 날짜순 항목으로 옮긴 초안을 artifacts/CHANGELOG-store.proposed.md로. 저장소 파일은 건드리지 않는다(CM이 사용자 PC에서 반영).
4. CM 소유 문서 커밋 1건: almanac/workflows/lane-charter-2026-10-10.md(CF가 lint 인용 2개 추가한 작업 트리 상태 그대로), docs/orchestration/*.md, almanac/workflows/metadata-manager-*.md, tactic/metadata 로그, docs/tactic-editor/followup-session-prompts-2026-10-08b.md·cm-r-task-blocks-2026-10-10.md 중 **미커밋 상태인 것만**. 커밋 전 git status로 다른 레인 파일(frontend/, backend/, contracts/)이 섞이지 않는지 확인하고, 섞여 있으면 CM 문서만 add. codealmanac validate 통과 필수. 메시지 "orchestration docs 2026-10-10".
산출물: debug/cm_r_store_1_<stamp>/output.md + artifacts(revision 표, runbook, CHANGELOG 초안, dry-run 캡처), 커밋 해시 1개. 완료 보고: Steam revision 출처 결론(확정/후보/미확인), 자동 L1/L2 범위, 커밋 해시.
```

## R-VERIFY-W5b — W5b 결과 수신 검증 (W5b 워커와 다른 세션)

```
읽을 것: docs/tactic-editor/followup-session-prompts-2026-10-08b.md §W5b(과제 원문·판정 기준) → debug/ 아래 W5b 세션 폴더(이름에 mika_ex 또는 w5b, 2026-10-08 이후) output.md·artifacts → docs/tactic-editor/t1-mika-ex-gate-2026-10-08b.md(있으면) → docs/tactic-editor/evidence/t1-mika-ex-logic-jp-1.73.0.json → C:\Users\brigh\ba-client-data\extracts\jp\jp-1.73.0-e2baf70e\mika-ex-logic\provenance.json(읽기만).
원칙: 재계산·재추출 금지. 읽고 대조만. 라운드 1.
표로 답할 것: (1) 과제 1~4 각각 수행 여부와 산출 경로 (2) 구조 판정(10틱+1타 일치/불일치) 근거 꼬리표 (3) 틱·마지막 [최소,최대] 범위와 55건 안/밖/HP-미기록-미판정 건수 — output.md 수치와 evidence JSON 수치가 같은지 (4) PASS/FAIL/NOT_VERIFIED 선언이 기준(범위 밖 0 && 미판정 0 → PASS)과 맞는지 (5) 계수 보정·가설 채택 흔적 유무 (6) 저장소 provenance sha와 evidence sha 일치 (7) 커밋 해시와 변경 파일이 과제 허용 범위(extract_jp.py TABLES·evidence·보고서) 안인지 (8) 남은 입력(보스 HP 영상 필요 여부).
산출물: debug/cm_r_verify_w5b_<stamp>/output.md 1개. 결론 한 줄: "수용 / 조건부 수용(사유) / 반려(사유)".
```

## R-VERIFY-W4b — W4b 결과 수신 검증

```
읽을 것: followup-session-prompts-2026-10-08b.md §W4b → 커밋 a107c3f2의 변경 파일과 debug/ W4b 세션 폴더 output.md → docs/tactic-editor/evidence/favor-cafe-tables-jp-1.73.0.json ExpType 절(버전 올린 것) → dis 텍스트.
원칙: 재역어셈블 금지. 라운드 1.
표로: (1) 결론이 ①랭크별 필요 / ②누적 임계 / 미확정 중 무엇이며 근거 [코드] 꼬리표(심볼·RVA·명령 라인) (2) FavorLevelupType → 원소 인덱스 변환 확인 여부 (3) 실행 가능 섹션 + exact unwind 기준 충족 (4) 변경 파일이 허용 범위(evidence·dis) 안인지, 프론트 로그 미수정 (5) 미확정이면 "사용자 인연 화면 1장" 교차 확인 안내가 있는지.
산출물: debug/cm_r_verify_w4b_<stamp>/output.md. 결론 한 줄 + 프론트에 전달할 3줄(ExpType 해석 확정값 또는 미확정).
```
