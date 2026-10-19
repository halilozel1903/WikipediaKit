import Foundation

/// Page titles as the APIs want them.
public enum WikiTitle {
    /// The form used in URLs: spaces become underscores, leading and trailing whitespace is
    /// removed. `"Apollo 11"` becomes `"Apollo_11"`.
    public static func canonical(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
    }

    /// The form shown to people: underscores become spaces. `"Apollo_11"` becomes `"Apollo 11"`.
    public static func normalized(_ title: String) -> String {
        title.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// One path segment for the REST API: the canonical title, percent-encoded, with `/`, `?`,
    /// `#` and `%` encoded too, so `"AC/DC"` is `"AC%2FDC"`.
    public static func pathSegment(_ title: String) -> String {
        canonical(title).addingPercentEncoding(withAllowedCharacters: pathAllowed) ?? canonical(title)
    }

    /// Unreserved characters and the sub-delimiters that MediaWiki leaves alone in titles.
    static let pathAllowed: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        set.insert(charactersIn: "-._~!$&'()*+,;=:@")
        return set
    }()
}
