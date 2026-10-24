# Startup user-data migration boundary v1

Default user state is copied from the legacy user directory into its `v7/`
child once. Originals are retained. A new UUID staging directory is verified
against before/after file hashes and atomically renamed; incomplete copies are
never exposed as the current repository. Explicit user/storage overrides skip
this default migration. Symlinks/reparse points, pending repository recovery,
active OS locks and unrecognized destinations still block copying.

On Windows, migration filesystem calls use normalized absolute extended-length
drive paths (`\\?\C:\...`) or UNC paths (`\\?\UNC\server\share\...`). This
includes inventory, copy, marker publication, locks and owned-stage cleanup.
The system registry and process manifests are not changed. Relative keys in the
migration record retain their portable spelling; the prefix is an I/O detail.
[Microsoft's path-length documentation](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation)
specifies these forms and their normalization requirements.

If migration fails, the JSONL backend remains available in a restricted startup
state. It does not construct ApplicationProtocolV1, scanner/preparation services
or a normal writable repository. Each trusted request receives the correlated
`user_data_migration_failed` response defined in the adjacent schema. This is a
global startup error, before all method-specific error sets. Success DTOs and
methods are unchanged. Malformed or untrusted envelopes remain ignored.

Details are exactly `reason`, `source_kept:true`, `restart_required:true`. Reasons
are allowlisted. OSError becomes `user_data_io_error`; exception messages, account
data, filenames and absolute paths are not returned or printed. Unknown migration
reasons become `user_data_migration_failed`. After resolving the cause, restart
the backend/app; a request cannot silently switch the blocked process to another
user root. An empty account or fallback writes into the legacy root are not used.

The developer-tool process retains its separate v1 one-shot error shape:
`{version:1,ok:false,error:{type:"UserStateMigrationError",message:...}}` and exit
code 1. It consumes the request before reporting the safe startup failure.

The persistent `.v7-migration.guard` file anchors an OS byte-range lock. Its
existence or age is not evidence of a live/stale lock. The handle owns the lock;
normal exit releases it while retaining the anchor. Leave the file in place.
Deleting an apparently old guard can split synchronization between processes;
the backend and tests do not automatically delete it. Only this invocation's
fresh staging directory is removed on failure. Unknown leftover staging and
original state are preserved for a separate recovery decision.

CF pairing: PlanningProtocolClient accepts the new global code before method
allowlists and validates its exact details. Existing typed success DTOs and Mock
methods are unchanged. Add process coverage with synthetic LOCALAPPDATA or
explicit temporary user/storage overrides. Tests must never use the actual user
directory. Native user-data migration and first-run explanatory UI remain
separate acceptance/CM follow-ups.
