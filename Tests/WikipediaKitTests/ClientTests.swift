import Foundation
import Testing
@testable import WikipediaKit

@Suite("WikipediaClient requests")
struct ClientTests {
    @Test func summaryRequest() async throws {
        let stub = StubbedClient { _ in try .json("summary-apollo-11") }
        let page = try await stub.client.summary(for: "Apollo 11")

        #expect(page.title == "Apollo 11")
        let request = try #require(stub.lastRequest)
        #expect(request.url?.host == "en." + stub.domain)
        #expect(request.url?.scheme == "https")
        #expect(stub.lastPath == "/api/rest_v1/page/summary/Apollo_11")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func userAgentOnEveryRequest() async throws {
        let stub = StubbedClient { request in
            if request.url?.path.hasSuffix("api.php") == true {
                return try .json("search-moon-landing")
            }
            return try .json("summary-apollo-11")
        }
        _ = try await stub.client.summary(for: "Apollo 11")
        _ = try await stub.client.search("Moon landing")

        #expect(stub.requests.count == 2)
        for request in stub.requests {
            #expect(request.value(forHTTPHeaderField: "User-Agent") == testAgent.value)
            #expect(request.value(forHTTPHeaderField: "Api-User-Agent") == testAgent.value)
        }
    }

    @Test func incompleteUserAgentIsRefusedBeforeSending() async throws {
        let agent = WikipediaUserAgent(appName: "Reader", version: "1.0", contact: "")
        let stub = StubbedClient(userAgent: agent) { _ in try .json("summary-apollo-11") }
        do {
            _ = try await stub.client.summary(for: "Apollo 11")
            Issue.record("Expected an invalid user agent error")
        } catch let error as WikipediaError {
            guard case .invalidUserAgent = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func titlesAreEncodedAsOnePathSegment() async throws {
        let stub = StubbedClient { _ in try .json("summary-apollo-11") }
        _ = try await stub.client.summary(for: "AC/DC")
        #expect(stub.lastPath == "/api/rest_v1/page/summary/AC%2FDC")
        _ = try await stub.client.summary(for: "Zürich")
        #expect(stub.lastPath == "/api/rest_v1/page/summary/Z%C3%BCrich")
    }

    @Test func emptyTitleIsRefused() async throws {
        let stub = StubbedClient { _ in try .json("summary-apollo-11") }
        await #expect(throws: WikipediaError.self) {
            _ = try await stub.client.summary(for: "   ")
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func languageSelection() async throws {
        let stub = StubbedClient(language: .german) { _ in try .json("summary-apollo-11") }
        _ = try await stub.client.summary(for: "Mondlandung")
        #expect(stub.lastRequest?.url?.host == "de." + stub.domain)

        let japanese = stub.client.language(.japanese)
        #expect(japanese.language == .japanese)
        #expect(stub.client.language == .german)
        _ = try await japanese.summary(for: "アポロ11号")
        #expect(stub.lastRequest?.url?.host == "ja." + stub.domain)
    }

    @Test func invalidLanguageIsRefused() async throws {
        let stub = StubbedClient(language: "en.example.com/") { _ in try .json("summary-apollo-11") }
        await #expect(throws: WikipediaError.self) {
            _ = try await stub.client.summary(for: "Apollo 11")
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func randomSummary() async throws {
        let stub = StubbedClient { _ in try .json("summary-apollo-11") }
        _ = try await stub.client.randomSummary()
        #expect(stub.lastPath == "/api/rest_v1/page/random/summary")
    }

    @Test func notFound() async throws {
        let stub = StubbedClient { _ in try .json("error-not-found", status: 404) }
        do {
            _ = try await stub.client.summary(for: "No such page here")
            Issue.record("Expected a not-found error")
        } catch let error as WikipediaError {
            #expect(error.isNotFound)
            #expect(error.statusCode == 404)
            #expect(error.errorDescription == "Page or revision not found.")
        }
    }

    @Test func featuredRequest() async throws {
        let stub = StubbedClient { _ in try .json("featured-2026-10-01") }
        let feed = try await stub.client.featured(on: WikiFeedDate(year: 2026, month: 10, day: 1))
        #expect(stub.lastPath == "/api/rest_v1/feed/featured/2026/10/01")
        #expect(feed.featuredArticle?.title == "Hubble Space Telescope")
    }

    @Test func invalidFeedDateIsRefused() async throws {
        let stub = StubbedClient { _ in try .json("featured-2026-10-01") }
        await #expect(throws: WikipediaError.self) {
            _ = try await stub.client.featured(on: WikiFeedDate(year: 2026, month: 2, day: 30))
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func onThisDayRequest() async throws {
        let stub = StubbedClient { _ in try .json("onthisday-all-07-20") }
        let day = try await stub.client.onThisDay(.births, month: 7, day: 20)
        #expect(stub.lastPath == "/api/rest_v1/feed/onthisday/births/07/20")
        #expect(day.births.count == 2)

        _ = try await stub.client.onThisDay(on: WikiFeedDate(year: 2026, month: 10, day: 1))
        #expect(stub.lastPath == "/api/rest_v1/feed/onthisday/all/10/01")

        await #expect(throws: WikipediaError.self) {
            _ = try await stub.client.onThisDay(month: 13, day: 1)
        }
    }

    @Test func searchRequest() async throws {
        let stub = StubbedClient { _ in try .json("search-moon-landing") }
        let results = try await stub.client.search("Moon landing", limit: 2, offset: 0)

        #expect(stub.lastPath == "/w/api.php")
        #expect(stub.lastQueryValue("action") == "query")
        #expect(stub.lastQueryValue("list") == "search")
        #expect(stub.lastQueryValue("srsearch") == "Moon landing")
        #expect(stub.lastQueryValue("srlimit") == "2")
        #expect(stub.lastQueryValue("sroffset") == "0")
        #expect(stub.lastQueryValue("format") == "json")
        #expect(stub.lastQueryValue("formatversion") == "2")
        #expect(results.query == "Moon landing")
        #expect(results.totalHits == 8421)
        #expect(results.nextOffset == 2)
        #expect(results.results.map(\.title) == ["Moon landing", "Apollo 11"])
    }

    @Test func searchEncodesPlus() async throws {
        let stub = StubbedClient { _ in try .json("search-empty") }
        let results = try await stub.client.search("C++")
        #expect(results.isEmpty)
        let query = stub.lastRequest?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.percentEncodedQuery }
        #expect(query?.contains("srsearch=C%2B%2B") == true)
        #expect(stub.lastQueryValue("srsearch") == "C++")
    }

    @Test func emptySearchIsRefused() async throws {
        let stub = StubbedClient { _ in try .json("search-empty") }
        await #expect(throws: WikipediaError.self) {
            _ = try await stub.client.search("  ")
        }
        #expect(stub.requests.isEmpty)
    }

    @Test func actionAPIErrors() async throws {
        let stub = StubbedClient { _ in try .json("error-action") }
        do {
            _ = try await stub.client.search("Moon")
            Issue.record("Expected an API error")
        } catch let error as WikipediaError {
            #expect(error == .api(code: "badvalue", info: "Unrecognized value for parameter \"list\": serch."))
        }
    }

    @Test func pageInfoFollowsNormalizationAndRedirects() async throws {
        let stub = StubbedClient { _ in try .json("pageinfo") }
        let info = try await stub.client.pageInfo(for: ["moon landing", "Apollo_11", "No such page here", "Apollo 11"])

        #expect(stub.lastQueryValue("prop") == "pageimages|description")
        #expect(stub.lastQueryValue("titles") == "moon landing|Apollo 11|No such page here")
        #expect(stub.lastQueryValue("redirects") == "1")
        #expect(info["moon landing"]?.title == "Moon landings")
        #expect(info["moon landing"]?.thumbnail != nil)
        #expect(info["Apollo 11"]?.description == "First crewed Moon landing mission (1969)")
        #expect(info["No such page here"] == nil)
        #expect(info.count == 2)
    }

    @Test func pageInfoLimits() async throws {
        let stub = StubbedClient { _ in try .json("pageinfo") }
        let none = try await stub.client.pageInfo(for: [])
        #expect(none.isEmpty)
        #expect(stub.requests.isEmpty)
        let many = (1...51).map { "Page " + String($0) }
        await #expect(throws: WikipediaError.self) {
            _ = try await stub.client.pageInfo(for: many)
        }
    }

    @Test func searchArticlesJoinsThumbnails() async throws {
        let stub = StubbedClient { request in
            if request.queryValue("list") == "search" {
                return try .json("search-moon-landing")
            }
            return try .json("pageinfo")
        }
        let (results, hits) = try await stub.client.searchArticles("Moon landing", limit: 2)
        #expect(results.totalHits == 8421)
        #expect(hits.map(\.title) == ["Moon landing", "Apollo 11"])
        #expect(hits.first?.thumbnail != nil)
        #expect(hits.first?.description == "Arrival of a spacecraft on the surface of the Moon")
        #expect(hits.last?.thumbnail == nil)
        #expect(stub.requests.count == 2)
    }

    @Test func relatedFromTheRESTAPI() async throws {
        let stub = StubbedClient { _ in try .json("related-apollo-11") }
        let pages = try await stub.client.related(to: "Apollo 11", limit: 1)
        #expect(stub.lastPath == "/api/rest_v1/page/related/Apollo_11")
        #expect(pages.map(\.title) == ["Apollo 12"])
    }

    @Test func relatedFallsBackToMoreLike() async throws {
        let stub = StubbedClient { request in
            if request.url?.path.contains("/page/related/") == true {
                return try .json("error-not-found", status: 404)
            }
            return try .json("morelike-apollo-11")
        }
        let pages = try await stub.client.related(to: "Apollo 11", limit: 5)

        #expect(stub.requests.count == 2)
        #expect(stub.lastQueryValue("generator") == "search")
        #expect(stub.lastQueryValue("gsrsearch") == "morelike:Apollo 11")
        #expect(stub.lastQueryValue("gsrlimit") == "5")
        #expect(pages.map(\.title) == ["Apollo 12", "Buzz Aldrin"])
        #expect(pages.first?.language == "en")
        #expect(pages.first?.thumbnail != nil)
    }

    @Test func relatedWithoutFallback() async throws {
        let stub = StubbedClient(relatedFallback: false) { _ in try .json("error-not-found", status: 404) }
        await #expect(throws: WikipediaError.self) {
            _ = try await stub.client.related(to: "Apollo 11")
        }
        #expect(stub.requests.count == 1)
    }

