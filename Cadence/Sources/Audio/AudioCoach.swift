import Foundation
import AVFoundation
import AudioToolbox

/// Hands-free audio guidance for a block: announces each exercise, speaks the cue,
/// counts the time, chimes at transitions, auto-advances (or waits, per settings).
@MainActor
final class AudioCoach: NSObject, ObservableObject {

    struct Segment {
        var exerciseIndex: Int
        var label: String       // e.g. "Set 1 · Left side"
        var speech: String?     // spoken when the segment starts
        var seconds: Int
        var isAnnouncement: Bool
    }

    @Published var segments: [Segment] = []
    @Published var currentIndex: Int = 0
    @Published var remaining: Int = 0
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var finished = false
    @Published var waitingForTap = false

    private var timer: Timer?
    private let synth = AVSpeechSynthesizer()
    private var autoAdvance = true
    private var block: Block?

    var currentExercise: Exercise? {
        guard let block, !segments.isEmpty, currentIndex < segments.count else { return nil }
        let idx = segments[currentIndex].exerciseIndex
        guard idx < block.exercises.count else { return nil }
        return block.exercises[idx]
    }

    var currentLabel: String {
        guard currentIndex < segments.count else { return "" }
        return segments[currentIndex].label
    }

    var nextExerciseName: String? {
        guard let block, currentIndex < segments.count else { return nil }
        let idx = segments[currentIndex].exerciseIndex
        let next = idx + 1
        guard next < block.exercises.count else { return nil }
        return block.exercises[next].name
    }

    var progress: Double {
        guard !segments.isEmpty else { return 0 }
        return Double(currentIndex) / Double(segments.count)
    }

    // MARK: - Lifecycle

    func start(block: Block, autoAdvance: Bool, shortVersion: Bool) {
        self.block = block
        self.autoAdvance = autoAdvance
        configureAudioSession()
        segments = Self.buildSegments(for: block, short: shortVersion)
        currentIndex = 0
        finished = false
        isRunning = true
        isPaused = false
        beginSegment()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        synth.stopSpeaking(at: .immediate)
        isRunning = false
    }

    func togglePause() {
        guard isRunning else { return }
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
            synth.pauseSpeaking(at: .word)
        } else {
            synth.continueSpeaking()
            startTicking()
        }
    }

    func skip() {
        advance()
    }

    func repeatSegment() {
        beginSegment()
    }

    func tapToContinue() {
        guard waitingForTap else { return }
        waitingForTap = false
        advance(force: true)
    }

    // MARK: - Internals

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private static func buildSegments(for block: Block, short: Bool) -> [Segment] {
        var out: [Segment] = []
        let exercises = short ? block.exercises.filter { $0.inShortVersion } : block.exercises
        for (i, ex) in exercises.enumerated() {
            out.append(Segment(
                exerciseIndex: i,
                label: "Get ready",
                speech: "\(ex.name). \(ex.prescription). \(ex.why)",
                seconds: 9,
                isAnnouncement: true))
            let perSet = ex.seconds ?? Self.estimatedSeconds(reps: ex.reps ?? 8)
            for set in 1...max(ex.sets, 1) {
                if ex.perSide {
                    out.append(Segment(exerciseIndex: i, label: "Set \(set) · Left side",
                                       speech: "Set \(set), left side.", seconds: perSet, isAnnouncement: false))
                    out.append(Segment(exerciseIndex: i, label: "Set \(set) · Right side",
                                       speech: "Switch. Right side.", seconds: perSet, isAnnouncement: false))
                } else {
                    out.append(Segment(exerciseIndex: i, label: "Set \(set)",
                                       speech: set == 1 ? "Begin." : "Set \(set).",
                                       seconds: perSet, isAnnouncement: false))
                }
            }
        }
        return out
    }

    private static func estimatedSeconds(reps: Int) -> Int {
        max(30, reps * 4)
    }

    private func beginSegment() {
        timer?.invalidate()
        guard currentIndex < segments.count else {
            finish()
            return
        }
        let seg = segments[currentIndex]
        remaining = seg.seconds
        if let speech = seg.speech {
            speak(speech)
        }
        startTicking()
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard isRunning, !isPaused else { return }
        remaining -= 1
        if remaining <= 0 {
            chime()
            advance()
        }
    }

    private func advance(force: Bool = false) {
        timer?.invalidate()
        guard currentIndex < segments.count else { return }
        let nextIndex = currentIndex + 1
        if nextIndex >= segments.count {
            finish()
            return
        }
        // At an exercise boundary in tap-to-advance mode, wait for the user.
        let crossesExercise = segments[nextIndex].exerciseIndex != segments[currentIndex].exerciseIndex
        if crossesExercise && !autoAdvance && !force {
            waitingForTap = true
            speak("Tap when you're ready for the next one.")
            return
        }
        currentIndex = nextIndex
        beginSegment()
    }

    private func finish() {
        timer?.invalidate()
        isRunning = false
        finished = true
        if let block {
            speak("Done. \(block.title), complete. Nice work.")
        }
        chime()
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        utterance.preUtteranceDelay = 0.1
        synth.speak(utterance)
    }

    private func chime() {
        AudioServicesPlaySystemSound(1057)
    }
}
