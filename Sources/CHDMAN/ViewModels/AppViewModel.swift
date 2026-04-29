import Foundation
import SwiftUI
import AppKit

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - UI state

    @Published var selectedFolder: URL?
    @Published var selectedTool: ToolKind = .chdman
    @Published var appMode: AppMode = .create
    @Published var isRecursive: Bool = true
    @Published var jobs: [ConversionJob] = []
    @Published var parallelJobs: Int = 2
    @Published var isScanning: Bool = false
    @Published var isConverting: Bool = false
    @Published var isPaused: Bool = false
    @Published var isCancelling: Bool = false
    @Published var globalLog: String = ""
    @Published var autoScrollLog: Bool = true
    @Published var conversionStartDate: Date?
    @Published var showChdmanAlert: Bool = false
    @Published var chdmanAlertMessage: String = ""
    @Published var chdmanMissing: Bool = false
    @Published var showDolphinToolAlert: Bool = false
    @Published var dolphinToolAlertMessage: String = ""
    @Published var dolphinToolMissing: Bool = false
    @Published var showMaxcsoAlert: Bool = false
    @Published var maxcsoAlertMessage: String = ""
    @Published var maxcsoMissing: Bool = false
    @Published var showNszAlert: Bool = false
    @Published var nszAlertMessage: String = ""
    @Published var nszMissing: Bool = false
    @Published var showSevenZipAlert: Bool = false
    @Published var sevenZipAlertMessage: String = ""
    @Published var sevenZipMissing: Bool = false
    @Published var showWitAlert: Bool = false
    @Published var witAlertMessage: String = ""
    @Published var witMissing: Bool = false
    @Published var showRepackinatorAlert: Bool = false
    @Published var repackinatorAlertMessage: String = ""
    @Published var repackinatorMissing: Bool = false
    @Published var showMakePs3IsoAlert: Bool = false
    @Published var makePs3IsoAlertMessage: String = ""
    @Published var makePs3IsoMissing: Bool = false
    @Published var showExtractXisoAlert: Bool = false
    @Published var extractXisoAlertMessage: String = ""
    @Published var extractXisoMissing: Bool = false
    @Published var chdmanCapabilities: ChdmanCapabilities?

    // MARK: - Persisted settings

    @AppStorage("hasCompletedSetup") var hasCompletedSetup: Bool = false
    @Published var showSetupWizard: Bool = false
    @Published var showArtworkScraper: Bool = false

    // MARK: - ScreenScraper credentials
    @AppStorage("ssUsername") var ssUsername: String = ""
    @AppStorage("ssPassword") var ssPassword: String = ""

    @AppStorage("customChdmanPath") var customChdmanPath: String = ""
    @AppStorage("customDolphinToolPath") var customDolphinToolPath: String = ""
    @AppStorage("customMaxcsoPath") var customMaxcsoPath: String = ""
    @AppStorage("customNszPath") var customNszPath: String = ""
    @AppStorage("customSevenZipPath") var customSevenZipPath: String = ""
    @AppStorage("customWitPath") var customWitPath: String = ""
    @AppStorage("customRepackinatorPath") var customRepackinatorPath: String = ""
    @AppStorage("customMakePs3IsoPath") var customMakePs3IsoPath: String = ""
    @AppStorage("customExtractPs3IsoPath") var customExtractPs3IsoPath: String = ""
    @AppStorage("customExtractXisoPath") var customExtractXisoPath: String = ""
    @AppStorage("deleteSourceAfterConversion") var deleteSourceAfterConversion: Bool = false
    @AppStorage("notifyOnCompletion") var notifyOnCompletion: Bool = true
    @AppStorage("compressionPreset") private var compressionPresetRawValue: String = CompressionPreset.balanced.rawValue

    var compressionPreset: CompressionPreset {
        get { CompressionPreset(rawValue: compressionPresetRawValue) ?? .balanced }
        set { compressionPresetRawValue = newValue.rawValue }
    }

    // MARK: - Computed counts / progress

    var totalCount: Int      { jobs.count }
    var doneCount: Int       { jobs.filter { $0.status == .done      }.count }
    var failedCount: Int     { jobs.filter { $0.status == .failed    }.count }
    var skippedCount: Int    { jobs.filter { $0.status == .skipped   }.count }
    var cancelledCount: Int  { jobs.filter { $0.status == .cancelled }.count }
    var convertingCount: Int { jobs.filter { $0.status == .converting }.count }

    var finishedCount: Int {
        doneCount + failedCount + skippedCount + cancelledCount
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(finishedCount) / Double(totalCount)
    }

    var estimatedTimeRemaining: String? {
        guard let start = conversionStartDate,
              isConverting,
              finishedCount > 0 else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let avgPerJob = elapsed / Double(finishedCount)
        let remaining = Int(avgPerJob * Double(totalCount - finishedCount))
        if remaining < 60 { return "\(remaining)s" }
        if remaining < 3600 { return "\(remaining / 60)m \(remaining % 60)s" }
        return "\(remaining / 3600)h \(remaining % 3600 / 60)m"
    }

    // MARK: - Button availability

    var canScan: Bool {
        selectedFolder != nil && !isScanning && !isConverting
    }
    var canClearList: Bool {
        !jobs.isEmpty && !isConverting
    }
    var canStart: Bool {
        !jobs.isEmpty && !isConverting &&
        jobs.contains(where: { $0.status == .pending })
    }
    var canPause: Bool  { isConverting && !isPaused && !isCancelling }
    var canResume: Bool { isConverting &&  isPaused && !isCancelling }
    var canCancel: Bool { isConverting && !isCancelling }

    // MARK: - Private services

    private let scanner  = FolderScanner()
    private let locator  = ChdmanLocator()
    private let dolphinToolLocator = DolphinToolLocator()
    private let maxcsoLocator = MaxcsoLocator()
    private let nszLocator = NszLocator()
    private let sevenZipLocator = SevenZipLocator()
    private let witLocator = WitLocator()
    private let repackinatorLocator = RepackinatorLocator()
    private let makePs3IsoLocator = MakePs3IsoLocator()
    private let extractPs3IsoLocator = ExtractPs3IsoLocator()
    private let extractXisoLocator = ExtractXisoLocator()
    private let logStore = LogStore()
    private let maxGlobalLogCharacters = 200_000

    private var engine: BatchEngine?
    private var conversionTask: Task<Void, Never>?
    private var currentRunID: UUID?
    private var currentRunWasCancelled = false

    // MARK: - Startup check

    func checkSelectedToolAvailability() async {
        // Show setup wizard on first launch
        if !hasCompletedSetup {
            showSetupWizard = true
        }

        // Reset all missing flags, then check the selected one.
        chdmanMissing = false
        dolphinToolMissing = false
        maxcsoMissing = false
        nszMissing = false
        sevenZipMissing = false
        witMissing = false
        repackinatorMissing = false
        makePs3IsoMissing = false
        extractXisoMissing = false

        switch selectedTool {
        case .chdman:
            do {
                _ = try await locator.locate(
                    customPath: customChdmanPath.isEmpty ? nil : customChdmanPath
                )
            } catch {
                chdmanMissing = true
            }
        case .dolphinTool:
            do {
                let path = try await dolphinToolLocator.locate(
                    customPath: customDolphinToolPath.isEmpty ? nil : customDolphinToolPath
                )
                let isValid = await dolphinToolLocator.verify(path: path)
                dolphinToolMissing = !isValid
            } catch {
                dolphinToolMissing = true
            }
        case .maxcso:
            do {
                let path = try await maxcsoLocator.locate(
                    customPath: customMaxcsoPath.isEmpty ? nil : customMaxcsoPath
                )
                let isValid = await maxcsoLocator.verify(path: path)
                maxcsoMissing = !isValid
            } catch {
                maxcsoMissing = true
            }
        case .nsz:
            do {
                let path = try await nszLocator.locate(
                    customPath: customNszPath.isEmpty ? nil : customNszPath
                )
                let isValid = await nszLocator.verify(path: path)
                nszMissing = !isValid
            } catch {
                nszMissing = true
            }
        case .sevenZip:
            do {
                let path = try await sevenZipLocator.locate(
                    customPath: customSevenZipPath.isEmpty ? nil : customSevenZipPath
                )
                let isValid = await sevenZipLocator.verify(path: path)
                sevenZipMissing = !isValid
            } catch {
                sevenZipMissing = true
            }
        case .wit:
            do {
                let path = try await witLocator.locate(
                    customPath: customWitPath.isEmpty ? nil : customWitPath
                )
                let isValid = await witLocator.verify(path: path)
                witMissing = !isValid
            } catch {
                witMissing = true
            }
        case .repackinator:
            do {
                let path = try await repackinatorLocator.locate(
                    customPath: customRepackinatorPath.isEmpty ? nil : customRepackinatorPath
                )
                let isValid = await repackinatorLocator.verify(path: path)
                repackinatorMissing = !isValid
            } catch {
                repackinatorMissing = true
            }
        case .makeps3iso:
            // Check whichever binary is needed for the current mode
            if appMode == .create {
                do {
                    let path = try await makePs3IsoLocator.locate(
                        customPath: customMakePs3IsoPath.isEmpty ? nil : customMakePs3IsoPath
                    )
                    makePs3IsoMissing = !(await makePs3IsoLocator.verify(path: path))
                } catch { makePs3IsoMissing = true }
            } else {
                do {
                    let path = try await extractPs3IsoLocator.locate(
                        customPath: customExtractPs3IsoPath.isEmpty ? nil : customExtractPs3IsoPath
                    )
                    makePs3IsoMissing = !(await extractPs3IsoLocator.verify(path: path))
                } catch { makePs3IsoMissing = true }
            }
        case .extractXiso:
            do {
                let path = try await extractXisoLocator.locate(
                    customPath: customExtractXisoPath.isEmpty ? nil : customExtractXisoPath
                )
                let isValid = await extractXisoLocator.verify(path: path)
                extractXisoMissing = !isValid
            } catch {
                extractXisoMissing = true
            }
        }
    }

    func handleToolSelectionChange() async {
        chdmanCapabilities = nil
        clearList()
        // Enforce mode constraints
        if !selectedTool.supportsCreate && appMode == .create {
            appMode = .extract
        }
        if !selectedTool.supportsExtract && appMode == .extract {
            appMode = .create
        }
        await checkSelectedToolAvailability()
    }

    // MARK: - Folder picker

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles        = false
        panel.canChooseDirectories  = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to scan for \(scanTargetDescription())"
        panel.prompt  = "Select"
        if panel.runModal() == .OK {
            selectedFolder = panel.url
        }
    }

    // MARK: - Scan

    func scan() async {
        guard let folder = selectedFolder else { return }
        isScanning = true
        defer { isScanning = false }

        let discovered = await scanner.scan(
            folder: folder,
            recursive: isRecursive,
            tool: selectedTool,
            mode: appMode
        )
        jobs = discovered

        let modeLabel = scanTargetDescription()
        let msg = "[\(timestamp())] Scan complete — \(discovered.count) \(modeLabel) found in \(folder.path)"
        appendGlobalLog(msg)
        Task { await logStore.appendGlobal(msg) }
    }

    // MARK: - Clear

    func clearList() {
        jobs = []
        let msg = "[\(timestamp())] List cleared."
        appendGlobalLog(msg)
    }

    // MARK: - Start conversion

    func startConversion() async {
        let concurrency = min(parallelJobs, ProcessInfo.processInfo.activeProcessorCount)
        let engineToRun: BatchEngine

        switch selectedTool {
        case .chdman:
            let chdmanPath: String
            do {
                chdmanPath = try await locator.locate(
                    customPath: customChdmanPath.isEmpty ? nil : customChdmanPath
                )
            } catch {
                chdmanAlertMessage =
                    "\(error.localizedDescription)\n\nInstall chdman with:\n    brew install rom-tools"
                showChdmanAlert = true
                return
            }

            let caps: ChdmanCapabilities
            do {
                caps = try await locator.detectCapabilities(chdmanPath: chdmanPath)
            } catch {
                chdmanAlertMessage =
                    "Failed to detect chdman capabilities: \(error.localizedDescription)"
                showChdmanAlert = true
                return
            }

            chdmanCapabilities = caps
            let capLine = "[\(timestamp())] chdman: \(chdmanPath) | createcd=\(caps.hasCreateCD) createdvd=\(caps.hasCreateDVD) extractcd=\(caps.hasExtractCD) extractdvd=\(caps.hasExtractDVD)"
            appendGlobalLog(capLine)
            Task { await logStore.appendGlobal(capLine) }

            let eng = ConversionEngine(
                chdmanPath: chdmanPath,
                capabilities: caps,
                compressionPreset: compressionPreset,
                concurrency: concurrency,
                jobs: jobs,
                logStore: logStore,
                deleteSource: deleteSourceAfterConversion
            )
            eng.onLogLine = { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.appendGlobalLog(line)
                }
            }
            engineToRun = eng

        case .dolphinTool:
            let dolphinToolPath: String
            do {
                dolphinToolPath = try await dolphinToolLocator.locate(
                    customPath: customDolphinToolPath.isEmpty ? nil : customDolphinToolPath
                )
            } catch {
                dolphinToolAlertMessage = error.localizedDescription
                showDolphinToolAlert = true
                return
            }

            guard await dolphinToolLocator.verify(path: dolphinToolPath) else {
                dolphinToolAlertMessage =
                    "The selected executable does not appear to support `dolphin-tool convert`."
                showDolphinToolAlert = true
                return
            }

            chdmanCapabilities = nil
            let pathLine = "[\(timestamp())] dolphin-tool: \(dolphinToolPath)"
            appendGlobalLog(pathLine)
            Task { await logStore.appendGlobal(pathLine) }

            let eng = DolphinToolEngine(
                dolphinToolPath: dolphinToolPath,
                compressionPreset: compressionPreset,
                mode: appMode,
                concurrency: concurrency,
                jobs: jobs,
                logStore: logStore,
                deleteSource: deleteSourceAfterConversion
            )
            eng.onLogLine = { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.appendGlobalLog(line)
                }
            }
            engineToRun = eng

        case .maxcso:
            let maxcsoPath: String
            do {
                maxcsoPath = try await maxcsoLocator.locate(
                    customPath: customMaxcsoPath.isEmpty ? nil : customMaxcsoPath
                )
            } catch {
                maxcsoAlertMessage =
                    "\(error.localizedDescription)\n\nDownload maxcso from:\ngithub.com/unknownbrackets/maxcso/releases"
                showMaxcsoAlert = true
                return
            }

            guard await maxcsoLocator.verify(path: maxcsoPath) else {
                maxcsoAlertMessage =
                    "The selected executable does not appear to be a valid maxcso binary."
                showMaxcsoAlert = true
                return
            }

            chdmanCapabilities = nil
            let pathLine = "[\(timestamp())] maxcso: \(maxcsoPath)"
            appendGlobalLog(pathLine)
            Task { await logStore.appendGlobal(pathLine) }

            let eng = MaxcsoEngine(
                maxcsoPath: maxcsoPath,
                compressionPreset: compressionPreset,
                mode: appMode,
                concurrency: concurrency,
                jobs: jobs,
                logStore: logStore,
                deleteSource: deleteSourceAfterConversion
            )
            eng.onLogLine = { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.appendGlobalLog(line)
                }
            }
            engineToRun = eng

        case .nsz:
            let nszPath: String
            do {
                nszPath = try await nszLocator.locate(
                    customPath: customNszPath.isEmpty ? nil : customNszPath
                )
            } catch {
                nszAlertMessage =
                    "\(error.localizedDescription)\n\nInstall nsz with:\n    pip3 install nsz"
                showNszAlert = true
                return
            }

            guard await nszLocator.verify(path: nszPath) else {
                nszAlertMessage =
                    "The selected executable does not appear to be a valid nsz binary."
                showNszAlert = true
                return
            }

            chdmanCapabilities = nil
            let pathLine = "[\(timestamp())] nsz: \(nszPath)"
            appendGlobalLog(pathLine)
            Task { await logStore.appendGlobal(pathLine) }

            let eng = NszEngine(
                nszPath: nszPath,
                compressionPreset: compressionPreset,
                mode: appMode,
                concurrency: concurrency,
                jobs: jobs,
                logStore: logStore,
                deleteSource: deleteSourceAfterConversion
            )
            eng.onLogLine = { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.appendGlobalLog(line)
                }
            }
            engineToRun = eng

        case .sevenZip:
            let sevenZipPath: String
            do {
                sevenZipPath = try await sevenZipLocator.locate(
                    customPath: customSevenZipPath.isEmpty ? nil : customSevenZipPath
                )
            } catch {
                sevenZipAlertMessage =
                    "\(error.localizedDescription)\n\nInstall 7z with:\n    brew install p7zip"
                showSevenZipAlert = true
                return
            }

            guard await sevenZipLocator.verify(path: sevenZipPath) else {
                sevenZipAlertMessage =
                    "The selected executable does not appear to be a valid 7z binary."
                showSevenZipAlert = true
                return
            }

            chdmanCapabilities = nil
            let pathLine = "[\(timestamp())] 7z: \(sevenZipPath)"
            appendGlobalLog(pathLine)
            Task { await logStore.appendGlobal(pathLine) }

            let eng = SevenZipEngine(
                sevenZipPath: sevenZipPath,
                concurrency: concurrency,
                jobs: jobs,
                logStore: logStore,
                deleteSource: deleteSourceAfterConversion
            )
            eng.onLogLine = { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.appendGlobalLog(line)
                }
            }
            engineToRun = eng

        case .wit:
            let witPath: String
            do {
                witPath = try await witLocator.locate(
                    customPath: customWitPath.isEmpty ? nil : customWitPath
                )
            } catch {
                witAlertMessage =
                    "\(error.localizedDescription)\n\nDownload from wit.wiimm.de or install via Homebrew."
                showWitAlert = true
                return
            }

            guard await witLocator.verify(path: witPath) else {
                witAlertMessage =
                    "The selected executable does not appear to be a valid wit binary."
                showWitAlert = true
                return
            }

            chdmanCapabilities = nil
            let pathLine = "[\(timestamp())] wit: \(witPath)"
            appendGlobalLog(pathLine)
            Task { await logStore.appendGlobal(pathLine) }

            let eng = WitEngine(
                witPath: witPath,
                compressionPreset: compressionPreset,
                mode: appMode,
                concurrency: concurrency,
                jobs: jobs,
                logStore: logStore,
                deleteSource: deleteSourceAfterConversion
            )
            eng.onLogLine = { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.appendGlobalLog(line)
                }
            }
            engineToRun = eng

        case .repackinator:
            let repackinatorPath: String
            do {
                repackinatorPath = try await repackinatorLocator.locate(
                    customPath: customRepackinatorPath.isEmpty ? nil : customRepackinatorPath
                )
            } catch {
                repackinatorAlertMessage =
                    "\(error.localizedDescription)\n\nDownload from:\ngithub.com/Team-Resurgent/Repackinator/releases"
                showRepackinatorAlert = true
                return
            }

            guard await repackinatorLocator.verify(path: repackinatorPath) else {
                repackinatorAlertMessage =
                    "The selected executable does not appear to be a valid Repackinator binary."
                showRepackinatorAlert = true
                return
            }

            chdmanCapabilities = nil
            let repackLine = "[\(timestamp())] repackinator: \(repackinatorPath)"
            appendGlobalLog(repackLine)
            Task { await logStore.appendGlobal(repackLine) }

            let repackEng = RepackinatorEngine(
                repackinatorPath: repackinatorPath,
                compressionPreset: compressionPreset,
                mode: appMode,
                concurrency: concurrency,
                jobs: jobs,
                logStore: logStore,
                deleteSource: deleteSourceAfterConversion
            )
            repackEng.onLogLine = { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.appendGlobalLog(line)
                }
            }
            engineToRun = repackEng

        case .makeps3iso:
            let makeps3isoPath: String
            let extractps3isoPath: String

            // Always locate makeps3iso (needed for create)
            do {
                makeps3isoPath = try await makePs3IsoLocator.locate(
                    customPath: customMakePs3IsoPath.isEmpty ? nil : customMakePs3IsoPath
                )
            } catch {
                makePs3IsoAlertMessage =
                    "\(error.localizedDescription)\n\nDownload from:\ngithub.com/bucanero/ps3iso-utils/releases"
                showMakePs3IsoAlert = true
                return
            }

            // Always locate extractps3iso (needed for extract)
            do {
                extractps3isoPath = try await extractPs3IsoLocator.locate(
                    customPath: customExtractPs3IsoPath.isEmpty ? nil : customExtractPs3IsoPath
                )
            } catch {
                makePs3IsoAlertMessage =
                    "\(error.localizedDescription)\n\nDownload from:\ngithub.com/bucanero/ps3iso-utils/releases"
                showMakePs3IsoAlert = true
                return
            }

            // Verify the binary that will actually be used for the current mode
            if appMode == .create {
                guard await makePs3IsoLocator.verify(path: makeps3isoPath) else {
                    makePs3IsoAlertMessage =
                        "The selected executable does not appear to be a valid makeps3iso binary."
                    showMakePs3IsoAlert = true
                    return
                }
            } else {
                guard await extractPs3IsoLocator.verify(path: extractps3isoPath) else {
                    makePs3IsoAlertMessage =
                        "The selected executable does not appear to be a valid extractps3iso binary."
                    showMakePs3IsoAlert = true
                    return
                }
            }

            chdmanCapabilities = nil
            let ps3Line = "[\(timestamp())] makeps3iso: \(makeps3isoPath) | extractps3iso: \(extractps3isoPath)"
            appendGlobalLog(ps3Line)
            Task { await logStore.appendGlobal(ps3Line) }

            let ps3Eng = MakePs3IsoEngine(
                makeps3isoPath: makeps3isoPath,
                extractps3isoPath: extractps3isoPath,
                mode: appMode,
                concurrency: concurrency,
                jobs: jobs,
                logStore: logStore,
                deleteSource: deleteSourceAfterConversion
            )
            ps3Eng.onLogLine = { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.appendGlobalLog(line)
                }
            }
            engineToRun = ps3Eng

        case .extractXiso:
            let extractXisoPath: String
            do {
                extractXisoPath = try await extractXisoLocator.locate(
                    customPath: customExtractXisoPath.isEmpty ? nil : customExtractXisoPath
                )
            } catch {
                extractXisoAlertMessage =
                    "\(error.localizedDescription)\n\nInstall with:\n    brew install extract-xiso"
                showExtractXisoAlert = true
                return
            }

            guard await extractXisoLocator.verify(path: extractXisoPath) else {
                extractXisoAlertMessage =
                    "The selected executable does not appear to be a valid extract-xiso binary."
                showExtractXisoAlert = true
                return
            }

            chdmanCapabilities = nil
            let xisoLine = "[\(timestamp())] extract-xiso: \(extractXisoPath)"
            appendGlobalLog(xisoLine)
            Task { await logStore.appendGlobal(xisoLine) }

            let xisoEng = ExtractXisoEngine(
                extractXisoPath: extractXisoPath,
                mode: appMode,
                concurrency: concurrency,
                jobs: jobs,
                logStore: logStore,
                deleteSource: deleteSourceAfterConversion
            )
            xisoEng.onLogLine = { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.appendGlobalLog(line)
                }
            }
            engineToRun = xisoEng
        }

        let startMsg = startMessage(concurrency: concurrency)
        appendGlobalLog(startMsg)
        Task { await logStore.appendGlobal(startMsg) }

        engine = engineToRun
        isConverting = true
        isPaused = false
        isCancelling = false
        conversionStartDate = Date()
        let runID = UUID()
        currentRunID = runID
        currentRunWasCancelled = false

        conversionTask = Task { [weak self, engineToRun] in
            await engineToRun.run()
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.currentRunID == runID else { return }

                let wasCancelled = self.currentRunWasCancelled
                self.isConverting = false
                self.isCancelling = false
                self.conversionStartDate = nil
                self.engine = nil
                self.conversionTask = nil
                self.currentRunID = nil
                self.currentRunWasCancelled = false

                let doneMsg: String
                if wasCancelled {
                    doneMsg = "[\(self.timestamp())] Batch cancelled — \(self.doneCount) done, \(self.failedCount) failed, \(self.skippedCount) skipped, \(self.cancelledCount) cancelled."
                } else {
                    doneMsg = "[\(self.timestamp())] All jobs finished — \(self.doneCount) done, \(self.failedCount) failed, \(self.skippedCount) skipped."
                }

                self.appendGlobalLog(doneMsg)
                Task { await self.logStore.appendGlobal(doneMsg) }
                if self.notifyOnCompletion && !wasCancelled {
                    self.sendCompletionNotification()
                }
            }
        }
    }

    // MARK: - Pause / Resume / Cancel

    func pauseConversion() {
        engine?.pause()
        isPaused = true
        let line = "[\(timestamp())] [PAUSE] Conversion paused — running jobs will finish."
        appendGlobalLog(line)
        Task { await logStore.appendGlobal(line) }
    }

    func resumeConversion() {
        engine?.resume()
        isPaused = false
        let line = "[\(timestamp())] [RESUME] Conversion resumed."
        appendGlobalLog(line)
        Task { await logStore.appendGlobal(line) }
    }

    func cancelConversion() {
        guard isConverting, !isCancelling else { return }
        isCancelling = true
        isPaused = false
        currentRunWasCancelled = true
        engine?.cancel()
        let line = "[\(timestamp())] [CANCEL] Cancellation requested — active jobs will stop."
        appendGlobalLog(line)
        Task { await logStore.appendGlobal(line) }
    }

    // MARK: - Log helpers

    func openLogFile() {
        Task {
            if let url = await logStore.logFileURL {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func appendGlobalLog(_ line: String) {
        globalLog.appendCappedLine(line, limit: maxGlobalLogCharacters)
    }

    func timestamp() -> String {
        DateFormatter.timestamp.string(from: Date())
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        // No-op: NSSound-based notification needs no permission
    }

    private func sendCompletionNotification() {
        NSSound.beep()
        NSApp.requestUserAttention(.informationalRequest)
    }

    private func scanTargetDescription() -> String {
        switch (selectedTool, appMode) {
        case (.chdman, .create):
            return "disc images"
        case (.chdman, .extract):
            return "CHD files"
        case (.dolphinTool, .create):
            return "ISO, GCZ, and WIA files"
        case (.dolphinTool, .extract):
            return "RVZ, GCZ, and WIA files"
        case (.maxcso, .create):
            return "ISO files"
        case (.maxcso, .extract):
            return "CSO files"
        case (.nsz, .create):
            return "NSP and XCI files"
        case (.nsz, .extract):
            return "NSZ and XCZ files"
        case (.sevenZip, .extract):
            return "7z, ZIP, and RAR archives"
        case (.sevenZip, .create):
            return "files"
        case (.wit, .create):
            return "ISO files"
        case (.wit, .extract):
            return "WBFS files"
        case (.repackinator, .create):
            return "ISO files (Xbox OG)"
        case (.repackinator, .extract):
            return "CCI files"
        case (.makeps3iso, .create):
            return "PS3 game folders"
        case (.makeps3iso, .extract):
            return "PS3 ISO files"
        case (.extractXiso, .create):
            return "Xbox game folders"
        case (.extractXiso, .extract):
            return "Xbox ISO files"
        }
    }

    private func startMessage(concurrency: Int) -> String {
        var parts = [
            "[\(timestamp())] Starting \(selectedTool.rawValue) \(appMode.rawValue) batch",
            "concurrency=\(concurrency)"
        ]
        if appMode == .create {
            parts.append("preset=\(compressionPreset.title)")
        }
        return parts.joined(separator: " — ")
    }
}
