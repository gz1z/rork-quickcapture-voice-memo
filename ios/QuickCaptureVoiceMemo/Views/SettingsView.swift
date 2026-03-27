import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsManager
    @State private var showNotionHelp = false
    @State private var showTelegramHelp = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Auto-send after recording", isOn: $settings.autoSend)
                } header: {
                    Text("General")
                } footer: {
                    Text("Automatically route memos to enabled destinations after transcription.")
                }

                Section {
                    Toggle("Send to Notion", isOn: $settings.sendToNotion)

                    if settings.sendToNotion {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            SecureField("API Key", text: $settings.notionAPIKey)
                                .textContentType(.password)
                        }

                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            TextField("Parent Page ID", text: $settings.notionPageId)
                                .textContentType(.none)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        Button {
                            showNotionHelp = true
                        } label: {
                            Label("How to get Notion credentials", systemImage: "questionmark.circle")
                                .font(.subheadline)
                        }
                    }
                } header: {
                    HStack {
                        Text("Notion")
                        Spacer()
                        if settings.isNotionConfigured && settings.sendToNotion {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                }

                Section {
                    Toggle("Send to Telegram", isOn: $settings.sendToTelegram)

                    if settings.sendToTelegram {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            SecureField("Bot Token", text: $settings.telegramBotToken)
                                .textContentType(.password)
                        }

                        HStack {
                            Image(systemName: "number")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            TextField("Chat ID", text: $settings.telegramChatId)
                                .textContentType(.none)
                                .keyboardType(.numbersAndPunctuation)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        Button {
                            showTelegramHelp = true
                        } label: {
                            Label("How to get Telegram credentials", systemImage: "questionmark.circle")
                                .font(.subheadline)
                        }
                    }
                } header: {
                    HStack {
                        Text("Telegram")
                        Spacer()
                        if settings.isTelegramConfigured && settings.sendToTelegram {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("QuickCapture")
                                .font(.headline)
                            Text("Voice → Text → Anywhere")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showNotionHelp) {
                notionHelpSheet
            }
            .sheet(isPresented: $showTelegramHelp) {
                telegramHelpSheet
            }
        }
    }

    private var notionHelpSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    instructionStep(number: 1, text: "Go to notion.so/my-integrations and create a new integration.")
                    instructionStep(number: 2, text: "Copy the Internal Integration Secret — this is your API Key.")
                    instructionStep(number: 3, text: "Open the Notion page where you want memos saved.")
                    instructionStep(number: 4, text: "Click ••• → Connections → Connect the integration you created.")
                    instructionStep(number: 5, text: "Copy the page ID from the URL (the 32-character string after the page title).")
                }
                .padding()
            }
            .navigationTitle("Notion Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showNotionHelp = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var telegramHelpSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    instructionStep(number: 1, text: "Open Telegram and search for @BotFather.")
                    instructionStep(number: 2, text: "Send /newbot and follow the prompts to create a bot.")
                    instructionStep(number: 3, text: "Copy the bot token provided by BotFather.")
                    instructionStep(number: 4, text: "Send a message to your new bot, then visit:\nhttps://api.telegram.org/bot<TOKEN>/getUpdates")
                    instructionStep(number: 5, text: "Find your chat ID in the response JSON under message → chat → id.")
                }
                .padding()
            }
            .navigationTitle("Telegram Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showTelegramHelp = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue))

            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
