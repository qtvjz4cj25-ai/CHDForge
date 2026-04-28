import SwiftUI
import AppKit

struct ArtworkScraperView: View {

    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    // Folder & system
    @State private var selectedFolder: URL?
    @State private var selectedSystem: SSSystem = SSSystem.all[0]
    @State private var outputFormat: ScrapeOutputFormat = .emulationStation
    @State private var selectedMediaTypes: Set<ScrapeMediaType> = [.boxArt, .screenshot]

    // Jobs
    @State private var jobs: [ScrapeJob] = []
    @State private var isScanning = false
    @State private var isScraping = false
    @State private var scrapeTask: Task<Void, Never>? = nil

    // Progress
    @State private var completedCount = 0
    @State private var globalLog: String = ""

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ────────────────────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Artwork Scraper")
                        .font(.title3.weight(.bold))
                    Text("Powered by ScreenScraper.fr")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(toolbarBackground)

            Divider()

            // ── Config row ────────────────────────────────────────────────
            configRow
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(toolbarBackground)

            Divider()

            // ── Job list ──────────────────────────────────────────────────
            if jobs.isEmpty {
                emptyState
            } else {
                jobListView
            }

            Divider()

            // ── Progress bar ──────────────────────────────────────────────
            if !jobs.isEmpty {
                progressRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
            }

            Divider()

            // ── Log ───────────────────────────────────────────────────────
            LogPanelView(
                log: globalLog,
                autoScroll: .constant(true),
                onOpenFile: {}
            )
            .frame(minHeight: 100, idealHeight: 130)

            Divider()

