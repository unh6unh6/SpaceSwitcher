import XCTest
@testable import SpaceSwitcher

final class MemoStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func files(in url: URL? = nil) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: (url ?? dir).path)) ?? []).sorted()
    }

    private func read(_ name: String, in url: URL? = nil) -> String {
        (try? String(contentsOf: (url ?? dir).appendingPathComponent(name), encoding: .utf8)) ?? ""
    }

    func testSaveCreatesNamedMarkdownFile() {
        let store = MemoStore(directory: dir)
        store.setMemo("## 오늘\n- [ ] 할 일", for: "A", desktopName: "업무")
        XCTAssertEqual(files(), ["업무.md"])
        XCTAssertEqual(read("업무.md"), "---\nspace: A\n---\n## 오늘\n- [ ] 할 일\n")
        XCTAssertEqual(MemoStore(directory: dir).memo(for: "A"), "## 오늘\n- [ ] 할 일")
    }

    func testUpdatingKeepsTheSameFile() {
        let store = MemoStore(directory: dir)
        store.setMemo("처음", for: "A", desktopName: "업무")
        store.setMemo("고침", for: "A", desktopName: "업무")
        XCTAssertEqual(files(), ["업무.md"])
        XCTAssertEqual(store.memo(for: "A"), "고침")
    }

    func testEmptyMemoDeletesFile() {
        let store = MemoStore(directory: dir)
        store.setMemo("메모", for: "A", desktopName: "업무")
        store.setMemo("  \n", for: "A", desktopName: "업무")
        XCTAssertEqual(files(), [])
        XCTAssertNil(store.memo(for: "A"))
    }

    func testSameDesktopNameGetsNumberedFiles() {
        let store = MemoStore(directory: dir)
        store.setMemo("하나", for: "A", desktopName: "업무")
        store.setMemo("둘", for: "B", desktopName: "업무")
        XCTAssertEqual(files(), ["업무 2.md", "업무.md"])
        XCTAssertEqual(store.memo(for: "B"), "둘")
    }

    // The link lives in the front matter, so a file renamed in Finder still belongs to its desktop.
    func testFileRenamedOutsideStillMatches() throws {
        MemoStore(directory: dir).setMemo("메모", for: "A", desktopName: "업무")
        try FileManager.default.moveItem(at: dir.appendingPathComponent("업무.md"),
                                         to: dir.appendingPathComponent("아무 이름.md"))
        let store = MemoStore(directory: dir)
        XCTAssertEqual(store.memo(for: "A"), "메모")
        store.setMemo("고침", for: "A", desktopName: "업무")
        XCTAssertEqual(files(), ["아무 이름.md"])
    }

    func testRenameDesktopRenamesFile() {
        let store = MemoStore(directory: dir)
        store.setMemo("메모", for: "A", desktopName: "업무")
        store.renameFile(for: "A", to: "백엔드")
        XCTAssertEqual(files(), ["백엔드.md"])
        XCTAssertEqual(store.memo(for: "A"), "메모")
    }

    // Other notes in the same folder (e.g. an Obsidian vault) are never touched.
    func testIgnoresMarkdownWithoutSpaceFrontMatter() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "# 내 노트".write(to: dir.appendingPathComponent("업무.md"), atomically: true, encoding: .utf8)
        let store = MemoStore(directory: dir)
        XCTAssertFalse(store.hasAnyMemo(among: ["A"]))
        store.setMemo("메모", for: "A", desktopName: "업무")
        XCTAssertEqual(files(), ["업무 2.md", "업무.md"])
        XCTAssertEqual(read("업무.md"), "# 내 노트")
    }

    func testExternalEditIsPickedUpOnReload() throws {
        let store = MemoStore(directory: dir)
        store.setMemo("처음", for: "A", desktopName: "업무")
        try "---\nspace: A\n---\n바깥에서 고침\n".write(to: dir.appendingPathComponent("업무.md"),
                                                     atomically: true, encoding: .utf8)
        store.reload()
        XCTAssertEqual(store.memo(for: "A"), "바깥에서 고침")
    }

    func testHasAnyMemoOnlyCountsGivenDesktops() {
        let store = MemoStore(directory: dir)
        store.setMemo("메모", for: "GONE", desktopName: "옛날")
        XCTAssertFalse(store.hasAnyMemo(among: ["A"]))
        store.setMemo("메모", for: "A", desktopName: "업무")
        XCTAssertTrue(store.hasAnyMemo(among: ["A"]))
    }

    func testChangeDirectoryMovingFiles() {
        let store = MemoStore(directory: dir)
        store.setMemo("메모", for: "A", desktopName: "업무")
        let newDir = dir.appendingPathComponent("vault")
        store.changeDirectory(to: newDir, moveExisting: true)
        XCTAssertEqual(files(in: newDir), ["업무.md"])
        XCTAssertFalse(files().contains("업무.md"))
        XCTAssertEqual(store.memo(for: "A"), "메모")
    }

    func testChangeDirectoryWithoutMovingStartsFromNewFolder() {
        let store = MemoStore(directory: dir)
        store.setMemo("메모", for: "A", desktopName: "업무")
        let newDir = dir.appendingPathComponent("empty")
        store.changeDirectory(to: newDir, moveExisting: false)
        XCTAssertNil(store.memo(for: "A"))
        XCTAssertEqual(files(), ["empty", "업무.md"])
    }

    // #17 put descriptions into names.json before memos were files; move them out once.
    func testImportsLegacyDescriptionsWithoutOverwriting() {
        let store = MemoStore(directory: dir)
        store.setMemo("이미 있음", for: "A", desktopName: "업무")
        store.importLegacy(["A": "옛 설명", "B": "다른 설명"], desktopName: { $0 == "B" ? "개인" : "?" })
        XCTAssertEqual(store.memo(for: "A"), "이미 있음")
        XCTAssertEqual(store.memo(for: "B"), "다른 설명")
        XCTAssertEqual(files(), ["개인.md", "업무.md"])
    }

    func testChangePostsNotification() {
        let store = MemoStore(directory: dir)
        let posted = expectation(forNotification: MemoStore.didChange, object: store)
        store.setMemo("메모", for: "A", desktopName: "업무")
        wait(for: [posted], timeout: 1)
    }
}
