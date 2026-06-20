import XCTest
@testable import LeRecital

/// Dataset-integrity tests. These LOAD the bundled `Poems.json` and assert on
/// COUNTS and STRUCTURE only — they never compare, echo, or print verse text.
final class DatasetTests: XCTestCase {

    /// Load from the TEST bundle's host app resources.
    private func loadAnthology() -> Anthology {
        // The poems live in the app bundle (the test host). Resolve it robustly.
        let candidates: [Bundle] = [Bundle(for: DatasetTests.self), .main]
            + Bundle.allBundles
        for b in candidates {
            if b.url(forResource: "Poems", withExtension: "json") != nil {
                return Anthology.loadBundled(b)
            }
        }
        // Fall back to the host app bundle nested in the test bundle.
        if let hostURL = Bundle(for: DatasetTests.self).url(forResource: nil, withExtension: "app",
                                                            subdirectory: nil) {
            // unlikely path; keep for completeness
            _ = hostURL
        }
        return Anthology.loadBundled(.main)
    }

    func testExactlyThirtyPoems() {
        let anth = loadAnthology()
        XCTAssertEqual(anth.poems.count, 30, "Expected exactly 30 poems in the bundle.")
    }

    func testLanguageSplit() {
        let anth = loadAnthology()
        let en = anth.poems.filter { $0.lang == "en" }.count
        let fr = anth.poems.filter { $0.lang == "fr" }.count
        XCTAssertEqual(en, 17, "Expected 17 English poems.")
        XCTAssertEqual(fr, 13, "Expected 13 French poems.")
    }

    func testLangValuesValid() {
        let anth = loadAnthology()
        for p in anth.poems {
            XCTAssertTrue(p.lang == "en" || p.lang == "fr", "Unexpected lang for id \(p.id)")
        }
    }

    func testRequiredFieldsNonEmpty() {
        let anth = loadAnthology()
        for p in anth.poems {
            XCTAssertFalse(p.id.isEmpty, "Empty id")
            XCTAssertFalse(p.title.isEmpty, "Empty title for id \(p.id)")
            XCTAssertFalse(p.author.isEmpty, "Empty author for id \(p.id)")
            XCTAssertFalse(p.authorYears.isEmpty, "Empty authorYears for id \(p.id)")
            XCTAssertFalse(p.year.isEmpty, "Empty year for id \(p.id)")
            XCTAssertFalse(p.source.isEmpty, "Empty source for id \(p.id)")
        }
    }

    func testCraftNotesNonEmpty() {
        let anth = loadAnthology()
        for p in anth.poems {
            XCTAssertFalse(p.craftNote.fr.isEmpty, "Empty craftNote.fr for id \(p.id)")
            XCTAssertFalse(p.craftNote.en.isEmpty, "Empty craftNote.en for id \(p.id)")
        }
    }

    func testLineCountAtLeastSix() {
        let anth = loadAnthology()
        for p in anth.poems {
            XCTAssertGreaterThanOrEqual(p.lineCount, 6, "lineCount < 6 for id \(p.id)")
            // The declared lineCount should match the number of non-empty lines.
            XCTAssertEqual(p.lineCount, p.spokenLines.count,
                           "lineCount mismatch for id \(p.id)")
        }
    }

    func testIDsUnique() {
        let anth = loadAnthology()
        let ids = anth.poems.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Poem ids are not unique.")
    }

    func testEveryPoemHasAtLeastSomeWords() {
        // Masking + reveal rely on tokenizable words; assert counts only.
        let anth = loadAnthology()
        for p in anth.poems {
            XCTAssertGreaterThan(p.wordCount, 0, "No tokenizable words for id \(p.id)")
        }
    }
}
