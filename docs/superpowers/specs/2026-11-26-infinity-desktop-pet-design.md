# Infinity Desktop Pet Design

## Intent

Create a new Apple-platform app whose display name is `∞`, whose product and App Store name is `Infinity`, and whose bundle identifier is `com.example.infinity`. The app carries the complete desktop-pet experience from MyTools into a focused standalone product while preserving MyTools' native SwiftUI design language and repository organization.

## Goals

- Support iPhone, iPad, and Mac with minimum deployment targets iOS/iPadOS 26.0 and macOS 26.0.
- Preserve the pet's local state, decay, feeding, petting, poses, pixel art, 3D model, iOS/iPadOS in-app overlay, macOS desktop window, and interactive home-screen widget.
- Keep unreadable stored state instead of silently overwriting it.
- Share state between the iOS/iPadOS app and widget through an App Group, with a safe standard-defaults fallback for unsigned development builds.
- Use an original infinity-symbol app icon and `∞` as the installed display name.
- Keep the project small and independent from MyTools' finance, stock, server, activation, backup, and CloudKit systems.

## Non-goals

- Migrating existing MyTools user data into Infinity automatically.
- Reusing MyTools module activation or server licensing.
- Adding accounts, CloudKit, analytics, third-party packages, or non-pet tools.
- Shipping or submitting the app to App Store Connect in this task.

## Constraints

- App target product name: `Infinity`; display name: `∞`; bundle identifier: `com.example.infinity`.
- Widget bundle identifier: `com.example.infinity.widget`.
- App Group identifier: `group.com.example.infinity`.
- Native Swift, SwiftUI, RealityKit, WidgetKit, AppIntents, UIKit, and AppKit only.
- Repository organization follows MyTools: `Infinity/App`, `Infinity/Core`, `Infinity/Features/DesktopPet`, `InfinityWidget`, `InfinityTests`, `Config`, and `Documentation`.
- Pet state remains local-only and outside backups or cloud sync.

## Approaches

1. Copy and strip the entire MyTools project. Rejected because it would import a large unrelated project graph and create hidden coupling to modules, signing, and services.
2. Create a clean multi-platform project and port only the pet's dependency closure. Selected because it preserves behavior and presentation while producing a maintainable standalone app.
3. Rebuild a simplified pet from scratch. Rejected because it would not satisfy the requested complete migration of the pixel, 3D, overlay, desktop-window, and widget experiences.

## Architecture

`InfinityApp` owns one `DesktopPetStore` and platform presentation controllers. `DesktopPetState` and its repository are dependency-free domain code shared with the widget. Presentation remains split into focused SwiftUI files for the main screen, pixel renderer, 3D renderer, iOS overlay, and macOS desktop window. A small Core layer provides typography and logging compatibility without pulling in MyTools diagnostics.

The widget compiles the shared state and pixel renderer sources and exposes feed/pet App Intents. The app and widget use the App Group when signed with that entitlement and otherwise fall back safely during local development.

## Product Experience

The main window opens directly to the pet page. It uses the MyTools card hierarchy, typography, spacing, gradients, gauges, and native controls. Users can switch between pixel and 3D styles, tap to pet, feed the cat, enable the floating presentation appropriate to the platform, and delete local pet data. The pet remains named `脏脏橘`, matching the source feature.

## Branding

The icon is an original centered infinity mark with rounded, continuous geometry and a warm orange-to-violet palette that visually connects the pet's orange coat with the infinity identity. It must remain legible at small icon sizes and avoid text beyond the symbol itself.

## Verification

- Swift Testing covers decay, clock rollback, actions and poses, corrupt-state preservation, persistence, legacy migration, and reset behavior.
- The app and widget build for iOS Simulator 26.0; the app builds and tests for macOS 26.0.
- Project settings are inspected for names, bundle identifiers, supported platforms, deployment targets, App Group, and device families.
- Asset catalogs contain complete icon metadata and the original icon artwork.
