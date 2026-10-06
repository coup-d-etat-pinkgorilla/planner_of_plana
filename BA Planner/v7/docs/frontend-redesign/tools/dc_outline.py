"""Design 캔버스 artboard(.dc.html)를 읽기 쉬운 개요로 덤프한다.

시안 HTML은 파일마다 같은 공통 CSS(<helmet>)가 반복되고 사선 path가 길어서 통째로 읽으면
토큰이 많이 든다. 이 도구는 본문만 골라 요소마다 한 줄로 출력한다.

    py -3.11 docs/frontend-redesign/tools/dc_outline.py <artboard.dc.html> [--abs] [--text-only] [--max-depth N]

출력 한 줄 = 들여쓰기(깊이) + 태그 + .class + [aria-label] + {left,top,width,height} + "텍스트".
--abs 를 주면 position:absolute 조상의 left/top을 누적한 근사 절대좌표도 함께 적는다
(flex 배치나 transform은 계산하지 않으므로 근사값이다. 섹션 rect는 svg path bbox를 쓴다).
svg path는 d 문자열 대신 bbox와 fill/stroke만 적는다.
표준 라이브러리만 쓴다.
"""
from __future__ import annotations

import argparse
import re
import sys
from html.parser import HTMLParser

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
GEOM_KEYS = ("left", "top", "width", "height", "right", "bottom")
NUM = re.compile(r"-?\d+(?:\.\d+)?")


def parse_style(style: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in style.split(";"):
        if ":" in part:
            k, v = part.split(":", 1)
            out[k.strip().lower()] = v.strip()
    return out


def px(value: str | None) -> float | None:
    if not value or not value.endswith("px"):
        return None
    m = NUM.match(value)
    return float(m.group()) if m else None


def path_bbox(d: str) -> tuple[float, float, float, float] | None:
    nums = [float(n) for n in NUM.findall(d)]
    if len(nums) < 2:
        return None
    xs, ys = nums[0::2], nums[1::2]
    return min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)


class Outline(HTMLParser):
    def __init__(self, args: argparse.Namespace) -> None:
        super().__init__(convert_charrefs=True)
        self.args = args
        self.stack: list[dict] = []
        self.in_body = False
        self.skip = 0  # inside <helmet>/<style>/<script>
        self.lines: list[str] = []

    # -- helpers ---------------------------------------------------------
    def _origin(self) -> tuple[float, float]:
        x = y = 0.0
        for node in self.stack:
            if node.get("abs"):
                x += node.get("left") or 0.0
                y += node.get("top") or 0.0
        return x, y

    def _emit(self, depth: int, text: str) -> None:
        if self.args.max_depth is not None and depth > self.args.max_depth:
            return
        self.lines.append("  " * depth + text)

    # -- parser ----------------------------------------------------------
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "x-dc":
            self.in_body = True
            return
        if tag in ("helmet", "style", "script"):
            self.skip += 1
            return
        if not self.in_body or self.skip:
            return
        style = parse_style(a.get("style", ""))
        node = {"tag": tag, "abs": style.get("position") == "absolute"}
        for k in ("left", "top"):
            node[k] = px(style.get(k))
        depth = len(self.stack)
        if not self.args.text_only:
            bits = [tag]
            if a.get("class"):
                bits.append("." + ".".join(a["class"].split()))
            for key in ("aria-label", "role", "aria-pressed", "id", "alt"):
                if a.get(key):
                    bits.append(f"[{key}={a[key]}]")
            geom = {k: style[k] for k in GEOM_KEYS if k in style}
            if geom:
                bits.append("{" + ",".join(f"{k}:{v}" for k, v in geom.items()) + "}")
                if self.args.abs and node["abs"]:
                    ox, oy = self._origin()
                    l, t = node["left"], node["top"]
                    if l is not None and t is not None:
                        bits.append(f"@abs({ox + l:.1f},{oy + t:.1f})")
            if tag == "path" and a.get("d"):
                bb = path_bbox(a["d"])
                if bb:
                    bits.append("bbox(%.1f,%.1f,%.1f,%.1f)" % bb)
                for key in ("fill", "stroke", "transform"):
                    if a.get(key):
                        bits.append(f"{key}={a[key]}")
            cp = style.get("clip-path", "")
            if cp.startswith("path("):
                bb = path_bbox(cp)
                if bb:
                    bits.append("clip-bbox(%.1f,%.1f,%.1f,%.1f)" % bb)
            for key in ("transform", "background", "color", "font-size", "font-weight"):
                if key in style and key != "background":
                    bits.append(f"{key}={style[key]}")
            if "background" in style and "_blob" not in style["background"]:
                bits.append("bg=" + style["background"][:60])
            if tag == "img" and a.get("src"):
                bits.append("src=" + a["src"].rsplit("/", 1)[-1][:12])
            self._emit(depth, " ".join(bits))
        if tag not in VOID:
            self.stack.append(node)

    def handle_endtag(self, tag):
        if tag == "x-dc":
            self.in_body = False
            return
        if tag in ("helmet", "style", "script"):
            self.skip = max(0, self.skip - 1)
            return
        if not self.in_body or self.skip or tag in VOID:
            return
        while self.stack:
            node = self.stack.pop()
            if node["tag"] == tag:
                break

    def handle_data(self, data):
        if not self.in_body or self.skip:
            return
        text = " ".join(data.split())
        if text:
            self._emit(len(self.stack), f'"{text}"')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file")
    ap.add_argument("--abs", action="store_true", help="absolute 조상 좌표 누적값 표시")
    ap.add_argument("--text-only", action="store_true", help="텍스트만 출력")
    ap.add_argument("--max-depth", type=int, default=None)
    args = ap.parse_args()
    with open(args.file, encoding="utf-8") as fh:
        html = fh.read()
    p = Outline(args)
    p.feed(html)
    sys.stdout.reconfigure(encoding="utf-8")
    print("\n".join(p.lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
