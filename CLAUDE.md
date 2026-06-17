# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CalendarX (小日历) is a macOS menu bar calendar app built with SwiftUI. It displays in the system menu bar as a popover and supports lunar calendar, Chinese holidays, calendar events, and desktop widgets.

## Build & Run

```bash
# Build from Xcode (no CLI build script provided)
open CalendarX.xcodeproj

# Build via xcodebuild
xcodebuild -project CalendarX.xcodeproj -scheme CalendarX -configuration Debug build

# Create DMG for release (used in CI)
scripts/create_dmg.sh
```

- **Xcode project**: `CalendarX.xcodeproj` (not SPM-based at root level)
- **Deployment target**: macOS 11.0+
- **Swift version**: 6.0 (strict concurrency enabled)
- **Bundle ID**: `com.dd.calendarx`

## Architecture

### Targets

| Target | Purpose |
|--------|---------|
| `CalendarX` | Main menu bar app |
| `CalendarXWidget` | WidgetKit extension (Large widget with interactive support on macOS 14+) |
| `CalendarXIntentExtension` | App Intents for widget configuration |
| `CalendarXLib` | Shared Swift Package (local) — models, extensions, festival data |

### App Architecture (MVVM + Router)

- **Router** (`Router.swift`): Stack-based navigation using `@Published path: [Screen]`. Left-click opens calendar, right-click opens context menu.
- **MenubarController**: Owns the `NSStatusItem`, `MenubarPopover`, and `MenubarSchedule`. Bridges AppKit menu bar with SwiftUI views.
- **MenubarPopover**: `NSPopover` subclass hosting SwiftUI `RootScreen` via `NSHostingController`. Handles global event monitors for dismiss-on-click-outside.
- **RootScreen**: Switches between screens based on `router.root` (base) and `router.top` (overlay with animation).

### State Management

- `AppStore` — `@AppStorage` wrapper for theme, appearance, language (stored in App Group `UserDefaults`)
- `MenubarStore` — menubar display style preferences (icon/text/date format)
- `CalendarStore` — calendar data access and event authorization
- `MainViewModel` — calendar grid data, current month navigation

All stores use `@MainActor` and `ObservableObject`. Injected as `@EnvironmentObject` in SwiftUI views.

### CalendarXLib (Shared Package)

Located at `CalendarXLib/`, swift-tools-version 5.9, targets macOS 11+.

Key contents:
- `Model/AppDate.swift` — type aliases mapping to EventKit types (`AppDate = Date`, `AppEvent = EKEvent`)
- `FestivalStore.swift` — Chinese lunar calendar festivals and 调休 (tiaoxiu) data from bundled JSON
- `Extension/Calendar+.swift` — date grid generation for month views
- `Extension/Date+.swift` — date comparison and component helpers
- `L10n.swift` — localization key constants
- `Constant.swift` — shared constants (sizes, storage keys)

### Auto-Update

Uses [Sparkle](https://github.com/sparkle-project/Sparkle) framework via `Updater.swift`. Appcast XML at project root. EdDSA key signing for update verification.

## Dependencies

- **Sparkle** — macOS app auto-update framework
- **Schedule** — timer scheduling library
- **Swift Algorithms** — Apple's algorithms package

All managed via Swift Package Manager in Xcode.

## Localization

Two languages supported: English (`en.lproj/`) and Simplified Chinese (`zh-Hans.lproj/`). Keys defined in `CalendarXLib/Sources/L10n.swift`, strings in `Localizable.strings`.

## Key Patterns

- `@MainActor` is used extensively — all ViewModels, stores, and most public CalendarXLib types are main-actor isolated (Swift 6 concurrency)
- Navigation via `Router.push()` / `Router.pop()` with optional animation
- Cross-component communication uses `NotificationCenter` publishers (e.g., `.popoverWillCloseManually`, `.titleStyleDidChanged`)
- Widget timeline refresh triggered by `WidgetCenter.shared.reloadAllTimelines()` on EventKit changes
