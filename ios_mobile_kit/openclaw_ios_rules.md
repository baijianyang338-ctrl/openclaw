# OpenClaw iOS 任务处理规则

## iOS 入口

iPhone 通过 iOS Mobile Bridge Pro 发送任务：

```text
C:\OpenClawWork\Mobile_Bridge\inbox
```

OpenClaw 每次收到“检查 iPhone 指令”时，读取最新 JSON 文件。

## 任务字段

常见字段：

- `kind`: message / share / upload
- `type`: voice_task / clipboard / shared_url / file / fixed_task
- `text`: 用户文本
- `url`: 分享链接
- `file_path`: 上传文件保存路径
- `created_at`: 创建时间

## 处理流程

1. 读取最新 inbox JSON。
2. 提取 `text`、`url`、`file_path`。
3. 判断任务类型：
   - PPT
   - 爬虫
   - 前后端
   - WPS
   - 文件清理
   - 系统维护
   - 普通问答
4. 如果任务较长，拆成小步骤。
5. 执行时更新：

```text
C:\OpenClawWork\Lobster_Status\heartbeat.json
```

6. 输出文件统一保存到：

```text
C:\OpenClawWork
```

7. 完成后只回复状态、输出路径、报告路径。

## iOS 限制

不要承诺完全接管 iPhone。iOS 主要通过快捷指令主动发送任务给电脑。

## 推荐命令

用户说：

```text
检查 iPhone 指令
```

你执行：

1. 读取 `C:\OpenClawWork\Mobile_Bridge\inbox` 最新 JSON。
2. 判断任务。
3. 给出执行计划或执行简单任务。

用户说：

```text
龙虾，查看手机发来的最新链接
```

你读取最新 `kind=share` 的 JSON，分析 `url`。
