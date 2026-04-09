//
//  RetunedPlaylistsView.swift
//  Retune
//
//  Created by Eliase Osmani on 2/17/26.
//

import SwiftUI
import MusicKit
import Combine

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
                        selected = PlaylistSelection(appleMusicPlaylist: playlist)
                    } label: {
                        Text(playlist.name)
                    }
                }
            }
        }
        .navigationTitle("Choose a Playlist")
        .task { await vm.load() }
        .navigationDestination(item: $selected) { selection in
            if let playlist = selection.appleMusicPlaylist {
                RetuneSessionLoaderView(playlist: playlist)
            } else {
                ContentUnavailableView(
                    "Playlist unavailable",
                    systemImage: "music.note.list"
                )
            }
        }
    }
}
