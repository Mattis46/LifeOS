import Foundation
import Supabase

@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [RemoteProject] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadProjects() async {
        isLoading = true
        errorMessage = nil
        do {
            projects = try await client
                .from("projects")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addProject(name: String, notes: String? = nil) async {
        guard name.isEmpty == false else { return }
        do {
            let inserted: [RemoteProject] = try await client
                .from("projects")
                .insert(RemoteProject(id: nil, name: name, notes: notes))
                .select()
                .execute()
                .value
            if let first = inserted.first {
                projects.insert(first, at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
