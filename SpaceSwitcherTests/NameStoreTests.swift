import XCTest
@testable import SpaceSwitcher

final class NameStoreTests: XCTestCase {
    private var dir: URL!
    private var fileURL: URL { dir.appendingPathComponent("names.json") }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testMissingFileStartsEmpty() {
        XCTAssertNil(NameStore(fileURL: fileURL).name(for: "A"))
    }

    func testSetNamePersistsAcrossInstances() {
        NameStore(fileURL: fileURL).setName("업무", for: "A")
        XCTAssertEqual(NameStore(fileURL: fileURL).name(for: "A"), "업무")
    }

    func testCreatesDirectoryAndWritesSpecFormat() throws {
        NameStore(fileURL: fileURL).setName("메인", for: Space.mainKey)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        XCTAssertEqual(json?["version"] as? Int, 2)
        XCTAssertEqual((json?["names"] as? [String: String])?[Space.mainKey], "메인")
    }

    func testTrimsWhitespace() {
        let store = NameStore(fileURL: fileURL)
        store.setName("  개인 \n", for: "A")
        XCTAssertEqual(store.name(for: "A"), "개인")
    }

    func testEmptyNameRemovesEntry() {
        let store = NameStore(fileURL: fileURL)
        store.setName("업무", for: "A")
        store.setName("   ", for: "A")
        XCTAssertNil(store.name(for: "A"))
        XCTAssertNil(NameStore(fileURL: fileURL).name(for: "A"))
    }

    func testTruncatesToThirtyCharacters() {
        let store = NameStore(fileURL: fileURL)
        store.setName(String(repeating: "가", count: 40), for: "A")
        XCTAssertEqual(store.name(for: "A")?.count, NameStore.maxLength)
    }

    // Grapheme clusters, not UTF-16 units: an emoji must not be cut in half.
    func testTruncationKeepsWholeCharacters() {
        let store = NameStore(fileURL: fileURL)
        store.setName(String(repeating: "👨‍👩‍👧", count: 31), for: "A")
        XCTAssertEqual(store.name(for: "A"), String(repeating: "👨‍👩‍👧", count: 30))
    }

    func testRemoveUnusedKeepsOnlyGivenIDs() {
        let store = NameStore(fileURL: fileURL)
        store.setName("업무", for: "A")
        store.setName("옛날", for: "GONE")
        XCTAssertEqual(store.unusedCount(keeping: ["A"]), 1)
        XCTAssertEqual(store.removeUnused(keeping: ["A"]), 1)
        XCTAssertEqual(store.name(for: "A"), "업무")
        XCTAssertNil(NameStore(fileURL: fileURL).name(for: "GONE"))
    }

    // Names for Spaces that are temporarily missing must survive until the user cleans up explicitly.
    func testUnknownIDsAreKeptByDefault() {
        let store = NameStore(fileURL: fileURL)
        store.setName("옛날", for: "GONE")
        store.setName("업무", for: "A")
        XCTAssertEqual(NameStore(fileURL: fileURL).name(for: "GONE"), "옛날")
    }

    func testCorruptFileIsSetAsideNotOverwritten() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)

        let store = NameStore(fileURL: fileURL)
        XCTAssertNil(store.name(for: "A"))
        let backup = fileURL.appendingPathExtension("corrupt")
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), "not json")
    }

    func testPostsChangeNotification() {
        let store = NameStore(fileURL: fileURL)
        let posted = expectation(forNotification: NameStore.didChange, object: store)
        store.setName("업무", for: "A")
        wait(for: [posted], timeout: 1)
    }

    // MARK: descriptions (#17)

    func testDescriptionPersistsAndKeepsLineBreaks() {
        NameStore(fileURL: fileURL).setDescription("결제 모듈 분리\nPR #142 리뷰 대기", for: "A")
        XCTAssertEqual(NameStore(fileURL: fileURL).description(for: "A"), "결제 모듈 분리\nPR #142 리뷰 대기")
    }

    func testDescriptionTrimsOuterWhitespaceOnly() {
        let store = NameStore(fileURL: fileURL)
        store.setDescription("\n  첫 줄\n  들여쓴 둘째 줄  \n\n", for: "A")
        XCTAssertEqual(store.description(for: "A"), "첫 줄\n  들여쓴 둘째 줄")
    }

    func testEmptyDescriptionRemovesIt() {
        let store = NameStore(fileURL: fileURL)
        store.setDescription("메모", for: "A")
        store.setDescription("  \n ", for: "A")
        XCTAssertNil(store.description(for: "A"))
    }

    func testDescriptionIsCappedByCharacters() {
        let store = NameStore(fileURL: fileURL)
        store.setDescription(String(repeating: "가", count: 600), for: "A")
        XCTAssertEqual(store.description(for: "A")?.count, NameStore.maxDescriptionLength)
    }

    func testHasAnyDescription() {
        let store = NameStore(fileURL: fileURL)
        XCTAssertFalse(store.hasAnyDescription(among: ["A", "B"]))
        store.setDescription("메모", for: "GONE")
        XCTAssertFalse(store.hasAnyDescription(among: ["A", "B"]))   // only desktops that exist count
        store.setDescription("메모", for: "B")
        XCTAssertTrue(store.hasAnyDescription(among: ["A", "B"]))
    }

    // Files written by v0.1/v0.2 have no "descriptions" key.
    func testReadsVersionOneFile() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"version":1,"names":{"A":"업무"}}"#.utf8).write(to: fileURL)
        let store = NameStore(fileURL: fileURL)
        XCTAssertEqual(store.name(for: "A"), "업무")
        XCTAssertNil(store.description(for: "A"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.appendingPathExtension("corrupt").path))
    }

    func testRemoveUnusedAlsoRemovesDescriptions() {
        let store = NameStore(fileURL: fileURL)
        store.setDescription("옛 메모", for: "GONE")
        store.setName("업무", for: "A")
        XCTAssertEqual(store.unusedCount(keeping: ["A"]), 1)
        store.removeUnused(keeping: ["A"])
        XCTAssertNil(store.description(for: "GONE"))
        XCTAssertEqual(store.name(for: "A"), "업무")
    }

    func testDescriptionChangePostsNotification() {
        let store = NameStore(fileURL: fileURL)
        let posted = expectation(forNotification: NameStore.didChange, object: store)
        store.setDescription("메모", for: "A")
        wait(for: [posted], timeout: 1)
    }
}
