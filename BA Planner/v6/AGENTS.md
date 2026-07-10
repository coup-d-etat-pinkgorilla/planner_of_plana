# Agent Instructions

## Clarification Discipline

- If requested behavior, scope, data meaning, UI state, compatibility requirements, or acceptance criteria are ambiguous or not explicitly specified, stop and ask a concise clarification question before editing.
- Do not silently choose between interpretations that would produce different user-visible behavior or persisted data.
- Do not invent scan thresholds, ROI values, sorting rules, migration behavior, or planner semantics from nearby code alone.
- A clarification is not required for a purely mechanical choice that follows an established repository pattern and cannot change behavior.

## Start Here

- Read `README.md` for the project map, commands, and documentation entry points.
- Read the relevant `almanac/` page before changing a cross-file flow, persistent data meaning, or a large central module.
- Use `docs/` for detailed algorithms and operational procedures. Use `almanac/` for design intent, invariants, and recurring gotchas.

## Required Reading By Task

- Student viewer, planner, filters, or statistics: read `STUDENT_PLANNER_HANDOFF.md`, `almanac/architecture/runtime-boundaries.md`, and `almanac/decisions/data-bucket-separation.md`.
- Student scanning or recognition: read `almanac/flows/student-scan.md` and the related scanner or matcher tests.
- Item or equipment inventory scanning: read `docs/inventory_scan_algorithm.md`, `docs/inventory_sorting.md`, and `almanac/flows/inventory-scan.md`.
- Student metadata or SchaleDB sync: read `almanac/decisions/generated-student-metadata.md` and inspect `tools/sync_student_skills_from_schaledb.py`, `tools/schaledb_sync.py`, and `tools/student_meta_tool.py` together.
- Large-file refactoring: read `almanac/gotchas/large-module-change-safety.md` before editing.
- Release, updater, or packaging work: read `docs/REPOSITORY_POLICY.md`, `docs/LOCAL_UPDATE_WORKFLOW.md`, and `docs/BETA_TESTING.md`.
- Cloudflare Worker work: also follow `bug-report-worker/AGENTS.md` and retrieve current Cloudflare documentation.

## Generated And Local Files

- Treat `profiles/`, `*.db`, `config.json`, `artifacts/`, `debug/`, `logs/`, `scan_results/`, `build/`, `dist/`, and `release/` as local or generated state. Do not use them as source-of-truth documentation or include them in ordinary source changes.
- Do not edit `__pycache__/` or `*.pyc` files.
- `core/student_meta.py` is the stable runtime lookup API. Generated records live in `core/student_meta_data.py`, and shared type contracts live in `core/student_meta_types.py`. Use the SchaleDB sync and metadata writer tools for bulk metadata changes; do not perform broad hand edits to generated records.
- Treat `templates/` and `regions/` as runtime contracts. Change them only with matching recognition logic, fixtures, and documentation in scope.

## Large File Change Procedure

- Before changing the viewer façade/components, scanner façade/components, `core/matcher.py`, or student metadata API/data, identify direct callers, callback or signal connections, state or file consumers, and related tests.
- Search Qt signals, Tk callbacks, subprocess or status-file communication, string keys, and JSON-driven behavior separately; static import or call graphs may not show them.
- Keep behavior changes separate from file moves or symbol renames whenever possible.
- Add or identify characterization tests before extracting behavior from a large module, then run focused tests and the broader affected suite after the edit.
- Avoid concurrent agent edits inside the same large class or method.

## Documentation Maintenance

- Update `README.md` when entry commands, top-level structure, or documentation routes change.
- Update `docs/` when an algorithm, external contract, build, release, or operator procedure changes.
- Update `almanac/` only for durable decisions, cross-file flows, invariants, and recurring gotchas. Routine renames and facts visible directly in code do not belong there.
- Keep CodeAlmanac manual: do not enable transcript sync, Garden, auto-update, or auto-commit without explicit user approval.
- Every Almanac source entry must cite an existing repository path and be referenced in the page body.

## Windows Editing

- When editing files, use the built-in `apply_patch` tool instead of invoking `apply_patch` through PowerShell or any shell command.
- Do not run shell-based `apply_patch` wrappers on Windows. They can fail under sandbox path and permission checks.

## Korean Text And Encoding

- Korean document content is allowed and preferred when the user asks for Korean text.
- PowerShell mojibake is a console display issue, not a reason to replace Korean content with ASCII-only text.
- Preserve UTF-8 Korean text in source files, Markdown, JSON, and generated documents.
- When Korean output appears broken in the console, verify the actual file content with UTF-8-aware reads, rendered documents, PDFs, screenshots, or application-level inspection instead of rewriting the wording in ASCII.
- Use ASCII explanations only when the user explicitly asks for ASCII-only content or when the target format truly cannot store Unicode.
