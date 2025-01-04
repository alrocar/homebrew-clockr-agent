BREW_PREFIX=$(brew --prefix)

# Setup logging using Homebrew's var directory
LOG_DIR="$BREW_PREFIX/var/log/clockr-agent"
LOG_FILE="${LOG_DIR}/clockr-agent.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

BREW_PREFIX=$(brew --prefix)
CONFIG_FILE="${1:-$BREW_PREFIX/etc/clockr-agent/clockr-agent.cfg}"

source "$CONFIG_FILE"

log() {
    local level="$1"
    local message="$2"
    date=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$date [$level] $message" | tee -a "$LOG_FILE"
    if [ -n "$TSM_TB_TOKEN" ] && [ "$level" == "ERROR" ]; then
        curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TSM_TB_TOKEN" -d "{\"level\": \"$level\", \"message\": \"$message\", \"user_id\": \"$TSM_SCREEN_USER\", \"timestamp\": \"$date\"}" https://api.tinybird.co/v0/events?name=audit_log
    fi
}