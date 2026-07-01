import Cocoa
import CoreServices
import ServiceManagement

private let quickLookExtensionIdentifier = "dev.gamecat.QuickLookExtended.PreviewExtension"

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let savedReadySnapshotKey = "savedReadySnapshot"

    private var window: NSWindow?
    private let statusLabel = NSTextField(labelWithString: "")
    private var currentState: SetupState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerExtension()
    }

    private func registerExtension() {
        let bundlePath = Bundle.main.bundlePath
        DispatchQueue.global(qos: .utility).async {
            let bundleURL = URL(fileURLWithPath: bundlePath) as CFURL
            _ = LSRegisterURL(bundleURL, false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.finishSetupCheck()
            }
        }
    }

    private func finishSetupCheck() {
        let state = SetupState.current()
        currentState = state

        if state.isReady, UserDefaults.standard.string(forKey: Self.savedReadySnapshotKey) == state.snapshot {
            NSApp.terminate(nil)
            return
        }

        if state.isReady {
            UserDefaults.standard.set(state.snapshot, forKey: Self.savedReadySnapshotKey)
        }

        showWindow(for: state)
    }

    private func showWindow(for state: SetupState) {
        NSApp.setActivationPolicy(.regular)
        window?.close()

        let title = NSTextField(labelWithString: state.isReady ? "QuickLookExtended is ready" : "QuickLookExtended setup")
        title.font = .boldSystemFont(ofSize: 22)
        title.alignment = .center

        statusLabel.stringValue = ""
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 0
        statusLabel.isHidden = true

        let loginButton = NSButton(title: "Add to Login Items", target: self, action: #selector(addToLoginItems))
        loginButton.bezelStyle = .rounded
        loginButton.isEnabled = state.loginItem != .enabled

        let settingsButton = NSButton(title: "Open System Settings", target: self, action: #selector(openSettings))
        settingsButton.bezelStyle = .rounded

        let checks = NSStackView(views: [
            makeStatusSection(
                title: "Quick Look extension",
                stateTitle: state.extensionState.title,
                message: state.extensionHelpText,
                color: state.extensionState.color,
                button: settingsButton
            ),
            makeStatusSection(
                title: "Login Item",
                stateTitle: state.loginItem.title,
                message: state.loginHelpText,
                color: state.loginItem.color,
                button: loginButton
            )
        ])
        checks.orientation = .vertical
        checks.alignment = .leading
        checks.spacing = 14

        let doneButton = NSButton(title: "Done", target: self, action: #selector(done))
        doneButton.bezelStyle = .rounded

        let buttons = NSStackView(views: [doneButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 10
        buttons.distribution = .gravityAreas

        let stack = NSStackView(views: [title, checks, statusLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 320))
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        let window = NSWindow(
            contentRect: contentView.bounds,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "QuickLookExtended"
        window.contentView = contentView
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeStatusSection(
        title: String,
        stateTitle: String,
        message: String,
        color: NSColor,
        button: NSButton
    ) -> NSView {
        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.backgroundColor = color.cgColor
        dot.layer?.cornerRadius = 5
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10)
        ])

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .boldSystemFont(ofSize: 13)

        let stateLabel = NSTextField(labelWithString: stateTitle)
        stateLabel.font = .systemFont(ofSize: 13)
        stateLabel.textColor = .secondaryLabelColor

        let header = NSStackView(views: [dot, titleLabel, stateLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8

        let messageLabel = NSTextField(labelWithString: message)
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 0

        let stack = NSStackView(views: [header, messageLabel, button])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    @objc private func addToLoginItems() {
        guard #available(macOS 13.0, *) else {
            statusLabel.stringValue = "Login Items automation requires macOS 13 or newer."
            return
        }

        do {
            try SMAppService.mainApp.register()
            finishSetupCheck()
        } catch {
            statusLabel.isHidden = false
            statusLabel.stringValue = "Could not add QuickLookExtended to Login Items: \(error.localizedDescription)"
        }
    }

    @objc private func openSettings() {
        let settingsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        if !NSWorkspace.shared.open(settingsURL) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/System Settings.app"), configuration: .init())
        }
    }

    @objc private func done() {
        if let state = currentState, state.isReady {
            UserDefaults.standard.set(state.snapshot, forKey: Self.savedReadySnapshotKey)
        }
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private struct SetupState {
    let extensionState: ExtensionState
    let loginItem: LoginItemState
    let appVersion: String

    var isReady: Bool {
        extensionState == .enabled && loginItem == .enabled
    }

    var snapshot: String {
        "extension=\(extensionState.rawValue);login=\(loginItem.rawValue);version=\(appVersion)"
    }

    var extensionHelpText: String {
        extensionState == .enabled
            ? "Quick Look previews are enabled."
            : "Open System Settings and enable QuickLookExtended under Quick Look."
    }

    var loginHelpText: String {
        switch loginItem {
        case .enabled:
            return "The app can verify setup at login and quit silently when everything is ready."
        case .requiresApproval:
            return "Approve QuickLookExtended in System Settings."
        default:
            return "Add the app to Login Items for automatic setup verification."
        }
    }

    static func current() -> SetupState {
        SetupState(
            extensionState: .current(),
            loginItem: .current(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        )
    }
}

private enum ExtensionState: String {
    case enabled
    case registered
    case disabled
    case missing

    var title: String {
        switch self {
        case .enabled: "Enabled"
        case .registered: "Registered, enable it in System Settings"
        case .disabled: "Disabled"
        case .missing: "Not registered"
        }
    }

    var color: NSColor {
        switch self {
        case .enabled: .systemGreen
        case .registered: .systemOrange
        case .disabled, .missing: .systemRed
        }
    }

    static func current() -> ExtensionState {
        guard let output = runPlugInKit(),
              let line = output.components(separatedBy: .newlines).first(where: { $0.contains(quickLookExtensionIdentifier) }) else {
            return .missing
        }

        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.hasPrefix("+") {
            return .enabled
        }
        if trimmed.hasPrefix("-") {
            return .disabled
        }
        return .registered
    }

    private static func runPlugInKit() -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-A", "-D", "-v", "-i", quickLookExtensionIdentifier]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

private enum LoginItemState: String {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
    case unavailable

    var title: String {
        switch self {
        case .enabled: "Enabled"
        case .notRegistered: "Not added"
        case .requiresApproval: "Needs approval in System Settings"
        case .notFound: "Not found"
        case .unavailable: "Unavailable"
        }
    }

    var color: NSColor {
        switch self {
        case .enabled: .systemGreen
        case .requiresApproval: .systemOrange
        case .notRegistered, .notFound, .unavailable: .systemRed
        }
    }

    static func current() -> LoginItemState {
        guard #available(macOS 13.0, *) else {
            return .unavailable
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .notRegistered
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .unavailable
        }
    }
}
