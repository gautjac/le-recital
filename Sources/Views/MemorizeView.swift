import SwiftUI

/// "Apprendre par cœur" — progressive word-masking. The learner climbs masking
/// levels (15% → … → fully blank), reciting from memory and tapping blanks to
/// peek. Clearing a level records mastery; reaching the top marks the poem
/// learned by heart and offers an SRS review.
public struct MemorizeView: View {
    @EnvironmentObject private var loc: LocManager
    @EnvironmentObject private var settings: Settings
    @Environment(\.palette) private var pal
    @ObservedObject var library: Library
    let poem: Poem

    @State private var level: Int = 1
    @State private var peeked: Set<Int> = []
    @State private var showReview = false

    public init(library: Library, poem: Poem) {
        self.library = library
        self.poem = poem
        let cleared = library.progress(for: poem.id, createIfMissing: false)?.masteryLevel ?? 0
        _level = State(initialValue: min(max(1, cleared + 1), Masking.maxLevel))
    }

    private var lvl: Masking.Level { Masking.level(level) }

    public var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(spacing: 20) {
                    titleBlock
                    levelControl
                    PageCard {
                        VerseView(poem: poem,
                                  maskLevel: level,
                                  peeked: peeked,
                                  fontSize: 21,
                                  onTapMasked: { idx in
                                      withAnimation(.easeOut(duration: 0.2)) {
                                          if peeked.contains(idx) { peeked.remove(idx) }
                                          else { peeked.insert(idx) }
                                      }
                                  })
                    }
                    hint
                    clearButton
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20).padding(.top, 12)
            }
        }
        .navigationTitle(loc.t("Par cœur", "By heart"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { LangToggleToolbar() }
        .sheet(isPresented: $showReview) {
            ReviewSheet(library: library, poem: poem)
                .recitalChrome(settings)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(poem.title).font(.display(22)).foregroundStyle(pal.ink)
                .multilineTextAlignment(.center)
            Text(poem.author).font(.verse(15)).italic().foregroundStyle(pal.inkSoft)
        }
    }

    private var levelControl: some View {
        VStack(spacing: 10) {
            HStack {
                Text(loc.t(lvl.titleFR, lvl.titleEN))
                    .font(.display(17)).foregroundStyle(pal.ribbon)
                Spacer()
                Text("\(Int(lvl.fraction * 100))%")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(pal.inkSoft)
            }
            // Level pips.
            HStack(spacing: 6) {
                ForEach(1...Masking.maxLevel, id: \.self) { i in
                    Capsule()
                        .fill(i <= level ? pal.gild : pal.rule.opacity(0.4))
                        .frame(height: 5)
                        .onTapGesture { withAnimation { level = i; peeked = [] } }
                }
            }
            HStack {
                Button { step(-1) } label: { Image(systemName: "minus.circle") }
                    .disabled(level <= 1)
                Spacer()
                Text(loc.t("Niveau \(level) / \(Masking.maxLevel)", "Level \(level) / \(Masking.maxLevel)"))
                    .font(.system(size: 13, design: .serif)).foregroundStyle(pal.inkFaint)
                Spacer()
                Button { step(1) } label: { Image(systemName: "plus.circle") }
                    .disabled(level >= Masking.maxLevel)
            }
            .font(.system(size: 22)).tint(pal.ribbon)
        }
        .padding(.horizontal, 4)
    }

    private var hint: some View {
        Text(lvl.showFirstLetter
             ? loc.t("Touchez un blanc pour révéler le mot. La première lettre vous guide.",
                     "Tap a blank to reveal the word. The first letter guides you.")
             : loc.t("Plus d'indices — récitez de mémoire, touchez pour vérifier.",
                     "No more hints — recite from memory, tap to check."))
            .font(.system(size: 13, design: .serif)).italic()
            .foregroundStyle(pal.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clearButton: some View {
        Button {
            library.recordLevelCleared(poem.id, level: level)
            if level >= Masking.maxLevel {
                showReview = true
            } else {
                withAnimation { level += 1; peeked = [] }
            }
        } label: {
            Label(level >= Masking.maxLevel
                  ? loc.t("Je le sais par cœur", "I know it by heart")
                  : loc.t("Niveau réussi", "Level cleared"),
                  systemImage: level >= Masking.maxLevel ? "heart.fill" : "checkmark")
                .font(.system(size: 16, weight: .medium, design: .serif))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(level >= Masking.maxLevel ? pal.ribbon : pal.gild)
        .controlSize(.large)
    }

    private func step(_ d: Int) {
        withAnimation {
            level = min(max(1, level + d), Masking.maxLevel)
            peeked = []
        }
    }
}

/// After learning by heart, schedule the first SRS review.
struct ReviewSheet: View {
    @EnvironmentObject private var loc: LocManager
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: Library
    let poem: Poem

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 22) {
                Spacer()
                MasteryRing(fraction: 1, learned: true, size: 84)
                Text(loc.t("Appris par cœur", "Learned by heart"))
                    .font(.display(26)).foregroundStyle(pal.ink)
                Text(poem.title).font(.verse(18)).italic().foregroundStyle(pal.inkSoft)
                Text(loc.t("« \(poem.author) » entre dans votre répertoire. On vous le redonnera à réviser pour qu'il y reste.",
                           "“\(poem.author)” joins your repertoire. We'll resurface it for review so it stays."))
                    .font(.system(size: 15, design: .serif)).foregroundStyle(pal.inkSoft)
                    .multilineTextAlignment(.center).padding(.horizontal, 30)
                Spacer()
                Button {
                    library.review(poem.id, outcome: .correct)
                    dismiss()
                } label: {
                    Text(loc.t("Programmer la révision", "Schedule review"))
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(pal.ribbon).controlSize(.large)
                Button(loc.t("Plus tard", "Later")) { dismiss() }
                    .tint(pal.inkSoft)
            }
            .padding(28)
        }
    }
}
