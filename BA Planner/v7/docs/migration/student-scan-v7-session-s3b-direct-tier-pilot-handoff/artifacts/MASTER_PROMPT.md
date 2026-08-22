# Master verification

`output.md`의 artifact hashes를 대조하고 다음을 실행한다.

```powershell
$env:BA_PLANNER_ASSET_DIR=(Resolve-Path .).Path
backend\.venv\Scripts\python.exe backend\tools\benchmark_student_equipment_s3b_direct_tier.py
backend\.venv\Scripts\python.exe -m unittest backend.tests.test_student_equipment_s3b -v
codealmanac validate
codealmanac health
git diff --check
```

이 pilot은 production 전환이 아니다. 나머지 6-family template와 전체 identity-independent
validation이 들어오기 전에는 기존 synthesized reader/fallback을 유지한다.
