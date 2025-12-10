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
    var colorHex: String?
    var icon: String?
    var targetDate: Date?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, horizon, notes
        case colorHex = "color_hex"
        case icon
        case targetDate = "target_date"
        case createdAt = "created_at"
    }

    init(
        id: UUID? = nil,
        title: String,
        horizon: Horizon,
        notes: String? = nil,
        colorHex: String? = nil,
        icon: String? = nil,
        targetDate: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.horizon = horizon
        self.notes = notes
        self.colorHex = colorHex
        self.icon = icon
        self.targetDate = targetDate
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        horizon = try container.decode(Horizon.self, forKey: .horizon)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)

        // target_date kann als date (yyyy-MM-dd) oder ISO-Timestamp kommen; beide Formate abdecken.
        if let dateValue = try? container.decodeIfPresent(Date.self, forKey: .targetDate) {
            targetDate = dateValue
        } else if let dateString = try container.decodeIfPresent(String.self, forKey: .targetDate) {
            targetDate = RemoteGoal.dateParser(dateString)
        } else {
            targetDate = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(horizon, forKey: .horizon)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)

        if let targetDate {
            // Supabase date-Spalte akzeptiert "yyyy-MM-dd"; Fallback auf ISO8601, falls nötig.
            let dateString = RemoteGoal.dateFormatter.string(from: targetDate)
            try container.encode(dateString, forKey: .targetDate)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return f
    }()

    private static func dateParser(_ value: String) -> Date? {
        if let d = dateFormatter.date(from: value) { return d }
        if let d = isoFormatter.date(from: value) { return d }
        return nil
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
