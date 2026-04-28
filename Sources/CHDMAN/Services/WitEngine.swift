import Foundation

/// Orchestrates wit (Wiimms ISO Tool) conversion jobs for Wii/GameCube images.
/// Converts between ISO and WBFS formats.
final class WitEngine: BatchEngine {

    let witPath: String
    let compressionPreset: CompressionPreset
    let mode: AppMode

    init(
        witPath: String,
        compressionPreset: CompressionPreset,
        mode: AppMode,
        concurrency: Int,
        jobs: [ConversionJob],
        logStore: LogStore,
        deleteSource: Bool = false
    ) {
        self.witPath = witPath
        self.compressionPreset = compressionPreset
        self.mode = mode
        super.init(concurrency: concurrency, jobs: jobs, logStore: logStore, deleteSource: deleteSource)
    }

    // MARK: - Override: convert

    override func convert(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        let args = buildArgs(snapshot: snapshot)

        guard let r = await runTool(
            executablePath: witPath,
            job: job,
            snapshot: snapshot,
            args: args
        ) else { return false }

        guard r.succeeded, outputValid(snapshot.outputPath) else {
            removeInvalidOutput(snapshot.outputPath)
            if wasCancelled() { return false }
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — wit conversion failed."
            await setJob(job, status: .failed, detail: "Conversion failed", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        return true
    }

    // MARK: - Build arguments

    private func buildArgs(snapshot: JobSnapshot) -> [String] {
        // wit COPY source dest [options]
        var args = ["copy", snapshot.path, snapshot.outputPath]

        switch mode {
        case .create:
            args.append("--wbfs")
            args += compressionPreset.witArguments
        case .extract:
            args.append("--iso")
        }

        return args
    }
}
