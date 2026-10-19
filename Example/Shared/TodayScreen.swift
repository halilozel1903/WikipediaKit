import SwiftUI
import WikipediaKit
import WikipediaUI

/// The Today page: the featured article, the picture of the day, the most-read articles of the
/// day before, on this day and in the news, from the featured feed of one day.
struct TodayScreen: View {
    let scene: ScreenshotScene?

    @Environment(ReaderStore.self) private var store
    @State private var state: Loadable<FeaturedContent> = .loading

    private var date: WikiFeedDate {
        scene == .today ? ScreenshotScene.featuredDate : .today
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                switch state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 320)
                case let .failed(message):
                    ContentUnavailableView {
                        Label("Today isn't available", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                case let .loaded(feed):
                    sections(feed)
                }
            }
            .padding(24)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Today")
        .readerNavigationStyle()
        .task(id: date) { await load() }
        .refreshable { await load() }
        .signalsScreenshotReady(scene, when: isReadyForScreenshot, minimumImages: 4)
    }

    /// The featured article, the picture of the day and most-read articles are on screen.
    private var isReadyForScreenshot: Bool {
        guard let feed = state.value else { return false }
        return feed.featuredArticle != nil && feed.pictureOfTheDay != nil && (feed.mostRead?.articles.count ?? 0) >= 6
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(date.date.map { $0.formatted(Date.FormatStyle(date: .complete, time: .omitted, timeZone: TimeZone(identifier: "UTC")!)) } ?? date.description)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("Today on Wikipedia")
                .font(ReaderTheme.serif(.largeTitle, weight: .bold))
            Text(store.language.autonym + " · " + store.language.host)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func sections(_ feed: FeaturedContent) -> some View {
        if feed.isEmpty {
            ContentUnavailableView("Nothing featured", systemImage: "newspaper", description: Text("This Wikipedia has no featured content for the day."))
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 20, alignment: .top)], alignment: .leading, spacing: 20) {
            if let article = feed.featuredArticle {
                FeaturedArticleCard(page: article)
            }
            if let picture = feed.pictureOfTheDay {
                PictureOfTheDayCard(picture: picture)
            }
        }
        if let mostRead = feed.mostRead, !mostRead.articles.isEmpty {
            MostReadSection(mostRead: mostRead)
        }
        if !feed.onThisDay.isEmpty {
            OnThisDaySection(events: Array(feed.onThisDay.prefix(6)))
        }
        if !feed.news.isEmpty {
            NewsSection(items: Array(feed.news.prefix(4)))
        }
        WikipediaAttribution()
    }

    private func load() async {
        if state.value == nil {
            state = .loading
        }
        do {
            state = .loaded(try await store.featured(on: date))
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

/// A section title in the serif face.
struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(ReaderTheme.serif(.title2))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A small caps label above a card's title.
struct Eyebrow: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(ReaderTheme.accent)
    }
}

/// Today's featured article: its image, title, description and first paragraph.
struct FeaturedArticleCard: View {
    let page: PageSummary

    var body: some View {
        NavigationLink(value: ArticleRoute(title: page.title, language: page.language ?? "en")) {
            VStack(alignment: .leading, spacing: 0) {
                ArticleThumbnail(page: page, width: 960)
                    .frame(height: 230)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Featured article", systemImage: "star.fill")
                    Text(page.displayTitle)
                        .font(ReaderTheme.serif(.title))
                        .lineLimit(2)
                    if let description = page.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let extract = page.extract {
                        Text(extract)
                            .font(.callout)
                            .lineLimit(5)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .readerCard()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The picture of the day with its description, author and license.
struct PictureOfTheDayCard: View {
    let picture: PictureOfTheDay
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = picture.filePageURL { openURL(url) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                WikiRemoteImage(url: picture.imageURL(width: 960))
                    .frame(height: 230)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Picture of the day", systemImage: "photo")
                    Text(picture.displayTitle)
                        .font(ReaderTheme.serif(.title3))
                        .lineLimit(2)
                    if let description = picture.plainDescription {
                        Text(description)
                            .font(.callout)
                            .lineLimit(5)
                    }
                    Text([picture.plainArtist, picture.license].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .readerCard()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// The ten most-read articles of the day before, with their views.
struct MostReadSection: View {
    let mostRead: MostRead

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Most read",
                subtitle: mostRead.day?.date.map { $0.formatted(Date.FormatStyle(date: .long, time: .omitted, timeZone: TimeZone(identifier: "UTC")!)) }
            )
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16, alignment: .top)], alignment: .leading, spacing: 12) {
                ForEach(Array(mostRead.articles.prefix(10).enumerated()), id: \.element.id) { index, article in
                    NavigationLink(value: ArticleRoute(title: article.page.title, language: article.page.language ?? "en")) {
                        ArticleRow(page: article.page, rank: index + 1, detail: article.views.compactViews)
                            .padding(10)
                            .readerCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Anniversaries of the day, each with the year and the image of its main article.
struct OnThisDaySection: View {
    let events: [OnThisDayEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "On this day")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(events) { event in
                    OnThisDayRow(event: event)
                    if event.id != events.last?.id {
                        Divider().padding(.leading, 86)
                    }
                }
            }
            .padding(.vertical, 4)
            .readerCard()
        }
    }
}

struct OnThisDayRow: View {
    let event: OnThisDayEvent

    var body: some View {
        let row = HStack(alignment: .top, spacing: 14) {
            Text(event.yearText ?? "")
                .font(ReaderTheme.serif(.title3, weight: .bold))
                .foregroundStyle(ReaderTheme.accent)
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)
            Text(event.text)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let page = event.leadPage, page.thumbnail != nil {
                ArticleThumbnail(page: page, width: 120)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())

        if let page = event.leadPage {
            NavigationLink(value: ArticleRoute(title: page.title, language: page.language ?? "en")) {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }
}

/// In the news, for the current day.
struct NewsSection: View {
    let items: [NewsItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "In the news")
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.story)
                        .font(.callout)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(item.links.prefix(4)) { page in
                                NavigationLink(value: ArticleRoute(title: page.title, language: page.language ?? "en")) {
                                    Text(page.displayTitle)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(.quaternary, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .readerCard()
            }
        }
    }
}
