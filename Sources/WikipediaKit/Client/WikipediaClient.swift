import Foundation

/// A client for Wikipedia's [REST API](https://en.wikipedia.org/api/rest_v1/) (page summaries,
/// random and related pages, the featured feed and on this day) and the
/// [Action API](https://www.mediawiki.org/wiki/API:Search) for full-text search, in any language.
///
/// ```swift
/// let wikipedia = WikipediaClient(userAgent: WikipediaUserAgent(
///     appName: "MyReader", version: "1.0", contact: "https://example.com/myreader"
/// ))
///
/// let apollo = try await wikipedia.summary(for: "Apollo 11")
/// apollo.description                       // the short description
/// apollo.imageURL(width: 960)              // upload.wikimedia.org/…/960px-…jpg
///
/// let today = try await wikipedia.featured(on: WikiFeedDate(year: 2026, month: 10, day: 1))
/// today.featuredArticle?.title
/// today.mostRead?.articles.first?.views
///
/// let results = try await wikipedia.search("Moon landing")
/// let german = try await wikipedia.language(.german).summary(for: "Mondlandung")
/// ```
///
/// Every request sends the ``WikipediaUserAgent`` you give, as Wikimedia's policy requires.
/// The client is `Sendable`; share one across your app.
public final class WikipediaClient: Sendable {
    public let configuration: WikipediaConfiguration

    public init(configuration: WikipediaConfiguration) {
        self.configuration = configuration
    }

    /// A client for `language` with the default settings otherwise.
    public convenience init(userAgent: WikipediaUserAgent, language: WikipediaLanguage = .english, session: URLSession = .shared) {
        self.init(configuration: WikipediaConfiguration(userAgent: userAgent, language: language, session: session))
    }

    /// The language requests go to.
    public var language: WikipediaLanguage {
        configuration.language
    }

    /// A client with the same settings for another Wikipedia edition.
    public func language(_ language: WikipediaLanguage) -> WikipediaClient {
        var configuration = self.configuration
        configuration.language = language
        return WikipediaClient(configuration: configuration)
    }

    // MARK: - Pages

    /// The summary of a page (`/page/summary/{title}`). Redirects are followed, so the result's
    /// title can differ from `title`. Throws ``WikipediaError/notFound(problem:url:)`` for a
    /// page that does not exist.
    public func summary(for title: String) async throws -> PageSummary {
        try await rest(PageSummary.self, path: "page/summary/" + checkedTitle(title))
    }

    /// The summary of a random article (`/page/random/summary`).
    public func randomSummary() async throws -> PageSummary {
        try await rest(PageSummary.self, path: "page/random/summary")
    }

    /// Pages related to a page (`/page/related/{title}`), at most `limit`.
    ///
    /// When that endpoint is not served (HTTP 403, 404, 410 or 501, as Wikimedia retires parts of
    /// the REST API) and ``WikipediaConfiguration/relatedFallback`` is on, the same question is
    /// asked of the Action API's `morelike:` search instead, which is what `/page/related` used.
    /// Those summaries have a title, description, extract and thumbnail.
    public func related(to title: String, limit: Int = 20) async throws -> [PageSummary] {
        let segment = try checkedTitle(title)
        do {
            let response = try await rest(RelatedPagesResponse.self, path: "page/related/" + segment)
            return Array(response.pages.prefix(max(0, limit)))
        } catch let error as WikipediaError where configuration.relatedFallback && Self.isRetired(error) {
            return try await moreLike(title, limit: limit)
        }
    }

