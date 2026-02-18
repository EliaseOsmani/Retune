//
//  NavigationStack.swift
//  Retune
//
//  Created by Eliase Osmani on 2/17/26.
//

import SwiftUI

enum AppRoute: Hashable {
    case retune
}

struct RootView: View {
    @State private var path: [AppRoute] = []
    
    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationTitle("Retune")
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .retune:
                        RetunePlaylistsView()
                    }
                }
        }
    }
}

struct HomeView: View {
    @Binding var path: [AppRoute]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Home")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Retune"){ path.append(.retune) }
                    //Later Features "Friends"
                    //Later Features "Setting"
                    //Later Features "Feed"
                } label: {
                    Image(systemName: "line3.horizontal")
                }
            }
        }
    }
}
