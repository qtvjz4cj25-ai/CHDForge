# CHDForge - Batch CHD Converter

A macOS app for batch converting disc images to CHD format using [chdman](https://wiki.recalbox.com/en/tutorials/utilities/rom-conversion/chdman).

## About

This project was vibe coded with [Claude](https://claude.ai) (Anthropic's AI assistant) based on a script I originally wrote. The entire SwiftUI app — architecture, UI, parsing, and batch processing — was built collaboratively through conversation with Claude.

## Features

- Batch convert CUE/BIN, GDI, and ISO disc images to CHD
- Folder scanning with recursive file discovery
- Drag and drop folder support
- Parallel conversions with configurable concurrency
- Pause, resume, and cancel conversions
- Real-time progress tracking with ETA
- Per-job and global logging with log file export
- Optional source file deletion after successful conversion
- macOS notifications on batch completion
- Auto-detection of chdman with guided install (Homebrew or MAME download)
- Automatic chdman capability detection (createcd/createdvd)
- Configurable chdman binary path
- macOS native SwiftUI interface

## Requirements

- macOS 13.0+
- [chdman](https://wiki.recalbox.com/en/tutorials/utilities/rom-conversion/chdman) binary installed

## Installing chdman

**Option 1 — Homebrew** (requires [Homebrew](https://brew.sh)):
```bash
brew install rom-tools
```

**Option 2 — MAME**: Download from [mamedev.org](https://www.mamedev.org/release.html), which includes chdman. Then set the path in the app's Settings.

## Running unsigned apps on macOS

Since CHDForge is not distributed through the Mac App Store or signed with an Apple Developer ID, macOS Gatekeeper will block it the first time you try to open it. To allow it:

1. **Right-click** (or Control-click) the app and select **Open**
2. Click **Open** in the dialog that appears
3. You only need to do this once — macOS will remember your choice

Alternatively, go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the blocked app message.

## Building

Open the project in Xcode or build from the command line:

```bash
swift build
```

## License

MIT
