import SwiftUI
import SwiftData

struct MemoHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VoiceMemo.timestamp, order: .reverse) private var memos: [VoiceMemo]
    @State private var selectedMemo: VoiceMemo?
    let settings: SettingsManager

    var body: some View {
        NavigationStack {
            Group {
                if memos.isEmpty {
                    ContentUnavailableView(
                        "No Memos Yet",
                        systemImage: "waveform",
                        description: Text("Your voice memos will appear here")
                    )
                } else {
                    List {
                        ForEach(memos) { memo in
                            MemoRow(memo: memo)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedMemo = memo
                                }
                        }
                        .onDelete(perform: deleteMemos)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Memos")
            .sheet(item: $selectedMemo) { memo in
                MemoDetailView(memo: memo, settings: settings)
            }
        }
    }

    private func deleteMemos(at offsets: IndexSet) {
        for index in offsets {
            let memo = memos[index]
            try? FileManager.default.removeItem(at: memo.audioFileURL)
            modelContext.delete(memo)
        }
    }
}

struct MemoRow: View {
    let memo: VoiceMemo
    @State private var recorder = AudioRecorderService()

    var body: some View {
        HStack(spacing: 14) {
            Button {
                if recorder.isPlaying {
                    recorder.stopPlaying()
                } else {
                    recorder.playAudio(url: memo.audioFileURL)
                }
            } label: {
                Image(systemName: recorder.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(recorder.isPlaying ? .red : .blue)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(memo.transcription.isEmpty ? "No transcription" : memo.transcription)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(memo.transcription.isEmpty ? .secondary : .primary)

                HStack(spacing: 8) {
                    Label(memo.formattedDuration, systemImage: "clock")
                    Label(memo.timestamp.formatted(.dateTime.month(.abbreviated).day().hour().minute()), systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            routingBadges
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var routingBadges: some View {
        HStack(spacing: 4) {
            if memo.isSentToNotion {
                Image(systemName: "doc.text.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
            if memo.isSentToTelegram {
                Image(systemName: "paperplane.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
    }
}

struct MemoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let memo: VoiceMemo
    let settings: SettingsManager
    @State private var recorder = AudioRecorderService()
    @State private var sendingStatus: VoiceMemoViewModel.SendingStatus = .idle

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        Button {
                            if recorder.isPlaying {
                                recorder.stopPlaying()
                            } else {
                                recorder.playAudio(url: memo.audioFileURL)
                            }
                        } label: {
                            Image(systemName: recorder.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(recorder.isPlaying ? .red : .blue)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(memo.formattedDuration)
                                .font(.title2.weight(.semibold))
                            Text(memo.timestamp.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute()))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    if !memo.transcription.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transcription")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            Text(memo.transcription)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Routing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack(spacing: 12) {
                            routingChip(
                                title: "Notion",
                                icon: "doc.text.fill",
                                sent: memo.isSentToNotion,
                                configured: settings.isNotionConfigured
                            )
                            routingChip(
                                title: "Telegram",
                                icon: "paperplane.fill",
                                sent: memo.isSentToTelegram,
                                configured: settings.isTelegramConfigured
                            )
                        }

                        if settings.hasAnyDestination && !memo.transcription.isEmpty {
                            sendButton
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Voice Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    private func routingChip(title: String, icon: String, sent: Bool, configured: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
            if sent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(sent ? Color.green.opacity(0.1) : Color(.tertiarySystemBackground))
        .clipShape(.capsule)
        .overlay(
            Capsule()
                .strokeBorder(sent ? Color.green.opacity(0.3) : Color(.separator), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var sendButton: some View {
        switch sendingStatus {
        case .idle:
            Button {
                Task {
                    sendingStatus = .sending
                    var notionOk = true
                    var telegramOk = true

                    if settings.sendToNotion && settings.isNotionConfigured && !memo.isSentToNotion {
                        do {
                            try await NotionService().sendMemo(
                                transcription: memo.transcription,
                                duration: memo.formattedDuration,
                                date: memo.timestamp,
                                apiKey: settings.notionAPIKey,
                                pageId: settings.notionPageId
                            )
                            memo.isSentToNotion = true
                        } catch { notionOk = false }
                    }

                    if settings.sendToTelegram && settings.isTelegramConfigured && !memo.isSentToTelegram {
                        do {
                            try await TelegramService().sendMemo(
                                transcription: memo.transcription,
                                duration: memo.formattedDuration,
                                date: memo.timestamp,
                                botToken: settings.telegramBotToken,
                                chatId: settings.telegramChatId
                            )
                            memo.isSentToTelegram = true
                        } catch { telegramOk = false }
                    }

                    sendingStatus = (notionOk && telegramOk) ? .sent : .failed("Some sends failed")
                }
            } label: {
                Label("Send Now", systemImage: "paperplane")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.blue)

        case .sending:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Sending...")
            }
            .frame(maxWidth: .infinity)

        case .sent:
            Label("Sent", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)

        case .failed(let msg):
            Text(msg)
                .foregroundStyle(.red)
                .font(.subheadline)
        }
    }
}
