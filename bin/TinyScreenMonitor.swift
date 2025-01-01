import Cocoa

// Add bundle identifier
@objc(TinyScreenMonitorApp)
class AppDelegate: NSObject, NSApplicationDelegate {
    let task = Process()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set bundle identifier
        if let bundle = Bundle.main.bundleIdentifier {
            log("Using bundle identifier: \(bundle)")
        } else {
            Bundle.main.bundleIdentifier = "com.alrocar.tiny-screen-monitor"
        }
        
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/tiny-screen-monitor.sh")
        try? task.run()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        task.terminate()
    }
}

// Main entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 