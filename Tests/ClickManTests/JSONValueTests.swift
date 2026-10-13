import Foundation
import XCTest
@testable import ClickMan

final class JSONValueTests: XCTestCase {
    func testCyclicFoundationContainersAreRejectedInsteadOfCrashing() {
        let cycle = NSMutableArray()
        cycle.add(cycle)
        defer { cycle.removeAllObjects() }
        XCTAssertThrowsError(try JSONValue.object(from: ["cycle": cycle]))
    }

    func testCyclicFoundationDictionariesAreRejected() {
        let cycle = NSMutableDictionary()
        cycle["self"] = cycle
        defer { cycle.removeAllObjects() }
        XCTAssertThrowsError(try JSONValue.object(from: ["cycle": cycle]))
    }

    func testSharedContainersAreAllowedAndExcessiveNestingIsRejected() throws {
        let shared = NSArray(array: ["a", "b"])
        let object = try JSONValue.object(from: ["first": shared, "second": shared])
        XCTAssertEqual(object["first"], object["second"])
        var nested: Any = "leaf"
        for _ in 0..<70 { nested = ["nested": nested] }
        XCTAssertThrowsError(try JSONValue.object(from: ["deep": nested]))
    }
    func testHostValuesBecomeTheirJSON() throws {
        let host: [String: Any] = [
            "flag": true, "count": 42, "ratio": 32.5, "name": "mp4", "none": Int?.none as Any,
            "list": [1, "two"], "nested": ["deep": false],
        ]

        XCTAssertEqual(try JSONValue.object(from: host), [
            "flag": .bool(true), "count": .integer(42), "ratio": .number(32.5), "name": .string("mp4"), "none": .null,
            "list": .array([.integer(1), .string("two")]), "nested": .object(["deep": .bool(false)]),
        ])
    }

    func testDatesUrlsAndUuidsBecomeStringsAtAnyDepth() throws {
        let id = UUID()
        let host: [String: Any] = ["at": Date(unixMilliseconds: 0), "nested": ["link": URL(string: "https://example.com/a")!, "id": id]]

        XCTAssertEqual(try JSONValue.object(from: host), [
            "at": .string("1970-01-01T00:00:00.000Z"),
            "nested": .object(["link": .string("https://example.com/a"), "id": .string(id.uuidString)]),
        ])
    }

    func testAValueWithNoJSONFormIsRefused() {
        XCTAssertThrowsError(try JSONValue.object(from: ["value": NSObject()]))
        XCTAssertThrowsError(try JSONValue.object(from: ["keys": [1: "one"]]))
    }

    func testANumberThatIsNotFiniteHasNoText() {
        XCTAssertThrowsError(try JSONValue.number(.nan).json())
        XCTAssertThrowsError(try JSONValue.number(.infinity).json())
    }

    func testIntegersStayExact() throws {
        let object = try JSONValue.object(from: ["id": Int64(9_007_199_254_740_993)])
        XCTAssertEqual(try JSONValue.object(object).json(), #"{"id":9007199254740993}"#)
    }

    func testUnsignedIntegersStayExactBeyondTheSignedRange() throws {
        let object = try JSONValue.object(from: ["id": UInt64.max])
        XCTAssertEqual(try JSONValue.object(object).json(), #"{"id":18446744073709551615}"#)
    }

    func testTheTextHasSortedKeysAndPlainSlashes() throws {
        XCTAssertEqual(try JSONValue.object(["b": .string("https://x/y"), "a": .integer(1)]).json(), #"{"a":1,"b":"https://x/y"}"#)
    }

    func testStoredTextParsesBackToTheSameObject() throws {
        let traits: [String: JSONValue] = ["plan": .string("pro"), "seats": .integer(3), "team": .object(["id": .integer(2)])]

        XCTAssertEqual(try JSONValue.object(parsing: JSONValue.object(traits).json()), traits)
        XCTAssertThrowsError(try JSONValue.object(parsing: "[1]"))
    }
}
