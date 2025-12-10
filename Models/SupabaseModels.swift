import Foundation

struct RemoteTask: Identifiable, Codable, Hashable {
    enum Status: String, Codable, CaseIterable {
        case open, inProgress = "in_progress", done, blocked

        var display: String {
            switch self {
            case .open: return "Offen"
            case .inProgress: return "Läuft"
            case .done: return "Fertig"
            case .blocked: return "Blockiert"
            }
        }
    }

    let id: UUID?
    var title: String
    var description: String?
    var status: Status
    var due: Date?
    var goalId: UUID?
    var projectId: UUID?
    var categoryId: UUID?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, status, due, description
        case goalId = "goal_id"
        case projectId = "project_id"
        case categoryId = "category_id"
        case createdAt = "created_at"
    }

    init(
        id: UUID? = nil,
        title: String,
        description: String? = nil,
        status: Status = .open,
        due: Date? = nil,
        goalId: UUID? = nil,
        projectId: UUID? = nil,
        categoryId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.due = due
        self.goalId = goalId
        self.projectId = projectId
        self.categoryId = categoryId
    }
}

struct RemoteHabit: Identifiable, Codable, Hashable {
    let id: UUID?
    var title: String
    var cadence: String
    var streak: Int?
    var goalId: UUID?
    var categoryId: UUID?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, cadence, streak
        case goalId = "goal_id"
        case categoryId = "category_id"
        case createdAt = "created_at"
    }
}

struct RemoteGoal: Identifiable, Codable, Hashable {
    enum Horizon: String, Codable, CaseIterable { case short, mid, long }

    let id: UUID?
    var title: String
    var horizon: Horizon
    var notes: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, horizon, notes
        case createdAt = "created_at"
    }
}

struct RemoteCategory: Identifiable, Codable, Hashable {
    let id: UUID?
    var name: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
    }
}

struct RemoteProject: Identifiable, Codable, Hashable {
    let id: UUID?
    var name: String
    var notes: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case createdAt = "created_at"
    }
}

struct RemoteNote: Identifiable, Codable, Hashable {
    enum NoteType: String, Codable { case journal, note }

    let id: UUID?
    var title: String?
    var noteType: NoteType?
    var mood: Int?
    var energy: Int?
    var content: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title
        case noteType = "note_type"
        case mood, energy, content
        case createdAt = "created_at"
    }
}
