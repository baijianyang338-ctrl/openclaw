$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

if (-not (Test-Path ".env")) {
  Copy-Item ".env.example" ".env"
  Write-Host "已生成 .env，请先编辑 HERMES_REPO_URL 后重新运行。"
  exit 1
}

Get-Content ".env" | ForEach-Object {
  if ($_ -match "^\s*#") { return }
  if ($_ -match "^\s*$") { return }
  $parts = $_ -split "=", 2
  if ($parts.Count -eq 2) {
    [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
  }
}

$Repo = $env:HERMES_REPO_URL
if ([string]::IsNullOrWhiteSpace($Repo)) { $Repo = "https://github.com/NousResearch/hermes-agent.git" }

$Ref = $env:HERMES_REF
if ([string]::IsNullOrWhiteSpace($Ref)) { $Ref = "main" }

$Dir = $env:HERMES_DIR
if ([string]::IsNullOrWhiteSpace($Dir)) { $Dir = ".\runtime\hermes-agent" }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "缺少 git，请先安装 Git for Windows。"
}

New-Item -ItemType Directory -Force -Path (Split-Path $Dir -Parent) | Out-Null

if (-not (Test-Path (Join-Path $Dir ".git"))) {
  Write-Host "正在下载 Hermes Agent: $Repo"
  git clone $Repo $Dir
} else {
  Write-Host "正在更新 Hermes Agent: $Dir"
  git -C $Dir fetch --all --prune
}

git -C $Dir checkout $Ref
Set-Location $Dir

if (Test-Path ".\setup-hermes.sh") {
  Write-Host "检测到 setup-hermes.sh。Windows 推荐在 WSL 中运行：bash ./setup-hermes.sh"
} else {
  Write-Host "尝试 Python 安装。"
  if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "缺少 Python。"
  }
  python -m venv venv
  .\venv\Scripts\python.exe -m pip install --upgrade pip
  .\venv\Scripts\python.exe -m pip install -e ".[all]"
}

Write-Host ""
Write-Host "Hermes Agent 部署脚本执行完毕。"
Write-Host "下一步："
Write-Host "  hermes setup"
Write-Host "  hermes doctor"
Write-Host "  hermes"
Write-Host ""
Write-Host "如果从 OpenClaw / 龙虾迁移："
Write-Host "  hermes claw migrate --dry-run"
Write-Host "  hermes claw migrate"
