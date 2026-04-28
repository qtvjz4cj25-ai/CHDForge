import SwiftUI
import AppKit

// MARK: - Tool setup metadata

private struct ToolSetupInfo: Identifiable {
    let id: ToolKind
    let name: String
    let subtitle: String
    let installMethod: InstallMethod

    enum InstallMethod {
        case brew(package: String)
        case npm(package: String)
        case pip(package: String)
        case manual(url: String, hint: String)
    }

    var isScriptable: Bool {
        switch installMethod {
        case .brew, .npm, .pip: return true
        case .manual:           return false
        }
    }
}

private let allTools: [ToolSetupInfo] = [
    .init(id: .chdman,
          name: "chdman",
          subtitle: "CHD for CD/DVD — PS1, PS2, Dreamcast, Saturn",
          installMethod: .brew(package: "rom-tools")),
    .init(id: .dolphinTool,
          name: "dolphin-tool",
          subtitle: "RVZ for GameCube & Wii",
          installMethod: .npm(package: "dolphin-tool")),
    .init(id: .maxcso,
          name: "maxcso",
          subtitle: "CSO for PSP & PS2 — download required",
          installMethod: .manual(
            url: "https://github.com/unknownbrackets/maxcso/releases",
            hint: "Download the macOS binary, then set the path in Settings.")),
    .init(id: .nsz,
          name: "nsz",
          subtitle: "NSZ/XCZ for Nintendo Switch",
          installMethod: .pip(package: "nsz")),
    .init(id: .wit,
          name: "wit",
          subtitle: "WBFS for Wii/GameCube — download required",
          installMethod: .manual(
            url: "https://wit.wiimm.de/download.html",
            hint: "Extract, then run: sudo ./install.sh")),
    .init(id: .sevenZip,
          name: "7z",
          subtitle: "Extract 7Z, ZIP, and RAR archives",
          installMethod: .brew(package: "p7zip")),
    .init(id: .repackinator,
          name: "Repackinator",
          subtitle: "CCI for Original Xbox — download required",
          installMethod: .manual(
            url: "https://github.com/Team-Resurgent/Repackinator/releases/latest",
            hint: "Download the osx-arm64 or osx-x64 tar, extract, then set the path in Settings.")),
]

// MARK: - Tool status

private enum ToolStatus: Equatable {
    case checking
    case found(path: String)
    case missing
    case installing
    case installed
    case failed(String)
    case requiresNode   // dolphin-tool: node missing
}

// MARK: - SetupWizardView

struct SetupWizardView: View {
    var onDismiss: () -> Void = {}
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false

    @State private var statuses: [ToolKind: ToolStatus] = Dictionary(
        uniqueKeysWithValues: ToolKind.allCases.map { ($0, .checking) }
    )
    @State private var logs: [ToolKind: String] = [:]
    @State private var expandedLog: ToolKind? = nil
    @State private var isCheckingAll = false