    /// Articles like a page, by the Action API's `morelike:` search, with their descriptions,
    /// first sentences and thumbnails. At most 20.
    public func moreLike(_ title: String, limit: Int = 20, thumbnailWidth: Int = 330) async throws -> [PageSummary] {
        _ = try checkedTitle(title)
        let limit = min(max(1, limit), 20)
        let response = try await action(PagesResponse.self, query: [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "morelike:" + WikiTitle.normalized(title)),
            URLQueryItem(name: "gsrnamespace", value: "0"),
            URLQueryItem(name: "gsrlimit", value: String(limit)),
            URLQueryItem(name: "prop", value: "pageimages|description|extracts"),
            URLQueryItem(name: "piprop", value: "thumbnail"),
            URLQueryItem(name: "pithumbsize", value: String(WikimediaThumbnail.standardWidth(atLeast: thumbnailWidth))),
            URLQueryItem(name: "pilimit", value: String(limit)),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "exsentences", value: "2"),
            URLQueryItem(name: "exlimit", value: String(limit)),
        ])
        let code = self.language.rawValue
        return response.pages.filter { !$0.isMissing }.map { $0.summary(language: code) }
    }

    // MARK: - Feeds

    /// The featured feed of a day (`/feed/featured/{yyyy}/{mm}/{dd}`): the featured article,
    /// picture of the day, most-read articles, on this day and news. Days are in UTC.
    public func featured(on date: WikiFeedDate = .today) async throws -> FeaturedContent {
        guard date.isValid else {
            throw WikipediaError.invalidRequest("There is no day \(date).")
        }
        return try await rest(FeaturedContent.self, path: "feed/featured/" + date.path)
    }

    /// Events, births, deaths and holidays on a day of the year
    /// (`/feed/onthisday/{type}/{mm}/{dd}`).
    public func onThisDay(_ type: OnThisDayType = .all, month: Int, day: Int) async throws -> OnThisDay {
        guard (1...12).contains(month), (1...31).contains(day) else {
            throw WikipediaError.invalidRequest("There is no day \(month)/\(day).")
        }
        let path = "feed/onthisday/" + type.rawValue + "/" + WikiFeedDate.pad(month) + "/" + WikiFeedDate.pad(day)
        return try await rest(OnThisDay.self, path: path)
    }

    /// On this day for the month and day of `date`.
    public func onThisDay(_ type: OnThisDayType = .all, on date: WikiFeedDate) async throws -> OnThisDay {
        try await onThisDay(type, month: date.month, day: date.day)
    }

    // MARK: - Search

    /// Full-text search of articles
    /// (`w/api.php?action=query&list=search&srsearch=…&format=json`), `limit` results (at most
    /// 500) from `offset`. Throws ``WikipediaError/invalidRequest(_:)`` for empty text.
    public func search(_ text: String, limit: Int = 20, offset: Int = 0) async throws -> SearchResults {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw WikipediaError.invalidRequest("Search needs some text.")
        }
        let offset = max(0, offset)
        let response = try await action(SearchResponse.self, query: [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: text),
            URLQueryItem(name: "srnamespace", value: "0"),
            URLQueryItem(name: "srlimit", value: String(min(max(1, limit), 500))),
            URLQueryItem(name: "sroffset", value: String(offset)),
            URLQueryItem(name: "srinfo", value: "totalhits|suggestion"),
            URLQueryItem(name: "srprop", value: "snippet|wordcount|size|timestamp"),
        ])
        return SearchResults(
            query: text,
            totalHits: response.totalHits,
            suggestion: response.suggestion,
            results: response.results,
            offset: offset,
            nextOffset: response.nextOffset
        )
    }

    /// Short descriptions and thumbnails of up to 50 pages
    /// (`w/api.php?action=query&prop=pageimages|description&titles=…`), keyed by the titles as
    /// you passed them. Pages that do not exist are left out.
    public func pageInfo(for titles: [String], thumbnailWidth: Int = 330) async throws -> [String: PageInfo] {
        var seen = Set<String>()
        let unique = titles.map(WikiTitle.normalized).filter { !$0.isEmpty && seen.insert($0).inserted }
        guard !unique.isEmpty else { return [:] }
        guard unique.count <= 50 else {
            throw WikipediaError.invalidRequest("pageInfo(for:) takes at most 50 titles at a time.")
        }
        let response = try await action(PagesResponse.self, query: [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "prop", value: "pageimages|description"),
            URLQueryItem(name: "titles", value: unique.joined(separator: "|")),
            URLQueryItem(name: "redirects", value: "1"),
            URLQueryItem(name: "piprop", value: "thumbnail|name"),
            URLQueryItem(name: "pithumbsize", value: String(WikimediaThumbnail.standardWidth(atLeast: thumbnailWidth))),
            URLQueryItem(name: "pilimit", value: "50"),
        ])
        var byTitle: [String: PageInfo] = [:]
        for page in response.pages where !page.isMissing {
            byTitle[page.title] = page
        }
        var result: [String: PageInfo] = [:]
        for title in unique {
            // Follow normalization, then a redirect, to the page the API answered for.
            var resolved = title
            for _ in 0..<3 {
                guard let next = response.renamed[resolved] else { break }
                resolved = next
            }
            if let page = byTitle[resolved] {
                result[title] = page
            }
        }
        return result
    }

    /// A search with each result's short description and thumbnail: ``search(_:limit:offset:)``
    /// followed by ``pageInfo(for:thumbnailWidth:)`` for the results.
    public func searchArticles(_ text: String, limit: Int = 20, thumbnailWidth: Int = 330) async throws -> (results: SearchResults, hits: [SearchHit]) {
        let results = try await search(text, limit: min(limit, 50))
        let info = try await pageInfo(for: results.results.map(\.title), thumbnailWidth: thumbnailWidth)
        let hits = results.results.map { SearchHit(result: $0, info: info[WikiTitle.normalized($0.title)]) }
        return (results, hits)
    }

    // MARK: - Images

    /// The bytes of an image on upload.wikimedia.org (or any URL), sent with this client's
    /// User-Agent, which Wikimedia's media servers require too, and retried like API requests.
    public func imageData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        try applyHeaders(to: &request, accept: "image/*")
        return try await self.data(for: request)
    }

    // MARK: - Requests

    /// The request for a REST API path, such as `page/summary/Apollo_11`. Exposed for tests and
    /// debugging; `path` must already be percent-encoded.
    public func restRequest(path: String) throws -> URLRequest {
        guard language.isValid else {
            throw WikipediaError.invalidRequest("\"\(language.rawValue)\" is not a Wikipedia language code.")
        }
        let base = configuration.restBaseURL.absoluteString
        guard let url = URL(string: base + "/" + path) else {
            throw WikipediaError.invalidRequest("Could not build a URL for \(path).")
        }
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        try applyHeaders(to: &request, accept: "application/json")
        return request
    }

    /// The request for the Action API with `query` plus `format=json&formatversion=2`.
    public func actionRequest(query: [URLQueryItem]) throws -> URLRequest {
        guard language.isValid else {
            throw WikipediaError.invalidRequest("\"\(language.rawValue)\" is not a Wikipedia language code.")
        }
        guard var components = URLComponents(url: configuration.actionAPIURL, resolvingAgainstBaseURL: false) else {
            throw WikipediaError.invalidRequest("Could not build the Action API URL.")
        }
        components.queryItems = query + [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
        ]
        // URLComponents leaves "+" as is, but servers read it as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else {
            throw WikipediaError.invalidRequest("Could not build the Action API URL.")
        }
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        try applyHeaders(to: &request, accept: "application/json")
        return request
    }

    /// Fetches and decodes a REST API path, for endpoints this client has no method for.
    public func rest<Value: Decodable>(_ type: Value.Type, path: String) async throws -> Value {
        let body = try await self.data(for: restRequest(path: path))
        return try decode(Value.self, from: body)
    }

    /// Fetches and decodes an Action API query, for modules this client has no method for.
    /// An `{"error":…}` body throws ``WikipediaError/api(code:info:)``.
    public func action<Value: Decodable>(_ type: Value.Type, query: [URLQueryItem]) async throws -> Value {
        let body = try await self.data(for: actionRequest(query: query))
        if let errorBody = try? JSONDecoder().decode(ActionAPIErrorBody.self, from: body), let error = errorBody.error {
            throw WikipediaError.api(code: error.code ?? "unknown", info: error.info ?? error.text ?? "")
        }
        return try decode(Value.self, from: body)
    }

    func applyHeaders(to request: inout URLRequest, accept: String) throws {
        let agent = configuration.userAgent
        if let problem = agent.problem {
            throw WikipediaError.invalidUserAgent(problem)
        }
        request.setValue(agent.value, forHTTPHeaderField: "User-Agent")
        // Browsers can't set User-Agent; Wikimedia reads Api-User-Agent as well.
        request.setValue(agent.value, forHTTPHeaderField: "Api-User-Agent")
        request.setValue(accept, forHTTPHeaderField: "Accept")
    }

    func checkedTitle(_ title: String) throws -> String {
        let canonical = WikiTitle.canonical(title)
        guard !canonical.isEmpty else {
            throw WikipediaError.invalidRequest("A page title can't be empty.")
        }
        return WikiTitle.pathSegment(canonical)
    }

    func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw WikipediaError.decoding(type: String(describing: Value.self), description: String(describing: error))
        }
    }

    /// Sends the request and maps transport failures; any HTTP status is returned.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let result: (Data, URLResponse)
        do {
            result = try await configuration.session.data(for: request)
        } catch let error as URLError {
            throw WikipediaError.transport(error)
        } catch is CancellationError {
            throw WikipediaError.transport(URLError(.cancelled))
        }
        guard let http = result.1 as? HTTPURLResponse else {
            throw WikipediaError.invalidResponse
        }
        return (result.0, http)
    }

    /// Performs a request, retrying busy and failed attempts, and returns the body of a
    /// successful response; other statuses throw with the API's problem details.
    func data(for request: URLRequest) async throws -> Data {
        let url = request.url ?? configuration.siteURL
        var attempt = 0
        while true {
            let response: (Data, HTTPURLResponse)
            do {
                response = try await send(request)
            } catch WikipediaError.transport(let error) where Self.isRetryable(error) && attempt < configuration.maxRetries {
                attempt += 1
                try await Self.pause(Self.backoff(attempt: attempt))
                continue
            }
            let (data, http) = response
            switch http.statusCode {
            case 200..<300:
                return data
            case 404:
                throw WikipediaError.notFound(problem: Self.problem(in: data), url: url)
            case 429, 502, 503, 504:
                guard attempt < configuration.maxRetries else {
                    throw WikipediaError.http(statusCode: http.statusCode, problem: Self.problem(in: data), url: url)
                }
                attempt += 1
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                try await Self.pause(min(retryAfter ?? Self.backoff(attempt: attempt), 30))
            default:
                throw WikipediaError.http(statusCode: http.statusCode, problem: Self.problem(in: data), url: url)
            }
        }
    }

    static func isRetired(_ error: WikipediaError) -> Bool {
        guard let status = error.statusCode else { return false }
        return [403, 404, 410, 501].contains(status)
    }

    static func isRetryable(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    /// 0.5 s, 1 s, 2 s… for the first, second, third retry.
    static func backoff(attempt: Int) -> TimeInterval {
        0.5 * pow(2, Double(max(0, attempt - 1)))
    }

    static func pause(_ seconds: TimeInterval) async throws {
        do {
            try await Task.sleep(for: .seconds(seconds))
        } catch {
            throw WikipediaError.transport(URLError(.cancelled))
        }
    }

    /// The problem details of an error body, when it has any.
    static func problem(in data: Data) -> WikipediaProblem? {
        guard let problem = try? JSONDecoder().decode(WikipediaProblem.self, from: data),
              problem.title != nil || problem.detail != nil || problem.type != nil
        else { return nil }
        return problem
    }
}
