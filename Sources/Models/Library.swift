import Foundation
import SwiftData
import Combine

/// Runtime facade over the anthology + SwiftData mastery/recording graph.
///
/// Holds the decoded `Anthology` (loaded once from the bundle) and provides the
/// read/write operations the views need: fetching or creating a poem's progress,
/// toggling favourites, applying an SRS review, and listing the learned-by-heart
/// shelf and the review queue. SwiftData mutations go through the injected
/// `ModelContext`.
@MainActor
public final class Library: ObservableObject {
    public let anthology: Anthology
    public let context: ModelContext

    public init(anthology: Anthology, context: ModelContext) {
        self.anthology = anthology
        self.context = context
    }

    public var poems: [Poem] { anthology.poems }

    public func poem(id: String) -> Poem? { anthology.poem(id: id) }

    // MARK: Progress

    /// The progress row for a poem, creating one lazily if it doesn't exist yet.
    public func progress(for poemID: String, createIfMissing: Bool = true) -> PoemProgress? {
        let descriptor = FetchDescriptor<PoemProgress>(
            predicate: #Predicate { $0.poemID == poemID }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        guard createIfMissing else { return nil }
        let p = PoemProgress(poemID: poemID)
        context.insert(p)
        try? context.save()
        return p
    }

    public func isFavorite(_ poemID: String) -> Bool {
        progress(for: poemID, createIfMissing: false)?.isFavorite ?? false
    }

    public func toggleFavorite(_ poemID: String) {
        guard let p = progress(for: poemID) else { return }
        p.isFavorite.toggle()
        try? context.save()
        objectWillChange.send()
    }

    /// Record that the learner cleared a masking level (monotonic high-water).
    public func recordLevelCleared(_ poemID: String, level: Int) {
        guard let p = progress(for: poemID) else { return }
        if level > p.masteryLevel { p.masteryLevel = level }
        if level >= Masking.maxLevel { p.learnedByHeart = true }
        try? context.save()
        objectWillChange.send()
    }

    /// Apply an SRS review outcome, updating box / due date / counts.
    public func review(_ poemID: String, outcome: SRS.Outcome, now: Date = Date()) {
        guard let p = progress(for: poemID) else { return }
        let result = SRS.review(box: p.box, outcome: outcome, now: now)
        p.box = result.box
        p.dueDate = result.due
        p.lastReviewed = now
        if outcome == .correct { p.reviewCount += 1 }
        try? context.save()
        objectWillChange.send()
    }

    // MARK: Shelves & queues

    /// Poems the learner has taken all the way to "par cœur", most recent first.
    public func learnedByHeart() -> [(poem: Poem, progress: PoemProgress)] {
        let descriptor = FetchDescriptor<PoemProgress>(
            predicate: #Predicate { $0.learnedByHeart == true }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows
            .compactMap { row in poem(id: row.poemID).map { ($0, row) } }
            .sorted { ($0.progress.lastReviewed ?? .distantPast) > ($1.progress.lastReviewed ?? .distantPast) }
    }

    /// Poems currently due for review (have progress, are due now), most overdue
    /// first. Only poems the learner has actually engaged with appear here.
    public func dueForReview(now: Date = Date()) -> [(poem: Poem, progress: PoemProgress)] {
        let descriptor = FetchDescriptor<PoemProgress>()
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows
            .filter { $0.reviewCount > 0 || $0.masteryLevel > 0 }
            .filter { SRS.isDue(dueDate: $0.dueDate, now: now) }
            .compactMap { row in poem(id: row.poemID).map { ($0, row) } }
            .sorted { SRS.reviewSortKey(dueDate: $0.progress.dueDate, now: now)
                    < SRS.reviewSortKey(dueDate: $1.progress.dueDate, now: now) }
    }

    public func favorites() -> [Poem] {
        let descriptor = FetchDescriptor<PoemProgress>(
            predicate: #Predicate { $0.isFavorite == true }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        let ids = Set(rows.map(\.poemID))
        return poems.filter { ids.contains($0.id) }
    }

    // MARK: Recordings

    public func recordings(for poemID: String) -> [Recording] {
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { $0.poemID == poemID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func addRecording(poemID: String, fileName: String, duration: Double) {
        let r = Recording(poemID: poemID, fileName: fileName, duration: duration)
        context.insert(r)
        try? context.save()
        objectWillChange.send()
    }

    public func deleteRecording(_ recording: Recording) {
        let url = RecordingStore.url(for: recording.fileName)
        try? FileManager.default.removeItem(at: url)
        context.delete(recording)
        try? context.save()
        objectWillChange.send()
    }
}

/// Filesystem home for recitation audio: `Documents/recordings/`.
public enum RecordingStore {
    public static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    public static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }
    public static func newFileName(poemID: String) -> String {
        "\(poemID)-\(Int(Date().timeIntervalSince1970)).m4a"
    }
}
