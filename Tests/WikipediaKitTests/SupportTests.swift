import Foundation
import Testing
@testable import WikipediaKit

@Suite("Titles, dates, HTML, thumbnails, languages and agents")
struct SupportTests {
    @Test func titles() {
        #expect(WikiTitle.canonical(" Apollo 11 ") == "Apollo_11")
        #expect(WikiTitle.normalized("Apollo_11") == "Apollo 11")
        #expect(WikiTitle.pathSegment("AC/DC") == "AC%2FDC")
        #expect(WikiTitle.pathSegment("What? Why #1") == "What%3F_Why_%231")
        #expect(WikiTitle.pathSegment("100% Pure") == "100%25_Pure")
        #expect(WikiTitle.pathSegment("C++") == "C++")
        #expect(WikiTitle.pathSegment("Zürich") == "Z%C3%BCrich")
        #expect(WikiTitle.pathSegment("Rock 'n' Roll (song)") == "Rock_'n'_Roll_(song)")
    }

    @Test func feedDates() throws {
        let date = WikiFeedDate(year: 2026, month: 10, day: 1)
        #expect(date.path == "2026/10/01")
        #expect(date.description == "2026-10-01")
        #expect(date.isValid)
        #expect(date.previousDay == WikiFeedDate(year: 2026, month: 9, day: 30))
        #expect(WikiFeedDate(year: 2026, month: 1, day: 1).previousDay == WikiFeedDate(year: 2025, month: 12, day: 31))
        #expect(WikiFeedDate("2026-10-01") == date)
        #expect(WikiFeedDate("20261001") == date)
        #expect(WikiFeedDate("2026-02-30") == nil)
        #expect(WikiFeedDate(year: 2026, month: 13, day: 1).isValid == false)
        #expect(WikiFeedDate(year: 2026, month: 9, day: 30) < date)
        let utcNoon = try #require(date.date).addingTimeInterval(12 * 3600)
        #expect(WikiFeedDate(utcNoon) == date)
    }

    @Test func html() {
        #expect(WikiHTML.plainText("<i>Apollo 11</i> &amp; the <span class=\"searchmatch\">Moon</span>") == "Apollo 11 & the Moon")
        #expect(WikiHTML.plainText("Moon&#039;s &#x2013; &quot;far&quot; side") == "Moon's \u{2013} \"far\" side")
        #expect(WikiHTML.plainText("  a\n\n  b  ") == "a b")
        #expect(WikiHTML.plainText("AT&T & co") == "AT&T & co")
        #expect(WikiHTML.decodeEntities("&unknown; &lt;b&gt;") == "&unknown; <b>")
    }

    @Test func thumbnails() throws {
        let thumb = try #require(URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Some_%28file%29.jpg/330px-Some_%28file%29.jpg"))
        #expect(WikimediaThumbnail.width(of: thumb) == 330)
        #expect(WikimediaThumbnail.url(thumb, width: 330, originalWidth: nil) == thumb)
        #expect(WikimediaThumbnail.url(thumb, width: 600, originalWidth: nil).absoluteString
            == "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Some_%28file%29.jpg/960px-Some_%28file%29.jpg")
        #expect(WikimediaThumbnail.url(thumb, width: 600, originalWidth: 700).lastPathComponent == "500px-Some_(file).jpg")
        #expect(WikimediaThumbnail.url(thumb, width: 100, originalWidth: nil).lastPathComponent == "120px-Some_(file).jpg")

        let svg = try #require(URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/Flag.svg/330px-Flag.svg.png"))
        #expect(WikimediaThumbnail.url(svg, width: 1000, originalWidth: 512).lastPathComponent == "500px-Flag.svg.png")

        let pdf = try #require(URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/Doc.pdf/page1-330px-Doc.pdf.jpg"))
        #expect(WikimediaThumbnail.width(of: pdf) == 330)
        #expect(WikimediaThumbnail.url(pdf, width: 500, originalWidth: nil).lastPathComponent == "page1-500px-Doc.pdf.jpg")

        let original = try #require(URL(string: "https://upload.wikimedia.org/wikipedia/commons/9/98/Photo.jpg"))
        #expect(WikimediaThumbnail.width(of: original) == nil)
        #expect(WikimediaThumbnail.url(original, width: 500, originalWidth: nil) == original)

        #expect(WikimediaThumbnail.standardWidth(atLeast: 1) == 20)
        #expect(WikimediaThumbnail.standardWidth(atLeast: 331) == 500)
        #expect(WikimediaThumbnail.standardWidth(atLeast: 10_000) == 3840)
    }

    @Test func languages() {
        #expect(WikipediaLanguage.german.host == "de.wikipedia.org")
        #expect(WikipediaLanguage("  DE ") == .german)
        #expect(WikipediaLanguage.french.autonym == "Français")
        #expect(WikipediaLanguage("zh-yue").isValid)
        #expect(WikipediaLanguage("simple").isValid)
        #expect(WikipediaLanguage("").isValid == false)
        #expect(WikipediaLanguage("en.evil.com/").isValid == false)
        #expect(WikipediaLanguage("1en").isValid == false)
        #expect(WikipediaLanguage.arabic.isRightToLeft)
        #expect(WikipediaLanguage.english.isRightToLeft == false)
        #expect(WikipediaLanguage.common.first == .english)
        #expect(Set(WikipediaLanguage.common).count == WikipediaLanguage.common.count)
    }

    @Test func userAgents() {
        let agent = WikipediaUserAgent(appName: "My Reader", version: "2.1", contact: "https://example.com/reader")
        #expect(agent.value == "My-Reader/2.1 (https://example.com/reader) WikipediaKit/1.0")
        #expect(agent.isValid)
        #expect(WikipediaUserAgent(appName: "Reader", version: "1", contact: "me@example.com").isValid)
        #expect(WikipediaUserAgent(appName: "", version: "1", contact: "me@example.com").problem != nil)
        #expect(WikipediaUserAgent(appName: "Reader", version: " ", contact: "me@example.com").problem != nil)
        #expect(WikipediaUserAgent(appName: "Reader", version: "1", contact: "").problem != nil)
        #expect(WikipediaUserAgent(appName: "Reader", version: "1", contact: "call me").problem != nil)
    }
}
