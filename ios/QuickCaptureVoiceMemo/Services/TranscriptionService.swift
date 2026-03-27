import Foundation
import Speech

@MainActor
@Observable
final class TranscriptionService {
    var isTranscribing = false
    var transcriptionProgress: String = ""

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(audioURL: URL) async -> String? {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            return nil
        }

        isTranscribing = true
        defer { isTranscribing = false }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        do {
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                var hasResumed = false

                let task = recognizer.recognitionTask(with: request) { result, error in
                    guard !hasResumed else { return }

                    if let result, result.isFinal {
                        hasResumed = true
                        continuation.resume(returning: result)
                        return
                    }

                    if let error {
                        hasResumed = true
                        continuation.resume(throwing: error)
                    }
                }

                Task {
                    try? await Task.sleep(for: .seconds(30))
                    guard !hasResumed else { return }
                    hasResumed = true
                    task.finish()
                    continuation.resume(throwing: TranscriptionError.timeout)
                }
            }
            return result.bestTranscription.formattedString
        } catch {
            return nil
        }
    }
}

nonisolated enum TranscriptionError: Error {
    case timeout
}
