# Inventory Sorting Rules

This document records the scan/display order expected by the inventory scanner.
The code source of truth is `core.inventory_profiles`, with item ID lists coming
from `core.oparts` and `core.equipment_items`.

## Storage Key

Inventory quantities are stored by `item_id` when an ID is available. Display
names are metadata only. Name keys are used only as a fallback for profiles that
do not have stable IDs yet.

## Scan Profiles

### Tech Notes

Profile ID: `tech_notes`

Order:

1. School order:
   `Hyakkiyako`, `RedWinter`, `Trinity`, `Gehenna`, `Abydos`, `Millennium`,
   `Arius`, `Shanhaijing`, `Valkyrie`, `Highlander`, `Wildhunt`.
2. For each school, tier order is `0`, `1`, `2`, `3`.
3. Final item is `Item_Icon_SkillBook_Ultimate_Piece`.

ID pattern:

```text
Item_Icon_SkillBook_{School}_{Tier}
```

### Tactical BD

Profile ID: `tactical_bd`

Order:

1. Same school order as tech notes.
2. For each school, tier order is `0`, `1`, `2`, `3`.
3. Final item is `Item_Icon_SkillBook_Ultimate_Piece`.

ID pattern:

```text
Item_Icon_Material_ExSkill_{School}_{Tier}
```

Order-hint matching for tech notes and tactical BD uses the ordered profile
cursor. Exact item IDs are preferred, but same-school candidates may be accepted
with the expected tier when the count read is confident enough. This compensates
for low icon margins and occasional tier-color contamination from the selected
slot focus border.

Grid recognition is hierarchical for both profiles. The background first
selects one of the four tier groups, then a profile-specific school-mark ROI
selects the school. Tech notes and tactical BD intentionally use different
ROIs because the BD disc and cover geometry do not align with the note card.

Tier color hinting uses the slot background color for the same zero-based tier
order in both profiles: `0` = white/gray, `1` = blue, `2` = yellow, `3` =
purple. When a new school is added in-game, update `_SCHOOL_ORDER`,
`_SCHOOL_LABELS`, generated template assets, and this document together.

`Item_Icon_SkillBook_Ultimate_Piece` is the final secret-note item for both
`tech_notes` and `tactical_bd` profiles.

The scanner can use confirmed tier colors as profile-order anchors. If a later
ordered item is confidently matched while earlier ordered items were not visible,
those skipped entries are treated as zero quantity because the game omits zero
quantity cells from these sorted material lists.

### Ooparts

Profile ID: `ooparts`

Order:

1. `OPART_DEFINITIONS` declaration order in `core.oparts`.
2. For each opart family, tier index order is `0`, `1`, `2`, `3`.
3. Then workbook items in `OPART_WB_ITEMS` order.

Current family order:

1. Nebra Disk (`Nebra`)
2. Phaistos Disc (`Phaistos`)
3. Wolfsegg Steel (`Wolfsegg`)
4. Nimrud Lens (`Nimrud`)
5. Mandrake Extract (`Mandragora`)
6. Rohonc Codex (`Rohonc`)
7. Aether Essence (`Ether`)
8. Antikythera Mechanism (`Antikythera`)
9. Voynich Manuscript (`Voynich`)
10. Crystal Haniwa (`CrystalHaniwa`)
11. Totem Pole (`TotemPole`)
12. Ancient Battery (`Baghdad`)
13. Golden Fleece (`GoldenFleece`)
14. Okiku Doll (`Kikuko`)
15. Disco Colgante (`DiscoColgante`)
16. Atlantis Medal (`AtlantisMedal`)
17. Roman Dodecahedron (`RomanDice`)
18. Quimbaya Relic (`Quimbaya`)
19. Istanbul Rocket (`Rocket`)
20. Mystery Stone / Winnipesaukee Stone (`WinniStone`)

Workbook tail order:

1. `Item_Icon_WorkBook_PotentialMaxHP` (PE / Max HP)
2. `Item_Icon_WorkBook_PotentialAttack` (Shooting / Attack)
3. `Item_Icon_WorkBook_PotentialHealPower` (Hygiene / Heal Power)

Grid matching first filters normal ooparts by the detected tier background and
then compares only the twenty family icons at that tier. Workbook templates are
canonical grid candidates from `templates/icons/temp/`, use the yellow T2
background, and are ranked in a separate three-item branch so their margins are
not diluted by normal oopart families.

When new ooparts are added in-game, append the family to `OPART_DEFINITIONS`
in this exact scanner/display order. If the in-game order changes, update this
list and the code together; profile cursor and order-hint matching depend on it.

ID pattern:

```text
Item_Icon_Material_{IconKey}_{TierIndex}
Item_Icon_WorkBook_Potential{StatKey}
```

### Equipment

Profile ID: `equipment`

Order:

1. Equipment exp stones in `EQUIPMENT_EXP_ITEMS` order:
   `Equipment_Icon_Exp_3`, `Equipment_Icon_Exp_2`,
   `Equipment_Icon_Exp_1`, `Equipment_Icon_Exp_0`.
2. For each equipment series in `EQUIPMENT_SERIES` declaration order, tiers
   `10` down to `2`.
3. For each equipment series again, tier `1`.
4. Weapon growth parts in `WEAPON_PART_ITEMS` order: `Z`, `C`, `B`, `A`.
5. For each weapon part, tiers `4` down to `1`; the ID suffix is zero-based,
   so those become suffixes `3`, `2`, `1`, `0`.

