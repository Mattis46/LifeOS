import Foundation
import Supabase

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [RemoteNote] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadNotes() async {
        isLoading = true
        errorMessage = nil
        do {
            notes = try await client
                .from("notes")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addNote(mood: Int?, energy: Int?, content: String?) async {
        do {
            let inserted: [RemoteNote] = try await client
                .from("notes")
                .insert(RemoteNote(id: nil, mood: mood, energy: energy, content: content))
                .select()
                .execute()
                .value
            if let first = inserted.first {
                notes.insert(first, at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
