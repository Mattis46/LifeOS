import Foundation
import Supabase

@MainActor
final class MilestoneStore: ObservableObject {
    @Published private(set) var milestones: [RemoteMilestone] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadMilestones(goalId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            var query = client
                .from("milestones")
                .select()
            if let goalId {
                query = query.eq("goal_id", value: goalId)
            }
            milestones = try await query
                .order("due", ascending: true, nullsFirst: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            milestones = Array(milestones)
            objectWillChange.send()
        } catch {
            let nsError = error as NSError
            let isCancel = (error is CancellationError) || nsError.code == URLError.cancelled.rawValue || nsError.localizedDescription.lowercased() == "cancelled"
            if isCancel == false {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func addMilestone(goalId: UUID?, title: String, due: Date? = nil) async {
        guard title.isEmpty == false else { return }
        do {
            let inserted: [RemoteMilestone] = try await client
                .from("milestones")
                .insert(RemoteMilestone(goalId: goalId, title: title, due: due))
                .select()
                .execute()
                .value
            if let first = inserted.first {
                milestones.insert(first, at: 0)
                milestones = Array(milestones)
                objectWillChange.send()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMilestone(_ milestone: RemoteMilestone) async {
        guard let id = milestone.id else { return }
        do {
            let updated: [RemoteMilestone] = try await client
                .from("milestones")
                .update(milestone)
                .eq("id", value: id)
                .select()
                .execute()
                .value
            if let first = updated.first, let idx = milestones.firstIndex(where: { $0.id == id }) {
                milestones[idx] = first
                milestones = Array(milestones)
                objectWillChange.send()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleMilestone(_ milestone: RemoteMilestone) async {
        var updated = milestone
        updated.isDone.toggle()
        await updateMilestone(updated)
    }
}
