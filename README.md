# Tiny Screen Monitor

A macOS utility that monitors screen lock status and active applications, designed to track screen time and application usage.

## Features

- Detects screen lock states:
  - Physical lid closure
  - Screen saver activation
  - Lock screen activation
  - Display power state
- Logs screen state changes
- Integrates with Tinybird for data collection
- Supports verbose debugging mode

## Installation

```sh
brew tap alrocar/clockr-agent
brew install clockr-agent
```

## Configuration

1. Create your configuration file:

```sh
cp lock_screen_cfg.template lock_screen_cfg
```

2. Edit the configuration:

```sh
LOCKED_TB_TOKEN=your_tinybird_token # Your Tinybird API token
LOCKED_SCREEN_USER=your_username # Your username for logging
LOCKED_SCREEN_SLEEP_TIME=10 # Polling interval in seconds
```

3. Grant required permissions in System Settings → Privacy & Security:

- Accessibility
- Automation (to get browser active tab)

The service does not control any application, it just uses operative system events to get the current running application or browser tab.

You'll be prompted on service start for those permissions.

## Usage

Run as a background service (recommended):

```sh
brew services start alrocar/clockr-agent/clockr-agent
```

Run in normal model

```sh
clockr-agent
```

Run in verbose mode

```sh
clockr-agent -v
```

## Troubleshooting

Check status of the service:

```sh
brew services list
```

Check logs:

```sh
cat $(brew --prefix)/var/log/clockr-agent/output.log
cat $(brew --prefix)/var/log/clockr-agent/error.log
cat $(brew --prefix)/var/log/clockr-agent/clockr-agent.log
```

## Dependencies

- `osascript`
- `curl`

## Uninstallation

To remove the package:

```sh
brew uninstall clockr-agent
```

To remove the tap:

```sh
brew untap alrocar/clockr-agent
```

## License

MIT


# Check status
brew services list

# Check logs
cat $(brew --prefix)/var/log/clockr-agent/output.log
cat $(brew --prefix)/var/log/clockr-agent/error.log