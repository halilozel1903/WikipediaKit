import Foundation

/// A Wikipedia edition, by its language code: `en` is en.wikipedia.org, `de` is
/// de.wikipedia.org, `simple` is Simple English Wikipedia.
///
/// ```swift
/// let german: WikipediaLanguage = "de"
/// WikipediaLanguage.japanese.host       // "ja.wikipedia.org"
/// WikipediaLanguage.french.autonym      // "Français"
/// ```
public struct WikipediaLanguage: RawRepresentable, Hashable, Sendable, Codable, Identifiable,
    ExpressibleByStringLiteral, CustomStringConvertible
{
    /// The subdomain, such as `en`, `de`, `zh-yue` or `simple`. Always lowercase.
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public init(_ code: String) {
        self.init(rawValue: code)
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var id: String { rawValue }
    public var description: String { rawValue }

    /// The host on Wikipedia, such as `de.wikipedia.org`.
    public var host: String { host(domain: "wikipedia.org") }

    /// The host on another domain, such as `en.wiktionary.org` for `domain: "wiktionary.org"`.
    public func host(domain: String) -> String {
        rawValue + "." + domain
    }

    /// Whether the code can be a subdomain: letters, digits and hyphens, starting with a letter.
    public var isValid: Bool {
        let letters: ClosedRange<Unicode.Scalar> = "a"..."z"
        let digits: ClosedRange<Unicode.Scalar> = "0"..."9"
        guard let first = rawValue.unicodeScalars.first, letters.contains(first), rawValue.count <= 20 else {
            return false
        }
        return rawValue.unicodeScalars.allSatisfy { scalar in
            letters.contains(scalar) || digits.contains(scalar) || scalar == "-"
        }
    }

    /// The name of the language in itself, for the languages in ``common``; otherwise the code.
    public var autonym: String {
        Self.autonyms[rawValue] ?? rawValue
    }

    /// Whether the language is written right to left.
    public var isRightToLeft: Bool {
        ["ar", "arz", "fa", "he", "ur", "yi", "ps", "ckb", "sd", "ug", "dv"].contains(rawValue)
    }

    public static let english: WikipediaLanguage = "en"
    public static let simpleEnglish: WikipediaLanguage = "simple"
    public static let german: WikipediaLanguage = "de"
    public static let french: WikipediaLanguage = "fr"
    public static let spanish: WikipediaLanguage = "es"
    public static let italian: WikipediaLanguage = "it"
    public static let portuguese: WikipediaLanguage = "pt"
    public static let dutch: WikipediaLanguage = "nl"
    public static let polish: WikipediaLanguage = "pl"
    public static let swedish: WikipediaLanguage = "sv"
    public static let russian: WikipediaLanguage = "ru"
    public static let ukrainian: WikipediaLanguage = "uk"
    public static let turkish: WikipediaLanguage = "tr"
    public static let arabic: WikipediaLanguage = "ar"
    public static let hebrew: WikipediaLanguage = "he"
    public static let persian: WikipediaLanguage = "fa"
    public static let hindi: WikipediaLanguage = "hi"
    public static let japanese: WikipediaLanguage = "ja"
    public static let korean: WikipediaLanguage = "ko"
    public static let chinese: WikipediaLanguage = "zh"
    public static let vietnamese: WikipediaLanguage = "vi"
    public static let indonesian: WikipediaLanguage = "id"

    /// Large editions, in a stable order, for a language picker.
    public static let common: [WikipediaLanguage] = [
        .english, .german, .french, .spanish, .italian, .portuguese, .dutch, .polish, .swedish,
        .russian, .ukrainian, .turkish, .arabic, .hebrew, .persian, .hindi, .japanese, .korean,
        .chinese, .vietnamese, .indonesian, .simpleEnglish,
    ]

    static let autonyms: [String: String] = [
        "en": "English", "simple": "Simple English", "de": "Deutsch", "fr": "Français",
        "es": "Español", "it": "Italiano", "pt": "Português", "nl": "Nederlands", "pl": "Polski",
        "sv": "Svenska", "ru": "Русский", "uk": "Українська", "tr": "Türkçe", "ar": "العربية",
        "he": "עברית", "fa": "فارسی", "hi": "हिन्दी", "ja": "日本語", "ko": "한국어", "zh": "中文",
        "vi": "Tiếng Việt", "id": "Bahasa Indonesia",
    ]
}
