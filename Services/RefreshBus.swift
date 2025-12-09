import Foundation

@MainActor
final class RefreshBus: ObservableObject {
    enum Event {
        case tasks, habits, goals, notes, projects, categories
    }

    func send(_ event: Event) {
        objectWillChange.send()
    }
}
