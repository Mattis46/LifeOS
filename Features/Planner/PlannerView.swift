import SwiftUI

struct PlannerView: View {
    @EnvironmentObject private var services: AppServices
    @State private var showAddTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskDescription = ""
    @State private var newTaskDue: Date = Date()
    @State private var includeDue = false
    @State private var selectedGoalId: UUID?
    @State private var selectedProjectId: UUID?
    @State private var selectedCategoryId: UUID?
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var showAddProject = false
    @State private var newProjectName = ""
    @State private var newProjectNotes = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Aufgaben") {
                    if let error = services.taskStore.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    if services.taskStore.isLoading {
                        ProgressView()
                    } else if services.taskStore.tasks.isEmpty {
                        Text("Keine Tasks geladen").foregroundStyle(.secondary)
                    } else {
                        ForEach(services.taskStore.tasks) { task in
                            NavigationLink {
                                TaskDetailView(task: task)
                            } label: {
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
                                    PlannerStatusBadge(status: task.status)
                                }
                            }
                        }
                    }
                    Button {
                        showAddTask = true
                    } label: {
                        Label("Aufgabe hinzufügen", systemImage: "plus")
                    }
                }

                Section("Gewohnheiten") {
                    NavigationLink {
                        HabitsView()
                    } label: {
                        Label("Gewohnheiten öffnen", systemImage: "heart.text.square")
                    }
                }

                Section("Ziele") {
                    NavigationLink {
                        GoalsView()
                    } label: {
                        Label("Ziele öffnen", systemImage: "target")
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
            .task {
                if services.taskStore.tasks.isEmpty {
                    await services.taskStore.loadTasks()
                }
                if services.goalStore.goals.isEmpty {
                    await services.goalStore.loadGoals()
                }
                if services.projectStore.projects.isEmpty {
                    await services.projectStore.loadProjects()
                }
                if services.categoryStore.categories.isEmpty {
                    await services.categoryStore.loadCategories()
                }
            }
            .refreshable {
                await services.taskStore.loadTasks()
                await services.goalStore.loadGoals()
                await services.projectStore.loadProjects()
                await services.categoryStore.loadCategories()
            }
            .sheet(isPresented: $showAddTask) {
                NavigationStack {
                    Form {
                        Section("Titel") {
                            TextField("Titel", text: $newTaskTitle)
                        }
                        Section("Beschreibung") {
                            TextField("Beschreibung", text: $newTaskDescription, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                        }
                        Section("Fällig") {
                            Toggle("Fälligkeitsdatum setzen", isOn: $includeDue)
                            if includeDue {
                                DatePicker("Fällig am", selection: $newTaskDue, displayedComponents: [.date, .hourAndMinute])
                            }
                        }
                        Section("Ziel / Projekt / Kategorie") {
                            Picker("Ziel", selection: Binding(
                                get: { selectedGoalId },
                                set: { selectedGoalId = $0 }
                            )) {
                                Text("Kein Ziel").tag(UUID?.none)
                                ForEach(services.goalStore.goals, id: \.id) { goal in
                                    Text(goal.title).tag(goal.id)
                                }
                            }
                            Picker("Projekt", selection: Binding(
                                get: { selectedProjectId },
                                set: { selectedProjectId = $0 }
                            )) {
                                Text("Kein Projekt").tag(UUID?.none)
                                ForEach(services.projectStore.projects, id: \.id) { project in
                                    Text(project.name).tag(project.id)
                                }
                            }
                            Button("Projekt hinzufügen") { showAddProject = true }
                            Picker("Kategorie", selection: Binding(
                                get: { selectedCategoryId },
                                set: { selectedCategoryId = $0 }
                            )) {
                                Text("Keine Kategorie").tag(UUID?.none)
                                ForEach(services.categoryStore.categories, id: \.id) { cat in
                                    Text(cat.name).tag(cat.id)
                                }
                            }
                            Button("Kategorie hinzufügen") { showAddCategory = true }
                        }
                    }
                    .navigationTitle("Neue Aufgabe")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                resetTaskForm()
                                showAddTask = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                let description = newTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                                let due: Date? = includeDue ? newTaskDue : nil
                                Task {
                                    await services.taskStore.addTask(
                                        title: title,
                                        description: description,
                                        due: due,
                                        goalId: selectedGoalId,
                                        projectId: selectedProjectId,
                                        categoryId: selectedCategoryId
                                    )
                                    await services.taskStore.loadTasks()
                                }
                                resetTaskForm()
                                showAddTask = false
                            }
                        }
                    }
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
            .sheet(isPresented: $showAddProject) {
                NavigationStack {
                    Form {
                        Section("Projekt") {
                            TextField("Name", text: $newProjectName)
                            TextField("Notizen", text: $newProjectNotes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                        }
                    }
                    .navigationTitle("Projekt hinzufügen")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                resetProjectForm()
                                showAddProject = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                                let notes = newProjectNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                                Task { await services.projectStore.addProject(name: name, notes: notes) }
                                resetProjectForm()
                                showAddProject = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func resetTaskForm() {
        newTaskTitle = ""
        newTaskDescription = ""
        includeDue = false
        newTaskDue = Date()
        selectedGoalId = nil
        selectedProjectId = nil
        selectedCategoryId = nil
    }

    private func resetProjectForm() {
        newProjectName = ""
        newProjectNotes = ""
    }
}

private struct PlannerStatusBadge: View {
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
