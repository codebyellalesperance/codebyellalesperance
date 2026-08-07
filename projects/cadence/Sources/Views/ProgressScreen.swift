import SwiftUI
import Charts

/// Data, not badges: exercise history, tension trend, weekly block picture.
struct ProgressScreen: View {
    @EnvironmentObject var store: AppStore

    @State private var selectedExerciseID: String?

    private var loggedExerciseIDs: [(id: String, name: String)] {
        var seen: Set<String> = []
        var out: [(String, String)] = []
        for log in store.exerciseLogs.sorted(by: { $0.dayKey > $1.dayKey }) {
            if !seen.contains(log.exerciseID) {
                seen.insert(log.exerciseID)
                out.append((log.exerciseID, log.exerciseName))
            }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SkyBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Progress")
                                .font(.hanken(36, .light))
                                .foregroundStyle(Palette.ink)
                            Text("Data, not badges")
                                .font(.hanken(13))
                                .foregroundStyle(Palette.grey)
                        }
                        .padding(.top, 8)

                        exerciseHistoryCard
                        tensionCard
                        weekCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: - Exercise history

    private var exerciseHistoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabelText("Exercise history")
            if loggedExerciseIDs.isEmpty {
                Text("Log some sets and the trends land here.")
                    .font(.hanken(13))
                    .foregroundStyle(Palette.grey)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(loggedExerciseIDs, id: \.id) { item in
                            let isOn = currentExerciseID == item.id
                            Button {
                                selectedExerciseID = item.id
                            } label: {
                                Text(item.name)
                                    .font(.hanken(12, isOn ? .medium : .regular))
                                    .foregroundStyle(isOn ? Palette.ink : Palette.grey)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 6)
                                    .overlay(
                                        Capsule().stroke(isOn ? Palette.ink : Palette.ink.opacity(0.15), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                historyChart
                historyTable
            }
        }
        .padding(16)
        .glassCard(corner: 20)
    }

    private var currentExerciseID: String? {
        selectedExerciseID ?? loggedExerciseIDs.first?.id
    }

    private struct HistoryPoint: Identifiable {
        var id: String { dayKey }
        var dayKey: String
        var best: Double
    }

    private var historyPoints: [HistoryPoint] {
        guard let id = currentExerciseID else { return [] }
        return store.history(for: id).map { log in
            let best = log.entries.map { entry -> Double in
                if let s = entry.seconds { return Double(s) }
                return entry.weight ?? 0
            }.max() ?? 0
            return HistoryPoint(dayKey: log.dayKey, best: best)
        }
    }

    private var historyChart: some View {
        Chart(historyPoints) { point in
            LineMark(x: .value("Day", point.dayKey), y: .value("Best", point.best))
                .foregroundStyle(Palette.pine)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            PointMark(x: .value("Day", point.dayKey), y: .value("Best", point.best))
                .foregroundStyle(Palette.pine)
                .symbolSize(24)
        }
        .chartXAxis(.hidden)
        .frame(height: 90)
    }

    private var historyTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(historyPoints.reversed().prefix(6))) { point in
                HStack {
                    Text(point.dayKey)
                        .font(.hanken(11))
                        .monospacedDigit()
                        .foregroundStyle(Palette.grey)
                    Spacer()
                    Text(String(format: "%g", point.best))
                        .font(.hanken(12, .medium))
                        .monospacedDigit()
                        .foregroundStyle(Palette.pine)
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.hairline.opacity(0.6)).frame(height: 0.5)
                }
            }
        }
    }

    // MARK: - Tension

    private struct TensionPoint: Identifiable {
        var id: String { dayKey }
        var dayKey: String
        var value: Int
    }

    private var tensionPoints: [TensionPoint] {
        Array(store.checkIns
            .compactMap { ci in ci.tension.map { TensionPoint(dayKey: ci.dayKey, value: $0) } }
            .sorted { $0.dayKey < $1.dayKey }
            .suffix(14))
    }

    private var tensionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabelText("Neck tension")
            Text("Should trend down. 1 = loose, 10 = locked.")
                .font(.hanken(12))
                .foregroundStyle(Palette.bone.opacity(0.6))
            if tensionPoints.isEmpty {
                Text("Evening check-ins feed this trend.")
                    .font(.hanken(13))
                    .foregroundStyle(Palette.bone.opacity(0.7))
            } else {
                Chart(tensionPoints) { point in
                    LineMark(x: .value("Day", point.dayKey), y: .value("Tension", point.value))
                        .foregroundStyle(Color(red: 0.56, green: 0.69, blue: 0.64))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartYScale(domain: 0...10)
                .chartXAxis(.hidden)
                .frame(height: 70)
            }
        }
        .padding(16)
        .foregroundStyle(Palette.bone)
        .background(RoundedRectangle(cornerRadius: 20).fill(Palette.ink.opacity(0.88)))
    }

    // MARK: - Week summary

    private var weekCard: some View {
        let cal = Calendar.current
        let last7: [Date] = (0..<7).compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }.reversed()
        return VStack(alignment: .leading, spacing: 10) {
            LabelText("Last 7 days")
            HStack(spacing: 6) {
                ForEach(last7, id: \.self) { date in
                    let ratio = PlanEngine.completionRatio(on: date, store: store)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ratio >= 1 ? Palette.pine : (ratio > 0 ? Palette.pine.opacity(0.4) : Palette.hairline))
                            .frame(height: 30)
                        Text("\(cal.component(.day, from: date))")
                            .font(.hanken(10))
                            .monospacedDigit()
                            .foregroundStyle(Palette.faint)
                    }
                }
            }
            Text("Filled = every block done. Faded = partial. That's all the scoreboard there is — no streaks.")
                .font(.hanken(11.5))
                .foregroundStyle(Palette.grey)
        }
        .padding(16)
        .glassCard(corner: 20)
    }
}
