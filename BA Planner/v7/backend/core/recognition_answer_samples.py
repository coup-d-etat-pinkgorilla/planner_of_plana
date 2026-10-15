from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import json
import hashlib
from pathlib import Path
import re
from typing import Iterable
from uuid import uuid4

from PIL import Image
from core.numeric_sample_safety import numeric_mask_issue


_PROFILE_ID = re.compile(r"^[0-9a-f]{24}$")
_SAFE_PART = re.compile(r"^[A-Za-z0-9_.-]+$")


@dataclass(frozen=True, slots=True)
class NumericAnswerSample:
    field: str
    roi_name: str
    digit: str
    image: Image.Image
    sample_id: str
    validated: bool = False


@dataclass(frozen=True, slots=True)
class NumericSampleWrite:
    sample_id: str
    created: bool
    quarantined: bool


@dataclass(frozen=True, slots=True)
class InventoryAnswerSample:
    item_id: str
    image: Image.Image
    sample_id: str


class RecognitionAnswerSampleStore:
    """User-confirmed recognition data isolated from bundled runtime assets."""

    VERSION = 1

    def __init__(self, storage_root: Path) -> None:
        self.root = Path(storage_root) / "recognition_samples"

    @staticmethod
    def resolution_key(source_size: tuple[int, int]) -> str:
        width, height = source_size
        if not isinstance(width, int) or not isinstance(height, int) or width < 1 or height < 1:
            raise ValueError("source_size must contain positive pixel dimensions")
        return f"{width}x{height}"

    @staticmethod
    def _part(value: str, label: str) -> str:
        if not isinstance(value, str) or not value or _SAFE_PART.fullmatch(value) is None:
            raise ValueError(f"{label} contains unsupported characters")
        return value

    def _scope(self, profile_id: str, source_size: tuple[int, int]) -> Path:
        if _PROFILE_ID.fullmatch(profile_id) is None:
            raise ValueError("profile_id must be a stable 24-character lowercase hex ID")
        return self.root / profile_id / self.resolution_key(source_size)

    @staticmethod
    def _write_metadata(path: Path, payload: dict[str, object]) -> None:
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        temporary.replace(path)

    def save_numeric(
        self,
        profile_id: str,
        source_size: tuple[int, int],
        *,
        field: str,
        roi_name: str,
        digit: str,
        mask: Image.Image,
        candidate_id: str,
    ) -> str:
        return self.write_numeric(
            profile_id, source_size, field=field, roi_name=roi_name, digit=digit,
            mask=mask, candidate_id=candidate_id,
        ).sample_id

    def write_numeric(
        self, profile_id: str, source_size: tuple[int, int], *, field: str,
        roi_name: str, digit: str, mask: Image.Image, candidate_id: str,
        quarantine_reason: str | None = None,
    ) -> NumericSampleWrite:
        field = self._part(field, "field")
        roi_name = self._part(roi_name, "roi_name")
        if digit not in "0123456789" or len(digit) != 1:
            raise ValueError("digit must be one decimal character")
        issue = numeric_mask_issue(mask, field, roi_name)
        if issue:
            raise ValueError(f"numeric_mask_rejected:{issue}")
        scope = self._scope(profile_id, source_size)
        prepared = mask.convert("L")
        mask_sha = hashlib.sha256(
            json.dumps(prepared.size).encode() + prepared.tobytes()
        ).hexdigest()
        sample_id = hashlib.sha256(json.dumps(
            [profile_id, list(source_size), candidate_id, field, roi_name, digit, mask_sha],
            separators=(",", ":"), ensure_ascii=False,
        ).encode()).hexdigest()
        active_directory = scope / "numeric" / field / roi_name / digit
        directory = (self.root / "_quarantine" / "numeric" / active_directory.relative_to(self.root)
                     if quarantine_reason else active_directory)
        directory.mkdir(parents=True, exist_ok=True)
        image_path = directory / f"{sample_id}.png"
        metadata_path = directory / f"{sample_id}.json"
        if image_path.is_file() and metadata_path.is_file():
            try:
                existing = json.loads(metadata_path.read_text(encoding="utf-8"))
                intact = (isinstance(existing, dict) and existing.get("mask_sha256") == mask_sha
                          and existing.get("png_sha256") == hashlib.sha256(image_path.read_bytes()).hexdigest())
            except (OSError, ValueError):
                intact = False
            if intact:
                prepared.close()
                return NumericSampleWrite(sample_id, False, quarantine_reason is not None)
        temporary_image = image_path.with_suffix(".png.tmp")
        try:
            prepared.save(temporary_image, format="PNG", optimize=True)
        finally:
            prepared.close()
        temporary_image.replace(image_path)
        self._write_metadata(metadata_path, {
            "version": self.VERSION,
            "sample_id": sample_id,
            "kind": "numeric_digit",
            "field": field,
            "roi_name": roi_name,
            "digit": digit,
            "candidate_id": candidate_id,
            "capture_resolution": list(source_size),
            "confirmed_at": datetime.now(timezone.utc).isoformat(),
            "confirmation_source": "user_review",
            "mask_sha256": mask_sha,
            "png_sha256": hashlib.sha256(image_path.read_bytes()).hexdigest(),
            "safety_status": "quarantined" if quarantine_reason else "validated",
            "reason": quarantine_reason,
            "original_path": str(active_directory / image_path.name),
            "stored_path": str(image_path),
        })
        return NumericSampleWrite(sample_id, True, quarantine_reason is not None)

    def load_numeric(
        self, profile_id: str, source_size: tuple[int, int]
    ) -> tuple[NumericAnswerSample, ...]:
        root = self._scope(profile_id, source_size) / "numeric"
        if not root.is_dir():
            return ()
        result: list[NumericAnswerSample] = []
        for path in sorted(root.glob("*/*/[0-9]/*.png")):
            try:
                relative = path.relative_to(root).parts
                field, roi_name, digit = relative[:3]
                with Image.open(path) as opened:
                    image = opened.convert("L")
                if numeric_mask_issue(image, field, roi_name):
                    image.close()
                    continue
                metadata_path = path.with_suffix(".json")
                try:
                    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
                except (OSError, ValueError):
                    metadata = {}
                if not isinstance(metadata, dict) or metadata.get("safety_status") == "quarantined":
                    image.close()
                    continue
                if metadata.get("png_sha256") and metadata["png_sha256"] != hashlib.sha256(path.read_bytes()).hexdigest():
                    image.close()
                    continue
                result.append(NumericAnswerSample(field, roi_name, digit, image, path.stem,
                                                  metadata.get("safety_status") == "validated"))
            except (OSError, ValueError, IndexError):
                continue
        return tuple(result)

    def save_inventory(
        self,
        profile_id: str,
        source_size: tuple[int, int],
        *,
        item_id: str,
        crop: Image.Image,
        candidate_id: str,
        observed_slot: int,
    ) -> str:
        item_id = self._part(item_id, "item_id")
        sample_id = uuid4().hex
        directory = self._scope(profile_id, source_size) / "inventory_grid" / item_id
        directory.mkdir(parents=True, exist_ok=True)
        image_path = directory / f"{sample_id}.png"
        temporary_image = image_path.with_suffix(".png.tmp")
        prepared = crop.convert("RGB")
        try:
            prepared.save(temporary_image, format="PNG", optimize=True)
        finally:
            prepared.close()
        temporary_image.replace(image_path)
        self._write_metadata(directory / f"{sample_id}.json", {
            "version": self.VERSION,
            "sample_id": sample_id,
            "kind": "inventory_grid_slot",
            "item_id": item_id,
            "candidate_id": candidate_id,
            "observed_slot": observed_slot,
            "capture_resolution": list(source_size),
            "confirmed_at": datetime.now(timezone.utc).isoformat(),
            "confirmation_source": "user_review",
        })
        return sample_id

    def load_inventory(
        self, profile_id: str, source_size: tuple[int, int]
    ) -> tuple[InventoryAnswerSample, ...]:
        root = self._scope(profile_id, source_size) / "inventory_grid"
        if not root.is_dir():
            return ()
        result: list[InventoryAnswerSample] = []
        for path in sorted(root.glob("*/*.png")):
            try:
                item_id = path.parent.name
                with Image.open(path) as opened:
                    image = opened.convert("RGB")
                result.append(InventoryAnswerSample(item_id, image, path.stem))
            except OSError:
                continue
        return tuple(result)

    @staticmethod
    def close(samples: Iterable[NumericAnswerSample | InventoryAnswerSample]) -> None:
        for sample in samples:
            sample.image.close()
