import Foundation

/// A Leitner spaced-repetition scheduler for memorized poems.
///
/// Pure value logic (no SwiftData) so it is exhaustively testable. Boxes 0…5 map
/// to growing review intervals; a *correct* recall promotes the poem one box (and
/// pushes the next due date out), a *lapse* demotes it back toward box 1.
public enum SRS {

    /// Review interval in DAYS for each Leitner box. Box 0 = brand new (due now).
    /// Classic Leitner-ish doubling: 1, 2, 4, 8, 16, 32 days.
    public static let intervalsDays: [Int] = [0, 1, 2, 4, 8, 16, 32]

    public static var maxBox: Int { intervalsDays.count - 1 }

    /// Interval (days) for a box, clamped.
    public static func interval(forBox box: Int) -> Int {
        let b = min(max(box, 0), maxBox)
        return intervalsDays[b]
    }

    /// The result of a single review session.
    public enum Outcome { case correct, lapse }

    /// Apply a review outcome, returning the new box and the next due date.
    /// - correct: promote one box (cap at maxBox), schedule by the new interval.
    /// - lapse:   demote to box 1 (not all the way to 0 — keep it surfacing
    ///            soon but don't reset its history), schedule for tomorrow.
    public static func review(box: Int, outcome: Outcome, now: Date = Date(),
                              calendar: Calendar = .current) -> (box: Int, due: Date) {
        let newBox: Int
        switch outcome {
        case .correct: newBox = min(box + 1, maxBox)
        case .lapse:   newBox = max(1, min(box, maxBox) - 2)  // step back, floor at 1
        }
        let days = interval(forBox: newBox)
        let base = calendar.startOfDay(for: now)
        let due = calendar.date(byAdding: .day, value: max(days, outcome == .lapse ? 1 : 0), to: base) ?? now
        return (newBox, due)
    }

    /// Is a poem due for review at `now`? A nil dueDate means "never scheduled"
    /// → due (the user has touched it but not set a cadence yet).
    public static func isDue(dueDate: Date?, now: Date = Date()) -> Bool {
        guard let dueDate else { return true }
        return dueDate <= now
    }

    /// Sort key for a review queue: due poems first (most overdue first), then by
    /// soonest upcoming. Used to order the "à réviser" list.
    public static func reviewSortKey(dueDate: Date?, now: Date = Date()) -> Double {
        guard let dueDate else { return -Double.greatestFiniteMagnitude } // never-scheduled = most urgent
        return dueDate.timeIntervalSince(now)
    }
}
