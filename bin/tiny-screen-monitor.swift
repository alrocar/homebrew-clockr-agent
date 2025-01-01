#!/usr/bin/swift

import Foundation

let process = Process()
process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/tiny-screen-monitor.sh")
try process.run()
process.waitUntilExit() 