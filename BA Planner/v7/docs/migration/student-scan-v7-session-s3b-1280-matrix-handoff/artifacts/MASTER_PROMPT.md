# Exact 1280x720 equipment matrix master verification

1. Read `output.md`, the coverage document, `verification.txt` and
   `equipment_1280x720_matrix.json`.
2. Verify the artifact sizes and SHA-256 recorded in `output.md`.
3. From `backend`, regenerate and validate the matrix:

   ```powershell
   .venv\Scripts\python.exe tools\build_student_equipment_s3b_1280_matrix.py ..\docs\migration\student-scan-v7-session-s3b-1280-matrix-handoff\artifacts\equipment_1280x720_matrix.json
   .venv\Scripts\python.exe -m unittest tests.test_student_equipment_s3b -v
   ```

4. Confirm 1,335 equipped configurations, 4,005 equipped atomic cases, 4,010 normal equipment
   atomic cases, 4,016 live atomic cases including favorite and a 4,080-PNG non-deduplicated upper
   bound at three repeats.
5. Reject every source whose pixel size is not exactly 1280x720 or that contains borders, padding
   or letterboxing. Do not count the prior 1275x720/1276x752 results in promotion metrics.
6. Keep both production flags false and do not begin S4/S5.

