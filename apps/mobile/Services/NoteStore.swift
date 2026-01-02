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
            notes = Array(notes)
            objectWillChange.send()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addNote(title: String?, noteType: RemoteNote.NoteType, mood: Int?, energy: Int?, content: String?) async {
        do {
            let inserted: [RemoteNote] = try await client
                .from("notes")
                .insert(RemoteNote(id: nil, title: title, noteType: noteType, mood: mood, energy: energy, content: content))
                .select()
                .execute()
                .value
            if let first = inserted.first {
                notes.insert(first, at: 0)
                notes = Array(notes)
                objectWillChange.send()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNote(_ note: RemoteNote) async {
        guard let id = note.id else { return }
        struct Payload: Encodable {
            let title: String?
            let note_type: String?
            let mood: Int?
            let energy: Int?
            let content: String?
        }
        do {
            let payload = Payload(
                title: note.title,
                note_type: note.noteType?.rawValue,
                mood: note.mood,
                energy: note.energy,
                content: note.content
            )
            let updated: [RemoteNote] = try await client
                .from("notes")
                .update(payload)
                .eq("id", value: id)
                .select()
                .execute()
                .value
            if let first = updated.first, let idx = notes.firstIndex(where: { $0.id == id }) {
                notes[idx] = first
                notes = Array(notes)
                objectWillChange.send()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
