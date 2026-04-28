import Foundation

// MARK: - System Registry

/// ScreenScraper system IDs for each supported platform.
struct SSSystem: Identifiable, Hashable {
    let id: Int
    let name: String
    let shortName: String  // used in ES-DE media folder names
}

extension SSSystem {
    static let all: [SSSystem] = [
        // Sony
        SSSystem(id: 57,  name: "PlayStation",          shortName: "psx"),
        SSSystem(id: 58,  name: "PlayStation 2",        shortName: "ps2"),
        SSSystem(id: 69,  name: "PlayStation 3",        shortName: "ps3"),
        SSSystem(id: 61,  name: "PlayStation Portable", shortName: "psp"),
        // Sega
        SSSystem(id: 23,  name: "Dreamcast",            shortName: "dreamcast"),
        SSSystem(id: 22,  name: "Saturn",               shortName: "saturn"),
        SSSystem(id: 1,   name: "Mega Drive / Genesis", shortName: "megadrive"),
        SSSystem(id: 20,  name: "Mega CD",              shortName: "megacd"),
        SSSystem(id: 31,  name: "32X",                  shortName: "sega32x"),
        // Nintendo
        SSSystem(id: 3,   name: "NES / Famicom",        shortName: "nes"),
        SSSystem(id: 4,   name: "Super Nintendo",       shortName: "snes"),
        SSSystem(id: 14,  name: "Nintendo 64",          shortName: "n64"),
        SSSystem(id: 13,  name: "GameCube",             shortName: "gc"),
        SSSystem(id: 16,  name: "Wii",                  shortName: "wii"),
        SSSystem(id: 18,  name: "Wii U",                shortName: "wiiu"),
        SSSystem(id: 225, name: "Nintendo Switch",      shortName: "switch"),
        SSSystem(id: 9,   name: "Game Boy",             shortName: "gb"),
        SSSystem(id: 10,  name: "Game Boy Color",       shortName: "gbc"),
        SSSystem(id: 12,  name: "Game Boy Advance",     shortName: "gba"),
        SSSystem(id: 15,  name: "Nintendo DS",          shortName: "nds"),
        SSSystem(id: 17,  name: "Nintendo 3DS",         shortName: "3ds"),
        // Other
        SSSystem(id: 75,  name: "PC Engine / TurboGrafx-16", shortName: "pcengine"),
        SSSystem(id: 40,  name: "Neo Geo",              shortName: "neogeo"),
        SSSystem(id: 36,  name: "Atari 2600",           shortName: "atari2600"),
        SSSystem(id: 76,  name: "Atari 5200",           shortName: "atari5200"),
        SSSystem(id: 78,  name: "Atari 7800",           shortName: "atari7800"),
        SSSystem(id: 104, name: "Atari Jaguar",         shortName: "jaguar"),
        SSSystem(id: 29,  name: "3DO",                  shortName: "3do"),
        SSSystem(id: 109, name: "Arcade (MAME)",        shortName: "mame"),
    ]
}

// MARK: - Output format

enum ScrapeOutputFormat: String, CaseIterable, Identifiable {
    case emulationStation = "EmulationStation / Batocera"
    case esDe             = "ES-DE"
    case imagesOnly       = "Images Only (no XML)"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .emulationStation:
            return "Creates gamelist.xml with box art in an images/ subfolder. Compatible with EmulationStation, Batocera, RetroPie."
        case .esDe:
            return "Creates gamelist.xml with media in ES-DE's downloaded_media structure."
        case .imagesOnly:
            return "Downloads box art only — no XML generated. Use if you manage metadata elsewhere."
        }
    }
}

// MARK: - Media types to download

enum ScrapeMediaType: String, CaseIterable, Identifiable {
    case boxArt    = "Box Art"
    case screenshot = "Screenshot"
    case wheel     = "Wheel / Logo"
    case fanart    = "Fanart"

    var id: String { rawValue }

    /// The ScreenScraper `type` value for this media kind.
    var ssTypes: [String] {
        switch self {
        case .boxArt:     return ["box-2D", "box-2D-back", "box-3D"]
        case .screenshot: return ["screenshot"]
        case .wheel:      return ["wheel", "wheel-hd", "wheel-carbon"]
        case .fanart:     return ["fanart"]
        }
    }

    /// Subfolder name used in gamelist output (ES standard).
    var esFolder: String {
        switch self {
        case .boxArt:     return "images"
        case .screenshot: return "screenshots"
        case .wheel:      return "marquees"
        case .fanart:     return "fanart"
        }
    }

