import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var chdmanDraftPath: String = ""
    @State private var dolphinToolDraftPath: String = ""
    @State private var maxcsoDraftPath: String = ""
    @State private var nszDraftPath: String = ""
    @State private var sevenZipDraftPath: String = ""
    @State private var witDraftPath: String = ""
    @State private var repackinatorDraftPath: String = ""
    @State private var makePs3IsoDraftPath: String = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tool Setup Wizard")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Check which tools are installed and install any that are missing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        vm.showSetupWizard = true
                    } label: {
                        Label("Open Wizard", systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 2)
            } header: {
                Label("Quick Setup", systemImage: "sparkles")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom chdman path")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Leave blank to auto-detect: Homebrew → /usr/local/bin → PATH")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("/opt/homebrew/bin/chdman", text: $chdmanDraftPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            panel.message = "Select the chdman executable"
                            if panel.runModal() == .OK, let url = panel.url {
                                chdmanDraftPath = url.path
                            }
                        }
                    }

                    HStack {
                        Button("Save") {
                            vm.customChdmanPath = chdmanDraftPath
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Clear") {
                            chdmanDraftPath = ""
                            vm.customChdmanPath = ""
                        }

                        Spacer()

                        if !vm.customChdmanPath.isEmpty {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("Auto-detect active", systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("chdman Executable", systemImage: "wrench.and.screwdriver")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom dolphin-tool path")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Leave blank to auto-detect the native binary inside npm's node_modules")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("Auto-detected from npm node_modules", text: $dolphinToolDraftPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            panel.message = "Select the dolphin-tool executable"
                            if panel.runModal() == .OK, let url = panel.url {
                                dolphinToolDraftPath = url.path
                            }
                        }
                    }

                    HStack {
                        Button("Save") {
                            vm.customDolphinToolPath = dolphinToolDraftPath
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Clear") {
                            dolphinToolDraftPath = ""
                            vm.customDolphinToolPath = ""
                        }

                        Spacer()

                        if !vm.customDolphinToolPath.isEmpty {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("Auto-detect active", systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("dolphin-tool Executable", systemImage: "gamecontroller")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom maxcso path")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Leave blank to auto-detect: Homebrew → /usr/local/bin → PATH")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("/opt/homebrew/bin/maxcso", text: $maxcsoDraftPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            panel.message = "Select the maxcso executable"
                            if panel.runModal() == .OK, let url = panel.url {
                                maxcsoDraftPath = url.path
                            }
                        }
                    }

                    HStack {
                        Button("Save") {
                            vm.customMaxcsoPath = maxcsoDraftPath
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Clear") {
                            maxcsoDraftPath = ""
                            vm.customMaxcsoPath = ""
                        }

                        Spacer()

                        if !vm.customMaxcsoPath.isEmpty {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("Auto-detect active", systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("maxcso Executable", systemImage: "externaldrive")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom nsz path")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Leave blank to auto-detect: pip install location → PATH")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("~/.local/bin/nsz", text: $nszDraftPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            panel.message = "Select the nsz executable"
                            if panel.runModal() == .OK, let url = panel.url {
                                nszDraftPath = url.path
                            }
                        }
                    }

                    HStack {
                        Button("Save") {
                            vm.customNszPath = nszDraftPath
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Clear") {
                            nszDraftPath = ""
                            vm.customNszPath = ""
                        }

                        Spacer()

                        if !vm.customNszPath.isEmpty {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("Auto-detect active", systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("nsz Executable", systemImage: "rectangle.stack")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom wit path")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Leave blank to auto-detect: Homebrew → /usr/local/bin → PATH")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("/opt/homebrew/bin/wit", text: $witDraftPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            panel.message = "Select the wit executable"
                            if panel.runModal() == .OK, let url = panel.url {
                                witDraftPath = url.path
                            }
                        }
                    }

                    HStack {
                        Button("Save") {
                            vm.customWitPath = witDraftPath
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Clear") {
                            witDraftPath = ""
                            vm.customWitPath = ""
                        }

                        Spacer()

                        if !vm.customWitPath.isEmpty {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("Auto-detect active", systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("wit Executable", systemImage: "opticaldisc.fill")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom 7z path")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Leave blank to auto-detect: Homebrew → /usr/local/bin → PATH")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("/opt/homebrew/bin/7z", text: $sevenZipDraftPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            panel.message = "Select the 7z executable"
                            if panel.runModal() == .OK, let url = panel.url {
                                sevenZipDraftPath = url.path
                            }
                        }
                    }

                    HStack {
                        Button("Save") {
                            vm.customSevenZipPath = sevenZipDraftPath
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Clear") {
                            sevenZipDraftPath = ""
                            vm.customSevenZipPath = ""
                        }

                        Spacer()

                        if !vm.customSevenZipPath.isEmpty {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("Auto-detect active", systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("7z Executable", systemImage: "doc.zipper")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom Repackinator path")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Leave blank to auto-detect. Set to the repackinator.shell binary inside the extracted tar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("~/Applications/Repackinator/repackinator.shell", text: $repackinatorDraftPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            panel.message = "Select the repackinator.shell executable"
                            if panel.runModal() == .OK, let url = panel.url {
                                repackinatorDraftPath = url.path
                            }
                        }
                    }

                    HStack {
                        Button("Save") {
                            vm.customRepackinatorPath = repackinatorDraftPath
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Clear") {
                            repackinatorDraftPath = ""
                            vm.customRepackinatorPath = ""
                        }

                        Spacer()

                        if !vm.customRepackinatorPath.isEmpty {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("Auto-detect active", systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("Repackinator Executable", systemImage: "xmark.seal.fill")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom makeps3iso path")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Leave blank to auto-detect: ~/bin → ~/.local/bin → PATH. Set to the extracted binary from the ps3iso-utils tar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("~/bin/makeps3iso", text: $makePs3IsoDraftPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            panel.message = "Select the makeps3iso executable"
                            if panel.runModal() == .OK, let url = panel.url {
                                makePs3IsoDraftPath = url.path
                            }
                        }
                    }

                    HStack {
                        Button("Save") {
                            vm.customMakePs3IsoPath = makePs3IsoDraftPath
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Clear") {
                            makePs3IsoDraftPath = ""
                            vm.customMakePs3IsoPath = ""
                        }

                        Spacer()

                        if !vm.customMakePs3IsoPath.isEmpty {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("Auto-detect active", systemImage: "magnifyingglass")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("makeps3iso Executable (PS3)", systemImage: "circle.grid.2x2.fill")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ScreenScraper Account")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Optional but recommended — free accounts get higher API rate limits. Register at screenscraper.fr.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        TextField("Username", text: $vm.ssUsername)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $vm.ssPassword)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Button("Register Free Account") {
                            if let url = URL(string: "https://www.screenscraper.fr/membreinscription.php") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button {
                            vm.showArtworkScraper = true
                        } label: {
                            Label("Open Scraper", systemImage: "photo.badge.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Label("Artwork Scraper", systemImage: "photo.on.rectangle")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Compression preset")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text("Choose whether to favor shorter conversions or smaller output files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Compression preset", selection: Binding(
                        get: { vm.compressionPreset },
                        set: { vm.compressionPreset = $0 }
                    )) {
                        ForEach(CompressionPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(vm.compressionPreset.detail(for: vm.selectedTool))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(isOn: $vm.deleteSourceAfterConversion) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Delete source files after conversion")
                                .font(.system(.body, design: .rounded).weight(.semibold))
                            Text("Removes the original source files after a successful conversion")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $vm.notifyOnCompletion) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Notify when batch completes")
                                .font(.system(.body, design: .rounded).weight(.semibold))
                            Text("Send a macOS notification when all jobs finish")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Label("Conversion Options", systemImage: "slider.horizontal.3")
            }

            Section {
                if let caps = vm.chdmanCapabilities {
                    VStack(alignment: .leading, spacing: 8) {
                        capRow("createcd", available: caps.hasCreateCD, note: "CUE/BIN, GDI, and ISO fallback")
                        capRow("createdvd", available: caps.hasCreateDVD, note: "Preferred for ISO disc images")
                    }
                } else {
                    Text("Run a chdman conversion to detect capabilities.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Detected Capabilities", systemImage: "cpu")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Option 1 — Homebrew (recommended)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Requires Homebrew, the macOS package manager. If you don't have it, install it first from brew.sh.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Button {
                            if let url = URL(string: "https://brew.sh") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Get Homebrew", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    HStack {
                        Text("brew install rom-tools")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew install rom-tools", forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy to clipboard")
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )

                    Divider()

                    Text("Option 2 — Download from MAME")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Download MAME, which includes chdman, then use Browse above to set the path.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        if let url = URL(string: "https://www.mamedev.org/release.html") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Open MAME Downloads", systemImage: "arrow.up.right.square")
                    }

                    Divider()

                    Text("dolphin-tool (RVZ conversion)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Install via npm. The app auto-detects the native binary inside node_modules.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("npm i -g dolphin-tool")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("npm i -g dolphin-tool", forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy to clipboard")
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )

                    Divider()

                    Text("maxcso (CSO compression)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Download from GitHub, place the binary in your PATH or set the path in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        if let url = URL(string: "https://github.com/unknownbrackets/maxcso/releases") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Download maxcso", systemImage: "arrow.up.right.square")
                    }

                    Divider()

                    Text("wit (Wiimms ISO Tools — Wii/GameCube)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Download from the official site or check if available via Homebrew.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        if let url = URL(string: "https://wit.wiimm.de/download.html") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Download wit", systemImage: "arrow.up.right.square")
                    }

                    Divider()

                    Text("7z (archive extraction)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("brew install p7zip")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew install p7zip", forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy to clipboard")
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )

                    Divider()

                    Text("nsz (Nintendo Switch compression)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("pip3 install nsz")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("pip3 install nsz", forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy to clipboard")
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                }
            } header: {
                Label("Installation", systemImage: "terminal")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 540, height: 800)
        .onAppear {
            chdmanDraftPath = vm.customChdmanPath
            dolphinToolDraftPath = vm.customDolphinToolPath
            maxcsoDraftPath = vm.customMaxcsoPath
            nszDraftPath = vm.customNszPath
            sevenZipDraftPath = vm.customSevenZipPath
            witDraftPath = vm.customWitPath
            repackinatorDraftPath = vm.customRepackinatorPath
            makePs3IsoDraftPath = vm.customMakePs3IsoPath
        }
    }

    @ViewBuilder
    private func capRow(_ command: String, available: Bool, note: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(available ? Color.green : Color.red)
            Text(command)
                .font(.system(.body, design: .monospaced).weight(.semibold))
            Text("·")
                .foregroundStyle(.tertiary)
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
