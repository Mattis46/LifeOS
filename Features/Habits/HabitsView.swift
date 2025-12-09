import SwiftUI

struct HabitsView: View {
    private let habits = SampleData.habits

    var body: some View {
        NavigationStack {
            List {
                ForEach(habits) { habit in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(habit.title)
                                .font(.headline)
                            Text("\(habit.cadence) • Streak \(habit.streak)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            // Mark completion
                        } label: {
                            Image(systemName: "checkmark.circle")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Gewohnheiten")
            .toolbar {
                Button {
                    // Add habit
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
