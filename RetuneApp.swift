//
//  RetuneApp.swift
//  Retune
//

import SwiftUI
import SwiftData

@main
struct RetuneApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: SessionRecord.self)
    }
}
