import Cocoa
import Foundation
import SQLite3

@objc(ClockrAgentApp)
class AppDelegate: NSObject, NSApplicationDelegate {
    let task = Process()
    let bundleIdentifier = "com.alrocar.clockr-agent"
    var statusItem: NSStatusItem?
    var timer: Timer?
    var lastStatus: String?
    var statusStartTime: Date?
    var todayActiveTime: TimeInterval = 0
    var isCheckingStatus = false
    var currentVersion: String? {
        // Read current version from installed formula
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "readlink /opt/homebrew/opt/clockr-agent"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let version = path.split(separator: "/").last {
                return "0.0.0.dev\(version)"
            }
        } catch {
            NSLog("Failed to get current version: \(error)")
        }
        return nil
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create .clockr directory if it doesn't exist
        try? FileManager.default.createDirectory(
            atPath: "\(NSHomeDirectory())/.clockr",
            withIntermediateDirectories: true
        )
        
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Load custom icon
            let iconPath = "/opt/homebrew/share/clockr-agent/icons/clockr-icon.png"
            if let image = NSImage(contentsOfFile: iconPath) {
                image.isTemplate = true  // Make it work with dark/light modes
                button.image = image
                button.imagePosition = .imageLeft
                updateStats()  // Initial update
                
                // Set up timer to update stats every second
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.updateStats()
                }
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
            kill(-pid, SIGTERM)
            NSLog("Killing process group \(-pid)")
            Thread.sleep(forTimeInterval: 0.5)
            kill(-pid, SIGKILL)
            