ID patterns:

```text
Equipment_Icon_{SeriesIconKey}_Tier{Tier}
Equipment_Icon_WeaponExpGrowth{PartKey}_{TierMinusOne}
```

### Student Elephs

Profile ID: `student_elephs`

Student elephs use Korean-server student metadata from `core.student_meta`;
`JP_ONLY_STUDENT_IDS` are excluded from the scan target list. The order follows
the full localized eleph item label, using the student display name plus the
eleph suffix. This matches in-game ordering where punctuation and full names
participate in the same comparison; for example, Mari scans as Mari (Idol),
Mari (Sportswear), Marina (Qipao), Marina, then base Mari.

ID pattern:

```text
Item_Icon_SecretStone_{student_id}
```

Grid matching uses the eleph icon templates in `templates/students_elephs/` and
the normal item T0 background composition. Because eleph icons share a large
purple frame and T0 background, tier color hinting is disabled. Recognition
combines the established face crop (`left=0.3630`, `right=0.3592`,
`top=0.2896`, `bottom=0.3159`) at weight `0.9` with a wider hair/headgear and
outer-appearance crop at weight `0.1`. The second ROI is a cross-check; the
stored first-page captures showed that giving it more weight reduced margin.

Detail fallback templates are generated under
`templates/inventory_detail/student_elephs/` from the same `eleph_work` project.
The detail ROI is `(511,331)-(809,658)` on a 2560x1440 reference, and each
eleph icon is composited at `(-89,-25)` within that ROI at `476x377`.

### Presents

Profile ID: `presents`

Presents use the same grid-matching composition as the student-eleph profile,
but the icon candidates come only from `templates/icons/presents/`. The profile
uses the present icon file stems as stable item IDs and scan labels. The expected
grid order follows the same natural filename order as that folder, and the
scanner uses that order for row-anchor candidate narrowing and gap zero-fill.

For `presents`, profile-order hints and row anchors are enabled by default even
when the umbrella `BA_INVENTORY_ANCHOR_MATCH` experiment is off. They can still
be disabled independently with `BA_ITEM_GRID_ORDER_HINT=0` and
`BA_ITEM_GRID_ROW_ANCHOR_HINT=0`. Other profiles retain the umbrella opt-in.

Legacy icon fallback candidates are restricted to the active profile catalog,
so a weak present slot cannot be replaced by a visually similar eleph or other
item family before profile validation.

ID pattern examples:

```text
Item_Icon_Favor_{Index}
Item_Icon_Favor_Lv2_{Index}
Item_Icon_Favor_SSR_GL_{Index}
```

Grid matching uses a dedicated, wider object crop (`left=0.34`, `right=0.34`,
`top=0.28`, `bottom=0.30`) rather than the eleph face crop. Background color is
also a strict rarity gate: normal presents use the T2 yellow background and
only `SSR` or `Lv2` IDs enter the T3 purple branch. Numeric filename suffixes
are present indices and must never be interpreted as tiers.

Detail fallback templates are generated under `templates/inventory_detail/presents/`
using the same ROI and overlay geometry as `student_elephs`: detail ROI
`(511,331)-(809,658)` on a 2560x1440 reference and overlay geometry
`(-89,-25)` at `476x377`. The same present background rule is used for these
fallback templates. Unlike grid matching, detail fallback does not use the
yellow/purple rarity backgrounds. It uses the common blue detail-screen crop in
`templates/inventory_detail_backgrounds/presents.png`. Regenerate the 75
composites with `python -m tools.build_present_detail_templates`; pass
`--background-source` only when replacing the committed blue crop from a full
detail-screen screenshot.

The scan preparation keeps the default item sort rule (`sort_rule_check`),
unlike student elephs, which use the name-sort reference. Until the dedicated
present filter image is supplied, the UI click target is temporarily mapped to
the ooparts filter position.

### Coins

Profile ID: none

Coins are no longer exposed as an item scan filter. Existing saved coin entries
may still be displayed from stored inventory data, but new item scans skip the
coin category.

### Activity Reports

Profile ID: `activity_reports`

Reports use `_REPORT_NAMES` for display labels and stable zero-based item IDs
for storage and detail templates.

The four legacy grid assets `templates/icons/temp/report_0.png` through
`report_3.png` are exposed through the canonical IDs below. Tier-background
detection strictly reduces the grid catalog to one report candidate before the
composite score is evaluated.

Grid counts ending in `K` use a second, consistently left-shifted glyph layout
for the `x` prefix and every preceding digit. A weak terminal `K` may select
this layout when the final cell cannot be accepted as a digit. The abbreviated
grid value is still not expanded or stored as an exact quantity; it requests
detail-screen count verification.

ID pattern:

```text
Item_Icon_ExpItem_{TierIndex}
```

## Gap Recovery

When profile gap recovery runs, the scanner compares captured detail crops
against the ordered list above. Missing ordered positions are written as
quantity `0`; matched positions use the canonical `item_id` for that profile.

## Viewer Group Sorting

The Qt inventory viewer groups items before sorting:

1. Equipment tier items are grouped by equipment series and sorted by tier
   descending.
2. Ooparts, workbooks, exp stones, reports, weapon parts, tech notes, BD,
   and student elephs each use their profile order map.
3. Unknown items fall back to display label alphabetical order.
