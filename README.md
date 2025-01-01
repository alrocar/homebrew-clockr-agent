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
brew tap alrocar/tiny-screen-monitor
brew install tiny-screen-monitor
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
- Screen Recording

## Usage

Run in normal model

```sh
screen-monitor
```

Run in verbose mode

```sh
screen-monitor -v
```

## Logs

Logs are stored in ./logs/locked_screen.log

## Dependencies

- `osascript`
- `curl`

## Uninstallation

To remove the package:

```sh
brew uninstall tiny-screen-monitor
```

To remove the tap:

```sh
brew untap alrocar/tiny-screen-monitor
```

## License

MIT
