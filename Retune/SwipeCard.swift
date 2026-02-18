//
//  SwipeCard.swift
//  Retune
//
//  Created by Eliase Osmani on 2/11/26.
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

    // Haptics
    @State private var lastThresholdState: ThresholdState = .none
    private let feedback = UIImpactFeedbackGenerator(style: .medium)

    // Tint Color (driven by artwork)
    @State private var tintColor: Color = .gray
    
    //Audio Playback Trigger
    @StateObject private var audio = AudioPreviewPlayer.shared

    private let swipeThreshold: CGFloat = 120
    private let offscreenX: CGFloat = 900

    enum ThresholdState {
        case none
        case left
        case right
    }

    var body: some View {
        VStack(spacing: 14) {

            ArtworkView(url: song.artworkURL, tintColor: $tintColor)
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(radius: 8)

            VStack(spacing: 6) {
                Text(song.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(song.artist)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 280)
        .background(
            RoundedRectangle(cornerRadius: 24)
                //Creates a solid base on the card
                .fill(Color(.systemBackground))
            
                //Creates tinted layer on top
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(0.22),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                        )
                    )
            
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(tintColor.opacity(0.25), lineWidth: 1)
                )
                .shadow(radius: 12)
        )
        .overlay(alignment: .topLeading) {
            // Only show labels on the top card
            if isTopCard {
                if offset.width > 40 {
                    Text("KEEP")
                        .font(.headline)
                        .padding(10)
                        .background(.green.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 3)
                        .padding()
                } else if offset.width < -40 {
                    Text("REMOVE")
                        .font(.headline)
                        .padding(10)
                        .background(.red.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 3)
                        .padding()
                }
            }
        }
        // ✅ Only the TOP card should move/rotate
        .offset(isTopCard ? offset : .zero)
        .rotationEffect(.degrees(isTopCard ? rotation : 0))
        // ✅ Only the TOP card should be draggable
        .gesture(isTopCard && isDraggingEnabled ? dragGesture : nil)
        .onAppear {
            // Preps haptics so no lag
            feedback.prepare()
            
            //Audio Implementation - Play
            if isTopCard {
                audio.play(url: song.previewURL)
            }
        }
        
        .onDisappear() {
            //Audio Implementation - Pause
            if isTopCard {
                audio.stop()
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                offset = gesture.translation
                rotation = Double(gesture.translation.width / 18)
                handleThresholdHaptics(for: offset.width)
            }
            .onEnded { _ in
                handleRelease()
            }
    }

    private func handleThresholdHaptics(for x: CGFloat) {
        let newState: ThresholdState
        if x > swipeThreshold {
            newState = .right
        } else if x < -swipeThreshold {
            newState = .left
        } else {
            newState = .none
        }

        // Only when state changes (crossing in or out)
        if newState != lastThresholdState {
            // Fire when entering left/right threshold (not when returning to none)
            if newState == .left || newState == .right {
                feedback.impactOccurred()
                feedback.prepare()
            }
            lastThresholdState = newState
        }
    }

    private func handleRelease() {
        if offset.width > swipeThreshold {
            swipeOut(toRight: true)
        } else if offset.width < -swipeThreshold {
            swipeOut(toRight: false)
        } else {
            snapBack()
        }
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            offset = .zero
            rotation = 0
        }
        lastThresholdState = .none
    }

    private func swipeOut(toRight: Bool) {
        isDraggingEnabled = false

        withAnimation(.easeOut(duration: 0.22)) {
            offset = CGSize(
                width: toRight ? offscreenX : -offscreenX,
                height: offset.height * 0.2
            )
            rotation = toRight ? 18 : -18
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            lastThresholdState = .none
            isDraggingEnabled = true
            if isTopCard { audio.stop() }
            onSwipeFinished(toRight)
        }
    }
}
