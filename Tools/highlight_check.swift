import AppKit
import Foundation
import UniformTypeIdentifiers

@main
struct HighlightCheck {
    static func main() {
        let sample = """
        name: "demo"
        enabled: true
        ports:
          - 8080 # public
        """

        let attributed = YAMLHighlighter.attributed(sample, highlighted: true)
        assert(attributed.string == sample)
        assert(attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == .systemBlue)
        let highlightedHTML = String(data: PreviewHTML.codeData(from: attributed), encoding: .utf8) ?? ""
        assert(highlightedHTML.contains("qle-zoom-value"), highlightedHTML)
        assert(highlightedHTML.contains("qle-wrap-toggle"), highlightedHTML)
        assert(highlightedHTML.contains("qle-wrap-icon"), highlightedHTML)
        assert(highlightedHTML.contains("qle-wrap-prompt"), highlightedHTML)
        assert(highlightedHTML.contains("qle-nowrap"), highlightedHTML)
        assert(!highlightedHTML.contains(">Wrap<"), highlightedHTML)
        assert(!highlightedHTML.contains("qle-wrap-prompt\">&gt;</span>"), highlightedHTML)
        assert(highlightedHTML.contains("gesturechange"), highlightedHTML)
        assert(highlightedHTML.contains("<pre class=\"qle-code\">"), highlightedHTML)
        assert(highlightedHTML.contains("color: rgb(0, 122, 255)"), highlightedHTML)
        assert(highlightedHTML.contains("name:"), highlightedHTML)
        let plainHTML = String(data: PreviewHTML.plainTextData(from: "plain <text>"), encoding: .utf8) ?? ""
        assert(plainHTML.contains("plain &lt;text&gt;"), plainHTML)
        let markdownHTML = String(data: MarkdownRenderer.htmlData(from: "# Title"), encoding: .utf8) ?? ""
        assert(markdownHTML.contains("qle-zoom-value"), markdownHTML)
        assert(markdownHTML.contains("<h1>Title</h1>"), markdownHTML)
        checkMarkdownTables()
        let terraform = TerraformHighlighter.attributed("resource \"null_resource\" \"demo\" {\n  count = 1 # demo\n}\n")
        assert(terraform.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == .systemBlue)
        assert(terraform.attribute(.foregroundColor, at: 9, effectiveRange: nil) as? NSColor == .systemGreen)
        let tfstate = JSONHighlighter.attributed("{\n  \"version\": 4,\n  \"terraform_version\": \"1.8.0\"\n}\n")
        assert(tfstate.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor == .systemBlue)
        assert(tfstate.attribute(.foregroundColor, at: 15, effectiveRange: nil) as? NSColor == .systemOrange)
        let plist = XMLHighlighter.attributed("<plist><dict><key>Name</key><string>Demo</string><integer>42</integer><true/></dict></plist>\n")
        let plistKeyRange = (plist.string as NSString).range(of: "Name")
        assert(plist.attribute(.foregroundColor, at: plistKeyRange.location, effectiveRange: nil) as? NSColor == .systemBlue)
        let plistStringRange = (plist.string as NSString).range(of: "Demo")
        assert(plist.attribute(.foregroundColor, at: plistStringRange.location, effectiveRange: nil) as? NSColor == .systemGreen)
        let plistNumberRange = (plist.string as NSString).range(of: "42")
        assert(plist.attribute(.foregroundColor, at: plistNumberRange.location, effectiveRange: nil) as? NSColor == .systemOrange)
        let config = ConfigHighlighter.attributed("enabled=true # demo\n")
        assert(config.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == .systemBlue)
        assert(config.attribute(.foregroundColor, at: 8, effectiveRange: nil) as? NSColor == .systemPurple)
        let go = CodeHighlighter.attributed("package main\nfunc main() {\n  println(\"demo\", 42) // ok\n}\n")
        assert(go.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == .systemBlue)
        assert(go.attribute(.foregroundColor, at: 13, effectiveRange: nil) as? NSColor == .systemBlue)
        let stringRange = (go.string as NSString).range(of: "\"demo\"")
        assert(go.attribute(.foregroundColor, at: stringRange.location, effectiveRange: nil) as? NSColor == .systemGreen)
        assert(TextSniffer.isProbablyText(Data("plain text\n".utf8)))
        assert(!TextSniffer.isProbablyText(Data([0x00, 0x01, 0x02, 0x03])))
        assert(TextSniffer.text(from: Data("ssh -L 6443:127.0.0.1:6443\n".utf8)) != nil)
        assert(TextSniffer.text(from: Data([0x00, 0x01, 0x02, 0x03])) == nil)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let folderURL = tempURL.appendingPathComponent("folder", isDirectory: true)
        let nestedURL = folderURL.appendingPathComponent("nested", isDirectory: true)
        let zipSourceURL = tempURL.appendingPathComponent("zip-source", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try! FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true)
        try! Data().write(to: folderURL.appendingPathComponent("beta.txt"))
        let folderListing = try! PreviewProvider.listingHTML(for: folderURL, contentType: nil)
        assert(folderListing?.contains("<table>") == true, folderListing ?? "nil")
        assert(folderListing?.contains("qle-zoom-value") == true, folderListing ?? "nil")
        assert(folderListing?.contains("beta.txt") == true, folderListing ?? "nil")
        assert(folderListing?.contains("nested") == true, folderListing ?? "nil")

        try! FileManager.default.createDirectory(at: zipSourceURL.appendingPathComponent("dir", isDirectory: true), withIntermediateDirectories: true)
        try! Data().write(to: zipSourceURL.appendingPathComponent("a.txt"))
        try! Data().write(to: zipSourceURL.appendingPathComponent("dir/b.txt"))
        let zipURL = tempURL.appendingPathComponent("sample.zip")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = zipSourceURL
        zip.arguments = ["-r", zipURL.path, "a.txt", "dir"]
        zip.standardOutput = Pipe()
        zip.standardError = Pipe()
        try! zip.run()
        zip.waitUntilExit()
        assert(zip.terminationStatus == 0)
        let zipListing = try! PreviewProvider.listingHTML(for: zipURL, contentType: .zip)
        assert(zipListing?.contains("a.txt") == true, zipListing ?? "nil")
        assert(zipListing?.contains("dir/") == true, zipListing ?? "nil")
        assert(zipListing?.contains("dir/b.txt") == true, zipListing ?? "nil")
    }

