//
//  SpotifyAPIClient.swift
//  Retune
//
//  NOTE: Spotify Web API track access requires Extended Quota Mode, which
//  requires a registered business entity. Playlist listing works in
//  Development Mode but fetching tracks does not. This implementation is
//  complete and ready to enable once quota extension is granted.
//

import Foundation

@MainActor
final class SpotifyAPIClient {

    static let shared = SpotifyAPIClient()
    private init() {}

    private let base = "https://api.spotify.com/v1"

    // MARK: - Auth header

    private func authorizedRequest(for urlString: String, method: String = "GET", body: Data? = nil) async throws -> URLRequest {
        guard let token = await SpotifyAuthManager.shared.validAccessToken else {
            throw SpotifyError.notAuthenticated
        }
        guard let url = URL(string: urlString) else {
            throw SpotifyError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    // MARK: - Response validator

    private func validate(_ data: Data, _ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 401:       throw SpotifyError.unauthorized
        case 403:       throw SpotifyError.forbidden
        case 429:       throw SpotifyError.rateLimited
        default:
            throw SpotifyError.httpError(http.statusCode)
        }
    }

    // MARK: - Fetch playlists

    func fetchPlaylists() async throws -> [SpotifyPlaylist] {
        var playlists: [SpotifyPlaylist] = []
        var nextURL: String? = "\(base)/me/playlists?limit=50"

        while let urlString = nextURL {
            let request          = try await authorizedRequest(for: urlString)
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(data, response)
            let decoded = try JSONDecoder().decode(SpotifyPagingResponse<SpotifyPlaylist>.self, from: data)
            playlists.append(contentsOf: decoded.items)
            nextURL = decoded.next
        }

        return playlists
    }

    // MARK: - Fetch tracks
    // NOTE: Returns 403 in Development Mode due to Spotify quota restrictions.
    // Will work once app has Extended Quota Mode (requires business entity).

    func fetchTracks(playlistID: String) async throws -> [Song] {
        var songs: [Song] = []
        var nextURL: String? = "\(base)/playlists/\(playlistID)/tracks?limit=100"

        while let urlString = nextURL {
            let request          = try await authorizedRequest(for: urlString)
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(data, response)
            let decoded = try JSONDecoder().decode(SpotifyPagingResponse<SpotifyTrackItem>.self, from: data)

            let batch = decoded.items.compactMap { item -> Song? in
                guard let track = item.track, !track.id.isEmpty else { return nil }
                let artworkURL = track.album?.images.first?.url.flatMap { URL(string: $0) }
                let previewURL = track.preview_url.flatMap { URL(string: $0) }
                return Song(
                    title:       track.name,
                    artist:      track.artists.first?.name ?? "Unknown Artist",
                    artworkURL:  artworkURL,
                    previewURL:  previewURL,
                    musicItemID: track.id
                )
            }

            songs.append(contentsOf: batch)
            nextURL = decoded.next
        }

        return songs
    }

    // MARK: - User ID

    func fetchUserID() async throws -> String {
        let request          = try await authorizedRequest(for: "\(base)/me")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data, response)
        return try JSONDecoder().decode(SpotifyUser.self, from: data).id
    }

    // MARK: - Create playlist

    func createPlaylist(name: String, description: String) async throws -> String {
        let userID           = try await fetchUserID()
        let body             = try JSONEncoder().encode(SpotifyCreatePlaylistBody(name: name, description: description))
        let request          = try await authorizedRequest(for: "\(base)/users/\(userID)/playlists", method: "POST", body: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data, response)
        return try JSONDecoder().decode(SpotifyPlaylist.self, from: data).id
    }

    // MARK: - Add tracks to playlist

    func addTracks(playlistID: String, trackIDs: [String]) async throws {
        let batchSize = 100
        for batchStart in stride(from: 0, to: trackIDs.count, by: batchSize) {
            let batch   = Array(trackIDs[batchStart..<min(batchStart + batchSize, trackIDs.count)])
            let uris    = batch.map { "spotify:track:\($0)" }
            let body    = try JSONEncoder().encode(SpotifyAddTracksBody(uris: uris))
            let request = try await authorizedRequest(
                for: "\(base)/playlists/\(playlistID)/tracks",
                method: "POST",
                body: body
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(data, response)
        }
    }

    // MARK: - Save playlist (full flow)

    func savePlaylist(name: String, keptSongs: [Song]) async throws -> String {
        let description = "Curated with Retune on \(Date().formatted(date: .abbreviated, time: .omitted))"
        let playlistID  = try await createPlaylist(name: name, description: description)
        let trackIDs    = keptSongs.compactMap { $0.musicItemID }
        guard !trackIDs.isEmpty else { throw SpotifyError.noValidTracks }
        try await addTracks(playlistID: playlistID, trackIDs: trackIDs)
        return playlistID
    }
}

// MARK: - Errors

enum SpotifyError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case unauthorized
    case forbidden
    case rateLimited
    case failedToAddTracks
    case noValidTracks
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in to Spotify."
        case .invalidURL:
            return "Invalid Spotify API URL."
        case .unauthorized:
            return "Your Spotify session expired. Please reconnect in Profile."
        case .forbidden:
            return "Spotify track access isn't available yet. We're working on it."
        case .rateLimited:
            return "Too many requests to Spotify. Please wait a moment and try again."
        case .failedToAddTracks:
            return "Couldn't add tracks to the playlist."
        case .noValidTracks:
            return "None of the kept songs have valid Spotify IDs."
        case .httpError(let code):
            return "Spotify returned an unexpected error (code \(code))."
        }
    }
}

// MARK: - API Models

struct SpotifyPagingResponse<T: Decodable>: Decodable {
    let items: [T]
    let next:  String?
}

struct SpotifyPlaylist: Decodable, Identifiable {
    let id:     String
    let name:   String
    let images: [SpotifyImage]

    init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        id     = try c.decode(String.self, forKey: .id)
        name   = try c.decode(String.self, forKey: .name)
        images = (try? c.decodeIfPresent([SpotifyImage].self, forKey: .images)) ?? []
    }

    enum CodingKeys: String, CodingKey { case id, name, images }
    var artworkURL: URL? { images.first?.url.flatMap { URL(string: $0) } }
}

struct SpotifyImage: Decodable {
    let url: String?
}

struct SpotifyTrackItem: Decodable {
    let track: SpotifyTrack?
}

struct SpotifyTrack: Decodable {
    let id:          String
    let name:        String
    let artists:     [SpotifyArtist]
    let album:       SpotifyAlbum?
    let preview_url: String?

    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        artists     = (try? c.decodeIfPresent([SpotifyArtist].self, forKey: .artists)) ?? []
        album       = try? c.decodeIfPresent(SpotifyAlbum.self,     forKey: .album)
        preview_url = try? c.decodeIfPresent(String.self,           forKey: .preview_url)
    }

    enum CodingKeys: String, CodingKey { case id, name, artists, album, preview_url }
}

struct SpotifyArtist: Decodable {
    let name: String
}

struct SpotifyAlbum: Decodable {
    let images: [SpotifyImage]

    init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        images = (try? c.decodeIfPresent([SpotifyImage].self, forKey: .images)) ?? []
    }

    enum CodingKeys: String, CodingKey { case images }
}

struct SpotifyUser: Decodable {
    let id: String
}

struct SpotifyCreatePlaylistBody: Encodable {
    let name:        String
    let description: String
    let isPublic:    Bool = false

    enum CodingKeys: String, CodingKey {
        case name, description
        case isPublic = "public"
    }
}

struct SpotifyAddTracksBody: Encodable {
    let uris: [String]
}
