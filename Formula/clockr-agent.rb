class ClockrAgent < Formula
  desc "Monitor screen lock status and active applications on macOS"
  homepage "https://github.com/alrocar/homebrew-clockr-agent"
  url "https://github.com/alrocar/homebrew-clockr-agent/archive/refs/tags/0.0.0.dev103.tar.gz"
  sha256 "f22d04e8305260e5d17c945b809e1323495c014835f772f20c913a3fe25eb894"
  license "MIT"

  depends_on "curl"

  resource "clockr-icon" do
    url "https://clockr.xyz.com/clockr-icon.tar.gz"
    sha256 "dbb710d768416665daea2fd1a1414eaac120c3e25629f3c7b3e1d680edb7a6fb"
  end

  def install
    # First, create all necessary directories
    bin.mkpath
    (etc/"clockr-agent").mkpath
    (var/"log/clockr-agent").mkpath
    
    # Install binaries and scripts
    bin.install "bin/clockr-agent.sh"
    bin.install "bin/clockr-check-display.sh"
    bin.install "bin/clockr-auth.sh"
    bin.install "bin/clockr-log.sh"
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

    # Install icons
    resource("clockr-icon").stage {
      icons_dir = "#{prefix}/share/clockr-agent/icons"
      mkdir_p icons_dir
      cp "clockr-icon.png", "#{icons_dir}/clockr-icon.png"
      cp "clockr-icon@2x.png", "#{icons_dir}/clockr-icon@2x.png"
      cp "clockr-icon@3x.png", "#{icons_dir}/clockr-icon@3x.png"
    }
  end

  # def post_install
  #   # Stop service first
  #   system "brew", "services", "stop", "clockr-agent" rescue nil
  #   sleep 1

  #   # Force cleanup of ALL versions except current
  #   system "rm", "-rf", *Dir["#{HOMEBREW_PREFIX}/Cellar/clockr-agent/*"].reject { |d| d.include?(version.to_s) } rescue nil
  #   system "brew", "cleanup", name rescue nil

  #   # Ensure service directory exists
  #   system "mkdir", "-p", "#{ENV["HOME"]}/Library/LaunchAgents"
    
  #   # Start service
  #   system "brew", "services", "start", "clockr-agent" rescue nil
  # end

  # def post_upgrade
  #   # Same cleanup process as post_install
  #   post_install
  # end

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
