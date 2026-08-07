import Foundation

// MARK: - Plan (the pluggable program config)

struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var sets: Int
    /// Rep count for rep-based work; nil when time-based.
    var reps: Int?
    /// Seconds per set for time-based work; nil when rep-based.
    var seconds: Int?
    var perSide: Bool
    /// Suggested starting load, e.g. "25 lb" or "bodyweight". Display only; logs carry real numbers.
    var load: String?
    /// Rest between sets, seconds.
    var rest: Int?
    var why: String
    /// Where you should feel it + how to engage. Shown on demand ("Where should I feel this?").
    var feel: String
    var videoURL: String?
    /// IDs or names of acceptable substitutions.
    var swaps: [String]
    /// Included in the short (low-energy) version of the block.
    var inShortVersion: Bool
    /// Log numeric sets (weights/holds) instead of a plain tick.
    var logged: Bool

    var prescription: String {
        let base: String
        if let s = seconds {
            base = "\(sets) × \(s)s"
        } else if let r = reps {
            base = "\(sets) × \(r)"
        } else {
            base = "\(sets) sets"
        }
        return perSide ? base + " / side" : base
    }
}

enum BlockKind: String, Codable {
    case morning, desk, gym, evening
}

struct Block: Codable, Identifiable, Hashable {
    var id: String
    var kind: BlockKind
    var title: String
    var minutes: Int
    var audio: Bool
    var note: String?
    var exercises: [Exercise]
}

struct GymDay: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    /// The plot: what this day is building toward.
    var goalThread: String
    var lifts: [Exercise]
}

struct TrainingPlan: Codable {
    var id: String
    var name: String
    var version: String
    var coachNote: String
    var morning: Block
    var desk: Block
    var gymDays: [GymDay]
    var defaultGymDaysPerWeek: Int
}

// MARK: - Settings (intake output)

enum PushLevel: String, Codable, CaseIterable {
    case quiet = "Stay quiet"
    case gentle = "Gentle nudges"
    case push = "Really push me"
}

enum CoachTone: String, Codable, CaseIterable {
    case calm = "Calm & clinical"
    case warm = "Warm & encouraging"
    case minimal = "Blunt & minimal"
}

struct AppSettings: Codable {
    var intakeDone: Bool = false
    var displayName: String = ""
    /// 1 = Sunday ... 7 = Saturday (Calendar.weekday)
    var gymWeekdays: [Int] = [2, 4, 6, 7]
    var pushLevel: PushLevel = .quiet
    var tone: CoachTone = .calm
    var cycleAware: Bool = true
    var autoAdvance: Bool = true
    var eveningCheckInEnabled: Bool = true
    var morningMinutesTarget: Int = 10
    var homeEquipment: [String] = []
    var gymEquipment: [String] = []
}

// MARK: - Logs

/// Date key in local time, "yyyy-MM-dd". Never derived from toISOString-style UTC.
enum DayKey {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func key(for date: Date) -> String { formatter.string(from: date) }
    static func date(from key: String) -> Date? { formatter.date(from: key) }
}

struct SetEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var weight: Double?
    var reps: Int?
    var seconds: Int?
}

struct ExerciseLog: Codable, Identifiable {
    var id: UUID = UUID()
    var dayKey: String
    var exerciseID: String
    var exerciseName: String
    var entries: [SetEntry]
    var swappedFrom: String?
}

struct BlockCompletion: Codable, Identifiable {
    var id: UUID = UUID()
    var dayKey: String
    var blockID: String
    var completedAt: Date
    var shortVersion: Bool
}

struct CheckIn: Codable, Identifiable {
    var id: UUID = UUID()
    var dayKey: String
    var tension: Int?
    var periodStart: Bool
    var note: String
}

/// External activity (a run, a class) with the post-activity answers that let the plan adapt.
struct ActivityEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var dayKey: String
    var kind: String
    var focus: String
    var intensity: Int // 1-5
    var note: String
}

/// A gym day the user moved or skipped.
struct DayAdjustment: Codable, Identifiable {
    var id: UUID = UUID()
    var dayKey: String
    var action: String // "skipped" | "bumped"
    /// When bumped, the dayKey it moved to.
    var target: String?
}
