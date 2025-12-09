import SwiftUI

struct JournalView: View {
    @EnvironmentObject private var services: AppServices
    @State private var showAddNote = false
    @State private var noteText = ""
    @State private var mood: Int = 3
    @State private var energy: Int = 3

    var body: some View {
        NavigationStack {
            List {
                if let error = services.noteStore.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                if services.noteStore.isLoading {
                    ProgressView()
                } else if services.noteStore.notes.isEmpty {
                    Text("Keine Einträge").foregroundStyle(.secondary)
                } else {
                    ForEach(services.noteStore.notes) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                if let mood = entry.mood {
                                    Label("Mood \(mood)", systemImage: "face.smiling")
                                }
                                Spacer()
                                if let energy = entry.energy {
                                    Label("Energie \(energy)", systemImage: "bolt")
                                }
                            }
                            .font(.caption)
                            if let text = entry.content, text.isEmpty == false {
                                Text(text)
                            }
                            if let date = entry.createdAt {
                                Text(date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Journal")
            .refreshable {
                await services.noteStore.loadNotes()
            }
            .toolbar {
                Button {
                    showAddNote = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
            .task {
                if services.noteStore.notes.isEmpty {
                    await services.noteStore.loadNotes()
                }
            }
            .sheet(isPresented: $showAddNote) {
                NavigationStack {
                    Form {
                        Section("Stimmung & Energie") {
                            Stepper("Mood \(mood)", value: $mood, in: 1...5)
                            Stepper("Energie \(energy)", value: $energy, in: 1...5)
                        }
                        Section("Notizen") {
                            TextField("Was bewegt dich?", text: $noteText, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                        }
                    }
                    .navigationTitle("Neuer Eintrag")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") { showAddNote = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Speichern") {
                                let content = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                                Task { await services.noteStore.addNote(mood: mood, energy: energy, content: content) }
                                noteText = ""
                                showAddNote = false
                            }
                        }
                    }
                }
            }
        }
    }
}
