//
//  ArtworkView.swift
//  Retune
//
//  Created by Eliase Osmani on 2/11/26.
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
                    .scaledToFit()
                    .onAppear {
                        if let avg = img.averageColor {
                            tintColor = Color(uiColor: avg)
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
            }
        }
        .task {
            await loader.load(from: url)
        }
    }
}
