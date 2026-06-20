import SwiftUI

/// "Aujourd'hui / Today" — a single beautiful page presenting the day's poem,
/// with a slow line-by-line reveal, the craft note, and entries into memorizing
/// and reciting.
public struct TodayView: View {
    @EnvironmentObject private var loc: LocManager
    @EnvironmentObject private var settings: Settings
    @Environment(\.palette) private var pal
    @ObservedObject var library: Library

    @State private var revealed = LaunchFlags.revealAll ? Int.max : 1
    @State private var autoTimer: Timer?
    @State private var showCraft = false
    @State private var deepLinkMemorize = LaunchFlags.screen == "memorize"
    @State private var deepLinkPoem = LaunchFlags.poemID != nil

    private var today: Date { LaunchFlags.pinnedDate ?? Date() }

    private var poem: Poem? {
        DailyPoem.poem(for: today, in: library.poems,
                       preferred: settings.preferMyLanguage ? loc.lang : nil)
    }

    public var body: some View {
        ZStack {
            PaperBackground()
            if let poem {
                content(poem)
            } else {
                Text(loc.t("Aucun poème.", "No poem.")).foregroundStyle(pal.inkSoft)
            }
        }
        .navigationTitle(loc.t("Aujourd'hui", "Today"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { LangToggleToolbar() }
        .onDisappear { autoTimer?.invalidate() }
        .navigationDestination(isPresented: $deepLinkMemorize) {
            if let poem { MemorizeView(library: library, poem: poem) }
        }
        .navigationDestination(isPresented: $deepLinkPoem) {
            if let id = LaunchFlags.poemID, let p = library.poem(id: id) {
                PoemDetailView(library: library, poem: p)
            }
        }
    }

    private var totalLines: Int { poem?.spokenLines.count ?? 0 }
    private var fullyRevealed: Bool { revealed >= totalLines }

    @ViewBuilder
    private func content(_ poem: Poem) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                header(poem)
                ChapbookRule()

                PageCard {
                    VStack(alignment: .leading, spacing: 16) {
                        VerseView(poem: poem,
                                  revealedSpokenLines: fullyRevealed ? nil : revealed,
                                  fontSize: 22)
                            .animation(settings.autoPace ? .easeIn(duration: 0.4) : .default,
                                       value: revealed)

                        if !fullyRevealed {
                            revealControls(poem)
                        }
                    }
                }

                if fullyRevealed {
                    craftSection(poem)
                    actions(poem)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .onTapGesture { if !settings.autoPace { advance() } }
    }

    @ViewBuilder
    private func header(_ poem: Poem) -> some View {
        VStack(spacing: 8) {
            Text(dateLine).font(.system(size: 13, weight: .medium, design: .serif))
                .tracking(1.5).foregroundStyle(pal.inkFaint).textCase(.uppercase)
            Text(poem.title)
                .font(.display(30, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(pal.ink)
            Text(poem.author)
                .font(.verse(18)).italic().foregroundStyle(pal.inkSoft)
            HStack(spacing: 8) {
                Tag(poem.authorYears)
                Tag(poem.year, filled: true)
                Tag(poem.poemLang.label)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: loc.lang == .fr ? "fr_FR" : "en_US")
        f.dateStyle = .long
        return f.string(from: today)
    }

    @ViewBuilder
    private func revealControls(_ poem: Poem) -> some View {
        VStack(spacing: 12) {
            ChapbookRule(ornament: "·")
            HStack {
                Text(loc.t("Vers \(revealed) / \(totalLines)", "Line \(revealed) / \(totalLines)"))
                    .font(.system(size: 13, design: .serif)).foregroundStyle(pal.inkFaint)
                Spacer()
                Button {
                    advance()
                } label: {
                    Label(loc.t("Dévoiler", "Reveal"), systemImage: "arrow.down")
                        .font(.system(size: 15, weight: .medium, design: .serif))
                }
                .buttonStyle(.borderedProminent)
                .tint(pal.ribbon)
            }
            Toggle(isOn: Binding(get: { settings.autoPace }, set: { setAuto($0) })) {
                Text(loc.t("Lecture automatique", "Auto-pace")).font(.system(size: 14, design: .serif))
            }
            .tint(pal.gild)
        }
    }

    @ViewBuilder
    private func craftSection(_ poem: Poem) -> some View {
        PageCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "quote.opening").foregroundStyle(pal.gild)
                    Text(loc.t("Pourquoi ce poème tient", "Why this poem holds"))
                        .font(.display(17)).foregroundStyle(pal.ink)
                }
                Text(poem.craft(loc.lang))
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(pal.inkSoft)
                    .lineSpacing(4)
                ChapbookRule(ornament: "·")
                Text(poem.source)
                    .font(.system(size: 12, design: .serif)).italic()
                    .foregroundStyle(pal.inkFaint)
                DeepenButton(poem: poem)
            }
        }
    }

    @ViewBuilder
    private func actions(_ poem: Poem) -> some View {
        let prog = library.progress(for: poem.id, createIfMissing: false)
        VStack(spacing: 12) {
            NavigationLink {
                MemorizeView(library: library, poem: poem)
            } label: {
                actionRow(icon: "brain.head.profile",
                          title: loc.t("Apprendre par cœur", "Learn by heart"),
                          subtitle: loc.t("Masquage progressif des mots", "Progressively mask the words"))
            }
            NavigationLink {
                ReciteView(library: library, poem: poem)
            } label: {
                actionRow(icon: "mic",
                          title: loc.t("Réciter & s'enregistrer", "Recite & record"),
                          subtitle: loc.t("Écoutez-vous, gardez vos prises", "Hear yourself, keep your takes"))
            }
            HStack {
                Button {
                    library.toggleFavorite(poem.id)
                } label: {
                    Label(library.isFavorite(poem.id) ? loc.t("Favori", "Favorited") : loc.t("Ajouter aux favoris", "Add to favorites"),
                          systemImage: library.isFavorite(poem.id) ? "star.fill" : "star")
                        .font(.system(size: 14, design: .serif))
                }
                .tint(pal.gild)
                Spacer()
                if let prog, prog.masteryLevel > 0 {
                    MasteryRing(fraction: prog.masteryFraction, learned: prog.learnedByHeart, size: 34)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        PageCard(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22)).foregroundStyle(pal.ribbon)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.display(16)).foregroundStyle(pal.ink)
                    Text(subtitle).font(.system(size: 13, design: .serif)).foregroundStyle(pal.inkFaint)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(pal.inkFaint)
            }
        }
    }

