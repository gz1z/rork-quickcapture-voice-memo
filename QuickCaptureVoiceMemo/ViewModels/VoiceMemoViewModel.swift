import Foundation
import SwiftData
import AVFoundation

@MainActor
@Observable
final class VoiceMemoViewModel {
    var recordingState: RecordingState = .idle
    var currentTranscription: String = ""
    var errorMessage: String?
    var showError = false
    var sendingStatus: SendingStatus = .idle

    enum RecordingState {
        case idle
        case recording
        case processing
        case done
    }

    enum SendingStatus {
        case idle
        case sending
        case sent
        case failed(String)
    }

    let recorder = AudioRecorderService()
    let transcriber = TranscriptionService()
    let settings: SettingsManager

    private var currentAudioURL: URL?
    private var currentFileName: String?

    init(settings: SettingsManager) {
        self.settings = settings
    }

    func requestPermissions() async {
        _ = await recorder.requestPermission()
        _ = await transcriber.requestPermission()
    }

    func startRecording() {
        guard let url = recorder.startRecording() else {
            showErrorMessage("Could not start recording. Check microphone permission.")
            return
        }
        currentAudioURL = url
        currentFileName = url.lastPathComponent
        recordingState = .recording
        currentTranscription = ""
        sendingStatus = .idle
    }

    func stopRecording(modelContext: ModelContext) async {
        let (_, duration) = recorder.stopRecording()
        recordingState = .processing

        guard let audioURL = currentAudioURL else {
            recordingState = .idle
            return
        }

        let transcription = await transcriber.transcribe(audioURL: audioURL)
        currentTranscription = transcription ?? ""

        let memo = VoiceMemo(
            timestamp: Date(),
            duration: duration,
            transcription: currentTranscription,
            audioFileName: currentFileName ?? ""
        )
        modelContext.insert(memo)

        recordingState = .done

        if settings.autoSend && settings.hasAnyDestination && !currentTranscription.isEmpty {
            await sendMemo(memo, modelContext: modelContext)
        }
    }

    func sendMemo(_ memo: VoiceMemo, modelContext: ModelContext) async {
        guard !memo.transcription.isEmpty else {
            showErrorMessage("No transcription available to send.")
            return
        }

        sendingStatus = .sending

        var notionSuccess = true
        var telegramSuccess = true

        if settings.sendToNotion && settings.isNotionConfigured {
            do {
                try await NotionService().sendMemo(
                    transcription: memo.transcription,
                    duration: memo.formattedDuration,
                    date: memo.timestamp,
                    apiKey: settings.notionAPIKey,
                    pageId: settings.notionPageId
                )
                memo.isSentToNotion = true
            } catch {
                notionSuccess = false
            }
        }

        if settings.sendToTelegram && settings.isTelegramConfigured {
            do {
                try await TelegramService().sendMemo(
                    transcription: memo.transcription,
                    duration: memo.formattedDuration,
                    date: memo.timestamp,
                    botToken: settings.telegramBotToken,
                    chatId: settings.telegramChatId
                )
                memo.isSentToTelegram = true
            } catch {
                telegramSuccess = false
            }
        }

        if notionSuccess && telegramSuccess {
            sendingStatus = .sent
        } else {
            var failures: [String] = []
            if !notionSuccess { failures.append("Notion") }
            if !telegramSuccess { failures.append("Telegram") }
            sendingStatus = .failed("Failed to send to \(failures.joined(separator: " & "))")
        }
    }

    func resetForNewRecording() {
        recordingState = .idle
        currentTranscription = ""
        sendingStatus = .idle
        currentAudioURL = nil
        currentFileName = nil
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}
