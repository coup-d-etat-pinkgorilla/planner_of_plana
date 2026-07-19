# Agent Instructions

## Start Here

- Read `README.md` and the relevant page under `almanac/` before changing a subsystem.
- Read `docs/migration/v6-knowledge-baseline.md` before copying or adapting v6 code.
- Treat `../v6` as a behavioral reference, not as an importable runtime dependency.

## Migration Rules

- Do not copy Qt, QML, QWidget, Tkinter, or PySide6 code into v7.
- Keep Flutter and Python in separate processes with a versioned local protocol.
- Preserve the five data buckets: scanned current state, static metadata, user goals,
  gross calculation results, and inventory-derived shortage.
- Copy one backend vertical slice at a time and add a parity fixture before adapting it.
- Do not import Python modules from `../v6` at runtime.
- Do not copy scanner or repository facades until their DTO and callback dependencies
  have been characterized and separated.

## Generated And Local Files

- `backend/core/student_meta_data.py` is generated data. Do not broadly hand-edit it.
- `profiles/`, databases, logs, scan results, Flutter `build/`, Python caches, and
  release output are generated/local state.
- Runtime UI assets and scanner recognition templates must remain separate.

## Validation

- Python: `cd backend; py -3.11 -m unittest discover -s tests -v`
- Flutter: `cd frontend; flutter analyze; flutter test`
- Windows release: `cd frontend; flutter build windows --release`

