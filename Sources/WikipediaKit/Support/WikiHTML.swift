import Foundation

/// Turns the small HTML fragments Wikipedia sends (search snippets, news stories, display titles,
/// image descriptions) into plain text.
public enum WikiHTML {
    /// Removes tags, decodes character references (`&amp;`, `&quot;`, `&#8211;`, `&#x2013;`…)
    /// and collapses runs of whitespace into single spaces.
    ///
    /// ```swift
    /// WikiHTML.plainText("<i>Apollo 11</i> &amp; the <span class=\"searchmatch\">Moon</span>")
    /// // "Apollo 11 & the Moon"
    /// ```
    public static func plainText(_ html: String) -> String {
        var output = ""
        output.reserveCapacity(html.count)
        var inTag = false
        for character in html {
            if inTag {
                if character == ">" { inTag = false }
                continue
            }
            if character == "<" {
                inTag = true
                continue
            }
            output.append(character)
        }
        return collapseWhitespace(decodeEntities(output))
    }

    /// Decodes named and numeric character references.
    public static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            guard character == "&",
                  let semicolon = text[index...].prefix(12).firstIndex(of: ";")
            else {
                result.append(character)
                index = text.index(after: index)
                continue
            }
            let name = String(text[text.index(after: index)..<semicolon])
            if let decoded = decode(entity: name) {
                result.append(decoded)
                index = text.index(after: semicolon)
            } else {
                result.append(character)
                index = text.index(after: index)
            }
        }
        return result
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "ndash": "\u{2013}", "mdash": "\u{2014}", "hellip": "\u{2026}", "lsquo": "\u{2018}",
        "rsquo": "\u{2019}", "ldquo": "\u{201C}", "rdquo": "\u{201D}", "minus": "\u{2212}",
        "times": "\u{00D7}", "deg": "\u{00B0}", "copy": "\u{00A9}", "eacute": "\u{00E9}",
    ]

    private static func decode(entity name: String) -> String? {
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            return UInt32(name.dropFirst(2), radix: 16).flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
        }
        if name.hasPrefix("#") {
            return UInt32(name.dropFirst(), radix: 10).flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
        }
        return named[name]
    }

    private static func collapseWhitespace(_ text: String) -> String {
        var result = ""
        var pendingSpace = false
        for character in text {
            if character.isWhitespace {
                pendingSpace = !result.isEmpty
            } else {
                if pendingSpace {
                    result.append(" ")
                    pendingSpace = false
                }
                result.append(character)
            }
        }
        return result
    }
}
