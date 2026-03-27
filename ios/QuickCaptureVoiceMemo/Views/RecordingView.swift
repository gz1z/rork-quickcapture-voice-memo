import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: VoiceMemoViewModel
    @State private var pulseAmount: CGFloat = 1.0
    @State private var wavePhase: Double = 0

    init(settings: SettingsManager) {
        _viewModel = State(initialValue: VoiceMemoViewModel(settings: settings))
    }

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                statusSection
                    .padding(.bottom, 40)

                recordButton
                    .padding(.bottom, 32)

                transcriptionSection
                    .padding(.horizontal, 24)

                Spacer()

                bottomActions
                    .padding(.bottom, 8)
            }
        }
        .task {
            await viewModel.requestPermissions()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var backgroundGradient: some View {
        Group {
            switch viewModel.recordingState {
            case .recording:
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0, 0], [0.5, 0], [1, 0],
                        [0, 0.5], [0.5, 0.5], [1, 0.5],
                        [0, 1], [0.5, 1], [1, 1]
                    ],
                    colors: [
                        .red.opacity(0.3), .orange.opacity(0.2), .red.opacity(0.25),
                        .orange.opacity(0.15), .red.opacity(0.1), .orange.opacity(0.2),
                        Color(.systemBackground), Color(.systemBackground), Color(.systemBackground)
                    ]
                )
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: viewModel.recorder.audioLevel)
            default:
                Color(.systemBackground)
            }
        }
    }

    private var statusSection: some View {
        VStack(spacing: 12) {
            switch viewModel.recordingState {
            case .idle:
                Image(systemName: "waveform.circle")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Tap to capture")
                    .font(.title3)
                    .foregroundStyle(.secondary)

            case .recording:
                audioWaveform
                    .frame(height: 60)
                    .padding(.horizontal, 40)
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAmount)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAmount)
                        .onAppear { pulseAmount = 1.4 }
                        .onDisappear { pulseAmount = 1.0 }
                    Text(formatDuration(viewModel.recorder.recordingDuration))
                        .font(.system(.title2, design: .monospaced, weight: .medium))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.default, value: viewModel.recorder.recordingDuration)
                }

            case .processing:
                ProgressView()
                    .controlSize(.large)
                    .tint(.primary)
                Text("Transcribing...")
                    .font(.title3)
                    .foregroundStyle(.secondary)

            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: viewModel.recordingState == .done)
                sendingStatusView
            }
        }
        .animation(.spring(response: 0.4), value: viewModel.recordingState)
    }

    private var audioWaveform: some View {
        GeometryReader { geometry in
            let barCount = 30
            let barWidth: CGFloat = 3
            let spacing = (geometry.size.width - CGFloat(barCount) * barWidth) / CGFloat(barCount - 1)

            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let normalizedIndex = Double(index) / Double(barCount)
                    let wave = sin(normalizedIndex * .pi * 3 + wavePhase)
                    let level = CGFloat(viewModel.recorder.audioLevel)
                    let height = max(4, geometry.size.height * level * CGFloat(0.5 + wave * 0.5))

                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .onChange(of: viewModel.recorder.audioLevel) { _, _ in
                withAnimation(.linear(duration: 0.05)) {
                    wavePhase += 0.3
                }
            }
        }
    }

    private var recordButton: some View {
        Button {
            handleRecordTap()
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.recordingState == .recording ? .red.opacity(0.15) : Color(.tertiarySystemBackground))
                    .frame(width: 120, height: 120)
                    .scaleEffect(viewModel.recordingState == .recording ? 1.15 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.recordingState == .recording)

                Circle()
                    .fill(viewModel.recordingState == .recording ? .red : .red.opacity(0.9))
                    .frame(width: 88, height: 88)
                    .shadow(color: .red.opacity(0.3), radius: viewModel.recordingState == .recording ? 20 : 8, y: 4)

                Group {
                    if viewModel.recordingState == .recording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.recordingState == .processing)
        .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.recordingState)
    }

    @ViewBuilder
    private var transcriptionSection: some View {
        if !viewModel.currentTranscription.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundStyle(.secondary)
                    Text("Transcription")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                ScrollView {
                    Text(viewModel.currentTranscription)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 16))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var sendingStatusView: some View {
        switch viewModel.sendingStatus {
        case .idle:
            EmptyView()
        case .sending:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Sending...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .sent:
            Text("Sent successfully")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        if viewModel.recordingState == .done {
            HStack(spacing: 16) {
                if !viewModel.currentTranscription.isEmpty && viewModel.settings.hasAnyDestination {
                    if case .sent = viewModel.sendingStatus {
                        EmptyView()
                    } else {
                        Button {
                            Task {
                                guard let memo = fetchLatestMemo() else { return }
                                await viewModel.sendMemo(memo, modelContext: modelContext)
                            }
                        } label: {
                            Label("Send", systemImage: "paperplane.fill")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.35)) {
                        viewModel.resetForNewRecording()
                    }
                } label: {
                    Label("New Memo", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4), value: viewModel.recordingState)
        }
    }

    private func handleRecordTap() {
        switch viewModel.recordingState {
        case .idle:
            viewModel.startRecording()
        case .recording:
            Task {
                await viewModel.stopRecording(modelContext: modelContext)
            }
        case .done:
            withAnimation(.spring(response: 0.35)) {
                viewModel.resetForNewRecording()
            }
        case .processing:
            break
        }
    }

    private func fetchLatestMemo() -> VoiceMemo? {
        let descriptor = FetchDescriptor<VoiceMemo>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return try? modelContext.fetch(descriptor).first
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
