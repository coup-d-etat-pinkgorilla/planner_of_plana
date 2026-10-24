# F2 recognition cache preparation v1

Alpha-1 scope (CM D-ALPHA-SPLIT, 2026-10-20): recognition assets only. Existing
Flutter UI images stay bundled. F5 UI extraction/manual449 is alpha-2. This API
does not run a game process, capture/input, download, decrypt or read key material.
The runtime reads only the selected installed client's plain catalog, bundle
revisions and unencrypted recognition textures/sprites/fonts using the existing
extractor. The first-run frontend is CF-owned.

`asset-preparation-v1.schema.json` is the strict protocol v1 envelope contract.
All request payloads reject unknown keys. There is no arbitrary replay/output
path, force-delete, UI image stage or new scanner kind.

| Method | Request payload | Successful response payload |
|---|---|---|
| `assets.prepare.status` | `{}` | status below |
| `assets.prepare.game_dir.set` | `{path:string|null}` | status; null returns to automatic discovery |
| `assets.prepare.start` | `{}` | `{job_id,generation}` |
| `assets.prepare.cancel` | `{job_id,generation}` | `{job_id,generation,cancel_requested:bool}` |
| `assets.prepare.snapshot` | `{job_id,generation}` | `{job:jobSnapshot}` |

Status exact fields:

- `game_dir`: `path` (selected root/null), `source:auto|user|none`, `valid`,
  `reason` (null or bounded code), `catalog_sha256`, `bundle_revision` (nullable).
  The user override is retained even if a later patch/move makes it invalid.
  Automatic discovery uses the existing Steam libraryfolders/appmanifest logic.
  Validation needs BlueArchive_Data/StreamingAssets/PUB/Resource, a CCDB-v1
  Catalog/Windows/catalog_Windows.bytes and consistent numeric BundleRevision
  files in **all three** Catalog/Preload/GameData folders. Missing, malformed or
  mismatched revisions are explicit reasons; Steam buildid is not substituted.
- `cache`: `state:missing|unknown|invalid|stale|ready|partial`,
  `catalog_sha256`, `bundle_revision`, `icons`, `sprites`, `fonts`, `failed`.
  Unknown/invalid/stale counts are zero and failed is null; these are not a
  successful zero-extraction claim. Ready/partial require the current catalog,
  extractor and rarity identities, mandatory sprites/fonts, safe member paths
  and **every derived file's hash**. Missing optional icons yields partial;
  Start retries partial extraction. Failed extraction preserves the old tree.
- `busy` (preparation or folder change owns the gate), `scanner_busy`, current
  `job` (nullable), `last_result` (nullable, persisted terminal result), `metadata`.
- `metadata`: nullable `data_version_id`, `data_snapshot_sha256`,
  `steam_bundle_revision`, `steam_matches_snapshot`; `jp_update_required:null`.
  These come from the installed app's `.ba_planner_data_snapshot.json` (M6).
  Absence/malformed metadata is unknown. Steam revision disagreement is local
  evidence only; it cannot prove a JP table update is needed. Network latest
  lookup and app/data update choice belong to the release updater.

Folder settings/result are separate atomic JSON files under the existing
resolved repository user-data root (`asset-preparation.json`,
`asset-preparation-result.json`). They survive ZIP replacement. Recognition
cache uses the same `resolve_extracted_asset_root()` as SynthProvider, and the
same catalog-hash directory/manifest; no second extraction tree is created.
These are user-generated local files excluded from distribution. This slice
does not silently migrate current paths to a new `v7` suffix; that remains X3.

## Jobs and UI events

Event method: `assets.prepare.event`. Payload exact job snapshot fields plus
`event_kind:progress|terminal`. Snapshots contain:
`job_id`, `generation`, `sequence`, `state`, `stage`, `done`, `total`,
`unit:"bundles"`, `created`, `available`, `reused`, `failed`, `reason_codes`.

States: running/cancelling then succeeded/partial/failed/cancelled. Stages:
validating/icons/sprites/fonts/complete. `done` is completed bundle work,
**never an icon count**. `total` may be null (sprite/font search stops when its
targets are found); hide denominator/percentage/ETA then. A final known stage
denominator describes only that completed stage, not a predeclared whole-job
total. There is no fixed 1,330 denominator or whole-job percentage.

