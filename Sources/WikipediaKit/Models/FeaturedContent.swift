import Foundation

/// The featured feed of one day (`/feed/featured/{yyyy}/{mm}/{dd}`): the featured article, the
/// picture of the day, the previous day's most-read articles, events on this day, and news.
///
/// What a day has depends on the wiki and the date: news is only given for the current day,
/// the most-read list is for the day before, and smaller editions have no featured article.
/// Missing parts are `nil` or empty.
public struct FeaturedContent: Decodable, Sendable, Hashable {
    /// Today's featured article (`tfa`).
    public var featuredArticle: PageSummary?
    /// The most-read articles of the previous day (`mostread`).
    public var mostRead: MostRead?
    /// The picture of the day from Wikimedia Commons (`image`).
    public var pictureOfTheDay: PictureOfTheDay?
    /// In the news (`news`).
    public var news: [NewsItem]
    /// Selected anniversaries (`onthisday`).
    public var onThisDay: [OnThisDayEvent]

    public init(
        featuredArticle: PageSummary? = nil,
        mostRead: MostRead? = nil,
        pictureOfTheDay: PictureOfTheDay? = nil,
        news: [NewsItem] = [],
        onThisDay: [OnThisDayEvent] = []
    ) {
        self.featuredArticle = featuredArticle
        self.mostRead = mostRead
        self.pictureOfTheDay = pictureOfTheDay
        self.news = news
        self.onThisDay = onThisDay
    }

    enum CodingKeys: String, CodingKey {
        case tfa, mostread, image, news, onthisday
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        featuredArticle = container.lossy(PageSummary.self, forKey: .tfa)
        mostRead = container.lossy(MostRead.self, forKey: .mostread)
        pictureOfTheDay = container.lossy(PictureOfTheDay.self, forKey: .image)
        news = container.lossyArray(NewsItem.self, forKey: .news)
        onThisDay = container.lossyArray(OnThisDayEvent.self, forKey: .onthisday)
    }

    /// Whether the day has nothing at all.
    public var isEmpty: Bool {
        featuredArticle == nil && (mostRead?.articles.isEmpty ?? true) && pictureOfTheDay == nil
            && news.isEmpty && onThisDay.isEmpty
    }
}

/// The most-read articles of a day.
public struct MostRead: Decodable, Sendable, Hashable {
    /// The day the views were counted, such as `2026-09-30Z`.
    public var date: String?
    /// The articles, most viewed first.
    public var articles: [MostReadArticle]

    public init(date: String? = nil, articles: [MostReadArticle]) {
        self.date = date
        self.articles = articles
    }

    enum CodingKeys: String, CodingKey {
        case date, articles
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = container.lossyString(forKey: .date)
        articles = container.lossyArray(MostReadArticle.self, forKey: .articles)
            .sorted { ($0.rank ?? Int.max, -$0.views) < ($1.rank ?? Int.max, -$1.views) }
    }

    /// The day as a ``WikiFeedDate``.
    public var day: WikiFeedDate? {
        date.flatMap { WikiFeedDate(String($0.prefix(10))) }
    }
}

/// A most-read article: the page summary, its views and rank.
public struct MostReadArticle: Decodable, Sendable, Hashable, Identifiable {
    public var page: PageSummary
    /// Views on the day.
    public var views: Int
    /// The position in the list. Ranks can skip numbers.
    public var rank: Int?
    /// Views on the days before, oldest first.
    public var viewHistory: [DailyViews]

    public init(page: PageSummary, views: Int, rank: Int? = nil, viewHistory: [DailyViews] = []) {
        self.page = page
        self.views = views
        self.rank = rank
        self.viewHistory = viewHistory
    }

    public var id: String { page.id }

    enum CodingKeys: String, CodingKey {
        case views, rank, view_history
    }

    public init(from decoder: any Decoder) throws {
        page = try PageSummary(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        views = container.lossyInt(forKey: .views) ?? 0
        rank = container.lossyInt(forKey: .rank)
        viewHistory = container.lossyArray(DailyViews.self, forKey: .view_history)
    }
}

/// The views of one day.
public struct DailyViews: Codable, Sendable, Hashable {
    /// Such as `2026-09-26Z`.
    public var date: String
    public var views: Int

