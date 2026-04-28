import Foundation

/// Orchestrates nsz conversion jobs (NSP/XCI ↔ NSZ/XCZ). Inherits concurrency
/// framework, pause/resume/cancel, and shared boilerplate from BatchEngine.
///
/// nsz uses `-o` for the output *directory* (not file), so we extract the
/// parent directory from the snapshot's outputPath.
final class NszEngine: BatchEngine {

    let nszPath: String
    let compressionPreset: CompressionPreset
    let mode: AppMode

    init(
        nszPath: String,
        compressionPreset: CompressionPreset,
        mode: AppMode,
        concurrency: Int,
        jobs: [ConversionJob],
        logStore: LogStore,
        deleteSource: Bool = false
    ) {
        self.nszPath = nszPath
        self.compressionPreset = compressionPreset
        self.mode = mode
        super.init(concurrency: concurrency, jobs: jobs, logStore: logStore, deleteSource: deleteSource)
    }

    // MARK: - Override: convert

    override func convert(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        let args = buildArgs(snapshot: snapshot)

        if let r = await runTool(executablePath: nszPath, job: job, snapshot: snapshot, args: args),
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
        // nsz -C|-D [-l LEVEL] [-t THREADS] -o OUTPUT_DIR input
        let outputDir = URL(fileURLWithPath: snapshot.outputPath)
            .deletingLastPathComponent().path

        var args: [String] = []

        switch mode {
        case .create:
            args.append("-C")
            args += compressionPreset.nszArguments
        case .extract:
            args.append("-D")
        }

        args += ["-t", "1", "-o", outputDir, snapshot.path]
        return args
    }
}
