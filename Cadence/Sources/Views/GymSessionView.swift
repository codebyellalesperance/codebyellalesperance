import SwiftUI

/// The gym session: goal-threaded lifts, last-session comparison,
/// minimal-tap set logging, automatic rest timer, feel-check + swap.
struct GymSessionView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let gymDay: GymDay
    let date: Date

    @State private var openLiftID: String?

    private var lifts: [Exercise] {
        PlanEngine.applySwaps(gymDay.lifts, on: date, store: store)
    }

    private var completedCount: Int {
        lifts.filter { lift in
            store.exerciseLogs.contains { $0.dayKey == DayKey.key(for: date) && $0.exerciseID == lift.id }
        }.count
    }

    var body: some View {
        ZStack {
            SkyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    ForEach(lifts) { lift in
                        LiftCard(lift: lift,
                                 date: date,
                                 isOpen: openLiftID == lift.id,
                                 onToggle: {
                                     openLiftID = (openLiftID == lift.id) ? nil : lift.id
                                 })
                    }
                    completeButton
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(gymDay.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(gymDay.goalThread)
                .font(.hanken(13))
                .foregroundStyle(Palette.grey)
            Text("\(completedCount) / \(lifts.count) lifts logged")
                .font(.hanken(12))
                .foregroundStyle(Palette.faint)
        }
        .padding(.top, 8)
    }

    private var completeButton: some View {
        Button {
            store.completeBlock("gym-\(gymDay.id)", on: date)
            dismiss()
        } label: {
            Text("Finish session")
                .font(.hanken(15, .medium))
                .foregroundStyle(Palette.bone)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(Palette.ink))
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
    }
}

// MARK: - Lift card

struct LiftCard: View {
    @EnvironmentObject var store: AppStore
    let lift: Exercise
    let date: Date
    let isOpen: Bool
    let onToggle: () -> Void

    @State private var entries: [SetEntry] = []
    @State private var restRemaining: Int = 0
    @State private var restTimer: Timer?
    @State private var showFeel = false
    @State private var showSwap = false

    private var logged: Bool {
        store.exerciseLogs.contains { $0.dayKey == DayKey.key(for: date) && $0.exerciseID == lift.id }
    }

