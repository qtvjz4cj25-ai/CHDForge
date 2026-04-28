import Foundation

/// Orchestrates 7z archive extraction jobs. Inherits concurrency framework,
/// pause/resume/cancel, and shared boilerplate from BatchEngine.
final class SevenZipEngine: BatchEngine {

    let sevenZipPath: String

    init(
        sevenZipPath: String,
        concurrency: Int,
        jobs: [ConversionJob],
        logStore: LogStore,
        deleteSource: Bool = false
    ) {
        self.sevenZipPath = sevenZipPath
        super.init(concurrency: concurrency, jobs: jobs, logStore: logStore, deleteSource: deleteSource)
    }

    // MARK: - Override: convert

    override func convert(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        let args = buildArgs(snapshot: snapshot)

        guard let r = await runTool(
            executablePath: sevenZipPath,
            job: job,
            snapshot: snapshot,
            args: args
        ) else { return false }

        guard r.succeeded else {
            if wasCancelled() { return false }
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — 7z extraction failed."
            await setJob(job, status: .failed, detail: "Extraction failed", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        // Verify the output directory exists and contains files
        guard outputDirValid(snapshot.outputPath) else {
            if wasCancelled() { return false }
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — output directory empty or missing."
            await setJob(job, status: .failed, detail: "No files extracted", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        return true
    }

    // MARK: - Helpers

    private func buildArgs(snapshot: JobSnapshot) -> [String] {
        // 7z x archive.7z -oOutputDir -y
        // -y = assume Yes on all queries (overwrite prompts)
        // Note: no space between -o and the path
        ["x", snapshot.path, "-o\(snapshot.outputPath)", "-y"]
    }

    /// Checks that the output directory exists and is non-empty.
    private func outputDirValid(_ path: String) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        let contents = (try? fm.contentsOfDirectory(atPath: path)) ?? []
        return !contents.isEmpty
    }
}
