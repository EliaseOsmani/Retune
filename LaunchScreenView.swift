//
//  LaunchScreenView.swift
//  Retune
//
//  Branded splash screen shown while AppStateManager.boot() runs.
//  Transitions automatically to onboarding or home once boot completes.
//

import SwiftUI

struct LaunchScreenView: View {

    @StateObject private var appState = AppStateManager.shared

    // Animation state
    @State private var logoScale:   CGFloat = 0.7
    @State private var logoOpacity: CGFloat = 0
    @State private var wordmarkOpacity: CGFloat = 0
    @State private var taglineOpacity:  CGFloat = 0
    @State private var isTransitioning = false

    var body: some View {
        ZStack {
            // Background — deep dark so the logo pops
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo mark ──────────────────────────────────────────────
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.35), .clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(logoScale)

                    // Icon background pill
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: .purple.opacity(0.5), radius: 24, y: 8)

                    Image(systemName: "music.note.list")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // ── Wordmark ───────────────────────────────────────────────
                Text("Retune")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.top, 28)
                    .opacity(wordmarkOpacity)

                // ── Tagline ────────────────────────────────────────────────
                Text("Curate what you love")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .opacity(taglineOpacity)

                Spacer()

                // ── Loading indicator at bottom ────────────────────────────
                ProgressView()
                    .tint(.secondary)
                    .opacity(taglineOpacity)
                    .padding(.bottom, 52)
            }
        }
        .task {
            await animateIn()
            await AppStateManager.shared.boot()
        }
    }

    // MARK: - Entrance animation

    private func animateIn() async {
        // Slight stagger between logo, wordmark, tagline
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.easeOut(duration: 0.35)) {
            wordmarkOpacity = 1.0
        }
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.easeOut(duration: 0.35)) {
            taglineOpacity = 1.0
        }
    }
}
