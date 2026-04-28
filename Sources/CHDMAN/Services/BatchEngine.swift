import Foundation

// MARK: - Concurrency primitives

/// A Swift-concurrency semaphore: limits the number of concurrently running tasks.
actor AsyncSemaphore {
    private var slots: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(_ count: Int) { slots = max(1, count) }

    func wait() async {
        if slots > 0 {
            slots -= 1
        } else {
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    func signal() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            slots += 1
        }
    }
}

/// Tracks whether the engine is paused; jobs await entry into this gate before
/// starting.  Running jobs are not affected by pause.
actor PauseGate {
    private var paused = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func setPaused(_ value: Bool) {
        paused = value
        if !value { drainContinuations() }
    }

    func waitIfPaused() async {
        guard paused else { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    private func drainContinuations() {
        let waiting = continuations
        continuations = []
        waiting.forEach { $0.resume() }
    }

    /// Drain all waiters unconditionally (used on cancel).
    func drainAll() {
        paused = false
        drainContinuations()
    }
}

/// Tracks which child processes are alive so we can kill them on cancel.
/// Uses NSLock for synchronous registration from process callbacks, avoiding
/// the race where a fire-and-forget Task could register after termination.
final class ProcessRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [UUID: Process] = [:]
    private var _cancelled = false

    var cancelled: Bool {
        lock.withLock { _cancelled }
    }

    func register(_ proc: Process, id: UUID) {
        lock.withLock { entries[id] = proc }
    }

    func unregister(id: UUID) {
        lock.withLock { _ = entries.removeValue(forKey: id) }
    }

    /// Mark cancelled, returns the live processes to terminate.
    func cancel() -> [Process] {
        lock.withLock {
            _cancelled = true
            let procs = Array(entries.values)
            entries = [:]
            return procs
        }
    }
}

// MARK: - JobSnapshot

/// A Sendable snapshot of a ConversionJob's state, captured on the MainActor
/// before handing off to background conversion work.
struct JobSnapshot: Sendable {
    let job: ConversionJob
    let sourceURL: URL
    let sourceType: SourceType
    let status: JobStatus
    let filename: String
    let path: String
    let outputPath: String
}

// MARK: - BatchEngine

/// Base class for conversion engines. Provides the concurrency framework
/// (bounded parallelism, pause/resume, cancel) and shared job processing
/// boilerplate. Subclasses override `convert(_:snapshot:)` and optionally
/// `cleanupSource(_:)`.
class BatchEngine: @unchecked Sendable {

    let concurrency: Int
    let jobs: [ConversionJob]
    let logStore: LogStore
    let deleteSource: Bool

    /// Called on every log line so the view model can append it to the global log.
    var onLogLine: ((String) -> Void)?

    // Concurrency primitives
    let sema: AsyncSemaphore
    let gate = PauseGate()
    let registry = ProcessRegistry()

    init(concurrency: Int, jobs: [ConversionJob], logStore: LogStore, deleteSource: Bool) {
        self.concurrency = max(1, concurrency)
        self.jobs = jobs
        self.logStore = logStore
        self.deleteSource = deleteSource
        self.sema = AsyncSemaphore(max(1, concurrency))
    }

    // MARK: - External controls (callable synchronously from @MainActor)

    func pause()  { Task { await gate.setPaused(true)  } }
    func resume() { Task { await gate.setPaused(false) } }

    func cancel() {
        let procs = registry.cancel()
        procs.forEach { $0.terminate() }
        Task { await gate.drainAll() }
    }

    // MARK: - Main run loop

    func run() async {
        let pending = await pendingJobs()

        await withTaskGroup(of: Void.self) { group in
            for snap in pending {
                if registry.cancelled { break }

                await sema.wait()

                if registry.cancelled {
                    await sema.signal()
                    break
                }

                await gate.waitIfPaused()

                if registry.cancelled {
                    await sema.signal()
                    break
                }

                group.addTask { [weak self] in
                    guard let self else { return }
                    defer { Task { await self.sema.signal() } }
                    await self.processJob(snap.job, snapshot: snap)
                }
            }
            await group.waitForAll()
        }

        if registry.cancelled {
            for job in await cancellableJobs() {
                await setJobStatus(job, status: .cancelled, detail: "Cancelled")
            }
        }
    }

    // MARK: - Per-job processing (shared boilerplate)

    private func processJob(_ job: ConversionJob, snapshot: JobSnapshot) async {
        let fm = FileManager.default

        // Already-done check
        if fm.fileExists(atPath: snapshot.outputPath) {
            let size = (try? fm.attributesOfItem(atPath: snapshot.outputPath))?[.size] as? Int ?? 0
            if size > 0 {
                let msg = "[\(ts())] [SKIP] \(snapshot.filename) — output already exists."
                await setJob(job, status: .skipped, detail: "Output exists", log: msg)
                emit(msg)
                Task { await logStore.appendGlobal(msg) }
                return
            }
            try? fm.removeItem(atPath: snapshot.outputPath)
        }

        // Source existence check
        guard fm.fileExists(atPath: snapshot.path) else {
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — source file missing."
            await setJob(job, status: .failed, detail: "Source missing", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return
        }

        let startMsg = "[\(ts())] [START] \(snapshot.filename)"
        await setJob(job, status: .converting, detail: "Converting…", log: startMsg)
        emit(startMsg)
        Task { await logStore.appendGlobal(startMsg) }

        // Delegate to subclass
        let succeeded = await convert(job, snapshot: snapshot)

        if succeeded {
            let okMsg = "[\(ts())] [OK] \(snapshot.filename)"
            await setJob(job, status: .done, detail: "Done", log: okMsg)
            emit(okMsg)
            Task { await logStore.appendGlobal(okMsg) }

            if deleteSource {
                cleanupSource(snapshot)
            }
        }
    }

    // MARK: - Subclass override points

    /// Perform the actual conversion. Return `true` on success, `false` on failure.
    /// On failure, subclasses should set job status and log the error themselves.
    func convert(_ job: ConversionJob, snapshot: JobSnapshot) async -> Bool {
        fatalError("Subclasses must override convert(_:snapshot:)")
    }

    /// Delete source files after a successful conversion. Override for formats
    /// that reference multiple files (e.g. CUE+BIN, GDI+tracks).
    func cleanupSource(_ snapshot: JobSnapshot) {
        safeDelete(snapshot.sourceURL)
    }

    // MARK: - Shared process runner

    func runTool(
        executablePath: String,
        job: ConversionJob,
        snapshot: JobSnapshot,
        args: [String]
    ) async -> ProcessResult? {
        let runner = ProcessRunner()
        let procID = UUID()

        do {
            let result = try await runner.run(
                executablePath: executablePath,
                arguments: args,
                lineHandler: { [weak self] line in
                    guard let self else { return }
                    await self.appendLog(job, text: line + "\n")
                },
                willLaunch: { [weak self] proc in
                    self?.registry.register(proc, id: procID)
                },
                processEnded: { [weak self] in
                    self?.registry.unregister(id: procID)
                }
            )
            if wasCancelled() {
                await markCancelled(job, snapshot: snapshot)
                return nil
            }
            return result
        } catch is CancellationError {
            await markCancelled(job, snapshot: snapshot)
            return nil
        } catch {
            let msg = "[\(ts())] [FAIL] \(snapshot.filename) — launch error: \(error.localizedDescription)"
            await setJob(job, status: .failed, detail: "Launch error", log: msg)
            emit(msg)
            Task { await logStore.appendGlobal(msg) }
            return nil
        }
    }

    // MARK: - Job state helpers

    func setJob(_ job: ConversionJob, status: JobStatus, detail: String, log text: String) async {
        await MainActor.run {
            job.status = status
            job.detail = detail
            job.appendLog(text + "\n")
        }
    }

    func setJobStatus(_ job: ConversionJob, status: JobStatus, detail: String) async {
        await MainActor.run {
            job.status = status
            job.detail = detail
        }
    }

    func appendLog(_ job: ConversionJob, text: String) async {
        await MainActor.run { job.appendLog(text) }
    }

    func markCancelled(_ job: ConversionJob, snapshot: JobSnapshot) async {
        let msg = "[\(ts())] [CANCEL] \(snapshot.filename)"
        await setJob(job, status: .cancelled, detail: "Cancelled", log: msg)
        emit(msg)
        Task { await logStore.appendGlobal(msg) }
    }

    func wasCancelled() -> Bool {
        registry.cancelled
    }

    // MARK: - File helpers

    func outputValid(_ path: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return false }
        let size = (try? fm.attributesOfItem(atPath: path))?[.size] as? Int ?? 0
        return size > 0
    }

    func removeInvalidOutput(_ path: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return }
        let size = (try? fm.attributesOfItem(atPath: path))?[.size] as? Int ?? 0
        if size == 0 { try? fm.removeItem(atPath: path) }
    }

    func safeDelete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Log forwarding

    func emit(_ line: String) {
        onLogLine?(line)
    }

    func ts() -> String {
        DateFormatter.timestamp.string(from: Date())
    }

    // MARK: - Snapshot helpers

    @MainActor
    private func snapshot(for job: ConversionJob) -> JobSnapshot {
        JobSnapshot(
            job: job,
            sourceURL: job.sourceURL,
            sourceType: job.sourceType,
            status: job.status,
            filename: job.filename,
            path: job.path,
            outputPath: job.outputPath
        )
    }

    private func pendingJobs() async -> [JobSnapshot] {
        await MainActor.run {
            jobs.map(snapshot(for:)).filter { $0.status == .pending }
        }
    }

    private func cancellableJobs() async -> [ConversionJob] {
        await MainActor.run {
            jobs.filter { $0.status == .pending || $0.status == .paused }
        }
    }
}
