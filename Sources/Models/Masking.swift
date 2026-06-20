import Foundation

/// Progressive word-masking for "apprendre par cœur" (learn by heart).
///
/// A poem is masked at one of several LEVELS. Level 0 shows everything. Each
/// higher level hides a larger fraction of the words; at the top level the whole
/// poem is blank. Hidden words show a first-letter HINT at the easy levels and
/// become a bare blank at the hard levels. The choice of *which* words to hide
/// is deterministic per (poem, level) so a learner sees a stable challenge, and
/// each level's hidden set is a SUPERSET of the easier level's — the poem only
/// disappears, it never re-appears, as you climb.
public enum Masking {

    /// The masking levels, easiest → hardest. `fraction` = share of words hidden,
    /// `showFirstLetter` = whether a hidden word reveals its initial as a hint.
    public struct Level: Equatable, Sendable {
        public let index: Int
        public let fraction: Double
        public let showFirstLetter: Bool
        public let titleFR: String
        public let titleEN: String
    }

    public static let levels: [Level] = [
        Level(index: 0, fraction: 0.00, showFirstLetter: true,  titleFR: "Lecture",        titleEN: "Reading"),
        Level(index: 1, fraction: 0.15, showFirstLetter: true,  titleFR: "Premiers vides", titleEN: "First gaps"),
        Level(index: 2, fraction: 0.35, showFirstLetter: true,  titleFR: "À demi-mot",     titleEN: "Half-hidden"),
        Level(index: 3, fraction: 0.55, showFirstLetter: true,  titleFR: "De mémoire",     titleEN: "From memory"),
        Level(index: 4, fraction: 0.80, showFirstLetter: false, titleFR: "Presque tout",   titleEN: "Almost all"),
        Level(index: 5, fraction: 1.00, showFirstLetter: false, titleFR: "Par cœur",       titleEN: "By heart"),
    ]

    public static var maxLevel: Int { levels.count - 1 }

    public static func level(_ index: Int) -> Level {
        let clamped = min(max(index, 0), maxLevel)
        return levels[clamped]
    }

    /// A flattened, ordered list of every word position in the poem, as
    /// (lineIndex, wordIndexWithinLine). Blank/stanza lines contribute nothing.
    public static func wordPositions(of poem: Poem) -> [(line: Int, word: Int)] {
        var positions: [(Int, Int)] = []
        for (li, line) in poem.lines.enumerated() {
            let words = Poem.words(in: line)
            for wi in words.indices { positions.append((li, wi)) }
        }
        return positions
    }

    /// The SET of hidden global word-indices for a poem at a given level.
    /// Deterministic per (poem.id, totalWords). Nested so harder levels strictly
    /// contain easier ones: we rank every word once by a stable hash, then hide
    /// the top `fraction` of that ranking.
    public static func hiddenIndices(poem: Poem, level: Int) -> Set<Int> {
        let lvl = self.level(level)
        let positions = wordPositions(of: poem)
        let total = positions.count
        guard total > 0, lvl.fraction > 0 else { return [] }

        let hideCount = Int((Double(total) * lvl.fraction).rounded())
        guard hideCount > 0 else { return [] }
        if hideCount >= total { return Set(0..<total) }

        // Stable ranking: each word index gets a deterministic priority from a
        // hash of (poem.id, globalIndex). Lowest priorities are hidden first, so
        // the hidden set grows monotonically with the count.
        let ranked = (0..<total).sorted { a, b in
            priority(poemID: poem.id, index: a) < priority(poemID: poem.id, index: b)
        }
        return Set(ranked.prefix(hideCount))
    }

    /// Deterministic per-word priority used for the nested hide-ranking.
    static func priority(poemID: String, index: Int) -> UInt64 {
        var h: UInt64 = 1469598103934665603 // FNV-1a offset
        for b in poemID.utf8 {
            h ^= UInt64(b)
            h = h &* 1099511628211
        }
        h ^= UInt64(bitPattern: Int64(index))
        h = h &* 1099511628211
        // One SplitMix64 finalize for good dispersion.
        var z = h
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// How a single rendered token should appear.
    public enum Token: Equatable, Sendable {
        case visible(String)         // shown verbatim (a word or punctuation)
        case hint(full: String, shown: String)  // hidden, first-letter hint
        case blank(full: String, length: Int)   // fully hidden, length only
    }

    /// Render a whole line into display tokens at a level, given the running
    /// global word index BEFORE this line. Returns the tokens and the updated
    /// running index. Punctuation/spaces between words are emitted as `.visible`.
    public static func renderLine(_ line: String, poem: Poem, level: Int,
                                  startingGlobalIndex: Int) -> (tokens: [Token], nextGlobalIndex: Int) {
        let hidden = hiddenIndices(poem: poem, level: level)
        let lvl = self.level(level)
        var tokens: [Token] = []
        var gIndex = startingGlobalIndex

        var buffer = ""              // pending punctuation/space run
        var word = ""                // pending word run
        func flushPunct() {
            if !buffer.isEmpty { tokens.append(.visible(buffer)); buffer = "" }
        }
        func flushWord() {
            guard !word.isEmpty else { return }
            if hidden.contains(gIndex) {
                if lvl.showFirstLetter, let first = word.first {
                    tokens.append(.hint(full: word, shown: String(first)))
                } else {
                    tokens.append(.blank(full: word, length: word.count))
                }
            } else {
                tokens.append(.visible(word))
            }
            gIndex += 1
            word = ""
        }

        for ch in line {
            if ch.isLetter || ch.isNumber || ch == "'" || ch == "\u{2019}" || ch == "-" {
                if !buffer.isEmpty { flushPunct() }
                word.append(ch)
            } else {
                if !word.isEmpty { flushWord() }
                buffer.append(ch)
            }
        }
        flushWord()
        flushPunct()
        return (tokens, gIndex)
    }
}
