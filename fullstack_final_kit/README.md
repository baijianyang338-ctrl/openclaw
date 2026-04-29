# Fullstack Final Kit / 前后端最终体工程库

Fullstack Final Kit 是给 OpenClaw 安装到电脑里的前后端项目生成库。目标是让 Agent 不只是写散代码，而是能生成可运行、可扩展、带 API、带前端页面、带测试说明的完整工程骨架。

## 学习来源与设计吸收

参考开源社区常见全栈模板的工程思想：

- FastAPI 项目：清晰路由、Pydantic 数据模型、自动 API 文档。
- React/Vite 项目：快速启动、组件化页面、现代前端开发体验。
- Full-stack template 类仓库：前后端分离、统一启动文档、环境变量管理。
- AI Agent template 类仓库：任务输入、状态输出、日志和结果追踪。

本库重新实现一套轻量模板生成器，适合 OpenClaw 本地自动化使用。

## 能力目标

- 一条命令生成完整前后端项目。
- 后端：FastAPI，提供健康检查、任务创建、任务列表、任务详情 API。
- 前端：原生 HTML/CSS/JS 单页控制台，无需复杂依赖即可运行。
- 支持后续升级到 React/Vite、数据库、登录、文件上传、OpenClaw 工具调用。
- OpenClaw 安装后能直接跑通。

## 安装

```bash
python -m pip install -r fullstack_final_kit/requirements.txt
```

## 生成项目

```bash
python fullstack_final_kit/scaffold.py --name agent_console --out /mnt/c/OpenClawWork/Fullstack_Final/output
```

## 启动后端

```bash
cd /mnt/c/OpenClawWork/Fullstack_Final/output/agent_console/backend
python -m pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

## 打开前端

直接双击：

```text
C:\OpenClawWork\Fullstack_Final\output\agent_console\frontend\index.html
```

## 给 OpenClaw 的安装指令

```text
请安装并测试 fullstack_final_kit。
1. 进入 openclaw 仓库目录。
2. 执行 python -m pip install -r fullstack_final_kit/requirements.txt
3. 执行 python fullstack_final_kit/scaffold.py --name agent_console --out /mnt/c/OpenClawWork/Fullstack_Final/output
4. 进入生成的 backend 目录。
5. 执行 python -m pip install -r requirements.txt
6. 启动 uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
7. 打开 frontend/index.html，测试能否访问后端 API。
8. 把项目路径、后端地址、前端文件路径告诉我。
```

## 后续升级方向

- React/Vite 版本前端。
- SQLite 数据库。
- 文件上传与下载。
- Agent 任务日志中心。
- 本地 OpenClaw 工具调用 API。
- PPT/Excel/PDF 生成 API。
