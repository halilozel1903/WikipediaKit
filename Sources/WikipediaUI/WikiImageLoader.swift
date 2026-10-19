import SwiftUI
import WikipediaKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Loads the bytes of an image URL. The views in this module load images through the loader in
/// the environment, so you can route them through your ``WikipediaClient`` (and its User-Agent),
/// your own cache, or bundled images in previews and tests.
///
/// ```swift
/// ContentView()
///     .wikiImageLoader(.client(wikipedia))
/// ```
public struct WikiImageLoader: Sendable {
    private let load: @Sendable (URL) async throws -> Data

    public init(_ load: @escaping @Sendable (URL) async throws -> Data) {
        self.load = load
    }

    public func data(for url: URL) async throws -> Data {
        try await load(url)
    }

    /// Loads with `client`, which sends its User-Agent and retries busy answers, keeping recent
    /// images in memory. File URLs are read from disk.
    public static func client(_ client: WikipediaClient) -> WikiImageLoader {
        WikiImageLoader { url in
            if url.isFileURL {
                return try Data(contentsOf: url)
            }
            if let cached = await ImageDataCache.shared.data(for: url) {
                return cached
            }
            let data = try await client.imageData(from: url)
            await ImageDataCache.shared.insert(data, for: url)
            return data
        }
    }

    /// The default loader: `URLSession.shared` with a User-Agent naming WikipediaKit. Apps should
    /// use ``client(_:)`` so that image requests carry their own User-Agent.
    public static let standard = WikiImageLoader { url in
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        if let cached = await ImageDataCache.shared.data(for: url) {
            return cached
        }
        var request = URLRequest(url: url)
        request.setValue(
            "WikipediaKit/" + WikipediaUserAgent.libraryVersion + " (https://github.com/halilozel1903/WikipediaKit)",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        await ImageDataCache.shared.insert(data, for: url)
        return data
    }
}

/// Recently loaded image bytes.
actor ImageDataCache {
    static let shared = ImageDataCache()

    private var entries: [URL: Data] = [:]
    private var order: [URL] = []
    private let limit = 200

    func data(for url: URL) -> Data? {
        entries[url]
    }

    func insert(_ data: Data, for url: URL) {
        if entries[url] == nil {
            order.append(url)
        }
        entries[url] = data
        while order.count > limit {
            entries[order.removeFirst()] = nil
        }
    }
}

/// Decoded images, so an image that scrolls back into view appears at once.
@MainActor
final class DecodedImageCache {
    static let shared = DecodedImageCache()

    private var images: [URL: Image] = [:]
    private var order: [URL] = []
    private let limit = 200

    func image(for url: URL) -> Image? {
        images[url]
    }

    func insert(_ image: Image, for url: URL) {
        if images[url] == nil {
            order.append(url)
        }
        images[url] = image
        while order.count > limit {
            images[order.removeFirst()] = nil
        }
    }

    static func decode(_ data: Data) -> Image? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}

private struct WikiImageLoaderKey: EnvironmentKey {
    static let defaultValue: WikiImageLoader = .standard
}

extension EnvironmentValues {
    /// The loader ``WikiRemoteImage`` views use. Defaults to ``WikiImageLoader/standard``.
    public var wikiImageLoader: WikiImageLoader {
        get { self[WikiImageLoaderKey.self] }
        set { self[WikiImageLoaderKey.self] = newValue }
    }
}

extension View {
    /// Loads every image below this view with `loader`.
    public func wikiImageLoader(_ loader: WikiImageLoader) -> some View {
        environment(\.wikiImageLoader, loader)
    }
}

/// An image from a URL that fills the space it is given, with a placeholder while it loads or
/// when there is no image. Give it a frame or an aspect ratio.
public struct WikiRemoteImage<Placeholder: View>: View {
    private let url: URL?
    private let contentMode: ContentMode
    private let placeholder: Placeholder

    @Environment(\.wikiImageLoader) private var loader
    @State private var loaded: LoadedImage?

    public init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    public var body: some View {
        Color.clear
            .overlay {
                if let image = currentImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                } else {
                    placeholder
                }
            }
            .clipped()
            .task(id: url) {
                await load()
            }
    }

    private var currentImage: Image? {
        guard let url else { return nil }
        if let loaded, loaded.url == url {
            return loaded.image
        }
        return DecodedImageCache.shared.image(for: url)
    }

    private func load() async {
        guard let url, DecodedImageCache.shared.image(for: url) == nil else { return }
        guard let data = try? await loader.data(for: url), !Task.isCancelled else { return }
        guard let image = DecodedImageCache.decode(data) else { return }
        DecodedImageCache.shared.insert(image, for: url)
        withAnimation(.easeOut(duration: 0.2)) {
            loaded = LoadedImage(url: url, image: image)
        }
    }
}

extension WikiRemoteImage where Placeholder == WikiImagePlaceholder {
    /// An image with the standard placeholder.
    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.init(url: url, contentMode: contentMode) { WikiImagePlaceholder() }
    }
}

/// A quiet placeholder with the Wikipedia "W" glyph.
public struct WikiImagePlaceholder: View {
    public init() {}

    public var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Text("W")
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct LoadedImage {
    let url: URL
    let image: Image
}
