import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsManager {
    var notionAPIKey: String {
        didSet { UserDefaults.standard.set(notionAPIKey, forKey: "notionAPIKey") }
    }
    var notionPageId: String {
        didSet { UserDefaults.standard.set(notionPageId, forKey: "notionPageId") }
    }
    var telegramBotToken: String {
        didSet { UserDefaults.standard.set(telegramBotToken, forKey: "telegramBotToken") }
    }
    var telegramChatId: String {
        didSet { UserDefaults.standard.set(telegramChatId, forKey: "telegramChatId") }
    }
    var sendToNotion: Bool {
        didSet { UserDefaults.standard.set(sendToNotion, forKey: "sendToNotion") }
    }
    var sendToTelegram: Bool {
        didSet { UserDefaults.standard.set(sendToTelegram, forKey: "sendToTelegram") }
    }
    var autoSend: Bool {
        didSet { UserDefaults.standard.set(autoSend, forKey: "autoSend") }
    }

    var isNotionConfigured: Bool {
        !notionAPIKey.isEmpty && !notionPageId.isEmpty
    }

    var isTelegramConfigured: Bool {
        !telegramBotToken.isEmpty && !telegramChatId.isEmpty
    }

    var hasAnyDestination: Bool {
        (sendToNotion && isNotionConfigured) || (sendToTelegram && isTelegramConfigured)
    }

    init() {
        self.notionAPIKey = UserDefaults.standard.string(forKey: "notionAPIKey") ?? ""
        self.notionPageId = UserDefaults.standard.string(forKey: "notionPageId") ?? ""
        self.telegramBotToken = UserDefaults.standard.string(forKey: "telegramBotToken") ?? ""
        self.telegramChatId = UserDefaults.standard.string(forKey: "telegramChatId") ?? ""
        self.sendToNotion = UserDefaults.standard.bool(forKey: "sendToNotion")
        self.sendToTelegram = UserDefaults.standard.bool(forKey: "sendToTelegram")
        self.autoSend = UserDefaults.standard.object(forKey: "autoSend") as? Bool ?? true
    }
}
