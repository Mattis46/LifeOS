import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject private var services: AppServices
    @Environment(\.dismiss) private var dismiss
    let task: RemoteTask

    @State private var title: String
    @State private var description: String
    @State private var due: Date?
    @State private var includeDue: Bool
    @State private var selectedGoalId: UUID?
    @State private var selectedProjectId: UUID?
    @State private var selectedCategoryId: UUID?
    @State private var taskStatus: RemoteTask.Status

    init(task: RemoteTask) {
        self.task = task
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description ?? "")
        _due = State(initialValue: task.due)
        _includeDue = State(initialValue: task.due != nil)
        _selectedGoalId = State(initialValue: task.goalId)
        _selectedProjectId = State(initialValue: task.projectId)
        _selectedCategoryId = State(initialValue: task.categoryId)
        _taskStatus = State(initialValue: task.status)
    }

    var body: some View {
        Form {
            Section("Titel & Beschreibung") {
                TextField("Titel", text: $title)
                TextField("Beschreibung", text: $description, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }

            Section("Status") {
                Picker("Status", selection: Binding(
                    get: { taskStatus },
                    set: { taskStatus = $0 }
                )) {
                    ForEach(RemoteTask.Status.allCases, id: \.self) { status in
                        Text(status.display).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Fälligkeit") {
                Toggle("Fälligkeitsdatum", isOn: $includeDue)
                if includeDue {
                    DatePicker("Fällig am", selection: Binding(
                        get: { due ?? Date() },
                        set: { due = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])
                }
            }

            Section("Ziel / Projekt / Kategorie") {
                Picker("Ziel", selection: $selectedGoalId) {
                    Text("Kein Ziel").tag(UUID?.none)
                    ForEach(services.goalStore.goals, id: \.id) { goal in
                        Text(goal.title).tag(goal.id)
                    }
                }
                Picker("Projekt", selection: $selectedProjectId) {
                    Text("Kein Projekt").tag(UUID?.none)
                    ForEach(services.projectStore.projects, id: \.id) { project in
                        Text(project.name).tag(project.id)
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
        .navigationTitle("Aufgabe")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { save() }
            }
        }
        .task {
            if services.goalStore.goals.isEmpty { await services.goalStore.loadGoals() }
            if services.projectStore.projects.isEmpty { await services.projectStore.loadProjects() }
            if services.categoryStore.categories.isEmpty { await services.categoryStore.loadCategories() }
        }
        .onDisappear {
            Task { await services.taskStore.loadTasks() }
        }
    }

    private func save() {
        guard let id = task.id else { return }
        let updated = RemoteTask(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            status: taskStatus,
            due: includeDue ? due : nil,
            goalId: selectedGoalId,
            projectId: selectedProjectId,
            categoryId: selectedCategoryId
        )
        Task {
            await services.taskStore.updateTask(updated)
            dismiss()
        }
    }
}
