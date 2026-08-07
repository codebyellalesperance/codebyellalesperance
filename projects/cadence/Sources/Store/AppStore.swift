import Foundation
import SwiftUI

/// Single source of truth. Plan + settings + logs, persisted as JSON in Documents.
/// Paint first, hydrate after: loading failures fall back to seed/in-memory, never block the UI.
@MainActor
final class AppStore: ObservableObject {
    @Published var plan: TrainingPlan
    @Published var settings: AppSettings
    @Published var completions: [BlockCompletion] = []
    @Published var exerciseLogs: [ExerciseLog] = []
    @Published var checkIns: [CheckIn] = []
    @Published var activities: [ActivityEntry] = []
    @Published var adjustments: [DayAdjustment] = []
    /// Per-day exercise swaps: [dayKey: [originalExerciseID: replacementExerciseID]]
    @Published var daySwaps: [String: [String: String]] = [:]

    private let fm = FileManager.default

    init() {
        plan = AppStore.loadSeedPlan()
        settings = AppSettings()
        load()
    }

    // MARK: - Persistence

    private var docs: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func url(_ name: String) -> URL {
        docs.appendingPathComponent(name)
    }

    private func read<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to name: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value) {
            try? data.write(to: url(name), options: .atomic)
        }
    }

    private func load() {
        if let p: TrainingPlan = read("plan.json", as: TrainingPlan.self) { plan = p }
        if let s: AppSettings = read("settings.json", as: AppSettings.self) { settings = s }
        completions = read("completions.json", as: [BlockCompletion].self) ?? []
        exerciseLogs = read("exercise-logs.json", as: [ExerciseLog].self) ?? []
        checkIns = read("checkins.json", as: [CheckIn].self) ?? []
        activities = read("activities.json", as: [ActivityEntry].self) ?? []
        adjustments = read("adjustments.json", as: [DayAdjustment].self) ?? []
        daySwaps = read("swaps.json", as: [String: [String: String]].self) ?? [:]
    }

    func saveAll() {
        write(plan, to: "plan.json")
        write(settings, to: "settings.json")
        write(completions, to: "completions.json")
        write(exerciseLogs, to: "exercise-logs.json")
        write(checkIns, to: "checkins.json")
        write(activities, to: "activities.json")
        write(adjustments, to: "adjustments.json")
        write(daySwaps, to: "swaps.json")
    }

    static func loadSeedPlan() -> TrainingPlan {
        if let seedURL = Bundle.main.url(forResource: "seed-plan", withExtension: "json"),
           let data = try? Data(contentsOf: seedURL),
           let plan = try? JSONDecoder().decode(TrainingPlan.self, from: data) {
            return plan
        }
        // Absolute fallback so the app always paints.
        let breathing = Exercise(
            id: "hip-breathing", name: "90/90 hip breathing", sets: 2, reps: 5, seconds: nil,
            perSide: false, load: nil, rest: nil,
            why: "Full exhales stack ribs over pelvis so everything after works on the right tissue.",
            feel: "Ribs down on the exhale; low back gently flat.",
            videoURL: nil, swaps: [], inShortVersion: true, logged: false)
        let morning = Block(id: "morning", kind: .morning, title: "Morning stretch",
                            minutes: 10, audio: true, note: "Breathing first, always.",
                            exercises: [breathing])
        let desk = Block(id: "desk", kind: .desk, title: "Desk resets",
                         minutes: 5, audio: false, note: "Chair-friendly.", exercises: [])
        return TrainingPlan(id: "fallback", name: "Starter", version: "0",
                            coachNote: "", morning: morning, desk: desk,
                            gymDays: [], defaultGymDaysPerWeek: 4)
    }

    // MARK: - Actions

    func completeBlock(_ blockID: String, on date: Date, short: Bool = false) {
        let key = DayKey.key(for: date)
        guard !isBlockComplete(blockID, on: date) else { return }
        completions.append(BlockCompletion(dayKey: key, blockID: blockID,
                                           completedAt: Date(), shortVersion: short))
        saveAll()
    }

    func uncompleteBlock(_ blockID: String, on date: Date) {
        let key = DayKey.key(for: date)
        completions.removeAll { $0.dayKey == key && $0.blockID == blockID }
        saveAll()
    }

    func isBlockComplete(_ blockID: String, on date: Date) -> Bool {
        let key = DayKey.key(for: date)
        return completions.contains { $0.dayKey == key && $0.blockID == blockID }
    }

    func logExercise(_ exercise: Exercise, entries: [SetEntry], on date: Date, swappedFrom: String? = nil) {
        let key = DayKey.key(for: date)
        exerciseLogs.removeAll { $0.dayKey == key && $0.exerciseID == exercise.id }
        exerciseLogs.append(ExerciseLog(dayKey: key, exerciseID: exercise.id,
                                        exerciseName: exercise.name,
                                        entries: entries, swappedFrom: swappedFrom))
        saveAll()
    }

    func lastLog(for exerciseID: String, before date: Date) -> ExerciseLog? {
        let key = DayKey.key(for: date)
        return exerciseLogs
            .filter { $0.exerciseID == exerciseID && $0.dayKey < key }
            .sorted { $0.dayKey < $1.dayKey }
            .last
    }

    func history(for exerciseID: String, limit: Int = 8) -> [ExerciseLog] {
        Array(exerciseLogs
            .filter { $0.exerciseID == exerciseID }
            .sorted { $0.dayKey < $1.dayKey }
            .suffix(limit))
    }

    func saveCheckIn(tension: Int?, periodStart: Bool, note: String, on date: Date) {
        let key = DayKey.key(for: date)
        checkIns.removeAll { $0.dayKey == key }
        checkIns.append(CheckIn(dayKey: key, tension: tension, periodStart: periodStart, note: note))
        saveAll()
    }

    func checkIn(on date: Date) -> CheckIn? {
        checkIns.first { $0.dayKey == DayKey.key(for: date) }
    }

    func addActivity(kind: String, focus: String, intensity: Int, note: String, on date: Date) {
        activities.append(ActivityEntry(dayKey: DayKey.key(for: date), kind: kind,
                                        focus: focus, intensity: intensity, note: note))
        saveAll()
    }

    func skipGym(on date: Date) {
        adjustments.append(DayAdjustment(dayKey: DayKey.key(for: date), action: "skipped", target: nil))
        saveAll()
    }

    func bumpGym(from date: Date, to target: Date) {
        adjustments.append(DayAdjustment(dayKey: DayKey.key(for: date), action: "bumped",
                                         target: DayKey.key(for: target)))
        saveAll()
    }

    func swapExercise(original: Exercise, replacementID: String, on date: Date) {
        let key = DayKey.key(for: date)
        var swaps = daySwaps[key] ?? [:]
        swaps[original.id] = replacementID
        daySwaps[key] = swaps
        saveAll()
    }

    /// Most recent manually-logged period start, if any.
    var lastManualPeriodStart: Date? {
        checkIns
            .filter { $0.periodStart }
            .compactMap { DayKey.date(from: $0.dayKey) }
            .max()
    }

    // MARK: - Import / export

    func exportPlanJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(plan) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func importPlanJSON(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let newPlan = try? JSONDecoder().decode(TrainingPlan.self, from: data) else {
            return false
        }
        plan = newPlan
        saveAll()
        return true
    }

    func exportLogsJSON() -> String {
        struct Dump: Encodable {
            let completions: [BlockCompletion]
            let exerciseLogs: [ExerciseLog]
            let checkIns: [CheckIn]
            let activities: [ActivityEntry]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let dump = Dump(completions: completions, exerciseLogs: exerciseLogs,
                        checkIns: checkIns, activities: activities)
        guard let data = try? encoder.encode(dump) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func clearAllData() {
        completions = []
        exerciseLogs = []
        checkIns = []
        activities = []
        adjustments = []
        daySwaps = [:]
        settings = AppSettings()
        plan = AppStore.loadSeedPlan()
        saveAll()
    }
}
