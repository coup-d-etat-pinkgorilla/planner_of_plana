# S3B archive validation input

User source: `C:\Users\brigh\Pictures\Screenshots\BA`

Treat the folder as a read-only collection of Blue Archive in-game screenshots. Inventory its files,
identify student-detail screens, and validate the S3B equipment binary shadow matcher against every
usable basic-equipment ROI. Preserve the accepted S3 generated/menu fallback and keep S4/S5 out of
scope.

- Apply runtime ordering: student ID → metadata equipment family → icon tier → binary level.
- Do not treat a direct digit crop from an incomplete/non-detail screen as production evidence.
- Establish visible ground truth without using archive crops as runtime templates.
- Record screenshot hashes, coverage, confusion, score/margin and remaining production gaps.
- Preserve portable test evidence without copying source screenshots into runtime recognition assets.
- Update the active workflow/status and hand off actual artifacts using
  `almanac/workflows/slave-artifact-handoff.md`.
