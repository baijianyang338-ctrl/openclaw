# iOS Mobile Kit / iPhone 龙虾遥控器能力包

iOS Mobile Kit 是给 OpenClaw 使用的 iPhone 连接能力包。它的目标不是突破 iOS 系统限制，而是把 iPhone 变成“龙虾遥控器”和“移动输入端”。

## 核心定位

iPhone 负责：

- Siri 语音下达任务。
- 快捷指令发送文字、剪贴板、网页链接、图片或文件。
- 分享网页/文本到电脑上的龙虾。
- 查看龙虾状态面板。

电脑上的 OpenClaw 负责：

- 接收 iPhone 任务。
- 判断任务类型。
- 调用本地工具：PPT、爬虫、前后端、WPS、PowerShell Bridge。
- 生成文件和报告。
- 更新运行状态面板。

## iOS 限制

iOS 不允许普通外部程序像 Android ADB 那样完全接管系统。不能稳定做到：

- 后台长期监听所有 App。
- 自动读取所有微信消息。
- 自动替你操作任意 App。
- 锁屏后持续执行复杂自动化。
- 无确认静默控制手机系统级功能。

可行路线是：

- 快捷指令 + HTTP API。
- 分享菜单 + URL Scheme。
- 手动确认关键动作。
- 电脑端执行重任务。

## 文件结构

```text
ios_mobile_kit/
├─ README.md
├─ mobile_bridge_pro.py
├─ shortcuts_recipes.md
└─ openclaw_ios_rules.md
```

## 启动方式

在 Windows 上运行：

```bat
cd /d C:\OpenClawWork\Mobile_Bridge
python mobile_bridge_pro.py
```

服务地址：

```text
http://0.0.0.0:8797
```

iPhone 同一 Wi-Fi 下访问：

```text
http://电脑局域网IP:8797/health
```

## OpenClaw 使用方式

让 OpenClaw 读取：

```text
C:\OpenClawWork\Mobile_Bridge\inbox
```

里面每个 JSON 都是一条 iPhone 任务。OpenClaw 根据 `type` 和 `text` 字段决定调用 PPT、爬虫、前后端、清理、WPS 或普通问答。

## 推荐快捷指令

1. 呼叫龙虾：听写文本，然后 POST 到 `/message`。
2. 分享给龙虾：从分享菜单接收网页 URL 或文本，然后 POST 到 `/share`。
3. 发送剪贴板给龙虾：读取剪贴板，然后 POST 到 `/message`。
4. 上传文件给龙虾：选择文件，然后 POST 到 `/upload`。
5. 查看龙虾状态：打开 `http://电脑IP:8799`。
