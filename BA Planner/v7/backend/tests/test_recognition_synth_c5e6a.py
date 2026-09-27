"""C5e-6a: synthetic templates reproduce real tiles, detail icons and count glyphs (E4/E3/E5)."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

from core.inventory_detail_recovery import InventoryDetailRecognizer
from core.inventory_navigation import InventoryNavigation
from core.recognition_asset_extract import AssetCache, extract, find_game_dir
from core.recognition_assets import RecognitionAssetCatalog
from core.recognition_image_ops import icon_vector_similarity, icon_vectors, ncc_unit_bilinear
from core.recognition_synth import (DETAIL_ROI, SynthUnavailable, glyph_em_candidates, ink_map, normalize_detail,
                                    normalize_tile, render_glyphs, synthesize, ui_scale)

BACKEND = Path(__file__).resolve().parents[1]
V7 = BACKEND.parent
RARITY = BACKEND / "assets/recognition/spec/item-rarity-v1.json"
TECH_NOTES = V7 / "debug/scanner_c5_live/tech-notes-full-c"
FRAMES = ["frame-12.png", "frame-92.png", "frame-117.png", "frame-142.png", "frame-167.png", "frame-192.png"]
DETAIL_RUN = V7 / "debug/scanner_c5e1d_live/tech_notes"
GAME = find_game_dir()
LIVE = bool(GAME and RARITY.is_file())


class ScaleAndFailureTests(unittest.TestCase):
    def test_ngui_scale_for_16_9_and_4_3(self):
        self.assertAlmostEqual(720 / 1665, ui_scale(1280, 720))
        self.assertAlmostEqual(1440 / 1665, ui_scale(2560, 1440))
        self.assertAlmostEqual(1280 / 2960, ui_scale(1280, 960), places=4)
        self.assertEqual((19, 20, 21), glyph_em_candidates((1280, 720)))

    def test_missing_inputs_are_synth_unavailable(self):
        with self.assertRaises(SynthUnavailable):
            synthesize(None, {}, profile="presents")
        with tempfile.TemporaryDirectory() as root:
            cache = AssetCache(Path(root), {"icons": {}, "sprites": {}, "fonts": {}})
            with self.assertRaises(SynthUnavailable) as exc:
                synthesize(cache, {"items": {}}, profile="presents", identities=[])
            self.assertIn("sprite", exc.exception.reason)


@unittest.skipUnless(LIVE, "local Steam client and rarity snapshot required")
class LiveSynthTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = tempfile.TemporaryDirectory()
        cls.cache = extract(GAME, Path(cls.root.name), RARITY)
        cls.rarity = json.loads(cls.cache.rarity_path.read_text(encoding="utf-8"))

    @classmethod
    def tearDownClass(cls):
        cls.root.cleanup()

    def test_synthesis_is_deterministic(self):
        ids = ["Item_Icon_SkillBook_Hyakkiyako_0", "Item_Icon_Favor_0"]
        first, second = (synthesize(self.cache, self.rarity, profile="presents", identities=ids) for _ in range(2))
        digest = lambda s: hashlib.sha256(b"".join(s.tiles[i].tobytes() + s.details[i].tobytes() for i in ids)
                                          + b"".join(g.tobytes() for size in s.glyphs.values() for g in size.values())).hexdigest()
        self.assertEqual(digest(first), digest(second))
        self.assertEqual(first.fingerprint, second.fingerprint)
        self.assertEqual({(96, 96)}, {tile.size for tile in first.tiles.values()})
        self.assertEqual({(128, 128)}, {detail.size for detail in first.details.values()})
        with self.assertRaises(SynthUnavailable):
            synthesize(self.cache, self.rarity, profile="presents", identities=["Item_Icon_Not_A_Thing"])

    def real_tiles(self):
        if not all((TECH_NOTES / name).is_file() for name in FRAMES):
            self.skipTest("tech-notes-full-c frames are local only")
        catalog = RecognitionAssetCatalog()
        detail = InventoryDetailRecognizer(catalog)
        nav = InventoryNavigation(None, catalog, detail)
        trace = json.loads((TECH_NOTES / "trace.json").read_text(encoding="utf-8"))
        entries = trace["result"]["candidates"][0]["payload"]["entries"]
        # D18: this recording's slot 44 was labelled with the secret-note piece; the tile is the secret note.
        label = {e["observed_slot"]: e["item_id"].replace("SkillBook_Ultimate_Piece", "SkillBook_Ultimate") for e in entries}
        quantity = {e["observed_slot"]: e["quantity"] for e in entries}
        cumulative = [0]
        for shift in [x["shift_px"] for x in trace["navigation_trace"] if "shift_px" in x and x["attempt"] == 1]:
            cumulative.append(cumulative[-1] + shift)
        tiles = []
        for page, name in enumerate(FRAMES):
            with Image.open(TECH_NOTES / name) as frame:
                frame = frame.convert("RGB")
                for top in nav.gutter_tops(frame, "item"):
                    if top + 95 > int(.8472 * 720) - 6:
                        continue
                    row = round((cumulative[page] + top - 159) / 101.5)
                    for col in range(5):
                        index = row * 5 + col
                        if index in label:
                            x1 = round((0.5387 + 0.0851 * col) * 1280) + 2
                            tiles.append((label[index], quantity[index], frame.crop((x1, top + 2, x1 + 98, top + 91)),
                                          frame.crop((x1 + 28, top + 64, x1 + 112, top + 96))))
        detail.close()
        nav.close()
        return tiles

    def test_e4_grid_tiles_match_real_tech_notes(self):
        tiles = self.real_tiles()
        synth = synthesize(self.cache, self.rarity, profile="tech_notes", glyph_sizes=())
        bank = {identity: icon_vectors(image) for identity, image in synth.tiles.items()}
        correct, true_scores = 0, []
        for identity, _quantity, crop, _strip in tiles:
            query = icon_vectors(normalize_tile(crop))
            best = max(bank, key=lambda other: icon_vector_similarity(query, bank[other]))
            correct += best == identity
            true_scores.append(icon_vector_similarity(query, bank[identity]))
        true_scores.sort()
        self.assertGreaterEqual(correct / len(tiles), .99)
        self.assertGreaterEqual(true_scores[len(true_scores) // 2], .95)

    def test_e3_detail_icons_match_real_detail_panels(self):
        frames = sorted(DETAIL_RUN.glob("frame-*.png"))[:40]
        if not frames:
            self.skipTest("detail frames are local only")
        reader = InventoryDetailRecognizer(RecognitionAssetCatalog())
        real = {}
        for path in frames:
            with Image.open(path) as frame:
                frame = frame.convert("RGB")
                if reader.classify(frame) != "item":
                    continue
                result = reader.read(frame, "item")
                if result.identity and result.score > .9 and result.identity not in real:
                    w, h = frame.size
                    real[result.identity] = frame.crop((round(DETAIL_ROI[0] * w), round(DETAIL_ROI[1] * h),
                                                        round(DETAIL_ROI[2] * w), round(DETAIL_ROI[3] * h)))
        reader.close()
        synth = synthesize(self.cache, self.rarity, profile="tech_notes", glyph_sizes=())
        bank = {identity: icon_vectors(image) for identity, image in synth.details.items()}
        self.assertGreaterEqual(len(real), 10)
        for identity, crop in real.items():
            query = icon_vectors(normalize_detail(crop))
            self.assertEqual(identity, max(bank, key=lambda other: icon_vector_similarity(query, bank[other])))

    def test_e5_count_glyphs_read_real_labels(self):
        tiles = self.real_tiles()
        font = self.cache.font("GyeonggiTitle-Bold")
        accuracy = {}
        for em in sorted(glyph_em_candidates((1280, 720))):
            glyphs = render_glyphs(font, em, ui_scale(1280, 720))
            total = correct = 0
            for _identity, quantity, _crop, strip in tiles:
                ink = _label(ink_map(strip), max(glyphs[c].height for c in "0123456789"))
                if ink is None or not quantity:
                    continue
                text = "x" + quantity
                widths = [glyphs[c].width for c in text]
                scale, x = ink.width / sum(widths), 0.0
                for char, width in zip(text, widths):
                    start, x = x, x + width * scale
                    if char == "x":
                        continue
                    total += 1
                    correct += _best_digit(ink, start, glyphs) == char
            accuracy[em] = correct / total
            if accuracy[em] >= .90:
                break
        self.assertGreaterEqual(max(accuracy.values()), .90, accuracy)


def _label(strip, digit_height, gap=4):
    """The count label: bottom-most band of strong ink rows, its rightmost run of columns (icon art sits further
    left), then the digit height from the bottom (art above can merge into the band), trimmed to its ink."""
    binary = strip.point(lambda v: 255 if v > 160 else 0)
    w, h = binary.size
    data = binary.tobytes()
    rows = [sum(1 for x in range(w) if data[y * w + x]) for y in range(h)]
    bottom = max((y for y in range(h) if rows[y] >= 2), default=None)
    if bottom is None:
        return None
    top = bottom
    while top > 0 and rows[top - 1] >= 2:
        top -= 1
    binary, strip = binary.crop((0, top, w, bottom + 1)), strip.crop((0, top, w, bottom + 1))
    data, h = binary.tobytes(), binary.height
    columns = [any(data[y * w + x] for y in range(h)) for x in range(w)]
    right = max((x for x in range(w) if columns[x]), default=None)
    left, blank = right, 0
    for x in range(right, -1, -1):
        if columns[x]:
            left, blank = x, 0
        else:
            blank += 1
            if blank > gap:
                break
    ink = strip.crop((left, 0, right + 1, h))
    if ink.height > digit_height:
        ink = ink.crop((0, ink.height - digit_height, ink.width, ink.height))
        box = ink.point(lambda v: 255 if v > 160 else 0).getbbox()
        ink = ink.crop((box[0], 0, box[2], ink.height)) if box else ink
    return ink


def _best_digit(ink, start, glyphs):
    scores = {}
    for digit, glyph in glyphs.items():
        if digit == "x":
            continue
        best = 0.0
        for dx in range(-3, 4):
            left = round(start + dx)
            if 0 <= left and left + glyph.width <= ink.width:
                best = max(best, ncc_unit_bilinear(ink.crop((left, 0, left + glyph.width, ink.height)), glyph))
        scores[digit] = best
    return max(scores, key=scores.get)


if __name__ == "__main__":
    unittest.main()
