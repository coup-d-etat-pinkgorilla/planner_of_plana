# X4 / FD-182 tutorial practice contract v1

This freezes the DTO and lifecycle **before implementation**. The schema/fixture
commit permits CF's Mock tutorial work. Runtime dispatch, persistence/replay and
Process E2E are a subsequent paired slice. `runtimeImplemented:false` in the
fixture is explicit; these methods currently return unknown_method.

The user's FD-182 replaces the old prefilled practice-account tour: start after
the first real account is created, use an isolated temporary account and virtual
game window, follow the real scan/review/commit/student/plan/scenario/inventory/
statistics UI, then remove the temporary account on completion or dismissal.

## Frozen methods (JSONL protocol 1)

`tutorial-practice-v1.schema.json` and `fixtures/tutorial_practice_v1.json` define
all exact request and response keys. Mutation keys are idempotent: retries retain
the original complete request and return the original result; changed requests
with the same key conflict. Revision integers reject bool and negative values.

| Method | Request payload | Success payload |
|---|---|---|
| repository.practice.create | origin_profile_id, expected_origin_revision, idempotency_key | practice, selected_profile_id |
| repository.practice.current | empty object | practice (or null), selected_profile_id |
| repository.practice.reset | profile_id, expected_revision, idempotency_key | practice, selected_profile_id |
| repository.practice.end | profile_id, expected_revision, idempotency_key, reason: completed or dismissed | deleted_profile_id, selected_profile_id (nullable), already_deleted |
| repository.practice.recover | idempotency_key | removed_profile_ids, selected_profile_id (nullable) |

`practice` is exactly `profile_id,origin_profile_id,is_practice:true,revision,
dataset_version:tutorial-v1,virtual_target_id:tutorial:1280x720`.
Only `is_practice` is used; there is no is_tutorial alias. Existing regular profile
read DTOs gain an **optional boolean is_practice, absent means false** in the
runtime pairing. The current strict repository schema is not silently changed
by this forward-contract commit. Clients cannot set this flag via ordinary
profile.create/update or convert a real account into a practice account.

- Only one tutorial account at a time. create selects it, preserves the real
  origin account and never imports v6 or copies private real account contents.
  Same-key retry returns the original result. A different new create while one
  is active returns practice_session_active; use current/reset/end.
- reset cancels/closes its active virtual sessions, increments/replaces the
  practice revision atomically and restores only the fixed tutorial seed.
  Prior candidate revisions/generations are invalid. The origin account is
  unchanged. Clear frontend pending candidates and event cursors on reset.
- end closes/cancels sessions and deletes **all practice-owned state** (current,
  goals, history, plans/scenarios, tactical/share files, local samples/replay
  working cache), then restores the origin selection. Repeated deletion is
  idempotent. A missing/deleted origin returns a valid normal selection or null;
  never recreates an origin. Apply the existing deletion journal/lock order.
- At backend process startup, recover removes orphan practice accounts before
  normal selection/exposure. Explicit recover is the idempotent retry boundary
  for cleanup. Cleanup failure is surfaced, not relabeled as success. A runtime
  implementation must keep a durable ownership marker to prevent deletion of
  ordinary profiles. It must not use display-name matching or caller paths.
- Normal account lists, real-account aggregates/recommendations and v6 import
  selectors omit practice accounts. While tutorial is selected, its **scoped**
  statistics show its own synthetic history so the statistics step works.
  Nothing enters real-account statistics/recommendation inputs or global sample
  tiers. User data remains outside the installed app tree; X3 migration is a
  separate implementation and does not block this contract.

## Virtual target and replay: existing scanner wire

When the selected profile is practice, `scanner.target.list {}` returns one
virtual target, without enumerating or capturing any native window:
`target_id:tutorial:1280x720`, `title:가상 게임 창 · 튜토리얼`, `status:ready`,
`foreground:false`, `client_width:1280`, `client_height:720`, `game:blue_archive`.
The existing target game enum spelling remains exactly blue_archive. Normal
profiles never see/use this target. Starting it with a normal/missing profile_id
or starting a real native target for a practice profile fails
practice_profile_required. No fallback to real capture/input is permitted.

