---
title: "Canonical Metadata Boundary"
summary: "BA Planner owns a versioned student metadata catalog while SchaleDB remains an isolated provider and adapter."
topics: [architecture, data]
sources:
  - id: canonical-loader
    type: file
    path: backend/core/canonical_metadata.py
  - id: canonical-catalog
    type: file
    path: backend/data/metadata/v1/student_catalog.json
  - id: schaledb-provider
    type: file
    path: backend/core/schaledb_provider.py
  - id: schaledb-adapter
    type: file
    path: backend/core/schaledb_metadata_adapter.py
  - id: compatibility-api
    type: file
    path: backend/core/student_meta.py
---

# Canonical Metadata Boundary

BA Planner owns the version-1 catalog at
`backend/data/metadata/v1/student_catalog.json`. It is the runtime and editor
source of truth. Its schema is stored beside it as `catalog.schema.json`.
Generated Python declarations are migration input only and must not receive new
runtime or editor writes. [@canonical-loader] [@canonical-catalog]

The catalog separates these concerns:

- `students`: provider-neutral static student records
- `forms`: form-specific overrides keyed by canonical BA Planner student ID
- `server_availability`: JP-only membership
- `favorite_items`: BA Planner favorite-item availability state
- `provider_refs`: external identifiers grouped by provider
- `gift_affinities`: normalized preference and unique tag lists keyed by canonical ID

Provider-owned fields such as `schaledb_id`, `favor_item_tags` and
`favor_item_unique_tags` are invalid inside `students`. `core.student_meta`
reconstructs those legacy lookup fields at the compatibility edge so existing
planning, scanner and protocol consumers do not depend on catalog layout.
[@compatibility-api]

`core.schaledb_provider` owns HTTP endpoints, request headers and raw document
retrieval only. `core.schaledb_metadata_adapter` owns source URL parsing, slug
normalization, exceptional and multi-path identity mapping, source validation and
the explicit minimal import allowlist. Neither module writes the canonical
catalog. The standalone metadata tool coordinates preview and confirmed writes.
[@schaledb-provider] [@schaledb-adapter]

Student statistics, equipment statistics and gift item definitions remain
separate bounded catalogs. They may reference a canonical student ID or an
external provider ID, but they are not folded into the student static record.

The bootstrap exporter `backend/tools/export_canonical_metadata.py` exists to
reproduce the first canonical snapshot from the legacy generated declaration.
After the migration snapshot, normal changes must go through canonical catalog
writers rather than regenerate from the legacy Python file.
