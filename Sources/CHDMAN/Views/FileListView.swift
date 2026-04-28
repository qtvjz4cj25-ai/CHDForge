import SwiftUI

struct FileListView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var selection: Set<ConversionJob.ID> = []
    @State private var sortOrder = [KeyPathComparator(\ConversionJob.filename)]
    @State private var selectedJobForLog: ConversionJob?

    var body: some View {
        Table(vm.jobs, selection: $selection, sortOrder: $sortOrder) {

            // Filename
            TableColumn("Filename", value: \.filename) { job in
                HStack(spacing: 6) {
                    sourceTypeBadge(job.sourceType)
                    Text(job.filename)
                        .lineLimit(1)
                        .help(job.filename)
                }
            }
            .width(min: 160, ideal: 220)

            // Full path (monospaced, muted)
            TableColumn("Path") { job in
                Text(job.path.truncatedPath())
                    .lineLimit(1)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .help(job.path)
            }
            .width(min: 160, ideal: 210)

            // Output path
            TableColumn("Output") { job in
                HStack(spacing: 4) {
                    Text(job.outputPath.truncatedPath())
                        .lineLimit(1)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .help(job.outputPath)

                    // Inline reveal button — only shown for Done jobs
                    if job.status == .done {
                        Button {
                            revealOutput(job)
                        } label: {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal output in Finder")
                    }
                }
            }
            .width(min: 160, ideal: 210)

            // Status
            TableColumn("Status", value: \.status.rawValue) { job in
                statusBadge(job.status)
            }
            .width(88)

            // Detail
            TableColumn("Detail") { job in
                Text(job.detail.isEmpty ? "—" : job.detail)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(job.detail)
            }
            .width(min: 80, ideal: 140)
        }
        .onChange(of: sortOrder) { newOrder in
            vm.jobs.sort(using: newOrder)
        }
        .contextMenu(forSelectionType: ConversionJob.ID.self) { ids in
            if ids.count == 1,
               let id   = ids.first,
               let job  = vm.jobs.first(where: { $0.id == id }) {

                Button("Show Log…") { selectedJobForLog = job }

                Divider()

                Button("Reveal Source in Finder") {
                    NSWorkspace.shared.selectFile(job.path, inFileViewerRootedAtPath: "")
                }

                Button("Reveal Output in Finder") {
                    revealOutput(job)
                }
                .disabled(job.status != .done)

                Divider()

                Button("Copy Source Path") {
                    NSPasteboard.general.setString(job.path)
                }
                Button("Copy Output Path") {
                    NSPasteboard.general.setString(job.outputPath)
                }

                Divider()

                Button("Remove from List") {
                    vm.jobs.removeAll { $0.id == id }
                }
                .disabled(vm.isConverting)
            }
        }
        .sheet(item: $selectedJobForLog) { job in
            JobLogSheet(job: job)
        }
    }

    // MARK: - Source type badge

    @ViewBuilder
    private func sourceTypeBadge(_ type: SourceType) -> some View {
        Text(type.rawValue)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(typeColor(type))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(typeColor(type).opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(typeColor(type).opacity(0.35), lineWidth: 0.5)
            )
    }

    // MARK: - Status badge

    @ViewBuilder
    private func statusBadge(_ status: JobStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon(status))
                .font(.system(size: 9))
                .foregroundStyle(status.swiftUIColor)
            Text(status.rawValue)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(status.swiftUIColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(status.swiftUIColor.opacity(status == .pending ? 0.0 : 0.08))
        )
    }

    // MARK: - Helpers

    private func revealOutput(_ job: ConversionJob) {
        let fm = FileManager.default
        if fm.fileExists(atPath: job.outputPath) {
            NSWorkspace.shared.selectFile(job.outputPath, inFileViewerRootedAtPath: "")
        } else {
            // Reveal the containing directory if the CHD doesn't exist yet.
            NSWorkspace.shared.selectFile(
                job.outputURL.deletingLastPathComponent().path,
                inFileViewerRootedAtPath: ""
            )
        }
    }

    private func typeColor(_ type: SourceType) -> Color {
        switch type {
        case .iso: return .blue
        case .cue: return Color(red: 0.2, green: 0.72, blue: 0.35)
        case .gdi: return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .chd: return .purple
        case .gcz: return Color(red: 0.88, green: 0.42, blue: 0.16)
        case .rvz: return Color(red: 0.15, green: 0.65, blue: 0.8)
        case .wia: return Color(red: 0.8, green: 0.32, blue: 0.5)
        case .cso: return Color(red: 0.55, green: 0.35, blue: 0.85)
        case .nsp: return Color(red: 0.9, green: 0.2, blue: 0.3)
        case .xci: return Color(red: 0.2, green: 0.5, blue: 0.9)
        case .nsz: return Color(red: 0.75, green: 0.15, blue: 0.25)
        case .xcz: return Color(red: 0.15, green: 0.4, blue: 0.75)
        case .sevenZ: return Color(red: 0.4, green: 0.7, blue: 0.3)
        case .zip: return Color(red: 0.95, green: 0.7, blue: 0.2)
        case .rar: return Color(red: 0.7, green: 0.3, blue: 0.6)
        case .wbfs: return Color(red: 0.3, green: 0.6, blue: 0.9)
        case .cci:  return Color(red: 0.55, green: 0.15, blue: 0.15)
        }
    }

    private func statusIcon(_ status: JobStatus) -> String {
        switch status {
        case .pending:    return "clock"
        case .converting: return "arrow.2.circlepath"
        case .done:       return "checkmark.circle.fill"
        case .failed:     return "xmark.circle.fill"
        case .skipped:    return "forward.circle.fill"
        case .cancelled:  return "stop.circle.fill"
        case .paused:     return "pause.circle.fill"
        }
    }
}
