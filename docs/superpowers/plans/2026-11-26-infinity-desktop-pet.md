# Infinity Desktop Pet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the standalone `Infinity` Apple-platform app with the complete MyTools desktop-pet experience.

**Architecture:** A single SwiftUI app target supports iOS, iPadOS, and macOS, with platform-specific overlay/window controllers behind compile conditions. A WidgetKit extension shares dependency-free pet domain and pixel-renderer sources with the app through an App Group.

**Tech Stack:** Swift 6, SwiftUI, RealityKit, WidgetKit, AppIntents, UIKit, AppKit, Swift Testing, Xcode project format.

**Spec:** `docs/superpowers/specs/2026-11-26-infinity-desktop-pet-design.md`

## Global Constraints

- Display name is `∞`; product/App Store name is `Infinity`; app bundle identifier is `com.example.infinity`.
- Minimum systems are iOS/iPadOS 26.0 and macOS 26.0.
- No third-party dependencies, accounts, licensing, CloudKit, or MyTools business modules.
- Pet state is local-only; unreadable bytes are preserved and not silently replaced.
- Full migration includes pixel and 3D pets, iOS/iPadOS overlay, macOS desktop window, and interactive widget.

## Review Focus

- A backwards-moving clock must not increase or corrupt levels; covered by Task 2 tests.
- Corrupt persisted JSON must be copied aside and never overwritten by repository update; covered by Task 2 tests.
- Unsigned builds without an App Group container must fall back to standard defaults; covered by Task 2 structure and build verification.
- Platform-only UIKit/AppKit code must not leak into the other platform build; covered by Task 4 builds.
- Widget and app must agree on state keys, widget kind, App Group, and intents; covered by Task 5 build and settings inspection.

---

### Task 1: Project skeleton and identity

**Files:**
- Create: `Infinity.xcodeproj/project.pbxproj`
- Create: `Infinity.xcodeproj/xcshareddata/xcschemes/Infinity.xcscheme`
- Create: `Config/Shared.xcconfig`
- Create: `Config/Infinity.entitlements`
- Create: `Config/InfinityWidget.entitlements`
- Create: `Infinity/Info.plist`
- Create: `InfinityWidget/Info.plist`
- Create: `Infinity/PrivacyInfo.xcprivacy`
- Create: `InfinityWidget/PrivacyInfo.xcprivacy`

**Interfaces:**
- Produces: app target `Infinity`, widget target `InfinityWidgetExtension`, unit-test target `InfinityTests`, shared scheme `Infinity`.

- [ ] Create the project and configuration with exact identity, deployment targets, supported platforms, device families, and App Group values from the spec.
- [ ] Run `xcodebuild -project Infinity.xcodeproj -scheme Infinity -showBuildSettings` and inspect the identity/platform settings.

### Task 2: Pet domain and persistence

**Files:**
- Test: `InfinityTests/DesktopPet/DesktopPetStateTests.swift`
- Create: `Infinity/Features/DesktopPet/Domain/DesktopPetState.swift`
- Create: `Infinity/Features/DesktopPet/Application/DesktopPetStore.swift`
- Create: `Infinity/Core/Diagnostics/AppLogger.swift`

**Interfaces:**
- Produces: `DesktopPetPose`, `DesktopPetState`, `DesktopPetDefaults`, `DesktopPetStateRepository`, and `@MainActor DesktopPetStore` with `feed()`, `pet()`, `reload()`, and `removeLocalData()`.

- [ ] Write tests for initial values, decay, clock rollback, pose priority, feed/pet effects, pose transition dates, corrupt-state preservation, legacy move, store persistence, and reset.
- [ ] Run the focused test target and confirm it fails because the domain types are absent.
- [ ] Implement the dependency-free state/repository and app store using Infinity App Group keys.
- [ ] Run the focused tests and confirm they pass.

### Task 3: Main pet presentation and resources

