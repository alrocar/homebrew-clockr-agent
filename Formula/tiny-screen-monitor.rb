class TinyScreenMonitor < Formula
  desc "Monitor screen lock status and active applications on macOS"
  homepage "https://github.com/alrocar/homebrew-tiny-screen-monitor"
  url "https://github.com/alrocar/homebrew-tiny-screen-monitor/archive/refs/tags/0.0.0.dev6.tar.gz"
  # curl -L https://github.com/alrocar/homebrew-tiny-screen-monitor/archive/refs/tags/0.0.0.dev2.tar.gz | shasum -a 256
  sha256 "a941513f4feb6faaa0c25de992e11192e515960a9f0c0b124d8ae8fe4c5e5541"
  license "MIT"

  depends_on "curl"

  def install
    bin.install "bin/tiny-screen-monitor.sh" => "tiny-screen-monitor"
    bin.install "bin/check_display.sh"

    # Install config template
    prefix.install "bin/tiny-screen-monitor.cfg.template"

    # Create logs directory
    (var/"log/tiny-screen-monitor").mkpath
  end

  def post_install
    # Create etc directory and copy config
    (etc/"tiny-screen-monitor").mkpath
    config_template = prefix/"tiny-screen-monitor.cfg.template"
    config_file = etc/"tiny-screen-monitor/tiny-screen-monitor.cfg"
    
    unless config_file.exist?
      cp config_template, config_file
      chmod 0600, config_file
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
