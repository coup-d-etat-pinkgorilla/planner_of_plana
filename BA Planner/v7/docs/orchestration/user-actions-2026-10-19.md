# 사용자 PC 복귀 후 실행 목록 (2026-10-19 22:45, CM)

순서대로. 각 명령은 쓰기 없는 검증 또는 CM 승인된 저장소 import다. 키·원본 무관.

## 1. 스캔 v25 독립 채점 (모델 재실행 없음)
```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\grid_scroll_stitch_20261005_01a10a3b\artifacts\practical_roi_eval_v25\artifacts"
py -3.11 -B .\score_reviewed_labels.py .\reviewed-labels.json .\independent-score.json
```
결과 `independent-score.json`을 CM에(붙여넣기 또는 "됐어").

## 2. 공용 저장소 import 4건 (CM 승인 2026-10-19)
```powershell
$S='C:\Users\brigh\ba-client-data'; $V='C:\Users\brigh\planner_of_plana\BA Planner\v7'; $PY="$V\backend\.venv\Scripts\python.exe"
# 2-1 student-stats (M3 결정 3)
cd $V; $sha8 = (git log -1 --format=%h -- data/extracted/pipeline/run_all.py)
New-Item -ItemType Directory -Force "$env:TEMP\student-stats-src" | Out-Null
Copy-Item "$V\data\extracted\student-stats-jp.json","$V\data\extracted\student-stat-formula-jp.json" "$env:TEMP\student-stats-src\"
& $PY -X utf8 -B "$S\tools\import_extract.py" --server jp --version-id jp-1.73.0-e2baf70e --kind student-stats --src "$env:TEMP\student-stats-src" --tool "v7 data/extracted/pipeline/run_all.py@$sha8" --consumer v7 --store $S --note "M3 stats kind (CM approved 2026-10-19)"
# 2-2 animation-events (A1-b, 19 MB 폴더)
& $PY -X utf8 -B "$S\tools\import_extract.py" --server jp --version-id jp-1.73.0-e2baf70e --kind animation-events --src "$V\data\extracted\animation-events\jp-1.73.0-e2baf70e" --tool "extract_animation_events.py@73b37bd5" --consumer v7 --store $S
# 2-3 animation-spectrum (A1-c, 부분 — 연결 0건 상태임을 note에)
& $PY -X utf8 -B "$S\tools\import_extract.py" --server jp --version-id jp-1.73.0-e2baf70e --kind animation-spectrum --src "$V\data\extracted\animation-spectrum\jp-1.73.0-e2baf70e" --tool "build_animation_spectrum.py@5295cb22" --consumer v7 --store $S --note "A1-c partial: linkedLogicEvents=0, anim layer only"
# 2-4 skill-logic-full (A1-a) — 1.4 GB canonical 대신 index + zip만
New-Item -ItemType Directory -Force "$env:TEMP\skill-logic-full-src" | Out-Null
Copy-Item "$V\docs\tactic-editor\evidence\skill-logic-full-index-jp-1.73.0.json","$V\debug\cm_r_a1a_20261010\artifacts\derived-output.zip" "$env:TEMP\skill-logic-full-src\"
& $PY -X utf8 -B "$S\tools\import_extract.py" --server jp --version-id jp-1.73.0-e2baf70e --kind skill-logic-full --src "$env:TEMP\skill-logic-full-src" --tool "extract_skill_logic_full.py@97ffb518" --consumer v7 --store $S --note "index + compressed payload (canonical 1.41 GB kept in v7 data/extracted)"
```
각 명령 종료 코드 0과 `claims_mismatch 0`만 확인. 실패하면 그 줄의 출력만 CM에.

## 3. 그 뒤 (CM이 명령 줄 준비)
- [x] 1·2 완료 2026-10-19 23:30 (4건 모두 claims_mismatch 0). proposed lock 생성·verify OK → `debug/cm_lock_update_20261019/`.
- `verify_lock.py` → proposed lock(기존 pin + 새 kind 4개) → CM 확인 → live lock 교체.
- R-M3-1(gift-affinity) CM-R 세션 시작 — `cm-r-task-blocks-2026-10-10.md` 끝.
- push: `git push -u origin scanner-consolidation` (219+ 커밋, 첫 push 느림).

## 4. 결정만 해 주면 되는 것 (PC 불필요)
- `docs/alpha/alpha-distribution-decision-2026-10-19.md` A/B/C 권고안 확정 여부.
- `docs/alpha/first-run-tutorial-concept-2026-10-19.md` 방향(빈 상태=안내, 체크리스트 3단계) 동의 여부 → 동의하면 CF에 설계 입력으로 전달.
- FE10-z 둘러보기는 PC 복귀 후.
