import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthService

    @State private var showImport = false
    @State private var importText = ""
    @State private var importFailed = false
    @State private var showClearConfirm1 = false
    @State private var showClearConfirm2 = false
    @State private var copied = false

    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Coaching") {
                    Picker("Push level", selection: $store.settings.pushLevel) {
                        ForEach(PushLevel.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    Picker("Tone", selection: $store.settings.tone) {
                        ForEach(CoachTone.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    Toggle("Audio auto-advance", isOn: $store.settings.autoAdvance)
                    Toggle("Evening check-in", isOn: $store.settings.eveningCheckInEnabled)
                    Toggle("Cycle-aware training", isOn: $store.settings.cycleAware)
                }

                Section("Schedule") {
                    HStack {
                        ForEach(1...7, id: \.self) { weekday in
                            let on = store.settings.gymWeekdays.contains(weekday)
                            Button {
                                if on {
                                    store.settings.gymWeekdays.removeAll { $0 == weekday }
                                } else {
                                    store.settings.gymWeekdays.append(weekday)
                                }
                                store.saveAll()
                            } label: {
                                Text(weekdayNames[weekday - 1])
                                    .font(.hanken(11, on ? .medium : .regular))
                                    .foregroundStyle(on ? Palette.bone : Palette.grey)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(on ? Palette.ink : Color.clear))
                                    .overlay(Capsule().stroke(Palette.ink.opacity(on ? 0 : 0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Stepper("Morning block target: \(store.settings.morningMinutesTarget) min",
                            value: $store.settings.morningMinutesTarget, in: 5...30, step: 5)
                }

                Section("Apple Health") {
                    if health.isAvailable {
                        Button(health.authorized ? "Connected — refresh" : "Connect Apple Health") {
                            if health.authorized { health.refresh() } else { health.requestAuthorization() }
                        }
                        if let sleep = health.snapshot.sleepHours {
                            LabeledContent("Last night", value: String(format: "%.1f h sleep", sleep))
                        }
                        if let steps = health.snapshot.stepsToday {
                            LabeledContent("Steps today", value: "\(steps)")
                        }
                    } else {
                        Text("Health data not available on this device.")
                    }
                }

                Section("Plan") {
                    LabeledContent("Active plan", value: store.plan.name)
                    LabeledContent("Version", value: store.plan.version)
                    Button(copied ? "Copied ✓" : "Export plan (copy JSON)") {
                        UIPasteboard.general.string = store.exportPlanJSON()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }
                    Button("Import plan (paste JSON)") {
                        importText = ""
                        showImport = true
                    }
                    Button("Export full log history") {
                        UIPasteboard.general.string = store.exportLogsJSON()
                    }
                    Text("Paste a Claude-generated plan here when it's time for the next phase.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Clear all data", role: .destructive) {
                        showClearConfirm1 = true
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: store.settings.pushLevel) { store.saveAll() }
            .onChange(of: store.settings.tone) { store.saveAll() }
            .onChange(of: store.settings.autoAdvance) { store.saveAll() }
            .onChange(of: store.settings.eveningCheckInEnabled) { store.saveAll() }
            .onChange(of: store.settings.cycleAware) { store.saveAll() }
            .onChange(of: store.settings.morningMinutesTarget) { store.saveAll() }
            .sheet(isPresented: $showImport) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Paste a plan JSON below. It replaces the active plan; logs are kept.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $importText)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(minHeight: 260)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        if importFailed {
                            Text("That JSON didn't validate as a plan. Nothing was changed.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Import plan")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Import") {
                                if store.importPlanJSON(importText) {
                                    importFailed = false
                                    showImport = false
                                } else {
                                    importFailed = true
                                }
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showImport = false }
                        }
                    }
                }
            }
            .alert("Clear all data?", isPresented: $showClearConfirm1) {
                Button("Continue", role: .destructive) { showClearConfirm2 = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Logs, check-ins, settings and the plan all reset.")
            }
            .alert("Really clear everything?", isPresented: $showClearConfirm2) {
                Button("Clear everything", role: .destructive) { store.clearAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}
