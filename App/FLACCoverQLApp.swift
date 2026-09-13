import SwiftUI

@main
struct FLACCoverQLApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FLACCoverQL")
                .font(.title2.bold())

            Text("FLAC ファイルのカバーアートを Finder のサムネイルとして表示する機能拡張")
                .foregroundStyle(.secondary)

            Divider()

            Button("機能拡張の設定を開く") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
