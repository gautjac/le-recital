import SwiftUI
import Combine

/// "Réciter & s'enregistrer" — read the poem aloud and capture takes. On a real
/// device this records via the microphone; in the Simulator it shows an honest
/// disabled note (recording needs a mic). Saved takes are listed, playable, and
/// deletable.
public struct ReciteView: View {
    @EnvironmentObject private var loc: LocManager
    @Environment(\.palette) private var pal
    @ObservedObject var library: Library
    let poem: Poem

    @StateObject private var recorderBox = RecorderBox()
    @StateObject private var player = TakePlayer()
    @State private var permissionDenied = false
    @State private var refreshToken = 0

    public init(library: Library, poem: Poem) {
        self.library = library
        self.poem = poem
    }

    private var recorder: any RecitationRecording { recorderBox.recorder }

    public var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text(poem.title).font(.display(22)).foregroundStyle(pal.ink)
                            .multilineTextAlignment(.center)
                        Text(poem.author).font(.verse(15)).italic().foregroundStyle(pal.inkSoft)
                    }
                    PageCard {
                        VerseView(poem: poem, fontSize: 19, lineSpacing: 7)
                    }
                    recordPanel
                    takesList
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20).padding(.top, 12)
            }
        }
        .navigationTitle(loc.t("Réciter", "Recite"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { LangToggleToolbar() }
        .onDisappear { player.stop() }
    }

    @ViewBuilder
    private var recordPanel: some View {
        PageCard {
            VStack(spacing: 14) {
                if recorder.isAvailable {
                    RecorderControl(recorderBox: recorderBox) { url, duration in
                        let name = RecordingStore.newFileName(poemID: poem.id)
                        let dest = RecordingStore.url(for: name)
                        try? FileManager.default.moveItem(at: url, to: dest)
                        library.addRecording(poemID: poem.id, fileName: name, duration: duration)
                        refreshToken += 1
                    } onDenied: {
                        permissionDenied = true
                    }
                    if permissionDenied {
                        Text(loc.t("Accès au micro refusé. Activez-le dans Réglages.",
                                   "Microphone access denied. Enable it in Settings."))
                            .font(.system(size: 12, design: .serif)).foregroundStyle(pal.ribbon)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.slash").font(.system(size: 22)).foregroundStyle(pal.inkFaint)
                        Text(recorder.unavailableNote)
                            .font(.system(size: 13, design: .serif)).foregroundStyle(pal.inkSoft)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var takesList: some View {
        let takes = library.recordings(for: poem.id)
        if !takes.isEmpty {
            PageCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc.t("Vos prises", "Your takes"))
                        .font(.display(16)).foregroundStyle(pal.ink)
                    ForEach(takes) { take in
                        TakeRow(take: take, player: player) {
                            library.deleteRecording(take)
                            refreshToken += 1
                        }
                        if take.id != takes.last?.id { ChapbookRule(ornament: "·") }
                    }
                }
            }
            .id(refreshToken)
        }
    }
}

/// Holds the platform recorder so the view can observe it. Forwards the concrete
/// recorder's `objectWillChange` so SwiftUI refreshes on record state / elapsed
/// updates even though the recorder is held as an existential.
@MainActor
final class RecorderBox: ObservableObject {
    let recorder: any RecitationRecording
    private var bag: AnyCancellable?
    init() {
        let r = RecorderFactory.make()
        recorder = r
        bag = forwarder(of: r)
    }
    /// Type-erase the concrete publisher and republish through `self`.
    private func forwarder<R: RecitationRecording>(of r: R) -> AnyCancellable {
        r.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

/// The record button + elapsed timer. Calls back with the finished file URL.
private struct RecorderControl: View {
    @EnvironmentObject private var loc: LocManager
    @Environment(\.palette) private var pal
    @ObservedObject var recorderBox: RecorderBox
    var onFinish: (URL, Double) -> Void
    var onDenied: () -> Void

    @State private var currentURL: URL?

    private var rec: any RecitationRecording { recorderBox.recorder }

    var body: some View {
        VStack(spacing: 12) {
            Text(elapsedString)
                .font(.system(size: 34, weight: .light, design: .monospaced))
                .foregroundStyle(isRecording ? pal.ribbon : pal.inkSoft)
                .contentTransition(.numericText())
            Button {
                toggle()
            } label: {
                ZStack {
                    Circle().stroke(pal.ribbon, lineWidth: 3).frame(width: 72, height: 72)
                    RoundedRectangle(cornerRadius: isRecording ? 6 : 30)
                        .fill(pal.ribbon)
                        .frame(width: isRecording ? 30 : 56, height: isRecording ? 30 : 56)
                        .animation(.spring(duration: 0.25), value: isRecording)
                }
            }
            .accessibilityLabel(isRecording ? loc.t("Arrêter", "Stop") : loc.t("Enregistrer", "Record"))
            Text(isRecording ? loc.t("Enregistrement…", "Recording…")
                             : loc.t("Touchez pour vous enregistrer", "Tap to record yourself"))
                .font(.system(size: 13, design: .serif)).foregroundStyle(pal.inkFaint)
        }
    }

    private var isRecording: Bool { rec.isRecording }
    private var elapsed: Double { rec.elapsed }

    private var elapsedString: String {
        let s = Int(elapsed); return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func toggle() {
        if rec.isRecording {
            let duration = rec.stop()
            if let url = currentURL { onFinish(url, duration) }
            currentURL = nil
        } else {
            rec.requestPermission { granted in
                guard granted else { onDenied(); return }
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("take-\(UUID().uuidString).m4a")
                currentURL = tmp
                _ = rec.start(to: tmp)
            }
        }
    }
}

private struct TakeRow: View {
    @EnvironmentObject private var loc: LocManager
    @Environment(\.palette) private var pal
    let take: Recording
    @ObservedObject var player: TakePlayer
    var onDelete: () -> Void

    private var url: URL { RecordingStore.url(for: take.fileName) }
    private var isPlaying: Bool { player.playingURL == url }

    var body: some View {
        HStack(spacing: 12) {
            Button { player.toggle(url) } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30)).foregroundStyle(pal.ribbon)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(durationString).font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(pal.ink)
                Text(dateString).font(.system(size: 12, design: .serif)).foregroundStyle(pal.inkFaint)
            }
            Spacer()
            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up").foregroundStyle(pal.inkSoft)
            }
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash").foregroundStyle(pal.ribbonDim)
            }
        }
    }

    private var durationString: String {
        let s = Int(take.duration.rounded()); return String(format: "%d:%02d", s / 60, s % 60)
    }
    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: loc.lang == .fr ? "fr_FR" : "en_US")
        f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: take.createdAt)
    }
}