    private var lastLog: ExerciseLog? {
        store.lastLog(for: lift.id, before: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(logged ? Palette.pine : Color.white)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(logged ? Palette.pine : Palette.faint, lineWidth: 1.2))
                        .overlay {
                            if logged {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lift.name)
                            .font(.hanken(14.5, .medium))
                            .foregroundStyle(logged ? Palette.grey : Palette.ink)
                        Text("→ \(lift.why)")
                            .font(.hanken(11.5))
                            .foregroundStyle(Palette.clay)
                            .lineLimit(isOpen ? nil : 1)
                    }
                    Spacer()
                    RxText(lift.prescription)
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                openBody
            }
        }
        .padding(14)
        .glassCard()
        .onAppear { seedEntries() }
        .onDisappear { restTimer?.invalidate() }
    }

    private var openBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, 8)

            ForEach(entries.indices, id: \.self) { i in
                SetRow(index: i,
                       entry: $entries[i],
                       timed: lift.seconds != nil,
                       last: lastEntry(at: i)) {
                    startRest()
                }
            }

            if restRemaining > 0 {
                HStack {
                    Text("REST")
                        .font(.hanken(10, .medium))
                        .kerning(1.4)
                        .foregroundStyle(Palette.bone.opacity(0.7))
                    Spacer()
                    Text(restString)
                        .font(.hanken(17, .light))
                        .monospacedDigit()
                        .foregroundStyle(Palette.bone)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.ink.opacity(0.85)))
            }

            HStack(spacing: 16) {
                Button("Where should I feel this?") { showFeel.toggle() }
                    .font(.hanken(12))
                    .foregroundStyle(Palette.grey)
                    .buttonStyle(.plain)
                if !lift.swaps.isEmpty {
                    Button("Swap exercise") { showSwap = true }
                        .font(.hanken(12))
                        .foregroundStyle(Palette.clay)
                        .buttonStyle(.plain)
                }
                Spacer()
                if let urlString = lift.videoURL, let url = URL(string: urlString) {
                    Link("Video", destination: url)
                        .font(.hanken(12, .medium))
                        .foregroundStyle(Palette.pine)
                }
            }
            .padding(.top, 4)

            if showFeel {
                Text(lift.feel)
                    .font(.hanken(13))
                    .foregroundStyle(Palette.grey)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Palette.hairline).frame(width: 1)
                    }
            }

            Button {
                store.logExercise(lift, entries: entries.filter { $0.weight != nil || $0.reps != nil || $0.seconds != nil }, on: date)
            } label: {
                Text(logged ? "Update log" : "Save sets")
                    .font(.hanken(13, .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().stroke(Palette.ink, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .confirmationDialog("Swap for today", isPresented: $showSwap, titleVisibility: .visible) {
            ForEach(lift.swaps, id: \.self) { swapID in
                if let target = PlanEngine.allExercises(in: store.plan).first(where: { $0.id == swapID }) {
                    Button(target.name) {
                        store.swapExercise(original: lift, replacementID: swapID, on: date)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var restString: String {
        String(format: "%d:%02d", restRemaining / 60, restRemaining % 60)
    }

    private func seedEntries() {
        guard entries.isEmpty else { return }
        let existing = store.exerciseLogs.first {
            $0.dayKey == DayKey.key(for: date) && $0.exerciseID == lift.id
        }
        if let existing, !existing.entries.isEmpty {
            entries = existing.entries
        } else {
            entries = (0..<max(lift.sets, 1)).map { _ in SetEntry() }
        }
    }

    private func lastEntry(at index: Int) -> SetEntry? {
        guard let last = lastLog, index < last.entries.count else { return nil }
        return last.entries[index]
    }

    private func startRest() {
        guard let rest = lift.rest, rest > 0 else { return }
        restTimer?.invalidate()
        restRemaining = rest
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                if restRemaining > 1 {
                    restRemaining -= 1
                } else {
                    restRemaining = 0
                    timer.invalidate()
                }
            }
        }
    }
}

// MARK: - Set row

struct SetRow: View {
    let index: Int
    @Binding var entry: SetEntry
    let timed: Bool
    let last: SetEntry?
    var onLogged: () -> Void

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var secondsText = ""

    var body: some View {
        HStack(spacing: 12) {
            Text("SET \(index + 1)")
                .font(.hanken(10, .medium))
                .kerning(1.2)
                .foregroundStyle(Palette.faint)
                .frame(width: 46, alignment: .leading)

            Text(lastString)
                .font(.hanken(12))
                .monospacedDigit()
                .foregroundStyle(Palette.faint)
                .frame(width: 76, alignment: .leading)

            if timed {
                TextField("sec", text: $secondsText)
                    .keyboardType(.numberPad)
                    .font(.hanken(15))
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField("lb", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.hanken(15))
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
                Text("×")
                    .font(.hanken(13))
                    .foregroundStyle(Palette.faint)
                TextField("reps", text: $repsText)
                    .keyboardType(.numberPad)
                    .font(.hanken(15))
                    .frame(width: 56)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            Button {
                commit()
                onLogged()
            } label: {
                Image(systemName: entryHasData ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(entryHasData ? Palette.pine : Palette.faint)
            }
            .buttonStyle(.plain)
        }
        .onAppear { hydrate() }
    }

    private var entryHasData: Bool {
        entry.weight != nil || entry.reps != nil || entry.seconds != nil
    }

    private var lastString: String {
        guard let last else { return "—" }
        if let s = last.seconds { return "last \(s)s" }
        let w = last.weight.map { String(format: "%g", $0) } ?? "—"
        let r = last.reps.map { "\($0)" } ?? "—"
        return "last \(w)×\(r)"
    }

    private func hydrate() {
        if let w = entry.weight { weightText = String(format: "%g", w) }
        if let r = entry.reps { repsText = "\(r)" }
        if let s = entry.seconds { secondsText = "\(s)" }
    }

    private func commit() {
        entry.weight = Double(weightText)
        entry.reps = Int(repsText)
        entry.seconds = Int(secondsText)
    }
}
