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
    @State private var status: ExtensionStatus = .checking

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FLACCoverQL")
                .font(.title2.bold())

            Text("description", tableName: "UI")
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 8) {
                Circle()
                    .fill(status.color)
                    .frame(width: 10, height: 10)
                Text(String(localized: status.key, table: "UI"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button(String(localized: "clearCache", table: "UI")) {
                    clearCache()
                }
                Button(String(localized: "openSettings", table: "UI")) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                }
                Button(String(localized: "recheck", table: "UI")) {
                    status = .checking
                    Task { await checkExtension() }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 360)
        .task {
            await checkExtension()
        }
    }

    private func clearCache() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        process.arguments = ["-r", "cache"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private func checkExtension() async {
        guard let testURL = Bundle.main.url(forResource: "test", withExtension: "flac") else {
            status = .error
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: testURL,
            size: CGSize(width: 64, height: 64),
            scale: 1.0,
            representationTypes: .thumbnail
        )

        do {
            let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            status = rep.type == .thumbnail ? .active : .inactive
        } catch {
            status = .inactive
        }
    }
}

enum ExtensionStatus {
    case checking, active, inactive, error

    var color: Color {
        switch self {
        case .checking: .gray
        case .active: .green
        case .inactive: .yellow
        case .error: .red
        }
    }

    var key: String.LocalizationValue {
        switch self {
        case .checking: "statusChecking"
        case .active: "statusActive"
        case .inactive: "statusInactive"
        case .error: "statusError"
        }
    }
}
