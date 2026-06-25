# BA Planner Beta Testing

## Repository Role

`coup-d-etat-pinkgorilla/planner_of_plana` is the release and download repository for beta tests and official releases. Local workspace files stay on this computer; GitHub Releases host the files that testers and released clients download.

See `docs/REPOSITORY_POLICY.md` for the local-only file policy and release repository guardrails.
See `docs/LOCAL_UPDATE_WORKFLOW.md` for the local command checklist used to prepare asset and app updates.

## Distribution Shape

Beta releases are shipped as two files:

- `BA Planner` onedir build, zipped or uploaded as a release folder artifact.
- `ba-planner-assets-<version>.zip`, uploaded to the same GitHub Release.
- Optional `ba-planner-patch-<old>-to-<version>.zip` for incremental asset updates.
- `asset_manifest.json`, either uploaded to the release or to a stable "latest" URL.
- `app_manifest.json`, uploaded to the release and to the stable `latest-app` release for whole-app update checks.

The app does not bundle the large image assets into the exe. On first launch it looks for assets in this order:

1. `BA_PLANNER_ASSET_DIR`, if set.
2. `assets/` next to the exe.
3. The exe folder itself.
4. `%LOCALAPPDATA%\BA Planner\assets\current`.
5. The source checkout, for developer runs.

If assets are missing, the app reads `asset_manifest.json`, opens a small startup progress window, and downloads the asset zip from GitHub automatically. A local `ba-planner-assets.zip` next to the exe is only needed as an offline fallback.

If assets are already installed, the app checks the manifest version. When `manifest_url` is present, it downloads the latest manifest, compares it to `%LOCALAPPDATA%\BA Planner\assets\current\installed_manifest.json`, and applies a matching patch zip first. If the patch is missing or fails, it falls back to the full asset zip.

Whole-app updates are separate from asset updates. The app reads `app_manifest.json`, checks the stable `latest-app` manifest URL, and asks the tester to open the new GitHub Release when a newer `ba-planner-windows-<version>.zip` is available. The app does not overwrite its own running exe.

Managed asset files currently include:

- `templates/`
- `regions/`
- `data/planning/`
- `core/student_meta.py`
- `gui/font/`
- `assets/`

`tools/build_beta_release.py` validates required runtime support assets before writing `asset_manifest.json`. If scanner code starts resolving another support directory from the runtime asset root, add that broad directory to `ASSET_ROOTS` so future files in it are picked up automatically.

## Build

Install build dependencies once:

```powershell
py -3.11 -m pip install -r requirements.txt
py -3.11 -m pip install -r requirements-build.txt
```

## New Student Asset Update Helper

For small updates, prepare only these inputs:

- SchaleDB student slug or URL, for example `hoshino_battle_tank`.
- Template matching image.
- Student portrait image.
- Eleph image.

Then run:

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

The helper will:

- Copy images into `templates/students/`, `templates/students_portraits/`, and `templates/students_elephs/`.
- Build or update the student entry in `core/student_meta.py` from SchaleDB.
- Build `ba-planner-assets-<version>.zip`.
- Build a patch zip containing only changed files when `--previous-manifest` is provided.
- Write `release_notes_<version>.md` with the upload list.

Use `--dry-run` to validate paths before writing, and `--overwrite` when replacing an existing student image.

Build the asset pack and exe:

```powershell
py -3.11 tools\build_beta_release.py --version 0.1.0-beta.1
```

Build a new code/app release after source changes:

```powershell
py -3.11 tools\build_beta_release.py --version 0.1.0-beta.2 --github-release v0.1.0-beta.2
```

This creates both `asset_manifest.json` and `app_manifest.json`. For code-only changes, upload the new `ba-planner-windows-<version>.zip` and `app_manifest.json`; rebuilding assets is still harmless and keeps the release self-contained.

Build a release with an incremental patch from the previous manifest:

```powershell
py -3.11 tools\build_beta_release.py --version 0.1.0-beta.2 --previous-manifest release\0.1.0-beta.1\asset_manifest.json
```

Build only the asset pack and manifest:

```powershell
py -3.11 tools\build_beta_release.py --version 0.1.0-beta.1 --skip-exe
```

