import SwiftUI

struct GoalsView: View {
    private let goals = SampleData.goals

    var body: some View {
        NavigationStack {
            List {
                ForEach(goals) { goal in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goal.title)
                            .font(.headline)
                        Text(goal.notes)
                            .foregroundStyle(.secondary)
                        Label(goal.horizon.rawValue.capitalized, systemImage: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Ziele")
            .toolbar {
                Button {
                    // Add goal
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
