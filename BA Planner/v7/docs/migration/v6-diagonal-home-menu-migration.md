# v6 diagonal Home menu migration

## Scope

The v7 Home page recreates the v6 presentation contract in Flutter. No Qt,
QML, or Python UI code is imported at runtime.

## Geometry contract

- Button bounds are established before the glass ratio. The 238-pixel design
  row uses the source-image widths: 692 for the featured trapezoid, 233/233/231
  for the three-button row, and 315/314 for the two-button row. A 15-pixel
  horizontal seam makes those rectangular image bounds interlock at 80 degrees.
- The resulting rounded right-cut glass section is 742 by 1018 logical pixels.
  It keeps that fixed aspect ratio and scales the complete design canvas down
  uniformly when either window dimension is constrained, so image crops,
  diagonal depths, margins, gaps, and corner radii remain proportional.
- Four menu rows divide the available section height equally with 10 logical
  pixels between rows.
- Each row evaluates the section's right boundary at its own starting Y, so
  lower rows become progressively narrower instead of being clipped afterward.
- Buttons in a row use the same 80 degree diagonal. Later buttons extend on the
  left and cut on the right, producing a parallelogram silhouette.
- Rectangular button hosts overlap by the diagonal slant minus the 10 pixel seam
  gap. The painted diagonal faces therefore retain a constant visible gap at
  both their top and bottom endpoints.
- Labels reserve the left extension and right cut depth as content-safe padding.
  `ClipPath` owns both antialiased clipping and transparent-corner hit testing.

## Flutter ownership

- `frontend/lib/ui/widgets/diagonal_menu.dart` owns reusable path construction,
  the trapezoid glass section, button clipping, and interlocking row layout.
- `frontend/lib/ui/pages/home_page.dart` owns Home-specific row grouping, image
  content, labels, and section navigation callbacks.
- `frontend/test/widget_test.dart` verifies section containment, bilateral
  button corners, constant seam spacing, and final row coverage.
