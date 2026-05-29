import ArgumentParser
import XCTest

@testable import SmartWin

final class SmartWinTests: XCTestCase {
    func testApplicationIndexOutOfRangeThrows() throws {
        let args = ["9999", "-x", "0", "-y", "0", "--width", "100", "--height", "100"]
        var cmd = try RepositionWindow.parseAsRoot(args)
        XCTAssertThrowsError(try cmd.run()) { error in
            XCTAssert(error is ValidationError)
        }
    }

    func testResizeWidthWithoutHeightThrows() throws {
        let args = ["Finder", "-x", "0", "-y", "0", "--width", "100"]
        XCTAssertThrowsError(try RepositionWindow.parseAsRoot(args))
    }

    func testResizeHeightWithoutWidthThrows() throws {
        let args = ["Finder", "-x", "0", "-y", "0", "--height", "100"]
        XCTAssertThrowsError(try RepositionWindow.parseAsRoot(args))
    }

    func testResizeRequiresPositiveValues() throws {
        let args = ["Finder", "-x", "0", "-y", "0", "--width", "0", "--height", "100"]
        XCTAssertThrowsError(try RepositionWindow.parseAsRoot(args))
    }

    func testNoResizeIsValid() throws {
        let args = ["Finder", "-x", "0", "-y", "0"]
        XCTAssertNoThrow(try RepositionWindow.parseAsRoot(args))
    }
}
