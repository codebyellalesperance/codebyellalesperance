import Foundation
import HealthKit

struct HealthSnapshot {
    var sleepHours: Double?
    var stepsToday: Int?
    var lastCycleStartFromHealth: Date?
    var latestWorkoutYesterday: String?
}

/// Read-only HealthKit access. Every read is optional: denial or absence
/// degrades to nil and the app carries on.
final class HealthService: ObservableObject {
    static let shared = HealthService()
    private let store = HKHealthStore()

    @Published var snapshot = HealthSnapshot()
    @Published var authorized = false

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let flow = HKObjectType.categoryType(forIdentifier: .menstrualFlow) { types.insert(flow) }
        if let energy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) { types.insert(energy) }
        if let protein = HKObjectType.quantityType(forIdentifier: .dietaryProtein) { types.insert(protein) }
        return types
    }

    func requestAuthorization() {
        guard isAvailable else { return }
        store.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.authorized = success
                if success { self?.refresh() }
            }
        }
    }

    func refresh() {
        guard isAvailable else { return }
        fetchSleep()
        fetchSteps()
        fetchCycleStart()
        fetchYesterdayWorkout()
    }

    // MARK: - Queries

    private func fetchSleep() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .hour, value: -18, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
            let asleepSeconds = (samples as? [HKCategorySample] ?? [])
                .filter { sample in
                    HKCategoryValueSleepAnalysis.allAsleepValues
                        .map { $0.rawValue }
                        .contains(sample.value)
                }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            DispatchQueue.main.async {
                self?.snapshot.sleepHours = asleepSeconds > 0 ? asleepSeconds / 3600.0 : nil
            }
        }
        store.execute(query)
    }

    private func fetchSteps() {
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { [weak self] _, stats, _ in
            let count = stats?.sumQuantity()?.doubleValue(for: HKUnit.count())
            DispatchQueue.main.async {
                self?.snapshot.stepsToday = count.map { Int($0) }
            }
        }
        store.execute(query)
    }

    private func fetchCycleStart() {
        guard let flowType = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return }
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: flowType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            let flowSamples = (samples as? [HKCategorySample] ?? [])
                .filter { $0.value != HKCategoryValueVaginalBleeding.none.rawValue }
            // Cycle start = first flow day after a gap of 7+ days.
            var lastStart: Date?
            var previousEnd: Date?
            for sample in flowSamples {
                if let prev = previousEnd {
                    let gap = cal.dateComponents([.day], from: prev, to: sample.startDate).day ?? 0
                    if gap >= 7 { lastStart = sample.startDate }
                } else {
                    lastStart = sample.startDate
                }
                previousEnd = sample.endDate
            }
            DispatchQueue.main.async {
                self?.snapshot.lastCycleStartFromHealth = lastStart
            }
        }
        store.execute(query)
    }

    private func fetchYesterdayWorkout() {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: yesterdayStart, end: todayStart, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                                  limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            let workout = (samples as? [HKWorkout])?.first
            DispatchQueue.main.async {
                self?.snapshot.latestWorkoutYesterday = workout.map { Self.name(for: $0.workoutActivityType) }
            }
        }
        store.execute(query)
    }

    private static func name(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "run"
        case .walking: return "walk"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "strength session"
        case .pilates: return "Pilates class"
        case .yoga: return "yoga"
        case .cycling: return "ride"
        default: return "workout"
        }
    }
}
