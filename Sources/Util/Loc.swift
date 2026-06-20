import Foundation
import SwiftUI
import Combine

/// Le Récital's tiny bilingual layer (FR + EN), mirroring the Atelier i18n spec.
///
/// - Default language follows the system (`Locale.preferredLanguages.first`),
///   with **French as the fallback** (Jac is FR-first / Québécois).
/// - The choice is persisted under the shared Atelier key `atelier_lang` and can
///   be overridden in-app from Settings.
/// - Every user-visible literal is routed through `t(fr, en)` / `L.t(...)`.
///
/// Note: the *poems themselves* are always shown in their ORIGINAL language
/// (a Baudelaire stays in French, a Keats stays in English) — only the chrome,
/// craft notes, and UI follow the toggle. Each poem carries `craftFR`/`craftEN`.

public enum Lang: String, CaseIterable, Sendable {
    case fr
    case en

    public var label: String { self == .fr ? "FR" : "EN" }

    /// The system's best-guess language, FR fallback.
    public static var systemDefault: Lang {
        let pref = Locale.preferredLanguages.first?.lowercased() ?? "fr"
        return pref.hasPrefix("en") ? .en : .fr
    }
}

/// Shared, observable language store. A single instance (`LocManager.shared`)
/// backs the whole app so the FR/EN toggle is global.
@MainActor
public final class LocManager: ObservableObject {
    public static let shared = LocManager()

    /// Persisted under the shared Atelier key. Synced with `@AppStorage` views.
    public static let storageKey = "atelier_lang"

    @Published public var lang: Lang {
        didSet {
            guard oldValue != lang else { return }
            UserDefaults.standard.set(lang.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = Lang(rawValue: raw) {
            lang = saved
        } else {
            lang = Lang.systemDefault
        }
    }

    /// Pick the right string for the current language.
    public func t(_ fr: String, _ en: String) -> String { lang == .fr ? fr : en }
}

/// Free-function convenience that reads the *current* persisted language without
/// needing a view's environment. Use inside model/value types where there is no
/// `@EnvironmentObject`.
public func t(_ fr: String, _ en: String) -> String {
    let lang: Lang
    if let raw = UserDefaults.standard.string(forKey: LocManager.storageKey),
       let saved = Lang(rawValue: raw) {
        lang = saved
    } else {
        lang = Lang.systemDefault
    }
    return lang == .fr ? fr : en
}

/// Namespaced alias so call sites can read `L.t(...)` when `t` would shadow a
/// local parameter named `t`.
public enum L {
    public static func t(_ fr: String, _ en: String) -> String { Recital_t(fr, en) }
}

private func Recital_t(_ fr: String, _ en: String) -> String { t(fr, en) }
