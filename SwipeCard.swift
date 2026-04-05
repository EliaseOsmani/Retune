//
//  SwipeCard.swift
//  Retune
//

import SwiftUI
import UIKit

struct SwipeCard: View {
    let song: Song
    let isTopCard: Bool
    let onSwipeFinished: (_ swipedRight: Bool) -> Void

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var isDraggingEnabled = true

    // Haptics — distinct generators per direction (PDR: distinct patterns)
    @State private var lastThresholdState: ThresholdState = .none
    private let keepFeedback   = UIImpactFeedbackGenerator(style: .medium)
    private let removeFeedback = UIImpactFeedbackGenerator(style: .rigid)

    // Tint color driven by artwork (also passed up to parent for screen bg)
    @Binding var tintColor: Color

    // Audio
    @StateObject private var audio = AudioPreviewPlayer.shared

    // PDR: ~40% screen width OR velocity > 500 pts/sec
    private let swipeThresholdRatio: CGFloat = 0.40
    private let velocityThreshold:   CGFloat = 500
    private let offscreenX:          CGFloat = 900

    enum ThresholdState { case none, left, right }

    var body: some View {
        GeometryReader { geo in
            let swipeThreshold = geo.size.width * swipeThresholdRatio

            ZStack(alignment: .bottom) {

                // ── HERO: Full-bleed album art ──────────────────────────────
                ArtworkView(url: song.artworkURL, tintColor: $tintColor)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // ── Gradient scrim so text is legible over art ──────────────
                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // ── Song info overlay at bottom ─────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.80))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)

                // ── Swipe direction labels ──────────────────────────────────
                if isTopCard {
                    HStack {
                        if offset.width < -40 {
                            Label("REMOVE", systemImage: "xmark")
                                .font(.headline).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.vertical, 8).padding(.horizontal, 14)
                                .background(.red.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.leading, 20)
                                .transition(.opacity)
                        }
                        Spacer()
                        if offset.width > 40 {
                            Label("KEEP", systemImage: "checkmark")
                                .font(.headline).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.vertical, 8).padding(.horizontal, 14)
                                .background(.green.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.trailing, 20)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 20)
                    .animation(.easeInOut(duration: 0.15), value: offset.width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            // Subtle tint border
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(tintColor.opacity(0.30), lineWidth: 1)
            )
            .offset(isTopCard ? offset : .zero)
            .rotationEffect(.degrees(isTopCard ? rotation : 0))
            .gesture(isTopCard && isDraggingEnabled ? dragGesture(threshold: swipeThreshold) : nil)
            .onAppear {
                keepFeedback.prepare()
                removeFeedback.prepare()
                if isTopCard { audio.play(url: song.previewURL) }
            }
            .onDisappear {
                if isTopCard { audio.stop() }
            }
        }
    }

    // MARK: - Drag Gesture

    private func dragGesture(threshold: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { gesture in
                offset   = gesture.translation
                rotation = Double(gesture.translation.width / 18)
                handleThresholdHaptics(for: offset.width, threshold: threshold)
            }
            .onEnded { gesture in
                // PDR: commit on velocity > 500 pts/sec OR distance > threshold
                let velocity = abs(gesture.predictedEndTranslation.width - gesture.translation.width)
                let committedRight = offset.width > threshold  || (velocity > velocityThreshold && offset.width > 0)
                let committedLeft  = offset.width < -threshold || (velocity > velocityThreshold && offset.width < 0)

                if committedRight      { swipeOut(toRight: true) }
                else if committedLeft  { swipeOut(toRight: false) }
                else                   { snapBack() }
            }
    }

    // MARK: - Haptics (distinct per direction — PDR requirement)

    private func handleThresholdHaptics(for x: CGFloat, threshold: CGFloat) {
        let newState: ThresholdState
        if      x >  threshold { newState = .right }
        else if x < -threshold { newState = .left  }
        else                   { newState = .none  }

        if newState != lastThresholdState {
            switch newState {
            case .right: keepFeedback.impactOccurred();   keepFeedback.prepare()
            case .left:  removeFeedback.impactOccurred(); removeFeedback.prepare()
            case .none:  break
            }
            lastThresholdState = newState
        }
    }

    // MARK: - Animation helpers

    private func snapBack() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            offset   = .zero
            rotation = 0
        }
        lastThresholdState = .none
    }

    private func swipeOut(toRight: Bool) {
        isDraggingEnabled = false
        withAnimation(.easeOut(duration: 0.22)) {
            offset   = CGSize(width: toRight ? offscreenX : -offscreenX, height: offset.height * 0.2)
            rotation = toRight ? 18 : -18
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            lastThresholdState = .none
            isDraggingEnabled  = true
            if isTopCard { audio.stop() }
            onSwipeFinished(toRight)
        }
    }
}
