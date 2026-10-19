import Foundation
@testable import WikipediaKit

/// JSON responses in `Fixtures/`, hand-written in the shapes of the published API schemas.
enum Fixture {
    struct Missing: Error {
        let name: String
    }

    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw Missing(name: name)
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONDecoder().decode(T.self, from: data(name))
    }
}

/// A canned HTTP response.
struct StubResponse: Sendable {
    var status: Int
    var headers: [String: String]
    var body: Data

    static func json(_ fixture: String, status: Int = 200) throws -> StubResponse {
        try StubResponse(status: status, headers: ["Content-Type": "application/json"], body: Fixture.data(fixture))
    }

    static func raw(_ text: String, status: Int = 200, headers: [String: String] = ["Content-Type": "application/json"]) -> StubResponse {
        StubResponse(status: status, headers: headers, body: Data(text.utf8))
    }

    static func status(_ status: Int, headers: [String: String] = [:]) -> StubResponse {
        StubResponse(status: status, headers: headers, body: Data())
    }
}

typealias StubHandler = @Sendable (URLRequest) throws -> StubResponse

/// Answers requests from a handler registered for the request's domain (the host without its
/// language label), so every test can run in parallel with its own domain. Nothing ever reaches
/// the network.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host, let handler = StubRegistry.shared.handler(for: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        StubRegistry.shared.record(request, for: host)
        do {
            let stub = try handler(request)
            guard let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: stub.headers) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class StubRegistry: @unchecked Sendable {
    static let shared = StubRegistry()

    private let lock = NSLock()
    private var handlers: [String: StubHandler] = [:]
    private var requests: [String: [URLRequest]] = [:]

    func register(_ handler: @escaping StubHandler, for domain: String) {
        lock.withLock { handlers[domain] = handler }
    }

    /// The handler for `en.stub-….test`, registered for `stub-….test`.
    func handler(for host: String) -> StubHandler? {
        lock.withLock { handlers[host] ?? handlers[Self.domain(of: host)] }
    }

    func record(_ request: URLRequest, for host: String) {
        lock.withLock { requests[Self.domain(of: host), default: []].append(request) }
    }

    func requests(for domain: String) -> [URLRequest] {
        lock.withLock { requests[domain] ?? [] }
    }

    static func domain(of host: String) -> String {
        guard let dot = host.firstIndex(of: ".") else { return host }
        return String(host[host.index(after: dot)...])
    }
}

let testAgent = WikipediaUserAgent(appName: "WikipediaKitTests", version: "1.0", contact: "https://github.com/halilozel1903/WikipediaKit")

/// A client wired to the stub, on a domain of its own.
struct StubbedClient {
    let domain: String
    let client: WikipediaClient

    init(
        language: WikipediaLanguage = .english,
        userAgent: WikipediaUserAgent = testAgent,
        maxRetries: Int = 2,
        relatedFallback: Bool = true,
        handler: @escaping StubHandler
    ) {
        domain = "stub-" + UUID().uuidString.lowercased() + ".test"
        StubRegistry.shared.register(handler, for: domain)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        client = WikipediaClient(configuration: WikipediaConfiguration(
            userAgent: userAgent,
            language: language,
            domain: domain,
            session: URLSession(configuration: configuration),
            maxRetries: maxRetries,
            relatedFallback: relatedFallback
        ))
    }

    /// Every request the client sent, in order.
    var requests: [URLRequest] {
        StubRegistry.shared.requests(for: domain)
    }

    var lastRequest: URLRequest? {
        requests.last
    }

    /// The last request's path, percent-encoded as sent.
    var lastPath: String? {
        lastRequest?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.percentEncodedPath }
    }

    /// The value of a query item of the last request.
    func lastQueryValue(_ name: String) -> String? {
        lastRequest?.queryValue(name)
    }
}

extension URLRequest {
    /// The value of a query item.
    func queryValue(_ name: String) -> String? {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first(where: { $0.name == name })?.value
    }

    /// The path, percent-encoded as sent.
    var encodedPath: String? {
        url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.percentEncodedPath }
    }
}

/// Counts calls across a handler's invocations.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }

    var count: Int {
        lock.withLock { value }
    }
}
