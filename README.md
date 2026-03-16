# Kanshi

A native macOS menu bar app that monitors CI status on your open GitHub pull requests. Pure Swift + SwiftUI + AppKit, zero external dependencies.

## Features

- Menu bar icon reflects overall CI state (green/red/yellow/gray)
- Pull requests grouped by organization/user, sorted by most recent
- Expandable job list with clickable links to GitHub check-run pages
- Desktop notifications on CI failures
- Optional always-on-top floating window
- Configurable polling interval (30s, 1min, 10min, 30min, 1h)

## Requirements

- macOS 14+
- Xcode 15+
- [just](https://github.com/casey/just) command runner
- `swift-format` (`brew install swift-format`) — for formatting/linting only

## Build

```bash
just build      # Debug build
just release    # Release build
just run        # Build + launch app
```

## Install

1. Build a release:
   ```bash
   just release
   ```
2. Find the built app:
   ```bash
   open "$(xcodebuild -project Kanshi.xcodeproj -scheme Kanshi -configuration Release -showBuildSettings | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')"
   ```
3. Drag `Kanshi.app` to `/Applications`.

## Setup

1. Launch Kanshi — a circle icon appears in the menu bar.
2. Click the icon, expand **Settings**, and paste your GitHub Personal Access Token.
3. The token needs the `repo` scope to access check-run status on your PRs.

## Development

```bash
just fmt        # Format Swift code
just lint       # Check formatting
just clean      # Remove build artifacts
just open       # Open in Xcode
```
