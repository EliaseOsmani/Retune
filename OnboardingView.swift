//
//  OnboardingView.swift
//  Retune
//
//  First-time user flow. Three pages:
//    0 — Welcome
//    1 — Choose your service
//    2 — Success confirmation
//

import SwiftUI
import MusicKit

struct OnboardingView: View {

    @EnvironmentObject private var appState: AppStateManager

    @State private var page: Int = 0
    @State private var selectedService: MusicPlatform? = nil

    @State private var isConnectingApple = false
    @State private var appleMusicError:  String? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: page)

            Color(.systemBackground)
                .opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if page < 2 {
                    pageDots.padding(.top, 16)
                }

                Spacer()

                Group {
                    switch page {
                    case 0:  welcomePage
                    case 1:  chooseServicePage
                    default: successPage
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    )
                )
                .id(page)

                Spacer()
            }
        }
    }

    // MARK: - Background

    private var backgroundColors: [Color] {
        switch page {
        case 0:  return [Color.purple.opacity(0.6), Color.indigo.opacity(0.4)]
        case 1:  return [Color.indigo.opacity(0.5), Color.blue.opacity(0.3)]
        default: return [Color.pink.opacity(0.4),   Color.purple.opacity(0.4)]
        }
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.primary : Color.secondary.opacity(0.35))
                    .frame(width: i == page ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.35), value: page)
            }
        }
    }

    // MARK: ── Page 0: Welcome ──────────────────────────────────────────────

    private var welcomePage: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.purple.opacity(0.4), .clear],
                        center: .center, startRadius: 20, endRadius: 90
                    ))
                    .frame(width: 180, height: 180)

                RoundedRectangle(cornerRadius: 32)
                    .fill(LinearGradient(
                        colors: [.purple, .indigo],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 110, height: 110)
                    .shadow(color: .purple.opacity(0.5), radius: 28, y: 10)

                Image(systemName: "music.note.list")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                Text("Welcome to Retune")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Swipe through your playlists and keep only the songs you love.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                featurePill(icon: "hand.draw.fill",       color: .purple, text: "Swipe to keep or remove")
                featurePill(icon: "music.note.plus",      color: .indigo, text: "Save as a new playlist")
                featurePill(icon: "arrow.uturn.backward", color: .blue,   text: "Undo any swipe, anytime")
            }
            .padding(.horizontal, 28)

            primaryButton(label: "Get Started", icon: "arrow.right") {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { page = 1 }
            }
            .padding(.horizontal, 28)
        }
    }

    private func featurePill(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 32)
            Text(text).font(.body)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: ── Page 1: Choose Service ──────────────────────────────────────

    private var chooseServicePage: some View {
        VStack(spacing: 32) {
            VStack(spacing: 10) {
                Text("Connect Your Music")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Connect Apple Music to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 16) {
                appleMusicCard
                spotifyComingSoonCard
            }
            .padding(.horizontal, 24)

            if let error = appleMusicError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button { appState.completeOnboarding() } label: {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appleMusicCard: some View {
        Button {
            guard !isConnectingApple else { return }
            appleMusicError = nil
            selectedService = .appleMusic
            Task {
                isConnectingApple = true
                let granted = await appState.connectAppleMusic()
                isConnectingApple = false
                if granted {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { page = 2 }
                } else {
                    appleMusicError = "Apple Music access was denied. You can enable it in Settings."
                }
            }
        } label: {
            serviceCardLabel(
                icon: "applelogo",
                iconColor: .primary,
                badgeColor: Color(.systemGray5),
                name: "Apple Music",
                subtitle: "Connect your Apple Music library",
                isLoading: isConnectingApple,
                isDisabled: false
            )
        }
        .buttonStyle(.plain)
    }

    // Spotify shown as coming soon — tappable but shows an informational sheet
    private var spotifyComingSoonCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray4))
                    .frame(width: 52, height: 52)
                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(.systemGray2))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Spotify")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Coming Soon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.5))
                        .clipShape(Capsule())
                }
                Text("Spotify support is in the works")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemFill))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func serviceCardLabel(
        icon: String,
        iconColor: Color,
        badgeColor: Color,
        name: String,
        subtitle: String,
        isLoading: Bool,
        isDisabled: Bool
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(badgeColor)
                    .frame(width: 52, height: 52)
                if isLoading {
                    ProgressView().tint(iconColor)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isDisabled ? .secondary : .primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    // MARK: ── Page 2: Success ──────────────────────────────────────────────

    private var successPage: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 130, height: 130)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.purple)
                    .symbolEffect(.bounce, value: page)
            }

            VStack(spacing: 10) {
                Text("You're all set!")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Connected to Apple Music")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            primaryButton(label: "Start Retuning", icon: "play.fill") {
                appState.completeOnboarding()
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Shared button

    private func primaryButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(label).font(.headline)
                Image(systemName: icon).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(LinearGradient(
                colors: [.purple, .indigo],
                startPoint: .leading, endPoint: .trailing
            ))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .purple.opacity(0.4), radius: 12, y: 4)
        }
    }
}
