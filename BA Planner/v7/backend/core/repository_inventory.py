"""Pure canonical inventory rebase shared by scanner and repository."""
from __future__ import annotations

from typing import Any

from core.inventory_catalog import BY_KEY as INVENTORY_CATALOG_BY_KEY, CATALOG_REVISION, canonical_resource_key
from core.repository_dto import InventorySnapshot


def rebase_inventory_snapshot(inventory: dict[str, Any]) -> dict[str, Any]:
    """Rebase version-scoped ordinals while retaining observed screen slots."""
    snapshot = InventorySnapshot.from_dict(inventory)
    entries: list[dict[str, Any]] = []
    for item in snapshot.entries:
        entry = item.to_dict()
        # D18: an old catalog key (e.g. 비의서 stored as *_Ultimate_Piece) is rebased to the current key.
        entry["key"] = canonical_resource_key(entry["key"])
        if entry.get("item_id") is not None:
            entry["item_id"] = canonical_resource_key(entry["item_id"])
        identity = entry.get("item_id") or entry["key"]
        catalog_row = INVENTORY_CATALOG_BY_KEY.get(identity)
        if catalog_row is not None:
            if (
                entry.get("observed_slot") is None
                and entry.get("profile_id") == "visible-grid"
                and entry.get("index") is not None
            ):
                entry["observed_slot"] = entry["index"]
            entry["index"] = catalog_row.order_index
            entry["profile_id"] = catalog_row.profile_id
        entries.append(entry)
    return InventorySnapshot.from_dict({
        "version": 1,
        "catalog_revision": CATALOG_REVISION,
        "entries": entries,
    }).to_dict()