    @Test func retriesBusyAnswers() async throws {
        let counter = Counter()
        let stub = StubbedClient { _ in
            if counter.next() == 1 {
                return .status(429, headers: ["Retry-After": "0"])
            }
            return try .json("summary-apollo-11")
        }
        let page = try await stub.client.summary(for: "Apollo 11")
        #expect(page.title == "Apollo 11")
        #expect(counter.count == 2)
    }

    @Test func givesUpAfterMaxRetries() async throws {
        let counter = Counter()
        let stub = StubbedClient(maxRetries: 1) { _ in
            _ = counter.next()
            return .status(503, headers: ["Retry-After": "0"])
        }
        do {
            _ = try await stub.client.summary(for: "Apollo 11")
            Issue.record("Expected an HTTP error")
        } catch let error as WikipediaError {
            #expect(error.statusCode == 503)
        }
        #expect(counter.count == 2)
    }

    @Test func otherStatusesThrow() async throws {
        let stub = StubbedClient { _ in .raw(#"{"title":"Forbidden","detail":"Please set a user-agent"}"#, status: 403) }
        do {
            _ = try await stub.client.summary(for: "Apollo 11")
            Issue.record("Expected an HTTP error")
        } catch let error as WikipediaError {
            #expect(error.statusCode == 403)
            #expect(error.errorDescription == "Wikipedia answered with HTTP status 403: Please set a user-agent")
        }
    }

    @Test func malformedBodiesThrowDecodingErrors() async throws {
        let stub = StubbedClient { _ in .raw("<html>maintenance</html>") }
        do {
            _ = try await stub.client.summary(for: "Apollo 11")
            Issue.record("Expected a decoding error")
        } catch let error as WikipediaError {
            guard case let .decoding(type, _) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(type == "PageSummary")
        }
    }

    @Test func imageDataSendsTheUserAgent() async throws {
        let stub = StubbedClient { _ in StubResponse(status: 200, headers: ["Content-Type": "image/jpeg"], body: Data([0xFF, 0xD8, 0xFF])) }
        let url = try #require(URL(string: "https://upload." + stub.domain + "/wikipedia/commons/thumb/a/ab/X.jpg/330px-X.jpg"))
        let data = try await stub.client.imageData(from: url)
        #expect(data.count == 3)
        #expect(stub.lastRequest?.value(forHTTPHeaderField: "User-Agent") == testAgent.value)
        #expect(stub.lastRequest?.value(forHTTPHeaderField: "Accept") == "image/*")
    }
}
