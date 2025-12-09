import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var services: AppServices
    @State private var showAddGoal = false
    @State private var newGoalTitle = ""
    @State private var newGoalNotes = ""
    @State private var newGoalHorizon: RemoteGoal.Horizon = .short

    var body: some View {
        NavigationStack {
            List {
                if let error = services.goalStore.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                if services.goalStore.isLoading {
                    ProgressView()
                } else if services.goalStore.goals.isEmpty {
                    Text("Keine Ziele").foregroundStyle(.secondary)
                } else {
                    ForEach(services.goalStore.goals) { goal in
                        NavigationLink {
                            GoalDetailView(goal: goal)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(goal.title)
                                    .font(.headline)
                                if let notes = goal.notes, notes.isEmpty == false {
                                    Text(notes)
                                        .foregroundStyle(.secondary)
                                }
                                Label(goal.horizon.rawValue.capitalized, systemImage: "calendar.badge.clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Ziele")
            .refreshable {
                await services.goalStore.loadGoals()
            }
            .toolbar {
                Button {
                    showAddGoal = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .task {
                if services.goalStore.goals.isEmpty {
                    await services.goalStore.loadGoals()
                }
            }
            .sheet(isPresented: $showAddGoal) {
                NavigationStack {
                    Form {
                        Section("Titel") {
                            TextField("Titel", text: $newGoalTitle)
                        }
                        Section("Horizon") {
                            Picker("Zeitraum", selection: $newGoalHorizon) {
                                ForEach(RemoteGoal.Horizon.allCases, id: \.self) { horizon in
                                    Text(label(for: horizon)).tag(horizon)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        Section("Notizen") {
                            TextField("Notizen", text: $newGoalNotes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                        }
                    }
                    .navigationTitle("Neues Ziel")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                resetGoalForm()
                                showAddGoal = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                let title = newGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                let notes = newGoalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                                Task { await services.goalStore.addGoal(title: title, horizon: newGoalHorizon, notes: notes) }
                                resetGoalForm()
                                showAddGoal = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func label(for horizon: RemoteGoal.Horizon) -> String {
        switch horizon {
        case .short: return "Kurz"
        case .mid: return "Mittel"
        case .long: return "Lang"
        }
    }

    private func resetGoalForm() {
        newGoalTitle = ""
        newGoalNotes = ""
        newGoalHorizon = .short
    }
}
