import Cocoa
import Foundation

@objc(ClockrAgentApp)
class AppDelegate: NSObject, NSApplicationDelegate {
    let task = Process()
    let bundleIdentifier = "com.alrocar.clockr-agent"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request permissions upfront
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
        
        // Log app info
        NSLog("Starting ClockrAgent with identifier: \(bundleIdentifier)")
        
        // Set up signal handling
        signal(SIGTERM) { signal in
            NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)
            exit(0)
        }
        
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "exec /opt/homebrew/bin/clockr-agent.sh"]
        
        // Create a new process group
        task.qualityOfService = .userInitiated
        task.standardOutput = FileHandle.standardOutput
        task.standardError = FileHandle.standardError
        
        // Set up task termination handling
        task.terminationHandler = { task in
            NSLog("Shell script terminated with status: \(task.terminationStatus)")
            
            // Kill entire process group
            let pid = self.task.processIdentifier
            NSLog("Killing process group \(-pid)")
            kill(-pid, SIGTERM)
            Thread.sleep(forTimeInterval: 0.5)
            kill(-pid, SIGKILL)
            
            NSApplication.shared.terminate(nil)
        }
        
        try? task.run()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NSLog("Application terminating, cleaning up...")
        
        // Kill the entire process group
        let pid = task.processIdentifier
        NSLog("Killing process group \(-pid)")
        kill(-pid, SIGTERM)
        Thread.sleep(forTimeInterval: 0.5)
        kill(-pid, SIGKILL)
        
        // Terminate the main task
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