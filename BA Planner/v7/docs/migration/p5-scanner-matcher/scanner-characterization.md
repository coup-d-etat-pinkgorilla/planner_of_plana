# P5 scanner characterization

## v6 ownership and entry points

v6 `main.py` owns the presentation thread, creates `Scanner`, starts the scan task,
opens `ScanReviewDialog`, and only then calls autosave/repository code. Student entry
points are `scan_current_student`, `scan_students_v5`/`scan_students_fast`; inventory
entry points are `scan_resources`, `scan_items`, and `scan_equipment`. The large
student/inventory components mix navigation, capture, recognition and progress
callbacks, so v7 must preserve their observed decisions without importing them at
runtime.

The v6 capture boundary is a selected Windows HWND and its client area. Navigation
uses Windows input, waits for stable/menu-specific frames, and checks stop state at
wait, page and field boundaries. `capture.py` imports Win32/Pillow-related runtime
facilities and is not safe as a headless protocol import. P5 therefore keeps target,
capture/input, matcher and asset catalog behind injected ports.

## Recognition behavior to preserve

- Student matching narrows candidates with attributes/templates and uses detail
  panels and full candidate sets as fallback. A weak match or failed/absent field is
  evidence for review, never automatic confirmation.
- Inventory uses the grid/icon/count path only with sufficient score, margin and
  count evidence. Detail/name matching is the conservative fallback.
- Inventory profile ordering and the displayed row order are data contracts. Scroll
  overlap is established from stable captures; terminal, near-zero overlap and
  uncertain overlap are distinct outcomes.
- Missing inventory entries may be zero-filled only when ordered evidence proves the
  gap. A missing region/template or uncertain terminal must not become a zero.
- Adaptive samples are written only after reviewed confirmation and are scoped by
  account and actual capture resolution. They are writable local data, not release
  assets.

## Status, cancellation and save mapping

v6 reports string/progress callbacks while scanning and repeatedly calls
`_stop_requested()`. It can produce partial objects, but `main.py` separates result
review from autosave. Review-required rows are edited/confirmed in
`ScanReviewDialog`; rejecting review skips save.

P5 represents those boundaries explicitly:

1. A worker emits versioned phase/progress/candidate events.
2. Each candidate contains canonical P3/P4 payload plus per-field evidence.
3. Uncertain, failed, or missing-region evidence forces `review_required`.
4. Review creates a new candidate revision and audit record; it does not overwrite
   the original observation silently.
5. Only a separate commit request invokes P4 repository methods with repository
   revision and idempotency checks.

Student candidates map to `ConfirmedStudent`; inventory candidates map to
`InventorySnapshot`. Static metadata, user goals, planning totals and shortage never
enter scanner candidate/current payloads.

## Migration classification

| v6 concern | P5 treatment |
| --- | --- |
| HWND/client-area capture and safe input | isolate in Windows adapter |
| student and inventory confidence/fallback | port with parity fixtures |
| progress/stop callbacks | versioned event and cancellation token |
| review dialog | typed candidate review protocol |
| autosave/direct persistence | replace with explicit P4 commit port |
| `regions/`, production templates | copy only manifest-selected assets |
| debug crops, cache, profile samples | exclude from release assets |
| Tk/Qt/PySide presentation orchestration | exclude from P5 backend |

The follow-up ports the minimum production vertical slice with Win32 client capture,
safe input messages, v6 ratio regions and selected real PNG templates. Fixture tests
compose those production PNGs into 1280x720 captures and execute the same adapters used
by the backend process. This verifies adapter mechanics and conservative review
behavior, but it is not full v6 catalog/algorithm parity and is not a live-game smoke.
The deliberately small supported catalog and absent inventory count OCR remain explicit
follow-up risks.
