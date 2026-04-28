import Foundation

// MARK: - ToolKind

enum ToolKind: String, CaseIterable, Identifiable, Sendable {
    case chdman      = "chdman"
    case dolphinTool = "dolphin-tool"
    case maxcso      = "maxcso"
    case nsz         = "nsz"
    case sevenZip       = "7z"
    case wit            = "wit"
    case repackinator   = "repackinator"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chdman:      return "CHD (CD/DVD)"
        case .dolphinTool: return "RVZ (GC/Wii)"
        case .maxcso:      return "CSO (PSP/PS2)"
        case .nsz:         return "NSZ (Switch)"
        case .sevenZip:       return "7z (Archives)"
        case .wit:            return "WBFS (Wii/GC)"
        case .repackinator:   return "CCI (Xbox OG)"
        }
    }

    var icon: String {
        switch self {
        case .chdman:      return "opticaldisc"
        case .dolphinTool: return "gamecontroller"
        case .maxcso:      return "externaldrive"
        case .nsz:         return "rectangle.stack"
        case .sevenZip:       return "doc.zipper"
        case .wit:            return "opticaldisc.fill"
        case .repackinator:   return "xmark.seal.fill"
        }
    }

    /// Whether this tool supports Create mode.
    var supportsCreate: Bool {
        switch self {
        case .sevenZip: return false
        default:        return true
        }
    }
}

// MARK: - SourceType

enum SourceType: String, CaseIterable, Hashable, Sendable {
    case iso = "ISO"
    case cue = "CUE"
    case gdi = "GDI"
    case chd = "CHD"
    case gcz = "GCZ"
    case rvz = "RVZ"
    case wia = "WIA"
    case cso = "CSO"
    case nsp = "NSP"
    case xci = "XCI"
    case nsz = "NSZ"
    case xcz = "XCZ"
    case sevenZ = "7Z"
    case zip = "ZIP"
    case rar = "RAR"
    case wbfs = "WBFS"
    case cci  = "CCI"
}

// MARK: - AppMode

enum AppMode: String, CaseIterable, Identifiable, Sendable {
    case create  = "create"
    case extract = "extract"

    var id: String { rawValue }

    func label(for tool: ToolKind) -> String {
        switch self {
        case .create:  return "Create"
        case .extract: return "Extract"
        }
    }

    var icon: String {
        switch self {
        case .create:  return "archivebox.fill"
        case .extract: return "archivebox.circle"
        }
    }
}

// MARK: - JobStatus

enum JobStatus: String, CaseIterable, Hashable, Sendable {
    case pending    = "Pending"
    case converting = "Converting"
    case done       = "Done"
    case failed     = "Failed"
    case skipped    = "Skipped"
    case cancelled  = "Cancelled"
    case paused     = "Paused"

    var color: String {
        switch self {
        case .pending:    return "gray"
        case .converting: return "blue"
        case .done:       return "green"
        case .failed:     return "red"
        case .skipped:    return "orange"
        case .cancelled:  return "purple"
        case .paused:     return "yellow"
        }
    }
}

// MARK: - ConversionJob

@MainActor
final class ConversionJob: ObservableObject, Identifiable {
    private static let maxLogCharacters = 50_000

    let id = UUID()
    let sourceURL: URL
    let sourceType: SourceType
    let outputURL: URL

    @Published var status: JobStatus = .pending
    @Published var detail: String = ""
    @Published var log: String = ""

    var filename: String   { sourceURL.lastPathComponent }
    var path: String       { sourceURL.path }
    var outputPath: String { outputURL.path }

    init(sourceURL: URL, sourceType: SourceType, outputURL: URL) {
        self.sourceURL  = sourceURL
        self.sourceType = sourceType
        self.outputURL  = outputURL
    }

    func appendLog(_ text: String) {
        log.appendCappedLine(text.trimmingCharacters(in: .newlines), limit: Self.maxLogCharacters)
    }
}
