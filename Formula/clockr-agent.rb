class ClockrAgent < Formula
  desc "Monitor screen lock status and active applications on macOS"
  homepage "https://github.com/alrocar/homebrew-clockr-agent"
  url "https://github.com/alrocar/homebrew-clockr-agent/archive/refs/tags/0.0.0.dev76.tar.gz"
  sha256 "8ad680aed73a9a038fee58a1e1bd90aac8083023008034e2255bef38097ee973"
  license "MIT"

  depends_on "curl"

  def install
    # First, create all necessary directories
    bin.mkpath
    (etc/"clockr-agent").mkpath
    (var/"log/clockr-agent").mkpath
    
    # Install binaries and scripts
    bin.install "bin/clockr-agent.sh"
    bin.install "bin/clockr-check-display.sh"
    bin.install "bin/clockr-auth.sh"
    bin.install "bin/clockr-agent.cfg.template"

    # Compile Swift
    system "swiftc", 
           "-framework", "Cocoa",
           "-o", bin/"clockr-agent",
           "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
           "-module-name", "ClockrAgent",
           "bin/ClockrAgent.swift" \
    or raise "Swift compilation failed"
    
    chmod 0755, bin/"clockr-agent"
    
    # Copy config template if it doesn't exist
    unless (etc/"clockr-agent/clockr-agent.cfg").exist?
      cp bin/"clockr-agent.cfg.template", etc/"clockr-agent/clockr-agent.cfg"
    end

    chmod 0755, var/"log/clockr-agent"
  end

  def setup_permanent_script
    # Ensure log directory exists with proper permissions
    system "sudo", "mkdir", "-p", "#{var}/log/clockr-agent"
    system "sudo", "chown", ENV["USER"], "#{var}/log/clockr-agent"
    system "sudo", "chmod", "755", "#{var}/log/clockr-agent"
  end

  def cleanup_processes
    # First try pkill
    system "pkill", "-f", "clockr-agent" rescue nil
    system "pkill", "-f", "clockr-agent.sh" rescue nil
    
    # Then try killall (more common on macOS)
    system "killall", "clockr-agent" rescue nil
    system "killall", "clockr-agent.sh" rescue nil
    
    # As a last resort, find PIDs and kill them directly
    system %Q(ps aux | grep "[c]lockr-agent" | awk '{print $2}' | xargs kill -9) rescue nil
    
    sleep 1
    
    # Verify no processes are left
    system "ps aux | grep clockr-agent | grep -v grep" rescue nil
  end

  def post_install
    setup_permanent_script
    
    # Stop service first
    system "brew", "services", "stop", name rescue nil
    sleep 1
    
    cleanup_processes

    # Force cleanup of ALL versions except current
    system "rm", "-rf", *Dir["#{HOMEBREW_PREFIX}/Cellar/clockr-agent/*"].reject { |d| d.include?(version.to_s) } rescue nil
    system "brew", "cleanup", name rescue nil

    # Ensure service directory exists
    system "mkdir", "-p", "#{ENV["HOME"]}/Library/LaunchAgents"
    
    # Start service
    system "brew", "services", "start", name rescue nil
  end

  def post_upgrade
    # Same cleanup process as post_install
    post_install
  end

  service do
    name macos: "com.alrocar.clockr-agent"
    run opt_bin/"clockr-agent"
    working_dir HOMEBREW_PREFIX
    keep_alive true
    process_type :background
    log_path "#{var}/log/clockr-agent/debug.log"
    error_log_path "#{var}/log/clockr-agent/error.log"
    environment_variables PATH: std_service_path_env
  end

  def caveats
    <<~EOS
      To complete the installation:

      1. Edit your configuration file:
         $EDITOR #{etc}/clockr-agent/clockr-agent.cfg

      2. Ensure you have granted necessary permissions:
         - Accessibility access for monitoring active applications
         - Screen Recording permission for capturing browser URLs

      3. Start the service:
         brew services start clockr-agent

      Or to start manually:
         clockr-agent
    EOS
  end

  def post_uninstall
    # Remove logs directory
    rm_r var/"log/clockr-agent"

    # Optionally remove config file (uncomment if desired)
    rm Pathname.new(Dir.home)/"clockr-agent.cfg"
  end

  test do
    system "#{bin}/clockr-agent", "--version"
  end
end
