import SwiftUI

/// Twenty seconds: tension, cycle event, one-line note. Optional by setting.
struct CheckInSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var tension: Int?
    @State private var periodStart = false
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Palette.hairline)
                .frame(width: 32, height: 3)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            HStack(alignment: .lastTextBaseline) {
                Text("Evening check-in")
                    .font(.hanken(24, .light))
                    .foregroundStyle(Palette.ink)
                Spacer()
                RxText("20 sec")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Neck tension")
                    .font(.hanken(13.5))
                    .foregroundStyle(Palette.ink)
                Text("1 = loose, 10 = locked")
                    .font(.hanken(11.5))
                    .foregroundStyle(Palette.faint)
                HStack(spacing: 4) {
                    ForEach(1...10, id: \.self) { n in
                        Button {
                            tension = n
                        } label: {
                            Text("\(n)")
                                .font(.hanken(12, tension == n ? .medium : .light))
                                .foregroundStyle(tension == n ? Palette.bone : Palette.grey)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(tension == n ? Palette.ink : Color.clear)
                                )
                                .overlay(
                                    Capsule().stroke(tension == n ? Palette.ink : Palette.ink.opacity(0.18), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Toggle(isOn: $periodStart) {
                Text("Period started today?")
                    .font(.hanken(13.5))
                    .foregroundStyle(Palette.ink)
            }
            .tint(Palette.pine)

            VStack(alignment: .leading, spacing: 6) {
                Text("Note")
                    .font(.hanken(13.5))
                    .foregroundStyle(Palette.ink)
                TextField("optional — one line", text: $note)
                    .font(.hanken(14))
            }

            Button {
                store.saveCheckIn(tension: tension, periodStart: periodStart, note: note, on: date)
                dismiss()
            } label: {
                Text("Save")
                    .font(.hanken(15, .medium))
                    .foregroundStyle(Palette.bone)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Palette.ink))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 22)
        .background(Palette.bone)
        .onAppear {
            if let existing = store.checkIn(on: date) {
                tension = existing.tension
                periodStart = existing.periodStart
                note = existing.note
            }
        }
    }
}
