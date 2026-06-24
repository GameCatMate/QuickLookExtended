import AppKit
import Foundation

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
        let terraform = TerraformHighlighter.attributed("resource \"null_resource\" \"demo\" {\n  count = 1 # demo\n}\n")
        assert(terraform.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == .systemBlue)
        assert(terraform.attribute(.foregroundColor, at: 9, effectiveRange: nil) as? NSColor == .systemGreen)
        assert(TextSniffer.text(from: Data("ssh -L 6443:127.0.0.1:6443\n".utf8)) != nil)
        assert(TextSniffer.text(from: Data([0x00, 0x01, 0x02, 0x03])) == nil)
    }
}
