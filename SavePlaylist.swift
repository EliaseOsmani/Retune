//
//  SavePlaylist.swift
//  Retune
//
//  Created by Eliase Osmani on 2/17/26.
//

import SwiftUI
import MusicKit
import Combine

@MainActor
final class SavePlaylistVM: ObservableObject {
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false

    func savePlaylist(name: String, keptSongs: [Song]) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let ids = keptSongs.compactMap { $0.musicItemID }.map { MusicItemID($0) }

            // 1) Create a new playlist in the user's library
            // 2) Add the tracks by ID
            // (Implementation depends on MusicKit API available in your target iOS)

            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SaveRetunedPlaylistView: View {
    let keptSongs: [Song]
    @StateObject private var vm = SavePlaylistVM()
    @State private var newName: String = ""

    var body: some View {
        Form {
            Section("New Playlist Name") {
                TextField("My Retuned Playlist", text: $newName)
            }

            Section {
                Button(vm.isSaving ? "Saving…" : "Save to Apple Music") {
                    Task { await vm.savePlaylist(name: newName, keptSongs: keptSongs) }
                }
                .disabled(vm.isSaving || newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let msg = vm.errorMessage {
                Text(msg).foregroundStyle(.red)
            }

            if vm.didSave {
                Text("Saved!").foregroundStyle(.green)
            }
        }
        .navigationTitle("Save")
        .onAppear {
            if newName.isEmpty { newName = "Retuned • \(Date().formatted(date: .abbreviated, time: .omitted))" }
        }
    }
}
