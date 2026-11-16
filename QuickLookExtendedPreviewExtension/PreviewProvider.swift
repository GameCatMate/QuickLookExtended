import AppKit
import Quartz
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    // These limits are baked into the built extension through Info.plist, which keeps runtime startup cheap.
    private static let config = PreviewConfig.load()
    private static let maxListedItems = 1_000
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
        "ps1", "rs", "rst", "service", "sln", "tfstate", "toml", "tpl", "xcconfig", "xcodeproj", "yarnrc"
    ]

    func providePreview(for request: QLFilePreviewRequest, completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let url = request.fileURL
        let fileExtension = url.pathExtension.lowercased()
        let contentType = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType) ?? UTType(filenameExtension: fileExtension)
        let syntax = Self.syntax(for: url, contentType: contentType)
        let isPlainText = fileExtension.isEmpty || Self.plainTextExtensions.contains(fileExtension) || contentType?.conforms(to: .text) == true

        do {
            if let listingHTML = try Self.listingHTML(for: url, contentType: contentType) {
                let previewData = Data(listingHTML.utf8)
                let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 700)) { _ in previewData }
                reply.title = url.lastPathComponent
                handler(reply, nil)
                return
            }

            // Returning no reply lets Quick Look fall back to the system preview for formats we do not own.
            guard syntax != nil || isPlainText else {
                handler(nil, CocoaError(.fileReadUnsupportedScheme))
                return
            }

            let (data, truncated) = try Self.previewData(from: url, syntax: syntax)
            guard let text = try Self.text(from: data, syntax: syntax) else {
                handler(nil, CocoaError(.fileReadCorruptFile))
                return
            }

            let previewText = text + (truncated ? "\n\n... preview truncated ..." : "")
            let previewData: Data

            if syntax == .markdown {
                previewData = MarkdownRenderer.htmlData(from: previewText)
            } else if let syntax, previewText.utf8.count <= Self.config.maxHighlightedBytes {
                let highlightedText = Self.highlight(previewText, as: syntax)
                previewData = PreviewHTML.codeData(from: highlightedText)
            } else {
                previewData = PreviewHTML.plainTextData(from: previewText)
            }

            let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 900, height: 700)) { _ in previewData }
            reply.title = url.lastPathComponent
            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }

    static func listingHTML(for url: URL, contentType: UTType?) throws -> String? {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        if values?.isDirectory == true, values?.isPackage != true {
            do {
                return try directoryListingHTML(for: url)
            } catch {
                return listingHTML(title: url.lastPathComponent, items: [
                    ListedItem(name: "Unable to list contents: \(error.localizedDescription)", kind: "", size: "", iconDataURL: iconDataURL(for: nil, isDirectory: false))
                ])
            }
        }

        if url.pathExtension.lowercased() == "zip" || contentType?.conforms(to: .zip) == true {
            do {
                return try zipListingHTML(for: url)
            } catch {
                return listingHTML(title: url.lastPathComponent, items: [
                    ListedItem(name: "Unable to list archive: \(error.localizedDescription)", kind: "", size: "", iconDataURL: iconDataURL(for: nil, isDirectory: false))
                ])
            }
        }

        return nil
    }

    private static func directoryListingHTML(for url: URL) throws -> String {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.contentTypeKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsSubdirectoryDescendants]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }

        var entries: [URL] = []
        while let entry = enumerator.nextObject() as? URL {
            entries.append(entry)
            if entries.count > maxListedItems {
                break
            }
        }

        let items = entries
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .prefix(maxListedItems)
            .map { entry in
                let values = try? entry.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey, .isDirectoryKey])
                let isDirectory = values?.isDirectory == true
                return ListedItem(
                    name: entry.lastPathComponent,
                    kind: isDirectory ? "Folder" : values?.contentType?.localizedDescription ?? "File",
                    size: isDirectory ? "" : sizeText(values?.fileSize),
                    iconDataURL: iconDataURL(forFile: entry)
                )
            }

        return listingHTML(
            title: url.lastPathComponent,
            items: Array(items),
            moreItemsText: entries.count > maxListedItems ? "... more items ..." : nil
        )
    }

    private static func zipListingHTML(for url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let (items, totalCount) = try zipEntries(in: data)
        let omittedCount = totalCount - items.count
        return listingHTML(
            title: url.lastPathComponent,
            items: items,
            moreItemsText: omittedCount > 0 ? "... \(omittedCount) more items ..." : nil
        )
    }

    private static func listingHTML(title: String, items: [ListedItem], moreItemsText: String? = nil) -> String {
        let rows = items.isEmpty
            ? #"<tr><td class="name empty" colspan="3">Empty</td></tr>"#
            : items.map { item in
                """
                <tr>
                <td class="name"><img class="icon" src="\(item.iconDataURL)" alt=""><span>\(PreviewHTML.escape(item.name))</span></td>
                <td>\(PreviewHTML.escape(item.kind))</td>
                <td class="size">\(PreviewHTML.escape(item.size))</td>
                </tr>
                """
            }.joined(separator: "\n")
        let more = moreItemsText.map { #"<div class="more">\#(PreviewHTML.escape($0))</div>"# } ?? ""
        let body = """
        <header><h1>\(PreviewHTML.escape(title))</h1><div class="meta">\(items.count) item\(items.count == 1 ? "" : "s")</div></header>
        <table>
        <thead><tr><th class="name">Name</th><th>Kind</th><th class="size">Size</th></tr></thead>
        <tbody>
        \(rows)
        </tbody>
        </table>
        \(more)
        """
        return PreviewHTML.document(body: body, bodyClass: "qle-listing", style: """
        .qle-listing { font: 13px -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; }
        .qle-listing header { padding: 16px 20px 10px; border-bottom: 1px solid color-mix(in srgb, CanvasText 14%, transparent); }
        .qle-listing h1 { margin: 0; padding-right: 130px; font-size: 18px; font-weight: 600; letter-spacing: 0; }
        .qle-listing .meta { margin-top: 4px; color: color-mix(in srgb, CanvasText 58%, Canvas); font-size: 12px; }
        .qle-listing table { width: 100%; border-collapse: collapse; table-layout: fixed; }
        .qle-listing th, .qle-listing td { height: 32px; padding: 0 14px; border-bottom: 1px solid color-mix(in srgb, CanvasText 9%, transparent); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .qle-listing th { height: 28px; text-align: left; color: color-mix(in srgb, CanvasText 60%, Canvas); font-size: 11px; font-weight: 600; }
        .qle-listing th.name, .qle-listing td.name { width: 58%; padding-left: 20px; }
        .qle-listing th.size, .qle-listing td.size { width: 16%; text-align: right; padding-right: 20px; }
        .qle-listing .name span:last-child { vertical-align: middle; }
        .qle-listing .icon { width: 20px; height: 20px; margin-right: 8px; vertical-align: -5px; }
        .qle-listing .empty, .qle-listing .more { color: color-mix(in srgb, CanvasText 58%, Canvas); }
        .qle-listing .more { padding: 12px 20px; }
        """)
    }

    private static func zipEntries(in data: Data) throws -> ([ListedItem], Int) {
        guard let eocdOffset = zipEndOfCentralDirectoryOffset(in: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let totalCount = zipUInt16(in: data, at: eocdOffset + 10)
        let centralDirectoryOffset = Int(zipUInt32(in: data, at: eocdOffset + 16))
        guard totalCount < UInt16.max, centralDirectoryOffset < data.count else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }

        var offset = centralDirectoryOffset
        var items: [ListedItem] = []
        for _ in 0..<min(Int(totalCount), maxListedItems) {
            guard offset + 46 <= data.count, zipUInt32(in: data, at: offset) == 0x02014b50 else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let nameLength = Int(zipUInt16(in: data, at: offset + 28))
            let extraLength = Int(zipUInt16(in: data, at: offset + 30))
            let commentLength = Int(zipUInt16(in: data, at: offset + 32))
            let nameStart = offset + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= data.count else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let nameData = data[nameStart..<nameEnd]
            let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .isoLatin1) ?? "<unreadable name>"
            let isDirectory = name.hasSuffix("/")
            let type = isDirectory ? UTType.folder : UTType(filenameExtension: URL(fileURLWithPath: name).pathExtension)
            let size = Int64(zipUInt32(in: data, at: offset + 24))
            items.append(ListedItem(
                name: name,
                kind: isDirectory ? "Folder" : type?.localizedDescription ?? "File",
                size: isDirectory ? "" : sizeText(Int(size)),
                iconDataURL: iconDataURL(for: type, isDirectory: isDirectory)
            ))
            offset = nameEnd + extraLength + commentLength
        }

        return (items, Int(totalCount))
    }

    private static func sizeText(_ size: Int?) -> String {
        guard let size else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private static func iconDataURL(forFile url: URL) -> String {
        imageDataURL(NSWorkspace.shared.icon(forFile: url.path))
    }

    private static func iconDataURL(for type: UTType?, isDirectory: Bool) -> String {
        imageDataURL(NSWorkspace.shared.icon(for: isDirectory ? .folder : type ?? .data))
    }

    private static func imageDataURL(_ image: NSImage) -> String {
        var rect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            return ""
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            return ""
        }
        return "data:image/png;base64,\(data.base64EncodedString())"
    }

    private static func zipEndOfCentralDirectoryOffset(in data: Data) -> Int? {
        guard data.count >= 22 else {
            return nil
        }

        let start = max(0, data.count - 22 - 0xffff)
        var offset = data.count - 22
        while offset >= start {
            if zipUInt32(in: data, at: offset) == 0x06054b50 {
                return offset
            }
            offset -= 1
        }
        return nil
    }

    private static func zipUInt16(in data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func zipUInt32(in data: Data, at offset: Int) -> UInt32 {
        UInt32(zipUInt16(in: data, at: offset)) | UInt32(zipUInt16(in: data, at: offset + 2)) << 16
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

private struct ListedItem {
    let name: String
    let kind: String
    let size: String
    let iconDataURL: String
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
