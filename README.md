# Infinity

`Infinity` 是一个面向 iPhone、iPad 和 Mac 的原生 SwiftUI 提醒事项 App，安装后的显示名称为 `∞`。App 内保留一只可拖动的悬浮猫咪，提供轻触互动和自动动作。

- Display Name：`∞`
- Product / App Store Name：`Infinity`
- Bundle Identifier：`com.example.infinity`
- 最低系统：iOS / iPadOS 26.0、macOS 26.0

## 功能

- 创建带时间和内容的提醒事项
- 本地通知权限申请与定时提醒
- 提醒完成勾选和左滑删除
- iPhone / iPad App 内可拖动悬浮猫咪
- 点击触感反馈和自动动画动作
- 原创无限符号 App Icon

提醒数据只保存在本机 `UserDefaults`，通知使用系统本地通知，不参与 CloudKit 或业务备份。

## 构建

```sh
xcodebuild build -project Infinity.xcodeproj -scheme Infinity \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/infinity-ios-derived CODE_SIGNING_ALLOWED=NO

xcodebuild test -project Infinity.xcodeproj -scheme Infinity \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/infinity-macos-derived CODE_SIGNING_ALLOWED=NO
```

也可以直接在 Xcode 中打开 `Infinity.xcodeproj`，选择 `Infinity` scheme 后运行。

### iOS Simulator

项目已在 Xcode 27.1 的 iPhone 17 Simulator 上验证通过，能够完成编译、安装和启动。使用 MobileBuildMCP 时可以运行：

```sh
mobilebuildmcp simulator build-and-run \
  --project-path Infinity.xcodeproj \
  --scheme Infinity \
  --simulator-name 'iPhone 17'
```

### 真机签名

真机运行前，在 Xcode 的 App 和 `InfinityWidgetExtension` target 中选择同一个 Apple Developer Team，并确认以下标识符均已注册或允许自动签名：

- App：`com.example.infinity`
- Widget：`com.example.infinity.widget`
- App Group：`group.com.example.infinity`

真机安装还要求设备运行 iOS / iPadOS 26.0 或更高版本，并在设备上信任开发者证书。项目不会提交或包含个人签名证书、Provisioning Profile、Xcode 用户数据或构建产物。

真机或归档前，在 Xcode 中为 App 和 Widget 选择同一开发团队，并在开发者账户中配置 `group.com.example.infinity` App Group。
