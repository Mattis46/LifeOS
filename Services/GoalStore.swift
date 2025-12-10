import Foundation
import Supabase

@MainActor
final class GoalStore: ObservableObject {
    @Published private(set) var goals: [RemoteGoal] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadGoals() async {
        isLoading = true
        errorMessage = nil
        do {
            goals = try await client
                .from("goals")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            goals = Array(goals)
            objectWillChange.send()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addGoal(title: String, horizon: RemoteGoal.Horizon = .short, notes: String? = nil) async {
        guard title.isEmpty == false else { return }
        do {
            let inserted: [RemoteGoal] = try await client
                .from("goals")
                .insert(RemoteGoal(id: nil, title: title, horizon: horizon, notes: notes))
                .select()
                .execute()
                .value
            if let first = inserted.first {
                goals.insert(first, at: 0)
                goals = Array(goals)
                objectWillChange.send()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateGoal(_ goal: RemoteGoal) async {
        guard let id = goal.id else { return }
        do {
            let updated: [RemoteGoal] = try await client
                .from("goals")
                .update(goal)
                .eq("id", value: id)
                .select()
                .execute()
                .value
            if let first = updated.first, let idx = goals.firstIndex(where: { $0.id == id }) {
                goals[idx] = first
                goals = Array(goals)
                objectWillChange.send()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
