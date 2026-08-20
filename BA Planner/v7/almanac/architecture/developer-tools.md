---
title: "Standalone Developer Tools"
summary: "The v7 metadata editor, template extractor, and grid match inspector use Flutter windows backed by short-lived Python processes."
topics: [architecture, migration]
sources:
  - id: migration-note
    type: file
    path: docs/migration/developer-tools-migration.md
  - id: flutter-entry
    type: file
    path: frontend/lib/developer_tools_main.dart
  - id: python-entry
    type: file
    path: backend/tools/developer_tools.py
---

# Standalone Developer Tools

The student metadata editor, student template extractor, and inventory grid
match inspector are independent Flutter Windows processes. A required `--tool`
mode selects the surface. Each operation starts the Python developer-tool
backend, sends one protocol-v1 JSON request through stdin, reads one JSON
response from stdout, and lets the process exit. [@flutter-entry] [@python-entry]

The tools use v7 generated metadata and recognition assets directly. Template
extraction updates both the PNG and its recognition manifest integrity fields.
Grid inspection is read-only and uses the production v7 template matcher and
packaged region catalog. No v6 module and no Qt/Tk presentation code is a v7
runtime dependency. [@migration-note] [@python-entry]

The root `.cmd` launchers prefer `release/developer_tools/ba_planner_v7.exe`
and fall back to `flutter run` during development. Each launcher starts a new
OS process, so closing a tool cannot close the main Planner UI process.

The metadata editor's SchaleDB surface is a two-step boundary. Preview returns
incoming minimal gift-affinity fields alongside the current generated student
metadata, without writing. Apply atomically updates the three student fields and
the separate four-field gift catalog. The comparison UI renders bundled portraits
and present icons, shows current and incoming tags separately, and reports local
students that could not be matched. Student bond-stat fields are intentionally not
part of this sync.

Base student records and multi-form overrides are separate generated contracts.
`metadata.forms.get` and `metadata.forms.save` expose the latter without folding
form-specific fields into `STUDENTS`; the Flutter editor therefore uses an
explicit form-save action. Duplicate-as-new creates an editable base-record draft
and, when the source is multi-form, seeds a new two-form draft rather than sharing
the source declaration.

Metadata diagnostics use independent read-only list/get methods. The list DTO owns
search and KR/JP filtering plus asset-completeness checks against the v7 runtime
asset locations. The detail DTO serializes generated metadata and multi-form data
for display only. Flutter composes these values with bundled portrait and eleph
images; no diagnostic action can write a generated declaration.

Single-student SchaleDB import shares the bulk import's minimal snapshot helpers
and source-field allowlist. Source parsing accepts a student URL or slug, resolves
the existing local ID through the same path exceptions, and returns a preview DTO
before any write. Direct apply is limited to existing students; new identities are
editor drafts until the local required fields are completed. Both paths keep gift
catalog persistence separate from student metadata and exclude bond-stat fields.

Server state is an independent generated-data mutation. `metadata.server.set`
validates the student, changes only `JP_ONLY_STUDENT_IDS`, and returns the previous
and next server plus KR asset warnings. The UI confirms this action separately from
base metadata save or SchaleDB import, then refreshes both editor and diagnostic
state.

Multi-slug identity rules live separately in `core/schale_merge_paths.py` and are
managed through `metadata.merge_paths.list/save/delete`. A rule owns at least two
distinct SchaleDB paths; no path may belong to two local students. The first path
is the scalar-field source while all paths participate in reverse local-ID matching.
The Flutter view renders the local portrait with explicit primary/secondary path
chips. These rules merge source identities only and do not import form combat or
student/bond-stat data.

Item statistics are exposed by the read-only `metadata.items.analyze` method. With
no path override it resolves the selected v7 repository profile; explicit v7
profile/inventory JSON and legacy inventory mappings are accepted for developer
comparison, with an optional item-delta JSON. The DTO keeps absent, unknown,
explicit-zero, positive, plan-adjusted-negative, and missing-catalog identities
distinct. Flutter uses the packaged item backgrounds and available item/eleph
icons for rows and presents category coverage without summing unrelated resource
quantities.
