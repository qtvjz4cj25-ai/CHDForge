import Foundation

/// Converts PS3 JB game folders to ISO using makeps3iso from ps3iso-utils.
/// Source: a PS3 game folder containing PS3_GAME/PARAM.SFO
/// Output: a standard PS3 ISO file
final class MakePs3IsoEngine: BatchEngine {

    let makeps3isoPath: String

    init(
        makeps3isoPath: String,
        concurrency: Int,
        jobs: [ConversionJob],
        logStore: LogStore,
        deleteSource: Bool = false
    ) {
        self.makeps3isoPath = makeps3isoPath
        super.init(concurrency: concurrency, jobs: jobs, logStore: logStore, deleteSource: deleteSource)
    }

    // MARK: - Ensure executable

    private func ensureExecutable() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: makeps3isoPath),
              !fm.isExecutableFile(atPath: makeps3isoPath) else { return }
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: makeps3isoPath)
    }

    // MARK: - Override: convert

    override func convert(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        ensureExecutable()

        // makeps3iso <source_folder> <output_iso>
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
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — makeps3iso conversion failed."
            await setJob(job, status: .failed, detail: "Conversion failed", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        return true
    }

    // MARK: - Cleanup: delete the entire source directory

    override func cleanupSource(_ snapshot: JobSnapshot) {
        // The source is a directory — safeDelete handles directories via removeItem(at:)
        safeDelete(snapshot.sourceURL)
    }
}
