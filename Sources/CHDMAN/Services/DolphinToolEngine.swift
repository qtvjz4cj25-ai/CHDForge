import Foundation

/// Orchestrates DolphinTool conversion jobs. Inherits concurrency framework,
/// pause/resume/cancel, and shared boilerplate from BatchEngine.
final class DolphinToolEngine: BatchEngine {

    let dolphinToolPath: String
    let compressionPreset: CompressionPreset
    let mode: AppMode

    init(
        dolphinToolPath: String,
        compressionPreset: CompressionPreset,
        mode: AppMode,
        concurrency: Int,
        jobs: [ConversionJob],
        logStore: LogStore,
        deleteSource: Bool = false
    ) {
        self.dolphinToolPath = dolphinToolPath
        self.compressionPreset = compressionPreset
        self.mode = mode
        super.init(concurrency: concurrency, jobs: jobs, logStore: logStore, deleteSource: deleteSource)
    }

    // MARK: - Override: convert

    override func convert(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        let args = buildArgs(snapshot: snapshot)

        if let r = await runTool(executablePath: dolphinToolPath, job: job, snapshot: snapshot, args: args),
           r.succeeded, outputValid(snapshot.outputPath) {
            return true
        }
        removeInvalidOutput(snapshot.outputPath)
        if wasCancelled() { return false }

        let failMsg = "[\(ts())] [FAIL] \(snapshot.filename) — conversion failed."
        await setJob(job, status: .failed, detail: "Conversion failed", log: failMsg)
        emit(failMsg)
        Task { await logStore.appendGlobal(failMsg) }
        return false
    }

    // MARK: - Build arguments

    private func buildArgs(snapshot: JobSnapshot) -> [String] {
        var args = ["convert", "-i", snapshot.path, "-o", snapshot.outputPath]

        switch mode {
        case .create:
            args += ["-f", "rvz"]
            args += compressionPreset.dolphinToolArguments
        case .extract:
            args += ["-f", "iso"]
        }

        return args
    }
}
