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
}
