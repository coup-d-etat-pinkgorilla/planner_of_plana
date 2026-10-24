"""C5e-6a-0 (D24): extract recognition assets from the user's own Steam client.

The planner ships no game art. On first use it reads the installed client's plain Addressables catalog
(``catalog_Windows.bytes``, CCDB) and UnityFS bundles and writes a local cache:

    <root>/<catalog sha[:16]>/{icons/{items,equipment}/*.png, sprites/*.png, fonts/*.ttf, item-rarity.json, manifest.json}

Only files that need no key are read (catalog, icon textures, atlas sprites, font data); the ExcelDB-derived
rarity table is the distributed snapshot (D24 (2)). Updates are incremental per bundle: a bundle whose
file name, size and modification time match the previous cache is not opened again. Any failure is an
``asset_extract_failed`` ScannerError; callers disable the synthetic tier and keep scanning (detail panel,
labeling).
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import struct
import sys
import time
from typing import Any, Callable

from core.scanner_session import ScannerError

EXTRACTOR_VERSION = 1
STEAM_APP_ID = "3557620"
ICON_FOLDERS = {"uis/01_common/03_nonequipment/": "items", "uis/01_common/02_equipment/": "equipment"}
ICON_PREFIXES = ("item_icon_", "equipment_icon_")
ATLAS_NAME = "Common"
ATLAS_SPRITES = ("Card_Bg", "Card_Item_Bg_N", "Card_Item_Bg_R", "Card_Item_Bg_SR", "Card_Item_Bg_SSR", "Card_Select_Line",
                 "Common_Bg_Raius20px", "Common_Icon_Check_B", "Common_Icon_Formation_Star", "Common_Icon_Lock",
                 "Common_Line_Raius20px", "Common_Tab_Normal_Btn")
BLUEPRINT_KEY = "uis/00_images/card_item_bg_c"
FONTS = {"GyeonggiTitle-Bold": "MainFont_Bold", "GyeonggiTitle-Medium": "MainFont"}
ATLAS_BUNDLE_GLOB = "prologdepengroup-assets-_mx-uis-atlas-*"
FONT_BUNDLE_GLOB = "prologdepengroup-assets-_mx-uis-_mxcommon-*"


class AssetExtractFailed(ScannerError):
    def __init__(self, message: str) -> None:
        super().__init__("asset_extract_failed", message)


def resource_dir(game_dir: Path) -> Path:
    return Path(game_dir) / "BlueArchive_Data" / "StreamingAssets" / "PUB" / "Resource"


def _vdf_values(text: str, key: str) -> list[str]:
    return [value.replace("\\\\", "\\") for value in re.findall(rf'"{key}"\s+"([^"]*)"', text)]


def find_game_dir(steam_dir: Path | None = None) -> Path | None:
    """The Steam client's install folder from libraryfolders.vdf, or None (the UI then asks for a folder)."""
    if steam_dir is None and os.environ.get('BA_PLANNER_DISABLE_GAME_DISCOVERY') == '1':
        return None
    if steam_dir is None:
        steam_dir = _steam_dir()
    if steam_dir is None:
        return None
    libraries = [Path(steam_dir)]
    vdf = Path(steam_dir) / "steamapps" / "libraryfolders.vdf"
    if vdf.is_file():
        libraries += [Path(value) for value in _vdf_values(vdf.read_text(encoding="utf-8", errors="replace"), "path")]
    for library in dict.fromkeys(libraries):
        manifest = library / "steamapps" / f"appmanifest_{STEAM_APP_ID}.acf"
        if not manifest.is_file():
            continue
        folders = _vdf_values(manifest.read_text(encoding="utf-8", errors="replace"), "installdir")
        candidate = library / "steamapps" / "common" / (folders[0] if folders else "BlueArchive")
        if (resource_dir(candidate) / "Catalog" / "Windows" / "catalog_Windows.bytes").is_file():
            return candidate
    return None


def _steam_dir() -> Path | None:
    if sys.platform != "win32":
        return None
    import winreg
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as key:
            return Path(winreg.QueryValueEx(key, "SteamPath")[0])
    except OSError:
        return None


