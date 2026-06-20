import SwiftUI

/// The app shell: a chapbook with four "sections" — today's poem, the library,
/// the learned-by-heart shelf, and settings — joined by a slim serif tab bar.
public struct RootView: View {
    @EnvironmentObject private var loc: LocManager
    @EnvironmentObject private var settings: Settings
    @StateObject private var library: Library
    @State private var tab: Tab

    enum Tab: Hashable { case today, library, shelf, settings }

    public init(library: Library) {
        _library = StateObject(wrappedValue: library)
        switch LaunchFlags.screen {
        case "library": _tab = State(initialValue: .library)
        case "shelf":   _tab = State(initialValue: .shelf)
        case "settings": _tab = State(initialValue: .settings)
        default:        _tab = State(initialValue: .today)
        }
    }

    public var body: some View {
        TabView(selection: $tab) {
            NavigationStack { TodayView(library: library) }
                .tabItem { Label(loc.t("Aujourd'hui", "Today"), systemImage: "sun.max") }
                .tag(Tab.today)

            NavigationStack { LibraryView(library: library) }
                .tabItem { Label(loc.t("Bibliothèque", "Library"), systemImage: "books.vertical") }
                .tag(Tab.library)

            NavigationStack { ShelfView(library: library) }
                .tabItem { Label(loc.t("Par cœur", "By Heart"), systemImage: "heart.text.square") }
                .tag(Tab.shelf)

            NavigationStack { SettingsView() }
                .tabItem { Label(loc.t("Réglages", "Settings"), systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .environment(\.palette, settings.palette)
        .environment(\.themeMode, settings.mode)
        .tint(settings.palette.ribbon)
    }
}
