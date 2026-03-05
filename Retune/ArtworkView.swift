//
//  ArtworkView.swift
//  Retune
//

import SwiftUI
import UIKit

struct ArtworkView: View {
    let url: URL?
    @Binding var tintColor: Color

    @StateObject private var loader = ImageLoader()

    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .onAppear {
                        if let avg = img.averageColor {
                            tintColor = Color(uiColor: avg)
                        }
                    }
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemGray4), Color(.systemGray6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task { await loader.load(from: url) }
    }
}
