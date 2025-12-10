import SwiftUI

struct GoalDetailView: View {
    @EnvironmentObject private var services: AppServices
    @Environment(\.dismiss) private var dismiss
    let goal: RemoteGoal

    @State private var title: String
    @State private var notes: String
    @State private var horizon: RemoteGoal.Horizon
    @State private var colorHex: String
    @State private var icon: String
    @State private var includeDeadline: Bool
    @State private var targetDate: Date
    @State private var showAddTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskDescription = ""
    @State private var includeTaskDue = false
    @State private var newTaskDue = Date()
    @State private var showDeleteConfirm = false
    @State private var showSuccessConfetti = false

    init(goal: RemoteGoal) {
        self.goal = goal
        _title = State(initialValue: goal.title)
        _notes = State(initialValue: goal.notes ?? "")
        _horizon = State(initialValue: goal.horizon)
        _colorHex = State(initialValue: goal.resolvedColorHex)
        _icon = State(initialValue: goal.resolvedIcon)
        _targetDate = State(initialValue: goal.targetDate ?? Date())
        _includeDeadline = State(initialValue: goal.targetDate != nil)
    }

    var body: some View {
        Form {
            Section {
                GoalCard(
                    goal: RemoteGoal(
                        id: goal.id,
                        title: title,
                        horizon: horizon,
                        notes: notes,
                        colorHex: colorHex,
                        icon: icon,
                        targetDate: includeDeadline ? targetDate : nil,
                        createdAt: goal.createdAt
                    ),
                    progress: progress(for: goal),
                    nextTask: nextTask(for: goal)
                )
            }

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
            Section("Identity & Coach") {
                Text("Identität: \(identityTag(for: goal))")
                    .font(.subheadline)
                let stats = goalStats(for: goal, services: services)
                HStack {
                    Label("\(stats.doneCount)/\(stats.totalCount) Wins", systemImage: "checkmark.circle")
                    Spacer()
                    Label("Habits \(stats.habitStreakSum)", systemImage: "flame")
                }
                .font(.caption)
                if let insight = goalCoachInsight(for: goal, stats: stats) {
                    Text(insight)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    // Kleinster Schritt stub
                } label: {
                    Label("Kleinster Schritt", systemImage: "bolt.fill")
                }
                Button {
                    // Coach Suggests stub
                } label: {
                    Label("Coach Suggests", systemImage: "sparkles")
                }
            }
            Section("Farbe & Icon") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(GoalPalette.defaults, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: colorHex == hex ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Picker("Icon", selection: $icon) {
                    ForEach(GoalPalette.icons, id: \.self) { icon in
                        Label(icon, systemImage: icon).tag(icon)
                    }
                }
            }
            Section("Deadline") {
                Toggle("Deadline setzen", isOn: $includeDeadline)
                if includeDeadline {
                    DatePicker("Zieldatum", selection: $targetDate, displayedComponents: .date)
                }
            }
            Section("Notizen / Warum") {
                TextField("Was motiviert dich?", text: $notes, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }

            if let goalId = goal.id {
                Section("Verknüpfte Aufgaben") {
                    let tasks = services.taskStore.tasks.filter { $0.goalId == goalId }
                    if tasks.isEmpty {
                        Text("Keine Aufgaben").foregroundStyle(.secondary)
                    } else {
                        ForEach(tasks) { task in
                            NavigationLink {
                                TaskDetailView(task: task)
                            } label: {
                                HStack {
                                    Text(task.title)
                                    Spacer()
                                    GoalStatusBadge(status: task.status)
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
                Section("Verknüpfte Gewohnheiten") {
                    let habits = services.habitStore.habits.filter { $0.goalId == goalId }
                    if habits.isEmpty {
                        Text("Keine Gewohnheiten").foregroundStyle(.secondary)
                    } else {
                        ForEach(habits) { habit in
                            VStack(alignment: .leading) {
                                Text(habit.title)
                                Text("Streak \(habit.streak ?? 0)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Ziel")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { save() }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .onDisappear {
            Task { await services.goalStore.loadGoals() }
        }
        .alert("Ziel löschen?", isPresented: $showDeleteConfirm) {
            Button("Löschen", role: .destructive) {
                Task {
                    if let id = goal.id {
                        await services.goalStore.deleteGoal(id)
                        await services.goalStore.loadGoals()
                        dismiss()
                    }
                }
            }
            Button("Abbrechen", role: .cancel) { }
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
                        Toggle("Fälligkeitsdatum", isOn: $includeTaskDue)
                        if includeTaskDue {
                            DatePicker("Fällig am", selection: $newTaskDue, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                }
                .navigationTitle("Task hinzufügen")
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
                            let due = includeTaskDue ? newTaskDue : nil
                            Task {
                                await services.taskStore.addTask(
                                    title: title,
                                    description: description,
                                    due: due,
                                    goalId: goal.id,
                                    projectId: nil,
                                    categoryId: nil
                                )
                                await services.taskStore.loadTasks()
                                withAnimation(.spring()) { showSuccessConfetti = true }
                                resetTaskForm()
                                showAddTask = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func save() {
        guard let id = goal.id else { return }
        #if DEBUG
        print("[GoalDetail] save id=\(id.uuidString) color=\(colorHex) icon=\(icon) title=\"\(title)\"")
        #endif
        let updated = RemoteGoal(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            horizon: horizon,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: colorHex.isEmpty ? GoalPalette.defaults.first ?? "#4F46E5" : colorHex,
            icon: icon.isEmpty ? "target" : icon,
            targetDate: includeDeadline ? targetDate : nil,
            createdAt: goal.createdAt
        )
        Task {
            await services.goalStore.updateGoal(updated)
            await services.goalStore.loadGoals()
            withAnimation(.spring()) { showSuccessConfetti = true }
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

    private func progress(for goal: RemoteGoal) -> Double {
        guard let goalId = goal.id else { return 0 }
        let tasks = services.taskStore.tasks.filter { $0.goalId == goalId }
        guard tasks.isEmpty == false else { return 0 }
        let done = tasks.filter { $0.status == .done }.count
        return Double(done) / Double(tasks.count)
    }

    private func nextTask(for goal: RemoteGoal) -> RemoteTask? {
        guard let goalId = goal.id else { return nil }
        let tasks = services.taskStore.tasks
            .filter { $0.goalId == goalId && $0.status != .done }
            .sorted { ($0.due ?? Date.distantFuture) < ($1.due ?? Date.distantFuture) }
        return tasks.first
    }

    private func identityTag(for goal: RemoteGoal) -> String {
        switch goal.horizon {
        case .short: return "Momentum Builder"
        case .mid: return "Game Changer"
        case .long: return "Vision Architect"
        }
    }

    private func resetTaskForm() {
        newTaskTitle = ""
        newTaskDescription = ""
        includeTaskDue = false
        newTaskDue = Date()
    }
}
