import Foundation

/// The summary of a page (`/page/summary/{title}`): its titles, a short description, the first
/// paragraph as text and HTML, a thumbnail and the original lead image, links, and coordinates.
///
/// The same shape is used by the featured article, most-read articles, on-this-day and news
/// pages, and related pages. Every field but ``title`` is optional and read leniently, so a
/// record with missing or unexpected fields still decodes.
public struct PageSummary: Codable, Hashable, Sendable, Identifiable {
    /// `standard`, `disambiguation`, `mainpage` or `no-extract`.
    public var type: String?
    /// The normalized title with spaces, such as `Apollo 11`.
    public var title: String
    /// The title as HTML, such as `<i>Apollo 11</i>` for a ship or a work.
    public var displayTitleHTML: String?
    /// The title with underscores, as used in URLs.
    public var canonicalTitle: String?
    public var pageID: Int?
    /// The Wikidata item, such as `Q43653`.
    public var wikidataItem: String?
    /// The short description, such as `First crewed Moon landing mission (1969)`.
    public var description: String?
    /// The first paragraph as plain text.
    public var extract: String?
    /// The first paragraph as HTML.
    public var extractHTML: String?
    /// A small rendition of the lead image (about 330 pixels wide).
    public var thumbnail: WikiImage?
    /// The lead image at its original size. Can be an SVG or a video poster; prefer
    /// ``imageURL(width:)`` for display.
    public var originalImage: WikiImage?
    /// The language code, such as `en`.
    public var language: String?
    /// `ltr` or `rtl`.
    public var direction: String?
    /// The latest revision.
    public var revision: String?
    /// When the page was last edited, as ISO 8601 text.
    public var timestamp: String?
    /// The page on the desktop site.
    public var desktopURL: URL?
    /// The page on the mobile site.
    public var mobileURL: URL?
    public var coordinates: Coordinates?

    /// Latitude and longitude for pages about places.
    public struct Coordinates: Codable, Hashable, Sendable {
        public var latitude: Double
        public var longitude: Double

        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }

