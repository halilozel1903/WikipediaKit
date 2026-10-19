import Foundation

/// A calendar day for the feed endpoints, such as `2026/10/01` in
/// `/feed/featured/2026/10/01`. The feeds use days in UTC.
public struct WikiFeedDate: Hashable, Sendable, Comparable, CustomStringConvertible, Codable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The UTC day of `date`.
    public init(_ date: Date) {
        let components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 2001, month: components.month ?? 1, day: components.day ?? 1)
    }

    /// Today in UTC, the day Wikipedia's feeds are on.
    public static var today: WikiFeedDate {
        WikiFeedDate(Date())
    }

    /// `"2026-10-01"`, `"2026/10/01"` or `"20261001"`.
    public init?(_ string: String) {
        let digits = string.filter(\.isNumber)
        guard digits.count == 8,
              let year = Int(digits.prefix(4)),
              let month = Int(digits.dropFirst(4).prefix(2)),
              let day = Int(digits.suffix(2))
        else { return nil }
        self.init(year: year, month: month, day: day)
        guard isValid else { return nil }
    }

    /// Whether the day exists in the calendar.
    public var isValid: Bool {
        guard (1...12).contains(month), (1...31).contains(day), year > 0 else { return false }
        return date.map { WikiFeedDate($0) == self } ?? false
    }

    /// Midnight UTC at the start of the day.
    public var date: Date? {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// The day before, such as the day a featured feed's most-read list covers.
    public var previousDay: WikiFeedDate {
        guard let date, let previous = Self.calendar.date(byAdding: .day, value: -1, to: date) else { return self }
        return WikiFeedDate(previous)
    }

    /// Four digits: `"2026"`.
    public var yearString: String {
        let digits = String(year)
        return String(repeating: "0", count: max(0, 4 - digits.count)) + digits
    }

    /// Two digits: `"01"`.
    public var monthString: String { Self.pad(month) }
    /// Two digits: `"05"`.
    public var dayString: String { Self.pad(day) }

    /// `"2026/10/01"`, the path of the featured feed.
    public var path: String {
        yearString + "/" + monthString + "/" + dayString
    }

    /// `"2026-10-01"`.
    public var description: String {
        yearString + "-" + monthString + "-" + dayString
    }

    public static func < (lhs: WikiFeedDate, rhs: WikiFeedDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    static func pad(_ value: Int) -> String {
        value < 10 ? "0" + String(value) : String(value)
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
