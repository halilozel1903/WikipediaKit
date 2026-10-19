import Foundation

/// One page of full-text search results from the Action API
/// (`w/api.php?action=query&list=search`).
public struct SearchResults: Sendable, Hashable {
    /// The search text.
    public var query: String
    /// How many pages match in total (`searchinfo.totalhits`).
    public var totalHits: Int?
    /// A spelling suggestion, such as `apollo` for `apolo`.
    public var suggestion: String?
    /// The results on this page, best match first.
    public var results: [SearchResult]
    /// The offset of this page.
    public var offset: Int
    /// The offset of the next page (`continue.sroffset`), or `nil` on the last page.
    public var nextOffset: Int?

    public init(
        query: String,
        totalHits: Int? = nil,
        suggestion: String? = nil,
        results: [SearchResult],
        offset: Int = 0,
        nextOffset: Int? = nil
    ) {
        self.query = query
        self.totalHits = totalHits
        self.suggestion = suggestion
        self.results = results
        self.offset = offset
        self.nextOffset = nextOffset
    }

    public var isEmpty: Bool { results.isEmpty }
}

/// A full-text search result: the title, the matching snippet and the page's size.
public struct SearchResult: Codable, Sendable, Hashable, Identifiable {
    public var title: String
    public var pageID: Int?
    /// The namespace, 0 for articles.
    public var namespace: Int?
    /// The matching text as HTML, with matches in `<span class="searchmatch">`.
    public var snippetHTML: String?
    public var wordCount: Int?
    /// The size in bytes.
    public var size: Int?
    /// When the page was last edited, as ISO 8601 text.
    public var timestamp: String?

    public init(
        title: String,
        pageID: Int? = nil,
        namespace: Int? = 0,
        snippetHTML: String? = nil,
        wordCount: Int? = nil,
        size: Int? = nil,
        timestamp: String? = nil
    ) {
        self.title = title
        self.pageID = pageID
        self.namespace = namespace
        self.snippetHTML = snippetHTML
        self.wordCount = wordCount
        self.size = size
        self.timestamp = timestamp
    }

    public var id: String { WikiTitle.canonical(title) }

    /// The snippet as plain text.
    public var snippet: String? {
        snippetHTML.map(WikiHTML.plainText)?.nonEmpty
    }

    enum CodingKeys: String, CodingKey {
        case title
        case pageID = "pageid"
        case namespace = "ns"
        case snippetHTML = "snippet"
        case wordCount = "wordcount"
        case size, timestamp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let title = container.lossyString(forKey: .title) else {
            throw DecodingError.dataCorruptedError(forKey: .title, in: container, debugDescription: "No title")
        }
        self.title = title
        pageID = container.lossyInt(forKey: .pageID)
        namespace = container.lossyInt(forKey: .namespace)
        snippetHTML = container.lossyString(forKey: .snippetHTML)
        wordCount = container.lossyInt(forKey: .wordCount)
        size = container.lossyInt(forKey: .size)
        timestamp = container.lossyString(forKey: .timestamp)
    }
}

/// A search result with the page's short description and thumbnail, as returned by
/// ``WikipediaClient/searchArticles(_:limit:thumbnailWidth:)``.
public struct SearchHit: Sendable, Hashable, Identifiable {
    public var result: SearchResult
    public var info: PageInfo?

    public init(result: SearchResult, info: PageInfo? = nil) {
        self.result = result
        self.info = info
    }

    public var id: String { result.id }
    public var title: String { result.title }
    public var description: String? { info?.description }
    public var thumbnail: WikiImage? { info?.thumbnail }
}

/// What `prop=pageimages|description` says about a page: its short description and thumbnail.
public struct PageInfo: Codable, Sendable, Hashable, Identifiable {
    public var title: String
    public var pageID: Int?
    public var description: String?
    public var thumbnail: WikiImage?
    /// The lead image's file name, without `File:`.
    public var pageImage: String?
    /// The first sentences as plain text, when `prop=extracts` was asked for.
    public var extract: String?
    /// The position in generator results.
    public var index: Int?
    /// Whether the page does not exist.
    public var isMissing: Bool

