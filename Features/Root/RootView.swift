import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Dashboard", systemImage: "sun.max") }
            PlannerView()
                .tabItem { Label("Planer", systemImage: "square.grid.2x2") }
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
            GoalsView()
                .tabItem { Label("Ziele", systemImage: "target") }
            CoachView()
                .tabItem { Label("Coach", systemImage: "sparkles") }
        }
    }
}
