import Foundation

enum ExtractPs3IsoLocatorError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "extractps3iso not found. Download ps3iso-utils from github.com/bucanero/ps3iso-utils/releases and set the path in Settings."
    }
}

/// Finds the extractps3iso executable from ps3iso-utils.
/// Distributed in the same package as makeps3iso — both binaries live in the same folder.
struct ExtractPs3IsoLocator {

    private let knownPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/bin/extractps3iso",
            "\(home)/.local/bin/extractps3iso",
            "\(home)/Applications/ps3iso-utils/extractps3iso",
            "\(home)/Applications/makeps3iso/extractps3iso",
            "/usr/local/bin/extractps3iso",
            "/opt/homebrew/bin/extractps3iso",
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

        if let path = await which("extractps3iso") { return path }

        throw ExtractPs3IsoLocatorError.notFound
    }

    // MARK: - Verify

    func verify(path: String) async -> Bool {
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
