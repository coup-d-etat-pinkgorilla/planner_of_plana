from __future__ import annotations

import argparse
import importlib
import json
import queue
import re
import shutil
import subprocess
import sys
import threading
import tkinter as tk
from dataclasses import dataclass
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from urllib.parse import urlparse

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from gui.ui_scale import get_ui_scale, scale_px

RELEASE_DIR = ROOT_DIR / "release"
ASSET_ARCHIVE_BASENAME = "ba-planner-assets"
APP_ARCHIVE_BASENAME = "ba-planner-windows"
PATCH_ARCHIVE_BASENAME = "ba-planner-patch"
APP_MANIFEST_NAME = "app_manifest.json"
ASSET_MANIFEST_NAME = "asset_manifest.json"

STUDENT_TEMPLATE_DIR = ROOT_DIR / "templates" / "students"
PORTRAIT_TEMPLATE_DIR = ROOT_DIR / "templates" / "students_portraits"
STUDENT_ELEPH_DIR = ROOT_DIR / "templates" / "students_elephs"


@dataclass(frozen=True)
class StudentReference:
    raw: str
    student_id: str
    display_name: str
    jp_only: bool
    match_template: bool
    portrait: bool
    eleph: bool
    favorite_item_jp: bool
    favorite_item_kr: bool


@dataclass(frozen=True)
class UpdatePlan:
    version: str
    release_tag: str
    previous_manifest: Path | None
    github_repo: str
    latest_assets_release: str
    latest_app_release: str
    full_compile: bool
    jp_students: tuple[StudentReference, ...]
    kr_template_students: tuple[StudentReference, ...]
    server_state_students: tuple[StudentReference, ...]
    favorite_item_students: tuple[StudentReference, ...]
    build_command: tuple[str, ...]
    upload_command: tuple[str, ...] | None
    warnings: tuple[str, ...]


def _run(command: list[str], *, allow_failure: bool = False) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, cwd=ROOT_DIR, capture_output=True, text=True)
    if result.returncode != 0 and not allow_failure:
        if result.stdout:
            print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        raise subprocess.CalledProcessError(result.returncode, command)
    return result


def _gh_path() -> str:
    gh = shutil.which("gh")
    if gh:
        return gh
    winget_gh = (
        Path.home()
        / "AppData"
        / "Local"
        / "Microsoft"
        / "WinGet"
        / "Packages"
        / "GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe"
        / "bin"
        / "gh.exe"
    )
    if winget_gh.exists():
        return str(winget_gh)
    raise RuntimeError("GitHub CLI is not installed or not on PATH.")


