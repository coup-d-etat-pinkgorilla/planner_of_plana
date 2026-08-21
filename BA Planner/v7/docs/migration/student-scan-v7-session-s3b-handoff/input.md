# S3B input — 장비 기본 화면 binary matcher 보강

Canonical input: `docs/migration/student-scan-v7-session-s3b-input.md`

S3 master snapshot의 empty/locked/family/tier, small-ROI generated matcher,
unresolved-only one-menu fallback과 애용품 판독을 보존한다. S4/S5와 protocol/UI 확장은 제외한다.

- 48x36 ROI를 두 셀로 나누고 adaptive dark-ink를 20x28 binary glyph로 정규화한다.
- 기존 장비-menu digit asset을 slot/position/label template로 한 번 준비한다.
- IoU/correlation, top score, second margin을 기록하고 exact 뒤 불확정일 때만 +/-1px를 시도한다.
- 실제 0-9와 blank coverage가 부족한 동안 결과는 shadow evidence이며 candidate를 확정하지 않는다.
- low score/margin, asset/feature 누락, invalid tier-level은 generated/menu fallback으로 내린다.
- current Mika/Hibiki Lv70 6-frame/36-cell smoke, false-positive 0, confusion, fallback/menu calls,
  cold/warm/template/cache metrics와 focused/full backend 검증을 인계한다.
- S4/S5는 건드리지 않는다. Production promotion 미충족 항목은 `MASTER_REQUIRED`로 남긴다.

인계는 `almanac/workflows/slave-artifact-handoff.md` 형식의 `output.md`와 `artifacts/`로 한다.
