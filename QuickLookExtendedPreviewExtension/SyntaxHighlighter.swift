import AppKit

// Lightweight regex highlighters are enough for Quick Look: fast preview beats full language parsing here.
enum YAMLHighlighter {
    static var previewFont: NSFont {
        NSFont.userFixedPitchFont(ofSize: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    static func attributed(_ text: String, highlighted: Bool) -> NSAttributedString {
        let baseFont = previewFont
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor
        ])

        guard highlighted else {
            return result
        }

        let nsText = text as NSString
        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)
            highlightLine(line, offset: lineRange.location, in: result)
        }

        return result
    }

    private static func highlightLine(_ line: String, offset: Int, in result: NSMutableAttributedString) {
        let commentStart = line.firstCommentStart()
        let body = commentStart.map { String(line[..<$0]) } ?? line

        if let keyRange = body.range(of: #"^\s*(?:-\s*)?[^:#\[\]\{\},]+:"#, options: .regularExpression) {
            let range = NSRange(keyRange, in: body)
            result.addAttributes([
                .font: NSFontManager.shared.convert(previewFont, toHaveTrait: .boldFontMask),
                .foregroundColor: NSColor.systemBlue
            ], range: NSRange(location: offset + range.location, length: range.length))
        }

        highlightScalars(body, offset: offset, in: result)

        if let commentStart {
            let commentRange = NSRange(commentStart..<line.endIndex, in: line)
            result.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .obliqueness: 0.15
            ], range: NSRange(location: offset + commentRange.location, length: commentRange.length))
        }
    }

    private static func highlightScalars(_ value: String, offset: Int, in result: NSMutableAttributedString) {
        let pattern = #"'[^']*'|"(?:\\.|[^"\\])*"|(?<![\w.-])-?\d+(?:\.\d+)?(?![\w.-])|(?<![\w.-])(?:true|false|null|yes|no|on|off)(?![\w.-])"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))

        for match in matches {
            guard let range = Range(match.range, in: value) else {
                continue
            }

            let token = String(value[range])
            let color = token.first == "\"" || token.first == "'" ? NSColor.systemGreen : token.rangeOfCharacter(from: .decimalDigits) == nil ? NSColor.systemPurple : NSColor.systemOrange
            result.addAttribute(.foregroundColor, value: color, range: NSRange(location: offset + match.range.location, length: match.range.length))
        }
    }
}

enum TextSniffer {
    // Conservative text test for broad public.data handling. The caller chooses the sample size.
    static func isProbablyText(_ data: Data) -> Bool {
        if data.isEmpty {
            return true
        }

        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return true
        }

        return data.allSatisfy { $0 == 9 || $0 == 10 || $0 == 12 || $0 == 13 || $0 >= 32 }
    }

    static func text(from data: Data) -> String? {
        if data.isEmpty {
            return ""
        }

        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }

        guard isProbablyText(data) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

