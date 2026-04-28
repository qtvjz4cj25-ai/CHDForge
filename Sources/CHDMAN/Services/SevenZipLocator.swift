import Foundation

enum SevenZipLocatorError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "7z not found. Install via Homebrew: brew install p7zip (or brew install 7zip)"
    }
}

/// Finds the 7z executable for archive extraction.
struct SevenZipLocator {

    private let knownPaths = [
        "/opt/homebrew/bin/7z",
        "/opt/homebrew/bin/7zz",
        "/usr/local/bin/7z",
        "/usr/local/bin/7zz"
    ]

    // MARK: - Locate

    func locate(customPath: String?) async throws -> String {
        if let custom = customPath, !custom.isEmpty {
            if isExecutable(at: custom) { return custom }
        }

        for path in knownPaths {
            if isExecutable(at: path) { return path }
        }

        // Try `which` for both common binary names
        for name in ["7z", "7zz"] {
            if let path = await which(name) {
                return path
            }
        }

        throw SevenZipLocatorError.notFound
    }

    // MARK: - Verify

    func verify(path: String) async -> Bool {
        // 7z with no args prints banner/help and exits with code 0.
        guard let result = try? await runQuiet(executablePath: path, arguments: []) else {
            return false
        }
        let combined = result.stdout + result.stderr
        return combined.range(of: "7-Zip", options: .caseInsensitive) != nil
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
