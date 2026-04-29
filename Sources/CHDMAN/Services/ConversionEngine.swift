import Foundation

// MARK: - ConversionEngine

/// Orchestrates chdman conversion jobs. Inherits concurrency framework,
/// pause/resume/cancel, and shared boilerplate from BatchEngine.
final class ConversionEngine: BatchEngine {

    let chdmanPath: String
    let capabilities: ChdmanCapabilities
    let compressionPreset: CompressionPreset

    init(
        chdmanPath: String,
        capabilities: ChdmanCapabilities,
        compressionPreset: CompressionPreset,
        concurrency: Int,
        jobs: [ConversionJob],
        logStore: LogStore,
        deleteSource: Bool = false
    ) {
        self.chdmanPath = chdmanPath
        self.capabilities = capabilities
        self.compressionPreset = compressionPreset
        super.init(concurrency: concurrency, jobs: jobs, logStore: logStore, deleteSource: deleteSource)
    }

    // MARK: - Override: convert

    override func convert(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        switch snapshot.sourceType {
        case .iso: return await convertISO(job, snapshot: snapshot)
        case .cue: return await convertCUE(job, snapshot: snapshot)
        case .gdi: return await convertGDI(job, snapshot: snapshot)
        case .chd: return await extractCHD(job, snapshot: snapshot)
        case .gcz, .rvz, .wia, .cso, .nsp, .xci, .nsz, .xcz, .sevenZ, .zip, .rar, .wbfs, .cci, .ps3dir:
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — unsupported source type for chdman."
            await setJob(job, status: .failed, detail: "Unsupported source type", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }
    }

    // MARK: - Override: cleanupSource

    override func cleanupSource(_ snapshot: JobSnapshot) {
        switch snapshot.sourceType {
        case .cue:
            if let refs = try? CueParser().referencedFiles(cueURL: snapshot.sourceURL) {
                safeDelete(snapshot.sourceURL)
                refs.forEach { safeDelete($0) }
            }
        case .gdi:
            if let refs = try? GdiParser().referencedFiles(gdiURL: snapshot.sourceURL) {
                safeDelete(snapshot.sourceURL)
                refs.forEach { safeDelete($0) }
            }
        default:
            super.cleanupSource(snapshot)
        }
    }

    // MARK: - ISO conversion

    private func convertISO(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        // Attempt 1: createdvd (preferred for ISOs)
        if capabilities.hasCreateDVD {
            if let r = await runChdman(job: job, snapshot: snapshot, args: commandArgs(command: "createdvd", inputPath: snapshot.path, outputPath: snapshot.outputPath)),
               r.succeeded, outputValid(snapshot.outputPath) {
                return true
            }
            if wasCancelled() { return false }
            removeInvalidOutput(snapshot.outputPath)

            if !capabilities.hasCreateCD {
                let msg = "[\(ts())] [FAIL] \(snapshot.filename) — createdvd failed and createcd unavailable."
                await setJob(job, status: .failed, detail: "createdvd failed", log: msg)
                emit(msg)
                Task { await logStore.appendGlobal(msg) }
                return false
            }

            let retryMsg = "[\(ts())] [RETRY] \(snapshot.filename) — createdvd failed, trying createcd."
            await appendLog(job, text: retryMsg + "\n")
            emit(retryMsg)
            Task { await logStore.appendGlobal(retryMsg) }
        }

        // Attempt 2: createcd
        if capabilities.hasCreateCD {
            if let r = await runChdman(job: job, snapshot: snapshot, args: commandArgs(command: "createcd", inputPath: snapshot.path, outputPath: snapshot.outputPath)),
               r.succeeded, outputValid(snapshot.outputPath) {
                return true
            }
            if wasCancelled() { return false }
            removeInvalidOutput(snapshot.outputPath)
        }

        if wasCancelled() { return false }
        let failMsg = "[\(ts())] [FAIL] \(snapshot.filename) — all conversion attempts failed."
        await setJob(job, status: .failed, detail: "All attempts failed", log: failMsg)
        emit(failMsg)
        Task { await logStore.appendGlobal(failMsg) }
        return false
    }

    // MARK: - CUE conversion

    private func convertCUE(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        guard capabilities.hasCreateCD else {
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — createcd not available in this chdman build."
            await setJob(job, status: .failed, detail: "createcd unavailable", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        guard let r = await runChdman(job: job, snapshot: snapshot, args: commandArgs(command: "createcd", inputPath: snapshot.path, outputPath: snapshot.outputPath)),
              r.succeeded, outputValid(snapshot.outputPath) else {
            removeInvalidOutput(snapshot.outputPath)
            if wasCancelled() { return false }
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — createcd failed."
            await setJob(job, status: .failed, detail: "createcd failed", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        return true
    }

    // MARK: - GDI conversion

    private func convertGDI(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        guard capabilities.hasCreateCD else {
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — createcd not available in this chdman build."
            await setJob(job, status: .failed, detail: "createcd unavailable", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        guard let r = await runChdman(job: job, snapshot: snapshot, args: commandArgs(command: "createcd", inputPath: snapshot.path, outputPath: snapshot.outputPath)),
              r.succeeded, outputValid(snapshot.outputPath) else {
            removeInvalidOutput(snapshot.outputPath)
            if wasCancelled() { return false }
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — createcd failed."
            await setJob(job, status: .failed, detail: "createcd failed", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return false
        }

        return true
    }

    // MARK: - CHD extraction

    private func extractCHD(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        // Try extractcd first (covers CD-based CHDs: CUE/BIN, GDI)
        if capabilities.hasExtractCD {
            if let r = await runChdman(job: job, snapshot: snapshot, args: ["extractcd", "-i", snapshot.path, "-o", snapshot.outputPath]),
               r.succeeded, outputValid(snapshot.outputPath) {
                return true
            }
            if wasCancelled() { return false }
            removeInvalidOutput(snapshot.outputPath)

            if !capabilities.hasExtractDVD {
                let msg = "[\(ts())] [FAIL] \(snapshot.filename) — extractcd failed and extractdvd unavailable."
                await setJob(job, status: .failed, detail: "extractcd failed", log: msg)
                emit(msg)
                Task { await logStore.appendGlobal(msg) }
                return false
            }

            let retryMsg = "[\(ts())] [RETRY] \(snapshot.filename) — extractcd failed, trying extractdvd."
            await appendLog(job, text: retryMsg + "\n")
            emit(retryMsg)
            Task { await logStore.appendGlobal(retryMsg) }
        }

        // Try extractdvd (covers DVD/ISO-based CHDs)
        if capabilities.hasExtractDVD {
            let isoOutput = snapshot.outputPath.replacingOccurrences(of: ".bin", with: ".iso")
            if let r = await runChdman(job: job, snapshot: snapshot, args: ["extractdvd", "-i", snapshot.path, "-o", isoOutput]),
               r.succeeded, outputValid(isoOutput) {
                return true
            }
            if wasCancelled() { return false }
            removeInvalidOutput(isoOutput)
        }

        if wasCancelled() { return false }
        let failMsg = "[\(ts())] [FAIL] \(snapshot.filename) — all extraction attempts failed."
        await setJob(job, status: .failed, detail: "All attempts failed", log: failMsg)
        emit(failMsg)
        Task { await logStore.appendGlobal(failMsg) }
        return false
    }

    // MARK: - Helpers

    private func runChdman(job: ConversionJob, snapshot: JobSnapshot, args: [String]) async -> ProcessResult? {
        await runTool(executablePath: chdmanPath, job: job, snapshot: snapshot, args: args)
    }

    private func commandArgs(command: String, inputPath: String, outputPath: String) -> [String] {
        [command, "-i", inputPath, "-o", outputPath] + compressionPreset.chdmanArguments(for: command)
    }
}
