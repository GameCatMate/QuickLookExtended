import Cocoa
import CoreServices

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let statusLabel = NSTextField(labelWithString: "Registering Quick Look extension...")

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerExtension()
        showWindow()
    }

    private func registerExtension() {
        let bundlePath = Bundle.main.bundlePath
        DispatchQueue.global(qos: .utility).async {
            let bundleURL = URL(fileURLWithPath: bundlePath) as CFURL
            _ = LSRegisterURL(bundleURL, false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.statusLabel.stringValue = "QuickLookExtended is registered. Enable it in macOS Quick Look settings if it is not already enabled."
        }
    }

    private func showWindow() {
        NSApp.setActivationPolicy(.regular)

        let title = NSTextField(labelWithString: "QuickLookExtended")
        title.font = .boldSystemFont(ofSize: 22)
        title.alignment = .center

        let subtitle = NSTextField(labelWithString: "Preview YAML, Terraform, scripts, configs, source files, Markdown, and extensionless text files with Quick Look.")
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.maximumNumberOfLines = 0

        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 0

        let settingsButton = NSButton(title: "Open System Settings", target: self, action: #selector(openSettings))
        settingsButton.bezelStyle = .rounded

        let doneButton = NSButton(title: "Done", target: self, action: #selector(done))
        doneButton.bezelStyle = .rounded

        let buttons = NSStackView(views: [settingsButton, doneButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 10
        buttons.distribution = .gravityAreas

        let stack = NSStackView(views: [title, subtitle, statusLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 240))
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

    @objc private func openSettings() {
        let settingsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        if !NSWorkspace.shared.open(settingsURL) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/System Settings.app"), configuration: .init())
        }
    }

    @objc private func done() {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
