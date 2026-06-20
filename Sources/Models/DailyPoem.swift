import Foundation

/// Deterministic "poem of the day" selection.
///
/// Requirements: the SAME calendar day always maps to the SAME poem, and the
/// sequence cycles through the WHOLE anthology with NO repeats before the set is
/// exhausted, then begins a fresh (re-shuffled) cycle.
///
/// Strategy: compute a stable day-index (days since a fixed epoch). Split the
/// timeline into "cycles" of `count` days. Within each cycle we walk a
/// deterministic permutation of `0..<count` seeded by the cycle number, so every
/// poem appears exactly once per cycle and consecutive cycles differ.
public enum DailyPoem {

    /// A fixed reference day (2000-01-01, UTC) — the epoch for day indexing.
    /// Using a fixed epoch keeps selection stable across devices and time zones
    /// when paired with a caller-supplied calendar.
    static let epoch: DateComponents = DateComponents(year: 2000, month: 1, day: 1)

    /// Whole days from the epoch to `date` in the given calendar (local midnight
    /// to local midnight). Can be negative for dates before the epoch.
    public static func dayIndex(for date: Date, calendar: Calendar = .current) -> Int {
        var cal = calendar
        // Normalize to the calendar's own time zone start-of-day for stability.
        let epochDate = cal.date(from: epoch) ?? Date(timeIntervalSince1970: 946_684_800)
        let startToday = cal.startOfDay(for: date)
        let startEpoch = cal.startOfDay(for: epochDate)
        let comps = cal.dateComponents([.day], from: startEpoch, to: startToday)
        return comps.day ?? 0
    }

    /// The index into the anthology for a given day index, over `count` poems.
    /// Returns a value in `0..<count`. Each aligned cycle is a full permutation
    /// (every poem exactly once); a boundary fix-up also guarantees the first day
    /// of a cycle never repeats the last day of the previous cycle, so the user
    /// never sees the same poem two days running.
    public static func anthologyIndex(dayIndex: Int, count: Int) -> Int {
        precondition(count > 0, "anthology must be non-empty")
        // Floor-division/modulo that work for negative day indices too.
        let cycle = Int(floor(Double(dayIndex) / Double(count)))
        var pos = dayIndex % count
        if pos < 0 { pos += count }
        let perm = cyclePermutation(cycle: cycle, count: count)
        return perm[pos]
    }

    /// The permutation for a cycle, adjusted so its first element differs from the
    /// previous cycle's last element (avoids an across-boundary repeat). Needs at
    /// least 2 poems for the fix-up to be meaningful.
    static func cyclePermutation(cycle: Int, count: Int) -> [Int] {
        var perm = permutation(count: count,
                               seed: UInt64(bitPattern: Int64(cycle)) &+ 0x9E3779B97F4A7C15)
        guard count >= 2 else { return perm }
        let prev = permutation(count: count,
                               seed: UInt64(bitPattern: Int64(cycle - 1)) &+ 0x9E3779B97F4A7C15)
        if perm.first == prev.last {
            perm.swapAt(0, 1) // both are still full permutations after a swap
        }
        return perm
    }

    /// The poem chosen for `date` from `poems`.
    public static func poem(for date: Date, in poems: [Poem], calendar: Calendar = .current) -> Poem? {
        guard !poems.isEmpty else { return nil }
        let di = dayIndex(for: date, calendar: calendar)
        let idx = anthologyIndex(dayIndex: di, count: poems.count)
        return poems[idx]
    }

    /// The poem chosen for `date`, honouring a "prefer my language" setting.
    ///
    /// When `preferred` is nil, this is identical to the plain selection over the
    /// whole anthology (still rotating through BOTH languages without repeat).
    /// When a `preferred` language is set, the daily pick is biased toward that
    /// language: most days draw from the preferred-language sub-anthology (each of
    /// which still cycles without repeat), while a deterministic minority of days
    /// surface the other language so the learner is never wholly cut off from it.
    ///
    /// The bias is `everyNth`: 1-in-`everyNth` days draws from the *other*
    /// language. The selection stays fully deterministic per (date, preference).
    public static func poem(for date: Date, in poems: [Poem], preferred: Lang?,
                            everyNth: Int = 4, calendar: Calendar = .current) -> Poem? {
        guard !poems.isEmpty else { return nil }
        guard let preferred else {
            return poem(for: date, in: poems, calendar: calendar)
        }
        let primary = poems.filter { $0.poemLang == preferred }
        let secondary = poems.filter { $0.poemLang != preferred }
        // Degenerate corpora (only one language present) fall back to the whole set.
        guard !primary.isEmpty, !secondary.isEmpty else {
            return poem(for: date, in: poems, calendar: calendar)
        }
        let di = dayIndex(for: date, calendar: calendar)
        let step = max(2, everyNth)
        // Deterministic "is this an other-language day?" — every `step`-th day.
        let isOtherDay = (((di % step) + step) % step) == (step - 1)
        if isOtherDay {
            // Count of other-language days strictly before `di` indexes the
            // secondary cycle, so the secondary set rotates without repeat too.
            let otherOrdinal = Int(floor(Double(di + 1) / Double(step)))
            let idx = anthologyIndex(dayIndex: otherOrdinal, count: secondary.count)
            return secondary[idx]
        } else {
            let primaryOrdinal = di - Int(floor(Double(di + 1) / Double(step)))
            let idx = anthologyIndex(dayIndex: primaryOrdinal, count: primary.count)
            return primary[idx]
        }
    }

    /// A deterministic permutation of `0..<count` from a seed (Fisher–Yates with
    /// a SplitMix64 PRNG — stable across platforms, unlike `shuffled()`).
    public static func permutation(count: Int, seed: UInt64) -> [Int] {
        var arr = Array(0..<count)
        var state = seed
        // Fisher–Yates from the end.
        var i = count - 1
        while i > 0 {
            let j = Int(nextRandom(&state) % UInt64(i + 1))
            arr.swapAt(i, j)
            i -= 1
        }
        return arr
    }

    /// SplitMix64 — a tiny, well-distributed deterministic PRNG.
    static func nextRandom(_ state: inout UInt64) -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
