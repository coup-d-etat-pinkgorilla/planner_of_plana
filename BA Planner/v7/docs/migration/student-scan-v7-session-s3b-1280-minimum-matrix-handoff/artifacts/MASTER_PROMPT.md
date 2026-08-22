# Exact 1280x720 minimum matrix master verification

1. Read `output.md`, `verification.txt`, the coverage document and the minimum matrix JSON.
2. Verify all artifact sizes and SHA-256 recorded in `output.md`.
3. From `backend`, regenerate with:

   ```powershell
   .venv\Scripts\python.exe tools\build_student_equipment_s3b_1280_matrix.py ..\docs\migration\student-scan-v7-session-s3b-1280-minimum-matrix-handoff\artifacts\equipment_1280x720_minimum_matrix.json --include-minimum
   ```

4. Confirm each split has 30 rows and exactly 90 unique family-tier pairs. For every slot confirm
   one-digit 1-9, tens 1-7, ones 0-9, all tier maxima, 12/23/34 and 56/65 coverage.
5. Confirm each student's three tiers advance monotonically T1 through T10 and the Airi (Band) T4 row
   is 12/23/34.
6. Treat calibration repeats as repeats only. Use Chihiro/Marina (Qipao)/Tsurugi (Swimsuit) for the independent
   validation split; production-quality minimum is 60 configurations/180 exact-1280x720 PNGs.
7. Keep production flags false and do not begin S4/S5.
