import SwiftUI

struct JournalView: View {
    private let entries = SampleData.journal.sorted { $0.createdAt > $1.createdAt }

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Mood \(entry.mood)", systemImage: "face.smiling")
                            Spacer()
                            Label("Energie \(entry.energy)", systemImage: "bolt")
                        }
                        .font(.caption)
                        Text(entry.notes)
                        Text(entry.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                Button {
                    // Add entry
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }
}
