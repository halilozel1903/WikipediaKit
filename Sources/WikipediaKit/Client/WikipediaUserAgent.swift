import Foundation

/// The `User-Agent` every request of a ``WikipediaClient`` sends.
///
/// Wikimedia's [User-Agent policy](https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_User-Agent_Policy)
/// asks every client to identify itself with a name, a version and a way to contact its author,
/// and blocks requests with generic or missing agents. WikipediaKit therefore has no default
/// agent: you pass one when you create the client, and requests are refused before they are sent
/// when it is incomplete.
///
/// ```swift
/// let agent = WikipediaUserAgent(
///     appName: "MyReader",
///     version: "2.1",
///     contact: "https://example.com/myreader; myreader@example.com"
/// )
/// agent.value   // "MyReader/2.1 (https://example.com/myreader; myreader@example.com) WikipediaKit/1.0"
/// ```
public struct WikipediaUserAgent: Sendable, Hashable, CustomStringConvertible {
    /// The version of WikipediaKit added to every agent as a library token.
    public static let libraryVersion = "1.0"

    /// Your app or tool, such as `MyReader`.
    public var appName: String
    /// Its version, such as `2.1`.
    public var version: String
    /// How Wikimedia can reach you: a web page, an email address, or both.
    public var contact: String

    public init(appName: String, version: String, contact: String) {
        self.appName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.version = version.trimmingCharacters(in: .whitespacesAndNewlines)
        self.contact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The header value: `AppName/version (contact) WikipediaKit/1.0`. Spaces in the app name
    /// become hyphens so the product token stays one word.
    public var value: String {
        let name = appName.replacingOccurrences(of: " ", with: "-")
        return name + "/" + version + " (" + contact + ") WikipediaKit/" + Self.libraryVersion
    }

    public var description: String { value }

    /// Why the agent does not meet the policy, or `nil` when it does: the name and version must
    /// not be empty, and the contact must be a URL or an email address.
    public var problem: String? {
        if appName.isEmpty {
            return "The User-Agent needs the name of your app or tool."
        }
        if version.isEmpty {
            return "The User-Agent needs the version of your app or tool."
        }
        if contact.isEmpty {
            return "The User-Agent needs contact information: a URL or an email address."
        }
        let lowered = contact.lowercased()
        let looksLikeURL = lowered.contains("http://") || lowered.contains("https://")
        let looksLikeEmail = contact.contains("@") && contact.contains(".")
        if !looksLikeURL && !looksLikeEmail {
            return "The User-Agent contact must be a URL or an email address, not \"" + contact + "\"."
        }
        return nil
    }

    /// Whether the agent meets the policy (``problem`` is `nil`).
    public var isValid: Bool {
        problem == nil
    }
}
