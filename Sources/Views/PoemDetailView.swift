import SwiftUI

/// A poem's page in the library: the full verse, craft note, source, and entries
/// into memorizing and reciting. (The daily card has its own slow reveal; here
/// the poem is simply present, like opening to a page.)
public struct PoemDetailView: View {
    @EnvironmentObject private var loc: LocManager
    @Environment(\.palette) private var pal
    @ObservedObject var library: Library
    let poem: Poem

    public init(library: Library, poem: Poem) {
        self.library = library
        self.poem = poem
    }

    public var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(poem.title).font(.display(26)).foregroundStyle(pal.ink)
                            .multilineTextAlignment(.center)
                        Text(poem.author).font(.verse(17)).italic().foregroundStyle(pal.inkSoft)
                        HStack(spacing: 8) {
                            Tag(poem.authorYears); Tag(poem.year, filled: true); Tag(poem.poemLang.label)
                        }
                    }
                    ChapbookRule()
                    if LaunchFlags.craftFirst {
                        craftCard
                        verseCard
                    } else {
                        verseCard
                        craftCard
                    }

                    VStack(spacing: 12) {
                        NavigationLink {
                            MemorizeView(library: library, poem: poem)
                        } label: { actionRow("brain.head.profile", loc.t("Apprendre par cœur", "Learn by heart")) }
                        NavigationLink {
                            ReciteView(library: library, poem: poem)
                        } label: { actionRow("mic", loc.t("Réciter & s'enregistrer", "Recite & record")) }
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20).padding(.top, 12)
            }
        }
        .navigationTitle(poem.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            LangToggleToolbar()
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    library.toggleFavorite(poem.id)
                } label: {
                    Image(systemName: library.isFavorite(poem.id) ? "star.fill" : "star")
                        .foregroundStyle(pal.gild)
                }
            }
        }
    }

    private var verseCard: some View {
        PageCard { VerseView(poem: poem, fontSize: 21) }
    }

    private var craftCard: some View {
        PageCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "quote.opening").foregroundStyle(pal.gild)
                    Text(loc.t("Pourquoi ce poème tient", "Why this poem holds"))
                        .font(.display(17)).foregroundStyle(pal.ink)
                }
                Text(poem.craft(loc.lang))
                    .font(.system(size: 16, design: .serif)).foregroundStyle(pal.inkSoft)
                    .lineSpacing(4)
                ChapbookRule(ornament: "·")
                Text(poem.source).font(.system(size: 12, design: .serif)).italic()
                    .foregroundStyle(pal.inkFaint)
                DeepenButton(poem: poem)
            }
        }
    }

    private func actionRow(_ icon: String, _ title: String) -> some View {
        PageCard(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(pal.ribbon).frame(width: 30)
                Text(title).font(.display(16)).foregroundStyle(pal.ink)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(pal.inkFaint)
            }
        }
    }
}
