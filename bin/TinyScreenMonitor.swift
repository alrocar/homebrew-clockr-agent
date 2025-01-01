import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    let task = Process()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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