import SwiftUI

struct ContentView: View {
    @State private var settings = SettingsManager()

    var body: some View {
        TabView {
            Tab("Record", systemImage: "mic.fill") {
                RecordingView(settings: settings)
            }

            Tab("Memos", systemImage: "list.bullet") {
                MemoHistoryView(settings: settings)
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView(settings: settings)
            }
        }
    }
}
