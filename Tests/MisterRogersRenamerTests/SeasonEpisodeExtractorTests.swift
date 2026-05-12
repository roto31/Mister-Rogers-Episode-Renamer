import XCTest
@testable import MisterRogersRenamerCore

final class SeasonEpisodeExtractorTests: XCTestCase {
    func test_sxe_variants() {
        let a = SeasonEpisodeExtractor.extract(from: "Show.S01E02.foo")
        XCTAssertEqual(a?.season, 1)
        XCTAssertEqual(a?.episode, 2)
        let b = SeasonEpisodeExtractor.extract(from: "show s1e3 bar")
        XCTAssertEqual(b?.season, 1)
        XCTAssertEqual(b?.episode, 3)
        let c = SeasonEpisodeExtractor.extract(from: "S12E345.mkv")
        XCTAssertEqual(c?.season, 12)
        XCTAssertEqual(c?.episode, 345)
    }

    func test_x_separator() {
        let a = SeasonEpisodeExtractor.extract(from: "Show 1x02")
        XCTAssertEqual(a?.season, 1)
        XCTAssertEqual(a?.episode, 2)
        let b = SeasonEpisodeExtractor.extract(from: "name.10x15.ext")
        XCTAssertEqual(b?.season, 10)
        XCTAssertEqual(b?.episode, 15)
    }

    func test_negative() {
        XCTAssertNil(SeasonEpisodeExtractor.extract(from: "episode 02 only"))
        XCTAssertNil(SeasonEpisodeExtractor.extract(from: "no pattern"))
    }
}
