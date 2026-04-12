//
//  ProfileView.swift
//  Retune
//
//  Shows the connected service with a disconnect option.
//  Spotify is shown as "coming soon" until Extended Quota Mode is available.
//

import SwiftUI
import MusicKit

struct ProfileView: View {

    @EnvironmentObject private var appState: AppStateManager

    @State private var showDisconnectAlert = false

    var body: some View {
        List {
            // ── Connected service ──────────────────────────────────────────
            Section {
                connectedServiceCard
            } header: {
                Text("Connected Service")
            } footer: {
                Text("Retune uses this service to load your playlists and save sessions.")
            }

            // ── Spotify coming soon ────────────────────────────────────────
            Section {
                spotifyComingSoonRow
            } header: {
                Text("Coming Soon")
            } footer: {
                Text("Spotify support is in development and will be available in a future update.")
            }

            // ── App info ───────────────────────────────────────────────────
            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build",   value: buildNumber)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .alert("Disconnect Apple Music?", isPresented: $showDisconnectAlert) {
            Button("Disconnect", role: .destructive) {
                Task { await appState.disconnectAppleMusic() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll be taken back to the sign-in screen. Your session history won't be affected.")
        }
    }

    // MARK: - Connected service card

    @ViewBuilder
    private var connectedServiceCard: some View {
        switch appState.connectedService {
        case .appleMusic, .both:
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(width: 44, height: 44)
                    Image(systemName: "applelogo")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Apple Music")
                        .font(.body.weight(.medium))
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 7, height: 7)
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    showDisconnectAlert = true
                } label: {
                    Text("Disconnect")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

        case .spotify:
            // Shouldn't normally be reachable since Spotify tracks are blocked,
            // but handle gracefully if someone was previously connected
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                        .frame(width: 44, height: 44)
                    Image(systemName: "music.note")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Spotify")
                        .font(.body.weight(.medium))
                    HStack(spacing: 5) {
                        Circle().fill(Color.orange).frame(width: 7, height: 7)
                        Text("Limited access — coming soon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)

        case .none:
            HStack {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                Text("No service connected")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Spotify coming soon row

    private var spotifyComingSoonRow: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Image(systemName: "music.note")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.systemGray2))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Spotify")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Coming Soon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.5))
                        .clipShape(Capsule())
                }
                Text("Full support coming in a future update")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - App info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
