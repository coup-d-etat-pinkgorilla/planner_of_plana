from __future__ import annotations

from copy import deepcopy
import itertools
import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "contracts/animation-spectrum-v1.schema.json"
FIXTURE_PATH = ROOT / "contracts/fixtures/animation-spectrum/binah-sample.json"
BUNDLE_PATH = (
    "BlueArchive_Data/StreamingAssets/AssetBundles/"
    "assets-_mx-npcs-binah_original-_mxdependency-animationclips-2025-07-02_assets_all_57421249.bundle"
)


class AnimationSpectrumContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
        cls.fixture = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
        cls.validator = Draft202012Validator(cls.schema)

    def assert_valid(self, value: dict) -> None:
        errors = list(self.validator.iter_errors(value))
        self.assertEqual([], [error.message for error in errors])

    def assert_invalid(self, value: dict) -> None:
        self.assertTrue(list(self.validator.iter_errors(value)))

    def assert_event_conversion(self, event: dict, *, inferred: bool) -> None:
        """Semantic oracle for the contract; JSON Schema only validates shape."""
        exact_frame = event["timeSeconds"] * 30
        self.assertEqual(round(exact_frame), event["frame"])
        if inferred or abs(exact_frame - event["frame"]) >= 0.5:
            self.assertTrue(event["estimated"])

    def test_schema_is_valid_draft_2020_12_and_fixture_matches(self) -> None:
        self.assertEqual("https://json-schema.org/draft/2020-12/schema", self.schema["$schema"])
        Draft202012Validator.check_schema(self.schema)
        self.assert_valid(self.fixture)

    def test_binah_identity_and_source_pins_are_preserved(self) -> None:
        self.assertEqual(7300700, self.fixture["characterId"])
        self.assertEqual("boss", self.fixture["kind"])
        self.assertEqual("Binah_default_Torment", self.fixture["devName"])
        self.assertEqual({"ko": "비나", "ja": "ビナー"}, self.fixture["names"])
        self.assertEqual("jp-1.73.0-e2baf70e", self.fixture["clientVersionId"])
        self.assertEqual({
            "excelDb": "a5cfbbb9c7f00ccdd82a59e100febb7ed5eb107bc8ac93c6ed0dede14418416a",
            "excelZip": "f9e8e721c14486a1517b627799ea03122aaa39da4f024eda3da1da7c8347c97b",
            "bundles": [{
                "path": BUNDLE_PATH,
                "sha256": "b1ab8d7bce6221bd056c07893b7b97d376ceb4fb335baa764e1d4dccb3062593",
            }],
        }, self.fixture["sourceHashes"])

    def test_two_t3_clips_keep_observed_lengths_and_unknown_logic_duration(self) -> None:
        expected = [
            ("Binah_Original_Normal_Attack", 4.6666669845581055, 140, 6613088364977800608),
            ("Binah_Original_Vital_Groggy", 11.333333969116211, 340, -5953471448818496541),
        ]
        self.assertEqual(2, len(self.fixture["clips"]))
        for clip, (name, seconds, frames, path_id) in zip(self.fixture["clips"], expected):
            with self.subTest(clip=name):
                self.assertEqual(name, clip["name"])
                self.assertEqual(30, clip["sourceFps"])
                self.assertEqual(BUNDLE_PATH, clip["bundlePath"])
                self.assertEqual(seconds, clip["lengthSeconds"])
                self.assertEqual(frames, clip["lengthLogicFrames"])
                self.assertEqual(round(seconds * 30), frames)
                self.assertIsNone(clip["logicDurationFrames"])
                locator = f"{BUNDLE_PATH}#AnimationClip[name={name};PathID={path_id}]"
                for event in clip["events"]:
                    self.assertEqual(locator, event["evidence"]["clipPath"])
                    self.assertIn("logicDurationFrames is unknown", event["note"])
                    self.assertIn("does not establish a Torment EX mapping", event["note"])

    def test_all_five_observed_callbacks_keep_exact_float_times_and_inference(self) -> None:
        expected = [
            [("PlayAudio", 0.1666666716337204, 5, "sfx"),
             ("PlayAudio", 1.6666666269302368, 50, "sfx")],
            [("InstantiateFx", 0.0, 0, "vfx"),
             ("PlayAudio", 0.4333333373069763, 13, "sfx"),
             ("PlayAudio", 8.833333015441895, 265, "sfx")],
        ]
        self.assertEqual(5, sum(len(clip["events"]) for clip in self.fixture["clips"]))
        for clip, expected_events in zip(self.fixture["clips"], expected):
            self.assertEqual(expected_events, [
                (event["name"], event["timeSeconds"], event["frame"], event["kind"])
                for event in clip["events"]
            ])
            for event in clip["events"]:
                self.assertEqual("anim_event", event["layer"])
                self.assertEqual("observation", event["evidence"]["kind"])
                self.assertNotIn("rowSha", event["evidence"])
                self.assertNotIn("rva", event["evidence"])
                self.assertLess(abs(event["timeSeconds"] * 30 - event["frame"]), 0.5)
                self.assertIn("inferred", event["note"])
                self.assertIn("No rowSha/rva", event["note"])
                self.assert_event_conversion(event, inferred=True)

    def test_required_fields_cannot_be_removed_at_any_level(self) -> None:
        paths = [(), ("names",), ("sourceHashes",), ("sourceHashes", "bundles", 0),
                 ("clips", 0), ("clips", 0, "events", 0), ("clips", 0, "events", 0, "evidence")]
        for path in paths:
            original = self.fixture
            for part in path:
                original = original[part]
            required = set(original)
            if path == ("clips", 0, "events", 0, "evidence"):
                required = {"kind", "clipPath"}
            for key in required:
                with self.subTest(path=path, key=key):
                    value = deepcopy(self.fixture)
                    target = value
                    for part in path:
                        target = target[part]
                    del target[key]
                    self.assert_invalid(value)

    def test_unapproved_fields_and_top_level_version_are_rejected(self) -> None:
        paths = [(), ("names",), ("sourceHashes",), ("sourceHashes", "bundles", 0),
                 ("clips", 0), ("clips", 0, "events", 0), ("clips", 0, "events", 0, "evidence")]
        for path in paths:
            with self.subTest(path=path):
                value = deepcopy(self.fixture)
                target = value
                for part in path:
                    target = target[part]
                target["unexpected"] = 1
                self.assert_invalid(value)
        for key in ("format", "version"):
            value = deepcopy(self.fixture)
            value[key] = 1
            self.assert_invalid(value)

    def test_fixed_character_layer_event_and_evidence_enums(self) -> None:
        groups = [
            ((), "kind", ["student", "boss"]),
            (("clips", 0, "events", 0), "layer", ["anim_event", "logic_effect"]),
            (("clips", 0, "events", 0), "kind",
             ["fire", "hit", "vfx", "sfx", "damage", "buff", "debuff", "groggy", "summon", "other"]),
            (("clips", 0, "events", 0, "evidence"), "kind",
             ["table", "code", "observation", "knowledge", "unknown"]),
        ]
        for path, key, allowed in groups:
            for replacement in allowed + ["unsupported", None, 1]:
                with self.subTest(path=path, value=replacement):
                    value = deepcopy(self.fixture)
                    target = value
                    for part in path:
                        target = target[part]
                    target[key] = replacement
                    self.assertEqual(replacement in allowed, self.validator.is_valid(value))

    def test_sha256_fields_reject_short_uppercase_and_nonhex_values(self) -> None:
        paths = [("sourceHashes", "excelDb"), ("sourceHashes", "excelZip"),
                 ("sourceHashes", "bundles", 0, "sha256"),
                 ("clips", 0, "events", 0, "evidence", "rowSha")]
        for path in paths:
            for replacement in ("a" * 63, "a" * 65, "a" * 64 + "\n", "A" * 64, "g" * 64, None, 123):
                with self.subTest(path=path, value=replacement):
                    value = deepcopy(self.fixture)
                    target = value
                    for part in path[:-1]:
                        target = target[part]
                    target[path[-1]] = replacement
                    self.assert_invalid(value)

    def test_evidence_requires_a_location_and_allows_combinations(self) -> None:
        locations = {"table": "SkillLogic[verified-row]", "symbol": "Verified.Type.Method",
                     "clipPath": "verified-bundle#AnimationClip[name=clip;PathID=1]"}
        for count in range(1, 4):
            for keys in itertools.combinations(locations, count):
                value = deepcopy(self.fixture)
                value["clips"][0]["events"][0]["evidence"] = {
                    "kind": "table", **{key: locations[key] for key in keys},
                    "rowSha": "a" * 64, "rva": "0x1338160",
                }
                self.assert_valid(value)
        for evidence in ({"kind": "unknown"}, {"kind": "code", "rva": "0x1"},
                         {"kind": "table", "rowSha": "a" * 64},
                         {"kind": "observation", "clipPath": ""}):
            value = deepcopy(self.fixture)
            value["clips"][0]["events"][0]["evidence"] = evidence
            self.assert_invalid(value)

    def test_rva_is_a_hexadecimal_string_when_present(self) -> None:
        for rva in ("0x0", "0x1338160", "0xABCDEF", "0x1\n", 123, "1338160", "0x", "0xno", None):
            with self.subTest(rva=rva):
                value = deepcopy(self.fixture)
                value["clips"][0]["events"][0]["evidence"]["rva"] = rva
                self.assertEqual(rva in ("0x0", "0x1338160", "0xABCDEF"), self.validator.is_valid(value))

    def test_time_frame_fps_and_identity_types_and_bounds(self) -> None:
        invalid = [
            (("characterId",), "7300700"), (("characterId",), True), (("characterId",), 1.5),
            (("clips", 0, "sourceFps"), 0), (("clips", 0, "sourceFps"), -30),
            (("clips", 0, "sourceFps"), True), (("clips", 0, "lengthSeconds"), -1),
            (("clips", 0, "lengthLogicFrames"), -1), (("clips", 0, "lengthLogicFrames"), 1.5),
            (("clips", 0, "logicDurationFrames"), 1.5), (("clips", 0, "logicDurationFrames"), "-1"),
            (("clips", 0, "events", 0, "timeSeconds"), -0.1),
            (("clips", 0, "events", 0, "frame"), -1), (("clips", 0, "events", 0, "frame"), 1.5),
            (("clips", 0, "events", 0, "estimated"), "true"),
        ]
        for path, replacement in invalid:
            with self.subTest(path=path, value=replacement):
                value = deepcopy(self.fixture)
                target = value
                for part in path[:-1]:
                    target = target[part]
                target[path[-1]] = replacement
                self.assert_invalid(value)

    def test_signed_logic_duration_sentinels_do_not_replace_clip_length(self) -> None:
        for duration in (-1, 2147483647, 0, 198, None):
            with self.subTest(duration=duration):
                value = deepcopy(self.fixture)
                clip = value["clips"][0]
                clip["logicDurationFrames"] = duration
                clip["events"][0]["note"] = f"Raw logic Duration {duration}; preserve sentinel separately from motion length."
                self.assert_valid(value)
                self.assertEqual(140, clip["lengthLogicFrames"])
                self.assertEqual(4.6666669845581055, clip["lengthSeconds"])

    def test_logic_effect_after_motion_end_is_allowed(self) -> None:
        value = deepcopy(self.fixture)
        event = value["clips"][0]["events"][0]
        event.update(frame=707, timeSeconds=707 / 30, layer="logic_effect", kind="damage",
                     estimated=True, note="Synthetic contract case: inferred effect continues after motion end.")
        self.assert_valid(value)
        self.assert_event_conversion(event, inferred=True)
        self.assertGreater(event["frame"], value["clips"][0]["lengthLogicFrames"])

    def test_semantic_conversion_uses_30fps_ties_to_even_and_estimated_threshold(self) -> None:
        # Synthetic policy cases, not additional Binah observations or logic mappings.
        for seconds, frame, estimated in ((0.25, 8, True), (0.75, 22, True), (0.1, 3, False)):
            value = deepcopy(self.fixture)
            value["clips"][0]["sourceFps"] = 60
            event = value["clips"][0]["events"][0]
            event.update(timeSeconds=seconds, frame=frame, estimated=estimated,
                         note="Synthetic exact-time policy case, independent of clip sampling rate.")
            self.assert_valid(value)
            self.assert_event_conversion(event, inferred=False)
            if estimated:
                event["estimated"] = False
                self.assert_valid(value)  # Cross-field arithmetic is outside JSON Schema.
                with self.assertRaises(AssertionError):
                    self.assert_event_conversion(event, inferred=False)
        wrong = deepcopy(self.fixture["clips"][0]["events"][0])
        wrong.update(timeSeconds=0.75, frame=23, estimated=True)
        with self.assertRaises(AssertionError):
            self.assert_event_conversion(wrong, inferred=False)


if __name__ == "__main__":
    unittest.main()
