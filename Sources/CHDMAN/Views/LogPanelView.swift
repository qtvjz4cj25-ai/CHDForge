import SwiftUI

struct LogPanelView: View {
    let log: String
    @Binding var autoScroll: Bool
    var onOpenFile: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {

            // ── Header bar ────────────────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Activity Log")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                if let onOpenFile {
                    Button(action: onOpenFile) {
                        Label("Open File", systemImage: "square.and.arrow.up")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(logHeaderBackground)

            Divider().overlay(Color.primary.opacity(0.06))

            // ── Scrollable log body ───────────────────────────────────────────
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    Text(log.isEmpty ? "No activity yet." : log)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(log.isEmpty ? Color.tertiaryLabel : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .id("logBottom")
                        .textSelection(.enabled)
                }
                .background(logBodyBackground)
                .onChange(of: log) { _ in
                    if autoScroll {
                        withAnimation(.easeOut(duration: 0.08)) {
                            proxy.scrollTo("logBottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // A subtle warm-tinted background distinguishes the log area from
    // the rest of the window without going full dark-mode terminal.
    private var logHeaderBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Color.primary.opacity(0.025)
        }
    }

    private var logBodyBackground: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            // Very faint warm tint — the "retro" part without screaming about it.
            Color(red: 1.0, green: 0.97, blue: 0.92).opacity(0.04)
        }
    }
}

// MARK: - Per-job log sheet

struct JobLogSheet: View {
    @ObservedObject var job: ConversionJob
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        sourceTypePill(job.sourceType)
                        Text(job.filename)
                            .font(.headline)
                    }
                    Text(job.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("→ \(job.outputPath)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    statusPill(job.status)
                    Button("Close") { dismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                Text(job.log.isEmpty ? "No output for this job." : job.log)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(job.log.isEmpty ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .textSelection(.enabled)
            }
            .background(
                ZStack {
                    Color(nsColor: .textBackgroundColor)
                    Color(red: 1.0, green: 0.97, blue: 0.92).opacity(0.04)
                }
            )
        }
        .frame(width: 660, height: 420)
    }

    @ViewBuilder
    private func sourceTypePill(_ type: SourceType) -> some View {
        Text(type.rawValue)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(typeColor(type))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(typeColor(type).opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(typeColor(type).opacity(0.35), lineWidth: 0.5))
    }

    @ViewBuilder
    private func statusPill(_ status: JobStatus) -> some View {
        Text(status.rawValue)
            .font(.system(size: 10, design: .rounded).weight(.semibold))
            .foregroundStyle(status.swiftUIColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(status.swiftUIColor.opacity(0.1)))
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
}
