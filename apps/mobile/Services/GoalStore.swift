import Foundation
import Supabase

@MainActor
final class GoalStore: ObservableObject {
    @Published private(set) var goals: [RemoteGoal] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client: SupabaseClient
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadGoals() async {
        isLoading = true
        errorMessage = nil
        do {
            #if DEBUG
            print("[GoalStore] loadGoals() start")
            #endif
            goals = try await client
                .from("goals")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            goals = Array(goals)
            objectWillChange.send()
            #if DEBUG
            print("[GoalStore] loadGoals() success count=\(goals.count)")
            goals.prefix(3).forEach { g in
                print("  - \(g.title) color=\(g.colorHex ?? "nil") icon=\(g.icon ?? "nil") targetDate=\(String(describing: g.targetDate))")
            }
            #endif
        } catch {
            let nsError = error as NSError
            let isCancel = (error is CancellationError)
                || nsError.code == URLError.cancelled.rawValue
                || nsError.localizedDescription.lowercased() == "cancelled"
            if isCancel {
                #if DEBUG
                print("[GoalStore] loadGoals() cancelled (ignored)")
                #endif
            } else {
                errorMessage = error.localizedDescription
                #if DEBUG
                print("[GoalStore] loadGoals() error: \(error.localizedDescription)")
                #endif
            }
        }
        isLoading = false
    }

    func addGoal(
        title: String,
        horizon: RemoteGoal.Horizon = .short,
        purpose: String? = nil,
        identityTag: String? = nil,
        notes: String? = nil,
        colorHex: String? = "#4F46E5",
        icon: String? = "target",
        targetDate: Date? = nil
    ) async {
        guard title.isEmpty == false else { return }
        struct Payload: Encodable {
            let title: String
            let horizon: String
            let purpose: String?
            let identity_tag: String?
            let notes: String?
            let color_hex: String?
            let icon: String?
            let target_date: String?
        }
        do {
            let payload = Payload(
                title: title,
                horizon: horizon.rawValue,
                purpose: purpose,
                identity_tag: identityTag,
                notes: notes,
                color_hex: (colorHex?.isEmpty == false ? colorHex : "#4F46E5"),
                icon: (icon?.isEmpty == false ? icon : "target"),
                target_date: targetDate.map { dateFormatter.string(from: $0) }
            )
            #if DEBUG
            print("[GoalStore] addGoal payload title=\"\(payload.title)\" color=\(payload.color_hex ?? "nil") icon=\(payload.icon ?? "nil") target_date=\(payload.target_date ?? "nil")")
            #endif
            let inserted: [RemoteGoal] = try await client
                .from("goals")
                .insert(payload)
                .select()
                .execute()
                .value
            if let first = inserted.first {
                goals.insert(first, at: 0)
                goals = Array(goals)
                objectWillChange.send()
                #if DEBUG
                print("[GoalStore] addGoal inserted id=\(first.id?.uuidString ?? "nil") color=\(first.colorHex ?? "nil") icon=\(first.icon ?? "nil") targetDate=\(String(describing: first.targetDate))")
                #endif
            }
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[GoalStore] addGoal error: \(error.localizedDescription)")
            #endif
        }
    }

    func updateGoal(_ goal: RemoteGoal) async {
        guard let id = goal.id else { return }
        struct Payload: Encodable {
            let title: String
            let horizon: String
            let purpose: String?
            let identity_tag: String?
            let notes: String?
            let color_hex: String?
            let icon: String?
            let target_date: String?
        }
        do {
            let payload = Payload(
                title: goal.title,
                horizon: goal.horizon.rawValue,
                purpose: goal.purpose,
                identity_tag: goal.identityTag,
                notes: goal.notes,
                color_hex: (goal.colorHex?.isEmpty == false ? goal.colorHex : "#4F46E5"),
                icon: (goal.icon?.isEmpty == false ? goal.icon : "target"),
                target_date: goal.targetDate.map { dateFormatter.string(from: $0) }
            )
            #if DEBUG
            print("[GoalStore] updateGoal payload id=\(id.uuidString) color=\(payload.color_hex ?? "nil") icon=\(payload.icon ?? "nil") target_date=\(payload.target_date ?? "nil")")
            #endif
            let updated: [RemoteGoal] = try await client
                .from("goals")
                .update(payload)
                .eq("id", value: id)
                .select()
                .execute()
                .value
            if let first = updated.first, let idx = goals.firstIndex(where: { $0.id == id }) {
                goals[idx] = first
                goals = Array(goals)
                objectWillChange.send()
                #if DEBUG
                print("[GoalStore] updateGoal updated id=\(id.uuidString) color=\(first.colorHex ?? "nil") icon=\(first.icon ?? "nil") targetDate=\(String(describing: first.targetDate))")
                #endif
            }
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[GoalStore] updateGoal error: \(error.localizedDescription)")
            #endif
        }
    }

    func deleteGoal(_ id: UUID) async {
        do {
            try await client
                .from("goals")
                .delete()
                .eq("id", value: id)
                .execute()
            goals.removeAll { $0.id == id }
            goals = Array(goals)
            objectWillChange.send()
            #if DEBUG
            print("[GoalStore] deleteGoal id=\(id.uuidString) removed")
            #endif
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[GoalStore] deleteGoal error: \(error.localizedDescription)")
            #endif
        }
    }
}
