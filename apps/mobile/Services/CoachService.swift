import Foundation

struct AgentGoal: Encodable {
    var id: String?
    var title: String
    var horizon: String?
    var progress: Double?
    var status: String?
}

struct AgentTask: Encodable {
    var id: String?
    var title: String
    var status: String?
    var due: String?
    var goal_id: String?
}

struct AgentHabit: Encodable {
    var id: String?
    var title: String
    var streak: Int?
    var goal_id: String?
}

struct AgentRequest: Encodable {
    var mode: String
    var goals: [AgentGoal]
    var tasks: [AgentTask]
    var habits: [AgentHabit]
    var notes: [String]
    var focus_goal_id: String?
}

struct AgentResponse: Identifiable, Decodable {
    var id: UUID = .init()
    var insights: [String]
    var today_actions: [AgentAction]
    var milestones: [AgentMilestone]
    var habit_suggestions: [String]
    var questions: [String]
    var ops: [AgentOperation]

    enum CodingKeys: String, CodingKey {
        case insights
        case today_actions
        case milestones
        case habit_suggestions
        case questions
        case ops
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        insights = try container.decodeIfPresent([String].self, forKey: .insights) ?? []
        today_actions = try container.decodeIfPresent([AgentAction].self, forKey: .today_actions) ?? []
        milestones = try container.decodeIfPresent([AgentMilestone].self, forKey: .milestones) ?? []
        habit_suggestions = try container.decodeIfPresent([String].self, forKey: .habit_suggestions) ?? []
        questions = try container.decodeIfPresent([String].self, forKey: .questions) ?? []
        ops = try container.decodeIfPresent([AgentOperation].self, forKey: .ops) ?? []
    }
}

struct AgentAction: Identifiable, Decodable {
    var id: UUID = .init()
    var title: String
    var reason: String?
    var goal_id: String?
    var due_hint: String?
}

struct AgentMilestone: Identifiable, Decodable {
    var id: UUID = .init()
    var goal_id: String?
    var title: String
    var steps: [String]?
}

struct AgentOperation: Identifiable, Decodable {
    enum OpType: String, Decodable {
        case create_task
        case create_habit
        case create_goal
    }
    var id: UUID = .init()
    var type: OpType
    var title: String
    var detail: String?
    var goal_id: String?
    var due_date: String?
    var horizon: String?
    var frequency: String?
}

struct AgentChatMessage: Encodable, Decodable, Identifiable {
    enum Role: String, Encodable, Decodable {
        case user, assistant, system
    }
    var id: UUID = .init()
    var role: Role
    var content: String
}

struct AgentChatResponse: Decodable {
    let reply: String
}

private struct ChatMessagePayload: Encodable {
    let role: String
    let content: String
}

private struct ChatRequest: Encodable {
    let mode: String = "chat"
    let goals: [AgentGoal] = []
    let tasks: [AgentTask] = []
    let habits: [AgentHabit] = []
    let notes: [String] = []
    let focus_goal_id: String? = nil
    let chat_history: [ChatMessagePayload]
}

@MainActor
final class CoachService {
    private let endpoint: URL
    private let decoder = JSONDecoder()

    init(endpoint: URL) {
        self.endpoint = endpoint
    }

    func runAgent(request payload: AgentRequest) async throws -> AgentResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(AgentResponse.self, from: data)
    }

    func runChat(messages: [AgentChatMessage]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ChatRequest(
            chat_history: messages.map { ChatMessagePayload(role: $0.role.rawValue, content: $0.content) }
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        let resp = try decoder.decode(AgentChatResponse.self, from: data)
        return resp.reply
    }
}
