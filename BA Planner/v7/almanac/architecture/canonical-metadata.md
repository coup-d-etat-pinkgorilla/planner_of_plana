---
title: "Canonical Metadata Boundary"
summary: "Versioned canonical metadata, approved client-store regeneration and explicit client character bindings."
topics: [architecture, data]
sources:
  - id: canonical-loader
    type: file
    path: backend/core/canonical_metadata.py
  - id: canonical-catalog
    type: file
    path: backend/data/metadata/v1/student_catalog.json
  - id: store-generator
    type: file
    path: backend/tools/metadata_store_regenerate.py
  - id: client-character-refs
    type: file
    path: backend/core/client_character_refs.py
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

The read-only store generator accepts a lock/catalog-bound reviewed crosswalk,
approved client extracts, frozen gift experience values and explicit secondary
form bindings. It writes a new staging bundle only. Manual/KR fields and archived
provider references remain preserved; matching numeric values do not create new
source associations. Provisional ConstCommon is not consumed. The removed Schale
network/adapter/merge modules and seven tool methods are no longer runtime paths.
[@store-generator]

Student stats and bond calculations resolve explicit client character IDs through
`client-character-refs.json`. The legacy numeric `schaledb_id` field remains at
the compatibility edge; it does not authorize network import. [@client-character-refs]

Student statistics, equipment statistics and gift item definitions remain
separate bounded catalogs. They may reference a canonical student ID or an
external provider ID, but they are not folded into the student static record.

The bootstrap exporter `backend/tools/export_canonical_metadata.py` exists to
reproduce the first canonical snapshot from the legacy generated declaration.
Its `--from-store --bundle-output` mode regenerates canonical/generated data from
approved store sources without writing the shared store or replacing main data.
Normal editor changes still go through canonical catalog writers.
