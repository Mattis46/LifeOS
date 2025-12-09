import Foundation
import Supabase

struct AppConfig {
    let supabaseURL: URL
    let supabaseAnonKey: String
    let coachEndpoint: URL

    init(bundle: Bundle = .main) {
        func read(_ key: String) -> String {
            guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
                  value.isEmpty == false else {
                fatalError("Missing \(key) in Info.plist / Config.xcconfig")
            }
            return value
        }

        supabaseURL = URL(string: read("SUPABASE_URL"))!
        supabaseAnonKey = read("SUPABASE_ANON_KEY")
        coachEndpoint = URL(string: read("COACH_ENDPOINT"))!
    }
}

@MainActor
final class AppServices: ObservableObject {
    let config: AppConfig
    let supabase: SupabaseClient
    let coachService: CoachService
    let taskStore: TaskStore
    let goalStore: GoalStore
    let habitStore: HabitStore
    let noteStore: NoteStore
    let categoryStore: CategoryStore
    let projectStore: ProjectStore
    let refresh = RefreshBus()

    init(config: AppConfig = AppConfig()) {
        self.config = config
        let options = SupabaseClientOptions(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
        supabase = SupabaseClient(
            supabaseURL: config.supabaseURL,
            supabaseKey: config.supabaseAnonKey,
            options: options
        )
        coachService = CoachService(endpoint: config.coachEndpoint)
        taskStore = TaskStore(client: supabase)
        goalStore = GoalStore(client: supabase)
        habitStore = HabitStore(client: supabase)
        noteStore = NoteStore(client: supabase)
        categoryStore = CategoryStore(client: supabase)
        projectStore = ProjectStore(client: supabase)
    }
}
