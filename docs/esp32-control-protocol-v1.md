# OpenClaw ESP32-S3 控制协议 v1

本协议用于 iPhone 与 ESP32-S3 在同一局域网内通信。传输层为 HTTP，负载为 UTF-8 JSON。Mock 服务实现于 `mock_esp32/`；真实固件必须保持相同语义。

设备首次启动时在 NVS 中生成随机 128 位控制令牌，并通过本地串口日志显示。iPhone App 中的“设备配对令牌”仅在本机保存，不写入仓库。所有端点都要求 `Authorization: Bearer <令牌>`；缺失或错误返回 HTTP 401，且不得执行动作。令牌不会在 HTTP 响应中回传。当前 HTTP 依赖受保护的本地 Wi-Fi，尚未实现 TLS，因此不要在开放或不可信网络中使用。

真实 ESP-IDF 固件位于 `esp32_s3_firmware/`。当前实现使用 BLE HID 控制 iPhone，并通过本协议接收局域网指令。

## 端点

- `GET /v1/health`：连接测试与协议版本协商。
- `POST /v1/command`：提交一条有序控制指令。

默认端口为 `3333`。真机应使用固定 DHCP 租约、mDNS 或在 App 中手动配置 IP。

`GET /v1/health` 返回 `bleConnected`、`stopped`、`temperatureC`（传感器无效时为 `null`）及 `overheated`。温度达到配置阈值或传感器读数不可用时，固件释放 HID 按键并拒绝普通动作；`STOP` 与 `PING` 仍可接收。这里是 ESP32-S3 内部芯片温度，不等于环境温度或外壳温度。

## 指令

```json
{
  "version": 1,
  "id": 1001,
  "action": "CLICK",
  "x": 250,
  "y": 600,
  "createdAt": "2026-11-07T10:00:00Z"
}
```

动作：`MOVE`、`CLICK`、`PRESS`、`RELEASE`、`SCROLL`、`TYPE`、`STOP`、`PING`。

- `id` 是单调递增的无符号整数。设备必须缓存近期序号；相同序号不得重复执行。
- `version` 必须为整数 `1`；未提供或不兼容的版本会被拒绝。
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

当前 HTTP 请求同步返回最终 `EXECUTED`（BLE HID 报告已发送），对应上层示例中的 `COMPLETED`。它不证明画面已产生预期变化；iPhone 必须重新识别画面。`RECEIVED`、`EXECUTING` 及最终 `COMPLETED` 的多阶段状态回报仍待后续协议升级实现，不能把现有 `EXECUTED` 当成完整闭环成功。

只有收到匹配序号的 `EXECUTED` 才能进入画面验证。网络超时不得盲目重发新序号；应先查询或使用相同序号重试，让设备返回 `DUPLICATE`，避免双击。

## 安全与平台限制

- 不发送或处理验证码、身份验证或资格限制绕过指令。
- 识别置信度不足或连续画面不一致时不得执行。
- 自动化必须提供用户可见的急停入口。
- Mock 的 `EXECUTED` 只表示模拟确认，不证明真实蓝牙 HID 已完成动作。
