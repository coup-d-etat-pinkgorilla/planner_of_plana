# M6 / X1 release format v1

This is the committed offline packager/launcher boundary. The production update
launcher, actual first alpha ZIP acceptance and user upload are separate steps.
No network, installed client, shared-store write or lock update is performed by
`backend/tools/package_release.py`.

## Files and identity

- `latest-app.json` and `latest-data.json` are **independent stable endpoints**.
  Each uses `release-latest-v1.schema.json`: exact required keys `schemaVersion:1`,
  `releaseType:app|data`, `appVersion`, `dataVersionId`, `dataSnapshotSha256`,
  `zipUrl`, `sha256`, `notes`, `minLauncher`. Versions are semantic version strings;
  the URL is absolute HTTPS without credentials/fragment; SHA256 is lowercase hex.
  `releaseType` must match the endpoint. This split supersedes the original single
  `latest.json`; new generation does not write that ambiguous file. The schema of
  each entry remains v1. Publishing one channel preserves the other file's bytes.
- `data-snapshot-v1.schema.json`: `.ba_planner_data_snapshot.json` records the raw
  lock SHA, both server pins and their client-file hashes, each pinned kind's
  provenance SHA and canonical files-map SHA, and the exact shipped
  `backend/data/**` file byte counts/SHA256s. `dataVersionId` is the selected pin
  (`jp` by default). Local store paths and source extract contents are not copied.
- Kind records are **lock references**, not a claim that every shipped field was
  regenerated or independently verified. Manual/KR/legacy residual fields retain
  their existing values/provenance. M3 removal is not implied.
- `dataSnapshotSha256` hashes the exact snapshot JSON bytes. It distinguishes
  regenerated data under the same game pin. A launcher compares this as well as
  app/data versions; a change in the Steam secondary pin is therefore observable.
- `release-package-v1.schema.json` defines the root `release-manifest.json` in
  the ZIP: release type/versions/snapshot SHA and every other archive member's
  portable path/byte count/SHA. The manifest does not hash itself. All other
  members must appear exactly once, with no unlisted members/case collisions.
  Newly generated manifests also record `bundledUiAssets` (boolean). For older
  manifests its absence means false. Only app manifests may set it true.

## App first, then compatible data

The launcher reads `latest-app.json` first and validates its app entry. If
`app.appVersion` is newer than the installed version, automatically install the app ZIP
first, subject to the user's automatic-update setting and version/downgrade policy. Never
apply a data ZIP to make up for a missing or invalid app descriptor. After the
new app starts, check `latest-data.json`. If app versions already match, only
consider a data entry with that **same appVersion** and a different
`dataSnapshotSha256`; a missing data endpoint or a data entry for another app
version means no compatible data update. Comparing the game version alone misses
rebuilds under the same pin. An app mismatch is not permission for a silent
downgrade. `minLauncher`, hashes and staging/rollback still apply. This follows
the user's 2026-10-19 automatic-update decision. An explicit check bypasses the
automatic-update opt-out once, at the next safe launcher invocation; GUI wiring
for that request is a separate paired slice.

Both descriptor URLs must remain reachable independently. Publish the current
app descriptor even when only data is released. If both URLs are assets of the
same GitHub `releases/latest` release, **attach both descriptors on every release**,
carrying forward the unchanged counterpart and its immutable ZIP URL. Keeping a
descriptor only on an older tag does not satisfy that latest-release URL. The
offline packager preserves a counterpart already in output-dir but does not
fetch one or claim a complete publication when that counterpart is absent.

## ZIP layouts and consumer rules

Full `app` ZIP: `BA Planner v7.exe` (explicit distribution launcher input),
`release-manifest.json`, `app/ba_planner_v7.exe`, `app/backend/**`, Flutter native
runtime/data, `app/.ba_planner_data_snapshot.json`, `app/CHANGELOG-data.md`.
The existing C# development launcher is not made update-capable by packaging it;
the first distributable bootstrap ZIP requires the follow-up launcher change.

