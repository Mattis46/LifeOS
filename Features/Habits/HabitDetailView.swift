import SwiftUI

struct HabitDetailView: View {
    @EnvironmentObject private var services: AppServices
    @Environment(\.dismiss) private var dismiss
    let habit: RemoteHabit

    @State private var title: String
    @State private var cadence: String
    @State private var streak: Int
    @State private var selectedGoalId: UUID?
    @State private var selectedCategoryId: UUID?

    init(habit: RemoteHabit) {
        self.habit = habit
        _title = State(initialValue: habit.title)
        _cadence = State(initialValue: habit.cadence)
        _streak = State(initialValue: habit.streak ?? 0)
        _selectedGoalId = State(initialValue: habit.goalId)
        _selectedCategoryId = State(initialValue: habit.categoryId)
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Titel", text: $title)
                TextField("Cadence", text: $cadence)
                Stepper("Streak \(streak)", value: $streak, in: 0...10_000)
            }
            Section("Ziel / Kategorie") {
                Picker("Ziel", selection: $selectedGoalId) {
                    Text("Kein Ziel").tag(UUID?.none)
                    ForEach(services.goalStore.goals, id: \.id) { goal in
                        Text(goal.title).tag(goal.id)
                    }
                }
                Picker("Kategorie", selection: $selectedCategoryId) {
                    Text("Keine Kategorie").tag(UUID?.none)
                    ForEach(services.categoryStore.categories, id: \.id) { cat in
                        Text(cat.name).tag(cat.id)
                    }
                }
            }
        }
        .navigationTitle("Gewohnheit")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { save() }
            }
        }
        .task {
            if services.goalStore.goals.isEmpty { await services.goalStore.loadGoals() }
            if services.categoryStore.categories.isEmpty { await services.categoryStore.loadCategories() }
        }
        .onDisappear {
            Task { await services.habitStore.loadHabits() }
        }
    }

    private func save() {
        guard let id = habit.id else { return }
        let updated = RemoteHabit(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            cadence: cadence.trimmingCharacters(in: .whitespacesAndNewlines),
            streak: streak,
            goalId: selectedGoalId,
            categoryId: selectedCategoryId
        )
        Task {
            await services.habitStore.updateHabit(updated)
            dismiss()
        }
    }
}
