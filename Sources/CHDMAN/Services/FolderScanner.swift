import Foundation

/// Scans a directory tree for supported disc-image source files and produces
/// a deduplicated list of ConversionJob objects.
struct FolderScanner: Sendable {

    /// Runs file-system enumeration off the main thread, then creates the
    /// @MainActor ConversionJob objects back on the main actor.
    @MainActor
    func scan(folder: URL, recursive: Bool, tool: ToolKind, mode: AppMode) async -> [ConversionJob] {
        let found: [(URL, SourceType)] = await Task.detached(priority: .userInitiated) {
            Self.enumerateFiles(folder: folder, recursive: recursive, tool: tool, mode: mode)
        }.value

        return found.map { (url, type) in
            let output: URL
            switch (tool, mode) {
            case (.chdman, .create):
                output = url.deletingPathExtension().appendingPathExtension("chd")
            case (.chdman, .extract):
                output = url.deletingPathExtension().appendingPathExtension("bin")
            case (.dolphinTool, .create):
                output = url.deletingPathExtension().appendingPathExtension("rvz")
            case (.dolphinTool, .extract):
                output = url.deletingPathExtension().appendingPathExtension("iso")
            case (.maxcso, .create):
                output = url.deletingPathExtension().appendingPathExtension("cso")
            case (.maxcso, .extract):
                output = url.deletingPathExtension().appendingPathExtension("iso")
            case (.nsz, .create):
                // NSP → NSZ, XCI → XCZ
                let ext = url.pathExtension.lowercased() == "xci" ? "xcz" : "nsz"
                output = url.deletingPathExtension().appendingPathExtension(ext)
            case (.nsz, .extract):
                // NSZ → NSP, XCZ → XCI
                let ext = url.pathExtension.lowercased() == "xcz" ? "xci" : "nsp"
                output = url.deletingPathExtension().appendingPathExtension(ext)
            case (.sevenZip, .extract):
                // Archive → directory named after the archive (no extension)
                output = url.deletingPathExtension()
            case (.sevenZip, .create):
                // 7z only supports extract; this case shouldn't occur
                output = url.deletingPathExtension().appendingPathExtension("7z")
            case (.wit, .create):
                output = url.deletingPathExtension().appendingPathExtension("wbfs")
            case (.wit, .extract):
                output = url.deletingPathExtension().appendingPathExtension("iso")
            case (.repackinator, .create):
                output = url.deletingPathExtension().appendingPathExtension("cci")
            case (.repackinator, .extract):
                output = url.deletingPathExtension().appendingPathExtension("iso")
            case (.makeps3iso, .create):
                // Source is a directory — output ISO sits next to the folder
                output = url.appendingPathExtension("iso")
            case (.makeps3iso, .extract):
                // Not supported; shouldn't occur
                output = url.deletingPathExtension()
            }
            return ConversionJob(sourceURL: url, sourceType: type, outputURL: output)
        }
    }

    // MARK: - Pure FS enumeration (no UI objects, Sendable context)

    private static func enumerateFiles(
        folder: URL,
        recursive: Bool,
        tool: ToolKind,
        mode: AppMode
    ) -> [(URL, SourceType)] {
        let fm = FileManager.default
        let skipOptions: FileManager.DirectoryEnumerationOptions = recursive
            ? [.skipsHiddenFiles, .skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]

        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: skipOptions
        ) else { return [] }

        var results: [(URL, SourceType)] = []
        var seen: Set<String> = []

        let extensions: Set<String>
        // PS3 folder scanning is directory-based — handled separately
        if tool == .makeps3iso && mode == .create {
            return enumeratePS3GameFolders(folder: folder, recursive: recursive)
        }

        switch (tool, mode) {
        case (.chdman, .create):       extensions = ["iso", "cue", "gdi"]
        case (.chdman, .extract):      extensions = ["chd"]
        case (.dolphinTool, .create):  extensions = ["iso", "gcz", "wia"]
        case (.dolphinTool, .extract): extensions = ["rvz", "wia", "gcz"]
        case (.maxcso, .create):       extensions = ["iso"]
        case (.maxcso, .extract):      extensions = ["cso"]
        case (.nsz, .create):          extensions = ["nsp", "xci"]
        case (.nsz, .extract):         extensions = ["nsz", "xcz"]
        case (.sevenZip, .extract):    extensions = ["7z", "zip", "rar"]
        case (.sevenZip, .create):     extensions = []
        case (.wit, .create):          extensions = ["iso"]
        case (.wit, .extract):         extensions = ["wbfs"]
        case (.repackinator, .create): extensions = ["iso"]
        case (.repackinator, .extract):extensions = ["cci"]
        case (.makeps3iso, _):         extensions = []
        }

        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            else { continue }

            let ext = url.pathExtension.lowercased()
            guard extensions.contains(ext) else { continue }

            let type: SourceType
            switch ext {
            case "iso": type = .iso
            case "cue": type = .cue
            case "gdi": type = .gdi
            case "chd": type = .chd
            case "gcz": type = .gcz
            case "rvz": type = .rvz
            case "wia": type = .wia
            case "cso": type = .cso
            case "nsp": type = .nsp
            case "xci": type = .xci
            case "nsz": type = .nsz
            case "xcz": type = .xcz
            case "7z":  type = .sevenZ
            case "zip": type = .zip
            case "rar": type = .rar
            case "wbfs": type = .wbfs
            case "cci":  type = .cci
            default:     continue
            }

            let key = url.standardizedFileURL.path
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            results.append((url, type))
        }

        results.sort {
            let orderA = sortKey($0.1), orderB = sortKey($1.1)
            if orderA != orderB { return orderA < orderB }
            return $0.0.path < $1.0.path
        }
        return results
    }

    private static func sortKey(_ t: SourceType) -> Int {
        switch t {
        case .iso: return 0
        case .cue: return 1
        case .gdi: return 2
        case .chd: return 3
        case .gcz: return 4
        case .wia: return 5
        case .rvz: return 6
        case .cso: return 7
        case .nsp: return 8
        case .xci: return 9
        case .nsz: return 10
        case .xcz: return 11
        case .sevenZ: return 12
        case .zip: return 13
        case .rar: return 14
        case .wbfs:   return 15
        case .cci:    return 16
        case .ps3dir: return 17
        }
    }

    // MARK: - PS3 game folder enumeration

    /// Scans for subdirectories containing PS3_GAME/PARAM.SFO — these are PS3 JB game folders.
    private static func enumeratePS3GameFolders(folder: URL, recursive: Bool) -> [(URL, SourceType)] {
        let fm = FileManager.default
        var results: [(URL, SourceType)] = []
        var seen: Set<String> = []

        func scanLevel(_ dir: URL, depth: Int) {
            guard let children = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            for child in children.sorted(by: { $0.path < $1.path }) {
                guard (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                else { continue }

                // Check if this directory is a PS3 game folder
                let paramSfo = child.appendingPathComponent("PS3_GAME/PARAM.SFO")
                if fm.fileExists(atPath: paramSfo.path) {
                    let key = child.standardizedFileURL.path
                    if !seen.contains(key) {
                        seen.insert(key)
                        results.append((child, .ps3dir))
                    }
                } else if recursive && depth < 4 {
                    scanLevel(child, depth: depth + 1)
                }
            }
        }

        scanLevel(folder, depth: 0)
        return results
    }
}
