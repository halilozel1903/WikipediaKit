import Foundation

/// Decodes an array, skipping elements that fail to decode instead of failing the whole array.
struct LossyArray<Element: Decodable>: Decodable {
    var elements: [Element]

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else if (try? container.decode(Skip.self)) == nil {
                // The container could not move past the element; stop rather than loop.
                break
            }
        }
        self.elements = elements
    }

    /// Decodes anything (objects, strings, numbers, null) without reading it, so the container
    /// moves past an element that failed.
    private struct Skip: Decodable {
        init(from decoder: any Decoder) throws {}
    }
}

extension KeyedDecodingContainer {
    /// The value for `key`, or `nil` when it is missing, `null` or of another type.
    func lossy<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    /// An array for `key` with the elements that decode; empty when missing or not an array.
    func lossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
        lossy(LossyArray<T>.self, forKey: key)?.elements ?? []
    }

    /// A string for `key`, also accepting a number; `nil` when missing or empty.
    func lossyString(forKey key: Key) -> String? {
        if let string = lossy(String.self, forKey: key) {
            return string.isEmpty ? nil : string
        }
        if let int = lossy(Int.self, forKey: key) {
            return String(int)
        }
        return nil
    }

    /// An integer for `key`, also accepting a numeric string.
    func lossyInt(forKey key: Key) -> Int? {
        if let int = lossy(Int.self, forKey: key) {
            return int
        }
        if let string = lossy(String.self, forKey: key) {
            return Int(string.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }
}

/// A coding key made from any string, for reading only the keys a model needs.
struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        stringValue = string
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