    /// ES-DE media type name used in its downloaded_media folder structure.
    var esDeName: String {
        switch self {
        case .boxArt:     return "covers"
        case .screenshot: return "screenshots"
        case .wheel:      return "marquees"
        case .fanart:     return "fanart"
        }
    }

    /// gamelist.xml tag name.
    var xmlTag: String {
        switch self {
        case .boxArt:     return "image"
        case .screenshot: return "thumbnail"
        case .wheel:      return "marquee"
        case .fanart:     return "fanart"
        }
    }
}

// MARK: - Scrape job status

enum ScrapeStatus: Equatable {
    case pending
    case hashing
    case searching
    case downloading
    case done
    case notFound
    case failed(String)
    case skipped  // output already exists
}

// MARK: - Scrape job

@MainActor
final class ScrapeJob: ObservableObject, Identifiable {
    let id = UUID()
    let fileURL: URL
    var name: String { fileURL.deletingPathExtension().lastPathComponent }

    @Published var status: ScrapeStatus = .pending
    @Published var gameName: String = ""
    @Published var detail: String = ""

    init(fileURL: URL) {
        self.fileURL = fileURL
    }
}

// MARK: - ScreenScraper API response models

struct SSResponse: Decodable {
    let header: SSHeader
    let response: SSResponseBody?
}

struct SSHeader: Decodable {
    let success: String
    let error: String?
    let ssusername: String?

    var isSuccess: Bool { success == "true" }
}

struct SSResponseBody: Decodable {
    let jeu: SSGame?
}

struct SSGame: Decodable {
    let id: String?
    let noms: [SSLocalizedText]?
    let synopsis: [SSLocalizedText]?
    let dates: [SSLocalizedText]?
    let developpeur: SSSimpleText?
    let editeur: SSSimpleText?
    let genres: [SSGenre]?
    let joueurs: SSSimpleText?
    let note: SSSimpleText?
    let medias: [SSMedia]?

    /// Best display name (world → US → first available)
    func bestName(preferLanguage lang: String = "en") -> String? {
        guard let noms else { return nil }
        return noms.first(where: { $0.region == "wor" })?.text
            ?? noms.first(where: { $0.region == "us"  })?.text
            ?? noms.first?.text
    }

    func bestSynopsis(lang: String = "en") -> String? {
        synopsis?.first(where: { $0.langue == lang })?.text
            ?? synopsis?.first?.text
    }

    func bestDate() -> String? {
        dates?.first(where: { $0.region == "wor" })?.text
            ?? dates?.first?.text
    }

    /// Rating as 0.0–1.0 from "XX/20" or "X.X" format.
    func normalizedRating() -> Double? {
        guard let raw = note?.text else { return nil }
        if raw.contains("/") {
            let parts = raw.split(separator: "/")
            if let n = Double(parts[0]), let d = Double(parts[1]), d > 0 {
                return n / d
            }
        }
        return Double(raw)
    }

    /// First genre name in the given language.
    func firstGenre(lang: String = "en") -> String? {
        genres?.first?.noms?.first(where: { $0.langue == lang })?.text
            ?? genres?.first?.noms?.first?.text
    }

    /// Media URL for the given ScreenScraper type names, preferring a region.
    func mediaURL(types: [String], preferRegion: String = "wor") -> URL? {
        guard let medias else { return nil }
        for type_ in types {
            let matches = medias.filter { $0.type == type_ }
            if let preferred = matches.first(where: { $0.region == preferRegion }) {
                return URL(string: preferred.url)
            }
            if let first = matches.first {
                return URL(string: first.url)
            }
        }
        return nil
    }

    func mediaFormat(types: [String]) -> String {
        guard let medias else { return "png" }
        for type_ in types {
            if let m = medias.first(where: { $0.type == type_ }) {
                return m.format ?? "png"
            }
        }
        return "png"
    }
}

struct SSLocalizedText: Decodable {
    let region: String?
    let langue: String?
    let text: String
}

struct SSSimpleText: Decodable {
    let text: String
}

struct SSGenre: Decodable {
    let noms: [SSLocalizedText]?
}

struct SSMedia: Decodable {
    let type: String
    let url: String
    let region: String?
    let format: String?
}

// MARK: - Scrape result (in-memory, used to write gamelist)

struct ScrapeResult {
    let fileURL: URL
    let gameName: String
    let description: String
    let releaseDate: String?    // "YYYYMMDDTHHMMSS" (ES format)
    let developer: String?
    let publisher: String?
    let genre: String?
    let players: String?
    let rating: Double?
    var mediaFiles: [ScrapeMediaType: URL] = [:]  // local saved paths
}
