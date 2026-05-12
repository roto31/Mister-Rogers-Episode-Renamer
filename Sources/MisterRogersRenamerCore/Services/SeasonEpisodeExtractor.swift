import Foundation

enum SeasonEpisodeExtractor {
    /// Extracts season and episode from common TV release patterns (SxE, 1x02). Does not use bare episode numbers.
    static func extract(from filename: String) -> (season: Int, episode: Int)? {
        let stem = (filename as NSString).deletingPathExtension
        let patterns: [(String, [Int])] = [
            (#"(?i)\bS(\d{1,4})[\s._-]*E(\d{1,5})\b"#, [1, 2]),
            (#"(?i)\b(\d{1,3})[xX](\d{1,5})\b"#, [1, 2]),
        ]
        for (pattern, groups) in patterns {
            if let found = matchGroups(stem, pattern: pattern, groups: groups) {
                return found
            }
        }
        return nil
    }

    private static func matchGroups(_ string: String, pattern: String, groups: [Int]) -> (season: Int, episode: Int)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = string as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let m = regex.firstMatch(in: string, options: [], range: full) else { return nil }
        guard groups.count >= 2,
              m.numberOfRanges > groups[1],
              let sr = Range(m.range(at: groups[0]), in: string),
              let er = Range(m.range(at: groups[1]), in: string),
              let season = Int(string[sr]),
              let episode = Int(string[er]),
              season >= 0, episode >= 0
        else {
            return nil
        }
        return (season, episode)
    }
}
