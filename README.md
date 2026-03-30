# LightSwitcher

An extremely fast, extremely low-memory macOS window switcher.

## Current behavior

- Background menu bar app with no Dock icon
- Default shortcut: `Option+Tab`
- Shows only app icon + window title
- Snapshots visible windows only when triggered
- Cycles while the modifier is held
- Switches on modifier release

## Build

- Local development: `swift build` / `swift test` when the local toolchain is healthy
- CI build: GitHub Actions runs `swift test` and `xcodebuild`

## Notes

- Accessibility permission is required
- No previews, no screenshots, no persistent window tracking
