import Foundation
import EventKit

@MainActor
final class CalendarService: ObservableObject {
    private let store = EKEventStore()
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var lastError: String?

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestAccess(to: .event)
            authorizationStatus = granted ? .authorized : EKEventStore.authorizationStatus(for: .event)
            print("[CalendarService] requestAccess granted=\(granted) status=\(authorizationStatus.rawValue)")
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            print("[CalendarService] requestAccess error: \(error.localizedDescription)")
        }
    }

    func events(for day: Date) -> [EKEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    func addEvent(title: String, notes: String?, start: Date) async {
        lastError = nil
        print("[CalendarService] addEvent attempt title=\"\(title)\" start=\(start)")
        if authorizationStatus != .authorized {
            await requestAccess()
        }
        guard authorizationStatus == .authorized else {
            print("[CalendarService] addEvent aborted: status=\(authorizationStatus.rawValue)")
            return
        }
        // Nimm einen beschreibbaren Kalender (default oder erster beschreibbarer)
        guard let calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first(where: { $0.allowsContentModifications }) else {
            lastError = "Kein schreibbarer Kalender verfügbar."
            print("[CalendarService] addEvent aborted: no writable calendar")
            return
        }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.notes = notes
        event.startDate = start
        event.endDate = start.addingTimeInterval(60 * 60) // 1h Block
        event.calendar = calendar
        do {
            try store.save(event, span: .thisEvent, commit: true)
            print("[CalendarService] addEvent success title=\"\(title)\" calendar=\(calendar.title)")
        } catch {
            // Optional: Logging im DEBUG
            print("[CalendarService] addEvent error: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }
}
