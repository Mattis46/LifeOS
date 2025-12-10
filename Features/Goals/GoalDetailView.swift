import SwiftUI

struct GoalDetailView: View {
    @EnvironmentObject private var services: AppServices
    @Environment(\.dismiss) private var dismiss
    let goal: RemoteGoal

    @State private var title: String
    @State private var purpose: String
    @State private var identity: String
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
    @State private var showAddMilestone = false
    @State private var newMilestoneTitle = ""
    @State private var includeMilestoneDue = false
    @State private var newMilestoneDue = Date()
    @State private var showSettings = false

    init(goal: RemoteGoal) {
        self.goal = goal
        _title = State(initialValue: goal.title)
        _purpose = State(initialValue: goal.purpose ?? "")
        _identity = State(initialValue: goal.identityTag ?? "")
        _notes = State(initialValue: goal.notes ?? "")
        _horizon = State(initialValue: goal.horizon)
        _colorHex = State(initialValue: goal.resolvedColorHex)
        _icon = State(initialValue: goal.resolvedIcon)
        _targetDate = State(initialValue: goal.targetDate ?? Date())
        _includeDeadline = State(initialValue: goal.targetDate != nil)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                flowSection
                notesSection
                habitsSection
                coachSection
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Roadmap")
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .refreshable { await reloadAll() }
        .onAppear { Task { await preload() } }
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
        .sheet(isPresented: $showAddMilestone) {
            NavigationStack {
                Form {
                    Section("Titel") {
                        TextField("Titel", text: $newMilestoneTitle)
                    }
                    Section("Fällig") {
                        Toggle("Fälligkeitsdatum", isOn: $includeMilestoneDue)
                        if includeMilestoneDue {
                            DatePicker("Fällig am", selection: $newMilestoneDue, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                }
                .navigationTitle("Meilenstein hinzufügen")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            resetMilestoneForm()
                            showAddMilestone = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            let title = newMilestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            let due = includeMilestoneDue ? newMilestoneDue : nil
                            Task {
                                await services.milestoneStore.addMilestone(goalId: goal.id, title: title, due: due)
                                await services.milestoneStore.loadMilestones(goalId: goal.id)
                                resetMilestoneForm()
                                showAddMilestone = false
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                Form {
                    Section("Fokus & Identität") {
                        TextField("Titel", text: $title)
                        TextField("Warum / Purpose", text: $purpose, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("Identität", text: $identity)
                    }
                    Section("Zeitraum") {
                        Picker("Zeithorizont", selection: $horizon) {
                            ForEach(RemoteGoal.Horizon.allCases, id: \.self) { h in
                                Text(label(for: h)).tag(h)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("Styling") {
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
                        Toggle("Deadline setzen", isOn: $includeDeadline)
                        if includeDeadline {
                            DatePicker("Zieldatum", selection: $targetDate, displayedComponents: .date)
                        }
                    }
                }
                .navigationTitle("Einstellungen")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") { showSettings = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            save()
                            showSettings = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var headerCard: some View {
        GoalCard(
            goal: RemoteGoal(
                id: goal.id,
                title: title,
                horizon: horizon,
                purpose: purpose,
                identityTag: identity.isEmpty ? identityTagDefault(for: horizon) : identity,
                notes: notes,
                colorHex: colorHex,
                icon: icon,
                targetDate: includeDeadline ? targetDate : nil,
                createdAt: goal.createdAt
            ),
            progress: progress(for: goal),
            nextTask: nextTask(for: goal)
        )
        .padding(.horizontal, 12)
    }

    private var flowSection: some View {
        GroupBox("Roadmap Flow") {
            VStack(alignment: .leading, spacing: 12) {
                if flowNodes.isEmpty {
                    Text("Baue eine klare Roadmap: Meilensteine + Tasks in Reihenfolge.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(flowNodes.enumerated()), id: \.offset) { index, node in
                        flowRow(node, isLast: index == flowNodes.count - 1)
                    }
                }
                HStack {
                    Button {
                        showAddMilestone = true
                    } label: {
                        Label("Meilenstein", systemImage: "target")
                    }
                    Button {
                        showAddTask = true
                    } label: {
                        Label("Task", systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
    }

    private var notesSection: some View {
        GroupBox("Notizen") {
            TextEditor(text: $notes)
                .frame(minHeight: 120)
        }
        .padding(.horizontal, 12)
    }

    private var habitsSection: some View {
        GroupBox("Gewohnheiten, die zahlen") {
            VStack(alignment: .leading, spacing: 8) {
                if let goalId = goal.id {
                    let habits = services.habitStore.habits.filter { $0.goalId == goalId }
                    if habits.isEmpty {
                        Text("Keine Gewohnheiten verknüpft.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(habits) { habit in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(habit.title)
                                    Text("Streak \(habit.streak ?? 0)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } else {
                    Text("Ziel zuerst speichern, dann Habits verknüpfen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private var coachSection: some View {
        GroupBox("Coach & Momentum") {
            let stats = goalStats(for: goal, services: services)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("\(stats.doneCount)/\(stats.totalCount) Wins", systemImage: "checkmark.circle")
                    Spacer()
                    Label("Habits \(stats.habitStreakSum)", systemImage: "flame")
                }
                .font(.caption)
                if let insight = goalCoachInsight(for: goal, stats: stats) {
                    Text(insight)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Coach-Vorschläge folgen bald.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button {
                        // Placeholder für kleinsten Schritt
                    } label: {
                        Label("Kleinster Schritt", systemImage: "bolt.fill")
                    }
                    Spacer()
                    Button {
                        // Placeholder für Coach Suggests
                    } label: {
                        Label("Coach Suggests", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Helpers

    private var flowNodes: [FlowNode] {
        guard let goalId = goal.id else { return [] }
        let tasks = services.taskStore.tasks.filter { $0.goalId == goalId }
        let milestones = services.milestoneStore.milestones.filter { $0.goalId == goalId }
        var nodes: [FlowNode] = milestones.map { .milestone($0) } + tasks.map { .task($0) }
        nodes.sort { lhs, rhs in
            let lDate = lhs.date
            let rDate = rhs.date
            switch (lDate, rDate) {
            case let (l?, r?): return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            default: return lhs.fallback < rhs.fallback
            }
        }
        return nodes
    }

    @ViewBuilder
    private func flowRow(_ node: FlowNode, isLast: Bool) -> some View {
        let _ = isLast
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Button {
                    Task { await toggle(node) }
                } label: {
                    Image(systemName: node.toggleIcon)
                        .font(.title3)
                        .foregroundStyle(node.tint)
                }
                .buttonStyle(.plain)
                if isLast == false {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(node.cardFill(baseHex: colorHex))
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(node.cardStroke(baseHex: colorHex), lineWidth: 1)
                if node.isMilestone {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: colorHex).opacity(0.25), lineWidth: 3)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(node.title)
                            .fontWeight(.semibold)
                        Spacer()
                        if let badge = node.badge {
                            Text(badge)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: colorHex).opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    if let detail = node.detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
            }
        }
        .padding(.vertical, 2)
    }

    private var milestonesForGoal: [RemoteMilestone] {
        guard let id = goal.id else { return [] }
        return services.milestoneStore.milestones
            .filter { $0.goalId == id }
            .sorted {
                switch ($0.due, $1.due) {
                case let (l?, r?): return l < r
                case (nil, _?): return false
                case (_?, nil): return true
                default: return ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast)
                }
            }
    }

    @ViewBuilder
    private func timelineRow(_ milestone: RemoteMilestone, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Button {
                    Task { await services.milestoneStore.toggleMilestone(milestone) }
                } label: {
                    Image(systemName: milestone.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(milestone.isDone ? .green : .secondary)
                }
                .buttonStyle(.plain)
                Rectangle()
                    .fill(Color.secondary.opacity(isLast ? 0 : 0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .fontWeight(.semibold)
                if let due = milestone.due {
                    Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func tasksBucket(_ title: String, tasks: [RemoteTask]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if tasks.isEmpty == false {
                Text(title.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(tasks) { task in taskRow(task) }
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
            purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
            identityTag: identity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : identity.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: colorHex.isEmpty ? GoalPalette.defaults.first ?? "#4F46E5" : colorHex,
            icon: icon.isEmpty ? "target" : icon,
            targetDate: includeDeadline ? targetDate : nil,
            createdAt: goal.createdAt
        )
        Task {
            await services.goalStore.updateGoal(updated)
            await reloadAll()
            withAnimation(.spring()) { showSuccessConfetti = true }
            dismiss()
        }
    }

    private func reloadAll() async {
        await services.goalStore.loadGoals()
        await services.taskStore.loadTasks()
        await services.habitStore.loadHabits()
        if let id = goal.id {
            await services.milestoneStore.loadMilestones(goalId: id)
        }
    }

    private func preload() async {
        if services.taskStore.tasks.isEmpty { await services.taskStore.loadTasks() }
        if services.habitStore.habits.isEmpty { await services.habitStore.loadHabits() }
        if let id = goal.id, services.milestoneStore.milestones.filter({ $0.goalId == id }).isEmpty {
            await services.milestoneStore.loadMilestones(goalId: id)
        }
    }

    private func label(for horizon: RemoteGoal.Horizon) -> String {
        switch horizon {
        case .short: return "Kurz"
        case .mid: return "Mittel"
        case .long: return "Lang"
        }
    }

    private func identityTagDefault(for horizon: RemoteGoal.Horizon) -> String {
        switch horizon {
        case .short: return "Momentum Builder"
        case .mid: return "Game Changer"
        case .long: return "Vision Architect"
        }
    }

    private func progress(for goal: RemoteGoal) -> Double {
        guard let goalId = goal.id else { return 0 }
        let tasks = services.taskStore.tasks.filter { $0.goalId == goalId }
        let milestones = services.milestoneStore.milestones.filter { $0.goalId == goalId }
        let taskScore: Double
        if tasks.isEmpty { taskScore = 0 } else {
            let done = tasks.filter { $0.status == .done }.count
            taskScore = Double(done) / Double(tasks.count)
        }
        let milestoneScore: Double
        if milestones.isEmpty { milestoneScore = 0 } else {
            let done = milestones.filter { $0.isDone }.count
            milestoneScore = Double(done) / Double(milestones.count)
        }
        return max(0, min(1, (taskScore + milestoneScore) / 2))
    }

    private func nextTask(for goal: RemoteGoal) -> RemoteTask? {
        guard let goalId = goal.id else { return nil }
        let tasks = services.taskStore.tasks
            .filter { $0.goalId == goalId && $0.status != .done }
            .sorted { ($0.due ?? Date.distantFuture) < ($1.due ?? Date.distantFuture) }
        return tasks.first
    }

    private func identityTag(for goal: RemoteGoal) -> String {
        if let tag = goal.identityTag, tag.isEmpty == false { return tag }
        return identityTagDefault(for: goal.horizon)
    }

    private func resetTaskForm() {
        newTaskTitle = ""
        newTaskDescription = ""
        includeTaskDue = false
        newTaskDue = Date()
    }

    private func resetMilestoneForm() {
        newMilestoneTitle = ""
        includeMilestoneDue = false
        newMilestoneDue = Date()
    }

    private func taskBuckets(goalId: UUID) -> (today: [RemoteTask], week: [RemoteTask], later: [RemoteTask]) {
        let calendar = Calendar.current
        let now = Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        let tasks = services.taskStore.tasks.filter { $0.goalId == goalId }
        var today: [RemoteTask] = []
        var week: [RemoteTask] = []
        var later: [RemoteTask] = []
        for task in tasks {
            guard let due = task.due else {
                later.append(task)
                continue
            }
            if calendar.isDateInToday(due) {
                today.append(task)
            } else if due <= endOfWeek {
                week.append(task)
            } else {
                later.append(task)
            }
        }
        let sorter: (RemoteTask, RemoteTask) -> Bool = { ($0.due ?? now) < ($1.due ?? now) }
        today.sort(by: sorter)
        week.sort(by: sorter)
        later.sort(by: sorter)
        return (today, week, later)
    }

    @ViewBuilder
    private func taskRow(_ task: RemoteTask) -> some View {
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
                }
                Spacer()
                GoalStatusBadge(status: task.status)
            }
        }
    }

    private enum FlowNode {
        case milestone(RemoteMilestone)
        case task(RemoteTask)

        var date: Date? {
            switch self {
            case .milestone(let m): return m.due
            case .task(let t): return t.due
            }
        }

        var fallback: Date {
            switch self {
            case .milestone(let m): return m.createdAt ?? .distantPast
            case .task(let t): return t.createdAt ?? .distantPast
            }
        }

        var title: String {
            switch self {
            case .milestone(let m): return m.title
            case .task(let t): return t.title
            }
        }

        var detail: String? {
            switch self {
            case .milestone(let m):
                if let due = m.due { return "Due \(due.formatted(date: .abbreviated, time: .omitted))" }
                return nil
            case .task(let t):
                if let due = t.due { return "Task · \(due.formatted(date: .abbreviated, time: .omitted))" }
                return "Task"
            }
        }

        var badge: String? {
            switch self {
            case .milestone:
                return "Milestone"
            case .task:
                return "Task"
            }
        }

        func cardFill(baseHex: String) -> Color {
            switch self {
            case .milestone:
                return Color(hex: baseHex).opacity(0.28)
            case .task:
                return Color.primary.opacity(0.035)
            }
        }

        func cardStroke(baseHex: String) -> Color {
            switch self {
            case .milestone:
                return Color(hex: baseHex).opacity(0.9)
            case .task:
                return Color.primary.opacity(0.15)
            }
        }

        var isMilestone: Bool {
            if case .milestone = self { return true }
            return false
        }

        var icon: String {
            switch self {
            case .milestone(let m): return m.isDone ? "target" : "circle.dashed"
            case .task(let t):
                switch t.status {
                case .done: return "checkmark.circle.fill"
                case .inProgress: return "clock.arrow.circlepath"
                case .blocked: return "exclamationmark.triangle"
                case .open: return "circle"
                }
            }
        }

        var toggleIcon: String {
            switch self {
            case .milestone(let m):
                return m.isDone ? "checkmark.circle.fill" : "circle.dashed"
            case .task(let t):
                switch t.status {
                case .done: return "checkmark.circle.fill"
                case .blocked: return "exclamationmark.circle"
                case .inProgress: return "clock"
                case .open: return "circle"
                }
            }
        }

        var tint: Color {
            switch self {
            case .milestone(let m): return m.isDone ? .green : .primary
            case .task(let t):
                switch t.status {
                case .done: return .green
                case .inProgress: return .blue
                case .blocked: return .red
                case .open: return .secondary
                }
            }
        }
    }

    private func toggle(_ node: FlowNode) async {
        switch node {
        case .milestone(let m):
            await services.milestoneStore.toggleMilestone(m)
            if let id = goal.id { await services.milestoneStore.loadMilestones(goalId: id) }
        case .task(let t):
            var updated = t
            updated.status = (t.status == .done) ? .open : .done
            await services.taskStore.updateTask(updated)
            await services.taskStore.loadTasks()
        }
    }
}
