# iPhone 真机签名与屏幕广播验证

## 当前状态

`ios-native-unsigned` 仅验证 Swift 工程和广播扩展可以在 Codemagic 的 macOS/Xcode 环境编译；其 `.app` 没有签名，不能安装到 iPhone。`ios-native-adhoc` 是手动启动的签名工作流，只有 Apple 签名材料准备好后才能生成可安装的 IPA。目前尚未产出签名 IPA，也尚未验证 iOS 26.6.2 上跨 App 画面采集。

2026-11-07 的 [Codemagic 构建 6aef32ab24e1ec2375572f29](https://codemagic.io/app/6aec822974fc39deaceedfc9/build/6aef32ab24e1ec2375572f29) 显示：Mac mini M2、`main`、提交 `5b4f3cb`、工作流 `OpenClaw Vision - unsigned validation`，状态 `finished`，页面出现绿色构建成功提示。这是该提交的无签名云端编译记录。签名工作流是在后续提交中准备的，尚未运行。

## Codemagic 页面操作

1. 打开 Codemagic 的 `openclaw` 项目，点 **Start new build**，分支选 `main`、工作流先选 **OpenClaw Vision - unsigned validation**。确认所有步骤为绿色，尤其是 `Build iOS app and broadcast extension without signing` 和 `Verify embedded broadcast extension`。
2. 在 Apple Developer Program 中登记这部 iPhone 的 UDID。创建主应用 `com.baijianyang.openclawvision` 和广播扩展 `com.baijianyang.openclawvision.broadcast` 两个 App ID，为两者启用相同的 App Group `group.com.baijianyang.openclawvision`。若实际标识已被占用，先同步修改 Xcode 项目、两个 entitlements 和 `codemagic.yaml` 的签名标识。
3. 为主应用和广播扩展分别准备包含该 iPhone 的 Ad Hoc provisioning profile，并准备匹配的 Apple Distribution 证书。只在 Codemagic 的 **Team settings → codemagic.yaml settings → Code signing identities** 上传；私钥、证书密码、`.p12`、`.mobileprovision` 和 API key 不进入 Git。
4. 再点 **Start new build**，分支选 `main`、工作流选 **OpenClaw Vision - signed iPhone test**。工作流先执行 `xcode-project use-profiles`，再执行 `xcode-project build-ipa`；成功后在构建页 **Artifacts** 下载 `build/ios/ipa/*.ipa`。若提示 `No matching profiles`，检查两个 Bundle ID、Ad Hoc 类型、App Group 和设备 UDID；不要关闭签名检查。

上述签名流程依据 [Codemagic iOS 签名文档](https://docs.codemagic.io/yaml-code-signing/signing-ios/) 和 [原生 iOS 工程指南](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/)。非 TestFlight 的真机安装要求设备已登记且位于描述文件中，见 [Codemagic 设备登记说明](https://docs.codemagic.io/yaml-testing/ios-provisioning/)。

## 在 iPhone 上安装

签名 IPA 必须通过支持 Ad Hoc 安装的方式交付给已登记的设备，例如受信任的 HTTPS OTA 分发服务提供的安装清单，或在 Mac 上使用 Apple Configurator。单纯在 iPhone Safari 中下载原始 `.ipa` 文件通常不能完成安装。Windows 电脑可用于下载与传输产物，但当前工程没有配置 OTA 分发服务；在实际选择分发渠道并确认安装前，不把 IPA 标记为已安装。

## 跨 App 采集的真机验收

1. 安装并启动签名 App，确认主应用能打开，广播扩展出现在系统广播选择器。
2. 由用户点选广播扩展并在系统界面确认开始。保持广播运行，切换到自制测试页面，再切换到其他 App。每一步记录扩展的采集状态、已收帧数、实际 FPS、OCR 延迟和最近画面时间。
3. 在自制页面放入明确的中英文文字与倒计时，对比 OCR 原文、置信度和重复识别结果。遮挡、切换 App、锁屏、电话打断及广播暂停/停止时记录失败原因和状态恢复。
4. 确认扩展在主 App 不处于前台时是否继续收到帧和执行本地 OCR；确认局域网健康探测是否得到 ESP32 的响应。扩展当前只进行只读健康探测，不自动发送点击指令。
5. 在上述基础能力验证前，不进行抖音自动操作。若第三方 App 阻止广播、画面不可用或规则不确定，保持人工控制并记录实际结果。

这一流程需要实际签名、安装和用户授权。无签名云端编译不能替代真机兼容性结论。
