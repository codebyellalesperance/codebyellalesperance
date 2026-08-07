import SwiftUI

/// The hands-free audio player: big ring, spoken cues, auto-advance.
struct BlockPlayerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coach = AudioCoach()

    let block: Block
    let date: Date

    @State private var started = false
    @State private var shortVersion = false

    var body: some View {
        ZStack {
            SkyBackground()
            VStack(spacing: 0) {
                if !started {
                    preRoll
                } else if coach.finished {
                    doneView
                } else {
                    playerView
                }
            }
            .padding(.horizontal, 22)
        }
        .navigationTitle(block.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { coach.stop() }
    }

    // MARK: - Pre-roll

    private var preRoll: some View {
        VStack(spacing: 18) {
            Spacer()
            LabelText(block.title)
            Text("\(block.exercises.count) exercises · about \(block.minutes) min")
                .font(.hanken(15))
                .foregroundStyle(Palette.grey)
            if let note = block.note {
                Text(note)
                    .font(.hanken(13))
                    .foregroundStyle(Palette.clay)
                    .multilineTextAlignment(.center)
            }
            if block.audio {
                Button {
                    started = true
                    coach.start(block: block, autoAdvance: store.settings.autoAdvance, shortVersion: shortVersion)
                } label: {
                    Text(shortVersion ? "Start short version" : "Start")
                        .font(.hanken(15, .medium))
                        .foregroundStyle(Palette.bone)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(Palette.ink))
                }
                .buttonStyle(.plain)
                Toggle(isOn: $shortVersion) {
                    Text("Low-energy short version")
                        .font(.hanken(13))
                        .foregroundStyle(Palette.grey)
                }
                .tint(Palette.pine)
                .padding(.horizontal, 4)
                Text("Phone can stay face-down — audio carries the block.")
                    .font(.hanken(11, .medium))
                    .kerning(1.2)
                    .foregroundStyle(Palette.faint)
                    .multilineTextAlignment(.center)
            } else {
                checklistView
            }
            Spacer()
        }
        .padding(20)
        .glassCard(corner: 24)
        .padding(.vertical, 30)
    }

    /// Silent blocks (desk resets) are a simple tick list.
    private var checklistView: some View {
        VStack(spacing: 8) {
            ForEach(block.exercises) { ex in
                ExerciseChecklistRow(exercise: ex)
            }
            Button {
                store.completeBlock(block.id, on: date)
                dismiss()
            } label: {
                Text("Mark block done")
                    .font(.hanken(15, .medium))
                    .foregroundStyle(Palette.bone)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Palette.ink))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: - Player

    private var playerView: some View {
        VStack(spacing: 14) {
            Spacer()
            LabelText(block.title)
            ZStack {
                Circle()
                    .stroke(Palette.ink.opacity(0.08), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: coach.progress)
                    .stroke(Palette.pine, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(coach.remaining)")
                    .font(.hanken(54, .ultraLight))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            .frame(width: 190, height: 190)
            .padding(.vertical, 10)

            Text(coach.currentExercise?.name ?? "")
                .font(.hanken(23, .light))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            Text(coach.currentLabel.uppercased())
                .font(.hanken(12, .medium))
                .kerning(1.4)
                .foregroundStyle(Palette.clay)

            if let next = coach.nextExerciseName {
                Text("Next · \(next)")
                    .font(.hanken(13))
                    .foregroundStyle(Palette.grey)
                    .padding(.top, 6)
            }

            if coach.waitingForTap {
                Button {
                    coach.tapToContinue()
                } label: {
                    Text("Ready — next exercise")
                        .font(.hanken(14, .medium))
                        .foregroundStyle(Palette.bone)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Palette.ink))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            } else {
                controls
            }
            Spacer()
        }
        .onChange(of: coach.finished) { _, finished in
            if finished {
                store.completeBlock(block.id, on: date, short: shortVersion)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            ControlCircle(symbol: "arrow.counterclockwise", size: 44) { coach.repeatSegment() }
            ControlCircle(symbol: coach.isPaused ? "play.fill" : "pause", size: 56) { coach.togglePause() }
            ControlCircle(symbol: "forward.end", size: 44) { coach.skip() }
        }
        .padding(.top, 14)
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(Palette.pine)
            Text("Done — \(block.title.lowercased()) complete.")
                .font(.hanken(19, .light))
                .foregroundStyle(Palette.ink)
            Button {
                dismiss()
            } label: {
                Text("Back to today")
                    .font(.hanken(14, .medium))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(Capsule().stroke(Palette.ink, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }
}

struct ControlCircle: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.32, weight: .light))
                .foregroundStyle(Palette.ink)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(0.4)))
                .overlay(Circle().stroke(Palette.ink.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Row used in silent (desk) blocks + anywhere a plain tick list is needed.
struct ExerciseChecklistRow: View {
    let exercise: Exercise
    @State private var done = false
    @State private var showFeel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 11) {
                Circle()
                    .fill(done ? Palette.pine : Color.white)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(done ? Palette.pine : Palette.faint, lineWidth: 1.2))
                    .overlay {
                        if done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                Text(exercise.name)
                    .font(.hanken(14, .medium))
                    .foregroundStyle(done ? Palette.grey : Palette.ink)
                Spacer()
                RxText(exercise.prescription)
            }
            .contentShape(Rectangle())
            .onTapGesture { done.toggle() }

            Button {
                showFeel.toggle()
            } label: {
                Text("Where should I feel this?")
                    .font(.hanken(11))
                    .foregroundStyle(Palette.faint)
                    .underline()
            }
            .buttonStyle(.plain)

            if showFeel {
                Text(exercise.feel)
                    .font(.hanken(13))
                    .foregroundStyle(Palette.grey)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Palette.hairline).frame(width: 1)
                    }
            }
        }
        .padding(.vertical, 6)
    }
}
