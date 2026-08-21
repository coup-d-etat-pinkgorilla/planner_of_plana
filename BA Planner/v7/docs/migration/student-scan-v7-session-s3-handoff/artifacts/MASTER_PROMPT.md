# S3 final review prompt

Read `AGENTS.md`, `README.md`, `almanac/workflows/p0-p6-workflow-status.md`,
`almanac/workflows/student-scan-validation-workflow.md`,
`docs/migration/student-scan-v7-session-s3-input.md`, and
`docs/migration/v6-knowledge-baseline.md` before review.

Review and accept S3 only. Do not start S4 or S5.

1. Inspect `backend/core/student_equipment_recognizer.py`. Confirm that candidate generation uses a
   cached 200x160 card and direct 48x36 ROI, the 384-entry LRU owns only compact features, and exact
   alignment is evaluated before conditional +/-1px retry.
2. Confirm level-lock, empty, family restriction, tier/level validation, favorite states, full-frame
   disposal, and one shared menu capture restricted to unresolved slots.
3. Inspect `backend/tests/fixtures/student_equipment_s3_live_master.json` and the full-screen sources
   under `student_equipment_s3_dataset/live_1280x720/`. Verify three Mika basic/menu repeats and
   three Hibiki favorite-T2 repeats, with runtime assets kept separate.
4. Inspect `student_equipment_s3_v6_baseline.json`: v6 cold 902.3751ms and warm p50 58.53545ms are
   executable measurements, not historical estimates. Confirm the offline runner does not enter the
   v7 runtime.
5. From `backend`, run:
   - `.venv\Scripts\python.exe -m unittest tests.test_student_equipment_s3 tests.test_scanner_stdio_transport.ScannerStdioTransportTests.test_real_process_serves_asset_readiness_and_windows_target_list -q`
   - `.venv\Scripts\python.exe tools\benchmark_student_equipment_s3.py --output tests\fixtures\student_equipment_s3_benchmark.json`
6. From the v7 root, run `git diff --check`, `codealmanac validate`, and `codealmanac health`.
7. Accept the retained unresolved-only menu fallback. Do not interpret the future T1-T9/non-70,
   favorite-T1, or alternate-scale coverage list as permission to tune thresholds without evidence.

The repository's unrelated generated student metadata currently causes eight baseline full-suite
failures documented in `verification.txt`; do not repair that generated-data subsystem as part of
S3 review.
