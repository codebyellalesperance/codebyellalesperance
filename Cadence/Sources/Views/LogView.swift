import SwiftUI

/// Reverse-chronological record of everything: blocks, sets, activities, check-ins.
struct LogView: View {
    @EnvironmentObject var store: AppStore

    private struct LogRow: Identifiable {
        var id: String
        var dayKey: String
        var title: String
        var detail: String
        var kind: String
    }

    private var rows: [LogRow] {
        var out: [LogRow] = []
        for c in store.completions {
            out.append(LogRow(id: "c-\(c.id)", dayKey: c.dayKey,
                              title: blockName(c.blockID) + (c.shortVersion ? " · short" : ""),
                              detail: "Block complete", kind: "block"))
        }
        for l in store.exerciseLogs {
            let sets = l.entries.map { entry -> String in
                if let s = entry.seconds { return "\(s)s" }
                let w = entry.weight.map { String(format: "%g", $0) } ?? "—"
                let r = entry.reps.map { "\($0)" } ?? "—"
                return "\(w)×\(r)"
            }.joined(separator: " / ")
            out.append(LogRow(id: "l-\(l.id)", dayKey: l.dayKey,
                              title: l.exerciseName, detail: sets, kind: "lift"))
        }
        for a in store.activities {
            out.append(LogRow(id: "a-\(a.id)", dayKey: a.dayKey,
                              title: a.kind,
                              detail: [a.focus, "intensity \(a.intensity)/5"].filter { !$0.isEmpty }.joined(separator: " · "),
                              kind: "activity"))
        }
        for ci in store.checkIns {
            var bits: [String] = []
            if let t = ci.tension { bits.append("tension \(t)") }
            if ci.periodStart { bits.append("period start") }
            if !ci.note.isEmpty { bits.append(ci.note) }
            out.append(LogRow(id: "ci-\(ci.id)", dayKey: ci.dayKey,
                              title: "Check-in", detail: bits.joined(separator: " · "), kind: "checkin"))
        }
        return out.sorted { $0.dayKey > $1.dayKey }
    }

    private func blockName(_ blockID: String) -> String {
        if blockID == store.plan.morning.id { return store.plan.morning.title }
        if blockID == store.plan.desk.id { return store.plan.desk.title }
        if blockID.hasPrefix("gym-"),
           let day = store.plan.gymDays.first(where: { "gym-\($0.id)" == blockID }) {
            return "Gym — \(day.title)"
        }
        return blockID
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SkyBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Log")
                            .font(.hanken(36, .light))
                            .foregroundStyle(Palette.ink)
                            .padding(.top, 8)
                        if rows.isEmpty {
                            Text("Nothing yet. It all shows up here.")
                                .font(.hanken(14))
                                .foregroundStyle(Palette.grey)
                                .padding(.top, 20)
                        }
                        ForEach(rows) { row in
                            HStack(alignment: .top, spacing: 12) {
                                Text(row.dayKey.suffix(5))
                                    .font(.hanken(11))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.faint)
                                    .frame(width: 44, alignment: .leading)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.title)
                                        .font(.hanken(14, .medium))
                                        .foregroundStyle(Palette.ink)
                                    if !row.detail.isEmpty {
                                        Text(row.detail)
                                            .font(.hanken(12))
                                            .monospacedDigit()
                                            .foregroundStyle(Palette.grey)
                                    }
                                }
                                Spacer()
                            }
                            .padding(12)
                            .glassCard(corner: 14)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}
