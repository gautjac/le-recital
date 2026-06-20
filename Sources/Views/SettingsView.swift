import SwiftUI

/// "Réglages / Settings" — language, reveal pace, prefer-my-language daily bias,
/// and the soir / nightstand mode. A small "about" footer notes provenance.
public struct SettingsView: View {
    @EnvironmentObject private var loc: LocManager
    @EnvironmentObject private var settings: Settings
    @Environment(\.palette) private var pal

    public init() {}

    public var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    languageCard
                    modeCard
                    paceCard
                    dailyCard
                    aboutCard
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20).padding(.top, 12)
            }
        }
        .navigationTitle(loc.t("Réglages", "Settings"))
    }

    private func cardTitle(_ s: String) -> some View {
        Text(s).font(.display(16)).foregroundStyle(pal.ink)
    }

    private var languageCard: some View {
        PageCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle(loc.t("Langue de l'interface", "Interface language"))
                Picker("", selection: Binding(get: { loc.lang }, set: { loc.lang = $0 })) {
                    Text("Français").tag(Lang.fr)
                    Text("English").tag(Lang.en)
                }
                .pickerStyle(.segmented)
                Text(loc.t("Les poèmes restent dans leur langue d'origine ; seuls l'interface et les notes suivent ce choix.",
                           "Poems stay in their original language; only the interface and craft notes follow this choice."))
                    .font(.system(size: 12, design: .serif)).foregroundStyle(pal.inkFaint)
            }
        }
    }

    private var modeCard: some View {
        PageCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle(loc.t("Ambiance", "Ambience"))
                Picker("", selection: Binding(get: { settings.mode }, set: { settings.mode = $0 })) {
                    Text(loc.t("Jour", "Day")).tag(Theme.Mode.jour)
                    Text(loc.t("Soir", "Night")).tag(Theme.Mode.soir)
                }
                .pickerStyle(.segmented)
                Text(loc.t("« Soir » tamise la page en lumière chaude et basse pour la lecture du coucher.",
                           "“Night” dims the page to a warm, low light for bedtime reading."))
                    .font(.system(size: 12, design: .serif)).foregroundStyle(pal.inkFaint)
            }
        }
    }

    private var paceCard: some View {
        PageCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle(loc.t("Rythme du dévoilement", "Reveal pace"))
                Picker("", selection: Binding(get: { settings.pace }, set: { settings.pace = $0 })) {
                    ForEach(Settings.Pace.allCases, id: \.self) { p in
                        Text(p.title(loc.lang)).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                Toggle(isOn: Binding(get: { settings.autoPace }, set: { settings.autoPace = $0 })) {
                    Text(loc.t("Lecture automatique par défaut", "Auto-pace by default"))
                        .font(.system(size: 14, design: .serif))
                }
                .tint(pal.gild)
            }
        }
    }

    private var dailyCard: some View {
        PageCard {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle(loc.t("Poème du jour", "Daily poem"))
                Toggle(isOn: Binding(get: { settings.preferMyLanguage }, set: { settings.preferMyLanguage = $0 })) {
                    Text(loc.t("Préférer ma langue", "Prefer my language"))
                        .font(.system(size: 14, design: .serif))
                }
                .tint(pal.gild)
                Text(loc.t("Le poème du jour favorisera votre langue, tout en faisant tourner les deux au fil du temps.",
                           "The daily poem will favour your language, while still rotating through both over time."))
                    .font(.system(size: 12, design: .serif)).foregroundStyle(pal.inkFaint)
            }
        }
    }

    private var aboutCard: some View {
        PageCard {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle(loc.t("À propos", "About"))
                Text("Le Récital")
                    .font(.display(18)).foregroundStyle(pal.ribbon)
                Text(loc.t("Un poème par jour, appris par cœur.", "A poem a day, learned by heart."))
                    .font(.verse(15)).italic().foregroundStyle(pal.inkSoft)
                ChapbookRule(ornament: "❧")
                Text(loc.t("Trente poèmes du domaine public — anglais (PoetryDB) et français (Wikisource) — chacun attribué dans sa fiche.",
                           "Thirty public-domain poems — English (PoetryDB) and French (Wikisource) — each attributed in its record."))
                    .font(.system(size: 12, design: .serif)).foregroundStyle(pal.inkFaint).lineSpacing(3)
            }
        }
    }
}
