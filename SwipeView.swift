//
//  SwipeView.swift
//  Retune
//

import SwiftUI
import SwiftData

// MARK: - Swipe Decision (in-memory, for undo support)

private struct SwipeDecision {
    let song: Song
    let kept: Bool
}

// MARK: - RetuneSwipeView

struct RetuneSwipeView: View {
    let allSongs: [Song]
    let playlistID:   String
    let playlistName: String
    let orderMode:    String

    @State private var remainingSongs: [Song]
    @State private var history:        [SwipeDecision] = []
    @State private var keptSongs:      [Song] = []
    @State private var removedSongs:   [Song] = []
    @State private var goToSave = false
    @State private var screenTint: Color = .black

    // SwiftData
    @Environment(\.modelContext) private var modelContext
    @State private var sessionRecord: SessionRecord? = nil

    init(songs: [Song], playlistID: String, playlistName: String, orderMode: String) {
        self.allSongs     = songs
        self.playlistID   = playlistID
        self.playlistName = playlistName
        self.orderMode    = orderMode
        _remainingSongs   = State(initialValue: songs)
    }

    private var totalCount:    Int { allSongs.count }
    private var reviewedCount: Int { totalCount - remainingSongs.count }

    var body: some View {
        ZStack {
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
                    progressBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    cardStack
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 16)

                    undoButton
                        .padding(.bottom, 24)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToSave) {
            SaveRetunedPlaylistView(keptSongs: keptSongs, removedSongs: removedSongs, platform: playlistID.hasPrefix("spotify:") ? "spotify" : "appleMusic")
        }
        .onAppear { restoreOrCreateSession() }
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
                    .font(.caption).foregroundStyle(.secondary)
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

            SwipeCard(
                song: remainingSongs[0],
                isTopCard: true,
                onSwipeFinished: { swipedRight in
                    let decided = remainingSongs.removeFirst()
                    history.append(SwipeDecision(song: decided, kept: swipedRight))
                    if swipedRight { keptSongs.append(decided) }
                    else           { removedSongs.append(decided) }
                    persistDecision(song: decided, kept: swipedRight)
                },
                tintColor: $screenTint
            )
            .id(remainingSongs[0].id)
        }
    }

    // MARK: - Undo Button

    private var undoButton: some View {
        Button { undoLastSwipe() } label: {
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

            HStack(spacing: 32) {
                statBadge(count: keptSongs.count,    label: "Kept",     color: .green, icon: "checkmark.circle.fill")
                statBadge(count: removedSongs.count, label: "Archived", color: .red,   icon: "archivebox.fill")
            }

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
                    deleteSession()
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
        .onAppear { deleteSession() }  // session complete — clean up record
    }

    private func statBadge(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text("\(count)").font(.title).fontWeight(.bold)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
    }

    // MARK: - Undo Logic

    private func undoLastSwipe() {
        guard let last = history.popLast() else { return }

        if last.kept { keptSongs.removeAll  { $0.id == last.song.id } }
        else         { removedSongs.removeAll { $0.id == last.song.id } }

        remainingSongs.insert(last.song, at: 0)
        undoPersistedDecision(song: last.song)
    }

    // MARK: - SwiftData: Session lifecycle

    /// On appear — either restore an existing session for this playlist, or create a new one.
    private func restoreOrCreateSession() {
        let id = playlistID

        // Fetch any existing record for this playlist
        let descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.playlistID == id }
        )
        let existing = (try? modelContext.fetch(descriptor))?.first

        if let record = existing, !record.isComplete {
            // Restore state from the saved record
            sessionRecord = record
            remainingSongs = record.remainingSongs
            keptSongs      = record.keptSongs
            removedSongs   = record.removedSongs
            // Rebuild in-memory history from decisions (enables undo after resume)
            history = record.decisions
                .sorted { $0.timestamp < $1.timestamp }
                .compactMap { decision in
                    guard let song = record.allSongs.first(where: { $0.id.uuidString == decision.songID })
                    else { return nil }
                    return SwipeDecision(song: song, kept: decision.kept)
                }
        } else {
            // Clean up any stale completed record and start fresh
            if let old = existing { modelContext.delete(old) }
            let record = SessionRecord(
                playlistID:   playlistID,
                playlistName: playlistName,
                orderMode:    orderMode,
                songs:        allSongs
            )
            modelContext.insert(record)
            sessionRecord = record
        }
    }

    /// Append a decision to the persisted record after every swipe.
    private func persistDecision(song: Song, kept: Bool) {
        guard let record = sessionRecord else { return }
        let decision = SongDecision(songID: song.id.uuidString, kept: kept)
        record.decisions.append(decision)
    }

    /// Remove the last decision from the persisted record when undoing.
    private func undoPersistedDecision(song: Song) {
        guard let record = sessionRecord else { return }
        // Remove the most recent decision for this song
        if let idx = record.decisions
            .sorted(by: { $0.timestamp > $1.timestamp })
            .firstIndex(where: { $0.songID == song.id.uuidString }) {
            let sorted = record.decisions.sorted(by: { $0.timestamp > $1.timestamp })
            let toRemove = sorted[idx]
            record.decisions.removeAll { $0.songID == toRemove.songID && $0.timestamp == toRemove.timestamp }
        }
    }

    /// Delete the session record when complete or discarded.
    private func deleteSession() {
        guard let record = sessionRecord else { return }
        modelContext.delete(record)
        sessionRecord = nil
    }
}
