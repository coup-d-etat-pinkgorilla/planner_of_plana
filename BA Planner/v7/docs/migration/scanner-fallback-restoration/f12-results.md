# F12 integrated validation, release, and completion gate

## Verdict

F12 implementation, production-process integration, 1280/2560 game validation, full regressions,
the Windows release build, and the final D2 resize check are complete. The overall F0-F12 restoration
workflow is **complete**. After three successful 16:9 live scans, the user accepted the absence of a
naturally occurring low-score T10/70 sample and the disabled native2560 special-inference branch as an
acknowledged risk. Synthetic corruption remains separate and is not presented as natural evidence.

No final retained trace contains a confirmed wrong student or item. Scanner candidates stayed in
memory for review only: review, revalidation, repository commit, profile write, persistent learning,
growth, equipment change, purchase, and consumable actions were all zero.

## F12 changes

- Added `f12-integration-contract.json`, an R01-R24 audit tool/test, and a reproducible process-summary
  tool. The final audit resolves code, fixture, focused test, result document, and coverage/limitation
  for all 24 rows: 24/24 passed.
- Added a real `ProcessAppService` probe that starts the production Python backend and records typed
  events, candidates, evidence, terminal state, and mutation counts.
- Added the typed `inventory_scan_profile` request field across Dart and Python. It is allowed only
  for inventory scans and remains separate from the account `profile_id`.
- Updated item preparation for the current game display dialog, which exposes basic/name/quantity/
  expiry and direction controls rather than v6 category checkboxes. Blank legacy coordinates are no
  longer clicked.
- Restricted inventory recognition with a global foreign-item check and positive profile-membership
  proof. Non-monotonic current display order now retains verified entries as partial, blocks zero-fill,
  and does not turn correct review data into a terminal failure.

## Evidence partitions

Historical JSON diagnostics were rerun into `debug/scanner_f12_replay` and remain distinct from new
frames. They produced 224 candidates: 142 dependency-missing, 77 verified, and 5 suspicious. Fixed
feedback replay remained 38/38 and the level archive result remained 10. These figures are diagnostic
replay, not new live accuracy.

The F7 D2 audit replays 24 independent native1280 slots with 24 correct direct reads. Its separate
synthetic partition has 120 perturbations, five eligible T10/70 recoveries, zero false inference, and
321 negative cases with zero false inference. No naturally weak T10 was found in the independent
originals. The synthetic result is not described as natural recovery coverage.

New process traces:

| Trace | Result | Candidates | Elapsed | Event gap p50 / p95 / max |
|---|---:|---:|---:|---:|
| student single, native1280 | completed | Mika 1 | 20.006 s | unavailable in first probe revision |
| student full, native1280 | time-cancelled with retention | 10 | 45.740 s | 0 / 335 / 5026 ms |
| student multi-form, native1280 | completed | Hoshino(Battle) forms 2 | 21.077 s | 0 / 1206 / 5636 ms |
| inventory presents, native1280 | time-cancelled with retention | 1 candidate, 2 entries | 20.359 s | 512 / 6340 / 6340 ms |
| student single, native2560 | completed | Mika 1 | 14.718 s | 0 / 218 / 3441 ms |
| inventory presents, native2560 | time-cancelled with retention | 1 candidate, 3 entries | 35.305 s | 4568 / 8567 / 8567 ms |
| student single, resized 1280x720 client | completed | Mika 1 | 13.419 s | not summarized |
| student single, resized 1079x607 logical client | completed | Mika 1 | 18.952 s | not summarized |
| student single, resized 960x540 client | completed | Mika 1 | 19.890 s | not summarized |

Both student single traces read Mika as level 90, bond 74, star 5, skills 5/10/10/10, weapon
level 60/star 4, potential 25/25/25, and all three equipment slots as T10/70. The native2560 trace
used zero `equipment_level70_t10` inferred observations: normal direct recognition succeeded while
the unvalidated special branch stayed closed. The remaining student validation issue is one expected
stat-calculation dependency, not a mismatched computed value.

The native1280 presents trace retained `Item_Icon_Favor_Random=8` and
`Item_Icon_Favor_Selection=197`. The native2560 trace additionally retained
`Item_Icon_Favor_Random_Lv2=18`. Both are partial/cancelled review candidates and contain no zero-fill.
The full failed-attempt and correction history is recorded in `f12-attempt-history.json`; superseded
wrong review-only inventory candidates were never reviewed, revalidated, or committed.

The final D2 resize check used three independently applied 16:9 client sizes. The 1079x607 observation
is the DPI-scaled logical capture of a 16:9 window and differs from the exact ratio only by integer
rounding. Every run completed on Mika and read all three equipment slots as T10/Lv70. No run emitted
`equipment_level70_t10` inference evidence, so direct recognition remained sufficient. The only
unrelated inference was `independent_weapon_flag` for student star in the 1079x607 run. Review,
revalidation, and commit mutations were zero in all three runs. The machine-readable decision is in
`f12-d2-resize-validation.json`.

The production process event contract records field fallback entry/success/failure via evidence
status/source and records event latency, but does not export a cumulative raw click/recapture counter.
Bounded click/recapture counts and failure injection remain covered by the F1-F11 focused tests and
their preserved live result documents. This instrumentation limitation is explicit rather than
reconstructed from expected control flow.

## Resource cleanup and release

The full-scan resource sample has 122 observations. Working set was 88,469,504 bytes initially,
92,762,112 bytes finally and at maximum. Private memory was 76,079,104 bytes initially,
80,224,256 bytes finally and at maximum. Handles were 187 initially, 188 finally and 189 maximum.
After the probes no v7 backend Python process remained.

Final validation:

- Python: 533/533 passed in 289.278 s.
- Flutter analyze: no issues in 39.5 s.
- Flutter tests: 400/400 passed sequentially in 3:38.
- Windows release: `flutter build windows --release` passed; the synchronized bundle fingerprint is
  current.
- Bundled recognition assets: ready, manifest version 1, 3051 assets, zero missing, zero corrupt;
  supported resolutions include 1280x720, 1920x1080, and 2560x1440.
- Launcher SHA256: `D640555C2C29FC642C95621E68B0BBF55823670846A40C2C5ED2A097F052D4A9`.
- Release executable SHA256: `595C72C80584917383A4FFA0D646906D302CDD4614A1EA147A917808DDA84715`.

## Acknowledged risk

A naturally occurring frame with direct T10 confidence in `[.55, .60)` was still not observed, and
the native2560 special-inference branch remains disabled. This limits evidence for the recovery branch
but does not affect the direct-recognition results in the three final 16:9 checks. Per the user's
2026-09-01 acceptance instruction, this is retained as an acknowledged risk rather than a completion
gate. The safe shipped behavior remains: native1280 inference is narrowly gated, native2560 inference
is disabled, and uncertain observations stay partial instead of being promoted.
