from __future__ import annotations

import argparse
import json
from pathlib import Path


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def backend_main() -> str:
    return '''from datetime import datetime
from typing import Dict, List
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="Agent Console API", version="0.1.0")

class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=120)
    description: str = Field("", max_length=2000)
    kind: str = Field("general", max_length=50)

class Task(TaskCreate):
    id: str
    status: str
    created_at: str

TASKS: Dict[str, Task] = {}

@app.get("/")
def root():
    return {"name": "Agent Console API", "status": "running", "docs": "/docs"}

@app.get("/health")
def health():
    return {"ok": True, "time": datetime.now().isoformat(timespec="seconds")}

@app.post("/tasks", response_model=Task)
def create_task(payload: TaskCreate):
    task = Task(
        id=str(uuid4()),
        title=payload.title,
        description=payload.description,
        kind=payload.kind,
        status="created",
        created_at=datetime.now().isoformat(timespec="seconds"),
    )
    TASKS[task.id] = task
    return task

@app.get("/tasks", response_model=List[Task])
def list_tasks():
    return list(TASKS.values())

@app.get("/tasks/{task_id}", response_model=Task)
def get_task(task_id: str):
    task = TASKS.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="task not found")
    return task
'''


def frontend_html() -> str:
    return '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Agent Console</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<div class="shell">
  <aside>
    <h1>Agent Console</h1>
    <p>Fullstack Final Kit 生成的本地任务控制台。</p>
    <button onclick="checkHealth()">检查后端</button>
  </aside>
  <main>
    <section class="hero">
      <h2>本地 AI 自动化任务中心</h2>
      <p>后端 FastAPI，前端 HTML/CSS/JS。适合 OpenClaw 继续扩展成 PPT、Python、前端、后端任务中枢。</p>
      <div id="health" class="status">等待检测</div>
    </section>
    <section class="card">
      <h3>创建任务</h3>
      <input id="title" placeholder="任务标题">
      <textarea id="description" placeholder="任务描述"></textarea>
      <select id="kind"><option>ppt</option><option>python</option><option>frontend</option><option>backend</option><option>general</option></select>
      <button onclick="createTask()">提交任务</button>
    </section>
    <section class="card"><h3>任务列表</h3><div id="tasks"></div></section>
  </main>
</div>
<script src="app.js"></script>
</body>
</html>
'''


def frontend_css() -> str:
    return '''*{box-sizing:border-box}body{margin:0;font-family:system-ui,"Microsoft YaHei",sans-serif;background:#eef5ff;color:#172033}.shell{display:grid;grid-template-columns:300px 1fr;min-height:100vh}aside{padding:32px 24px;background:linear-gradient(180deg,#0f2d55,#09203f);color:white}aside h1{margin:0 0 10px;font-size:30px}aside p{color:#c7e7ff;line-height:1.6}button{border:0;border-radius:12px;padding:12px 16px;margin:8px 6px 8px 0;background:#1d77e5;color:white;font-weight:700;cursor:pointer}aside button{width:100%;background:#39bdf8;color:#05223c}main{padding:32px}.hero,.card{background:white;border:1px solid #d9e5f5;border-radius:20px;padding:24px;margin-bottom:20px;box-shadow:0 10px 30px rgba(15,45,85,.08)}.hero h2{margin:0 0 8px;font-size:30px;color:#0f2d55}.status{display:inline-block;padding:8px 12px;border-radius:999px;background:#e2f1ff;color:#0f2d55;font-weight:700}input,textarea,select{width:100%;border:1px solid #c8d8ee;border-radius:12px;padding:12px;margin:8px 0;font-size:15px}textarea{min-height:90px}.task{border:1px solid #dbeafe;border-radius:14px;padding:14px;margin:10px 0;background:#f8fbff}.task b{color:#0f2d55}@media(max-width:800px){.shell{grid-template-columns:1fr}}'''


def frontend_js() -> str:
    return '''const API="http://127.0.0.1:8000";
async function checkHealth(){const el=document.getElementById("health");try{const r=await fetch(`${API}/health`);const d=await r.json();el.textContent=`后端正常：${d.time}`}catch(e){el.textContent="后端未连接，请先启动 uvicorn"}}
async function createTask(){const title=document.getElementById("title").value.trim();const description=document.getElementById("description").value.trim();const kind=document.getElementById("kind").value;if(!title)return alert("请输入标题");const r=await fetch(`${API}/tasks`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({title,description,kind})});if(!r.ok)return alert("创建失败");document.getElementById("title").value="";document.getElementById("description").value="";await loadTasks()}
async function loadTasks(){const box=document.getElementById("tasks");try{const r=await fetch(`${API}/tasks`);const tasks=await r.json();box.innerHTML=tasks.length?tasks.map(t=>`<div class="task"><b>${t.title}</b><p>${t.description||"无描述"}</p><small>类型：${t.kind} ｜ 状态：${t.status} ｜ ${t.created_at}</small></div>`).join(""):"<p>暂无任务</p>"}catch(e){box.innerHTML="<p>无法连接后端</p>"}}
checkHealth();loadTasks();'''


def scaffold(name: str, out: Path) -> Path:
    root = out / name
    write(root / "README.md", "# Generated Fullstack Project\n\nRun backend: `uvicorn app.main:app --reload --host 127.0.0.1 --port 8000`\n")
    write(root / "backend" / "requirements.txt", "fastapi>=0.110.0\nuvicorn>=0.27.0\npydantic>=2.0.0\n")
    write(root / "backend" / "app" / "__init__.py", "")
    write(root / "backend" / "app" / "main.py", backend_main())
    write(root / "frontend" / "index.html", frontend_html())
    write(root / "frontend" / "style.css", frontend_css())
    write(root / "frontend" / "app.js", frontend_js())
    write(root / "manifest.json", json.dumps({"name": name, "api": "http://127.0.0.1:8000", "docs": "http://127.0.0.1:8000/docs"}, ensure_ascii=False, indent=2))
    return root


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", default="agent_console")
    parser.add_argument("--out", default="./output")
    args = parser.parse_args()
    root = scaffold(args.name, Path(args.out))
    print(f"Generated project: {root}")
    print(f"Backend: {root / 'backend'}")
    print(f"Frontend: {root / 'frontend' / 'index.html'}")


if __name__ == "__main__":
    main()
