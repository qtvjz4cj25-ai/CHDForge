import Foundation

/// Orchestrates maxcso conversion jobs (ISO ↔ CSO). Inherits concurrency
/// framework, pause/resume/cancel, and shared boilerplate from BatchEngine.
final class MaxcsoEngine: BatchEngine {

    let maxcsoPath: String
    let compressionPreset: CompressionPreset
    let mode: AppMode

    init(
        maxcsoPath: String,
        compressionPreset: CompressionPreset,
        mode: AppMode,
        concurrency: Int,
        jobs: [ConversionJob],
        logStore: LogStore,
        deleteSource: Bool = false
    ) {
        self.maxcsoPath = maxcsoPath
        self.compressionPreset = compressionPreset
        self.mode = mode
        super.init(concurrency: concurrency, jobs: jobs, logStore: logStore, deleteSource: deleteSource)
    }

    // MARK: - Override: convert

    override func convert(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        let args = buildArgs(snapshot: snapshot)

        if let r = await runTool(executablePath: maxcsoPath, job: job, snapshot: snapshot, args: args),
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
        // maxcso [options] input -o output
        var args: [String] = []

        switch mode {
        case .extract:
            args.append("--decompress")
        case .create:
            args += compressionPreset.maxcsoArguments
        }

        // Limit to 1 thread per process; our engine handles parallelism.
        args += ["--threads=1", snapshot.path, "-o", snapshot.outputPath]
        return args
    }
}
