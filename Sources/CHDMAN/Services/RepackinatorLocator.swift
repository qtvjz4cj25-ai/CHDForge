import Foundation

enum RepackinatorLocatorError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "Repackinator not found. Download from github.com/Team-Resurgent/Repackinator/releases and set the path in Settings."
    }
}

/// Finds the Repackinator executable for Original Xbox ISO/CCI conversion.
/// Repackinator is distributed as a manual download (tar archive from GitHub).
/// The macOS binary inside the tar is simply named `repackinator`.
struct RepackinatorLocator {

    private let knownPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Applications/Repackinator/repackinator",
            "\(home)/Applications/Repackinator/repackinator.shell",
            "\(home)/Applications/Repackinator/Repackinator.Shell",
            "/usr/local/bin/repackinator",
            "/usr/local/bin/repackinator.shell",
            "/opt/homebrew/bin/repackinator",
        ]
    }()

    // MARK: - Locate

    func locate(customPath: String?) async throws -> String {
        if let custom = customPath, !custom.isEmpty {
            // Trust the user-provided path if the file exists at all.
            // Downloaded .NET binaries may lack the execute bit until chmod'd,
            // and quarantined files still exist on disk.
            if fileExists(at: custom) { return custom }
        }

        for path in knownPaths {
            if isExecutable(at: path) { return path }
        }

        for name in ["repackinator", "repackinator.shell"] {
            if let path = await which(name) { return path }
        }

        throw RepackinatorLocatorError.notFound
    }

    // MARK: - Verify

    func verify(path: String) async -> Bool {
        // Try running -h; accept any output that looks like Repackinator.
        if let result = try? await runQuiet(executablePath: path, arguments: ["-h"]) {
            let combined = (result.stdout + result.stderr).lowercased()
            if combined.contains("repackinator") || combined.contains("action") || combined.contains("convert") {
                return true
            }
        }
        // Fall back to existence check — the file is there, trust the user.
        return fileExists(at: path)
    }

    // MARK: - Helpers

    func isExecutable(at path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    func fileExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
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
