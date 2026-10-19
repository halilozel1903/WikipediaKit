import Foundation

/// Settings of a ``WikipediaClient``.
public struct WikipediaConfiguration: Sendable {
    /// Sent as `User-Agent` (and `Api-User-Agent`) with every request. Required by Wikimedia.
    public var userAgent: WikipediaUserAgent
    /// The Wikipedia edition requests go to. Change it per call with
    /// ``WikipediaClient/language(_:)``.
    public var language: WikipediaLanguage
    /// The project domain below the language: `wikipedia.org` by default. Requests go to
    /// `https://{language}.{domain}/api/rest_v1/…` and `https://{language}.{domain}/w/api.php`.
    /// Tests point it at a stub host.
    public var domain: String
    /// The session that performs requests. Give it a `URLProtocol` subclass to stub responses.
    public var session: URLSession
    /// How many times a request is retried after HTTP 429, 502, 503 or 504, a timeout or a lost
    /// connection (default 2). Retries wait 0.5 s, then 1 s, or what `Retry-After` asks (at most
    /// 30 s).
    public var maxRetries: Int
    /// The request timeout in seconds.
    public var timeout: TimeInterval
    /// Whether ``WikipediaClient/related(to:limit:)`` falls back to a `morelike:` search on the
    /// Action API when `/page/related` is not served (HTTP 403, 404, 410 or 501). On by default.
    public var relatedFallback: Bool

    public init(
        userAgent: WikipediaUserAgent,
        language: WikipediaLanguage = .english,
        domain: String = "wikipedia.org",
        session: URLSession = .shared,
        maxRetries: Int = 2,
        timeout: TimeInterval = 30,
        relatedFallback: Bool = true
    ) {
        self.userAgent = userAgent
        self.language = language
        self.domain = domain
        self.session = session
        self.maxRetries = max(0, maxRetries)
        self.timeout = timeout
        self.relatedFallback = relatedFallback
    }

    /// `https://{language}.{domain}`.
    public var siteURL: URL {
        URL(string: "https://" + language.host(domain: domain))!
    }

    /// `https://{language}.{domain}/api/rest_v1`.
    public var restBaseURL: URL {
        siteURL.appendingPathComponent("api").appendingPathComponent("rest_v1")
    }

    /// `https://{language}.{domain}/w/api.php`.
    public var actionAPIURL: URL {
        siteURL.appendingPathComponent("w").appendingPathComponent("api.php")
    }
}
