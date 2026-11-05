import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

final class SettingsWindowController: NSWindowController {
    convenience init(store: ConfigStore) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store)))
        window.title = "CircleMenu Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var store: ConfigStore

    var body: some View {
        TabView {
            OptionsTab(store: store)
                .tabItem { Label("Menu", systemImage: "circle.circle") }
            GeneralTab(store: store)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .padding(12)
        .frame(width: 780, height: 540)
    }
}

// MARK: - Menu options

private struct OptionsTab: View {
    @ObservedObject var store: ConfigStore
    @State private var selection: UUID?

    private var options: [MenuOption] { store.config.options }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                RadialPreview(options: options,
                              selectedIndex: options.firstIndex { $0.id == selection })
                    .frame(width: 220, height: 220)
                    .frame(maxWidth: .infinity)
                Text("Options (clockwise from top)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                optionList
            }
            .frame(width: 250)

            Group {
                if let id = selection, let binding = binding(for: id) {
                    OptionEditor(option: binding)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.point.left").font(.largeTitle).foregroundStyle(.tertiary)
                        Text("Select an option to edit it").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { if selection == nil { selection = options.first?.id } }
    }

    private var optionList: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(options) { option in
                    Label {
                        Text(option.title.isEmpty ? "Untitled" : option.title)
                    } icon: {
                        Image(systemName: option.symbol).frame(width: 18)
                    }
                    .tag(option.id)
                }
                .onMove { store.config.options.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.inset)

            Divider()
            HStack(spacing: 0) {
                Button(action: add) { Image(systemName: "plus").frame(width: 26, height: 22) }
                    .disabled(options.count >= AppConfig.maxOptions)
                    .help("Add option (max \(AppConfig.maxOptions))")
                Divider().frame(height: 16)
                Button(action: remove) { Image(systemName: "minus").frame(width: 26, height: 22) }
                    .disabled(selection == nil)
                    .help("Remove selected option")
                Spacer()
                Text("\(options.count)/\(AppConfig.maxOptions)")
                    .font(.caption).foregroundStyle(.secondary).padding(.trailing, 8)
            }
            .buttonStyle(.borderless)
            .background(.bar)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
    }

    private func binding(for id: UUID) -> Binding<MenuOption>? {
        guard let current = options.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { store.config.options.first { $0.id == id } ?? current },
            set: { newValue in
                if let i = store.config.options.firstIndex(where: { $0.id == id }) {
                    store.config.options[i] = newValue
                }
            })
    }

    private func add() {
        let option = MenuOption(title: "New Option", symbol: "star", kind: .openWithApp)
        store.config.options.append(option)
        selection = option.id
    }

    private func remove() {
        guard let id = selection, let index = options.firstIndex(where: { $0.id == id }) else { return }
        store.config.options.remove(at: index)
        let remaining = store.config.options
        selection = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
    }
}

private struct OptionEditor: View {
    @Binding var option: MenuOption

    var body: some View {
        Form {
            Section("Appearance") {
                TextField("Title", text: $option.title)
                LabeledContent("Icon") { SymbolPicker(symbol: $option.symbol) }
            }
            Section("Action") {
                Picker("When chosen", selection: $option.kind) {
                    ForEach(MenuOption.Kind.allCases) { Text($0.label).tag($0) }
                }
                switch option.kind {
                case .openWithApp:
                    LabeledContent("Application") {
                        AppPicker(path: $option.appPath) { appName in
                            if option.title.isEmpty || option.title == "New Option" { option.title = appName }
                        }
                    }
                    Toggle("Open the containing folder instead of the file", isOn: $option.openContainingFolder)
                case .copyPath:
                    Text("Copies the full path of each selected Finder item to the clipboard.")
                        .foregroundStyle(.secondary)
                case .shellCommand:
                    TextField("Command", text: $option.command, prompt: Text("open -a Preview \"$@\""), axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(.body, design: .monospaced))
                    Text("Runs with zsh in the selection's folder. Selected paths are passed as \"$@\" (first one is \"$1\").")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Acts on the current Finder selection (or the front Finder window's folder).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct SymbolPicker: View {
    @Binding var symbol: String
    @State private var isPresented = false

    private static let suggestions = [
        "chevron.left.forwardslash.chevron.right", "terminal", "doc.on.doc", "folder", "doc.text",
        "square.and.arrow.up", "trash", "magnifyingglass", "eye", "pencil", "hammer", "wrench.and.screwdriver",
        "globe", "safari", "envelope", "paperplane", "photo", "film", "music.note", "archivebox",
        "doc.zipper", "link", "star", "heart", "bolt", "tag", "bookmark", "cloud", "lock", "gearshape",
        "app.badge", "cpu", "externaldrive", "printer", "text.cursor", "list.bullet",
    ]

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).frame(width: 20)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 8), spacing: 4) {
                    ForEach(Self.suggestions, id: \.self) { name in
                        Button {
                            symbol = name
                            isPresented = false
                        } label: {
                            Image(systemName: name)
                                .frame(width: 32, height: 32)
                                .background(RoundedRectangle(cornerRadius: 6)
                                    .fill(name == symbol ? Color.accentColor.opacity(0.25) : Color.clear))
                        }
                        .buttonStyle(.plain)
                        .help(name)
                    }
                }
                TextField("Custom SF Symbol name", text: $symbol)
                Link("Browse SF Symbols…", destination: URL(string: "https://developer.apple.com/sf-symbols/")!)
                    .font(.caption)
            }
            .padding(12)
            .frame(width: 300)
        }
    }
}

private struct AppPicker: View {
    @Binding var path: String
    var onPick: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            if !path.isEmpty, FileManager.default.fileExists(atPath: path) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(FileManager.default.displayName(atPath: path))
            } else {
                Text(path.isEmpty ? "None" : "Not found").foregroundStyle(.secondary)
            }
            Button("Choose…", action: choose)
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        path = url.path
        onPick(FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""))
    }
}

private struct RadialPreview: NSViewRepresentable {
    var options: [MenuOption]
    var selectedIndex: Int?

    func makeNSView(context: Context) -> RadialMenuView {
        RadialMenuView(blendingMode: .withinWindow)
    }

    func updateNSView(_ view: RadialMenuView, context: Context) {
        view.options = options
        view.selectedIndex = selectedIndex
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var store: ConfigStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Enable Left + Right click menu", isOn: $store.config.enabled)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                LabeledContent("Chord delay") {
                    HStack {
                        Slider(value: $store.config.chordDelay, in: 0.08...0.4)
                            .frame(width: 220)
                        Text("\(Int(store.config.chordDelay * 1000)) ms")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            } footer: {
                Text("How long a single click waits for the other button. Lower feels snappier, higher makes the menu easier to trigger.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Permissions") {
                LabeledContent("Accessibility") {
                    HStack {
                        Label(accessibilityGranted ? "Granted" : "Not granted",
                              systemImage: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(accessibilityGranted ? .green : .orange)
                        Button("Open Settings…") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button("Reveal Config File") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                    }
                    Spacer()
                    Button("Reset to Defaults", role: .destructive) { store.config = .default }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }
}
