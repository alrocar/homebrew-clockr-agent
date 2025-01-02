class TinyScreenMonitor < Formula
  desc "Monitor screen lock status and active applications on macOS"
  homepage "https://github.com/alrocar/homebrew-tiny-screen-monitor"
  url "https://github.com/alrocar/homebrew-tiny-screen-monitor/archive/refs/tags/0.0.0.dev54.tar.gz"
  sha256 "b72509dfbfb6ba5c3fa1c432ed5400826d240273be8d38c6103cb47d75ca2012"
  license "MIT"

  depends_on "curl"

  def install
    bin.install "bin/tiny-screen-monitor.sh"

    system "swiftc", 
           "-framework", "Cocoa",
           "-o", bin/"tiny-screen-monitor",
           "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
           "-module-name", "TinyScreenMonitor",
           "bin/TinyScreenMonitor.swift" \
    or raise "Swift compilation failed"
    
    chmod 0755, bin/"tiny-screen-monitor"
    
    bin.install "bin/check_display.sh"
    
    # Install config template
    prefix.install "bin/tiny-screen-monitor.cfg.template"

    # Create logs directory with write permissions
    (var/"log/tiny-screen-monitor").mkpath
    chmod 0755, var/"log/tiny-screen-monitor"
  end

  def setup_permanent_script
    # Ensure log directory exists with proper permissions
    system "sudo", "mkdir", "-p", "#{var}/log/tiny-screen-monitor"
    system "sudo", "chown", ENV["USER"], "#{var}/log/tiny-screen-monitor"
    system "sudo", "chmod", "755", "#{var}/log/tiny-screen-monitor"
  end

  def cleanup_processes
    # Stop the service first
    system "brew", "services", "stop", name rescue nil
    sleep 1
    
    # Kill any remaining shell script processes
    system "pkill", "-f", "tiny-screen-monitor.sh" rescue nil
    sleep 1
  end

  def post_install
    setup_permanent_script
    
    # Stop service
    system "brew", "services", "stop", name rescue nil
    sleep 1
    cleanup_processes

    # Force cleanup of ALL versions except current
    system "rm", "-rf", *Dir["#{HOMEBREW_PREFIX}/Cellar/tiny-screen-monitor/*"].reject { |d| d.include?(version.to_s) } rescue nil
    system "brew", "cleanup", name rescue nil

    # Ensure service directory exists
    system "mkdir", "-p", "#{ENV["HOME"]}/Library/LaunchAgents"
    
    # Start service
    system "brew", "services", "start", name rescue nil
  end

  def post_upgrade
    setup_permanent_script
    
    # Stop service
    system "brew", "services", "stop", name rescue nil
    sleep 1
    cleanup_processes
    
    # Force cleanup
    system "rm", "-rf", *Dir["#{HOMEBREW_PREFIX}/Cellar/tiny-screen-monitor/*"].reject { |d| d.include?(version.to_s) } rescue nil
    system "brew", "cleanup", name rescue nil

    # Ensure service directory exists
    system "mkdir", "-p", "#{ENV["HOME"]}/Library/LaunchAgents"
    
    # Start service (don't use restart as it might fail)
    system "brew", "services", "start", name rescue nil
  end

  service do
    name macos: "tiny-screen-monitor"
    run opt_bin/"tiny-screen-monitor"
    working_dir HOMEBREW_PREFIX
    keep_alive true
    process_type :background
    log_path "#{var}/log/tiny-screen-monitor/debug.log"
    error_log_path "#{var}/log/tiny-screen-monitor/error.log"
    environment_variables PATH: std_service_path_env
  end

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <true/>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/tiny-screen-monitor</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>WorkingDirectory</key>
        <string>#{HOMEBREW_PREFIX}</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/tiny-screen-monitor/debug.log</string>
        <key>StandardErrorPath</key>
        <string>#{var}/log/tiny-screen-monitor/error.log</string>
        <key>EnvironmentVariables</key>
        <dict>
          <key>PATH</key>
          <string>#{HOMEBREW_PREFIX}/bin:#{HOMEBREW_PREFIX}/sbin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        </dict>
      </dict>
      </plist>
    EOS
  end

  def caveats
    <<~EOS
      To complete the installation:

      1. Edit your configuration file:
         $EDITOR #{etc}/tiny-screen-monitor/tiny-screen-monitor.cfg

      2. Ensure you have granted necessary permissions:
         - Accessibility access for monitoring active applications
         - Screen Recording permission for capturing browser URLs

      3. Start the service:
         brew services start tiny-screen-monitor

      Or to start manually:
         tiny-screen-monitor
    EOS
  end

  def post_uninstall
    # Remove logs directory
    rm_r var/"log/tiny-screen-monitor"

    # Optionally remove config file (uncomment if desired)
    rm Pathname.new(Dir.home)/"tiny-screen-monitor.cfg"
  end

  test do
    system "#{bin}/tiny-screen-monitor", "--version"
  end
end