    var body: some View {
        VStack(spacing: 0) {

            // Header
            VStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
                Text("Welcome to CHDForge")
                    .font(.title2.weight(.bold))
                Text("Let's check which tools are installed and install any that are missing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.horizontal, 32)
            .padding(.bottom, 20)

            Divider()

            // Tool list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(allTools) { tool in
                        ToolRow(
                            tool: tool,
                            status: statuses[tool.id] ?? .checking,
                            log: logs[tool.id] ?? "",
                            isExpanded: expandedLog == tool.id,
                            onToggleLog: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedLog = expandedLog == tool.id ? nil : tool.id
                                }
                            },
                            onInstall: { await install(tool: tool) },
                            onOpenURL: { openURL(tool.installMethod) }
                        )
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .frame(minHeight: 280)

            Divider()

            // Footer buttons
            HStack(spacing: 10) {
                // Install all missing (scriptable) tools
                let missingScriptable = allTools.filter {
                    tool in tool.isScriptable && (statuses[tool.id] == .missing)
                }

                if !missingScriptable.isEmpty {
                    Button {
                        Task {
                            for tool in missingScriptable {
                                await install(tool: tool)
                            }
                        }
                    } label: {
                        Label("Install All Missing", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnyInstalling)
                }

                Spacer()

                Button("Continue") {
                    hasCompletedSetup = true
                    onDismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding(16)
        }
        .frame(width: 520)
        .task { await checkAll() }
    }

    // MARK: - Check all tools

    private func checkAll() async {
        isCheckingAll = true
        await withTaskGroup(of: Void.self) { group in
            for tool in allTools {
                group.addTask { await check(tool: tool) }
            }
        }
        isCheckingAll = false
    }

    private func check(tool: ToolSetupInfo) async {
        await setStatus(.checking, for: tool.id)

        switch tool.installMethod {
        case .brew(let pkg):
            let bin = findBrew()
            guard let brew = bin else {
                await setStatus(.missing, for: tool.id)
                return
            }
            // Check if the installed package provides the binary
            let toolBin = resolvedBinaryPath(for: tool.id)
            if let p = toolBin, FileManager.default.isExecutableFile(atPath: p) {
                await setStatus(.found(path: p), for: tool.id)
            } else if let p = await which(tool.id.rawValue) {
                await setStatus(.found(path: p), for: tool.id)
            } else {
                _ = brew // brew exists but package not installed
                await setStatus(.missing, for: tool.id)
            }

        case .npm(let pkg):
            _ = pkg
            // Check for node first
            guard findNode() != nil else {
                await setStatus(.requiresNode, for: tool.id)
                return
            }
            if let path = DolphinToolLocator().findNativeBinary() {
                await setStatus(.found(path: path), for: tool.id)
            } else if let p = await which("dolphin-tool") {
                await setStatus(.found(path: p), for: tool.id)
            } else {
                await setStatus(.missing, for: tool.id)
            }

        case .pip(let pkg):
            _ = pkg
            if let p = resolvedBinaryPath(for: tool.id),
               FileManager.default.isExecutableFile(atPath: p) {
                await setStatus(.found(path: p), for: tool.id)
            } else if let p = await which("nsz") {
                await setStatus(.found(path: p), for: tool.id)
            } else {
                await setStatus(.missing, for: tool.id)
            }

        case .manual:
            if let p = resolvedBinaryPath(for: tool.id),
               FileManager.default.isExecutableFile(atPath: p) {
                await setStatus(.found(path: p), for: tool.id)
            } else if let p = await which(tool.id.rawValue) {
                await setStatus(.found(path: p), for: tool.id)
            } else {
                await setStatus(.missing, for: tool.id)
            }
        }
    }

    // MARK: - Install

    private func install(tool: ToolSetupInfo) async {
        await setStatus(.installing, for: tool.id)
        await appendLog("", for: tool.id)

        let (executable, arguments): (String, [String])

        switch tool.installMethod {
        case .brew(let pkg):
            guard let brew = findBrew() else {
                await setStatus(.failed("Homebrew not found. Install from brew.sh first."), for: tool.id)
                return
            }
            (executable, arguments) = (brew, ["install", pkg])

        case .npm(let pkg):
            guard let npm = findNode().flatMap({ _ in findNpm() }) else {
                await setStatus(.failed("Node.js not found. Install from nodejs.org or:\nbrew install node"), for: tool.id)
                return
            }
            (executable, arguments) = (npm, ["install", "-g", pkg])

        case .pip(let pkg):
            guard let pip = findPip() else {
                await setStatus(.failed("pip3 not found. Install Python from python.org or:\nbrew install python"), for: tool.id)
                return
            }
            (executable, arguments) = (pip, ["install", pkg])

        case .manual:
            return
        }

        let result = await runInstall(
            executable: executable,
            arguments: arguments,
            tool: tool.id
        )

        if result {
            await check(tool: tool)
            if case .found = statuses[tool.id] {
                await setStatus(.installed, for: tool.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    Task { await self.check(tool: tool) }
                }
            }
        } else {
            if case .installing = statuses[tool.id] {
                await setStatus(.failed("Installation failed — see log below."), for: tool.id)
            }
        }
    }

    private func runInstall(executable: String, arguments: [String], tool: ToolKind) async -> Bool {
        await withCheckedContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                // Provide a reasonable PATH so package managers can find their deps
                process.environment = [
                    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
                    "HOME": FileManager.default.homeDirectoryForCurrentUser.path
                ]

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError  = errPipe

                outPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                    Task { @MainActor in self.logs[tool, default: ""] += text }
                }
                errPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                    Task { @MainActor in self.logs[tool, default: ""] += text }
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    Task { @MainActor in self.logs[tool, default: ""] += "Error: \(error.localizedDescription)\n" }
                    continuation.resume(returning: false)
                }
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func setStatus(_ s: ToolStatus, for id: ToolKind) {
        statuses[id] = s
    }

    @MainActor
    private func appendLog(_ text: String, for id: ToolKind) {
        logs[id] = text
    }

    private var isAnyInstalling: Bool {
        statuses.values.contains(.installing)
    }

    private func openURL(_ method: ToolSetupInfo.InstallMethod) {
        if case .manual(let url, _) = method,
           let u = URL(string: url) {
            NSWorkspace.shared.open(u)
        }
    }

    private func findBrew() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func findNode() -> String? {
        ["/opt/homebrew/bin/node", "/usr/local/bin/node"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func findNpm() -> String? {
        ["/opt/homebrew/bin/npm", "/usr/local/bin/npm"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func findPip() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/usr/bin/pip3",
            "/opt/homebrew/bin/pip3",
            "/usr/local/bin/pip3",
            "\(home)/.local/bin/pip3"
        ].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Known install paths for each tool — quick check before shelling out to `which`.
    private func resolvedBinaryPath(for tool: ToolKind) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch tool {
        case .chdman:
            return ["/opt/homebrew/bin/chdman", "/usr/local/bin/chdman"]
                .first { FileManager.default.isExecutableFile(atPath: $0) }
        case .dolphinTool:
            return DolphinToolLocator().findNativeBinary()
        case .maxcso:
            return ["/opt/homebrew/bin/maxcso", "/usr/local/bin/maxcso"]
                .first { FileManager.default.isExecutableFile(atPath: $0) }
        case .nsz:
            return [
                "\(home)/.local/bin/nsz",
                "/opt/homebrew/bin/nsz",
                "/usr/local/bin/nsz"
            ].first { FileManager.default.isExecutableFile(atPath: $0) }
        case .sevenZip:
            return ["/opt/homebrew/bin/7z", "/usr/local/bin/7z",
                    "/opt/homebrew/bin/7zz", "/usr/local/bin/7zz"]
                .first { FileManager.default.isExecutableFile(atPath: $0) }
        case .wit:
            return ["/usr/local/bin/wit", "/opt/homebrew/bin/wit"]
                .first { FileManager.default.isExecutableFile(atPath: $0) }
        case .repackinator:
            return [
                "\(home)/Applications/Repackinator/repackinator",
                "\(home)/Applications/Repackinator/repackinator.shell",
                "/usr/local/bin/repackinator",
            ].first { FileManager.default.fileExists(atPath: $0) }
        }
    }

    private func which(_ name: String) async -> String? {
        try? await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            p.arguments = [name]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError  = Pipe()
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }
            let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return str?.isEmpty == false ? str : nil
        }.value
    }
}

// MARK: - ToolRow

private struct ToolRow: View {
    let tool: ToolSetupInfo
    let status: ToolStatus
    let log: String
    let isExpanded: Bool
    let onToggleLog: () -> Void
    let onInstall: () async -> Void
    let onOpenURL: () -> Void

