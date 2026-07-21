"""Receive one BA Planner slave handoff over a trusted local network."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer
from threading import Event, Thread
from urllib.parse import urlparse


EXPECTED_SUFFIXES = (
    ".zip",
    ".sha256",
    ".manifest.json",
    "-MASTER_PROMPT.md",
)
DISCOVERY_SERVICE = "BA_PLANNER_HANDOFF_DISCOVERY_V1"


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Receive a four-file cross-PC slave handoff over LAN."
    )
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--token", default="")
    parser.add_argument("--discovery-port", type=int, default=8766)
    parser.add_argument("--no-discovery", action="store_true")
    parser.add_argument("--show-token", action="store_true")
    parser.add_argument("--max-file-bytes", type=int, default=512 * 1024 * 1024)
    return parser.parse_args()


def _local_ipv4_addresses() -> list[str]:
    addresses: set[str] = set()
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            address = info[4][0]
            if not address.startswith("127."):
                addresses.add(address)
    except socket.gaierror:
        pass
    return sorted(addresses)


def _base_name(filename: str) -> str | None:
    for suffix in sorted(EXPECTED_SUFFIXES, key=len, reverse=True):
        if filename.endswith(suffix):
            return filename[: -len(suffix)]
    return None


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _serve_discovery(
    discovery_socket: socket.socket,
    stop_event: Event,
    task_id: str,
    token: str,
    upload_urls: list[str],
    http_port: int,
) -> None:
    discovery_socket.settimeout(0.5)
    while not stop_event.is_set():
        try:
            data, address = discovery_socket.recvfrom(4096)
        except socket.timeout:
            continue
        except OSError:
            break
        try:
            request = json.loads(data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
        if request.get("service") != DISCOVERY_SERVICE:
            continue
        if request.get("task_id") != task_id:
            continue
        nonce = request.get("nonce")
        if not isinstance(nonce, str) or not 8 <= len(nonce) <= 128:
            continue
        response = {
            "service": DISCOVERY_SERVICE,
            "task_id": task_id,
            "nonce": nonce,
            "upload_urls": upload_urls,
            "port": http_port,
            "token": token,
        }
        try:
            discovery_socket.sendto(
                json.dumps(response).encode("utf-8"), address
            )
        except OSError:
            break


def _validate_complete(destination: Path, base_name: str) -> dict[str, object]:
    paths = {suffix: destination / f"{base_name}{suffix}" for suffix in EXPECTED_SUFFIXES}
    missing = [str(path.name) for path in paths.values() if not path.is_file()]
    if missing:
        raise ValueError(f"missing transfer files: {', '.join(missing)}")

    manifest = json.loads(paths[".manifest.json"].read_text(encoding="utf-8-sig"))
    package = paths[".zip"]
    actual_size = package.stat().st_size
    actual_hash = _sha256(package)
    if manifest.get("package") != package.name:
        raise ValueError("manifest package name does not match the received ZIP")
    if manifest.get("package_size") != actual_size:
        raise ValueError("manifest package size does not match the received ZIP")
    if str(manifest.get("package_sha256", "")).lower() != actual_hash:
        raise ValueError("manifest SHA-256 does not match the received ZIP")

    sidecar_hash = paths[".sha256"].read_text(encoding="utf-8-sig").split()[0].lower()
    if sidecar_hash != actual_hash:
        raise ValueError(".sha256 sidecar does not match the received ZIP")

    return {
        "package": str(package),
        "package_size": actual_size,
        "package_sha256": actual_hash,
        "master_prompt": str(paths["-MASTER_PROMPT.md"]),
    }


def main() -> int:
    args = _parse_args()
    if not 1 <= args.port <= 65535:
        raise SystemExit("--port must be between 1 and 65535")
    if not 1 <= args.discovery_port <= 65535:
        raise SystemExit("--discovery-port must be between 1 and 65535")
    if args.max_file_bytes <= 0:
        raise SystemExit("--max-file-bytes must be positive")
    if any(character in args.task_id for character in "\\/:"):
        raise SystemExit("--task-id contains an invalid path character")

    destination = args.destination.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    token = args.token or secrets.token_urlsafe(32)
    state: dict[str, object] = {"base_name": None, "received": set()}
    stop_event = Event()

    class Handler(BaseHTTPRequestHandler):
        server_version = "BAPlannerHandoff/1"

        def _reply(self, status: int, payload: dict[str, object]) -> None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_PUT(self) -> None:  # noqa: N802 - HTTP handler API
            if urlparse(self.path).path != "/upload":
                self._reply(404, {"error": "unknown endpoint"})
                return
            if self.headers.get("Authorization") != f"Bearer {token}":
                self._reply(401, {"error": "invalid bearer token"})
                return

            filename = self.headers.get("X-File-Name", "")
            if not filename or filename != Path(filename).name:
                self._reply(400, {"error": "invalid X-File-Name"})
                return
            base_name = _base_name(filename)
            if base_name is None or not base_name.startswith(f"{args.task_id}-"):
                self._reply(400, {"error": "file name is not valid for this task"})
                return
            if state["base_name"] not in (None, base_name):
                self._reply(409, {"error": "files belong to different handoff packages"})
                return

            try:
                content_length = int(self.headers.get("Content-Length", ""))
            except ValueError:
                self._reply(411, {"error": "valid Content-Length is required"})
                return
            if content_length <= 0 or content_length > args.max_file_bytes:
                self._reply(413, {"error": "file size is outside the allowed range"})
                return

            target = destination / filename
            if target.exists():
                self._reply(409, {"error": "destination file already exists"})
                return

            temporary = destination / f".{filename}.{secrets.token_hex(6)}.part"
            remaining = content_length
            try:
                with temporary.open("xb") as stream:
                    while remaining:
                        chunk = self.rfile.read(min(1024 * 1024, remaining))
                        if not chunk:
                            raise ConnectionError("upload ended before Content-Length")
                        stream.write(chunk)
                        remaining -= len(chunk)
                temporary.replace(target)
            except Exception as error:
                temporary.unlink(missing_ok=True)
                self._reply(400, {"error": str(error)})
                return

            state["base_name"] = base_name
            received = state["received"]
            assert isinstance(received, set)
            received.add(filename)

            if len(received) == len(EXPECTED_SUFFIXES):
                try:
                    verification = _validate_complete(destination, base_name)
                except Exception as error:
                    self._reply(422, {"error": str(error), "received": sorted(received)})
                    return
                self._reply(201, {"status": "HANDOFF_RECEIVED", **verification})
                print("\nWIRELESS_HANDOFF_RECEIVED", flush=True)
                print(json.dumps(verification, ensure_ascii=False, indent=2), flush=True)
                stop_event.set()
                Thread(target=self.server.shutdown, daemon=True).start()
                return

            self._reply(
                201,
                {
                    "status": "FILE_RECEIVED",
                    "file": filename,
                    "received_count": len(received),
                    "expected_count": len(EXPECTED_SUFFIXES),
                },
            )

        def log_message(self, message_format: str, *message_args: object) -> None:
            print(f"{self.client_address[0]} - {message_format % message_args}", flush=True)

    server = HTTPServer((args.bind, args.port), Handler)
    addresses = _local_ipv4_addresses()
    upload_urls = [f"http://{address}:{args.port}/upload" for address in addresses]
    if not upload_urls:
        upload_urls = [f"http://<MASTER_LAN_IP>:{args.port}/upload"]

    discovery_socket: socket.socket | None = None
    discovery_thread: Thread | None = None
    if not args.no_discovery:
        discovery_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        discovery_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        discovery_socket.bind(("0.0.0.0", args.discovery_port))
        discovery_thread = Thread(
            target=_serve_discovery,
            args=(
                discovery_socket,
                stop_event,
                args.task_id,
                token,
                upload_urls,
                args.port,
            ),
            daemon=True,
        )
        discovery_thread.start()

    print("BA Planner cross-PC handoff receiver", flush=True)
    print(f"destination: {destination}", flush=True)
    print(f"task_id: {args.task_id}", flush=True)
    print(f"port: {args.port}", flush=True)
    if args.show_token:
        print(f"token: {token}", flush=True)
    for upload_url in upload_urls:
        print(f"upload_url: {upload_url}", flush=True)
    if discovery_socket is not None:
        print(f"discovery: UDP/{args.discovery_port} enabled", flush=True)
        print("On the slave PC run Send-SlaveResult.ps1; no token entry is needed.", flush=True)
    print("Use only on a trusted private LAN. The receiver stops after one valid handoff.", flush=True)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Receiver stopped by user.", flush=True)
    finally:
        stop_event.set()
        if discovery_socket is not None:
            discovery_socket.close()
        if discovery_thread is not None:
            discovery_thread.join(timeout=1)
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
