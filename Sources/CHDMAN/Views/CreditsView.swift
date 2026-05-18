import SwiftUI
import AppKit

// MARK: - Credit entry model

private struct CreditEntry: Identifiable {
    let id = UUID()
    let tool: String
    let author: String
    let description: String
    let url: String
    let color: Color
}

private let credits: [CreditEntry] = [
    .init(tool: "chdman",
          author: "The MAME Project",
          description: "CD/DVD disc image archiving — PS1, PS2, Dreamcast, Saturn & more",
          url: "https://www.mamedev.org",
          color: .blue),
    .init(tool: "dolphin-tool",
          author: "Dolphin Emulator Team",
          description: "GameCube & Wii image conversion — ISO ↔ RVZ/GCZ/WIA",
          url: "https://dolphin-emu.org",
          color: Color(red: 0.2, green: 0.6, blue: 1.0)),
    .init(tool: "maxcso",
          author: "unknownbrackets",
          description: "PSP & PS2 CSO compression — ISO ↔ CSO",
          url: "https://github.com/unknownbrackets/maxcso",
          color: Color(red: 0.8, green: 0.4, blue: 0.0)),
    .init(tool: "nsz",
          author: "nicoboss",
          description: "Nintendo Switch compression — NSP/XCI ↔ NSZ/XCZ",
          url: "https://github.com/nicoboss/nsz",
          color: Color(red: 0.9, green: 0.1, blue: 0.1)),
    .init(tool: "7-Zip",
          author: "Igor Pavlov",
          description: "Archive extraction — 7z, ZIP, RAR",
          url: "https://www.7-zip.org",
          color: Color(red: 0.0, green: 0.5, blue: 0.3)),
    .init(tool: "Wiimms ISO Tools",
          author: "Wiimm",
          description: "Wii & GameCube disc management — ISO ↔ WBFS",
          url: "https://wit.wiimm.de",
          color: Color(red: 0.5, green: 0.0, blue: 0.8)),
    .init(tool: "Repackinator",
          author: "Team Resurgent",
          description: "Xbox OG CCI repackaging — ISO → CCI",
          url: "https://github.com/Team-Resurgent/Repackinator",
          color: Color(red: 0.0, green: 0.6, blue: 0.3)),
    .init(tool: "ps3iso-utils",
          author: "bucanero",
          description: "PS3 ISO tools — PS3 folder ↔ ISO (makeps3iso & extractps3iso)",
          url: "https://github.com/bucanero/ps3iso-utils",
          color: Color(red: 0.0, green: 0.45, blue: 0.85)),
    .init(tool: "extract-xiso",
          author: "xboxdev / in2e",
          description: "Xbox OG XISO creation & extraction — folder ↔ XISO",
          url: "https://github.com/xboxdev/extract-xiso",
          color: Color(red: 0.1, green: 0.6, blue: 0.2)),
    .init(tool: "ScreenScraper",
          author: "ScreenScraper.fr",
          description: "Game artwork & metadata — powers the Artwork Scraper",
          url: "https://www.screenscraper.fr",
          color: .purple),
]

// MARK: - CreditsView

struct CreditsView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.pink)
                Text("Built on the shoulders of giants")
                    .font(.title2.bold())
                Text("CHDForge is a front-end. All the real work is done by these outstanding open-source tools and their creators.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()

            // Credits list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(credits) { entry in
                        CreditRow(entry: entry)
                        if entry.id != credits.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Footer
            HStack {
                Text("CHDForge is not affiliated with any of the above projects.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Close") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 520, height: 560)
    }
}

// MARK: - CreditRow

private struct CreditRow: View {
    let entry: CreditEntry

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: 6)
                .fill(entry.color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(entry.color.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    Text(String(entry.tool.prefix(1)))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.color)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.tool)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(entry.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(entry.description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                NSWorkspace.shared.open(URL(string: entry.url)!)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(entry.url)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
