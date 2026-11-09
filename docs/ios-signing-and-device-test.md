# iPhone 真机签名与屏幕广播验证

## 当前状态

`ios-native-unsigned` 已在 Codemagic 和 GitHub Actions 的 macOS/Xcode 环境编译主应用与 ReplayKit 广播扩展。无签名 IPA 不能直接安装；2026-11-09 已用 Windows iPASide 和用户自己的免费 Apple Account 在本机签名并安装到 iPhone 16 Pro。用户开启开发者模式后，应用和 `OpenClaw Screen OCR` 广播扩展均能在真机打开。免费签名需要定期刷新，且不提供 App Group 权限；主应用与扩展现用同一签名下的 Keychain 共享少量状态和 OCR 文本，不共享截图。令牌仅保存在用户设备上。

2026-11-07 的 [Codemagic 构建 6aef32ab24e1ec2375572f29](https://codemagic.io/app/6aec822974fc39deaceedfc9/build/6aef32ab24e1ec2375572f29) 显示：Mac mini M2、`main`、提交 `5b4f3cb`、工作流 `OpenClaw Vision - unsigned validation`，状态 `finished`，页面出现绿色构建成功提示。这是该提交的无签名云端编译记录。签名工作流是在后续提交中准备的，尚未运行。

2026-11-09 的 [GitHub Actions 无签名构建 #10](https://github.com/baijianyang338-ctrl/openclaw/actions/runs/42616164901) 在提交 `c394d08d9a9c66fff8728d6ea6943df916434dc7` 成功，产物包含主应用、广播扩展及 IPA。该 IPA 已通过 iPASide 本机签名并覆盖安装。Codemagic 的正式 Ad Hoc 签名工作流仍未运行。

## 已完成的真机验证（2026-11-09）

- 用户从控制中心选择 `OpenClaw Screen OCR` 并明确开始广播，然后切到 Safari。USB 系统日志在约 18 秒内记录 343 条扩展收到 `replayd` 视频帧的消息，说明主应用退到后台后，广播扩展继续收到跨 App 画面。
- 重新进入主应用时，界面显示已接收 456 帧、约 50 FPS、最近一次 OCR 耗时 52 ms，证明本地采集和 Vision OCR 路径在该次测试中运行。OCR 文字准确率及抖音页面兼容性尚未验收。
- iPhone App 配置同一局域网中的真实 ESP32-S3 后，“测试连接”显示已连接、BLE HID 已连接和 28 °C。用户点击“发送 PING”，App 收到匹配序号的 `EXECUTED` 回执。设备对重复序号返回 `DUPLICATE`。
- ESP32 通过 BLE HID 键盘把 32 字符本机配对令牌输入到 App 的令牌框，随后 App 的认证健康检查成功。这只验证该 ASCII 输入场景，不证明中文评论可输入。
- 自制 Safari 点击测试页能从 iPhone 加载，人工点击能增加网页计数；ESP32 的 `CLICK` 返回 `EXECUTED` 后网页计数未增加。鼠标点击、指针定位、完整识别到操作的闭环及自动评论 **尚未通过真机验证**。不能把 HID 报告发送成功当成点击成功。

## Codemagic 页面操作

1. 打开 Codemagic 的 `openclaw` 项目，点 **Start new build**，分支选 `main`、工作流先选 **OpenClaw Vision - unsigned validation**。确认所有步骤为绿色，尤其是 `Build iOS app and broadcast extension without signing` 和 `Verify embedded broadcast extension`。
2. 在 Apple Developer Program 中登记这部 iPhone 的 UDID。创建主应用 `com.baijianyang.openclawvision` 和广播扩展 `com.baijianyang.openclawvision.broadcast` 两个 App ID，为两者启用相同的 App Group `group.com.baijianyang.openclawvision`。若实际标识已被占用，先同步修改 Xcode 项目、两个 entitlements 和 `codemagic.yaml` 的签名标识。
3. 为主应用和广播扩展分别准备包含该 iPhone 的 Ad Hoc provisioning profile，并准备匹配的 Apple Distribution 证书。只在 Codemagic 的 **Team settings → codemagic.yaml settings → Code signing identities** 上传；私钥、证书密码、`.p12`、`.mobileprovision` 和 API key 不进入 Git。
4. 再点 **Start new build**，分支选 `main`、工作流选 **OpenClaw Vision - signed iPhone test**。工作流先执行 `xcode-project use-profiles`，再执行 `xcode-project build-ipa`；成功后在构建页 **Artifacts** 下载 `build/ios/ipa/*.ipa`。若提示 `No matching profiles`，检查两个 Bundle ID、Ad Hoc 类型、App Group 和设备 UDID；不要关闭签名检查。

上述签名流程依据 [Codemagic iOS 签名文档](https://docs.codemagic.io/yaml-code-signing/signing-ios/) 和 [原生 iOS 工程指南](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/)。非 TestFlight 的真机安装要求设备已登记且位于描述文件中，见 [Codemagic 设备登记说明](https://docs.codemagic.io/yaml-testing/ios-provisioning/)。

## 在 iPhone 上安装

免费个人安装路径已在本机成功实测：从成功的无签名云端构建下载 IPA，在 Windows iPASide 内用用户自己的 Apple Account 本机签名，安装时保留广播扩展，然后在 iPhone 上启用开发者模式并打开 App。免费描述文件有效期有限，需定期重新签名安装；iPASide 的自动刷新能力尚未验证。不要把 Apple Account 密码、签名材料、设备令牌或个性化 IPA 提交到仓库。付费开发者账号仍可采用上面的 Codemagic Ad Hoc 流程。

## 跨 App 采集的真机验收

1. 安装并启动签名 App，确认主应用能打开，广播扩展出现在系统广播选择器。
2. 由用户点选广播扩展并在系统界面确认开始。保持广播运行，切换到自制测试页面，再切换到其他 App。每一步记录扩展的采集状态、已收帧数、实际 FPS、OCR 延迟和最近画面时间。
3. 在自制页面放入明确的中英文文字与倒计时，对比 OCR 原文、置信度和重复识别结果。遮挡、切换 App、锁屏、电话打断及广播暂停/停止时记录失败原因和状态恢复。
4. 确认扩展在主 App 不处于前台时是否继续收到帧和执行本地 OCR；确认局域网健康探测是否得到 ESP32 的响应。扩展当前只进行只读健康探测，不自动发送点击指令。
5. 在上述基础能力验证前，不进行抖音自动操作。若第三方 App 阻止广播、画面不可用或规则不确定，保持人工控制并记录实际结果。

首次 Safari 跨 App 广播验证已通过；后续仍需逐项验证页面文字、按钮坐标、BLE 点击、中文输入与抖音兼容性。只有应用重新识别到预期画面变化，才能把操作标记为成功。

