import Cocoa
import Quartz

@MainActor
final class PreviewProvider: NSViewController, QLPreviewingController {
    private static let maxPreviewBytes = 2 * 1024 * 1024
    private var multiClickMonitor: Any?
    private var copyMonitor: Any?
    private var suppressNextMouseUp = false
    private var lastHighlightRange: NSRange?
    private weak var previewTextView: PreviewTextView?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installEventMonitors()
    }

    private func installEventMonitors() {
        guard multiClickMonitor == nil, copyMonitor == nil else {
            return
        }

        multiClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self else {
                return event
            }

            if event.type == .leftMouseDown {
                guard event.clickCount > 1, self.previewTextView?.consumeMultiClick(event) == true else {
                    return event
                }

                self.suppressNextMouseUp = true
                return nil
            }

            if self.suppressNextMouseUp, event.window === self.view.window {
                self.suppressNextMouseUp = false
                return nil
            }

            return event
        }
        copyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.copySelectedText(for: event) == true else {
                return event
            }

            return nil
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        suppressNextMouseUp = false

        if let multiClickMonitor {
            NSEvent.removeMonitor(multiClickMonitor)
            self.multiClickMonitor = nil
        }
        if let copyMonitor {
            NSEvent.removeMonitor(copyMonitor)
            self.copyMonitor = nil
        }
    }

    private func copySelectedText(for event: NSEvent) -> Bool {
        guard event.window === view.window, isCopyShortcut(event), previewTextView?.copySelectionToPasteboard() == true else {
            return false
        }

        return true
    }

    private func isCopyShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let commandOnly = flags.contains(.command) && !flags.contains(.option) && !flags.contains(.control)
        guard commandOnly else {
            return false
        }

        let character = event.charactersIgnoringModifiers?.lowercased()
        return event.keyCode == 8 || character == "c" || character == "с"
    }

    func preparePreviewOfFile(at url: URL) async throws {
        preferredContentSize = CGSize(width: 900, height: 700)

        let fileExtension = url.pathExtension.lowercased()
        let isYAML = fileExtension == "yaml" || fileExtension == "yml"
        let isTerraform = fileExtension == "tf"

        guard isYAML || isTerraform || fileExtension.isEmpty else {
            showGeneric(for: url)
            return
        }

        let (data, truncated) = try Self.previewData(from: url)
        guard let text = TextSniffer.text(from: data) else {
            showGeneric(for: url)
            return
        }

        let previewText = text + (truncated ? "\n\n... preview truncated ..." : "")
        let attributedText = isTerraform ? TerraformHighlighter.attributed(previewText) : YAMLHighlighter.attributed(previewText, highlighted: isYAML)
        showText(attributedText)
    }

    private static func previewData(from url: URL) throws -> (Data, Bool) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0

        guard size > maxPreviewBytes else {
            return (try Data(contentsOf: url), false)
        }

        // ponytail: cap broad public.data previews; stream paging if huge files need full preview.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return (try handle.read(upToCount: maxPreviewBytes) ?? Data(), true)
    }

    private func showText(_ attributedText: NSAttributedString) {
        let scrollView = NSScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true

        let textView = PreviewTextView(frame: scrollView.bounds)
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.textContainer?.widthTracksTextView = false
        // ponytail: finite width avoids first-click lazy-layout blanking in Quick Look.
        textView.textContainer?.containerSize = NSSize(width: 100_000, height: CGFloat.greatestFiniteMagnitude)
        textView.layoutManager?.allowsNonContiguousLayout = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.onPersistentHighlight = { [weak self] range in
            self?.lastHighlightRange = range
        }
        textView.textStorage?.setAttributedString(attributedText)
        if let textContainer = textView.textContainer {
            textView.layoutManager?.ensureLayout(for: textContainer)
        }
        if let lastHighlightRange, NSMaxRange(lastHighlightRange) <= (attributedText.string as NSString).length {
            textView.restorePersistentHighlight(lastHighlightRange)
        }

        scrollView.documentView = textView
        previewTextView = textView
        view.subviews = [scrollView]
    }

    private func showGeneric(for url: URL) {
        preferredContentSize = CGSize(width: 760, height: 420)

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber).map { ByteCountFormatter.string(fromByteCount: $0.int64Value, countStyle: .file) } ?? ""
        let modified = (attributes?[.modificationDate] as? Date).map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .medium) } ?? ""

        let icon = NSTextField(labelWithString: "?")
        icon.alignment = .center
        icon.font = .systemFont(ofSize: 92, weight: .light)
        icon.textColor = .tertiaryLabelColor
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 10
        icon.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: url.lastPathComponent)
        title.font = .systemFont(ofSize: 32, weight: .bold)
        title.lineBreakMode = .byTruncatingMiddle

        let details = NSTextField(labelWithString: [size, modified].filter { !$0.isEmpty }.joined(separator: "\n"))
        details.font = .systemFont(ofSize: 17)
        details.textColor = .secondaryLabelColor
        details.maximumNumberOfLines = 2

        let labels = NSStackView(views: [title, details])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 12

        let stack = NSStackView(views: [icon, labels])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 54
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: view.bounds)
        container.autoresizingMask = [.width, .height]
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 150),
            icon.heightAnchor.constraint(equalToConstant: 190),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -36)
        ])

        view.subviews = [container]
        lastHighlightRange = nil
        previewTextView = nil
    }
}

