import Foundation

/// One item on the Today timeline.
struct DayItem: Identifiable {
    enum Payload {
        case block(Block)
        case gym(GymDay)
        case checkIn
    }
    var id: String
    var title: String
    var subtitle: String
    var payload: Payload
    var complete: Bool
}

/// Resolves what a given date's day looks like from plan + settings + logs.
/// Deterministic v1 rules engine — no server, no surprises.
enum PlanEngine {

    static func isWorkday(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6
    }

    /// Whether a gym session lands on this date (schedule + bumps − skips).
    static func gymScheduled(on date: Date, store: AppStore) -> Bool {
        let key = DayKey.key(for: date)
        let weekday = Calendar.current.component(.weekday, from: date)
        let adjustmentsHere = store.adjustments.filter { $0.dayKey == key }
        if adjustmentsHere.contains(where: { $0.action == "skipped" }) { return false }
        if adjustmentsHere.contains(where: { $0.action == "bumped" }) { return false }
        if store.adjustments.contains(where: { $0.action == "bumped" && $0.target == key }) { return true }
        return store.settings.gymWeekdays.contains(weekday)
    }

    /// Which gym day of the rotation comes next: count completed gym sessions, take the next.
    static func nextGymDay(for date: Date, store: AppStore) -> GymDay? {
        let days = store.plan.gymDays
        guard !days.isEmpty else { return nil }
        let key = DayKey.key(for: date)
        let completedBefore = store.completions
            .filter { $0.blockID.hasPrefix("gym-") && $0.dayKey < key }
            .count
        // If today's session is already done, show today's completed one.
        if let doneToday = store.completions.first(where: { $0.dayKey == key && $0.blockID.hasPrefix("gym-") }),
           let match = days.first(where: { "gym-\($0.id)" == doneToday.blockID }) {
            return match
        }
        return days[completedBefore % days.count]
    }

    /// Apply per-day swaps to a list of exercises.
    static func applySwaps(_ exercises: [Exercise], on date: Date, store: AppStore) -> [Exercise] {
        let key = DayKey.key(for: date)
        guard let swaps = store.daySwaps[key], !swaps.isEmpty else { return exercises }
        let all = allExercises(in: store.plan)
        return exercises.map { ex in
            guard let replacementID = swaps[ex.id],
                  let replacement = all.first(where: { $0.id == replacementID }) else { return ex }
            return replacement
        }
    }

    static func allExercises(in plan: TrainingPlan) -> [Exercise] {
        var list = plan.morning.exercises + plan.desk.exercises
        for day in plan.gymDays { list += day.lifts }
        return list
    }

    static func timeline(for date: Date, store: AppStore) -> [DayItem] {
        var items: [DayItem] = []
        let morning = store.plan.morning
        items.append(DayItem(
            id: morning.id,
            title: morning.title,
            subtitle: "\(morning.minutes) min · audio-guided",
            payload: .block(morning),
            complete: store.isBlockComplete(morning.id, on: date)))

        if isWorkday(date) {
            let desk = store.plan.desk
            items.append(DayItem(
                id: desk.id,
                title: desk.title,
                subtitle: "\(desk.exercises.count) resets · silent",
                payload: .block(desk),
                complete: store.isBlockComplete(desk.id, on: date)))
        }

        if gymScheduled(on: date, store: store), let gymDay = nextGymDay(for: date, store: store) {
            items.append(DayItem(
                id: "gym-\(gymDay.id)",
                title: "Gym — \(gymDay.title)",
                subtitle: "\(gymDay.lifts.count) lifts · logs + rest timer",
                payload: .gym(gymDay),
                complete: store.isBlockComplete("gym-\(gymDay.id)", on: date)))
        }

        if store.settings.eveningCheckInEnabled {
            items.append(DayItem(
                id: "checkin",
                title: "Evening check-in",
                subtitle: "20 seconds · tension · cycle · note",
                payload: .checkIn,
                complete: store.checkIn(on: date) != nil))
        }
        return items
    }

    /// Week-strip state: proportion of that day's items complete (0 = none, 1 = all).
    static func completionRatio(on date: Date, store: AppStore) -> Double {
        let items = timeline(for: date, store: store)
        guard !items.isEmpty else { return 0 }
        let done = items.filter { $0.complete }.count
        return Double(done) / Double(items.count)
    }
}
