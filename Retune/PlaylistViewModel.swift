//
//  PlaylistViewModel.swift
//  Retune
//
//  Created by Eliase Osmani on 2/10/26.
//

import Foundation
import Combine

class PlaylistViewModel: ObservableObject {
    @Published var songs: [Song] = [
        Song(
            title: "Rockman",
            artist: "Mk.gee",
            artworkURL: Bundle.main.url(forResource: "rockman", withExtension: "jpg")
        ),
        Song(title: "The Dress",
             artist: "Dijon",
             artworkURL: Bundle.main.url(forResource: "the_dress", withExtension: "jpg")
            ),
        Song(title: "BETTER MAN",
             artist: "Justin Bieber",
             artworkURL: Bundle.main.url(forResource: "BETTER_MAN", withExtension: "jpg")
            ),
        Song(title: "Lost in the Fire",
             artist: "Gesaffelstien & The Weeknd",
             artworkURL: Bundle.main.url(forResource: "lost_in_the_fire", withExtension: "jpg")
            )
    ]
    
    func removeSong(_ song: Song) {
        songs.removeAll { $0.id == song.id }
    }
}

