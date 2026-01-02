import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var services: AppServices
    @State private var mood: Int = 3
    @State private var energy: Int = 3
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                if let error = services.taskStore.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section("Check-in") {
                    Stepper(value: $mood, in: 1...5) { Label("Stimmung: \(mood)", systemImage: "face.smiling") }
                    Stepper(value: $energy, in: 1...5) { Label("Energie: \(energy)", systemImage: "bolt") }
                }

                Section("Top Aufgaben") {
                    if services.taskStore.isLoading {
                        ProgressView()
                    } else if services.taskStore.tasks.isEmpty {
                        Text("Keine Tasks geladen").foregroundStyle(.secondary)
                    } else {
                        ForEach(services.taskStore.tasks.prefix(3)) { task in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.headline)
                                    if let desc = task.description, desc.isEmpty == false {
                                        Text(desc)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(task.status.display)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let due = task.due {
                                        Text(due, style: .date)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                StatusBadge(status: task.status)
                            }
                        }
                    }
                }

                Section("Gewohnheiten") {
                    if let error = services.habitStore.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    if services.habitStore.isLoading {
                        ProgressView()
                    } else if services.habitStore.habits.isEmpty {
                        Text("Keine Gewohnheiten").foregroundStyle(.secondary)
                    } else {
                        ForEach(services.habitStore.habits) { habit in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(habit.title)
                                    Text("\(habit.cadence) • Streak \(habit.streak ?? 0)")
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
            }
            .navigationTitle("Heute")
            .task {
                if services.taskStore.tasks.isEmpty {
                    await services.taskStore.loadTasks()
                }
                if services.habitStore.habits.isEmpty {
                    await services.habitStore.loadHabits()
                }
            }
            .refreshable {
                await services.taskStore.loadTasks()
                await services.habitStore.loadHabits()
            }
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
    let status: RemoteTask.Status

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
