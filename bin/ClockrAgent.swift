import Cocoa
import Foundation

@objc(ClockrAgentApp)
class AppDelegate: NSObject, NSApplicationDelegate {
    let task = Process()
    let bundleIdentifier = "com.alrocar.clockr-agent"
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Load custom icon
            let iconPath = "/opt/homebrew/share/clockr-agent/icons/clockr-icon.png"
            if let image = NSImage(contentsOfFile: iconPath) {
                image.isTemplate = true  // Make it work with dark/light modes
                button.image = image
            } else {
                // Fallback to system icon
                button.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Clockr")
            }
        }
        
        // Create the menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Clockr: Running", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Authenticate", action: #selector(authenticate), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Visit clockr.xyz", action: #selector(openWebsite), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        // Request permissions upfront
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
        
        // Log app info
        NSLog("Starting ClockrAgent with identifier: \(bundleIdentifier)")
        
        // Set up signal handling for SIGTERM
        signal(SIGTERM) { signal in
            NSLog("Received SIGTERM signal")
            
            // Find and kill all clockr-agent.sh processes
            let findProcess = Process()
            findProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            findProcess.arguments = ["-f", "clockr-agent.sh"]
            
            let pipe = Pipe()
            findProcess.standardOutput = pipe
            
            try? findProcess.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let pids = String(data: data, encoding: .utf8) {
                NSLog("Found PIDs to kill: \(pids)")
                for pid in pids.split(separator: "\n") {
                    if let pidNum = Int32(pid) {
                        NSLog("Killing process \(pidNum)")
                        kill(pidNum, SIGTERM)
                        Thread.sleep(forTimeInterval: 0.5)
                        kill(pidNum, SIGKILL)
                    }
                }
            }
            
            NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)
            exit(0)
        }
        
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/clockr-agent.sh")
        task.arguments = []
        
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
    
    @objc func quit() {
        NSLog("Quitting application...")
        // First try graceful termination
        task.terminate()
        
        // Give it a moment
        Thread.sleep(forTimeInterval: 1.0)
        
        // Find and kill all clockr-agent.sh processes
        let findProcess = Process()
        findProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        findProcess.arguments = ["-f", "clockr-agent.sh"]
        
        let pipe = Pipe()
        findProcess.standardOutput = pipe
        
        try? findProcess.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let pids = String(data: data, encoding: .utf8) {
            for pid in pids.split(separator: "\n") {
                if let pidNum = Int32(pid) {
                    NSLog("Killing process \(pidNum)")
                    kill(pidNum, SIGTERM)
                    Thread.sleep(forTimeInterval: 0.5)
                    kill(pidNum, SIGKILL)
                }
            }
        }
        
        NSApplication.shared.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NSLog("Application terminating through willTerminate...")
        NSLog("Application terminating, cleaning up...")
        
        // First try graceful termination
        task.terminate()
        
        // Give it a moment
        Thread.sleep(forTimeInterval: 1.0)
        
        // Find and kill all clockr-agent.sh processes
        let findProcess = Process()
        findProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        findProcess.arguments = ["-f", "clockr-agent.sh"]
        
        let pipe = Pipe()
        findProcess.standardOutput = pipe
        
        try? findProcess.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let pids = String(data: data, encoding: .utf8) {
            for pid in pids.split(separator: "\n") {
                if let pidNum = Int32(pid) {
                    NSLog("Killing process \(pidNum)")
                    kill(pidNum, SIGTERM)
                    Thread.sleep(forTimeInterval: 0.5)
                    kill(pidNum, SIGKILL)
                }
            }
        }
        
        findProcess.waitUntilExit()
        Thread.sleep(forTimeInterval: 1.0)
    }
    
    @objc func openWebsite() {
        if let url = URL(string: "https://clockr.xyz") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func authenticate() {
        let authTask = Process()
        authTask.executableURL = URL(fileURLWithPath: "/bin/bash")
        authTask.arguments = ["-c", "source /opt/homebrew/bin/clockr-auth.sh && authenticate_agent"]
        
        // Capture output for error handling
        let pipe = Pipe()
        authTask.standardOutput = pipe
        authTask.standardError = pipe
        
        do {
            try authTask.run()
            authTask.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                NSLog("Auth script output: \(output)")
            }
            
            if authTask.terminationStatus == 0 {
                // Optionally restart the main task after successful auth
                task.terminate()
                try? task.run()
            }
        } catch {
            NSLog("Failed to run auth script: \(error)")
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 