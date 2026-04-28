import Foundation

enum DolphinToolLocatorError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "dolphin-tool not found. Install with: npm i -g dolphin-tool\nThen set the native binary path in Settings."
    }
}

/// Finds the dolphin-tool executable — the native Mach-O binary bundled
/// inside the npm `dolphin-tool` package.
///
/// The npm package installs a Node.js wrapper script at the global bin
/// path, but GUI apps can't run that because `node` isn't in their PATH.
/// This locator digs into node_modules to find the actual native binary.
struct DolphinToolLocator {

    // MARK: - Locate

    func locate(customPath: String?) async throws -> String {
        // 1. Custom path from Settings
        if let custom = customPath, !custom.isEmpty {
            if isExecutable(at: custom) { return custom }
        }

        // 2. Search npm global node_modules for the native binary
        if let path = findNativeBinaryInNpmGlobal() {
            return path
        }

        // 3. Try `which` — if it finds the Node wrapper, resolve to the native binary
        if let wrapperPath = await which("dolphin-tool") {
            if let native = resolveNativeBinary(from: wrapperPath) {
                return native
            }
        }

        throw DolphinToolLocatorError.notFound
    }

    // MARK: - Verify

    func verify(path: String) async -> Bool {
        guard let result = try? await runQuiet(executablePath: path, arguments: ["--help"]) else {
            return false
        }
        let combined = result.stdout + result.stderr
        return combined.range(of: "convert", options: .caseInsensitive) != nil
    }

    // MARK: - Native binary resolution

    /// The npm `dolphin-tool` package bundles platform-specific native binaries
    /// under `@emmercm/dolphin-tool-darwin-{arch}/dist/dolphin-tool`.
    /// This searches common npm global prefixes for that binary.
    func findNativeBinaryInNpmGlobal() -> String? {
        let fm = FileManager.default
        let arch = archSuffix()

        // Common npm global lib directories
        var searchRoots: [String] = [
            "/opt/homebrew/lib/node_modules/dolphin-tool",
            "/usr/local/lib/node_modules/dolphin-tool"
        ]

        // nvm installs
        let home = fm.homeDirectoryForCurrentUser.path
        if let nvmDir = findNvmNodeModules(home: home) {
            searchRoots.append(nvmDir)
        }

        // Generic ~/.npm-global
        searchRoots.append("\(home)/.npm-global/lib/node_modules/dolphin-tool")

        // Local project install
        searchRoots.append("\(home)/node_modules/dolphin-tool")

        for root in searchRoots {
            let nativePath = "\(root)/node_modules/@emmercm/dolphin-tool-darwin-\(arch)/dist/dolphin-tool"
            if isExecutable(at: nativePath) { return nativePath }
        }

        return nil
    }

    /// Given the path to the Node.js wrapper script (e.g. `/opt/homebrew/bin/dolphin-tool`),
    /// resolve to the native binary in the sibling node_modules directory.
    private func resolveNativeBinary(from wrapperPath: String) -> String? {
        let url = URL(fileURLWithPath: wrapperPath)
        // Wrapper is at <prefix>/bin/dolphin-tool
        // Native is at <prefix>/lib/node_modules/dolphin-tool/node_modules/@emmercm/dolphin-tool-darwin-{arch}/dist/dolphin-tool
        let prefix = url.deletingLastPathComponent().deletingLastPathComponent().path
        let arch = archSuffix()
        let nativePath = "\(prefix)/lib/node_modules/dolphin-tool/node_modules/@emmercm/dolphin-tool-darwin-\(arch)/dist/dolphin-tool"
        if isExecutable(at: nativePath) { return nativePath }
        return nil
    }

    /// Find nvm's current node version's global node_modules
    private func findNvmNodeModules(home: String) -> String? {
        let nvmDir = "\(home)/.nvm/versions/node"
        let fm = FileManager.default
        guard let versions = try? fm.contentsOfDirectory(atPath: nvmDir) else { return nil }
        // Sort descending to prefer newest version
        for version in versions.sorted().reversed() {
            let path = "\(nvmDir)/\(version)/lib/node_modules/dolphin-tool"
            if fm.fileExists(atPath: path) { return path }
        }
        return nil
    }

    private func archSuffix() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x64"
        #endif
    }

    // MARK: - Helpers

    private func isExecutable(at path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    private func which(_ tool: String) async -> String? {
        guard let result = try? await runQuiet(executablePath: "/usr/bin/which", arguments: [tool]),
              result.exitCode == 0
        else { return nil }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private func runQuiet(executablePath: String, arguments: [String]) async throws
        -> (exitCode: Int32, stdout: String, stderr: String)
    {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError  = errPipe

            try process.run()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            let stdout = String(data: outData, encoding: .utf8) ?? ""
            let stderr = String(data: errData, encoding: .utf8) ?? ""
            return (process.terminationStatus, stdout, stderr)
        }.value
    }
}
