//
//  ImageLoader.swift
//  Retune
//
//  Created by Eliase Osmani on 2/11/26.
//

import Foundation
import UIKit
import Combine

@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    private var currentURL: URL?

    func load(from url: URL?) async {
        guard let url else {
            image = nil
            return
        }

        // If already loaded for this URL, don't redo work
        if currentURL == url, image != nil { return }
        currentURL = url

        // ✅ Cache lookup
        if let cached = ImageCache.shared.image(for: url) {
            image = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let img = UIImage(data: data) else {
                image = nil
                return
            }

            // ✅ Cache store
            ImageCache.shared.set(img, for: url)
            image = img
        } catch {
            image = nil
        }
    }
}
