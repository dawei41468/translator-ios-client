import SwiftUI

struct MessageListView: View {
    @Binding var messages: [TranslatedMessage]
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                // Scroll to the latest message when new messages arrive
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
                // Scroll to bottom on initial load
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: TranslatedMessage

    var body: some View {
        HStack {
            if message.isOwn {
                Spacer()
            }

            VStack(alignment: message.isOwn ? .trailing : .leading, spacing: 6) {
                // Speaker name
                Text(message.speakerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: message.isOwn ? .trailing : .leading)

                // Original text (smaller, more subtle)
                if !message.originalText.isEmpty {
                    Text("\"\(message.originalText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary.opacity(0.7))
                        .italic()
                        .frame(maxWidth: .infinity, alignment: message.isOwn ? .trailing : .leading)
                }

                // Translated text (prominent)
                Text(message.translatedText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: message.isOwn ? .trailing : .leading)

                // Language indicator
                HStack(spacing: 4) {
                    Text(message.sourceLang.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray4).opacity(0.5))
                        .cornerRadius(8)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(message.targetLang.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray4).opacity(0.5))
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: message.isOwn ? .trailing : .leading)
            }
            .padding(16)
            .background(message.isOwn ? Color.blue.opacity(0.15) : Color(.systemGray6))
            .cornerRadius(20)
            .frame(maxWidth: 320, alignment: message.isOwn ? .trailing : .leading)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

            if !message.isOwn {
                Spacer()
            }
        }
    }
}

#Preview {
    MessageListView(messages: .constant([
        TranslatedMessage(originalText: "Hello, how are you today?", translatedText: "Hola, ¿cómo estás hoy?", sourceLang: "en", targetLang: "es", fromUserId: "1", toUserId: "2", speakerName: "Alice", isOwn: false),
        TranslatedMessage(originalText: "I'm doing great, thank you for asking!", translatedText: "¡Me va genial, gracias por preguntar!", sourceLang: "en", targetLang: "es", fromUserId: "2", toUserId: "1", speakerName: "Bob", isOwn: true),
        TranslatedMessage(originalText: "That's wonderful to hear", translatedText: "Qué maravilloso escuchar eso", sourceLang: "en", targetLang: "es", fromUserId: "1", toUserId: "2", speakerName: "Alice", isOwn: false)
    ]))
}