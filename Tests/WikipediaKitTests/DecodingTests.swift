import Foundation
import Testing
@testable import WikipediaKit

@Suite("Decoding")
struct DecodingTests {
    @Test func summary() throws {
        let page = try Fixture.decode(PageSummary.self, from: "summary-apollo-11")

        #expect(page.title == "Apollo 11")
        #expect(page.id == "Apollo_11")
        #expect(page.displayTitleHTML == "<i>Apollo 11</i>")
        #expect(page.displayTitle == "Apollo 11")
        #expect(page.pageID == 662)
        #expect(page.wikidataItem == "Q43653")
        #expect(page.description == "First crewed Moon landing mission (1969)")
        #expect(page.extract?.hasPrefix("Apollo 11 was a spaceflight") == true)
        #expect(page.extractHTML?.hasPrefix("<p><b>Apollo 11</b>") == true)
        #expect(page.thumbnail?.width == 330)
        #expect(page.originalImage?.width == 2349)
        #expect(page.language == "en")
        #expect(page.direction == "ltr")
        #expect(page.isDisambiguation == false)
        #expect(page.desktopURL?.absoluteString == "https://en.wikipedia.org/wiki/Apollo_11")
        #expect(page.mobileURL?.absoluteString == "https://en.m.wikipedia.org/wiki/Apollo_11")
        #expect(page.webURL == page.desktopURL)
        #expect(page.imageAspectRatio == 1.0)
    }

    @Test func summaryImageURLs() throws {
        let page = try Fixture.decode(PageSummary.self, from: "summary-apollo-11")

        #expect(page.imageURL()?.lastPathComponent == "330px-Aldrin_Apollo_11_original.jpg")
        #expect(page.imageURL(width: 900)?.lastPathComponent == "960px-Aldrin_Apollo_11_original.jpg")
        #expect(page.imageURL(width: 5000)?.lastPathComponent == "1920px-Aldrin_Apollo_11_original.jpg")
    }

    @Test func summaryRoundTrip() throws {
        let page = try Fixture.decode(PageSummary.self, from: "summary-apollo-11")
        let data = try JSONEncoder().encode(page)
        let decoded = try JSONDecoder().decode(PageSummary.self, from: data)
        #expect(decoded == page)
    }

