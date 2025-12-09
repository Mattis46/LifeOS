import Foundation
import Supabase

@MainActor
final class CategoryStore: ObservableObject {
    @Published private(set) var categories: [RemoteCategory] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadCategories() async {
        isLoading = true
        errorMessage = nil
        do {
            categories = try await client
                .from("habit_categories")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addCategory(name: String) async {
        guard name.isEmpty == false else { return }
        do {
            let inserted: [RemoteCategory] = try await client
                .from("habit_categories")
                .insert(RemoteCategory(id: nil, name: name))
                .select()
                .execute()
                .value
            if let first = inserted.first {
                categories.insert(first, at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
