from __future__ import annotations

import argparse
from itertools import product
import json
from pathlib import Path


LEVEL_CAPS = {
    "T1": 10,
    "T2": 20,
    "T3": 30,
    "T4": 40,
    "T5": 45,
    "T6": 50,
    "T7": 55,
    "T8": 60,
    "T9": 65,
    "T10": 70,
}

REPRESENTATIVES = (
    ("airi_band", ("Hat", "Hairpin", "Charm")),
    ("haruna_sportswear", ("Shoes", "Bag", "Necklace")),
    ("kanna", ("Gloves", "Badge", "Watch")),
)

VALIDATION_REPRESENTATIVES = (
    ("chihiro", ("Hat", "Badge", "Necklace")),
    ("marina_qipao", ("Gloves", "Hairpin", "Watch")),
    ("tsurugi_swimsuit", ("Shoes", "Bag", "Charm")),
)

COMPACT_REQUIRED_LEVELS = (
    *range(1, 10),
    *LEVEL_CAPS.values(),
    11, 12, 13, 14, 16, 17, 18, 19,
    23, 34, 56,
)


def _state_patterns() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    bands = (
        ("student_level_1_to_9", ("choice", "locked", "locked")),
        ("student_level_10_to_19", ("choice", "choice", "locked")),
        ("student_level_20_plus", ("choice", "choice", "choice")),
    )
    for band, slots in bands:
        choices = [("empty", "equipped") if value == "choice" else (value,) for value in slots]
        for index, states in enumerate(product(*choices), start=1):
            rows.append({
                "case_id": f"{band}_{index:02d}",
                "student_level_band": band,
                "slot_states": list(states),
            })
    return rows


def _compact_rows(
    representatives: tuple[tuple[str, tuple[str, str, str]], ...],
    split: str,
) -> list[dict[str, object]]:
    assignments: list[dict[tuple[int, int], tuple[str, int]]] = []
    special = (12, 23, 34)
    for slot in (1, 2, 3):
        cells = [
            (representative, row, row + 1)
            for representative in range(3)
            for row in range(10)
        ]
        result: dict[tuple[int, int], tuple[str, int]] = {}
        fixed_cell = (0, 3)
        fixed_tier = next(tier for rep, row, tier in cells if (rep, row) == fixed_cell)
        result[fixed_cell] = (f"T{fixed_tier}", special[slot - 1])

        for tier_number, maximum in enumerate(LEVEL_CAPS.values(), start=1):
            candidates = [
                (rep, row) for rep, row, tier in cells
                if tier == tier_number and (rep, row) not in result
            ]
            candidates.sort(key=lambda cell: ((cell[0] - (slot - 1)) % 3, cell[1]))
            result[candidates[0]] = (f"T{tier_number}", maximum)

        remaining_values = [
            value for value in COMPACT_REQUIRED_LEVELS
            if value != special[slot - 1] and value not in LEVEL_CAPS.values()
        ]
        remaining_cells = [
            (rep, row, tier) for rep, row, tier in cells if (rep, row) not in result
        ]
        for value in sorted(remaining_values, reverse=True):
            fitting = sorted(
                (cell for cell in remaining_cells if value <= LEVEL_CAPS[f"T{cell[2]}"]),
                key=lambda cell: (
                    LEVEL_CAPS[f"T{cell[2]}"],
                    (cell[0] - (slot - 1)) % 3,
                    cell[1],
                ),
            )
            if not fitting:
                raise ValueError(f"compact matrix cannot place level {value} in slot {slot}")
            rep, row, tier = fitting[0]
            result[(rep, row)] = (f"T{tier}", value)
            remaining_cells.remove((rep, row, tier))
        if remaining_cells:
            raise ValueError(f"compact matrix left cells unassigned in slot {slot}")
        assignments.append(result)

    rows: list[dict[str, object]] = []
    for representative, (student_ref, families) in enumerate(representatives):
        for row in range(10):
            slots = []
            for slot, family in enumerate(families, start=1):
                tier, level = assignments[slot - 1][(representative, row)]
                slots.append({"slot": slot, "family": family, "tier": tier, "level": level})
            rows.append({
                "sequence": len(rows) + 1,
                "case_id": f"{split}_{student_ref}_{row + 1:02d}",
                "split": split,
                "student_ref": student_ref,
                "source_size": [1280, 720],
                "repeat_count": 3,
                "slots": slots,
                "filename_pattern": f"{split}_{student_ref}_{row + 1:02d}_r{{repeat:02d}}.png",
            })
    return rows


