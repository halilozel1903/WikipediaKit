import SwiftUI
import WikipediaKit
import WikipediaUI

/// An article's summary: the lead image, title, description, first paragraph, links, and the
/// related articles.
struct ArticleScreen: View {
    let route: ArticleRoute
    let scene: ScreenshotScene?

    @Environment(ReaderStore.self) private var store
    @State private var summary: Loadable<PageSummary> = .loading
    @State private var related: Loadable<[PageSummary]> = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch summary {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 360)
                case let .failed(message):
                    ContentUnavailableView {
                        Label("Couldn't load \(route.title)", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                case let .loaded(page):
                    ArticleHeader(page: page)
                    relatedSection
                    WikipediaAttribution(page: page)
                }
            }
            .padding(24)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(summary.value?.displayTitle ?? route.title)
        .readerNavigationStyle()
        .toolbar {
            if let url = summary.value?.webURL {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: url)
                }
            }
        }
        .task(id: route) { await load() }
        .signalsScreenshotReady(scene, when: isReadyForScreenshot, minimumImages: minimumImages)
    }

    private var isReadyForScreenshot: Bool {
        summary.value != nil && (related.value?.count ?? 0) >= 4
    }

    /// The lead image and the related articles' thumbnails that should be on screen.
    private var minimumImages: Int {
        let lead = summary.value?.thumbnail == nil ? 0 : 1
        let thumbnails = related.value?.filter { $0.thumbnail != nil }.count ?? 0
        return lead + min(3, thumbnails)
    }

    @ViewBuilder
    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Related articles")
            switch related {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 160)
            case let .failed(message):
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case let .loaded(pages):
                if pages.isEmpty {
                    Text("No related articles.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 16, alignment: .top)], alignment: .leading, spacing: 16) {
                        ForEach(pages) { page in
                            NavigationLink(value: ArticleRoute(title: page.title, language: page.language ?? route.language)) {
                                RelatedCard(page: page)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func load() async {
        do {
            summary = .loaded(try await store.summary(route))
        } catch is CancellationError {
            return
        } catch {
            summary = .failed(error.localizedDescription)
            return
        }
        do {
            related = .loaded(try await store.related(route))
        } catch is CancellationError {
            return
        } catch {
            related = .failed(error.localizedDescription)
        }
    }
}

/// The top of an article: image, title, description, first paragraph and links.
struct ArticleHeader: View {
    let page: PageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if page.thumbnail != nil {
                WikiRemoteImage(url: page.imageURL(width: 960), contentMode: .fit)
                    .aspectRatio(page.imageAspectRatio.map { CGFloat(max(0.6, min($0, 2.2))) } ?? 1.5, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(page.displayTitle)
                    .font(ReaderTheme.serif(.largeTitle, weight: .bold))
                if let description = page.description {
                    Text(description)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            if let extract = page.extract {
                Text(extract)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            HStack(spacing: 12) {
                if let url = page.webURL {
                    Link(destination: url) {
                        Label("Read on Wikipedia", systemImage: "safari")
                    }
                    .buttonStyle(.borderedProminent)
                }
                if let item = page.wikidataItem, let url = URL(string: "https://www.wikidata.org/wiki/" + item) {
                    Link(destination: url) {
                        Label(item, systemImage: "barcode")
                    }
                    .buttonStyle(.bordered)
                }
                if let coordinates = page.coordinates {
                    Label(
                        String(format: "%.3f, %.3f", coordinates.latitude, coordinates.longitude),
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// A related article: thumbnail, title and description.
struct RelatedCard: View {
    let page: PageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArticleThumbnail(page: page, width: 500)
                .frame(height: 130)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                Text(page.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                Text(page.description ?? page.extract ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        }
        .readerCard()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
