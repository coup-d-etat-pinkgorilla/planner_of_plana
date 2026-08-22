# S3B promotion re-evaluation master verification

1. Read `output.md`, `verification.txt`, `reevaluation_summary.json` and both raw analyzer reports.
2. Verify every artifact size and SHA-256 recorded in `output.md`.
3. From `backend`, run:

   ```powershell
   .venv\Scripts\python.exe tools\benchmark_student_equipment_s3b_generated_glyph.py
   .venv\Scripts\python.exe -m unittest tests.test_student_equipment_s3b -v
   .venv\Scripts\python.exe -m unittest tests.test_student_scan_s2 tests.test_student_equipment_s3 tests.test_student_equipment_s3b tests.test_recognition_assets tests.test_scanner_stdio_transport -v
   ```

4. Confirm frozen generated fill remains 334/334, wrong 0, fallback 0.
5. Confirm the 1275x720 raw report accepts all three Aris T9 Lv65 crops as Lv6 for all generated
   variants; this is the production-blocking counterexample.
6. Confirm the six-screen report recognizes Niko/Kurumi repeats but rejects Kurumi Necklace T2 at
   margin 0.009946, leaving the end-to-end probe at 17/18.
7. Keep `generated_binary_production_enabled=false`; do not suppress fallback or begin S4/S5.

