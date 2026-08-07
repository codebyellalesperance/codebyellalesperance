import Foundation

struct Suggestion: Identifiable {
    var id: String
    var text: String
}

/// Deterministic adaptation: suggests, never forces. The v1 stand-in for the v1.5 AI brain.
enum RulesEngine {

    static func cycleDay(on date: Date, lastPeriodStart: Date?) -> Int? {
        guard let start = lastPeriodStart else { return nil }
        let days = Calendar.current.dateComponents([.day], from: start, to: date).day ?? 0
        guard days >= 0 && days < 45 else { return nil }
        return days + 1
    }

    static func cyclePhaseLabel(day: Int) -> String {
        switch day {
        case 1...5: return "menstrual"
        case 6...13: return "follicular"
        case 14...16: return "ovulatory"
        case 17...23: return "mid-luteal"
        default: return "late luteal"
        }
    }

    static func cycleNote(day: Int) -> String {
        switch day {
        case 1...5:
            return "Early cycle: go by feel. Movement helps; intensity is optional."
        case 6...13:
            return "Follicular: energy tends to run high — a good window to push."
        case 14...16:
            return "Around ovulation: strength often peaks. Warm up well."
        case 17...23:
            return "Mid-luteal: steady work. Recovery matters more this week."
        default:
            return "Late luteal: hold the loads, trim a set if fried."
        }
    }

    static func suggestions(for date: Date,
                            settings: AppSettings,
                            health: HealthSnapshot,
                            lastPeriodStart: Date?) -> [Suggestion] {
        var out: [Suggestion] = []

        if let sleep = health.sleepHours, sleep > 0, sleep < 6.0 {
            out.append(Suggestion(
                id: "sleep",
                text: String(format: "Short night (%.1f h). Short versions are one tap away — worth taking today.", sleep)))
        }

        if settings.cycleAware, let day = cycleDay(on: date, lastPeriodStart: lastPeriodStart) {
            out.append(Suggestion(id: "cycle", text: cycleNote(day: day)))
        }

        if let workout = health.latestWorkoutYesterday {
            out.append(Suggestion(
                id: "workout",
                text: "Yesterday's \(workout) is in the books — factor it into how hard today needs to be."))
        }

        return out
    }
}