enum PreviewHTML {
    static func document(body: String, bodyClass: String = "", style: String = "") -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; }
        html, body { min-height: 100%; background: Canvas; }
        body { margin: 0; color: CanvasText; }
        .qle-toolbar { position: fixed; top: 8px; right: 10px; z-index: 10; display: flex; align-items: center; gap: 3px; padding: 3px; border: 1px solid color-mix(in srgb, CanvasText 16%, transparent); border-radius: 7px; background: color-mix(in srgb, Canvas 82%, transparent); -webkit-backdrop-filter: blur(18px) saturate(160%); box-shadow: 0 2px 10px color-mix(in srgb, CanvasText 14%, transparent); font: 12px -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; user-select: none; }
        .qle-toolbar button { width: 26px; height: 24px; border: 0; border-radius: 5px; background: transparent; color: CanvasText; font: 17px -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1; }
        .qle-toolbar button:hover { background: color-mix(in srgb, CanvasText 9%, transparent); }
        .qle-toolbar button:active { transform: scale(0.94); background: color-mix(in srgb, CanvasText 14%, transparent); }
        .qle-toolbar button:disabled { opacity: 0.35; }
        .qle-toolbar button[aria-pressed="true"] { background: color-mix(in srgb, CanvasText 12%, transparent); }
        .qle-toolbar .qle-wrap-toggle { width: 26px; }
        .qle-wrap-icon { position: relative; display: inline-block; width: 17px; height: 10px; vertical-align: -1px; }
        .qle-wrap-prompt { position: absolute; left: 0; top: 0; width: 6px; height: 8px; }
        .qle-wrap-prompt::before, .qle-wrap-prompt::after { content: ""; position: absolute; top: 2px; right: 0; width: 6px; height: 2px; border-radius: 1px; background: currentColor; transform-origin: right center; }
        .qle-wrap-prompt::before { transform: rotate(35deg); }
        .qle-wrap-prompt::after { transform: rotate(-35deg); }
        .qle-wrap-icon::before, .qle-wrap-icon::after { content: ""; position: absolute; left: 7px; right: 1px; height: 2px; border-radius: 1px; background: currentColor; }
        .qle-wrap-icon::before { top: 2px; }
        .qle-wrap-icon::after { bottom: 2px; right: 5px; }
        .qle-wrap-toggle[aria-pressed="false"] .qle-wrap-prompt { top: 2px; }
        .qle-wrap-toggle[aria-pressed="false"] .qle-wrap-icon::before { top: 4px; }
        .qle-wrap-toggle[aria-pressed="false"] .qle-wrap-icon::after { display: none; }
        .qle-zoom-value { min-width: 42px; text-align: center; font-variant-numeric: tabular-nums; }
        .qle-content { min-height: 100vh; }
        @media (prefers-reduced-transparency: reduce) {
            .qle-toolbar { background: Canvas; -webkit-backdrop-filter: none; }
        }
        \(style)
        </style>
        </head>
        <body>
        <div class="qle-toolbar" role="toolbar" aria-label="Zoom controls">
        <button id="qle-zoom-out" type="button" aria-label="Zoom out">-</button>
        <span id="qle-zoom-value" class="qle-zoom-value" aria-live="polite">100%</span>
        <button id="qle-zoom-in" type="button" aria-label="Zoom in">+</button>
        <button id="qle-wrap-toggle" class="qle-wrap-toggle" type="button" aria-label="Disable line wrap" aria-pressed="true" title="Disable line wrap"><span class="qle-wrap-icon" aria-hidden="true"><span class="qle-wrap-prompt"></span></span></button>
        </div>
        <main id="qle-content" class="qle-content \(bodyClass)">\(body)</main>
        <script>
        (() => {
            const content = document.getElementById('qle-content');
            const percent = document.getElementById('qle-zoom-value');
            const outButton = document.getElementById('qle-zoom-out');
            const inButton = document.getElementById('qle-zoom-in');
            const wrapButton = document.getElementById('qle-wrap-toggle');
            const minZoom = 0.5;
            const maxZoom = 3;
            const buttonStep = 0.1;
            let zoom = 1;
            let gestureStartZoom = 1;
            let lineWrap = true;

            function clamp(value) {
                return Math.min(maxZoom, Math.max(minZoom, value));
            }

            function setZoom(value) {
                zoom = Math.round(clamp(value) * 100) / 100;
                content.style.zoom = String(zoom);
                percent.textContent = Math.round(zoom * 100) + '%';
                outButton.disabled = zoom <= minZoom;
                inButton.disabled = zoom >= maxZoom;
            }

            outButton.addEventListener('click', () => setZoom(zoom - buttonStep));
            inButton.addEventListener('click', () => setZoom(zoom + buttonStep));
            wrapButton.addEventListener('click', () => setLineWrap(!lineWrap));

            function setLineWrap(enabled) {
                lineWrap = enabled;
                content.classList.toggle('qle-nowrap', !lineWrap);
                wrapButton.setAttribute('aria-pressed', String(lineWrap));
                wrapButton.setAttribute('aria-label', lineWrap ? 'Disable line wrap' : 'Enable line wrap');
                wrapButton.title = lineWrap ? 'Disable line wrap' : 'Enable line wrap';
            }

            document.addEventListener('gesturestart', (event) => {
                event.preventDefault();
                gestureStartZoom = zoom;
            }, { passive: false });

            document.addEventListener('gesturechange', (event) => {
                event.preventDefault();
                setZoom(gestureStartZoom * event.scale);
            }, { passive: false });

            document.addEventListener('wheel', (event) => {
                if (!event.ctrlKey) {
                    return;
                }
                event.preventDefault();
                setZoom(zoom * Math.exp(-event.deltaY * 0.01));
            }, { passive: false });

            setZoom(zoom);
            setLineWrap(lineWrap);
        })();
        </script>
        </body>
        </html>
        """
    }

    static func plainTextData(from text: String) -> Data {
        Data(document(body: #"<pre class="qle-code">\#(escape(text))</pre>"#, bodyClass: "qle-code-wrap", style: codeStyle).utf8)
    }

    static func codeData(from attributedText: NSAttributedString) -> Data {
        Data(document(body: #"<pre class="qle-code">\#(attributedHTML(from: attributedText))</pre>"#, bodyClass: "qle-code-wrap", style: codeStyle).utf8)
    }

    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let codeStyle = """
    .qle-code-wrap { padding: 18px 24px 24px; }
    .qle-code { margin: 0; font: 12px ui-monospace, SFMono-Regular, Menlo, Monaco, monospace; line-height: 1.45; tab-size: 4; white-space: pre-wrap; overflow-wrap: anywhere; }
    .qle-code-wrap.qle-nowrap .qle-code { white-space: pre; overflow-wrap: normal; overflow: auto; }
    """

    private static func attributedHTML(from attributedText: NSAttributedString) -> String {
        let source = attributedText.string as NSString
        var html = ""
        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length)) { attributes, range, _ in
            let text = escape(source.substring(with: range))
            let style = styleAttribute(from: attributes)
            html += style.isEmpty ? text : #"<span style="\#(style)">\#(text)</span>"#
        }
        return html
    }

    private static func styleAttribute(from attributes: [NSAttributedString.Key: Any]) -> String {
        var styles: [String] = []

        if let color = attributes[.foregroundColor] as? NSColor, let css = cssColor(color) {
            styles.append("color: \(css)")
        }

        if let font = attributes[.font] as? NSFont, NSFontManager.shared.traits(of: font).contains(.boldFontMask) {
            styles.append("font-weight: 600")
        }

        if attributes[.obliqueness] != nil {
            styles.append("font-style: italic")
        }

        return styles.joined(separator: "; ")
    }

    private static func cssColor(_ color: NSColor) -> String? {
        if color == .labelColor {
            return nil
        }
        if color == .secondaryLabelColor {
            return "color-mix(in srgb, CanvasText 58%, Canvas)"
        }
        if color == .systemBlue {
            return "rgb(0, 122, 255)"
        }
        if color == .systemGreen {
            return "rgb(52, 199, 89)"
        }
        if color == .systemPurple {
            return "rgb(175, 82, 222)"
        }
        if color == .systemOrange {
            return "rgb(255, 149, 0)"
        }

        guard let rgb = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB) else {
            return nil
        }

        return String(
            format: "rgba(%d, %d, %d, %.3f)",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded()),
            rgb.alphaComponent
        )
    }
}

enum MarkdownRenderer {
    // ponytail: common Markdown preview only; use a CommonMark library if full spec coverage matters.
    static func htmlData(from text: String) -> Data {
        Data(PreviewHTML.document(body: render(text), bodyClass: "qle-markdown", style: """
        .qle-markdown { padding: 24px 30px; font: -apple-system-body; line-height: 1.45; }
        .qle-markdown code, .qle-markdown pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.92em; }
        .qle-markdown pre { padding: 12px; border-radius: 8px; overflow: auto; background: color-mix(in srgb, CanvasText 8%, Canvas); }
        .qle-markdown blockquote { margin-left: 0; padding-left: 14px; border-left: 3px solid color-mix(in srgb, CanvasText 30%, Canvas); color: color-mix(in srgb, CanvasText 75%, Canvas); }
        .qle-markdown h1, .qle-markdown h2, .qle-markdown h3, .qle-markdown h4, .qle-markdown h5, .qle-markdown h6 { padding-right: 130px; line-height: 1.2; margin: 1em 0 0.45em; }
        .qle-markdown p, .qle-markdown ul, .qle-markdown ol, .qle-markdown pre { margin: 0 0 1em; }
        .qle-markdown a { color: LinkText; }
        .qle-markdown table { width: 100%; table-layout: fixed; border-collapse: collapse; margin: 0 0 1em; }
        .qle-markdown th, .qle-markdown td { padding: 6px 8px; border: 1px solid color-mix(in srgb, CanvasText 18%, Canvas); vertical-align: top; overflow-wrap: anywhere; }
        .qle-markdown th { font-weight: 600; }
        .qle-markdown td code, .qle-markdown th code { padding: 2px 4px; border-radius: 4px; background: color-mix(in srgb, CanvasText 8%, Canvas); }
        """).utf8)
    }

    private static func render(_ text: String) -> String {
        var html = ""
        var paragraph: [String] = []
        var inList = false
        var inCode = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html += "<p>\(inline(paragraph.joined(separator: " ")))</p>\n"
            paragraph.removeAll()
        }

        func closeList() {
            guard inList else { return }
            html += "</ul>\n"
            inList = false
        }

        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: .newlines)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            index += 1

            if trimmed.hasPrefix("```") {
                flushParagraph()
                closeList()
                html += inCode ? "</code></pre>\n" : "<pre><code>"
                inCode.toggle()
                continue
            }

            if inCode {
                html += "\(escape(line))\n"
                continue
            }

            guard !trimmed.isEmpty else {
                flushParagraph()
                closeList()
                continue
            }

            if trimmed.hasPrefix("> ") {
                flushParagraph()
                closeList()
                html += "<blockquote>\(inline(String(trimmed.dropFirst(2))))</blockquote>\n"
            } else if let heading = heading(from: trimmed) {
                flushParagraph()
                closeList()
                html += "<h\(heading.level)>\(inline(heading.text))</h\(heading.level)>\n"
            } else if let item = unorderedListItem(from: trimmed) {
                flushParagraph()
                if !inList {
                    html += "<ul>\n"
                    inList = true
                }
                html += "<li>\(inline(item))</li>\n"
            } else if index < lines.count,
                      let header = tableCells(from: trimmed),
                      let alignments = tableAlignments(from: lines[index]),
                      header.count == alignments.count {
                flushParagraph()
                closeList()
                html += "<table><thead>\(tableRow(header, alignments: alignments, isHeader: true))</thead><tbody>\n"
                index += 1
                while index < lines.count {
                    let row = lines[index].trimmingCharacters(in: .whitespaces)
                    guard !row.hasPrefix("```"), !row.hasPrefix("> "),
                          heading(from: row) == nil, unorderedListItem(from: row) == nil,
                          let cells = tableCells(from: row) else { break }
                    html += tableRow(cells, alignments: alignments) + "\n"
                    index += 1
                }
                html += "</tbody></table>\n"
            } else {
                paragraph.append(trimmed)
            }
        }

        flushParagraph()
        closeList()
        if inCode {
            html += "</code></pre>\n"
        }
        return html
    }

    private static func tableCells(from line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var cells: [String] = []
        var cell = ""
        var characters = trimmed.makeIterator()
        var endsWithSeparator = false
        while let character = characters.next() {
            endsWithSeparator = false
            if character == "\\", let next = characters.next() {
                // Escaped pipes belong to the cell, including inside inline code.
                cell.append(next == "|" ? "" : "\\")
                cell.append(next)
            } else if character == "|" {
                cells.append(cell.trimmingCharacters(in: .whitespaces))
                cell = ""
                endsWithSeparator = true
            } else {
                cell.append(character)
            }
        }
        guard !cells.isEmpty else { return nil }
        cells.append(cell.trimmingCharacters(in: .whitespaces))
        if trimmed.hasPrefix("|") { cells.removeFirst() }
        if endsWithSeparator { cells.removeLast() }
        return cells.isEmpty ? nil : cells
    }

    private static func tableAlignments(from line: String) -> [String]? {
        guard let cells = tableCells(from: line),
              cells.allSatisfy({ $0.range(of: #"^:?-+:?$"#, options: .regularExpression) != nil }) else {
            return nil
        }
        return cells.map { $0.hasSuffix(":") ? ($0.hasPrefix(":") ? "center" : "right") : "left" }
    }

    private static func tableRow(_ cells: [String], alignments: [String], isHeader: Bool = false) -> String {
        let tag = isHeader ? "th" : "td"
        let scope = isHeader ? #" scope="col""# : ""
        let contents = alignments.enumerated().map { index, alignment in
            let text = index < cells.count ? cells[index] : ""
            return "<\(tag)\(scope) style=\"text-align: \(alignment)\">\(inline(text))</\(tag)>"
        }.joined()
        return "<tr>\(contents)</tr>"
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let count = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(count), line.dropFirst(count).first == " " else {
            return nil
        }
        return (count, String(line.dropFirst(count + 1)))
    }

    private static func unorderedListItem(from line: String) -> String? {
        guard line.count > 2 else { return nil }
        let marker = line.prefix(2)
        guard marker == "- " || marker == "* " || marker == "+ " else {
            return nil
        }
        return String(line.dropFirst(2))
    }

    private static func inline(_ text: String) -> String {
        var value = escape(text)
        value = replace(#"`([^`]+)`"#, with: #"<code>$1</code>"#, in: value)
        value = replace(#"\*\*([^*]+)\*\*"#, with: #"<strong>$1</strong>"#, in: value)
        value = replace(#"\*([^*]+)\*"#, with: #"<em>$1</em>"#, in: value)
        value = replace(#"\[([^\]]+)\]\(([^)]+)\)"#, with: #"<a href="$2">$1</a>"#, in: value)
        return value
    }

    private static func replace(_ pattern: String, with template: String, in text: String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: template)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

enum TerraformHighlighter {
    static func attributed(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: YAMLHighlighter.previewFont,
            .foregroundColor: NSColor.labelColor
        ])
        let nsText = text as NSString

        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)
            highlightLine(line, offset: lineRange.location, in: result)
        }

        return result
    }

    private static func highlightLine(_ line: String, offset: Int, in result: NSMutableAttributedString) {
        let commentStart = line.firstTerraformCommentStart()
        let body = commentStart.map { String(line[..<$0]) } ?? line

        apply(pattern: #"^\s*([A-Za-z_][A-Za-z0-9_-]*)\s*="#, group: 1, to: body, offset: offset, in: result, attributes: [
            .font: NSFontManager.shared.convert(YAMLHighlighter.previewFont, toHaveTrait: .boldFontMask),
            .foregroundColor: NSColor.systemBlue
        ])
        apply(pattern: #"^\s*(resource|data|provider|variable|output|locals|module|terraform|moved|import|check)\b"#, group: 1, to: body, offset: offset, in: result, attributes: [
            .font: NSFontManager.shared.convert(YAMLHighlighter.previewFont, toHaveTrait: .boldFontMask),
            .foregroundColor: NSColor.systemBlue
        ])
        highlightScalars(body, offset: offset, in: result)

        if let commentStart {
            let commentRange = NSRange(commentStart..<line.endIndex, in: line)
            result.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .obliqueness: 0.15
            ], range: NSRange(location: offset + commentRange.location, length: commentRange.length))
        }
    }

    private static func highlightScalars(_ value: String, offset: Int, in result: NSMutableAttributedString) {
        let pattern = #""(?:\\.|[^"\\])*"|(?<![\w.-])-?\d+(?:\.\d+)?(?![\w.-])|(?<![\w.-])(?:true|false|null)(?![\w.-])"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))

        for match in matches {
            guard let range = Range(match.range, in: value) else {
                continue
            }

            let token = String(value[range])
            let color = token.first == "\"" ? NSColor.systemGreen : token.rangeOfCharacter(from: .decimalDigits) == nil ? NSColor.systemPurple : NSColor.systemOrange
            result.addAttribute(.foregroundColor, value: color, range: NSRange(location: offset + match.range.location, length: match.range.length))
        }
    }

    private static func apply(pattern: String, group: Int, to text: String, offset: Int, in result: NSMutableAttributedString, attributes: [NSAttributedString.Key: Any]) {
        let regex = try! NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), match.numberOfRanges > group else {
            return
        }

        let range = match.range(at: group)
        result.addAttributes(attributes, range: NSRange(location: offset + range.location, length: range.length))
    }
}

enum JSONHighlighter {
    static func attributed(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: YAMLHighlighter.previewFont,
            .foregroundColor: NSColor.labelColor
        ])
        let pattern = #""(?:\\.|[^"\\])*"|(?<![\w.-])-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?(?![\w.-])|(?<![\w.-])(?:true|false|null)(?![\w.-])"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches {
            guard let range = Range(match.range, in: text) else {
                continue
            }

            let token = String(text[range])
            let attributes: [NSAttributedString.Key: Any]
            if token.first == "\"" {
                let tail = text[range.upperBound...]
                if tail.range(of: #"^\s*:"#, options: .regularExpression) != nil {
                    attributes = [
                        .font: NSFontManager.shared.convert(YAMLHighlighter.previewFont, toHaveTrait: .boldFontMask),
                        .foregroundColor: NSColor.systemBlue
                    ]
                } else {
                    attributes = [.foregroundColor: NSColor.systemGreen]
                }
            } else {
                attributes = [.foregroundColor: token.rangeOfCharacter(from: .decimalDigits) == nil ? NSColor.systemPurple : NSColor.systemOrange]
            }

            result.addAttributes(attributes, range: match.range)
        }

        return result
    }
}

enum XMLHighlighter {
    static func attributed(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: YAMLHighlighter.previewFont,
            .foregroundColor: NSColor.labelColor
        ])

        apply(pattern: #"<!--[\s\S]*?-->"#, to: text, in: result, attributes: [
            .foregroundColor: NSColor.secondaryLabelColor,
            .obliqueness: 0.15
        ])
        apply(pattern: #"</?\s*([A-Za-z_][A-Za-z0-9_.:-]*)"#, group: 1, to: text, in: result, attributes: [
            .font: NSFontManager.shared.convert(YAMLHighlighter.previewFont, toHaveTrait: .boldFontMask),
            .foregroundColor: NSColor.systemBlue
        ])
        apply(pattern: #"\s([A-Za-z_][A-Za-z0-9_.:-]*)\s*="#, group: 1, to: text, in: result, attributes: [
            .foregroundColor: NSColor.systemPurple
        ])
        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, to: text, in: result, attributes: [
            .foregroundColor: NSColor.systemGreen
        ])
        apply(pattern: #"<key>([^<]+)</key>"#, group: 1, to: text, in: result, attributes: [
            .font: NSFontManager.shared.convert(YAMLHighlighter.previewFont, toHaveTrait: .boldFontMask),
            .foregroundColor: NSColor.systemBlue
        ])
        apply(pattern: #"<(?:string|date|data)>([^<]+)</(?:string|date|data)>"#, group: 1, to: text, in: result, attributes: [
            .foregroundColor: NSColor.systemGreen
        ])
        apply(pattern: #"<(?:integer|real)>([^<]+)</(?:integer|real)>"#, group: 1, to: text, in: result, attributes: [
            .foregroundColor: NSColor.systemOrange
        ])
        apply(pattern: #"<(?:true|false)\s*/>"#, to: text, in: result, attributes: [
            .foregroundColor: NSColor.systemPurple
        ])

        return result
    }

    private static func apply(pattern: String, group: Int = 0, to text: String, in result: NSMutableAttributedString, attributes: [NSAttributedString.Key: Any]) {
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches where match.numberOfRanges > group {
            let range = match.range(at: group)
            guard range.location != NSNotFound else {
                continue
            }

            result.addAttributes(attributes, range: range)
        }
    }
}

enum ConfigHighlighter {
    static func attributed(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: YAMLHighlighter.previewFont,
            .foregroundColor: NSColor.labelColor
        ])
        let nsText = text as NSString

        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)
            highlightLine(line, offset: lineRange.location, in: result)
        }

        return result
    }

    private static func highlightLine(_ line: String, offset: Int, in result: NSMutableAttributedString) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") || trimmed.hasPrefix(";") || trimmed.hasPrefix("!") {
            result.addAttributes(commentAttributes, range: NSRange(location: offset, length: (line as NSString).length))
            return
        }

        let commentStart = line.firstConfigCommentStart()
        let body = commentStart.map { String(line[..<$0]) } ?? line
        apply(pattern: #"^\s*\[[^\]]+\]"#, to: body, offset: offset, in: result, attributes: [
            .font: NSFontManager.shared.convert(YAMLHighlighter.previewFont, toHaveTrait: .boldFontMask),
            .foregroundColor: NSColor.systemPurple
        ])
        apply(pattern: #"^\s*([A-Za-z_][A-Za-z0-9_.-]*)\s*[:=]"#, group: 1, to: body, offset: offset, in: result, attributes: [
            .font: NSFontManager.shared.convert(YAMLHighlighter.previewFont, toHaveTrait: .boldFontMask),
            .foregroundColor: NSColor.systemBlue
        ])
        highlightScalars(body, offset: offset, in: result)

        if let commentStart {
            let commentRange = NSRange(commentStart..<line.endIndex, in: line)
            result.addAttributes(commentAttributes, range: NSRange(location: offset + commentRange.location, length: commentRange.length))
        }
    }

    private static var commentAttributes: [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.secondaryLabelColor,
            .obliqueness: 0.15
        ]
    }

    private static func highlightScalars(_ value: String, offset: Int, in result: NSMutableAttributedString) {
        let pattern = #"'[^']*'|"(?:\\.|[^"\\])*"|(?<![\w.-])-?\d+(?:\.\d+)?(?![\w.-])|(?<![\w.-])(?:true|false|null|yes|no|on|off)(?![\w.-])"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))

        for match in matches {
            guard let range = Range(match.range, in: value) else {
                continue
            }

            let token = String(value[range])
            let color = token.first == "\"" || token.first == "'" ? NSColor.systemGreen : token.rangeOfCharacter(from: .decimalDigits) == nil ? NSColor.systemPurple : NSColor.systemOrange
            result.addAttribute(.foregroundColor, value: color, range: NSRange(location: offset + match.range.location, length: match.range.length))
        }
    }

    private static func apply(pattern: String, group: Int = 0, to text: String, offset: Int, in result: NSMutableAttributedString, attributes: [NSAttributedString.Key: Any]) {
        let regex = try! NSRegularExpression(pattern: pattern)
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), match.numberOfRanges > group else {
            return
        }

        let range = match.range(at: group)
        result.addAttributes(attributes, range: NSRange(location: offset + range.location, length: range.length))
    }
}

enum CodeHighlighter {
    static func attributed(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: YAMLHighlighter.previewFont,
            .foregroundColor: NSColor.labelColor
        ])
        let nsText = text as NSString

        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)
            highlightLine(line, offset: lineRange.location, in: result)
        }

        return result
    }

    private static func highlightLine(_ line: String, offset: Int, in result: NSMutableAttributedString) {
        let commentStart = line.firstCodeCommentStart()
        let body = commentStart.map { String(line[..<$0]) } ?? line
        applyScalars(in: body, offset: offset, result: result)
        applyKeywords(in: body, offset: offset, result: result)

        if let commentStart {
            let commentRange = NSRange(commentStart..<line.endIndex, in: line)
            result.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .obliqueness: 0.15
            ], range: NSRange(location: offset + commentRange.location, length: commentRange.length))
        }
    }

    private static func applyScalars(in text: String, offset: Int, result: NSMutableAttributedString) {
        let pattern = #"'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|`(?:\\.|[^`\\])*`|(?<![\w.-])-?\d+(?:\.\d+)?(?![\w.-])|(?<![\w.-])(?:true|false|null|nil|none|yes|no)(?![\w.-])"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches {
            guard let range = Range(match.range, in: text) else {
                continue
            }

            let token = String(text[range])
            let color = token.first == "\"" || token.first == "'" || token.first == "`" ? NSColor.systemGreen : token.rangeOfCharacter(from: .decimalDigits) == nil ? NSColor.systemPurple : NSColor.systemOrange
            result.addAttribute(.foregroundColor, value: color, range: NSRange(location: offset + match.range.location, length: match.range.length))
        }
    }

    private static func applyKeywords(in text: String, offset: Int, result: NSMutableAttributedString) {
        let pattern = #"(?<![\w.])(?:async|await|break|case|catch|class|const|continue|data|def|defer|do|else|enum|export|extends|final|for|from|func|function|if|impl|import|in|interface|let|match|mod|package|private|protocol|public|return|select|static|struct|switch|throw|throws|try|type|use|val|var|while|with|SELECT|FROM|WHERE|JOIN|GROUP|ORDER|BY|WITH|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)(?![\w.])"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches {
            result.addAttributes([
                .font: NSFontManager.shared.convert(YAMLHighlighter.previewFont, toHaveTrait: .boldFontMask),
                .foregroundColor: NSColor.systemBlue
            ], range: NSRange(location: offset + match.range.location, length: match.range.length))
        }
    }
}

enum DockerfileHighlighter {
    static func attributed(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: YAMLHighlighter.previewFont,
            .foregroundColor: NSColor.labelColor
        ])
        let nsText = text as NSString

        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)
            highlightLine(line, offset: lineRange.location, in: result)
        }

        return result
    }

    private static func highlightLine(_ line: String, offset: Int, in result: NSMutableAttributedString) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            result.addAttributes([
                .foregroundColor: NSColor.secondaryLabelColor,
                .obliqueness: 0.15
            ], range: NSRange(location: offset, length: (line as NSString).length))
            return
        }

        let body = line.firstCommentStart().map { String(line[..<$0]) } ?? line
        let regex = try! NSRegularExpression(pattern: #"^\s*([A-Za-z]+)\b"#)
        if let match = regex.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)), match.numberOfRanges > 1 {
            result.addAttributes([
                .font: NSFontManager.shared.convert(YAMLHighlighter.previewFont, toHaveTrait: .boldFontMask),
                .foregroundColor: NSColor.systemBlue
            ], range: NSRange(location: offset + match.range(at: 1).location, length: match.range(at: 1).length))
        }
    }
}

private extension String {
    func firstCommentStart() -> Index? {
        var quote: Character?
        var previous: Character?

        for index in indices {
            let character = self[index]

            if character == "\"" || character == "'" {
                if quote == character, previous != "\\" {
                    quote = nil
                } else if quote == nil {
                    quote = character
                }
            } else if character == "#", quote == nil {
                return index
            }

            previous = character
        }

        return nil
    }

    func firstConfigCommentStart() -> Index? {
        var quote: Character?
        var previous: Character?

        for index in indices {
            let character = self[index]

            if character == "\"" || character == "'" {
                if quote == character, previous != "\\" {
                    quote = nil
                } else if quote == nil {
                    quote = character
                }
            } else if quote == nil, character == "#" || character == ";" {
                return index
            }

            previous = character
        }

        return nil
    }

    func firstCodeCommentStart() -> Index? {
        var quote: Character?
        var previous: Character?

        for index in indices {
            let character = self[index]

            if character == "\"" || character == "'" || character == "`" {
                if quote == character, previous != "\\" {
                    quote = nil
                } else if quote == nil {
                    quote = character
                }
            } else if quote == nil, character == "#" || character == "/" && self.index(after: index) < endIndex && self[self.index(after: index)] == "/" || character == "-" && self.index(after: index) < endIndex && self[self.index(after: index)] == "-" {
                return index
            }

            previous = character
        }

        return nil
    }

    func firstTerraformCommentStart() -> Index? {
        var quote: Character?
        var previous: Character?

        for index in indices {
            let character = self[index]

            if character == "\"" {
                if quote == character, previous != "\\" {
                    quote = nil
                } else if quote == nil {
                    quote = character
                }
            } else if quote == nil, character == "#" || character == "/" && self.index(after: index) < endIndex && self[self.index(after: index)] == "/" {
                return index
            }

            previous = character
        }

        return nil
    }
}
