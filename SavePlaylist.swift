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
    case noSubscription          // PDR: Key Tradeoff — graceful degradation
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

    func savePlaylist(name: String, keptSongs: [Song]) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !keptSongs.isEmpty else {
            saveState = .failed("No songs to save — keep at least one song before saving.")
            return
        }

        // ── Step 1: Verify Apple Music authorization ─────────────────────
        saveState = .checkingSubscription
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            saveState = .noSubscription
            return
        }

        // ── Step 2: Look up each song in the catalog by MusicItemID ──────
        // We need live MusicKit.Song objects to pass to MusicLibrary.
        // Our Song model stores musicItemID strings from when songs were fetched.
        saveState = .lookingUpTracks
        let songIDs = keptSongs.compactMap { $0.musicItemID }.map { MusicItemID($0) }

        guard !songIDs.isEmpty else {
            saveState = .failed("None of the kept songs have Apple Music IDs. This shouldn't happen — please try again.")
            return
        }

        var catalogSongs: [MusicKit.Song] = []
        do {
            // Fetch in batches of 25 to avoid hitting request size limits
            let batchSize = 25
            for batchStart in stride(from: 0, to: songIDs.count, by: batchSize) {
                let batchEnd   = min(batchStart + batchSize, songIDs.count)
                let batchIDs   = Array(songIDs[batchStart..<batchEnd])
                var request    = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, memberOf: batchIDs)
                request.limit  = batchSize
                let response   = try await request.response()
                // Preserve original order
                let ordered = batchIDs.compactMap { id in response.items.first(where: { $0.id == id }) }
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

        // ── Step 3: Create the new playlist ──────────────────────────────
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

        // ── Step 4: Add songs one by one (MusicKit has no bulk-add API) ──
        var addedCount = 0
        for (index, song) in catalogSongs.enumerated() {
            saveState = .addingTracks(current: index + 1, total: catalogSongs.count)
            do {
                try await MusicLibrary.shared.add(song, to: newPlaylist)
                addedCount += 1
            } catch {
                // Non-fatal: log and continue — don't abort the whole save for one bad track
                print("[Retune] Couldn't add \(song.title): \(error.localizedDescription)")
            }
        }

        if addedCount == 0 {
            saveState = .failed("Playlist was created but no songs could be added. Try again.")
        } else {
            saveState = .success(playlistName: name)
        }
    }

    // MARK: - Error handling

    private func handleMusicKitError(_ error: Error, fallback: String) -> SaveState {
        let nsError = error as NSError
        // MPErrorDomain Code=5 = "The requested action is not supported"
        // This is what Apple Music throws when user has no active subscription.
        if nsError.domain == "MPErrorDomain" && nsError.code == 5 {
            return .noSubscription
        }
        return .failed(nsError.localizedDescription.isEmpty ? fallback : nsError.localizedDescription)
    }
}

// MARK: - SaveRetunedPlaylistView

struct SaveRetunedPlaylistView: View {
    let keptSongs:   [Song]
    let removedSongs: [Song]

    @StateObject private var vm = SavePlaylistVM()
    @State private var newName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {

            // ── Summary ─────────────────────────────────────────────────
            Section("Session Summary") {
                HStack {
                    Label("\(keptSongs.count) kept", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Label("\(removedSongs.count) archived", systemImage: "archivebox.fill")
                        .foregroundStyle(.secondary)
                }
            }

            // ── Playlist name ────────────────────────────────────────────
            if !isFinalState {
                Section("New Playlist Name") {
                    TextField("My Retuned Playlist", text: $newName)
                        .disabled(vm.isWorking)
                }
            }

            // ── Action / Progress ────────────────────────────────────────
            Section {
                switch vm.saveState {
                case .idle:
                    Button("Save to Apple Music") {
                        Task { await vm.savePlaylist(name: newName, keptSongs: keptSongs) }
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
                            Text("Saved to Apple Music!")
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
                        Button("Try Again") {
                            vm.saveState = .idle
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }

            // ── Discard ──────────────────────────────────────────────────
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

    // MARK: - Helpers

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

            Text("Saving playlists to Apple Music requires an active Apple Music subscription. You can still use Retune to review and curate playlists — just connect an Apple Music account to save results.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link("Learn about Apple Music", destination: URL(string: "https://www.apple.com/apple-music/")!)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
