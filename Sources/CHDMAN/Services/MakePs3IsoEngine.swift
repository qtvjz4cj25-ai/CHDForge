import Foundation

/// Converts between PS3 game folders and PS3 ISO images using ps3iso-utils.
///
/// Create:  PS3 game folder (contains PS3_GAME/PARAM.SFO) → PS3 ISO
///   Command: makeps3iso <source_folder> <output.iso>
///
/// Extract: PS3 ISO → PS3 game folder
///   Command: extractps3iso <source.iso> <output_folder>
final class MakePs3IsoEngine: BatchEngine {

    let makeps3isoPath: String
    let extractps3isoPath: String
    let mode: AppMode

    init(
        makeps3isoPath: String,
        extractps3isoPath: String,
        mode: AppMode,
        concurrency: Int,
        jobs: [ConversionJob],
        logStore: LogStore,
        deleteSource: Bool = false
    ) {
        self.makeps3isoPath = makeps3isoPath
        self.extractps3isoPath = extractps3isoPath
        self.mode = mode
        super.init(concurrency: concurrency, jobs: jobs, logStore: logStore, deleteSource: deleteSource)
    }

    // MARK: - Ensure executable

    private func ensureExecutable() {
        let fm = FileManager.default
        for path in [makeps3isoPath, extractps3isoPath] {
            guard fm.fileExists(atPath: path),
                  !fm.isExecutableFile(atPath: path) else { continue }
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        }
    }

    // MARK: - Override: convert

    override func convert(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        ensureExecutable()

        switch mode {
        case .create:
            return await runCreate(job: job, snapshot: snapshot)
        case .extract:
            return await runExtract(job: job, snapshot: snapshot)
        }
    }

    // MARK: - Create (folder → ISO)

    private func runCreate(job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        let args = [snapshot.path, snapshot.outputPath]

        guard let r = await runTool(
            executablePath: makeps3isoPath,
            job: job,
            snapshot: snapshot,
            args: args
        ) else { return false }

        guard r.succeeded, outputValid(snapshot.outputPath) else {
            removeInvalidOutput(snapshot.outputPath)
            if wasCancelled() { return false }
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — makeps3iso failed."
            await setJob(job, status: .failed, detail: "Conversion failed", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        return true
    }

    // MARK: - Extract (ISO → folder)

    private func runExtract(job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        // Create output directory first
        try? FileManager.default.createDirectory(
            atPath: snapshot.outputPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let args = [snapshot.path, snapshot.outputPath]

        guard let r = await runTool(
            executablePath: extractps3isoPath,
            job: job,
            snapshot: snapshot,
            args: args
        ) else { return false }

        guard r.succeeded, outputDirValid(snapshot.outputPath) else {
            try? FileManager.default.removeItem(atPath: snapshot.outputPath)
            if wasCancelled() { return false }
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — extractps3iso failed."
            await setJob(job, status: .failed, detail: "Conversion failed", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        return true
    }

    // MARK: - Output validation for extract (directory)

    private func outputDirValid(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir),
              isDir.boolValue else { return false }
        return !((try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []).isEmpty
    }

    // MARK: - Cleanup

    override func cleanupSource(_ snapshot: JobSnapshot) {
        // Both create (directory) and extract (file) sources are deleted the same way
        safeDelete(snapshot.sourceURL)
    }
}
