# S3B master verification prompt

Read `AGENTS.md`, `README.md`, `almanac/workflows/p0-p6-workflow-status.md`,
`almanac/workflows/student-scan-validation-workflow.md`, the S3B canonical input, this handoff's
`input.md`, `output.md`, and every artifact before deciding acceptance.

Verify artifact size/SHA-256 against `output.md`, inspect the source bundle, then run from `backend`:

```powershell
.venv\Scripts\python.exe -B tools\benchmark_student_equipment_s3b.py
.venv\Scripts\python.exe -B -m unittest tests.test_student_scan_s2 tests.test_student_equipment_s3 tests.test_student_equipment_s3b tests.test_recognition_assets tests.test_scanner_stdio_transport
.venv\Scripts\python.exe -B -m unittest discover -s tests
```

From the repository root also run Python compile on the changed modules, `git diff --check`,
`codealmanac validate`, and `codealmanac health`.

Acceptance at this handoff means the S3B shadow implementation is safe and reproducible. It does
not mean production promotion. Confirm that `equipment_binary_shadow` never enters payload values,
does not suppress the generated/menu fallback, and that S4/S5 are unchanged.

MASTER_REQUIRED before production promotion: independent actual coverage for digits 1-6/8/9 and
single-digit blank, broader slot/tier/family/resolution repeats, full confusion data, committed false
positive 0, and evidence-based score/margin selection. Do not enable production from the current
7/0-only smoke fixture.
