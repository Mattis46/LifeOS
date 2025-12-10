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

    init(goal: RemoteGoal) {
        self.goal = goal
        _title = State(initialValue: goal.title)
        _notes = State(initialValue: goal.notes ?? "")
        _horizon = State(initialValue: goal.horizon)
        _colorHex = State(initialValue: goal.colorHex ?? GoalPalette.defaults.first ?? "#4F46E5")
        _icon = State(initialValue: goal.icon ?? "target")
        _targetDate = State(initialValue: goal.targetDate ?? Date())
        _includeDeadline = State(initialValue: goal.targetDate != nil)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
                .padding(.horizontal, 12)

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
                    Section("Farbe & Icon") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(GoalPalette.defaults, id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: colorHex == hex ? 3 : 0)
                                        )
                                        .onTapGesture { colorHex = hex }
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
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: colorHex,
            icon: icon,
            targetDate: includeDeadline ? targetDate : nil,
            createdAt: goal.createdAt
        )
        Task {
            await services.goalStore.updateGoal(updated)
            await services.goalStore.loadGoals()
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
}
