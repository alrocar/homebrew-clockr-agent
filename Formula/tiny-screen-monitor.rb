class TinyScreenMonitor < Formula
  desc "Monitor screen lock status and active applications on macOS"
  homepage "https://github.com/alrocar/homebrew-tiny-screen-monitor"
  url "https://github.com/alrocar/homebrew-tiny-screen-monitor/archive/refs/tags/0.0.0.dev20.tar.gz"
  sha256 "f3430d402336da761fbc8ef27f0a75fc87a8af16abcf53223c857f3a87e2bb23"
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

  service do
    name macos: "com.alrocar.tiny-screen-monitor"
    run opt_bin/"tiny-screen-monitor"
    working_dir HOMEBREW_PREFIX
    keep_alive true
    log_path var/"log/tiny-screen-monitor/output.log"
    error_log_path var/"log/tiny-screen-monitor/error.log"
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

  def post_install
    system "pkill", "-f", "tiny-screen-monitor" rescue nil
  end

  test do
    system "#{bin}/tiny-screen-monitor", "--version"
  end
end
