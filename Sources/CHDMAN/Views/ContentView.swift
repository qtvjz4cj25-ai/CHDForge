import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 175, ideal: 190, max: 210)
        } detail: {
            DetailView()
        }
        .frame(minWidth: 820, minHeight: 560)
        // ── Alerts ──────────────────────────────────────────────────────────
        .alert("chdman not available", isPresented: $vm.showChdmanAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.chdmanAlertMessage) }

        .alert("chdman not found", isPresented: $vm.chdmanMissing) {
            Button("Copy Homebrew Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("brew install rom-tools", forType: .string)
            }
            Button("Download from MAME") {
                NSWorkspace.shared.open(URL(string: "https://www.mamedev.org/release.html")!)
            }
            Button("Open Settings") { openSettings() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("chdman is required but was not found.\n\nOption 1 — Homebrew:\nbrew install rom-tools\n\nOption 2 — Download MAME (includes chdman) and set the path in Settings.")
        }

        .alert("dolphin-tool not available", isPresented: $vm.showDolphinToolAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.dolphinToolAlertMessage) }

        .alert("dolphin-tool not found", isPresented: $vm.dolphinToolMissing) {
            Button("Copy npm Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("npm i -g dolphin-tool", forType: .string)
            }
            Button("Open Settings") { openSettings() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("dolphin-tool is required for RVZ conversions.\n\nInstall via npm (requires Node.js):\nnpm i -g dolphin-tool\n\nThe app auto-detects the native binary inside node_modules.")
        }

        .alert("maxcso not available", isPresented: $vm.showMaxcsoAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.maxcsoAlertMessage) }

        .alert("maxcso not found", isPresented: $vm.maxcsoMissing) {
            Button("Download from GitHub") {
                NSWorkspace.shared.open(URL(string: "https://github.com/unknownbrackets/maxcso/releases")!)
            }
            Button("Open Settings") { openSettings() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("maxcso is required for CSO conversions.\n\nDownload from:\ngithub.com/unknownbrackets/maxcso/releases\n\nThen set the path in Settings.")
        }

        .alert("nsz not available", isPresented: $vm.showNszAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.nszAlertMessage) }

        .alert("nsz not found", isPresented: $vm.nszMissing) {
            Button("Copy pip Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("pip3 install nsz", forType: .string)
            }
            Button("Open Settings") { openSettings() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("nsz is required for Nintendo Switch conversions.\n\nInstall with pip:\npip3 install nsz")
        }

        .alert("wit not available", isPresented: $vm.showWitAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.witAlertMessage) }

        .alert("wit not found", isPresented: $vm.witMissing) {
            Button("Open Downloads") {
                NSWorkspace.shared.open(URL(string: "https://wit.wiimm.de/download.html")!)
            }
            Button("Open Settings") { openSettings() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("wit (Wiimms ISO Tools) is required for WBFS conversions.\n\nDownload from wit.wiimm.de and run: sudo ./install.sh")
        }

        .alert("7z not available", isPresented: $vm.showSevenZipAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.sevenZipAlertMessage) }

        .alert("7z not found", isPresented: $vm.sevenZipMissing) {
            Button("Copy Homebrew Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("brew install p7zip", forType: .string)
            }
            Button("Open Settings") { openSettings() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("7z is required for archive extraction.\n\nInstall with Homebrew:\nbrew install p7zip")
        }

        .alert("Repackinator not available", isPresented: $vm.showRepackinatorAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.repackinatorAlertMessage) }

        .alert("Repackinator not found", isPresented: $vm.repackinatorMissing) {
            Button("Open Downloads") {
                NSWorkspace.shared.open(URL(string: "https://github.com/Team-Resurgent/Repackinator/releases/latest")!)
            }
            Button("Open Settings") { openSettings() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("Repackinator is required for Xbox OG CCI conversions.\n\nDownload the osx-arm64 or osx-x64 tar from GitHub, then set the path in Settings.")
        }

        .alert("makeps3iso not available", isPresented: $vm.showMakePs3IsoAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.makePs3IsoAlertMessage) }

        .alert("extract-xiso not available", isPresented: $vm.showExtractXisoAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.extractXisoAlertMessage) }

        .alert("extract-xiso not found", isPresented: $vm.extractXisoMissing) {
            Button("Copy Homebrew Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("brew install extract-xiso", forType: .string)
            }
            Button("Open GitHub") {
                NSWorkspace.shared.open(URL(string: "https://github.com/xboxdev/extract-xiso")!)
            }
            Button("Open Settings") { openSettings() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("extract-xiso is required for Xbox OG XISO creation and extraction.\n\nInstall with Homebrew:\nbrew install extract-xiso\n\nOr build from source at github.com/xboxdev/extract-xiso")
        }

        .alert("ps3iso-utils not found", isPresented: $vm.makePs3IsoMissing) {
            Button("Open Downloads") {
                NSWorkspace.shared.open(URL(string: "https://github.com/bucanero/ps3iso-utils/releases")!)
            }
            Button("Open Settings") { openSettings() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("ps3iso-utils (makeps3iso + extractps3iso) is required for PS3 ISO conversions.\n\nDownload the tar from GitHub, extract it, chmod +x the binaries, and set the paths in Settings.")
        }

        // ── Sheets ──────────────────────────────────────────────────────────
        .sheet(isPresented: $vm.showSetupWizard) {
            SetupWizardView(onDismiss: { vm.showSetupWizard = false })
        }
        .sheet(isPresented: $vm.showArtworkScraper) {
            ArtworkScraperView().environmentObject(vm)
        }
        .task { await vm.checkSelectedToolAvailability() }
        .onChange(of: vm.selectedTool) { _ in
            Task { await vm.handleToolSelectionChange() }
        }
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $vm.selectedTool) {
                Section("Converters") {
                    ForEach(ToolKind.allCases) { tool in
                        toolRow(tool)
                            .tag(tool)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Scraper entry at bottom — always visible
            Button {
                vm.showArtworkScraper = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "photo.badge.arrow.down.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.purple)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Artwork Scraper")
                            .font(.system(.body, weight: .medium))
                        Text("ScreenScraper.fr")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(Color.purple.opacity(0.05))

            Divider()

            // Settings + setup at very bottom
            HStack(spacing: 0) {
                Button {
                    vm.showSetupWizard = true
                } label: {
                    Label("Setup", systemImage: "wrench.and.screwdriver")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                Divider().frame(height: 20)

                Group {
                    if #available(macOS 14.0, *) {
                        SettingsLink {
                            Label("Settings", systemImage: "gear")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        } label: {
                            Label("Settings", systemImage: "gear")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func toolRow(_ tool: ToolKind) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tool.icon)
                .font(.system(size: 14))
                .foregroundStyle(toolColor(tool))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(tool.displayName)
                    .font(.system(.body, weight: .medium))
                Text(tool.shortDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func toolColor(_ tool: ToolKind) -> Color {
        switch tool {
        case .chdman:      return .blue
        case .dolphinTool: return .cyan
        case .maxcso:      return Color(red: 0.55, green: 0.35, blue: 0.85)
        case .nsz:         return .red
        case .sevenZip:     return .green
        case .wit:          return .orange
        case .repackinator: return Color(red: 0.7, green: 0.2, blue: 0.2)
        case .makeps3iso:   return Color(red: 0.0, green: 0.45, blue: 0.85)
        case .extractXiso:  return Color(red: 0.1, green: 0.6, blue: 0.2)
        }
    }
}

// MARK: - Detail

private struct DetailView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Header: mode + folder ──────────────────────────────────────
            VStack(spacing: 10) {
                // Mode toggle
                if vm.selectedTool.supportsCreate && vm.selectedTool.supportsExtract {
                    modeToggle
                } else if !vm.selectedTool.supportsCreate {
                    // Extract-only (7z)
                    HStack {
                        Label("Extract Only", systemImage: "archivebox.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }

                // Folder row
                folderRow
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(headerBackground)

            Divider().overlay(Color.primary.opacity(0.08))

            // ── File list (drop zone) ──────────────────────────────────────
            ZStack {
                FileListView()

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor, lineWidth: 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.07))
                        )
                        .overlay(
                            Label("Drop folder to scan", systemImage: "folder.badge.plus")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        )
                        .padding(6)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 200)
            .onDrop(of: [UTType.folder, UTType.fileURL],
                    isTargeted: $isDropTargeted,
                    perform: handleDrop)

            Divider().overlay(Color.primary.opacity(0.08))

            // ── Controls ──────────────────────────────────────────────────
            controlsRow
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(headerBackground)

            Divider().overlay(Color.primary.opacity(0.08))

            // ── Progress ──────────────────────────────────────────────────
            progressRow
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider().overlay(Color.primary.opacity(0.08))

            // ── Log ───────────────────────────────────────────────────────
            LogPanelView(
                log: vm.globalLog,
                autoScroll: $vm.autoScrollLog,
                onOpenFile: { vm.openLogFile() }
            )
            .frame(minHeight: 140, idealHeight: 180)
        }
    }

    // MARK: - Mode toggle

    @ViewBuilder
    private var modeToggle: some View {
        HStack(spacing: 8) {
            ForEach(AppMode.allCases) { mode in
                Button {
                    guard !vm.isConverting else { return }
                    vm.appMode = mode
                    vm.clearList()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(mode.label(for: vm.selectedTool))
                            .font(.system(.subheadline, weight: .semibold))
                        Spacer()
                        Text(modeSubtitle(mode))
                            .font(.caption2)
                            .opacity(0.75)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(vm.appMode == mode
                                  ? Color.accentColor
                                  : Color.primary.opacity(0.06))
                    )
                    .foregroundStyle(vm.appMode == mode ? .white : .primary)
                }
                .buttonStyle(.plain)
                .disabled(vm.isConverting)
            }
        }
    }

    private func modeSubtitle(_ mode: AppMode) -> String {
        switch (vm.selectedTool, mode) {
        case (.chdman,      .create):  return "ISO / CUE / GDI → CHD"
        case (.chdman,      .extract): return "CHD → ISO / BIN"
        case (.dolphinTool, .create):  return "ISO / GCZ / WIA → RVZ"
        case (.dolphinTool, .extract): return "RVZ / GCZ / WIA → ISO"
        case (.maxcso,      .create):  return "ISO → CSO"
        case (.maxcso,      .extract): return "CSO → ISO"
        case (.nsz,         .create):  return "NSP / XCI → NSZ / XCZ"
        case (.nsz,         .extract): return "NSZ / XCZ → NSP / XCI"
        case (.wit,          .create):  return "ISO → WBFS"
        case (.wit,          .extract): return "WBFS → ISO"
        case (.repackinator, .create):  return "ISO → CCI"
        case (.repackinator, .extract): return "CCI → ISO"
        case (.extractXiso,  .create):  return "Xbox Folder → XISO"
        case (.extractXiso,  .extract): return "XISO → Xbox Folder"
        case (.makeps3iso,   .create):  return "PS3 Folder → ISO"
        case (.makeps3iso,   .extract): return "PS3 ISO → Folder"
        default:                        return ""
        }
    }

    // MARK: - Folder row

    @ViewBuilder
    private var folderRow: some View {
        HStack(spacing: 8) {
            // Choose folder button
            Button {
                vm.selectFolder()
            } label: {
                Label("Choose Folder…", systemImage: "folder.badge.plus")
                    .fontWeight(.medium)
            }
            .disabled(vm.isConverting)

            // Folder path chip
            if let folder = vm.selectedFolder {
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.caption)
                    Text(folder.lastPathComponent)
                        .font(.system(.caption, design: .monospaced))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.accentColor.opacity(0.1)))
                .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.5))
                .help(folder.path)
                .lineLimit(1)
                .frame(maxWidth: 260, alignment: .leading)
                .truncationMode(.middle)
            } else {
                Text("No folder selected — drop one here or use Choose Folder")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Recursive
            Toggle(isOn: $vm.isRecursive) {
                Label("Recursive", systemImage: "arrow.trianglehead.2.counterclockwise.rotate.90")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .disabled(vm.isConverting)
            .help("Include subfolders when scanning")

            Divider().frame(height: 18)

            // Scan
            Button {
                Task { await vm.scan() }
            } label: {
                if vm.isScanning {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini)
                        Text("Scanning…")
                    }
                } else {
                    Label("Scan", systemImage: "magnifyingglass")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.canScan)
            .help(scanHelpText)

            // Clear
            Button {
                vm.clearList()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(!vm.canClearList)
            .help("Clear the file list")
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsRow: some View {
        HStack(spacing: 12) {

            // Parallel jobs
            HStack(spacing: 6) {
                Image(systemName: "cpu").foregroundStyle(.secondary).font(.caption)
                Slider(value: Binding(
                    get: { Double(vm.parallelJobs) },
                    set: { vm.parallelJobs = Int($0) }
                ), in: 1...8, step: 1)
                .frame(width: 90)
                .disabled(vm.isConverting)
                Text("\(vm.parallelJobs) job\(vm.parallelJobs == 1 ? "" : "s")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 38, alignment: .leading)
            }
            .help("Parallel conversion jobs — capped at active CPU core count")

            if vm.appMode == .create && vm.selectedTool != .sevenZip {
                Divider().frame(height: 18)
                compressionPresetChip
                    .help(vm.compressionPreset.detail(for: vm.selectedTool))
            }

            Divider().frame(height: 18)

            // Start
            Button {
                Task { await vm.startConversion() }
            } label: {
                Label("Start", systemImage: "play.fill").fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(nsColor: .systemGreen).opacity(0.85))
            .disabled(!vm.canStart)
            .keyboardShortcut("s", modifiers: [.command])

            // Pause / Resume
            if vm.canResume {
                Button { vm.resumeConversion() } label: {
                    Label("Resume", systemImage: "play.fill")
                }
            } else {
                Button { vm.pauseConversion() } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .disabled(!vm.canPause)
            }

            // Cancel
            Button { vm.cancelConversion() } label: {
                Label("Cancel", systemImage: "stop.fill")
            }
            .tint(.red)
            .disabled(!vm.canCancel)
            .keyboardShortcut(".", modifiers: [.command])

            Spacer()

            // chdman capabilities
            if vm.selectedTool == .chdman, let caps = vm.chdmanCapabilities {
                HStack(spacing: 4) {
                    if vm.appMode == .create {
                        capBadge("createcd",  available: caps.hasCreateCD)
                        capBadge("createdvd", available: caps.hasCreateDVD)
                    } else {
                        capBadge("extractcd",  available: caps.hasExtractCD)
                        capBadge("extractdvd", available: caps.hasExtractDVD)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func capBadge(_ label: String, available: Bool) -> some View {
        Text(label)
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(available ? Color.green : Color.secondary)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3)
                .fill(available ? Color.green.opacity(0.12) : Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 3)
                .strokeBorder(available ? Color.green.opacity(0.3) : Color.primary.opacity(0.1),
                              lineWidth: 0.5))
    }

    @ViewBuilder
    private var compressionPresetChip: some View {
        Menu {
            ForEach(CompressionPreset.allCases) { preset in
                Button {
                    vm.compressionPreset = preset
                } label: {
                    HStack {
                        Text(preset.title)
                        if preset == vm.compressionPreset { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "shippingbox.circle").font(.system(size: 10)).foregroundStyle(.secondary)
                Text(vm.compressionPreset.title)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.05)))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(vm.isConverting)
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                ProgressView(value: vm.progress)
                    .progressViewStyle(.linear)
                    .tint(progressTint)
                    .animation(.easeInOut(duration: 0.25), value: vm.progress)
                if let eta = vm.estimatedTimeRemaining {
                    Text("~\(eta) remaining")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                countChip("\(vm.totalCount)",     icon: "tray.full",        tip: "Total",     color: .secondary)
                countChip("\(vm.doneCount)",      icon: "checkmark.circle", tip: "Done",      color: .green)
                countChip("\(vm.failedCount)",    icon: "xmark.circle",     tip: "Failed",    color: .red)
                countChip("\(vm.skippedCount)",   icon: "forward.circle",   tip: "Skipped",   color: .orange)
                countChip("\(vm.cancelledCount)", icon: "stop.circle",      tip: "Cancelled", color: .purple)
            }
        }
    }

    private var progressTint: Color {
        if vm.failedCount > 0 && vm.doneCount == 0 { return .red }
        if vm.failedCount > 0 { return .orange }
        return .accentColor
    }

    @ViewBuilder
    private func countChip(_ value: String, icon: String, tip: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(color == .secondary ? Color.primary : color)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 5)
            .fill(color == .secondary ? Color.primary.opacity(0.05) : color.opacity(0.08)))
        .help(tip)
    }

    // MARK: - Helpers

    private var headerBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Color.primary.opacity(0.015)
        }
    }

    private var scanHelpText: String {
        switch (vm.selectedTool, vm.appMode) {
        case (.chdman,      .create):  return "Scan for ISO, CUE, and GDI files"
        case (.chdman,      .extract): return "Scan for CHD files"
        case (.dolphinTool, .create):  return "Scan for ISO, GCZ, and WIA files"
        case (.dolphinTool, .extract): return "Scan for RVZ, GCZ, and WIA files"
        case (.maxcso,      .create):  return "Scan for ISO files"
        case (.maxcso,      .extract): return "Scan for CSO files"
        case (.nsz,         .create):  return "Scan for NSP and XCI files"
        case (.nsz,         .extract): return "Scan for NSZ and XCZ files"
        case (.sevenZip,    .extract): return "Scan for 7z, ZIP, and RAR archives"
        case (.sevenZip,    .create):  return "7z only supports extraction"
        case (.wit,         .create):  return "Scan for ISO files"
        case (.wit,         .extract): return "Scan for WBFS files"
        case (.repackinator, .create):  return "Scan for Xbox OG ISO files"
        case (.repackinator, .extract): return "Scan for CCI files"
        case (.makeps3iso, .create):    return "Scan for PS3 game folders (containing PS3_GAME/PARAM.SFO)"
        case (.makeps3iso, .extract):   return "Scan for PS3 ISO files"
        case (.extractXiso, .create):   return "Scan for Xbox game folders (containing default.xbe)"
        case (.extractXiso, .extract):  return "Scan for Xbox ISO files"
        }
    }

    @MainActor
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.folder.identifier) {
            _ = provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.folder.identifier) { url, _, _ in
                guard let url else { return }
                Task { @MainActor in
                    vm.selectedFolder = url
                    await vm.scan()
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true) else { return }
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                guard isDir.boolValue else { return }
                Task { @MainActor in
                    vm.selectedFolder = url
                    await vm.scan()
                }
            }
            return true
        }

        return false
    }
}

// MARK: - ToolKind extensions for sidebar

private extension ToolKind {
    var shortDescription: String {
        switch self {
        case .chdman:      return "CD/DVD · PS1, PS2, DC…"
        case .dolphinTool: return "GameCube & Wii"
        case .maxcso:      return "PSP & PS2 ISOs"
        case .nsz:         return "Nintendo Switch"
        case .sevenZip:      return "Extract archives"
        case .wit:           return "Wii/GC · WBFS"
        case .repackinator:  return "Xbox OG · CCI"
        case .makeps3iso:    return "PS3 · Folder ↔ ISO"
        case .extractXiso:   return "Xbox OG · XISO"
        }
    }
}
