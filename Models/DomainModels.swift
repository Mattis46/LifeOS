import Foundation

struct Goal: Identifiable, Hashable {
    enum Horizon: String, CaseIterable { case short, mid, long }
    let id: UUID
    var title: String
    var horizon: Horizon
    var notes: String
}

struct Habit: Identifiable, Hashable {
    let id: UUID
    var title: String
    var cadence: String
    var streak: Int
}

struct FocusTask: Identifiable, Hashable {
    enum Status: String { case open, inProgress, done, blocked }
    let id: UUID
    var title: String
    var due: Date?
    var status: Status
    var goal: Goal?
}

struct JournalEntry: Identifiable, Hashable {
    let id: UUID
    var mood: Int
    var energy: Int
    var notes: String
    var createdAt: Date
}

enum SampleData {
    static let goals: [Goal] = [
        Goal(id: UUID(), title: "Launch MVP", horizon: .short, notes: "Ship to TestFlight"),
        Goal(id: UUID(), title: "Improve Energy", horizon: .mid, notes: "Regular sleep, exercise")
    ]

    static let habits: [Habit] = [
        Habit(id: UUID(), title: "Journal 5 min", cadence: "Daily", streak: 6),
        Habit(id: UUID(), title: "Move 20 min", cadence: "Daily", streak: 3)
    ]

    static let tasks: [FocusTask] = [
        FocusTask(id: UUID(), title: "Define onboarding", due: Date(), status: .open, goal: goals.first),
        FocusTask(id: UUID(), title: "Prep coach prompt", due: Calendar.current.date(byAdding: .day, value: 1, to: Date()), status: .inProgress, goal: goals.first),
        FocusTask(id: UUID(), title: "Plan week reflection", due: nil, status: .open, goal: goals.last)
    ]

    static let journal: [JournalEntry] = [
        JournalEntry(id: UUID(), mood: 4, energy: 3, notes: "Solid morning deep work.", createdAt: Date()),
        JournalEntry(id: UUID(), mood: 3, energy: 2, notes: "Need a break this afternoon.", createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
        JournalEntry(id: UUID(), mood: 5, energy: 4, notes: "Long run, felt great.", createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date())!)
    ]
}
