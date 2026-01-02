import SwiftUI

struct CoachView: View {
    @EnvironmentObject private var services: AppServices
    @State private var messages: [AgentChatMessage] = [
        AgentChatMessage(role: .assistant, content: "Hey, ich bin dein LifeOS Coach. Frag mich, was dir gerade hilft – Fokus, kleiner Schritt, Muster.")
    ]
    @State private var input: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { msg in
                                chatBubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                HStack(spacing: 8) {
                    TextField("Nachricht an den Coach …", text: $input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isSending)
                    Button {
                        send()
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Coach")
        }
    }

    @ViewBuilder
    private func chatBubble(_ msg: AgentChatMessage) -> some View {
        let isUser = msg.role == .user
        HStack {
            if isUser { Spacer() }
            Text(msg.content)
                .padding(10)
                .background(isUser ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if !isUser { Spacer() }
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        input = ""
        errorMessage = nil
        let userMsg = AgentChatMessage(role: .user, content: text)
        messages.append(userMsg)
        isSending = true
        Task {
            do {
                let reply = try await services.coachService.runChat(messages: messages)
                messages.append(AgentChatMessage(role: .assistant, content: reply))
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}
