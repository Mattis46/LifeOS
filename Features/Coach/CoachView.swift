import SwiftUI

struct CoachView: View {
    @EnvironmentObject private var services: AppServices
    @State private var suggestion: CoachSuggestion?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let suggestion {
                    CoachCard(suggestion: suggestion)
                } else if isLoading {
                    ProgressView("Coach denkt …")
                } else {
                    Text("Hol dir einen Tages-Impuls.")
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button(action: fetch) {
                    Label("Empfehlung holen", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Coach")
        }
    }

    private func fetch() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let context = CoachContext(
                    focusTasks: SampleData.tasks.map(\.title),
                    habits: SampleData.habits.map(\.title),
                    moodAverage: Double(SampleData.journal.map(\.mood).reduce(0, +)) / Double(SampleData.journal.count),
                    energyAverage: Double(SampleData.journal.map(\.energy).reduce(0, +)) / Double(SampleData.journal.count),
                    reflections: SampleData.journal.map(\.notes)
                )
                suggestion = try await services.coachService.fetchSuggestion(context: context)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

private struct CoachCard: View {
    let suggestion: CoachSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if suggestion.focus.isEmpty == false {
                Text("Fokus")
                    .font(.headline)
                ForEach(suggestion.focus, id: \.self) { item in
                    Label(item, systemImage: "target")
                }
            }
            if suggestion.nudges.isEmpty == false {
                Text("Nudges")
                    .font(.headline)
                ForEach(suggestion.nudges, id: \.self) { item in
                    Label(item, systemImage: "lightbulb")
                }
            }
            if let reflection = suggestion.reflection {
                Text("Reflexion")
                    .font(.headline)
                Text(reflection)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
