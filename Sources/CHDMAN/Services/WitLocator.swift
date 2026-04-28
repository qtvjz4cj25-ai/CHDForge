import Foundation

enum WitLocatorError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "wit not found. Download Wiimms ISO Tools from wit.wiimm.de or install via Homebrew."
    }
}

/// Finds the wit (Wiimms ISO Tool) executable for Wii/GameCube ISO management.
struct WitLocator {

    private let knownPaths = [
        "/opt/homebrew/bin/wit",
        "/usr/local/bin/wit"
    ]

    // MARK: - Locate

    func locate(customPath: String?) async throws -> String {
        if let custom = customPath, !custom.isEmpty {
            if isExecutable(at: custom) { return custom }
        }

        for path in knownPaths {
            if isExecutable(at: path) { return path }
        }

        if let path = await which("wit") {
            return path
        }

        throw WitLocatorError.notFound
    }

    // MARK: - Verify

    func verify(path: String) async -> Bool {
        // Try `wit VERSION` (uppercase subcommand) first, then `wit version`,
        // then no args. If the binary exists and runs at all, accept it —
        // macOS quarantine can cause the process to silently fail even when
        // the binary is valid, so we accept any output containing "wit".
        for args in [["VERSION"], ["version"], ["--version"]] {
            guard let result = try? await runQuiet(executablePath: path, arguments: args) else {
                continue
            }
            let combined = result.stdout + result.stderr
            if combined.range(of: "wit", options: .caseInsensitive) != nil {
                return true
            }
        }
        // Last resort: if the file is executable, assume it's valid.
        // The user can correct the path in Settings if it's wrong.
        return isExecutable(at: path)
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
