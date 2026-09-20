//
//  FaviconView.swift
//  nextBookmark
//
//  Nextcloud Bookmarks crawls and caches a favicon per bookmark server-side;
//  this loads it (authenticated, like every other request) and falls back
//  to a generic globe glyph while loading or if none is cached yet.
//

import SwiftUI

/// Keeps re-scrolling the bookmark list from re-fetching the same favicon
/// over and over. Cleared on relaunch; that's fine, favicons rarely change.
private final class FaviconCache {
    static let shared = FaviconCache()
    private let cache = NSCache<NSNumber, UIImage>()

    func image(for id: Int) -> UIImage? { cache.object(forKey: NSNumber(value: id)) }
    func store(_ image: UIImage, for id: Int) { cache.setObject(image, forKey: NSNumber(value: id)) }
}

struct FaviconView: View {
    let bookmarkId: Int
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "globe")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 20, height: 20)
        .onAppear(perform: load)
    }

    private func load() {
        guard image == nil else { return }
        if let cached = FaviconCache.shared.image(for: bookmarkId) {
            image = cached
            return
        }
        CallNextcloud().fetchFavicon(bookmarkId: bookmarkId) { data in
            guard let data = data, let loaded = UIImage(data: data) else { return }
            FaviconCache.shared.store(loaded, for: bookmarkId)
            DispatchQueue.main.async {
                image = loaded
            }
        }
    }
}
