import SwiftUI
import UIKit

struct JournalView: View {
    @EnvironmentObject private var services: AppServices
    @State private var showAddNote = false
    @State private var entryTitle = ""
    @State private var noteText = ""
    @State private var mood: Int = 3
    @State private var energy: Int = 3
    @State private var entryType: EntryType = .journal

    var body: some View {
        NavigationStack {
            List {
                Picker("Typ", selection: $entryType) {
                    Text("Journal").tag(EntryType.journal)
                    Text("Notizen").tag(EntryType.note)
                }
                .pickerStyle(.segmented)

                if let error = services.noteStore.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                if services.noteStore.isLoading {
                    ProgressView()
                } else {
                    let entries = entryType == .journal ? journalEntries : notes
                    if entries.isEmpty {
                        Text("Keine Einträge").foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            NavigationLink {
                                JournalDetailView(entry: entry)
                            } label: {
                                JournalRow(entry: entry)
                            }
                        }
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
                        Section("Typ") {
                            Picker("Typ", selection: $entryType) {
                                Text("Journal-Eintrag").tag(EntryType.journal)
                                Text("Notiz").tag(EntryType.note)
                            }
                            .pickerStyle(.segmented)
                        }
                        Section("Titel") {
                            TextField("Titel", text: $entryTitle)
                        }
                        if entryType == .journal {
                            Section("Stimmung & Energie") {
                                Stepper("Mood \(mood)", value: $mood, in: 1...5)
                                Stepper("Energie \(energy)", value: $energy, in: 1...5)
                            }
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
                                let title = entryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                let content = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                                let moodValue = entryType == .journal ? mood : nil
                                let energyValue = entryType == .journal ? energy : nil
                                Task {
                                    await services.noteStore.addNote(
                                        title: title.isEmpty ? nil : title,
                                        noteType: entryType == .journal ? .journal : .note,
                                        mood: moodValue,
                                        energy: energyValue,
                                        content: content
                                    )
                                    await services.noteStore.loadNotes()
                                }
                                resetForm()
                            }
                        }
                    }
                }
            }
        }
    }

    private var journalEntries: [RemoteNote] {
        services.noteStore.notes.filter {
            if let type = $0.noteType {
                return type == .journal
            } else {
                return ($0.mood != nil) || ($0.energy != nil)
            }
        }
    }

    private var notes: [RemoteNote] {
        services.noteStore.notes.filter {
            if let type = $0.noteType {
                return type == .note
            } else {
                return $0.mood == nil && $0.energy == nil
            }
        }
    }

    private func resetForm() {
        noteText = ""
        mood = 3
        energy = 3
        entryType = .journal
        showAddNote = false
        entryTitle = ""
    }

    private enum EntryType: Hashable {
        case journal, note
    }
}

private struct JournalRow: View {
    let entry: RemoteNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = entry.title, title.isEmpty == false {
                Text(title)
                    .font(.headline)
            }
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
                    .lineLimit(2)
            } else {
                Text("Kein Text").foregroundStyle(.secondary)
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

private struct JournalDetailView: View {
    @EnvironmentObject private var services: AppServices
    @Environment(\.dismiss) private var dismiss
    let entry: RemoteNote
    @State private var title: String
    @State private var content: String
    @State private var mood: Int?
    @State private var energy: Int?
    @State private var noteType: RemoteNote.NoteType

    init(entry: RemoteNote) {
        self.entry = entry
        _title = State(initialValue: entry.title ?? "")
        _content = State(initialValue: entry.content ?? "")
        _mood = State(initialValue: entry.mood)
        _energy = State(initialValue: entry.energy)
        _noteType = State(initialValue: entry.noteType ?? ((entry.mood != nil || entry.energy != nil) ? .journal : .note))
    }

    var body: some View {
        Form {
            if entry.mood != nil || entry.energy != nil {
                Section("Stimmung & Energie") {
                    Stepper("Mood \(mood ?? 3)", value: Binding(
                        get: { mood ?? 3 },
                        set: { mood = $0 }
                    ), in: 1...5)
                    Stepper("Energie \(energy ?? 3)", value: Binding(
                        get: { energy ?? 3 },
                        set: { energy = $0 }
                    ), in: 1...5)
                }
            }
            Section("Titel") {
                TextField("Titel", text: $title)
            }
            Section("Inhalt") {
                TextEditor(text: $content)
                    .font(.body)
                    .frame(minHeight: contentHeight(), alignment: .topLeading)
                    .padding(.vertical, 4)
            }
            if let date = entry.createdAt {
                Section("Datum") {
                    Text(date, style: .date)
                    Text(date, style: .time)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Eintrag")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Speichern") { save() }
            }
        }
    }

    private func save() {
        guard let id = entry.id else { return }
        let updated = RemoteNote(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            noteType: noteType,
            mood: mood,
            energy: energy,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: entry.createdAt
        )
        Task {
            await services.noteStore.updateNote(updated)
            await services.noteStore.loadNotes()
            dismiss()
        }
    }

    // Make the text field as tall as its content (with a sensible minimum).
    private func contentHeight() -> CGFloat {
        let textToMeasure = content.isEmpty ? " " : content
        let font = UIFont.preferredFont(forTextStyle: .body)
        // Rough available width inside the form row.
        let availableWidth = UIScreen.main.bounds.width - 32
        let rect = (textToMeasure as NSString).boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        // Minimum height to keep it usable even for kurze Texte.
        return max(120, ceil(rect.height) + 24)
    }
}
