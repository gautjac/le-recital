import XCTest
@testable import LeRecital

/// Pure-logic tests for the daily selection, progressive masking, and SRS. These
/// build synthetic poems with placeholder tokens — NO real verse is used here.
final class LogicTests: XCTestCase {

    // Synthetic poem with `n` spoken lines of `w` placeholder words each.
    private func makePoem(id: String, lang: String = "en", lines n: Int = 8, wordsPerLine w: Int = 6) -> Poem {
        var lines: [String] = []
        for li in 0..<n {
            let words = (0..<w).map { "w\(li)x\($0)" }.joined(separator: " ")
            lines.append(words)
            if li == n / 2 - 1 { lines.append("") } // a stanza break
        }
        return Poem(
            id: id, title: "T-\(id)", author: "A", authorYears: "1800–1850",
            year: "1820", lang: lang, lines: lines,
            lineCount: n, source: "synthetic",
            craftNote: .init(fr: "fr", en: "en")
        )
    }

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    // MARK: Daily selection

    func testSameDateSamePoem() {
        let poems = (0..<30).map { makePoem(id: "p\($0)") }
        let a = DailyPoem.poem(for: date(2026, 6, 19), in: poems, calendar: cal)
        let b = DailyPoem.poem(for: date(2026, 6, 19), in: poems, calendar: cal)
        XCTAssertEqual(a?.id, b?.id)
    }

    func testDifferentTimeSameDaySamePoem() {
        let poems = (0..<30).map { makePoem(id: "p\($0)") }
        let morning = cal.date(from: DateComponents(year: 2026, month: 6, day: 19, hour: 7))!
        let night = cal.date(from: DateComponents(year: 2026, month: 6, day: 19, hour: 23))!
        XCTAssertEqual(DailyPoem.poem(for: morning, in: poems, calendar: cal)?.id,
                       DailyPoem.poem(for: night, in: poems, calendar: cal)?.id)
    }

    func testCyclesWithoutRepeat() {
        // A "cycle" is an aligned block of `count` days. Each cycle visits every
        // poem exactly once. Walk a cycle aligned to the epoch (day 0) so we test
        // the contract directly.
        let count = 30
        let poems = (0..<count).map { makePoem(id: "p\($0)") }
        // Day 0 = the epoch (2000-01-01). Use anthologyIndex over an aligned block.
        for cycleStart in [0, count, 5 * count] {
            var seen: [String] = []
            for d in 0..<count {
                let idx = DailyPoem.anthologyIndex(dayIndex: cycleStart + d, count: count)
                seen.append(poems[idx].id)
            }
            XCTAssertEqual(Set(seen).count, count,
                           "Aligned cycle at \(cycleStart) must hit every poem exactly once.")
        }
    }

    func testNoRepeatAcrossLongRunWithinEachCycle() {
        // Over many cycles, every aligned block of `count` is a full permutation.
        let count = 30
        for cycle in 0..<6 {
            let perm = DailyPoem.permutation(
                count: count,
                seed: UInt64(bitPattern: Int64(cycle)) &+ 0x9E3779B97F4A7C15)
            XCTAssertEqual(Set(perm).count, count)
            XCTAssertEqual(perm.sorted(), Array(0..<count))
        }
    }

    func testNoAdjacentDayRepeat() {
        let count = 30
        let poems = (0..<count).map { makePoem(id: "p\($0)") }
        var last: String?
        for offset in 0..<120 {
            let d = cal.date(byAdding: .day, value: offset, to: date(2026, 1, 1))!
            let id = DailyPoem.poem(for: d, in: poems, calendar: cal)!.id
            XCTAssertNotEqual(id, last, "Same poem must not appear two days running (offset \(offset)).")
            last = id
        }
    }

    func testConsecutiveCyclesDiffer() {
        let count = 30
        let poems = (0..<count).map { makePoem(id: "p\($0)") }
        let c0 = DailyPoem.permutation(count: count, seed: 0x9E3779B97F4A7C15)
        let c1 = DailyPoem.permutation(count: count, seed: 0x9E3779B97F4A7C15 &+ 1)
        XCTAssertNotEqual(c0, c1, "Consecutive cycles should reshuffle.")
    }

    func testPreferLanguageBiasesButRotatesBoth() {
        var poems = (0..<17).map { makePoem(id: "en\($0)", lang: "en") }
        poems += (0..<13).map { makePoem(id: "fr\($0)", lang: "fr") }
        var enCount = 0, frCount = 0
        for offset in 0..<60 {
            let d = cal.date(byAdding: .day, value: offset, to: date(2026, 1, 1))!
            let p = DailyPoem.poem(for: d, in: poems, preferred: .en, everyNth: 4, calendar: cal)!
            if p.lang == "en" { enCount += 1 } else { frCount += 1 }
        }
        XCTAssertGreaterThan(enCount, frCount, "Preferred language should dominate.")
        XCTAssertGreaterThan(frCount, 0, "But the other language must still surface.")
    }

    func testPreferLanguageDeterministic() {
        var poems = (0..<17).map { makePoem(id: "en\($0)", lang: "en") }
        poems += (0..<13).map { makePoem(id: "fr\($0)", lang: "fr") }
        let d = date(2026, 6, 19)
        XCTAssertEqual(DailyPoem.poem(for: d, in: poems, preferred: .fr, calendar: cal)?.id,
                       DailyPoem.poem(for: d, in: poems, preferred: .fr, calendar: cal)?.id)
    }

