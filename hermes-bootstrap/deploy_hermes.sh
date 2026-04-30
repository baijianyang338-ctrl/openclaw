#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [ -f .env ]; then
  set -a
  source .env
  set +a
elif [ -f .env.example ]; then
  cp .env.example .env
  echo "已生成 .env，请先编辑 HERMES_REPO_URL 后重新运行。"
  exit 1
else
  echo "缺少 .env.example"
  exit 1
fi

HERMES_REPO_URL="${HERMES_REPO_URL:-https://github.com/NousResearch/hermes-agent.git}"
HERMES_REF="${HERMES_REF:-main}"
HERMES_DIR="${HERMES_DIR:-./runtime/hermes-agent}"

if ! command -v git >/dev/null 2>&1; then
  echo "缺少 git，请先安装 git。"
  exit 1
fi

mkdir -p "$(dirname "$HERMES_DIR")"

if [ ! -d "$HERMES_DIR/.git" ]; then
  echo "正在下载 Hermes Agent：$HERMES_REPO_URL"
  git clone "$HERMES_REPO_URL" "$HERMES_DIR"
else
  echo "正在更新 Hermes Agent：$HERMES_DIR"
  git -C "$HERMES_DIR" fetch --all --prune
fi

git -C "$HERMES_DIR" checkout "$HERMES_REF"

cd "$HERMES_DIR"

if [ -f ./setup-hermes.sh ]; then
  echo "检测到 setup-hermes.sh，开始安装。"
  bash ./setup-hermes.sh
else
  echo "未找到 setup-hermes.sh，尝试 Python/uv 安装。"
  if command -v uv >/dev/null 2>&1; then
    uv venv venv --python 3.11 || uv venv venv
    source venv/bin/activate
    uv pip install -e '.[all]'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m venv venv
    source venv/bin/activate
    python -m pip install --upgrade pip
    python -m pip install -e '.[all]'
  else
    echo "缺少 Python 3 或 uv。"
    exit 1
  fi
fi

cat <<'MSG'

Hermes Agent 部署脚本执行完毕。

下一步建议让龙虾执行：
  hermes setup
  hermes doctor
  hermes

如果你从 OpenClaw / 龙虾迁移：
  hermes claw migrate --dry-run
  hermes claw migrate

MSG
