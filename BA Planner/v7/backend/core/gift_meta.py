"""Stable runtime accessors for generated minimal gift metadata."""

from __future__ import annotations

from core.gift_meta_data import GIFT_ITEMS, GiftMeta


def get(gift_id: int) -> GiftMeta | None:
    return GIFT_ITEMS.get(int(gift_id))


def all_ids() -> tuple[int, ...]:
    return tuple(GIFT_ITEMS)


def category(gift_id: int) -> str | None:
    item = get(gift_id)
    return str(item["category"]) if item else None


def tags(gift_id: int) -> tuple[str, ...]:
    item = get(gift_id)
    return tuple(str(tag) for tag in item["tags"]) if item else ()


def exp_value(gift_id: int) -> int:
    item = get(gift_id)
    return int(item["exp_value"]) if item else 0
