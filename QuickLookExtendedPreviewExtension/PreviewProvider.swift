import AppKit
import Quartz
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    // These limits are baked into the built extension through Info.plist, which keeps runtime startup cheap.
    private static let config = PreviewConfig.load()
    private static let yamlExtensions: Set<String> = ["kubeconfig", "yaml", "yml"]
    private static let hclExtensions: Set<String> = ["tf", "tfvars", "hcl", "nomad"]
    private static let jsonExtensions: Set<String> = ["json", "jsonnet", "tfstate"]
    private static let markdownExtensions: Set<String> = ["markdown", "md"]
    private static let propertyListExtensions: Set<String> = ["csproj", "plist", "runsettings", "targets", "xml", "xsd"]
    private static let codeExtensions: Set<String> = [
        "bash", "c", "cmake", "cpp", "cs", "css", "cue", "fish", "go", "gradle", "graphql", "groovy",
        "h", "hpp", "html", "java", "js", "jsx", "kt", "kts", "m", "mk", "mm", "podspec",
        "proto", "ps1", "py", "rb", "rs", "sh", "sql", "swift", "ts", "tsx", "zsh"
    ]
    private static let configExtensions: Set<String> = [
        "cfg", "conf", "config", "dockerignore", "editorconfig", "entitlements", "env", "gemrc",
        "gitattributes", "gitignore", "ini", "npmrc", "pbxproj", "properties", "props",
        "list", "lock", "log", "rst", "service", "sln", "toml", "xcconfig", "xcodeproj", "yarnrc"
    ]
    private static let plainTextExtensions: Set<String> = [
        "bash", "cfg", "conf", "config", "crt", "csr", "cue", "dockerfile",
        "dockerignore", "editorconfig", "entitlements", "env", "fish", "gemrc", "gitattributes",
        "gitignore", "go", "gradle", "groovy", "ini", "jsonnet", "kt", "kts",
        "kubeconfig", "list", "lock", "npmrc", "pbxproj", "pem", "podspec", "properties", "props", "pub",
        "ps1", "rs", "rst", "service", "sln", "tfstate", "toml", "xcconfig", "xcodeproj", "yarnrc"
    ]

    func providePreview(for request: QLFilePreviewRequest, completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let url = request.fileURL
        let fileExtension = url.pathExtension.lowercased()
        let contentType = UTType(filenameExtension: fileExtension)
        let syntax = Self.syntax(for: url, contentType: contentType)
        let isPlainText = fileExtension.isEmpty || Self.plainTextExtensions.contains(fileExtension) || contentType?.conforms(to: .text) == true

        // Returning no reply lets Quick Look fall back to the system preview for formats we do not own.
        guard syntax != nil || isPlainText else {
            handler(nil, CocoaError(.fileReadUnsupportedScheme))
            return
        }

        do {
            let (data, truncated) = try Self.previewData(from: url, syntax: syntax)
            guard let text = try Self.text(from: data, syntax: syntax) else {
                handler(nil, CocoaError(.fileReadCorruptFile))
                return
            }

            let previewText = text + (truncated ? "\n\n... preview truncated ..." : "")
            let contentType: UTType
            let previewData: Data

            if syntax == .markdown {
                previewData = MarkdownRenderer.htmlData(from: previewText)
                contentType = .html
            } else if let syntax, previewText.utf8.count <= Self.config.maxHighlightedBytes {
                // RTF generation is the expensive step. Keep highlighting capped so Space stays instant.
                let highlightedText = Self.highlight(previewText, as: syntax)
                previewData = try Self.rtfData(from: highlightedText)
                contentType = .rtf
            } else {
                previewData = previewText.data(using: .utf8) ?? Data()
                contentType = .plainText
            }

            let reply = QLPreviewReply(dataOfContentType: contentType, contentSize: CGSize(width: 900, height: 700)) { _ in previewData }
            reply.title = url.lastPathComponent
            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }

    private static func syntax(for url: URL, contentType: UTType?) -> Syntax? {
        let fileExtension = url.pathExtension.lowercased()
        let filename = url.lastPathComponent.lowercased()

        // Prefer filename and extension checks over UTType when macOS maps useful text extensions to unrelated types.
        if yamlExtensions.contains(fileExtension) || filename == "kubeconfig" {
            return .yaml
        }
        if hclExtensions.contains(fileExtension) {
            return .hcl
        }
        if jsonExtensions.contains(fileExtension) {
            return .json
        }
        if markdownExtensions.contains(fileExtension) {
            return .markdown
        }
        if propertyListExtensions.contains(fileExtension) || contentType?.identifier.contains("property-list") == true {
            return .propertyList
        }
        if codeExtensions.contains(fileExtension) {
            return .code
        }
        if contentType?.conforms(to: .sourceCode) == true {
            return .code
        }
        if configExtensions.contains(fileExtension) || filename == ".env" {
            return .config
        }
        if fileExtension == "dockerfile" || filename == "dockerfile" {
            return .dockerfile
        }

        return nil
    }

    private static func highlight(_ text: String, as syntax: Syntax) -> NSAttributedString {
        switch syntax {
        case .yaml:
            return YAMLHighlighter.attributed(text, highlighted: true)
        case .hcl:
            return TerraformHighlighter.attributed(text)
        case .json:
            return JSONHighlighter.attributed(text)
        case .markdown:
            return YAMLHighlighter.attributed(text, highlighted: false)
        case .propertyList:
            return XMLHighlighter.attributed(text)
        case .code:
            return CodeHighlighter.attributed(text)
        case .config:
            return ConfigHighlighter.attributed(text)
        case .dockerfile:
            return DockerfileHighlighter.attributed(text)
        }
    }

    private static func previewData(from url: URL, syntax: Syntax?) throws -> (Data, Bool) {
        let sourceURL = previewSourceURL(for: url)
        let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        let readLimit = Self.config.maxPreviewBytes == 0 ? size : min(size, Self.config.maxPreviewBytes)
        let truncated = Self.config.maxPreviewBytes > 0 && size > Self.config.maxPreviewBytes

        guard readLimit > 0 else {
            return (Data(), false)
        }

        let handle = try FileHandle(forReadingFrom: sourceURL)
        defer { try? handle.close() }

        // The extension also claims public.data for extensionless files, so reject obvious binaries early.
        let firstChunk = try handle.read(upToCount: min(readLimit, Self.config.binarySniffBytes)) ?? Data()
        if syntax != .propertyList, !TextSniffer.isProbablyText(firstChunk) {
            throw CocoaError(.fileReadCorruptFile)
        }

        guard firstChunk.count < readLimit else {
            return (firstChunk, truncated)
        }

        var data = firstChunk
        if let rest = try handle.read(upToCount: readLimit - firstChunk.count) {
            data.append(rest)
        }
        return (data, truncated)
    }

    private static func previewSourceURL(for url: URL) -> URL {
        guard url.pathExtension.lowercased() == "xcodeproj" else {
            return url
        }

        return url.appendingPathComponent("project.pbxproj", isDirectory: false)
    }

    private static func text(from data: Data, syntax: Syntax?) throws -> String? {
        if let text = TextSniffer.text(from: data) {
            return text
        }

        // Binary plists are text-like to the user, but must be converted before Quick Look can render them.
        guard case .propertyList? = syntax else {
            return nil
        }

        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let xmlData = try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
        return String(data: xmlData, encoding: .utf8)
    }

    private static func rtfData(from attributedText: NSAttributedString) throws -> Data {
        try attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}

private enum Syntax: Equatable {
    case yaml
    case hcl
    case json
    case markdown
    case propertyList
    case code
    case config
    case dockerfile
}

private struct PreviewConfig {
    private static let defaultMaxPreviewBytes = 0
    private static let defaultMaxHighlightedBytes = 256 * 1024
    private static let defaultBinarySniffBytes = 16 * 1024

    let maxPreviewBytes: Int
    let maxHighlightedBytes: Int
    let binarySniffBytes: Int

    static func load() -> PreviewConfig {
        // Xcode substitutes QLE_* build settings into these Info.plist keys during build.
        let info = Bundle(for: PreviewProvider.self).infoDictionary ?? [:]
        return PreviewConfig(
            maxPreviewBytes: nonNegativeInt("QLEMaxPreviewBytes", in: info, fallback: defaultMaxPreviewBytes),
            maxHighlightedBytes: positiveInt("QLEMaxHighlightedBytes", in: info, fallback: defaultMaxHighlightedBytes),
            binarySniffBytes: positiveInt("QLEBinarySniffBytes", in: info, fallback: defaultBinarySniffBytes)
        )
    }

    private static func nonNegativeInt(_ key: String, in info: [String: Any], fallback: Int) -> Int {
        if let number = info[key] as? NSNumber, number.intValue >= 0 {
            return number.intValue
        }

        if let string = info[key] as? String, let value = Int(string), value >= 0 {
            return value
        }

        return fallback
    }

    private static func positiveInt(_ key: String, in info: [String: Any], fallback: Int) -> Int {
        if let number = info[key] as? NSNumber, number.intValue > 0 {
            return number.intValue
        }

        if let string = info[key] as? String, let value = Int(string), value > 0 {
            return value
        }

        return fallback
    }
}
