import Foundation
import Supabase

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [RemoteTask] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadTasks() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: [RemoteTask] = try await client
                .from("tasks")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            tasks = response
            tasks = Array(tasks)
            objectWillChange.send()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addTask(
        title: String,
        description: String? = nil,
        due: Date? = nil,
        goalId: UUID? = nil,
        projectId: UUID? = nil,
        categoryId: UUID? = nil
    ) async {
        guard title.isEmpty == false else { return }
        do {
            let inserted: [RemoteTask] = try await client
                .from("tasks")
                .insert(
                    RemoteTask(
                        title: title,
                        description: description,
                        due: due,
                        goalId: goalId,
                        projectId: projectId,
                        categoryId: categoryId
                    )
                )
                .select()
                .execute()
                .value
            if let first = inserted.first {
                tasks.insert(first, at: 0)
                tasks = Array(tasks)
                objectWillChange.send()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTask(_ task: RemoteTask) async {
        guard let id = task.id else { return }
        do {
            let updated: [RemoteTask] = try await client
                .from("tasks")
                .update(task)
                .eq("id", value: id)
                .select()
                .execute()
                .value
            if let first = updated.first, let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx] = first
                tasks = Array(tasks)
                objectWillChange.send()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
