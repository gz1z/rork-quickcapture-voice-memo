import Foundation

nonisolated struct TelegramService: Sendable {
    func sendMemo(transcription: String, duration: String, date: Date, botToken: String, chatId: String) async throws {
        let url = URL(string: "https://api.telegram.org/bot\(botToken)/sendMessage")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let message = """
        🎙️ *Voice Memo* — \(duration)
        📅 \(formatter.string(from: date))

        \(transcription)
        """

        let body: [String: Any] = [
            "chat_id": chatId,
            "text": message,
            "parse_mode": "Markdown"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ServiceError.telegramFailed
        }
    }
}
