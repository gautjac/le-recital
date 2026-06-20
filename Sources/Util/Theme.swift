import SwiftUI

/// Le Récital's visual identity — a fine letterpress / chapbook aesthetic.
/// Warm cream paper "jour" mode, a warm dim low-blue "soir" (nightstand) mode,
/// an elegant serif for the verse, a ribbon-bookmark accent, deckled edges.
///
/// Two palettes, switched by `Theme.Mode`. All views read colours through the
/// `Palette` so the soir/jour transition is one source of truth.
public enum Theme {

    public enum Mode: String, CaseIterable, Sendable {
        case jour   // warm cream paper, daytime
        case soir   // warm dim, low-blue, bedtime

        public var isDark: Bool { self == .soir }
    }

    public struct Palette {
        public let paper: Color        // page background
        public let paperEdge: Color    // deckled-edge / card shadow tint
        public let ink: Color          // body verse ink
        public let inkSoft: Color      // secondary text
        public let inkFaint: Color     // tertiary / masked-letter hints
        public let ribbon: Color       // bookmark ribbon accent
        public let ribbonDim: Color
        public let rule: Color         // hairline rules / dividers
        public let gild: Color         // gilt accent (mastery rings, stars)
        public let maskFill: Color     // the blank slot fill in memorization
        public let cardField: Color    // raised card surface
    }

    // MARK: Jour — warm cream chapbook in daylight.
    public static let jour = Palette(
        paper:     Color(red: 0.96, green: 0.93, blue: 0.86),
        paperEdge: Color(red: 0.88, green: 0.83, blue: 0.72),
        ink:       Color(red: 0.17, green: 0.13, blue: 0.10),
        inkSoft:   Color(red: 0.38, green: 0.32, blue: 0.26),
        inkFaint:  Color(red: 0.62, green: 0.56, blue: 0.48),
        ribbon:    Color(red: 0.62, green: 0.16, blue: 0.16),   // deep madder red
        ribbonDim: Color(red: 0.74, green: 0.42, blue: 0.36),
        rule:      Color(red: 0.78, green: 0.71, blue: 0.59),
        gild:      Color(red: 0.70, green: 0.54, blue: 0.20),   // antique gilt
        maskFill:  Color(red: 0.86, green: 0.80, blue: 0.69),
        cardField: Color(red: 0.98, green: 0.96, blue: 0.90)
    )

    // MARK: Soir — warm dim nightstand, low blue.
    public static let soir = Palette(
        paper:     Color(red: 0.10, green: 0.085, blue: 0.075),
        paperEdge: Color(red: 0.05, green: 0.04, blue: 0.035),
        ink:       Color(red: 0.86, green: 0.79, blue: 0.66),   // warm parchment ink
        inkSoft:   Color(red: 0.66, green: 0.58, blue: 0.47),
        inkFaint:  Color(red: 0.46, green: 0.40, blue: 0.32),
        ribbon:    Color(red: 0.78, green: 0.36, blue: 0.30),   // dim ember red
        ribbonDim: Color(red: 0.55, green: 0.30, blue: 0.26),
        rule:      Color(red: 0.26, green: 0.22, blue: 0.18),
        gild:      Color(red: 0.80, green: 0.63, blue: 0.32),
        maskFill:  Color(red: 0.18, green: 0.155, blue: 0.13),
        cardField: Color(red: 0.135, green: 0.115, blue: 0.10)
    )

    public static func palette(_ mode: Mode) -> Palette {
        mode == .soir ? soir : jour
    }
}

/// Serif display + reading fonts for the verse. We lean on the system's New York
/// serif (`.serif` design) so there is no font-bundling/licensing concern and it
/// renders beautifully at display sizes — a tasteful chapbook serif.
public extension Font {
    /// The verse face — a generous serif for the poem lines.
    static func verse(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// The display face — titles and the poem's name.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// Environment plumbing so any view can read the active palette + mode.
private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Theme.Palette = Theme.jour
}
private struct ModeKey: EnvironmentKey {
    static let defaultValue: Theme.Mode = .jour
}
public extension EnvironmentValues {
    var palette: Theme.Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
    var themeMode: Theme.Mode {
        get { self[ModeKey.self] }
        set { self[ModeKey.self] = newValue }
    }
}
