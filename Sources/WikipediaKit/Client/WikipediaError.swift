import Foundation

/// Errors thrown by ``WikipediaClient``.
public enum WikipediaError: Error, Equatable, Sendable, LocalizedError {
    /// Nothing exists at this address (HTTP 404), such as a page title that does not exist.
    /// `problem` is the REST API's explanation when it sent one.
    case notFound(problem: WikipediaProblem?, url: URL)
    /// Any other unsuccessful HTTP status, with the REST API's problem details when it sent them.
    case http(statusCode: Int, problem: WikipediaProblem?, url: URL)
    /// The Action API (`w/api.php`) answered with an error object, such as `badvalue`.
    case api(code: String, info: String)
    /// The response was not JSON of the expected shape.
    case decoding(type: String, description: String)
    /// The request could not be completed (offline, timed out, cancelled…).
    case transport(URLError)
    /// The response was not an HTTP response.
    case invalidResponse
    /// The configured User-Agent does not meet Wikimedia's policy; nothing was sent.
    case invalidUserAgent(String)
    /// The request can't be sent as asked, such as an empty search or an invalid language code.
    case invalidRequest(String)

    public var errorDescription: String? {
        switch self {
        case let .notFound(problem, _):
            return problem?.detail ?? problem?.title ?? "Wikipedia has no page at this address."
        case let .http(statusCode, problem, _):
            if let text = problem?.detail ?? problem?.title {
                return "Wikipedia answered with HTTP status \(statusCode): \(text)"
            }
            return "Wikipedia answered with HTTP status \(statusCode)."
        case let .api(code, info):
            return info.isEmpty ? "The Wikipedia API returned the error \(code)." : info
        case let .decoding(type, _):
            return "Wikipedia sent data that could not be read as \(type)."
        case let .transport(error):
            return error.localizedDescription
        case .invalidResponse:
            return "Wikipedia sent an invalid response."
        case let .invalidUserAgent(reason):
            return reason
        case let .invalidRequest(reason):
            return reason
        }
    }

    /// Whether the error is a 404.
    public var isNotFound: Bool {
        if case .notFound = self { return true }
        return false
    }

    /// The HTTP status of a `.notFound` or `.http` error.
    public var statusCode: Int? {
        switch self {
        case .notFound: return 404
        case let .http(status, _, _): return status
        default: return nil
        }
    }
}

/// The problem details the REST API sends with errors
/// ([RFC 7807](https://www.rfc-editor.org/rfc/rfc7807)), such as
/// `{"type":"…/not_found","title":"Not found.","detail":"Page or revision not found."}`.
public struct WikipediaProblem: Codable, Equatable, Sendable {
    public var type: String?
    public var title: String?
    public var detail: String?
    public var method: String?
    public var uri: String?

    public init(type: String? = nil, title: String? = nil, detail: String? = nil, method: String? = nil, uri: String? = nil) {
        self.type = type
        self.title = title
        self.detail = detail
        self.method = method
        self.uri = uri
    }
}
