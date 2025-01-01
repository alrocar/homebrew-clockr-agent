class TinyScreenMonitor < Formula
  desc "Monitor screen lock status and active applications on macOS"
  homepage "https://github.com/alrocar/tiny-screen-monitor"
  url "https://github.com/alrocar/tiny-screen-monitor/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "YOUR_TARBALL_SHA256" # You'll need to update this after creating the release
  license "MIT"

  depends_on "curl"
  depends_on "osascript"

  def install
    bin.install "bin/tiny-screen-monitor.sh" => "tiny-screen-monitor"
    bin.install "bin/check_display.sh"
    
    # Install config template
    prefix.install "bin/tiny-screen-monitor.cfg.template"
    
    # Create logs directory
    (var/"log/tiny-screen-monitor").mkpath
  end

  def post_install
    # Copy config template if it doesn't exist
    config_template = prefix/"tiny-screen-monitor.cfg.template"
    config_file = ENV["HOME"]/"tiny-screen-monitor.cfg"
    
    unless config_file.exist?
      cp config_template, config_file
      chmod 0600, config_file
    end
  end

  def caveats
    <<~EOS
      To complete the installation:
      
      1. Edit your configuration file:
         $EDITOR #{ENV["HOME"]}/tiny-screen-monitor.cfg
      
      2. Ensure you have granted necessary permissions:
         - Accessibility access for monitoring active applications
         - Screen Recording permission for capturing browser URLs
      
      3. Start the service:
         tiny-screen-monitor
    EOS
  end

  def post_uninstall
    # Remove logs directory
    rm_rf var/"log/tiny-screen-monitor"
    
    # Optionally remove config file (uncomment if desired)
    # rm_f ENV["HOME"]/"tiny-screen-monitor.cfg"
  end

  test do
    system "#{bin}/tiny-screen-monitor", "--version"
  end
end 