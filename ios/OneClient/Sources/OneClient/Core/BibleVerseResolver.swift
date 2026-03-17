import Foundation

public struct BibleVerseResolver: Sendable {
    public static let shared = BibleVerseResolver(bundle: .module)

    private let versesByReference: [String: String]

    public init(bundle: Bundle) {
        self.versesByReference = Self.loadLookup(bundle: bundle)
    }

    public func resolveText(for reference: String?, fallback: String?) -> String? {
        if let reference,
           let verse = versesByReference[Self.normalize(reference)] {
            return verse
        }
        guard let fallback else {
            return nil
        }
        let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func loadLookup(bundle: Bundle) -> [String: String] {
        guard let url = bundle.url(forResource: "kjv_lookup", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return raw
    }

    private static func normalize(_ reference: String) -> String {
        reference
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
            .lowercased()
    }
}
