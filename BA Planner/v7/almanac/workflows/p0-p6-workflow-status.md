---
title: "P0-P6 Workflow Status"
summary: "새 대화에서도 P0~P6 작업의 정의, 진행 상태, 산출물과 다음 행동을 복원하기 위한 활성 진행 기록입니다."
topics: [workflow, architecture, migration]
sources:
  - id: agent-instructions
    type: file
    path: AGENTS.md
---

# P0-P6 Workflow Status

### 2026-08-23 S3B actual tier-ROI bank production-selected

- Status: two additional exact 1280x720 sequences provide Airi (Band) T1-T10 for
  Hat/Hairpin/Charm and Kanna T1-T10 for Gloves/Badge/Watch. Combined with Haruna (Sportswear)
  Shoes/Bag/Necklace, the actual basic-screen bank now contains all 9 families x 10 tiers = 90
  fixed 70x40 inner ROIs. Source files and SHA-256 are retained in the generated metadata; only the
  recognition ROI atlas, not full screenshots, enters runtime assets.
- By explicit user decision, a new identity-disjoint T1-T10 validation capture set is not required:
  v6 already verified that game equipment icons occupy the exact same position. This waiver applies
  to the fixed tier-icon ROI bank, not to unrelated scanner fields or non-exact resolutions.
- Runtime loads and prepares the 90 actual ROIs once, then compares only the metadata-selected
  family's ten tiers. Score threshold is 0.65 and top1 margin is 0.08. The former background plus
  inventory-icon synthesis remains only as a missing-bank/uncertainty fallback and is no longer the
  normal path.
- Gate results: 90/90 template tiers correct with wrong 0, minimum margin 0.129761. The already
  available identity-independent Kurumi T2 plus Mika/Hibiki T10 regression is 30/30, wrong 0 and
  direct-source 30/30, with minimum score/margin 0.999764/0.144884. Kurumi Necklace T2 is therefore
  resolved. Warm one-ROI p50/p95 is 1.960/2.269ms; bank preparation is 52.269ms, recognizer cold
  construction 91.631ms and prepared memory 1,310,400 bytes.
- Recognition assets increase from 1,115 to 1,117. The 38-test S3/S3B/asset/stdio set and full
  backend 203/203 pass. The production level path remains the 19-mask position bank; S4/S5 remain
  untouched.

### 2026-08-23 S3B direct tier-ROI pilot passes three families

- Status: the user proposed replacing per-read `background + inventory icon` synthesis with direct
  comparison against fixed actual basic-screen icon ROIs. Fourteen exact 1280x720 screenshots were
  accepted from `S3B_SHOE_BAG_NECKLACE_SAMPLE`: Haruna (Sportswear) supplies one T1-T10 template
  screen for Shoes/Bag/Necklace, and four Kurumi T2 screens form an identity-independent validation
  split. The source folder is read-only; its 42 inner 70x40 ROIs are stored only in a test fixture.
- On Kurumi's 12 validation ROIs, the current synthesized reader confirms 8/12 and falls back on all
  four Necklace T2 observations. Direct actual-ROI correlation confirms 12/12 with wrong 0,
  minimum score 0.999900 and minimum margin 0.502763. Necklace margin improves from 0.035068 to
  0.502763. All 30 template tiers are self-consistent with minimum top1 margin 0.354209.
- The prepared-feature direct variant also returns 12/12 with wrong 0, minimum margin 0.144884 and
  warm one-ROI p50/p95 2.233/2.386ms, compared with synthesized p50/p95 51.928/52.810ms. Its 30
  prepared templates use 436,800 bytes. RGB-mean-only is faster at 0.766/0.848ms but Necklace's
  0.039230 margin is too narrow to select as the production variant.
- Decision: the direct actual-ROI design is technically validated for the three pilot families but
  remains diagnostic. Production code and the synthesized fallback are unchanged until Hat,
  Hairpin, Charm, Gloves, Badge and Watch receive T1-T10 template coverage and an identity-disjoint
  validation split covers all nine families. The new S3B fixture regression passes 16/16 focused
  tests. S4/S5 remain untouched.

### 2026-08-23 S3B fixed-position level bank promoted

- Status: the five newly supplied screenshots were reviewed. Four are exact 1280x720 and cover
  levels 10-19, including every ones digit 0-9 in all three slots; the 2560x1440 10/11/12 frame is
  retained as diagnostic evidence only. Under the user's fixed-font, fixed-shear, fixed-position and
  prior v6 visual-mask verification decisions, no further per-digit capture is required.
- Runtime now loads one compact v7-owned bank with 19 masks: first-position digits 1-9 and
  second-position digits 0-9. It contains 1,330 prepared bytes (5,751-byte JSON), uses the accepted
  v6 text-layer renderer only to build the masks, and contains no source screenshot pixels. The
  matcher requires exactly one tall fill component in each occupied cell so external icon/background
  contamination cannot be silently accepted.
- The fixed-position path is production-selected for equipment **level** only. It runs after
  empty/locked/family/tier and before the legacy generated/menu fallbacks. Low score/margin,
  contamination, blank misuse and invalid tier-level pairs still fall back safely. The older
  equipment-menu binary and whole-string generated variants remain diagnostic/fallback paths.
- Frozen replay is 349/349 top-1 and 349/349 accepted-correct with accepted-wrong 0 and fallback 0;
  exact 1280x720 is 30/30. Minimum score/margin are 0.654438/0.086389. Six integration frames reduce
  equipment-menu calls from 6 to 0, leave no unresolved slot, and build no whole-string templates.
  Cold recognizer construction is 36.288ms, bank load 0.462ms, and one-ROI warm p50/p95 is
  2.768/3.206ms.
- Verification: the focused 35-test set passed; the full backend suite passed 200/200 before the
  final component-contamination guard, followed by the guard-specific S3B suite passing 15/15 and
  the unchanged 349/349 benchmark. Runtime recognition assets now total 1,115.
- Remaining boundary: Kurumi Necklace T2 is still a separate tier-icon rejection (T2 top-1,
  score 0.493740, margin 0.009946). This does not block the level fast path but does block claiming
  full S3B end-to-end production completion. S4/S5 remain untouched.

### 2026-08-22 minimum matrix representatives corrected from the actual v6 account

- The earlier Shiroko/Hoshino/Ako proposal was not executable because those students are already
  developed. The read-only v6 account database was therefore evaluated at SHA-256
  `4b5a2052cf45cd89117eb4d219bef4cfb4e6bf1e8c5129de03e9c8d5a099f011`.
- Calibration now uses Airi (Band), Haruna (Sportswear), and Kanna. Their current equipment states
  are respectively T1/Lv1 in all slots, empty in all slots, and T1/Lv1 plus two empty slots. They
  are already student level 20+, so all equipment slots are unlocked.
- Independent validation uses Chihiro, Marina (Qipao), and Tsurugi (Swimsuit), whose states are
  respectively T1/Lv1 in all slots, empty in all slots, and T1/Lv1 in all slots. The two trios are
  identity-disjoint, and each trio covers all nine equipment families exactly once.
- The 30-row factorized lower bound and 60-configuration/180-PNG two-split total are unchanged. The
  12/23/34 anchor moves from Shiroko T4 to Airi (Band) T4. Production flags remain false; S4/S5 are
  unchanged.

### 2026-08-22 exact 1280 equipment matrix reduced to a proven 30-screen core

- Status: the user-proposed mixed-slot approach (`12/23/34`) is valid when coverage is factorized
  along the runtime boundary. Tier recognition is family-specific, while generated level glyph
  recognition is slot-specific and family-independent.
- Nine families times ten tiers require 90 family-tier observations. Three independently readable
  slots per screenshot give a lower bound of 30 screenshots. A generated 30-row matrix reaches the
  bound while every slot covers one-digit 1-9, tens digits 1-7, ones digits 0-9, all ten tier maxima
  and the 12/23/34 plus 56/65 confusion pairs.
- The executable v6-account calibration/validation representatives are recorded in the correction
  entry above. All three slots advance monotonically T1→T10, and the calibration T4 anchor is
  exactly 12/23/34. Three stable repeats require 90 PNGs per split.
- The identity-independent validation trio also covers all nine families without overlap. The
  minimum production-quality two-split plan is 60 configurations/180 PNGs. Repeated
  frames from calibration are not validation independence.
- The earlier 1,335 configurations remain the Cartesian exhaustive option only if every family must
  be directly paired with every valid level. Production flags remain false and S4/S5 are unchanged.

### 2026-08-22 exact 16:9 S3B evidence policy and 1280 matrix fixed

- Status: by user decision, non-16:9 and non-exact-size screenshots are excluded from calibration,
  validation and production promotion evidence. The prior 1275x720/1276x752 replay remains a scale
  diagnostic only; its Aris Lv65→Lv6 result is not a promotion failure until reproduced at exact
  1280x720.
- Exact 1280x720 exhaustive coverage contains 4,005 equipped atomic cases: nine families times 445
  valid tier-level pairs. Shiroko (Hat/Hairpin/Watch), Hoshino (Shoes/Bag/Charm) and Ako
  (Gloves/Badge/Necklace) cover all nine families without overlap.
- Advancing all three slots together requires 445 configurations per representative, or 1,335
  configurations total. Three stable repeats require 4,005 PNGs. Fourteen physically valid
  empty/equipped/locked patterns, five unlock boundary probes and six favorite states add at most
  75 PNGs at three repeats, for a non-deduplicated upper bound of 4,080.
- Seven unresolved-slot masks and invalid tier-level/blank/partial-digit cases are deterministic
  synthetic tests, not live accuracy denominator samples. Exact dimension, border/padding/letterbox
  rejection and capture metadata are specified in
  `docs/migration/student-scan-v7-s3b-1280x720-equipment-coverage.md`.
- Production remains disabled. Current valid exact-1280 evidence covers Lv70 only, so non-Lv70 exact
  1280 coverage, independent calibration/validation, the existing 2560 Kurumi T2 tier miss, cold
  optimization, fallback reduction measurement and explicit master acceptance remain open. S4/S5
  remain untouched.

### 2026-08-22 S3B low-resolution diagnostic (superseded as promotion evidence)

- Status: this entry preserves the diagnostic result, but the later exact-16:9 policy supersedes its
  use for promotion decisions. Kurumi and Niko recognition assets now exist and pass catalog integrity. Their separate
  T2 repeat captures pass the student gate as `niko` at score/margin 0.989095/0.165600 and
  `kurumi` at 0.985231/0.169860. The template-source T1 captures themselves score 1.0 and are not
  treated as independent identity evidence.
- Replaying the six 2560x1440 promotion screens now resolves the former student gate: all 6/6
  identities are correct. Icon tier is confirmed for 17/18 equipment slots; Kurumi T2 slot 3
  identifies T2 as top-1 but is rejected at score 0.493740 and margin 0.009946. Generated fill is
  correct on all 17 tier-eligible levels; the full end-to-end result is therefore 17/18, not 18/18.
- The BA archive contains eight 1275x720 client-area captures and two 1276x752 framed captures,
  not additional exact 1280x720 PNGs. Manual review identified 11 tier-eligible level-bearing
  observations in the 1275x720 set: generated fill accepts 6 correctly, accepts three real Lv65
  values incorrectly as Lv6, and falls back on two real Lv1 values. Three additional tier-eligible
  blank/non-level crops all fall back, so this replay has no blank false positive.
- The Lv65 failure reproduces in all three generated variants and all three equipment slots. Fill
  accepts Lv6 at score 0.749681-0.768803 and margin 0.207606-0.222588, so threshold adjustment alone
  cannot safely repair it. The current near-white/tall-component extraction loses the second digit
  at this client scale.
- Frozen 334 remains 334/334 for generated fill and the 12 S3B plus 6 asset/stdio tests pass. The
  latest benchmark measured cold menu+fill construction 261.390ms, fill preparation 219.656ms,
  and warm three-slot p50/p95 6.935/8.398ms; timing remains an optimization gate.
- Decision: production promotion is rejected and both production flags remain false. Before another
  review, fix scale-aware two-digit preservation and the Kurumi Necklace T2 tier miss, add the
  1275x720 set as a portable reviewed regression, pass an independent calibration/validation split,
  reduce cold cost, measure fallback/menu-call reduction, and obtain explicit master acceptance.
  S4/S5 remain untouched.

### 2026-08-22 student portrait AP-bar exclusion implemented

- Status: all 254 existing `student-template` portrait assets now exclude the 82px top resource
  bar. The templates remain identity crops and no Kurumi/Niko portrait was synthesized or added by
  this migration.
- `student_texture_region.y1` moved from `0.0082` to `0.0653`, corresponding to y=94 on the
  2560x1440 reference frame. This keeps the old crop's 12px origin plus the removed 82px bar and
  also places current captures below the relocated AP icon and the full resource bar.
- The recognition manifest now records each portrait as an adapted v6 source and carries refreshed
  byte counts/SHA-256 values. The region asset integrity fields were refreshed as well. The
  developer-tool extractor automatically uses the revised region for future Kurumi/Niko and other
  portrait extraction.
- Verification: 58 focused tests pass: asset readiness/all-template height, production adapters,
  the S2 fixed screen, S3/S3B equipment regressions and the developer-tool extraction boundary.
  Two direct current-UI Saori (Swimsuit) repeats match at 0.988101-0.988759 confidence with
  0.153849-0.154296 margin. S3B production promotion and S4/S5 are unchanged.
- Follow-up correction: the revised 2560x1440 extractor initially produced 647x529 because
  `y2=0.4329` rounded to 623. The top boundary remains y=94; only the bottom boundary moves to
  y=624 (`y2=0.4333`), making new Niko/Kurumi outputs 647x530 without reintroducing the AP bar.
  Both portraits were re-extracted from the reviewed current-UI captures; each now matches its
  source repeat at confidence 1.0 with margin 0.173892. The catalog now contains 256 student
  templates and 1,114 total recognition assets.
- A second normalization pass found 11 legacy RGBA/RGB sources whose original height was 611px.
  Those assets now remove 81px rather than 82px, preserving the complete portrait while excluding
  their shorter top bar. All 256 student templates are therefore exactly 647x530; provenance records
  the per-source 81px or 82px removal and manifest integrity values are refreshed.

### 2026-08-22 S3B generated text-layer glyph shadow implemented

- Status: the user-directed continuation of S3B is implemented and remains shadow-only. Production
  enablement, fallback suppression and S4/S5 were not changed. Runtime now emits a separate
  `equipment_generated_binary_shadow` observation in addition to the existing menu-derived binary
  shadow; neither observation is confirmed or copied into candidate payload values.
- The v7-owned renderer creates a transparent text layer with the accepted v6 font, white fill,
  1px navy outline, -0.25 shear and the existing level ROI transform. Screen extraction uses the
  near-white fill as a locality seed, rejects short card/icon components, and can derive outline,
  fill+outline and fill masks without retaining background or equipment-icon pixels. Full level
  strings are normalized to one 40x28 bitset, so real single digits are no longer cut at the old
  24px cell boundary.
- The six reviewed promotion screenshots were exported, with source SHA-256 verification, to a
  portable 432x72 test-only atlas containing 18 ROIs. It covers T1 levels 1/8/9 and T2 levels
  12/16/18 across Kurumi, Niko and Saori (Swimsuit), all three slots, without copying source pixels
  into runtime recognition assets.
- Frozen replay now covers 334 level pairs: the prior 298 archive ROIs, 18 Mika/Hibiki exact
  1280x720 Lv70 pairs and the 18 new exact 2560x1440 probes. The old menu bank produced top-1
  325/334 and accepted 316/334 with 18 fallbacks. Generated outline produced top-1 334/334 and
  accepted 331/334; fill+outline produced top-1 334/334 and accepted 310/334. Generated fill
  produced top-1 and current-gate acceptance 334/334, accepted-wrong 0 and fallback 0, with minimum
  score 0.616097 and minimum margin 0.065519.
- Generated fill is only the benchmark lead, not a production-selected variant. No threshold was
  changed, and the frozen 334 pairs are not authorized for threshold calibration. Production still
  requires an independent calibration set, non-Lv70 exact 1280x720 repeats and an explicit master
  decision. Niko/Kurumi student recognition assets are also required before all new screens count
  as end-to-end scan evidence.
- A single slot-independent fill bank contains 70 whole-level bitsets/9,800 bytes. Outline and
  fill+outline are created lazily for the comparison tool; all three variants total 210 bitsets/
  29,400 bytes. Measured cold construction with menu+fill was 206.438ms, fill preparation 173.055ms,
  and warm three-slot fill matching p50 4.525ms/p95 4.925ms; full-size reference canvases remain 0.
  Cold preparation therefore remains an optimization gate before production promotion.
- Verification: 12 S3B tests and the 38-test S2/S3/S3B/asset/stdio set pass. The full backend run
  executed 198 tests and retained exactly the known out-of-scope baseline: seven missing
  Aru/Eimi/Kotama stat-catalog errors and one Hoshino gift assertion. No new failure was introduced.

### 2026-08-21 S3B generated-glyph template experiment added

- Status: template provenance was audited after the user noted that v6 generated comparison cards
  were built from background + equipment icon + rendered level text. No matcher implementation or
  production flag changed; this entry records the next S3B experiment and acceptance boundary.
- The current S3B binary bank is not the inventory-grid bank. It contains 54 byte-identical copies
  from v6 `templates/equip{slot}level_digit{position}/`; 51 numeric files are loaded and three `v`
  markers are excluded. These are equipment-menu, slot/position-specific assets, not student basic
  detail-screen glyphs. The inventory `templates/inventory_count/` assets, fixed RGB mask, six-digit
  geometry and `x`/`k` rules were not copied.
- The user's accuracy concern is accepted: although the source is not the grid, reusing equipment-
  menu digits across screens creates a domain mismatch in scale, antialiasing and placement. The
  new real T1/T2 probe confirms it: centered single digits are split incorrectly, while 12/16/18
  retain correct top-1 shapes but fall below the current confidence gates.
- The v6/v7 generated path renders white text with a 1px `#505878` outline, -0.25 shear and bicubic
  antialiasing after composing a 200x160 equipment card. The existing dark-ink extractor primarily
  sees the navy outline rather than the white fill, so the outline must not be removed by assumption.
- Decision: add an S3B generated-glyph experiment. Preserve the renderer's slot placement and quad
  transform, but retain only the transformed text layer so background/icon pixels cannot enter the
  binary template. Compare outline-only, fill+outline, and fill-only variants against the current
  menu bank and the existing full-composite generated matcher. Outline-only is the lead hypothesis,
  not an accepted production choice.
- Single digits must be parsed from the full level ROI with a foreground bounding box or connected
  component; only detected two-component glyphs may be split into digit positions. Template and
  threshold calibration data must remain separate from the frozen validation sets. Promotion still
  requires zero false positives when replaying the prior 316 accepted pairs plus 18 new probes,
  exact non-Lv70 1280x720 repeats, fallback/performance measurements and explicit master acceptance.

### 2026-08-21 S3B production-promotion probe remains shadow-only

- Status: six new exact 2560x1440 screenshots were added to the read-only BA archive. They provide
  three independent student repeats of T1 levels 1/8/9 and three repeats of T2 levels 12/16/18.
  This closes the requested *sample availability* gap for position-2 digits 2/6/8 and a real
  single-digit layout, but it does not pass the matcher gate.
- On the nine T1 ROIs the current fixed two-cell split did not model the centered one-digit layout.
  Candidate pairs were 15/31/45, 15/38/47 and 12/38/47 instead of 1/8/9, so 0/9 level pairs were
  acceptable. The existing synthetic blank test is therefore not evidence for a real blank.
- On the nine T2 ROIs the top-1 candidates were 12/16/18 on all three repeats, but 0/9 passed the
  current score/margin gate. Scores were 0.488096-0.499431, below the 0.52 threshold; the 16 and 18
  samples also had margins 0.019369-0.034806 below the 0.04 margin gate. Global thresholds must not
  be lowered because that would overlap the previously accepted archive boundary.
- The end-to-end runtime gate accepted student ID/family/tier only for the two Saori (Swimsuit)
  captures (6/18 ROIs). Niko and Kurumi were below the student matcher gate on four captures
  (score 0.788055-0.798752, margin 0.004795-0.006418), so their recognition templates must be added
  and independently checked before these screens can count as production end-to-end evidence.
- The archive analyzer was corrected to read icon tier whenever the student family is known, before
  applying the binary level gate, matching production runtime order. This separates tier success
  from binary rejection on low-tier samples.
- Decision: `binary_production_enabled` stays false; generated/menu fallback and S4/S5 remain
  unchanged. Promotion now requires a center-aware single-digit parser with real 1/8/9 support,
  improved real-sample normalization/templates for 12/16/18 without threshold relaxation, Niko and
  Kurumi student assets for end-to-end repeats, a zero-false-positive replay of all accepted and new
  probes, and non-Lv70 exact 1280x720 repeats. An explicit master acceptance decision remains last.

### 2026-08-21 S3B screenshot archive validation complete

- Status: the user supplied `C:\Users\brigh\Pictures\Screenshots\BA` as an additional read-only
  validation source. Its 194 PNGs were inventoried and screened through the runtime order of student
  ID, metadata family, icon tier, then binary shadow level. S4/S5 and production behavior remain
  untouched.
- The archive contains 179 exact 2560x1440 images plus 15 nonstandard/cropped dimensions. The
  runtime gates produced 298 eligible equipment ROIs from 116 screenshots, 64 students, all three
  slots, all T1-T10 tiers, and nine equipment families. Every eligible ROI was enlarged 4x on seven
  opaque-RGB contact sheets and visually checked against its printed prediction.
- All 298 archive level pairs matched. Observed values are 10, 20, 21, 30, 37, 40, 43, 45, 50,
  54, 55, 59, 60, 65 and 70. Position 1 now covers every valid tens digit 1-7; position 2 covers
  0/1/3/4/5/7/9. Score range is 0.521064-0.650632 and margin range is 0.043264-0.117650.
- A compact 960x540 ROI atlas and 298-record manifest preserve source filename/SHA-256,
  student/family/tier/slot, visual ground truth, score/margin and atlas coordinates under
  `backend/tests/fixtures/student_equipment_s3b_archive/`. The atlas replays 298/298 in a focused
  test without copying archive screenshots into runtime assets.
- Combined with the accepted Mika/Hibiki smoke data, S3B now has 316/316 correct level pairs and
  632/632 correct digit cells with committed false positives 0. This materially narrows but does not
  close the production gate: position-2 digits 2/6/8, actual single-digit blank, and broader
  non-Lv70 1280x720 evidence remain missing. `binary_production_enabled` therefore stays false and
  the generated/menu fallback remains unchanged.
- Next action: review the separate archive-validation handoff. Production promotion requires the
  remaining independent samples and an explicit acceptance decision; S4 still requires separate
  user direction.

### 2026-08-21 student equipment binary matcher S3B implementation complete

- Status: the user-directed S3B implementation, shadow evidence, metrics, fixtures, benchmark and
  handoff are complete. Production promotion is deliberately not approved because independent real
  0-9 plus blank coverage is still missing. S4/S5 remain untouched.
- The accepted S3 decision remains the safety baseline: binary observations cannot commit candidate
  values until independent real 0-9 plus blank coverage exists, and uncertain observations continue
  through the small-ROI generated matcher and unresolved-only one-menu fallback.
- `PreparedBinaryGlyph` stores each 20x28 glyph as a compact Python integer bitset. The recognizer
  prepares 51 existing equipment-menu digit templates once (3,570 binary bytes), extracts the basic
  screen with the equipment adaptive dark-ink mask, and ranks slot/position candidates using 75%
  IoU plus 25% normalized binary correlation. Exact alignment precedes conditional +/-1px retry.
- The result is exposed as `equipment_binary_shadow` evidence before the accepted empirical/generated
  paths. Its status is `shadow`, so even a value-bearing observation is never `confirmed`, never
  enters payload values, and never suppresses the unresolved-only one-menu fallback.
- Mika/Hibiki 1280x720 Lv70 data produced 18/18 level pairs and 36/36 digit cells with committed
  false positives 0. Cold startup was 26.38ms including 25.10ms template preparation; a warm
  three-slot frame measured p50 1.264ms and p95 1.450ms. Binary shadow left menu calls at 6/6 by
  design, generated cache entries at 0, and full-size reference canvases at 0.
- Nine S3B tests and the combined 35-test S2/S3/S3B/asset/stdio set pass. The full 195-test run has
  the same eight out-of-scope generated metadata failures as S3: seven stat lookups for missing
  Aru/Eimi/Kotama `schaledb_id` mappings and one Hoshino gift assertion. No affected generated file
  was changed by S3B.
- Remaining `MASTER_REQUIRED` gates are independent real digits 1-6/8/9, a real single-digit blank,
  broader slot/tier/family/resolution repeats, and a completed confusion matrix before selecting
  production thresholds. Next action is review the separate S3B handoff; S4 still requires explicit
  user direction after acceptance.

### 2026-08-21 student equipment binary matcher S3B added to workflow

- Status: the user approved adding a post-S3 binary-matcher slice. S3 remains complete and its
  generated matcher plus unresolved-only one-menu fallback remain the accepted safety baseline.
  S3B is specified but not implemented. S4/S5 remain untouched and S4 now waits for S3B master
  acceptance.
- Read-only exploration on the accepted live dataset established the boundary. Directly applying
  the inventory grid's fixed `#2D4663` mask and inventory digit templates to Mika equipment cells
  found only 0-5 ink pixels and effectively zero IoU, so direct template/geometry reuse is rejected.
- The viable hybrid uses the equipment adaptive dark-ink mask, 20x28 canonical glyphs, existing
  equipment-menu slot/position binary masks, and grid-style IoU. Across three Mika and three Hibiki
  1280x720 frames it ranked the expected `7`/`0` first in all 36 cells; score range was
  0.459459-0.631818 and margin range 0.054173-0.080536.
- This is feasibility evidence only because it covers T10/Lv70 and digits 7/0 at one resolution.
  S3B must begin in shadow mode, collect independent 0-9 plus blank coverage, forbid template/test
  leakage, and require committed false positives of zero before production promotion. Threshold,
  ROI and confusion-pair tuning remain evidence-gated.
- Approved order: `empty/locked -> family/tier -> binary -> small-ROI generated -> one-menu`.
  Existing fallback is never removed by S3B; low confidence/margin and invalid tier-level pairs fall
  through. No OpenCV/numpy runtime dependency or wholesale v6 inventory matcher copy is approved.
- New session input: `docs/migration/student-scan-v7-session-s3b-input.md`. The workflow page now
  records S3B implementation/data/performance gates. Next action is start S3B only on explicit user
  direction, then update this status and produce a separate handoff before S4.

### 2026-08-21 student scan S3 master validation complete

- Status: S3 implementation and its master-only validation are complete. S4/S5 were not changed.
  The former `MASTER_REQUIRED` gates are superseded by the executable v6 baseline and live evidence
  below; the S3 benchmark now has an empty `master_required` list.
- A disposable dependency-complete v6 environment reproduced the original OpenCV generated-RGB
  T10/Lv70 result: cold 902.38ms, warm p50 58.54ms, warm p95 62.03ms, 70 full-screen candidate
  cache misses, and 774,144,000 theoretical candidate RGB bytes. The environment was removed after
  the raw JSON and offline runner were retained in v7; there is still no v6 runtime import.
- Live Windows-client evidence at 1280x720/100% UI scale contains three stable repeats each for Mika
  basic equipment, Mika's shared equipment-growth menu, and Hibiki favorite equipment. Mika visually
  confirms Hat/Badge/Watch T10/Lv70 and Hibiki confirms favorite T2. Contract-shaped full-screen
  copies and metadata remain under `student_equipment_s3_dataset/live_1280x720/`, separate from
  runtime recognition assets.
- On the same Mika answer set, v6 basic generated-RGB resolved slot1 Lv70 and conservatively fell
  back on slots2/3; the v7 basic reader resolved all three T10 tiers but left all levels uncertain;
  the one shared menu frame resolved all three Lv70 values on all three repeats. Hibiki favorite T2
  resolved on all three repeats at confidence 0.854468 and margin 0.120613. No false level value was
  committed by either path.
- Decision: retain basic tier/favorite recognition, the conservative small-ROI level attempt, and
  unresolved-only one-menu fallback. Do not retune empirical thresholds, ROI geometry, digit-pair
  corrections, or storage from one real T10/Lv70 condition. Retain the bounded in-memory prepared
  bundle; broader T1-T9/non-70, favorite T1, and resolution/UI-scale data is future calibration
  coverage, not an unfinished S3 decision.
- The warm matcher now evaluates the exact alignment first and allocates the +/-1px variants only
  after an uncertain first pass. The final v7 benchmark is cold 141.61ms, warm p50 18.54ms and p95
  19.85ms: 6.37x faster cold and 3.16x faster warm than the reproduced v6 run. The one-pixel-shift
  regression remains exact, the compact cache remains bounded at 140 entries/658,000 bytes, and the
  full-size reference-canvas counter remains zero.
- Verification: all 15 S3 tests and the updated real-process 1,112-asset readiness test pass;
  Python compile, `git diff --check`, CodeAlmanac validate, and CodeAlmanac health pass. A full
  186-test run exposed eight pre-existing generated-data failures outside S3: seven stat-catalog
  lookups cannot resolve Aru/Eimi/Kotama because current `student_meta_data.py` lacks their
  `schaledb_id`, and the gift metadata test likewise sees no Hoshino `schaledb_id`. Those tracked
  data files have no S3 diff and were not altered. The one S3-related stale asset-count assertion
  found by that run was updated to 1,112 and passes in isolation.
- Final handoff: `docs/migration/student-scan-v7-session-s3-handoff/output.md`. Next action is S3
  review/acceptance; do not start S4 without a separate user direction.

### 2026-08-21 student scan parity and stat validation S3 implementation complete

- Status: the user accepted the S2 handoff by directing S3 to start. S3 implementation and Python
  verification are complete; acceptance and the dataset-dependent measurement decisions below are
  pending. S4 relationship OCR/stat mismatch evidence and S5 Flutter review work were not changed.
- The v6 behavioral baseline has been re-read at `read_equipment()`,
  `_read_basic_equipment_slot()`, the basic-equipment matcher functions, the prepared inventory-mask
  flow, and the four required regression suites. The retained semantics are level-locked slots,
  empty-dot short-circuiting, metadata-restricted equipment families, icon tier recognition,
  tier/level compatibility, favorite empty/locked/T1/T2, and one shared menu capture for unresolved
  slots.
- `student_equipment_recognizer.py` is the v7-specific small module. It short-circuits locked and
  empty slots, restricts icons to the student's metadata family, validates T1-T10 tier/level pairs,
  recognizes favorite empty/locked/T1/T2, and prepares RGB/gray/edge plus dark-ink glyph features.
  The 384-entry LRU owns compact cells only. Its generated fallback composes one cached 200x160 card
  and transforms directly to the 48x36 ROI; the full-size reference-canvas counter remains zero.
- Production wiring now opens the equipment menu only when the basic frame leaves slots unresolved,
  waits for one stable menu frame shared by those slots, scans no resolved neighbor, closes the menu,
  and discards the capture. Confirmed menu levels train at most four session-local basic glyph samples
  per slot/position/digit; a classifier needs competing labels before using that calibration.
- The version-1 S3 manifest adds 99 recognition artifacts (3,351,020 bytes): one dedicated bold font,
  one card background, menu regions with open/close controls, favorite templates, menu tier/flag/digit
  templates. Existing inventory equipment icons are reused inside the recognition catalog without
  mixing them with Flutter runtime UI assets.
- Final benchmark on the accepted machine: catalog verification plus cold start 0.62s; real Serika
  empty/locked fast path 0.29ms; T10 Lv70 small-ROI cold 210.10ms; warm p50 67.01ms and p95 69.63ms
  over 20 samples. The answer stayed Lv70, 70 cards produced 140 prepared cached cells, peak cache
  payload was 658,000 bytes, and no 2560x1440 candidate canvas was created. Twelve same-generator
  level answers, ten tier answers, one-pixel shift, digit/blank confusion, and the three real slot
  states were exact; those synthetic results are not claimed as real-capture accuracy.
- The accepted real answer set has only empty slot1/2, level-locked slot3, and unsupported favorite
  evidence. Therefore empirical thresholds, ROI revision, digit-pair correction, atlas/pack choice,
  and fallback removal remain `MASTER_REQUIRED`. The v6 OpenCV cold/warm path could not be rerun in
  this environment because v7 has no OpenCV/numpy and v6 has no isolated environment; the historical
  0.9-1.05s cold / 52ms warm values remain explicitly historical rather than a reproduced result.
- Verification: 25 focused S2/S3/production/asset tests and all 182 backend tests passed. Asset
  readiness reports 1,112 files; Python compile, `git diff --check`, CodeAlmanac validate, and
  CodeAlmanac health passed. The handoff is under
  `docs/migration/student-scan-v7-session-s3-handoff/`. Next action is master review, collection of
  contract-complete real equipped/favorite/menu captures, and S3 acceptance; S4 must not start first.

### 2026-08-21 student scan parity and stat validation S2 complete

- Status: the user accepted the S1 snapshot by directing S2 to start. S2 headless student basic-info
  recognition is complete and Python-verified. S3 must not start until this S2 handoff is accepted.
- `StudentMatcherAdapter` now converts exactly one stable basic screenshot into owned named crops,
  closes the full frame, and recognizes canonical ID/form reference, level, student star, four skills,
  weapon state/star/level, and HP/ATK/DEF/HEAL. The scanner session, version-1 repository payload,
  generation, cancellation, progress, review, and commit boundaries were not extended.
- `student_scan_recognizer.py` is a pure-Pillow port boundary. Each observation owns its source,
  confidence, status, and note; only confirmed/inferred values enter `ConfirmedStudent.values`.
  An uncertain field therefore forces review without erasing other confirmed observations. Multi-form
  recognition maps the matched template name to the existing canonical `student_id#form` reference.
- A separate version-1 `student_basic_manifest.json` adds 233 small v6-derived runtime templates:
  17 skill, 19 level digit, 187 combat-stat digit, and 10 weapon-level digit files. The deterministic
  sync tool copies them from the v6 behavioral-reference tree; v7 has no v6 runtime dependency.
- The accepted real fixed screen is the v6 Serika New Year 2560x1440 debug capture. It confirms
  ID, Lv12, 5-star, EX/S1/S3 level 1, equipped weapon Lv50/4-star, HP 11054, ATK 1321, DEF 28,
  and HEAL 4228. Skill2 remains below the conservative margin and is omitted with `uncertain`
  evidence, which directly exercises field-failure isolation and review-required behavior.
- Verification: 22 focused matcher/asset/session/contract tests passed; the real subprocess asset
  readiness regression passed with 1013 assets; the full backend suite passed 171 tests. Asset sync
  reproduced the same auxiliary-manifest SHA-256, Python compile passed, and CodeAlmanac validate
  and health passed with zero findings.
- S3 equipment/favorite-item recognition and performance profiling, S4 bond OCR/stat calculation
  evidence, and S5 Flutter work were not implemented. The named-crop recognizer boundary is the S3
  replacement port; next action is review/accept this S2 snapshot and then begin S3 separately.

### 2026-08-20 student scan parity and stat validation S1 complete

- Status: S1 static stat data and pure calculation core are complete and Python-verified. S2 has
  not started and must begin only after the S1 snapshot is accepted.
- The earlier deferral of student and bond statistics is superseded by the user's decision to add
  SchaleDB-compatible student stat calculation. The primary new value is scanner cross-validation:
  calculate expected HP/ATK/DEF/HEAL from independently scanned growth inputs and compare them with
  the basic-screen numeric observations before commit.
- The current v7 production `StudentMatcherAdapter` only identifies the student and returns an empty
  `values` object. Repository fields, candidate/review/commit session boundaries, Flutter handoff,
  and most v6 recognition regions already exist, but the student review UI is only a raw payload and
  evidence listing.
- v6 contains student level/star/skill/weapon/equipment/combat-stat recognition but no relationship
  rank matcher, ROI, or template. Relationship rank OCR is therefore a new required slice. Exact
  stat validation must also account for every known `FavorAlts` outfit; unknown alternate-outfit
  ranks are a dependency gap, not a mismatch.
- The v6 equipment fast path is retained conceptually, but its generated level matcher must not be
  copied. On a cache miss it creates a 2560x1440 RGB reference image for every possible equipment
  level; a T10 context can transiently allocate roughly 738 MiB of pixel buffers before small crops
  are cached. A supplemental v6 performance analysis was reviewed against the source and found
  additional valid gaps in the first workflow: warm matching recalculates gray normalization and
  edge features for every cached RGB candidate, while pre-generating thousands of individual PNGs
  could replace CPU work with file-open/decode overhead.
- S3 now begins by reproducing the reported v6 cold 0.9~1.05s and warm 52ms measurements rather
  than treating them as fixed v7 targets. It compares generated RGB, prepared feature bundles,
  empirical normalized glyphs, and empirical-first plus small-ROI fallback on one answer set. The
  gate includes accuracy/error/fallback rates, per-slot/tier/digit confusion matrices, warm p50/p95,
  startup and feature preparation, RAM, and installed size. Dataset source screenshots and metadata
  remain separate from runtime assets; storage format and fallback removal require measured evidence.
- The approved sequential slices are S1 pure stat data/calculation, S2 headless student recognition,
  S3 optimized equipment/favorite-item recognition, S4 relationship OCR and calculation evidence,
  and S5 Flutter review workspace plus real-process E2E. Scanner-heavy slices are sequential and may
  not edit the same large matcher modules in parallel.
- S1 adds strict version-1 DTOs and a UI/scanner-free calculator in
  `backend/core/student_stats_types.py`, `student_stats.py`, and `student_stats_catalog.py`. The
  calculation preserves Schale's four-decimal interpolation and rounding order, star scaling,
  equipment current-level interpolation, unique-weapon separated-flat stats, relationship and
  alternate-outfit accumulation, favorite gear, and level-90 potential contributions.
- `backend/tools/sync_student_stats_from_schaledb.py` owns the source normalization boundary. It
  generated `backend/data/student_stats/v1/catalog.json` from source payloads identified by SHA-256,
  without expanding the generated `student_meta_data.py`. The catalog contains 272 students and 90
  canonical equipment tier rows, is byte-deterministic for the same source, and is 154,008 bytes
  versus 1,709,724 source bytes (about 9.0%). Hoshino Battle form 2 resolves through the existing
  ordered merge paths to Schale ID 10099 rather than reusing form 1's ID 10098.
- The S1 result type never substitutes zero for unknown current or alternate-outfit relationship
  ranks or unlocked equipment. It returns `dependency_missing`, no exact `values`, a separately
  labelled `partial_values`, and typed missing dependencies. Explicitly unowned alternate outfits
  retain rank-1 zero contribution and allow an exact result.
