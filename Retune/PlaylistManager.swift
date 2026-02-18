//
//  PlaylistManager.swift
//  Retune
//
//  Created by Eliase Osmani on 2/12/26.
//

import Foundation
import Combine

final class PlaylistManager: ObservableObject {
    
    @Published private(set) var playlists: [RetunedPlaylist] = []
    
    private let key = "saved_playlists"
    
    init() { load() }
    
    func addPlaylist(name: String, songs: [Song]) {
        let p = RetunedPlaylist(
            id: UUID(),
            name: name,
            songs:songs,
            dateCreated: Date()
        )
        playlists.insert(p, at: 0)
        save()
    }
    
    private func save() {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
    
    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([RetunedPlaylist].self, from: data)
            else { return }
        playlists = decoded
    }
}
