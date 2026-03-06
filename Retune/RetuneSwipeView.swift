//
//  RetuneSwipeView.swift
//  Retune
//

import SwiftUI
import MusicKit
import Combine

@MainActor
final class RetuneSessionVM: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let playlist: Playlist

    init(playlist: Playlist) {
        self.playlist = playlist
    }

    func loadSongs() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let detailed = try await playlist.with([.tracks])

            guard let tracks = detailed.tracks else {
                songs = []
                return
            }

            let musicKitSongs: [MusicKit.Song] = tracks.compactMap { $0 as? MusicKit.Song }

            songs = musicKitSongs.map {
                Song(
                    title: $0.title,
                    artist: $0.artistName,
                    artworkURL: $0.artwork?.url(width: 600, height: 600), // higher res for full-bleed
                    previewURL: $0.previewAssets?.first?.url,
                    musicItemID: $0.id.rawValue
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RetuneSessionLoaderView: View {
    let playlist: Playlist
    @StateObject private var vm: RetuneSessionVM

    init(playlist: Playlist) {
        self.playlist = playlist
        _vm = StateObject(wrappedValue: RetuneSessionVM(playlist: playlist))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading songs…")
            } else if let msg = vm.errorMessage {
                ContentUnavailableView(
                    "Couldn't load songs",
                    systemImage: "xmark.circle",
                    description: Text(msg)
                )
            } else {
                RetuneSwipeView(songs: vm.songs, playlistID: vm.playlist.id.rawValue, playlistName: vm.playlist.name, orderMode: SessionOrderMode.inOrder.rawValue)
            }
        }
        .navigationTitle(vm.playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadSongs() }
    }
}
