# v6 triangle texture migration

## Scope

The v6 image-free background renderer in `../v6/gui/triangle_texture.py` is
reimplemented for Flutter in
`frontend/lib/ui/widgets/ba_triangle_background.dart`. No Qt class, painter,
widget, or runtime dependency is imported into v7.

## Preserved visual contract

- Fill the complete surface from the active v7 palette.
- Generate triangle faces from deterministic coordinate noise and a stable seed.
- Offset the global origin and vary row phase and row height without opening gaps.
- Draw sparse oversized faces over the fine tessellation without outlines.
- Compose centered light, directional fog, a soft glow, and edge vignette layers.
- Keep the texture in one repaint boundary beneath the Flutter application UI.
- Repaint only when geometry or texture configuration changes.

The initial full-window configuration retains the v6 baseline values: seed
`7319`, triangle size `138`, fine contrast `0.032`, macro chance `0.075`, macro
scale `3.0`, macro contrast `0.024`, centered light `0.16`, fog direction `18°`,
fog strength `0.13`, and vignette strength `0.2`. Colors are intentionally
derived from the v7 palette rather than copying the v6 Qt palette constants.

## Flutter ownership

`AppShell` owns the full-window texture as its lowest `Stack` layer. Ordinary
content remains independent. Structural glass surfaces use translucent fills
and backdrop blur so the texture can show through, while cards and controls
retain their explicit fills for readability.

## Validation

`frontend/test/widget_test.dart` renders the painter to raw RGBA pixels and
asserts that repeated renders with seed `7319` match while a different seed
changes the output. The app-shell widget test also asserts that exactly one
full-window texture layer is present.
