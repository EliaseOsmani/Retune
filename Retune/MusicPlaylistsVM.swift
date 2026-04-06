//
//  MusicPlaylistsVM.swift
//  Retune
//
//  Created by Eliase Osmani on 2/17/26.
//

import Foundation
import Combine
import MusicKit

@MainActor
final class MusicPlaylistsVM: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            errorMessage = "Apple Music access not authorized."
            return
        }

        do {
            var request = MusicLibraryRequest<Playlist>()
            request.limit = 50
            let response = try await request.response()
            playlists = Array(response.items)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