    public init(date: String, views: Int) {
        self.date = date
        self.views = views
    }
}

/// The picture of the day: a file on Wikimedia Commons with its renditions, description,
/// author, credit and license.
public struct PictureOfTheDay: Decodable, Sendable, Hashable {
    /// The file name, such as `File:Lunar eclipse October 2025.jpg`.
    public var title: String
    /// A small rendition.
    public var thumbnail: WikiImage?
    /// The full-size image.
    public var image: WikiImage?
    /// The description as HTML.
    public var descriptionHTML: String?
    /// The description as plain text.
    public var descriptionText: String?
    /// The language of the description.
    public var descriptionLanguage: String?
    /// The author as plain text.
    public var artist: String?
    /// The author as HTML, usually a link to their user page.
    public var artistHTML: String?
    /// The credit line as plain text, such as `Own work`.
    public var credit: String?
    /// The license name, such as `CC BY-SA 4.0`.
    public var license: String?
    /// The license code, such as `cc-by-sa-4.0`.
    public var licenseCode: String?
    /// The license deed.
    public var licenseURL: URL?
    /// The file's page on Wikimedia Commons, with the full attribution.
    public var filePageURL: URL?

    public init(
        title: String,
        thumbnail: WikiImage? = nil,
        image: WikiImage? = nil,
        descriptionHTML: String? = nil,
        descriptionText: String? = nil,
        descriptionLanguage: String? = nil,
        artist: String? = nil,
        artistHTML: String? = nil,
        credit: String? = nil,
        license: String? = nil,
        licenseCode: String? = nil,
        licenseURL: URL? = nil,
        filePageURL: URL? = nil
    ) {
        self.title = title
        self.thumbnail = thumbnail
        self.image = image
        self.descriptionHTML = descriptionHTML
        self.descriptionText = descriptionText
        self.descriptionLanguage = descriptionLanguage
        self.artist = artist
        self.artistHTML = artistHTML
        self.credit = credit
        self.license = license
        self.licenseCode = licenseCode
        self.licenseURL = licenseURL
        self.filePageURL = filePageURL
    }

    /// The file name without `File:` and the extension: `Lunar eclipse October 2025`.
    public var displayTitle: String {
        var name = title
        if let colon = name.firstIndex(of: ":") {
            name = String(name[name.index(after: colon)...])
        }
        if let dot = name.lastIndex(of: "."), name.distance(from: dot, to: name.endIndex) <= 5 {
            name = String(name[..<dot])
        }
        return WikiTitle.normalized(name)
    }

    /// The description as plain text, from ``descriptionText`` or the HTML.
    public var plainDescription: String? {
        descriptionText?.nonEmpty ?? descriptionHTML.map(WikiHTML.plainText)?.nonEmpty
    }

    /// The author as plain text.
    public var plainArtist: String? {
        artist?.nonEmpty ?? artistHTML.map(WikiHTML.plainText)?.nonEmpty
    }

    /// A rendition about `width` pixels wide, from the thumbnail URL.
    public func imageURL(width: Int = 960) -> URL? {
        guard let thumbnail else { return image?.source }
        return WikimediaThumbnail.url(thumbnail.source, width: width, originalWidth: image?.width)
    }

    /// The image's width divided by its height.
    public var aspectRatio: Double? {
        image?.aspectRatio ?? thumbnail?.aspectRatio
    }

    enum CodingKeys: String, CodingKey {
        case title, thumbnail, image, description, artist, credit, license, file_page
    }

    private struct TextValue: Decodable {
        var html: String?
        var text: String?
        var lang: String?
        var name: String?
    }

    private struct License: Decodable {
        var type: String?
        var code: String?
        var url: String?
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let title = container.lossyString(forKey: .title) else {
            throw DecodingError.dataCorruptedError(forKey: .title, in: container, debugDescription: "No file title")
        }
        self.title = title
        thumbnail = container.lossy(WikiImage.self, forKey: .thumbnail)
        image = container.lossy(WikiImage.self, forKey: .image)
        let description = container.lossy(TextValue.self, forKey: .description)
        descriptionHTML = description?.html?.nonEmpty
        descriptionText = description?.text?.nonEmpty
        descriptionLanguage = description?.lang?.nonEmpty
        let artist = container.lossy(TextValue.self, forKey: .artist)
        self.artist = artist?.text?.nonEmpty ?? artist?.name?.nonEmpty
        artistHTML = artist?.html?.nonEmpty
        let credit = container.lossy(TextValue.self, forKey: .credit)
        self.credit = credit?.text?.nonEmpty ?? credit?.html.map(WikiHTML.plainText)?.nonEmpty
        let license = container.lossy(License.self, forKey: .license)
        self.license = license?.type?.nonEmpty
        licenseCode = license?.code?.nonEmpty
        licenseURL = license?.url.flatMap { URL(string: $0) }
        filePageURL = container.lossyString(forKey: .file_page).flatMap { URL(string: $0) }
    }
}

/// A story from In the news: HTML text and the articles it links to.
public struct NewsItem: Decodable, Sendable, Hashable, Identifiable {
    /// The story as HTML.
    public var storyHTML: String
    /// The articles the story links to.
    public var links: [PageSummary]

