//
//  SwipeView.swift
//  Retune
//

import SwiftUI

// MARK: - Swipe Decision (for undo support)

private struct SwipeDecision {
    let song: Song
    let kept: Bool
}

// MARK: - RetuneSwipeView

struct RetuneSwipeView: View {
    // Passed in from RetuneSessionLoaderView
    let allSongs: [Song]

    @State private var remainingSongs: [Song]
    @State private var history: [SwipeDecision] = []   // for unlimited undo
    @State private var keptSongs: [Song]    = []
    @State private var removedSongs: [Song] = []
    @State private var goToSave = false

    // Screen background tint — driven by top card's artwork
    @State private var screenTint: Color = .black

    init(songs: [Song]) {
        self.allSongs = songs
        _remainingSongs = State(initialValue: songs)
    }

    private var totalCount: Int { allSongs.count }
    private var reviewedCount: Int { totalCount - remainingSongs.count }

    var body: some View {
        ZStack {
            // ── Full-screen tinted background (PDR: dynamic color theming) ──
            screenTint
                .opacity(0.25)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: screenTint)

            Color(.systemBackground)
                .opacity(0.75)
                .ignoresSafeArea()

            if remainingSongs.isEmpty {
                sessionCompleteView
            } else {
                VStack(spacing: 0) {

                    // ── Progress bar (PDR: X of Y songs reviewed) ───────────
                    progressBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // ── Card stack ───────────────────────────────────────────
                    cardStack
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 16)

                    // ── Undo button (PDR: unlimited undo) ────────────────────
                    undoButton
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToSave) {
            SaveRetunedPlaylistView(keptSongs: keptSongs, removedSongs: removedSongs)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(screenTint.opacity(0.8))
                        .frame(
                            width: totalCount > 0
                                ? geo.size.width * CGFloat(reviewedCount) / CGFloat(totalCount)
                                : 0,
                            height: 6
                        )
                        .animation(.spring(response: 0.4), value: reviewedCount)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(reviewedCount) of \(totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Label("\(keptSongs.count)", systemImage: "checkmark")
                        .font(.caption).foregroundStyle(.green)
                    Label("\(removedSongs.count)", systemImage: "xmark")
                        .font(.caption).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            // Back card
            if remainingSongs.count > 1 {
                SwipeCard(
                    song: remainingSongs[1],
                    isTopCard: false,
                    onSwipeFinished: { _ in },
                    tintColor: .constant(.gray)
                )
                .scaleEffect(0.95)
                .offset(y: 14)
                .opacity(0.9)
            }

            // Top card — passes tint up to screen
            SwipeCard(
                song: remainingSongs[0],
                isTopCard: true,
                onSwipeFinished: { swipedRight in
                    let decided = remainingSongs.removeFirst()
                    history.append(SwipeDecision(song: decided, kept: swipedRight))
                    if swipedRight { keptSongs.append(decided) }
                    else           { removedSongs.append(decided) }
                },
                tintColor: $screenTint
            )
            .id(remainingSongs[0].id)
        }
    }


    // MARK: - Undo Button

    private var undoButton: some View {
        Button {
            undoLastSwipe()
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .disabled(history.isEmpty)
        .opacity(history.isEmpty ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.2), value: history.isEmpty)
    }

    // MARK: - Session Complete

    private var sessionCompleteView: some View {
        VStack(spacing: 28) {
            Image(systemName: "music.note.list")
                .font(.system(size: 52))
                .foregroundStyle(screenTint)

            VStack(spacing: 8) {
                Text("Playlist Retuned")
                    .font(.title).fontWeight(.bold)
                Text("Here's your session summary")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            // Stats
            HStack(spacing: 32) {
                statBadge(count: keptSongs.count, label: "Kept", color: .green, icon: "checkmark.circle.fill")
                statBadge(count: removedSongs.count, label: "Archived", color: .red, icon: "archivebox.fill")
            }

            // Actions (PDR: save as new, discard, share)
            VStack(spacing: 12) {
                Button {
                    goToSave = true
                } label: {
                    Label("Save to Apple Music", systemImage: "music.note.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(screenTint.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(role: .destructive) {
                    // Discard — pop navigation
                } label: {
                    Text("Discard Session")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemFill))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 20)
        .padding(24)
    }

    private func statBadge(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title).fontWeight(.bold)
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
    }

    // MARK: - Undo Logic

    private func undoLastSwipe() {
        guard let last = history.popLast() else { return }

        if last.kept { keptSongs.removeAll { $0.id == last.song.id } }
        else         { removedSongs.removeAll { $0.id == last.song.id } }

        remainingSongs.insert(last.song, at: 0)
    }
}
