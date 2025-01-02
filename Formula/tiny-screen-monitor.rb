class TinyScreenMonitor < Formula
  desc "Monitor screen lock status and active applications on macOS"
  homepage "https://github.com/alrocar/homebrew-tiny-screen-monitor"
  url "https://github.com/alrocar/homebrew-tiny-screen-monitor/archive/refs/tags/0.0.0.dev22.tar.gz"
  sha256 "3af999fc4e659d1e3179d31989c6fa41e4a5a415c74e23e40ad41883907acc38"
  license "MIT"

  depends_on "curl"

  def install
    bin.install "bin/tiny-screen-monitor.sh" => "tiny-screen-monitor"
    rm_rf "#{opt_prefix}/bin/tiny-screen-monitor"
    
    # Compile and install the app wrapper
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

  service do
    name macos: "com.alrocar.tiny-screen-monitor"
    run opt_bin/"tiny-screen-monitor"
    working_dir HOMEBREW_PREFIX
    keep_alive true
    log_path var/"log/tiny-screen-monitor/output.log"
    error_log_path var/"log/tiny-screen-monitor/error.log"
    environment_variables PATH: std_service_path_env
    run_type :immediate
    process_type :background
  end

  def caveats
    <<~EOS
      To use tiny-screen-monitor, you need to:
      
      1. Grant Accessibility permissions in System Settings:
         System Settings → Privacy & Security → Accessibility
         
      2. Add and enable BOTH:
         - /opt/homebrew/bin/tiny-screen-monitor
         - /opt/homebrew/opt/tiny-screen-monitor/bin/tiny-screen-monitor
         
      3. Restart the service after granting permissions:
         brew services restart tiny-screen-monitor
    EOS
  end

  def post_uninstall
    # Remove logs directory
    rm_r var/"log/tiny-screen-monitor"

    # Optionally remove config file (uncomment if desired)
    rm Pathname.new(Dir.home)/"tiny-screen-monitor.cfg"
  end

  def post_install
    # More aggressive process cleanup
    system "pkill", "-f", "tiny-screen-monitor" rescue nil
    system "pkill", "-f", "tiny-screen-monitor.sh" rescue nil
    sleep 2  # Give processes time to terminate
    
    # Clean up any lingering lock files
    system "rm", "-f", "/tmp/tiny-screen-monitor.lock" rescue nil
  end

  test do
    system "#{bin}/tiny-screen-monitor", "--version"
  end
end