    @State private var isInstalling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Status icon
                statusIcon
                    .frame(width: 28, height: 28)

                // Name + subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                    Text(tool.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Action button
                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            // Expandable log
            if isExpanded && !log.isEmpty {
                ScrollView {
                    Text(log)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 100)
                .background(Color.black.opacity(0.04))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .checking:
            ProgressView().controlSize(.small)
        case .found:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        case .installed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        case .missing, .requiresNode:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
        case .installing:
            ProgressView().controlSize(.small)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.title3)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .checking:
            EmptyView()

        case .found(let path):
            Text(URL(fileURLWithPath: path).lastPathComponent)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

        case .installed:
            Text("Installed")
                .font(.caption)
                .foregroundStyle(.green)

        case .missing:
            if tool.isScriptable {
                Button {
                    isInstalling = true
                    Task {
                        await onInstall()
                        isInstalling = false
                    }
                } label: {
                    Label("Install", systemImage: "arrow.down.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isInstalling)
            } else {
                Button {
                    onOpenURL()
                } label: {
                    Label("Get it", systemImage: "arrow.up.right.square")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(manualHint)
            }

        case .requiresNode:
            VStack(alignment: .trailing, spacing: 4) {
                Text("Requires Node.js")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("Install Node.js") {
                    NSWorkspace.shared.open(URL(string: "https://nodejs.org")!)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Button {
                    onToggleLog()
                } label: {
                    Text(isExpanded ? "Hide log" : "Show log")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

        case .failed(let msg):
            VStack(alignment: .trailing, spacing: 4) {
                Text("Failed")
                    .font(.caption)
                    .foregroundStyle(.red)
                if !log.isEmpty {
                    Button(isExpanded ? "Hide log" : "Show log") {
                        onToggleLog()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                } else {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 180)
                }
            }
        }
    }

    private var manualHint: String {
        if case .manual(_, let hint) = tool.installMethod { return hint }
        return ""
    }
}

// MARK: - DolphinToolLocator bridge

// Expose the native binary finder for use in the setup wizard.
extension DolphinToolLocator {
    func findNativeBinary() -> String? {
        findNativeBinaryInNpmGlobal()
    }
}
