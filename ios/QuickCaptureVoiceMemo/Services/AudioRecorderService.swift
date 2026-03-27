import AVFoundation
import Accelerate

@MainActor
@Observable
final class AudioRecorderService: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    var isRecording = false
    var isPlaying = false
    var recordingDuration: TimeInterval = 0
    var audioLevel: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var currentFileURL: URL?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() -> URL? {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return nil
        }

        let fileName = "memo_\(UUID().uuidString).m4a"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            currentFileURL = fileURL
            isRecording = true
            recordingDuration = 0
            startTimers()
            return fileURL
        } catch {
            return nil
        }
    }

    func stopRecording() -> (URL?, TimeInterval) {
        audioRecorder?.stop()
        stopTimers()
        isRecording = false
        let url = currentFileURL
        let duration = recordingDuration
        return (url, duration)
    }

    func playAudio(url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            return
        }
    }

    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
    }

    private func startTimers() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                self.audioLevel = max(0, (power + 60) / 60)
            }
        }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordingDuration += 1
            }
        }
    }

    private func stopTimers() {
        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        audioLevel = 0
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            isRecording = false
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
        }
    }
}
