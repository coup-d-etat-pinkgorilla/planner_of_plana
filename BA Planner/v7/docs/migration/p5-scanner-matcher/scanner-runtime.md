# Scanner protocol v1 runtime

`ScannerSessionService` is the headless lifecycle owner. It accepts injected target,
student matcher, inventory matcher, recognition catalog, event sink and P4 repository
ports. Blocking capture/matching runs on a single scanner worker, leaving request
dispatch available for cancel and snapshot calls.

Only one session is active at a time. The service registers `session_id` and a
process-monotonic `generation` before submitting the worker, so a fast first event
cannot create an unknown session. Every event has a strictly increasing sequence.
Snapshots contain the authoritative event history and candidate set.

Consumer policy is:

- wrong session/generation: stale, ignore;
- sequence at or below the cursor: duplicate/out-of-order, ignore;
- sequence above `last + 1`: pause application and request snapshot;
- terminal: accept once, then ignore all later events.

Cancel is idempotent. It sets a cooperative token; matchers and Windows adapters must
check it around waits, capture, navigation, page and field operations. The session
worker emits exactly one `completed`, `cancelled`, or `failed` terminal event and the
event sink refuses post-terminal output.

Candidate scan output remains separate from confirmed current state. Review validates
the complete canonical P3 payload, increments candidate revision and records user
approval. Commit requires session/generation, candidate revision, profile ID,
repository expected revision, and a non-empty idempotency key. Student commit replaces
the same student ID within the profile; inventory commit replaces the canonical
inventory snapshot. P4 alone owns persistence.

The JSON Schema and shared fixture are
`contracts/scanner-protocol-v1.schema.json` and
`contracts/fixtures/scanner_protocol_v1.json`.

## Follow-up production runtime

`WindowsCaptureInputAdapter` lazily enumerates matching HWNDs and reports ready,
minimized and foreground state. Capture uses client-sized Win32 `PrintWindow` with a
GDI `BitBlt` fallback and records the actual image resolution. Click and wheel input
use client-coordinate Win32 messages. Importing the module does not enumerate windows,
capture, inject input or access user storage.

`StudentMatcherAdapter` uses the v6 student portrait ROI and manifest-selected
production portrait templates. `InventoryMatcherAdapter` uses the v6 5x4 grid ROI,
center icon fast comparison, full-slot detail fallback, manifest-backed v6 count
glyph matching and stable-frame overlap for
tail/no-motion detection. The initial production catalog intentionally contains two
student portraits and two inventory icons; unsupported identities remain a documented
coverage risk rather than being silently guessed. Missing or low-margin quantity
glyphs remain `uncertain` and force review; they are never silently zero-filled.

Recognition assets live under `backend/core/recognition_assets`, separate from Flutter
UI assets. `manifest.json` records source version, purpose, scan kind, size and SHA-256.
Readiness fails on missing, corrupt or version-mismatched assets. Account/resolution
adaptive samples are writable local state and are explicitly excluded from packaging.

`JsonlMultiplexer` is the only stdout writer. It buffers session events until the
corresponding start response is queued, writes complete JSON lines from one writer
thread, coalesces only progress under bounded backpressure, and never drops responses,
candidates or terminal events. EOF closes the scanner worker before draining and
stopping the writer; diagnostics remain on stderr.
