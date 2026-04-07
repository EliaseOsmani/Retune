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

// MARK: - Platform

enum MusicPlatform: String, CaseIterable {
    case appleMusic = "Apple Music"
    case spotify    = "Spotify"

    var icon: String {
        switch self {
        case .appleMusic: return "applelogo"
        case .spotify:    return "music.note"
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @StateObject private var appleMusicVM = MusicPlaylistsVM()
    @StateObject private var spotifyVM    = SpotifyPlaylistsVM()
    @StateObject private var spotifyAuth  = SpotifyAuthManager.shared

    @State private var selectedPlatform: MusicPlatform = .appleMusic
    @State private var selected: PlaylistSelection?

    @Query private var savedSessions: [SessionRecord]
    @State private var resumeSongs:   [Song]?         = nil
    @State private var resumeSession: SessionRecord?  = nil
    @State private var showResume = false

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let msg = errorMessage {
                ContentUnavailableView(
                    "Couldn't load playlists",
                    systemImage: "exclamationmark.triangle",
                    description: Text(msg)
                )
            } else if currentPlaylists.isEmpty {
                ContentUnavailableView(
                    "No Playlists Found",
                    systemImage: "music.note.list",
                    description: Text("Add playlists to your \(selectedPlatform.rawValue) library to get started.")
                )
            } else {
                playlistList
            }
        }
        .navigationTitle("Retune")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadCurrentPlatform() }
        .onChange(of: selectedPlatform) {
            Task { await loadCurrentPlatform() }
        }
        .navigationDestination(item: $selected) { selection in
            if selection.isSpotify {
                SpotifySessionSetupView(playlist: selection.spotifyPlaylist!)
            } else {
                SessionSetupView(playlist: selection.appleMusicPlaylist!)
            }
        }
    }

    // MARK: - Platform loading

    private var isLoading: Bool {
        selectedPlatform == .appleMusic ? appleMusicVM.isLoading : spotifyVM.isLoading
    }

    private var errorMessage: String? {
        selectedPlatform == .appleMusic ? appleMusicVM.errorMessage : spotifyVM.errorMessage
    }

    private var currentPlaylists: [PlaylistSelection] {
        switch selectedPlatform {
        case .appleMusic:
            return appleMusicVM.playlists.map {
                PlaylistSelection(appleMusicPlaylist: $0)
            }
        case .spotify:
            return spotifyVM.playlists.map {
                PlaylistSelection(spotifyPlaylist: $0)
            }
        }
    }

    private func loadCurrentPlatform() async {
        switch selectedPlatform {
        case .appleMusic:
            await appleMusicVM.load()
        case .spotify:
            if spotifyAuth.isAuthenticated {
                await spotifyVM.load()
            }
        }
    }

    // MARK: - Playlist List

    private var playlistList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                resumeBanner
                headerBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                // Platform picker
                Picker("Platform", selection: $selectedPlatform) {
                    ForEach(MusicPlatform.allCases, id: \.self) { platform in
                        Text(platform.rawValue).tag(platform)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Spotify login prompt
                if selectedPlatform == .spotify && !spotifyAuth.isAuthenticated {
                    spotifyLoginBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                } else {
                    // Section label
                    HStack {
                        Text("Your Playlists")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(currentPlaylists.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                    ForEach(currentPlaylists) { selection in
                        UnifiedPlaylistRow(selection: selection) {
                            selected = selection
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Spotify Login Banner

    private var spotifyLoginBanner: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("Connect Spotify")
                .font(.title3.weight(.semibold))

            Text("Sign in to browse and retune your Spotify playlists.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                spotifyAuth.login()
                Task { await spotifyVM.load() }
            } label: {
                Text("Connect Spotify")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let error = spotifyAuth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
            ProgressView().scaleEffect(1.2)
            Text("Loading your playlists…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Unified Playlist Row

struct UnifiedPlaylistRow: View {
    let selection: PlaylistSelection
    let onTap: () -> Void

    @State private var artworkImage: UIImage? = nil
    @State private var tintColor: Color = .purple

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
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

                VStack(alignment: .leading, spacing: 3) {
                    Text(selection.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("Tap to retune")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

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
        guard let url = selection.artworkURL else { return }
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

// MARK: - Unified Playlist Selection

struct PlaylistSelection: Identifiable, Hashable {
    let id: String
    let name: String
    let artworkURL: URL?
    let isSpotify: Bool

    var appleMusicPlaylist: Playlist?
    var spotifyPlaylist:    SpotifyPlaylist?

    init(appleMusicPlaylist: Playlist) {
        self.id                 = appleMusicPlaylist.id.rawValue
        self.name               = appleMusicPlaylist.name
        self.artworkURL         = appleMusicPlaylist.artwork?.url(width: 120, height: 120)
        self.isSpotify          = false
        self.appleMusicPlaylist = appleMusicPlaylist
        self.spotifyPlaylist    = nil
    }

    init(spotifyPlaylist: SpotifyPlaylist) {
        self.id              = "spotify:\(spotifyPlaylist.id)"
        self.name            = spotifyPlaylist.name
        self.artworkURL      = spotifyPlaylist.artworkURL
        self.isSpotify       = true
        self.spotifyPlaylist = spotifyPlaylist
        self.appleMusicPlaylist = nil
    }

    static func == (lhs: PlaylistSelection, rhs: PlaylistSelection) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Spotify Session Setup

struct SpotifySessionSetupView: View {
    let playlist: SpotifyPlaylist

    @StateObject private var vm = SpotifySessionSetupVM()
    @State private var navigateToSession = false
    @State private var sessionSongs: [Song] = []
    @State private var artworkImage: UIImage? = nil
    @State private var tintColor: Color = .green

    var body: some View {
        ZStack {
            tintColor.opacity(0.12).ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: tintColor)
            Color(.systemBackground).opacity(0.85).ignoresSafeArea()

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
            await vm.loadSongs(playlistID: playlist.id)
        }
        .navigationDestination(isPresented: $navigateToSession) {
            RetuneSwipeView(
                songs:        sessionSongs,
                playlistID:   "spotify:\(playlist.id)",
                playlistName: playlist.name,
                orderMode:    vm.orderMode.rawValue
            )
        }
    }

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
                Text("Spotify")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var songCountBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note").foregroundStyle(tintColor)
            if vm.isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading songs…").foregroundStyle(.secondary)
                }
            } else if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.caption)
            } else {
                Text("\(vm.songs.count) songs").font(.body.weight(.medium))
            }
        }
        .font(.body)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    private var orderPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Play Order").font(.headline).padding(.horizontal, 4)
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
                Image(systemName: mode.icon).font(.body.weight(.medium))
                Text(mode.rawValue).font(.body.weight(.medium))
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
            .background(vm.isLoading || vm.songs.isEmpty ? Color(.systemFill) : tintColor)
            .foregroundStyle(vm.isLoading || vm.songs.isEmpty ? Color.secondary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: vm.isLoading ? .clear : tintColor.opacity(0.4), radius: 12, y: 4)
        }
        .disabled(vm.isLoading || vm.songs.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: vm.isLoading)
    }

    private func loadArtwork() async {
        guard let url = playlist.artworkURL else { return }
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

// MARK: - Spotify Session Setup VM

@MainActor
final class SpotifySessionSetupVM: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var orderMode: SessionOrderMode = .inOrder

    func loadSongs(playlistID: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            songs = try await SpotifyAPIClient.shared.fetchTracks(playlistID: playlistID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var orderedSongs: [Song] {
        orderMode == .shuffled ? songs.shuffled() : songs
    }
}

// MARK: - Coming Soon stub

struct ComingSoonView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(.secondary)
            Text(title).font(.title2.weight(.semibold))
            Text("Coming in Phase 2").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
