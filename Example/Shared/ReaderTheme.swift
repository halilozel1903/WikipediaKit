import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ReaderTheme {
    /// The link blue of Wikipedia's interface, a little brighter for dark backgrounds.
    static let accent = Color(red: 0.24, green: 0.48, blue: 0.95)

    /// An opaque background for the Mac sidebar. A translucent (Liquid Glass) sidebar can come
    /// out as a blank white panel in window captures on CI; a solid color always draws.
    static var sidebarBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .systemGroupedBackground)
        #endif
    }

    /// Cards on the Today page.
    static var cardBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemBackground)
        #endif
    }

    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif).weight(weight)
    }
}

extension View {
    /// The inline title style with a visible bar on iPad (iOS 26 hides the bar background
    /// otherwise); nothing on the Mac.
    func readerNavigationStyle() -> some View {
        #if os(iOS)
        return navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        return self
        #endif
    }

    /// A rounded card with the card background.
    func readerCard() -> some View {
        background(ReaderTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// A value that is loading, loaded or failed.
enum Loadable<Value> {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case let .loaded(value) = self { return value }
        return nil
    }
}

/// A page to open, in a language.
struct ArticleRoute: Hashable {
    var title: String
    var language: String
}
