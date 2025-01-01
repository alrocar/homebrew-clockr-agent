class TinyScreenMonitor < Formula
  desc "Monitor screen lock status and active applications on macOS"
  homepage "https://github.com/alrocar/homebrew-tiny-screen-monitor"
  url "https://github.com/alrocar/homebrew-tiny-screen-monitor/archive/refs/tags/0.0.0.dev4.tar.gz"
  # curl -L https://github.com/alrocar/homebrew-tiny-screen-monitor/archive/refs/tags/0.0.0.dev2.tar.gz | shasum -a 256
  sha256 "0a1d24a98bf0f4418ef66d86107a7f0456c4b96e41e2076edb54d702c43553ec"
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
    # Copy config template if it doesn't exist
    config_template = prefix/"tiny-screen-monitor.cfg.template"
    config_file = Pathname.new(Dir.home)/"tiny-screen-monitor.cfg"

    unless config_file.exist?
      # Use system cp instead of Ruby's cp to handle permissions better
      system "cp", config_template.to_s, config_file.to_s
      system "chmod", "0600", config_file.to_s
      puts "Configuration file created at: #{config_file}"
    end
  end

  def caveats
    <<~EOS
      To complete the installation:

      1. Create your configuration file:
         cp #{prefix}/lock_screen_cfg.template #{Dir.home}/tiny-screen-monitor.cfg
         chmod 600 #{Dir.home}/tiny-screen-monitor.cfg

      2. Edit your configuration file:
         $EDITOR #{Dir.home}/tiny-screen-monitor.cfg

      3. Ensure you have granted necessary permissions:
         - Accessibility access for monitoring active applications
         - Screen Recording permission for capturing browser URLs

      4. Start the service:
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
