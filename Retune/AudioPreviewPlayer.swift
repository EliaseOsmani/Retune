//
//  AudioPreviewPlayer.swift
//  Retune
//
//  Created by Eliase Osmani on 2/11/26.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioPreviewPlayer: ObservableObject {
    static let shared = AudioPreviewPlayer()
    
    private var player: AVPlayer?
    private var currentURL: URL?
    
    private init() {}
    
    func play(url: URL?) {
        guard let url else { return }
        
        //Don't Restart if already playing same preview
        if currentURL == url {return}
        currentURL = url
        
        //Blend audios together smoothly
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            //if Audio session fails, we can still try playing audio
        }
        
        player?.pause()
        player = AVPlayer(playerItem: AVPlayerItem(url: url))
        player?.play()
    }
    
    //Stop playing function
    func stop() {
        player?.pause()
        player = nil
        currentURL = nil
    }
}