    public init(
        title: String,
        pageID: Int? = nil,
        description: String? = nil,
        thumbnail: WikiImage? = nil,
        pageImage: String? = nil,
        extract: String? = nil,
        index: Int? = nil,
        isMissing: Bool = false
    ) {
        self.title = title
        self.pageID = pageID
        self.description = description
        self.thumbnail = thumbnail
        self.pageImage = pageImage
        self.extract = extract
        self.index = index
        self.isMissing = isMissing
    }

    public var id: String { WikiTitle.canonical(title) }

    enum CodingKeys: String, CodingKey {
        case title
        case pageID = "pageid"
        case description, thumbnail
        case pageImage = "pageimage"
        case extract, index
        case isMissing = "missing"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let title = container.lossyString(forKey: .title) else {
            throw DecodingError.dataCorruptedError(forKey: .title, in: container, debugDescription: "No title")
        }
        self.title = title
        pageID = container.lossyInt(forKey: .pageID)
        description = container.lossyString(forKey: .description)
        thumbnail = container.lossy(WikiImage.self, forKey: .thumbnail)
        pageImage = container.lossyString(forKey: .pageImage)
        extract = container.lossyString(forKey: .extract)
        index = container.lossyInt(forKey: .index)
        // formatversion=2 sends "missing": true; formatversion=1 sends "missing": "".
        isMissing = container.contains(.isMissing) && container.lossy(Bool.self, forKey: .isMissing) != false
    }

    /// The page as a ``PageSummary`` in `language`, for lists that show summaries.
    public func summary(language: String?) -> PageSummary {
        PageSummary(
            title: title,
            pageID: pageID,
            description: description,
            extract: extract,
            thumbnail: thumbnail,
            language: language
        )
    }
}

// MARK: - Action API bodies

/// `{"error":{"code":"…","info":"…"}}`, sent with HTTP 200.
struct ActionAPIErrorBody: Decodable {
    struct Detail: Decodable {
        var code: String?
        var info: String?
        var text: String?
    }

    var error: Detail?
}

/// The body of `list=search`.
struct SearchResponse: Decodable {
    var totalHits: Int?
    var suggestion: String?
    var results: [SearchResult]
    var nextOffset: Int?

    enum Keys: String, CodingKey {
        case query, searchinfo, search, totalhits, suggestion
        case continueKey = "continue"
        case sroffset
    }

    init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: Keys.self)
        if let next = try? root.nestedContainer(keyedBy: Keys.self, forKey: .continueKey) {
            nextOffset = next.lossyInt(forKey: .sroffset)
        }
        guard let query = try? root.nestedContainer(keyedBy: Keys.self, forKey: .query) else {
            // A search with no results still has a query object; its absence means another shape.
            throw DecodingError.keyNotFound(Keys.query, .init(codingPath: [], debugDescription: "No query object"))
        }
        if let info = try? query.nestedContainer(keyedBy: Keys.self, forKey: .searchinfo) {
            totalHits = info.lossyInt(forKey: .totalhits)
            suggestion = info.lossyString(forKey: .suggestion)
        }
        results = query.lossyArray(SearchResult.self, forKey: .search)
    }
}

/// The body of `prop=…` queries: `query.pages`, an array with formatversion=2 or an object
/// keyed by page ID with formatversion=1, plus `normalized` and `redirects` title maps.
struct PagesResponse: Decodable {
    var pages: [PageInfo]
    /// Title changes the API made: normalization (`apollo 11` → `Apollo 11`) and redirects.
    var renamed: [String: String]

    enum Keys: String, CodingKey {
        case query, pages, normalized, redirects
    }

    struct Rename: Decodable {
        var from: String
        var to: String
    }

    init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: Keys.self)
        guard let query = try? root.nestedContainer(keyedBy: Keys.self, forKey: .query) else {
            // A generator search with no results has no query object at all.
            pages = []
            renamed = [:]
            return
        }
        if let list = query.lossy(LossyArray<PageInfo>.self, forKey: .pages) {
            pages = list.elements
        } else if let map = query.lossy([String: PageInfo].self, forKey: .pages) {
            pages = Array(map.values)
        } else {
            pages = []
        }
        pages.sort { ($0.index ?? Int.max, $0.title) < ($1.index ?? Int.max, $1.title) }
        var renamed: [String: String] = [:]
        for rename in query.lossyArray(Rename.self, forKey: .normalized) + query.lossyArray(Rename.self, forKey: .redirects) {
            renamed[rename.from] = rename.to
        }
        self.renamed = renamed
    }
}
