import XCTest
@testable import MisterRogersRenamerCore

final class TvdbSeriesIDParserTests: XCTestCase {
    func test_plainDigits() {
        XCTAssertEqual(TvdbSeriesIDParser.parseSeriesID(from: "77750"), 77750)
        XCTAssertEqual(TvdbSeriesIDParser.parseSeriesID(from: "  12345  "), 12345)
    }

    func test_seriesURL() {
        XCTAssertEqual(
            TvdbSeriesIDParser.parseSeriesID(from: "https://thetvdb.com/series/77750/mister-rogers-neighborhood"),
            77750
        )
        XCTAssertEqual(
            TvdbSeriesIDParser.parseSeriesID(from: "https://www.thetvdb.com/series/42/show-name"),
            42
        )
    }

    func test_invalid() {
        XCTAssertNil(TvdbSeriesIDParser.parseSeriesID(from: ""))
        XCTAssertNil(TvdbSeriesIDParser.parseSeriesID(from: "no-id-here"))
    }
}
