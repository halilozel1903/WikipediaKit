import SwiftUI
import WikipediaKit
import WikipediaUI

/// Full-text search of the chosen Wikipedia, with each result's description and thumbnail.
struct SearchScreen: View {
    let scene: ScreenshotScene?

    @Environment(ReaderStore.self) private var store
    @State private var text: String
    @State private var submitted: String
    @State private var state: Loadable<SearchOutcome>?

    init(scene: ScreenshotScene?) {
        self.scene = scene
        let initial = scene == .search ? ScreenshotScene.searchText : ""
        _text = State(initialValue: initial)
        _submitted = State(initialValue: initial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                results
            }
            .padding(24)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Search")
        .readerNavigationStyle()
        .searchable(text: $text, prompt: "Search " + store.language.autonym + " Wikipedia")
        .onSubmit(of: .search) { submitted = text.trimmingCharacters(in: .whitespaces) }
        .task(id: submitted) { await run() }
        .signalsScreenshotReady(scene, when: (state?.value?.hits.count ?? 0) >= 8, minimumImages: minimumImages)
    }

    private var minimumImages: Int {
        min(4, state?.value?.hits.filter { $0.thumbnail != nil }.count ?? 0)
    }

    @ViewBuilder
    private var results: some View {
        switch state {
        case nil:
            ContentUnavailableView(
                "Search Wikipedia",
                systemImage: "magnifyingglass",
                description: Text("Full-text search of every article on " + store.language.host + ".")
            )
        case .loading?:
            ProgressView().frame(maxWidth: .infinity, minHeight: 300)
        case let .failed(message)?:
            ContentUnavailableView("Search failed", systemImage: "wifi.exclamationmark", description: Text(message))
        case let .loaded(outcome)?:
            if outcome.hits.isEmpty {
                ContentUnavailableView.search(text: submitted)
            } else {
                header(outcome.results)
                VStack(spacing: 0) {
                    ForEach(outcome.hits) { hit in
                        NavigationLink(value: ArticleRoute(title: hit.title, language: store.language.rawValue)) {
                            SearchHitRow(hit: hit)
                        }
                        .buttonStyle(.plain)
                        if hit.id != outcome.hits.last?.id {
                            Divider().padding(.leading, 92)
                        }
                    }
                }
                .padding(.vertical, 4)
                .readerCard()
            }
        }
    }

    private func header(_ results: SearchResults) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("“" + results.query + "”")
                .font(ReaderTheme.serif(.title, weight: .bold))
            HStack(spacing: 6) {
                if let total = results.totalHits {
                    Text("\(total.formatted()) articles")
                }
                Text("·")
                Text(store.language.host)
                if let suggestion = results.suggestion {
                    Text("·")
                    Button("Did you mean “" + suggestion + "”?") {
                        text = suggestion
                        submitted = suggestion
                    }
                    .buttonStyle(.borderless)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func run() async {
        guard !submitted.isEmpty else {
            state = nil
            return
        }
        state = .loading
        do {
            state = .loaded(try await store.search(submitted))
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

/// A search result: thumbnail, title, short description and the matching snippet.
struct SearchHitRow: View {
    let hit: SearchHit

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            WikiRemoteImage(url: hit.thumbnail.map { WikimediaThumbnail.url($0.source, width: 250, originalWidth: nil) })
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(hit.title)
                    .font(.headline)
                if let description = hit.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let snippet = hit.result.snippet {
                    Text(snippet + "…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let words = hit.result.wordCount {
                Text("\(words.formatted()) words")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
