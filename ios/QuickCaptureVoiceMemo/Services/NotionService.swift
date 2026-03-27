import Foundation

nonisolated struct NotionService: Sendable {
    func sendMemo(transcription: String, duration: String, date: Date, apiKey: String, pageId: String) async throws {
        let url = URL(string: "https://api.notion.com/v1/pages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: date)

        let body: [String: Any] = [
            "parent": ["page_id": pageId],
            "properties": [
                "title": [
                    "title": [
                        ["text": ["content": "Voice Memo — \(duration)"]]
                    ]
                ]
            ],
            "children": [
                [
                    "object": "block",
                    "type": "callout",
                    "callout": [
                        "icon": ["type": "emoji", "emoji": "🎙️"],
                        "rich_text": [
                            ["type": "text", "text": ["content": "Recorded on \(dateString)"]]
                        ]
                    ]
                ],
                [
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": [
                        "rich_text": [
                            ["type": "text", "text": ["content": transcription]]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ServiceError.notionFailed
        }
    }
}

nonisolated enum ServiceError: Error, LocalizedError, Sendable {
    case notionFailed
    case telegramFailed
    case noTranscription

    var errorDescription: String? {
        switch self {
        case .notionFailed: "Failed to send to Notion"
        case .telegramFailed: "Failed to send to Telegram"
        case .noTranscription: "Could not transcribe audio"
        }
    }
}
