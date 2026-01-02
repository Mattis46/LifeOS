import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Label("Einstellungen folgen hier", systemImage: "person.circle")
                }
                Section("App") {
                    Label("Benachrichtigungen", systemImage: "bell")
                    Label("Datenschutz", systemImage: "lock.shield")
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}
