//
//  SavePlaylist.swift
//  Retune
//

import SwiftUI
import MusicKit
import Combine

// MARK: - Save State

enum SaveState: Equatable {
    case idle
    case checkingSubscription
    case lookingUpTracks
    case creatingPlaylist
    case addingTracks(current: Int, total: Int)
    case success(playlistName: String)
    case noSubscription
    case failed(String)
}

// MARK: - SavePlaylistVM

@MainActor
final class SavePlaylistVM: ObservableObject {
    @Published var saveState: SaveState = .idle

    var isWorking: Bool {
        switch saveState {
        case .idle, .success, .noSubscription, .failed: return false
        default: return true
        }
    }

    func saveToAppleMusic(name: String, keptSongs: [Song]) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !keptSongs.isEmpty else {
            saveState = .failed("No songs to save — keep at least one song before saving.")
            return
        }

        saveState = .checkingSubscription
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            saveState = .noSubscription
            return
        }

        saveState = .lookingUpTracks
        let songIDs = keptSongs.compactMap { $0.musicItemID }.map { MusicItemID($0) }
        guard !songIDs.isEmpty else {
            saveState = .failed("None of the kept songs have Apple Music IDs.")
            return
        }

        var catalogSongs: [MusicKit.Song] = []
        do {
            let batchSize = 25
            for batchStart in stride(from: 0, to: songIDs.count, by: batchSize) {
                let batchEnd  = min(batchStart + batchSize, songIDs.count)
                let batchIDs  = Array(songIDs[batchStart..<batchEnd])
                var request   = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, memberOf: batchIDs)
                request.limit = batchSize
                let response  = try await request.response()
                let ordered   = batchIDs.compactMap { id in response.items.first(where: { $0.id == id }) }
                catalogSongs.append(contentsOf: ordered)
            }
        } catch {
            saveState = handleMusicKitError(error, fallback: "Couldn't look up songs in Apple Music catalog.")
            return
        }

        guard !catalogSongs.isEmpty else {
            saveState = .failed("Couldn't find any of the kept songs in the Apple Music catalog.")
            return
        }

        saveState = .creatingPlaylist
        let newPlaylist: Playlist
        do {
            newPlaylist = try await MusicLibrary.shared.createPlaylist(
                name: name,
                description: "Curated with Retune on \(Date().formatted(date: .abbreviated, time: .omitted))",
                authorDisplayName: nil
            )
        } catch {
            saveState = handleMusicKitError(error, fallback: "Couldn't create playlist in Apple Music.")
            return
        }

        var addedCount = 0
        for (index, song) in catalogSongs.enumerated() {
            saveState = .addingTracks(current: index + 1, total: catalogSongs.count)
            do {
                try await MusicLibrary.shared.add(song, to: newPlaylist)
                addedCount += 1
            } catch {
                print("[Retune] Couldn't add \(song.title): \(error.localizedDescription)")
            }
        }

        if addedCount == 0 {
            saveState = .failed("Playlist was created but no songs could be added. Try again.")
        } else {
            saveState = .success(playlistName: name)
        }
    }

    func saveToSpotify(name: String, keptSongs: [Song]) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !keptSongs.isEmpty else {
            saveState = .failed("No songs to save — keep at least one song before saving.")
            return
        }

        saveState = .creatingPlaylist
        do {
            saveState = .addingTracks(current: 0, total: keptSongs.count)
            let _ = try await SpotifyAPIClient.shared.savePlaylist(name: name, keptSongs: keptSongs)
            saveState = .success(playlistName: name)
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    private func handleMusicKitError(_ error: Error, fallback: String) -> SaveState {
        let nsError = error as NSError
        if nsError.domain == "MPErrorDomain" && nsError.code == 5 {
            return .noSubscription
        }
        return .failed(nsError.localizedDescription.isEmpty ? fallback : nsError.localizedDescription)
    }
}

// MARK: - SaveRetunedPlaylistView

struct SaveRetunedPlaylistView: View {
    let keptSongs:    [Song]
    let removedSongs: [Song]
    let platform:     String

    @StateObject private var vm = SavePlaylistVM()
    @State private var newName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Session Summary") {
                HStack {
                    Label("\(keptSongs.count) kept", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Label("\(removedSongs.count) archived", systemImage: "archivebox.fill")
                        .foregroundStyle(.secondary)
                }
            }

            if !isFinalState {
                Section("New Playlist Name") {
                    TextField("My Retuned Playlist", text: $newName)
                        .disabled(vm.isWorking)
                }
            }

            Section {
                switch vm.saveState {
                case .idle:
                    Button("Save to \(platform == "spotify" ? "Spotify" : "Apple Music")") {
                        Task {
                            if platform == "spotify" {
                                await vm.saveToSpotify(name: newName, keptSongs: keptSongs)
                            } else {
                                await vm.saveToAppleMusic(name: newName, keptSongs: keptSongs)
                            }
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                case .checkingSubscription:
                    progressRow(label: "Checking Apple Music…", icon: "music.note")

                case .lookingUpTracks:
                    progressRow(label: "Looking up tracks…", icon: "magnifyingglass")

                case .creatingPlaylist:
                    progressRow(label: "Creating playlist…", icon: "plus.circle")

                case .addingTracks(let current, let total):
                    VStack(alignment: .leading, spacing: 8) {
                        progressRow(label: "Adding tracks (\(current) of \(total))…", icon: "music.note.list")
                        ProgressView(value: Double(current), total: Double(total))
                            .tint(.green)
                    }

                case .success(let name):
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Saved!")
                                .font(.body.weight(.medium))
                            Text("\"\(name)\" · \(keptSongs.count) songs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                case .noSubscription:
                    noSubscriptionView

                case .failed(let msg):
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Save failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.body.weight(.medium))
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Try Again") { vm.saveState = .idle }
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }

            if !vm.isWorking {
                Section {
                    Button("Discard", role: .destructive) { dismiss() }
                }
            }
        }
        .navigationTitle("Save Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if newName.isEmpty {
                newName = "Retuned • \(Date().formatted(date: .abbreviated, time: .omitted))"
            }
        }
    }

    private var isFinalState: Bool {
        switch vm.saveState {
        case .success, .noSubscription: return true
        default: return false
        }
    }

    private func progressRow(label: String, icon: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().scaleEffect(0.85)
            Label(label, systemImage: icon)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    private var noSubscriptionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Apple Music Required", systemImage: "music.note")
                .font(.body.weight(.medium))
                .foregroundStyle(.orange)
            Text("Saving playlists requires an active Apple Music subscription.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link("Learn about Apple Music", destination: URL(string: "https://www.apple.com/apple-music/")!)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
