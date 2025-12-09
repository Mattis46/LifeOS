import SwiftUI

struct PlannerView: View {
    private let tasks = SampleData.tasks
    private let habits = SampleData.habits
    private let goals = SampleData.goals

    var body: some View {
        NavigationStack {
            List {
                Section("Aufgaben") {
                    ForEach(tasks) { task in
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
                            PlannerStatusBadge(status: task.status)
                        }
                    }
                    Button {
                        // Add task
                    } label: {
                        Label("Aufgabe hinzufügen", systemImage: "plus")
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
                            Image(systemName: "checkmark.circle")
                        }
                    }
                    NavigationLink {
                        HabitsView()
                    } label: {
                        Label("Alle Gewohnheiten verwalten", systemImage: "slider.horizontal.3")
                    }
                }

                Section("Ziele") {
                    ForEach(goals) { goal in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.title)
                                .font(.headline)
                            Text(goal.horizon.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        GoalsView()
                    } label: {
                        Label("Ziele bearbeiten", systemImage: "slider.horizontal.2.square")
                    }
                }

                Section("Journal & Reflexion") {
                    NavigationLink {
                        JournalView()
                    } label: {
                        Label("Journal öffnen", systemImage: "book.closed")
                    }
                }
            }
            .navigationTitle("Planer")
        }
    }
}

private struct PlannerStatusBadge: View {
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