private final class PreviewTextView: NSTextView {
    private var highlightedRange: NSRange?
    private var highlightedSnapshot: NSAttributedString?
    private var suppressNextMouseUp = false
    var onPersistentHighlight: ((NSRange) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)

        if event.clickCount > 1, consumeMultiClick(event) {
            suppressNextMouseUp = true
            return
        }

        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        guard !suppressNextMouseUp else {
            suppressNextMouseUp = false
            return
        }

        super.mouseUp(with: event)
    }

    func consumeMultiClick(_ event: NSEvent) -> Bool {
        guard event.window === window else {
            return false
        }

        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else {
            return false
        }

        window?.makeFirstResponder(self)
        guard event.type == .leftMouseDown, let range = selectionRange(at: point, clickCount: event.clickCount) else {
            return true
        }

        setSelectedRange(range)
        scrollRangeToVisible(range)
        applyPersistentHighlight(range)
        onPersistentHighlight?(range)
        return true
    }

    private func selectionRange(at point: NSPoint, clickCount: Int) -> NSRange? {
        guard let layoutManager, let textContainer else {
            return nil
        }

        let nsString = string as NSString
        guard nsString.length > 0 else {
            return nil
        }

        layoutManager.ensureLayout(for: textContainer)

        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = min(layoutManager.characterIndexForGlyph(at: glyphIndex), nsString.length - 1)

        if clickCount == 2 {
            return wordRange(in: nsString, at: characterIndex)
        }

        return nsString.lineRange(for: NSRange(location: characterIndex, length: 0))
    }

    private func wordRange(in nsString: NSString, at index: Int) -> NSRange {
        let wordCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

        guard isWordCharacter(nsString.character(at: index), in: wordCharacters) else {
            return nsString.rangeOfComposedCharacterSequence(at: index)
        }

        var start = index
        while start > 0, isWordCharacter(nsString.character(at: start - 1), in: wordCharacters) {
            start -= 1
        }

        var end = index + 1
        while end < nsString.length, isWordCharacter(nsString.character(at: end), in: wordCharacters) {
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    private func isWordCharacter(_ character: unichar, in characterSet: CharacterSet) -> Bool {
        guard let scalar = UnicodeScalar(character) else {
            return false
        }

        return characterSet.contains(scalar)
    }

    private func applyPersistentHighlight(_ range: NSRange) {
        clearPersistentHighlight()
        highlightedSnapshot = textStorage?.attributedSubstring(from: range)
        highlightedRange = range

        textStorage?.addAttributes([
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor
        ], range: range)
    }

    func restorePersistentHighlight(_ range: NSRange) {
        setSelectedRange(range)
        applyPersistentHighlight(range)
    }

    func copySelectionToPasteboard() -> Bool {
        let selectedRange = selectedRange()
        let range = selectedRange.length > 0 ? selectedRange : highlightedRange
        guard let range, range.length > 0, NSMaxRange(range) <= (string as NSString).length else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString((string as NSString).substring(with: range), forType: .string)
    }

    override func copy(_ sender: Any?) {
        _ = copySelectionToPasteboard()
    }

    private func clearPersistentHighlight() {
        guard let highlightedRange, let highlightedSnapshot else {
            return
        }

        textStorage?.replaceCharacters(in: highlightedRange, with: highlightedSnapshot)
        self.highlightedRange = nil
        self.highlightedSnapshot = nil
    }
}
