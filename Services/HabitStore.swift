import Foundation
import Supabase

@MainActor
final class HabitStore: ObservableObject {
    @Published private(set) var habits: [RemoteHabit] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadHabits() async {
        isLoading = true
        errorMessage = nil
        do {
            habits = try await client
                .from("habits")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            habits = Array(habits)
            objectWillChange.send()
        } catch {
            let nsError = error as NSError
            let isCancel = (error is CancellationError) || nsError.code == URLError.cancelled.rawValue || nsError.localizedDescription.lowercased() == "cancelled"
            if isCancel {
                // Ignoriere Abbruch (z.B. Pull-to-refresh)
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func addHabit(title: String, cadence: String = "Daily", goalId: UUID? = nil, categoryId: UUID? = nil) async {
        guard title.isEmpty == false else { return }
        do {
            let inserted: [RemoteHabit] = try await client
                .from("habits")
                .insert(RemoteHabit(id: nil, title: title, cadence: cadence, streak: 0, goalId: goalId, categoryId: categoryId))
                .select()
                .execute()
                .value
            if let first = inserted.first {
                habits.insert(first, at: 0)
                habits = Array(habits)
                objectWillChange.send()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateHabit(_ habit: RemoteHabit) async {
        guard let id = habit.id else { return }
        do {
            let updated: [RemoteHabit] = try await client
                .from("habits")
                .update(habit)
                .eq("id", value: id)
                .select()
                .execute()
                .value
            if let first = updated.first, let idx = habits.firstIndex(where: { $0.id == id }) {
                habits[idx] = first
                habits = Array(habits)
                objectWillChange.send()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
