import Foundation

enum NszLocatorError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "nsz not found. Install it with: pip3 install nsz"
    }
}

/// Finds the nsz executable for Nintendo Switch NSP/XCI compression.
struct NszLocator {

    private let knownPaths = [
        "/opt/homebrew/bin/nsz",
        "/usr/local/bin/nsz"
    ]

    // MARK: - Locate

    func locate(customPath: String?) async throws -> String {
        if let custom = customPath, !custom.isEmpty {
            if isExecutable(at: custom) { return custom }
        }

        for path in knownPaths {
            if isExecutable(at: path) { return path }
        }

        // pip user install (~/.local/bin/nsz)
        let pipUserPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/nsz").path
        if isExecutable(at: pipUserPath) { return pipUserPath }

        // macOS pip user install (~/Library/Python/3.x/bin/)
        let libDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Python")
        if let pythonVersions = try? FileManager.default.contentsOfDirectory(
            at: libDir, includingPropertiesForKeys: nil
        ) {
            for dir in pythonVersions.sorted(by: { $0.path > $1.path }) {
                let candidate = dir.appendingPathComponent("bin/nsz").path
                if isExecutable(at: candidate) { return candidate }
            }
        }

        if let path = await which("nsz") {
            return path
        }

        throw NszLocatorError.notFound
    }

    // MARK: - Verify

    func verify(path: String) async -> Bool {
        guard let result = try? await runQuiet(executablePath: path, arguments: ["--help"]) else {
            return false
        }
        let combined = result.stdout + result.stderr
        return combined.range(of: "compress", options: .caseInsensitive) != nil
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
