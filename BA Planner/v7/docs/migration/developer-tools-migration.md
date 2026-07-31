# v6 developer tools migration

## Scope

The v6 student metadata editor, student template extractor, and inventory grid
match inspector are migrated as v7 developer tools. They run in their own
Flutter windows and do not import or launch the v6 runtime.

## Runtime boundary

- Flutter owns presentation, file selection, form state, and result display.
- Each operation starts a short-lived Python 3.11 process through
  `backend/tools/developer_tools.py`.
- Requests and responses are versioned JSON objects on stdin/stdout.
- Python owns generated metadata edits, image cropping, recognition-manifest
  updates, and inventory template matching.
- Qt, QML, QWidget, Tkinter, and PySide6 code are not copied into v7.

## Vertical slices and parity anchors

1. Student metadata: list, inspect, create/update, JP-only toggle, and delete.
   The `STUDENTS` and `JP_ONLY_STUDENT_IDS` declarations in
   `backend/core/student_meta_data.py` remain the persistence contract.
2. Student template extraction: the default crop is derived from
   `student_texture_region`; a crop is written as RGBA PNG and accompanied by
   timestamped extraction metadata. The recognition manifest entry is updated
   atomically so runtime verification remains valid.
3. Inventory grid inspection: slots come from the packaged inventory region
   catalog and candidates are ranked by the same v7 `TemplateMatcher` used by
   the production scanner. Threshold and margin are inspection inputs only;
   inspecting never mutates recognition assets.

The v6 programs remain behavioral references only. v7 paths, manifests, and
backend APIs are the source of truth after migration.

## Launch model

`frontend/lib/developer_tools_main.dart` selects one tool from a required
`--tool` argument. The three root launchers start independent OS processes:

- `run_student_metadata_editor.cmd`
- `run_student_template_extractor.cmd`
- `run_inventory_grid_match_inspector.cmd`

The launchers use an existing developer-tools release bundle when available
and otherwise fall back to `flutter run -d windows` with the dedicated entry
point.
