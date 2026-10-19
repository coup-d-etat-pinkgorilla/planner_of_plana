# Isolated recognition development pack candidate (2026-10-14)

Prepared under user decision A from the installed KR/Steam public catalog.
Independent CompactCatalog resolves addresses; actual Unity container pointers
select icons, atlas material/texture, and fonts. UnityPy is the shared decoder.
All source catalog/bundle hashes were unchanged before/after. No raw sources
were copied. Icons: 1330; sprites: 13; fonts: 2.

This local binary pack is development/test input only and remains git-ignored.
Runtime keeps extracting from each user's installed client. The existing rarity
snapshot and geometry specification are unchanged; new catalog-only icons do
not invent rarity, names, categories or metadata. Prior prefab parity is explicitly
historical and current prefab parity was not investigated. Main publication,
whole Python verification and crop commit are separate pending steps.

Publication projection preserves the existing manifest sprite border order
(left, right, top, bottom). Source atlas values agree by named side; sprite
coordinates, dimensions and exact decoded pixels remain unchanged. This
projection requires its own main-equivalent gate before publication/commit.