def build_manifest(*, include_minimum: bool = False) -> dict[str, object]:
    rows: list[dict[str, object]] = []
    sequence = 0
    for tier, maximum in LEVEL_CAPS.items():
        tier_number = int(tier[1:])
        for level in range(1, maximum + 1):
            for student_ref, families in REPRESENTATIVES:
                sequence += 1
                rows.append({
                    "sequence": sequence,
                    "case_id": f"{student_ref}_T{tier_number:02d}_L{level:02d}",
                    "student_ref": student_ref,
                    "source_size": [1280, 720],
                    "repeat_count": 3,
                    "slots": [
                        {"slot": slot, "family": family, "tier": tier, "level": level}
                        for slot, family in enumerate(families, start=1)
                    ],
                    "filename_pattern": (
                        f"{student_ref}_T{tier_number:02d}_L{level:02d}_r{{repeat:02d}}.png"
                    ),
                })

    family_cases = 9 * sum(LEVEL_CAPS.values())
    manifest: dict[str, object] = {
        "schema_version": 1,
        "purpose": "exhaustive exact-1280x720 student equipment S3B capture matrix",
        "acceptance": {
            "width": 1280,
            "height": 720,
            "aspect_ratio": "16:9",
            "exact_dimensions_required": True,
            "reject_window_border_padding_letterbox": True,
            "reject_non_16_9": True,
            "format": "lossless PNG",
            "stable_frame_repeats": 3,
        },
        "level_caps": LEVEL_CAPS,
        "representatives": [
            {"student_ref": student_ref, "slots": list(families)}
            for student_ref, families in REPRESENTATIVES
        ],
        "counts": {
            "tier_level_pairs_per_family": sum(LEVEL_CAPS.values()),
            "equipped_atomic_cases": family_cases,
            "normal_equipment_atomic_cases_including_empty_locked": family_cases + 5,
            "live_atomic_cases_including_favorite": family_cases + 5 + 6,
            "equipped_capture_configurations": len(rows),
            "equipped_pngs_at_three_repeats": len(rows) * 3,
            "physical_empty_locked_state_patterns": 14,
            "unlock_boundary_probes": 5,
            "favorite_atomic_states": 6,
            "unresolved_slot_masks": 7,
            "live_capture_configuration_upper_bound_before_deduplication": len(rows) + 14 + 5 + 6,
            "live_png_upper_bound_at_three_repeats": (len(rows) + 14 + 5 + 6) * 3,
        },
        "equipped_capture_rows": rows,
        "physical_empty_locked_state_patterns": _state_patterns(),
        "unlock_boundary_probes": [
            {"student_level": 1, "expected": ["unlocked", "locked", "locked"]},
            {"student_level": 9, "expected": ["unlocked", "locked", "locked"]},
            {"student_level": 10, "expected": ["unlocked", "unlocked", "locked"]},
            {"student_level": 19, "expected": ["unlocked", "unlocked", "locked"]},
            {"student_level": 20, "expected": ["unlocked", "unlocked", "unlocked"]},
        ],
        "favorite_atomic_states": [
            "unsupported_on_kr",
            "supported_empty",
            "supported_love_locked",
            "supported_t1",
            "supported_t2",
            "supported_uncertain",
        ],
        "unresolved_slot_masks": [
            [slot for slot in (1, 2, 3) if mask & (1 << (slot - 1))]
            for mask in range(1, 8)
        ],
        "synthetic_only_negative_cases": [
            "blank_crop",
            "zero",
            "tier_max_plus_one_for_each_tier",
            "greater_than_70",
            "partial_second_digit",
            "nonnumeric_or_icon_contamination",
            "tier_level_pair_unresolved",
        ],
    }
    if include_minimum:
        compact_calibration = _compact_rows(REPRESENTATIVES, "calibration")
        compact_validation = _compact_rows(VALIDATION_REPRESENTATIVES, "validation")
        manifest["validation_representatives"] = [
            {"student_ref": student_ref, "slots": list(families)}
            for student_ref, families in VALIDATION_REPRESENTATIVES
        ]
        counts = manifest["counts"]
        assert isinstance(counts, dict)
        counts.update({
            "minimum_factorized_configurations_per_split": len(compact_calibration),
            "minimum_factorized_pngs_per_split_at_three_repeats": len(compact_calibration) * 3,
            "independent_two_split_configurations": len(compact_calibration) + len(compact_validation),
            "independent_two_split_pngs_at_three_repeats": (len(compact_calibration) + len(compact_validation)) * 3,
        })
        manifest["minimum_factorized_matrix"] = {
            "lower_bound_reason": "90 family-tier pairs / 3 independently readable slots = 30 screenshots",
            "factorization_assumption": "tier icon is family-specific; level glyph is slot-specific and family-independent",
            "required_levels_per_slot": list(COMPACT_REQUIRED_LEVELS),
            "calibration_rows": compact_calibration,
            "validation_rows": compact_validation,
        }
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--include-minimum", action="store_true")
    args = parser.parse_args()
    manifest = build_manifest(include_minimum=args.include_minimum)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(manifest["counts"], sort_keys=True))


if __name__ == "__main__":
    main()
