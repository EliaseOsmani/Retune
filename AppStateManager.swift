//
//  AppStateManager.swift
//  Retune
//
//  Central source of truth for authentication and app routing state.
//  All views read from this — nothing checks MusicKit or Keychain directly.
//

import SwiftUI
import MusicKit
import Combine

// MARK: - Connected Service

enum ConnectedService: Equatable {
    case appleMusic         // Only Apple Music connected
    case spotify            // Only Spotify connected
    case both               // Both connected — picker shown in HomeView
    case none
}

// MARK: - App Phase (drives root routing)

enum AppPhase: Equatable {
    case launching          // Splash screen — checking auth state
    case onboarding         // First-time or fully logged-out user
    case home               // Authenticated, go to main app
}

// MARK: - AppStateManager

@MainActor
final class AppStateManager: ObservableObject {

    static let shared = AppStateManager()

    // MARK: - Published state

    @Published private(set) var phase: AppPhase = .launching
    @Published private(set) var connectedService: ConnectedService = .none

    /// When both services are connected, this tracks which one HomeView is
    /// currently showing. Defaults to Apple Music. Toggled by the picker.
    @Published var activeService: MusicPlatform = .appleMusic

    // MARK: - Private

    private let onboardingKey = "hasCompletedOnboarding"
    private var cancellables  = Set<AnyCancellable>()

    private init() {
        SpotifyAuthManager.shared.$isAuthenticated
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.refreshServiceState() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Boot sequence (called from LaunchScreenView)

    func boot() async {
        try? await Task.sleep(for: .milliseconds(800))
        await refreshServiceState()

        if connectedService == .none && !hasCompletedOnboarding {
            phase = .onboarding
        } else {
            phase = .home
        }
    }

    // MARK: - Service detection

    func refreshServiceState() async {
        let appleMusicAuthorized = MusicAuthorization.currentStatus == .authorized
        let spotifyAuthenticated = SpotifyAuthManager.shared.isAuthenticated

        switch (appleMusicAuthorized, spotifyAuthenticated) {
        case (true,  true):  connectedService = .both
        case (true,  false): connectedService = .appleMusic
        case (false, true):  connectedService = .spotify
        case (false, false): connectedService = .none
        }

        // When dropping from both → single, snap activeService to whatever remains
        if connectedService == .appleMusic { activeService = .appleMusic }
        if connectedService == .spotify    { activeService = .spotify }
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: onboardingKey)
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingKey)
        phase = .home
    }

    // MARK: - Connect / Disconnect

    @discardableResult
    func connectAppleMusic() async -> Bool {
        let status = await MusicAuthorization.request()
        await refreshServiceState()
        return status == .authorized
    }

    func disconnectSpotify() async {
        SpotifyAuthManager.shared.logout()
        await refreshServiceState()
        if connectedService == .none { phase = .onboarding }
    }

    func disconnectAppleMusic() async {
        await refreshServiceState()
        if connectedService == .none { phase = .onboarding }
    }
}
