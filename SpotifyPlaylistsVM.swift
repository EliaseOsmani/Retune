//
//  SpotifyPlaylistsVM.swift
//  Retune
//
//  Created by Eliase Osmani on 4/6/26.
//

import Foundation
import Combine

@MainActor
final class SpotifyPlaylistsVM: ObservableObject {
    @Published var playlists: [SpotifyPlaylist] = []
    @Published var isLoading  = false
    @Published var errorMessage: String?

    func load() async {
        isLoading   = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            playlists = try await SpotifyAPIClient.shared.fetchPlaylists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
