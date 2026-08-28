---
title: "Inventory Catalog Order Stability"
summary: "Inventory identities are stable while profile ordinals are scoped to a content-addressed catalog revision."
topics: [architecture, data]
sources:
  - id: inventory-catalog
    type: file
    path: backend/core/inventory_catalog.py
  - id: inventory-dto
    type: file
    path: backend/core/repository_dto.py
  - id: repository-store
    type: file
    path: backend/core/repository_store.py
  - id: inventory-schema
    type: file
    path: contracts/planning-inventory-catalog-v1.schema.json
---

# Inventory Catalog Order Stability

`resource_key` is the durable inventory identity. `profile_id` and `order_index`
describe one item’s position only within the exact inventory catalog revision
that produced them. They must never be used as a cross-version identity.
[@inventory-catalog]

The student-eleph profile is derived from the current KR-available canonical
student set and the full localized eleph label. Adding a KR student, changing a
display name, or changing JP/KR availability can move existing ordinals. This is
expected because the order models the current in-game scan order. Repeating the
derivation from the same metadata is deterministic, including duplicate-name
tie-breaking by canonical student ID.

`planning.inventory.catalog` returns `catalog_revision`, a SHA-256 digest of the
complete canonical catalog rows. A fixture that asserts profile order must pin
that revision or assert relative ordering; an isolated absolute ordinal without
the revision is invalid evidence. [@inventory-schema]

Repository inventory snapshots may carry the same `catalog_revision`. On load
and write, known identities are rebased to the current catalog’s `profile_id` and
`order_index`. Old `visible-grid` entries are migrated by retaining their former
screen position as `observed_slot`; new scanner results write `observed_slot`
directly. Unknown identities retain their supplied optional metadata because no
canonical catalog row exists to rebase them. [@inventory-dto] [@repository-store]

Catalog order and scan observation therefore have separate meanings:

- `resource_key`: durable identity
- `order_index`: current catalog ordinal
- `catalog_revision`: ordinal namespace/version
- `observed_slot`: position seen in a particular scan