            // ── Bottom toolbar ────────────────────────────────────────────
            bottomBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(toolbarBackground)
        }
        .frame(width: 680, height: 620)
    }

    // MARK: - Config row

    @ViewBuilder
    private var configRow: some View {
        HStack(spacing: 10) {
            // Folder picker
            Button {
                pickFolder()
            } label: {
                Label(selectedFolder?.lastPathComponent ?? "Choose Folder…",
                      systemImage: "folder.badge.plus")
                    .lineLimit(1)
                    .frame(maxWidth: 160)
                    .truncationMode(.middle)
            }
            .help(selectedFolder?.path ?? "Select the folder containing your ROMs")

            Divider().frame(height: 18)

            // System picker
            Picker("System", selection: $selectedSystem) {
                ForEach(SSSystem.all) { sys in
                    Text(sys.name).tag(sys)
                }
            }
            .labelsHidden()
            .frame(width: 200)
            .help("The gaming system this folder belongs to")

            Divider().frame(height: 18)

            // Output format
            Picker("Format", selection: $outputFormat) {
                ForEach(ScrapeOutputFormat.allCases) { fmt in
                    Text(fmt.rawValue).tag(fmt)
                }
            }
            .labelsHidden()
            .frame(width: 220)
            .help(outputFormat.description)

            Spacer()

            // Scan button
            Button {
                Task { await scanFolder() }
            } label: {
                if isScanning {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini)
                        Text("Scanning…")
                    }
                } else {
                    Label("Scan", systemImage: "magnifyingglass")
                }
            }
            .disabled(selectedFolder == nil || isScanning || isScraping)
        }
    }

    // MARK: - Media type toggles

    @ViewBuilder
    private var mediaTypeRow: some View {
        HStack(spacing: 8) {
            Text("Download:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(ScrapeMediaType.allCases) { type in
                Toggle(type.rawValue, isOn: Binding(
                    get: { selectedMediaTypes.contains(type) },
                    set: { if $0 { selectedMediaTypes.insert(type) } else { selectedMediaTypes.remove(type) } }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)
                .disabled(isScraping)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Choose a folder and system, then click Scan")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if vm.ssUsername.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("No ScreenScraper account set — add one in Settings for better rate limits.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Job list

    @ViewBuilder
    private var jobListView: some View {
        VStack(spacing: 0) {
            mediaTypeRow

            List(jobs) { job in
                ScrapeJobRow(job: job)
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressRow: some View {
        let total = jobs.count
        let done  = jobs.filter { if case .done = $0.status { return true }; return false }.count
        let notFound = jobs.filter { if case .notFound = $0.status { return true }; return false }.count
        let failed   = jobs.filter { if case .failed = $0.status { return true }; return false }.count
        let progress = total > 0 ? Double(done + notFound + failed) / Double(total) : 0

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(failed > 0 && done == 0 ? .red : .accentColor)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                chip("\(total)",    icon: "tray.full",        color: .secondary)
                chip("\(done)",     icon: "checkmark.circle", color: .green)
                chip("\(notFound)", icon: "questionmark",     color: .orange)
                chip("\(failed)",   icon: "xmark.circle",     color: .red)
            }
        }
    }

    @ViewBuilder
    private func chip(_ value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(color)
            Text(value).font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(color == .secondary ? Color.primary : color)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 5)
            .fill(color == .secondary ? Color.primary.opacity(0.05) : color.opacity(0.08)))
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                jobs = []
                globalLog = ""
                completedCount = 0
            } label: { Image(systemName: "trash") }
            .disabled(jobs.isEmpty || isScraping)
            .help("Clear list")

            Spacer()

            if isScraping {
                Button {
                    scrapeTask?.cancel()
                    scrapeTask = nil
                } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .tint(.red)
            } else {
                Button {
                    scrapeTask = Task { await startScraping() }
                } label: {
                    Label("Scrape Artwork", systemImage: "photo.badge.arrow.down.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(jobs.isEmpty || selectedMediaTypes.isEmpty)
                .keyboardShortcut("s", modifiers: [.command])
            }
        }
    }

    private var toolbarBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Color.primary.opacity(0.018)
        }
    }

    // MARK: - Actions

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the folder containing your ROM files"
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
            jobs = []
            globalLog = ""
        }
    }

    private func scanFolder() async {
        guard let folder = selectedFolder else { return }
        isScanning = true
        defer { isScanning = false }

        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let romExtensions: Set<String> = [
            "chd", "iso", "cue", "gdi", "bin",
            "rvz", "gcz", "wia", "wbfs",
            "cso", "nsp", "nsz", "xci", "xcz",
            "7z", "zip", "rar", "rom", "n64",
            "z64", "v64", "gb", "gbc", "gba",
            "nds", "3ds", "sfc", "smc", "md",
            "gen", "gg", "pce", "sg"
        ]

        let romURLs = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            return romExtensions.contains(ext)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        await MainActor.run {
            jobs = romURLs.map { ScrapeJob(fileURL: $0) }
        }

        appendLog("[\(ts())] Scan complete — \(romURLs.count) files found in \(folder.lastPathComponent)")
    }

    private func startScraping() async {
        guard !jobs.isEmpty else { return }
        await MainActor.run { isScraping = true }
        defer { Task { @MainActor in isScraping = false } }

        let client = ScreenScraperClient(
            username: vm.ssUsername,
            password: vm.ssPassword
        )
        let folder = selectedFolder
        let format = outputFormat
        let system = selectedSystem
        let mediaTypes = selectedMediaTypes

        var results: [ScrapeResult] = []

        for job in jobs {
            if Task.isCancelled { break }

            await MainActor.run { job.status = .hashing }
            appendLog("[\(ts())] [HASH] \(job.name)")

            let md5: String
            do {
                md5 = try await ScreenScraperClient.md5(of: job.fileURL)
            } catch {
                await MainActor.run {
                    job.status = .failed("Hash error: \(error.localizedDescription)")
                }
                appendLog("[\(ts())] [FAIL] \(job.name) — \(error.localizedDescription)")
                continue
            }

            await MainActor.run { job.status = .searching }
            appendLog("[\(ts())] [SEARCH] \(job.name)")

            let game: SSGame
            do {
                game = try await client.lookupGame(
                    md5: md5,
                    filename: job.fileURL.lastPathComponent,
                    systemID: system.id
                )
            } catch ScreenScraperError.notFound {
                await MainActor.run {
                    job.status = .notFound
                    job.detail = "Not found"
                }
                appendLog("[\(ts())] [NOT FOUND] \(job.name)")
                // Rate limit: 1 req/sec
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            } catch ScreenScraperError.rateLimited {
                await MainActor.run {
                    job.status = .failed("Rate limited — wait and retry")
                }
                appendLog("[\(ts())] [RATE LIMIT] Pausing 10s…")
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                continue
            } catch {
                await MainActor.run {
                    job.status = .failed(error.localizedDescription)
                }
                appendLog("[\(ts())] [FAIL] \(job.name) — \(error.localizedDescription)")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                continue
            }

            let gameName = game.bestName() ?? job.name
            await MainActor.run {
                job.gameName = gameName
                job.status = .downloading
                job.detail = gameName
            }
            appendLog("[\(ts())] [FOUND] \(job.name) → \(gameName)")

            // Build result and download media
            var result = ScrapeResult(
                fileURL: job.fileURL,
                gameName: gameName,
                description: game.bestSynopsis() ?? "",
                releaseDate: GamelistWriter.convertDate(game.bestDate()),
                developer: game.developpeur?.text,
                publisher: game.editeur?.text,
                genre: game.firstGenre(),
                players: game.joueurs?.text,
                rating: game.normalizedRating()
            )

            for mediaType in mediaTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let mediaURL = game.mediaURL(types: mediaType.ssTypes) else { continue }
                guard let destFolder = folder else { continue }

                let ext = game.mediaFormat(types: mediaType.ssTypes)
                let stem = job.fileURL.deletingPathExtension().lastPathComponent
                let mediaFolder: URL

                switch format {
                case .emulationStation:
                    mediaFolder = destFolder.appendingPathComponent(mediaType.esFolder)
                case .esDe:
                    let home = FileManager.default.homeDirectoryForCurrentUser
                    mediaFolder = home
                        .appendingPathComponent(".emulationstation/downloaded_media")
                        .appendingPathComponent(system.shortName)
                        .appendingPathComponent(mediaType.esDeName)
                case .imagesOnly:
                    mediaFolder = destFolder.appendingPathComponent(mediaType.esFolder)
                }

                let destURL = mediaFolder.appendingPathComponent("\(stem).\(ext)")

                do {
                    try await client.downloadMedia(from: mediaURL, to: destURL)
                    result.mediaFiles[mediaType] = destURL
                    appendLog("[\(ts())] [IMG] \(mediaType.rawValue) → \(destURL.lastPathComponent)")
                } catch {
                    appendLog("[\(ts())] [IMG FAIL] \(mediaType.rawValue): \(error.localizedDescription)")
                }
            }

            results.append(result)
            await MainActor.run { job.status = .done }

            // Rate limit: 1 req/sec
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        // Write gamelist
        if !results.isEmpty, let folder {
            do {
                try GamelistWriter.write(
                    results: results,
                    to: folder,
                    format: format,
                    system: system
                )
                appendLog("[\(ts())] [DONE] gamelist.xml written to \(folder.lastPathComponent)")
            } catch {
                appendLog("[\(ts())] [FAIL] gamelist.xml write failed: \(error.localizedDescription)")
            }
        }

        appendLog("[\(ts())] Scrape complete.")
    }

    @MainActor
    private func appendLog(_ line: String) {
        globalLog.appendCappedLine(line, limit: 100_000)
    }

    private func ts() -> String {
        DateFormatter.timestamp.string(from: Date())
    }
}

