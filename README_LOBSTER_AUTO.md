# Lobster Auto / 龙虾自动运行库

Lobster Auto 是一个给 OpenClaw 使用的安全本地自动化代码库。它不是“无限权限脚本”，而是一个可审计、可 dry-run、带安全边界的任务运行器。

## 设计目标

- 让 OpenClaw 可以把重复工作沉淀为 JSON 任务。
- 支持一键体检、任务预览、任务执行、循环运行。
- 默认不删除文件、不改系统、不执行危险命令。
- 所有输出、日志、报告集中到 `C:\OpenClawWork\LobsterAuto` 或 Linux 下的 `~/OpenClawWork/LobsterAuto`。
- 适合后续接 WPS、PPT、Python、前端、后端、文件整理等自动化流程。

## 核心思路

参考成熟 Agent 项目的工程习惯：

1. 配置优先，不把路径和权限写死。
2. dry-run 优先，先预览再执行。
3. 工具插件化，不把所有能力塞进一个脚本。
4. 日志和报告必须完整，方便复盘。
5. 对文件、命令、网络做 allowlist，避免 Agent 失控。

## 安装

在项目根目录执行：

```bash
python -m pip install -e .
```

安装后可以运行：

```bash
lobster doctor
lobster init
lobster plan examples/tasks.json
lobster run examples/tasks.json --dry-run
lobster run examples/tasks.json --yes
```

## 给 OpenClaw 的安装指令

把下面这段发给 OpenClaw：

```text
请安装并测试 Lobster Auto 自动运行库。

步骤：
1. 进入本仓库目录。
2. 执行 python -m pip install -e .
3. 执行 lobster doctor
4. 执行 lobster init
5. 执行 lobster plan examples/tasks.json
6. 先执行 lobster run examples/tasks.json --dry-run
7. 确认无误后执行 lobster run examples/tasks.json --yes
8. 把日志和输出路径告诉我。

安全规则：
不要删除系统文件，不要卸载软件，不要执行未授权 shell 命令，不要处理密码、验证码、支付和隐私信息。
```

## 任务文件格式

任务文件是 JSON：

```json
{
  "name": "demo",
  "steps": [
    {"action": "create_folder", "path": "output/demo"},
    {"action": "write_text", "path": "output/demo/hello.txt", "text": "hello lobster"},
    {"action": "list_dir", "path": "output"}
  ]
}
```

## 支持动作

| action | 说明 | 是否默认安全 |
|---|---|---|
| create_folder | 创建文件夹 | 是 |
| write_text | 写文本文件 | 是 |
| append_text | 追加文本 | 是 |
| copy_file | 复制文件 | 是 |
| list_dir | 列目录 | 是 |
| run_command | 执行 allowlist 内命令 | 需要配置 |
| web_fetch | 抓取 allowlist 域名文本 | 需要配置 |

## 典型用途

- 让 OpenClaw 生成 PPT/Word/Excel/PDF 后统一放入输出目录。
- 让 OpenClaw 生成前后端项目骨架。
- 让 OpenClaw 做文件扫描、报告生成、任务复盘。
- 让 OpenClaw 定期做系统自检。

## 安全边界

Lobster Auto 默认拒绝：

- 删除文件或目录。
- 修改系统目录。
- 执行未加入 allowlist 的命令。
- 访问未加入 allowlist 的域名。
- 读取密钥、密码、Cookie、Token。
- 自动支付、转账、登录、破解验证码。

需要高风险能力时，必须由用户明确手动确认，并单独开发受控插件。
