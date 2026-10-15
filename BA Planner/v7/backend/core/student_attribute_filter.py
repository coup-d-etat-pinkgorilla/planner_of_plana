"""Version 1 conservative, form-aware candidates; no identity or confidence vote."""

from dataclasses import dataclass, field
import hashlib
import json

from core import student_meta
from core.runtime_paths import resolve_metadata_catalog_path


CONTRACT = "student-attribute-prefilter-v1"
EVIDENCE_SCHEMA_VERSION = 2
AXES = ("attack_type", "defense_type", "role", "position", "combat_class")
# Only AXES have a pre-identity image reader. These additional fields require an
# explicit selection; equipment kinds belong to a slot, never an unordered bag.
SELECTED_AXES = ("equipment_slot_1", "equipment_slot_2", "equipment_slot_3", "weapon_type", "school")
FILTER_AXES = AXES + SELECTED_AXES
VALUES = {
    "attack_type": {"explosive", "piercing", "mystic", "sonic"},
    "defense_type": {"light", "heavy", "special", "elastic", "composite"},
    "role": {"dealer", "healer", "supporter", "tanker", "t_s"},
    "position": {"front", "middle", "back"},
    "combat_class": {"striker", "special"},
    "equipment_slot_1": {"hat", "gloves", "shoes"},
    "equipment_slot_2": {"bag", "badge", "hairpin"},
    "equipment_slot_3": {"charm", "watch", "necklace"},
    "weapon_type": {"sg", "smg", "ar", "gl", "hg", "rl", "sr", "rg", "mg", "mt", "ft"},
    "school": {"abydos", "arius", "etc", "gehenna", "highlander", "hyakkiyako", "millennium",
               "red winter", "srt", "sakugawa", "shanhaijing", "tokiwadai", "trinity",
               "valkyrie", "wild hunt"},
}


def normalized(axis, value):
    if not isinstance(value, str):
        return None
    value = value.strip().casefold()
    return value if value in VALUES.get(axis, ()) else None


def selected_filter_payload(value):
    """Validate the optional wire model, retaining unknown tokens for diagnostics.

    One string (or null/omitted) per axis; different axes are AND constraints.
    Lists and numeric game enums are not silently interpreted as selections.
    """
    if value is None:
        return {}
    if not isinstance(value, dict) or any(
        axis not in FILTER_AXES or (token is not None and not isinstance(token, str))
        for axis, token in value.items()
    ):
        raise ValueError("student_identity_filters must contain one string or null per supported axis")
    return dict(value)


def merge_selected_attributes(observed, selected):
    """Only accepted image values and explicit known selections may exclude.

    A disagreement removes the entire axis rather than picking either source.
    Invalid/unknown selections cannot override an accepted image observation.
    """
    attributes = dict(observed)
    observations, issues = {}, []
    for axis, token in selected_filter_payload(selected).items():
        value = normalized(axis, token)
        image_value = normalized(axis, observed.get(axis))
        conflict = value is not None and image_value is not None and value != image_value
        reason = ("selected_observed_conflict" if conflict else
                  "explicit_selection" if value is not None else "unknown_or_unsupported_attribute")
        if conflict:
            attributes.pop(axis, None)
        elif value is not None:
            attributes[axis] = value
        else:
            issues.append({"axis": axis, "reason": reason, "source": "user_selected_filter"})
        if conflict:
            issues.append({"axis": axis, "reason": reason, "observed_value": image_value,
                           "selected_value": value})
        observations[axis] = {"value": value if value is not None and not conflict else None,
                              "selected_value": token, "source": "user_selected_filter",
                              "confidence": None, "score": None, "margin": None,
                              "roi_id": None, "accepted": value is not None and not conflict,
                              "reason": reason}
    return attributes, observations, tuple(issues)


