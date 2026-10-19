"""C5e-6a-0 (D24): local asset extraction from the user's Steam client."""
import io
import json
from pathlib import Path
import struct
import tempfile
import time
import unittest
from unittest.mock import patch
import zipfile

from PIL import Image

import core.recognition_asset_extract as extractor
from core.recognition_asset_extract import AddressablesCatalog, AssetExtractFailed, extract, find_game_dir, pixel_sha

BACKEND = Path(__file__).resolve().parents[1]
PACK = BACKEND / "assets/recognition/asset_pack"
RARITY = BACKEND / "assets/recognition/spec/item-rarity-v1.json"


def varint_blob(data: bytes) -> bytes:
    length, out = len(data), b""
    while True:
        byte = length & 0x7F
        length >>= 7
        out += bytes([byte | (0x80 if length else 0)])
        if not length:
            return out + data


def ccdb(addresses: dict[str, str]) -> bytes:
    """A CCDB v1 catalog: each address -> one bundle dependency."""
    internal = []
    keys = []
    for address, bundle in addresses.items():
        internal += [f"Assets/{address}.png", "{PlatformUtils.AddressableLoadPath}\\\\" + bundle]
        keys += [address, bundle]
    key_block = struct.pack("<I", len(keys)) + b"".join(
        bytes([0]) + struct.pack("<I", len(key.encode())) + key.encode() for key in keys)
    # buckets: key i -> entry i; entries: (internalId, provider, dependencyKey, hash, data, primaryKey, type)
    bucket_block = struct.pack("<I", len(keys)) + b"".join(struct.pack("<III", 0, 1, index) for index in range(len(keys)))
    entries = []
    for index in range(len(keys)):
        dependency = index + 1 if index % 2 == 0 else -1
        entries.append(struct.pack("<7i", index, 0, dependency, 0, -1, index, 0))
    entry_block = struct.pack("<I", len(entries)) + b"".join(entries)
    body = b"CCDB\x01" + varint_blob(b"locator") + varint_blob(b"{}") + varint_blob(b"{}")
    body += struct.pack("<I", 0)  # resource providers
    body += struct.pack("<I", 1) + varint_blob(b"BundledAssetProvider")
    body += struct.pack("<I", len(internal)) + b"".join(varint_blob(text.encode()) for text in internal)
    for block in (key_block, bucket_block, entry_block):
        body += struct.pack("<I", len(block)) + block
    return body + struct.pack("<I", 0)


class CatalogTests(unittest.TestCase):
    def test_compact_catalog_resolves_an_address_to_its_bundle(self):
        catalog = AddressablesCatalog(ccdb({"uis/01_common/03_nonequipment/item_icon_a": "icons_1.bundle",
                                            "uis/00_images/card_item_bg_c": "images_2.bundle"}))
        self.assertEqual("icons_1.bundle", catalog.bundle_for("UIs/01_Common/03_NonEquipment/Item_Icon_A"))
        self.assertEqual("images_2.bundle", catalog.bundle_for("uis/00_images/card_item_bg_c"))
        self.assertIsNone(catalog.bundle_for("uis/missing"))
        self.assertEqual(["uis/01_common/03_nonequipment/item_icon_a"], catalog.addresses("uis/01_common/03_"))

    def test_damaged_catalog_is_asset_extract_failed(self):
        for data in (b"JSON{}", ccdb({"a": "b"})[:-40]):
            with self.subTest(size=len(data)):
                with self.assertRaises(AssetExtractFailed) as exc:
                    AddressablesCatalog(data)
                self.assertEqual("asset_extract_failed", exc.exception.code)


class GameFolderTests(unittest.TestCase):
    def test_library_folders_and_app_manifest_locate_the_client(self):
        with tempfile.TemporaryDirectory() as root:
            steam, library = Path(root) / "Steam", Path(root) / "Games"
            (steam / "steamapps").mkdir(parents=True)
            (steam / "steamapps/libraryfolders.vdf").write_text(
                '"libraryfolders"\n{\n "0" { "path" "%s" }\n "1" { "path" "%s" }\n}\n'
                % (str(steam).replace("\\", "\\\\"), str(library).replace("\\", "\\\\")), encoding="utf-8")
            (library / "steamapps").mkdir(parents=True)
            (library / "steamapps/appmanifest_3557620.acf").write_text('"AppState"\n{\n "installdir" "BA Client"\n}\n', encoding="utf-8")
            self.assertIsNone(find_game_dir(steam))  # catalog not there yet
            catalog = extractor.resource_dir(library / "steamapps/common/BA Client") / "Catalog/Windows/catalog_Windows.bytes"
            catalog.parent.mkdir(parents=True)
            catalog.write_bytes(b"CCDB\x01")
            self.assertEqual(library / "steamapps/common/BA Client", find_game_dir(steam))

    def test_missing_client_or_snapshot_fails_without_touching_the_cache(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaises(AssetExtractFailed):
                extract(Path(root) / "nowhere", Path(root) / "cache", RARITY)
            self.assertFalse((Path(root) / "cache").exists())


GAME = find_game_dir()


@unittest.skipUnless(GAME and PACK.is_dir() and RARITY.is_file(), "local Steam client and development asset pack required")
class LiveClientAnswerKeyTests(unittest.TestCase):
    """Answer key (workflow 6a-0): extraction from this PC's client equals the development pack."""

    def test_extraction_matches_the_pack_and_updates_incrementally(self):
        with tempfile.TemporaryDirectory() as root:
            started = time.monotonic()
            cache = extract(GAME, Path(root), RARITY)
            first = time.monotonic() - started
            pack = json.loads((PACK / "manifest.json").read_text(encoding="utf-8"))
            archives = {}
            for archive in PACK.glob("icons-*.zip"):
                handle = zipfile.ZipFile(archive)
                for member in handle.namelist():
                    archives[member] = handle
            # PNG bytes depend on the encoder; decoded pixels are the identity.
            for identity, entry in pack["icons"].items():
                with Image.open(io.BytesIO(archives[entry["path"]].read(entry["path"]))) as image:
                    self.assertEqual(pixel_sha(image), cache.manifest["icons"][identity]["pixel_sha256"], identity)
            for name, entry in pack["sprites"].items():
                with Image.open(PACK / entry["path"]) as image:
                    self.assertEqual(pixel_sha(image), cache.manifest["sprites"][name]["pixel_sha256"], name)
            for name, entry in pack["fonts"].items():
                self.assertEqual(entry["sha256"], cache.manifest["fonts"][name]["sha256"])
            self.assertEqual([], cache.manifest["missing"])
            self.assertLess(first, 60)
            # A new catalog with the same bundles opens no bundle again.
            real = extractor._file_sha
            with patch.object(extractor, "_file_sha", side_effect=lambda path: "f" * 64 if path.name == "catalog_Windows.bytes" else real(path)):
                updated = extract(GAME, Path(root), RARITY)
            self.assertEqual(len(cache.manifest["bundles"]) - 1, updated.manifest["reused_bundles"])  # font bundle is not counted
            self.assertEqual({k: v["pixel_sha256"] for k, v in cache.manifest["icons"].items()},
                             {k: v["pixel_sha256"] for k, v in updated.manifest["icons"].items()})
            self.assertFalse(cache.root.exists())
            self.assertTrue(updated.icon("Item_Icon_SkillBook_Ultimate").is_file())


if __name__ == "__main__":
    unittest.main()
