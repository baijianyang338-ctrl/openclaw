# Hermes AI 自部署脚手架

这个目录用于让 OpenClaw / 龙虾自动部署 Hermes AI 框架。

我没有写死某个 Hermes 仓库地址，因为 Hermes 相关项目名称很多，必须以你确认的官方仓库为准，避免部署错项目。

## 目标

让龙虾自动完成：

1. 读取 Hermes 官方仓库地址。
2. 自动下载或更新源码。
3. 判断项目类型：Docker Compose、Python、Node.js。
4. 自动安装依赖。
5. 自动启动服务。
6. 输出访问地址和日志检查命令。

## Windows PowerShell

```powershell
cd hermes-bootstrap
Copy-Item .env.example .env
notepad .env
powershell -ExecutionPolicy Bypass -File .\deploy_hermes.ps1
```

## Linux / WSL

```bash
cd hermes-bootstrap
cp .env.example .env
nano .env
bash ./deploy_hermes.sh
```

## 必填配置

编辑 `.env`：

```env
HERMES_REPO_URL=https://example.com/official/hermes.git
HERMES_REF=main
HERMES_PORT=7860
```

把 `HERMES_REPO_URL` 改成你确认的 Hermes 官方仓库地址。

## 给龙虾的执行方式

把 `openclaw_task.md` 的内容交给龙虾执行。它会按步骤检查环境、部署、启动和验证。

## 注意

`.env` 里不要提交 API Key、Token、密码等敏感信息。
