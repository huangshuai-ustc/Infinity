# Infinity

`Infinity` 是一个面向 iPhone、iPad 和 Mac 的原生 SwiftUI 桌面宠物 App。

- Display Name：`∞`
- Product / App Store Name：`Infinity`
- Bundle Identifier：`com.example.infinity`
- 最低系统：iOS / iPadOS 26.0、macOS 26.0

## 功能

- 会随时间变化饱腹与心情的「脏脏橘」
- 喂食、摸摸、睡眠、饥饿和开心状态
- 像素与 RealityKit 3D 两种展示
- iPhone / iPad App 内可拖动悬浮宠物
- macOS 跨桌面浮窗
- 可直接喂食和摸摸的交互式 Widget
- 原创无限符号 App Icon

宠物状态只保存在本机 `UserDefaults`；iOS App 与 Widget 通过 `group.com.example.infinity` App Group 共享状态，不参与 CloudKit 或业务备份。

## 构建

```sh
xcodebuild build -project Infinity.xcodeproj -scheme Infinity \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/infinity-ios-derived CODE_SIGNING_ALLOWED=NO

xcodebuild test -project Infinity.xcodeproj -scheme Infinity \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/infinity-macos-derived CODE_SIGNING_ALLOWED=NO
```

真机或归档前，在 Xcode 中为 App 和 Widget 选择同一开发团队，并在开发者账户中配置 `group.com.example.infinity` App Group。
