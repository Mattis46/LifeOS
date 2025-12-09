import SwiftUI

struct GoalDetailView: View {
    @EnvironmentObject private var services: AppServices
    @Environment(\.dismiss) private var dismiss
    let goal: RemoteGoal

    @State private var title: String
    @State private var notes: String
    @State private var horizon: RemoteGoal.Horizon

    init(goal: RemoteGoal) {
        self.goal = goal
        _title = State(initialValue: goal.title)
        _notes = State(initialValue: goal.notes ?? "")
        _horizon = State(initialValue: goal.horizon)
    }

    var body: some View {
        Form {
            Section("Titel") {
                TextField("Titel", text: $title)
            }
            Section("Zeitraum") {
                Picker("Horizon", selection: $horizon) {
                    ForEach(RemoteGoal.Horizon.allCases, id: \.self) { h in
                        Text(label(for: h)).tag(h)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Notizen") {
                TextField("Notizen", text: $notes, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }
        }
        .navigationTitle("Ziel")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { save() }
            }
        }
        .onDisappear {
            Task { await services.goalStore.loadGoals() }
        }
    }

    private func save() {
        guard let id = goal.id else { return }
        let updated = RemoteGoal(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            horizon: horizon,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Task {
            await services.goalStore.updateGoal(updated)
            dismiss()
        }
    }

    private func label(for horizon: RemoteGoal.Horizon) -> String {
        switch horizon {
        case .short: return "Kurz"
        case .mid: return "Mittel"
        case .long: return "Lang"
        }
    }
}
