import Foundation

enum TvdbSeriesIDParser {
    /// Parses a numeric series id from pasted text: plain digits or a TheTVDB URL containing `/series/<id>`.
    static func parseSeriesID(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let onlyDigits = Int(trimmed), onlyDigits > 0 {
            return onlyDigits
        }

        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)/series/(\d+)(?:\b|/|\?|$)"#,
            options: []
        ) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let m = regex.firstMatch(in: trimmed, options: [], range: range),
              m.numberOfRanges >= 2,
              let idRange = Range(m.range(at: 1), in: trimmed),
              let id = Int(trimmed[idRange]), id > 0
        else {
            return nil
        }
        return id
    }
}
