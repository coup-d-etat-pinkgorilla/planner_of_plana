# S2 master 수신 prompt

`input.md`와 `output.md`를 먼저 읽고 `artifacts/`의 SHA-256을 검증한다.
`student_basic_assets.zip`은 `backend/assets/recognition/v1/templates/` 아래에 풀어
`student_basic/` 경로를 복원한다. 나머지 artifact는 보존된 상대 경로에 배치한다.

그 뒤 repository venv에서 아래를 재실행한다.

```powershell
cd backend
$env:BA_PLANNER_ASSET_DIR=(Resolve-Path '.').Path
.\.venv\Scripts\python.exe -m unittest tests.test_student_scan_s2 tests.test_scanner_production_adapters tests.test_recognition_assets tests.test_scanner_session tests.test_scanner_protocol_contract -v
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

실제 fixture에서 ID 외 확정값, 단일 stable capture, `skill2` 불확실성 격리,
review-required, canonical multi-form ref, asset readiness 1013개를 확인한다. S2가 승인되기
전에는 S3를 시작하지 않는다. 승인 후에도 S3 장비·애용품 fast path와 profiler만 수행하고
S4 인연 OCR/계산 evidence 및 S5 Flutter는 건드리지 않는다.