The build scripts infer the GitHub repo from `git remote origin`. For this checkout that is `coup-d-etat-pinkgorilla/planner_of_plana`. If you pass `--github-release`, asset and patch URLs are filled automatically. Override with `--github-repo`, `--asset-url`, `--patch-url`, or `--manifest-url` only when needed.

After uploading assets to GitHub Releases, rebuild with the release tag if you want first-run auto-download and update checks:

```powershell
py -3.11 tools\build_beta_release.py --version 0.1.0-beta.2 `
  --previous-manifest release\0.1.0-beta.1\asset_manifest.json `
  --github-release v0.1.0-beta.2
```

Publish the generated artifacts after GitHub CLI authentication:

```powershell
py -3.11 tools\publish_beta_release.py --version 0.1.0-beta.1
```

This uploads `ba-planner-windows-<version>.zip`, `ba-planner-assets-<version>.zip`, and `asset_manifest.json` to `v<version>`, then uploads `asset_manifest.json` to the stable `latest-assets` release used by update checks.
It also uploads `app_manifest.json` to the same versioned release and to `latest-app`, so already-installed beta clients can notice whole-app updates.

Equivalent explicit URLs:

```powershell
py -3.11 tools\build_beta_release.py --version 0.1.0-beta.2 `
  --previous-manifest release\0.1.0-beta.1\asset_manifest.json `
  --asset-url "https://github.com/coup-d-etat-pinkgorilla/planner_of_plana/releases/download/v0.1.0-beta.2/ba-planner-assets-0.1.0-beta.2.zip" `
  --patch-url "https://github.com/coup-d-etat-pinkgorilla/planner_of_plana/releases/download/v0.1.0-beta.2/ba-planner-patch-0.1.0-beta.1-to-0.1.0-beta.2.zip" `
  --manifest-url "https://github.com/coup-d-etat-pinkgorilla/planner_of_plana/releases/download/latest-assets/asset_manifest.json"
```

## Tester Instructions

1. Download `ba-planner-windows-<version>.zip` from the release.
2. Extract the zip.
3. Run `BA Planner.exe`.
4. Wait for the first-run data download window to finish.
5. If Windows SmartScreen appears, choose `More info` and then `Run anyway`.
6. Open the `설정` tab, select or create a profile, open the window list, and choose the Blue Archive window.
7. Open the `스캔` tab and run the needed scan mode. The app will bring the saved Blue Archive window forward before starting the scanner.
8. `전체 스캔` is disabled during beta testing; use narrower scan modes such as `현재 학생`, `학생`, `자원`, `아이템`, or `장비`.

Only download `ba-planner-assets-<version>.zip` manually when the tester needs an offline install or automatic download fails.

## Feedback to Collect

- Windows version and display scaling.
- Blue Archive client type and resolution.
- Whether first launch installed or downloaded assets correctly.
- Any crash message, plus files from `%LOCALAPPDATA%\BA Planner\logs` if present.
- Scan mode used, target screen, and expected vs actual result.
- Screenshot when recognition fails, with private/account information hidden.

## Release Checklist

- Run `py -3.11 tools\configure_release_repo_worktree.py --apply` once in this checkout so tracked local workspace files stay local.
- Run `py -3.11 tools\check_release_repo_hygiene.py` before preparing a release commit.
- Confirm `git status` does not include personal runtime data in the release commit.
- Build asset zip and record the SHA256 printed by the build script.
- When updating from a previous release, build with `--previous-manifest` and upload the generated patch zip.
- Upload the latest `asset_manifest.json` to the stable URL used by `manifest_url`.
- Upload the latest `app_manifest.json` to the stable `latest-app` release used by whole-app update checks.
- Start the built exe in a clean folder with no local `templates/`.
- Verify assets install into `%LOCALAPPDATA%\BA Planner\assets\current`.
- Verify `%LOCALAPPDATA%\BA Planner\assets\current\installed_manifest.json` is written.
- Run at least one app launch, settings-tab profile creation, BA window selection, scan-tab scan path, and planner data refresh.
- Upload exe artifact, asset zip, and release notes to GitHub Releases.
