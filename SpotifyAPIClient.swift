//
//  SpotifyAPIClient.swift
//  Retune
//
//  Created by Eliase Osmani on 4/6/26.
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

    // MARK: - Fetch playlists

    func fetchPlaylists() async throws -> [SpotifyPlaylist] {
        // Temporary — find out which account we're authenticated as
        let meRequest = try await authorizedRequest(for: "\(base)/me")
        let (meData, _) = try await URLSession.shared.data(for: meRequest)
        print("🎵 Spotify me response:", String(data: meData, encoding: .utf8) ?? "unreadable")

        var playlists: [SpotifyPlaylist] = []
        var nextURL: String? = "\(base)/me/playlists?limit=50"

        while let urlString = nextURL {
            let request   = try await authorizedRequest(for: urlString)
            let (data, _) = try await URLSession.shared.data(for: request)

            print("🎵 Spotify playlists response:", String(data: data, encoding: .utf8) ?? "unreadable")

            let response = try JSONDecoder().decode(SpotifyPagingResponse<SpotifyPlaylist>.self, from: data)

            print("🎵 Playlist count:", response.items.count)
            print("🎵 First few:", response.items.prefix(3).map(\.name))

            playlists.append(contentsOf: response.items)
            nextURL = response.next
        }

        return playlists
    }

    // MARK: - Fetch tracks for a playlist

    func fetchTracks(playlistID: String) async throws -> [Song] {
        var songs: [Song] = []
        var nextURL: String? = "\(base)/users/5p5v75aiq275hj8i4tcldu4pe/playlists?limit=50"
        while let urlString = nextURL {
            let request   = try await authorizedRequest(for: urlString)
            let (data, _) = try await URLSession.shared.data(for: request)
            let response  = try JSONDecoder().decode(SpotifyPagingResponse<SpotifyTrackItem>.self, from: data)

            let batch = response.items.compactMap { item -> Song? in
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
            nextURL = response.next
        }

        return songs
    }

    // MARK: - Get current user ID

    func fetchUserID() async throws -> String {
        let request   = try await authorizedRequest(for: "\(base)/me")
        let (data, _) = try await URLSession.shared.data(for: request)
        let response  = try JSONDecoder().decode(SpotifyUser.self, from: data)
        return response.id
    }

    // MARK: - Create playlist

    func createPlaylist(name: String, description: String) async throws -> String {
        let userID  = try await fetchUserID()
        let body    = try JSONEncoder().encode(SpotifyCreatePlaylistBody(name: name, description: description))
        let request = try await authorizedRequest(for: "\(base)/users/\(userID)/playlists", method: "POST", body: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response  = try JSONDecoder().decode(SpotifyPlaylist.self, from: data)
        return response.id
    }

    // MARK: - Add tracks to playlist

    func addTracks(playlistID: String, trackIDs: [String]) async throws {
        // Spotify allows max 100 tracks per request
        let batchSize = 100
        for batchStart in stride(from: 0, to: trackIDs.count, by: batchSize) {
            let batchEnd  = min(batchStart + batchSize, trackIDs.count)
            let batch     = Array(trackIDs[batchStart..<batchEnd])
            let uris      = batch.map { "spotify:track:\($0)" }
            let body      = try JSONEncoder().encode(SpotifyAddTracksBody(uris: uris))
            let request   = try await authorizedRequest(
                for: "\(base)/playlists/\(playlistID)/tracks",
                method: "POST",
                body: body
            )
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 201 {
                throw SpotifyError.failedToAddTracks
            }
        }
    }

    // MARK: - Full save flow (matches Apple Music save pattern)

    func savePlaylist(name: String, keptSongs: [Song]) async throws -> String {
        let description = "Curated with Retune on \(Date().formatted(date: .abbreviated, time: .omitted))"
        let playlistID  = try await createPlaylist(name: name, description: description)

        let trackIDs = keptSongs.compactMap { $0.musicItemID }
        guard !trackIDs.isEmpty else { throw SpotifyError.noValidTracks }

        try await addTracks(playlistID: playlistID, trackIDs: trackIDs)
        return playlistID
    }
}

// MARK: - Errors

enum SpotifyError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case failedToAddTracks
    case noValidTracks

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:  return "Not signed in to Spotify."
        case .invalidURL:        return "Invalid Spotify API URL."
        case .failedToAddTracks: return "Couldn't add tracks to the playlist."
        case .noValidTracks:     return "None of the kept songs have Spotify IDs."
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
}

struct SpotifyArtist: Decodable {
    let name: String
}

struct SpotifyAlbum: Decodable {
    let images: [SpotifyImage]
}

struct SpotifyUser: Decodable {
    let id: String
}

struct SpotifyCreatePlaylistBody: Encodable {
    let name:            String
    let description:     String
    let isPublic:        Bool = false

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case isPublic = "public"
    }
}

struct SpotifyAddTracksBody: Encodable {
    let uris: [String]
}
