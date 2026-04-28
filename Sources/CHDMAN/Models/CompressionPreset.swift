import Foundation

enum CompressionPreset: String, CaseIterable, Identifiable, Sendable {
    case fast
    case balanced
    case smallest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:
            return "Fast"
        case .balanced:
            return "Balanced"
        case .smallest:
            return "Smallest"
        }
    }

    func detail(for tool: ToolKind) -> String {
        switch (self, tool) {
        case (.fast, .chdman):
            return "Larger files, shorter conversion time"
        case (.balanced, .chdman):
            return "Use chdman defaults"
        case (.smallest, .chdman):
            return "Smaller files, slower conversion"
        case (.fast, .dolphinTool):
            return "zstd level 1 — fast with decent compression"
        case (.balanced, .dolphinTool):
            return "zstd level 5 — good balance (default)"
        case (.smallest, .dolphinTool):
            return "lzma2 level 9 — smallest files, slowest conversion"
        case (.fast, .maxcso):
            return "LZ4 — fastest compression"
        case (.balanced, .maxcso):
            return "zlib — good balance (default)"
        case (.smallest, .maxcso):
            return "zstd — smallest files, slower conversion"
        case (.fast, .nsz):
            return "zstd level 3 — fast compression"
        case (.balanced, .nsz):
            return "zstd level 18 — nsz default"
        case (.smallest, .nsz):
            return "zstd level 22 — maximum compression"
        case (_, .sevenZip):
            return "Not applicable for archive extraction"
        case (.fast, .wit):
            return "No scrubbing — fastest, larger WBFS files"
        case (.balanced, .wit):
            return "Default scrubbing — good balance"
        case (.smallest, .wit):
            return "Aggressive trim — smallest WBFS files"
        case (.fast, .repackinator):
            return "CCI — compressed, no scrubbing"
        case (.balanced, .repackinator):
            return "CCI — compressed + scrub padding"
        case (.smallest, .repackinator):
            return "CCI — compressed + trim scrub (smallest)"
        }
    }

    // MARK: - chdman arguments

    func chdmanArguments(for command: String) -> [String] {
        switch (self, command) {
        case (.balanced, _):
            return []
        case (.fast, "createcd"):
            return ["--compression", "cdzl"]
        case (.fast, "createdvd"):
            return ["--compression", "zlib"]
        case (.smallest, "createcd"):
            return ["--compression", "cdlz,cdzl,cdfl", "--hunksize", "150528"]
        case (.smallest, "createdvd"):
            return ["--compression", "lzma,zlib,huff,flac", "--hunksize", "32768"]
        default:
            return []
        }
    }

    // MARK: - DolphinTool arguments

    var dolphinToolArguments: [String] {
        switch self {
        case .fast:
            return ["-c", "zstd", "-l", "1", "-b", "131072"]
        case .balanced:
            return ["-c", "zstd", "-l", "5", "-b", "131072"]
        case .smallest:
            return ["-c", "lzma2", "-l", "9", "-b", "131072"]
        }
    }

    // MARK: - maxcso arguments

    var maxcsoArguments: [String] {
        switch self {
        case .fast:
            return ["--lz4"]
        case .balanced:
            return []
        case .smallest:
            return ["--zstd"]
        }
    }

    // MARK: - nsz arguments

    // MARK: - wit arguments

    var witArguments: [String] {
        switch self {
        case .fast:
            return ["--no-trim"]
        case .balanced:
            return []
        case .smallest:
            return ["--trim"]
        }
    }

    // MARK: - Repackinator arguments (applied only in create/CCI mode)

    var repackinatorArguments: [String] {
        switch self {
        case .fast:     return []          // CCI only, no scrub
        case .balanced: return ["-s"]      // scrub padding
        case .smallest: return ["-t"]      // trimscrub (scrub + trim)
        }
    }

    // MARK: - nsz arguments

    var nszArguments: [String] {
        switch self {
        case .fast:
            return ["-l", "3"]
        case .balanced:
            return [] // nsz default (level 18)
        case .smallest:
            return ["-l", "22"]
        }
    }
}
