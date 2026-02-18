//
//  Song.swift
//  Retune
//
//  Created by Eliase Osmani on 2/10/26.
//

import Foundation
import MusicKit

struct Song: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let artworkURL: URL?
    let previewURL: URL?
    let musicItemID: String?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        artworkURL: URL? = nil,
        previewURL: URL? = nil,
        musicItemID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.previewURL = previewURL
        self.musicItemID = musicItemID
    }
}
