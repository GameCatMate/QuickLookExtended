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

enum MarkdownRenderer {
    // ponytail: common Markdown preview only; use a CommonMark library if full spec coverage matters.
    static func htmlData(from text: String) -> Data {
        let document = """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        :root { color-scheme: light dark; }
        body { font: -apple-system-body; margin: 24px 30px; line-height: 1.45; color: CanvasText; background: Canvas; }
        code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.92em; }
        pre { padding: 12px; border-radius: 8px; overflow: auto; background: color-mix(in srgb, CanvasText 8%, Canvas); }
        blockquote { margin-left: 0; padding-left: 14px; border-left: 3px solid color-mix(in srgb, CanvasText 30%, Canvas); color: color-mix(in srgb, CanvasText 75%, Canvas); }
        h1, h2, h3, h4, h5, h6 { line-height: 1.2; margin: 1em 0 0.45em; }
        p, ul, ol, pre { margin: 0 0 1em; }
        a { color: LinkText; }
        </style>
        </head>
        <body>
        \(render(text))
        </body>
        </html>
        """
        return Data(document.utf8)
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

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

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