    public init(storyHTML: String, links: [PageSummary]) {
        self.storyHTML = storyHTML
        self.links = links
    }

    public var id: String { storyHTML }

    /// The story as plain text.
    public var story: String {
        WikiHTML.plainText(storyHTML)
    }

    enum CodingKeys: String, CodingKey {
        case story, links
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let story = container.lossyString(forKey: .story) else {
            throw DecodingError.dataCorruptedError(forKey: .story, in: container, debugDescription: "No story")
        }
        storyHTML = story
        links = container.lossyArray(PageSummary.self, forKey: .links)
    }
}

/// Something that happened on this day: a sentence, a year (holidays have none) and the
/// articles it is about.
public struct OnThisDayEvent: Decodable, Sendable, Hashable, Identifiable {
    public var text: String
    /// The year; negative for B.C. Holidays have no year.
    public var year: Int?
    public var pages: [PageSummary]

    public init(text: String, year: Int? = nil, pages: [PageSummary] = []) {
        self.text = text
        self.year = year
        self.pages = pages
    }

    public var id: String { (year.map(String.init) ?? "") + ":" + text }

    /// The year as people write it: `1969`, or `44 BC` for -44.
    public var yearText: String? {
        guard let year else { return nil }
        return year < 0 ? String(-year) + " BC" : String(year)
    }

    /// The first page with an image, for a thumbnail beside the event.
    public var leadPage: PageSummary? {
        pages.first { $0.thumbnail != nil } ?? pages.first
    }

    enum CodingKeys: String, CodingKey {
        case text, year, pages
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let text = container.lossyString(forKey: .text) else {
            throw DecodingError.dataCorruptedError(forKey: .text, in: container, debugDescription: "No text")
        }
        self.text = text
        year = container.lossyInt(forKey: .year)
        pages = container.lossyArray(PageSummary.self, forKey: .pages)
    }
}

/// The lists of `/feed/onthisday/{type}/{mm}/{dd}`.
public enum OnThisDayType: String, CaseIterable, Sendable, Hashable {
    /// Every list.
    case all
    /// Selected anniversaries, the list shown on the Main Page.
    case selected
    case births
    case deaths
    case events
    case holidays
}

/// The body of `/feed/onthisday/{type}/{mm}/{dd}`: the lists that were asked for.
public struct OnThisDay: Decodable, Sendable, Hashable {
    public var selected: [OnThisDayEvent]
    public var births: [OnThisDayEvent]
    public var deaths: [OnThisDayEvent]
    public var events: [OnThisDayEvent]
    public var holidays: [OnThisDayEvent]

    public init(
        selected: [OnThisDayEvent] = [],
        births: [OnThisDayEvent] = [],
        deaths: [OnThisDayEvent] = [],
        events: [OnThisDayEvent] = [],
        holidays: [OnThisDayEvent] = []
    ) {
        self.selected = selected
        self.births = births
        self.deaths = deaths
        self.events = events
        self.holidays = holidays
    }

    enum CodingKeys: String, CodingKey {
        case selected, births, deaths, events, holidays
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selected = container.lossyArray(OnThisDayEvent.self, forKey: .selected)
        births = container.lossyArray(OnThisDayEvent.self, forKey: .births)
        deaths = container.lossyArray(OnThisDayEvent.self, forKey: .deaths)
        events = container.lossyArray(OnThisDayEvent.self, forKey: .events)
        holidays = container.lossyArray(OnThisDayEvent.self, forKey: .holidays)
    }

    /// The list of one type; ``OnThisDayType/all`` is every list with a year, newest first.
    public func list(_ type: OnThisDayType) -> [OnThisDayEvent] {
        switch type {
        case .selected: return selected
        case .births: return births
        case .deaths: return deaths
        case .events: return events
        case .holidays: return holidays
        case .all:
            return (selected + events + births + deaths)
                .sorted { ($0.year ?? Int.min) > ($1.year ?? Int.min) } + holidays
        }
    }
}