- `backend/tests/fixtures/student_stats_s1_parity.json` fixes Aru relationship ranks
  1/10/20/50/100, equipment level 1/middle/max interpolation, Kotama star 1~5 edges, and a mixed
  level-90 Aru build covering T10 equipment, unique weapon, relationship, and potential. Nine
  focused tests passed, all 272 catalog students passed a complete-build smoke calculation, and the
  full backend suite passed 166 tests with the repository venv and workspace asset override.
- Active workflow: `almanac/workflows/student-scan-validation-workflow.md`.
- Handoff and copy-ready session inputs:
  `docs/migration/student-scan-v7-next-session-handoff-2026-08-20.md` and
  `docs/migration/student-scan-v7-session-s1-input.md` through `-s5-input.md`.
- Next action: review and accept the S1 handoff, freeze that snapshot, then start S2 headless student
  recognition from it. S2 must not extend the protocol or Flutter UI. S4 still requires real
  bond-rank screenshot fixtures; ROI values must not be guessed in advance.

### 2026-08-20 remaining student-metadata-tool migration restarted

- Status: all six approved non-student-statistics vertical slices complete.
- A source-level comparison against v6 `tools/student_meta_tool.py` found the previously unlisted
  gaps: duplicate-as-new, multi-form override management, single-student SchaleDB URL/slug
  preview and save, JP/KR server-state actions, SchaleDB merge-path management, metadata debug
  table/detail views, and item statistics. Student statistics and student/bond-stat SchaleDB fields
  remain deferred by the existing user decision.
- The first slice migrates duplicate-as-new and `MULTI_FORM_STUDENTS` management. The Python tool
  now exposes version-1 get/save methods, validates JSON objects against `StudentFormMeta`, requires
  `template_name`, supplies missing labels, rejects orphan students and unknown fields, and rewrites
  only the generated multi-form declaration atomically.
- Flutter now provides a collapsible multi-form editor with current form count, JSON-array editing,
  a two-form seed, clear/remove guidance, explicit form save, and a duplicate-as-new draft action.
  Basic student metadata and form overrides retain separate save actions and storage contracts.
- Verification: five focused Python metadata/gift tests and all seven standalone developer-tool
  Flutter tests passed; `flutter analyze` reported no issues. The Windows developer-tool bundle was
  rebuilt and copied.
- The second slice migrates the read-only metadata diagnostic view. Its version-1 list/get DTOs
  provide search, KR/JP filtering and counts, recognition-template completeness, portrait and
  eleph availability, multi-form counts, major classification columns, and full selected-student
  field details. The Flutter surface uses existing portrait and eleph assets in selectable cards
  with a separate detail pane; it cannot mutate metadata.
- Live diagnostic verification reported 265 students (253 KR, 12 JP), all 265 portrait and eleph
  assets present, 253 students with complete recognition templates, and two multi-form students.
  The new focused Python diagnostic test, all eight standalone Flutter developer-tool tests, and
  `flutter analyze` passed. The Windows developer-tool bundle was rebuilt again.
- The third slice adds single-student SchaleDB URL/slug preview with automatic local-ID matching,
  including path exceptions such as `hoshino_battle_tank` to `hoshino_battle`. It reuses the exact
  seven-field boundary and gift-affinity calculation from bulk sync. Existing students can apply
  the three student fields and four-field gift catalog after confirmation; unmatched/new slugs can
  only be loaded into an editor draft until required local name/template/group fields are supplied.
- The single-student Flutter surface separates bulk and single modes, shows existing/new status,
  changed-field chips, special/general gift icons and points, and explicit editor-load versus
  minimal-save actions. Raw Schale tags and student/bond-stat fields are not presented as the main
  result and are not expanded in persistence.
- Live URL verification resolved `hoshino_battle_tank` to existing local `hoshino_battle`, found
  zero student-field changes, 52 gifts, four special and four general preferred gifts, and a 240pt
  leading special gift. Four focused Python sync tests, all nine standalone Flutter developer-tool
  tests, and `flutter analyze` passed; the Windows developer-tool bundle was rebuilt.
- The fourth slice adds explicit JP/KR server-state control to the diagnostic detail view. The
  backend validates an existing student and rewrites only `JP_ONLY_STUDENT_IDS`; `STUDENTS` and
  multi-form declarations are untouched. Repeating the current state is idempotent. KR transition
  results include warnings when portrait or recognition templates are missing.
- Flutter exposes only the transition appropriate to the current state (`JP 전용 지정` or
  `KR로 전환`), requires confirmation, refreshes editor and diagnostic state, and displays any
  asset follow-up warning. The focused Python membership/warning tests, all ten standalone Flutter
  developer-tool tests, and `flutter analyze` passed. The Windows developer-tool bundle was rebuilt.
- The fifth slice migrates SchaleDB multi-slug merge-path management into a dedicated generated
  rule module and version-1 list/save/delete methods. Rules require at least two distinct paths,
  normalize URL/slug input, reject a slug already owned by another local student, and preserve
  the first path as the scalar-field source. Every listed path participates in reverse matching,
  so both `hoshino_battle_tank` and `hoshino_battle_dealer` resolve to local
  `hoshino_battle` without importing form combat/stat data.
- Flutter adds a third SchaleDB mode with portrait-backed student cards, visually distinct
  `기준`/`보조` path chips, selected-student seeding, save, and confirmed deletion. Three focused
  Python tests, all eleven standalone Flutter developer-tool tests, `flutter analyze`, and the
  sandbox-external full 155-test Python suite passed. The Windows developer-tool bundle was rebuilt.
- The sixth slice migrates read-only item statistics. It loads the selected v7 repository profile
  by default and also accepts an explicit v7 profile/inventory or legacy inventory JSON plus an
  optional item-delta JSON. The analysis preserves unknown quantity, explicit zero, positive,
  missing snapshot, missing catalog, and plan-adjusted negative states separately; it does not
  invent a cross-resource total quantity.
- Flutter adds an icon-backed item list, catalog/snapshot/known/unknown/zero/shortage KPI cards,
  category coverage, search, state filters, and v6-compatible shortage/name/adjusted sorting.
  Live verification on `거모이는존재한다 (v7 UI 테스트)` reported catalog 538, snapshot 614,
  known 614, explicit zero 80, positive 534, and 76 snapshot identities absent from the catalog.
- Two focused backend tests, all 12 standalone developer-tool widget tests, the full 157-test
  Python suite, the full 384-test Flutter suite, and `flutter analyze` passed.
- No approved non-student-statistics parity slice remains. Student statistics and SchaleDB
  student/bond-stat expansion remain deferred by the user decision.

### 2026-08-20 minimal SchaleDB gift-affinity sync and visual metadata comparison

- Status: implementation, live-data application, and focused automated verification complete.
- The standalone student metadata editor now previews SchaleDB data before writing and persists
  exactly seven source fields: three student fields (`Id`, `FavorItemTags`,
  `FavorItemUniqueTags`) and four gift fields (`Id`, `Category`, `Tags`, `ExpValue`). Bond stat
  types and values remain explicitly deferred.
- Generated student metadata stores the three normalized fields, while the generated gift
  catalog remains a separate static-data bucket with stable runtime accessors. Apply rewrites
  both generated declarations atomically per file and preserves all unrelated student fields.
- The editor separates normal metadata editing from SchaleDB import. Raw tag comparison is no
  longer the primary user surface: each student card uses the bundled portrait and calculated
  gift results, split into unique-tag `special` and general-tag `preferred` rows. Gift icons carry
  expected-point badges, hover details expose the gift name and multiplier, and long general lists
  show six leading icons plus a remaining count. The gift catalog remains icon-based and the
  unmatched-student report stays separate.
- These result rows are preview-only DTOs and add no persisted fields. The calculation unions the
  student's general and unique tags with SchaleDB's universal gift tags (`BC`, `Bc`, `ew`), caps
  matching gift-tag count at three, and reports `ExpValue * (1 + match count)`. A unique-tag match
  takes display precedence over the general row so the same gift is never shown twice.
- Live verification matched all 265 local students, imported 52 Favor gifts, resolved all 52
  bundled gift icons, and reported no unmatched students. A second preview reported zero changed
  students, confirming idempotent student-field application.
- Verification: four focused Python metadata/gift tests passed, all six developer-tool Flutter
  tests passed at narrow and wide layouts, and `flutter analyze` reported no issues. The complete
  Python suite remains subject to the already documented local Pillow `_imaging` DLL access
  failure; the changed non-image tests run with the system Python and pass.
- The final Windows build was visually inspected with live data. At the inspected desktop width it
  rendered three student-result cards per row with portraits, special/general gift icon bands,
  point badges (`240pt`, `60pt`, `40pt` examples), remaining-count indicators, and gift detail
  tooltips without clipping or horizontal overflow. The developer-tool bundle was rebuilt and
  copied after this verification.
- Artifacts: `backend/core/student_meta_data.py`, `backend/core/student_meta_types.py`,
  `backend/core/gift_meta_data.py`, `backend/core/gift_meta.py`,
  `backend/core/student_meta.py`, `backend/tools/developer_tools.py`,
  `frontend/lib/developer_tools_main.dart`, focused backend/Flutter tests, and the developer-tool
  migration/architecture documents.

### 2026-08-16 scenario comparison diagonal rail correction

- Status: implementation, automated verification, release build, and maximized
  release UI verification complete.
- Re-read the plan builder, phase editor, student selector, and diagonal-list
  lessons before changing the comparison workspace. The retained constraints are
  the 2560x1392 maximized review surface, height-derived 80-degree depth, shared
  paint/clip geometry, and a 12px visual seam between adjacent components.
- The earlier comparison styling only inscribed rectangular children in safe
  intervals. That kept them inside the outer shape but did not implement the
  project's diagonal-placement rule. Existing phase, resource, bottleneck, preset,
  and student lists were re-inspected to recover the actual rule.
- Comparison candidate cards and result rows now use the same viewport-space rail
  projection as those lists: a row's bottom-left bound is taken from the parent's
  left rail, its top-right bound from the parent's right rail, and its horizontal
  offset is recalculated from `viewportY - scrollOffset`. Each child then paints and
  clips its own height-derived 80-degree parallelogram. Consecutive rows therefore
  advance down-left along both parent rails instead of staying in one rectangle.
- Tabs, content bands, footer/action bands, both A/B panes, and the confirm control
  also derive their bounding rectangles from their actual top and bottom rail
  intersections. Decorative paint remains ignored for hit testing, clip and paint
  paths are shared, and the A/B seam retains the established 12px visual gap.
- Verification: the focused comparison regression now asserts that both left and
  right bounds of the second candidate/result row are left of the first row. All
  374 Flutter tests passed, `flutter analyze` reported no issues, and
  `codealmanac validate` passed. A fresh Windows release was built and the actual
  app result view was inspected: the A/B result rows visibly step down-left along
  the same rails without clipping or overlap.
- Artifacts: `frontend/lib/ui/widgets/plan_section_layout.dart` and
  `frontend/test/planning_page_test.dart`.

### 2026-08-16 startup login gate and v7 profile reselection

- Status: implementation and automated verification complete; user visual review
  pending.
- The first reconnect fix still left a short startup gap: the profile request made
  during `connecting` failed immediately, set `_loading` false, and allowed the
  primary title action to open the v6 migration dialog before the connected retry
  completed. The title now performs no account classification until the backend is
  connected, keeps the primary action gated while disconnected or connecting, and
  invalidates any in-flight account load when the connection drops.
- `AppShell` uses the same connection gate and invalidates an in-flight selected
  profile request on disconnect.
- Repository inspection confirmed the v7 UI-test account and its eight scenarios
  remained intact. The user's migration-dialog attempt created and selected a new
  `v6 가져오기 8` profile; it was preserved, while the existing
  `거모이는존재한다 (v7 UI 테스트)` profile was selected again.
- The developer seed tool's fixed profile-selection idempotency key conflicted after
  a later profile revision. Its selection key now includes the target profile
  revision, allowing safe reselection after another profile has been selected.
- Focused verification: all 35 title/widget Flutter tests passed,
  `flutter analyze` reported no issues, the seed-tool Python test passed, and the
  real seed run reused the existing profile, added no scenarios, returned all eight
  scenarios, and selected the v7 profile.
- Full verification: all 373 Flutter tests passed, and the Windows release was
  rebuilt and synchronized after the fix.
- Artifacts: `frontend/lib/ui/pages/title_page.dart`,
  `frontend/lib/ui/app_shell.dart`, `frontend/test/title_page_test.dart`, and
  `backend/tools/seed_ui_test_profile.py`.

### 2026-08-16 backend readiness probe and non-blocking title warmup

- Status: implementation, automated verification, Windows release sync, and actual
  release UI verification complete.
- A real release process timing probe showed that repository operations complete in
  milliseconds after initialization, but Python process startup takes about three
  seconds. The Dart client previously marked the backend connected as soon as the OS
  process spawned, before Python imports and the JSONL server were ready, allowing
  the first title requests to consume their timeout during startup.
- Production `ProcessAppService` launch paths now keep the connection in
  `connecting` until a typed `repository.profile.list` startup probe succeeds. The
  probe has a separate 30-second startup allowance; a failed probe terminates the
  unusable child process and restores the disconnected state. Direct fake-client
  tests retain the opt-in-free behavior used by their deterministic harnesses.
- Title account loading no longer waits for `planning.student.catalog`. Profiles and
  selected repository state establish login first, while catalog count and portrait
  warmup run as an optional background task whose timeout cannot clear a valid
  account or show the account-load error.
- Focused verification: the new connecting-until-probe regression plus protocol,
  title, and real repository-process suites passed all 40 tests; `flutter analyze`
  reported no issues.
- Full verification: all 374 Flutter tests passed and the Windows release rebuilt
  successfully. The previously running release visibly reproduced
  `Backend request timed out: repository.profile.list`; after replacement, the
  actual release displayed `거모이는존재한다 (v7 UI 테스트)` with 217/265 students
  and entered Home via Space without showing the v6 migration dialog.
- Artifacts: `frontend/lib/services/planning_protocol_client.dart`,
  `frontend/lib/services/process_app_service.dart`,
  `frontend/lib/ui/pages/title_page.dart`, and
  `frontend/test/planning_protocol_client_test.dart`.

### 2026-08-15 startup account reload and seed-data recovery check

- Status: implementation and automated verification complete; user visual review
  pending.
- The reported missing v7 UI-test account and scenario-list fixtures were verified
  in the production repository at `%LOCALAPPDATA%/BA Planner/repository`; no data
  had been deleted. The selected profile remains
  `거모이는존재한다 (v7 UI 테스트)` (`424eaa52e54c457e874c61f4`) and the deployed
  release backend returns all eight named scenarios at scenario revision 8.
- The visible failure was a startup race: `main` starts the real Python backend
  asynchronously, while `TitlePage` and `AppShell` previously requested profiles
  once during `disconnected` or `connecting`. `PlanningProtocolClient.send` rejects
  that request, and neither widget retried after the connection became ready.
- Both widgets now listen for a transition to `BackendConnection.connected` and
  reload the selected profile. Load generations prevent an earlier failed request
  from overwriting a later successful response, and listeners are transferred or
  removed across widget updates and disposal.
- Verification: the two new reconnect regressions and the complete title/widget
  focused run passed all 35 tests; the full Flutter suite passed all 373 tests and
  `flutter analyze` reported no issues. The Windows release was rebuilt and synced
  after the fix. The deployed release Python boundary independently returned the
  selected profile and all eight scenarios.
- Artifacts: `frontend/lib/ui/pages/title_page.dart`,
  `frontend/lib/ui/app_shell.dart`, `frontend/test/title_page_test.dart`, and
  `frontend/test/widget_test.dart`.

### 2026-08-15 plan scenario comparison first vertical slice

- Status: implementation and automated verification complete; user visual review
  pending.
- The Plan Section 1 scenario comparison action is active when the repository,
  comparison service, and active planning document are available. Its dedicated
  80-to-260 workspace offers the active plan plus every saved scenario and requires
  exactly two distinct selections in stable A/B order.
- The backend `planning.scenario.compare` boundary now accepts either `plan` or
  `scenario` documents, while retaining the distinct-document requirement and the
  neutral no-winner comparison result. `MockAppService` implements the same boundary.
- Results keep A and B side by side across four views: overall phase/result summary,
  final student targets, resource requirements and known shortages, and first
  bottlenecks. A scenario whose `base_profile_revision` is lower than the current
  profile revision is explicitly marked as older and recalculated against the current
  confirmed-student and inventory snapshots.
- Saved-scenario actions support editing through the existing phase workflow,
  repository duplication, returning to the candidate list, and incorporating the
  scenario after the current active plan. Incorporation preserves existing phases,
  remaps all imported phase/stage IDs, and excludes stages that would regress an
  already planned student. Entering scenario create/edit now snapshots the active
  in-memory plan and restores it on save or cancel.
- Verification: the focused eight-test Python planning-document suite passed;
  `flutter analyze` reported no issues; all 371 Flutter tests passed; and the Windows
  release build completed. The complete Python suite remains locally blocked by the
  existing Windows native-DLL access failures for Pillow `_imaging` and `rpds`; tests
  that do not import those native modules, including the changed comparison tests,
  pass.
- Artifacts: `backend/core/protocol_v1.py`,
  `backend/tests/test_planning_document.py`,
  `frontend/lib/services/mock_app_service.dart`,
  `frontend/lib/services/scenario_service.dart`,
  `frontend/lib/ui/widgets/plan_section_layout.dart`,
  `frontend/test/planning_page_test.dart`, and
  `frontend/test/scenario_service_test.dart`.

### 2026-08-14 persistent v6-backed UI test profile and scenarios

- Status: implementation, actual local seeding, and automated verification complete;
  user visual review pending.
- Added an idempotent developer seed tool that imports the v6
  `거모이는존재한다` account through the production read-only migration boundary,
  renames the independent copy to `거모이는존재한다 (v7 UI 테스트)`, selects it,
  and preserves the imported students, inventory, and goals in normal v7 storage.
- The tool adds eight stable scenarios covering single/multi-student rows,
  one/three-phase documents, mixed owned-state portraits, aggregate calculation,
  shortage, and bottleneck summaries. Re-running skips scenarios by their stable
  names and reuses the named profile instead of producing another import copy.
- Existing local profiles and scenarios are not removed or overwritten.
- Actual local result: the selected UI-test profile contains 217 students, 614
  inventory entries, 9 imported goals, and exactly 8 seeded scenarios. A second
  tool run created no profile and added no scenario, proving the intended
  idempotent reuse behavior.
- Verification: all 142 Python tests and all 50 planning-page Flutter tests
  passed; `flutter analyze` reported no issues; `codealmanac validate` passed.
- Artifacts: `backend/tools/seed_ui_test_profile.py`,
  `backend/tests/test_seed_ui_test_profile.py`, and `README.md`.

### 2026-08-07 production v6 account import and planning activation

- Status: implementation and full automated verification complete; user visual
  review pending.
- The normal app now selects `ProcessAppService` by default. Mock mode remains
  available through `BA_PLANNER_USE_REAL_BACKEND=false`, so production launches
  no longer present non-persistent mock account data.
- Windows release synchronization fingerprints and bundles the Python `core`,
  planning data, recognition assets, `pyproject.toml`, and the verified Python
  3.11 virtual environment under `release/backend/`. Backend auto-discovery
  therefore works from the release executable instead of depending on the
  source-tree backend location or globally installed Pillow.
- v6 root discovery supports both source layout (`v7/backend`) and packaged
  layout (`v7/release/backend`) while preserving `BA_PLANNER_V6_DIR` as the
  explicit override.
- When no v7 account exists, the title primary action previews sibling v6
  accounts and offers either new-account creation or a read-only v6 copy. A
  successful import selects the new profile and opens the Plan tab immediately.
  Existing installations can run the same import from Settings.
- The imported planning boundary remains limited to account name/avatar,
  confirmed students, inventory, and growth goals. Scanner candidates, logs,
  and tactical records are not inferred as planning data, and no v6 file is
  modified.
- Verification: `flutter analyze`; all 140 Python tests; all 358 tests in the
  full Flutter suite; the added bundled-runtime resolver test; 22 focused real
  Dart-to-Python repository/planning/scenario/tactical tests; the complete
  18-test title suite; the Settings v6-import widget test; and a
  read-only real-data probe importing 217 students, 614 inventory entries, and
  9 goals. The real imported plan calculated 101,589,028 credits and 73 shortage
  rows without protocol errors. The Windows Release build and freshness check
  passed; its bundled Python imported Pillow 12.3.0, loaded `release/backend/core`,
  resolved the real sibling v6 root, and previewed the same 217/614/9 counts.
- Artifacts: `frontend/lib/main.dart`,
  `frontend/lib/ui/pages/title_page.dart`,
  `frontend/lib/ui/pages/settings_page.dart`,
  `frontend/lib/services/backend_process.dart`,
  `frontend/tool/sync_windows_release.ps1`, `backend/core/runtime_paths.py`,
  `backend/tests/test_v6_migration.py`, `frontend/test/title_page_test.dart`,
  `frontend/test/settings_page_test.dart`,
  `frontend/test/planning_protocol_client_test.dart`, and `README.md`.

### 2026-08-04 plan-main student selector without an incoming seed

- Status: `implemented · full automated verification complete · user visual review pending`
- Plan Section 1 now keeps its existing phase-editor action and adds `학생 추가`.
  Opening it leaves Section 1 in place while Sections 2-5 complete their own
  outro motions, then presents a dedicated student-selection workspace in the
  vacated center/right area.
- The selector uses a four-column `StudentDiagonalGrid` at one half of the
  student tab's grid-section width and a separate bilateral filter surface with
  an explicit responsive gap. The filter surface places search at the top,
  followed by the reused student-tab metadata filters plus the planning-only
  `보유 상태` and `계획 상태` groups.
- Selecting a card immediately builds a `PlanningStudentSeed` from the active
  profile's confirmed state and opens `PlanElementBuilder`. Students already
  represented in the current plan session keep their `PLAN` badge and reopen
  the saved stage drafts for editing instead of starting over.
- `선택 취소` restores Sections 2-5. Removing the selector also disposes its
  search controller and filter selections, so every subsequent entry starts
  with an empty search and no active filters.
- The shared student grid now accepts a source-compatible optional column count;
  the student tab retains its eight-column default while the plan selector sets
  four columns. The shared diagonal filter list similarly accepts optional
  definitions while retaining the original student-tab defaults.
- Screenshot-driven follow-up adds a student-tab-style opaque inner bilateral
  container to both selector sections. Grid scroll/fog/scrollbar effects are
  clipped to the grid container. A second screenshot review found that placing
  the selector's rectangular bounds 12px after Section 1 still added the
  selector's complete left-cut depth to the visible gap. Placement now compares
  the two actual 80-degree edges at one shared reference Y and preserves a true
  12px visual gap. The grid title row was removed so its inner container starts
  10px below the outer section rather than leaving a large unused top band.
- The filter now follows `search control → clipped filter-scroll container →
  reset button`: search and reset are direct children of the outer section and
  use opposite diagonal-safe insets, while only the scrolling filter list sits
  inside the opaque inner container. A further 12px inset separates every
  filter row from that container's border.
- Latest visual follow-up gives both selector sections the exact top and bottom
  bounds of Plan Section 1. Their internal surfaces resize with them and retain
  their existing border insets. Both visible edge gaps are now 24px at the same
  reference Y: `Section 1 ↔ grid` and `grid ↔ filter`; the latter subtracts both
  sections' cut depth instead of treating their rectangular bounds as visible
  edges.
- The central filter-scroll path is now derived from the outer filter section's
  complete 80-degree trajectory at its actual top and bottom, retaining a 10px
  parallel border gap even though the search and reset controls consume height.
  Its rows retain an additional 12px content inset. The reusable viewport fog
  accepts a surface color, and the plan filter uses its inner container's opaque
  `#162431` rather than the student-tab default fog color.
- Verification: `flutter analyze` reported no issues; all 316 Flutter tests
  passed, including 38 planning page tests and 46 student-layout tests; the
  Windows release build completed; and `codealmanac validate` passed. Added coverage verifies the
  non-zero grid/filter gap, four-column contract, Section 1 persistence,
  Sections 2-5 exit, search/filter reset, immediate builder entry, plan-state
  filtering, and reopening existing stage drafts.
- Artifacts: `frontend/lib/ui/widgets/plan_student_selector.dart`,
  `frontend/lib/ui/widgets/plan_section_layout.dart`,
  `frontend/lib/ui/widgets/student_section_layout.dart`,
  `frontend/lib/ui/pages/planning_page.dart`, and
  `frontend/test/planning_page_test.dart`.

### 2026-08-01 student Section 2 grid/list views

- Status: `implemented · full automated verification complete · user visual review pending`
- 구현 결과, 사용자 재지적, 폐기한 원인 가설, 최종 그리드·목록·Section 3 렌더링 계약과
  성능 개선 이력은
  [학생 카드 그리드·목록·초상 반복 개선 기록](../design/student-card-rendering-lessons-2026-08-02.md)에
  상세히 기록했다.
- Student Section 2 now defaults to its existing eight-column grid and can be
  switched to a diagonal student-information list built with the extracted
  `PlanStudentStepTile` constructor. Both views receive the same searched,
  filtered, hidden, and sorted student sequence and use the same selection
  callback.
- Section 1 now follows the vertical order `one-row list/grid buttons → sort
  dropdown → add to plan → scan → filter`. Moving the split view row to the
  wider top position avoids shrinking either icon button. The dropdown, view row,
  three actions, and four equal gaps are recalculated together so the added row
  remains inside the left attached section without overlapping controls.
- The list toggle is now an attached trapezoid. Its right bevel, the grid
  toggle's two bevels, and Section 1's right rail use the same 80-degree depth;
  the grid toggle retains the same right-rail inset as the action controls.
  Following the bond-gauge correction, the toggle rail is no longer rebuilt
  only from an ideal 80-degree polygon: its top and bottom endpoints are sampled
  from the actual rounded Section 1 path and inset from that rendered boundary.
- Extended the reusable plan-student tile with source-compatible optional
  `owned` and `onTap` inputs. Ownership reaches the shared diagonal media
  portrait, where the existing clipped `UNOWNED` overlay is painted, while plan
  call sites retain the default owned and non-interactive behavior.
- Container 12, the outer Section 2 content container, now uses an opaque
  darker `#162431` fill instead of the shared blue triangle texture while
  retaining its own outline. The faint rectangles belonged to the baked edge
  pixels of each bond-rank grid background; only those edge pixels are cropped
  and the original alpha silhouette reapplied, preserving the interior pattern
  and bond-rank color.
- Student list rows are 97.5px high (1.5 times the original 65px) while their
  inter-row gap remains 4px.
- Follow-up visual correction increases bond-background edge cropping from
  3.5% to 11% after pixel inspection showed the baked bright rim continuing
  roughly 14-20 source pixels inward. The original alpha silhouette is still
  reapplied after cropping.
- A second source-canvas investigation found that `square.png`, bond-color
  backgrounds, and student portraits all report non-zero alpha bounds across
  their complete 252x204 canvases. Roughly 1,200 square-background pixels use
  alpha 1-31; stretching the cropped interior and reapplying every non-zero
  alpha value exposed those bounds as a faint rectangle. Grid backgrounds now
  discard alpha below 12.5%, portraits below 4%, and the selected silhouette
  outline receives the same per-item threshold.
- Student-list current-state rows now omit the left order and title target
  suffix, move the unowned badge into the vacated order slot, alpha-preserve
  portrait darkening with `ColorFiltered`, hide bond delta text, scale the
  requested text families by 1.5, and scale equipment icons by 1.15. The
  default shared plan-row presentation remains source- and visually compatible.
- The left status rail now reserves three stable, path-derived badge slots in
  `UNOWNED / PLAN / JP` order. Their bounds keep independent gaps from the
  rounded 80-degree item edge, the portrait, and neighboring badges.
- Grid/list switching now reverses the existing Section 2 motion completely,
  swaps the child only after the outro, and then forwards the same controller
  for re-entry. Repeated view/filter requests are ignored during the cycle.
- Verification: 48 focused student-layout, diagonal-media, and reusable-tile
  tests passed; the full Flutter suite passed 277 tests with `--concurrency=1`,
  `flutter analyze` reported no issues,
  the Windows Release build completed, and `codealmanac validate` passed. User
  visual review remains pending.
- Artifacts: `frontend/lib/ui/widgets/diagonal_media_list_item.dart`,
  `frontend/lib/ui/widgets/asset_image_grid.dart`,
  `frontend/lib/ui/widgets/plan_student_step_tile.dart`,
  `frontend/lib/ui/widgets/student_section_layout.dart`,
  `frontend/test/plan_student_step_tile_test.dart`, and
  `frontend/test/student_studio_layout_test.dart`.

### 2026-08-01 reusable plan student step tile boundary

- Status: `implemented · focused verification complete`
- Extracted `PlanStudentStepPreview`, `PlanBottleneckFocusField`, and
  `PlanStudentStepTile` from the full plan-section layout into the dedicated
  `frontend/lib/ui/widgets/plan_student_step_tile.dart` library.
- Other tabs can now import the dedicated library and construct the same tile
  API without depending on the complete plan main-section implementation.
- `plan_section_layout.dart` imports and re-exports the dedicated library, so
  existing plan call sites and consumers of the former library boundary remain
  source-compatible. No new usage was added outside the plan tab in this pass.
- Added a standalone widget test that imports only the reusable tile boundary
  and verifies its data, portrait, target, highlight, and progress projection.
- Verification: the standalone tile test and existing planning page suite
  passed 37 focused tests; the full Flutter suite passed 274 tests,
  `flutter analyze` reported no issues, and CodeAlmanac validation passed.
- Artifacts: `frontend/lib/ui/widgets/plan_student_step_tile.dart`,
  `frontend/lib/ui/widgets/plan_section_layout.dart`, and
  `frontend/test/plan_student_step_tile_test.dart`.

### 2026-08-01 student portrait unowned status overlay

- Status: `implemented · full automated verification complete · user visual review pending`
- Adapted the v6 student-card ownership treatment without copying Qt code: a
  `rgba(6, 8, 14, 0.46)` dark portrait overlay and an `UNOWNED` pill with a
  dark surface, subtle white border, shadow, and white bold label.
- Ownership remains a relation between the catalog and the confirmed repository
  ID set. Missing current values alone do not redefine an owned student as
  unowned.
- Added the layout-neutral `StudentPortraitStatusOverlay` widget API and the
  batched-painter entry point `paintUnownedStudentPortraitStatus`. Both ignore
  pointer input and rely on the host portrait's existing clip or alpha mask, so
  other portrait surfaces can opt in without changing surrounding geometry.
- Applied the API to both student-tab surfaces requested by the user: every
  unowned portrait in the eight-column student grid and the selected student's
  large focused portrait. The grid continues to use its existing square alpha
  mask, while the focused portrait reuses Container 1's actual clip path.
- Updated `AGENTS.md` to require focused follow-up questions until behavior,
  scope, and acceptance criteria are clear whenever the user has not explicitly
  decided a material ambiguity.
- Verification: student layout suite 39 tests passed, the full Flutter suite
  passed 273 tests with `--concurrency=1`, `flutter analyze` reported no issues,
  and the Windows release build completed. User visual review remains pending.
- Artifacts: `frontend/lib/ui/widgets/student_portrait_status_overlay.dart`,
  `frontend/lib/ui/widgets/student_section_layout.dart`,
  `frontend/test/student_studio_layout_test.dart`, and `AGENTS.md`.

### 2026-07-31 student detail status indicators

- Status: `complete`
- Detailed implementation history, user feedback, rejected approaches, and the
  current rounded-path rendering contract are recorded in
  [Student Detail Indicator Iteration Lessons](../design/student-detail-indicator-lessons-2026-08-01.md).
- Added explicit `LEVEL`, `SKILL SUMMARY`, `EQUIPMENT`, and `STATS`
  headings. The skill summary is split into four icon-bearing columns with
  dividers and compact progress bars, while HP/ATK/DEF/HEAL use a dedicated
  icon-bearing vertical panel.
- Split the level card into a blue parallelogram and trapezoid, with the
  selected student's bundled school mark recolored white. The metadata rows now
  use pink `Position`, `Class`, and `Weapon` labels without numeric prefixes.
- Reworked bond rank as a standalone pink vertical gauge while retaining only
  the 1.8x numeric rank at the triangle's geometric centroid.
- Strengthened the translucent `심상개화` lock treatment and enlarged its
  label. All triangle-textured regions below the star bar now derive from the
  same blue palette as the level region.
- Follow-up detail tuning aligns the white school mark with the level value,
  moves diagonal-edge headings into their safe intervals, and gives
  Position/Class/Weapon values one shared canvas-space start line. Skill icons
  and micro progress bars were removed; skill and equipment headings now use a
  divider-line header treatment.
- Equipment tier/level labels are 1.5x larger and offset along the panel rail.
  The ability row now labels `능력개방  Ability Release`. Combat labels, icons,
  and six-digit values follow one 80-degree trajectory, use value-sized icons,
  and render ATK with a custom sword glyph.
- Replaced the bond triangle with a narrow independent parallelogram gauge,
  using a bordered dark track, pink proportional fill, and the numeric rank
  centered within the filled portion.
- Follow-up rail correction renders only `Ability Release` with the shared
  section-title treatment. STATS rows now use each row center's actual 80-degree
  boundary position, so the title marker and all four stat icons share one
  trajectory. The stats panel's unused right width was reclaimed to give the
  bond panel an independent in-section gap; its outer and inner rails now use
  the same `height / tan(80°)` slope.
- Latest indicator refinement uses 80-degree separators between all four skill
  columns and all four equipment/favorite-item columns. `Ability Release` is
  left-aligned to the same safe rail as the other section headers, and `STATS`
  now has both a full header divider and horizontal dividers between stat rows.
- The bond container now shortens its bottom edge to exactly 80 percent of the
  top edge. Its dark inner trapezoid contains a separately clipped pink
  proportional fill, while the rank number remains centered on the dark inner
  container independently of the fill level.
- The upper-right level metadata surfaces use the darker potential-lock-panel
  family. The shared triangle palette remains unchanged; a proposed next-pass
  texture tuning is to increase face size and luminance contrast without
  changing hue, pending visual approval.
- Latest follow-up removes the temporary standalone bond gauge and restores
  container 4 (STATS) to its original width. The bond rank is again numeric-only
  inside the remaining right-side triangle. STATS no longer renders the
  HP/ATK/DEF/HEAL labels, retaining only the four icons and values.
- Skill and equipment separators now derive their complete painted endpoints
  from an exact 80-degree line instead of clamping the horizontal run to the
  layout slot. `Ability Release` remains left-aligned while its HP/ATK/HEAL
  value group is centered within the region remaining after the title.
- The STATS title now uses the same horizontal divider treatment as `SKILL
  SUMMARY` and `EQUIPMENT`. The bond triangle contains a rounded inner
  triangular track whose pink fill rises bottom-to-top according to rank/100;
  the numeric rank is fixed in a separate bottom band with visible gaps from
  both the gauge and the outer triangle base.
- The rounded inner bond gauge now uses one geometric inset for both the
  vertical side and the hypotenuse normal, with a responsive 2-4 pixel gap and
  a smaller corner radius so the usable triangular gauge is visibly larger.
  Shared student-detail triangle texture contrast increased from `0.024` to
  `0.030` without changing its palette or deterministic seed.
- Skill labels now sit halfway between their former centered position and the
  header divider, reducing the visible header gap by half. Skill-level values
  are 1.5x larger (`21` to `31.5` logical pixels).
- STATS row dividers now use the same height-derived 80-degree rail offset as
  their corresponding combat rows. Their two endpoints progress leftward at
  each row boundary instead of forming fixed vertical endpoint rails that spill
  outside the parallelogram.
- The bond gauge host now extends closer to the rank band and receives the
  container's actual local outer path after rounded corners and parent-section
  intersection. Its visible inset is produced by clearing one uniform stroke
  from that exact path instead of reconstructing a second ideal triangle, so
  vertical, bottom, curved-corner, and hypotenuse gaps share the same rendered
  normal distance and are no longer pinned by the outer `ClipPath`.
- The uniform bond-gauge edge inset is now doubled from the responsive
  `1.5-3px` range to `3-6px`. The rank-side cutoff uses a rounded-bottom mask at
  both the slanted and vertical intersections, and the numeric rank region is
  shifted left by a responsive `3-8px` so it is optically centered in the
  remaining lower triangle.
- The rounded-bottom host radius now compensates for the subsequent cleared
  inset: it uses `10px + inset + 0.5px` (`13.5-16.5px`) so the final visible
  lower corners retain approximately the same `10px` radius as the outer
  triangle instead of collapsing toward a sharp corner.
- Follow-up layout correction: container 5 now owns the four skills, container
  6 owns the three equipment slots and favorite item, and the bottom container
  9 is a locked potential-release (`심상개화`) placeholder.
- Position and combat class use title case (`Back`, `Striker`, `Special`).
  Weapon level now uses only `Lv. N`; the temporary firearm silhouette and the
  `Weapon` label were both removed.
- Combat-stat rows follow the 80-degree parallelogram rail with progressive
  horizontal offsets. The bond triangle now renders only the numeric rank.
- Bond-rank text is 1.8x larger (24 to 43.2 logical pixels) and centered on the
  right triangle's geometric centroid rather than a hand-tuned alignment.
- Filled the read-only student detail regions with level/position/role/weapon
  level, unique-weapon state and stars, four skills with `M` maxima, three
  equipment icons with tiers and levels, favorite-item state, scanned
  HP/ATK/DEF/HEAL values, ability-release values, and bond rank.
- Kept the unique-weapon region empty when the system is not unlocked. Unowned
  and multi-state presentation remains intentionally deferred.
- Extended the planning student-catalog contract with the three static
  equipment slot types so the Flutter surface can resolve the correct tiered
  assets without importing v6 runtime code. Regenerated
  `frontend/assets/student_catalog.json` from the v7 generated metadata.
- Expanded the deterministic 42-student mock roster with six-digit combat
  stats and favorite-item states while retaining evenly distributed
  progression.
- Verification: Python 123 tests passed; Flutter 263 tests passed before the
  final skill-label spacing and type-size adjustment;
  `flutter analyze` passed; Windows release build passed; the current release
  executable was visually checked with an owned student at 2560x1392, including
  the exact 80-degree separators, restored STATS width, centered ability values,
  label-free six-digit stats, the diagonal STATS header, and the bottom-up
  rounded-triangle bond gauge with a separated bottom rank. Final visual
  verification is intentionally left to the user as requested. After the
  latest STATS-divider correction, the focused student layout suite passed 38
  tests and `flutter analyze` reported no issues. The enlarged equal-inset bond
  gauge and horizontal STATS header retained the same 38-test and analyze pass.
  The actual-path bond inset replacement also passed the focused 38-test suite
  and `flutter analyze`. The doubled inset, rounded gauge base, and optical
  rank shift retained the same focused-suite and analyze pass.
  The compensated outer-radius bottom corners retained the 38-test and analyze
  pass.
