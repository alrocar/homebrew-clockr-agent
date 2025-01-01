class TinyScreenMonitor < Formula
  desc "Monitor screen lock status and active applications on macOS"
  homepage "https://github.com/alrocar/homebrew-tiny-screen-monitor"
  url "https://github.com/alrocar/homebrew-tiny-screen-monitor/archive/refs/tags/0.0.0.dev8.tar.gz"
  # curl -L https://github.com/alrocar/homebrew-tiny-screen-monitor/archive/refs/tags/0.0.0.dev2.tar.gz | shasum -a 256
  sha256 "259dfe96e86b36ad6f6ff39a0e09f4994a7f82f07c38a178790e03d49f630af8"
  license "MIT"

  depends_on "curl"

  def install
    bin.install "bin/tiny-screen-monitor.sh" => "tiny-screen-monitor"
    bin.install "bin/check_display.sh"

    # Install config template
    prefix.install "bin/tiny-screen-monitor.cfg.template"

    # Create logs directory with write permissions
    (var/"log/tiny-screen-monitor").mkpath
    chmod 0755, var/"log/tiny-screen-monitor"
  end

  def post_install
    # Create etc directory and copy config
    (etc/"tiny-screen-monitor").mkpath
    config_template = prefix/"tiny-screen-monitor.cfg.template"
    config_file = etc/"tiny-screen-monitor/tiny-screen-monitor.cfg"
    
    unless config_file.exist?
      cp config_template, config_file
      # Make config readable/writable by user only
      chmod 0644, config_file
    end
  end

  def caveats
    <<~EOS
      To complete the installation:

      1. Edit your configuration file:
         $EDITOR /etc/tiny-screen-monitor/tiny-screen-monitor.cfg

      2. Ensure you have granted necessary permissions:
         - Accessibility access for monitoring active applications
         - Screen Recording permission for capturing browser URLs

      3. Start the service:
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
