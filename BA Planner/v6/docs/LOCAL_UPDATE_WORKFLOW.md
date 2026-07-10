# Local Update Workflow

This is the local checklist for preparing BA Planner beta updates before GitHub upload.

## First-Time Setup

Run once in this checkout:

```powershell
py -3.11 -m pip install -r requirements.txt
py -3.11 -m pip install -r requirements-build.txt
py -3.11 tools\configure_release_repo_worktree.py --apply
```

Before every release, check that local workspace files are not visible to Git:

```powershell
py -3.11 tools\check_release_repo_hygiene.py
```

The hygiene check should say:

```text
OK: no local-only files are visible to Git.
```

## Pick the Update Type

Use this rule:

- Student images, templates, scanner fonts, app support images, planning data, or `core/student_meta_data.py` only: prepare an asset update.
- Source code, UI, behavior, dependencies, or executable packaging changed: prepare an app update.
- Both changed: prepare an app update with `--previous-manifest` so the same release also contains asset update files.

## Asset Update

Use this for small updates such as one new student.

Inputs you prepare:

- SchaleDB student slug or URL.
- Template matching image.
- Student portrait image.
- Eleph image.

Dry run first:

```powershell
py -3.11 tools\prepare_student_asset_update.py `
  --schale-source "SCHALEDB_STUDENT_SLUG_OR_URL" `
  --template-image "C:\path\student_template.png" `
  --portrait-image "C:\path\student_portrait.png" `
  --eleph-image "C:\path\Item_Icon_SecretStone_student.png" `
  --version 0.1.0-beta.2 `
  --previous-manifest release\0.1.0-beta.1\asset_manifest.json `
  --github-release v0.1.0-beta.2 `
  --dry-run
```

If the paths look right, run without `--dry-run`:

```powershell
py -3.11 tools\prepare_student_asset_update.py `
  --schale-source "SCHALEDB_STUDENT_SLUG_OR_URL" `
  --template-image "C:\path\student_template.png" `
  --portrait-image "C:\path\student_portrait.png" `
  --eleph-image "C:\path\Item_Icon_SecretStone_student.png" `
  --version 0.1.0-beta.2 `
  --previous-manifest release\0.1.0-beta.1\asset_manifest.json `
  --github-release v0.1.0-beta.2
```

Expected output folder:

```text
release\0.1.0-beta.2\
```

Expected files:

- `ba-planner-assets-0.1.0-beta.2.zip`
- `ba-planner-patch-0.1.0-beta.1-to-0.1.0-beta.2.zip`, if files changed
- `asset_manifest.json`
- `release_notes_0.1.0-beta.2.md`

Upload later with:

```powershell
py -3.11 tools\publish_beta_release.py --version 0.1.0-beta.2 --dry-run
py -3.11 tools\publish_beta_release.py --version 0.1.0-beta.2
```

## App Update

Use this when code, UI, behavior, or packaging changed.

Build the new release:

```powershell
py -3.11 tools\build_beta_release.py `
  --version 0.1.0-beta.2 `
  --previous-manifest release\0.1.0-beta.1\asset_manifest.json `
  --github-release v0.1.0-beta.2
```

Expected files:

- `ba-planner-windows-0.1.0-beta.2.zip`
- `ba-planner-assets-0.1.0-beta.2.zip`
- `asset_manifest.json`
- `app_manifest.json`
- Optional patch zip if assets changed

Upload later with:

```powershell
py -3.11 tools\publish_beta_release.py --version 0.1.0-beta.2 --dry-run
py -3.11 tools\publish_beta_release.py --version 0.1.0-beta.2
```

`publish_beta_release.py` uploads to:

- `v0.1.0-beta.2`: app zip, asset zip, asset manifest, app manifest
- `latest-assets`: latest `asset_manifest.json`
- `latest-app`: latest `app_manifest.json`

## Code-Only Shortcut

If only code changed, still use `build_beta_release.py`. Rebuilding assets is okay and keeps the GitHub release self-contained.

```powershell
py -3.11 tools\build_beta_release.py --version 0.1.0-beta.2 --github-release v0.1.0-beta.2
```

## Versioning

Use monotonically increasing beta versions:

```text
0.1.0-beta.1
0.1.0-beta.2
0.1.0-beta.3
```

GitHub release tags use `v`:

```text
v0.1.0-beta.1
v0.1.0-beta.2
v0.1.0-beta.3
```

## Before Upload

Run:

```powershell
py -3.11 tools\check_release_repo_hygiene.py
py -3.11 tools\publish_beta_release.py --version 0.1.0-beta.2 --dry-run
```

Open the generated manifests and confirm the URLs point to `coup-d-etat-pinkgorilla/planner_of_plana`:

```powershell
Get-Content release\0.1.0-beta.2\asset_manifest.json
Get-Content release\0.1.0-beta.2\app_manifest.json
```

## GitHub Authentication

Uploading requires GitHub CLI authentication. Run once on a machine with browser access:

```powershell
gh auth login
```

If `gh` is not on PATH in this checkout, use:

```powershell
& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe\bin\gh.exe" auth login --hostname github.com --web --clipboard --git-protocol https
```

After authentication, run:

```powershell
py -3.11 tools\publish_beta_release.py --version 0.1.0-beta.2
```

## After Upload

Check these GitHub Release URLs:

```text
https://github.com/coup-d-etat-pinkgorilla/planner_of_plana/releases/tag/v0.1.0-beta.2
https://github.com/coup-d-etat-pinkgorilla/planner_of_plana/releases/tag/latest-assets
https://github.com/coup-d-etat-pinkgorilla/planner_of_plana/releases/tag/latest-app
```

Then test from a clean folder:

- Download `ba-planner-windows-<version>.zip`.
- Extract it.
- Run `BA Planner.exe`.
- Confirm assets install or download.
- Confirm the planner opens as the first screen.
- In `설정`, create or select a profile, open the window list, and save the Blue Archive window.
- In `스캔`, run at least one scan mode and confirm the saved Blue Archive window is brought forward.
