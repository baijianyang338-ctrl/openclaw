from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List


DEFAULT_WINDOWS_ROOT = Path("/mnt/c/OpenClawWork/LobsterAuto")
DEFAULT_LINUX_ROOT = Path.home() / "OpenClawWork" / "LobsterAuto"


SAFE_COMMANDS = {
    "python",
    "python3",
    "pip",
    "pip3",
    "node",
    "npm",
    "git",
    "echo",
    "ls",
    "dir",
}


@dataclass
class RunContext:
    root: Path
    dry_run: bool = True
    yes: bool = False

    @classmethod
    def create(cls, dry_run: bool = True, yes: bool = False) -> "RunContext":
        root = DEFAULT_WINDOWS_ROOT if DEFAULT_WINDOWS_ROOT.parent.exists() else DEFAULT_LINUX_ROOT
        root.mkdir(parents=True, exist_ok=True)
        for name in ["output", "logs", "reports", "tasks", "inbox", "sandbox"]:
            (root / name).mkdir(parents=True, exist_ok=True)
        return cls(root=root, dry_run=dry_run, yes=yes)

    def resolve(self, raw_path: str) -> Path:
        p = Path(raw_path)
        if p.is_absolute():
            resolved = p.resolve()
        else:
            resolved = (self.root / raw_path).resolve()
        root_resolved = self.root.resolve()
        if not str(resolved).startswith(str(root_resolved)):
            raise PermissionError(f"Path outside LobsterAuto root is not allowed: {resolved}")
        return resolved

    def log(self, message: str) -> None:
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        line = f"[{timestamp}] {message}"
        print(line)
        with (self.root / "logs" / "lobster.log").open("a", encoding="utf-8") as f:
            f.write(line + "\n")


def load_task_file(path: str | Path) -> Dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict) or "steps" not in data or not isinstance(data["steps"], list):
        raise ValueError("Task file must be a JSON object with a 'steps' list.")
    return data


def init_workspace() -> Path:
    ctx = RunContext.create(dry_run=True)
    readme = ctx.root / "README.txt"
    if not readme.exists():
        readme.write_text(
            "Lobster Auto workspace. Put tasks in tasks/, inputs in inbox/, outputs in output/.\n",
            encoding="utf-8",
        )
    return ctx.root


def doctor() -> Dict[str, Any]:
    root = init_workspace()
    result = {
        "python": sys.version.split()[0],
        "platform": sys.platform,
        "workspace": str(root),
        "workspace_exists": root.exists(),
        "git_available": shutil.which("git") is not None,
        "node_available": shutil.which("node") is not None,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return result


def plan(task: Dict[str, Any]) -> str:
    lines: List[str] = []
    lines.append(f"Task: {task.get('name', 'unnamed')}")
    lines.append(f"Steps: {len(task.get('steps', []))}")
    lines.append("")
    for i, step in enumerate(task.get("steps", []), start=1):
        lines.append(f"{i}. {step.get('action')} -> {step}")
    return "\n".join(lines)


def run_task(task: Dict[str, Any], dry_run: bool = True, yes: bool = False) -> None:
    ctx = RunContext.create(dry_run=dry_run, yes=yes)
    ctx.log(f"Starting task: {task.get('name', 'unnamed')} dry_run={dry_run} yes={yes}")
    for i, step in enumerate(task.get("steps", []), start=1):
        action = step.get("action")
        ctx.log(f"Step {i}: {action}")
        if action == "create_folder":
            do_create_folder(ctx, step)
        elif action == "write_text":
            do_write_text(ctx, step, append=False)
        elif action == "append_text":
            do_write_text(ctx, step, append=True)
        elif action == "copy_file":
            do_copy_file(ctx, step)
        elif action == "list_dir":
            do_list_dir(ctx, step)
        elif action == "run_command":
            do_run_command(ctx, step)
        elif action == "web_fetch":
            do_web_fetch(ctx, step)
        else:
            raise ValueError(f"Unsupported action: {action}")
    ctx.log("Task finished.")


def do_create_folder(ctx: RunContext, step: Dict[str, Any]) -> None:
    path = ctx.resolve(require(step, "path"))
    ctx.log(f"create_folder {path}")
    if not ctx.dry_run:
        path.mkdir(parents=True, exist_ok=True)


def do_write_text(ctx: RunContext, step: Dict[str, Any], append: bool) -> None:
    path = ctx.resolve(require(step, "path"))
    text = str(step.get("text", ""))
    ctx.log(("append_text" if append else "write_text") + f" {path}")
    if not ctx.dry_run:
        path.parent.mkdir(parents=True, exist_ok=True)
        mode = "a" if append else "w"
        with path.open(mode, encoding="utf-8") as f:
            f.write(text)
            if not text.endswith("\n"):
                f.write("\n")


def do_copy_file(ctx: RunContext, step: Dict[str, Any]) -> None:
    src = ctx.resolve(require(step, "src"))
    dst = ctx.resolve(require(step, "dst"))
    ctx.log(f"copy_file {src} -> {dst}")
    if not ctx.dry_run:
        if not src.exists():
            raise FileNotFoundError(src)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def do_list_dir(ctx: RunContext, step: Dict[str, Any]) -> None:
    path = ctx.resolve(step.get("path", "."))
    ctx.log(f"list_dir {path}")
    if path.exists():
        for item in sorted(path.iterdir()):
            print(item.name)


def do_run_command(ctx: RunContext, step: Dict[str, Any]) -> None:
    command = step.get("command")
    if not isinstance(command, list) or not command:
        raise ValueError("run_command.command must be a non-empty list")
    exe = Path(str(command[0])).name
    if exe not in SAFE_COMMANDS:
        raise PermissionError(f"Command not in safe allowlist: {exe}")
    ctx.log(f"run_command {' '.join(map(str, command))}")
    if not ctx.dry_run:
        subprocess.run(command, cwd=ctx.root, check=True)


def do_web_fetch(ctx: RunContext, step: Dict[str, Any]) -> None:
    url = require(step, "url")
    allowed = step.get("allowed_domains", [])
    if allowed and not any(domain in url for domain in allowed):
        raise PermissionError("URL domain is not in allowed_domains")
    output = ctx.resolve(require(step, "output"))
    ctx.log(f"web_fetch {url} -> {output}")
    if not ctx.dry_run:
        output.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(url, timeout=20) as resp:
            content = resp.read().decode("utf-8", errors="replace")
        output.write_text(content, encoding="utf-8")


def require(step: Dict[str, Any], key_name: str) -> str:
    value = step.get(key_name)
    if value is None or value == "":
        raise ValueError(f"Missing required field: {key_name}")
    return str(value)
