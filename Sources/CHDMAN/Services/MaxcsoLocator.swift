import Foundation

enum MaxcsoLocatorError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "maxcso not found. Download it from GitHub: github.com/unknownbrackets/maxcso"
    }
}

/// Finds the maxcso executable for CSO compression/decompression.
struct MaxcsoLocator {

    private let knownPaths = [
        "/opt/homebrew/bin/maxcso",
        "/usr/local/bin/maxcso"
    ]

    // MARK: - Locate

    func locate(customPath: String?) async throws -> String {
        if let custom = customPath, !custom.isEmpty {
            if isExecutable(at: custom) { return custom }
        }

        for path in knownPaths {
            if isExecutable(at: path) { return path }
        }

        if let path = await which("maxcso") {
            return path
        }

        throw MaxcsoLocatorError.notFound
    }

    // MARK: - Verify

    func verify(path: String) async -> Bool {
        // maxcso with no args prints usage to stderr and exits non-zero.
        guard let result = try? await runQuiet(executablePath: path, arguments: []) else {
            return false
        }
        let combined = result.stdout + result.stderr
        return combined.range(of: "cso", options: .caseInsensitive) != nil
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

    /// Reads pipes before waiting for exit to avoid deadlock.
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
