import Cocoa

@objc(TinyScreenMonitorApp)
class AppDelegate: NSObject, NSApplicationDelegate {
    let task = Process()
    let bundleIdentifier = "com.alrocar.tiny-screen-monitor"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request permissions upfront
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
        
        // Log app info
        NSLog("Starting TinyScreenMonitor with identifier: \(bundleIdentifier)")
        
        // Set up signal handling
        signal(SIGTERM) { signal in
            NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)
            exit(0)
        }
        
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/tiny-screen-monitor.sh")
        
        // Set up task termination handling
        task.terminationHandler = { task in
            NSLog("Shell script terminated with status: \(task.terminationStatus)")
            NSApplication.shared.terminate(nil)
        }
        
        try? task.run()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NSLog("Application terminating, cleaning up...")
        
        // Send SIGTERM to the shell script
        task.terminate()
        
        // Wait briefly for cleanup
        Thread.sleep(forTimeInterval: 1.0)
        
        // Force kill if still running
        if task.isRunning {
            task.interrupt()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 