- Artifacts: `frontend/lib/services/mock_student_fixture.dart`,
  `frontend/lib/ui/widgets/student_section_layout.dart`,
  `frontend/test/mock_student_fixture_test.dart`, and
  `frontend/test/student_studio_layout_test.dart`. Lessons and handoff:
  `almanac/design/student-detail-indicator-lessons-2026-08-01.md`.

### 2026-07-31 학생 탭 표시용 Mock 보유 학생 fixture

- 상태: `구현·집중 검증 완료`
- 기본 앱의 `MockAppService(fullStudentCatalog: true)`가 선택 프로필에 canonical 학생
  42명의 confirmed current를 주입한다. 축약형 테스트 Mock은 기존처럼 빈 repository를
  유지한다.
- 레벨은 1~90 전 구간에 분산하고 1~5성은 각 8~9명으로 균등 배치했다. 5성 학생은
  전용무기 1~4성을 모두 포함하며 인연, 스킬, 장비, 능력치도 서로 다른 순열로 분산해
  학생 탭의 표시·정렬 밑작업 fixture로 사용한다.
- 산출물: `frontend/lib/services/mock_student_fixture.dart`,
  `frontend/test/mock_student_fixture_test.dart`.
- 검증: fixture 분포·범위·고유 canonical ID와 portrait catalog 연결, 선택 프로필 주입,
  축약 Mock 비영향, `flutter analyze` 및 학생 화면·Studio 집중 40 tests 통과.

### 2026-07-30 standalone v6 developer tools migration

- Status: `complete`
- Migrated the student metadata editor, student template extractor, and
  inventory grid match inspector without copying Qt, QML, QWidget, Tkinter, or
  PySide6 presentation code.
- Added a short-lived protocol-v1 Python boundary at
  `backend/tools/developer_tools.py` and a dedicated Flutter Windows entry at
  `frontend/lib/developer_tools_main.dart`.
- Metadata edits atomically replace only generated declarations. Template
  extraction writes RGBA crops, extraction metadata, and updated recognition
  manifest integrity. Grid inspection uses the production v7 matcher and
  packaged regions without mutating scanner state.
- Artifacts: `docs/migration/developer-tools-migration.md`, three root `.cmd`
  launchers, `frontend/tool/build_windows_developer_tools.ps1`, and
  `release/developer_tools/`.
- Verification: Python 123 tests passed; Flutter 228 tests passed;
  `flutter analyze` passed; Windows release build passed; CodeAlmanac validate
  and health passed; all three tool modes remained alive as distinct launched
  OS processes.
- Next action: retain the three launchers as the supported entry points and
  rebuild the shared developer-tools bundle after Flutter tool UI changes.

#### Metadata editor Windows UTF-8 transport fix

- Fixed `FormatException: Unexpected extension byte` when Korean metadata was
  returned through a Windows pipe.
- Dart now launches Python with `PYTHONUTF8=1` and
  `PYTHONIOENCODING=utf-8`; the Python tool also reconfigures stdin, stdout, and
  stderr to UTF-8 as a transport-level invariant.
- Added a real Dart-to-Python process test that queries `hoshino` and verifies
  the decoded Korean display name.

이 문서는 P0~P6 워크플로가 모두 완료될 때까지 유지하는 활성 작업 기록이다. 새
대화에서 관련 작업을 시작할 때 가장 먼저 읽고, 단계의 상태·결정·산출물·다음 행동이
바뀐 작업이 끝날 때마다 갱신한다. [@agent-instructions]

## 기록 원칙

- 저장소나 사용자가 제공한 근거 없이 단계의 목적과 완료 상태를 추측하지 않는다.
- 각 단계의 `input.md`, `output.md`와 `artifacts/` 위치를 기록한다.
- 완료 판정은 마스터가 결과물을 직접 확인한 뒤에만 기록한다.
- 슬레이브의 완료 보고만 받은 상태는 `검증 중`이며 `완료`가 아니다.
- 중요한 설계 결정, 실패 원인, 보류 이유와 다음 행동을 남긴다.
- 코드와 문서가 이 기록과 다르면 코드 및 검증 결과를 우선하고 이 문서를 바로잡는다.
- P0~P6 전체가 완료되기 전에는 이 문서를 삭제하거나 완료 기록을 축약하지 않는다.
- 전체 완료 후에는 최종 상태와 검증 근거를 남긴 뒤 장기 결정 문서로 정리할 수 있다.

## 상태 값

| 상태 | 의미 |
|---|---|
| `정의 필요` | 단계 이름이나 완료 조건이 아직 확인되지 않음 |
| `대기` | 정의됐지만 선행 작업 또는 명령을 기다림 |
| `진행 중` | 마스터 또는 슬레이브가 작업 중 |
| `인계 대기` | 슬레이브가 결과를 만들었으나 `output.md`와 결과물 인계가 끝나지 않음 |
| `검증 중` | 마스터가 전달된 결과물을 확인 중 |
| `차단됨` | 구체적인 장애 때문에 진행할 수 없음 |
| `완료` | 마스터가 결과물과 완료 조건을 직접 확인함 |

## 단계 정의

단계의 고정된 목적과 완료 조건은
[P0-P6 Implementation Workflow](p0-p6-workflow)를 따른다. 이 문서는 그 정의를
반복하지 않고 현재 상태, 실제 산출물, 검증과 다음 행동을 기록한다.

## 현재 단계 현황

2026-07-23 P0 계약부터 P6 전 기본 탭 실제 데이터 통합까지 마스터가 완료 조건과 대조해 보완하고
인수했다. 최종 P6 검증은 Python 79개, Flutter 136개, `flutter analyze`, 실제 Python process와
MockAppService의 scan Hold/Approve → current → goal → gross → shortage → tactical → restart restore,
세 viewport, Almanac과 Windows release build를 통과했다. P6-7 변경은 아직 커밋되지 않았다.

| 단계 | 목적 | 상태 | 근거 또는 산출물 | 다음 행동 |
|---|---|---|---|---|
| P0 | planning IPC 계약과 공용 fixture | `완료` | schema·fixture, Python/Dart contract 및 parity test 통과 | 계약 변경 시 양쪽 fixture test 유지 |
| P1 | Python JSONL process와 Dart client | `완료` | lifecycle·오류·실제 세 method E2E 및 release build 통과 | P2가 `AppService` planning method만 사용하도록 유지 |
| P2 | 실제 계획 화면 수직 슬라이스 | `완료` | 인계 patch 적용 후 마스터 보완, Widget test 8개와 전체 39개·실제 backend·Mock·release 통과 | P4/P6 전까지 in-memory·총 필요량 경계 유지 |
| P3 | repository 특성화와 DTO 분리 | `완료` | 원본과 followup 2건 적용, DTO·fixture·비중첩·전체 검증 통과 | P4에서 승인된 DTO·병합 계약 유지 |
| P4 | 프로필과 repository 영구 저장 | `완료` | nested schema·40-case Python/Dart contract, typed state, atomic persistence와 실제 Dart↔Python restart E2E; Python 40·Flutter 43·analyze·release 통과 | P5에서 repository 확정과 분리된 scanner session 경계 작성 |
| P5 | scanner/matcher session protocol과 backend | `완료` | 40-path follow-up 인수와 마스터 보완; Python 59·Flutter 47·실제 process E2E·release asset gate 통과 | 2학생·2인벤토리 아이콘 제한 coverage를 유지하고 P6에서 scanner UI 연결 |
| P6 | 전 기본 탭 실제 데이터 통합 | `완료` | P6-1~P6-7 완료; Python 79·Flutter 136·analyze·release·실제 process/Mock 최종 E2E·3 viewport·Almanac 통과 | P7은 별도 승인 전 시작하지 않음 |

## 현재 결정

- P0은 planning wire 계약, P1은 그 계약의 실제 process transport로 분리한다.
- P2에서 계획 탭을 먼저 실제화하고 P6에서는 repository·scanner 결과까지 통합한다.
- P3는 실제 repository 쓰기보다 DTO와 v6 병합 parity를 먼저 완료한다.
- P5는 scanner 결과 생성과 repository 확정을 분리한다.
- P5 event는 session ID, generation과 단조 증가 sequence를 가지며 terminal 뒤 event와
  이전 generation의 지연 event는 typed state와 repository를 바꾸지 않는다.
- 낮은 confidence candidate는 자동 저장하지 않고 검토·수정과 expected repository
  revision/idempotency key를 가진 별도 commit만 P4 경계를 호출한다.
- recognition template·region·adaptive sample은 Flutter UI asset과 분리하며 manifest와
  SHA-256으로 배포 경계를 검증한다.
- P6은 총 7개 하위 단계다: P6-1 학생 → P6-2 인벤토리 → P6-3 스캔 → P6-4 홈 →
  P6-5 통계 → P6-6 전술대항전 → P6-7 설정 및 통합 오류 처리.
- P6 전체 완료는 P6-7까지 구현한 뒤 모든 기본 탭과 스캔 → 현재 상태 검토 → 목표 설정 →
  총 필요량 → 부족량 → 저장·복원 통합 흐름을 검증한 경우에만 판정한다. 이는 정식 출시가
  아니라 통합 베타 기준이다.
- P6 화면 설계 전 입력으로 `almanac/design/frontend-section-direction-and-user-flows.md`를
  사용한다. 이 문서는 사용자가 정한 80도 사선·글라스·부착면·전환 방향을 확정 규칙으로,
  계획 외 탭의 기능별 행동 순서를 검수 전 가설로 구분한다.
- 창 비율 대응은 `almanac/design/responsive-diagonal-layout-policy.md`의 제한된 레이아웃
  상태 제안을 검수한 뒤 확정한다. 전체 캔버스 일괄 축소와 제약 없는 자동 재배치는
  기본 전략으로 사용하지 않는다.
- 기능 화면은 한 섹션에 많은 기능을 압축하기보다 사용자 목적 단위의 여러 부착 섹션으로
  나눈다. 중앙에 독립적으로 떠 있는 섹션은 만들지 않는다.
- backend launcher 설정은 연결 시점에 지연 해석해 잘못된 경로에서도 shell을 띄운다.
- timeout 후 늦은 response ID는 진단만 남기지만, malformed response·method mismatch,
  허용되지 않은 오류 code·성공 payload와 stdin 실패는 연결 전체를 종료한다.
- P1의 실제 backend에는 scanner capability가 없으며 스캔 버튼을 비활성화한다.
- 슬레이브와 마스터가 다른 PC이면 로컬 절대경로를 인계로 인정하지 않고 ZIP,
  SHA-256, manifest와 마스터 실행 프롬프트 네 파일을 마스터 inbox로 옮긴다.
- 같은 신뢰 가능한 사설 Wi-Fi/LAN에서는 일회용 token 수신기로 네 파일을 무선
  전송하고 ZIP 검증 후 자동 종료한다. token은 결과물이나 장기 문서에 기록하지 않는다.
- 마스터는 `$HOME/.codex/ba-planner-slave/Receive-SlaveResult.ps1` 단일 래퍼로 결과
  수신·staging 검사·`MASTER_PROMPT.md` 클립보드 복사를 수행한다.
- 슬레이브는 `$HOME/.codex/ba-planner-slave/Send-SlaveResult.ps1` 단일 래퍼로
  패키징·UDP 마스터 자동 발견·무선 업로드를 수행하며 IP·port·token을 수동 입력하지 않는다.
- 현재 슬레이브 PC는 저장 공간 제약으로 Flutter/Dart SDK를 설치·사용하지 않으며
  CodeAlmanac CLI도 지원되지 않는다. 이는 작업 차단 사유가 아니라 검증 책임 분리 조건이다.
  슬레이브는 Python·정적 검사·patch·패키징을 수행하고 Flutter/Dart/analyze/release,
  실제 Dart↔Python E2E와 Almanac 검증은 `MASTER_REQUIRED`로 인계한다.
- 슬레이브가 작성한 Flutter/Dart code와 test는 마스터 검증 전 통과로 간주하지 않으며,
  슬레이브의 `COMPLETED`는 산출물 준비 완료일 뿐 단계 완료 승인이 아니다.
- Windows UDP discovery는 도달 불가능한 가상 어댑터의 ICMP connection-reset을 개별
  probe 잡음으로 무시하고 nonce가 일치하는 수신기 응답을 계속 기다린다.

## 확인된 P0/P1 산출물

- 계약: `contracts/planning-protocol-v1.schema.json`과 method/error schema
- fixture: `contracts/fixtures/planning_protocol_v1.json`
- Python: `backend/core/protocol_v1.py`, `stdio_server.py`, `backend_process.py`
- Dart: `backend_process.dart`, `planning_protocol_client.dart`, `process_app_service.dart`
- test: Python contract/stdio test와 Dart contract/client test
- 실행 선택: 기본 mock을 유지하며 dart-define으로 실제 backend를 선택

기존 슬레이브 `input.md`, `output.md`와 `artifacts/` 위치는 확인되지 않았다. 이후
사용자가 현재 작업 트리의 P0/P1을 이 워크플로에 맞게 직접 수정하도록 지시했고,
마스터가 코드·diff·테스트를 직접 보완하고 검증했으므로 기존 인계 누락은 P0/P1의
완료를 막지 않는 일회성 예외로 판정했다. P2부터는 Slave Artifact Handoff 계약을
생략하지 않는다.

## 현재 검증

- `codealmanac validate`: 통과, 6 pages
- `py -3.11 -m unittest discover -s tests -v`: 27 tests 통과
- P3 repository parity: 10 tests와 fixture 26 cases 통과; current/metadata field 교집합 없음, `display_name` confirmed/commit 유입 두 사례 거부
- `flutter analyze`: 문제 없음
- `flutter test`: 39 tests 통과
- P2 Widget test: 8 tests 통과(조회·중복·삭제·오류·Mock·목표 의미·합산·stale·좁은 화면)
- 실제 Python process의 student lookup, plan validation, calculation: 통과
- timeout, late response, malformed response, method mismatch, invalid error/success
  payload, stdin failure, unexpected exit, restart와 dispose: 통과
- `flutter build windows --release`: 통과
- `git diff --check`: 통과
- 금지된 GUI/v6 runtime import 검사: 유입 없음

## 다음 행동

1. `docs/migration/p5-scanner-matcher/slave-execution-prompt.md`를 슬레이브에게 전달한다.
2. 슬레이브는 P4 승인 baseline gate가 모두 통과한 경우에만 P5 구현을 시작한다.
3. P5 인계 전까지 scanner capability와 스캔 버튼은 비활성 상태를 유지한다.
4. P6 전까지 P2 결과는 보유량 차감 전 총 필요량이며 부족량을 표시하지 않는다.
5. P6 하위 단계의 화면 구성을 확정하기 전에 탭별 흐름 가설의 `사용자 검수 포인트`를
   사용자와 확인하고, 승인된 흐름만 실제 섹션 구성으로 변환한다.

## P6 UX 선행 입력 — 섹션 방향과 탭별 사용자 흐름

- 상태: `진행 중`
- 목적: 실제 P6 화면 배치 전에 공통 섹션 규칙과 계획 외 탭의 기능별 행동 흐름을 고정
- 입력: 사용자 제공 프론트엔드 디자인 방향, P6 탭별 기능, v6 사용자 흐름 감사
- 출력 보고서: `almanac/design/frontend-section-direction-and-user-flows.md`,
  `almanac/design/responsive-diagonal-layout-policy.md`
- 결과물: 80도 사선·부착면·글라스·모션 계약, 탭별 기능 그룹·주 흐름·탭 간 인계·검수 질문,
  창 비율별 제한된 레이아웃 상태와 사선 안전 폭 계약 제안
- 검증: `AppSection.primary`, P6 탭별 기능과 v6 보존 흐름 대조; `codealmanac validate`와
  `codealmanac health` 통과(8 pages, orphan·dead ref·broken link·citation 문제 없음)
- 결정 및 제약: 계획 탭은 사용자가 이미 기획한 기준 사례로만 기록하며 재설계하지 않음;
  나머지 탭의 흐름은 화면 배치가 아니라 검수 전 가설임
- 차단 사항: 없음
- 다음 행동: 사용자가 탭별 우선순위·흐름 분기점과 반응형 정책의 승인 항목을 검수한 뒤
  실제 섹션 구성 및 지원 최소 창 크기를 별도 확정
- 최종 갱신: 2026-07-22

## P6 이후 섹션 템플릿 Studio

- 상태: `초기 구현 완료`
- 목적: 실제 탭 재디자인 전에 섹션 점유 공간·80도 형상·허용 조합을 개발 화면에서 검증
- 산출물: `frontend/lib/ui/studio/section_template.dart`,
  `frontend/lib/ui/pages/section_template_studio_page.dart`,
  `frontend/lib/ui/widgets/section_template_surface.dart`,
  `frontend/test/section_template_studio_test.dart`,
  `almanac/design/section-template-studio.md`
- 결정: 단일/조합 모드와 고정 조합 preset을 제거하고 사용자 정의 요소 목록 하나로 통합한다.
  Section이 하나면 단일, 둘 이상이면 조합이며 사용자가 Section을 직접 추가·삭제·선택하고
  X·Y·폭·높이를 편집한다. 전역 96×96 논리 사선 격자에서 8칸마다 major line을
  표시하고 한 칸을 섹션 사이 기본 간격으로 사용한다. 모든 사선은
  우측 위 `/` 방향 80도로 고정하고 반대 방향 및 상·하 방향 사선은 허용하지 않는다.
  형상 입력은 삼각형·사다리꼴·평행사변형 모드, 붙는 면과 면 내부 96분할 범위로 구성하고
  사다리꼴·평행사변형만 높이를 추가로 받는다. 채팅 전달용 요약 복사를 제공한다.
  모든 요소는 별도 Positioned clip 영역 없이 하나의 콘텐츠 캔버스 Size·원점에서 절대
  좌표 path로 함께 그린다. 따라서 사선이 요소 rect를 넘어도 공용 캔버스 안에서는 잘리지
  않는다. 선택 요소의 본체 drag는 이동, 네 모서리 handle drag는 resize이며 두 조작 모두
  실제 pointer delta를 정수 grid cell로 snap하고 최소 1칸과 96×96 캔버스 경계에서 clamp한다.
  프리뷰 상단 고정 헤더는 0/96~48/96 비율을 선택하고 남은
  콘텐츠 영역만 섹션 geometry에 사용한다. 모든 polygon 꼭짓점에 corner radius를 적용하며
  예각은 직선 구간을 더 유지하는 36% 접점과 polygon winding 방향의 볼록한 원형 fillet로
  더 깊게 잘라 둥글리며 반대 원 중심에서 생기는 오목한 패임을 허용하지 않는다.
  구성 저장은 version 5 UTF-8 JSON(`*.ba-section-studio.json`)을 사용하고 version 1~4 read 호환을
  유지하며 format/version, Section 96×96 grid, 하위 부모 상대 배치·공통 간격, 우측 위 80° 사선
  계약, workspace 표시 상태와 모든 요소 설정을 기록한다.
  불러오기는 문서 전체의 타입·범위·중복 ID·선택 ID를 검증한 뒤에만 캔버스를 원자적으로
  교체하며 손상·비호환 파일은 기존 상태를 보존한다. Windows 기본 파일 대화상자는 Flutter
  공식 `file_selector`로 연결하고 service 주입 경계로 실제 파일 시스템 없이 회귀 test한다.
  개발 상태 패널에서만 Studio에 진입하며 기존 실제 탭의 `DiagonalSection`은 아직 교체하지 않는다.
- 검증: Section 범위·중첩과 하위 부모 경계·아이템 간격 validator, 공용 캔버스 rect 외 경로
  보존과 hit test, 형상 geometry, 요소 추가·선택·편집, Section grid snap과 하위 간격 snap,
  resize·경계 clamp, viewport 전환,
  AppShell 개발 패널 진입과 전체 요소
  채팅용 요약 복사, versioned JSON round-trip·schema 거부·저장·원자적 불러오기 Widget test;
  `flutter analyze`, Flutter 전체 tests, `flutter build windows --release`, `git diff --check`,
  `codealmanac validate`, `codealmanac health` 통과. 현재 host의 Windows 개발자 모드는 꺼져 있어
  Flutter가 plugin symlink를 직접 만들 수 없으므로 ignored ephemeral 폴더에 같은 package target의
  directory junction을 생성한 뒤 release를 검증했으며 시스템 설정은 변경하지 않음
- 후속 레이어 확장: Section은 전역 96×96 좌표계를 유지하고 Container → Feature는 각 부모의
  경계 상자에 대한 0~1 비율 rect를 사용하도록 정리했다. 하위 요소 drag는 부모 테두리와 형제
  아이템 사이의 선택 간격에 snap하며 resize는 부모 경계에서 clamp된다. 2026-07-26 후속 보정으로
  이 간격 계산을 rect의 네 변 비교에서 실제 둥근 polygon path 사이 최단거리로 교체했다.
  부모의 짧은 변에 대한 비율을 pixel 거리로 환산하고 평행사변형 사선의 법선 방향 snap,
  경계 밖 이동 복귀, 실제 path 중첩·간격 validator와 최단거리 guide를 같은 계산으로 통일했다.
  Container와 shape
  Feature는 삼각형·사다리꼴·평행사변형 및 80° 계약을 공유하고 부모 path 안에서 렌더링·hit
  test한다. image Feature는 252×172 기본 이미지, 863×250 Plan A 타이틀과 둥근 화살표 preset을
  사용하며 입력·handle resize 모두 선택 preset 비율을 고정한다. 저장 문서는
  계층·부모 ID·image metadata·부모 상대 배치·공통 간격을 포함하는 version 4를 거쳐, 0% 헤더,
  Container BA 삼각 무늬와 image preset·text·line Feature를 저장하는 version 5로 올렸다. v1~v4를
  읽으며 v1~v3의
  하위 96 좌표를 읽을 때 비율 rect로 변환한다.
  Windows release 동기화는 기존 `release/` 루트의 `*.ba-section-studio.json`을 staging으로
  승계한 뒤 번들을 교체해 사용자 배치 문서를 삭제하지 않는다.
  `저장 파일에서 섹션 추가`는 현재 workspace에 section을 append하며 모든 자식 ID와 parent 참조를
  충돌 없는 새 ID로 remap한다. 제공받은 863×250 Plan A 타이틀 PNG는 Studio asset으로 복사하고,
  화살표 preset은 별도 bitmap 없이 둥근 stroke path로 렌더링한다. Container 삼각 무늬는 기존
  `BATriangleTexturePainter`를 고정 seed·저대비 설정으로 재사용한다. Flutter 전체 161 tests,
  `flutter analyze`, Windows release build,
  `codealmanac validate`·`health`와 `git diff --check`를 후속 확장 기준으로 통과했다.
- 2026-07-26 최신 Studio v5 빌드는 `flutter build windows --release`까지 통과했다. 현재 사용자가
  `release/ba_planner_v7.exe`를 실행 중이어서 release 동기화의 실행 파일 교체만 Windows 파일 잠금으로
  보류했다. 앱을 닫은 뒤 `frontend/tool/build_windows_release.ps1`을 다시 실행하면 기존 Studio JSON을
  보존하면서 새 번들로 교체된다.
- 2026-07-26 Title 계정 생성·관리 클러스터를
  `release/section-account-create-manager.ba-section-studio.json`에서 typed projection했다. 재저장된
  문서를 다시 확인해 이전 export에 없었던 Section 5·Container 11~16·18·19·Feature 5~8의 임시
  runtime 배치를 폐기하고 저장 좌표와 polygon으로 교체했다. typed 문서 encode 결과와 저장 JSON
  전체를 비교하는 회귀 test를 추가했으며 Container 15 목록 행, Container 16 portrait, Feature
  5·6·7의 계정명·구분선·학생 수, Feature 8 입력 영역의 실제 배치도 검증한다. 부모 Section fill은
  자식 입력·텍스처·목록 path를 차감해 반투명 표면이 중복 합성되지 않게 했다. 첫 계정은 Section 1만,
  Title 설정은 Section 5만 진입하고 추가·수정은 Section 1,
  사진 선택은 Section 4를 호출한다. 4열 portrait scroll grid는 asset manifest의 전체 portrait를
  `AssetImageGrid`로 직접 paint하며 square→98% portrait, 내부 여백·간격·2% pink 선택 stroke를 같은
  painter가 처리한다. profile summary에 `avatar_student_id`를 호환 추가하고 update/delete protocol,
  Mock·Python atomic store와 실제 Dart↔Python restart E2E를 확장했다. 계정 삭제는 UI 확인 후에만
  실행한다. Python 80개, Flutter 174개, `flutter analyze`, Windows release build,
  `codealmanac validate`·`health`와 `git diff --check`가 통과했다.
- 2026-07-26 계정 클러스터 후속 조정으로 Section 5 호출/퇴장을 0°/180°, Section 1·4를
  80°/260°로 분리하고 비직교 벡터의 X·Y 성분과 진행 방향을 Widget test로 고정했다. Section 5의
  Container 12·13·14·18·19는 동일 높이·세로 간격과 Container 11 사선까지의 동일 간격으로
  재배치했다. Container 11에는 삼각 무늬를 그리지 않으며, Container 15·16을 내부 여백 안으로
  옮기고 각 목록 행이 scroll offset에 따라 80° 경계를 따라 이동하도록 변경했다. 저장 Studio
  JSON과 typed projection을 함께 갱신했다. Flutter 171개, `flutter analyze`, Windows release
  build, `codealmanac validate`·`health`와 `git diff --check`를 검증 기준으로 사용한다.
- 2026-07-26 재수정된 계정 Studio JSON의 Container 11~19와 Feature 5~7 좌표 및 workspace 선택을
  typed projection에 다시 반영했다. Section 4 portrait grid는 행별 viewport 위치에 따라 위쪽
  80°·아래쪽 역방향 260°가 되는 직선 scroll 궤적을 사용하고 painter와 hit test가 같은 X offset을
  공유한다. 선택 stroke는 cell RRect 대신 `square.png` alpha silhouette를 확장·내부 제거해 그린다.
  Flutter 172개와 `flutter analyze`가 통과했다.
- 2026-07-26 Section 5·1·4를 독립 animation controller로 분리했다. 관리 화면의 추가·수정은 Section
  5를 유지한 채 Section 1을 열고, Section 4 닫기·저장은 Section 4만 퇴장한다. Section 1 뒤로는
  첫 계정 경로에서 Title로, 관리 경로에서는 Section 4와 Section 1만 퇴장해 Section 5로 돌아간다.
  관리 버튼 폭은 매 viewport에서 Container 11 실제 polygon 경계를 기준으로 같은 간격이 되도록
  재계산한다. Section 4에는 grid 궤적을 따르는 custom scrollbar track·handle과 drag mapping을
  추가했다. Flutter 174개와 `flutter analyze`가 통과했다.
- 2026-07-26 Section 4 portrait grid와 custom scrollbar의 위치별 곡선 보간을 제거하고, 전체
  viewport에서 고정 80° 직선(역방향 260°) 하나를 공유하도록 수정했다. 행 painter·hit test와
  scrollbar track·handle은 동일한 선형 X offset을 사용한다. Flutter 174개, `flutter analyze`,
  Windows release build, `codealmanac validate`·`health`와 `git diff --check`가 통과했다.
- 2026-07-26 Section 4 grid painter가 loose cross-axis constraint에서 폭 0으로 축소되던 경로를
  `StackFit.expand`로 고쳐 Container 8 폭을 사용하게 했다. Section 5 계정 행은 Container 11의
  중앙 80° 기준선에 맞추고 기존 사선 scroll translation을 유지한다. Title Space 단축키는 Title이
  실제 활성 상태일 때만 시작 동작을 호출한다. Flutter 174개, `flutter analyze`, Windows release
  build, `codealmanac validate`·`health`와 `git diff --check`가 통과했다.
- 2026-07-26 계정명 입력의 별도 진한 표면·border·fill을 제거하고, 기존 이름 편집 시 selection을
  문자열 끝으로 설정해 한글 IME cursor 위치를 고정했다. Container 3은 Container 4 square의 실제
  path 폭과 80° 중심선을 공유한다. Section 5·1·4가 모두 열린 상태의 Section 1 뒤로는 세 Section을
  모두 퇴장시켜 Title로 돌아가며, Container 11에는 행과 같은 80° custom scrollbar를 추가했다.
  Flutter 174개, `flutter analyze`, Windows release build, `codealmanac validate`·`health`와
  `git diff --check`가 통과했다.
- 2026-07-26 후속 수정으로 계정명 controller가 각 Windows IME composing update의 selection을
  `composing.end`로 정규화하도록 변경했다. Container 3 폭은 `square.png` 252×204 전체 캔버스가
  아니라 중앙 정사각 이미지의 204px 한 변에 실제 contain 배율을 적용한 길이를 사용한다.
  Flutter 174개, `flutter analyze`, Windows release build, `codealmanac validate`·`health`와
  `git diff --check`가 통과했다.
- 2026-07-26 위 selection 정규화가 Windows 한글 IME와 편집 상태를 왕복해 `ㄱ거거` 중복 입력을
  일으키는 것을 실기기 재현으로 확인했다. 정규화 listener를 제거해 IME의 composing text·selection·
  range를 그대로 보존하고, 조합 중에만 기본 cursor를 숨긴 뒤 commit 시 다시 표시하도록 교체했다.
  Flutter 174개, `flutter analyze`, Windows release build, `codealmanac validate`·`health`와
  `git diff --check`가 통과했다.
- 2026-07-26 이번 계정 클러스터 적용의 시행착오를 `almanac/design/section-template-studio.md`의
  `계정 클러스터 적용 시행착오와 재발 방지`에 통합했다. 저장 전후 Studio 좌표 불일치, polygon
  경계 기반 동적 버튼 폭, 80° 직선 scroll의 painter·hit test·scrollbar 좌표 공유, loose constraint로
  폭 0이 된 grid, square alpha silhouette 선택선, 중첩 Section 상태 전이, Title Space shortcut 범위,
  Windows IME composing selection 강제 변경에 따른 중복 입력과 최종 cursor-only 대응을 원인·실패
  방식·재발 방지 규칙으로 기록했다.
- 2026-07-26 Section 1 editor, Section 4 asset picker, Section 5 manager를 요소 번호별 작업 스타일로
  문서화했다. Container 3~16·18·19와 Feature 4~8의 표면·이미지·text·click·상태 전이 계약을
  기록하고, 유사 위젯에는 별도 지시가 없으면 list/grid의 표준 수직 ScrollController를 유지하면서
  row·자식·hit test·custom scrollbar를 같은 80° 직선으로 투영하는 기본 경향을 적용하기로 했다.
  이 공통 scroll 계약은 `almanac/design/responsive-diagonal-layout-policy.md`에도 반영했다.
- 2026-07-27 Title의 밝은 삼각 무늬 행동 버튼 팔레트를 하늘색에서 공용 핑크색 계열로 변경했다.
  메인 시작·설정·종료와 계정 클러스터의 변경·뒤로·저장·닫기·전환·추가·수정·삭제가 같은
  공용 action 색상군을 사용하며, 어두운 계정 row와 scrollbar는 범위에서
  제외했다. 밝은 삼각 무늬 버튼은 핑크색 계열을 사용한다는 공통 스타일도 Almanac에 기록했다.
  Title 집중 14개와 Flutter 전체 171개 test, `flutter analyze`, Windows release build가 통과했다.
- 2026-07-27 후속 검수에서 첫 핑크 팔레트의 base·panel이 너무 진한 자주색으로 보이는 문제를
  확인해, 테두리 강조색에 가까운 저채도 연핑크색으로 올렸다. texture geometry·seed·대비는
  변경하지 않았으며 Almanac의 밝은 삼각 무늬 버튼 규칙도 진한 자주색을 사용하지 않도록 구체화했다.
  연핑크 hue·명도 계약을 추가했고 Title 집중 15개, Flutter 전체 172개 test, `flutter analyze`,
  Windows release build가 통과했다.
- 2026-07-27 두 번째 연핑크 팔레트도 넓은 버튼 면에서 너무 튄다는 검수에 따라 Title 로고 PNG의
  대표 핑크 `#E08EE6`을 직접 추출했다. 이를 흰색 쪽으로 옅게 섞고 base alpha를 약 53%로 낮춘
  `BATrianglePalette.softTitlePink*`로 교체해 로고 hue는 공유하되 표면 대비는 낮췄다. Title 집중
  15개와 Flutter 전체 172개 test, `flutter analyze`, Windows release build가 통과했다.
- 2026-07-27 Title 패널의 기본 brand·primary·account Section과 계정 editor·picker·manager Section
  모두에 공용 `paintLiftedPathShadow` 기반 그림자를 추가했다. 각 그림자는 차감 전 Section polygon을
  사용하고 motion subtree 안에서 표면과 함께 이동하며 버튼·목록에는 중복 적용하지 않는다. Title
  집중 15개와 Flutter 전체 172개 test, `flutter analyze`, Windows release build가 통과했다.
- 다음 행동: 사용자가 0% 헤더, Container 삼각 무늬, 세 image preset과 text·line Feature를 수동
  검수하고 Title 계정 클러스터를 수동 확인한 뒤 Dart spec export와 공용 `SectionGeometry` 승격
  범위를 결정
- 최종 갱신: 2026-07-27

## 마스터 사용량 중단 시 슬레이브 작업 규칙

마스터의 사용량이 중간에 끊기거나 마스터가 결과를 즉시 검사할 수 없을 때도 슬레이브는
이미 전달받은 현재 단계의 `input.md` 범위 안에서 작업을 계속할 수 있다. 다만 슬레이브의
`COMPLETED` 보고는 마스터의 수신·검증·적용을 대신하지 않으며, 마스터 검증 없이 다음 의존
단계를 구현하지 않는다.

### 공통으로 계속할 수 있는 작업

1. 이미 지시받은 현재 단계의 구현, 테스트, 문서화와 자체 검증을 끝낸다.
2. 최종 patch, fixture, 검증 로그 등 실제 결과물을 `artifacts/`에 저장한다.
3. 각 결과물의 크기와 SHA-256을 기록한 `output.md`를 작성하고 인계 패키지를 준비한다.
4. 실패·미검증·환경 제한과 마스터가 결정해야 할 사항을 `output.md`에 명시한다.
5. 다음 단계에 필요한 v6 동작 조사, 현재 코드 경계 목록, 위험 목록과 테스트 사례를 읽기
   전용 조사 산출물로 준비할 수 있다.
6. 마스터가 복귀할 때까지 원래 결과물과 전송 패키지를 보존하며, 임의로 재생성하거나
   다른 단계 결과와 합치지 않는다.

### 마스터 검증 전 금지 작업

- 슬레이브가 자신의 결과를 승인·적용된 것으로 간주하거나 이 상태 문서를 `완료`로 바꾸는 일
- 현재 단계 결과를 전제로 다음 의존 단계의 production 구현을 시작하는 일
- 아직 승인되지 않은 DTO, protocol, event schema 또는 repository 경계를 사실상 확정하는 일
- 마스터 작업공간에 patch를 직접 적용하거나 여러 단계 patch를 하나로 합치는 일
- `../v6` runtime import, 실제 사용자 프로필 변경 또는 명시되지 않은 migration 실행
- 마스터 지시 없이 기존 결과물을 폐기·재생성하거나 파일명과 인계 경로를 바꾸는 일

### 단계별 대기 작업

| 마스터 중단 시점 | 슬레이브가 할 수 있는 작업 | 넘어가면 안 되는 경계 |
|---|---|---|
| P3 검증 전 | P3 follow-up 완료·자체 테스트·패키징, P4의 atomic write·손상·migration·revision 시험 항목 조사 | P4 영구 저장 구현 |
| P4 지시 전 | v6 프로필 저장 동작과 오류 사례 조사, 저장 파일 소유권·migration 위험·contract test 표 초안 | 승인되지 않은 P3 DTO를 사용한 P4 코드 |
| P4 작업 중 | 전달받은 P4 범위 구현·전체 검증·패키징 | 자신의 P4 결과를 전제로 한 P5 구현 |
| P5 지시 전 | v6 scanner/capture/matcher 의존성 조사, event 종류·취소·stale·confidence fixture 후보와 recognition asset 목록 작성 | session protocol 확정, backend 연결, repository commit 구현 |
| P5 작업 중 | 전달받은 P5 범위 구현·headless test·asset 검사·패키징 | 자신의 P5 결과를 전제로 한 P6 실제 연결 |
| P6 지시 전 | 탭별 placeholder·공용 widget·필요 service 목록, loading/empty/error/disconnected 및 대용량 UI test matrix 작성 | 실제 repository/scanner client 연결 |
| P6 작업 중 | 마스터가 지정한 단일 P6 하위 단계만 구현·검증·패키징 | 다음 P6 하위 단계나 미승인 service 계약으로 범위 확대 |

P4, P5와 P6은 순차 의존하므로 마스터가 없는 동안 자동 연쇄 실행하지 않는다. 병렬 준비는
선행 계약을 바꾸지 않는 조사, fixture 후보, 테스트 계획과 UI 현황 목록으로 제한한다.

## P2 — 계획 화면 수직 슬라이스

- 상태: `완료`
- 목적: 계획 placeholder를 학생 목표 편집과 총 필요량 계산이 가능한 실제 화면으로 교체
- 완료 조건: AppService planning method만 사용하는 학생별·전체 계산, 필수 상태와 Widget test, 전체 검증 통과
- 입력: `docs/migration/p2-planning-screen/input.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p2-planning-screen/staging/master-verify-20260722-000001-a8bb6fea/output.md`
- 결과물: 같은 staging의 `artifacts/p2-planning-screen.patch`, `artifacts/verification.txt`; 수신 ZIP SHA-256 `16b833cde5201f3dd90e08d56ccbce223f5ee40d78c4f1257ea15daf063cdc87`
- 검증: ZIP·manifest·산출물 크기/SHA-256 일치, 무중첩 확인, `git apply --check` 후 적용; Python 17, Flutter 39, analyze, 실제 Python process E2E, Mock flow, Windows release, Almanac와 diff 검사 통과
- 결정 및 제약: 정확한 학생 ID 조회, in-memory 임시 현재 상태, AppService planning method만 사용, 부족량·저장·scanner 제외
- 차단 사항: 없음
- 다음 행동: 작성된 P3 작업 지시를 슬레이브에게 전달하고 DTO·병합 fixture 결과 인계 대기
- 최종 갱신: 2026-07-22

## P3 — Repository 특성화와 DTO 분리

