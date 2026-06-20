from __future__ import annotations

import argparse
import importlib
import json
import re
import sys
import tkinter as tk
from datetime import datetime
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from PIL import Image, ImageTk

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from gui.ui_scale import get_ui_scale, scale_px

REGION_PATH = ROOT_DIR / "regions" / "student_normal_info_regions.json"
OUTPUT_DIR = ROOT_DIR / "templates" / "students"
METADATA_DIR = ROOT_DIR / "debug" / "student_template_extractor"
PREVIEW_MAX_WIDTH = 1400
PREVIEW_MAX_HEIGHT = 880


def _sanitize_name(value: str, fallback: str = "student_template") -> str:
    cleaned = re.sub(r"[\\/:*?\"<>|]+", "_", (value or "").strip())
    cleaned = re.sub(r"\s+", "_", cleaned).strip("._")
    return cleaned or fallback


def _load_region() -> dict[str, float]:
    payload = json.loads(REGION_PATH.read_text(encoding="utf-8-sig"))
    region = payload.get("student_texture_region")
    if not isinstance(region, dict):
        raise RuntimeError(f"student_texture_region not found in {REGION_PATH}")
    required = ("x1", "y1", "x2", "y2")
    if not all(key in region for key in required):
        raise RuntimeError(f"student_texture_region must contain {', '.join(required)}")
    return {key: float(region[key]) for key in required}


def _rect_from_region(image_size: tuple[int, int], region: dict[str, float]) -> tuple[int, int, int, int]:
    width, height = image_size
    left = int(round(width * region["x1"]))
    top = int(round(height * region["y1"]))
    right = int(round(width * region["x2"]))
    bottom = int(round(height * region["y2"]))
    return _clamp_rect((left, top, right, bottom), image_size)


def _clamp_rect(rect: tuple[int, int, int, int], image_size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = image_size
    left, top, right, bottom = rect
    left = max(0, min(left, width - 1))
    top = max(0, min(top, height - 1))
    right = max(left + 1, min(right, width))
    bottom = max(top + 1, min(bottom, height))
    return left, top, right, bottom


def _crop_template(image: Image.Image, rect: tuple[int, int, int, int]) -> Image.Image:
    return image.convert("RGBA").crop(rect)


def _write_metadata(
    *,
    student_id: str,
    source_path: Path,
    output_path: Path,
    source_size: tuple[int, int],
    crop_rect: tuple[int, int, int, int],
    region_source: Path,
) -> Path:
    METADATA_DIR.mkdir(parents=True, exist_ok=True)
    metadata_path = METADATA_DIR / f"{student_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    payload = {
        "student_id": student_id,
        "captured_at": datetime.now().isoformat(timespec="seconds"),
        "source_image_path": str(source_path),
        "source_size": {"width": source_size[0], "height": source_size[1]},
        "crop_box_image": {
            "left": crop_rect[0],
            "top": crop_rect[1],
            "right": crop_rect[2],
            "bottom": crop_rect[3],
        },
        "output_path": str(output_path),
        "region_source_path": str(region_source),
    }
    metadata_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return metadata_path


def _student_search_terms(student_id: str, meta: dict) -> list[str]:
    terms = [
        student_id,
        str(meta.get("display_name") or ""),
        str(meta.get("template_name") or ""),
    ]
    for key in ("search_tags", "kr_search_tags"):
        value = meta.get(key)
        if isinstance(value, (list, tuple, set)):
            terms.extend(str(item) for item in value)
        elif value:
            terms.extend(part.strip() for part in str(value).split(","))
    return [term.strip() for term in terms if term and term.strip()]


def resolve_student_id(query: str, *, allow_new: bool = False) -> str:
    raw = query.strip()
    if not raw:
        raise ValueError("student id is required")
    module = importlib.reload(importlib.import_module("core.student_meta"))
    students = dict(getattr(module, "STUDENTS", {}))
    if raw in students:
        return raw

    exact: list[str] = []
    partial: list[str] = []
    needle = raw.casefold()
    for student_id, meta in students.items():
        terms = _student_search_terms(student_id, dict(meta))
        if any(term.casefold() == needle for term in terms):
            exact.append(student_id)
        elif any(needle in term.casefold() for term in terms):
            partial.append(student_id)

    matches = exact or partial
    if not matches:
        if allow_new:
            return _sanitize_name(raw)
        raise ValueError(f"student not found: {query}")
    if len(matches) > 1:
        preview = ", ".join(matches[:8])
        suffix = " ..." if len(matches) > 8 else ""
        raise ValueError(f"student query is ambiguous: {query} -> {preview}{suffix}")
    return matches[0]


