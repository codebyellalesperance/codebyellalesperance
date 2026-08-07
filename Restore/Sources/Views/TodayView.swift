import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthService

    @State private var selectedDate = Date()
    @State private var showCheckIn = false
    @State private var showActivitySheet = false
    @State private var activeBlock: Block?
    @State private var activeGymDay: GymDay?

    private var lastPeriodStart: Date? {
        store.lastManualPeriodStart ?? health.snapshot.lastCycleStartFromHealth
    }

    private var cycleLine: String? {
        guard store.settings.cycleAware,
              let day = RulesEngine.cycleDay(on: selectedDate, lastPeriodStart: lastPeriodStart) else { return nil }
        return "Day \(day) — \(RulesEngine.cyclePhaseLabel(day: day))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SkyBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        suggestions
                        WeekStrip(selectedDate: $selectedDate)
                        timeline
                        addActivityButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
            .navigationDestination(item: $activeBlock) { block in
                BlockPlayerView(block: block, date: selectedDate)
            }
            .navigationDestination(item: $activeGymDay) { day in
                GymSessionView(gymDay: day, date: selectedDate)
            }
            .sheet(isPresented: $showCheckIn) {
                CheckInSheet(date: selectedDate)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showActivitySheet) {
                ActivitySheet(date: selectedDate)
                    .presentationDetents([.medium])
            }
            .onAppear { health.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline) {
                Text("Today")
                    .font(.hanken(36, .light))
                    .foregroundStyle(Palette.ink)
                Spacer()
                let items = PlanEngine.timeline(for: selectedDate, store: store)
                let done = items.filter { $0.complete }.count
                Text("\(done) / \(items.count) blocks")
                    .font(.hanken(13))
                    .foregroundStyle(Palette.grey)
            }
            Text(selectedDate.formatted(date: .abbreviated, time: .omitted)
                 + (cycleLine.map { " · \($0)" } ?? ""))
                .font(.hanken(13))
                .foregroundStyle(Palette.grey)
        }
        .padding(.top, 8)
    }

    private var suggestions: some View {
        let list = RulesEngine.suggestions(for: selectedDate,
                                           settings: store.settings,
                                           health: health.snapshot,
                                           lastPeriodStart: lastPeriodStart)
        return ForEach(list) { suggestion in
            Text(suggestion.text)
                .font(.hanken(13))
                .foregroundStyle(Palette.clay)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .glassCard(corner: 14)
        }
    }

    private var timeline: some View {
        VStack(spacing: 10) {
            ForEach(PlanEngine.timeline(for: selectedDate, store: store)) { item in
                DayItemRow(item: item) {
                    handleTap(item)
                } onSkip: {
                    if case .gym = item.payload { store.skipGym(on: selectedDate) }
                } onBump: {
                    if case .gym = item.payload,
                       let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                        store.bumpGym(from: selectedDate, to: tomorrow)
                    }
                }
            }
        }
    }

    private var addActivityButton: some View {
        Button {
            showActivitySheet = true
        } label: {
            Text("+ Add a run, class or other activity")
                .font(.hanken(13, .medium))
                .foregroundStyle(Palette.pine)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func handleTap(_ item: DayItem) {
        switch item.payload {
        case .block(let block):
            activeBlock = block
        case .gym(let day):
            activeGymDay = day
        case .checkIn:
            showCheckIn = true
        }
    }
}

// MARK: - Rows

struct DayItemRow: View {
    let item: DayItem
    var onTap: () -> Void
    var onSkip: () -> Void
    var onBump: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(item.complete ? Palette.pine : Color.white)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(item.complete ? Palette.pine : Palette.faint, lineWidth: 1.2)
                    )
                    .overlay {
                        if item.complete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.hanken(15, .medium))
                        .foregroundStyle(item.complete ? Palette.grey : Palette.ink)
                    Text(item.subtitle)
                        .font(.hanken(12))
                        .foregroundStyle(Palette.grey)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Palette.faint)
            }
            .padding(14)
            .glassCard()
        }
        .buttonStyle(.plain)
        .contextMenu {
            if case .gym = item.payload {
                Button("Move to tomorrow", action: onBump)
                Button("Skip today", role: .destructive, action: onSkip)
            }
        }
    }
}

// MARK: - Week strip

struct WeekStrip: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedDate: Date

    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        // Monday-start offset: weekday 2 = Monday.
        let offset = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -offset, to: today) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(weekDates, id: \.self) { date in
                let cal = Calendar.current
                let isToday = cal.isDateInToday(date)
                let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
                let ratio = PlanEngine.completionRatio(on: date, store: store)
                VStack(spacing: 5) {
                    Text(shortWeekday(date))
                        .font(.hanken(9, .medium))
                        .kerning(1)
                        .foregroundStyle(Palette.faint)
                    Text("\(cal.component(.day, from: date))")
                        .font(.hanken(15, isToday ? .regular : .light))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle().stroke(isSelected ? Palette.ink : .clear, lineWidth: 1)
                        )
                    Circle()
                        .fill(dotColor(date: date, ratio: ratio))
                        .frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { selectedDate = date }
            }
        }
        .padding(.vertical, 6)
    }

    private func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: date).uppercased()
    }

    private func dotColor(date: Date, ratio: Double) -> Color {
        if ratio >= 1.0 { return Palette.pine }
        if PlanEngine.gymScheduled(on: date, store: store) { return Palette.clay }
        return Palette.greyBlue.opacity(0.6)
    }
}

// MARK: - Activity sheet

struct ActivitySheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let date: Date

    @State private var kind = "Run"
    @State private var focus = ""
    @State private var intensity = 3
    @State private var note = ""

    private let kinds = ["Run", "Walk", "Workout class", "Pilates", "Yoga", "Swim", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Picker("What was it?", selection: $kind) {
                    ForEach(kinds, id: \.self) { Text($0) }
                }
                TextField("What did it focus on? (legs, full body…)", text: $focus)
                Picker("How hard was it?", selection: $intensity) {
                    ForEach(1...5, id: \.self) { level in
                        Text(["Very easy", "Easy", "Moderate", "Hard", "All out"][level - 1]).tag(level)
                    }
                }
                TextField("Anything worth noting?", text: $note)
            }
            .navigationTitle("Add activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addActivity(kind: kind, focus: focus, intensity: intensity, note: note, on: date)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
