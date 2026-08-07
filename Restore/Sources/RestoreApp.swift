import SwiftUI

@main
struct RestoreApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var health = HealthService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if store.settings.intakeDone {
                    RootView()
                } else {
                    IntakeView()
                }
            }
            .environmentObject(store)
            .environmentObject(health)
            .onAppear {
                if store.settings.intakeDone {
                    health.refresh()
                }
            }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "rectangle.grid.1x2") }
            LogView()
                .tabItem { Label("Log", systemImage: "chart.bar") }
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Palette.ink)
    }
}
