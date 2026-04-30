# 给龙虾 / OpenClaw 的任务：部署 Hermes Agent

你现在的任务是把 Hermes Agent 部署到本机，并检查是否能正常运行。

## 已知官方仓库

默认使用：

```text
https://github.com/NousResearch/hermes-agent.git
```

如果用户给了新的官方 Hermes 仓库地址，以用户给出的地址为准。

## 执行步骤

1. 进入目录：

```bash
cd hermes-bootstrap
```

2. 检查 `.env`。

如果没有 `.env`，从 `.env.example` 复制一份。

3. 确认 `.env` 中：

```env
HERMES_REPO_URL=https://github.com/NousResearch/hermes-agent.git
HERMES_REF=main
HERMES_DIR=./runtime/hermes-agent
```

4. 在 WSL / Linux 下运行：

```bash
bash ./deploy_hermes.sh
```

5. 在 Windows PowerShell 下运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy_hermes.ps1
```

6. 安装完成后执行验证：

```bash
hermes --help
hermes doctor
```

7. 如果要从 OpenClaw / 龙虾迁移配置，先试运行：

```bash
hermes claw migrate --dry-run
```

确认没问题后再执行：

```bash
hermes claw migrate
```

## 成功标准

- Hermes Agent 源码成功下载到 `hermes-bootstrap/runtime/hermes-agent`。
- `hermes --help` 能输出帮助。
- `hermes doctor` 能完成检查或给出明确缺失项。
- 不把 API Key、Token、密码提交到仓库。

## 遇到问题时的处理

- 缺少 git：安装 Git。
- 缺少 Python：安装 Python 3.11 或以上。
- Windows 脚本不兼容：优先用 WSL 运行 `deploy_hermes.sh`。
- 依赖失败：查看 Hermes 仓库 README 中的最新安装说明。