class AddressablesCatalog:
    """Minimal reader of the client's CCDB v1 compact Addressables catalog: address key -> bundle file."""

    def __init__(self, data: bytes) -> None:
        if not data.startswith(b"CCDB\x01"):
            raise AssetExtractFailed("catalog is not a CCDB v1 Addressables catalog")
        self.data = data
        self.internal_ids: list[str] = []
        self.keys: dict[str, list[int]] = {}
        self._buckets: list[tuple[int, int]] = []
        try:
            self._parse()
        except (struct.error, IndexError, UnicodeDecodeError, ValueError) as exc:
            raise AssetExtractFailed(f"catalog could not be read: {exc}") from exc

    def _varint(self, offset: int) -> tuple[int, int]:
        value = shift = 0
        while True:
            byte = self.data[offset]
            offset += 1
            value |= (byte & 0x7F) << shift
            if byte < 0x80:
                return value, offset
            shift += 7
            if shift > 35:
                raise ValueError("varint too long")

    def _u32(self, offset: int) -> int:
        return struct.unpack_from("<I", self.data, offset)[0]

    def _blob(self, offset: int) -> tuple[bytes, int]:
        length, start = self._varint(offset)
        if start + length > len(self.data):
            raise ValueError("blob exceeds file")
        return self.data[start:start + length], start + length

    def _key(self, offset: int) -> tuple[str | None, int]:
        kind = self.data[offset]
        offset += 1
        if kind in (0, 1):
            length = self._u32(offset)
            text = self.data[offset + 4:offset + 4 + length].decode("utf-8" if kind == 0 else "utf-16-le")
            return text, offset + 4 + length
        if kind == 2:
            return None, offset + 2
        if kind in (3, 4):
            return None, offset + 4
        if kind in (5, 6):
            return None, offset + 1 + self.data[offset]
        if kind == 7:
            offset += 1 + self.data[offset]
            offset += 1 + self.data[offset]
            return None, offset + 4 + self._u32(offset)
        raise ValueError(f"unknown key type {kind}")

    def _parse(self) -> None:
        offset = 5
        for _ in range(3):  # locator id, instance provider, scene provider
            _, offset = self._blob(offset)
        count, offset = self._u32(offset), offset + 4
        for _ in range(count):  # resource providers
            _, offset = self._blob(offset)
        count, offset = self._u32(offset), offset + 4
        for _ in range(count):  # provider ids
            _, offset = self._blob(offset)
        count, offset = self._u32(offset), offset + 4
        for _ in range(count):
            text, offset = self._blob(offset)
            self.internal_ids.append(text.decode("utf-8"))
        length, offset = self._u32(offset), offset + 4
        end = offset + length
        count, offset = self._u32(offset), offset + 4
        for index in range(count):
            key, offset = self._key(offset)
            if key is not None:
                self.keys.setdefault(key.lower(), []).append(index)
        if offset != end:
            raise ValueError("key block length mismatch")
        length, offset = self._u32(offset), offset + 4
        end = offset + length
        count, offset = self._u32(offset), offset + 4
        for _ in range(count):
            entries = self._u32(offset + 4)
            self._buckets.append((offset + 8, entries))
            offset += 8 + 4 * entries
        if offset != end:
            raise ValueError("bucket block length mismatch")
        length, offset = self._u32(offset), offset + 4
        self._entries = offset + 4
        self._entry_count = self._u32(offset)
        if self._entries + 28 * self._entry_count != offset + length or offset + length + 4 > len(self.data):
            raise ValueError("entry block length mismatch or truncated catalog")

    def _bucket(self, key_index: int) -> tuple[int, ...]:
        start, count = self._buckets[key_index]
        return struct.unpack_from(f"<{count}I", self.data, start)

    def _entry(self, index: int) -> tuple[int, ...]:
        return struct.unpack_from("<7i", self.data, self._entries + 28 * index)

    def addresses(self, prefix: str) -> list[str]:
        return [key for key in self.keys if key.startswith(prefix)]

    def bundle_for(self, address: str) -> str | None:
        """File name of the bundle holding the asset at address (its first dependency)."""
        for key_index in self.keys.get(address.lower(), []):
            for entry_index in self._bucket(key_index):
                dependency_key = self._entry(entry_index)[2]
                if dependency_key < 0:
                    continue
                for dependency in self._bucket(dependency_key):
                    internal = self.internal_ids[self._entry(dependency)[0]]
                    return internal.replace("\\", "/").rsplit("/", 1)[-1]
        return None


