import Foundation

// MARK: - ProcessResult

struct ProcessResult: Sendable {
    let exitCode: Int32
    let stdout:   String
    let stderr:   String

    var succeeded: Bool { exitCode == 0 }
    var combinedOutput: String { stdout + (stderr.isEmpty ? "" : "\n[stderr]\n" + stderr) }
}

// MARK: - ProcessRunner

/// Runs a child process and streams its output line-by-line via an async callback.
/// Supports cooperative cancellation: if the enclosing Task is cancelled the
/// child process receives SIGTERM.
struct ProcessRunner {

    /// Run a process, calling `lineHandler` for every chunk of text produced.
    /// - Parameters:
    ///   - willLaunch: Called with the Process *before* it is started, so callers
    ///     can register it synchronously (e.g. in a ProcessRegistry).
    ///   - processEnded: Called after the process terminates.
    /// - Returns: The exit code and full captured output after the process exits.
    func run(
        executablePath: String,
        arguments: [String],
        lineHandler: @escaping (String) async -> Void,
        willLaunch: @escaping (Process) -> Void = { _ in },
        processEnded: @Sendable @escaping () -> Void = {}
    ) async throws -> ProcessResult {

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments     = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError  = errPipe

        // Thread-safe accumulator for captured output. Uses a serial dispatch
        // queue to prevent data races between readabilityHandler callbacks
        // and the terminationHandler draining tail bytes.
        final class Accumulator: @unchecked Sendable {
            private let queue = DispatchQueue(label: "processrunner.accumulator")
            private var _stdout = ""
            private var _stderr = ""

            func appendStdout(_ text: String) { queue.sync { _stdout += text } }
            func appendStderr(_ text: String) { queue.sync { _stderr += text } }
            var stdout: String { queue.sync { _stdout } }
            var stderr: String { queue.sync { _stderr } }
        }
        let acc = Accumulator()

        // AsyncStream to bridge pipe callbacks → async for-in loop.
        let (stream, continuation) = AsyncStream<String>.makeStream(
            bufferingPolicy: .unbounded
        )

        // stdout
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8)
            else { return }
            acc.appendStdout(text)
            continuation.yield(text)
        }

        // stderr
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8)
            else { return }
            acc.appendStderr(text)
            continuation.yield("[stderr] " + text)
        }

        // Termination: read any tail bytes, then close the stream.
        process.terminationHandler = { proc in
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil

            // Drain any bytes buffered before the handler fired.
            let tailOut = outPipe.fileHandleForReading.readDataToEndOfFile()
            let tailErr = errPipe.fileHandleForReading.readDataToEndOfFile()

            if let t = String(data: tailOut, encoding: .utf8), !t.isEmpty {
                acc.appendStdout(t)
                continuation.yield(t)
            }
            if let t = String(data: tailErr, encoding: .utf8), !t.isEmpty {
                acc.appendStderr(t)
                continuation.yield("[stderr] " + t)
            }
            continuation.finish()
            processEnded()
        }

        // withTaskCancellationHandler ensures the child is killed if our Task
        // is cancelled before it exits normally.
        return try await withTaskCancellationHandler {
            // Bail immediately if already cancelled before we even launch.
            try Task.checkCancellation()

            // Register the process before launch so cancel() can always find it.
            willLaunch(process)
            try process.run()

            // Drain the stream, forwarding each chunk to the caller.
            for await chunk in stream {
                // Forward to UI / log, breaking on long lines.
                let lines = chunk.components(separatedBy: "\n")
                for line in lines where !line.isEmpty {
                    await lineHandler(line)
                }
            }

            // The terminationHandler has already called continuation.finish(),
            // so the for-in loop above has exited.  The process is done.
            try Task.checkCancellation()

            return ProcessResult(
                exitCode: process.terminationStatus,
                stdout:   acc.stdout,
                stderr:   acc.stderr
            )
        } onCancel: {
            process.terminate()
        }
    }
}
