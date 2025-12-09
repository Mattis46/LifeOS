import SwiftUI

struct HabitsView: View {
    @EnvironmentObject private var services: AppServices
    @State private var showAddHabit = false
    @State private var newHabitTitle = ""
    @State private var newHabitCadence = "Daily"
    @State private var selectedGoalId: UUID?
    @State private var selectedCategoryId: UUID?
    @State private var showAddCategory = false
    @State private var newCategoryName = ""

    var body: some View {
        NavigationStack {
            List {
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
                        NavigationLink {
                            HabitDetailView(habit: habit)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(habit.title)
                                        .font(.headline)
                                    Text("\(habit.cadence) • Streak \(habit.streak ?? 0)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Gewohnheiten")
            .refreshable {
                await services.habitStore.loadHabits()
                await services.goalStore.loadGoals()
                await services.categoryStore.loadCategories()
            }
            .toolbar {
                Button {
                    showAddHabit = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .task {
                if services.habitStore.habits.isEmpty {
                    await services.habitStore.loadHabits()
                }
                if services.goalStore.goals.isEmpty {
                    await services.goalStore.loadGoals()
                }
                if services.categoryStore.categories.isEmpty {
                    await services.categoryStore.loadCategories()
                }
            }
            .alert("Neue Gewohnheit", isPresented: $showAddHabit) {
                TextField("Titel", text: $newHabitTitle)
                TextField("Cadence (z.B. Daily, Weekly)", text: $newHabitCadence)
                Picker("Ziel", selection: Binding(
                    get: { selectedGoalId ?? UUID?.none },
                    set: { selectedGoalId = $0 }
                )) {
                    Text("Kein Ziel").tag(UUID?.none)
                    ForEach(services.goalStore.goals, id: \.id) { goal in
                        Text(goal.title).tag(goal.id)
                    }
                }
                Picker("Kategorie", selection: Binding(
                    get: { selectedCategoryId ?? UUID?.none },
                    set: { selectedCategoryId = $0 }
                )) {
                    Text("Keine Kategorie").tag(UUID?.none)
                    ForEach(services.categoryStore.categories, id: \.id) { cat in
                        Text(cat.name).tag(cat.id)
                    }
                }
                Button("Kategorie hinzufügen") { showAddCategory = true }
                Button("Speichern") {
                    let title = newHabitTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        await services.habitStore.addHabit(title: title, cadence: newHabitCadence, goalId: selectedGoalId, categoryId: selectedCategoryId)
                        await services.habitStore.loadHabits()
                    }
                    resetHabitForm()
                }
                Button("Abbrechen", role: .cancel) {
                    resetHabitForm()
                }
            }
            .sheet(isPresented: $showAddCategory) {
                NavigationStack {
                    Form {
                        Section("Kategorie") {
                            TextField("Name", text: $newCategoryName)
                        }
                    }
                    .navigationTitle("Kategorie hinzufügen")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                newCategoryName = ""
                                showAddCategory = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                                Task { await services.categoryStore.addCategory(name: name) }
                                newCategoryName = ""
                                showAddCategory = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func resetHabitForm() {
        newHabitTitle = ""
        newHabitCadence = "Daily"
        selectedGoalId = nil
        selectedCategoryId = nil
    }
}
