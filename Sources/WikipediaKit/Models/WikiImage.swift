import Foundation

/// An image on Wikimedia's servers with its size in pixels, such as a summary's `thumbnail` or
/// `originalimage`: `{"source":"https://upload.wikimedia.org/…","width":330,"height":330}`.
public struct WikiImage: Codable, Hashable, Sendable {
    public var source: URL
    public var width: Int?
    public var height: Int?
    public var mime: String?

    public init(source: URL, width: Int? = nil, height: Int? = nil, mime: String? = nil) {
        self.source = source
        self.width = width
        self.height = height
        self.mime = mime
    }

    enum CodingKeys: String, CodingKey {
        case source, width, height, mime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let text = container.lossy(String.self, forKey: .source), let url = URL(string: text) else {
            throw DecodingError.dataCorruptedError(forKey: .source, in: container, debugDescription: "No image source")
        }
        source = url
        width = container.lossyInt(forKey: .width)
        height = container.lossyInt(forKey: .height)
        mime = container.lossy(String.self, forKey: .mime)
    }

    /// Width divided by height, when both are known.
    public var aspectRatio: Double? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return Double(width) / Double(height)
    }

    /// The URL of a rendition about `width` pixels wide. See ``WikimediaThumbnail``.
    public func url(width requested: Int) -> URL {
        WikimediaThumbnail.url(source, width: requested, originalWidth: nil)
    }
}

/// Builds thumbnail URLs on upload.wikimedia.org.
///
/// A thumbnail URL has the form
/// `https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/File.jpg/330px-File.jpg`; the
/// `330px-` prefix of the last component picks its width. Wikimedia renders and caches a set of
/// standard widths and asks clients to use them, so a requested width is rounded up to the next
/// standard width (and never past the original's width when it is known). Non-thumbnail URLs are
/// returned unchanged.
public enum WikimediaThumbnail {
    /// The widths Wikimedia pre-renders for thumbnails.
    public static let standardWidths = [20, 40, 60, 120, 250, 330, 500, 960, 1280, 1920, 3840]

    /// The smallest standard width at least `width` pixels wide (the largest one past the end).
    public static func standardWidth(atLeast width: Int) -> Int {
        standardWidths.first { $0 >= width } ?? standardWidths[standardWidths.count - 1]
    }

    /// The width of a thumbnail URL, such as 330 for `…/330px-File.jpg`.
    public static func width(of url: URL) -> Int? {
        guard url.path.contains("/thumb/") else { return nil }
        let name = url.lastPathComponent
        guard let range = name.range(of: "px-") else { return nil }
        let prefix = name[name.startIndex..<range.lowerBound]
        // Page-numbered thumbnails look like "page1-330px-File.pdf.jpg".
        let digits = prefix.split(separator: "-").last.map(String.init) ?? String(prefix)
        return Int(digits)
    }

    /// `url` with its width changed to the standard width at least `width` pixels wide.
    public static func url(_ url: URL, width: Int, originalWidth: Int?) -> URL {
        guard let current = WikimediaThumbnail.width(of: url) else { return url }
        var target = standardWidth(atLeast: max(1, width))
        if let originalWidth, originalWidth > 0, target > originalWidth {
            // Thumbnails can't be wider than the original; use the widest standard one that fits.
            target = standardWidths.last { $0 <= originalWidth } ?? current
        }
        guard target != current else { return url }
        // Edit the text of the URL so the rest of it keeps its exact percent-encoding.
        let text = url.absoluteString
        guard let slash = text.lastIndex(of: "/") else { return url }
        let name = text[text.index(after: slash)...]
        let old = String(current) + "px-"
        guard let range = name.range(of: old) else { return url }
        var newText = text
        newText.replaceSubrange(range, with: String(target) + "px-")
        return URL(string: newText) ?? url
    }
}
