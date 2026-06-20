import SwiftUI

/// "Bibliothèque / Library" — browse the whole anthology by poet, era, or
/// language, filter to favorites, and search by title / author / first line.
public struct LibraryView: View {
    @EnvironmentObject private var loc: LocManager
    @Environment(\.palette) private var pal
    @ObservedObject var library: Library

    enum Grouping: String, CaseIterable { case poet, era, language, favorites }
    @State private var grouping: Grouping = .poet
    @State private var query = ""

    public init(library: Library) { self.library = library }

    public var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections, id: \.title) { section in
                        Section {
                            ForEach(section.poems) { poem in
                                NavigationLink {
                                    PoemDetailView(library: library, poem: poem)
                                } label: {
                                    PoemRow(poem: poem,
                                            progress: library.progress(for: poem.id, createIfMissing: false),
                                            favorite: library.isFavorite(poem.id))
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            sectionHeader(section.title)
                        }
                    }
                    if sections.isEmpty {
                        Text(loc.t("Rien ne correspond.", "Nothing matches."))
                            .font(.system(size: 15, design: .serif)).foregroundStyle(pal.inkFaint)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
        }
        .navigationTitle(loc.t("Bibliothèque", "Library"))
        .searchable(text: $query, prompt: loc.t("Titre, poète, premier vers", "Title, poet, first line"))
        .toolbar {
            LangToggleToolbar()
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("", selection: $grouping) {
                        Text(loc.t("Par poète", "By poet")).tag(Grouping.poet)
                        Text(loc.t("Par époque", "By era")).tag(Grouping.era)
                        Text(loc.t("Par langue", "By language")).tag(Grouping.language)
                        Text(loc.t("Favoris", "Favorites")).tag(Grouping.favorites)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.display(15)).foregroundStyle(pal.ribbon)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6).padding(.horizontal, 4)
            .background(pal.paper.opacity(0.96))
    }

    // MARK: Sections

    private struct PoemSection { let title: String; let poems: [Poem] }

    private var filtered: [Poem] {
        let base: [Poem]
        if grouping == .favorites {
            base = library.favorites()
        } else {
            base = library.poems
        }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { p in
            p.title.lowercased().contains(q)
            || p.author.lowercased().contains(q)
            || (p.spokenLines.first?.lowercased().contains(q) ?? false)
        }
    }

    private var sections: [PoemSection] {
        let poems = filtered
        switch grouping {
        case .favorites:
            return poems.isEmpty ? [] : [PoemSection(title: loc.t("Favoris", "Favorites"),
                                                     poems: poems.sorted { $0.title < $1.title })]
        case .poet:
            let groups = Dictionary(grouping: poems, by: \.author)
            return groups.keys.sorted().map { PoemSection(title: $0, poems: groups[$0]!.sorted { $0.year < $1.year }) }
        case .language:
            let fr = poems.filter { $0.poemLang == .fr }.sorted { $0.author < $1.author }
            let en = poems.filter { $0.poemLang == .en }.sorted { $0.author < $1.author }
            var out: [PoemSection] = []
            if !fr.isEmpty { out.append(PoemSection(title: loc.t("Français", "French"), poems: fr)) }
            if !en.isEmpty { out.append(PoemSection(title: loc.t("Anglais", "English"), poems: en)) }
            return out
        case .era:
            func era(_ y: String) -> Int { (Int(y.prefix(4)) ?? 0) / 100 * 100 }
            let groups = Dictionary(grouping: poems, by: { era($0.year) })
            return groups.keys.sorted().map { century in
                let label = century == 0 ? loc.t("Sans date", "Undated") : "\(century)s"
                return PoemSection(title: label, poems: groups[century]!.sorted { $0.year < $1.year })
            }
        }
    }
}

/// A compact poem row with title, author, era tags, mastery ring, favorite star.
struct PoemRow: View {
    @Environment(\.palette) private var pal
    let poem: Poem
    let progress: PoemProgress?
    let favorite: Bool

    var body: some View {
        PageCard(padding: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(poem.title).font(.display(16)).foregroundStyle(pal.ink)
                            .lineLimit(1)
                        if favorite {
                            Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(pal.gild)
                        }
                    }
                    Text("\(poem.author) · \(poem.year)")
                        .font(.system(size: 13, design: .serif)).foregroundStyle(pal.inkSoft)
                        .lineLimit(1)
                    Tag(poem.poemLang.label)
                }
                Spacer()
                if let progress, progress.masteryLevel > 0 {
                    MasteryRing(fraction: progress.masteryFraction, learned: progress.learnedByHeart, size: 34)
                }
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(pal.inkFaint)
            }
        }
    }
}
