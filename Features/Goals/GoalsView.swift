import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var services: AppServices
    @State private var showAddGoal = false
    @State private var newGoalTitle = ""
    @State private var newGoalNotes = ""
    @State private var newGoalHorizon: RemoteGoal.Horizon = .short
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
                        TabView {
                            ForEach(services.goalStore.goals) { goal in
                                NavigationLink {
                                    GoalDetailView(goal: goal)
                                } label: {
                                    GoalCard(
                                        goal: goal,
                                        progress: progress(for: goal),
                                        nextTask: nextTask(for: goal)
                                    )
                                    .padding(.horizontal, 12)
                                }
                            }
                        }
                        .frame(height: 240)
                        .tabViewStyle(.page(indexDisplayMode: .automatic))

                        SectionHeader(title: "Heute wichtig")
                        VStack(spacing: 12) {
                            ForEach(todayImportantTasks().prefix(3)) { task in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.headline)
                                        if let due = task.due {
                                            Text(due, style: .date)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    GoalStatusBadge(status: task.status)
                                }
                                .padding()
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            if todayImportantTasks().isEmpty {
                                Text("Keine dringenden Aufgaben für heute.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Ziele")
            .refreshable {
                await services.goalStore.loadGoals()
                await services.taskStore.loadTasks()
                await services.habitStore.loadHabits()
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
                if services.taskStore.tasks.isEmpty {
                    await services.taskStore.loadTasks()
                }
                if services.habitStore.habits.isEmpty {
                    await services.habitStore.loadHabits()
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
                        Section("Farbe & Icon") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(GoalPalette.defaults, id: \.self) { hex in
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: newGoalColor == hex ? 3 : 0)
                                            )
                                            .onTapGesture { newGoalColor = hex }
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
                                Task {
                                    await services.goalStore.addGoal(
                                        title: title,
                                        horizon: newGoalHorizon,
                                        notes: notes,
                                        colorHex: newGoalColor,
                                        icon: newGoalIcon,
                                        targetDate: targetDate
                                    )
                                    await services.goalStore.loadGoals()
                                }
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
                .fill(Color(hex: goal.colorHex ?? "#4F46E5").opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: goal.colorHex ?? "#4F46E5").opacity(0.35), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: goal.icon ?? "target")
                        .foregroundStyle(Color(hex: goal.colorHex ?? "#4F46E5"))
                        .font(.title2)
                    Spacer()
                    ProgressRing(progress: progress, color: Color(hex: goal.colorHex ?? "#4F46E5"))
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
