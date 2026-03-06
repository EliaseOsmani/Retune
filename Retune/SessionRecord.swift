//
//  SessionRecord.swift
//  Retune
//
//  Created by Eliase Osmani on 3/5/26.
//
//  SwiftData models for auto-saving swipe session progress.
//  PDR spec: playlistID, platform, order mode, and an array of SongDecision objects.
//

import Foundation
import SwiftData

// MARK: - SongDecision
// One entry per swiped card. Enough to reconstruct kept/removed lists on resume.

@Model
final class SongDecision {
    var songID:    String   // Song.id (UUID as string)
    var kept:      Bool     // true = keep, false = archive
    var timestamp: Date

    init(songID: String, kept: Bool) {
        self.songID    = songID
        self.kept      = kept
        self.timestamp = Date()
    }
}

// MARK: - SessionRecord
// One record per active session. Deleted when the session is completed or discarded.

@Model
final class SessionRecord {
    var playlistID:   String          // MusicItemID.rawValue
    var playlistName: String
    var platform:     String          // "appleMusic" for now, "spotify" in Phase 2
    var orderMode:    String          // SessionOrderMode.rawValue
    var startedAt:    Date

    // Full ordered song list as JSON — lets us reconstruct remainingSongs on resume
    var songsJSON:    Data

    // Decisions made so far — grows by one per swipe
    @Relationship(deleteRule: .cascade)
    var decisions:    [SongDecision]

    init(
        playlistID:   String,
        playlistName: String,
        platform:     String = "appleMusic",
        orderMode:    String,
        songs:        [Song]
    ) {
        self.playlistID   = playlistID
        self.playlistName = playlistName
        self.platform     = platform
        self.orderMode    = orderMode
        self.startedAt    = Date()
        self.decisions    = []
        self.songsJSON    = (try? JSONEncoder().encode(songs)) ?? Data()
    }

    // MARK: - Helpers

    /// Decode the full ordered song list
    var allSongs: [Song] {
        (try? JSONDecoder().decode([Song].self, from: songsJSON)) ?? []
    }

    /// Songs not yet decided (everything after the last decision index)
    var remainingSongs: [Song] {
        let decided = Set(decisions.map { $0.songID })
        // Preserve original order — filter out decided songs
        return allSongs.filter { !decided.contains($0.id.uuidString) }
    }

    var keptSongs: [Song] {
        let keptIDs = Set(decisions.filter { $0.kept }.map { $0.songID })
        return allSongs.filter { keptIDs.contains($0.id.uuidString) }
    }

    var removedSongs: [Song] {
        let removedIDs = Set(decisions.filter { !$0.kept }.map { $0.songID })
        return allSongs.filter { removedIDs.contains($0.id.uuidString) }
    }

    var isComplete: Bool { remainingSongs.isEmpty }
}
