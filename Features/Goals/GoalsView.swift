import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var services: AppServices
    @State private var showAddGoal = false
    @State private var newGoalTitle = ""
    @State private var newGoalNotes = ""
    @State private var newGoalHorizon: RemoteGoal.Horizon = .short
    @State private var newGoalPurpose = ""
    @State private var newGoalIdentity = ""
    @State private var newGoalColor: String = GoalPalette.defaults.first ?? "#4F46E5"
    @State private var newGoalIcon: String = "target"
    @State private var includeDeadline = false
    @State private var newGoalDate = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let error = services.goalStore.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }

                    if services.goalStore.goals.isEmpty {
                        VStack(spacing: 12) {
                            Text("Keine Ziele")
                                .font(.headline)
                            Text("Lege ein erstes Ziel an, um deinen Fokus zu setzen.")
                                .foregroundStyle(.secondary)
                            Button {
                                showAddGoal = true
                            } label: {
                                Label("Ziel hinzufügen", systemImage: "plus")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        goalHorizonSection(title: "Short-Term", goals: goals(for: .short))
                        goalHorizonSection(title: "Mid-Term", goals: goals(for: .mid))
                        goalHorizonSection(title: "Long-Term", goals: goals(for: .long))
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Ziele")
            .refreshable {
                await refreshAll()
            }
            .toolbar {
                Button {
                    showAddGoal = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .task {
                await refreshIfNeeded()
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
                        Section("Fokus & Identität") {
                            TextField("Warum / Purpose", text: $newGoalPurpose, axis: .vertical)
                                .lineLimit(2...4)
                            TextField("Identität (optional)", text: $newGoalIdentity)
                        }
                        Section("Farbe & Icon") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(GoalPalette.defaults, id: \.self) { hex in
                                        Button {
                                            newGoalColor = hex
                                        } label: {
                                            Circle()
                                                .fill(Color(hex: hex))
                                                .frame(width: 32, height: 32)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: newGoalColor == hex ? 3 : 0)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            Picker("Icon", selection: $newGoalIcon) {
                                ForEach(GoalPalette.icons, id: \.self) { icon in
                                    Label(icon, systemImage: icon).tag(icon)
                                }
                            }
                        }
                        Section("Deadline") {
                            Toggle("Deadline setzen", isOn: $includeDeadline)
                            if includeDeadline {
                                DatePicker("Zieldatum", selection: $newGoalDate, displayedComponents: .date)
                            }
                        }
                        Section("Notizen / Warum") {
                            TextField("Was motiviert dich?", text: $newGoalNotes, axis: .vertical)
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
                                let targetDate = includeDeadline ? newGoalDate : nil
                                let color = newGoalColor
                                let icon = newGoalIcon
                                #if DEBUG
                                print("[GoalsView] Save new goal color=\(color) icon=\(icon) title=\"\(title)\"")
                                #endif
                                Task {
                                    await services.goalStore.addGoal(
                                        title: title,
                                        horizon: newGoalHorizon,
                                        purpose: newGoalPurpose.trimmingCharacters(in: .whitespacesAndNewlines),
                                        identityTag: newGoalIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newGoalIdentity.trimmingCharacters(in: .whitespacesAndNewlines),
                                        notes: notes,
                                        colorHex: color,
                                        icon: icon,
                                        targetDate: targetDate
                                    )
                                    await services.goalStore.loadGoals()
                                    await MainActor.run {
                                        resetGoalForm()
                                        showAddGoal = false
                                    }
                                }
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
        newGoalPurpose = ""
        newGoalIdentity = ""
        newGoalHorizon = .short
        newGoalColor = GoalPalette.defaults.first ?? "#4F46E5"
        newGoalIcon = "target"
        includeDeadline = false
        newGoalDate = Date()
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

    private func todayImportantTasks() -> [RemoteTask] {
        services.taskStore.tasks
            .filter { $0.goalId != nil && $0.status != .done }
            .sorted { ($0.due ?? Date.distantFuture) < ($1.due ?? Date.distantFuture) }
    }
}

struct GoalCard: View {
    let goal: RemoteGoal
    let progress: Double
    let nextTask: RemoteTask?

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: goal.resolvedColorHex).opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: goal.resolvedColorHex).opacity(0.35), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: goal.resolvedIcon)
                        .foregroundStyle(Color(hex: goal.resolvedColorHex))
                        .font(.title2)
                    Spacer()
                    ProgressRing(progress: progress, color: Color(hex: goal.resolvedColorHex))
                        .frame(width: 48, height: 48)
                }
                Text(goal.title)
                    .font(.headline)
                if let notes = goal.notes, notes.isEmpty == false {
                    Text(notes)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                HStack(spacing: 12) {
                    Label(goal.horizon.rawValue.capitalized, systemImage: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let date = goal.targetDate {
                        Label {
                            Text(date, style: .date)
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                if let nextTask {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nächster Schritt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(nextTask.title)
                            .font(.subheadline)
                    }
                } else {
                    Text("Füge eine Aufgabe hinzu, um zu starten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.caption2)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 12)
    }
}

enum GoalPalette {
    static let defaults: [String] = [
        "#4F46E5", "#0EA5E9", "#22C55E", "#F97316", "#EF4444", "#E11D48", "#6366F1"
    ]
    static let icons: [String] = [
        "target", "flag.checkered", "flame", "star.fill", "bolt.fill", "heart.fill", "leaf.fill"
    ]
}

extension Color {
    init(hex: String) {
        let clean = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: UInt64
        switch clean.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (79, 70, 229)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

struct GoalStatusBadge: View {
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

struct GoalStats {
    let progress: Double
    let doneCount: Int
    let totalCount: Int
    let habitStreakSum: Int
    let nextTask: RemoteTask?
}

// MARK: - Helpers

extension GoalsView {
    var directionWidget: some View {
        let topShort = goals(for: .short).first
        let topMid = goals(for: .mid).first
        let topLong = goals(for: .long).first
        let focusText = [topShort?.title, topMid?.title, topLong?.title].compactMap { $0 }.joined(separator: " • ")
        return VStack(alignment: .leading, spacing: 8) {
            Text("Your Direction")
                .font(.title2).bold()
            if focusText.isEmpty {
                Text("Setze ein Ziel, um deinen Fokus festzulegen.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Du arbeitest gerade an \(focusText).")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    func goals(for horizon: RemoteGoal.Horizon) -> [RemoteGoal] {
        services.goalStore.goals.filter { $0.horizon == horizon }
    }

    @MainActor
    func refreshAll() async {
        async let g = services.goalStore.loadGoals()
        async let t = services.taskStore.loadTasks()
        async let h = services.habitStore.loadHabits()
        async let m = services.milestoneStore.loadMilestones()
        _ = await (g, t, h, m)
    }

    @MainActor
    func refreshIfNeeded() async {
        if services.goalStore.goals.isEmpty {
            async let g = services.goalStore.loadGoals()
            async let t = services.taskStore.loadTasks()
            async let h = services.habitStore.loadHabits()
            async let m = services.milestoneStore.loadMilestones()
            _ = await (g, t, h, m)
        } else {
            // Nur Tasks/Habits nachladen, falls leer.
            if services.taskStore.tasks.isEmpty {
                await services.taskStore.loadTasks()
            }
            if services.habitStore.habits.isEmpty {
                await services.habitStore.loadHabits()
            }
            if services.milestoneStore.milestones.isEmpty {
                await services.milestoneStore.loadMilestones()
            }
        }
    }

    @ViewBuilder
    func goalHorizonSection(title: String, goals: [RemoteGoal]) -> some View {
        if goals.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: title)
                ForEach(goals) { goal in
                    NavigationLink {
                        GoalDetailView(goal: goal)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(identityTag(for: goal), systemImage: goal.resolvedIcon)
                                    .foregroundStyle(Color(hex: goal.resolvedColorHex))
                                Spacer()
                                let stats = goalStats(for: goal, services: services)
                                ProgressRing(progress: stats.progress, color: Color(hex: goal.resolvedColorHex))
                                    .frame(width: 44, height: 44)
                            }
                            Text(goal.title)
                                .font(.headline)
                            if let notes = goal.notes, notes.isEmpty == false {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            let stats = goalStats(for: goal, services: services)
                            HStack(spacing: 8) {
                                Label("\(stats.doneCount)/\(stats.totalCount) Wins", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Label("Habits \(stats.habitStreakSum)", systemImage: "flame")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let insight = goalCoachInsight(for: goal, stats: stats) {
                                Text(insight)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 8) {
                                Button {
                                    // Kleinster Schritt: hier könnte der Coach später Vorschläge liefern.
                                } label: {
                                    Label("Kleinster Schritt", systemImage: "bolt.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(hex: goal.resolvedColorHex))

                                Button {
                                    // Coach Suggests placeholder
                                } label: {
                                    Label("Coach Suggests", systemImage: "sparkles")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .background(Color(hex: goal.resolvedColorHex).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    func identityTag(for goal: RemoteGoal) -> String {
        if let tag = goal.identityTag, tag.isEmpty == false { return tag }
        switch goal.horizon {
        case .short: return "Momentum Builder"
        case .mid: return "Game Changer"
        case .long: return "Vision Architect"
        }
    }

}

// Globale Helper, damit auch GoalDetailView darauf zugreifen kann.
@MainActor
func goalStats(for goal: RemoteGoal, services: AppServices) -> GoalStats {
    guard let goalId = goal.id else {
        return GoalStats(progress: 0, doneCount: 0, totalCount: 0, habitStreakSum: 0, nextTask: nil)
    }
    let tasks = services.taskStore.tasks.filter { $0.goalId == goalId }
    let done = tasks.filter { $0.status == .done }.count
    let progress = tasks.isEmpty ? 0 : Double(done) / Double(tasks.count)
    let habits = services.habitStore.habits.filter { $0.goalId == goalId }
    let habitStreakSum = habits.compactMap { $0.streak }.reduce(0, +)
    let nextTask = tasks
        .filter { $0.status != .done }
        .sorted { ($0.due ?? Date.distantFuture) < ($1.due ?? Date.distantFuture) }
        .first
    return GoalStats(progress: progress, doneCount: done, totalCount: tasks.count, habitStreakSum: habitStreakSum, nextTask: nextTask)
}

@MainActor
func goalCoachInsight(for goal: RemoteGoal, stats: GoalStats) -> String? {
    if stats.totalCount == 0 {
        return "Starte mit einem kleinsten Schritt, um Momentum aufzubauen."
    }
    if stats.progress >= 0.7 {
        return "Du bist auf Kurs – feiere deine Fortschritte und plane den nächsten Schritt."
    }
    if stats.habitStreakSum > 0 {
        return "Deine Habits zahlen auf dieses Ziel ein. Halte den Streak am Leben."
    }
    if let next = stats.nextTask {
        return "Nächster Schritt: \(next.title)"
    }
    return nil
}