- Start uses the unchanged scanner.session.start fields: profile_id is required
  for this target; student uses scan_kind:student + student_scan_mode:full;
  inventory uses scan_kind:inventory + inventory_scan_profile:tech_notes or
  tactical_bd. No new scan_kind, replay_path or frontend-only event stream.
- Scenarios are fixed by these parameters and dataset_version:tutorial-v1.
  Replay emits the existing sequenced phase/progress/feedback/candidate/terminal
  events and snapshot/control state. pause/resume/cancel safe-point behavior,
  session/generation, candidate revisions and stale-event guards are preserved.
  Frontend starts inventory sessions sequentially as FD-143 already specifies.
- Candidate get/review/revalidate/commit and FD146 partial approval/needs_review
  use the same service/repository path, **scoped to practice profile only**. Writes
  must refuse cross-profile commit/review, including a real candidate applied to
  practice or a practice candidate applied to real. No training of real samples.
- Seed contains a small previous student/inventory state and one synthetic
  history baseline. Goals and active plans start empty; scenarios start with one
  fixed example, `비나 대비 · 한 번에 MAX`, following the approved tutorial script:
  Kanna (swimsuit)/Maki/Mika priority 1, Shiroko (swimsuit)/Himari (battle)/Neru
  (school uniform) priority 2, Akane priority 3. The learner's plan starts with
  Kanna/Maki/Mika, Shiroko/Himari, Akane in three priority slots. Replayed students contain
  changed/new/review examples; tech notes and tactical BD contain review/unknown
  slots. Missing quantities stay null; no fake0 or runtime installed asset read.
  Content revision 2 preserves `dataset_version:tutorial-v1`: of 60 inventory
  slots, 54 start approved, two tech-note slots (index 26/27, quantities 46/47)
  require approval to reach 56, and four unread quantities remain null. Previous
  inventory contains the first ten tech-note slots: five unchanged, five with a
  quantity five below the replay. Content is synthetic and carries no native
  recognition accuracy claim.
- Existing committed student_full_ring_1280 and tech_notes golden candidate
  fixtures are the starting evidence. **There is currently no tactical_bd golden
  fixture in this suite.** A separately labeled synthetic tutorial scenario must
  be added and validated before runtime release. Do not claim existing native
  golden/accuracy coverage for it or rewrite scanner goldens to create it.
- Target virtuality is determined by practice ownership/target ID, not a new
  arbitrary client flag. Existing event shape and unknown-progress rules remain;
  counts/denominators are supplied only if the fixed replay actually knows them.

## Dart pre-change list for CF

- `frontend/lib/services/repository_service.dart`: RepositoryProfile/read DTO optional
  isPractice default false; PracticeProfile/PracticeSessionState/PracticeEndResult/
  PracticeRecoveryResult DTOs and the five exact methods; repository error decode.
- `frontend/lib/services/process_app_service.dart` and the repository protocol
  decoder in repository_service.dart (AppService exposure in app_service.dart): dispatch/strict decode of
  the five new responses and revision/idempotency inputs.
- `frontend/lib/services/mock_app_service.dart`: isolated one-active-practice
  lifecycle, seed/reset/end/recover and synthetic states; no real profile overwrite.
- `frontend/lib/services/scanner_service.dart`: existing target DTO suffices;
  existing ScannerKind/event/pause enums and start signatures **unchanged**.
  The Mock/AppService supplies the virtual target/replayed existing event shape.
- `frontend/lib/ui/scan/scan_session_controller.dart`: use practice profile scope,
  clear cursors/candidate copies on reset/end, preserve the real review/commit UI.
  Tutorial orchestration/first-account flow/account filtering is CF-owned F3.
- App/profile/repository strict DTO fixtures, Mock lifecycle tests, process restart
  orphan cleanup/cross-profile rejection, scanner replay pause/review/commit and
  controller/widget/golden tests need the same-source runtime paired gate.

No frontend file was edited by XB. Runtime implementation will post exact final
file paths/keys before main overlay. Contract validation alone is not runtime
completion, crash recovery proof or permission to connect unavailable methods.
