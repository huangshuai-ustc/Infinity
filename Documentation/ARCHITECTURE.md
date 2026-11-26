# Architecture

## Repository layout

- `Infinity/App`：启动与根导航。
- `Infinity/Core`：轻量日志与统一 SwiftUI 字体适配。
- `Infinity/Features/DesktopPet/Domain`：宠物状态、姿态、衰减与本地仓储。
- `Infinity/Features/DesktopPet/Application`：主线程 Store 与 Widget 刷新。
- `Infinity/Features/DesktopPet/Presentation`：主页面、像素渲染、3D 渲染与平台悬浮体验。
- `InfinityWidget`：WidgetKit 时间线、视图及 App Intents。
- `InfinityTests`：状态、持久化、组合和 3D 资源测试。

## State boundary

`DesktopPetState` 是 App 与 Widget 的稳定契约。它不依赖 SwiftUI、UIKit、AppKit 或日志类型。数据无法解码时，仓储把第一份异常字节保存在 `.unreadable` 键下，并拒绝仓储级自动更新，避免把损坏数据静默当成空状态覆盖。

App 中的显式喂食或摸摸会创建新的可用状态，但保留异常副本供诊断。没有可用 App Group 容器时，开发构建安全回退到标准 `UserDefaults`。

## Platform composition

同一 App Target 通过条件编译支持 iOS、iPadOS 和 macOS。iOS/iPadOS 使用独立透传 `UIWindow` 承载悬浮宠物；macOS 使用无边框 `NSPanel`。两者都复用相同 Store 和展示组件。

Widget Extension 直接编译领域状态、像素场景和 Sprite 三个共享源码文件，避免复制状态键或绘制逻辑。App 与 Widget 的 entitlements 都声明 `group.com.example.infinity`。

## Branding

`Assets.xcassets/AppIcon.appiconset` 包含原创橙紫色无限符号及 macOS 所需尺寸。源图为无透明通道的 1024×1024 RGB PNG；系统负责最终图标遮罩。
