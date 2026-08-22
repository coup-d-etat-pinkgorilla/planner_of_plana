# Master verification

```powershell
$env:BA_PLANNER_ASSET_DIR=(Resolve-Path .).Path
backend\.venv\Scripts\python.exe backend\tools\benchmark_student_equipment_s3b_actual_tier_bank.py
cd backend
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
cd ..
codealmanac validate
codealmanac health
git diff --check
```

90-template completeness, runtime asset hashes, `equipment_direct_icon_tier` normal path,
synthesized uncertainty fallback, asset count 1,117과 S4/S5 미변경을 확인한다.