        enum CodingKeys: String, CodingKey {
            case latitude = "lat"
            case longitude = "lon"
        }
    }

    public init(
        title: String,
        type: String? = "standard",
        displayTitleHTML: String? = nil,
        canonicalTitle: String? = nil,
        pageID: Int? = nil,
        wikidataItem: String? = nil,
        description: String? = nil,
        extract: String? = nil,
        extractHTML: String? = nil,
        thumbnail: WikiImage? = nil,
        originalImage: WikiImage? = nil,
        language: String? = nil,
        direction: String? = nil,
        revision: String? = nil,
        timestamp: String? = nil,
        desktopURL: URL? = nil,
        mobileURL: URL? = nil,
        coordinates: Coordinates? = nil
    ) {
        self.type = type
        self.title = title
        self.displayTitleHTML = displayTitleHTML
        self.canonicalTitle = canonicalTitle ?? WikiTitle.canonical(title)
        self.pageID = pageID
        self.wikidataItem = wikidataItem
        self.description = description
        self.extract = extract
        self.extractHTML = extractHTML
        self.thumbnail = thumbnail
        self.originalImage = originalImage
        self.language = language
        self.direction = direction
        self.revision = revision
        self.timestamp = timestamp
        self.desktopURL = desktopURL
        self.mobileURL = mobileURL
        self.coordinates = coordinates
    }

    // MARK: - Derived values

    /// The canonical title, which is unique within a wiki.
    public var id: String {
        canonicalTitle ?? WikiTitle.canonical(title)
    }

    /// The display title as plain text (``title`` when there is none).
    public var displayTitle: String {
        displayTitleHTML.map(WikiHTML.plainText)?.nonEmpty ?? title
    }

    /// Whether the page is a disambiguation page.
    public var isDisambiguation: Bool {
        type == "disambiguation"
    }

    /// The page on the web: ``desktopURL``, or one built from the language and title.
    public var webURL: URL? {
        if let desktopURL { return desktopURL }
        guard let language else { return nil }
        return URL(string: "https://" + language + ".wikipedia.org/wiki/" + WikiTitle.pathSegment(id))
    }

    /// A rendition of the lead image about `width` pixels wide, from the thumbnail URL so that
    /// SVGs and videos come back as PNG or JPEG. `nil` when the page has no image.
    public func imageURL(width: Int = 330) -> URL? {
        guard let thumbnail else { return originalImage?.source }
        return WikimediaThumbnail.url(thumbnail.source, width: width, originalWidth: originalImage?.width)
    }

    /// The lead image's width divided by its height.
    public var imageAspectRatio: Double? {
        originalImage?.aspectRatio ?? thumbnail?.aspectRatio
    }

    // MARK: - Coding

    enum CodingKeys: String, CodingKey {
        case type, title, displaytitle, titles, pageid, wikibase_item, description, extract,
             extract_html, thumbnail, originalimage, lang, dir, revision, timestamp, content_urls,
             coordinates, normalizedtitle
    }

    private struct Titles: Codable {
        var canonical: String?
        var normalized: String?
        var display: String?
    }

    private struct ContentURLs: Codable {
        struct Links: Codable {
            var page: String?
        }

        var desktop: Links?
        var mobile: Links?
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let titles = container.lossy(Titles.self, forKey: .titles)
        guard let title = titles?.normalized?.nonEmpty
            ?? container.lossyString(forKey: .normalizedtitle)
            ?? container.lossyString(forKey: .title).map(WikiTitle.normalized)
        else {
            throw DecodingError.dataCorruptedError(forKey: .title, in: container, debugDescription: "A page summary needs a title")
        }
        self.title = title
        type = container.lossyString(forKey: .type)
        displayTitleHTML = titles?.display?.nonEmpty ?? container.lossyString(forKey: .displaytitle)
        canonicalTitle = titles?.canonical?.nonEmpty ?? WikiTitle.canonical(title)
        pageID = container.lossyInt(forKey: .pageid)
        wikidataItem = container.lossyString(forKey: .wikibase_item)
        description = container.lossyString(forKey: .description)
        extract = container.lossyString(forKey: .extract)
        extractHTML = container.lossyString(forKey: .extract_html)
        thumbnail = container.lossy(WikiImage.self, forKey: .thumbnail)
        originalImage = container.lossy(WikiImage.self, forKey: .originalimage)
        language = container.lossyString(forKey: .lang)
        direction = container.lossyString(forKey: .dir)
        revision = container.lossyString(forKey: .revision)
        timestamp = container.lossyString(forKey: .timestamp)
        let urls = container.lossy(ContentURLs.self, forKey: .content_urls)
        desktopURL = urls?.desktop?.page.flatMap { URL(string: $0) }
        mobileURL = urls?.mobile?.page.flatMap { URL(string: $0) }
        coordinates = container.lossy(Coordinates.self, forKey: .coordinates)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encode(canonicalTitle ?? WikiTitle.canonical(title), forKey: .title)
        try container.encodeIfPresent(displayTitleHTML, forKey: .displaytitle)
        try container.encode(Titles(canonical: canonicalTitle, normalized: title, display: displayTitleHTML), forKey: .titles)
        try container.encodeIfPresent(pageID, forKey: .pageid)
        try container.encodeIfPresent(wikidataItem, forKey: .wikibase_item)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(extract, forKey: .extract)
        try container.encodeIfPresent(extractHTML, forKey: .extract_html)
        try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
        try container.encodeIfPresent(originalImage, forKey: .originalimage)
        try container.encodeIfPresent(language, forKey: .lang)
        try container.encodeIfPresent(direction, forKey: .dir)
        try container.encodeIfPresent(revision, forKey: .revision)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        if desktopURL != nil || mobileURL != nil {
            let urls = ContentURLs(
                desktop: desktopURL.map { ContentURLs.Links(page: $0.absoluteString) },
                mobile: mobileURL.map { ContentURLs.Links(page: $0.absoluteString) }
            )
            try container.encode(urls, forKey: .content_urls)
        }
        try container.encodeIfPresent(coordinates, forKey: .coordinates)
    }
}

/// The body of `/page/related/{title}`: `{"pages":[…]}`.
struct RelatedPagesResponse: Decodable {
    var pages: [PageSummary]

    enum CodingKeys: String, CodingKey {
        case pages
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.contains(.pages) else {
            throw DecodingError.keyNotFound(CodingKeys.pages, .init(codingPath: [], debugDescription: "No pages"))
        }
        pages = container.lossyArray(PageSummary.self, forKey: .pages)
    }
}
