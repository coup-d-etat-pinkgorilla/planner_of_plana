# M6 / X1 release format v1

This is the committed offline packager/launcher boundary. The production update
launcher, actual first alpha ZIP acceptance and user upload are separate steps.
No network, installed client, shared-store write or lock update is performed by
`backend/tools/package_release.py`.

## Files and identity

- `release-latest-v1.schema.json`: exact required keys `schemaVersion:1`,
  `releaseType:app|data`, `appVersion`, `dataVersionId`, `dataSnapshotSha256`,
  `zipUrl`, `sha256`, `notes`, `minLauncher`. Versions are semantic version strings;
  the URL is absolute HTTPS without credentials/fragment; SHA256 is lowercase hex.
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
```

Replace OWNER/REPO/TAG and the version/notes; no upload is automatic. The filename
is `BA-Planner-v7-<mode>-<appVersion>-<dataVersionId>-<snapshotSHA12>.zip`.
`{filename}` is substituted only in this command argument; latest.json contains
the concrete final URL. Publish the generated ZIP and latest.json to those URLs.
The generator also writes `<zip>.sha256`, `.ba_planner_data_snapshot.json` and
`CHANGELOG-data.md` in output-dir. Use release as output-dir for the requested
release sidecars, or a separate debug folder for inspection.

Repeated identical generation produces identical ZIP bytes and one changelog
entry. A published filename cannot be overwritten with different bytes. Notes
cannot silently change for an existing release identity. The ZIP is generated
from pinned file bytes and latest.json is atomically replaced last. Changed
inputs during archiving abort publication. A separate developer_tools bundle
beside the main release is omitted; private repository/log/cache state, developer
writers and unexpected game image/font payloads cause a full-package failure.

FD-181 game pictures must already have been removed from the runtime bundle by
the F2/F5 follow-up. Current UI/recognition images are not silently exported or
marked as ready. The unclassified GyeonggiTitle font is blocked pending a source
decision. M4 manual mappings and the first-run extraction spec remain separate.
Synthetic packaging tests do not satisfy CM's native acceptance decision D.
