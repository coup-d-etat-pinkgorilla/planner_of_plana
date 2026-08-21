# S3B archive validation master prompt

Read `AGENTS.md`, the active P0-P6 status, student-scan validation workflow, the original S3B
handoff, and this handoff's `input.md`, `output.md` and artifacts.

Verify every artifact size/SHA-256, open `contact_sheets.zip`, and compare every printed prediction
with the enlarged visible digits. The archive ground-truth manifest discloses that predictions were
printed beside crops; acceptance therefore requires the visual review, source hashes and replay test
together, not the manifest label alone.

From `backend`, run:

```powershell
.venv\Scripts\python.exe -B tools\benchmark_student_equipment_s3b.py
.venv\Scripts\python.exe -B -m unittest tests.test_student_equipment_s3b -v
.venv\Scripts\python.exe -B -m unittest tests.test_student_scan_s2 tests.test_student_equipment_s3 tests.test_student_equipment_s3b tests.test_recognition_assets tests.test_scanner_stdio_transport
.venv\Scripts\python.exe -B -m unittest discover -s tests
```

Also run Python compile, `git diff --check`, `codealmanac validate`, and `codealmanac health`.

Do not promote the matcher from shadow mode yet. Position-2 digits 2/6/8, actual single-digit blank,
and non-Lv70 exact 1280x720 evidence are still absent. Confirm S4/S5 and generated/menu fallback are
unchanged.
