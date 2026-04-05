//
//  SessionSetupView.swift
//  Retune
//

import SwiftUI
import MusicKit
import Combine

// MARK: - Order Mode

enum SessionOrderMode: String, CaseIterable {
    case inOrder  = "Playlist Order"
    case shuffled = "Shuffle"

    var icon: String {
        switch self {
        case .inOrder:  return "list.number"
        case .shuffled: return "shuffle"
        }
    }
}

// MARK: - Setup VM

@MainActor
final class SessionSetupVM: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var orderMode: SessionOrderMode = .inOrder

    let playlist: Playlist

    init(playlist: Playlist) {
        self.playlist = playlist
    }

    // Load songs eagerly in the background while the user reads the setup screen
    func loadSongs() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let detailed = try await playlist.with([.tracks])
            guard let tracks = detailed.tracks else { songs = []; return }

            let mkSongs: [MusicKit.Song] = tracks.compactMap { $0 as? MusicKit.Song }
            songs = mkSongs.map {
                Song(
                    title: $0.title,
                    artist: $0.artistName,
                    artworkURL: $0.artwork?.url(width: 600, height: 600),
                    previewURL: $0.previewAssets?.first?.url,
                    musicItemID: $0.id.rawValue
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Apply order mode and return the final song list for the session
    var orderedSongs: [Song] {
        orderMode == .shuffled ? songs.shuffled() : songs
    }
}

// MARK: - Session Setup View

struct SessionSetupView: View {
    let playlist: Playlist

    @StateObject private var vm: SessionSetupVM
    @State private var navigateToSession = false
    @State private var sessionSongs: [Song] = []
    @State private var artworkImage: UIImage? = nil
    @State private var tintColor: Color = .purple

    init(playlist: Playlist) {
        self.playlist = playlist
        _vm = StateObject(wrappedValue: SessionSetupVM(playlist: playlist))
    }

    var body: some View {
        ZStack {
            // Subtle tinted background
            tintColor
                .opacity(0.12)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: tintColor)

            Color(.systemBackground)
                .opacity(0.85)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {

                    artworkHeader
                    songCountBadge
                    orderPicker
                    Spacer(minLength: 0)
                    startButton

                }
                .padding(24)
            }
        }
        .navigationTitle("Session Setup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArtwork()
            await vm.loadSongs()
        }
        .navigationDestination(isPresented: $navigateToSession) {
            RetuneSwipeView(songs: sessionSongs, playlistID: playlist.id.rawValue, playlistName: playlist.name, orderMode: vm.orderMode.rawValue)
        }
    }

    // MARK: - Artwork Header

    private var artworkHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(tintColor.opacity(0.15))
                    .frame(width: 160, height: 160)

                if let img = artworkImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundStyle(tintColor)
                }
            }
            .shadow(color: tintColor.opacity(0.35), radius: 20, y: 8)

            VStack(spacing: 4) {
                Text(playlist.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Apple Music")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Song Count Badge

    private var songCountBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .foregroundStyle(tintColor)

            if vm.isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading songs…")
                        .foregroundStyle(.secondary)
                }
            } else if let err = vm.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.caption)
            } else {
                Text("\(vm.songs.count) songs")
                    .font(.body.weight(.medium))
            }
        }
        .font(.body)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    // MARK: - Order Picker

    private var orderPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Play Order")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                ForEach(SessionOrderMode.allCases, id: \.self) { mode in
                    orderOption(mode)
                }
            }
        }
    }

    private func orderOption(_ mode: SessionOrderMode) -> some View {
        let isSelected = vm.orderMode == mode

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                vm.orderMode = mode
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.body.weight(.medium))
                Text(mode.rawValue)
                    .font(.body.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? tintColor : Color(.secondarySystemBackground))
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? tintColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            sessionSongs = vm.orderedSongs
            navigateToSession = true
        } label: {
            HStack(spacing: 10) {
                if vm.isLoading {
                    ProgressView().tint(.white)
                    Text("Loading…")
                } else {
                    Image(systemName: "play.fill")
                    Text("Start Retuning")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                vm.isLoading || vm.songs.isEmpty
                    ? Color(.systemFill)
                    : tintColor
            )
            .foregroundStyle(vm.isLoading || vm.songs.isEmpty ? Color.secondary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: vm.isLoading ? .clear : tintColor.opacity(0.4),
                radius: 12, y: 4
            )
        }
        .disabled(vm.isLoading || vm.songs.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: vm.isLoading)
    }

    // MARK: - Artwork loader

    private func loadArtwork() async {
        guard let url = playlist.artwork?.url(width: 320, height: 320) else { return }
        if let cached = ImageCache.shared.image(for: url) {
            artworkImage = cached
            if let avg = cached.averageColor { tintColor = Color(uiColor: avg) }
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else { return }
        ImageCache.shared.set(img, for: url)
        artworkImage = img
        if let avg = img.averageColor { tintColor = Color(uiColor: avg) }
    }
}
