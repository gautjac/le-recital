import Foundation
import SwiftData

/// SwiftData model for a poem's memorization state: the Leitner box (review
/// scheduling), the highest masking level cleared, favorite flag, and review
/// bookkeeping. One row per poem the user has engaged with.
@Model
public final class PoemProgress {
    /// Matches `Poem.id`. Unique per poem.
    @Attribute(.unique) public var poemID: String

    /// Leitner box, 0…5. Higher = longer interval before resurfacing.
    public var box: Int
    /// Highest masking level the learner has cleared (0…Masking.maxLevel).
    public var masteryLevel: Int
    /// True once the learner has reached the top "Par cœur" level.
    public var learnedByHeart: Bool
    public var isFavorite: Bool

    /// Last time this poem was reviewed.
    public var lastReviewed: Date?
    /// When the SRS wants it surfaced next.
    public var dueDate: Date?
    /// Total successful reviews (for the mastery ring fill + streaks).
    public var reviewCount: Int
    public var createdAt: Date

    public init(poemID: String) {
        self.poemID = poemID
        self.box = 0
        self.masteryLevel = 0
        self.learnedByHeart = false
        self.isFavorite = false
        self.lastReviewed = nil
        self.dueDate = nil
        self.reviewCount = 0
        self.createdAt = Date()
    }

    /// Mastery as a 0…1 fraction (for the progress ring).
    public var masteryFraction: Double {
        Double(masteryLevel) / Double(max(1, Masking.maxLevel))
    }
}

/// SwiftData model for a saved recitation recording. The audio file itself lives
/// in the app's Documents directory; this row holds the metadata + filename.
@Model
public final class Recording {
    @Attribute(.unique) public var id: UUID
    public var poemID: String
    /// File name (relative to Documents/recordings/).
    public var fileName: String
    public var createdAt: Date
    public var duration: Double   // seconds

    public init(poemID: String, fileName: String, duration: Double) {
        self.id = UUID()
        self.poemID = poemID
        self.fileName = fileName
        self.createdAt = Date()
        self.duration = duration
    }
}
