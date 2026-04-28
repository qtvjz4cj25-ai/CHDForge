import Foundation

/// Writes and updates gamelist.xml files in EmulationStation / ES-DE format.
struct GamelistWriter {

    // MARK: - Public API

    /// Write or merge results into a gamelist.xml at the given folder.
    /// Existing entries for other games are preserved.
    static func write(
        results: [ScrapeResult],
        to folder: URL,
        format: ScrapeOutputFormat,
        system: SSSystem
    ) throws {
        switch format {
        case .emulationStation:
            try writeES(results: results, to: folder)
        case .esDe:
            try writeESDe(results: results, to: folder, system: system)
        case .imagesOnly:
            break  // no XML written
        }
    }

    // MARK: - EmulationStation / Batocera

    private static func writeES(results: [ScrapeResult], to folder: URL) throws {
        let gamelistURL = folder.appendingPathComponent("gamelist.xml")

        // Load existing entries so we don't overwrite games we didn't scrape
        var existingEntries: [String: String] = [:]
        if let existing = try? String(contentsOf: gamelistURL, encoding: .utf8) {
            existingEntries = parseExistingEntries(existing)
        }

        // Build new entries, overwriting existing ones for files we scraped
        for result in results {
            existingEntries[result.fileURL.lastPathComponent] = esGameEntry(result: result, folder: folder)
        }

        let xml = buildGamelistXML(entries: existingEntries.values.sorted())
        try xml.write(to: gamelistURL, atomically: true, encoding: .utf8)
    }

    private static func esGameEntry(result: ScrapeResult, folder: URL) -> String {
        let relPath = "./\(result.fileURL.lastPathComponent)"
        let stem = result.fileURL.deletingPathExtension().lastPathComponent

        var entry = "  <game>\n"
        entry += "    <path>\(escapeXML(relPath))</path>\n"
        entry += "    <name>\(escapeXML(result.gameName))</name>\n"

        if let desc = result.description.nilIfEmpty {
            entry += "    <desc>\(escapeXML(desc))</desc>\n"
        }

        // Media paths relative to ROM folder
        for (mediaType, mediaURL) in result.mediaFiles.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let mediaFolder = mediaType.esFolder
            let ext = mediaURL.pathExtension
            let relMedia = "./\(mediaFolder)/\(stem).\(ext)"
            entry += "    <\(mediaType.xmlTag)>\(escapeXML(relMedia))</\(mediaType.xmlTag)>\n"
        }

        if let rating = result.rating {
            entry += "    <rating>\(String(format: "%.2f", rating))</rating>\n"
        }
        if let date = result.releaseDate {
            entry += "    <releasedate>\(escapeXML(date))</releasedate>\n"
        }
        if let dev = result.developer?.nilIfEmpty {
            entry += "    <developer>\(escapeXML(dev))</developer>\n"
        }
        if let pub = result.publisher?.nilIfEmpty {
            entry += "    <publisher>\(escapeXML(pub))</publisher>\n"
        }
        if let genre = result.genre?.nilIfEmpty {
            entry += "    <genre>\(escapeXML(genre))</genre>\n"
        }
        if let players = result.players?.nilIfEmpty {
            entry += "    <players>\(escapeXML(players))</players>\n"
        }

