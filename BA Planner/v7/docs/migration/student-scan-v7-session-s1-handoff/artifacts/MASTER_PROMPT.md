# S1 acceptance prompt

Review `output.md`, verify every artifact size and SHA-256, and compare the artifact copies with
their workspace destinations. Then run:

```powershell
cd backend
py -3.11 -m unittest tests.test_student_stats -v
$env:BA_PLANNER_ASSET_DIR=(Resolve-Path .).Path
.venv\Scripts\python.exe -m unittest discover -s tests -v
cd ..
codealmanac validate
codealmanac health
```

Acceptance checks:

- the focused suite reports 9 passing tests;
- the full suite reports 166 passing tests;
- `backend/data/student_stats/v1/catalog.json` is 154,008 bytes with SHA-256
  `6b583668c4fee8de6d4ceeeacab6210094741829d81545bb9af08820a8f76e4e`;
- unknown alternate-outfit ranks produce `dependency_missing` and no exact `values`;
- explicitly unowned alternate outfits contribute zero without creating a missing dependency;
- no scanner/protocol/Flutter code is part of this handoff.

After acceptance, freeze the S1 snapshot before starting S2. Do not fold S2 work into S1 review.