@dataclass(frozen=True)
class AttributeCandidates:
    before: frozenset[str]
    after: frozenset[str]
    used: dict[str, str]
    issues: tuple[dict, ...]
    metadata_sha256: str
    fallback_reason: str | None = None
    proposed_count: int | None = None
    axis_refs: dict[str, frozenset[str]] = field(default_factory=dict, compare=False)
    proposed_refs: frozenset[str] | None = field(default=None, compare=False)
    uncertain_refs: frozenset[str] = field(default_factory=frozenset, compare=False)

    @property
    def narrowed(self):
        return self.fallback_reason is None and self.after != self.before

    @property
    def name_ids(self):
        return frozenset(student_meta.split_form_ref(ref)[0] for ref in self.after)

    def evidence(self):
        def set_id(refs):
            return hashlib.sha256(json.dumps(sorted(refs)).encode('utf-8')).hexdigest()
        proposed = (self.proposed_refs if self.proposed_refs is not None else
                    frozenset() if self.proposed_count == 0 else self.after)
        axis_intersection = self.before.intersection(*self.axis_refs.values())
        return {
            "contract": CONTRACT, "version": 1,
            "evidence_schema_version": EVIDENCE_SCHEMA_VERSION,
            "used_attributes": self.used,
            "before_count": len(self.before), "after_count": len(self.after),
            "proposed_after_count": len(self.after) if self.proposed_count is None else self.proposed_count,
            "effective_after_count": len(self.after),
            "before_refs": sorted(self.before), "after_refs": sorted(self.after),
            "effective_refs": sorted(self.after),
            "proposed_refs": sorted(proposed), "proposed_set_sha256": set_id(proposed),
            "axis_candidates": {
                axis: {"used": axis in self.used,
                       "observed_value": self.used.get(axis),
                       "candidate_refs": sorted(self.axis_refs.get(axis, self.before)),
                       "candidate_count": len(self.axis_refs.get(axis, self.before)),
                       "candidate_set_sha256": set_id(self.axis_refs.get(axis, self.before)),
                       "rule": "match_or_unknown_metadata" if axis in self.used else "ignored_axis"}
                for axis in AXES + tuple(axis for axis in SELECTED_AXES
                    if axis in self.used or any(issue.get("axis") == axis for issue in self.issues))
            },
            "axis_intersection_refs": sorted(axis_intersection),
            "axis_intersection_set_sha256": set_id(axis_intersection),
            "conservative_retained_refs": sorted(self.uncertain_refs),
            "conservative_override_refs": sorted(self.uncertain_refs - axis_intersection),
            "before_set_sha256": set_id(self.before), "after_set_sha256": set_id(self.after),
            "effective_set_sha256": set_id(self.after),
            "metadata_sha256": self.metadata_sha256,
            "metadata_issues": list(self.issues),
            "narrowed": self.narrowed,
            "fallback": self.fallback_reason is not None,
            "fallback_reason": self.fallback_reason,
            "initial_fallback_reason": self.fallback_reason,
            "final_fallback_reason": self.fallback_reason,
            "fallback_history": ([{"stage": "candidate", "reason": self.fallback_reason}]
                                 if self.fallback_reason is not None else []),
            "initial_candidate_filter_applied": self.narrowed,
            "final_candidate_filter_applied": self.narrowed,
            "margin_scope": "attribute_conditioned" if self.narrowed else "full_catalog",
            "singleton_handling": "requires_full_catalog_illustration_gate" if len(self.after)==1 else "not_singleton",
        }


