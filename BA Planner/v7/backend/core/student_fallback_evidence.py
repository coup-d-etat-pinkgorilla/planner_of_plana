"""Transient student review crops; never part of repository values/history."""
from __future__ import annotations

import base64
from copy import deepcopy
from io import BytesIO
from typing import Any

from PIL import Image


WEAPON_FALLBACK_CROPS = {
    "weapon_level_fallback": "basic_weapon_level_digits_quad",
    "weapon_star_fallback": "basic_weapon_star_region",
}


def weapon_fallback_review_details(evidence: list[dict[str, Any]], crops) -> dict[str, dict[str, Any]]:
    """Encode only an existing fallback row's original named Basic Info ROI.

    The panel result and original trigger remain in that row. This image is the
    original rejected basic read, not a screenshot of the subsequent panel.
    No inverse value is inferred from recognition notes or confidence.
    """
    result = {}
    for row in evidence:
        key = WEAPON_FALLBACK_CROPS.get(row.get("field"))
        image = crops.images.get(key) if key is not None else None
        if not isinstance(image, Image.Image):
            continue
        with BytesIO() as buffer:
            image.save(buffer, format="PNG")
            encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
        result[row["field"]] = {
            "crop_png_base64": encoded,
            "crop_source": "basic_info",
            "crop_width": image.width,
            "crop_height": image.height,
        }
    return result


def attach_student_fallback_details(evidence: list[dict[str, Any]], specimen: dict[str, Any]) -> None:
    """Promote private matcher details only at the versioned session boundary.

    Raw matcher FieldEvidence remains compatible with the older repository DTO.
    Session evidence already supports additive details objects.
    """
    details = specimen.get("fallback_review_details", {})
    if not isinstance(details, dict):
        return
    for row in evidence:
        field = row.get("field")
        if field in WEAPON_FALLBACK_CROPS and isinstance(details.get(field), dict):
            row.setdefault("details", {}).update(deepcopy(details[field]))


def remove_student_crop_images(value: object) -> None:
    """Remove encoded crop bytes in place, preserving numeric/text evidence.

    Applied to a student's evidence and retained candidate events only. Inventory
    identity assignment has its own private image policy and is not affected.
    Previously emitted external copies are owned by the recipient, which must
    perform its own cache cleanup and diagnostic redaction.
    """
    if isinstance(value, dict):
        value.pop("crop_png_base64", None)
        for nested in value.values():
            remove_student_crop_images(nested)
    elif isinstance(value, list):
        for nested in value:
            remove_student_crop_images(nested)
