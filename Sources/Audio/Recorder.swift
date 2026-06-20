import Foundation
import AVFoundation
import Combine

/// Shared surface for recitation recording, so views can hold one type whether
/// they run on a real device (with a microphone) or in the Simulator (where mic
/// capture is unavailable and we degrade honestly).
@MainActor
public protocol RecitationRecording: ObservableObject {
    var isAvailable: Bool { get }
    var isRecording: Bool { get }
    /// Elapsed seconds of the in-progress take (0 when idle).
    var elapsed: Double { get }
    /// A short, honest note shown when recording isn't available.
    var unavailableNote: String { get }

    func requestPermission(_ completion: @escaping (Bool) -> Void)
    /// Begin a take into `url`. Returns false if it couldn't start.
    func start(to url: URL) -> Bool
    /// Stop the take; returns the recorded duration in seconds.
    func stop() -> Double
}

/// Factory: real recorder on device, mock on the Simulator. Cast to the protocol
/// so call sites are identical on both platforms (avoids a mismatched-ternary
/// type error in the device build).
@MainActor
public enum RecorderFactory {
    public static func make() -> any RecitationRecording {
        #if targetEnvironment(simulator)
        return SimRecorder()
        #else
        return MicRecorder()
        #endif
    }
}

// MARK: - Simulator fallback (always compiled, honest "disabled" state).

/// A non-functional recorder used in the Simulator. Reports unavailable and never
/// captures audio — so the recite UI shows an honest disabled note instead of
/// pretending to record silence.
@MainActor
public final class SimRecorder: RecitationRecording {
    @Published public private(set) var isRecording = false
    @Published public private(set) var elapsed: Double = 0
    public var isAvailable: Bool { false }
    public var unavailableNote: String {
        t("L'enregistrement nécessite un micro — disponible sur votre iPhone ou iPad, pas dans le simulateur.",
          "Recording needs a microphone — available on your iPhone or iPad, not in the Simulator.")
    }
    public init() {}
    public func requestPermission(_ completion: @escaping (Bool) -> Void) { completion(false) }
    public func start(to url: URL) -> Bool { false }
    public func stop() -> Double { 0 }
}

#if !targetEnvironment(simulator)
// MARK: - Device recorder (AVAudioRecorder, on-device only).

@MainActor
public final class MicRecorder: NSObject, RecitationRecording, AVAudioRecorderDelegate {
    @Published public private(set) var isRecording = false
    @Published public private(set) var elapsed: Double = 0
    public var isAvailable: Bool { true }
    public var unavailableNote: String { "" }

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startedAt: Date?

    public override init() { super.init() }

    public func requestPermission(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    public func start(to url: URL) -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return false
        }
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.delegate = self
            guard rec.record() else { return false }
            recorder = rec
            isRecording = true
            startedAt = Date()
            elapsed = 0
            let t = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let s = self.startedAt else { return }
                    self.elapsed = Date().timeIntervalSince(s)
                }
            }
            timer = t
            return true
        } catch {
            return false
        }
    }

    public func stop() -> Double {
        let duration = recorder?.currentTime ?? elapsed
        recorder?.stop()
        recorder = nil
        timer?.invalidate(); timer = nil
        isRecording = false
        let final = duration > 0 ? duration : elapsed
        elapsed = 0
        startedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        return final
    }
}
#endif

/// Lightweight AVAudioPlayer wrapper for previewing saved takes.
@MainActor
public final class TakePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published public private(set) var playingURL: URL?
    private var player: AVAudioPlayer?

    public func toggle(_ url: URL) {
        if playingURL == url { stop(); return }
        play(url)
    }

    public func play(_ url: URL) {
        stop()
        #if !targetEnvironment(simulator)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.play()
            player = p
            playingURL = url
        } catch {
            playingURL = nil
        }
    }

    public func stop() {
        player?.stop()
        player = nil
        playingURL = nil
    }

    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playingURL = nil }
    }
}
