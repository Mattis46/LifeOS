import SwiftUI

struct PlannerView: View {
    @EnvironmentObject private var services: AppServices
    @State private var showAddTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskDescription = ""
    @State private var newTaskDue: Date = Date()
    @State private var includeDue = false
    @State private var selectedGoalId: UUID?
    @State private var selectedCategoryId: UUID?
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var showSettings = false
    @State private var appearance: AppearanceOption = .system
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    tasksSection
                    habitsSection
                    goalsSection
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .navigationTitle("Planer")
            .toolbar {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            .task { await loadAllIfNeeded() }
            .refreshable { await refreshAll() }
            .sheet(isPresented: $showAddTask, content: taskSheet)
            .sheet(isPresented: $showAddCategory, content: categorySheet)
            .sheet(isPresented: $showSettings, content: settingsSheet)
            .preferredColorScheme(appearance.colorScheme)
        }
    }
}

// MARK: - Sections
private extension PlannerView {
    var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dein Planner")
                .font(.title2).bold()
            Text("Habits • Tasks • Goals • Zeit")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    var habitsSection: some View {
        GroupBox("Habits (Heute / Woche)") {
            let habits = habitsForDay(selectedDay)
            if habits.isEmpty {
                Text("Keine Habits angelegt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(habits.prefix(5)) { habit in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(habit.title)
                            if let goalId = habit.goalId,
                               let goal = services.goalStore.goals.first(where: { $0.id == goalId }) {
                                Text("zahlt auf: \(goal.title)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { idx in
                                Circle()
                                    .fill(idx == Calendar.current.component(.weekday, from: selectedDay) - 1 ? Color.accentColor : Color.secondary.opacity(0.15))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await services.habitStore.deleteHabit(id: habit.id) }
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
                NavigationLink {
                    HabitsView()
                } label: {
                    Label("Alle Habits öffnen", systemImage: "chevron.forward")
                        .font(.footnote)
                }
            }
        }
    }

    var tasksSection: some View {
        GroupBox("Tasks") {
            let buckets = taskBuckets(for: selectedDay)
            VStack(alignment: .leading, spacing: 10) {
                tasksBucket("Heute", tasks: buckets.today)
                tasksBucket("Diese Woche", tasks: buckets.week)
                tasksBucket("Backlog", tasks: buckets.later)
                Button {
                    showAddTask = true
                } label: {
                    Label("Aufgabe hinzufügen", systemImage: "plus")
                }
            }
        }
    }

    var goalsSection: some View {
        GroupBox("Goals") {
            if services.goalStore.goals.isEmpty {
                Text("Noch keine Goals. Lege eines an, um zu planen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(services.goalStore.goals.prefix(5)) { goal in
                    NavigationLink {
                        GoalDetailView(goal: goal)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.title)
                                    .font(.headline)
                                let stats = goalStats(for: goal, services: services)
                                Text("\(Int(stats.progress * 100))% · \(stats.doneCount)/\(stats.totalCount) Tasks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            ProgressRing(progress: goalStats(for: goal, services: services).progress, color: Color(hex: goal.resolvedColorHex))
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                NavigationLink {
                    GoalsView()
                } label: {
                    Label("Alle Goals öffnen", systemImage: "chevron.forward")
                        .font(.footnote)
                }
            }
        }
    }

    var journalSection: some View {
        GroupBox("Journal & Reflexion") {
            NavigationLink {
                JournalView()
            } label: {
                Label("Journal öffnen", systemImage: "book.closed")
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Helpers
private extension PlannerView {
    func loadAllIfNeeded() async {
        if services.taskStore.tasks.isEmpty { await services.taskStore.loadTasks() }
        if services.goalStore.goals.isEmpty { await services.goalStore.loadGoals() }
        if services.habitStore.habits.isEmpty { await services.habitStore.loadHabits() }
        if services.categoryStore.categories.isEmpty { await services.categoryStore.loadCategories() }
    }

    func refreshAll() async {
        async let t: Void = services.taskStore.loadTasks()
        async let g: Void = services.goalStore.loadGoals()
        async let h: Void = services.habitStore.loadHabits()
        async let c: Void = services.categoryStore.loadCategories()
        _ = await (t, g, h, c)
    }

    func upcomingWeek() -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    func taskBuckets(for day: Date) -> (today: [RemoteTask], week: [RemoteTask], later: [RemoteTask]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: day)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        let tasks = services.taskStore.tasks
        var todayTasks: [RemoteTask] = []
        var week: [RemoteTask] = []
        var later: [RemoteTask] = []
        for task in tasks {
            guard let due = task.due else {
                later.append(task)
                continue
            }
            if calendar.isDate(due, inSameDayAs: today) {
                todayTasks.append(task)
            } else if due > today && due <= endOfWeek {
                week.append(task)
            } else {
                later.append(task)
            }
        }
        let sorter: (RemoteTask, RemoteTask) -> Bool = { ($0.due ?? today) < ($1.due ?? today) }
        todayTasks.sort(by: sorter)
        week.sort(by: sorter)
        later.sort(by: sorter)
        return (todayTasks, week, later)
    }

    func habitsForDay(_ day: Date) -> [RemoteHabit] {
        // Noch keine Tageslogik, daher alle Habits. (Hook für später, wenn Habit-Schedule kommt.)
        return services.habitStore.habits
    }

    func resetTaskForm() {
        newTaskTitle = ""
        newTaskDescription = ""
        includeDue = false
        newTaskDue = Date()
        selectedGoalId = nil
        selectedCategoryId = nil
    }

    @ViewBuilder
    func tasksBucket(_ title: String, tasks: [RemoteTask]) -> some View {
        if tasks.isEmpty == false {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(tasks) { task in
                NavigationLink {
                    TaskDetailView(task: task)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                            if let due = task.due {
                                Text(due, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let goalId = task.goalId,
                               let goal = services.goalStore.goals.first(where: { $0.id == goalId }) {
                                Text("Goal: \(goal.title)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        PlannerStatusBadge(status: task.status)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await services.taskStore.deleteTask(id: task.id) }
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        } else if title == "Heute" {
            Text("Keine Tasks für heute.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    func taskSheet() -> some View {
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
                Section("Ziel / Kategorie") {
                    Picker("Ziel", selection: Binding(
                        get: { selectedGoalId },
                        set: { selectedGoalId = $0 }
                    )) {
                        Text("Kein Ziel").tag(UUID?.none)
                        ForEach(services.goalStore.goals, id: \.id) { goal in
                            Text(goal.title).tag(goal.id)
                        }
                    }
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
                                categoryId: selectedCategoryId
                            )
                            await services.taskStore.loadTasks()
                            await services.categoryStore.loadCategories()
                        }
                        resetTaskForm()
                        showAddTask = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    func categorySheet() -> some View {
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

    @ViewBuilder
    func settingsSheet() -> some View {
        NavigationStack {
            Form {
                Section("Darstellung") {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag(AppearanceOption.system)
                        Text("Hell").tag(AppearanceOption.light)
                        Text("Dunkel").tag(AppearanceOption.dark)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { showSettings = false }
                }
            }
        }
    }

}

private enum AppearanceOption: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
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

private let timeFormatter: DateFormatter = {
    let df = DateFormatter()
    df.timeStyle = .short
    return df
}()
