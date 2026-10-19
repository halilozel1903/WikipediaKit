import Foundation
import Observation
import WikipediaKit

/// The app's data, all from one `WikipediaClient` on the live APIs: the chosen language and
/// caches for what was already loaded.
@Observable
@MainActor
final class ReaderStore {
    /// The User-Agent Wikimedia asks for: the app, its version and where to reach its author.
    static let userAgent = WikipediaUserAgent(
        appName: "WikiReader",
        version: "1.0",
        contact: "https://github.com/halilozel1903/WikipediaKit"
    )

    private(set) var language: WikipediaLanguage
    private(set) var client: WikipediaClient

    @ObservationIgnored private var featuredCache: [String: FeaturedContent] = [:]
    @ObservationIgnored private var summaryCache: [String: PageSummary] = [:]
    @ObservationIgnored private var relatedCache: [String: [PageSummary]] = [:]
    /// How many times a request is tried before the error is shown.
    private let attempts: Int

    init(language: WikipediaLanguage = .english, attempts: Int = 1) {
        self.language = language
        client = WikipediaClient(userAgent: Self.userAgent, language: language)
        self.attempts = max(1, attempts)
    }

    /// English Wikipedia. Screenshot scenes retry failed requests a few times, since a capture
    /// must not show an error.
    static func make(for scene: ScreenshotScene?) -> ReaderStore {
        ReaderStore(language: .english, attempts: scene == nil ? 1 : 4)
    }

    func setLanguage(_ language: WikipediaLanguage) {
        guard language != self.language else { return }
        self.language = language
        client = client.language(language)
    }

    /// Runs `operation`, trying again after a pause when it fails, up to `attempts` times.
    nonisolated static func retrying<T: Sendable>(
        attempts: Int,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await operation()
            } catch {
                guard attempt < attempts, !Task.isCancelled else { throw error }
                print("Request failed (attempt \(attempt) of \(attempts)): \(error)")
                try await Task.sleep(for: .seconds(Double(attempt) * 3))
                attempt += 1
            }
        }
    }

    func languageClient(_ language: String) -> WikipediaClient {
        language == client.language.rawValue ? client : client.language(WikipediaLanguage(language))
    }

    // MARK: - Loading

    func featured(on date: WikiFeedDate) async throws -> FeaturedContent {
        let key = language.rawValue + "/" + date.path
        if let cached = featuredCache[key] { return cached }
        let client = self.client
        let feed = try await Self.retrying(attempts: attempts) {
            try await client.featured(on: date)
        }
        featuredCache[key] = feed
        return feed
    }

    func summary(_ route: ArticleRoute) async throws -> PageSummary {
        let key = route.language + ":" + WikiTitle.canonical(route.title)
        if let cached = summaryCache[key] { return cached }
        let source = languageClient(route.language)
        let title = route.title
        let page = try await Self.retrying(attempts: attempts) {
            try await source.summary(for: title)
        }
        summaryCache[key] = page
        return page
    }

    func related(_ route: ArticleRoute, limit: Int = 12) async throws -> [PageSummary] {
        let key = route.language + ":" + WikiTitle.canonical(route.title)
        if let cached = relatedCache[key] { return cached }
        let source = languageClient(route.language)
        let title = route.title
        let pages = try await Self.retrying(attempts: attempts) {
            try await source.related(to: title, limit: limit)
        }
        relatedCache[key] = pages
        return pages
    }

    func search(_ text: String) async throws -> SearchOutcome {
        let client = self.client
        let outcome = try await Self.retrying(attempts: attempts) {
            let (results, hits) = try await client.searchArticles(text, limit: 20, thumbnailWidth: 250)
            return SearchOutcome(results: results, hits: hits)
        }
        return outcome
    }

    func random() async throws -> PageSummary {
        let client = self.client
        let page = try await Self.retrying(attempts: attempts) {
            try await client.randomSummary()
        }
        summaryCache[(page.language ?? language.rawValue) + ":" + page.id] = page
        return page
    }
}

struct SearchOutcome: Sendable {
    var results: SearchResults
    var hits: [SearchHit]
}
