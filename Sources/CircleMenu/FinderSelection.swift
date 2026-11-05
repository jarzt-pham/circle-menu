import AppKit

enum FinderSelection {
    /// Selected Finder items; falls back to the front Finder window's folder, then the Desktop.
    private static let source = """
    tell application "Finder"
        set sel to selection as alias list
        if (count of sel) is 0 then
            try
                set sel to {(target of front Finder window) as alias}
            on error
                set sel to {(path to desktop folder)}
            end try
        end if
        set out to ""
        repeat with f in sel
            set out to out & POSIX path of f & linefeed
        end repeat
        return out
    end tell
    """

    static func current() -> [URL] {
        var error: NSDictionary?
        guard let output = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue else {
            NSLog("CircleMenu: Finder selection failed: \(error ?? [:])")
            return []
        }
        return output.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
    }
}