Before completion `created/reused/failed` may be null; `available` counts only
validated published assets (initially zero). At success/partial, available is
icons+sprites+fonts, created is newly generated files and reused is unchanged
files reused from prior cache. Failed/cancelled counts remain null when exact
counts cannot be established. Missing reasons are summarized as `assets_missing`;
other bounded terminal reasons: cancelled, asset_cache_invalid,
asset_extract_failed, result_not_saved. No original path, key, stack trace or
exception text is emitted in errors. Consumers should use reason codes.

The start response precedes that job's events even for an immediate cache hit.
Per-backend generation and per-job sequence are monotonic. CF accepts only the
selected job/generation and increasing sequences; duplicates/old jobs are
discarded. Recover a gap with snapshot and treat its cursor as authoritative.
Only the current job is retained in memory, plus its last terminal result on
disk; after backend restart there is no resumable old job. Re-query status and
start anew. A stale cursor returns asset_prepare_job_not_found.

Start is an explicit action, not an idempotent restart request: active jobs return
asset_prepare_busy; after completion, another start checks/reuses the cache.
Cancel acknowledges a **request**, not terminal cancellation. Keep controls busy
until terminal/status confirms release. Cancellation is checked between bundles
and individual Unity objects/stages; an in-progress UnityPy decode must return
before cancellation completes. It does not terminate the decoding thread.

## Scanner and publication boundary

The production backend shares one atomic gate between scanner starts,
preparation and folder changes. Any active (including paused) scan rejects
preparation/folder change with scanner_busy. Preparation rejects scan/new prep/
folder changes with asset_prepare_busy. Gate scope is one app backend process;
running multiple independent backend instances over the same user cache is not
a supported coordination mode. No existing scanner event/response keys change.

Extraction stages in a sibling private directory. Cancel/failure removes only
that staging tree; publication renames the old target to a recoverable sibling,
publishes the checked staged tree, and rolls back on replace failure. A crash
between those renames is recovered by restoring the old sibling on the next
extraction. The previous version is pruned only after a new validated cache is
published. Input catalog/revisions/rarity and bundle stats are rechecked before
publication. Readiness is rechecked before announcing successful preparation.

The production scanner's SynthProvider uses the prepared cache loader. It
**never silently extracts during a scan**. If preparation is missing/invalid,
the synthetic tier reports SynthUnavailable and the existing detail/labeling
flow continues; packaged scanner recognition readiness is still the independent
`scanner.recognition.status`. A successful F2 job does not manufacture missing
packaged recognition templates. Legacy direct SynthProvider callers retain
their existing default behavior; the app backend uses explicit preparation.

## CF Dart changes before runtime commit

- New service DTO/interface (suggested `services/asset_preparation_service.dart`):
  strict request validators, status/game/cache/metadata/job/cancel DTOs, bounded
  enums and exact nullable counts; keep scanner DTOs separate.
- `process_app_service.dart`/app service surface: methods above and event stream;
  bind preparation events by job/generation and close subscriptions on restart.
- `mock_app_service.dart`: synthetic missing/stale/ready/partial/failure/cancel
  states, same scan/prep exclusion and start-response/event cursor semantics.
- First-run/settings controller: remember selected root, start/cancel/poll,
  snapshot gap recovery, null denominator handling and no false JP freshness.
- Process/contract/Mock/controller/widget tests: strict unknown-key rejection,
  restart/folder persistence, cursor filtering, busy and cancellation lifecycle.

XB edits no frontend files. Runtime may be committed only after the same-source
CF paired gate; synthetic tests do not establish real-client/native acceptance.
# Test discovery control

`BA_PLANNER_DISABLE_GAME_DISCOVERY=1` disables automatic Steam-library discovery
for process tests. It does not invalidate an explicitly selected user folder.
Tests that use an isolated repository and this flag can query status or clear a
folder override without inspecting an installed game. The default runtime keeps
automatic discovery enabled.
