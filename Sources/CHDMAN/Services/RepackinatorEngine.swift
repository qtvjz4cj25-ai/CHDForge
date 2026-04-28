import Foundation

/// Orchestrates Repackinator conversion jobs for Original Xbox disc images.
/// Converts between ISO and CCI (Cerbios Compressed Image) formats.
final class RepackinatorEngine: BatchEngine {

    let repackinatorPath: String
    let compressionPreset: CompressionPreset
    let mode: AppMode

    init(
        repackinatorPath: String,
        compressionPreset: CompressionPreset,
        mode: AppMode,
        concurrency: Int,
        jobs: [ConversionJob],
        logStore: LogStore,
        deleteSource: Bool = false
    ) {
        self.repackinatorPath = repackinatorPath
        self.compressionPreset = compressionPreset
        self.mode = mode
        super.init(concurrency: concurrency, jobs: jobs, logStore: logStore, deleteSource: deleteSource)
    }

    // MARK: - Ensure executable

    /// Repackinator binaries downloaded from GitHub may lack the execute bit.
    /// Attempt to set it before running the first job.
    private func ensureExecutable() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: repackinatorPath),
              !fm.isExecutableFile(atPath: repackinatorPath) else { return }
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: repackinatorPath)
    }

    // MARK: - Override: convert

    override func convert(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        ensureExecutable()
        let args = buildArgs(snapshot: snapshot)

        guard let r = await runTool(
            executablePath: repackinatorPath,
            job: job,
            snapshot: snapshot,
            args: args
        ) else { return false }

        guard r.succeeded, outputValid(snapshot.outputPath) else {
            removeInvalidOutput(snapshot.outputPath)
            if wasCancelled() { return false }
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — Repackinator conversion failed."
            await setJob(job, status: .failed, detail: "Conversion failed", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        return true
    }

    // MARK: - Build arguments

    private func buildArgs(snapshot: JobSnapshot) -> [String] {
        // repackinator.shell -a=convert -i=<source> -o=<output> -n [options]
        var args = ["-a=convert", "-i=\(snapshot.path)", "-o=\(snapshot.outputPath)", "-n"]

        switch mode {
        case .create:
            // ISO → CCI: add compress flag plus preset scrub options
            args.append("-c")
            args += compressionPreset.repackinatorArguments
        case .extract:
            // CCI → ISO: no -c flag, no scrub needed
            break
        }

        return args
    }
}