    @Test func summaryWithOnlyATitle() throws {
        let page = try JSONDecoder().decode(PageSummary.self, from: Data(#"{"title":"Main_Page","pageid":"15580374"}"#.utf8))
        #expect(page.title == "Main Page")
        #expect(page.id == "Main_Page")
        #expect(page.pageID == 15580374)
        #expect(page.thumbnail == nil)
        #expect(page.imageURL() == nil)
        #expect(page.webURL == nil)
    }

    @Test func summaryWithoutTitleFails() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PageSummary.self, from: Data(#"{"type":"standard"}"#.utf8))
        }
    }

    @Test func featuredFeed() throws {
        let feed = try Fixture.decode(FeaturedContent.self, from: "featured-2026-10-01")

        #expect(feed.featuredArticle?.title == "Hubble Space Telescope")
        #expect(feed.featuredArticle?.description == "NASA/ESA space telescope launched in 1990")
        #expect(feed.isEmpty == false)

        let mostRead = try #require(feed.mostRead)
        #expect(mostRead.day == WikiFeedDate(year: 2026, month: 9, day: 30))
        // The element without a title is skipped; the rest are sorted by rank.
        #expect(mostRead.articles.map(\.page.title) == ["Neil Armstrong", "Moon"])
        #expect(mostRead.articles.first?.views == 1203456)
        #expect(mostRead.articles.first?.rank == 3)
        #expect(mostRead.articles.last?.viewHistory.count == 2)
        #expect(mostRead.articles.last?.viewHistory.last == DailyViews(date: "2026-09-30Z", views: 412345))
    }

    @Test func pictureOfTheDay() throws {
        let feed = try Fixture.decode(FeaturedContent.self, from: "featured-2026-10-01")
        let picture = try #require(feed.pictureOfTheDay)

        #expect(picture.title == "File:Full Moon Luc Viatour.jpg")
        #expect(picture.displayTitle == "Full Moon Luc Viatour")
        #expect(picture.plainDescription == "The full Moon seen from Earth & photographed in 2010.")
        #expect(picture.artist == "Luc Viatour")
        #expect(picture.plainArtist == "Luc Viatour")
        #expect(picture.credit == "Own work")
        #expect(picture.license == "CC BY-SA 3.0")
        #expect(picture.licenseCode == "cc-by-sa-3.0")
        #expect(picture.licenseURL?.absoluteString == "https://creativecommons.org/licenses/by-sa/3.0")
        #expect(picture.filePageURL?.absoluteString == "https://commons.wikimedia.org/wiki/File:FullMoon2010.jpg")
        #expect(picture.aspectRatio == 1.0)
        // 640 is not a standard width; asking for 960 snaps to it and stays under the original.
        #expect(picture.imageURL(width: 900)?.lastPathComponent == "960px-FullMoon2010.jpg")
        #expect(picture.imageURL(width: 1400)?.lastPathComponent == "1280px-FullMoon2010.jpg")
    }

    @Test func onThisDayAndNewsInTheFeed() throws {
        let feed = try Fixture.decode(FeaturedContent.self, from: "featured-2026-10-01")

        #expect(feed.onThisDay.count == 2)
        #expect(feed.onThisDay.first?.year == 1949)
        #expect(feed.onThisDay.first?.pages.first?.title == "People's Republic of China")
        #expect(feed.onThisDay.last?.pages.isEmpty == true)
        #expect(feed.onThisDay.last?.leadPage == nil)

        #expect(feed.news.count == 1)
        #expect(feed.news.first?.story == "A comet passes Earth & is seen worldwide.")
        #expect(feed.news.first?.links.first?.title == "Comet")
    }

    @Test func emptyFeed() throws {
        let feed = try JSONDecoder().decode(FeaturedContent.self, from: Data("{}".utf8))
        #expect(feed.isEmpty)
        #expect(feed.featuredArticle == nil)
        #expect(feed.news.isEmpty)
    }

    @Test func onThisDayLists() throws {
        let day = try Fixture.decode(OnThisDay.self, from: "onthisday-all-07-20")

        #expect(day.selected.first?.year == 1969)
        #expect(day.selected.first?.pages.first?.displayTitle == "Apollo 11")
        #expect(day.births.count == 2)
        #expect(day.deaths.first?.yearText == "1973")
        #expect(day.events.first?.yearText == "356 BC")
        #expect(day.holidays.first?.year == nil)
        #expect(day.holidays.first?.yearText == nil)
        #expect(day.list(.births).map(\.year) == [1304, 1919])
        // .all: every dated list, newest first, then holidays.
        #expect(day.list(.all).map(\.year) == [1973, 1969, 1919, 1304, -356, nil])
    }

    @Test func relatedPages() throws {
        let response = try Fixture.decode(RelatedPagesResponse.self, from: "related-apollo-11")
        #expect(response.pages.map(\.title) == ["Apollo 12", "Buzz Aldrin"])
    }

    @Test func searchResponse() throws {
        let response = try Fixture.decode(SearchResponse.self, from: "search-moon-landing")

        #expect(response.totalHits == 8421)
        #expect(response.suggestion == "moon landings")
        #expect(response.nextOffset == 2)
        #expect(response.results.count == 2)
        let first = try #require(response.results.first)
        #expect(first.title == "Moon landing")
        #expect(first.id == "Moon_landing")
        #expect(first.pageID == 21580)
        #expect(first.namespace == 0)
        #expect(first.wordCount == 7512)
        #expect(first.size == 64210)
        #expect(first.snippet == "A Moon landing is the arrival of a spacecraft on the surface of the Moon's")
    }

    @Test func emptySearchResponse() throws {
        let response = try Fixture.decode(SearchResponse.self, from: "search-empty")
        #expect(response.results.isEmpty)
        #expect(response.totalHits == 0)
        #expect(response.nextOffset == nil)
    }

    @Test func pagesResponse() throws {
        let response = try Fixture.decode(PagesResponse.self, from: "pageinfo")

        #expect(response.pages.count == 3)
        #expect(response.renamed["moon landing"] == "Moon landing")
        #expect(response.renamed["Moon landing"] == "Moon landings")
        let missing = try #require(response.pages.first { $0.title == "No such page here" })
        #expect(missing.isMissing)
        let landing = try #require(response.pages.first { $0.title == "Moon landings" })
        #expect(landing.isMissing == false)
        #expect(landing.pageImage == "Aldrin_Apollo_11_original.jpg")
        #expect(landing.thumbnail?.height == 330)
    }

    @Test func pagesResponseInFormatVersion1() throws {
        let json = #"{"query":{"pages":{"662":{"pageid":662,"ns":0,"title":"Apollo 11","description":"Mission"},"-1":{"ns":0,"title":"Nope","missing":""}}}}"#
        let response = try JSONDecoder().decode(PagesResponse.self, from: Data(json.utf8))
        #expect(response.pages.map(\.title) == ["Apollo 11", "Nope"])
        #expect(response.pages.last?.isMissing == true)
    }

    @Test func generatorResultsAreInSearchOrder() throws {
        let response = try Fixture.decode(PagesResponse.self, from: "morelike-apollo-11")
        #expect(response.pages.map(\.title) == ["Apollo 12", "Buzz Aldrin"])
        let summary = try #require(response.pages.first?.summary(language: "en"))
        #expect(summary.description == "Second crewed Moon landing (1969)")
        #expect(summary.extract == "Apollo 12 was the sixth crewed flight in the Apollo program.")
        #expect(summary.webURL?.absoluteString == "https://en.wikipedia.org/wiki/Apollo_12")
    }

    @Test func problemDetails() throws {
        let problem = try Fixture.decode(WikipediaProblem.self, from: "error-not-found")
        #expect(problem.title == "Not found.")
        #expect(problem.detail == "Page or revision not found.")
    }
}