    private static func checkMarkdownTables() {
        let sample = """
        ## 1. Подготовьте платформу

        Чарт создаёт приложения, но **не устанавливает** Kubernetes.

        | Что должно быть готово | Когда требуется |
        |---|---|
        | Минимум 3 worker-ноды, запас CPU/RAM и диска | Стандартный HA-профиль: обязательная anti-affinity разводит реплики |
        | CSI StorageClass с RWO и `reclaimPolicy: Retain` | Каждая встроенная БД |
        | Snapshot Controller, CSI snapshots и VolumeSnapshotClass | При `postgresql.cnpg.backup.enabled: true` |
        | CloudNativePG / Altinity / Redis Operator | Только для БД с `enabled: true` |
        | Gateway API CRD **либо** Ingress Controller/Class | Для выбранного способа публикации |
        | cert-manager с CRD, webhook и cainjector | При включённых APM-операторе или metadata injection |
        | DNS-имена Grafana/Collector, TLS-цепочка и ключ | Для приложений |
        | Helm и kubectl с необходимыми правами | Для всех установок |

        Следующий абзац.
        """
        for source in [sample, sample.replacingOccurrences(of: "\n", with: "\r\n")] {
            let html = String(decoding: MarkdownRenderer.htmlData(from: source), as: UTF8.self)
            assert(html.contains("<thead><tr><th scope=\"col\" style=\"text-align: left\">Что должно быть готово</th>"), html)
            assert(html.components(separatedBy: "<tr>").count - 1 == 9, html)
            assert(html.contains("<code>reclaimPolicy: Retain</code>"), html)
            assert(html.contains("<strong>либо</strong>"), html)
            assert(html.contains("</tbody></table>\n<p>Следующий абзац.</p>"), html)
        }

        let edgeCases = #"""
        Left | Center | Right
        :--- | :---: | ---:
        a\|b | `c\|d` | <script>
        short | row
        a | b | c | ignored
        # Heading | outside

        | Single |
        | --- |
        | |
        """#
        let html = String(decoding: MarkdownRenderer.htmlData(from: edgeCases), as: UTF8.self)
        assert(html.contains("text-align: center\">Center</th>"), html)
        assert(html.contains("text-align: right\">Right</th>"), html)
        assert(html.contains("text-align: left\">a|b</td>"), html)
        assert(html.contains("<code>c|d</code>"), html)
        assert(html.contains("&lt;script&gt;</td>"), html)
        assert(html.contains("text-align: right\"></td></tr>"), html)
        assert(!html.contains("ignored"), html)
        assert(html.contains("</tbody></table>\n<h1>Heading | outside</h1>"), html)
        assert(html.contains("<td style=\"text-align: left\"></td></tr>"), html)

        for source in ["a | b\nnot | a separator", "a | b\n--- | --- | ---", "```\na | b\n--- | ---\nx | y\n```"] {
            let html = String(decoding: MarkdownRenderer.htmlData(from: source), as: UTF8.self)
            assert(!html.contains("<table>"), html)
        }
    }
}
