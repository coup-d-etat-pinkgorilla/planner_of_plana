from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
from threading import Event
from typing import Any, Callable

from PIL import Image, ImageStat

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import CapturePort, Match, TemplateMatcher, ratio_crop
from core.scanner_session import ScannerError


def _number(value: object, label: str) -> float:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ScannerError("invalid_candidate", f"{label} must be a number")
    result = float(value)
    if not 0.0 <= result <= 1.0:
        raise ScannerError("invalid_candidate", f"{label} must be between 0 and 1")
    return result


def canonical_tactical_lobby_candidate(value: object) -> dict[str, Any]:
    """Validate the P8 review DTO without making it a P9 persistence record."""
    if not isinstance(value, dict):
        raise ScannerError("invalid_candidate", "tactical lobby candidate must be an object")
    required = {
        "version", "roi_profile_id", "observed_at", "screen_hash",
        "refresh_generation", "frame_complete", "current_rank", "rows",
        "overall_confidence", "review_status",
    }
    if set(value) != required or value.get("version") != 1:
        raise ScannerError("invalid_candidate", "tactical lobby candidate shape/version is invalid")
    if not isinstance(value["roi_profile_id"], str) or not value["roi_profile_id"]:
        raise ScannerError("invalid_candidate", "roi_profile_id must be non-empty")
    if not isinstance(value["observed_at"], str) or not value["observed_at"]:
        raise ScannerError("invalid_candidate", "observed_at must be non-empty")
    for key in ("screen_hash", "refresh_generation"):
        if not isinstance(value[key], str) or not value[key]:
            raise ScannerError("invalid_candidate", f"{key} must be non-empty")
    if not isinstance(value["frame_complete"], bool):
        raise ScannerError("invalid_candidate", "frame_complete must be boolean")
    if value["review_status"] not in {"confirmed", "review_required"}:
        raise ScannerError("invalid_candidate", "review_status is invalid")
    _number(value["overall_confidence"], "overall_confidence")
    rank = value["current_rank"]
    if not isinstance(rank, dict) or set(rank) != {"value", "proposed_value", "confidence", "margin", "review_status"}:
        raise ScannerError("invalid_candidate", "current_rank is invalid")
    if rank["value"] is not None and (not isinstance(rank["value"], int) or isinstance(rank["value"], bool) or rank["value"] < 1):
        raise ScannerError("invalid_candidate", "current_rank.value is invalid")
    if not isinstance(rank["proposed_value"], int) or isinstance(rank["proposed_value"], bool) or rank["proposed_value"] < 1:
        raise ScannerError("invalid_candidate", "current_rank.proposed_value is invalid")
    _number(rank["confidence"], "current_rank.confidence")
    _number(rank["margin"], "current_rank.margin")
    if rank["review_status"] not in {"confirmed", "review_required"}:
        raise ScannerError("invalid_candidate", "current_rank.review_status is invalid")
    rows = value["rows"]
    if not isinstance(rows, list) or len(rows) != 3:
        raise ScannerError("invalid_candidate", "tactical lobby requires exactly three rows")
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or set(row) != {"index", "rank", "opponent", "public_defense", "confidence", "review_status"}:
            raise ScannerError("invalid_candidate", f"rows[{index}] is invalid")
        if row["index"] != index or row["review_status"] not in {"confirmed", "review_required"}:
            raise ScannerError("invalid_candidate", f"rows[{index}] identity/status is invalid")
        _number(row["confidence"], f"rows[{index}].confidence")
        opponent = row["opponent"]
        if not isinstance(opponent, dict) or set(opponent) != {"display_name", "proposed_display_name", "confidence", "margin", "review_status"}:
            raise ScannerError("invalid_candidate", f"rows[{index}].opponent is invalid")
        for key in ("display_name", "proposed_display_name"):
            if opponent[key] is not None and not isinstance(opponent[key], str):
                raise ScannerError("invalid_candidate", f"rows[{index}].opponent.{key} is invalid")
        _number(opponent["confidence"], f"rows[{index}].opponent.confidence")
        _number(opponent["margin"], f"rows[{index}].opponent.margin")
        deck = row["public_defense"]
        if not isinstance(deck, dict) or set(deck) != {"version", "strikers", "specials"} or deck["version"] != 2:
            raise ScannerError("invalid_candidate", f"rows[{index}].public_defense is invalid")
        if not isinstance(deck["strikers"], list) or len(deck["strikers"]) != 4 or not isinstance(deck["specials"], list) or len(deck["specials"]) != 2:
            raise ScannerError("invalid_candidate", f"rows[{index}] deck slot counts are invalid")
        for slot_index, slot in enumerate(deck["strikers"] + deck["specials"]):
            expected_position = slot_index if slot_index < 4 else slot_index - 4
            expected = {"version", "position", "student_id", "state", "source", "confidence", "review_status", "wildcard"}
            if not isinstance(slot, dict) or set(slot) != expected or slot.get("version") != 2 or slot.get("position") != expected_position:
                raise ScannerError("invalid_candidate", f"rows[{index}] deck slot is invalid")
            if slot["student_id"] is not None and not isinstance(slot["student_id"], str):
                raise ScannerError("invalid_candidate", f"rows[{index}] student_id is invalid")
            if slot["confidence"] is not None:
                _number(slot["confidence"], f"rows[{index}] slot confidence")
    return json.loads(json.dumps(value, ensure_ascii=False))


