import Foundation

struct CoachContext: Encodable {
    var focusTasks: [String]
    var habits: [String]
    var moodAverage: Double
    var energyAverage: Double
    var reflections: [String]
}

struct CoachSuggestion: Identifiable, Decodable {
    var id: UUID = .init()
    var focus: [String]
    var nudges: [String]
    var reflection: String?
}

@MainActor
final class CoachService {
    private let endpoint: URL
    private let decoder = JSONDecoder()

    init(endpoint: URL) {
        self.endpoint = endpoint
    }

    func fetchSuggestion(context: CoachContext) async throws -> CoachSuggestion {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["context": context])

        let (data, _) = try await URLSession.shared.data(for: request)
        if let suggestion = try? decoder.decode(CoachSuggestion.self, from: data) {
            return suggestion
        }

        // If server returns raw text, wrap it gracefully
        if let text = String(data: data, encoding: .utf8) {
            return CoachSuggestion(focus: [], nudges: [text], reflection: nil)
        }

        return CoachSuggestion(focus: [], nudges: ["No response received."], reflection: nil)
    }
}
