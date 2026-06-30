import AppKit

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
    static func text(from data: Data) -> String? {
        if data.isEmpty {
            return ""
        }

        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }

        guard data.prefix(8192).allSatisfy({ $0 == 9 || $0 == 10 || $0 == 12 || $0 == 13 || $0 >= 32 }) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
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
