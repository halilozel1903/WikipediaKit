import SwiftUI
import WikipediaKit
import WikipediaUI

/// Wiki Reader for iPad: Today on Wikipedia, search and article summaries, in any language,
/// from the live Wikipedia APIs.
@main
struct WikiReaderApp: App {
    @State private var store: ReaderStore
    private let scene = ScreenshotScene.current

    init() {
        _store = State(initialValue: ReaderStore.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup {
            ReaderRootView(scene: scene)
                .environment(store)
                // Images go through the client so they carry its User-Agent. Screenshot scenes
                // count their image loads, to report ready once all are on screen.
                .wikiImageLoader(scene == nil ? WikiImageLoader.client(store.client) : ScreenshotScene.imageLoader(client: store.client))
                .preferredColorScheme(scene == nil ? nil : .dark)
                .tint(ReaderTheme.accent)
        }
    }
}