def default_student_id_from_image(path: Path) -> str:
    stem = path.stem
    stem = re.sub(r"(_student_texture|_template|_screenshot|_screen)$", "", stem, flags=re.IGNORECASE)
    return _sanitize_name(stem)


def save_student_template(
    *,
    image_path: Path,
    student_query: str,
    output_path: Path | None = None,
    crop_rect: tuple[int, int, int, int] | None = None,
    overwrite: bool = False,
) -> tuple[Path, Path, tuple[int, int, int, int]]:
    image = Image.open(image_path).convert("RGBA")
    student_id = resolve_student_id(student_query, allow_new=True)
    rect = crop_rect or _rect_from_region(image.size, _load_region())
    rect = _clamp_rect(rect, image.size)
    destination = output_path or (OUTPUT_DIR / f"{student_id}.png")
    if destination.exists() and not overwrite:
        raise FileExistsError(f"template already exists: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    crop = _crop_template(image, rect)
    crop.save(destination)
    metadata_path = _write_metadata(
        student_id=student_id,
        source_path=image_path,
        output_path=destination,
        source_size=image.size,
        crop_rect=rect,
        region_source=REGION_PATH,
    )
    return destination, metadata_path, rect


class StudentTemplateExtractor(tk.Tk):
    def __init__(self, *, initial_image: Path | None = None, student_query: str = "") -> None:
        super().__init__()
        self.title("Student Template Extractor")
        self.scale = get_ui_scale(self, base_width=1040, base_height=760)
        self.geometry(f"{scale_px(1120, self.scale)}x{scale_px(820, self.scale)}")
        self.minsize(scale_px(860, self.scale), scale_px(620, self.scale))

        self._student_var = tk.StringVar(value=student_query)
        self._overwrite_var = tk.BooleanVar(value=False)
        self._status_var = tk.StringVar(value="Open a student screen screenshot.")
        self._target_var = tk.StringVar(value=str(OUTPUT_DIR))
        self._source_path: Path | None = None
        self._source_image: Image.Image | None = None
        self._preview_image: Image.Image | None = None
        self._preview_photo: ImageTk.PhotoImage | None = None
        self._preview_scale = 1.0
        self._selection_preview: tuple[int, int, int, int] | None = None
        self._selection_canvas_id: int | None = None
        self._drag_start: tuple[int, int] | None = None

        self._build_ui()
        self._bind_events()
        if initial_image is not None:
            self._load_image(initial_image)

    def _pad(self) -> int:
        return scale_px(8, self.scale)

    def _build_ui(self) -> None:
        pad = self._pad()
        self.columnconfigure(0, weight=1)
        self.rowconfigure(2, weight=1)

        top = ttk.Frame(self, padding=pad)
        top.grid(row=0, column=0, sticky="ew")
        top.columnconfigure(2, weight=1)
        ttk.Button(top, text="Open Screenshot", command=self._choose_image).grid(row=0, column=0, padx=(0, pad))
        ttk.Label(top, text="Student").grid(row=0, column=1, padx=(0, pad))
        ttk.Entry(top, textvariable=self._student_var).grid(row=0, column=2, sticky="ew", padx=(0, pad))
        ttk.Button(top, text="Resolve", command=self._resolve_student).grid(row=0, column=3, padx=(0, pad))
        ttk.Button(top, text="Default ROI", command=self._apply_default_region).grid(row=0, column=4, padx=(0, pad))
        ttk.Checkbutton(top, text="Overwrite", variable=self._overwrite_var).grid(row=0, column=5)

        actions = ttk.Frame(self, padding=(pad, 0, pad, pad))
        actions.grid(row=1, column=0, sticky="ew")
        actions.columnconfigure(1, weight=1)
        ttk.Label(actions, text="Target").grid(row=0, column=0, sticky="w", padx=(0, pad))
        ttk.Label(actions, textvariable=self._target_var).grid(row=0, column=1, sticky="w")
        ttk.Button(actions, text="Save Template", command=self._save_template).grid(row=0, column=2, padx=(pad, 0))
        ttk.Button(actions, text="Save As", command=self._save_as).grid(row=0, column=3, padx=(pad, 0))

        canvas_frame = ttk.Frame(self, padding=(pad, 0, pad, pad))
        canvas_frame.grid(row=2, column=0, sticky="nsew")
        canvas_frame.columnconfigure(0, weight=1)
        canvas_frame.rowconfigure(0, weight=1)
        self._canvas = tk.Canvas(canvas_frame, bg="#111827", highlightthickness=0, cursor="crosshair")
        self._canvas.grid(row=0, column=0, sticky="nsew")

        status = ttk.Label(self, textvariable=self._status_var, anchor="w")
        status.grid(row=3, column=0, sticky="ew", padx=pad, pady=(0, pad))

    def _bind_events(self) -> None:
        self._canvas.bind("<ButtonPress-1>", self._on_press)
        self._canvas.bind("<B1-Motion>", self._on_drag)
        self._canvas.bind("<ButtonRelease-1>", self._on_release)
        self.bind("<Control-o>", lambda _event: self._choose_image())
        self.bind("<Control-s>", lambda _event: self._save_template())
        self.bind("<Escape>", lambda _event: self._clear_selection())

    def _choose_image(self) -> None:
        selected = filedialog.askopenfilename(
            title="Open student screen screenshot",
            filetypes=(("Images", "*.png;*.jpg;*.jpeg;*.bmp;*.webp"), ("All files", "*.*")),
        )
        if selected:
            self._load_image(Path(selected))

    def _load_image(self, path: Path) -> None:
        image = Image.open(path).convert("RGBA")
        self._source_path = path
        self._source_image = image
        if not self._student_var.get().strip():
            self._student_var.set(default_student_id_from_image(path))

        src_w, src_h = image.size
        scale = min(PREVIEW_MAX_WIDTH / max(src_w, 1), PREVIEW_MAX_HEIGHT / max(src_h, 1), 1.0)
        self._preview_scale = scale
        preview_size = (max(1, int(round(src_w * scale))), max(1, int(round(src_h * scale))))
        self._preview_image = image.resize(preview_size, Image.Resampling.LANCZOS) if scale < 1.0 else image.copy()
        self._preview_photo = ImageTk.PhotoImage(self._preview_image)

        self._canvas.delete("all")
        self._canvas.config(scrollregion=(0, 0, preview_size[0], preview_size[1]))
        self._canvas.create_image(0, 0, image=self._preview_photo, anchor="nw")
        self._selection_canvas_id = None
        self._apply_default_region()
        self._status_var.set(f"Loaded {path.name} | {src_w}x{src_h} | drag to adjust if needed.")
        self._refresh_target()

    def _resolve_student(self) -> None:
        try:
            student_id = resolve_student_id(self._student_var.get())
        except Exception as exc:
            messagebox.showerror("Resolve failed", str(exc))
            return
        self._student_var.set(student_id)
        self._refresh_target()
        self._status_var.set(f"Resolved: {student_id}")

    def _refresh_target(self) -> None:
        query = self._student_var.get().strip()
        if not query:
            self._target_var.set(str(OUTPUT_DIR))
            return
        try:
            student_id = resolve_student_id(query, allow_new=True)
        except Exception:
            student_id = _sanitize_name(query)
        self._target_var.set(str(OUTPUT_DIR / f"{student_id}.png"))

    def _preview_rect(self, rect_image: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
        return tuple(int(round(value * self._preview_scale)) for value in rect_image)  # type: ignore[return-value]

    def _image_rect(self, rect_preview: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
        if self._source_image is None:
            return rect_preview
        scale = max(self._preview_scale, 1e-6)
        rect = tuple(int(round(value / scale)) for value in rect_preview)
        return _clamp_rect(rect, self._source_image.size)  # type: ignore[arg-type]

    def _draw_selection(self, rect_preview: tuple[int, int, int, int]) -> None:
        self._selection_preview = rect_preview
        if self._selection_canvas_id is not None:
            self._canvas.delete(self._selection_canvas_id)
        self._selection_canvas_id = self._canvas.create_rectangle(*rect_preview, outline="#facc15", width=2)

    def _apply_default_region(self) -> None:
        if self._source_image is None:
            return
        rect = _rect_from_region(self._source_image.size, _load_region())
        self._draw_selection(self._preview_rect(rect))
        self._status_var.set("Default student_texture_region applied.")

    def _clear_selection(self) -> None:
        self._selection_preview = None
        if self._selection_canvas_id is not None:
            self._canvas.delete(self._selection_canvas_id)
            self._selection_canvas_id = None
        self._status_var.set("Selection cleared.")

    def _on_press(self, event) -> None:
        if self._preview_image is None:
            return
        x = int(self._canvas.canvasx(event.x))
        y = int(self._canvas.canvasy(event.y))
        self._drag_start = (x, y)
        if self._selection_canvas_id is not None:
            self._canvas.delete(self._selection_canvas_id)
        self._selection_canvas_id = self._canvas.create_rectangle(x, y, x, y, outline="#38bdf8", width=2)

    def _on_drag(self, event) -> None:
        if self._drag_start is None or self._selection_canvas_id is None:
            return
        x0, y0 = self._drag_start
        x1 = int(self._canvas.canvasx(event.x))
        y1 = int(self._canvas.canvasy(event.y))
        self._canvas.coords(self._selection_canvas_id, x0, y0, x1, y1)

    def _on_release(self, event) -> None:
        if self._preview_image is None or self._drag_start is None:
            return
        x0, y0 = self._drag_start
        x1 = int(self._canvas.canvasx(event.x))
        y1 = int(self._canvas.canvasy(event.y))
        left = max(0, min(x0, x1))
        top = max(0, min(y0, y1))
        right = min(self._preview_image.width, max(x0, x1))
        bottom = min(self._preview_image.height, max(y0, y1))
        self._drag_start = None
        if right - left < 2 or bottom - top < 2:
            self._status_var.set("Selection is too small.")
            return
        self._draw_selection((left, top, right, bottom))
        image_rect = self._image_rect((left, top, right, bottom))
        self._status_var.set(f"Manual crop: {image_rect}")

    def _save_as(self) -> None:
        query = self._student_var.get().strip()
        filename = f"{_sanitize_name(query)}.png" if query else "student_template.png"
        selected = filedialog.asksaveasfilename(
            title="Save student template",
            initialdir=str(OUTPUT_DIR),
            initialfile=filename,
            defaultextension=".png",
            filetypes=(("PNG", "*.png"), ("All files", "*.*")),
        )
        if selected:
            self._save_template(Path(selected))

    def _save_template(self, output_path: Path | None = None) -> None:
        if self._source_path is None or self._source_image is None:
            messagebox.showinfo("Student Template Extractor", "Open a screenshot first.")
            return
        if self._selection_preview is None:
            messagebox.showinfo("Student Template Extractor", "Select a crop region first.")
            return
        query = self._student_var.get().strip()
        if not query:
            messagebox.showinfo("Student Template Extractor", "Enter a student id or name.")
            return
        try:
            student_id = resolve_student_id(query)
            destination = output_path or (OUTPUT_DIR / f"{student_id}.png")
            if destination.exists() and not self._overwrite_var.get():
                ok = messagebox.askyesno("Overwrite?", f"{destination} already exists.\nOverwrite it?")
                if not ok:
                    return
            saved_path, metadata_path, rect = save_student_template(
                image_path=self._source_path,
                student_query=student_id,
                output_path=destination,
                crop_rect=self._image_rect(self._selection_preview),
                overwrite=True,
            )
        except Exception as exc:
            messagebox.showerror("Save failed", str(exc))
            return
        self._student_var.set(student_id)
        self._refresh_target()
        self._status_var.set(f"Saved {saved_path.name} | crop={rect} | metadata={metadata_path.name}")
        messagebox.showinfo("Saved", f"Saved:\n{saved_path}\n\nMetadata:\n{metadata_path}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extract templates/students/<student_id>.png from a student screen screenshot."
    )
    parser.add_argument("image", nargs="?", help="Student screen screenshot to open.")
    parser.add_argument("--student-id", "--student", dest="student_id", default="", help="Student id, display name, or search tag.")
    parser.add_argument("--output", default="", help="Optional output PNG path.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite an existing template file.")
    parser.add_argument("--save", action="store_true", help="Run headless crop/save using the default student_texture_region.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    image_path = Path(args.image).expanduser() if args.image else None
    if args.save:
        if image_path is None:
            parser.error("image is required with --save")
        student_query = args.student_id or default_student_id_from_image(image_path)
        saved_path, metadata_path, rect = save_student_template(
            image_path=image_path,
            student_query=student_query,
            output_path=Path(args.output).expanduser() if args.output else None,
            overwrite=args.overwrite,
        )
        print(f"saved: {saved_path}")
        print(f"metadata: {metadata_path}")
        print(f"crop: {rect}")
        return 0

    app = StudentTemplateExtractor(
        initial_image=image_path,
        student_query=args.student_id,
    )
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