// MARK: - Scrape job row

private struct ScrapeJobRow: View {
    @ObservedObject var job: ScrapeJob

    var body: some View {
        HStack(spacing: 10) {
            statusIcon.frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                if !job.gameName.isEmpty {
                    Text(job.gameName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            statusLabel
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch job.status {
        case .pending:
            Circle().fill(Color.secondary.opacity(0.3)).frame(width: 8, height: 8)
        case .hashing:
            ProgressView().controlSize(.mini)
        case .searching:
            ProgressView().controlSize(.mini)
        case .downloading:
            ProgressView().controlSize(.mini)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .notFound:
            Image(systemName: "questionmark.circle").foregroundStyle(.orange)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .skipped:
            Image(systemName: "forward.circle").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch job.status {
        case .pending:     Text("Pending").font(.caption).foregroundStyle(.secondary)
        case .hashing:     Text("Hashing…").font(.caption).foregroundStyle(.secondary)
        case .searching:   Text("Searching…").font(.caption).foregroundStyle(.secondary)
        case .downloading: Text("Downloading…").font(.caption).foregroundStyle(.blue)
        case .done:        Text("Done").font(.caption).foregroundStyle(.green)
        case .notFound:    Text("Not Found").font(.caption).foregroundStyle(.orange)
        case .failed(let msg):
            Text(msg).font(.caption).foregroundStyle(.red).lineLimit(1).frame(maxWidth: 160)
        case .skipped:     Text("Skipped").font(.caption).foregroundStyle(.secondary)
        }
    }
}
