//
//  SwipeView.swift
//  Retune
//
//  Created by Eliase Osmani on 2/10/26.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = PlaylistViewModel()
    @EnvironmentObject var playlistManager: PlaylistManager
    
    @State private var keptSongs: [Song] = []
    @State private var removedSongs: [Song] = []
    
    var body: some View {
        ZStack {
            if viewModel.songs.isEmpty {
                VStack(spacing: 12) {
                    Text("Playlist Retuned 🎵")
                        .font(.title2)
                        //.background(.ultraThinMaterial)
                    
                    Button("Save as Retuned Playlist") {
                        playlistManager.addPlaylist(name: "Retuned Playlist", songs: keptSongs)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                //Second Card in stack
                if viewModel.songs.count > 1 {
                    let nextSong = viewModel.songs[1]
                    SwipeCard(song: nextSong, isTopCard: false) { _ in }
                    //NO Ops on second card
                    .padding()
                    .scaleEffect(0.95)
                    .offset(y: 14)
                    .opacity(0.9)
                }
                
                //Front Card OPs
                let currentSong = viewModel.songs[0]
                SwipeCard(song: currentSong, isTopCard: true) { swipedRight in
                    if swipedRight {
                        keptSongs.append(currentSong)
                    } else {
                        removedSongs.append(currentSong)
                    }
                    
                    viewModel.removeSong(currentSong)
                }
                .id(currentSong.id) // Keep this, resets @State per song
                .padding()
            }
        }
    }
}

struct RetuneSwipeView: View {
    @State private var remainingSongs: [Song]
    @State private var keptSongs: [Song] = []
    @State private var removedSongs: [Song] = []
    @State private var goToSave = false

    init(songs: [Song]) {
        _remainingSongs = State(initialValue: songs)
    }

    var body: some View {
        ZStack {
            if remainingSongs.isEmpty {
                VStack(spacing: 12) {
                    Text("Playlist Retuned 🎵").font(.title2)

                    Button("Save to Apple Music") {
                        goToSave = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                if remainingSongs.count > 1 {
                    let nextSong = remainingSongs[1]
                    SwipeCard(song: nextSong, isTopCard: false) { _ in }
                        .padding()
                        .scaleEffect(0.95)
                        .offset(y: 14)
                        .opacity(0.9)
                }

                let currentSong = remainingSongs[0]
                SwipeCard(song: currentSong, isTopCard: true) { swipedRight in
                    if swipedRight { keptSongs.append(currentSong) }
                    else { removedSongs.append(currentSong) }
                    remainingSongs.removeFirst()
                }
                .id(currentSong.id)
                .padding()
            }
        }
        .navigationDestination(isPresented: $goToSave) {
            SaveRetunedPlaylistView(keptSongs: keptSongs)
        }
    }
}


