# CHDForge — Batch ROM & Disc Image Converter

A macOS app for batch converting disc images and ROM archives across multiple emulator formats.

> Built with [Claude](https://claude.ai) (Anthropic's AI assistant) — the entire SwiftUI app was built collaboratively through conversation.

---

## Supported Tools & Formats

| Tool | Mode | Source → Output | Platform |
|------|------|-----------------|----------|
| **chdman** | Create | ISO, CUE/BIN, GDI → CHD | CD/DVD (PS1, PS2, Dreamcast, Saturn…) |
| **chdman** | Extract | CHD → BIN/ISO | |
| **dolphin-tool** | Create | ISO, GCZ, WIA → RVZ | GameCube / Wii |
| **dolphin-tool** | Extract | RVZ, GCZ, WIA → ISO | |
| **maxcso** | Create | ISO → CSO | PSP / PS2 |
| **maxcso** | Extract | CSO → ISO | |
| **nsz** | Create | NSP, XCI → NSZ, XCZ | Nintendo Switch |
| **nsz** | Extract | NSZ, XCZ → NSP, XCI | |
| **wit** | Create | ISO → WBFS | Wii / GameCube |
| **wit** | Extract | WBFS → ISO | |
| **7z** | Extract | 7Z, ZIP, RAR → files | Any ROM archive set |
| **Repackinator** | Create | ISO → CCI | Original Xbox |
| **Repackinator** | Extract | CCI → ISO | |

---

## Features

- **8 conversion backends** — one app for your entire ROM library
- **Bidirectional** — create compressed images or extract back to original
- **First-launch Setup Wizard** — detects missing tools and installs them in one click
- **Artwork Scraper** — fetch box art, screenshots, and wheel art from ScreenScraper.fr and generate `gamelist.xml` for EmulationStation, ES-DE, or Images Only
- Batch convert entire folders with recursive file discovery
- **Compression presets** — Fast, Balanced, or Smallest per tool
- Drag and drop folder support with auto-scan
- Parallel conversions — 1–8 simultaneous jobs (configurable)
- Pause, resume, and cancel mid-batch
- Real-time progress with ETA
- Per-job and global logging with log file export
- Optional source file deletion after successful conversion
- macOS notification on batch completion
- Auto-detection of all tool binaries
- Custom binary paths for every tool in Settings
- macOS native SwiftUI interface — requires macOS 13.0+

---

## Installing the Tools

### Setup Wizard (Recommended)

CHDForge includes a built-in **Setup Wizard** that runs automatically on first launch. It scans for each tool, shows what's missing, and lets you install everything with a single click — no terminal needed for most tools.

You can reopen the wizard any time from **Settings → Open Wizard**.

---

If you prefer to install manually, or if the wizard can't find a tool after installing it, follow the steps below.

---

### Manual Installation

Most tools can be installed through **Homebrew** — a package manager for macOS. If you don't have Homebrew yet, start there.

### Step 1 — Install Homebrew

Open **Terminal** (Applications → Utilities → Terminal) and paste:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the prompts. When it finishes, **read the terminal output carefully** — it will print two lines at the end that you must run to finish the setup. They look like this (Apple Silicon Macs):

```
==> Next steps:
Run these two commands in your terminal to add Homebrew to your PATH:
    (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Copy those exact two lines from your terminal and run them.** Without this step, `brew` won't be found in new terminal windows. On Intel Macs this step is usually not needed.

Verify the install worked:
```bash
brew --version
```

---

### Step 2 — Install Tools You Need

Install only the tools for the formats you care about. You don't need all of them.

#### chdman — CHD (CD/DVD)
For PS1, PS2, Dreamcast, Saturn, and other disc-based systems.
```bash
brew install rom-tools
```
Or download MAME from [mamedev.org](https://www.mamedev.org/release.html) (chdman is included), then set the path in Settings.

---

#### dolphin-tool — RVZ (GameCube / Wii)
```bash
npm i -g dolphin-tool
```
Requires **Node.js**. If you don't have it:
```bash
brew install node
```
Then install dolphin-tool:
```bash
npm i -g dolphin-tool
```
> **Note:** CHDForge auto-detects the native binary inside node_modules. If it can't find it, open Settings and paste the path to the binary. Run `npm root -g` in Terminal to find where npm installs global packages.

Alternatively, install [Dolphin Emulator](https://dolphin-emu.org/) — dolphin-tool is bundled inside the app.

---

#### maxcso — CSO (PSP / PS2)
maxcso is **not on Homebrew**. Download the macOS binary from GitHub:

[github.com/unknownbrackets/maxcso/releases](https://github.com/unknownbrackets/maxcso/releases)

Download the `.tar.gz` for macOS, extract it, and move `maxcso` somewhere permanent (e.g. `~/Applications/Tools/maxcso`). Then set the path in **Settings → maxcso Path**.

---

#### nsz — NSZ (Nintendo Switch)
Requires **Python 3**. If you don't have it:
```bash
brew install python
```
Then install nsz:
```bash
pip3 install nsz
```
CHDForge auto-detects nsz in common pip install locations. If it can't find it, run `which nsz` in Terminal and paste the result into **Settings → nsz Path**.

---

#### wit — WBFS (Wii / GameCube)
Wiimms ISO Tools must be built/installed manually — it's not on Homebrew.

**1. Download** the macOS package from [wit.wiimm.de/download.html](https://wit.wiimm.de/download.html)
   Choose the file ending in `-mac.tar.gz`.

**2. Extract the archive** — double-click the `.tar.gz` in Finder, or in Terminal:
```bash
cd ~/Downloads
tar -xzf wit-*.tar.gz
```

**3. Run the installer** — `cd` into the extracted folder, then run it with sudo:
```bash
cd ~/Downloads/wit-v*/
sudo ./install.sh
```
Enter your password when prompted. This copies `wit` and `wwt` to `/usr/local/bin/`.

> **Note:** The installer tries to download optional game title databases from gametdb.com and will print a bunch of errors if those downloads fail — that is completely harmless. The tool works fine without them.

**4. Verify it installed:**
```bash
ls /usr/local/bin/wit
```
If that file exists, CHDForge will find and use it automatically — no further setup needed.

**If macOS blocks it** when a conversion actually runs (you see "cannot be opened because the developer cannot be verified"), go to **System Settings → Privacy & Security** and click **Allow Anyway** next to wit.

---

#### 7z — Archive Extraction (7Z / ZIP / RAR)
```bash
brew install p7zip
```
Or install the newer official build:
```bash
brew install sevenzip
```

---

#### Repackinator — CCI (Original Xbox)
Repackinator is **not on Homebrew**. Download the macOS binary from GitHub:

[github.com/Team-Resurgent/Repackinator/releases](https://github.com/Team-Resurgent/Repackinator/releases/latest)

Download the `Repackinator-osx-arm64.tar` (Apple Silicon) or `Repackinator-osx-x64.tar` (Intel) archive, extract it, and move the `repackinator` binary somewhere permanent (e.g. `~/Applications/Repackinator/repackinator`). Then set the path in **Settings → Repackinator Path**.

> **Note:** After extracting, macOS may not mark the binary as executable. CHDForge will automatically `chmod +x` it on first use, but if you run it manually from Terminal first, run `chmod +x repackinator` in the folder where it lives.

**If macOS blocks it** (Gatekeeper), go to **System Settings → Privacy & Security** and click **Allow Anyway** next to Repackinator, then try running the conversion again.

---

### Verify Everything Is Working

After installing, launch CHDForge. The **Setup Wizard** will check each tool automatically. You can also select a tool in the sidebar — the app checks for its binary and shows an alert with instructions if it can't find it.

---

## Compression Presets

All formats use **lossless** compression — gameplay is bit-for-bit identical regardless of preset. The preset only affects conversion speed and file size.

### chdman (CHD)
| Preset | Method | Notes |
|--------|--------|-------|
| Fast | zlib / cdzl | Larger files, fast conversion |
| Balanced | chdman defaults | General use (recommended) |
| Smallest | lzma + cdlz + flac, tuned hunk sizes | Maximum compression, slowest |

### dolphin-tool (RVZ)
| Preset | Method | Notes |
|--------|--------|-------|
| Fast | zstd level 1 | Quick with decent ratio |
| Balanced | zstd level 5 | Good balance (recommended) |
| Smallest | lzma2 level 9 | Smallest files, slowest |

### maxcso (CSO)
| Preset | Method | Notes |
|--------|--------|-------|
| Fast | LZ4 | Fastest compression |
| Balanced | zlib (default) | Good balance |
| Smallest | zstd | Smallest files |

### nsz (NSZ/XCZ)
| Preset | Level | Notes |
|--------|-------|-------|
| Fast | zstd level 3 | Fast |
| Balanced | zstd level 18 | nsz default (recommended) |
| Smallest | zstd level 22 | Maximum compression |

### wit (WBFS)
| Preset | Behavior | Notes |
|--------|----------|-------|
| Fast | No scrubbing | Faster, slightly larger |
| Balanced | Default scrubbing | Removes unused game data |
| Smallest | Aggressive trim | Smallest possible WBFS |

### Repackinator (CCI)
| Preset | Behavior | Notes |
|--------|----------|-------|
| Fast | CCI only | Fastest, no padding removal |
| Balanced | CCI + scrub | Removes padding sectors |
| Smallest | CCI + trimscrub | Scrub and trim for smallest size |

---

## Running the App (Gatekeeper)

Since CHDForge is not signed with an Apple Developer ID, macOS will block it on first launch.

1. Right-click `CHDForge.app` → **Open**
2. macOS says it can't be verified — click **Open** if the option appears, or dismiss the dialog
3. Go to **System Settings → Privacy & Security**
4. Scroll down to find CHDForge listed with an **Open Anyway** button — click it
5. Launch the app again and authenticate with your admin password when prompted

After this one-time setup, the app opens normally.

---

## Building from Source

Open in Xcode or build from Terminal:
```bash
swift build
```
Requires Xcode 15+ and macOS 13.0+ SDK.

---

## Architecture

Layered SwiftUI architecture with a `BatchEngine` base class that provides concurrency, pause/resume, and cancel for all tools:

- **Models** — `ConversionJob`, `ToolKind`, `AppMode`, `SourceType`, `CompressionPreset`
- **Services** — `BatchEngine` (shared concurrency), one `Engine` + one `Locator` per tool, `FolderScanner`, `ProcessRunner`, `LogStore`
- **ViewModels** — `AppViewModel` (central state + orchestration)
- **Views** — `ContentView` (NavigationSplitView), `FileListView`, `LogPanelView`, `SettingsView`, `SetupWizardView`
- **Scraper** — `ArtworkScraperView`, `ScreenScraperClient`, `ScreenScraperModels`, `GamelistWriter`
- **Parsers** — `CueParser`, `GdiParser` (multi-file source cleanup)

Adding a new conversion tool:
1. Add `SourceType` + `ToolKind` cases in `ConversionJob.swift`
2. Create a Locator struct (find + verify the binary)
3. Create a `BatchEngine` subclass (override `convert()`, optionally `cleanupSource()`)
4. Add scan extensions in `FolderScanner`
5. Add compression arguments in `CompressionPreset`
6. Wire up in `AppViewModel`, `ContentView`, and `SettingsView`

---

## Support

If you find CHDForge useful, consider buying me a coffee:

[![Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/ninjapiraterobo)

---

## License

MIT
