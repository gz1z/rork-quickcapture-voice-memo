import Foundation
import SwiftData

@Model
final class VoiceMemo {
    var id: UUID
    var timestamp: Date
    var duration: TimeInterval
    var transcription: String
    var audioFileName: String
    var isSentToNotion: Bool
    var isSentToTelegram: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        duration: TimeInterval = 0,
        transcription: String = "",
        audioFileName: String = "",
        isSentToNotion: Bool = false,
        isSentToTelegram: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
        self.transcription = transcription
        self.audioFileName = audioFileName
        self.isSentToNotion = isSentToNotion
        self.isSentToTelegram = isSentToTelegram
    }

    var audioFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(audioFileName)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
