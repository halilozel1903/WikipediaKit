import SwiftUI
import WikipediaKit
import WikipediaUI

/// What the sidebar can show.
enum SidebarItem: Hashable {
    case today
    case search
}

/// The whole app, on iPad and on the Mac: a sidebar with Today, Search, Random and the language,
/// and a detail column that pushes article pages.
struct ReaderRootView: View {
    let scene: ScreenshotScene?

    @Environment(ReaderStore.self) private var store
    @State private var selection: SidebarItem?
    @State private var columnVisibility: NavigationSplitViewVisibility
    @State private var path: [ArticleRoute]
    @State private var randomError: String?
    @State private var showsRandomError = false
    @State private var loadingRandom = false
    @State private var language: WikipediaLanguage = .english

    init(scene: ScreenshotScene?) {
        self.scene = scene
        _selection = State(initialValue: scene == .search ? .search : .today)
        // The iPad scenes show the page full width; the Mac scenes show the sidebar.
        #if os(iOS)
        let fullWidth = scene != nil
        #else
        let fullWidth = false
        #endif
        _columnVisibility = State(initialValue: fullWidth ? .detailOnly : .all)
        _path = State(initialValue: scene == .article ? [ArticleRoute(title: ScreenshotScene.articleTitle, language: "en")] : [])
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack(path: $path) {
                content
                    .navigationDestination(for: ArticleRoute.self) { route in
                        ArticleScreen(route: route, scene: scene == .article ? scene : nil)
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selection) { path = [] }
        .onChange(of: language) {
            store.setLanguage(language)
            path = []
        }
        .onAppear { language = store.language }
        .alert("Couldn't open a random article", isPresented: $showsRandomError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(randomError ?? "")
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Read") {
                Label("Today", systemImage: "newspaper")
                    .tag(SidebarItem.today)
                Label("Search", systemImage: "magnifyingglass")
                    .tag(SidebarItem.search)
            }
            Section("Discover") {
                Button {
                    Task { await openRandom() }
                } label: {
                    Label(loadingRandom ? "Finding an article…" : "Random article", systemImage: "shuffle")
                }
                .buttonStyle(.plain)
                .disabled(loadingRandom)
            }
            Section("Language") {
                Picker("Wikipedia", selection: $language) {
                    ForEach(WikipediaLanguage.common) { language in
                        Text(language.autonym).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Text(store.language.host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        #if os(macOS)
        // An opaque sidebar: a translucent one can be captured as a blank white panel on CI.
        .scrollContentBackground(.hidden)
        .background(ReaderTheme.sidebarBackground)
        #endif
        .navigationTitle("Wikipedia")
        .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
    }

    @ViewBuilder
    private var content: some View {
        switch selection ?? .today {
        case .today:
            if scene == .article {
                // The article scene opens straight on the article; the Today page below it would
                // only load images nobody sees.
                Color.clear
            } else {
                TodayScreen(scene: scene == .today ? scene : nil)
                    .id(store.language)
            }
        case .search:
            SearchScreen(scene: scene == .search ? scene : nil)
                .id(store.language)
        }
    }

    private func openRandom() async {
        loadingRandom = true
        defer { loadingRandom = false }
        do {
            let page = try await store.random()
            path.append(ArticleRoute(title: page.title, language: page.language ?? store.language.rawValue))
        } catch {
            randomError = error.localizedDescription
            showsRandomError = true
        }
    }
}
