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

1. Student metadata: list, inspect, create/update, JP-only toggle, delete, and a
   preview-before-apply SchaleDB gift-affinity sync. The sync deliberately keeps
   only `student.Id`, `student.FavorItemTags`, `student.FavorItemUniqueTags`,
   `gift.Id`, `gift.Category`, `gift.Tags`, and `gift.ExpValue`; bond stat fields
   remain out of scope. Current generated metadata and incoming values stay
   separate until apply, and the Flutter comparison uses bundled student portraits
   and gift icons rather than downloading presentation assets.
   The `STUDENTS` and `JP_ONLY_STUDENT_IDS` declarations in
   `backend/core/student_meta_data.py` remain the persistence contract.
   Duplicate-as-new and multi-form override editing are also migrated. Multi-form
   JSON is validated against `StudentFormMeta` and persists independently through
   the generated `MULTI_FORM_STUDENTS` declaration; saving the base student does
   not implicitly overwrite form-specific data.
   The read-only diagnostic surface is migrated through separate list/get DTOs. It
   combines KR/JP status, asset completeness, multi-form count, selected summary
   fields, and full field details for inspection without exposing write actions.
   Single-student SchaleDB URL/slug preview is migrated on the same seven-field
   boundary as bulk sync. Existing students may apply directly after confirmation;
   new or unmatched slugs must first become an editor draft so required local-only
   metadata cannot be omitted.
   Explicit server-state actions update only `JP_ONLY_STUDENT_IDS`. The diagnostic
   detail view confirms JP-only/KR transitions and reports missing KR-facing portrait
   or recognition assets after the change.
   SchaleDB multi-slug merge-path management stores identity rules separately from
   generated student metadata. The first slug drives the same minimal field import,
   every slug reverse-matches to the local student, and duplicate ownership is
   rejected. The Flutter view uses student portraits and primary/secondary chips.
2. Student template extraction: the default crop is derived from
   `student_texture_region`; a crop is written as RGBA PNG and accompanied by
   timestamped extraction metadata. The recognition manifest entry is updated
   atomically so runtime verification remains valid.
3. Inventory grid inspection: slots come from the packaged inventory region
   catalog and candidates are ranked by the same v7 `TemplateMatcher` used by
   the production scanner. Threshold and margin are inspection inputs only;
   inspecting never mutates recognition assets.
4. Item statistics: the selected v7 repository profile is the default read-only
   source, with optional explicit inventory/profile and plan-delta JSON files for
   parity inspection. Unknown, zero, positive, absent, missing-catalog, and
   plan-adjusted negative states remain distinct. Category coverage and item rows
   use packaged assets; unrelated resource quantities are never summed.

The v6 programs remain behavioral references only. v7 paths, manifests, and
backend APIs are the source of truth after migration.

## Deferred scope

Student statistics and SchaleDB student/bond-stat expansion remain deferred. All
approved non-student-statistics metadata-tool parity slices are migrated.

## Launch model

`frontend/lib/developer_tools_main.dart` selects one tool from a required
`--tool` argument. The three root launchers start independent OS processes:

- `run_student_metadata_editor.cmd`
- `run_student_template_extractor.cmd`
- `run_inventory_grid_match_inspector.cmd`

The launchers use an existing developer-tools release bundle when available
and otherwise fall back to `flutter run -d windows` with the dedicated entry
point.