        entry += "  </game>"
        return entry
    }

    // MARK: - ES-DE

    private static func writeESDe(results: [ScrapeResult], to folder: URL, system: SSSystem) throws {
        // ES-DE stores media outside the ROM folder in downloaded_media/<system>/
        // The gamelist.xml goes in the ROM folder, with absolute or ~ paths
        let gamelistURL = folder.appendingPathComponent("gamelist.xml")

        var existingEntries: [String: String] = [:]
        if let existing = try? String(contentsOf: gamelistURL, encoding: .utf8) {
            existingEntries = parseExistingEntries(existing)
        }

        for result in results {
            existingEntries[result.fileURL.lastPathComponent] = esDeGameEntry(result: result, folder: folder, system: system)
        }

        let xml = buildGamelistXML(entries: existingEntries.values.sorted())
        try xml.write(to: gamelistURL, atomically: true, encoding: .utf8)
    }

    private static func esDeGameEntry(result: ScrapeResult, folder: URL, system: SSSystem) -> String {
        let relPath = "./\(result.fileURL.lastPathComponent)"
        let stem = result.fileURL.deletingPathExtension().lastPathComponent

        var entry = "  <game>\n"
        entry += "    <path>\(escapeXML(relPath))</path>\n"
        entry += "    <name>\(escapeXML(result.gameName))</name>\n"

        if let desc = result.description.nilIfEmpty {
            entry += "    <desc>\(escapeXML(desc))</desc>\n"
        }

        for (mediaType, mediaURL) in result.mediaFiles.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let ext = mediaURL.pathExtension
            // ES-DE uses ~/.emulationstation/downloaded_media/<system>/<type>/<stem>.<ext>
            let esDeMedia = "~/.emulationstation/downloaded_media/\(system.shortName)/\(mediaType.esDeName)/\(stem).\(ext)"
            entry += "    <\(mediaType.xmlTag)>\(escapeXML(esDeMedia))</\(mediaType.xmlTag)>\n"
        }

        if let rating = result.rating {
            entry += "    <rating>\(String(format: "%.2f", rating))</rating>\n"
        }
        if let date = result.releaseDate {
            entry += "    <releasedate>\(escapeXML(date))</releasedate>\n"
        }
        if let dev = result.developer?.nilIfEmpty {
            entry += "    <developer>\(escapeXML(dev))</developer>\n"
        }
        if let pub = result.publisher?.nilIfEmpty {
            entry += "    <publisher>\(escapeXML(pub))</publisher>\n"
        }
        if let genre = result.genre?.nilIfEmpty {
            entry += "    <genre>\(escapeXML(genre))</genre>\n"
        }
        if let players = result.players?.nilIfEmpty {
            entry += "    <players>\(escapeXML(players))</players>\n"
        }

        entry += "  </game>"
        return entry
    }

    // MARK: - Helpers

    private static func buildGamelistXML(entries: [String]) -> String {
        var xml = "<?xml version=\"1.0\"?>\n<gameList>\n"
        xml += entries.joined(separator: "\n")
        if !entries.isEmpty { xml += "\n" }
        xml += "</gameList>\n"
        return xml
    }

    /// Crude but effective parser: extracts <path> → full <game>…</game> block mapping.
    private static func parseExistingEntries(_ xml: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = #"<game>.*?</game>"#
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                    options: [.dotMatchesLineSeparators]) else {
            return result
        }
        let ns = xml as NSString
        for match in regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml)) {
            let block = ns.substring(with: match.range)
            // Extract the filename from <path>./filename.ext</path>
            if let pathRange = block.range(of: "<path>"),
               let endRange  = block.range(of: "</path>") {
                let pathContent = String(block[pathRange.upperBound..<endRange.lowerBound])
                let filename = URL(fileURLWithPath: pathContent).lastPathComponent
                result[filename] = block.trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }

    private static func escapeXML(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'",  with: "&apos;")
    }

    // MARK: - ES release date conversion

    /// Converts "YYYY-MM-DD" or "YYYY" to ES format "YYYYMMDDTHHMMSS".
    static func convertDate(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let clean = raw.prefix(10).trimmingCharacters(in: .whitespaces)
        // Already in correct format
        if clean.count == 8 && !clean.contains("-") { return "\(clean)T000000" }
        // YYYY-MM-DD
        if clean.count == 10 {
            let parts = clean.split(separator: "-")
            if parts.count == 3 {
                return "\(parts[0])\(parts[1])\(parts[2])T000000"
            }
        }
        // YYYY only
        if clean.count == 4 { return "\(clean)0101T000000" }
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
