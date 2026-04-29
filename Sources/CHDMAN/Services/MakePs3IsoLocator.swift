import Foundation

enum MakePs3IsoLocatorError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "makeps3iso not found. Download from github.com/bucanero/ps3iso-utils/releases and set the path in Settings."
    }
}

/// Finds the makeps3iso executable from ps3iso-utils.
/// Distributed as a manual download (tar archive from GitHub).
/// The extracted binary is named `makeps3iso`.
struct MakePs3IsoLocator {

    private let knownPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/bin/makeps3iso",
            "\(home)/.local/bin/makeps3iso",
            "\(home)/Applications/ps3iso-utils/makeps3iso",
            "\(home)/Applications/makeps3iso/makeps3iso",
            "/usr/local/bin/makeps3iso",
            "/opt/homebrew/bin/makeps3iso",
        ]
    }()

    // MARK: - Locate

    func locate(customPath: String?) async throws -> String {
        if let custom = customPath, !custom.isEmpty {
            if fileExists(at: custom) { return custom }
        }

        for path in knownPaths {
            if isExecutable(at: path) { return path }
        }

        if let path = await which("makeps3iso") { return path }

        throw MakePs3IsoLocatorError.notFound
    }

    // MARK: - Verify

    func verify(path: String) async -> Bool {
        // makeps3iso prints usage when run with no args or --help
        if let result = try? await runQuiet(executablePath: path, arguments: []) {
            let combined = result.stdout + result.stderr
            if combined.range(of: "ps3", options: .caseInsensitive) != nil { return true }
            if combined.range(of: "iso", options: .caseInsensitive) != nil { return true }
        }
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
