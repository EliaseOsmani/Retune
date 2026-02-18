//
//  RetunedPlaylist.swift
//  Retune
//
//  Created by Eliase Osmani on 2/12/26.
//

import Foundation

struct RetunedPlaylist: Identifiable, Codable {
    
    let id: UUID
    let name: String
    let songs: [Song]
    let dateCreated: Date
    
}