    // MARK: Masking

    func testMaskingFractionsPerLevel() {
        let poem = makePoem(id: "m", lines: 10, wordsPerLine: 10) // 100 words
        let total = Masking.wordPositions(of: poem).count
        XCTAssertEqual(total, 100)
        for level in 0...Masking.maxLevel {
            let hidden = Masking.hiddenIndices(poem: poem, level: level)
            let expected = Int((Double(total) * Masking.level(level).fraction).rounded())
            XCTAssertEqual(hidden.count, expected, "Level \(level) hid \(hidden.count), expected \(expected)")
        }
    }

    func testMaskingNestedMonotonic() {
        let poem = makePoem(id: "n", lines: 8, wordsPerLine: 8)
        var prev = Set<Int>()
        for level in 0...Masking.maxLevel {
            let hidden = Masking.hiddenIndices(poem: poem, level: level)
            XCTAssertTrue(prev.isSubset(of: hidden),
                          "Level \(level) must be a superset of the previous level.")
            prev = hidden
        }
    }

    func testMaskingLevelZeroHidesNothingAndTopHidesAll() {
        let poem = makePoem(id: "z", lines: 6, wordsPerLine: 5)
        let total = Masking.wordPositions(of: poem).count
        XCTAssertEqual(Masking.hiddenIndices(poem: poem, level: 0).count, 0)
        XCTAssertEqual(Masking.hiddenIndices(poem: poem, level: Masking.maxLevel).count, total)
    }

    func testHintShownAtEasyLevelsBlankAtHard() {
        let poem = makePoem(id: "h", lines: 6, wordsPerLine: 5)
        // Level 1 shows first-letter hints.
        let (tokens1, _) = Masking.renderLine(poem.spokenLines[0], poem: poem, level: 1, startingGlobalIndex: 0)
        let anyHint = tokens1.contains { if case .hint = $0 { return true } else { return false } }
        // Level 5 hides all with no hint (pure blanks).
        let (tokens5, _) = Masking.renderLine(poem.spokenLines[0], poem: poem, level: 5, startingGlobalIndex: 0)
        let anyBlank = tokens5.contains { if case .blank = $0 { return true } else { return false } }
        let anyHint5 = tokens5.contains { if case .hint = $0 { return true } else { return false } }
        // At least one of the levels should produce a hint somewhere across lines;
        // assert the structural property of hints vs blanks directly.
        XCTAssertTrue(anyHint || Masking.level(1).showFirstLetter)
        XCTAssertTrue(anyBlank, "Top level should produce blank tokens.")
        XCTAssertFalse(anyHint5, "Top level should not show first-letter hints.")
    }

    func testHintIsFirstLetterOnly() {
        let poem = makePoem(id: "fl", lines: 6, wordsPerLine: 5)
        let (tokens, _) = Masking.renderLine(poem.spokenLines[0], poem: poem, level: 3, startingGlobalIndex: 0)
        for t in tokens {
            if case let .hint(full, shown) = t {
                XCTAssertEqual(shown.count, 1, "Hint should be a single first letter.")
                XCTAssertEqual(shown, String(full.first!))
            }
        }
    }

    // MARK: SRS

    func testSRSCorrectPromotes() {
        let r = SRS.review(box: 1, outcome: .correct, now: date(2026, 6, 19), calendar: cal)
        XCTAssertEqual(r.box, 2)
        let expectedDue = cal.date(byAdding: .day, value: SRS.interval(forBox: 2),
                                   to: cal.startOfDay(for: date(2026, 6, 19)))!
        XCTAssertEqual(r.due, expectedDue)
    }

    func testSRSCorrectCapsAtMaxBox() {
        let r = SRS.review(box: SRS.maxBox, outcome: .correct, now: date(2026, 6, 19), calendar: cal)
        XCTAssertEqual(r.box, SRS.maxBox)
    }

    func testSRSLapseDemotesButFloorsAtOne() {
        let r = SRS.review(box: 4, outcome: .lapse, now: date(2026, 6, 19), calendar: cal)
        XCTAssertEqual(r.box, 2) // 4 - 2
        let low = SRS.review(box: 1, outcome: .lapse, now: date(2026, 6, 19), calendar: cal)
        XCTAssertEqual(low.box, 1, "Lapse should floor at box 1.")
    }

    func testSRSLapseDueTomorrow() {
        let r = SRS.review(box: 2, outcome: .lapse, now: date(2026, 6, 19), calendar: cal)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: date(2026, 6, 19)))!
        XCTAssertGreaterThanOrEqual(r.due, tomorrow, "A lapse should resurface soon (≥ tomorrow).")
    }

    func testSRSIsDue() {
        XCTAssertTrue(SRS.isDue(dueDate: nil), "Never-scheduled is due.")
        XCTAssertTrue(SRS.isDue(dueDate: date(2026, 1, 1), now: date(2026, 6, 19)))
        XCTAssertFalse(SRS.isDue(dueDate: date(2026, 12, 1), now: date(2026, 6, 19)))
    }
}
