//
//  RetunedPlaylistsView.swift
//  Retune
//
//  Created by Eliase Osmani on 2/17/26.
//

import SwiftUI
import MusicKit
import Combine

private struct PlaylistSelection: Identifiable, Hashable {
    let id: MusicItemID
    let playlist: Playlist
    
    static func == (lhs: PlaylistSelection, rhs: PlaylistSelection) -> Bool { lhs.id == rhs.id }
    func hash(into haser: inout Hasher) { haser.combine(id) }
}

struct RetunePlaylistsView: View {
    @StateObject private var vm = MusicPlaylistsVM()
    @State private var selected: PlaylistSelection?

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading playlists…")
            } else if let msg = vm.errorMessage {
                ContentUnavailableView("Couldn’t load playlists",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(msg))
            } else {
                List(vm.playlists, id: \.id) { playlist in
                    Button {
                        selected = PlaylistSelection(id: playlist.id, playlist: playlist)
                    } label: {
                        Text(playlist.name)
                    }
                }
            }
        }
        .navigationTitle("Choose a Playlist")
        .task { await vm.load() }
        .navigationDestination(item: $selected) { selection in
            RetuneSessionLoaderView(playlist: selection.playlist)
        }
    }
}
