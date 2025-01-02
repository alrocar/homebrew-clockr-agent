class TinyScreenMonitor < Formula
  desc "Monitor screen lock status and active applications on macOS"
  homepage "https://github.com/alrocar/homebrew-tiny-screen-monitor"
  url "https://github.com/alrocar/homebrew-tiny-screen-monitor/archive/refs/tags/0.0.0.dev41.tar.gz"
  sha256 "87cc9dd89181ccdfd8d8c445a4c1251a09beceaea2fe9655273dd130cdb0242f"
  license "MIT"

  depends_on "curl"

  def install
    bin.install "bin/tiny-screen-monitor.sh"
    
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

  def setup_permanent_script
    # Create directories with proper permissions
    system "mkdir", "-p", "#{var}/tiny-screen-monitor"
    system "chmod", "755", "#{var}/tiny-screen-monitor"
    
    # Create symlink with full path verification
    target_script = opt_bin/"tiny-screen-monitor.sh"
    target_link = "#{var}/tiny-screen-monitor/tiny-screen-monitor.sh"
    
    if File.exist?(target_script)
      system "ln", "-sf", target_script, target_link
    else
      odie "Script not found: #{target_script}"
    end
  end

  def post_install
    setup_permanent_script
    
    # Stop service
    system "brew", "services", "stop", name rescue nil
    sleep 1

    # Force cleanup of ALL versions except current
    system "rm", "-rf", *Dir["#{HOMEBREW_PREFIX}/Cellar/tiny-screen-monitor/*"].reject { |d| d.include?(version.to_s) } rescue nil
    system "brew", "cleanup", name rescue nil

    # Restart service
    system "brew", "services", "restart", name rescue nil
  end

  def post_upgrade
    setup_permanent_script
    
    # Stop service
    system "brew", "services", "stop", name rescue nil
    sleep 1
    
    # Force cleanup
    system "rm", "-rf", *Dir["#{HOMEBREW_PREFIX}/Cellar/tiny-screen-monitor/*"].reject { |d| d.include?(version.to_s) } rescue nil
    system "brew", "cleanup", name rescue nil

    # Restart service
    system "brew", "services", "restart", name rescue nil
  end

  service do
    name macos: "com.alrocar.tiny-screen-monitor"
    run ["sh", "-c", "exec #{HOMEBREW_PREFIX}/var/tiny-screen-monitor/tiny-screen-monitor.sh"]
    working_dir HOMEBREW_PREFIX
    keep_alive true
    process_type :background
    log_path "#{var}/log/tiny-screen-monitor/debug.log"
    error_log_path "#{var}/log/tiny-screen-monitor/error.log"
    environment_variables PATH: std_service_path_env
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