- 상태: `완료`
- 목적: v6 repository의 scanner·storage 결합을 특성화하고 독립 DTO와 순수 병합 parity 경계를 확정
- 완료 조건: scanner/matcher 없이 fixture 재생, 다섯 데이터 버킷 매핑 고정, v6 runtime import 없는 parity test, 실제 사용자 저장소 쓰기 없음
- 입력: `docs/migration/p3-repository-dto/input.md`
- 추가 입력: `docs/migration/p3-repository-dto-followup-1/input.md`
- 추가 입력 2: `docs/migration/p3-repository-dto-followup-2/input.md`
- 출력 보고서: 원본 `docs/migration/handoffs/incoming/ba-planner-v7-p3-repository-dto/staging/20260722-004918-138dd469/output.md`; followup-1 `docs/migration/handoffs/incoming/ba-planner-v7-p3-repository-dto-followup-1/staging/20260722-012000-57ed5103/output.md`; followup-2 `docs/migration/handoffs/incoming/ba-planner-v7-p3-repository-dto-followup-2/staging/20260722-020150-bead4898/output.md`
- 결과물: followup-2 staging의 `artifacts/p3-repository-dto-followup-2.patch`, `artifacts/verification.txt`; followup-2 ZIP SHA-256 `af07c2538b63cdb9cd03601a4bde8d28ce5324372f439884f052853e30823560`
- 검증: 세 패키지의 ZIP·manifest·sidecar·artifact 해시와 단계별 baseline·무중첩 확인, 각 `git apply --check` 후 증분 적용; P3 10 tests·fixture 26 cases, Python 27, Flutter 39, analyze, Windows release, Almanac, diff, 실제 backend 세 method E2E와 Mock 계획 흐름 통과; current/metadata 교집합 `set()`, `display_name` confirmed/commit 유입 두 사례 모두 `RepositoryDTOError`
- 결정 및 제약: P3는 DTO·순수 병합·fixture·문서·test만 구현하며 영구 저장은 P4, scanner session/backend는 P5에 남김
- 차단 사항: 없음
- 다음 행동: P4가 아래 승인 baseline을 변경 전 gate로 재현하도록 유지
- 최종 갱신: 2026-07-22

### P3 승인 baseline

P3 완료는 현재 작업 트리의 다음 파일과 실행 결과를 P4의 불변 입력으로 승인한 것을
뜻한다. P4 슬레이브는 구현 전에 이 baseline을 재현하며, 하나라도 다르면 P3를 임의로
수정하지 않고 `BLOCKED`로 반환한다.

- 승인 파일: `backend/core/repository_dto.py`, `backend/core/repository_merge.py`,
  `backend/tests/test_repository_parity.py`, `contracts/fixtures/repository_v6_parity.json`,
  `docs/migration/p3-repository-dto/repository-characterization.md`,
  `docs/migration/p3-repository-dto/repository-protocol-draft.md`
- fixture 기준: version 1, 26 cases(`student_merge` 6, `inventory_normalize` 3,
  `inventory_merge` 2, `inventory_order` 1, `inventory_diff` 1, `resolve` 2,
  `dto_error` 10, `bucket_mapping` 1)
- test 기준: `tests.test_repository_parity` 10 tests, 변경 전 전체 Python 27 tests
- field 기준: `CONFIRMED_STUDENT_VALUE_FIELDS`와 `StudentMeta.__annotations__` 교집합
  `set()`; `display_name`의 confirmed-current 및 student commit 유입 모두 거부
- 책임 기준: P3는 독립 DTO, 순수 병합, fixture와 특성화만 소유한다. filesystem/SQLite
  I/O, profile catalog, atomic persistence와 migration은 P4가 소유한다.
- 금지 기준: 실제 사용자 저장소 쓰기, `../v6`·scanner·GUI runtime import, 정적 metadata,
  goal, 총 계산 결과 또는 shortage의 confirmed-current/inventory 유입 없음

## P4 — Repository와 프로필 영구 저장

- 상태: `완료`
- 목적: Python backend가 프로필, 확정 현재 상태, 인벤토리와 사용자 목표의 안전한 저장·복원을 소유
- 완료 조건: 재실행 복원, atomic failure 시 기존 데이터 보존, revision/idempotency 및 손상·병합 fixture, Python/Dart contract와 전체 검증 통과
- 입력: `docs/migration/p4-repository-persistence/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p4-repository-persistence/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence/staging/20260722-124720-98185035/output.md`
- 결과물: 같은 staging의 `artifacts/p4-repository-persistence.patch`, `artifacts/verification.txt`; ZIP SHA-256 `f14f7d07f7908b71d87af136e3afbe027cf9c6c338c958a40eea52d73776143f`
- 검증: ZIP 21,647 bytes와 SHA-256이 사용자 값·manifest·sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. 21개 patch path가 모두 `BA Planner/v7/...`이고 기존 Almanac 변경과 중첩 없이 `git apply --check` 및 적용 통과. P3+P4 집중 Python 20, 전체 Python 37, `flutter analyze`, Windows release build, `codealmanac validate`, `git diff --check` 통과. Flutter 전체 41개 중 나머지 40개는 통과했으나 신규 profile panel test 1개가 disposed `TextEditingController` 재사용으로 실패. 수동 corruption probe에서 malformed catalog entry는 raw `KeyError`, malformed profile `idempotency`는 raw `AttributeError`를 발생시켜 구조화된 `corrupt_data` fail-closed 조건을 충족하지 못함. repository schema는 임의 success payload도 유효 판정하며 Dart fixture test는 case별 `valid`를 검증하지 않음
- 결정 및 제약: P4는 저장·profile·repository protocol과 최소 profile UI만 구현하며 scanner session/backend는 P5, 전 탭 통합은 P6에 남김
- 원본 인계 차단 이력: profile dialog lifecycle과 손상 catalog/idempotency raw 예외는 follow-up-1에서 해결됨; method별 success response schema와 Dart contract 검증은 미해결
- 보완 입력: `docs/migration/p4-repository-persistence-followup-1/input.md`
- 보완 슬레이브 실행 프롬프트: `docs/migration/p4-repository-persistence-followup-1/slave-execution-prompt.md`
- 보완 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence-followup-1/staging/20260722-141231-dda5ceb6/output.md`
- 보완 결과물: 같은 staging의 `artifacts/p4-repository-persistence-followup-1.patch`, `artifacts/verification.txt`; ZIP SHA-256 `d1cc336970efcd1ae8dac08163452102af22b526f17f770072d854c2d04c33c9`
- 보완 검증: ZIP 6,982 bytes와 SHA-256이 사용자 값·manifest·sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. 4개 증분 path가 모두 `BA Planner/v7/...`이며 현재 상태 문서와 중첩 없이 apply-check·적용 통과. 집중 Python 22, 전체 Python 39, Flutter 41, analyze, Windows release, Almanac와 diff 검사 통과. profile create/select/rename/cancel/빈 입력 lifecycle test 통과; malformed catalog와 idempotency가 모두 `corrupt_data`로 fail-closed함. 반면 `{ "nonsense": true }` profile-list success가 schema에서 여전히 유효하며 method별 success schema, Dart valid/invalid validator와 runtime rejection, typed repository state 및 real Dart/Python restart E2E는 미구현임
- 차단 사항: follow-up-1은 lifecycle/corruption을 해결했고 follow-up-2 부분 증분은 method별 top-level success schema만 해결함. Dart fixture validator, runtime malformed-success 차단, typed repository state, real Dart/Python restart E2E와 nested request/state schema가 미구현임. 전달문이 P4 follow-up task를 P2 및 `p2-planning-screen.patch`로 부르는 복사 오류도 남아 있음
- 보완 입력 2: `docs/migration/p4-repository-persistence-followup-2/input.md`
- 보완 슬레이브 실행 프롬프트 2: `docs/migration/p4-repository-persistence-followup-2/slave-execution-prompt.md`
- 보완 출력 보고서 2: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence-followup-2/staging/20260722-150536-0faf9415/output.md`
- 보완 결과물 2: 같은 staging의 `artifacts/p4-repository-persistence-followup-2.patch`, `artifacts/verification.txt`; ZIP SHA-256 `2d985e43867337843da811e08b02876cf4b340c575846f7028f03e717bb5085e`
- 보완 검증 2: ZIP 5,539 bytes와 SHA-256이 사용자 값·manifest·sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. schema·fixture 2개 증분 path가 `BA Planner/v7/...`이며 apply-check·적용 통과. repository fixture는 28 cases(valid 14/invalid 14), Python 집중 22·전체 39, Flutter 41, analyze와 Windows release 통과. 모든 repository method의 top-level nonsense success는 schema에서 거부됨. 그러나 confirmed current의 `display_name`/`shortages`와 goal `target_level: 999`가 포함된 state response, junk student update, 빈 inventory/goals update request가 여전히 schema에서 유효함. Dart test는 `valid`를 읽지 않고 runtime client는 `repository.*` success를 무조건 허용하며 service/UI는 raw state map을 사용함. 실제 Dart↔Python restart E2E 없음
- 보완 입력 3: `docs/migration/p4-repository-persistence-followup-3/input.md`
- 보완 슬레이브 실행 프롬프트 3: `docs/migration/p4-repository-persistence-followup-3/slave-execution-prompt.md`
- 보완 출력 보고서 3: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence-followup-3/staging/20260722-161431-fa2a3481/output.md` (`BLOCKED`)
- 보완 결과물 3: 같은 staging의 `artifacts/p4-repository-persistence-followup-3.patch` 50,024 bytes, SHA-256 `79b403e7a44a175c58ad37cc95f8b503ab74c7e61a2999337710988285af4982`; `artifacts/verification.txt` 3,733 bytes, SHA-256 `14980ff4d86dd5141306ad80b527a0304777267407c4b342a890e94dfd410bed`; ZIP 12,769 bytes, SHA-256 `2d032d42a459e9e788ac7658bb45bd5f47ff61354c54035595e5d24dd2dda809`
- 보완 검증 3: ZIP 크기·SHA-256이 사용자 값, manifest와 sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. unique staging에만 해제했고 10개 patch path가 모두 `BA Planner/v7/...`이며 기존 상태 문서 변경과 중첩 없이 `git apply --check --verbose` 및 적용 통과. repository fixture는 40 cases(valid 14/invalid 26)이며 Dart가 모든 case의 `valid`를 비교하고 Python schema·DTO contract 집중 23 및 전체 Python 40 tests가 통과함. malformed repository success fatal/restart test, typed repository state, Mock profile flow, Python 자체 child-process 재시작 복원, Flutter 전체 42 tests, Windows release, Almanac와 diff 검사가 통과함. 그러나 `flutter analyze`는 `repository_service.dart` 82·181행의 `curly_braces_in_flow_control_structures` 2건으로 실패함
- follow-up-3 차단 이력: 필수 실제 Dart `ProcessAppService` ↔ Python child-process temporary-root 종료·재시작·복원 E2E, analyzer 정리와 nested strict contract·typed state·E2E 문서 갱신이 누락됐음
- 보완 입력 4: `docs/migration/p4-repository-persistence-followup-4/input.md`
- 보완 슬레이브 실행 프롬프트 4: `docs/migration/p4-repository-persistence-followup-4/slave-execution-prompt.md`
- 마스터 직접 보완: 슬레이브 환경에 Flutter/Dart/CodeAlmanac이 없어 follow-up-4 실행이 불가능했으므로 마스터 작업트리에서 `BackendProcessConfig`의 immutable test environment override, 실제 repository process restart E2E, analyzer block 수정과 계약·저장·runtime 문서를 직접 완성함
- 최종 검증: P3/P4 집중 Python 23, 전체 Python 40, repository fixture 40 cases(valid 14/invalid 26), Flutter 전체 43, `flutter analyze`, Windows release build, `codealmanac validate`, `git diff --check` 통과. 실제 E2E는 Dart가 시작한 서로 다른 Python child process 2개를 순차 종료·실행하고 같은 temporary `BA_PLANNER_STORAGE_ROOT`에서 profile ID, display name, revision 3과 canonical goal을 typed state로 복원했으며 두 process exit code 0과 temporary root 삭제를 확인함. 금지된 v6/Qt runtime import 0건
- 슬레이브용 완료 선언: P4는 마스터 승인으로 최종 완료되었으며 follow-up-4는 재실행 대기
  작업이 아닌 이력 문서다. P5 슬레이브는 현재 작업 트리를 승인 baseline으로 사용하고,
  baseline이 다르면 P4를 수정하지 않고 `BLOCKED`로 보고한다.
- 차단 사항: 없음
- 다음 행동: P4 typed repository boundary를 유지한 채 P5 scanner/matcher session protocol을 시작
- 최종 갱신: 2026-07-22

## P5 — Scanner/Matcher session protocol과 backend

- 상태: `완료`
- 목적: v6 capture·scanner·matcher를 UI callback과 repository 저장에서 분리해 학생·인벤토리
  session, 구조화 event, 검토 가능한 candidate와 명시적 commit을 제공
- 완료 조건: 공용 Python/Dart event fixture, headless student/inventory session test, 취소·stale·낮은
  confidence 보존, 실제 adapter, recognition asset 분리와 전체 검증 통과
- 입력: `docs/migration/p5-scanner-matcher/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p5-scanner-matcher/slave-execution-prompt.md`
- 보완 입력: `docs/migration/p5-scanner-matcher-followup-1/input.md`
- 보완 슬레이브 실행 프롬프트: `docs/migration/p5-scanner-matcher-followup-1/slave-execution-prompt.md`
- 보완 수신 패키지: `docs/migration/handoffs/incoming/ba-planner-v7-p5-scanner-matcher-followup-1/ba-planner-v7-p5-scanner-matcher-followup-1-20260723-003156.zip`, 659,635 bytes, SHA-256 `dc3b04c7daae432c323e96adfdd8e5d526f3385a7da9697eb6fbef8feb59a920`
- 보완 출력 보고서: 같은 incoming 아래 `staging/20260723-003914-39a9bda9/output.md` (`COMPLETED`)
- 보완 결과물: 같은 staging의 `artifacts/p5-scanner-matcher-followup-1.patch` 924,250 bytes, SHA-256 `29faa865c125c52ca3485b98b26bb2cda3f0a10d06e50fc994e4edf7b312e005`; `artifacts/verification.txt` 4,322 bytes, SHA-256 `1438517ea731904d63fc5663aefb7ef719c55233ed1a5df923fa9fa3349e2012`
- 수신 패키지: `docs/migration/handoffs/incoming/ba-planner-v7-p5-repository-persistence/ba-planner-v7-p5-repository-persistence-20260722-222844.zip`, 17,273 bytes, SHA-256 `5ee0b0492c264d6c4ff2f542cdd8fbbe0bd4de57ce019e2b078cbedd4201d22d`
- 출력 보고서: 같은 incoming 아래 `staging/20260722-223045-00ae52e9/output.md` (`BLOCKED`)
- 결과물: 같은 staging의 `artifacts/p5-scanner-matcher.patch` 59,809 bytes, SHA-256 `8ef763d5ad294e803bfb6a2cea7a6e8b56bf2d69efd8b85a084e66a37ae291c0`; `artifacts/verification.txt` 4,188 bytes, SHA-256 `8345024909aaafc3c1ce51f3eb243e7512951beda38c8298033dab8628155f80`
- 인계 식별 오류: 외부 task ID는 `ba-planner-v7-p5-repository-persistence`, 동봉 master prompt는 P2와 `p2-planning-screen.patch`로 잘못 표기됐지만 내부 `output.md`와 artifact는 `ba-planner-v7-p5-scanner-matcher` 부분 증분이다.
- 마스터 검증: ZIP 크기·SHA-256이 사용자 값·manifest·sidecar와 일치하고 artifact 2개의
  크기·SHA-256도 `output.md`와 일치함. HEAD가 슬레이브 baseline `e0740be`와 같고 기존
  worktree 변경과 10개 patch path의 중첩이 없었으며 `git apply --check --verbose` 후 patch를
  clean 적용함. P5 집중 Python 8, 전체 Python 48, Flutter 전체 43, `flutter analyze`, Windows
  release build, `codealmanac validate`, `codealmanac health`, `git diff --check` 통과. 계획 화면
  Widget test 8개에서 current/goal 분리·빈 goal/숫자 0·총 필요량·MockAppService 흐름이
  통과했고 실제 Python stdio 8 tests와 실제 `ProcessAppService` repository restart E2E도 통과함.
- 결정 및 제약: P4 baseline을 선행 gate로 사용하고 candidate 생성과 repository 확정을 분리한다.
  event는 session ID·generation·sequence·정확히 하나의 terminal을 가지며, 낮은 confidence는
  review 없이 commit할 수 없다. 실제 student/inventory adapter 중 하나라도 placeholder이면
  완료가 아니다. UI asset과 recognition asset은 별도 manifest/path를 사용한다.
- 슬레이브 환경: Flutter/Dart SDK와 CodeAlmanac CLI 없음. Python test와 scanner backend,
  fixture·schema·asset·patch 검증은 슬레이브가 수행하고 Dart/Flutter test·analyze·release,
  실제 Dart↔Python event E2E와 Almanac 검증은 마스터 인계 후 필수 gate로 수행한다.
- 인계 차단 이력: 원본 패키지는 실제 Windows student/inventory adapter, recognition asset
  manifest, JSONL event transport와 Dart typed client 미구현으로 `BLOCKED`였고 P5 완료 조건을
  충족하지 못했다. 부분 증분 자체는 마스터가 검증·인수했다.
- follow-up-1 마스터 인수: ZIP 659,635 bytes와 SHA-256이 사용자 값·manifest·sidecar에
  일치하고, unique staging의 artifact 2개도 `output.md`의 크기·SHA-256과 일치함. baseline
  `9f533d8523dee54ca16f27c26d0b3af95668a66a`과 기존 변경 무중첩을 확인하고 40-path patch를
  `git apply --check --verbose` 후 clean 적용함.
- 마스터 직접 보완: 슬레이브가 작성한 Dart scanner source의 누락 import와 analyzer lint를
  수정하고, 실제 OS Python child process 2개를 순차 실행하는 `ProcessAppService` scanner event
  E2E 및 결정적 `MockAppService` scanner flow test를 추가함. E2E는 start response 뒤의
  phase·progress·candidate·terminal 단조 sequence, restart 후 새 session, 두 process exit code 0,
  dispose와 temporary storage 삭제를 확인함.
- 최종 검증: scanner 집중 Python 19, 전체 Python 59, Flutter 전체 47, `flutter analyze`,
  `flutter build windows --release`, `codealmanac validate`, `codealmanac health`,
  `git diff --check` 통과. 격리 wheel은 recognition manifest 1개와 production asset 16개를
  포함하고 설치된 runtime path에서 `ready=true`, missing/corrupt 0으로 해석됨. production
  student/inventory adapter, manifest 크기·SHA-256, bounded JSONL progress coalescing과
  candidate/terminal 보존을 독립 확인함.
- 결정 및 제약: production catalog는 학생 2명(`airi`, `aru`)과 inventory icon 2개의 제한된
  coverage이며 전체 catalog parity가 아니다. 실제 Blue Archive 게임 창 smoke scan은
  `NOT_VERIFIED`로 남지만 명시된 P5 완료 차단 조건은 아니다.
- 차단 사항: 없음. P5는 마스터 승인으로 완료되었고 슬레이브 follow-up 작업은 남아 있지 않다.
- 다음 행동: `docs/migration/p6-1-student-integration/slave-execution-prompt.md`를 슬레이브에 전달하고 결과 artifact를 인수·검증
- 최종 갱신: 2026-07-23

## P6-1 — 학생 실제 데이터 통합

- 상태: `완료`
- 목적: 학생 탭 placeholder를 실제 catalog·선택 프로필 repository state·scanner candidate와
  연결하고 검색·필터·정렬, 현재값 수정, 계획 탭 인계를 완성
- 완료 조건: catalog protocol, typed repository 학생 저장, service-backed StudentPage,
  계획 인계와 candidate review 경계, Python·Flutter·release·Almanac 검증 통과
- 입력: `docs/migration/p6-1-student-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-1-student-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-1-student-integration/staging/manual-20260723-015330-774c2d1a/output.md` (`COMPLETED`, 마스터 검증·인수 완료)
- 결과물: 같은 staging의 `artifacts/p6-1-student-integration.patch` 68,299 bytes,
  SHA-256 `da25a312a5f50501024f0c67d15c889ee66e591d7a925a3f996d1af875a329bc`와
  `artifacts/verification.txt` 1,934 bytes,
  SHA-256 `a780f23311210a358b0bd4e19e30d1896e6570f093d855a03c3bbe7e670a0e77`
- 수신 package: `ba-planner-v7-p6-1-student-integration-20260723-014628.zip` 18,347 bytes,
  SHA-256 `8229c01db4e992f0885e95e58acf856df6c9f857d8dc9718e883e02e33a83ccc`;
  사용자 제공값·manifest·sidecar와 일치하고 고유 staging에 독립 추출
- 검증: baseline HEAD `8f4ffd4` 일치, 기존 변경과 patch 20경로 비중첩,
  `git apply --check --verbose`와 clean 적용 통과. Python 61 tests, Windows release build,
  실제 Dart↔Python catalog·학생 저장·restart 복원 임시 acceptance E2E, 계획 draft 인계,
  candidate approve/hold, MockAppService 흐름, 1280×720·1440×900·1280×960 viewport,
  `flutter analyze`, Flutter 전체 58 tests, `codealmanac validate`, `codealmanac health`,
  `git diff --check`가 최종 통과했다. 임시 acceptance test는 실행 후 제거했다.
- 마스터 보완: deprecated dropdown 초기화를 `initialValue`로 교체하고 expanded/ellipsis로
  selection overflow를 제거했다. diagonal glass 내부에 투명 Material 경계를 추가하고,
  catalog test를 method별 request correlation으로 수정했다. candidate·off-screen action test는
  실제 scroll 동작을 사용하며 shell reachability test는 실제 StudentPage key를 확인한다.
- 결정 및 제약: P6 전체가 아닌 첫 수직 슬라이스다. scanner session 시작·진행·취소 UI는
  P6-3이 소유하며, 승인되지 않은 계획 preset protocol과 최종 반응형 layout state를
  추측하지 않는다. 현재값·정적 metadata·goal·계산·inventory shortage 경계를 유지한다.
- 차단 사항: 없음
- 다음 행동: `docs/migration/p6-2-inventory-integration/slave-execution-prompt.md`를 슬레이브에 전달
- 최종 갱신: 2026-07-23

## P6-2 — 인벤토리 실제 데이터 통합

- 상태: `완료`
- 목적: 인벤토리 탭 placeholder를 실제 catalog·선택 프로필 snapshot·저장된 plan shortage와
  scanner candidate에 연결하고 탐색·수정·부족 분석·검토 확정을 완성
- 완료 조건: inventory order parity와 catalog protocol, typed repository inventory 저장,
  gross totals와 분리된 shortage derivation, service-backed InventoryPage, candidate review 경계,
  Python·Flutter·release·실제 process E2E·Almanac 검증 통과
- 입력: `docs/migration/p6-2-inventory-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-2-inventory-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-2-inventory-integration/staging/manual-20260723-031217-6a77d237/output.md`
  (`COMPLETED`, 마스터 독립 검증 완료)
- 결과물: 수신 패키지 `ba-planner-v7-p6-2-inventory-integration-20260723-031020.zip`
  27,601 bytes, SHA-256 `480af0570516341daeebb05f210a78f8aec401da9888f9228acfc5b0d8ee328a`.
  같은 staging의 `artifacts/p6-2-inventory-integration.patch` 105,961 bytes,
  SHA-256 `86774247fc59593e5fc8d248bb7f98d64857043d73ec4f9fe5aa59c5e1275885`와
  `artifacts/verification.txt` 3,498 bytes,
  SHA-256 `bc9d476a1a8b4ae7143392e889fd23fc3669d350b181aa69e91d4e5560d87d9d`
- 검증: ZIP 사용자 제공값·manifest·sidecar와 artifact `output.md` 크기·SHA-256 일치,
  baseline HEAD `8d53673e8a0b9832725fb3cda9c9d3d415060856` 일치, 기존 사용자 변경 없음,
  29-path `git apply --check --verbose`와 적용 통과. Python 72, Flutter 65,
  `flutter analyze`, Windows release build, 실제 Dart↔Python catalog·shortage·inventory
  save/restart restore, Mock hold·approve·stale conflict, P6-1/planning 회귀,
  1280×720·1440×900·1280×960 layout, `codealmanac validate`, `codealmanac health`,
  금지 GUI/v6 runtime 참조 0건, `git diff --check` 통과
- 결정 및 제약: 기본 진입은 보유량 목록이며 부족 분석은 선택 프로필의 저장된 plan만
  대상으로 한다. snapshot 부재는 0이 아니라 unknown이고 명시적 zero-fill만 0이다.
  scanner session 시작·진행·취소 UI는 P6-3이 소유하며 전체 육성 부족·장기 pressure·추천은
  이 단계에서 구현하지 않는다.
- 마스터 보완: analyzer 중괄호 lint를 수정하고 InventoryPage widget test에 실제 Scaffold와
  lazy-list reveal을 적용했다. catalog 오류가 프로필 자동 선택에 지워지는 상태 경합을 분리했으며,
  실제 Dart↔Python catalog·명시적 0/unknown shortage·affected student 검증을 restart E2E에 추가했다.
- 전달 메모: 수신물의 `P2`/`p2-planning-screen.patch` 표기는 오래된 master prompt 문구였으나
  Task ID·manifest·output·실제 patch 29경로는 모두 P6-2로 일치했다.
  `WIRELESS_HANDOFF_RECEIVED`는 수신 디렉터리와 ZIP에 없으며 무선 전달이라는 별도 주장은 없었다.
- 차단 사항: 없음
- 다음 행동: P6-3 절의 승인된 범위와 실행 프롬프트를 사용해 슬레이브 작업 전달
- 최종 갱신: 2026-07-23

## P6-3 — 스캔 실제 UI 통합

- 상태: `완료`
- 목적: 스캔 탭 placeholder를 P5 typed scanner service에 연결하고 readiness·profile·target·kind,
  session start·phase·progress·cancel·retry·terminal과 candidate handoff 흐름을 완성
- 완료 조건: 단일 active session, cancel/terminal 분리, event gap snapshot 복구, bounded in-memory
  recent result, student/inventory candidate의 data-owner 탭 전달과 성공 commit 뒤 context 정리,
  Python·Flutter·release·실제 process E2E·Mock·viewport·Almanac 검증 통과
- 입력: `docs/migration/p6-3-scan-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-3-scan-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-3-scan-integration/staging/manual-20260723-121648-35b503de/output.md`
  (`COMPLETED`, 마스터 검증·인수 완료)
- 결과물: 수신 패키지 `ba-planner-v7-p6-3-scan-integration-20260723-121532.zip`
  (23,705 bytes, SHA-256 `2ba963e2f2b7a5ed1f816d3f3b53f8060b2064301ecb21e9f278dc2dee4d7e3b`),
  같은 staging의 `artifacts/p6-3-scan-integration.patch` (80,805 bytes,
  SHA-256 `e4bbd86b49ca9babbe8c41a29e7c5e040d68726cb1042760b28f4596b6eb4bcc`)와
  `artifacts/verification.txt` (4,470 bytes,
  SHA-256 `6f39b5373d140d90f78b1041d84b5893c312d14a60847a61d1d808e0e39fa744`)
- 검증: ZIP·manifest·sidecar·`output.md`의 크기와 SHA-256을 독립 대조했고 고유 staging에만
  해제했다. baseline `00b995d`의 깨끗한 작업 트리에서 기존 사용자 변경과 대상 경로 중첩이 없음을
  확인하고 `git apply --check` 뒤 patch를 적용했다. Python 3.11 전체 72 tests, Flutter 전체 78 tests,
  scanner 집중 16 tests, `flutter analyze`, Windows release build, 실제 Dart↔Python scanner process E2E,
  typed snapshot·event gap·cancel/retry·terminal, MockAppService, student/inventory candidate handoff와
  성공 commit 뒤 context 정리 및 hold 경계, 1280×720·1440×900·1280×960 Widget layout,
  `codealmanac validate`, `codealmanac health`, 금지 GUI/v6 runtime 참조 0건과 `git diff --check`를
  마스터에서 통과했다.
- 마스터 보정: nullable terminal payload lint, StudentPage test callback 위치, Mock cancel terminal의
  결정적 지연, offscreen/indeterminate progress Widget test와 retry timer 정리를 보정하고 실제 process
  E2E에 typed snapshot 복구 assertion을 추가했다.
- 결정 및 제약: ScanPage는 session 실행과 candidate 요약·handoff만 소유하며 repository review/commit은
  StudentPage/InventoryPage가 계속 소유한다. cancel acknowledgement만으로 terminal 처리하지 않고,
  최근 결과는 backend에 없는 영구 history를 만들지 않은 현재 앱 실행 중 bounded memory로 제한한다.
- baseline gate: P6-2 승인본은 현재 마스터 작업 트리의 미커밋 증분이므로 슬레이브가 정확한 accepted
  snapshot을 받지 못했다면 P6-1/P6-2를 재구성하지 않고 `BLOCKED`로 동일 snapshot을 요청한다.
- 인계 메모: 마스터 요청문의 P2·`p2-planning-screen.patch` 표기는 오래된 문구로 판단하고 실제
  Task ID·manifest·`output.md`·patch의 일치된 P6-3 범위를 기준으로 검증했다.
  `WIRELESS_HANDOFF_RECEIVED`는 수신 디렉터리·ZIP·현재 터미널 출력에 없었고 무선 전달이라는 별도
  주장은 없었다. 무선 전달이었다면 해당 수신 표식은 별도 운송 증빙으로 재확인이 필요하다.
- 차단 사항: 없음
- 다음 행동: 승인된 P6-3 snapshot과 P6-4 홈 통합 프롬프트를 슬레이브에 전달
- 최종 갱신: 2026-07-23

## P6-4 — 홈 실제 데이터 통합

- 상태: `완료`
- 목적: 기존 80° 홈 이미지 메뉴를 보존하면서 선택 프로필·backend, 실제 repository count,
  저장된 계획·부족 재화, 최신 scan과 검토 대기 상태를 읽는 시작 대시보드로 통합
- 완료 조건: 실제 typed source의 loading·empty·disconnected·partial error와 refresh/resume,
  profile/repository/plan/shortage/scan read model, data-owner quick action, 기존 홈 geometry와
  3개 viewport, Python·Flutter·release·실제 process E2E·Mock·Almanac 검증 통과
- 입력: `docs/migration/p6-4-home-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-4-home-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-4-home-integration/staging/20260723-151610-cb9794de/output.md`
  (`COMPLETED`, 마스터 검증·인수 완료)
- 결과물: 수신 패키지 `ba-planner-v7-p6-4-home-integration-20260723-151510.zip`
  (16,930 bytes, SHA-256 `c71c89e5b576551c6769b8216af085411d060461f605b2a46796a45401fa4283`),
  같은 staging의 `artifacts/p6-4-home-integration.patch` (48,288 bytes,
  SHA-256 `f243b7206ac45ca73db5859305a4b3116f72165c4e18078ddf7d6e7e90e352dc`)와
  `artifacts/verification.txt` (7,145 bytes,
  SHA-256 `2ae67543e492fb0e67dbc831f74674105553a5f4e5bdcbd28c7685aec691e365`)
- 검증: ZIP·manifest·sidecar·`output.md`의 크기와 SHA-256을 독립 대조하고 고유 staging에
  해제했다. HEAD `7fe68856`의 깨끗한 accepted P6-3 작업 트리와 patch 8경로의 비중첩을 확인하고
  `git apply --check --verbose` 뒤 깨끗하게 적용했다. Python 3.11 전체 72 tests, Flutter 전체
  91 tests와 홈·AppShell·scan·실제 process 집중 23 tests, `flutter analyze`, Windows release build,
  실제 Dart ProcessAppService↔Python profile/repository 저장·restart 복원·shortage E2E,
  Mock pending candidate Hold·commit 후 Home context 정리, typed recent scan handoff, refresh/race와
  partial failure, 기존 742×1018·80° home geometry/navigation, 1280×720·1440×900·1280×960 layout,
  `codealmanac validate`, `codealmanac health`, 금지 GUI/v6 runtime 참조 0건과 `git diff --check`를
  마스터에서 통과했다.
- 마스터 보정: 테스트의 Flutter foundation import와 fixture parameter를 정리하고, repository current
  envelope를 shortage API에 잘못 전달하던 결함을 Inventory/Home 공용 planning-current 변환으로 수정했다.
  실제 E2E에 confirmed student 저장을 추가했으며 홈 pending action key를 실제 button에 배치하고 lazy
  scroll test를 안정화하고 변경된 P6-4 Dart source를 formatter로 정규화했다.
- 결정 및 제약: 홈은 read model이며 repository save, plan mutation, candidate review/commit을 하지 않는다.
  inventory unknown을 0으로 만들지 않고 임시 planning draft를 저장된 plan으로 표현하지 않는다.
  최근 scan은 P6-3의 앱 실행 중 typed summary만 공유하며 backend에 없는 timestamp나 영구 history를
  만들지 않는다. P6-5~P6-7과 새 backend protocol은 범위 밖이다.
- 전달 메모: 마스터 요청문의 `P2`/`p2-planning-screen.patch` 표기는 오래된 문구였으나 실제
  Task ID·manifest·`output.md`·patch 8경로는 모두 P6-4로 일치했다. `WIRELESS_HANDOFF_RECEIVED`는
  수신 디렉터리와 현재 작업 터미널에서 확인되지 않았고 무선 전달이라는 별도 주장은 없었다.
- 차단 사항: 없음
- 다음 행동: 승인된 P6-4 snapshot과 P6-5 통계 통합 프롬프트를 슬레이브에 전달
- 최종 갱신: 2026-07-23

## P6-5 — 통계 실제 데이터 통합

- 상태: `완료`
- 목적: 통계 탭을 선택 프로필 전체의 실제 student/inventory catalog, repository current·goals,
  gross calculation과 shortage 결과에 연결하고 근거 detail에서 data-owner 탭으로 이동
- 완료 조건: 학생·인벤토리·계획 3 mode, 고정 KPI/분포와 pure typed projection,
  missing·unknown·zero·분모·gross/shortage 의미 보존, loading·empty·disconnected·partial error와
  refresh/re-entry, Python·Flutter·release·실제 process E2E·Mock·3 viewport·Almanac 검증 통과
- 입력: `docs/migration/p6-5-statistics-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-5-statistics-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-5-statistics-integration/staging/20260723-164735-0b236e6c/output.md`
  (`COMPLETED`, 마스터 독립 검증 완료)
- 결과물: 수신 패키지 `ba-planner-v7-p6-5-statistics-integration-20260723-164645.zip`
  (16,888 bytes, SHA-256 `8c377b4d6e2f9ac935e0e7f4649ecf85a1fb1fc07ddd7d158790aa8022a772d5`),
  같은 staging의 patch와 verification artifact
- 결정 및 제약: v6 통계는 StudentPage filtered set을 사용했지만 v7에는 filter 공유 계약이 없으므로
  P6-5 범위는 선택 프로필 전체로 고정한다. StudentPage filter handoff, 새 chart dependency,
  statistics protocol/storage/history를 만들지 않는다. 통계는 read-only이며 학생 current·metadata·goal,
  gross result와 inventory shortage bucket을 섞거나 mutation하지 않는다.
- 마스터 검증: package/manifest/output artifact의 크기와 SHA-256을 독립 확인하고 고유 staging에서만
  추출했다. accepted P6-4 baseline과 clean worktree를 확인한 뒤 7-path patch에 `git apply --check`를
  선행하고 적용했다. Python 72개, Flutter 전체 106개와 P6-5 집중 16개, `flutter analyze`, Windows
  release build, 실제 Dart↔Python catalog/repository/gross/shortage process E2E, MockAppService,
  1280×720·1440×900·1280×960 Widget layout, `codealmanac validate`·`health`, `git diff --check`를 통과했다.
- 마스터 보정: Widget test의 `ValueListenable` import, private test helper, lazy-scroll navigation과
  stable identity assertion을 정리했다. 인벤토리 snapshot 부재를 null 수량과 분리해 `absent`로
  집계하고 category known coverage의 분모를 catalog로 고정했으며, 범위 밖 학생 level/star가
  known-only 평균과 고정 bucket에 섞이지 않도록 pure projection과 회귀 test를 보강했다.
- 전달 메모: 마스터 요청문의 `P2`/`p2-planning-screen.patch` 표기는 오래된 문구였으나 실제
  Task ID·manifest·`output.md`·patch 7경로는 모두 P6-5로 일치했다. `WIRELESS_HANDOFF_RECEIVED`는
  수신 디렉터리와 현재 작업 터미널에서 확인되지 않았고 무선 전달이라는 별도 주장은 없었다.
- 선행 조건: P6-4 완료
- 차단 사항: 없음
- 다음 행동: 승인된 P6-6 snapshot을 기준으로 P6-7 설정 및 통합 오류 처리 프롬프트 작성
- 최종 갱신: 2026-07-23

## P6-6 — 전술대항전 실제 데이터 통합

- 상태: `완료`
- 목적: 실제 학생 ID 기반 4 Striker+2 Special 공격·방어 편성, 프로필별 전적·메모·수동
  족보 저장·복원과 검색·필터·재사용 통합
- 완료 조건: strict tactical contract/fixture, profile-scoped atomic persistence와 revision/idempotency,
  실제 Dart↔Python restart E2E, Mock, P6-1~P6-5 회귀, 3 viewport, release와 Almanac 검증 통과
- 입력: `docs/migration/p6-6-tactical-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-6-tactical-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-6-tactical-integration/staging/20260723-184006-136eea9c/output.md`
  (`COMPLETED`, 마스터 독립 검증 완료)
- 결과물: 수신 패키지 `ba-planner-v7-p6-6-tactical-integration-20260723-183844.zip`
  (22,658 bytes, SHA-256 `4e3226cb73cf05b8eb17196b6306541567385388ea88f3cf9e541ab54a174492`),
  같은 staging의 patch와 verification artifact
- 결정 및 제약: P6-6은 수동 match/jokbo 기본 기능만 소유한다. 로비 scan, 상대 identity/history,
  provenance, 전술 통계, 변경 감지, 예상 방어덱·추천·공유는 P7~P13에 남긴다. canonical student ID와
  fixed 4+2 slot 순서를 저장하며 v6 Qt/QML/PySide/SQLite facade를 복사하거나 runtime import하지 않는다.
- 마스터 검증: package/manifest/output artifact의 크기와 SHA-256을 독립 확인하고 고유 staging에서만
  추출했다. accepted P6-5 `e58281e`와 clean worktree를 확인하고 17-path patch에 `git apply --check`를
  선행한 뒤 적용했다. Python 79개, Flutter 전체 121개와 P6-6 집중 15개, `flutter analyze`, Windows
  release build, 실제 Dart↔Python tactical save→restart→restore, Mock CRUD/revision, strict schema/fixture,
  atomic failure·profile isolation·candidate Hold/Approve 회귀, 세 viewport의 empty/populated layout,
  `codealmanac validate`·`health`, `git diff --check`를 통과했다.
- 마스터 보정: 슬레이브 미실행 Dart source의 괄호/import 오류와 analyzer lint를 수정했다. Mock catalog의
  combat class 대소문자 때문에 own-deck 후보가 사라지던 문제를 정규화하고, 족보 복사가 가짜 상대·승리
  기록을 즉시 저장하지 않고 새 편집 draft를 열도록 수정했다. 날짜 범위 filter, profile/revision과 실제 덱
  evidence 표시, canonical record/profile/error strict Dart 검증, Mock CRUD/revision 및 copy-before-save와
  긴 데이터 세 viewport 회귀 test를 보강했다.
- 전달 메모: 마스터 요청문의 `P2`/`p2-planning-screen.patch` 표기는 오래된 문구였으나 실제 Task ID,
  manifest, `output.md`와 patch 17경로는 모두 P6-6으로 일치했다. 송신 보고서에는 wireless wrapper와
  `CROSS_PC_HANDOFF_READY`가 있으나 master 측 `WIRELESS_HANDOFF_RECEIVED` 터미널 출력은 보존되지 않았다.
  수신 ZIP은 master에서 사용자 값·manifest와 독립적으로 동일 byte/hash임을 확인했다.
- 선행 조건: P6-5 완료
- 차단 사항: 없음
- 다음 행동: accepted P6-6 snapshot과 P6-7 설정 및 통합 오류 처리 프롬프트를 슬레이브에 전달
- 최종 갱신: 2026-07-23

## P6-7 — 설정 및 통합 오류 처리

- 상태: `완료`
- 목적: 설정 탭을 실제 profile·backend·scanner·진단 source에 연결하고 전 탭 공통 오류·복구 흐름을
  통합한 뒤 P6 전체 독립 검증을 준비
- 완료 조건: profile 생성·선택·이름 변경, reconnect/restart, secret-safe diagnostics, Scan·Adaptive-Sync
  진입, 전 탭 reload/stale 보호와 스캔 → 현재 상태 검토 → 목표 설정 → 총 필요량 → 부족량 → 저장·복원
  통합 흐름이 실제 process·Mock·3 viewport·release·Almanac gate를 모두 통과
- 입력: `docs/migration/p6-7-settings-error-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-7-settings-error-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-7-settings-error-integration/staging/master-verify-20260723-200655-009bf168/output.md`
- 결과물: 같은 staging의 `artifacts/p6-7-settings-error-integration.patch`, `artifacts/verification.txt`
- 수신 패키지: `ba-planner-v7-p6-7-settings-error-integration-20260723-200126.zip`, 17,803 bytes,
  SHA-256 `1754b4a55ca8e9d7b7bce9995ba73d4016c9234d11595692fd74517ed81bc095`
- 인계 검증: manifest·sidecar·사용자 제공 byte/hash가 일치하고 새 고유 staging에 독립 추출했다.
  `output.md`의 patch 63,263 bytes/SHA-256 `ed090da2a33d59459f729d84db0e0f9afbf9871ccb1fa39bd09be424d5983370`,
  verification 4,106 bytes/SHA-256 `27e50cc43180ac581651b1b21439b37d37647ac52e586da4a5f9a8d86fbdb7ee`가
  실제 artifact와 일치했다. 보존된 `WIRELESS_HANDOFF_RECEIVED` 터미널 출력은 없지만 수신 ZIP을
  마스터가 다시 검증했으며 무선 전송 자체를 구현 검증으로 간주하지 않았다.
- patch 인수: baseline `4225ab3`, clean worktree와 11개 frontend path의 무중첩을 확인하고 저장소
  루트에서 `git apply --check --verbose`를 통과한 뒤 적용했다. 요청문의 `P2`와
  `p2-planning-screen.patch`는 오래된 템플릿 문구이며 Task ID·manifest·output·실제 patch는 P6-7로 일치했다.
- 마스터 보완: callback 반환 누락과 화면 밖 deep-link test를 수정하고, 설정 primary-tab 회귀를 갱신했다.
  launcher executable/args/working-directory까지 token/password/secret/authorization/Bearer를 제거하도록
  진단 경계를 강화했다. 실제 scanner fixture를 사용한 최종 process E2E와 동일 Mock 흐름을 추가해 Hold
  불변, Approve commit, current/inventory/goal/gross/shortage/tactical, profile 격리와 restart 복원을 검증했다.
- 독립 검증: Python 79개, Flutter 136개, P6-7 변경 13경로 Dart format, `flutter analyze`,
  `flutter build windows --release`, 1280×720·1440×900·1280×960 populated/disconnected/long-text layout,
  `codealmanac validate`, `codealmanac health`, 금지 GUI/v6 runtime import 0건과 `git diff --check` 통과.
- 결정 및 제한: profile 삭제·backup/import, 새 settings 저장소, 설정에서 scan 시작·target persistence,
  P7+ 기능은 제외한다. reconnect/restart는 draft/candidate를 자동 commit·삭제하지 않는다. 실제 Blue
  Archive 게임 창 smoke는 수행하지 않았고 fixture/Mock 결과를 실제 게임 검증으로 표현하지 않는다.
- 선행 조건: accepted P6-1~P6-6이 포함된 baseline `4225ab3` 확인
- 차단 사항: 없음
- 다음 행동: P0~P6 workflow 완료 상태를 유지하고 명시적 승인 전 P7을 시작하지 않음
- 최종 갱신: 2026-07-23

최종 갱신: 2026-07-23

## 단계별 기록 양식

단계 정의 또는 상태가 확인되면 아래 항목을 해당 단계 섹션으로 추가한다.

```markdown
## P<n> — <단계명>

