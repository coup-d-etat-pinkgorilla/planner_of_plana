"""Freeze/check F0 source symbols and local evidence without importing v6."""
from __future__ import annotations

import argparse
import ast
from hashlib import sha256
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "backend/tests/fixtures/scanner_fallback_restoration"
OUTPUT = ROOT / "docs/migration/scanner-fallback-restoration/source-manifest.json"
EXTRA = [
    "../v6/core/scanner.py", "../v6/core/scanner_shared.py", "../v6/main.py",
    "../v6/core/inventory_profiles.py", "../v6/core/inventory_count_matcher.py",
    "../v6/core/scanner_components/runtime.py", "../v6/core/scan_status.py",
    "backend/core/scanner_runtime.py", "backend/core/scanner_session.py",
    "backend/core/scanner_protocol_v1.py", "backend/core/repository_dto.py",
    "backend/core/recognition_answer_samples.py", "backend/core/studio_numeric_bank.py",
    "contracts/scanner-protocol-v1.schema.json", "contracts/student-scan-diagnostic-v1.schema.json",
]


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def functions(tree):
    result = {}

    def walk(node, prefix=""):
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
                name = prefix + child.name
                if not isinstance(child, ast.ClassDef):
                    result[name] = child
                walk(child, name + ".")
            else:
                walk(child, prefix)

    walk(tree)
    return result


def build():
    rows = read(FIXTURE / "restoration-matrix.json")["rows"]
    refs = sorted({s for r in rows for side in ("v6_symbols", "v7_symbols") for s in r[side]})
    paths = sorted(set(EXTRA) | {s.rsplit(":", 1)[0] for s in refs})
    texts, trees, funcs = {}, {}, {}
    for path in paths:
        if path.endswith(".py"):
            texts[path] = (ROOT / path).read_text(encoding="utf-8-sig")
            trees[path] = ast.parse(texts[path])
            funcs[path] = functions(trees[path])
    symbols = []
    for ref in refs:
        path, name = ref.rsplit(":", 1)
        matches = [(q, n) for q, n in funcs[path].items() if q == name or q.endswith("." + name)]
        if len(matches) != 1:
            raise ValueError(f"Expected one source symbol: {ref}; got {len(matches)}")
        qualified, node = matches[0]
        source = ast.get_source_segment(texts[path], node)
        callers = []
        for caller_path, methods in funcs.items():
            if caller_path.startswith("../v6/") != path.startswith("../v6/"):
                continue
            for caller, method in methods.items():
                for call in ast.walk(method):
                    if isinstance(call, ast.Call) and (
                        isinstance(call.func, ast.Name) and call.func.id == node.name
                        or isinstance(call.func, ast.Attribute) and call.func.attr == node.name
                    ):
                        callers.append({"path": caller_path, "symbol": caller, "line": call.lineno})
        calls = sorted({ast.unparse(n.func) for n in ast.walk(node) if isinstance(n, ast.Call)})
        symbols.append({
            "ref": ref, "qualified_symbol": qualified, "line": node.lineno, "end_line": node.end_lineno,
            "signature": ast.unparse(node.args),
            "normalized_source_sha256": sha256(source.encode("utf-8")).hexdigest(),
            "called_symbols": calls,
            "self_state_dependencies": sorted({n.attr for n in ast.walk(node) if isinstance(n, ast.Attribute)
                                                and isinstance(n.value, ast.Name) and n.value.id == "self"}),
            "status_events": sorted({n.args[0].value for n in ast.walk(node) if isinstance(n, ast.Call)
                                      and isinstance(n.func, ast.Attribute) and n.func.attr == "_status"
                                      and n.args and isinstance(n.args[0], ast.Constant)
                                      and isinstance(n.args[0].value, str)}),
            "syntactic_call_sites": list({(r["path"], r["line"]): r for r in callers}.values()),
        })
    return {"schema_version": 1, "recorded_on": "2026-08-30",
            "scope": "working-tree bytes, not HEAD; static inspection, no v6 import or live trace",
            "call_site_limit": "Name matches in listed sources only; callbacks, aliases, dynamic binding and same-name methods require manual call-path review in restoration-matrix.json",
            "files": [{"path": p, "sha256": digest(ROOT / p)} for p in paths], "symbols": symbols}


def check():
    matrix = read(FIXTURE / "restoration-matrix.json")
    assert [r["id"] for r in matrix["rows"]] == [f"R{i:02}" for i in range(1, 25)]
    evidence = read(FIXTURE / "evidence-catalog.json")
    known = {e["id"] for e in evidence["groups"]}
    source = read(OUTPUT)
    symbols = {s["ref"] for s in source["symbols"]}
    for r in matrix["rows"]:
        assert r["fixture_plan"]["positive"]["cases"] and r["fixture_plan"]["negative"]["cases"]
        assert set(r["evidence_refs"]) <= known
        assert set(r["v6_symbols"] + r["v7_symbols"]) <= symbols
    for record in source["files"] + evidence["files"]:
        path = ROOT / record["path"]
        assert digest(path) == record["sha256"], path
        if "size" in record:
            with Image.open(path) as im:
                assert list(im.size) == record["size"], path
    feedback = read(FIXTURE / "feedback1-manifest.json")
    assert len(feedback["records"]) == 19
    for record in feedback["records"]:
        path = Path(feedback["source_root"]) / record["source_file"]
        assert digest(path) == record["source_sha256"], path
        with Image.open(path) as im:
            assert list(im.size) == record["source_size"], path
    contract = read(FIXTURE / "decision-contracts.json")
    assert contract["decisions"]["D1"]["status"].startswith("user_confirmed")
    assert contract["decisions"]["D3"]["status"].startswith("user_confirmed")
    assert not contract["decisions"]["D2"]["current_bank_promotion"]
    print(f"F0 integrity OK: 24 rows, {len(symbols)} symbols, {len(source['files'])} sources, 19 feedback images, {len(evidence['files'])} evidence files")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Explicitly replace the F0 source snapshot")
    args = parser.parse_args()
    if args.write:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(OUTPUT)
    else:
        check()
