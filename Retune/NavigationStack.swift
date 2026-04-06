//
//  NavigationStack.swift
//  Retune
//

import SwiftUI
import MusicKit
import Combine
import SwiftData

// MARK: - Root (Tab Bar)

struct RootView: View {
    var body: some View {
        TabView {
            HomeTab()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // Phase 2 stubs — correct structure now, content later
            ComingSoonView(title: "Feed", icon: "music.note.list")
                .tabItem {
                    Label("Feed", systemImage: "music.note.list")
                }

            ComingSoonView(title: "Notifications", icon: "bell.fill")
                .tabItem {
                    Label("Notifications", systemImage: "bell.fill")
                }

            ComingSoonView(title: "Profile", icon: "person.fill")
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}

// MARK: - Home Tab

struct HomeTab: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}

// MARK: - Home View (Playlist Picker)

struct HomeView: View {
    @StateObject private var vm = MusicPlaylistsVM()
    @State private var selected: PlaylistSelection?

    // SwiftData — watch for unfinished sessions
    @Query private var savedSessions: [SessionRecord]
    @State private var resumeSongs: [Song]? = nil
    @State private var resumeSession: SessionRecord? = nil
    @State private var showResume = false

    var body: some View {
        Group {
            if vm.isLoading {
                loadingView
            } else if let msg = vm.errorMessage {
                ContentUnavailableView(
                    "Couldn't load playlists",
                    systemImage: "exclamationmark.triangle",
                    description: Text(msg)
                )
            } else if vm.playlists.isEmpty {
                ContentUnavailableView(
                    "No Playlists Found",
                    systemImage: "music.note.list",
                    description: Text("Add playlists to your Apple Music library to get started.")
                )
            } else {
                playlistList
            }
        }
        .navigationTitle("Retune")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .navigationDestination(item: $selected) { selection in
            SessionSetupView(playlist: selection.playlist)
        }
    }

    // MARK: - Playlist List

    private var playlistList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header
                resumeBanner
                headerBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                // Section label
                HStack {
                    Text("Your Playlists")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(vm.playlists.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // Rows
                ForEach(vm.playlists, id: \.id) { playlist in
                    PlaylistRow(playlist: playlist) {
                        selected = PlaylistSelection(id: playlist.id, playlist: playlist)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header Banner

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: "music.note")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Ready to retune?")
                    .font(.title3.weight(.semibold))
                Text("Pick a playlist to start swiping.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Resume Banner

    @ViewBuilder
    private var resumeBanner: some View {
        if let session = savedSessions.first(where: { !$0.isComplete }) {
            Button {
                resumeSession = session
                resumeSongs   = session.remainingSongs
                showResume    = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Resume Session")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(session.playlistName) · \(session.decisions.count) of \(session.allSongs.count) swiped")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .navigationDestination(isPresented: $showResume) {
                if let songs = resumeSongs, let session = resumeSession {
                    RetuneSwipeView(
                        songs:        songs,
                        playlistID:   session.playlistID,
                        playlistName: session.playlistName,
                        orderMode:    session.orderMode
                    )
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading your playlists…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    let playlist: Playlist
    let onTap: () -> Void

    @State private var artworkImage: UIImage? = nil
    @State private var tintColor: Color = .purple

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {

                // Artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tintColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    if let img = artworkImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.title3)
                            .foregroundStyle(tintColor)
                    }
                }
                .shadow(color: tintColor.opacity(0.25), radius: 6, y: 2)

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("Tap to retune")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .task { await loadArtwork() }
    }

    private func loadArtwork() async {
        guard let url = playlist.artwork?.url(width: 120, height: 120) else { return }
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

// MARK: - Route model (used by HomeView navigationDestination)

private struct PlaylistSelection: Identifiable, Hashable {
    let id: MusicItemID
    let playlist: Playlist

    static func == (lhs: PlaylistSelection, rhs: PlaylistSelection) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Coming Soon stub (Phase 2 tabs)

struct ComingSoonView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.semibold))
            Text("Coming in Phase 2")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
