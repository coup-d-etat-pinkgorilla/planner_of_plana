# Repository Policy

## Role

`coup-d-etat-pinkgorilla/planner_of_plana` is the public distribution repository for BA Planner beta tests and official releases.

Use this repository for:

- GitHub Release downloads.
- `ba-planner-windows-<version>.zip`.
- `ba-planner-assets-<version>.zip`.
- Incremental `ba-planner-patch-<old>-to-<version>.zip` files.
- The stable latest `asset_manifest.json` used by the app update checker.
- Public beta notes, tester instructions, and release checklists.

Do not use this repository as the day-to-day workspace for personal runtime data.

## Local-Only Files

These files should stay on this computer:

- `config.json`
- `profiles/`
- `*.db` and `*.db-*`
- `artifacts/`
- `debug/`
- `logs/`
- `scan_results/`
- `release/`, `build/`, and `dist/`
- Temporary asset intake folders such as `incoming_assets/`

Some of these files were tracked before this repository became release-focused. For this checkout, run:

```powershell
py -3.11 tools\configure_release_repo_worktree.py --apply
```

That marks the currently tracked local-only files as `skip-worktree`, so Git stops offering them for release commits. To undo it:

```powershell
py -3.11 tools\configure_release_repo_worktree.py --clear
```

## Development Flow

Normal development can continue in this local checkout. Keep source changes local until they are intentionally ready to become part of a beta or official release.

If development needs a separate public or private code repository later, create that repository separately and keep this repository as the release/download channel.

## Release Flow

1. Prepare code and asset changes locally.
2. Build release artifacts under `release/<version>/`.
3. Run:

```powershell
py -3.11 tools\check_release_repo_hygiene.py
```

4. Upload the generated artifacts to GitHub Releases.
5. Keep `latest-assets/asset_manifest.json` updated so beta clients can discover small asset updates.

For the local command checklist, see `docs/LOCAL_UPDATE_WORKFLOW.md`.

## Guardrail

Before pushing release-related commits, the hygiene check should report no local-only files. If it reports source files, review them deliberately and commit only the changes that are meant to affect beta testers.
