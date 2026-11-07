# OpenClaw Vision for iOS

独立的原生 Swift 工程，用于 iPhone 屏幕广播、本机 Vision OCR，以及后续通过 Wi-Fi 向正点原子 ESP32-S3 发送识别结果。

## 当前实现

- `OpenClawVision`：SwiftUI 主应用，提供系统广播按钮、ESP32-S3 地址配置和最新 OCR 结果预览。
- `OpenClawBroadcast`：ReplayKit Broadcast Upload Extension，限频读取视频帧并用 `VNRecognizeTextRequest` 做中英文 OCR。
- App Group：在主应用与扩展间共享配置和识别结果。
- 采集遥测：记录实际接收帧率、累计帧数、最近画面时间、OCR 耗时和失败原因。
- HTTP JSON：主应用支持健康检查、带序号指令、执行确认、重复保护语义、3 秒超时和紧急停止，默认 `192.168.4.1:3333`。
- 所有设备 HTTP 请求都携带运行时输入的随机配对令牌；未授权请求被设备拒绝。令牌只保存在本机 App Group 设置中，不能提交到仓库。
- 单任务状态机：严格使用 `IDLE → SEARCHING → DETECTED → READING_RULES → READY → EXECUTING → VERIFYING → WAITING_RESULT → FINISHED`，非法跳转进入 `ERROR`。
- 动态评论：从每次 OCR 结果重新提取评论原文，目标行置信度至少 80%，同一画面没有冲突文本，且连续三帧完全一致后才进入 `READY`。
- 广播扩展在规则确认后执行一次只读 `GET /v1/health`，把局域网探测状态和延迟写入 App Group，供真机跨 App 联调查看；该请求不会触发设备动作。
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

`codemagic.yaml` 另提供手动启动的 `ios-native-adhoc` 工作流，用于在签名材料配置完成后生成 IPA。Codemagic 页面步骤、两份描述文件、设备登记和真机采集验收见 [签名与真机验证](../../docs/ios-signing-and-device-test.md)。

## 签名前必须修改

在 Xcode 的 Signing & Capabilities 中为两个 Target 选择同一个 Team，并把下列示例标识改为你在 Apple Developer 中注册的唯一标识：

- 主应用：`com.baijianyang.openclawvision`
- 广播扩展：`com.baijianyang.openclawvision.broadcast`
- App Group：`group.com.baijianyang.openclawvision`

两个 Target 都必须启用同一个 App Groups capability。广播扩展的 provisioning profile 必须对应扩展 Bundle ID，主应用 profile 必须对应主应用 Bundle ID。

## 隐私与平台限制

屏幕采集必须由用户通过系统界面明确启动；应用没有绕过系统确认或后台静默启动采集的代码。Vision OCR 在设备本地执行，工程不会保存原始画面。

Apple 在较新的 SDK 中已将部分 ReplayKit 广播 API 标记为 deprecated，并推荐新项目评估 ScreenCaptureKit。当前仍保留 Broadcast Upload Extension，是为了满足系统级广播扩展方案和现阶段设备兼容性；后续迁移时可保留 `OCRResult` 与 HTTP 控制层，只替换帧采集入口。

跨 App 持续采集必须在签名真机上验证。模拟器和无签名 Codemagic 构建只能证明工程可编译及扩展可正确嵌入，不能证明抖音前台运行时一定能持续提供画面。

## ESP32-S3 协议

完整协议见仓库 `docs/esp32-control-protocol-v1.md`。示例指令：

```json
{"id":1001,"action":"CLICK","x":250,"y":600,"createdAt":"2026-11-07T10:00:00Z"}
```

Mock 服务位于仓库 `mock_esp32/`，只模拟协议确认，不控制真实 HID：

```sh
python mock_esp32/mock_server.py --host 0.0.0.0 --port 3333
python -m unittest discover -s mock_esp32/tests -v
```

真实设备必须缓存近期指令序号并对重复请求返回 `DUPLICATE`，不得重复执行。`TYPE` 保留 UTF-8 原文，但中文输入仍需后续与 iOS 原生输入法进行真机标定。
