from __future__ import annotations

import base64
import json
import time
import uuid
from pathlib import Path
from typing import Any, Dict

from flask import Flask, request, jsonify

app = Flask(__name__)

ROOT = Path(r"C:\OpenClawWork\Mobile_Bridge")
INBOX = ROOT / "inbox"
OUTBOX = ROOT / "outbox"
UPLOADS = ROOT / "uploads"
LOG = ROOT / "mobile_bridge.log"
HEARTBEAT = Path(r"C:\OpenClawWork\Lobster_Status\heartbeat.json")

for p in [ROOT, INBOX, OUTBOX, UPLOADS]:
    p.mkdir(parents=True, exist_ok=True)


def now() -> str:
    return time.strftime("%Y-%m-%d %H:%M:%S")


def safe_name(name: str) -> str:
    keep = []
    for ch in name:
        if ch.isalnum() or ch in "._-()[] 中文龙虾任务":
            keep.append(ch)
        else:
            keep.append("_")
    return "".join(keep)[:120] or "upload.bin"


def log(msg: str) -> None:
    line = f"[{now()}] {msg}"
    print(line)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def heartbeat(task: str, step: str, status: str, message: str = "") -> None:
    HEARTBEAT.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "status": status,
        "task": task,
        "step": step,
        "message": message,
        "updated_at": now(),
    }
    HEARTBEAT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def save_task(kind: str, payload: Dict[str, Any]) -> Path:
    task_id = str(uuid.uuid4())[:8]
    item = {
        "id": task_id,
        "kind": kind,
        "source": payload.get("source", "ios"),
        "type": payload.get("type", kind),
        "text": payload.get("text", ""),
        "url": payload.get("url", ""),
        "file_path": payload.get("file_path", ""),
        "created_at": now(),
        "status": "received",
        "raw": payload,
    }
    file = INBOX / f"{time.strftime('%Y%m%d_%H%M%S')}_{task_id}_{kind}.json"
    file.write_text(json.dumps(item, ensure_ascii=False, indent=2), encoding="utf-8")
    log(f"received {kind} {task_id}: {item.get('text','')[:80]} {item.get('url','')[:120]}")
    heartbeat("iOS 手机任务", f"收到 {kind}", "received", item.get("text") or item.get("url") or item.get("file_path") or "")
    return file


@app.get("/health")
def health():
    return jsonify({"ok": True, "service": "iOS Mobile Bridge Pro", "time": now()})


@app.post("/message")
def message():
    data = request.get_json(force=True)
    text = str(data.get("text", "")).strip()
    if not text:
        return jsonify({"ok": False, "error": "missing text"}), 400
    file = save_task("message", data)
    return jsonify({"ok": True, "message": "龙虾已收到 iPhone 文本指令", "inbox_file": str(file)})


@app.post("/share")
def share():
    data = request.get_json(force=True)
    text = str(data.get("text", "")).strip()
    url = str(data.get("url", "")).strip()
    if not text and not url:
        return jsonify({"ok": False, "error": "missing text or url"}), 400
    file = save_task("share", data)
    return jsonify({"ok": True, "message": "龙虾已收到分享内容", "inbox_file": str(file)})


@app.post("/upload_json")
def upload_json():
    data = request.get_json(force=True)
    filename = safe_name(str(data.get("filename", "upload.txt")))
    content = data.get("content", "")
    is_base64 = bool(data.get("base64", False))
    target = UPLOADS / f"{time.strftime('%Y%m%d_%H%M%S')}_{filename}"
    if is_base64:
        target.write_bytes(base64.b64decode(content))
    else:
        target.write_text(str(content), encoding="utf-8")
    data["file_path"] = str(target)
    file = save_task("upload", data)
    return jsonify({"ok": True, "message": "龙虾已收到 iPhone 文件", "saved_file": str(target), "inbox_file": str(file)})


@app.post("/upload")
def upload():
    if "file" not in request.files:
        return jsonify({"ok": False, "error": "missing file"}), 400
    f = request.files["file"]
    filename = safe_name(f.filename or "upload.bin")
    target = UPLOADS / f"{time.strftime('%Y%m%d_%H%M%S')}_{filename}"
    f.save(target)
    file = save_task("upload", {"source": "ios", "type": "file", "file_path": str(target), "text": request.form.get("text", "")})
    return jsonify({"ok": True, "message": "龙虾已收到 iPhone 文件", "saved_file": str(target), "inbox_file": str(file)})


@app.get("/latest")
def latest():
    files = sorted(INBOX.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not files:
        return jsonify({"ok": True, "latest": None})
    return jsonify({"ok": True, "latest": json.loads(files[0].read_text(encoding="utf-8"))})


@app.get("/list")
def list_tasks():
    files = sorted(INBOX.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)[:50]
    items = []
    for f in files:
        try:
            items.append(json.loads(f.read_text(encoding="utf-8")))
        except Exception as exc:
            items.append({"file": str(f), "error": str(exc)})
    return jsonify({"ok": True, "items": items})


if __name__ == "__main__":
    print("iOS Mobile Bridge Pro running at http://0.0.0.0:8797")
    app.run(host="0.0.0.0", port=8797)
