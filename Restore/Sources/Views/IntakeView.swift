import SwiftUI

/// First-run intake: the questionnaire that shapes the app's behavior.
/// (Plan *content* comes from the config; this configures delivery.)
struct IntakeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthService

    @State private var step = 0
    @State private var name = ""
    @State private var gymDays: Set<Int> = [2, 4, 6, 7]
    @State private var morningMinutes = 10
    @State private var pushLevel: PushLevel = .quiet
    @State private var tone: CoachTone = .calm
    @State private var cycleAware = true

    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let totalSteps = 5

    var body: some View {
        ZStack {
            SkyBackground()
            VStack(alignment: .leading, spacing: 22) {
                LabelText("Restore · Setup \(step + 1) of \(totalSteps)")
                    .padding(.top, 30)

                Group {
                    switch step {
                    case 0: nameStep
                    case 1: scheduleStep
                    case 2: coachingStep
                    case 3: cycleStep
                    default: healthStep
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .font(.hanken(14))
                            .foregroundStyle(Palette.grey)
                            .buttonStyle(.plain)
                    }
                    Spacer()
                    Button {
                        if step < totalSteps - 1 {
                            step += 1
                        } else {
                            finish()
                        }
                    } label: {
                        Text(step < totalSteps - 1 ? "Next" : "Start")
                            .font(.hanken(15, .medium))
                            .foregroundStyle(Palette.bone)
                            .padding(.horizontal, 34)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(Palette.ink))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 24)
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A calming trainer\nwho understands you.")
                .font(.hanken(32, .light))
                .foregroundStyle(Palette.ink)
            Text("A few questions shape how the app behaves. Your program itself is data — built with Claude, imported in Settings whenever it evolves.")
                .font(.hanken(14))
                .foregroundStyle(Palette.grey)
            TextField("What should it call you?", text: $name)
                .font(.hanken(18, .light))
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
        }
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("When does the gym\nactually happen?")
                .font(.hanken(30, .light))
                .foregroundStyle(Palette.ink)
            Text("Anchor days — movable and skippable in the moment, always guilt-free.")
                .font(.hanken(14))
                .foregroundStyle(Palette.grey)
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { weekday in
                    let on = gymDays.contains(weekday)
                    Button {
                        if on { gymDays.remove(weekday) } else { gymDays.insert(weekday) }
                    } label: {
                        Text(weekdayNames[weekday - 1])
                            .font(.hanken(12, on ? .medium : .regular))
                            .foregroundStyle(on ? Palette.bone : Palette.grey)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(on ? Palette.ink : Color.white.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                }
            }
            Stepper("Morning block: about \(morningMinutes) min",
                    value: $morningMinutes, in: 5...30, step: 5)
                .font(.hanken(14))
        }
    }

    private var coachingStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How are you\nbest coached?")
                .font(.hanken(30, .light))
                .foregroundStyle(Palette.ink)
            VStack(alignment: .leading, spacing: 10) {
                LabelText("Push level")
                ForEach(PushLevel.allCases, id: \.self) { level in
                    ChoiceRow(text: level.rawValue, selected: pushLevel == level) { pushLevel = level }
                }
                LabelText("Tone")
                    .padding(.top, 8)
                ForEach(CoachTone.allCases, id: \.self) { t in
                    ChoiceRow(text: t.rawValue, selected: tone == t) { tone = t }
                }
            }
        }
    }

    private var cycleStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Train with\nyour cycle?")
                .font(.hanken(30, .light))
                .foregroundStyle(Palette.ink)
            Text("When on, the app reads cycle data (Apple Health or your check-ins) and quietly tunes intensity notes to your phase. Evidence-based, suggestion-only, and it never withholds a workout.")
                .font(.hanken(14))
                .foregroundStyle(Palette.grey)
            Toggle(isOn: $cycleAware) {
                Text("Cycle-aware training")
                    .font(.hanken(15))
            }
            .tint(Palette.pine)
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Let it see\nthe whole picture.")
                .font(.hanken(30, .light))
                .foregroundStyle(Palette.ink)
            Text("Apple Health provides sleep, steps, workouts, cycle and nutrition (MyFitnessPal syncs there). Everything stays on this device. You can connect later in Settings instead.")
                .font(.hanken(14))
                .foregroundStyle(Palette.grey)
            if health.isAvailable {
                Button {
                    health.requestAuthorization()
                } label: {
                    Text(health.authorized ? "Connected ✓" : "Connect Apple Health")
                        .font(.hanken(14, .medium))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Capsule().stroke(Palette.ink, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func finish() {
        store.settings.displayName = name
        store.settings.gymWeekdays = Array(gymDays).sorted()
        store.settings.morningMinutesTarget = morningMinutes
        store.settings.pushLevel = pushLevel
        store.settings.tone = tone
        store.settings.cycleAware = cycleAware
        store.settings.intakeDone = true
        store.saveAll()
    }
}

struct ChoiceRow: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.hanken(14, selected ? .medium : .regular))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Circle()
                    .fill(selected ? Palette.pine : Color.clear)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(selected ? Palette.pine : Palette.faint, lineWidth: 1.2))
            }
            .padding(12)
            .glassCard(corner: 14)
        }
        .buttonStyle(.plain)
    }
}