@dataclass
class AssetCache:
    root: Path
    manifest: dict[str, Any]

    def icon(self, identity: str) -> Path | None:
        entry = self.manifest["icons"].get(identity)
        return self.root / entry["path"] if entry else None

    def sprite(self, name: str) -> Path | None:
        entry = self.manifest["sprites"].get(name)
        return self.root / entry["path"] if entry else None

    def font(self, name: str) -> Path | None:
        entry = self.manifest["fonts"].get(name)
        return self.root / entry["path"] if entry else None

    @property
    def rarity_path(self) -> Path:
        return self.root / "item-rarity.json"


def pixel_sha(image) -> str:
    """Encoder-independent image identity (PNG bytes differ between Pillow/zlib versions)."""
    rgba = image.convert("RGBA")
    return hashlib.sha256(f"{rgba.size}".encode() + rgba.tobytes()).hexdigest()


def _file_sha(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def _bundle_file(resources: Path, name: str) -> Path | None:
    for folder in ("GameData", "Preload"):
        path = resources / folder / "Windows" / name
        if path.is_file():
            return path
    return None


def _stat(path: Path) -> list:
    info = path.stat()
    return [path.name, info.st_size, info.st_mtime_ns]


def _targets(catalog: AddressablesCatalog, rarity: dict[str, Any]) -> dict[str, tuple[str, str]]:
    """identity -> (kind, address): the snapshot's icons plus newer icons only the catalog knows (D24)."""
    targets = {}
    for kind, table in (("items", rarity.get("items", {})), ("equipment", rarity.get("equipment", {}))):
        for identity, row in table.items():
            targets[identity] = (kind, row["icon_path"].lower())
    known = {address for _, address in targets.values()}
    for folder, kind in ICON_FOLDERS.items():
        for address in catalog.addresses(folder):
            name = address.rsplit("/", 1)[-1]
            if address not in known and name.startswith(ICON_PREFIXES):
                targets.setdefault(f"@{name}", (kind, address))  # proper case comes from the texture name
    return targets


def extract(game_dir: Path, out_root: Path, rarity_path: Path,
            progress: Callable[[str, int, int | None], None] | None = None, *,
            cancelled: Callable[[], bool] | None = None, force: bool = False) -> AssetCache:
    started = time.monotonic()
    resources = resource_dir(game_dir)
    catalog_path = resources / "Catalog" / "Windows" / "catalog_Windows.bytes"
    if not catalog_path.is_file():
        raise AssetExtractFailed(f"no client catalog under {game_dir}")
    if not Path(rarity_path).is_file():
        raise AssetExtractFailed("rarity snapshot is missing")
    try:
        import UnityPy  # noqa: F401 - checked before any work
    except ImportError as exc:
        raise AssetExtractFailed("UnityPy is not installed") from exc
    catalog_sha = _file_sha(catalog_path)
    out_root = Path(out_root)
    target = out_root / catalog_sha[:16]
    backup = target.with_name('.previous-' + target.name)
    if not target.exists() and backup.exists():
        os.replace(backup, target)
    from core.asset_preparation_cache import game_identity, validated_cache
    initial_identity = game_identity(Path(game_dir), 'user')
    revision = initial_identity['bundle_revision']
    initial_rarity_sha = _file_sha(Path(rarity_path))
    current = validated_cache(target, catalog_sha, Path(rarity_path), revision)
    if current is not None and not force:
        return current
    def notify(stage, done, total):
        _check_cancel(cancelled)
        if progress:
            progress(stage, done, total)
    previous_root, previous = _previous_cache(out_root, target)
    catalog = AddressablesCatalog(catalog_path.read_bytes())
    rarity = json.loads(Path(rarity_path).read_text(encoding="utf-8"))
    staging = out_root / f".staging-{catalog_sha[:16]}"
    shutil.rmtree(staging, ignore_errors=True)
    for folder in ("icons/items", "icons/equipment", "sprites", "fonts"):
        (staging / folder).mkdir(parents=True, exist_ok=True)
    manifest: dict[str, Any] = {"extractor_version": EXTRACTOR_VERSION, "client": "KR/Steam", "catalog_sha256": catalog_sha,
                                "bundle_revision": revision,
                                "icons": {}, "sprites": {}, "fonts": {}, "bundles": {}, "missing": [], "reused_bundles": 0,
                                "reused_files": 0}
    try:
        _extract_icons(catalog, rarity, resources, staging, manifest, previous_root, previous, notify, cancelled)
        _extract_sprites(catalog, resources, staging, manifest, previous_root, previous, notify, cancelled)
        _extract_fonts(resources, staging, manifest, previous_root, previous, notify, cancelled)
        _check_cancel(cancelled)
        shutil.copyfile(rarity_path, staging / "item-rarity.json")
        manifest["rarity_sha256"] = _file_sha(staging / "item-rarity.json")
        if not manifest["icons"] or len(manifest["sprites"]) < len(ATLAS_SPRITES) + 1 or len(manifest["fonts"]) < len(FONTS):
            raise AssetExtractFailed(f"incomplete extraction: icons={len(manifest['icons'])} sprites={len(manifest['sprites'])} fonts={len(manifest['fonts'])}")
        manifest["seconds"] = round(time.monotonic() - started, 1)
        (staging / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
        if game_identity(Path(game_dir), 'user') != initial_identity or _file_sha(Path(rarity_path)) != initial_rarity_sha:
            raise AssetExtractFailed('client or rarity snapshot changed during preparation')
        if any(_bundle_file(resources, name) is None or _stat(_bundle_file(resources, name)) != value
               for name, value in manifest['bundles'].items()):
            raise AssetExtractFailed('client bundles changed during preparation')
        if validated_cache(staging, catalog_sha, Path(rarity_path), revision) is None:
            raise AssetExtractFailed('staged cache failed identity validation')
        _check_cancel(cancelled)
        _publish_cache(staging, target)
    except AssetExtractFailed:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    except Exception as exc:  # a damaged or changed client must not stop a scan
        shutil.rmtree(staging, ignore_errors=True)
        raise AssetExtractFailed(f"{type(exc).__name__}: {exc}") from exc
    if previous_root is not None and previous_root != target:
        shutil.rmtree(previous_root, ignore_errors=True)
    return AssetCache(target, manifest)


def _check_cancel(cancelled):
    if cancelled and cancelled():
        raise AssetExtractFailed('asset preparation cancelled')


def _publish_cache(staging, target):
    """Restore the previous target if publishing the staged tree fails."""
    backup = target.with_name('.previous-' + target.name)
    if backup.exists():
        if not target.exists():
            os.replace(backup, target)
        else:
            shutil.rmtree(backup)
    moved = target.exists()
    if moved:
        os.replace(target, backup)
    try:
        os.replace(staging, target)
    except BaseException:
        if moved:
            os.replace(backup, target)
        raise
    if moved:
        shutil.rmtree(backup, ignore_errors=True)


def _load_manifest(root: Path) -> dict[str, Any] | None:
    try:
        return json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def _previous_cache(out_root: Path, target: Path) -> tuple[Path | None, dict[str, Any] | None]:
    if not out_root.is_dir():
        return None, None
    caches = [(path, _load_manifest(path)) for path in out_root.iterdir() if path.is_dir() and not path.name.startswith(".")]
    caches = [(path, manifest) for path, manifest in caches if manifest and manifest.get("extractor_version") == EXTRACTOR_VERSION]
    if not caches:
        return None, None
    return max(caches, key=lambda item: (item[0] == target, item[0].stat().st_mtime))


def _reuse(bundle_stat: list, section: dict, names, previous_root: Path | None, previous: dict | None, staging: Path) -> dict | None:
    """Copy this bundle's entries from the previous cache when the bundle file is unchanged."""
    if previous is None or previous.get("bundles", {}).get(bundle_stat[0]) != bundle_stat:
        return None
    from core.asset_preparation_cache import entry_path
    try:
        entries = {name: previous[section].get(name) for name in names}
        if any(entry is None or _file_sha(entry_path(previous_root, entry['path'])) != entry.get('sha256')
               for entry in entries.values()):
            return None
        for entry in entries.values():
            entry_path(staging, entry['path'])
    except (KeyError, TypeError, ValueError, OSError):
        return None
    for entry in entries.values():
        _link_or_copy(previous_root / entry["path"], staging / entry["path"])
    return entries


def _link_or_copy(source: Path, destination: Path) -> None:
    """Hard links keep an unchanged file without copying or re-reading it (live: 1345 copies took 9 s,
    almost all in file opens); the previous cache stays intact until the new one is complete."""
    try:
        os.link(source, destination)
    except OSError:
        shutil.copyfile(source, destination)


def _save_png(image, staging: Path, relative: str) -> dict[str, Any]:
    buffer = io.BytesIO()
    image.save(buffer, "PNG")
    (staging / relative).write_bytes(buffer.getvalue())
    return {"path": relative, "size": list(image.size), "pixel_sha256": pixel_sha(image),
            "sha256": hashlib.sha256(buffer.getvalue()).hexdigest()}


def _extract_icons(catalog, rarity, resources, staging, manifest, previous_root, previous, progress, cancelled=None) -> None:
    import UnityPy
    by_bundle: dict[str, dict[str, tuple[str, str]]] = {}
    for identity, (kind, address) in _targets(catalog, rarity).items():
        bundle = catalog.bundle_for(address)
        if bundle is None:
            manifest["missing"].append(identity)
            continue
        by_bundle.setdefault(bundle, {})[address.rsplit("/", 1)[-1]] = (identity, kind)
    for done, (bundle, wanted) in enumerate(sorted(by_bundle.items()), 1):
        if progress:
            progress("icons", done - 1, len(by_bundle))
        path = _bundle_file(resources, bundle)
        if path is None:
            manifest["missing"].extend(identity for identity, _ in wanted.values())
            continue
        stat = _stat(path)
        manifest["bundles"][bundle] = stat
        known = [identity for identity, _ in wanted.values() if not identity.startswith("@")]
        reused = _reuse(stat, "icons", [*known, *(name for name, entry in (previous or {}).get("icons", {}).items()
                                                  if entry.get("bundle") == bundle and name not in known)],
                        previous_root, previous, staging) if previous else None
        if reused is not None:
            manifest["icons"].update(reused)
            manifest["reused_bundles"] += 1
            manifest['reused_files'] += len(reused)
            continue
        found = set()
        for obj in UnityPy.load(str(path)).objects:
            _check_cancel(cancelled)
            if obj.type.name != "Texture2D":
                continue
            texture = obj.read()
            name = texture.m_Name.lower()
            if name not in wanted or name in found:
                continue
            identity, kind = wanted[name]
            identity = texture.m_Name if identity.startswith("@") else identity
            entry = _save_png(texture.image, staging, f"icons/{kind}/{identity}.png")
            entry.update(kind=kind, bundle=bundle, path_id=obj.path_id, snapshot=not wanted[name][0].startswith("@"))
            manifest["icons"][identity] = entry
            found.add(name)
        manifest["missing"].extend(identity for name, (identity, _) in wanted.items() if name not in found)
    progress('icons', len(by_bundle), len(by_bundle))


def _extract_sprites(catalog, resources, staging, manifest, previous_root, previous, progress, cancelled=None) -> None:
    import UnityPy
    names = [*ATLAS_SPRITES]
    atlas_found = False
    progress('sprites', 0, None)
    inspected = 0
    for path in sorted((resources / "Preload" / "Windows").glob(ATLAS_BUNDLE_GLOB)):
        progress('sprites', inspected, None)
        inspected += 1
        stat = _stat(path)
        reused = _reuse(stat, "sprites", names, previous_root, previous, staging) if previous else None
        if reused is not None and all(entry.get("bundle") == path.name for entry in reused.values()):
            manifest["sprites"].update(reused)
            manifest["bundles"][path.name] = stat
            manifest["reused_bundles"] += 1
            manifest['reused_files'] += len(reused)
            atlas_found = True
            break
        env = UnityPy.load(str(path))
        atlas = None
        for obj in env.objects:
            _check_cancel(cancelled)
            if obj.type.name == "MonoBehaviour":
                try:
                    tree = obj.read_typetree()
                except Exception:
                    continue
                if tree.get("m_Name") == ATLAS_NAME and "mSprites" in tree:
                    atlas = tree
                    break
        if atlas is None:
            continue
        texture = next((obj.read() for obj in env.objects if obj.type.name == "Texture2D" and obj.read().m_Name == ATLAS_NAME), None)
        if texture is None:
            continue
        image = texture.image
        rects = {sprite["name"]: sprite for sprite in atlas["mSprites"]}
        for name in names:
            _check_cancel(cancelled)
            sprite = rects.get(name)
            if sprite is None:
                manifest["missing"].append(f"sprite:{name}")
                continue
            crop = image.crop((sprite["x"], sprite["y"], sprite["x"] + sprite["width"], sprite["y"] + sprite["height"]))
            entry = _save_png(crop, staging, f"sprites/{name}.png")
            entry.update(bundle=path.name, rect=[sprite["x"], sprite["y"], sprite["width"], sprite["height"]])
            manifest["sprites"][name] = entry
        manifest["bundles"][path.name] = stat
        atlas_found = True
        break
    if not atlas_found:
        manifest["missing"].append(f"atlas:{ATLAS_NAME}")
    # Blueprint card background (UITexture Card_Bg_Gear) is its own texture.
    bundle = catalog.bundle_for(BLUEPRINT_KEY)
    progress('sprites', inspected, None)
    inspected += 1
    path = _bundle_file(resources, bundle) if bundle else None
    if path is None:
        manifest["missing"].append("sprite:Card_Item_Bg_C")
        return
    stat = _stat(path)
    reused = _reuse(stat, "sprites", ["Card_Item_Bg_C"], previous_root, previous, staging) if previous else None
    if reused is not None:
        manifest["sprites"].update(reused)
        manifest['reused_files'] += len(reused)
    else:
        texture = next((obj.read() for obj in UnityPy.load(str(path)).objects
                        if obj.type.name == "Texture2D" and obj.read().m_Name == "Card_Item_Bg_C"), None)
        if texture is None:
            manifest["missing"].append("sprite:Card_Item_Bg_C")
            return
        entry = _save_png(texture.image, staging, "sprites/Card_Item_Bg_C.png")
        entry["bundle"] = bundle
        manifest["sprites"]["Card_Item_Bg_C"] = entry
    manifest["bundles"][bundle] = stat
    progress('sprites', inspected, inspected)


def _extract_fonts(resources, staging, manifest, previous_root, previous, progress, cancelled=None) -> None:
    import UnityPy
    wanted = {unity: name for name, unity in FONTS.items()}
    progress('fonts', 0, None)
    inspected = 0
    for path in sorted((resources / "Preload" / "Windows").glob(FONT_BUNDLE_GLOB)):
        progress('fonts', inspected, None)
        inspected += 1
        stat = _stat(path)
        reused = _reuse(stat, "fonts", list(FONTS), previous_root, previous, staging) if previous else None
        if reused is not None and all(entry.get("bundle") == path.name for entry in reused.values()):
            manifest["fonts"].update(reused)
            manifest["bundles"][path.name] = stat
            manifest['reused_files'] += len(reused)
            progress('fonts', inspected, inspected)
            return
        found = {}
        for obj in UnityPy.load(str(path)).objects:
            _check_cancel(cancelled)
            if obj.type.name != "Font":
                continue
            font = obj.read()
            if font.m_Name in wanted and font.m_FontData:
                data = bytes(font.m_FontData)
                relative = f"fonts/{wanted[font.m_Name]}.ttf"
                (staging / relative).write_bytes(data)
                found[wanted[font.m_Name]] = {"path": relative, "sha256": hashlib.sha256(data).hexdigest(),
                                              "unity_name": font.m_Name, "bundle": path.name}
        if found:
            manifest["fonts"].update(found)
            manifest["bundles"][path.name] = stat
        if len(manifest["fonts"]) == len(FONTS):
            progress('fonts', inspected, inspected)
            return
    manifest["missing"].extend(f"font:{name}" for name in FONTS if name not in manifest["fonts"])
    progress('fonts', inspected, inspected)
