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
`contracts/fixtures/scanner_protocol_v1.json`. Scanner event JSONL/stdout
multiplexing is not wired yet; protocol diagnostics must remain on stderr when that
transport work is added.
