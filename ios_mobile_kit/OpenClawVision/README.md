# OpenClaw Vision for iOS

独立的原生 Swift 工程，用于 iPhone 屏幕广播、本机 Vision OCR，以及后续通过 Wi-Fi 向正点原子 ESP32-S3 发送识别结果。

## 当前实现

- `OpenClawVision`：SwiftUI 主应用，提供系统广播按钮、ESP32-S3 地址配置和最新 OCR 结果预览。
- `OpenClawBroadcast`：ReplayKit Broadcast Upload Extension，限频读取视频帧并用 `VNRecognizeTextRequest` 做中英文 OCR。
- App Group：在主应用与扩展间共享配置和识别结果。
- 采集遥测：记录实际接收帧率、累计帧数、最近画面时间、OCR 耗时和失败原因。
- UDP：扩展将 `OCRResult` JSON 数据报发送到用户配置的 IP/端口，默认 `192.168.4.1:3333`。
- 无第三方依赖，不包含任何账号、密钥、证书或描述文件。

工程的最低部署版本是 iOS 18.0，因此可在运行 iOS 26.6.2 的 iPhone 16 Pro 上使用。实际 SDK 由 Codemagic 的 `xcode: latest` 提供。

## 无签名构建

仓库根目录的 `codemagic.yaml` 定义了 `ios-native-unsigned` 工作流：

```sh
xcodebuild \
  -project ios_mobile_kit/OpenClawVision/OpenClawVision.xcodeproj \
  -scheme OpenClawVision \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  clean build
```

此流程会同时编译主应用和广播扩展，并验证 `.appex` 已嵌入 `.app`。无签名 `.app` 只能用于编译验证，不能直接安装到真机。

## 签名前必须修改

在 Xcode 的 Signing & Capabilities 中为两个 Target 选择同一个 Team，并把下列示例标识改为你在 Apple Developer 中注册的唯一标识：

- 主应用：`com.baijianyang.openclawvision`
- 广播扩展：`com.baijianyang.openclawvision.broadcast`
- App Group：`group.com.baijianyang.openclawvision`

两个 Target 都必须启用同一个 App Groups capability。广播扩展的 provisioning profile 必须对应扩展 Bundle ID，主应用 profile 必须对应主应用 Bundle ID。

## 隐私与平台限制

屏幕采集必须由用户通过系统界面明确启动；应用没有绕过系统确认或后台静默启动采集的代码。Vision OCR 在设备本地执行，工程不会保存原始画面。

Apple 在较新的 SDK 中已将部分 ReplayKit 广播 API 标记为 deprecated，并推荐新项目评估 ScreenCaptureKit。当前仍保留 Broadcast Upload Extension，是为了满足系统级广播扩展方案和现阶段设备兼容性；后续迁移时可保留 `OCRResult` 与 UDP 层，只替换帧采集入口。

跨 App 持续采集必须在签名真机上验证。模拟器和无签名 Codemagic 构建只能证明工程可编译及扩展可正确嵌入，不能证明抖音前台运行时一定能持续提供画面。

## ESP32-S3 协议草案

每个 UDP 数据报是 UTF-8 JSON：

```json
{"lines":["示例文字","OPENCLAW"],"capturedAt":783648000}
```

`capturedAt` 使用 `Codable` 默认的 Apple reference date 秒数。固件端应限制报文长度、校验 JSON，并允许丢包；UDP 不保证到达或顺序。如后续需要确认与重传，可将 `sendToESP32` 替换为 TCP/WebSocket 层。
