import SwiftUI
import SwiftData

@main
struct LeRecitalApp: App {
    let container: ModelContainer
    let anthology: Anthology
    @StateObject private var loc = LocManager.shared
    @StateObject private var settings = Settings.shared

    init() {
        // Honour screenshot launch flags before any view reads them.
        if let lang = LaunchFlags.forcedLang {
            UserDefaults.standard.set(lang.rawValue, forKey: LocManager.storageKey)
        }

        let anth = Anthology.loadBundled()
        anthology = anth

        do {
            container = try ModelContainer(for: PoemProgress.self, Recording.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        DemoSeed.seedIfNeeded(container.mainContext, anthology: anth)

        if let mode = LaunchFlags.forcedMode {
            Settings.shared.mode = mode
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(library: Library(anthology: anthology, context: container.mainContext))
                .environmentObject(loc)
                .environmentObject(settings)
                .environment(\.palette, settings.palette)
                .environment(\.themeMode, settings.mode)
                .preferredColorScheme(settings.mode == .soir ? .dark : .light)
                .tint(settings.palette.ribbon)
        }
        .modelContainer(container)
    }
}
