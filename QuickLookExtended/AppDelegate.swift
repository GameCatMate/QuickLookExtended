import CoreServices
import Darwin
import Foundation

@main
enum QuickLookExtendedLauncher {
    static func main() {
        let bundlePath = Bundle.main.bundlePath
        DispatchQueue.global(qos: .utility).async {
            let bundleURL = URL(fileURLWithPath: bundlePath) as CFURL
            _ = LSRegisterURL(bundleURL, false)
        }
        // ponytail: LSRegisterURL can hang; give PlugInKit a moment, then leave.
        sleep(1)
        exit(0)
    }
}
