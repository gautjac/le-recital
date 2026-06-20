import SwiftUI

/// "Par cœur / By Heart" — the learned-by-heart shelf with mastery rings, plus a
/// review queue surfacing poems the SRS wants resurfaced.
public struct ShelfView: View {
    @EnvironmentObject private var loc: LocManager
    @Environment(\.palette) private var pal
    @ObservedObject var library: Library

    public init(library: Library) { self.library = library }

    private var now: Date { LaunchFlags.pinnedDate ?? Date() }

    public var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    let due = library.dueForReview(now: now)
                    if !due.isEmpty {
                        sectionTitle(loc.t("À réviser", "To review"),
                                     subtitle: loc.t("Pour qu'ils restent", "So they stay"))
                        ForEach(due, id: \.poem.id) { item in
                            ReviewRow(library: library, poem: item.poem, progress: item.progress, now: now)
                        }
                    }

                    let shelf = library.learnedByHeart()
                    sectionTitle(loc.t("Appris par cœur", "Learned by heart"),
                                 subtitle: loc.t("\(shelf.count) poème·s", "\(shelf.count) poem(s)"))
                    if shelf.isEmpty {
                        emptyShelf
                    } else {
                        ForEach(shelf, id: \.poem.id) { item in
                            NavigationLink {
                                PoemDetailView(library: library, poem: item.poem)
                            } label: {
                                ShelfRow(poem: item.poem, progress: item.progress)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20).padding(.top, 12)
            }
        }
        .navigationTitle(loc.t("Par cœur", "By Heart"))
        .toolbar { LangToggleToolbar() }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.display(20)).foregroundStyle(pal.ink)
            Text(subtitle).font(.system(size: 13, design: .serif)).foregroundStyle(pal.inkFaint)
            ChapbookRule()
        }
    }

    private var emptyShelf: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical").font(.system(size: 40)).foregroundStyle(pal.rule)
            Text(loc.t("Votre étagère est vide — pour l'instant.",
                       "Your shelf is empty — for now."))
                .font(.system(size: 15, design: .serif)).foregroundStyle(pal.inkSoft)
            Text(loc.t("Apprenez un poème par cœur depuis « Aujourd'hui ».",
                       "Learn a poem by heart from “Today”."))
                .font(.system(size: 13, design: .serif)).foregroundStyle(pal.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }
}

private struct ShelfRow: View {
    @EnvironmentObject private var loc: LocManager
    @Environment(\.palette) private var pal
    let poem: Poem
    let progress: PoemProgress

    var body: some View {
        PageCard(padding: 14) {
            HStack(spacing: 14) {
                MasteryRing(fraction: progress.masteryFraction, learned: progress.learnedByHeart, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(poem.title).font(.display(16)).foregroundStyle(pal.ink).lineLimit(1)
                    Text(poem.author).font(.system(size: 13, design: .serif)).foregroundStyle(pal.inkSoft)
                    Text(loc.t("\(progress.reviewCount) révision·s", "\(progress.reviewCount) review(s)"))
                        .font(.system(size: 11, design: .serif)).foregroundStyle(pal.inkFaint)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(pal.inkFaint)
            }
        }
    }
}

/// A due-for-review row with quick "got it / missed it" buttons.
private struct ReviewRow: View {
    @EnvironmentObject private var loc: LocManager
    @Environment(\.palette) private var pal
    @ObservedObject var library: Library
    let poem: Poem
    let progress: PoemProgress
    let now: Date

    var body: some View {
        PageCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(pal.gild)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(poem.title).font(.display(15)).foregroundStyle(pal.ink).lineLimit(1)
                        Text(poem.author).font(.system(size: 12, design: .serif)).foregroundStyle(pal.inkSoft)
                    }
                    Spacer()
                    NavigationLink {
                        MemorizeView(library: library, poem: poem)
                    } label: {
                        Image(systemName: "eye").foregroundStyle(pal.ribbon)
                    }
                }
                HStack(spacing: 10) {
                    Button {
                        library.review(poem.id, outcome: .lapse, now: now)
                    } label: {
                        Label(loc.t("À revoir", "Missed"), systemImage: "xmark")
                            .font(.system(size: 13, design: .serif)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(pal.ribbonDim)
                    Button {
                        library.review(poem.id, outcome: .correct, now: now)
                    } label: {
                        Label(loc.t("Je le sais", "Got it"), systemImage: "checkmark")
                            .font(.system(size: 13, design: .serif)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(pal.gild)
                }
            }
        }
    }
}
