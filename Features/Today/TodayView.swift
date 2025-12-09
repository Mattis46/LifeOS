import SwiftUI

struct TodayView: View {
    @State private var mood: Int = 3
    @State private var energy: Int = 3
    @State private var showSettings = false
    private let tasks = SampleData.tasks
    private let habits = SampleData.habits

    var body: some View {
        NavigationStack {
            List {
                Section("Check-in") {
                    Stepper(value: $mood, in: 1...5) { Label("Stimmung: \(mood)", systemImage: "face.smiling") }
                    Stepper(value: $energy, in: 1...5) { Label("Energie: \(energy)", systemImage: "bolt") }
                }

                Section("Top Aufgaben") {
                    ForEach(tasks.prefix(3)) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.headline)
                                if let goal = task.goal {
                                    Text(goal.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            StatusBadge(status: task.status)
                        }
                    }
                }

                Section("Gewohnheiten") {
                    ForEach(habits) { habit in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(habit.title)
                                Text("\(habit.cadence) • Streak \(habit.streak)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                // Toggle habit completion stub
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Heute")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

private struct StatusBadge: View {
    let status: FocusTask.Status

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .open: return "Offen"
        case .inProgress: return "Läuft"
        case .done: return "Fertig"
        case .blocked: return "Blockiert"
        }
    }

    private var background: Color {
        switch status {
        case .open: return .gray.opacity(0.15)
        case .inProgress: return .blue.opacity(0.2)
        case .done: return .green.opacity(0.2)
        case .blocked: return .red.opacity(0.2)
        }
    }
}
