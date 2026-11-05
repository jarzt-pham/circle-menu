import AppKit
import Combine

struct MenuOption: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case openWithApp, copyPath, shellCommand
        var id: String { rawValue }
        var label: String {
            switch self {
            case .openWithApp: return "Open with Application"
            case .copyPath: return "Copy Path"
            case .shellCommand: return "Run Shell Command"
            }
        }
    }

    var id = UUID()
    var title: String
    var symbol: String
    var kind: Kind
    var appPath = ""
    var openContainingFolder = false
    var command = ""

    init(title: String, symbol: String, kind: Kind, appPath: String = "",
         openContainingFolder: Bool = false, command: String = "") {
        self.title = title
        self.symbol = symbol
        self.kind = kind
        self.appPath = appPath
        self.openContainingFolder = openContainingFolder
        self.command = command
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "circle"
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .copyPath
        appPath = try c.decodeIfPresent(String.self, forKey: .appPath) ?? ""
        openContainingFolder = try c.decodeIfPresent(Bool.self, forKey: .openContainingFolder) ?? false
        command = try c.decodeIfPresent(String.self, forKey: .command) ?? ""
    }
}

struct AppConfig: Codable, Equatable {
    static let maxOptions = 8

    var options: [MenuOption]
    var chordDelay: Double = 0.15
    var enabled = true

    init(options: [MenuOption], chordDelay: Double = 0.15, enabled: Bool = true) {
        self.options = options
        self.chordDelay = chordDelay
        self.enabled = enabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        options = try c.decodeIfPresent([MenuOption].self, forKey: .options) ?? AppConfig.default.options
        chordDelay = try c.decodeIfPresent(Double.self, forKey: .chordDelay) ?? 0.15
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }

    static var `default`: AppConfig {
        func appPath(_ bundleID: String, fallback: String) -> String {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path ?? fallback
        }
        return AppConfig(options: [
            MenuOption(title: "VS Code", symbol: "chevron.left.forwardslash.chevron.right", kind: .openWithApp,
                       appPath: appPath("com.microsoft.VSCode", fallback: "/Applications/Visual Studio Code.app")),
            MenuOption(title: "Terminal", symbol: "terminal", kind: .openWithApp,
                       appPath: appPath("com.apple.Terminal", fallback: "/System/Applications/Utilities/Terminal.app"),
                       openContainingFolder: true),
            MenuOption(title: "Copy Path", symbol: "doc.on.doc", kind: .copyPath),
        ])
    }
}

/// Persists the config as JSON in ~/Library/Application Support/CircleMenu/config.json.
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: AppConfig {
        didSet { if config != oldValue { save() } }
    }

    let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CircleMenu", isDirectory: true)
        fileURL = dir.appendingPathComponent("config.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = decoded
        } else {
            config = .default
            save()
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(config).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("CircleMenu: failed to save config: \(error)")
        }
    }
}
