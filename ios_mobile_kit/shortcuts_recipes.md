# iPhone 快捷指令配方

## 配方 1：呼叫龙虾

用途：用 Siri 听写一句话，发送到电脑龙虾。

快捷指令动作：

1. 听写文本
2. 获取 URL 内容

URL：

```text
http://电脑局域网IP:8797/message
```

方法：POST
请求正文：JSON

JSON：

```json
{
  "source": "ios_shortcuts",
  "type": "voice_task",
  "text": "听写文本"
}
```

保存快捷指令名：

```text
呼叫龙虾
```

之后可以说：

```text
嘿 Siri，呼叫龙虾
```

## 配方 2：发送剪贴板给龙虾

动作：

1. 获取剪贴板
2. 获取 URL 内容

URL：

```text
http://电脑局域网IP:8797/message
```

JSON：

```json
{
  "source": "ios_clipboard",
  "type": "clipboard",
  "text": "剪贴板"
}
```

## 配方 3：分享网页给龙虾

快捷指令设置：在分享表单中显示。

动作：

1. 接收“URL 或文本”作为快捷指令输入
2. 获取 URL 内容

URL：

```text
http://电脑局域网IP:8797/share
```

JSON：

```json
{
  "source": "ios_share_sheet",
  "type": "shared_url",
  "url": "快捷指令输入",
  "text": "请龙虾分析这个链接"
}
```

## 配方 4：查看龙虾状态

动作：打开 URL

URL：

```text
http://电脑局域网IP:8799
```

## 配方 5：发送固定任务

URL：

```text
http://电脑局域网IP:8797/message
```

JSON：

```json
{
  "source": "ios_shortcuts",
  "type": "fixed_task",
  "text": "龙虾，检查今天的任务收件箱，并把最新任务分类。"
}
```
