//
//  RetuneApp.swift
//  Retune
//
//  Created by Eliase Osmani on 2/10/26.
//

import SwiftUI

@main
struct RetuneApp: App {
    @StateObject private var playlistManager = PlaylistManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playlistManager)
        }
    }
}
