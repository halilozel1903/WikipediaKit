import SwiftUI
import WikipediaKit

/// A page's lead image, about `width` pixels wide, with a placeholder.
public struct ArticleThumbnail: View {
    private let page: PageSummary
    private let width: Int
    private let contentMode: ContentMode

    public init(page: PageSummary, width: Int = 330, contentMode: ContentMode = .fill) {
        self.page = page
        self.width = width
        self.contentMode = contentMode
    }

    public var body: some View {
        WikiRemoteImage(url: page.imageURL(width: width), contentMode: contentMode)
            .accessibilityHidden(true)
    }
}

/// A row for a list of pages: thumbnail, title, short description and an optional leading
/// number (a rank) and trailing detail (such as a view count).
public struct ArticleRow: View {
    private let page: PageSummary
    private let rank: Int?
    private let detail: String?
    private let thumbnailSize: CGFloat

    public init(page: PageSummary, rank: Int? = nil, detail: String? = nil, thumbnailSize: CGFloat = 56) {
        self.page = page
        self.rank = rank
        self.detail = detail
        self.thumbnailSize = thumbnailSize
    }

    public var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text(String(rank))
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 26, alignment: .trailing)
            }
            // Pages without a lead image get no thumbnail rather than an empty tile.
            if page.imageURL(width: Int(thumbnailSize * 2)) != nil {
                ArticleThumbnail(page: page, width: Int(thumbnailSize * 2))
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(page.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                if let description = page.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The license line Wikipedia's content asks for: "Text from Wikipedia, available under
/// CC BY-SA 4.0", linking to the page when there is one.
public struct WikipediaAttribution: View {
    private let page: PageSummary?

    public init(page: PageSummary? = nil) {
        self.page = page
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text("Text from Wikipedia, available under")
            Link("CC BY-SA 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
            if let url = page?.webURL {
                Text("·")
                Link("Source", destination: url)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

extension Int {
    /// A short view count, such as `1.2M views` or `845K views`.
    public var compactViews: String {
        let value = Double(self)
        switch self {
        case 1_000_000...:
            return String(format: "%.1fM views", value / 1_000_000)
        case 10_000...:
            return String(format: "%.0fK views", value / 1_000)
        case 1_000...:
            return String(format: "%.1fK views", value / 1_000)
        default:
            return String(self) + " views"
        }
    }
}