    // MARK: Reveal pacing

    private func advance() {
        guard revealed < totalLines else { return }
        withAnimation { revealed += 1 }
    }

    private func setAuto(_ on: Bool) {
        settings.autoPace = on
        autoTimer?.invalidate(); autoTimer = nil
        guard on, !fullyRevealed else { return }
        autoTimer = Timer.scheduledTimer(withTimeInterval: settings.pace.seconds, repeats: true) { tmr in
            Task { @MainActor in
                if revealed < totalLines { withAnimation { revealed += 1 } }
                else { tmr.invalidate() }
            }
        }
    }
}

/// A toolbar item that toggles the global FR/EN language.
public struct LangToggleToolbar: ToolbarContent {
    @EnvironmentObject private var loc: LocManager
    public init() {}
    public var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                loc.lang = (loc.lang == .fr) ? .en : .fr
            } label: {
                Text(loc.lang.label).font(.system(size: 14, weight: .bold, design: .serif))
            }
            .accessibilityLabel(loc.t("Changer de langue", "Switch language"))
        }
    }
}

/// The optional "approfondir" button — only present when a key exists.
public struct DeepenButton: View {
    @EnvironmentObject private var loc: LocManager
    @Environment(\.palette) private var pal
    let poem: Poem
    @State private var loading = false
    @State private var result: String?
    @State private var failed = false

    public init(poem: Poem) { self.poem = poem }

    public var body: some View {
        if Deepen.isAvailable {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Task { await run() }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(loc.t("Approfondir", "Go deeper"))
                        if loading { ProgressView().controlSize(.small).padding(.leading, 4) }
                    }
                    .font(.system(size: 14, weight: .medium, design: .serif))
                }
                .tint(pal.gild)
                .disabled(loading)

                if let result {
                    Text(result)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(pal.inkSoft).lineSpacing(4)
                        .padding(.top, 2)
                }
                if failed {
                    Text(loc.t("La lecture approfondie n'a pas abouti.", "The deeper reading didn't come through."))
                        .font(.system(size: 12, design: .serif)).foregroundStyle(pal.ribbon)
                }
            }
        }
    }

    private func run() async {
        loading = true; failed = false
        do { result = try await Deepen.reading(for: poem, lang: loc.lang) }
        catch { failed = true }
        loading = false
    }
}
