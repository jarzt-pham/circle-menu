import AppKit

enum ActionRunner {
    static func run(_ option: MenuOption, on urls: [URL]) {
        switch option.kind {
        case .openWithApp:
            guard !option.appPath.isEmpty, FileManager.default.fileExists(atPath: option.appPath) else {
                fail("Application not found: \(option.appPath)")
                return
            }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            let targets = option.openContainingFolder ? uniqueFolders(of: urls) : urls
            NSWorkspace.shared.open(targets, withApplicationAt: URL(fileURLWithPath: option.appPath),
                                    configuration: config) { _, error in
                if let error { fail("Open failed: \(error.localizedDescription)") }
            }

        case .copyPath:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)

        case .shellCommand:
            guard !option.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                fail("Empty command")
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // Paths become "$@" / "$1"… inside the command.
            process.arguments = ["-lc", option.command, "circlemenu"] + urls.map(\.path)
            process.currentDirectoryURL = uniqueFolders(of: urls).first
            process.terminationHandler = { p in
                if p.terminationStatus != 0 { fail("Command exited with \(p.terminationStatus)") }
            }
            do { try process.run() } catch { fail("Command failed: \(error.localizedDescription)") }
        }
    }

    private static func fail(_ message: String) {
        NSLog("CircleMenu: \(message)")
        DispatchQueue.main.async { NSSound.beep() }
    }

    private static func uniqueFolders(of urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.compactMap { url in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            let folder = isDir.boolValue ? url : url.deletingLastPathComponent()
            return seen.insert(folder.path).inserted ? folder : nil
        }
    }
}
