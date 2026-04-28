import Foundation
import CryptoKit

// MARK: - Errors

enum ScreenScraperError: LocalizedError {
    case notFound
    case rateLimited
    case authFailed
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:           return "Game not found in ScreenScraper database."
        case .rateLimited:        return "ScreenScraper rate limit reached. Wait a moment and try again."
        case .authFailed:         return "ScreenScraper authentication failed. Check your username and password in Settings."
        case .apiError(let msg):  return "ScreenScraper API error: \(msg)"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        }
    }
}

// MARK: - Client

/// Async client for the ScreenScraper API v2.
/// Register a free account at screenscraper.fr to get higher rate limits.
struct ScreenScraperClient {

    private let baseURL = "https://www.screenscraper.fr/api2"
    private let softName = "CHDForge"
    // Developer credentials — register at screenscraper.fr/forumsujets.php?topic=devapi
    private let devID       = ""   // leave blank; users can register their own
    private let devPassword = ""

    let username: String
    let password: String  // stored as-is; hashed when sending

    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }

    // MARK: - Game lookup

    /// Look up a game by MD5 hash and optionally filename. Falls back to filename only.
    func lookupGame(
        md5: String,
        filename: String,
        systemID: Int
    ) async throws -> SSGame {
        var components = URLComponents(string: "\(baseURL)/jeuInfos.php")!
        components.queryItems = authParams() + [
            URLQueryItem(name: "systemeid", value: "\(systemID)"),
            URLQueryItem(name: "romnom",    value: filename),
            URLQueryItem(name: "rommd5",    value: md5),
            URLQueryItem(name: "output",    value: "json"),
        ]

        let data = try await fetch(components.url!)
        return try parseGame(from: data)
    }

    /// Look up a game by filename only (no hash). Less accurate but faster.
    func lookupByFilename(filename: String, systemID: Int) async throws -> SSGame {
        var components = URLComponents(string: "\(baseURL)/jeuInfos.php")!
        components.queryItems = authParams() + [
            URLQueryItem(name: "systemeid", value: "\(systemID)"),
            URLQueryItem(name: "romnom",    value: filename),
            URLQueryItem(name: "output",    value: "json"),
        ]

        let data = try await fetch(components.url!)
        return try parseGame(from: data)
    }

    // MARK: - Media download

    /// Download a media URL to a local file path. Returns the saved URL.
    func downloadMedia(from url: URL, to destination: URL) async throws {
        let (tmpURL, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ScreenScraperError.apiError("Media download failed")
        }
        let fm = FileManager.default
        try? fm.removeItem(at: destination)
        try fm.createDirectory(at: destination.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        try fm.moveItem(at: tmpURL, to: destination)
    }

    // MARK: - MD5 hashing

    /// Compute MD5 of a file. Reads in chunks to handle large ROMs.
    static func md5(of fileURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            var hasher = Insecure.MD5()
            let chunkSize = 4 * 1024 * 1024  // 4 MB chunks

            while true {
                guard let chunk = try handle.read(upToCount: chunkSize),
                      !chunk.isEmpty else { break }
                hasher.update(data: chunk)
            }

            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }

    // MARK: - Helpers

    private func authParams() -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "devid",       value: devID),
            URLQueryItem(name: "devpassword", value: devPassword),
            URLQueryItem(name: "softname",    value: softName),
            URLQueryItem(name: "output",      value: "json"),
        ]
        if !username.isEmpty {
            items += [
                URLQueryItem(name: "ssid",       value: username),
                URLQueryItem(name: "sspassword", value: md5String(password)),
            ]
        }
        return items
    }

    private func md5String(_ string: String) -> String {
        let data = Data(string.utf8)
        return Insecure.MD5.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func fetch(_ url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw ScreenScraperError.apiError("Non-HTTP response")
            }
            switch http.statusCode {
            case 200:      return data
            case 401, 403: throw ScreenScraperError.authFailed
            case 429:      throw ScreenScraperError.rateLimited
            case 404:      throw ScreenScraperError.notFound
            default:
                let body = String(data: data, encoding: .utf8) ?? ""
                throw ScreenScraperError.apiError("HTTP \(http.statusCode): \(body.prefix(200))")
            }
        } catch let error as ScreenScraperError {
            throw error
        } catch {
            throw ScreenScraperError.networkError(error)
        }
    }

    private func parseGame(from data: Data) throws -> SSGame {
        let decoder = JSONDecoder()
        let response: SSResponse
        do {
            response = try decoder.decode(SSResponse.self, from: data)
        } catch {
            // ScreenScraper sometimes returns plain error text instead of JSON
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.contains("Erreur") || body.contains("error") {
                if body.lowercased().contains("non trouvé") || body.lowercased().contains("not found") {
                    throw ScreenScraperError.notFound
                }
                throw ScreenScraperError.apiError(String(body.prefix(200)))
            }
            throw ScreenScraperError.apiError("JSON decode error: \(error.localizedDescription)")
        }

        guard response.header.isSuccess else {
            let msg = response.header.error ?? "Unknown error"
            if msg.lowercased().contains("non trouvé") || msg.lowercased().contains("not found") {
                throw ScreenScraperError.notFound
            }
            if msg.lowercased().contains("identifiants") || msg.lowercased().contains("password") {
                throw ScreenScraperError.authFailed
            }
            throw ScreenScraperError.apiError(msg)
        }

        guard let game = response.response?.jeu else {
            throw ScreenScraperError.notFound
        }

        return game
    }
}