- 상태: `<상태 값>`
- 목적: `<이 단계가 달성할 결과>`
- 완료 조건: `<마스터가 검증할 조건>`
- 입력: `<input.md 절대경로 또는 저장소 상대경로>`
- 출력 보고서: `<output.md 경로>`
- 결과물: `<artifacts/ 경로와 주요 파일>`
- 검증: `<마스터가 실행하거나 확인한 내용>`
- 결정 및 제약: `<유지해야 할 판단>`
- 차단 사항: `<없음 또는 구체적인 원인>`
- 다음 행동: `<다음 대화에서 바로 수행할 일>`
- 최종 갱신: `<YYYY-MM-DD>`
```

## 대화 간 인계 절차

1. 새 대화에서 이 문서와 현재 대상 단계의 `input.md`를 읽는다.
2. `다음 행동`과 실제 작업 트리·산출물의 상태가 일치하는지 확인한다.
3. 슬레이브 명령에는 [Slave Artifact Handoff](slave-artifact-handoff)의 인계 계약을
   포함한다.
4. 결과를 받은 마스터는 `output.md`와 결과물을 직접 확인한다.
5. 검증 결과, 새 결정과 다음 행동을 이 문서에 기록한 뒤 대화를 마친다.

## P6 이후 학생 탭 Section 토대

- 상태: `현행 계약 구현 및 검증 완료`
- 목적: 학생 탭의 Studio Section 1~4, 행동 버튼, 사선 학생 grid, 선택 학생 indicator 토대를 실제 Flutter 화면에 적용
- 산출물: `frontend/lib/ui/studio/student_studio_layout.dart`,
  `frontend/lib/ui/widgets/student_section_layout.dart`, `frontend/lib/ui/pages/student_page.dart`,
  `frontend/test/student_studio_layout_test.dart`
- 결정 및 제약: Section 1 버튼 세 개는 Section inset·gap에서 같은 크기를 유도하고 기존 색의 삼각형
  texture를 적용한다. Section 1·2의 80° 빗면 간격은 12 px로 고정한다. Section 1~4에는 shadow만 있고
  Section outline은 없다. Section 2는 Container 12 하나 안의 8열 direct-painted portrait grid이며
  265명 bundled catalog를 전부 표시한다. Section 3의 Container 1·3은 surface 없는 placeholder이고
  portrait·성작·Container 5·6·7·9는 공통 좌측 80° rail, Container 5·6·7·9는 공통 우측 rail에 맞춘다.
  Section 4 검색 높이는 Studio 제안의 절반으로 줄였다. 상단 repository profile selector는 제거하고
  선택 profile을 service에서 자동 복원한다. Section 4의 표시·미보유·JP 전용 checkbox와 Section 5의
  catalog filter는 구현됐으며, Section 3 세부 text와 Container 4~7·9·10의 실제 indicator 내용만
  후속 범위다. 기존 repository 편집 Section은 제거하고 scanner candidate 검토 flow만 canvas 아래에
  조건부로 유지한다.
- 검증: `flutter analyze --no-pub` 통과, 학생 layout 7개·학생 페이지 9개 집중 test 통과,
  전체 Flutter 189개 test 통과, Windows release build 통과, 265명 catalog generator 재실행 및
  Python compile 통과, `codealmanac validate`, `codealmanac health`, `git diff --check` 통과
- 2026-07-27 후속 보정: 학생 grid의 외곽 8 px inset은 유지하고 양축 cell gap을 4.8 px로 줄여
  셀 이미지를 100%/98%로 확대했다. 80° custom scrollbar와 14 px 전용 폭을 grid 산식에 포함했고,
  성작 bar·scroll track의 80°를 수치 검증한다. Container 5·6·7·9의 세로 gap과 Container 4까지의
  법선 gap을 같은 값으로 맞추고, Section 1 버튼 폭은 오른쪽 80° 경계 inset에서 행별 역산한다.
  검색 입력을 수직 중앙에 놓고 Section 4 윗변 inset을 0.18→0.09로 줄였으며 세 행동 버튼에만
  연핑크 삼각 texture를 적용했다. 학생 layout 10개·학생 페이지 9개 집중 test와 analyze가 통과했다.
- 2026-07-27 추가 보정: Section 4의 오른쪽 끝은 유지하고 왼쪽 길이를 조정해 Section 3 왼쪽과 같은
  80° 직선에 맞췄다. Section 1 버튼의 빗면 법선 여백은 왼쪽 직선면 여백 이상이며 아이콘은 명시적
  중앙 정렬을 사용한다. 네 Section의 기본 alpha는 0.76으로 검증하고 canvas 아래 legacy repository
  editor Section을 제거했다. 학생 grid 행 gap은 4.8의 80%인 3.84 px, scrollbar handle은 pink로
  변경했다. full mock catalog의 아루·아야네 영문 override를 제거해 한국어 이름 정렬에 포함했다.
- 2026-07-27 motion/effect 보정: Section 1 아이콘은 사다리꼴 중간 Y의 실제 수평 선분 중앙에서
  계산한다. Container 12·2·4는 5·6·7·9와 같은 status texture, Container 10은 Section 1과 같은 action
  texture를 사용한다. Filter 버튼은 Section 2를 퇴장시킨 뒤 Section 5를 등장시키며
  역전환도 지원한다. motion은 Section 1=0/180, Section 2·5=80/260, Section 3·4=180/0으로 고정했다.
  분리된 foundation layer는 IgnorePointer로 grid hit test를 보존한다.
- 2026-07-27 학생 card/filter 보정: Container 4의 action texture를 원래 status texture로 되돌리고
  Container 10에 action texture를 적용했다. 학생 grid는 `square.png` alpha 내부의 하단 16%만
  overlay로 사용하며, 상단 3%에 v6 공격/방어 색상 띠를 좌우로 나누고 남은 13% 회색 반투명 영역에
  흰색 학생 이름을 표시한다. Section 4의 두 checkbox로 속성 띠와 이름을 각각 토글한다. Section 5는
  높이와 왼쪽 80° rail을 유지하며 후속 보정에서 양쪽 수평변을 Section 2의 50%로 줄였다.
- 2026-07-27 학생 card/filter 후속 보정: card 정보 영역을 하단 16%로 확대하고 상단 3% 속성 띠와
  나머지 13% 이름 영역으로 나눴다. Filter→목록 복귀 시 행동 버튼 아이콘은 학생 탭의
  `groups_2_outlined`로 전환한다. Section 5는 윗변·밑변을 모두 Section 2의 50%로 줄여 평행사변형을
  유지하고 내부 Container도 축소 path에 맞췄다. Section 4에는 미보유 학생·일본 서버 전용 숨김
  checkbox를 추가했으며, `jp_only`를 backend metadata, catalog protocol/schema/fixture, Flutter DTO와
  265명 mock asset에 이관했다.
- 2026-07-27 학생 Section 회고 문서화: 최초 토대·초기 해석과 반복 피드백 뒤 확정된 geometry,
  texture, placeholder, grid, card overlay, filter, data, motion 계약의 차이를
  `almanac/design/section-template-studio.md`에 비교표로 남겼다. 유사 Section을 새로 만들거나 기존
  Section과 유사하다고 판단할 때 범위·형상·효과·반응형·데이터·상호작용을 확인할 22개 질문과
  질문 순서·재질문 방지 원칙도 함께 기록했다.
- 2026-07-27 Section 사전 협의 절차 보강: 독립 요구가 많은 Section 작업은 geometry, container,
  effect, data/filter, motion 단위의 분리안을 먼저 제안하고 그 순서로 진행해도 되는지 사용자 승인을
  받도록 했다. 유사 Section 후보가 있으면 추상적으로 유사 여부만 묻지 않고 기존 Section에서 그대로
  참고할 속성, 다르게 만들 속성, 미정인 속성을 명시하는 질문 형식과 기존 widget 호출·형상 복제의
  구분 질문을 `almanac/design/section-template-studio.md`에 추가했다.
- 2026-07-27 학생 이름/정렬 보정: 학생 카드 이름 글꼴을 4~8px에서 6~12px로 1.5배 확대하고
  이름 영역 높이의 80%를 목표값으로 유지했다. Section 1에는 검색 입력과 같은 실제 높이, action과
  같은 inset·gap·80° 형상 계산을 쓰는 정렬 드롭다운을 추가했다. 닫힌 control은 투명 바탕에
  1px 연핑크 사다리꼴 테두리·연핑크 축약 text·연핑크 하향 삼각형만 표시한다. 이름·LV·성작·인연
  랭크의 오름/내림차순을 지원하며, 결측값은 방향과 관계없이 뒤로 보내고 이름순 tie-break를
  적용한다. 인연 랭크는 protocol 미구현 동안 이름순 fallback이다. 학생 집중 26개와 Flutter 전체
  198개 test, `flutter analyze`, Windows release build를 통과했다.
- 2026-07-28 학생 정렬 control 위치 보정: Section 1의 정렬 드롭다운을 최상단으로 이동하고,
  계획·스캔·필터 action을 그 아래 기존 순서로 배치했다. 검색 입력과 같은 높이, 공통 세로 gap,
  Section 상대 inset과 오른쪽 80° 경계 역산 규칙은 유지한다.
- 2026-07-28 학생 control text 보정: 정렬 드롭다운의 닫힌 label을 10→15px, 펼친 menu label을
  12→18px로 확대했다. Section 4의 네 checkbox label도 11→16.5px로 1.5배 확대하되 기존 control
  높이·간격과 한 줄 ellipsis는 유지한다.
- 2026-07-28 학생 motion 실행 계약 보정: Section 1은 0° intro/180° outro, Section 3·4는
  180° intro/0° outro의 독립 `SectionMotionSpec`을 사용한다. 공용 motion widget이 intro 값만으로
  reverse 궤적을 추론하지 않고 forward에는 intro, reverse에는 outro 벡터를 직접 적용하도록 했다.
  학생 집중 28개와 Flutter 전체 200개 test, `flutter analyze`, Windows release build를 통과했다.
- 2026-07-28 학생 탭 호출 lifecycle 보정: AppShell의 공용 90°/270° 페이지 translation이 학생
  Section별 motion과 합성되던 것이 일괄 호출처럼 보이던 원인이었다. 학생 페이지 index는 공용
  translation에서 제외하고, 이전 탭 퇴장 완료 callback에서 `StudentPage.active`를 켜 Section 1~4를
  각자의 intro로 호출한다. 학생 탭을 떠날 때는 `active`를 먼저 끄고 각 controller를 reverse하여
  독립 outro를 실행한다. 페이지 instance와 학생 선택·filter 상태의 기존 보존 방식은 유지한다.
  관련 집중 44개와 Flutter 전체 200개 test, `flutter analyze`, Windows release build를 통과했다.
- 2026-07-28 almanac 정합성 정리: 날짜별 이력보다 design 문서의 현행 계약과 runtime·회귀 test를
  우선하도록 판정 순서를 명시했다. 초기 요약에 남아 있던 Section 4·5 filter 미구현 표기와
  repository 편집 Section 유지 표기를 현재 구현에 맞게 정정하고, 페이지 전체 motion과 내부
  Section motion을 분리하는 탭 호출 lifecycle을 회고 비교표에도 추가했다.
- 다음 행동: Section 3의 텍스트·세부 상태 indicator와 Container 4~7·9·10의 실제 데이터를
  사용자 승인 디자인으로 채운다. 계획 버튼의 최종 계획 탭 연결 범위는 별도로 확정한다.
- 최종 갱신: 2026-07-28

## P6 이후 학생 Section 5 필터와 Section 2 viewport 후속 보정

- 상태: `완료`
- 목적: 학생 Section 5에 실제 v6 계열 filter group/list/check box를 배치하고 Section 2·5의
  scroll content가 container 크기를 바꾸지 않도록 고정 viewport와 상하 fog를 적용한다.
- 산출물: `frontend/lib/ui/widgets/student_section_layout.dart`,
  `frontend/test/student_studio_layout_test.dart`, `almanac/design/section-template-studio.md`
- 결정 및 제약: 현재 v7 catalog protocol에 존재하는 학교·초기 성급·공격/방어 타입·편성·역할·
  포지션만 v6 명칭과 값 mapping으로 노출한다. 선택은 같은 group OR/서로 다른 group AND이며
  Section 2 복귀 후에도 유지하고 별도 초기화 action으로만 제거한다. 성장·스킬 metadata는
  protocol 확장 전까지 표시하지 않는다.
- 검증: Flutter 전체 199개, 학생 layout 집중 test 27개, 학생 page test 9개,
  `flutter analyze --no-pub`, Windows release build 통과.
  1280x720·1440x900·1280x960 overflow 검증과 filter 유지·초기화·경계·fog test를 포함한다.
- 차단 사항: 없음
- 다음 행동: 전체 Flutter test와 Almanac/diff gate를 유지한다.
- 최종 갱신: 2026-07-28
- 2026-07-27 실화면 재검수: container를 부모 path와 강제 교차해 외부를 숨기던 계산을 제거하고,
  부모 Section의 위·아래 실제 80도 경계에서 10px 안쪽 polygon을 직접 계산했다. filter group은
  중심 Y와 자체 사선 깊이의 이중 이동을 밑변 Y 기반 단일 이동으로 바꾸고, 전체 사선 깊이를
  포함한 좌우 content-safe inset을 적용했다. Windows 1280x720과 최대화 화면에서 최초·중간 scroll
  위치를 직접 검수했으며 잘린 `학교` 제목, clipped corner와 행 궤적을 확인·보정했다.
## 2026-07-27 학생 Section viewport 실화면 재검수

- 첨부 화면에서 `StudentPage`가 상하 16px padding을 적용하면서도 내부
  `StudentSectionLayout` 높이에 차감 전 `constraints.maxHeight`를 사용해 Section 2·5 하단과
  필터 초기화 버튼이 viewport 아래로 총 32px 밀리는 원인을 확인했다.
- canvas 높이를 `max(590, maxHeight - padding.vertical)`로 고치고
  1280x720·1440x900·1280x960 page test에서 실제 `StudentSectionLayout` 높이를 검증한다.
- 추가 크기 역추적에서 필터 전용 paint 분기 이후의 공통 runtime container loop가 기존
  `container-12`를 원래 Section 2 크기로 다시 칠하는 것을 확인했다. 필터 모드에서는
  `element-2`의 legacy container/feature를 제외하고, 새 Section 5 container와 reset surface만
  그리도록 수정했다. 최대화 Windows release에서 중복 면·윤곽 제거를 직접 확인했다.
- Section 2·5의 고정 상·하 fog를 공통 `_StudentDiagonalScrollbar`의 `ScrollPosition` 기반
  overlay로 교체했다. scroll range가 없으면 양쪽을 숨기고, 최상단은 위쪽, 최하단은 아래쪽을
  숨기며 중간에서만 양쪽을 표시한다. 최대화 Windows release의 Section 2 최상단에서 위 fog
  제거를 확인하고, 무스크롤·최상단·중간·최하단 네 상태를 집중 test로 고정했다.
- 2026-07-28 Section 5의 높이가 서로 다른 filter group row에 같은 폭을 적용해 우측 사선
  끝점이 어긋나던 문제를 수정했다. row 높이에 따른 자체 사선 깊이를 폭 산식에 포함하여
  위·아래 우측 끝점이 하나의 80도 rail에 놓이게 했고, scroll offset이 있는 경우까지 수치
  test로 고정했다. Flutter 전체 199개와 학생 layout 27개·page 9개 집중 test,
  `flutter analyze --no-pub`, Windows release build를 통과했다.

## P6 이후 계획 탭 본문 초기화

- 상태: `완료`
- 목적: 계획 탭의 새 구성을 시작할 수 있도록 기존 헤더 아래의 학생 조회·빈 상태·학생 카드·
  계산·결과 섹션을 모두 제거한다.
- 산출물: `frontend/lib/ui/pages/planning_page.dart`,
  `frontend/test/planning_page_test.dart`
- 결정 및 제약: 여기서 헤더는 `AppShell`이 제공하는 상위 탭 헤더를 뜻한다. 계획 페이지
  내부에 있던 공용 프로필 패널과 `성장 계획` 카드도 하위 섹션으로 보아 함께 제거하고,
  본문은 빈 canvas만 유지한다. 학생 탭이 사용하는 `PlanningStudentSeed` 전달 계약은
  유지하되, 새 계획 본문이 정해지기 전까지 계획 탭에서 seed를 표시하거나 처리하지 않는다.
  기존 planning backend와 repository 계약은 변경하지 않는다.
- 검증: `flutter analyze --no-pub`, 계획 탭 집중 Widget test와 Flutter 전체 192개,
  `git diff --check` 통과.
- 차단 사항: 없음
- 다음 행동: 사용자 기획에 맞춰 계획 헤더 아래의 새 섹션을 순서대로 구성한다.
- 최종 갱신: 2026-07-28

## P6 이후 계획 탭 Section 1~4 초기 배치

- 상태: `초기 구현 완료`
- 목적: `release/section-plan-main.ba-section-studio.json`을 시작점으로 계획 탭에 내용이
  비어 있는 Section 4개를 배치하고, 사용자 실화면 검수 전에 motion과 shadow 계약을 고정한다.
- 산출물: `frontend/lib/ui/studio/plan_studio_layout.dart`,
  `frontend/lib/ui/widgets/plan_section_layout.dart`,
  `frontend/lib/ui/pages/planning_page.dart`, `frontend/lib/ui/app_shell.dart`,
  `frontend/test/planning_page_test.dart`, `almanac/design/section-template-studio.md`
- 결정 및 제약: JSON의 96×96 좌표와 shape를 그대로 초기 투영한다. Section 1은
  `0°/180°`, Section 2·3은 `80°/260°`, Section 4는 `180°/0°`의 intro/outro를 사용한다.
  네 Section 모두 최종 path에 공용 lifted shadow를 한 번씩 적용하고, 아직 내부 콘텐츠는
  추가하지 않는다. 계획 탭은 페이지 전체 motion 대신 Section별 motion을 사용한다.
- 검증: `flutter analyze --no-pub`, 계획 탭 집중 test 3개, Flutter 전체 194개,
  Windows release build 통과.
- 차단 사항: 없음
- 다음 행동: 사용자가 갱신된 Windows release에서 초기 배치를 확인한 뒤 Section별 크기를
  세부 조절한다.
- 최종 갱신: 2026-07-28
- 2026-07-28 밝기 보정: 실화면 비교에서 계획 페이지 전용 `AppColors.canvas` 72% fill이
  AppShell 공용 BA 배경과 Section surface 사이에 추가 합성되어 탭 전체를 어둡게 만드는 것을
  확인했다. 전용 fill을 제거하고 투명 host로 교체했으며 Section 색·alpha·그림자·motion은
  유지했다. 집중 test 3개와 Flutter 전체 194개, `flutter analyze --no-pub`를 통과했고
  실행 중 release를 종료한 뒤 Windows release bundle을 갱신했다.
- 2026-07-28 Section 2 페이즈 표시 토대: 계획은 공통 페이즈, 시나리오는 계산에서 분리된
  개별 페이즈를 가진다는 경계를 기록했다. Section 2 안에 80° 내부 texture Container,
  80° 궤적을 따르는 페이즈 카드와 scrollbar를 추가하고, 페이즈 내부 순서를 가진 학생 단계
  더미를 배치했다. 시로코 1·2·3단계가 페이즈 1·2·3에 순서대로 나타나며 기존 v6 이관 portrait
  asset을 사용한다. 편집 기능과 Section 1 메뉴·Section 3 재화 탭은 후속 Studio 배치 이후로
  남긴다. 계획 탭 집중 test 5개, Flutter 전체 196개, `flutter analyze --no-pub`, Windows
  release build를 통과했고 1280×720 실화면에서 초기·scroll 위치의 clipping과 80° rail을
  검수했다.
## 2026-07-28 계획 단계 공용 DiagonalMediaListItem

- 상태: `구현 및 전체 검증 완료`
- 목적: Studio JSON으로 만든 단계 아이템을 계획·스캔 결과에서 재사용 가능한
  중립 컴포넌트로 만들고 계획 탭의 기존 간이 타일을 즉시 교체한다.
- 산출물: `release/component-diagonal-media-list-item1.ba-section-studio.json`,
  `frontend/lib/ui/widgets/diagonal_media_list_item.dart`,
  `frontend/lib/ui/widgets/plan_section_layout.dart`,
  `frontend/assets/equipment_icons/`,
  `frontend/test/diagonal_media_list_item_test.dart`
- 결정 및 제약: 도형 4와 17은 배치 앵커로만 유지하며 각각 5+4 성작 표시와
  1~100 하트 랭크로 렌더링한다. 값 변화는 `5(▲2)`/`5(▼2)` 형식과
  초록/빨강을 사용한다. v6 장비 이미지는 scanner template을 runtime에서
  참조하지 않고 필요한 세 파일만 v7 UI asset으로 분리 복제했다.
- 검증: 세 중심선 그룹의 정규화 좌표, delta 색상, 하트·성작 semantics,
  계획 단계 전체 교체와 기존 사선 스크롤 집중 Widget test 통과.
  `flutter analyze --no-pub`, 전체 Flutter 198개 test, Windows release build,
  release bundle 동기화, `codealmanac validate`, `codealmanac health`,
  `git diff --check`를 통과했다.
- 다음 행동: 다시 실행한 최신 release 화면을 기준으로 섹션별 크기를 세부 조절한다.
- 최종 갱신: 2026-07-28

### 2026-07-28 아이템 높이·인연 배경·페이즈 흐름 후속 조정

- 상태: `구현 및 전체 검증 완료`
- 변경: 계획 아이템을 54px로 높이고 58px 행 단위로 배치했다. 각 행은 페이즈
  평행사변형의 현재 Y 좌우 경계를 직접 계산해 부모 사선과 평행하게 맞춘다.
  성작 바 높이 비율 0.22는 유지하고 장비 아이콘과 하트 높이·폭을 확대했다.
- 이미지: 학생 portrait 앞에는 98% 크기를 적용하고 뒤에는 인연 랭크별
  `square.png`를 둔다. 1~19 기본, 20~49 파랑, 50~99 노랑, 100 보라 규칙을
  학생 목록·포커스, 계획 아이템, 통계 학생 근거 행에서 공유한다.
- 데이터: confirmed student repository DTO와 schema에 1~100 `bond_rank`를
  추가하되 planning 계산 입력에는 전달하지 않아 기존 계산 계약을 유지한다.
- 흐름: 페이즈 사이 20px 간격에 아래 방향 삼각형을 배치한다.
- 검증: 관련 Flutter 46개 집중 test와 전체 Flutter 200개 test,
  `flutter analyze --no-pub`, 전체 Python 80개 test, Windows release build 및
  release bundle 동기화를 통과했다. 최신 Windows release에서 학생 이미지 무잘림,
  행/부모 사선 정렬, 페이즈 화살표, 하트 비율을 직접 확인했다.
- 다음 행동: 사용자 화면 검수 결과에 따라 세부 크기만 추가 조절한다.

### 2026-07-28 계획 아이템 밀도 및 인연 하트 후속 조정

- 상태: `구현 및 실화면 검증 완료`
- 변경: 계획 페이즈 아이템 높이를 54px에서 65px로 약 20% 확대하고, 행 간격을
  유지하도록 item extent를 69px로 조정했다. Studio 원본 섹션 높이도 20에서
  24로 맞췄다.
- 장비: 세 장비 아이콘 모두 `square.png`를 배경으로 사용하고 실제 장비 이미지는
  배경의 98% 크기로 겹쳐 그린다.
- 인연 하트: 참고 이미지의 넓은 연분홍 하트, 진분홍 외곽선, 짙은 숫자 스타일을
  반영했다. 하트 자체는 1.28:1 비율로 고정해 부모 폭에 따라 납작해지지 않으며,
  delta가 없어도 동일한 배치 공간을 유지한다.
- 검증: 관련 Widget test 11개, `flutter analyze --no-pub`, Windows release
  build를 통과했다. 최신 Windows 빌드의 계획 탭에서 사선 행 정렬, 장비 배경,
  하트 숫자와 페이즈 사이 흐름 표시를 확인했다.
- 다음 행동: 사용자의 실화면 판단에 따라 개별 텍스트와 아이콘 간격을 세부
  조정한다.

### 2026-07-28 계획 아이템 정보 열 재배치

- 상태: `구현 및 실화면 검증 완료`
- 인연: 하트를 아이템 우측 끝으로 이동하고 인연 상승치를 하트 바로 아래에
  독립된 줄로 배치했다.
- 하단 정보: 애장품 영역 폭을 확대해 `T2(▲1)`처럼 상승치가 포함되어도 본문이
  과도하게 축소되지 않게 했다. 각 장비 `square.png`와 티어 텍스트 사이에는
  0.008 이상의 정규화 간격을 둔다.
- 강조: 스킬은 학생 레벨과 첫 장비 사이에 유지하면서 기본 9.5px의 1.5배인
  14.25px로 키웠다.
- 성작: indicator 높이를 0.22에서 0.154로 30% 줄이고 기존 중심선을 유지했다.
- 검증: 관련 Widget test 11개와 `flutter analyze --no-pub`, Windows release
  build 및 실화면 검수를 통과했다. 정식 release bundle을 동기화했다.

### 2026-07-28 다중 값 변동 행 및 장비 레벨 추가

- 상태: `구현 및 실화면 검증 완료`
- 인연: 하트를 우측 끝에서 정보 영역 중앙 쪽으로 되돌리고 상승치는 하단 행에
  유지했다. 하트 내부 숫자는 10.5px에서 15.75px로 1.5배 확대해 100도 배지
  경계를 약간 사용할 수 있게 했다.
- 장비 데이터: 각 장비가 티어와 장비 레벨을 별도로 갖도록
  `DiagonalMediaEquipment`를 확장했다. 더미 데이터도 `T5 Lv.25` 형태와 각각의
  변동값을 제공한다.
- 다중 변동: 스킬·장비·추가 능력치는 본문을 위쪽에, 대응 변동값을 아래쪽에
  배치한다. 값이 변하지 않는 칸은 `-`, 변동 칸은 `▲n` 또는 `▼n`으로 표시하고
  `/`로 구분한다.
- 검증: 관련 Widget test 11개, `flutter analyze --no-pub`, Windows release
  build와 확대 실화면 검수를 통과했다. 정식 release bundle을 동기화했다.

### 2026-07-28 인연 열 고정 및 무변동 행 생략

- 상태: `구현 및 실화면 검증 완료`
- 인연: 하트가 기존 정보 열 위치로 되돌아가지 않도록 우측 전용 열
  (`center x = 0.95`) 안에 중앙 정렬했다. 상승치는 하트 아래에 유지한다.
- 변동 행: 스킬·장비·추가 능력치의 구성값이 모두 무변동이면 하단 행 자체를
  렌더링하지 않고 본문을 세로 중앙에 둔다. 하나라도 변동하면 기존처럼 무변동
  구성값은 `-`로 남겨 대응 관계를 보존한다.
- 스킬: EX 최대 5, 나머지 스킬 최대 10을 기준으로 최대값을 `M`으로 표시한다.
  실화면에서 3단계 시로코가 `M/6/6/6`으로 표시됨을 확인했다.
- 검증: 관련 Widget test 12개, `flutter analyze --no-pub`, Windows release
  build와 확대 실화면 검수를 통과했다. 정식 release bundle을 동기화했다.

### 2026-07-28 인연 하트 수직 정렬 및 페이즈 개수 제거

- 상태: `구현 및 코드 검증 완료, 사용자 육안 검수 대기`
- 정렬: 인연 하트의 실제 렌더링 영역 중심 Y를 장비 `square.png` 중심 Y와
  동일한 `0.67614347305232`로 맞췄다. 하단 인연 변화량 공간은 유지한다.
- 페이즈: 각 페이즈 컨테이너 우측 상단에 표시하던 내부 아이템 개수 텍스트를
  제거했다.
- 검증: 관련 Widget test 12개와 `flutter analyze --no-pub`를 통과했다.
  요청에 따라 자동 육안 검수는 수행하지 않고 release bundle만 동기화했다.

### 2026-07-28 최대화 화면 기준 인연 하트 중심 재정렬

- 상태: `구현·코드 검증·최대화 실화면 검증 완료`
- 원인: 이전 검증은 작은 장비 아이콘 뒤의 `square.png`를 비교 대상으로 삼아,
  사용자가 지칭한 학생 portrait 뒤의 큰 `square.png`보다 하트가 아래에 남았다.
- 변경: 하트의 실제 렌더링 영역 중심 Y를 학생 portrait 영역 중심 Y와 정확히
  일치시켰다. Studio 원본의 `feature-17` 위치와 Widget test도 같은 학생 portrait
  기준으로 변경했다.
- 검증: 관련 Widget test와 `flutter analyze --no-pub`, Windows release build 및
  release bundle 동기화를 통과했다. 최신 release를 현재 모니터의 2560×1392
  최대화 창으로 실행하여 학생 `square.png`와 하트 중심선이 일치하는 것을 확인했다.

### 2026-07-29 인연 변화량 중앙 정렬 및 작업 이력 문서화

- 상태: `구현·코드 검증·최대화 실화면 검증 완료`
- 변경: 인연 변화량을 하트 아래에 유지하면서 실제 텍스트 중심 X가 하트 중심 X와
  일치하도록 `_DeltaLabel`에 호출부별 alignment와 실제 콘텐츠 검증 key를 추가했다.
  공용 기본 정렬은 기존 `centerLeft`로 유지해 다른 값 열에는 영향을 주지 않는다.
- 문서: 계획·스캔 공용 `DiagonalMediaListItem`의 표시 계약, 단계별 조정 이력,
  학생/장비 `square.png` 혼동, 작은 창 검증, slot과 실제 render bounds 차이,
  중첩 `Align` 때문에 바깥 `Center`가 무효였던 원인과 향후 검증 규칙을
  `almanac/design/diagonal-media-list-item.md`에 기록했다.
- 검증: 집중 Widget test 5개, `flutter analyze --no-pub`,
  `codealmanac validate`, `codealmanac health`, Windows release build와 bundle
  동기화를 통과했다. 최신 release를 현재 모니터의 2560×1392 최대화 창에서
  확대 확인해 각 행의 인연 변화량이 하트 바로 아래에서 같은 중심 X를 사용하는
  것을 확인했다.

### 2026-07-29 계획 스크롤·인연 경계 더미 확장

- 상태: `구현·코드 검증·release 동기화 완료, 사용자 실행 검수 대기`
- 데이터: 4개 페이즈의 더미 학생 단계를 11개에서 16개로 늘려 기준 화면에서도
  충분한 세로 scroll extent가 생기게 했다. 인연 50은 유우카·히나, 인연 100은
  아즈사·아코 행에 배치했으며 100은 최대치이므로 추가 상승치를 생략한다.
- 테스트: 총 행 수와 50·100 존재 여부, 실제 `BondRankPortrait` 투영값과
  파랑·보라 배경 경계를 검증한다. 스크롤은 `maxScrollExtent`가 viewport보다
  큰지 확인하고 drag 뒤 offset, 중간 페이즈와 마지막 아코 행의 Y 이동을 함께
  검증하도록 강화했다.
- 검증: 계획·공용 아이템 집중 test 12개, `flutter analyze --no-pub`와 Windows
  release build 및 bundle 동기화를 통과했다. 실행·육안 검증은 사용자 요청에
  따라 수행하지 않았다.
- 다음 행동: 사용자가 최신 release를 실행해 추가 행, 인연 50·100 배경과
  scrollbar 이동을 확인한다.

### 2026-07-29 인연 50 배경 경계 수정

- 상태: `구현·코드 검증·release 동기화 완료, 사용자 실행 검수 대기`
- 원인: 노랑 배경 조건이 `bondRank > 50`이어서 정확히 50인 더미 행이 파랑
  `square_blue.png`로 분류됐다.
- 변경: 노랑 시작 조건을 `bondRank >= 50`으로 고쳐 1~20 기본, 21~49 파랑,
  50~99 노랑, 100 보라 경계를 적용했다.
- 검증: 49·50·99·100 경계값과 계획 탭의 인연 50·100 투영을 포함한 집중 test
  12개, `flutter analyze --no-pub`, Windows release build와 bundle 동기화를
  통과했다. 실행 검증은 사용자에게 맡긴다.

### 2026-07-29 계획 페이즈 스크롤 상·하단 안개 적용

- 상태: `구현·코드 검증·release 동기화 완료, 사용자 실행 검수 대기`
- 공용화: 학생 탭 Section 2의 안개 색상, 36px gradient와 scroll endpoint 판정을
  `ScrollViewportFog`와 `scrollViewportFogVisibility`로 분리했다. 학생 탭의 기존
  `StudentViewportFog` API와 key는 wrapper로 유지했다.
- 계획: 페이즈 목록 시작에서는 아래쪽, 중간에서는 위·아래, 끝에서는 위쪽 안개만
  표시한다. 최초 build에 `ScrollController`가 아직 연결되지 않은 경우에도 알려진
  content extent와 viewport로 초기 아래 안개를 계산한다.
- 검증: 계획 탭 test 7개, 학생 탭 test 28개, `flutter analyze --no-pub`,
  Windows release build와 bundle 동기화를 통과했다. 실행 검증은 사용자에게
  맡긴다.

### 2026-07-29 인연 20 파랑 배경 경계 수정

- 상태: `구현·코드 검증·release 동기화 완료, 사용자 실행 검수 대기`
- 원인: 파랑 배경 조건이 `bondRank > 20`이어서 정확히 20인 학생이 기본
  `square.png`로 분류됐다.
- 변경: 파랑 시작 조건을 `bondRank >= 20`으로 고쳐 1~19 기본, 20~49 파랑,
  50~99 노랑, 100 보라 경계를 적용했다.
- 검증: 19·20·49·50·99·100 경계와 계획 탭 투영을 포함한 집중 test 12개,
  `flutter analyze --no-pub`, Windows release build와 bundle 동기화를 통과했다.
  실행 검증은 사용자에게 맡긴다.

### 2026-07-29 계획 Section 3 재화 헤더

- 상태: `헤더 구현·코드 검증·최대화 실화면 검증 완료`
- 범위: Section 3 본문과 실제 부족 데이터 연결은 만들지 않고 헤더 부분만 구현했다.
- 구조: Section 3 평행사변형을 공용 compound header의 바깥 glass에 대응시키고,
  상단 `페이즈별 / 전체 / 병목` 탭 선반, divider와 중첩 재화 헤더를 추가했다.
  탭 선택 배경·primary 하단선·icon·label과 title 전환은 AppShell 헤더 문법을 따른다.
- 사선 적합: 탭 선반과 중첩 헤더의 좌우 끝을 각 Y의 Section 3 80° 경계에서 계산한다.
  title·subtitle도 위쪽 왼쪽과 아래쪽 오른쪽 경계가 만드는 공통 안전 폭 안에 둔다.
- 검증: 계획 탭 집중 test 9개, Flutter 전체 205 tests, `flutter analyze`, Windows
  debug·release build, `codealmanac validate`·`health`와 `git diff --check`를 통과했다.
  최신 debug 앱을 2560×1440 최대화 화면에서 열어 Section 2·4 침범 없음, 세 탭의 안전 폭,
  활성 탭 표현, 양쪽 80° 중첩 표면과 삼각 texture를 확인했다.
- 다음 행동: 사용자 검수 뒤 Section 3의 선택 탭별 본문 토대와 실제 부족 데이터 계약을
  별도 단계로 구현한다.

### 2026-07-29 계획 재화 Section 3·5 분리

- 상태: `구현·집중 검증·최대화 실화면 검증 완료`
- 입력: 갱신된 `release/section-plan-main.ba-section-studio.json`의 Section 3
  bottom 깊이 80과 신규 Section 5 `(53,1,42,14)`, top 깊이 96을 runtime projection에 반영했다.
- 역할: 기존 Section 3의 재화 헤더를 Section 5로 옮기고 Section 3은 탭별 결과 본문 자리로
  남겼다. Section 5는 독립 foundation에서 alpha 0.76 glass fill과 lifted shadow를 가진다.
- motion: Section 5는 사용자 지정 `intro 260° / outro 80°`를 독립 controller로 실행한다.
  Section 3은 기존 `80° / 260°`를 유지한다.
- 반응형: Section 5 높이에 따라 탭 선반과 중첩 헤더를 축소한다. 두 줄 copy가 넘치는
  낮은 viewport에서는 title만 유지하며 1280×720 Widget test에서도 overflow가 없다.
- 정렬·간격: Section 5를 x=53으로 옮겨 Section 3과 같은 80° rail에 맞췄다. y=1로
  내려 공용 헤더와 거리를 늘리고 Section 3과의 간격은 약 2.33 grid로 줄여 Section 3
  하단의 2 grid 바닥 여백과 유사하게 했다.
- 검증: 계획 탭 집중 test 9개, 전체 Flutter test 205개, `flutter analyze`,
  Windows debug/release build, `codealmanac validate`, `codealmanac health`,
  `git diff --check`를 통과했다. 최신 Windows debug 앱을 최대화 화면과
  1265×711 작은 창에서 열어 Section 5와 Section 3의 분리, 이어지는 80° rail,
  Section 5 외곽 glass·shadow와 내부 texture 및 세로 overflow가 없음을 확인했다.
- 다음 행동: 탭별 스위칭 시 Section 3 본문 교체 motion과 각 재화 보기의 내부 토대를 정한다.

### 2026-07-29 Section 5 병목 탭 우선 구현

- 상태: `구현·집중 검증·최대화 실화면 검증 완료`
- 탭 순서: `병목 / 페이즈별 / 전체`로 변경하고 병목을 초기 선택으로 지정했다.
- 병목 요약: Section 5의 기존 제목·설명 copy를 제거하고, 좌측에
  v6의 네브라 디스크 T3 아이콘과 tier index 2의 `square_yellow.png` 배경을
  런타임 UI 자산으로 분리 복사해 배치했다. 아이콘은 content 높이의 85%를 차지한다.
- 3행 정보: `가장 심한 병목 요소`, `보유량 : 42 / 필요량 : 60`,
  `확보 시 학생 3명의 목표 단계가 가능해집니다` 순서로 표시한다.
- 연동: 병목 아이템을 누르면 Section 2에서 네브라 T3 소모 학생으로 지정한
  아즈사·노노미·하루카의 모든 단계 행에 1.2px 핑크 테두리가 표시된다.
  병목 외 탭으로 전환하면 강조를 해제한다.
- 데이터: 실제 inventory-derived shortage 연결 전까지 수량 42/60과 영향 학생 3명은
  typed sample constants로 유지한다. 나머지 두 탭은 기존 placeholder copy를 복원하지 않는다.
- 반응형: 낮은 Section 5에서는 아이콘, 글꼴, 간격과 line height를 함께 축소해
  3행 정보를 유지하면서 세로 overflow를 방지한다.
- 검증: 계획·공용 행 집중 test 15개, 전체 Flutter test 206개, `flutter analyze`,
  Windows debug/release build를 통과했다. 최신 Windows debug 앱의 1265×711 및
  2560×1440 화면에서 아이콘 크기, 3행 copy, 하루카·노노미 2단계·아즈사의
  얇은 핑크 테두리와 비대상 행 유지 상태를 확인했다.
- 다음 행동: 실제 inventory-derived shortage DTO를 연결하고 병목 우선순위 산식을 정한다.

### 2026-07-29 Section 5 병목 가시성 조정

- 상태: `구현·Windows 실화면 검증 완료`
- Section 2 연동 강조선은 `1.2px → 1.8px`로 1.5배 확대했다.
- Section 5의 3행 copy 간격은 일반 화면 `3/4px → 4.5/6px`, compact 화면
  `1/1px → 1.5/1.5px`로 각각 1.5배 확대했다.
- 검증: 사용자 요청에 따라 자동 테스트는 생략했다. 최신 Windows debug 앱의
  2560×1440 계획 화면에서 3행 copy 간격과 선택된 하루카·노노미·아즈사 행의
  1.8px 핑크 테두리 가시성을 확인했다.

### 2026-07-29 Section 5 페이즈별 요약

- 상태: `후속 전체 탭 연동으로 대체`
- 공용화: 병목과 페이즈별 탭이 동일한 `PlanResourceItemSummary` 표현 구조를 사용한다.
- 페이즈별 copy: `가장 부족한 재화`, `보유량 : 42 / 필요량 : 60`,
  `2단계에서 4명 중 1명만 완료 가능`을 3행으로 표시한다.
- 아이콘: v6 기준 안티키테라 T4 아이콘과 보라색 등급 배경을 사용한다.
- 검증: 사용자 요청에 따라 자동 테스트와 실화면 검증을 수행하지 않았다.

### 2026-07-29 Section 5 세 탭 재화 강조 및 전체 요약

- 상태: `구현 완료·사용자 검증 대기`
- 공통 연동: Section 5의 병목·페이즈별·전체 탭은 각각 영향 학생 ID 집합을 가지며,
  현재 요약을 누르면 Section 2의 해당 학생 모든 단계 행에 1.8px 핑크 테두리를
  토글한다. 탭을 바꾸면 이전 집합의 강조는 해제한다.
- 병목: 네브라 디스크 T3 선택 시 아즈사·노노미·하루카를 강조한다.
- 페이즈별: 대표 재화를 안티키테라 T4로 교체하고 v6의 tier-index-3 보라 배경 규칙을
  적용했다. 현재 더미 소비 학생인 유우카를 강조한다.
- 전체: 아이콘 없이 `전체 요구량의 72% 확보`,
  `14종 부족 · 6명의 성장 계획에 영향` 두 문장만 표시한다. 기존 3행 재화 요약의
  작은 글자 크기를 재사용하지 않고 헤더 높이에 맞춘 전용 2행 typography를 사용하며,
  요약 클릭 시 시로코·호시노·세리카·하루카·노노미·아즈사를 강조한다.
- 자산: `Item_Icon_Material_Antikythera_3.png`와 `square_purple.png`를
  v7 런타임 UI 자산 폴더에 독립 복사했다.
- 검증: 사용자 요청에 따라 자동 테스트와 실화면 검증을 수행하지 않았다.

### 2026-07-29 Section 3-1 첫 병목 상세

- 상태: `후속 병목 카드 확장으로 대체`
- 탭 본문: Section 5의 선택 상태를 상위 `PlanSectionLayout`으로 올려 Section 3을
  `3-1 병목 / 3-2 페이즈 / 3-3 전체` keyed body로 전환한다. 이번 범위에서는
  3-1만 채우고 3-2·3-3은 후속 상세 UI를 위한 빈 body로 유지한다.
- 내부 컨테이너: `release/section-plan-main-1.ba-section-studio.json`의 container-1
  top·height 비율을 투영하고 부모 Section 3에 clip한다. Section 2와 동일하게 세로
  scroll offset을 80° X 이동으로 바꾸는 사선 카드 목록을 사용한다.
- 첫 병목: `첫 번째 병목`, `페이즈 2 · 호시노 2단계`, 크레딧 잔액,
  `기초 전술교육 BD`, `단계 진입 잔량 4 / 단계 필요량 12`, `8개 부족`과
  지연 단계 호시노 2·노노미 2·아코 3을 표시한다.
- 재화 배치: 병목 재화 카드는 Section 5 아이콘+3행 구조를 축소 적용하고 한 행을
  2열로 계산한다. 크레딧은 feature-6 크기에 맞춘 아이콘과 숫자만 표시하며
  `square.png` 배경을 사용하지 않는다.
- 자산: v6의 `Currency_Icon_Gold.png`,
  `Item_Icon_Material_ExSkill_Abydos_0.png`, 기본 `square.png`를 각각 v7의
  currency·tactical_bd·item_backgrounds 런타임 자산 폴더로 독립 복사했다.
- 검증: `flutter analyze`와 계획 화면 집중 Widget test 10개를 통과했다.
  Section 2·3-1의 공용 사선 scrollbar는 key prefix를 분리해 scroll·fog 상태가
  충돌하지 않도록 했다. 최종 크기·간격은 사용자 실화면 확인 대상으로 남긴다.

### 2026-07-29 Section 3-1 병목 카드 확장

- 상태: `후속 레이아웃 압축으로 대체`
- 헤더: `첫 번째 병목`을 `병목 1`로 바꾸고 단계 표기를
  `페이즈 2. 호시노 2단계`로 조정했다. 문구 좌측에는 기본 `square.png`와
  호시노 portrait를 겹치며, 자연 높이는 병목 재화 카드와 같은 168px이다.
- 크레딧: 상시 잔액 행을 제거했다. 크레딧 자체가 병목인 두 번째 사례에서만
  배경 없이 `Currency_Icon_Gold.png`를 표시하고 다른 재화와 동일하게
  `단계 진입 잔량 n / 단계 필요량 m`, 부족량을 표시한다.
- 재화 확대: 아이콘과 3행 copy의 자연 크기를 기존 대비 1.5배로 확대했다.
  좁은 viewport에서는 overflow 방지를 위해 이 자연 크기를 비례 축소한다.
- 장비: 장비 병목 이름에는 `헤어핀 (T10)`처럼 명시적인 tier suffix를 붙인다.
- 지연 단계: 기존 제목을 선택 버튼으로 바꿨다. 버튼을 누르면 학생 전체가 아니라
  해당 병목이 가진 phase·student·step 키와 정확히 일치하는 Section 2 행만
  기존 1.8px 핑크 테두리로 토글한다.
- 스크롤 사례: BD·크레딧·T10 장비·오파츠 병목 4건을 배치해 3-1의 세로 스크롤과
  80° X 이동을 확인할 수 있게 했다.
- 검증: `flutter analyze`와 계획 화면 집중 Widget test 11개를 통과했다.
  신규 test는 첫 병목 버튼의 호시노 2·노노미 2·아코 3 정확 일치 강조,
  비대상 단계 유지, 두 번째 카드의 Y 감소·X 증가 사선 이동을 확인한다.

### 2026-07-29 Section 3-1 레이아웃 압축 및 포커스 우선순위

- 상태: `후속 단계 아이템 재사용으로 대체`
- 최상위 컨테이너: Section 3 대비 가로·세로를 95%로 축소하고 가로 중앙 정렬했다.
  상단 margin은 기존 16.6% 수준에서 2.5%로 줄였으며 부모 polygon clip을 유지한다.
- 카드 헤더: `병목 n`을 좌측 상단에 독립 배치하고, 그 아래
  `97.5×123px`의 기본 square+portrait와 페이즈·단계 문구를 나란히 배치했다.
- 재화 카드: 높이를 168px에서 144px로 줄이고 세로 padding을 15px에서 8px로
  조정해 아이콘과 위·아래 사선 사이 여백을 줄였다.
- 지연 단계: 버튼의 기존 가로·세로 비율을 유지한 채 80° 평행사변형 path,
  clip, hit target으로 바꿨다. Section 2에서 결과를 보여주므로 버튼 아래 중복 단계 행은
  제거했다.
- 포커스: 지연 단계 버튼 뒤 재화 요약을 누르면 exact-stage set을 먼저 비우고
  재화의 affected-student set만 적용한다. 두 강조 집합은 동시에 남지 않는다.
- 검증: `flutter analyze`, 계획 화면 집중 Widget test 12개와 공용
  diagonal media Widget test 5개를 통과했다.
  컨테이너 95% geometry·2.5% top margin, 하위 단계 행 제거, exact-stage 강조,
  재화 선택 시 exact-stage 해제, 사선 스크롤을 확인했다.

### 2026-07-29 Section 3-1 단계 아이템 재사용 및 크레딧 분리

- 상태: `구현·집중 검증 완료·사용자 실화면 확인 대기`
- 단계 표시: 병목 번호와 재화 그리드 사이의 별도 portrait·문구 조합을 제거하고
  Section 2의 65px `PlanStudentStepTile`을 동일하게 재사용한다.
- 병목 원인: 공용 `DiagonalMediaListItemData`에 title·skills·equipment value의
  선택적 색상 override를 추가했다. 첫 BD 병목은 스킬 값, 장비 병목은 첫 장비 값,
  크레딧 병목은 단계 제목만 핑크색이며 공용 geometry는 바꾸지 않는다.
- 재화 여백: 병목 재화 카드 높이를 144px에서 134px, 세로 padding을 8px에서
  4px로 바꿔 아이콘 위·아래 시각 여백을 각각 절반 수준으로 줄였다.
- 복수 재화: 크레딧 사례에 안티키테라 T4와 네브라 T3를 함께 배치해 2열 한 행
  복수 재화 카드 구조를 확인할 수 있게 했다.
- 크레딧: ordinary resource grid에서 제외한다. 크레딧 부족이 있는 카드만 단계
  아이템과 재화 그리드 사이의 긴 행에 60% 크기 아이콘, `m / n`, 부족량 순으로
  표시하며 배경 square는 사용하지 않는다.
- 검증: `flutter analyze`, 계획 화면 집중 Widget test 12개와 공용
  diagonal media Widget test 5개를 통과했다.
  공용 단계 아이템 재사용·핑크 원인 텍스트·크레딧 grid 제외·60% 아이콘 크기·
  복수 재화 2개·134px 카드 높이를 확인했다.

### 2026-07-29 Section 3-1 재화 카드 세로 여백 후속 축소

- 상태: `구현·집중 검증 완료·사용자 실화면 확인 대기`
- 모니터 기준: 현재 primary display는 `2560×1440`, system DPI는 `96(100%)`로
  screenshot physical pixel과 Flutter logical pixel이 1:1이다.
- 측정: 첨부 480×145 crop에서 카드 fill은 Y=5~136의 132px, 밝은 아이콘·텍스트
  묶음은 Y=32~109의 78px이므로 기존 위·아래 여백은 각각 27px이다.
- 재화 카드 높이를 `134px → 107px`, 내부 세로 padding을 `4px → 2px`로
  줄여 목표 여백을 각각 약 13.5px로 잡았다.
- 카드 축소량 27px만큼 지연 단계 버튼과 다음 병목 카드 시작 위치도 함께 당겨
  사선 스크롤 간격을 유지한다.

### 2026-07-29 v6 이미지·인식 템플릿 이관 및 backend 연결

- 상태: `첫 수직 슬라이스 구현·자동 검증 완료`
- 사용자 승인을 받아 표시용 이미지는 기존 Flutter 역할별 경로를 유지하고, 인식
  자산은 Python 소스와 분리한 `backend/assets/recognition/v1/`로 이동했다.
- Flutter 표시용 v6 원본 1,045개와 backend recognition entry 780개의 크기·SHA-256을
  manifest로 검증했다. 학생 인식 254종과 inventory fast icon 497종이 실제
  `RecognitionAssetCatalog`와 scanner matcher에 연결된다.
- backend packaged root가 기본이며 `BA_PLANNER_RECOGNITION_ASSET_DIR`로 완전한 v1
  catalog를 교체할 수 있다. adaptive sample은 사용자 데이터로 계속 분리한다.
- `inventory_detail`, name template, raw count 학습 sample은 matcher parity가 아직 없어
  이번 slice에서 제외했으며 후속 수직 이관 대상으로 유지한다.
- 검증: Python 119 tests, Flutter 217 tests, `flutter analyze`, Windows release build와
  `tools/verify_v6_asset_migration.ps1` 통과.
- 상세 범위와 manifest는 `docs/migration/v6-asset-backend-connection/`에 기록했다.

### 2026-07-29 Section 3-1 크레딧 독립 가로 행

- 상태: `구현·집중 검증 완료·사용자 실화면 확인 대기`
- 크레딧 부족 표시는 일반 재화의 1행 2열 그리드에서 완전히 분리해 단계 아이템 바로 아래에 둔다.
- 크레딧 행은 `이 병목으로 지연되는 단계` 액션과 같은 안전 폭과 `38px` 높이를 쓰는 긴 평행사변형이다.
- 내부에는 배경 `square.png` 없이 `30×30px` 크레딧 아이콘, `m / n`, 부족량을 가로로 배치한다.
- 크레딧 행 축소분만큼 일반 재화 그리드와 카드 하단 액션을 위로 이동하고, 크레딧 사례 카드 높이를 `353px`로 줄였다.

### 2026-07-29 Section 3-1 병목 의미 확인 및 장비 배경 규칙 복원

- 상태: `장비 배경 수정·집중 검증 완료`
- 현재 병목 목록은 저장 계획과 인벤토리에서 계산한 결과가 아니라 typed UI preview 상수다. 따라서 아직 `최초 부족 지점 → 이후 누적 추가 부족` 산식을 구현한 상태가 아니다.
- v6의 일반 장비 `Equipment_Icon_*_TierN`은 숫자 tier와 관계없이 기본 `square.png`를 사용한다. BD·노트·오파츠 등의 0~3 품질 suffix 배경 규칙과 분리한다.
- `equipmentTier`가 있는 병목 재화는 잘못된 명시 배경이 들어와도 기본 장비 배경으로 정규화하며, T1~T10과 실제 T10 샘플 렌더링을 테스트한다.

### 2026-07-29 Section 3-2 페이즈 소모량 및 Section 3-3 전체 소모량

- 상태: `구현·집중 검증 완료·사용자 실화면 확인 대기`
- 3-2는 3-1의 외부 컨테이너, 카드 surface, 80° 사선 스크롤, 독립 크레딧 행, 2열 재화 카드와 107px 타일을 재사용한다.
- 3-2 카드에서는 Section 2의 65px 단계 아이템과 `이 병목으로 지연되는 단계` 버튼을 제거하고 `페이즈 N`과 해당 페이즈 소모량만 표시한다.
- 3-3은 동일 구조를 `전체 계획` 단일 카드로 단순화했으며, 각 전체 수량은 3-2의 같은 재화 페이즈 수량 합계와 정확히 일치한다.
- 크레딧은 두 탭 모두 일반 2열 grid 밖의 38px 독립 행을 유지하고, 일반 재화는 이름·소모량 label·수량의 3행 구조를 사용한다.
- 현재 수량은 typed UI preview다. 실제 저장 계획의 gross total 연결은 후속 데이터 작업으로 남긴다.

### 2026-07-30 Section 3-n 방향 전환·사선 grid·소모량 문구 보정

- 상태: `구현·집중 검증 완료·사용자 실화면 확인 대기`
- 3-1·3-2·3-3 본문 전환을 단순 fade switch에서 공용 순차 section motion으로 교체했다. 세 본문 모두 `intro 80° / outro 260°`이며 이전 본문 퇴장 뒤 새 본문이 진입한다.
- 3-n 재화 2열 배치는 rectangular `Wrap`을 제거하고 각 행의 top/bottom에서 부모 카드의 80° 좌우 rail을 다시 계산한다. 다음 행은 같은 x에 직각으로 쌓이지 않고 사선을 따라 왼쪽으로 이동한다.
- 3-2 일반 재화는 이름 아래 `진입 n │ 필요 m │ 종료 n-m`, 그 아래 `부족 k` 또는 `충족`을 표시한다. 독립 크레딧만 두 값을 한 가로 행에 표시한다. 3-3은 이름 아래 `보유 n / 필요 m`, 커스텀 확보율 bar와 백분율, `부족 k` 또는 `충족`의 3행을 표시한다. `페이즈 소모량`, `전체 소모량` label은 제거한 상태를 유지한다.
- 부족 여부는 하단의 `부족 k` 또는 `충족`이 전담하므로 재화 이름의 ` - 병목` suffix는 표시하지 않는다. 독립 크레딧 행은 자명한 `크레딧` 이름도 생략한다.
- 학교별 BD는 `기초 전술교육 BD : 아비도스`처럼 학교명을 붙인다. 오파츠·BD 등 비장비 이름에서는 tier를 제거하고 장비만 `(T10)` suffix를 유지한다.
- 후속 보정: Section 3의 반투명 glass foundation을 3-n 전환기 바깥의 고정 layer에서 제거하고 각 3-1·3-2·3-3 body 내부로 옮겼다. 따라서 glass 외곽과 내부 container가 같은 `260°` 퇴장·`80°` 진입 transform을 공유한다.

### 2026-07-30 Section 3-n 재화별 소비 계획 포커스

- 상태: `구현·집중 검증 완료·사용자 실화면 확인 대기`
- 3-1·3-2·3-3의 일반 재화 카드와 독립 크레딧 행을 모두 평행사변형 hit target으로 변경했다.
- 재화 선택 시 해당 재화를 소모하는 정확한 `phase/student/step`만 Section 2의 공용 핑크 테두리로 강조하고, 선택 재화 자체에는 1.5px 핑크 outline을 표시한다.
- 같은 재화를 다시 누르면 해제한다. 다른 재화, 지연 단계 action, Section 5 요약 또는 다른 3-n tab을 선택하면 기존 재화 포커스를 먼저 지워 강조가 겹치지 않게 한다.
- 전체 탭의 재화별 소비 단계 집합은 페이즈별 같은 재화 집합의 합집합이며, 표시되는 모든 sample 재화와 크레딧은 비어 있지 않은 소비 단계 집합을 가진다.

### 2026-07-30 Section 3-n 오파츠·장비 정식 이름 복원

- 상태: `구현·집중 검증 완료·사용자 실화면 확인 대기`
- v6 `core/oparts.py`의 icon suffix별 tier name과 `core/equipment_items.py`의 장비 tier name을 근거로 Section 3-n sample 명칭을 교정했다.
- T3 네브라는 `마모된 네브라 디스크`, T4 안티키테라는 `온전한 안티키테라 장치`, T10 장비는 `전자파 차단 헤어핀`·`게이밍 헬멧`·`스크린 워치`로 표시한다. 장비만 `(T10)` 표기를 유지한다.

### 2026-07-30 Section 3-2 수지·Section 3-3 확보율 표기

- 상태: `구현·집중 검증 완료·사용자 실화면 확인 대기`
- 3-2는 페이즈 진입 보유량, 필요량, 차감 후 종료량과 정확한 부족량 또는 `충족`을 같은 가로 행에 표시한다.
- 3-3은 보유량/전체 필요량, `보유 ÷ 필요` 기반 커스텀 확보율 bar와 반올림 백분율, 부족량 또는 `충족`의 3행 상세 구조를 사용한다. bar fill은 100%로 제한하지만 수량 계산은 제한하지 않는다.
- 독립 크레딧 행도 같은 수량 규칙을 사용하지만 `크레딧` 이름은 생략한다. 3-2는 가로 단일 행으로 돌아가 38px, 3-3은 58px 높이를 사용한다.

### 2026-07-30 Section 3-2 가로 수지 및 Section 3-3 bar 가시성 보정

- 상태: `구현·집중 검증 완료·사용자 실화면 확인 대기`
- 3-2의 독립 크레딧 수지 문자열과 `부족/충족`을 한 Row에 배치하고, 3-2·3-3 재화 이름의 중복 ` - 병목` suffix를 제거했다. 일반 재화는 후속 요청에 따라 상태를 수지 아래 행으로 원복했다.
- 3-2·3-3 독립 크레딧 행에서는 `크레딧` 이름을 렌더링하지 않고 수량 정보부터 표시한다.
- 확보율 `CustomPaint`에 실제 높이를 강제해 bar track과 fill이 그려지게 했으며, 퍼센트 오른쪽에 compact 10px·일반 14px 배율 여백을 적용했다.

### 2026-07-30 Section 3-2 일반 재화 상태 원복 및 bar 높이 조정

- 상태: `구현·집중 검증 완료·사용자 실화면 확인 대기`
- 3-2 일반 재화는 `진입│필요│종료` 아래에 `부족/충족`을 다시 배치하고, 크레딧만 긴 독립 행 안에서 가로 배치를 유지한다.
- 3-3 확보율 bar는 일반 12px→10.8px, compact 8px→7.2px로 정확히 10% 낮췄다.

### 2026-07-30 최대화 창 작업 기준 및 시작 상태

- 상태: `구현·전체 자동 검증·Windows release 빌드 완료·사용자 실화면 확인 대기`
- 별도 지시가 없는 UI 작업과 실화면 검수는 현재 모니터의 작업 표시줄 제외 작업 영역까지 최대화한 창을 canonical viewport로 사용하도록 반응형 정책에 명시했다.
- Windows runner의 첫-frame `ShowWindow` 명령을 `SW_SHOWNORMAL`에서 `SW_MAXIMIZE`로 변경해 프로그램이 작은 복원 창을 먼저 보이지 않고 최대화 상태로 시작하게 했다.
- 검증: Flutter 전체 test 222개, `flutter analyze`, Windows release build를 통과했다.

### 2026-07-30 Section 3-3 확보율 bar 높이 재적용

- 상태: `구현·집중 검증 완료·사용자 최대화 실화면 확인 대기`
- 이전처럼 확보율 행 전체를 줄이지 않고, 행은 일반 12px·compact 8px를 유지해 퍼센트 정렬을 보존한다.
- 실제 `CustomPaint` track/fill만 행 중앙에서 일반 10.8px·compact 7.2px로 그려 원래 bar 대비 정확히 10% 얇게 보이도록 수정했다.
- 계획 화면 Widget test에서 일반·compact 각각 outer row와 painted bar 높이를 분리 검증한다.

### 2026-07-30 계획 Section 4 제어 및 Section 6 재화 유형 필터

- 상태: `구현·전체 자동 검증 완료·사용자 최대화 실화면 확인 대기`
- Section 4의 학생 탭형 삼각형 안에 위에서부터 재화 유형 필터 버튼, 충족 재화
  숨기기 버튼, 재화 정렬 드롭다운을 배치했다. 두 버튼은 아이콘만 유지하고 hover
  tooltip으로 라벨을 제공한다. 정렬은 학생 Section 1의 투명·1px 핑크 outline·
  compact label·도형 화살표 커스텀 드롭다운 구조로 통일했다.
- 세 control의 실제 surface 사이 간격을 기존의 80%로 줄이고 남는 높이를 surface에
  균등 배분해 버튼 면적을 넓혔다. 최대화 geometry test에서 간격 비율과 높이 증가를
  수치로 검증했다.
- 재화 유형 필터를 누르면 Section 5와 동일한 외곽 glass·shadow·path를 쓰는
  Section 6으로 순차 전환한다. Section 6은 단일 4열·3행 checkbox 군과 초기화 버튼을
  가지며 `전체`와 10개 고유 재화 유형을 제공한다. 중복 요청된 강화석은 한 항목으로
  정규화했다.
- 4열 전환으로 모든 항목이 한 화면에 들어가므로 중간 외곽 painter, clip,
  `SingleChildScrollView`를 제거했다. Section 6은 필터 container와 초기화 버튼의
  두 요소만 가지며, Widget test에서 scroll 부재와 첫 행 4개 정렬을 검증한다.
- 필터 제목은 18px, checkbox label은 15.75px로 기존 대비 1.5배 확대했으며,
  최대화 geometry test에서 두 font size와 4열 첫 행을 함께 검증한다.
- 유형 필터, 충족 숨김, 기본/부족량/필요량/보유량/이름 정렬을 Section 3-n의 병목,
  페이즈별, 전체 preview에 공통 연결했다. 제어 변경 시 숨겨진 재화의 학생 계획
  강조가 남지 않도록 기존 포커스를 해제한다.
- 검증: `flutter analyze`, 계획 화면 20 tests, Flutter 전체 225 tests를 통과했다.
  Section 5·6 bounds 일치와 Section 4 control center의 삼각형 내부 배치를
  `2560×1392` canonical 최대화 viewport에서 검증했다.

### 2026-07-30 Section 3-n 2열 재화 rail 및 정렬 label 보정

- 상태: `구현·집중 검증 완료·사용자 최대화 실화면 확인 대기`
- 3-1·3-2·3-3 공용 2열 grid에서 카드 크기는 유지하고 왼쪽 열을 10.70px 오른쪽,
  오른쪽 열을 10.70px 왼쪽으로 이동했다. 두 외곽 painted rail은 부모 rail 기준
  약 22.70px inset이 되어 38px 크레딧 행·지연 단계 버튼과 일치하고, 65px 단계
  아이템과의 차이는 1px 미만이다.
- 정렬 드롭다운의 compact label 왼쪽 inset을 11px에서 26px로 늘려 한 글자 폭만큼
  오른쪽으로 이동했다. 좁은 control에서는 폭의 24%로 반응형 제한한다.
- 검증: `flutter analyze` 및 계획 화면 21 tests 통과. geometry test에서 기존
  107px 높이와 열 너비가 유지되는 동시에 네 외곽 rail 지점이 기준 inset에
  일치하는지 확인했다.

### 2026-07-30 계획 탭 UI 세션 시행착오 및 다음 세션 인계

- 상태: `현 세션 UI 구현·집중 검증 완료·실데이터 연결 다음 세션 대기`
- 시행착오와 재발 방지는
  `almanac/design/section-template-studio.md`의
  `2026-07-30 계획 탭 Section 3~6 작업 시행착오와 재발 방지`에 기록했다.
- 다음 세션용 source-of-truth handoff는
  `docs/migration/p2-planning-screen/next-session-handoff-2026-07-30.md`다.
- 현재 `PlanningPage`는 `AppService`와 학생 탭 `initialSeed`를 전달받지만 사용하지
  않으며, Section 1은 foundation만 있고 Section 2~6의 데이터는 typed preview
  상수다. 다음 세션은 이를 실제 repository goal/current/inventory 및 planning
  계산 결과에 연결하는 vertical slice를 시작해야 한다.
- 현 최신 검증 기준은 `flutter analyze`, 계획 화면 집중 21 tests,
  `codealmanac validate`, `git diff --check`다. 최신 Section 6·rail 보정 이후 Flutter
  전체 suite와 Windows release build는 다시 실행하지 않았으므로 다음 세션의
  마감 gate로 남긴다.

### 2026-07-30 계획 탭 인메모리 페이즈 편집 화면

- 상태: `목록 재배치 구현·집중 검증 완료 / 버튼 재배치 대기`
- 계획-메인 Section 1에 임시 호출 action을 추가하고, 더미 계획 요소를 페이즈로
  배정하는 4-Section 편집 화면을 추가했다.
- 페이즈 생성·제거·inline 이름 수정, 상세 항목 drag 이동, 제거 시 미배정 복귀,
  미배정 0개 전 완료 잠금, 완료 시 편집 Section 4를 메인 Section 2 위치로 이동한
  뒤 메인 화면이 인메모리 구성을 이어받는 흐름을 구현했다. 현재는 양쪽 compact
  목록의 기준 위치를 먼저 확정하기 위해 뒤로/생성/제거/완료 버튼 렌더링을
  임시 제거했으며, 관련 상태 변경 로직은 다음 버튼 배치 작업을 위해 유지한다.
- Section 1·2·3과 Section 4는 scroll Y를 80° rail X 이동으로 변환하며 전용 사선
  track과 handle을 사용한다. Section 2·4는 메인 Section 2와 동일한 `29×94`
  크기를 사용한다.
- 후속 보정으로 Section 1↔2와 Section 4↔3의 facing edge에 최소 12px seam을
  정의했다. 양쪽 compact 목록(코드 `element-1`, `element-3`)은 각 사다리꼴의
  짧은 수평 변에서 양쪽 12px 법선 간격에 해당하는 수평 inset을 차감한 길이를
  목록 평행사변형의 수평 변 길이로 사용한다. 목록 bounds는 Section 중심에 두어
  좌우 수평 마진을 같게 하고, 위·아래는 각각 10px inset한다. Section seam과
  목록-사다리꼴 사선 간격은 모두 80° 선의 법선 거리로 계산한다.
- Section 2·4 최외곽 container를 10px inset 양면 평행사변형으로 교체했다.
  모든 사선 목록에서 platform 수직 scrollbar를 끄고 전용 80° rail만 남겼다.
- 후속 실화면에서 평행사변형 원본을 bounds로 재교차하며 한쪽 사선이 잘리는 회귀를
  확인했다. Section 1·3 목록, Section 2·4 최외곽과 반복 item을 기존 bounds 안에서
  좌상단·우하단을 대칭 절단하는 단일 bilateral path로 교체해 크기와 양쪽 80°
  사선을 함께 보존했다.
- Section 1의 편집 초기 폭은 96칸 정수 그리드에서 15% 축소에 가장 가까운
  18칸으로 줄였다. Section 4는 편집 중부터 완료 전환까지 Section 2 및
  계획-메인 Section 2와 같은 29칸 폭을 유지한다.
- 후속 정밀 대조에서 상세 container 기준을 계획-메인 Section 2와 같은
  `sectionPath.getBounds().deflate(10)`으로 통일했다. 상세 행은 메인과 같은
  65px 높이·69px extent, phase header 38px, phase 간격 20px을 사용한다.
  양쪽 compact 사선 목록은 Studio JSON의 형태만 참고하고, 현재 배치 크기는 위의
  짧은 변·대칭 마진 규칙으로 계산한다. Section 4 배정 스크롤은 별도 축소 wrapper
  없이 29칸 Section의 10px inset 내부 컨테이너 전체를 사용한다.
- Section 1 portrait에 `square.png` 배경을 추가하고 label을 `학생 · N단계`로
  통일했다. Section 4는 항목 앞·사이·뒤 drop target, hover 삽입선, 같은 phase
  내부 재정렬을 지원한다.
- 산출물: `frontend/lib/ui/widgets/plan_phase_editor.dart`,
  `frontend/lib/ui/widgets/plan_section_layout.dart`,
  `frontend/test/planning_page_test.dart`.
- 데이터 영구 저장과 이전 계획 요소 생성 화면 연결은 포함하지 않는다.
- 현재 목록 재배치 검증: `flutter analyze`, 계획 화면 34 tests, Flutter 전체
  242 tests(`--concurrency=1`), Python 123 tests, Windows release build 통과.
  기본 병렬 Flutter suite에서는 실제 Python 프로세스 테스트 2개가 경합으로
  실패했지만 두 파일 단독 실행과 단일 동시성 전체 suite에서는 모두 통과했다.
  이번 버튼 제거·목록 재배치 상태의 최대화 실화면 확인은 아직 수행하지 않았다.
- 2026-07-30 간격 후속 보정은 `1280×720`, `1920×1080`, `2560×1392`에서
  Section facing seam, compact
  목록의 평행 사선 법선 간격, 반대쪽 직선 옆면 최소 간격이 모두 12px 이상임을
  수치로 검증한다.
- 2026-07-30 상세 배정 후속 작업에서 Section 2의 각 미배정 행을 65px item,
  6px seam, `65×65` 빠른 이동 버튼으로 분리했다. 버튼은 선택된 phase의 마지막
  index에 즉시 삽입한다. Section 3의 선택 ID를 Section 4 phase card 강조와
  빠른 이동 대상이 함께 사용한다.
- Section 4 결과 item은 계획-메인 Section 2처럼 phase card의 양쪽 80° 경계에서
  계산한 가용 폭 전체를 사용하며 오른쪽에 별도 버튼용 빈 폭을 남기지 않는다.
  drag feedback의 고정 250px 폭을 제거하고 각 원본 item의 실제 폭·65px 높이와
  0.72 opacity를 그대로 사용한다.
- 빠른 이동 버튼과 Section 3·4 선택 강조는 계획-메인의 공용
  `diagonalMediaHighlightColor`(`#F2B3EF`)를 사용한다. 버튼의 hover·pressed ink는
  평행사변형 `ClipPath` 안쪽 Material에서 그려져 사각형 모서리로 번지지 않는다.
  겹치는 사선 Section의 투명 bounds가 아래쪽 컨트롤을 가로채지 않도록 장식
  painter도 pointer hit test에서 제외했다.
