import Foundation
import SwiftUI
import Combine

/// App-wide reading & display preferences, persisted in `UserDefaults` (small,
/// scalar settings — SwiftData is reserved for the richer mastery/recording
/// graph). Observable so the whole UI reacts to soir mode, pace, and the
/// "prefer my language" toggle live.
@MainActor
public final class Settings: ObservableObject {
    public static let shared = Settings()

    public enum Pace: String, CaseIterable, Sendable {
        case gentle   // ~4.5s per line
        case measured // ~3s per line
        case brisk    // ~1.8s per line

        public var seconds: Double {
            switch self {
            case .gentle:   return 4.5
            case .measured: return 3.0
            case .brisk:    return 1.8
            }
        }
        public func title(_ lang: Lang) -> String {
            switch self {
            case .gentle:   return lang == .fr ? "Lent" : "Gentle"
            case .measured: return lang == .fr ? "Posé" : "Measured"
            case .brisk:    return lang == .fr ? "Vif" : "Brisk"
            }
        }
    }

    private enum Key {
        static let mode = "recital_mode"            // jour / soir
        static let pace = "recital_pace"
        static let autoPace = "recital_autopace"
        static let preferLang = "recital_prefer_lang" // bias daily pick to UI lang
    }

    @Published public var mode: Theme.Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Key.mode) }
    }
    @Published public var pace: Pace {
        didSet { UserDefaults.standard.set(pace.rawValue, forKey: Key.pace) }
    }
    @Published public var autoPace: Bool {
        didSet { UserDefaults.standard.set(autoPace, forKey: Key.autoPace) }
    }
    /// When true, the daily poem favours the active UI language (still rotating
    /// through both over time).
    @Published public var preferMyLanguage: Bool {
        didSet { UserDefaults.standard.set(preferMyLanguage, forKey: Key.preferLang) }
    }

    private init() {
        let d = UserDefaults.standard
        mode = Theme.Mode(rawValue: d.string(forKey: Key.mode) ?? "") ?? .jour
        pace = Pace(rawValue: d.string(forKey: Key.pace) ?? "") ?? .gentle
        autoPace = d.object(forKey: Key.autoPace) as? Bool ?? false
        preferMyLanguage = d.object(forKey: Key.preferLang) as? Bool ?? true
    }

    public var palette: Theme.Palette { Theme.palette(mode) }
}

/// Launch flags read once at startup — used by the screenshot harness to put the
/// app in a deterministic, pre-seeded state without touching real user data.
public enum LaunchFlags {
    /// `-recitalDemo 1` (or env `RECITAL_DEMO=1`): seed demo mastery/recordings.
    public static var demo: Bool {
        UserDefaults.standard.bool(forKey: "recitalDemo")
            || ProcessInfo.processInfo.environment["RECITAL_DEMO"] == "1"
    }
    /// `-recitalDate yyyy-MM-dd`: pin "today" so the daily card is reproducible.
    public static var pinnedDate: Date? {
        guard let s = UserDefaults.standard.string(forKey: "recitalDate")
            ?? ProcessInfo.processInfo.environment["RECITAL_DATE"] else { return nil }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
    /// `-recitalLang fr|en`: force the UI language for a screenshot pass.
    public static var forcedLang: Lang? {
        guard let s = UserDefaults.standard.string(forKey: "recitalLang")
            ?? ProcessInfo.processInfo.environment["RECITAL_LANG"] else { return nil }
        return Lang(rawValue: s)
    }
    /// `-recitalScreen today|library|shelf|settings|memorize`: open straight to a
    /// screen for a screenshot pass. `memorize` opens the day's poem mid-mask.
    public static var screen: String? {
        UserDefaults.standard.string(forKey: "recitalScreen")
            ?? ProcessInfo.processInfo.environment["RECITAL_SCREEN"]
    }
    /// `-recitalPoem <id>`: open a specific poem's detail page (screenshot helper).
    public static var poemID: String? {
        UserDefaults.standard.string(forKey: "recitalPoem")
            ?? ProcessInfo.processInfo.environment["RECITAL_POEM"]
    }
    /// `-recitalCraft 1`: in a poem detail, float the craft note above the verse
    /// so the "why it works" card is visible for a screenshot.
    public static var craftFirst: Bool {
        UserDefaults.standard.bool(forKey: "recitalCraft")
            || ProcessInfo.processInfo.environment["RECITAL_CRAFT"] == "1"
    }
    /// `-recitalReveal 1`: fully reveal the daily poem (for the craft-note shot).
    public static var revealAll: Bool {
        UserDefaults.standard.bool(forKey: "recitalReveal")
            || ProcessInfo.processInfo.environment["RECITAL_REVEAL"] == "1"
    }
    /// `-recitalMode jour|soir`: force the palette for a screenshot pass.
    public static var forcedMode: Theme.Mode? {
        guard let s = UserDefaults.standard.string(forKey: "recitalMode")
            ?? ProcessInfo.processInfo.environment["RECITAL_MODE"] else { return nil }
        return Theme.Mode(rawValue: s)
    }
}
