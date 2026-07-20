# v6 glass shadow and section transition migration

## Scope

The v6 lifted-shadow and section-host behavior from
`../v6/gui/viewer_components/home.py` is reimplemented in Flutter. Qt painter,
animation, snapshot, and widget classes are not copied into the v7 runtime.

## Fixed glass shadow

The compound L-shaped tab glass remains stationary. Its custom path reserves a
three-pixel lower-right inset and paints four translated shadow layers before
the translucent glass fill. The initial values preserve the v6 menu-section
contract: `(2, 2)` offset, four layers, three-pixel inset, and `0.22` maximum
alpha. The shadow follows the glass silhouette rather than the rectangular
widget bounds and does not change hit testing.

Implementation:

- `frontend/lib/ui/widgets/lifted_path_shadow.dart`
- `frontend/lib/ui/app_shell.dart`

## Animated sections below the glass

Only the page section area beneath the fixed glass moves. `AnimatedSectionStack`
keeps every page mounted and preserves its state while showing the outgoing and
incoming pages as siblings during a transition.

The v6 four-phase timing and direction contract are preserved:

1. pull for 120 ms opposite the outgoing `outro` direction;
2. exit for 300 ms along the outgoing `outro` direction;
3. linear entrance cruise for 360 ms along the incoming `intro` direction;
4. cubic settle for 190 ms into the final position.

Angles use monitor-space mathematical directions: `0` right, `90` up, `180`
left, and `270` down. Home uses the v6 diagonal pair `intro=80`, `outro=260`.
Other current top-level placeholders use vertical `intro=90`, `outro=270` and
can receive independent route values as their real sections are migrated.

Implementation:

- `frontend/lib/ui/widgets/animated_section_stack.dart`
- `frontend/lib/ui/app_shell.dart`

## Validation

Flutter tests cover cardinal direction mapping, the 80-degree diagonal's
collinearity, lower-right shadow alpha falloff, simultaneous outgoing/incoming
section presence, and the final settled page. Existing app state and narrow
development-panel tests remain enabled.
