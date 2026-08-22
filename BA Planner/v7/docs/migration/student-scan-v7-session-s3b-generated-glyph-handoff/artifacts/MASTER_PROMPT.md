# S3B generated glyph master verification

1. Read `output.md`, `verification.txt` and the raw benchmark.
2. Verify the ZIP and individual artifact hashes reported in `output.md`.
3. From `backend`, run:

   ```powershell
   .venv\Scripts\python.exe tools\benchmark_student_equipment_s3b_generated_glyph.py
   .venv\Scripts\python.exe -m unittest tests.test_student_equipment_s3b -v
   .venv\Scripts\python.exe -m unittest tests.test_student_scan_s2 tests.test_student_equipment_s3 tests.test_student_equipment_s3b tests.test_recognition_assets tests.test_scanner_stdio_transport -v
   ```

4. Confirm generated fill is `benchmark_lead_not_production_selected`, 334/334 with accepted wrong 0.
5. Confirm payload values and unresolved-only one-menu fallback are unchanged.
6. Do not enable production or start S4/S5 until independent calibration, non-Lv70 exact 1280x720,
   cold preparation optimization and explicit master acceptance are complete.
