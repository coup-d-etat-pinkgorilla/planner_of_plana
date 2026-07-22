from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
from typing import Any

from core.scanner_session import ScannerError


@dataclass(frozen=True, slots=True)
class RecognitionAsset:
    path: str
    scan_kind: str
    purpose: str
    required: bool
    bytes: int
    sha256: str
    identity: str | None = None


class RecognitionAssetCatalog:
    VERSION = 1

    def __init__(self, root: Path | None = None) -> None:
        self.root = root or Path(__file__).with_name("recognition_assets")
        self.manifest_path = self.root / "manifest.json"
        self._manifest: dict[str, Any] | None = None

    def load(self) -> dict[str, Any]:
        try:
            value = json.loads(self.manifest_path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            raise ScannerError("asset_manifest_invalid", str(exc)) from exc
        if not isinstance(value, dict) or value.get("version") != self.VERSION or not isinstance(value.get("assets"), list):
            raise ScannerError("asset_version_mismatch", f"recognition manifest version must be {self.VERSION}")
        self._manifest = value
        return value

    def verify(self) -> dict[str, Any]:
        manifest = self.load()
        missing: list[str] = []
        corrupt: list[str] = []
        for raw in manifest["assets"]:
            if not isinstance(raw, dict) or not isinstance(raw.get("path"), str):
                raise ScannerError("asset_manifest_invalid", "asset entry must contain a path")
            path = self.resolve(raw["path"])
            if not path.is_file():
                if raw.get("required") is True:
                    missing.append(raw["path"])
                continue
            content = path.read_bytes()
            digest = hashlib.sha256(content).hexdigest()
            if len(content) != raw.get("bytes") or digest != raw.get("sha256"):
                corrupt.append(raw["path"])
        return {
            "ready": not missing and not corrupt,
            "manifest_version": manifest["version"],
            "source_version": manifest.get("source_version"),
            "asset_count": len(manifest["assets"]),
            "missing": missing,
            "corrupt": corrupt,
            "supported_resolutions": manifest.get("supported_resolutions", []),
        }

    def resolve(self, relative: str) -> Path:
        path = (self.root / relative).resolve()
        try:
            path.relative_to(self.root.resolve())
        except ValueError as exc:
            raise ScannerError("asset_manifest_invalid", "asset path escapes recognition root") from exc
        return path

    def assets(self, scan_kind: str, purpose: str) -> list[RecognitionAsset]:
        manifest = self._manifest or self.load()
        result: list[RecognitionAsset] = []
        for raw in manifest["assets"]:
            if raw.get("scan_kind") != scan_kind or raw.get("purpose") != purpose:
                continue
            identity = raw.get("student_id") or raw.get("item_id") or raw.get("digit")
            result.append(RecognitionAsset(
                path=raw["path"], scan_kind=scan_kind, purpose=purpose,
                required=bool(raw.get("required")), bytes=raw["bytes"],
                sha256=raw["sha256"], identity=identity,
            ))
        return result

    def region(self, scan_kind: str) -> dict[str, Any]:
        assets = self.assets(scan_kind, f"{scan_kind}-regions" if scan_kind == "student" else "grid-regions")
        if len(assets) != 1:
            raise ScannerError("region_missing", f"{scan_kind} region asset is missing")
        try:
            return json.loads(self.resolve(assets[0].path).read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            raise ScannerError("region_missing", str(exc)) from exc