class TacticalLobbyMatcherAdapter:
    def __init__(
        self, capture: CapturePort, catalog: RecognitionAssetCatalog, *,
        rank_threshold: float = 0.88, rank_margin: float = 0.035,
        name_threshold: float = 0.88, name_margin: float = 0.035,
        portrait_threshold: float = 0.88, portrait_margin: float = 0.08,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        self.capture = capture
        self.regions = catalog.region("tactical_lobby")
        self.rank_matcher = TemplateMatcher(catalog, "tactical_lobby", "tactical-rank-template")
        self.name_matcher = TemplateMatcher(catalog, "tactical_lobby", "tactical-name-template")
        self.portrait_matcher = TemplateMatcher(catalog, "tactical_lobby", "tactical-student-template")
        self.rank_gate = (rank_threshold, rank_margin)
        self.name_gate = (name_threshold, name_margin)
        self.portrait_gate = (portrait_threshold, portrait_margin)
        self.clock = clock or (lambda: datetime.now(timezone.utc))

    @staticmethod
    def _accepted(match: Match, gate: tuple[float, float]) -> bool:
        return match.score >= gate[0] and match.margin >= gate[1]

    @staticmethod
    def _slot(position: int, match: Match | None, accepted: bool, source: str) -> dict[str, Any]:
        return {
            "version": 2, "position": position,
            "student_id": match.identity if match is not None and accepted else None,
            "state": "visible_lobby" if match is not None else "unknown",
            "source": source, "confidence": match.score if match is not None else None,
            "review_status": "confirmed" if accepted else "review_required",
            "wildcard": False,
        }

    @staticmethod
    def _evidence(field: str, match: Match, accepted: bool, source: str) -> dict[str, Any]:
        return {
            "field": field, "status": "ok" if accepted else "uncertain",
            "source": source, "confidence": match.score,
            "note": f"proposed={match.identity}; margin={match.margin:.6f}",
        }

    def __call__(self, target: dict[str, Any], cancel: Event, progress: Callable[[int, int | None, str], None]) -> list[dict[str, Any]]:
        if cancel.is_set():
            return []
        progress(0, 11, "scanner.tactical_lobby.capture")
        frame = self.capture.wait_stable(target, cancel)
        if cancel.is_set():
            return []
        expected_aspect = float(self.regions["aspect_ratio"])
        aspect_ok = abs(frame.width / frame.height - expected_aspect) <= float(self.regions["aspect_tolerance"])
        stable = ratio_crop(frame, self.regions["stable_panel"])
        frame_complete = aspect_ok and min(ImageStat.Stat(stable.convert("L")).extrema[0]) != max(ImageStat.Stat(stable.convert("L")).extrema[0])
        screen_bytes = stable.convert("L").resize((320, 142), Image.Resampling.BILINEAR).tobytes()
        screen_hash = hashlib.sha256(screen_bytes).hexdigest()
        evidence: list[dict[str, Any]] = [{
            "field": "frame", "status": "ok" if frame_complete else "region_missing",
            "source": "tactical_lobby_ratio_profile", "confidence": 1.0 if frame_complete else 0.0,
            "note": f"frame={frame.width}x{frame.height}; expected_aspect={expected_aspect:.6f}",
        }]
        rank_match = self.rank_matcher.match(ratio_crop(frame, self.regions["current_rank"]))
        rank_ok = self._accepted(rank_match, self.rank_gate)
        evidence.append(self._evidence("current_rank", rank_match, rank_ok, "tactical_rank_template"))
        progress(1, 11, "scanner.tactical_lobby.current_rank")
        rows: list[dict[str, Any]] = []
        semantic: list[str] = [rank_match.identity]
        confidences = [rank_match.score]
        review_required = not frame_complete or not rank_ok
        for row_index, regions in enumerate(self.regions["rows"]):
            if cancel.is_set():
                return []
            row_rank = self.rank_matcher.match(ratio_crop(frame, regions["rank"]))
            row_rank_ok = self._accepted(row_rank, self.rank_gate)
            name = self.name_matcher.match(ratio_crop(frame, regions["name"]))
            name_ok = self._accepted(name, self.name_gate)
            slot_matches: list[tuple[str, Match, bool]] = []
            for region_name in ("striker_1", "special_1", "special_2"):
                matched = self.portrait_matcher.match(ratio_crop(frame, regions[region_name]))
                slot_matches.append((region_name, matched, self._accepted(matched, self.portrait_gate)))
            fields_ok = row_rank_ok and name_ok and all(item[2] for item in slot_matches)
            review_required = review_required or not fields_ok
            row_confidences = [row_rank.score, name.score, *(item[1].score for item in slot_matches)]
            confidences.extend(row_confidences)
            evidence.extend([
                self._evidence(f"rows[{row_index}].rank", row_rank, row_rank_ok, "tactical_rank_template"),
                self._evidence(f"rows[{row_index}].opponent.display_name", name, name_ok, "tactical_name_template"),
                *(self._evidence(f"rows[{row_index}].{region_name}", match, ok, "tactical_student_template") for region_name, match, ok in slot_matches),
            ])
            striker = slot_matches[0]
            specials = slot_matches[1:]
            rows.append({
                "index": row_index,
                "rank": {"value": int(row_rank.identity) if row_rank_ok else None, "proposed_value": int(row_rank.identity), "confidence": row_rank.score, "margin": row_rank.margin, "review_status": "confirmed" if row_rank_ok else "review_required"},
                "opponent": {"display_name": name.identity if name_ok else None, "proposed_display_name": name.identity, "confidence": name.score, "margin": name.margin, "review_status": "confirmed" if name_ok else "review_required"},
                "public_defense": {
                    "version": 2,
                    "strikers": [self._slot(0, striker[1], striker[2], "visible_lobby"), *[self._slot(i, None, False, "hidden_lobby") for i in range(1, 4)]],
                    "specials": [self._slot(i, item[1], item[2], "visible_lobby") for i, item in enumerate(specials)],
                },
                "confidence": min(row_confidences),
                "review_status": "confirmed" if fields_ok else "review_required",
            })
            semantic.extend([row_rank.identity, name.identity, *(item[1].identity for item in slot_matches)])
            progress(1 + (row_index + 1) * 3, 11, "scanner.tactical_lobby.row")
        generation = "refresh-" + hashlib.sha256("\0".join(semantic).encode("utf-8")).hexdigest()[:24]
        payload = {
            "version": 1, "roi_profile_id": self.regions["profile_id"],
            "observed_at": self.clock().astimezone(timezone.utc).isoformat(),
            "screen_hash": screen_hash, "refresh_generation": generation,
            "frame_complete": frame_complete,
            "current_rank": {"value": int(rank_match.identity) if rank_ok else None, "proposed_value": int(rank_match.identity), "confidence": rank_match.score, "margin": rank_match.margin, "review_status": "confirmed" if rank_ok else "review_required"},
            "rows": rows, "overall_confidence": min(confidences),
            "review_status": "review_required" if review_required else "confirmed",
        }
        progress(11, 11, "scanner.tactical_lobby.complete")
        return [{"payload": canonical_tactical_lobby_candidate(payload), "evidence": evidence, "review_required": review_required}]