- Section 1 compact 목록의 `square.png`는 원본 252×204 비율을 36×36
  `BoxFit.cover`로 잘라 쓰던 구성을 제거했다. 44×36 `BoxFit.contain` 배경과
  중앙 32×32 portrait 안전 영역으로 분리해 배경의 좌우 모서리를 보존한다.

### 2026-07-30 계획 페이즈 편집기 측면 버튼 배치

- 상태: `구현·전체 자동 검증 완료·사용자 실화면 확인 대기`
- Section 1과 Section 3의 확정된 평행사변형 스크롤 목록은 그대로 유지하고, 각
  사다리꼴에 남은 측면 영역에만 버튼을 복원했다.
- 공통 12px 간격을 버튼 사이, 섹션 직선면, 80° 목록 빗면에 적용한다. 사선 간격은
  수평 차이가 아니라 법선 거리로 환산하며, 버튼 높이는 섹션 높이에 반응하는 동일
  44~72px 범위를 사용한다.
- Section 1은 돌아가기·전체 배치·전체 되돌리기, Section 3은 페이즈 위/아래 이동,
  생성·제거, 완료를 제공한다. 전체 배치와 제거/되돌리기의 데이터 이동 및 원래 순서
  복원도 함께 구현했다.
- 완료는 미배정 요소가 남으면 어두운 잠금 overlay와
  `계획 요소를 전부 배치하세요` tooltip을 표시한다. 같은 비활성 처리를 일괄 동작에도
  재사용한다. hover·pressed ink와 잠금 overlay는 각각의 사다리꼴·평행사변형
  경로로 clip된다.
