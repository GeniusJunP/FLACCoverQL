import SwiftUI
import QuickLookThumbnailing

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
    @State private var cacheCleared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FLACCoverQL")
                .font(.title2.bold())

            Text("FLAC ファイルのカバーアートを Finder のサムネイルとして表示する機能拡張")
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Divider()

            Button("サムネイルキャッシュを消去") {
                clearCache()
            }

            if cacheCleared {
                Text("キャッシュを消去した。Finder でサムネイルが再生成される。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("機能拡張の設定を開く") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
            }
        }
        .padding(24)
        .frame(minWidth: 320, idealWidth: 360)
    }

    private func clearCache() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        process.arguments = ["-r", "cache"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        cacheCleared = true
    }
}