def _git_remote_url(remote: str = "origin") -> str:
    result = _run(["git", "remote", "get-url", remote], allow_failure=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def _github_repo_from_remote(remote_url: str) -> str:
    text = remote_url.strip()
    if not text:
        return ""
    if text.startswith("git@github.com:"):
        path = text.removeprefix("git@github.com:")
    else:
        parsed = urlparse(text)
        if parsed.netloc.casefold() != "github.com":
            return ""
        path = parsed.path.lstrip("/")
    if path.endswith(".git"):
        path = path[:-4]
    parts = [part for part in path.split("/") if part]
    return "/".join(parts[:2]) if len(parts) >= 2 else ""


def _default_repo() -> str:
    return _github_repo_from_remote(_git_remote_url())


def _version_key(version: str) -> tuple[tuple[int, object], ...]:
    parts: list[tuple[int, object]] = []
    for token in re.findall(r"\d+|[A-Za-z]+", version.casefold()):
        parts.append((0, int(token)) if token.isdigit() else (1, token))
    return tuple(parts)


def _release_versions_with_manifest(manifest_name: str = ASSET_MANIFEST_NAME) -> list[str]:
    versions: list[str] = []
    if not RELEASE_DIR.exists():
        return versions
    for path in RELEASE_DIR.iterdir():
        if path.is_dir() and re.match(r"^\d", path.name) and (path / manifest_name).exists():
            versions.append(path.name)
    return sorted(versions, key=_version_key)


def _latest_release_version(manifest_name: str = ASSET_MANIFEST_NAME) -> str:
    versions = _release_versions_with_manifest(manifest_name)
    if not versions:
        return ""

    # Release directories can contain versions from an older numbering scheme
    # (for example 4.0.1 alongside the newer 0.6.x line).  Comparing version
    # numbers alone makes that old line win forever.  The manifest is generated
    # whenever a release is prepared, so its modification time identifies the
    # most recently prepared local release.  Keep the parsed version as a
    # deterministic tie-breaker for copied/restored files with equal mtimes.
    return max(
        versions,
        key=lambda version: (
            (RELEASE_DIR / version / manifest_name).stat().st_mtime_ns,
            _version_key(version),
        ),
    )


def _bump_last_version_number(version: str) -> str:
    matches = list(re.finditer(r"\d+", version))
    if not matches:
        return "0.0.1"
    last = matches[-1]
    bumped = str(int(last.group(0)) + 1)
    return f"{version[: last.start()]}{bumped}{version[last.end() :]}"


def _split_student_inputs(text: str) -> list[str]:
    parts = re.split(r"[\n,;]+", text)
    return [part.strip() for part in parts if part.strip()]


def _reload_student_meta():
    module = importlib.import_module("core.student_meta")
    return importlib.reload(module)


def _as_list(value: object) -> list[str]:
    if value is None:
        return []
    if isinstance(value, (list, tuple, set)):
        return [str(item).strip() for item in value if str(item).strip()]
    text = str(value).strip()
    return [part.strip() for part in text.split(",") if part.strip()] if text else []


def _resolve_asset_path(base_dir: Path, stem: str) -> Path | None:
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        candidate = base_dir / f"{stem}{ext}"
        if candidate.exists():
            return candidate
    return None


def _student_reference(module, raw: str) -> StudentReference:
    students = dict(getattr(module, "STUDENTS", {}))
    jp_only_ids = set(getattr(module, "JP_ONLY_STUDENT_IDS", frozenset()))
    query = raw.strip()
    query_key = query.casefold()
    matches: list[str] = []

    if query in students:
        matches = [query]
    else:
        for student_id, meta in students.items():
            names = [
                student_id,
                str(meta.get("display_name") or ""),
                str(meta.get("template_name") or ""),
            ]
            names.extend(_as_list(meta.get("search_tags")))
            names.extend(_as_list(meta.get("kr_search_tags")))
            if any(name.casefold() == query_key for name in names if name):
                matches.append(student_id)

    if not matches:
        partial_matches: list[str] = []
        for student_id, meta in students.items():
            blob_terms = [
                student_id,
                str(meta.get("display_name") or ""),
                str(meta.get("template_name") or ""),
            ]
            blob_terms.extend(_as_list(meta.get("search_tags")))
            blob_terms.extend(_as_list(meta.get("kr_search_tags")))
            if any(query_key in term.casefold() for term in blob_terms if term):
                partial_matches.append(student_id)
        matches = partial_matches

    if not matches:
        raise ValueError(f"학생을 찾을 수 없습니다: {raw}")
    if len(matches) > 1:
        joined = ", ".join(matches[:8])
        suffix = " ..." if len(matches) > 8 else ""
        raise ValueError(f"학생 이름이 여러 명과 일치합니다: {raw} -> {joined}{suffix}")

    student_id = matches[0]
    meta = dict(students[student_id])
    return StudentReference(
        raw=raw,
        student_id=student_id,
        display_name=str(meta.get("display_name") or student_id),
        jp_only=student_id in jp_only_ids,
        match_template=_resolve_asset_path(STUDENT_TEMPLATE_DIR, student_id) is not None,
        portrait=_resolve_asset_path(PORTRAIT_TEMPLATE_DIR, student_id) is not None,
        eleph=_resolve_asset_path(STUDENT_ELEPH_DIR, f"Item_Icon_SecretStone_{student_id}") is not None,
        favorite_item_jp=bool(module.favorite_item_enabled(student_id, server="jp")),
        favorite_item_kr=bool(module.favorite_item_enabled(student_id, server="kr")),
    )


def _resolve_students(text: str) -> tuple[StudentReference, ...]:
    module = _reload_student_meta()
    seen: set[str] = set()
    refs: list[StudentReference] = []
    for raw in _split_student_inputs(text):
        ref = _student_reference(module, raw)
        if ref.student_id in seen:
            continue
        seen.add(ref.student_id)
        refs.append(ref)
    return tuple(refs)


def _required_release_files(version: str, *, full_compile: bool) -> list[Path]:
    release_dir = RELEASE_DIR / version
    files = [
        release_dir / f"{ASSET_ARCHIVE_BASENAME}-{version}.zip",
        release_dir / ASSET_MANIFEST_NAME,
    ]
    if full_compile:
        files.extend(
            [
                release_dir / f"{APP_ARCHIVE_BASENAME}-{version}.zip",
                release_dir / APP_MANIFEST_NAME,
            ]
        )
    return files


def _load_asset_manifest(version: str) -> dict:
    manifest_path = RELEASE_DIR / version / ASSET_MANIFEST_NAME
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def _create_or_upload_release(
    *,
    gh: str,
    repo: str,
    tag: str,
    title: str,
    notes: str,
    files: list[Path],
    prerelease: bool,
) -> None:
    result = _run([gh, "release", "view", tag, "--repo", repo], allow_failure=True)
    existing_files = [str(path) for path in files]
    if result.returncode == 0:
        _run([gh, "release", "upload", tag, *existing_files, "--repo", repo, "--clobber"])
        return

    command = [
        gh,
        "release",
        "create",
        tag,
        *existing_files,
        "--repo",
        repo,
        "--title",
        title,
        "--notes",
        notes,
        "--latest=false",
    ]
    if prerelease:
        command.append("--prerelease")
    _run(command)


def publish_asset_update(version: str, repo: str, release_tag: str, latest_assets_release: str) -> None:
    gh = _gh_path()
    release_dir = RELEASE_DIR / version
    upload_files = [
        release_dir / ASSET_MANIFEST_NAME,
        release_dir / f"{ASSET_ARCHIVE_BASENAME}-{version}.zip",
    ]
    manifest = _load_asset_manifest(version)
    for patch in manifest.get("patches") or ():
        name = str(patch.get("archive_name") or "")
        if name:
            upload_files.append(release_dir / name)

    missing = [path for path in upload_files if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing release file(s):\n" + "\n".join(str(path) for path in missing))

    _create_or_upload_release(
        gh=gh,
        repo=repo,
        tag=release_tag,
        title=f"BA Planner Asset Update {version}",
        notes="BA Planner asset-only update. The app downloads this through asset_manifest.json.",
        files=upload_files,
        prerelease=True,
    )
    _create_or_upload_release(
        gh=gh,
        repo=repo,
        tag=latest_assets_release,
        title="BA Planner Latest Assets",
        notes="Stable asset manifest endpoint used by BA Planner update checks.",
        files=[release_dir / ASSET_MANIFEST_NAME],
        prerelease=False,
    )


def publish_full_update(version: str, repo: str, latest_assets_release: str, latest_app_release: str) -> None:
    command = [
        sys.executable,
        str(ROOT_DIR / "tools" / "publish_beta_release.py"),
        "--version",
        version,
        "--repo",
        repo,
        "--latest-manifest-release",
        latest_assets_release,
        "--latest-app-manifest-release",
        latest_app_release,
    ]
    subprocess.run(command, cwd=ROOT_DIR, check=True)


def _quote_command(command: tuple[str, ...] | list[str]) -> str:
    return " ".join(f'"{part}"' if " " in part else part for part in command)


def _write_update_notes(plan: UpdatePlan) -> Path:
    release_dir = RELEASE_DIR / plan.version
    release_dir.mkdir(parents=True, exist_ok=True)
    notes_path = release_dir / f"update_wizard_notes_{plan.version}.md"
    lines = [
        f"# BA Planner Update {plan.version}",
        "",
        "## Type",
        "",
        f"- Full compile: `{plan.full_compile}`",
        f"- JP student data: `{bool(plan.jp_students)}`",
        f"- KR template matching assets: `{bool(plan.kr_template_students)}`",
        f"- JP-only server-state changes: `{bool(plan.server_state_students)}`",
        f"- Favorite-item metadata changes: `{bool(plan.favorite_item_students)}`",
        "",
        "## Students",
        "",
    ]
    groups = (
        ("JP student data", plan.jp_students),
        ("KR template matching", plan.kr_template_students),
        ("Server-state change", plan.server_state_students),
        ("Favorite-item metadata change", plan.favorite_item_students),
    )
    any_student = False
    for label, refs in groups:
        if not refs:
            continue
        any_student = True
        lines.append(f"### {label}")
        lines.append("")
        for ref in refs:
            lines.append(
                f"- `{ref.student_id}` | {ref.display_name} | JP-only={ref.jp_only} | "
                f"match={ref.match_template} portrait={ref.portrait} eleph={ref.eleph}"
                f" favorite_item_jp={ref.favorite_item_jp} favorite_item_kr={ref.favorite_item_kr}"
            )
        lines.append("")
    if not any_student:
        lines.append("- No student names were entered.")
        lines.append("")

    lines.extend(
        [
            "## Commands",
            "",
            f"- Build: `{_quote_command(plan.build_command)}`",
        ]
    )
    if plan.upload_command:
        lines.append(f"- Upload: `{_quote_command(plan.upload_command)}`")
    if plan.previous_manifest:
        lines.extend(["", "## Previous Manifest", "", f"- `{plan.previous_manifest}`"])
    if plan.warnings:
        lines.extend(["", "## Warnings", ""])
        lines.extend(f"- {warning}" for warning in plan.warnings)
    notes_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return notes_path


class UpdateWizardApp:
    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title("BA Planner 업데이트 관리 마법사")
        self.scale = get_ui_scale(self.root, base_width=980, base_height=760)
        self.root.geometry(f"{scale_px(980, self.scale)}x{scale_px(760, self.scale)}")
        self.root.minsize(scale_px(860, self.scale), scale_px(640, self.scale))
        self._queue: queue.Queue[tuple[str, str]] = queue.Queue()
        self._running = False
        self._last_plan: UpdatePlan | None = None

        latest_version = _latest_release_version()
        next_version = _bump_last_version_number(latest_version) if latest_version else "0.0.1"
        previous_manifest = str(RELEASE_DIR / latest_version / ASSET_MANIFEST_NAME) if latest_version else ""

        self.jp_update_var = tk.BooleanVar(value=True)
        self.kr_template_var = tk.BooleanVar(value=False)
        self.server_state_var = tk.BooleanVar(value=False)
        self.favorite_item_var = tk.BooleanVar(value=False)
        self.full_compile_var = tk.BooleanVar(value=False)
        self.run_hygiene_var = tk.BooleanVar(value=True)

        self.version_var = tk.StringVar(value=next_version)
        self.previous_manifest_var = tk.StringVar(value=previous_manifest)
        self.github_repo_var = tk.StringVar(value=_default_repo())
        self.release_tag_var = tk.StringVar(value=f"v{next_version}")
        self.latest_assets_release_var = tk.StringVar(value="latest-assets")
        self.latest_app_release_var = tk.StringVar(value="latest-app")
        self.status_var = tk.StringVar(value="준비됨")

        self.jp_text: tk.Text
        self.kr_text: tk.Text
        self.server_text: tk.Text
        self.favorite_item_text: tk.Text
        self.log_text: tk.Text

        self._build_ui()
        self.version_var.trace_add("write", self._sync_release_tag)
        self.root.after(100, self._poll_queue)

    def _pad(self) -> int:
        return scale_px(8, self.scale)

    def _build_ui(self) -> None:
        pad = self._pad()
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(1, weight=1)

        header = ttk.Frame(self.root, padding=(pad, pad, pad, 0))
        header.grid(row=0, column=0, sticky="ew")
        header.columnconfigure(1, weight=1)
        ttk.Label(header, text="업데이트 형태 선택", font=("", scale_px(13, self.scale), "bold")).grid(row=0, column=0, sticky="w")
        ttk.Label(header, textvariable=self.status_var).grid(row=0, column=1, sticky="e")

        body = ttk.PanedWindow(self.root, orient=tk.HORIZONTAL)
        body.grid(row=1, column=0, sticky="nsew", padx=pad, pady=pad)

        left = ttk.Frame(body, padding=pad)
        right = ttk.Frame(body, padding=pad)
        body.add(left, weight=3)
        body.add(right, weight=2)
        left.columnconfigure(0, weight=1)
        left.rowconfigure(2, weight=1)
        right.columnconfigure(0, weight=1)
        right.rowconfigure(1, weight=1)

        type_frame = ttk.LabelFrame(left, text="업데이트 작업")
        type_frame.grid(row=0, column=0, sticky="ew")
        for index, (label, var) in enumerate(
            (
                ("일본 서버 학생 데이터 추가", self.jp_update_var),
                ("한국 서버 학생 템플릿 매칭 파일 추가/업로드", self.kr_template_var),
                ("일본 서버 전용 학생의 서버 상태 변경", self.server_state_var),
                ("학생 애장품 서버별 상태 추가/변경", self.favorite_item_var),
                ("전체 컴파일 후 신규 앱 버전 업데이트", self.full_compile_var),
            )
        ):
            ttk.Checkbutton(type_frame, text=label, variable=var, command=self._on_type_changed).grid(
                row=index // 2,
                column=index % 2,
                sticky="w",
                padx=pad,
                pady=scale_px(4, self.scale),
            )

        version_frame = ttk.LabelFrame(left, text="버전과 릴리스")
        version_frame.grid(row=1, column=0, sticky="ew", pady=(pad, 0))
        version_frame.columnconfigure(1, weight=1)
        version_frame.columnconfigure(3, weight=1)

        ttk.Label(version_frame, text="버전").grid(row=0, column=0, sticky="w", padx=pad, pady=scale_px(4, self.scale))
        ttk.Entry(version_frame, textvariable=self.version_var).grid(row=0, column=1, sticky="ew", padx=pad, pady=scale_px(4, self.scale))
        ttk.Label(version_frame, text="릴리스 태그").grid(row=0, column=2, sticky="w", padx=pad, pady=scale_px(4, self.scale))
        ttk.Entry(version_frame, textvariable=self.release_tag_var).grid(row=0, column=3, sticky="ew", padx=pad, pady=scale_px(4, self.scale))

        ttk.Label(version_frame, text="이전 매니페스트").grid(row=1, column=0, sticky="w", padx=pad, pady=scale_px(4, self.scale))
        ttk.Entry(version_frame, textvariable=self.previous_manifest_var).grid(row=1, column=1, columnspan=2, sticky="ew", padx=pad, pady=scale_px(4, self.scale))
        ttk.Button(version_frame, text="찾기", command=self._browse_previous_manifest).grid(row=1, column=3, sticky="ew", padx=pad, pady=scale_px(4, self.scale))

        ttk.Label(version_frame, text="GitHub repo").grid(row=2, column=0, sticky="w", padx=pad, pady=scale_px(4, self.scale))
        ttk.Entry(version_frame, textvariable=self.github_repo_var).grid(row=2, column=1, sticky="ew", padx=pad, pady=scale_px(4, self.scale))
        ttk.Label(version_frame, text="latest-assets").grid(row=2, column=2, sticky="w", padx=pad, pady=scale_px(4, self.scale))
        ttk.Entry(version_frame, textvariable=self.latest_assets_release_var).grid(row=2, column=3, sticky="ew", padx=pad, pady=scale_px(4, self.scale))

        ttk.Label(version_frame, text="latest-app").grid(row=3, column=2, sticky="w", padx=pad, pady=scale_px(4, self.scale))
        ttk.Entry(version_frame, textvariable=self.latest_app_release_var).grid(row=3, column=3, sticky="ew", padx=pad, pady=scale_px(4, self.scale))
        ttk.Checkbutton(version_frame, text="빌드 전 저장소 위생 검사 실행", variable=self.run_hygiene_var).grid(
            row=3, column=0, columnspan=2, sticky="w", padx=pad, pady=scale_px(4, self.scale)
        )

        students = ttk.Notebook(left)
        students.grid(row=2, column=0, sticky="nsew", pady=(pad, 0))
        self.jp_text = self._student_tab(students, "JP 학생 데이터", "메타데이터 관리자에서 만든 학생 ID, 표시명, 검색 태그를 입력")
        self.kr_text = self._student_tab(students, "KR 템플릿", "한국 서버 템플릿 매칭 이미지가 준비된 학생 입력")
        self.server_text = self._student_tab(students, "서버 상태 변경", "JP-only에서 KR로 넘어간 학생 입력")
        self.favorite_item_text = self._student_tab(
            students,
            "애장품 상태 변경",
            "메타데이터 관리자에서 JP/KR 애장품 값을 저장한 학생 입력",
        )

        action_frame = ttk.Frame(left)
        action_frame.grid(row=3, column=0, sticky="ew", pady=(pad, 0))
        for index in range(5):
            action_frame.columnconfigure(index, weight=1)
        ttk.Button(action_frame, text="메타데이터 관리자 열기", command=self._open_metadata_manager).grid(row=0, column=0, sticky="ew", padx=(0, pad))
        ttk.Button(action_frame, text="계획 미리보기", command=self._preview_plan).grid(row=0, column=1, sticky="ew", padx=(0, pad))
        ttk.Button(action_frame, text="빌드만 실행", command=lambda: self._start_work(upload=False)).grid(row=0, column=2, sticky="ew", padx=(0, pad))
        ttk.Button(action_frame, text="빌드 후 업로드", command=lambda: self._start_work(upload=True)).grid(row=0, column=3, sticky="ew", padx=(0, pad))
        ttk.Button(action_frame, text="닫기", command=self.root.destroy).grid(row=0, column=4, sticky="ew")

        ttk.Label(right, text="실행 로그", font=("", scale_px(12, self.scale), "bold")).grid(row=0, column=0, sticky="w")
        self.log_text = tk.Text(right, wrap="word", height=24)
        self.log_text.grid(row=1, column=0, sticky="nsew", pady=(pad, 0))
        log_scroll = ttk.Scrollbar(right, orient=tk.VERTICAL, command=self.log_text.yview)
        log_scroll.grid(row=1, column=1, sticky="ns", pady=(pad, 0))
        self.log_text.configure(yscrollcommand=log_scroll.set)

        self._log("메타데이터 관리자로 학생을 먼저 저장한 뒤, 여기에는 이름이나 student_id만 적으면 됩니다.")
        self._log(f"자동 제안 버전: {self.version_var.get()}")

    def _student_tab(self, notebook: ttk.Notebook, title: str, hint: str) -> tk.Text:
        pad = self._pad()
        frame = ttk.Frame(notebook, padding=pad)
        frame.columnconfigure(0, weight=1)
        frame.rowconfigure(1, weight=1)
        ttk.Label(frame, text=hint).grid(row=0, column=0, sticky="w")
        text = tk.Text(frame, height=8, wrap="word")
        text.grid(row=1, column=0, sticky="nsew", pady=(pad, 0))
        notebook.add(frame, text=title)
        return text

    def _sync_release_tag(self, *_args) -> None:
        version = self.version_var.get().strip()
        expected = f"v{version}" if version else ""
        current = self.release_tag_var.get().strip()
        if not current or current == "v" or re.fullmatch(r"v[\w.\-]+", current):
            self.release_tag_var.set(expected)

    def _on_type_changed(self) -> None:
        if self.full_compile_var.get():
            self.status_var.set("전체 컴파일 업데이트: 앱 zip과 앱 매니페스트까지 생성합니다.")
        else:
            self.status_var.set("간이 업데이트: 자산 zip, 패치 zip, asset_manifest.json만 생성합니다.")

    def _browse_previous_manifest(self) -> None:
        path = filedialog.askopenfilename(
            title="이전 asset_manifest.json 선택",
            initialdir=str(RELEASE_DIR),
            filetypes=(("Asset manifest", "asset_manifest.json"), ("JSON", "*.json"), ("All files", "*.*")),
        )
        if path:
            self.previous_manifest_var.set(path)

    def _open_metadata_manager(self) -> None:
        try:
            subprocess.Popen([sys.executable, str(ROOT_DIR / "tools" / "student_meta_tool.py")], cwd=ROOT_DIR)
        except Exception as exc:
            messagebox.showerror("메타데이터 관리자 실행 실패", str(exc))

    def _log(self, text: str) -> None:
        self.log_text.insert(tk.END, text.rstrip() + "\n")
        self.log_text.see(tk.END)

    def _queue_log(self, text: str) -> None:
        self._queue.put(("log", text))

    def _collect_plan(self) -> UpdatePlan:
        version = self.version_var.get().strip()
        release_tag = self.release_tag_var.get().strip() or f"v{version}"
        repo = self.github_repo_var.get().strip()
        latest_assets = self.latest_assets_release_var.get().strip() or "latest-assets"
        latest_app = self.latest_app_release_var.get().strip() or "latest-app"
        if not version:
            raise ValueError("버전을 입력하세요.")
        if not repo:
            raise ValueError("GitHub repo를 입력하세요. 예: owner/repo")
        previous_manifest_text = self.previous_manifest_var.get().strip()
        previous_manifest = Path(previous_manifest_text) if previous_manifest_text else None
        if previous_manifest is not None and not previous_manifest.exists():
            raise FileNotFoundError(f"이전 매니페스트를 찾을 수 없습니다: {previous_manifest}")

        jp_students = _resolve_students(self.jp_text.get("1.0", tk.END)) if self.jp_update_var.get() else ()
        kr_students = _resolve_students(self.kr_text.get("1.0", tk.END)) if self.kr_template_var.get() else ()
        server_students = _resolve_students(self.server_text.get("1.0", tk.END)) if self.server_state_var.get() else ()
        favorite_item_students = _resolve_students(self.favorite_item_text.get("1.0", tk.END)) if self.favorite_item_var.get() else ()
        full_compile = self.full_compile_var.get()

        if not full_compile and not (
            self.jp_update_var.get()
            or self.kr_template_var.get()
            or self.server_state_var.get()
            or self.favorite_item_var.get()
        ):
            raise ValueError("간이 업데이트로 처리할 작업을 하나 이상 선택하세요.")

        warnings: list[str] = []
        for ref in jp_students:
            if not ref.jp_only:
                warnings.append(f"{ref.student_id}는 현재 JP-only가 아닙니다. 일본 서버 전용 추가가 맞는지 확인하세요.")
            if not ref.portrait or not ref.eleph:
                warnings.append(f"{ref.student_id}의 portrait/eleph 자산이 일부 없습니다.")
        for ref in kr_students:
            if not ref.match_template:
                warnings.append(f"{ref.student_id}의 템플릿 매칭 파일이 없습니다: templates/students/{ref.student_id}.png")
            if ref.jp_only:
                warnings.append(f"{ref.student_id}는 아직 JP-only입니다. 한국 서버 학생이면 메타데이터 관리자에서 서버 상태를 KR로 바꾸세요.")
        for ref in server_students:
            if ref.jp_only:
                warnings.append(f"{ref.student_id}는 아직 JP-only입니다. 서버 상태 변경 저장 여부를 확인하세요.")
            if not ref.portrait:
                warnings.append(f"{ref.student_id}의 portrait 자산이 없습니다. KR 표시용 템플릿이 필요한지 확인하세요.")
        for ref in favorite_item_students:
            if not ref.favorite_item_jp and not ref.favorite_item_kr:
                warnings.append(f"{ref.student_id}는 JP/KR 모두 애장품 없음으로 저장되어 있습니다.")
            if ref.favorite_item_kr and not ref.favorite_item_jp:
                warnings.append(f"{ref.student_id}는 KR에만 애장품이 있고 JP에는 없습니다. 서버 값을 확인하세요.")

        build_command = [
            sys.executable,
            str(ROOT_DIR / "tools" / "build_beta_release.py"),
            "--version",
            version,
            "--github-release",
            release_tag,
            "--github-repo",
            repo,
            "--latest-manifest-release",
            latest_assets,
            "--latest-app-manifest-release",
            latest_app,
        ]
        if previous_manifest is not None:
            build_command.extend(["--previous-manifest", str(previous_manifest)])
        if not full_compile:
            build_command.append("--skip-exe")

        upload_command: tuple[str, ...] | None
        if full_compile:
            upload_command = (
                sys.executable,
                str(ROOT_DIR / "tools" / "publish_beta_release.py"),
                "--version",
                version,
                "--repo",
                repo,
                "--release-tag",
                release_tag,
                "--latest-manifest-release",
                latest_assets,
                "--latest-app-manifest-release",
                latest_app,
            )
        else:
            upload_command = (
                sys.executable,
                str(ROOT_DIR / "tools" / "update_wizard.py"),
                "publish-assets",
                "--version",
                version,
                "--repo",
                repo,
                "--release-tag",
                release_tag,
                "--latest-assets-release",
                latest_assets,
            )

        return UpdatePlan(
            version=version,
            release_tag=release_tag,
            previous_manifest=previous_manifest,
            github_repo=repo,
            latest_assets_release=latest_assets,
            latest_app_release=latest_app,
            full_compile=full_compile,
            jp_students=jp_students,
            kr_template_students=kr_students,
            server_state_students=server_students,
            favorite_item_students=favorite_item_students,
            build_command=tuple(build_command),
            upload_command=upload_command,
            warnings=tuple(warnings),
        )

    def _preview_plan(self) -> UpdatePlan | None:
        try:
            plan = self._collect_plan()
        except Exception as exc:
            messagebox.showerror("계획 생성 실패", str(exc))
            return None
        self._last_plan = plan
        self._log("")
        self._log(f"[계획] {'전체 컴파일' if plan.full_compile else '간이 자산 업데이트'}")
        self._log(f"버전: {plan.version} / 태그: {plan.release_tag}")
        if plan.previous_manifest:
            self._log(f"이전 매니페스트: {plan.previous_manifest}")
        for label, refs in (
            ("JP 학생", plan.jp_students),
            ("KR 템플릿", plan.kr_template_students),
            ("서버 상태 변경", plan.server_state_students),
            ("애장품 상태 변경", plan.favorite_item_students),
        ):
            if refs:
                self._log(f"{label}: " + ", ".join(f"{r.student_id}({r.display_name})" for r in refs))
        if plan.warnings:
            self._log("[확인 필요]")
            for warning in plan.warnings:
                self._log(f"- {warning}")
        self._log("[빌드 명령]")
        self._log(_quote_command(plan.build_command))
        self._log("[업로드 명령]")
        self._log(_quote_command(plan.upload_command or ()))
        self.status_var.set("계획 미리보기 완료")
        return plan

    def _start_work(self, *, upload: bool) -> None:
        if self._running:
            messagebox.showinfo("실행 중", "이미 작업이 실행 중입니다.")
            return
        plan = self._preview_plan()
        if plan is None:
            return
        if upload and plan.warnings:
            if not messagebox.askyesno("확인 필요", "경고가 있습니다. 그래도 빌드 후 업로드할까요?"):
                return
        self._running = True
        self.status_var.set("실행 중...")
        thread = threading.Thread(target=self._worker, args=(plan, upload), daemon=True)
        thread.start()

    def _run_streaming(self, command: tuple[str, ...]) -> None:
        self._queue_log("$ " + _quote_command(command))
        process = subprocess.Popen(
            list(command),
            cwd=ROOT_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        assert process.stdout is not None
        for line in process.stdout:
            self._queue_log(line.rstrip())
        code = process.wait()
        if code != 0:
            raise subprocess.CalledProcessError(code, list(command))

    def _worker(self, plan: UpdatePlan, upload: bool) -> None:
        try:
            if self.run_hygiene_var.get():
                self._run_streaming((sys.executable, str(ROOT_DIR / "tools" / "check_release_repo_hygiene.py")))
            self._run_streaming(plan.build_command)
            notes_path = _write_update_notes(plan)
            self._queue_log(f"릴리스 노트: {notes_path}")
            for path in _required_release_files(plan.version, full_compile=plan.full_compile):
                if not path.exists():
                    raise FileNotFoundError(f"필수 산출물이 없습니다: {path}")
            if upload and plan.upload_command:
                self._run_streaming(plan.upload_command)
                self._queue_log("업로드 완료")
            self._queue.put(("status", "완료"))
        except Exception as exc:
            self._queue_log(f"실패: {exc}")
            self._queue.put(("status", "실패"))
        finally:
            self._queue.put(("done", ""))

    def _poll_queue(self) -> None:
        try:
            while True:
                kind, text = self._queue.get_nowait()
                if kind == "log":
                    self._log(text)
                elif kind == "status":
                    self.status_var.set(text)
                elif kind == "done":
                    self._running = False
        except queue.Empty:
            pass
        self.root.after(100, self._poll_queue)

    def run(self) -> int:
        self.root.mainloop()
        return 0


def command_gui(_args: argparse.Namespace) -> int:
    return UpdateWizardApp().run()


def command_publish_assets(args: argparse.Namespace) -> int:
    publish_asset_update(args.version, args.repo, args.release_tag or f"v{args.version}", args.latest_assets_release)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="BA Planner update management wizard.")
    subparsers = parser.add_subparsers(dest="command")
    gui_parser = subparsers.add_parser("gui", help="Open the update wizard UI.")
    gui_parser.set_defaults(func=command_gui)

    publish_parser = subparsers.add_parser("publish-assets", help="Upload an asset-only update release.")
    publish_parser.add_argument("--version", required=True)
    publish_parser.add_argument("--repo", required=True)
    publish_parser.add_argument("--release-tag", default="")
    publish_parser.add_argument("--latest-assets-release", default="latest-assets")
    publish_parser.set_defaults(func=command_publish_assets)
    return parser


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv:
        argv = ["gui"]
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args) if hasattr(args, "func") else command_gui(args)


if __name__ == "__main__":
    raise SystemExit(main())
