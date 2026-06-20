import Foundation
import SwiftData

/// Seeds deterministic mastery/favorite state for the screenshot harness, so the
/// "appris par cœur" shelf, mastery rings, and review queue look like a real
/// learner's. Only runs under the `-recitalDemo 1` launch flag, and only once.
///
/// Crucially this NEVER writes any verse — it only sets progress metadata keyed
/// by poem id (slugs), letting the bundled anthology supply the text.
@MainActor
public enum DemoSeed {
    public static func seedIfNeeded(_ context: ModelContext, anthology: Anthology) {
        guard LaunchFlags.demo else { return }
        // Idempotent: bail if anything already exists.
        let existing = (try? context.fetch(FetchDescriptor<PoemProgress>())) ?? []
        guard existing.isEmpty else { return }

        let poems = anthology.poems
        guard poems.count >= 8 else { return }

        let now = Date()
        let cal = Calendar.current

        // A few learned-by-heart (full mastery), a few mid-progress, some favorites.
        // Use stable indices so screenshots are reproducible.
        func seed(_ idx: Int, level: Int, box: Int, reviews: Int, dueOffset: Int, fav: Bool) {
            guard idx < poems.count else { return }
            let p = PoemProgress(poemID: poems[idx].id)
            p.masteryLevel = level
            p.learnedByHeart = level >= Masking.maxLevel
            p.box = box
            p.reviewCount = reviews
            p.isFavorite = fav
            p.lastReviewed = cal.date(byAdding: .day, value: -max(1, reviews), to: now)
            p.dueDate = cal.date(byAdding: .day, value: dueOffset, to: cal.startOfDay(for: now))
            context.insert(p)
        }

        seed(0, level: Masking.maxLevel, box: 4, reviews: 9, dueOffset: 2, fav: true)
        seed(2, level: Masking.maxLevel, box: 3, reviews: 6, dueOffset: -1, fav: false)
        seed(5, level: Masking.maxLevel, box: 5, reviews: 12, dueOffset: 5, fav: true)
        seed(7, level: 3, box: 2, reviews: 3, dueOffset: 0, fav: false)
        seed(9, level: 2, box: 1, reviews: 1, dueOffset: -2, fav: true)
        seed(11, level: 1, box: 1, reviews: 1, dueOffset: 0, fav: false)

        try? context.save()
    }
}
