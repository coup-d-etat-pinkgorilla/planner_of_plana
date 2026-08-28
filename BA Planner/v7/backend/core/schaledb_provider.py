"""Transport-only provider for SchaleDB source payloads."""

from __future__ import annotations

import json
from typing import Any, Callable
from urllib.request import Request, urlopen


SCHALEDB_STUDENTS_URL = "https://schaledb.com/data/en/students.min.json"
SCHALEDB_ITEMS_URL = "https://schaledb.com/data/en/items.min.json"


def fetch_json(url: str) -> dict[str, Any]:
    request = Request(url, headers={"User-Agent": "BA-Planner-v7/1", "Accept": "application/json"})
    with urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if not isinstance(payload, dict):
        raise ValueError(f"SchaleDB returned a non-object payload: {url}")
    return payload


class SchaleDBProvider:
    """Fetches raw SchaleDB documents without knowing BA Planner metadata."""

    def __init__(self, fetcher: Callable[[str], dict[str, Any]] = fetch_json) -> None:
        self._fetcher = fetcher

    def students(self) -> dict[str, Any]:
        return self._fetcher(SCHALEDB_STUDENTS_URL)

    def items(self) -> dict[str, Any]:
        return self._fetcher(SCHALEDB_ITEMS_URL)

    def snapshot(self) -> tuple[dict[str, Any], dict[str, Any]]:
        return self.students(), self.items()
