import Foundation

/// A single poem in the curated, public-domain anthology.
///
/// Decoded EXACTLY from the bundled `Poems.json` (schema version 1). The poem
/// text is always carried in its ORIGINAL language (`lang`); the *craft note* —
/// the "why it works" — is authored in both FR and EN (`craftNote.fr/.en`) and
/// follows the UI toggle.
///
/// COPYRIGHT: every record in the bundle is a work in the public domain. The
/// `source` field attributes the text (PoetryDB for English, Wikisource for
/// French).
public struct Poem: Identifiable, Codable, Equatable, Hashable, Sendable {

    /// The bilingual craft note nested in each record.
    public struct CraftNote: Codable, Equatable, Hashable, Sendable {
        public let fr: String
        public let en: String
    }

    /// Stable slug, e.g. "baudelaire-recueillement". Used as the SwiftData key
    /// linking mastery state and recordings to a poem.
    public let id: String
    public let title: String
    public let author: String
    /// Author life span, e.g. "1821–1867".
    public let authorYears: String
    /// Year (or era) of composition / publication, e.g. "1857".
    public let year: String
    /// The poem's own language: "fr" or "en".
    public let lang: String
    /// The verse, one entry per line. Empty strings mark stanza breaks.
    public let lines: [String]
    /// Number of non-empty (spoken) lines, per the dataset.
    public let lineCount: Int
    /// Attribution / sourcing note (public-domain provenance).
    public let source: String
    /// Craft note — "why it works" — in FR and EN.
    public let craftNote: CraftNote

    public var isFrench: Bool { lang == "fr" }

    /// The line language as a `Lang` (for display niceties).
    public var poemLang: Lang { lang == "en" ? .en : .fr }

    /// Lines grouped into stanzas (split on the empty-string markers).
    public var stanzas: [[String]] {
        var out: [[String]] = []
        var current: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty { out.append(current); current = [] }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    /// Non-blank lines only (the spoken / recitable body).
    public var spokenLines: [String] {
        lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Total word count across all spoken lines.
    public var wordCount: Int {
        spokenLines.reduce(0) { $0 + Poem.words(in: $1).count }
    }

    /// The craft note in the requested UI language.
    public func craft(_ lang: Lang) -> String { lang == .fr ? craftNote.fr : craftNote.en }

    /// Tokenize a line into words (for masking & counts). A "word" is a maximal
    /// run of letters / numbers / apostrophes / hyphens; punctuation and spaces
    /// delimit. Returns the words in reading order.
    public static func words(in line: String) -> [String] {
        var words: [String] = []
        var current = ""
        for ch in line {
            if ch.isLetter || ch.isNumber || ch == "'" || ch == "\u{2019}" || ch == "-" {
                current.append(ch)
            } else {
                if !current.isEmpty { words.append(current); current = "" }
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }
}

/// The top-level shape of `Poems.json`: `{ "version": 1, "poems": [...] }`.
private struct PoemFile: Codable {
    let version: Int
    let poems: [Poem]
}

/// The decoded anthology + helpers. The single source of truth at runtime.
public struct Anthology: Sendable {
    public let poems: [Poem]

    public init(poems: [Poem]) { self.poems = poems }

    /// Load the bundled `Poems.json`. Returns an empty anthology (and asserts in
    /// DEBUG) on failure — a dataset error must be caught by the integrity tests,
    /// never shipped.
    public static func loadBundled(_ bundle: Bundle = .main) -> Anthology {
        guard let url = bundle.url(forResource: "Poems", withExtension: "json") else {
            assertionFailure("Poems.json missing from bundle")
            return Anthology(poems: [])
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(PoemFile.self, from: data)
            return Anthology(poems: file.poems)
        } catch {
            assertionFailure("Poems.json failed to decode: \(error)")
            return Anthology(poems: [])
        }
    }

    public func poem(id: String) -> Poem? { poems.first { $0.id == id } }

    /// All distinct authors, alphabetically.
    public var authors: [String] {
        Array(Set(poems.map(\.author))).sorted()
    }

    /// Poems whose original language matches `lang`.
    public func poems(in lang: Lang) -> [Poem] {
        poems.filter { $0.poemLang == lang }
    }
}