**Files:**
- Create: `Infinity/App/Bootstrap/InfinityApp.swift`
- Create: `Infinity/App/Navigation/RootView.swift`
- Create: `Infinity/Core/UI/AppTypography.swift`
- Create: `Infinity/Features/DesktopPet/Presentation/DesktopPetView.swift`
- Create: `Infinity/Features/DesktopPet/Presentation/DesktopPetCatView.swift`
- Create: `Infinity/Features/DesktopPet/Presentation/DesktopPetPixelSprite.swift`
- Create: `Infinity/Features/DesktopPet/Presentation/DesktopPetModelView.swift`
- Create: `Infinity/Features/DesktopPet/Resources/DesktopPetCat.usdz`

**Interfaces:**
- Consumes: Task 2 state/store types.
- Produces: `DesktopPetView`, `DesktopPetAnimatedCat`, and `DesktopPetModelView` wired into the app root.

- [ ] Add a compile-level presentation smoke test that instantiates the root view with an injected store.
- [ ] Run the test/build and confirm it fails because presentation types are absent.
- [ ] Port the pet page, pixel renderer, sprite, and RealityKit model renderer; replace MyTools-only logging/font calls with Core compatibility APIs.
- [ ] Copy the verified USDZ resource into the app target.
- [ ] Run the focused tests and app builds.

### Task 4: Platform floating experiences

**Files:**
- Create: `Infinity/Features/DesktopPet/Presentation/DesktopPetOverlay.swift`
- Create: `Infinity/Features/DesktopPet/Presentation/DesktopPetDesktopWindow.swift`

**Interfaces:**
- Consumes: Task 2 store and Task 3 animated pixel cat.
- Produces: iOS/iPadOS `DesktopPetOverlayController` and macOS `DesktopPetDesktopWindowController` injected into the root UI.

- [ ] Add controller state tests for persisted visibility and safe repeated show/hide transitions where platform APIs permit.
- [ ] Run tests and confirm failure because controllers are absent.
- [ ] Port the overlay and desktop-window controllers with Infinity persistence keys and app-level wiring.
- [ ] Build both iOS Simulator and macOS destinations to catch platform leakage.

### Task 5: Interactive Widget

**Files:**
- Create: `InfinityWidget/InfinityWidgetBundle.swift`
- Create: `InfinityWidget/DesktopPetWidget.swift`
- Modify: `Infinity.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Task 2 shared state/repository and Task 3 pixel renderer.
- Produces: interactive feed/pet widget using `DesktopPetFeedIntent` and `DesktopPetPetIntent`.

- [ ] Port the timeline provider, widget view, and App Intents without MyTools activation checks or copy.
- [ ] Build the widget target for iOS Simulator.
- [ ] Inspect that app and widget entitlements and Info.plist values use `group.com.example.infinity` and the same widget kind/state keys.

### Task 6: Infinity brand assets and documentation

**Files:**
- Create: `Infinity/Assets.xcassets/Contents.json`
- Create: `Infinity/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: app icon PNG assets
- Create: `README.md`
- Create: `Documentation/ARCHITECTURE.md`

**Interfaces:**
- Produces: complete branded asset catalog and developer-facing project documentation.

- [ ] Generate an original infinity-symbol icon with no MyTools branding and populate the asset catalog.
- [ ] Verify pixel dimensions, alpha/channel behavior, and asset-catalog metadata.
- [ ] Document architecture, local-only state, App Group signing, platform behavior, and build commands.

### Task 7: Final verification

**Files:**
- Modify only files required to address verification findings.

**Interfaces:**
- Consumes: all previous tasks.
- Produces: verified build/test evidence and a clean source tree.

- [ ] Run all unit tests on macOS 26.0.
- [ ] Build the app and widget for an iOS 26.0 simulator.
- [ ] Build the app for macOS 26.0.
- [ ] Run `plutil -lint` on plist and entitlement files and inspect build settings for all requested identifiers.
- [ ] Run `git diff --check` if the directory is initialized as Git; otherwise inspect generated files and report that no repository metadata exists.
