import AppKit
import Foundation

@main
struct HighlightCheck {
    static func main() {
        checkMarkdownTables()
        let sample = """
        name: "demo"
        enabled: true
        ports:
          - 8080 # public
        """

        let attributed = YAMLHighlighter.attributed(sample, highlighted: true)
        assert(attributed.string == sample)
        assert(attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == .systemBlue)
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