def build_candidates(attributes, *, extra_refs=(), metadata=None, canonical_catalog=None):
    """A missing/conflicting used field retains the entire form, never excludes it.

    Generated runtime metadata and the canonical snapshot must agree. Explicit
    metadata injection is for synthetic fixtures; production uses both sources.
    There is no minimum attribute count, top-k truncation, or first-candidate win.
    A joint filter is NOT the ordinary intersection when any used metadata is
    unknown: that exception keeps the entire form, including another mismatch.
    """
    issues = []
    used = {}
    for axis, value in attributes.items():
        value = normalized(axis, value)
        if value is not None:
            used[axis] = value
        else:
            issues.append({"axis": axis, "reason": "unknown_or_unsupported_attribute"})
    # Unselected axes do not change the historical five-axis evidence/fingerprint.
    checked_axes = AXES + tuple(axis for axis in SELECTED_AXES if axis in used)
    generated = metadata is None
    unavailable = False
    if generated:
        metadata = {
            student_meta.format_form_ref(sid, form): {
                axis: student_meta.field_for_form(sid, axis, form) for axis in checked_axes
            }
            for sid in student_meta.all_ids() for form in student_meta.form_indexes(sid)
        }
        try:
            canonical_catalog = json.loads(resolve_metadata_catalog_path().read_bytes())
            if (canonical_catalog.get("version") != 1
                    or not isinstance(canonical_catalog.get("students"), dict)
                    or not isinstance(canonical_catalog.get("forms"), dict)):
                raise ValueError("invalid canonical metadata shape/version")
        except (OSError, ValueError, TypeError, AttributeError) as exc:
            unavailable = True
            issues.append({"reason": "metadata_unavailable", "error": type(exc).__name__})
            canonical_catalog = None
    refs = set(metadata) | set(extra_refs)
    if canonical_catalog is not None:
        for sid in canonical_catalog.get("students", {}):
            rows = canonical_catalog.get("forms", {}).get(sid, [])
            count = max(1, len(rows)) if isinstance(rows, list) else 1
            # Preserve catalog form numbers without normalizing through an older
            # generated catalog, which could collapse a new form to form one.
            refs.update(sid if i == 1 else f"{sid}#{i}" for i in range(1, count + 1))
    before = frozenset(refs)
    checked = {}
    for ref in sorted(before):
        runtime_row = metadata.get(ref, {})
        runtime_row = runtime_row if isinstance(runtime_row, dict) else {}
        base, form = student_meta.split_form_ref(ref)
        canonical_row = None
        if canonical_catalog is not None:
            row = canonical_catalog.get("students", {}).get(base, {})
            canonical_row = dict(row) if isinstance(row, dict) else {}
            forms = canonical_catalog.get("forms", {}).get(base, [])
            if not isinstance(forms, list):
                canonical_row = {}
            elif forms:
                if form <= len(forms) and isinstance(forms[form-1], dict):
                    canonical_row.update(forms[form-1])
                else:
                    canonical_row = {}
            elif form > 1:
                canonical_row = {}  # A missing additional form is not the base form.
        values = {}
        for axis in checked_axes:
            value = normalized(axis, runtime_row.get(axis))
            reason = None if value is not None else "metadata_missing_or_invalid"
            if canonical_row is not None:
                other = normalized(axis, canonical_row.get(axis))
                if other is None:
                    value, reason = None, "canonical_metadata_missing_or_invalid"
                elif value is not None and other != value:
                    value, reason = None, "metadata_conflict"
            values[axis] = value
            if reason is not None and axis in used:
                issues.append({"student_ref": ref, "axis": axis, "reason": reason})
        checked[ref] = values
    fingerprint = hashlib.sha256(json.dumps(
        {"runtime": metadata, "canonical": canonical_catalog, "checked": checked},
        sort_keys=True, ensure_ascii=False, default=str,
    ).encode("utf-8")).hexdigest()
    # Diagnostic single-axis sets are independent views. They do not replace the
    # existing conservative joint rule below.
    diagnostics = {
        "axis_refs": {axis: frozenset(ref for ref, row in checked.items()
                                   if row[axis] is None or row[axis] == value)
                      for axis, value in used.items()},
        "uncertain_refs": frozenset(ref for ref, row in checked.items()
                                    if any(row[axis] is None for axis in used)),
    }
    if unavailable or not used:
        reason = "metadata_unavailable" if unavailable else "no_reliable_attributes"
        return AttributeCandidates(before, before, used, tuple(issues), fingerprint, reason,
                                   proposed_refs=before, **diagnostics)
    after = frozenset(ref for ref, row in checked.items()
        if any(row[axis] is None for axis in used)
        or all(row[axis] == value for axis, value in used.items()))
    if not after:
        return AttributeCandidates(before, before, used, tuple(issues), fingerprint,
                                   "empty_intersection", 0, proposed_refs=after, **diagnostics)
    return AttributeCandidates(before, after, used, tuple(issues), fingerprint,
                               proposed_refs=after, **diagnostics)
