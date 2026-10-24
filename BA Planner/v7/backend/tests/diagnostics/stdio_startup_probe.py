"""Bounded read-only startup diagnosis; never starts a scan or sends input."""
import json
import os
import subprocess
import time
import tempfile
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[2]
PYTHON = BACKEND / ".venv/Scripts/python.exe"
DEST = BACKEND.parent / 'debug' / ('stdio-startup-' + time.strftime('%Y%m%d_%H%M%S')) / 'diagnosis.json'
REQUESTS = "\n".join(json.dumps({"protocol": 1, "id": tag, "type": "request", "method": method, "payload": {}})
                     for tag, method in [("assets", "scanner.recognition.status"), ("targets", "scanner.target.list")]) + "\n"
INSTRUMENT = '''
import faulthandler, functools, json, sys, threading, time
origin = time.perf_counter()
faulthandler.dump_traceback_later(8, repeat=False)
def emit(stage, start, cpu):
    print(json.dumps({"stage": stage, "wall_seconds": round(time.perf_counter()-start,6),
                      "cpu_seconds": round(time.process_time()-cpu,6),
                      "elapsed": round(time.perf_counter()-origin,6),
                      "threads": len(threading.enumerate())}), file=sys.stderr, flush=True)
def wrap(owner, name, stage):
    original = getattr(owner, name)
    @functools.wraps(original)
    def call(*args, **kwargs):
        wall, cpu = time.perf_counter(), time.process_time()
        try: return original(*args, **kwargs)
        finally: emit(stage, wall, cpu)
    setattr(owner, name, call)
cpu = time.process_time()
import core.backend_process as backend
emit("imports", origin, cpu)
import core.scanner_runtime as runtime
wrap(runtime.RecognitionAssetCatalog, "verify", "catalog.verify")
for name in ["StudentPanelRecovery", "StudentMatcherAdapter", "InventoryDetailRecognizer",
             "InventoryMatcherAdapter", "InventoryNavigation", "SynthProvider", "TacticalLobbyMatcherAdapter"]:
    wrap(runtime, name, name)
wrap(runtime.WindowsCaptureInputAdapter, "__call__", "windows.target.list")
wrap(runtime, "build_scanner_service", "build_scanner_service")
backend.build_scanner_service = runtime.build_scanner_service
import core.application_protocol_v1 as application
import core.stdio_server as stdio
wrap(application.ApplicationProtocolV1, "__init__", "application.init")
wrap(application.ApplicationProtocolV1, "close", "application.close")
wrap(stdio, "serve", "stdio.serve")
try:
    backend.main()
finally:
    faulthandler.cancel_dump_traceback_later()
    emit("total", origin, 0)
'''

def stop_owned_process_tree(child):
    """Windows venv launchers have a Python descendant; reap only our live tree."""
    if child.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill.exe", "/PID", str(child.pid), "/T", "/F"],
                       capture_output=True, timeout=5, check=False)
    if child.poll() is None:
        child.kill()


def run(label, args):
    started = time.perf_counter()
    user_state = tempfile.TemporaryDirectory(prefix='ba-stdio-diagnosis-user-')
    environment = {**os.environ, 'BA_PLANNER_USER_DIR': user_state.name,
                   'BA_PLANNER_DISABLE_GAME_DISCOVERY': '1'}
    child = subprocess.Popen([str(PYTHON), *args], cwd=BACKEND, stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             text=True, encoding="utf-8", env=environment)
    spawn_seconds = time.perf_counter() - started
    timed_out = False
    try:
        try:
            stdout, stderr = child.communicate(REQUESTS, timeout=10)
        except subprocess.TimeoutExpired:
            timed_out = True
            # Diagnostic observation only, not a relaxed passing test.
            try:
                stdout, stderr = child.communicate(timeout=20)
            except subprocess.TimeoutExpired:
                stop_owned_process_tree(child)
                stdout, stderr = child.communicate(timeout=5)
    finally:
        if child.poll() is None:
            stop_owned_process_tree(child)
            child.communicate(timeout=5)
        user_state.cleanup()
    messages = [json.loads(line) for line in stdout.splitlines() if line.strip()]
    result = {"label": label, "command": [str(PYTHON), *args], "pid": child.pid,
              "spawn_seconds": round(spawn_seconds,6), "wall_seconds": round(time.perf_counter()-started,6),
              "ten_second_timeout": timed_out, "exit_code": child.returncode,
              "response_ids": [item.get("id") for item in messages],
              "ready": messages[0].get("payload",{}).get("ready") if messages else None,
              "asset_count": messages[0].get("payload",{}).get("asset_count") if messages else None,
              "target_payload_is_list": isinstance(messages[1].get("payload",{}).get("targets"),list) if len(messages)>1 else False,
              "stderr": stderr[-18000:]}
    print(json.dumps({k:v for k,v in result.items() if k not in {"command","stderr"}}), flush=True)
    return result

if __name__ == "__main__":
    evidence = {"schema": "ba-planner.stdio-startup-diagnosis.v1", "runs": []}
    for label,args in [("exact_1",["-m","core.backend_process"]),
                       ("exact_2",["-m","core.backend_process"]),
                       ("instrumented",["-c",INSTRUMENT])]:
        evidence["runs"].append(run(label,args))
    DEST.parent.mkdir(parents=True, exist_ok=False)
    DEST.write_text(json.dumps(evidence, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print("evidence="+str(DEST), flush=True)
