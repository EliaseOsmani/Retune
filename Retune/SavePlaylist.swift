//
//  SavePlaylist.swift
//  Retune
//

import SwiftUI
import Combine
import MusicKit

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
            // TODO: MusicKit write — requires active Apple Music subscription.
            // Show graceful error if subscription is inactive (PDR: Key Tradeoff).
            _ = ids
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SaveRetunedPlaylistView: View {
    let keptSongs: [Song]
    let removedSongs: [Song]

    @StateObject private var vm = SavePlaylistVM()
    @State private var newName = ""

    var body: some View {
        Form {
            // Summary section
            Section("Session Summary") {
                HStack {
                    Label("\(keptSongs.count) kept", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Label("\(removedSongs.count) archived", systemImage: "archivebox.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Section("New Playlist Name") {
                TextField("My Retuned Playlist", text: $newName)
            }

            Section {
                Button(vm.isSaving ? "Saving…" : "Save to Apple Music") {
                    Task { await vm.savePlaylist(name: newName, keptSongs: keptSongs) }
                }
                .disabled(vm.isSaving || newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Discard", role: .destructive) {
                    // Pop to root — handled by NavigationStack
                }
            }

            if let msg = vm.errorMessage {
                Section {
                    Text(msg).foregroundStyle(.red)
                }
            }

            if vm.didSave {
                Section {
                    Label("Saved successfully!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Save Playlist")
        .onAppear {
            if newName.isEmpty {
                newName = "Retuned • \(Date().formatted(date: .abbreviated, time: .omitted))"
            }
        }
    }
}