- 후속 보정에서 Section 1의 `전부 되돌리기`와 Section 3의 `위로 조정`도 이웃 버튼과
  같은 좌/우 face 사다리꼴로 바꿨다. Section 1~4 공통 사선 목록에는 scroll range 기반
  위·아래 안개를 추가했다.
- 80°/260° motion은 화면 수학 좌표를 Flutter 좌표로 변환할 때 Y를 반전한다. 따라서
  Section 2·4의 260° 퇴장은 실제 좌하단이며, 완료 전환의 Section 4는 controller
  reverse 없이 계획-메인 Section 2 위치로 왼쪽 이동하는 기존 경로를 유지한다.
- Section 4 phase 번호와 계획-메인 Section 2 번호는 공용
  `AppTextStyles.planPhaseNumber`를 사용한다.
- 학생 탭의 필터·학생 grid와 타이틀의 portrait·profile 사선 목록 wrapper는 플랫폼
  기본 scrollbar painting을 끄고 전용 80° scrollbar만 표시한다.
- 최종 검증: `flutter analyze`, Flutter 전체 243 tests(`--concurrency=1`),
  Windows release build, `codealmanac validate`, `git diff --check` 통과.

### 2026-07-30 계획 메인 우측 컨트롤 및 페이즈 이름 편집 후속 보정

- 상태: `구현·전체 자동 검증 완료·사용자 실화면 확인 대기`
- 계획 메인 최우측 삼각형 Section 4의 세 컨트롤은 기존 반응형 대간격을 제거하고 페이즈 편집기 Section 3과 동일한 12px 경계 간격을 사용한다. 버튼 높이와 기존 사다리꼴 경로는 유지한다.
- 페이즈 편집기 Section 3 이름 입력은 바깥 클릭으로 포커스를 잃을 때도 저장·종료된다. 완료 루틴은 중복 포커스 이벤트에 안전하며, 편집 외부의 이름 변경도 입력 컨트롤러에 동기화한다.
- 회귀 검증은 12px 컨트롤 간격과 바깥 클릭 이름 커밋을 포함한다.
- 검증: `flutter analyze`, 계획 화면 집중 35 tests, Flutter 전체 243 tests(`--concurrency=1`), Windows release build 통과.

### 2026-07-31 계획 페이즈 편집 시행착오 및 프리셋 제조 세션 인계

- 상태: `문서화 완료·프리셋 제품 계약 확정 대기`
- 페이즈 편집기 구현 중 확인한 사선 법선 간격, 자식 bounds 기반 bilateral path,
  pointer/scrollbar 중복, 실제 drag geometry, 재정렬 index, Flutter Y 좌표,
  focus-loss 커밋, 테스트 프로세스 경쟁 문제를
  `almanac/design/plan-phase-editor-lessons-2026-07-31.md`에 기록했다.
- 다음 세션의 활성 handoff는
  `docs/migration/p2-planning-screen/preset-builder-next-session-handoff-2026-07-31.md`다.
  기존 `next-session-handoff-2026-07-30.md`는 페이즈 편집기 구현 전의 역사 기록으로
  유지한다.
- 현재 코드에는 계획 프리셋 DTO, versioned protocol, repository 저장 계약이 없다.
  프리셋의 절대/상대 의미, 포함 필드, 미지정 필드, 기본 적용, 전역/프로필 scope,
  이번 구현의 영속화 범위를 사용자에게 먼저 확인한다.
- 다음 작업은 계약 확정 → 전용 Studio JSON → 별도 인메모리 draft →
  계획 탭 연결 → 학생 탭 적용 → 승인된 protocol/repository 순서로 진행한다.
- 이번 변경은 문서만 수정했으며 제품 코드와 기존 검증 기준선
  (`flutter analyze`, 계획 35 tests, 전체 243 tests `--concurrency=1`,
  Windows release build)은 변경하지 않았다.

### 2026-07-31 계획-페이즈 상위 탭 전환 퇴장 보정

- 상태: `구현·자동 검증 완료·사용자 실화면 확인 대기`
- 계획-페이즈 편집 화면에서 학생 탭 등 다른 상위 탭으로 이동할 때
  `PlanSectionLayout.active`가 `PlanPhaseEditor.active`까지 전달된다.
- 편집기는 상위 비활성화 시 네 section controller를 각각 1에서 reverse하여
  기존 180°·260°·0° outro 방향과 360ms duration을 그대로 재생한다. 상위
  `AnimatedSectionStack`가 outgoing 계획 페이지를 유지하는 동안 퇴장이 완료되고,
  incoming 독립 탭 section은 기존 `onIncomingReady` 시점부터 진입한다.
- 자체 취소·완료 전환 중에는 상위 active 변경이 편집기 controller를 재시작하지
  않도록 보호했다.
- 회귀 테스트는 상위 active가 꺼진 중간 프레임에서 네 편집 section의 실제
  translation 방향을 확인한다.
- 검증: 계획 화면 집중 36 tests, Flutter 전체 244 tests
  (`--concurrency=1`), `flutter analyze`, Windows release build 통과.

### 2026-07-31 계획 요소 제작 제품 계약 확정

- 상태: `첫 vertical slice 구현·전체 자동 검증 완료·사용자 실화면 확인 대기`
- 계획 요소 제작 화면은 `section-plan-starter.ba-section-studio.json`의 Section
  3·5·6·7을 각각 학생 현재 상태, 프리셋 불러오기, 누적 목표 단계 제작, 미배정
  계획 요소 목록으로 사용한다.
- `section-preset-element.ba-section-studio.json` 전체가 한 단계 카드이며 단계가
  늘어나면 카드가 하나씩 추가된다. 단계는 누적 목표 snapshot이고 상위 단계 값을
  올리면 순서를 위반하는 이후 값을 자동으로 올린다. 값을 낮출 때 이후 단계는
  낮추지 않는다.
- 같은 학생의 여러 단계는 페이즈 및 페이즈 내부 순서 전체에서 엄격한 순서를
  유지한다. 잘못된 drop은 거부하며 목표 의미가 바뀌면 해당 학생의 모든 단계를
  다시 미배정한다. 이름만 바뀌면 기존 배정을 유지한다.
- 미보유 학생은 정적 메타데이터에서 유도한 명시적인 가상 시작점을 사용한다.
  인연 랭크 목표는 포함하되 아이템 메타데이터 연결 전 비용은 미지원으로 표시하고,
  심상개화는 잠금 상태로 둔다.
- 첫 vertical slice는 학생 탭의 `PlanningStudentSeed`, 인메모리 프리셋 fixture,
  제작·미배정·페이즈 연결까지만 포함한다. 프리셋 영속화와 계획 탭 직접 학생
  선택은 후속 범위다.
- 계약 문서:
  `docs/migration/p2-planning-screen/plan-element-builder-contract-2026-07-31.md`
- 학생 탭의 보유·미보유 `PlanningStudentSeed`를 Section 3에 연결하고, Section 5
  프리셋 덮어쓰기, Section 6 누적 단계 카드 제작, Section 7 미배정 목록과 이름
  편집, 페이즈 편집기 연결을 구현했다.
- 단계 추가는 선택된 snapshot을 복제하고, 중간 삭제는 나머지 ID와 값을 보존한다.
  이전 단계를 올릴 때 이후 단계의 충돌 값만 자동 보정하며, 페이즈 편집기는 학생별
  전역 단계 순서를 위반하는 배치를 거부한다.
- 목표 확정 시 같은 학생의 기존 페이즈 배정을 모두 해제하고 달성 완료 단계는
  미배정 목록에서 생략한다. 모든 미배정 요소가 페이즈에 들어가기 전에는 완료할 수
  없다.
- 검증: `flutter analyze`, 계획 요소 전용 8 tests, Flutter 전체 252 tests
  (`--concurrency=1`), Windows release build 통과. 프리셋 영속화, 계획 탭 직접
  학생 선택, 인연 비용 메타데이터 연결은 계약대로 후속 범위다.

### 2026-08-01 계획 요소 제작 Section 3 Studio 내부 구성 보정

- 상태: `구현·전체 자동 검증 완료·사용자 실화면 확인 대기`
- 기존 구현은 `section-plan-starter.ba-section-studio.json`에서 Section 3 외곽만
  투영하고 내부를 단일 Column으로 재구성해 Studio 문서와 일치하지 않았다.
- 최신 Studio JSON의 Container 1·2·3·5·6·7·8·9와 Feature 2·5를 typed
  projection 및 런타임에 반영했다. Container 10은 잘못된 데이터로 판정되어 최신
  JSON과 런타임 모두에서 제거됐다.
- Feature 2는 학생 탭의 레벨·소속 학원 인디케이터, Feature 5는 전용무기 레벨,
  Container 8은 초상 위에 표시되는 인연 랭크 인디케이터다. 인연 비용 메타데이터
  미연결 안내는 Feature 2의 헤더에 표시한다.
- 학생 탭의 스킬·장비·추가 능력치·심상개화 위젯을 공용화해 Container 5·6·7·9에
  재사용한다. 미보유 배지는 후속 작업에서 초상 이미지 위쪽에 추가한다.
- 저장된 Studio JSON과 typed projection의 전체 JSON 일치, Section 3 내부 ID와
  Container 10 부재, 각 상태 인디케이터 렌더링을 계획 요소 전용 10 tests로
  검증했다. 학생·계획 집중 82 tests, Flutter 전체 266 tests(`--concurrency=1`),
  `flutter analyze`, Windows release build, `codealmanac validate`가 통과했다.
- 최신 빌드의 Windows UI 자동 캡처는 앱 실행 승인이 시간 초과되어 수행하지
  못했으므로 실제 화면의 글자 밀도와 Container 8/초상 중첩은 사용자 확인 대기다.
- 2026-08-01 almanac 자체 리뷰에서 Container 1에 `BondRankPortrait`를 넣어 인연을
  중복 표시하고, Container 8에는 학생 탭 최종형과 다른 하트·`인연` 문구를 표시한
  오류를 확인했다. Container 1은 순수 초상으로 교체하고 Container 8은 실제 rounded
  local path를 받는 공용 `StudentBondStatus`의 숫자-only gauge로 교체했다.
- `studentBondRankRect`와 gauge host도 optional actual outer path를 공유하도록 보정해,
  테스트와 런타임 모두 rounded·parent-intersected 경로에서 rank band를 계산한다.

### 2026-08-01 계획 요소 Section 6 preset-element 카드 투영

- Status: `구현·전체 자동 검증 완료·사용자 실화면 확인 대기`
- Section 6 단계 카드를 `section-preset-element.ba-section-studio.json`의 아홉
  element 좌표와 24:43 합집합 캔버스로 교체했다. Element 5는 내부 배경으로만
  사용하고 전체 카드를 자르지 않으며, element 2·3·4의 우측 돌출을 보존한다.
- 각 element는 동일한 반응형 80도 path를 독립적으로 채움·테두리·clip에 사용하고,
  카드 선택과 ink는 모든 element의 합집합 path를 사용한다. 단계명은 제거하고
  element 5 좌측 여백에 단계 번호만 표시한다.
- Element 4는 학생 5칸과 전용무기 4칸의 클릭 가능한 성작 스트립이다. 나머지
  구현 영역은 기존 감소·값·증가 제어를 유지하며 element 9는 잠금 상태다.
- 2026-08-01 자체 리뷰에서 typed JSON과 런타임 path가 분리돼 있음을 확인했다.
  수동 `_bilateralPath` 재구성을 제거하고 각 element의 저장된 `shape spec`을 공용
  polygon builder에 전달한 실제 path를 fill·border·clip·test가 공유하도록 고쳤다.
  시각 캡처에서 조작 면적이 작았던 성작 strip은 28px hit overlay를 추가했고,
  증감 아이콘은 `18×22px` 입력 면적을 갖도록 보정했다.
- Added typed Studio source `frontend/lib/ui/studio/preset_element_studio_layout.dart`
  and focused JSON parity, protrusion, ratio, nine-surface, star-input tests.
- Verification: 계획 요소 15 tests와 학생 레이아웃을 합친 집중 52 tests, Flutter
  전체 271 tests (`--concurrency=1`), `flutter analyze`, Windows release build
  통과. 2560×1392 widget raster probe에서 카드 외곽, 아홉 surface, 우측 돌출,
  성작 strip과 Container 8 숫자-only gauge를 확인한 뒤 임시 probe artifact는 제거했다.
- Next action: 사용자가 최신 Windows 빌드에서 카드 밀도, 단계 번호 위치, 얇은
  성작 스트립의 클릭성을 시각 확인한다. 인연 비용 메타데이터와 심상개화는 기존
  계약대로 후속 범위다.

### 2026-08-02 학생 Section 2 그리드 마스크·상태 배지 보정

- 상태: `구현·집중 자동 검증 완료·사용자 실화면 확인 대기`
- 이 항목의 전체 시행착오와 재발 방지 기준은
  [학생 카드 그리드·목록·초상 반복 개선 기록](../design/student-card-rendering-lessons-2026-08-02.md)을
  따른다.
- 학생 카드의 마지막 이름·속성·미보유 overlay 마스크에도 배경과 같은 `0.125`
  alpha cutoff를 적용했다. 배경 및 초상 painter 수정 뒤에도 남아 있던
  `square.png` 원본 캔버스 크기의 희미한 직사각형을 이 마지막 합성 단계에서 제거한다.
- 원본 PNG를 편집기에서 확인한 결과와 확대 스크린샷을 대조해, 남은 축 정렬 1px 선은
  PNG 알파 테두리가 아니라 `saveLayer`가 이미지의 정확한 `fitted/card` 사각 bounds와
  맞닿은 상태에서 필터링되는 합성 경계로 재분류했다. 배경·초상·선택 외곽선·overlay의
  offscreen layer bounds를 실제 콘텐츠 rect보다 2px 확장해 visible silhouette와 layer
  allocation 경계를 분리했다.
- 후속 실화면에서도 하단선이 유지되어 layer-bound 가설을 폐기했다. 최신 캡처에서 선은
  `square.png` 마지막 알파 행의 유효 폭과 일치했고, 카드 배경보다 이름 overlay mask가
  좌우로 길게 남는 형상 불일치로 확정했다. 학생 그리드는 이제 bitmap alpha를 형상으로
  사용하지 않고 `studentGridCardPath`의 80도 rounded parallelogram을 배경 clip, overlay clip,
  선택 stroke가 공유한다. `square*.png`는 edge-cropped 색상 소스로만 사용한다.
- 현재 상태 리스트의 세 배지는 80도 외곽선과 초상 슬롯 사이의 상단 협소 폭을
  그대로 사용하지 않는다. path에서 계산한 좌측 여백은 유지하되 공통 최소 폭을
  확보해 위 `UNOWNED`, 중앙 `PLAN`, 아래 `JP`의 글자가 과도하게 축소되지 않게 했다.
- 이미지 알파 마스크 제거 뒤에도 기존 카드 테두리의 시각 역할은 유지한다. 카드 콘텐츠와
  이름·속성 overlay를 모두 그린 뒤 foreground 단계에서 `studentGridCardPath`를 따라 흰색
  기본 stroke를 그려 clip 가장자리의 계단 현상을 덮는다. 기본선과 선택선은 모두 기존
  강조선 비율인 `0.02`이며, 선택된 카드는 분홍 강조 stroke를 가장 마지막에 같은 경로로 그린다.
- 후속 조정으로 흰 기본선은 `0.01`, 선택 강조선은 기존 `0.02`를 사용한다. 그리드 배지는
  card clip 밖의 foreground에서 그려 잘리지 않는다. `UNOWNED`는 상단 좌측 rounded corner,
  `JP`는 상단 우측 rounded corner에 접하고, `PLAN`은 `UNOWNED` 아래에서 카드 짧은 변의
  `0.01`만큼 간격을 둔 뒤 80도 rail 진행량만큼 왼쪽으로 이동한다. `JP`는 catalog의
  `jpOnly`, `PLAN`은 repository goal의 student ID 집합과 연결된다.
- `UNOWNED`의 좌측 위치에서 corner-radius 추가 inset을 제거해, 80도 상단 좌측 꼭짓점의
  rounded corner 시작 위치에 직접 붙도록 후속 조정했다.
- Section 2 그리드 로딩 병목 후속 작업으로 전체 스크롤 extent는 유지하면서 현재 viewport와
  위·아래 1개 buffer row에 속한 학생만 이미지 item, overlay, hit target으로 구성하도록
  row virtualization을 적용했다. 스크롤할 때 active row 범위가 바뀌면 벗어난 image stream
  listener를 해제하고 새 범위의 asset만 resolve한다.
- `AssetImageGrid`는 각 image stream 완료 시 즉시 `setState`와 전체 map 복사를 수행하지 않는다.
  같은 frame 동안 도착한 성공·실패 결과를 pending collection에 모은 뒤 post-frame callback
  한 번에서 immutable image map을 갱신해 연속 rebuild와 painter 실행을 병합한다.
- 첫 학생 탭 진입의 cold decode·paint 비용을 타이틀과 홈 체류 시간으로 분산한다. 타이틀이 이미
  로드한 catalog를 기본 이름 오름차순으로 정렬해 첫 64명과 bond background 3종을 선정하고,
  첫 frame 뒤부터 8 assets씩 `precacheImage`한 다음 매 batch 사이 한 frame을 양보한다.
  사용자가 타이틀을 빠르게 통과하면 offstage 상태의 StudentPage가 shared warmup controller로
  남은 asset을 이어받는다. 타이틀에는 `1/255` opacity의 실제 1-card grid painter를 잠시 그려
  clip, alpha layer, outline, badge, text 합성 경로도 미리 실행한다.
- Student Section 3의 `container-1`은 선택 학생 초상의 layout slot으로만 사용하고, 실제 visible
  card는 grid와 동일하게 `252×204` source가 `BoxFit.contain`으로 배치된 fitted rect에서 만든
  `studentGridCardPath`가 소유한다. 이미지 비율을 보존하므로 slot과 비율이 다르면 좌우 또는
  상하 여백이 생긴다. background는 `0.11` edge crop과 geometry clip, portrait는 grid와 같은
  `scale 0.98`·`clipRadiusFraction 0.12`·`alphaThreshold 0.04`를 사용한다.
- 전용 Section 3 overlay painter를 제거하고 `StudentGridCardOverlayPainter`를 1×1, name/attribute
  off, selection null로 직접 재사용한다. 따라서 미보유 dark overlay, `0.01` 흰 outline,
  `UNOWNED`·`PLAN`·`JP` 배지까지 배경과 동일한 fitted card path를 공유한다. PLAN은 repository
  goal, JP는 catalog `jpOnly`를 따른다.
- 후속 검증: 타이틀·학생 집중 71 tests, Flutter 전체 284 tests (`--concurrency=1`),
  `flutter analyze`, Windows release build, `codealmanac validate`, `git diff --check` 통과.

### 2026-08-02 학생 상세 인연 랭크 숫자 중앙 정렬

- 상태: `구현·집중 자동 검증 완료·사용자 실화면 확인 대기`
- Section 3 인연 랭크 숫자 영역에 남아 있던 폭 기반 `3~8px` 좌측 optical shift를 제거했다.
  숫자 영역은 실제 rounded·parent-intersected 삼각형 경로에서 측정한 하단 수평 span에
  좌우 동일 inset을 적용하므로, `FittedBox`의 중앙 정렬이 그 span의 정확한 중앙을 사용한다.
- 게이지 host, 하단 간격, 숫자 크기와 삼각형 외곽 형상은 변경하지 않았다.
- 검증: 학생 레이아웃 집중 46 tests, Flutter 전체 290 tests (`--concurrency=1`),
  `flutter analyze`, Windows release build, `codealmanac validate`, `git diff --check` 통과.

### 2026-08-02 계획 요소 외곽·초상·성작·인연 표시 통일

- 상태: `구현·전체 자동 검증 완료·사용자 실화면 확인 대기`
- 계획 요소 화면의 Section 3·5·6·7 외곽 foundation에서 삼각형 무늬를 제거하고
  `planElementBuilderSectionOpacity`를 사용하는 반투명 단색으로 교체했다. Section 3 내부
  컨테이너의 Studio `triangleTexture` 설정은 변경하지 않았다.
- Section 3 Feature 2는 학생 탭의 `StudentLevelStatus`를 직접 사용하며 학생 이름과
  인연 비용 미연결 헤더 문구를 제거했다.
- Container 1 초상은 학생 탭과 같은 `AssetImageGrid` 계약으로 교체했다. 인연 배경의
  `0.11` edge crop과 `studentGridCardPath`, 초상의 `0.98` scale·`0.12` clip radius·
  `0.04` alpha cutoff를 공유하며, 미보유·PLAN·JP 배지는 기존 결정대로 이번 범위에서
  추가하지 않았다.
- 학생 탭과 계획 탭의 성작 표시는 공용 `paintStudentStarStatus`와
  `StudentStarStatus`를 사용한다. Section 6 Element 4는 직전 snapshot을 현재 채움으로,
  해당 단계 목표를 학생 금색·전용무기 청색 테두리로 표시하며 기존 아홉 칸 click
  hit target과 목표 갱신 동작을 유지한다.
- 계획 Container 8은 공용 `StudentBondStatus`의 `inverted` 변형을 사용한다. 게이지
  그림만 180도 반전하고 rank band는 위쪽으로 mirror하며 숫자 glyph는 정방향을 유지한다.
- 계약 문서 `docs/migration/p2-planning-screen/plan-element-builder-contract-2026-07-31.md`를
  같은 시각·상태 표현으로 갱신했다.
- 검증: 계획 요소·학생 집중 62 tests, Flutter 전체 286 tests (`--concurrency=1`),
  `flutter analyze`, Windows release build 통과. 2560×1392 widget raster probe에서 외곽
  단색, 내부 texture 보존, 학생 탭 방식 초상, 현재 채움·목표 테두리 성작, 180도 반전
  인연 인디케이터를 확인한 뒤 임시 probe와 캡처 artifact를 제거했다.
- 다음 작업: 사용자가 최신 Windows build에서 Container 8의 위쪽 숫자 여백과 Section 6
  성작 테두리 굵기·색 대비를 최종 시각 확인한다.

### 2026-08-02 계획 Section 3 외곽·내부 rail 재정렬

- 상태: `구현·전체 자동 검증 완료·사용자 실화면 확인 대기`
- 계획 Container 3은 학생 탭과 같이 foundation의 fill·outline 대상에서 제외하고 성작
  아홉 세그먼트만 그린다.
- Container 8은 기존 좌측 face 사다리꼴에서 좌측 face 삼각형으로 바꾸고, 초상 패널과
  상단 12px·하단 약 10px의 평행 간격이 남도록 오른쪽으로 이동했다. 내부 인연 게이지의
  180도 반전과 정방향 숫자 계약은 유지한다.
- 상단 Container 8·1·2의 기존 픽셀 크기와 세로 위치를 기준으로 Section 3 폭을 Studio
  28칸에서 27칸으로 줄였다. Container 3·5·6·7·9는 기존 y·height·세로 간격을 보존하고
  새 Section 3의 우측 80도 rail에서 12px 안쪽에 오도록 x·width를 다시 계산했다.
- 저장된 `section-plan-starter.ba-section-studio.json`과 typed projection을 함께 갱신했다.
  2560×1392 widget raster probe에서 Container 3 외곽선 제거, 삼각형 Container 8,
  상단 패널 묶음에 맞춘 외곽 폭과 하단 패널의 점진적 우측 inset을 확인한 뒤 임시
  probe와 캡처 artifact를 제거했다.
- 검증: 계획 요소·학생 집중 63 tests, Flutter 전체 287 tests (`--concurrency=1`),
  `flutter analyze`, Windows release build 통과. Studio JSON parity, Section 3의 27칸 폭,
  Container 8의 좌측 face triangle, Container 3 foundation 제외, 하단 다섯 패널의
  12px rail gap을 집중 회귀 테스트로 고정했다.
- 다음 작업: 사용자가 최신 Windows build에서 삼각형 Container 8의 숫자 크기와 초상
  사이 여백, 하단 패널 우측 끝의 시각적 평행성을 최종 확인한다.

### 2026-08-02 계획 Section 3 독립 초상·배지·애장품 메타데이터 분기

- 상태: `구현·전체 자동 검증 완료·사용자 실화면 확인 대기`
- 계획 Section 3의 Container 1을 Studio JSON과 typed projection에서 제거했다. 초상은
  Section 3 기준 독립 placement에 직접 배치하며 `AssetImageGrid`의 fitted card path와
  `StudentGridCardOverlayPainter`만 visible surface·흰 외곽선·상태 배지를 소유한다.
- 계획 초상에도 학생 탭과 같은 `UNOWNED / PLAN / JP` 배지를 연결했다. 각각 seed 보유
  상태, 기존 계획 요소 존재 여부, `jp_only` 메타데이터를 사용하며 미보유 암전도 같은
  overlay painter에서 처리한다.
- 초상과 인연 Container 8을 오른쪽으로 재배치하고 Container 8의 세로 범위를 초상 slot과
  맞춰, Section 3 좌측 rail에 잘리는 삼각형 면적을 줄이면서 두 visible path의 비중첩을
  유지했다.
- 애장품은 `has_favorite_item_kr` 또는 `has_favorite_item` 메타데이터가 없으면 잠금 아이콘
  대신 `-`를 표시한다. 메타데이터가 존재하고 현재 티어가 0인 경우에만 잠금 아이콘을
  표시한다. catalog DTO 연결은 학생 메타데이터 편집기 갱신 뒤의 후속 범위다.
- 검증: 계획 요소·학생 집중 65 tests, Flutter 전체 289 tests (`--concurrency=1`),
  `flutter analyze`, Windows release build 통과. 2560×1392 widget raster probe에서 Container 1
  surface 제거, 초상 우측 이동, 인연 삼각형과 초상 사선의 간격, 세 배지 합성을 확인하고
  임시 probe test를 제거했다.
- 다음 작업: 사용자가 최신 Windows build에서 세 배지의 실제 텍스트 크기, 초상·인연
  삼각형 간격, 애장품 `-` 표시를 최종 확인한다.

### 2026-08-02 계획 Section 3 상단 패널 높이·간격 후속 조정

- 상태: `구현·전체 자동 검증 완료·사용자 실화면 확인 대기`
- 독립 초상 rect는 Container 2의 실제 clipped path 높이를 사용해 계산한다. 학생 카드의
  `252:204` 비율을 유지하면서 초상 상·하단과 Container 2 상·하단을 일치시켰다.
- Container 2는 기존 우측 rail 위치를 유지하고 좌측 경계만 오른쪽으로 이동해 폭을
  줄였다. 확보한 공간으로 초상을 오른쪽 방향으로 확대했고 두 평행 사선의 기준 간격을
  약 48px에서 24px로 절반 축소했다.
- Container 8 placement 높이를 직전 값의 정확히 1.3배로 늘렸다. 2560×1392 raster에서
  rounded triangle의 visible 높이는 약 186px에서 256px로 37% 증가했고 성작 스트립과
  겹치지 않았다.
- `StudentLevelStatus`의 레벨/학교 문양 구분선은 기존 `width * 0.06` run을 제거하고
  `height / tan(80°)`를 사용하도록 교정했다. 집중 geometry test가 계산 각도 80도를 고정한다.
- 검증: 계획 요소·학생 집중 66 tests, Flutter 전체 290 tests (`--concurrency=1`),
  `flutter analyze`, Windows release build 통과. 2560×1392 widget raster에서 초상·Container 2
  높이 일치, 24px 사선 간격, 확장된 삼각형과 성작 스트립의 비중첩을 확인했다.
- 다음 작업: 전체 자동 검증 후 사용자가 최신 Windows build에서 좁아진 학교 문양 영역과
  확장된 인연 삼각형의 숫자 여백을 확인한다.

### 2026-08-02 계획 인연 삼각형 좌측 rail·게이지 합성 통일

- 상태: `구현·전체 자동 검증·Windows release 빌드 완료·사용자 실화면 확인 대기`
- Container 8의 폭·높이는 유지하고 left placement만 Container 3의 left와 같은 값으로
  옮겼다. 따라서 삼각형의 왼쪽 수직 변이 바로 아래 성작 패널의 좌측 시작점과 연결된다.
- Container 8의 `triangleTexture`를 활성화해 학생 탭 Container 10처럼 Section foundation이
  texture와 outline을 소유하도록 했다. 계획 탭의 별도 `ColoredBox`와 foreground border
  painter를 제거하고 clipped child에는 공용 `StudentBondStatus(inverted: true)`만 둔다.
- geometry/widget test가 Container 8·3의 left 일치, 삼각형 크기 보존, texture 활성화,
  bond host 내부의 단일 gauge `CustomPaint`와 추가 `ColoredBox` 부재를 고정한다.
- 검증: 계획 요소 20 tests, 계획 요소·학생 집중 66 tests, Flutter 전체 290 tests
  (`--concurrency=1`), `flutter analyze`, Windows release build 통과. 2560×1392 widget raster에서 좌측 rail 연결,
  학생 탭 방식 texture·track·progress gauge 합성, 성작 패널과의 비중첩을 확인했다.
- 다음 작업: 사용자가 최신 Windows build에서 좌측 rail 연결과 학생 탭 방식의 내부 게이지를
  실화면 확인한다.

### 2026-08-02 계획 인연 삼각형 스킬 rail·좌향 게이지 보정

- 상태: `구현·전체 자동 검증·Windows release 빌드 완료·사용자 실화면 확인 대기`
- Container 8의 폭·높이는 유지하고 left placement만 Container 5 스킬 패널과 같은 값으로
  옮겼다. 이전 Container 3 기준은 사용자 실화면 검수에 따라 폐기했다.
- 학생 탭의 우향 삼각형용 gauge painter 전체를 180도 회전하던 합성을 제거했다. 계획 화면은
  Studio spec 자체가 이미 좌향이므로 실제 rounded outer path의 상단 span에서 숫자 영역을,
  그 아래 남은 영역에서 gauge host를 직접 계산한다. 진행량은 회전 결과와 같은 위→아래
  방향으로 채운다.
- 검증: 계획 요소·학생 집중 66 tests, Flutter 전체 290 tests (`--concurrency=1`),
  `flutter analyze`, Windows release build 통과. geometry test가 Container 8·5의 실제 왼쪽
  변 일치, 좌향 path 기반 상단 rank와 하단 gauge 분리를 고정한다.
- 다음 작업: 사용자가 최신 Windows build에서 스킬 패널 좌측 정렬과 내부 게이지를 실화면 확인한다.

### 2026-08-02 계획 Container 2 반간격 확장·학원 로고 안전 영역

- 상태: `구현·전체 자동 검증·Windows release 빌드 완료·사용자 실화면 확인 대기`
- Container 2의 우측 rail은 유지하고 좌측 경계를 Studio projection 기준 12px 왼쪽으로
  확장해, 2560×1392에서 초상과의 평행 사선 간격을 24px에서 정확히 12px로 줄였다.
- `StudentLevelStatus`의 70:30 Row를 실제 80도 split path 기반 두 안전 영역으로 교체했다.
  레벨 영역은 구분선 하단 교점까지, 학원 영역은 상단 교점부터 시작하므로 두 content가
  사선을 침범하지 않는다. 학원 로고의 5px 하향 transform은 13px top padding으로 흡수해
  하단 clip을 없애고 `BoxFit.contain`을 유지했다. 좁은 학생 탭 indicator에서는 `LEVEL`
  label도 한 줄 `FittedBox(scaleDown)`으로 축소해 안전 영역 축소에 따른 세로 overflow를 막았다.
- 검증: 계획 요소·학생 집중 66 tests, 학생 page 포함 관련 75 tests, Flutter 전체 290 tests
  (`--concurrency=1`), `flutter analyze`, Windows release build 통과. geometry/widget test가
  12px 사선 간격, 80도 split, 두 안전 영역의 비중첩, 학원 로고 bounds의 학원 영역 내부
  포함과 좁은 viewport의 overflow 부재를 고정한다.
- 다음 작업: 사용자가 최신 Windows build에서 넓어진 Container 2와 학원 로고를 실화면 확인한다.

### 2026-08-02 계획 Feature 2 학원 영역 제거

- 상태: `구현·전체 자동 검증·Windows release 빌드 완료·사용자 실화면 확인 대기`
- 계획 화면의 `StudentLevelStatus`에만 `showSchool: false`를 적용했다. Feature 2와 Container 2의
  위치·폭·높이는 유지하고, 내부 학원 배경·80도 구분선·학원 로고는 모두 렌더링하지 않는다.
  레벨 배경과 content가 기존 Feature 2 전체 영역을 사용한다.
- 공용 위젯의 기본값은 `showSchool: true`라서 학생 탭의 레벨/학원 인디케이터와 학교 로고는
  그대로 유지한다.
- 검증: 계획 요소·학생 Studio·학생 page 관련 75 tests, Flutter 전체 290 tests
  (`--concurrency=1`), `flutter analyze`, Windows release build 통과. 계획 화면의 level-only
  surface, split·school region·logo 부재와 학생 탭의 기존 split·logo 존재를 함께 고정한다.
- 다음 작업: 사용자가 최신 Windows build에서 Feature 2가 레벨 전용 패널로 보이는지 확인한다.

### 2026-08-02 계획 요소 제작 화면 기록·프리셋 관리 인계

- 상태: `문서화·다음 세션 인계 완료`
- 계획 요소 제작 화면의 Section 3·5·6·7 역할, 단계·프리셋 적용 계약, 학생 상태 카드의 최종
  geometry와 painter ownership, Container 2·8 보정, 공용 학생 위젯 회귀, Studio parity와
  raster probe 시행착오를
  [`plan-element-builder-lessons-2026-08-02.md`](../design/plan-element-builder-lessons-2026-08-02.md)에
  장기 기록했다.
- 다음 프리셋 관리 탭 세션의 source of truth, 현재 인메모리 `PlanElementPreset` 경계,
  Section 5 loader semantics, 확정된 제품 결정, 미결정 scope·lifecycle 질문, 권장 vertical
  slice와 검증 gate를
  [`preset-management-next-session-handoff-2026-08-02.md`](../../docs/migration/p2-planning-screen/preset-management-next-session-handoff-2026-08-02.md)에
  기록했다. 2026-07-31 handoff는 새 문서로 승계 표시했다.
- 현재 구현 기준선은 관련 75 tests, Flutter 전체 290 tests (`--concurrency=1`),
  `flutter analyze`, Windows release build, `codealmanac validate`, `git diff --check` 통과다.
- 다음 행동: 새 세션에서 관리 탭의 위치, 첫 slice 범위, preset scope, 내장 preset 정책,
  관리 action과 dirty 이동 정책을 사용자에게 확인한 뒤 구현을 시작한다.

### 2026-08-03 계획 단계 카드 편집 표시·MAX·장비 구조 수정

- 상태: `구현·전체 자동 검증·Windows release 빌드 완료·사용자 실화면 확인 대기`
- 학생·전용무기·인연·스킬 숫자를 인디케이터 스킬 숫자의 80%(25.2px)로 키우고
  불필요한 `Lv`, `R`, 스킬 prefix를 제거했다. `−`/`+`는 16.5px 텍스트로 바꾸고 각
  편집기에 계약 상한을 즉시 적용하는 `MAX` 배지를 추가했다.
- 장비 영역은 티어·아이콘·레벨·MAX의 4열 인디케이터형 편집기로 교체했다.
  아이콘은 인디케이터 비율의 70%(0.672), 레벨 텍스트는 120%(16.2px)를 사용하며
  슬롯 `MAX`는 티어와 레벨을 둘 다 상한으로 올린다.
- 추가 능력치는 `HP/ATK/HEAL`, 13.5px로 통일했다. 스킬·능력치는 단일 행 균등
  배치로 바꿔 wrap 클립을 막았다.
- 첫 clip 보정의 49-row 카드는 실화면에서 빈 세로 공간이 과도했다. 제목 padding,
  제목-컨트롤 gap, ± hit box, MAX 배지 padding을 축소하고 최종 외곽을 34-row로
  줄였다. 레벨·전용무기·인연·스킬은 4-row, 장비는 7-row, 능력치·심상개화는
  3-row를 사용한다. typed Studio projection과 release JSON을 같이 갱신했다.
- 모든 패널을 감싸기 위해 잠시 사용한 convex hull 외곽은 불규칙한 다각형이 되므로
  제거했다. 패널을 공통 80도 rail 안으로 재배치하고 최외곽을 하나의 정확한 80도
  평행사변형으로 구성했다. Section 6 내부 폭도 고정 `520px` 높이 추정을 제거하고
  Studio `width`를 수평 rail 길이로 해석한다. Section 높이의 사선 이동량을 중복
  차감하지 않고 카드 종횡비로 bounding box를 역산해, 실제 우측 사선까지 좌우
  rail에 8px만 남기는 최대 폭을 사용한다.
- Section 6 단계 목록을 사선 스크롤 구조로 교체했다. 각 카드는 scroll offset과
  viewport Y에 따라 80도 rail을 따라 수평 이동하며, 기본 scrollbar 대신 우측 사선
  track·handle과 scroll range 기반 상하 fog를 표시한다.
- 계획-메인의 페이즈 표시 Section을 기준으로 Section 6 안에 별도 80도 외곽 컨테이너를
  추가했다. 양쪽 80도 rail을 법선 거리 12px만큼 안쪽으로 이동하고 Section path와
  교차하며, 같은 삼각 텍스처와 0.9px outline을 사용한다. 목록·fog·scrollbar만 새
  컨테이너 안에 넣고 하단 버튼은 밖에 유지하며, 버튼 영역 62px와 컨테이너-버튼
  12px 간격을 보존한다. 컨테이너와 프리셋 카드 사이도 법선 12px를 유지하고
  scrollbar reserve 14px를 별도로 둔다.
- 프리셋 카드는 높이를 유지한 채 가로만 95%로 줄였다. 상단 학생·전용무기·인연을
  1행 3열로 바꾸고 인연의 `*`를 제거했으며, 성작은 host fill·outline을 투명화해
  내부 segment만 표시한다. 상단 3열 사이와 모든 행의 좌우 80도 rail, 상·하단 및
  `상단 3열 → 성작 → 스킬 → 장비 → 추가 능력치 → 심상개화` 행 사이는 24px을
  유지한다. 현재 높이는 기존 4:1:4:7:3:3 비율로 남은 공간을 채우는 중간 계약이며
  후속 단계에서 패널 높이 조정 후 카드 content wrapping을 적용할 예정이다.
