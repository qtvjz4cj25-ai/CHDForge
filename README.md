# CHDForge - Batch CHD Converter

A macOS app for batch converting disc images to CHD format using [chdman](https://wiki.recalbox.com/en/tutorials/utilities/rom-conversion/chdman).

## About

This project was vibe coded with [Claude](https://claude.ai) (Anthropic's AI assistant) based on a script I originally wrote. The entire SwiftUI app — architecture, UI, parsing, and batch processing — was built collaboratively through conversation with Claude.

## Features

- **Bidirectional** — create CHD from disc images or extract disc images from CHD
- Batch convert CUE/BIN, GDI, and ISO disc images to CHD
- Batch extract CHD files back to BIN or ISO
- **Compression presets** — Fast, Balanced, or Smallest to trade speed for file size
- Folder scanning with recursive file discovery
- Drag and drop folder support
- Parallel conversions with configurable concurrency (1–8 simultaneous jobs)
- Pause, resume, and cancel conversions
- Real-time progress tracking with ETA
- Per-job and global logging with log file export
- Optional source file deletion after successful conversion
- macOS notifications on batch completion
- Drag-and-drop folders with auto-scan
- Auto-detection of chdman with guided install (Homebrew or MAME download)
- Automatic chdman capability detection (createcd/createdvd/extractcd/extractdvd)
- Configurable chdman binary path
- macOS native SwiftUI interface

## Compression Presets

CHD is a **lossless** format — gameplay is identical regardless of preset. The preset only affects conversion speed and resulting file size.

| Preset | Description | Best for |
|--------|-------------|----------|
| **Fast** | Lightweight compression (zlib/cdzl) | Large libraries where speed matters |
| **Balanced** | chdman defaults | General use (default) |
| **Smallest** | Multi-codec with tuned hunk sizes (lzma, cdlz, flac) | Maximizing disk savings |

Change the preset from the toolbar chip or in **Settings > Conversion**.

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

Since CHDForge is not signed with an Apple Developer ID, macOS Gatekeeper may block it the first time you launch it.

1. In Finder, locate `CHDForge.app`.
2. Right-click the app and choose `Open`.
3. If macOS still says it cannot be opened, go to `System Settings > Privacy & Security`.
4. Click `Open Anyway` for CHDForge, then confirm the prompt.

After you approve it once, the app should open normally.

## Building

Open the project in Xcode or build from the command line:

```bash
swift build
```

## Support

If you find CHDForge useful, consider buying me a coffee:

[![Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/ninjapiraterobo)

## License

MIT