Data ZIP: `release-manifest.json`, `app/backend/data/**`,
`app/.ba_planner_data_snapshot.json`, `app/CHANGELOG-data.md` only. No launcher,
Python source, EXE/DLL, profile or scanner image is included. `appVersion` is the
**exact compatible installed app version**. A data update cannot jump from another
app version or erase/replace `app/` using this partial tree. The updater must copy
the current app to staging, replace only these declared files, validate the full
staged data inventory, then swap the complete app with rollback. Files that were
removed from the old data inventory are removed only inside staging/backend/data,
based on the previous/new snapshot lists. No user-data directory is a target.
The full current app remains usable until the final swap succeeds.

Before extraction the updater checks minLauncher, ZIP SHA and ZIP membership,
rejects absolute/drive/traversal/linked/duplicate paths, then checks each file and
the snapshot SHA. On mismatch it discards staging and runs the current app. No
launcher self-replacement is attempted while it is running. These are consumer
requirements, not implemented updater behavior in this commit.

## Generator

```powershell
cd backend
py -3.11 tools/package_release.py --mode data --bundle-dir ../release --output-dir ../release --app-version 7.0.0-alpha.1 --zip-url 'https://github.com/OWNER/REPO/releases/download/TAG/{filename}' --notes 'Data release description'
# Full app: use --mode app and add --launcher '../BA Planner v7.exe'.
# Alpha-1 full app with existing UI images: also add --allow-bundled-ui-assets.
```

Replace OWNER/REPO/TAG and the version/notes; no upload is automatic. The filename
is `BA-Planner-v7-<mode>-<appVersion>-<dataVersionId>-<snapshotSHA12>.zip`.
`{filename}` is substituted only in this command argument; `latest-<mode>.json`
contains the concrete final URL. Publish the ZIP/checksum and both independent
descriptor endpoints according to the rule above. CLI output `latestPath` names
the descriptor actually generated in this call; `latest` contains its v1 entry.
The generator also writes `<zip>.sha256`, `.ba_planner_data_snapshot.json` and
`CHANGELOG-data.md` in output-dir. Use release as output-dir for the requested
release sidecars, or a separate debug folder for inspection.

Repeated identical generation produces identical ZIP bytes and one changelog
entry. A published filename cannot be overwritten with different bytes. Notes
cannot silently change for an existing release identity. The ZIP is generated
from pinned file bytes and its channel descriptor is atomically replaced last. Changed
inputs during archiving abort publication. A separate developer_tools bundle
beside the main release is omitted; private repository/log/cache state, developer
writers and unexpected game image/font payloads cause a full-package failure.

CM D-ALPHA-SPLIT (2026-10-20): alpha-1 keeps existing UI images. By default,
Flutter UI images still cause failure; the explicit app-only
`--allow-bundled-ui-assets` flag allows images under
`data/flutter_assets/assets/**` and records `bundledUiAssets:true` in the ZIP
manifest. It does **not** allow `backend/assets/**` recognition images, private
state or developer code. Data mode rejects the flag. It does not mark a user's
recognition cache ready. FD-181 UI extraction/removal and M4 manual449 are alpha-2
(F5), while F2 covers recognition caches only.

The public GyeonggiTitle Medium font at
`data/flutter_assets/assets/fonts/GyeonggiTitle-Medium.ttf` is independently
allowlisted by SHA256. It is not a game extraction. When present, the packager
includes the unchanged `backend/licenses/GyeonggiTitle-LICENSE.txt` source notice
as `app/licenses/GyeonggiTitle-LICENSE.txt` and hashes it in the manifest. A
different font hash/path or conflicting bundled notice fails. The official
[Gyeonggi font use conditions](https://web1.gg.go.kr/contents/contents.do?ciIdx=679&menuId=2457)
permit embedding/distribution with programs and prohibit selling/transferring
the font itself for a fee. No frontend asset is changed by the packager.

M4 mappings and the first-run extraction spec remain separate.
Synthetic packaging tests do not satisfy CM's native acceptance decision D.
