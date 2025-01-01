import Cocoa

@objc(TinyScreenMonitorApp)
class AppDelegate: NSObject, NSApplicationDelegate {
    let task = Process()
    let bundleIdentifier = "com.alrocar.tiny-screen-monitor"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Log app info
        NSLog("Starting TinyScreenMonitor with identifier: \(bundleIdentifier)")
        
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/tiny-screen-monitor.sh")
        try? task.run()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        task.terminate()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 