import SwiftUI
import WikipediaKit
import WikipediaUI

/// Wiki Reader for the Mac: Today on Wikipedia, search and article summaries, in any language,
/// from the live Wikipedia APIs.
@main
struct WikiReaderMacApp: App {
    @State private var store: ReaderStore
    private let scene = ScreenshotScene.current

    init() {
        _store = State(initialValue: ReaderStore.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup("Wiki Reader") {
            ReaderRootView(scene: scene)
                .environment(store)
                .wikiImageLoader(scene == nil ? WikiImageLoader.client(store.client) : ScreenshotScene.imageLoader(client: store.client))
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(scene == nil ? nil : .dark)
                .tint(ReaderTheme.accent)
                .background {
                    if let scene {
                        ScreenshotWindow(scene: scene)
                    }
                }
        }
        .defaultSize(width: 1440, height: 900)
    }
}
