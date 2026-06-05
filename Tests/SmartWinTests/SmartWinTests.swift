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

    func testDetectWindowsOptionalApplicationArgumentParses() throws {
        let cmd = try DetectWindows.parseAsRoot(["Safari"])
        guard let detectCmd = cmd as? DetectWindows else {
            XCTFail("Expected DetectWindows command")
            return
        }
        XCTAssertEqual(detectCmd.applicationArgument, "Safari")
    }

    func testDetectWindowsJsonLongOptionParses() throws {
        let cmd = try DetectWindows.parseAsRoot(["Safari", "--json"])
        guard let detectCmd = cmd as? DetectWindows else {
            XCTFail("Expected DetectWindows command")
            return
        }
        XCTAssertTrue(detectCmd.json)
    }

    func testRepositionWindowAcceptsRelativeMonitorOptions() throws {
        let args = ["Finder", "-w", "1", "--monitor", "1", "--left", "50", "--top", "10", "--width", "800", "--height", "600"]
        XCTAssertNoThrow(try RepositionWindow.parseAsRoot(args))
    }

    func testRepositionWindowLongWindowOptionParses() throws {
        let args = ["Finder", "--window", "1", "--monitor", "1", "--left", "50", "--top", "10", "--width", "800", "--height", "600"]
        XCTAssertNoThrow(try RepositionWindow.parseAsRoot(args))
    }

    func testRepositionWindowShortMonitorOptionParses() throws {
        let args = ["Finder", "--window", "1", "-m", "1", "--left", "50", "--top", "10", "--width", "800", "--height", "600"]
        XCTAssertNoThrow(try RepositionWindow.parseAsRoot(args))
    }

    func testRepositionWindowRejectsLeftAndRightTogether() throws {
        let args = ["Finder", "--left", "10", "--right", "10"]
        XCTAssertThrowsError(try RepositionWindow.parseAsRoot(args))
    }
}