- 검증: `plan_element_builder_test.dart` 27 tests, Flutter 전체 297 tests
  (`--concurrency=1`), `flutter analyze`, Windows release build, `codealmanac validate`,
  `git diff --check` 통과. 숫자·라벨·배지·장비 아이콘 비율, MAX 상한 적용,
  각 편집 배지의 element bounds 내 포함, 외곽의 패널 containment·정확한 80도 평행사변형,
  Section 6 좌우 8px rail과 최대 카드 폭, scroll offset에 따른 80도 수평 이동과
  사선 scrollbar·fog 존재, 새 외곽 컨테이너와 프리셋 카드의 좌우 법선 12px,
  Section path containment·84px 하단 버튼 영역 분리, 카드 95% 가로 scaling·상단
  1행 3열·내부 24px 간격·성작 surface 투명·인연 `*` 제거를 새 회귀 test로 고정했다.
- 다음 행동: 사용자가 최신 실화면에서 숫자 체감 크기, 장비 아이콘, 배지 클립
  부재를 확인한다.

### 2026-08-03 preset panel height and card-centering pass

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- The top level/weapon/bond row now uses 50% of its previous runtime height. Skill
  and equipment use 60%, additional stats use 80%, while the star and mind-growth
  rows remain unchanged. Exact 24px inter-panel spacing is retained.
- The three top-row steppers share a centered control area beneath their titles.
- The 95%-width preset card is centered within the diagonal content rail after the
  scrollbar reserve is removed, giving equal horizontal residual margins.
- The outer card height remains unchanged by design; the newly freed vertical space
  is reserved for the later wrapping pass requested by the user.
- Focused `plan_element_builder_test.dart`: 28 tests passed, including row-scale,
  24px-gap, rail-centering, and top-stepper-centering regressions.
- Full Flutter suite: 298 tests passed with `--concurrency=1`. `flutter analyze`,
  Windows release build, `codealmanac validate`, and `git diff --check` passed.
### 2026-08-03 preset diagonal-scroll deletion correction

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Reproduced the add-stage, scroll-to-bottom, delete-selected-stage sequence. During
  the first shortened-list rebuild, the old controller offset exceeded the new
  content extent and incorrectly added excess X displacement to the 80-degree card
  rail.
- Card geometry now clamps the raw offset against the newly calculated content
  extent immediately. A guarded post-frame correction then synchronizes the actual
  controller position to its updated scroll metrics.
- Focused `plan_element_builder_test.dart`: 30 tests passed, including pure stale
  offset clamping and the complete add/scroll/delete first-card-rail regression.
- Full Flutter suite: 300 tests passed with `--concurrency=1`. `flutter analyze`,
  Windows release build, `codealmanac validate`, and `git diff --check` passed.
### 2026-08-03 equipment clearance and preset wrapping pass

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Equipment height now uses 0.63 of the original source row, exactly 105% of the
  previous 0.60 result. This adds clearance between its MAX badges and lower edge.
- The preset envelope is no longer held at the former 36-grid height. It wraps the
  preserved inner row heights and leaves exactly 24px between the mind-growth panel
  and the card bottom, matching the other normal panel gaps.
- The saved Studio projection uses a 28x27 wrapped outer element while retaining the
  28x36 pre-wrap reference solely for established inner sizing.
- Diagonal card-width solving now accounts for the wrapped height, preserving equal
  horizontal rail margins and the scrollbar reserve.
- Focused `plan_element_builder_test.dart`: 30 tests passed. Geometry regressions
  cover the equipment 105% ratio, exact bottom 24px gap, envelope containment, and
  the shortened-card 3-to-2-to-1 deletion scroll correction.
- Full Flutter suite: 300 tests passed with `--concurrency=1`. `flutter analyze`,
  Windows release build, `codealmanac validate`, and `git diff --check` passed.
### 2026-08-03 equipment MAX explicit bottom clearance

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Each of the three regular equipment slots now reserves an explicit 6px spacer
  below its MAX badge. The inset is independent of the flexible icon region and
  therefore survives panel-height and content changes.
- Focused `plan_element_builder_test.dart`: 31 tests passed. A rendered-geometry
  regression requires every regular equipment MAX badge to remain at least 6px
  above the equipment panel's lower edge.
- Full Flutter suite: 301 tests passed with `--concurrency=1`. `flutter analyze`,
  Windows release build, `codealmanac validate`, and `git diff --check` passed.
### 2026-08-03 preset flow triangles, right-list expansion, and motion

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Preset cards now render the same pink downward flow triangle used between
  plan-main phase items. Triangle hosts share the diagonal card rail and scroll
  offset, with exactly one indicator per adjacent card pair.
- The right section's phase-editor launch button is temporarily absent. Its list now
  spans the section between 14px left/right insets instead of retaining the former
  64% button-reserved width.
- Section motion contracts are student indicator 0/180, preset selection 0/180,
  preset-card editor 80/260, and right section 180/0. A synchronized 360ms entrance
  controller replays on activation and reverses on parent deactivation.
- Focused `plan_element_builder_test.dart`: 33 tests passed, covering motion
  directions and hosts, two flow triangles for three cards, full-width right-list
  geometry, hidden launch action, and prior scroll/card regressions.
- Full Flutter suite: 303 tests passed with `--concurrency=1`. `flutter analyze`,
  Windows release build, `codealmanac validate`, and `git diff --check` passed.
### 2026-08-03 flow bottom-center, compact gaps, right diagonal viewport

- Status: implementation and full automated validation complete; visual confirmation pending.
- Plan-main phase and preset flow triangles now target the preceding
  parallelogram's bottom-edge midpoint rather than its bounding-box center.
- Preset vertical row gaps are 12px. The card top/bottom edge clearances and the
  three-column horizontal gaps remain 24px; established panel heights are unchanged.
- Right `container-15` expands from 61.12% to 90% parent width and owns a clipped
  parallelogram viewport. Unassigned rows use a 66px/10px diagonal scroll stack,
  80-degree X displacement, viewport fog, and a matching diagonal scrollbar.
- Focused validation: 34 plan-element tests and 36 planning-page tests passed.
  Regressions cover both flow centers, half vertical gaps with preserved edge/column
  gaps, saved Studio parity, right-row rail displacement, and visible row/name
  centers inside the new container path.
- Full validation: all 304 Flutter tests passed with `--concurrency=1`.
  `flutter analyze`, Windows release build, `codealmanac validate`, and
  `git diff --check` passed.

### 2026-08-03 phase-editor-shaped preset right panel

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Replaced the right panel's Studio-container-derived viewport with responsive
  list/action paths derived from the actual right trapezoid, matching the phase
  editor's right-side structure and 80-degree rail.
- Removed the visible right-list header/count row. Restored only the bottom-right
  phase-editor launch button, preserving its disabled-until-elements-exist state.
- Unassigned items now render a square-backed student portrait followed by the
  student display name and editable stage name. Rename-on-submit/focus-loss remains.
- Focused validation: 35 plan-element tests and 36 planning-page tests passed.
  Regressions cover list/button path containment, no header, media/name containment,
  rename commits, disabled/enabled launch behavior, and the existing scroll rail.
- Full validation: all 305 Flutter tests passed with `--concurrency=1`.
  `flutter analyze`, Windows release build, `codealmanac validate`, and
  `git diff --check` passed.

### 2026-08-03 preset blocked reason and control/row visual correction

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Shortened the preset list viewport by 36px and inserted a dedicated 30px reason
  strip above the controls. Confirmation is disabled while no target exceeds the
  current state, and the reason is displayed in that strip.
- Replaced all four rectangular bottom buttons with responsive rounded 80-degree
  parallelogram controls using shared paint, clip, ink, semantics, and hit geometry.
- Repainted the phase-editor launch action with a muted purple BA triangle texture;
  its disabled lock state retains the texture with only a light darkening layer.
- Rebuilt unassigned row silhouettes from each row's actual size, removing the
  non-uniformly scaled fixed path. Row and container colors now match the existing
  phase-editor source-list reference.
- Focused `plan_element_builder_test.dart`: 38 tests passed. Regressions cover the
  reserved message strip, disabled/enabled confirmation, four control surfaces,
  exact 80-degree row/button paths, and blue/purple texture palette contracts.
- Full validation: all 308 Flutter tests passed with `--concurrency=1`.
  `flutter analyze`, Windows release build, `codealmanac validate`, and
  `git diff --check` passed.

### 2026-08-03 preset right-list color parity and phase completion route

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Set the preset right-list container to the plan-main phase container's exact blue
  triangle-texture contract, including deterministic seed `404`.
- Phase completion now closes the phase editor and element builder together, clears
  the stale selected-student seed, and reveals plan main rather than reopening the
  student element configuration surface.
- Focused `plan_element_builder_test.dart`: 39 tests passed. The new end-to-end widget
  regression confirms preset creation, phase assignment, completion, builder exit,
  and the restored plan-main phase list.
- Full validation: all 309 Flutter tests passed with `--concurrency=1`.
  `flutter analyze`, Windows release build, `codealmanac validate`, and
  `git diff --check` passed.

### 2026-08-03 builder exit motion and unassigned-stage actions

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Phase-editor launch and plan-menu return now wait for the element builder's complete
  360ms four-section outro before changing the parent route.
- Added three stacked, section-clipped 80-degree buttons to the right panel: selected
  stage deletion, plan-menu return, and phase-editor launch. Unassigned rows now have
  single selection with a visible highlight; deletion is disabled without selection.
- Deletion removes only the selected unassigned plan element and its matching draft.
  Returning closes the builder while preserving all remaining confirmed elements.
- Focused regressions cover action-path containment/order, delayed exit callbacks,
  selection-gated deletion, and end-to-end preservation of remaining elements after
  returning to plan main.
- Full validation: all 313 Flutter tests passed with `--concurrency=1`.
  `flutter analyze`, Windows release build, `codealmanac validate`, and
  `git diff --check` passed.

### 2026-08-04 preset-builder right-list texture and width

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- The right list uses the phase-editor source container's exact blue triangle texture,
  including deterministic seed `8404` and the 1px outline contract.
- Section 7 remains right-aligned but changes from grid `x=68, width=28` to
  `x=76, width=20`. Its responsive list is 70% of the former canonical width.
- All three right action buttons retain their previous width, height, vertical gaps,
  and right-edge alignment. Geometry regressions compare them against the legacy
  section while list-row containment and editing remain covered.
- Focused `plan_element_builder_test.dart`: 44 tests passed.
- Full validation: all 314 Flutter tests passed with `--concurrency=1`.
  `flutter analyze`, Windows release build, `codealmanac validate`, and
  `git diff --check` passed.

### 2026-08-04 preset-builder right-list texture visibility correction

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Corrected the right-list foundation from a full-section paint canvas to the list
  path's local bounds, so the shared texture's lighting, vignette, and triangle grid
  are evaluated inside the visible container.
- Added the phase-editor reference's translucent blue base layer before the clipped
  triangle texture. The shared local path still owns fill, texture clip, and outline.
- The widget regression now requires the foundation and clipped list viewport to
  occupy exactly the same rendered rectangle.
- Focused `plan_element_builder_test.dart`: 44 tests passed. Full validation: all
  314 Flutter tests passed with `--concurrency=1`; `flutter analyze`, Windows release
  build, `codealmanac validate`, and `git diff --check` passed.

### 2026-08-04 preset-builder session retrospective

- Status: documentation complete; implementation status is unchanged.
- Consolidated the session's repeated layout, scroll, texture, animation, routing,
  identity, and validation failures into the plan-element-builder design almanac.
- Each entry records the visible symptom, rejected or insufficient approach, root
  cause, final invariant, and required regression coverage so future work does not
  repeat the same pixel-only corrections.
- Artifact: `almanac/design/plan-element-builder-lessons-2026-08-02.md`, section
  `2026-08-04 session retrospective: failed approaches and durable rules`.

### 2026-08-04 plan student-selector panel surfaces and motion

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Replaced the grid and filter panels' outlined template surfaces with the same
  outline-free translucent fill and lifted path shadow contract used by plan Section
  1. Their nested grid/filter component outlines remain intact.
- Gave the grid and filter panels independent 360ms directional controllers. Both
  enter at 80 degrees and exit on the opposite 260-degree trajectory.
- Propagated the plan tab's active state into the selector so both panels reverse
  while the tab changes. Closing the selector now keeps it mounted for the complete
  outro before restoring the other plan sections.
- Focused `planning_page_test.dart`: 40 tests passed. Regressions cover the
  outline-free shadow surface, both motion specifications, and non-zero 260-degree
  exit movement after plan-tab deactivation.
- Full validation: all 318 Flutter tests passed with `--concurrency=1`.
  `flutter analyze`, Windows release build, `codealmanac validate`, and
  `git diff --check` passed.

### 2026-08-04 selector-card exit handoff and builder bond fill direction

- Status: implementation and full automated validation complete; user visual
  confirmation pending.
- Selecting a student portrait no longer unmounts the selector immediately. It marks
  the selector inactive, lets both grid and filter panels complete their 360ms
  260-degree outro, and only then mounts the plan-element builder with the selected
  seed. Repeated portrait callbacks are ignored during the handoff.
- Separated the bond gauge's triangle-layout inversion from its fill direction.
  `StudentBondStatus` now exposes `fillFromBottom`; the plan-element builder keeps its
  inverted triangle placement while explicitly filling the gauge from bottom to top.
- Focused planning and element-builder suites passed 84 tests. Regressions verify
  that both selector panels remain mounted and move left/down at half outro, the
  builder is absent until exit completion, and 40% bond progress occupies the bottom
  40% of the gauge bounds.
- Full validation: all 318 Flutter tests passed with `--concurrency=1`.
  `flutter analyze`, Windows release build, `codealmanac validate`, and
  `git diff --check` passed.
- The complete requirement decisions, screenshot feedback, insufficient approaches,
  root causes, final invariants, and regression rules for this selector iteration are
  consolidated in
  `almanac/design/plan-student-selector-lessons-2026-08-04.md`.

### 2026-08-04 plan selector filter width reduction

- Status: implementation and full automated verification complete; user visual
  confirmation pending.
- Reduced only the plan selector filter panel's width to 50% of its previous
  available span. Its left edge remains fixed, preserving the exact 24px visible gap
  from the student grid; height and internal vertical structure are unchanged.
- The planning-page regression preserves the left-edge gap and verifies that the
  rendered filter width is exactly half of the former `left -> 98.5% viewport` span.
- Full validation: all 318 Flutter tests passed with `--concurrency=1`.
  `flutter analyze`, Windows release build, `codealmanac validate`, and
  `git diff --check` passed.

### 2026-08-04 selector tab-return isolation and reusable editable preset card

- Status: implementation and full automated verification complete; user visual
  confirmation pending.
- Plan-tab reactivation is now route-aware. While the student selector is open,
  Section 1 and the selector panels re-enter, but plan-main Sections 2-5 remain at
  controller value 0 and cannot overlap the selector.
- Promoted the center diagonal stage-list item from private
  `_PlanPresetElementCard` to public `PlanPresetElementCard`. External hosts can
  supply stage/current values and retain the complete selection and edit callback
  contract without mounting the builder or its scroll list.
- Focused planning and element-builder suites passed 85 tests. Coverage performs a
  complete selector tab-away/tab-return cycle and directly hosts the public editable
  card outside `PlanElementBuilder`.
- Full validation: all 319 Flutter tests passed with `--concurrency=1`.
  `flutter analyze`, Windows release build, `codealmanac validate`, and
  `git diff --check` passed.

### 2026-08-04 student range-condition companion sections

- Status: implementation and full automated verification complete; user visual confirmation pending.
- Student and plan filters now open with an adjacent same-height condition section. It contains two reusable editable `PlanPresetElementCard` widgets, representing inclusive lower and upper bounds, separated by a vertical swap icon.
- Each card has a top-left enable checkbox and a small top-right value reset. Closing and reopening the student filter resets both conditions; closing and reopening the plan selector recreates initial condition state.
- Preserved the 24px visible diagonal-edge gap. The plan selector's condition panel shares the filter controller, so grid, filter, and condition all use intro 80 / outro 260 and exit together during tab changes and student-selection handoff.
- A direct-width compression attempt caused internal card row overflow. The final layout renders each card at a stable 680px design width and proportionally fits it into one of two non-scrolling slots. Header controls use path-derived safe insets so they remain visible and hit-testable inside the diagonal clip.
- New focused coverage verifies inclusive range semantics, two-card/no-scroll layout, editing and per-card reset, 24px companion geometry, student-filter close/reopen reset, plan-selector reopen reset, and three-panel outro behavior.
- Full validation: all 323 Flutter tests passed with `--concurrency=1`; `flutter analyze`, Windows release build, `codealmanac validate`, and `git diff --check` passed.
- Screenshot follow-up replaced the condition cards' header overlay geometry with a dedicated diagonal projection. It reserves 40px above the first value row and recovers that space by reducing the skill and additional-stat rows by 20px each, preserving the card's total height, gaps, and 80-degree rails. Focused 50-test verification and the full 324-test Flutter suite passed; `flutter analyze` and the Windows release build also passed.
- A second screenshot showed that internal row geometry was fixed while both card hosts still used rectangular slot centers. The host geometry now derives each card's uniform scale and X position from the parent bilateral path at that card's actual top and bottom; the lower card advances left by `ΔY / tan(80°)`, and the center arrow uses its own Y-specific path interval. A reusable parent/child diagonal-layout guide records boundary, normal-gap, scaling, clipping, hit-test, rounded-corner, and responsive-test requirements. Focused 45-test verification and the full 325-test Flutter suite passed; `flutter analyze` and the Windows release build also passed.
- Documentation follow-up adds a mandatory pre-implementation procedure for future diagonal sections: identify the failing hierarchy, write the parent/child geometry contract, select rectangular reflow or parallel-child fitting, unify paint/clip/hit paths, add pure and rendered regressions, and reject clip-only completion criteria.
- The condition section's painted foundation now wraps the two cards' parallel rail envelope instead of filling the full companion host. It preserves 12px top/bottom and normal rail margins, the card-to-arrow gaps, and the existing full-height left-rail anchor that owns the 24px filter seam. The outer host remains unchanged for sibling layout and transition contracts; only the visible foundation and clip shrink. Focused condition/planning verification passed 46 tests. Full validation passed all 326 Flutter tests, `flutter analyze`, Windows release build, `codealmanac validate`, and `git diff --check`.
- The student-tab filter section now keeps its existing left rail and height while reducing its current horizontal edge length by another 50%, from one half to one quarter of the original Section 2 edge. Its inner container and reset control remain inside the narrower path, and the range-condition companion continues to derive its 24px seam from the filter's new visible right rail. Focused student/condition verification passed 52 tests. Full validation passed all 326 Flutter tests, `flutter analyze`, Windows release build, `codealmanac validate`, and `git diff --check`.

### 2026-08-05 plan preset-management in-memory vertical slice

- Status: implementation and full automated verification complete; user visual
  confirmation pending.
- Added `프리셋 생성·관리` to plan-main Section 1. It exits the main sections and
  opens a dedicated preset-management screen, then restores the plan-main sections
  after its own outro completes.
- The left list/CRUD trapezoid uses intro 0 / outro 180. The adjacent multi-stage
  editor parallelogram uses intro 80 / outro 260 and reuses the public editable
  `PlanPresetElementCard` plus the diagonal card-list rail.
- Presets are student-independent ordered absolute targets. One preset can contain
  multiple goal cards; add, remove, reset, create, overwrite-edit, save, select, and
  delete operate in memory only. Saved presets are passed directly to the
  plan-element builder loader during the same plan-page lifetime.
- Removed the two built-in preset fixtures. v7 now starts with an empty preset list;
  repository/protocol persistence remains deferred until the v6 user-data migration.
- Returning with an unsaved draft opens a low confirmation parallelogram beside the
  editor. It uses intro 80 / outro 260 and exits only after explicit confirmation.
- Added a dedicated typed Studio projection and matching
  `section-preset-management.ba-section-studio.json`. Geometry regressions cover the
  sibling placement, compact confirmation height, requested motions, and 1280x720
  usability.
- Focused preset-management coverage passed 4 tests; planning and element-builder
  coverage passed 86 tests. Full validation passed all 330 Flutter tests with
  `--concurrency=1`; `flutter analyze`, Windows release build, and `git diff --check`
  passed.
- Screenshot follow-up aligned the editor to the exact plan-settings section geometry
  (`element-6`: x 21, y 2, width 21, height 92) and promoted/reused its four-button
  `PlanBuilderControls` path structure instead of a generic control row.
- The preset-name header now follows the student-selector filter treatment with a
  compact outlined field and prefix icon. The inner list derives its bilateral
  80-degree parallelogram from the actual Studio section path, while goal cards render
  at a stable design width and scale down inside narrow viewports.
- The unsaved-return copy is fixed to `저장하지 않은 변경사항을 버리고\n돌아갈까요?`,
  placing the requested line break immediately after `버리고`.
- The next preset-management visual pass now derives the editor's runtime X offset
  from the two facing 80-degree rails, preserving an exact 24 px normal gap between
  the left CRUD trapezoid and right editor at both 1280x720 and 2560x1392.
- The left panel now mirrors the phase-editor composition: a bilateral
  parallelogram scroll container occupies the main rail and back/create/edit/delete
  path buttons follow the remaining left wedge. Preset rows recompute their X/width
  from viewport Y while scrolling, and all overlapping rectangular hosts use
  path-aware hit testing so transparent wedges do not intercept adjacent controls.
- The plan-element builder's Section 5 preset loader now also owns a dedicated
  bilateral 80-degree container below its title. Loader rows preserve vertical
  scrolling while recomputing X from viewport Y, and reuse the diagonal scrollbar
  and top/bottom fog contract from the stage editor. Geometry coverage verifies that
  the container remains inside Section 5 and both row rails satisfy
  `deltaX = -deltaY / tan(80 degrees)` during scrolling.
- Focused element-builder validation passed all 48 tests. Full validation passed all
  332 Flutter tests with `--concurrency=1`; `flutter analyze` and the Windows release
  build passed.

### 2026-08-05 shared planning document and v6 account import vertical slice

- Status: items 1-4 implementation and automated verification complete; scenario
  persistence and the scenario-specific tab controls remain the next slice.
- Added one versioned `PlanningDocument` model for both `plan` and `scenario` kinds.
  Documents contain ordered phases and ordered student stages with a complete target
  snapshot. The backend rejects duplicate IDs, invalid ranges, and later stages that
  regress the same student.
- Added `planning.document.calculate`. It advances a virtual student state after each
  stage, reports stage/phase/overall cost and consumption, rolls inventory forward
  between phases, and identifies each resource's first bottleneck plus affected stage
  IDs. Unknown inventory remains explicitly unknown in the result UI.
- The production plan page now loads the selected repository profile instead of dummy
  results. Saved goals become one stage per student, in saved order, under one
  `v6 가져온 계획` phase; builder/phase edits recalculate the same document model.
- Added a read-only v6 account preview/import boundary. It copies account name/avatar,
  confirmed student state, inventory, and growth goals into an independent v7 profile.
  It does not import scanner candidates, tactical data, or logs and never writes to v6.
  A name collision creates `계정명 (v6 가져오기)` and then a numbered variant.
- Verification: all 127 Python tests and all 333 Flutter tests passed.
  `flutter analyze` and the Windows release build passed.

### 2026-08-05 scenario pre-GUI persistence and comparison slice

- Status: all work that does not require the scenario screen design is implemented;
  plan-main buttons, scenario screen geometry, transitions, multi-select controls, and
  bulk-apply panel remain pending GUI design.
- Added a profile-scoped scenario repository under `scenarios/{profile_id}.json`.
  It has an independent collection revision, per-scenario revision, strict
  idempotency, atomic writes, create/get/list/update/delete/duplicate operations, and
  profile-deletion cleanup. Scenario mutations do not alter the active plan file or
  profile revision.
- Scenario records persist name, description, base profile revision, timestamps, and
  a canonical `PlanningDocument` whose kind must be `scenario`. A future profile
  revision is rejected while an older revision remains representable as stale.
- Added `planning.scenario.compare`. Both documents are recalculated against the same
  current-student and inventory inputs. The response contains both normal projections
  plus neutral trade-off data for credits, resource requirements and shortages,
  student target differences, and first bottlenecks; it never declares a winner.
- Added versioned scenario repository and comparison JSON Schemas, Python application
  dispatch, typed Flutter records/results/services, strict wire validation, and a real
  Dart-to-Python lifecycle/comparison E2E test.
- Verification: all 135 Python tests and all 335 Flutter tests passed.
  `flutter analyze`, the Windows release build, and `git diff --check` passed.

### 2026-08-05 scenario temporary entry, list, and creation UI slice

- Status: temporary entry controls, scenario list workspace, and non-bulk
  creation flow are implemented and fully verified. Bulk apply, comparison UI,
  and final button styling remain pending by explicit user decision.
- Added three temporary controls below the existing Plan Section 1 actions.
  Scenario list and scenario creation are active; scenario comparison remains
  visibly disabled until its screen is implemented.
- Opening the scenario list keeps Section 1 in place, sends Sections 2-5 through
  their existing outros, and introduces one bilateral 80-degree parallelogram
  workspace with intro 80 / outro 260. Its rows recompute their horizontal
  position from viewport Y and scroll offset and reuse the plan diagonal
  scrollbar contract. Empty, loading, retry, stale-profile, selection, and
  refresh states are explicit.
- Scenario creation reuses the existing student selector, element builder, and
  phase editor without a bulk-apply panel. Completing phases opens a temporary
  standard name/description dialog, persists a scenario-kind planning document,
  and restores the active repository plan without mutating it.
- MockAppService now implements the scenario repository boundary so the default
  development UI and widget tests exercise the same typed CRUD interface as the
  real Python process.
- Verification: all 337 Flutter tests passed; the focused planning/builder/
  scenario suite passed 91 tests; `flutter analyze`, the Windows release build,
  and `git diff --check` passed.

### 2026-08-05 v6 student-growth rule parity

- Status: implementation and automated verification complete.
- Centralized the v6 equipment tier level caps (`T0=0`, `T1=10`, `T2=20`,
  `T3=30`, `T4=40`, `T5=45`, `T6=50`, `T7=55`, `T8=60`, `T9=65`,
  `T10=70`) and unique-weapon star level caps (`0=0`, `1=30`, `2=40`,
  `3=50`, `4=60`) as shared frontend rules with an equivalent backend
  semantic validator.
- Plan element editing, preset editing/loading/saving, reopened drafts, current
  student baselines, and legacy goal-to-document projection now normalize coupled
  values. A level-only change raises the required tier/star; an explicitly selected
  tier/star clamps its dependent level. Any weapon target also raises the student
  target to 5 stars, and favorite equipment remains disabled for unsupported
  students.
- Planning-document decoding validates the same coupled rules in both Dart and
  Python, so malformed persisted or external scenario/plan documents cannot reach
  calculation even if they bypass the UI.
- Regression coverage includes the reported `T9 / level 70` case, sparse versus
  explicit presets, weapon/student-star coupling, favorite-equipment support, exact
  boundaries, legacy goal projection, and backend rejection.
- The shared student/weapon star target strip now treats a tap on any active
  segment as removal from that segment onward (`tapped value - 1`), without
  crossing the current/previous-stage floor. This behavior is shared by the
  plan-element builder, preset manager, and the lower/upper range-condition
  filter cards. The range cards additionally clamp callback values to their
  field contracts. Both catalog-filter hosts retain their existing tap-again
  removal behavior; all paths are now covered explicitly in tests.
- Preset normalization is now game-state strict beyond simple numeric ranges:
  skill 2/3 follow their 2-star/3-star unlocks, equipment slots 2/3 follow
  student levels 10/20, ability release requires level 90 plus 5 stars,
  relationship rank follows the student-star cap, and favorite-item T1/T2
  follows bond ranks 20/25. Editing a dependent field raises its prerequisite;
  explicitly lowering a prerequisite clears or clamps every incompatible
  dependent field. The same normalization runs in the builder, preset manager,
  lower/upper condition cards, legacy goal projection, and reopened drafts.
- Python planning-document validation independently rejects all of these invalid
  combinations so persisted scenarios and external payloads cannot bypass UI
  normalization. Locked skill and equipment states are represented as zero in
  canonical fixtures.
- Verification: all 139 Python tests and all 354 Flutter tests passed;
  `flutter analyze` and the Windows release build passed.

### 2026-08-07 plan and scenario multi-student creation

- Status: implementation and full automated verification complete; user visual
  review pending.
- The shared plan/scenario student selector now toggles any number of student
  cards instead of navigating on the first card press. Selection order is the
  card-click order, tapping an active card removes it, and planned students
  remain selectable so their saved stages can be edited in the same workflow.
- Added a compact right-attached trapezoid showing the selected count and a
  trapezoid confirmation action. Its foundation, clip, ink, semantics, and hit
  geometry derive from the same responsive path, and it shares the selector's
  intro 80 / outro 260 motion.
- Visual follow-up anchors this compact trapezoid to the selector workspace's
  bottom-right corner. Its confirmation action now imports the exact shared
  title primary-action texture contract: the soft title-pink palette, seed
  `2077`, triangle size `105`, and the same tessellation/light/fog parameters.
  The title button and selector button consume one public constant so their
  colors and pattern cannot drift independently.
- Confirmation hands an ordered seed queue to the existing element builder.
  Confirming one student's stages automatically opens the next selected
  student; confirming the final student leaves that builder visible so phase
  configuration remains available.
- The builder's right unassigned-stage section now has a fourth stacked action,
  `선택한 학생 계획 수정`. It is enabled by the existing row selection and
  reopens every saved draft stage for that row's student after the builder
  outro. Repository-loaded and newly selected students share the same seed
  lookup, so the action also works for plans imported from account data.
- Focused verification: `flutter analyze` passed and the planning-page plus
  element-builder suites passed all 94 tests. Coverage includes toggle removal,
  multi-card selection highlighting, click-order traversal, last-student
  retention, existing-stage reopening, four-button diagonal geometry, scenario
  creation reuse, and all four selector-panel motion paths.
- Full verification: the visual follow-up's planning-page and title-page suites
  passed all 61 tests, and all 356 Flutter tests passed. `flutter analyze` and
  the Windows release build passed. The preceding multi-student baseline also
  passed all 139 Python tests; `codealmanac validate` and `git diff --check`
  passed after the follow-up documentation update.
- Artifacts: `frontend/lib/ui/widgets/plan_student_selector.dart`,
  `frontend/lib/ui/widgets/student_section_layout.dart`,
  `frontend/lib/ui/widgets/plan_section_layout.dart`,
  `frontend/lib/ui/widgets/plan_element_builder.dart`,
  `frontend/test/planning_page_test.dart`, and
  `frontend/test/plan_element_builder_test.dart`.

### 2026-08-12 plan resource list runtime regressions

- Status: implementation and focused automated verification complete; user
  visual review pending.
- Calculated bottleneck cards appeared as blank gray release-mode error widgets
  because `filterPlanBottleneckDetails` rebuilt each detail without its live
  `focusStepData`. Filtering and sorting now preserve that typed step snapshot,
  while the legacy preview fallback remains unchanged.
- Phase and overall consumption lists reused an obsolete scroll offset for one
  layout frame when `충족 재화 숨기기` reduced the content extent. Their diagonal
  X projection now uses an immediately clamped effective offset and schedules a
  post-frame controller correction, matching the established plan-builder list
  fix. The bottleneck list uses the same safeguard when category filtering
  reduces its extent.
- Regression coverage verifies calculated bottleneck focus-step preservation
  and stale-offset correction for both phase and overall consumption prefixes.
  The complete planning-page suite passed all 47 tests and `flutter analyze`
  reported no issues.
- Artifacts: `frontend/lib/ui/widgets/plan_section_layout.dart` and
  `frontend/test/planning_page_test.dart`.

### 2026-08-12 scenario-creation exits and student-grid hit geometry

- Status: implementation and focused automated verification complete; user
  visual review pending.
- Opening the scenario list while the scenario-creation student selector is
  visible now marks all four selector panels inactive, waits for their shared
  260-degree outro, restores the repository plan without briefly re-entering
  Sections 2-5, and only then mounts the scenario-list workspace. The same
  handoff also covers the ordinary plan student selector. Scenario creation is
  disabled while any student-selector handoff is active, preventing a second
  draft from being initialized beneath the existing selector.
- The remaining scenario-creation exit routes were audited: selector cancel and
  selector confirmation already retain the selector until its outro completes;
  element-builder exits and phase-editor cancel/complete are child-owned outro
  callbacks; plan-tab deactivation keeps each active child mounted while its
  `active` input reverses the section controllers.
- `StudentDiagonalGrid` no longer exposes the whole rectangular cell or the
  underlying `AssetImageGrid` as duplicate tap targets. Each explicit target is
  clipped to the same fitted 252:204 rounded parallelogram used by the image and
  overlay painters, so transparent wedges do not select a card while its visible
  surface remains clickable. Regression coverage checks every card in rows 1-4
  of a four-column grid and specifically probes the fourth-column transparent
  corners.
- Follow-up testing of the fourth-column upper-right corners found that the
  painted scrollbar followed the diagonal rail but its drag target was one large
  rectangular bounding strip. That strip intercepted the upper rows before the
  cards could receive taps. The drag target now uses a 16px path-aware band
  centered on the actual 80-degree track, and card hits use the full fitted
  parallelogram without rounded-corner dead zones. The regression now taps the
  upper-right of the fourth card in each of rows 1-4 while scrolling is active.
- A second full-selector follow-up reproduced the remaining failure that the
  isolated grid test missed. The later-painted filter section's background
  `CustomPainter` accepted hits across its entire rectangular render box,
  including the transparent wedge outside its bilateral path, and that wedge
  overlapped the upper-right of column 4. The section painter now answers hit
  tests only inside the exact painted path, allowing pointer events in the
  transparent overlap to reach the grid beneath it. Coverage mounts the real
  scenario-creation selector at 2560x1392 and taps the upper-right of the
  fourth-column portrait in rows 1-4.
- Verification: the complete planning-page and student-layout suites passed all
  97 tests, and `flutter analyze` reported no issues. The Windows release bundle
  freshness check also reported that the bundle was up to date before this
  source follow-up.
- Artifacts: `frontend/lib/ui/widgets/plan_section_layout.dart`,
  `frontend/lib/ui/widgets/student_section_layout.dart`,
  `frontend/test/planning_page_test.dart`, and
  `frontend/test/student_studio_layout_test.dart`.

### 2026-08-13 scenario-list first-pass summary data

- Status: the first-pass scenario-list information design is implemented and
  focused automated verification is complete; user visual review is pending.
  The second-pass calculated credit, shortage, and bottleneck summaries remain
  intentionally pending because they require a list-level calculation contract.
- Each scenario row now displays its name, optional one-line description,
  student/phase/growth-stage counts, an explicit current-data or recalculation
  status badge, and its last-modified timestamp. The former ambiguous `요소`
  label is now `성장 단계`.
- The existing vertical scroll model, 80-degree viewport-relative row projection,
  clipped card path, selection interaction, and stale-profile comparison remain
  unchanged. Row height increased from 78 to 108 pixels to keep all first-pass
  fields inside the card's diagonal content-safe region.
- No repository or protocol change was needed: the UI consumes the existing
  `description`, `updated_at`, `base_profile_revision`, and count fields.
- Verification: all 49 planning-page tests passed, including a new current/stale
  card summary regression, and `flutter analyze` reported no issues.
- Artifacts: `frontend/lib/ui/widgets/plan_section_layout.dart` and
  `frontend/test/planning_page_test.dart`.

### 2026-08-14 scenario-list calculation and visual summaries

- Status: the second- and third-pass scenario-list summaries are implemented
  and focused automated verification is complete; user visual review is pending.
- `repository.scenario.list` now derives every row's lightweight projection in
  one backend request using the current confirmed-student and inventory state.
  The typed v1 summary carries credits, required-resource type count, known
  shortage type count, inventory completeness, first bottleneck phase, and the
  largest known shortage. A failed derived calculation becomes `null` without
  hiding or corrupting the persisted scenario record.
- Scenario summaries also carry distinct student IDs in first-stage occurrence
  order. Each row shows up to four overlapping student portraits and a `+N`
  overflow badge, while retaining the exact vertical scroll model and
  viewport-relative 80-degree row projection.
- Cards now show compact credits, known shortage count, partial-inventory state,
  first bottleneck phase, and the representative shortage with an item image
  where a packaged category mapping exists and a safe inventory fallback icon
  otherwise. Row height increased from 108 to 142 pixels to preserve the
  diagonal content-safe region.
- The mock repository, strict Dart decoder, JSON Schema, Python store and
  application wiring, backend store regression, widget regression, and real
  Dart-to-Python scenario E2E path were updated together.
- Verification: five focused Python scenario store/protocol tests passed; the
  scenario Dart-to-Python E2E and typed service tests passed; the planning-page,
  scenario-service, and planning-protocol-client run passed all 71 tests;
  `flutter analyze`, the Windows release build, JSON syntax validation,
  `codealmanac validate`, and `git diff --check` passed.
  The Python JSON Schema test remains locally unexecutable because the existing
  venv's `rpds` native DLL is denied during import; this is an environment load
  failure rather than a schema assertion failure.
- Artifacts: `backend/core/application_protocol_v1.py`,
  `backend/core/scenario_store.py`, `backend/tests/test_scenario_store.py`,
  `contracts/scenario-protocol-v1.schema.json`,
  `frontend/lib/services/mock_app_service.dart`,
  `frontend/lib/services/scenario_service.dart`,
  `frontend/lib/ui/widgets/plan_section_layout.dart`,
  `frontend/test/planning_page_test.dart`,
  `frontend/test/scenario_process_e2e_test.dart`, and
  `frontend/test/scenario_service_test.dart`.

### 2026-08-14 scenario-list parallelogram and fog correction

- Status: implementation and focused automated verification complete; user
  visual review pending.
- Scenario rows previously retained a fixed 14-pixel diagonal depth after their
  height grew to 142 pixels, producing an approximately 84.4-degree silhouette
  instead of the plan UI's standard 80-degree bilateral parallelogram. Their
  shared paint and hit-test clip now derive depth from `height / tan(80°)`.
- The scenario viewport previously painted the shared scroll fog as an inset
  rectangle. `PlanDiagonalScrollbar` now accepts an optional fog clipper, and
  the scenario list supplies the same height-derived bilateral parallelogram
  clip used by its rows. Other plan lists retain their existing fog behavior.
- Regression coverage checks the exact 80-degree depth, excludes both
  rectangular side wedges, verifies the fog path, and confirms that a real
  created scenario mounts the same clipper on both its card and fog layer.
- Verification: all 52 planning-page tests passed; `flutter analyze`, the
  Windows release build, `codealmanac validate`, and `git diff --check` passed.
- Artifacts: `frontend/lib/ui/widgets/plan_section_layout.dart` and
  `frontend/test/planning_page_test.dart`.
