# OpenClaw ESP32-S3 控制协议 v1

本协议用于 iPhone 与 ESP32-S3 在同一局域网内通信。传输层为 HTTP，负载为 UTF-8 JSON。Mock 服务实现于 `mock_esp32/`；真实固件必须保持相同语义。

真实 ESP-IDF 固件位于 `esp32_s3_firmware/`。当前实现使用 BLE HID 控制 iPhone，并通过本协议接收局域网指令。

## 端点

- `GET /v1/health`：连接测试与协议版本协商。
- `POST /v1/command`：提交一条有序控制指令。

默认端口为 `3333`。真机应使用固定 DHCP 租约、mDNS 或在 App 中手动配置 IP。

## 指令

```json
{
  "id": 1001,
  "action": "CLICK",
  "x": 250,
  "y": 600,
  "createdAt": "2026-11-07T10:00:00Z"
}
```

动作：`MOVE`、`CLICK`、`PRESS`、`RELEASE`、`SCROLL`、`TYPE`、`STOP`、`PING`。

- `id` 是单调递增的无符号整数。设备必须缓存近期序号；相同序号不得重复执行。
- `x/y` 是屏幕逻辑坐标，必须在后续真机标定后映射为 HID 鼠标位移。
- `deltaX/deltaY` 用于相对移动或滚动。
- `durationMilliseconds` 用于按住时长。
- `text` 必须原样保留 UTF-8，但 `TYPE` 并不保证真实固件可以直接输入任意中文；中文输入策略需要与 iOS 原生输入法联合标定。
- `STOP` 为最高优先级，设备收到后立即释放所有按键/鼠标并进入停止锁存状态。

### 当前真机固件边界

- `MOVE` 只接受相对位移 `deltaX/deltaY`。在完成 iPhone 指针加速度和屏幕坐标标定前，带 `x/y` 的绝对移动会被拒绝。
- `CLICK` 点击当前指针位置；带 `x/y` 的点击会被拒绝，避免未标定时误触。
- `TYPE` 当前只执行非空 ASCII。包含中文或其他非 ASCII UTF-8 的文本在发送任何按键前会被拒绝。
- `STOP` 锁存后需重启 ESP32-S3 才能恢复普通动作；诊断用 `PING` 仍可执行。
- BLE HID 未与 iPhone 连接时，动作会返回 `REJECTED`，不会伪报执行成功。

## 确认

```json
{
  "id": 1001,
  "status": "EXECUTED",
  "executedAt": "2026-11-07T10:00:00Z",
  "message": "completed"
}
```

状态：`ACCEPTED`、`EXECUTED`、`DUPLICATE`、`REJECTED`、`FAILED`。

只有收到匹配序号的 `EXECUTED` 才能进入画面验证。网络超时不得盲目重发新序号；应先查询或使用相同序号重试，让设备返回 `DUPLICATE`，避免双击。

## 安全与平台限制

- 不发送或处理验证码、身份验证或资格限制绕过指令。
- 识别置信度不足或连续画面不一致时不得执行。
- 自动化必须提供用户可见的急停入口。
- Mock 的 `EXECUTED` 只表示模拟确认，不证明真实蓝牙 HID 已完成动作。
