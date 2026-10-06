import XCTest
@testable import MSecretCore
final class CoreTests: XCTestCase {
    func testRejectsValuesAndInvalidNames() {
        for args in [["set", "TOKEN", "secret"], ["get", "bad-name"], ["run", "TOKEN", "--"], ["run", "TOKEN", "TOKEN", "--", "env"]] {
            XCTAssertThrowsError(try Command.parse(args))
        }
        XCTAssertNoThrow(try validateName("_TOKEN_2"))
        XCTAssertThrowsError(try validateName("1TOKEN"))
        XCTAssertThrowsError(try validateName("TOKEN\n"))
        XCTAssertThrowsError(try validateName("TOKEN\0"))
    }
    func testPreservesChildArguments() throws {
        XCTAssertEqual(try Command.parse(["run", "TOKEN", "OTHER", "--", "echo", "a b", "--help"]), .run(["TOKEN", "OTHER"], ["echo", "a b", "--help"]))
    }
    func testIsolatedKeychainLifecycle() throws {
        guard ProcessInfo.processInfo.environment["MSECRET_KEYCHAIN_TESTS"] == "1" else { throw XCTSkip("Opt-in Keychain integration test") }
        let store = KeychainStore(service: "dev.msecret.tests." + UUID().uuidString)
        defer { try? store.delete("TEST_TOKEN") }
        XCTAssertEqual(try store.list(), [])
        XCTAssertThrowsError(try store.get("TEST_TOKEN"))
        try store.set("TEST_TOKEN", value: "dummy-one")
        XCTAssertEqual(try store.get("TEST_TOKEN"), "dummy-one")
        try store.set("TEST_TOKEN", value: "dummy-two")
        XCTAssertEqual(try store.get("TEST_TOKEN"), "dummy-two")
        XCTAssertEqual(try store.list(), ["TEST_TOKEN"])
        try store.delete("TEST_TOKEN")
        XCTAssertEqual(try store.list(), [])
    }
}