            NSApplication.shared.terminate(nil)
        }
        
        try? task.run()
        
        // Check for updates periodically
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
        
        // Initial update check
        checkForUpdates()
    }
    
    func cleanupAndQuit() {
        NSLog("Cleaning up and quitting...")
        
        // Stop the stats update timer
        timer?.invalidate()
        timer = nil
        
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
    
    @objc func quit() {
        cleanupAndQuit()
        exit(0)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NSLog("Application terminating through willTerminate...")
        cleanupAndQuit()
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
    
    func updateStats() {
        // Prevent overlapping calls
        guard !isCheckingStatus else { return }
        isCheckingStatus = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let statsTask = Process()
            statsTask.executableURL = URL(fileURLWithPath: "/bin/bash")
            statsTask.arguments = ["-c", "source /opt/homebrew/bin/clockr-check-display.sh && check_display_status"]
            
            let pipe = Pipe()
            statsTask.standardOutput = pipe
            
            do {
                try statsTask.run()
                statsTask.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let status = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    DispatchQueue.main.async {
                        self?.updateDisplay(with: status)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusItem?.button?.title = " --:--:--"
                    NSLog("Failed to get stats: \(error)")
                }
            }
            
            self?.isCheckingStatus = false
        }
    }
    
    private func updateDisplay(with status: String) {
        let now = Date()
        let trimmedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)
        
        NSLog("Raw status received: '%@'", trimmedStatus)  // Debug log
        
        // Status codes:
        // 0 = unlocked/active
        // 1 = locked
        // 2 = idle
        if trimmedStatus.contains("UNLOCKED") || trimmedStatus.contains("IDLE") {  // Active
            if let lastStart = statusStartTime {
                todayActiveTime += now.timeIntervalSince(lastStart)
            }
            statusStartTime = now
        } else {  // Locked
            statusStartTime = nil
        }
        
        lastStatus = trimmedStatus
        
        // Update display with hours, minutes, and seconds
        let hours = Int(todayActiveTime) / 3600
        let minutes = Int(todayActiveTime) % 3600 / 60
        let seconds = Int(todayActiveTime) % 60
        
        NSLog("Status code: %@ (0=active, 1=locked, 2=idle) Time: %02d:%02d:%02d", 
              trimmedStatus, hours, minutes, seconds)
        
        statusItem?.button?.title = String(format: " %02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func checkForUpdates() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        task.arguments = ["info", "clockr-agent"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Extract version from brew output
                if let latestVersion = extractVersion(from: output),
                   isNewerVersion(latest: latestVersion, current: currentVersion) {
                    DispatchQueue.main.async {
                        self.showUpdateAlert(newVersion: latestVersion)
                    }
                }
            }
        } catch {
            NSLog("Failed to check for updates: \(error)")
        }
    }
    
    private func extractVersion(from output: String) -> String? {
        // Example brew output patterns:
        // "stable 113" -> "0.0.0.dev113"
        // "stable 0.0.1" -> "0.0.1"
        // "stable 0.0.1.dev1" -> "0.0.1.dev1"
        let pattern = "stable ([0-9]+(?:\\.[0-9]+)*(?:\\.dev[0-9]+)?)"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        
        if let match = regex?.firstMatch(in: output, range: range),
           let versionRange = Range(match.range(at: 1), in: output) {
            let version = String(output[versionRange])
            // If it's just a number, convert to dev format
            if Int(version) != nil {
                return "0.0.0.dev\(version)"
            }
            return version
        }
        return nil
    }
    
    private func isNewerVersion(latest: String?, current: String?) -> Bool {
        guard let latest = latest, let current = current else { return false }
        
        // Split versions into components
        let latestParts = latest.split(separator: ".")
        let currentParts = current.split(separator: ".")
        
        // Handle dev versions
        if latest.contains("dev") && current.contains("dev") {
            if let latestDev = Int(latestParts.last?.dropFirst(3) ?? ""),
               let currentDev = Int(currentParts.last?.dropFirst(3) ?? "") {
                return latestDev > currentDev
            }
        }
        
        // Handle semantic versions
        let latestNums = latestParts.compactMap { $0.contains("dev") ? nil : Int($0) }
        let currentNums = currentParts.compactMap { $0.contains("dev") ? nil : Int($0) }
        
        // Compare version numbers
        for i in 0..<min(latestNums.count, currentNums.count) {
            if latestNums[i] > currentNums[i] {
                return true
            }
            if latestNums[i] < currentNums[i] {
                return false
            }
        }
        
        return latestNums.count > currentNums.count
    }
    
    private func showUpdateAlert(newVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "A new version (\(newVersion)) of Clockr is available. Would you like to update now?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            performUpdate()
        }
    }
    
    private func performUpdate() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        task.arguments = ["upgrade", "clockr-agent"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let restartAlert = NSAlert()
                restartAlert.messageText = "Update Complete"
                restartAlert.informativeText = "The update has been installed. Please restart Clockr to apply the changes."
                restartAlert.alertStyle = .informational
                restartAlert.addButton(withTitle: "Restart Now")
                restartAlert.addButton(withTitle: "Later")
                
                if restartAlert.runModal() == .alertFirstButtonReturn {
                    restart()
                }
            }
        } catch {
            NSLog("Failed to perform update: \(error)")
        }
    }
    
    private func restart() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "brew services restart clockr-agent"]
        try? task.run()
        NSApplication.shared.terminate(nil)
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // About menu item
        menu.addItem(NSMenuItem(title: "About Clockr", action: #selector(showAbout), keyEquivalent: ""))
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Quit menu item
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Clockr"
        
        let version = currentVersion ?? "Unknown version"
        alert.informativeText = """
            Screen time tracking for macOS
            
            Version: \(version)
            Author: alrocar
            Website: https://clockr.xyz
            Open Source: https://github.com/alrocar/homebrew-clockr-agent
            
            © 2024 alrocar
            """
            
        alert.alertStyle = .informational
        
        // Add an "OK" button
        alert.addButton(withTitle: "OK")
        
        // Add a "Visit Repository" button
        alert.addButton(withTitle: "Support")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // Open GitHub repository in default browser
            if let url = URL(string: "https://github.com/alrocar/homebrew-clockr-agent/issues/new") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 