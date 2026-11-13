
#!/usr/bin/env bash

set -Eeuo pipefail

# Installation paths
SCRIPT_PATH="/usr/local/sbin/system-update"
SERVICE_PATH="/etc/systemd/system/system-update.service"
TIMER_PATH="/etc/systemd/system/system-update.timer"

# systemd names
SERVICE_NAME="system-update.service"
TIMER_NAME="system-update.timer"

# Timer configuration
TIMER_SCHEDULE="daily"
TIMER_RANDOM_DELAY="30min"
TIMER_PERSISTENT="true"

# Update script settings
UPDATE_NICE="10"
UPDATE_TIMEOUT="30min"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERR]${NC} $*" >&2
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "This operation requires root privileges."
        echo "Run with: sudo $0 $*"
        exit 1
    fi
}

require_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        error "systemctl is not available."
        exit 1
    fi

    if [[ ! -d /run/systemd/system ]]; then
        error "systemd is not running."
        exit 1
    fi
}

create_update_script() {

    info "Creating update script..."

    install -d "$(dirname "$SCRIPT_PATH")"

    cat > "$SCRIPT_PATH" <<'UPDATE_SCRIPT'
#!/usr/bin/env bash

set -u

export DEBIAN_FRONTEND=noninteractive

log() {
    echo "[$(date '+%F %T')] $*"
}

FAILED=0
OS_UPDATED=0

if command -v dnf >/dev/null 2>&1; then

    log "Detected DNF. Updating packages..."
    dnf upgrade --refresh -y || FAILED=1
    OS_UPDATED=1

elif command -v apt-get >/dev/null 2>&1; then

    log "Detected APT. Updating package lists..."
    apt-get update || FAILED=1

    if [[ "$FAILED" -eq 0 ]]; then
        log "Upgrading APT packages..."
        apt-get upgrade -y || FAILED=1
    fi

    OS_UPDATED=1

elif command -v pacman >/dev/null 2>&1; then

    log "Detected Pacman. Updating packages..."
    pacman -Syu --noconfirm || FAILED=1
    OS_UPDATED=1

elif command -v zypper >/dev/null 2>&1; then

    log "Detected Zypper. Refreshing repositories..."
    zypper --non-interactive refresh || FAILED=1

    if [[ "$FAILED" -eq 0 ]]; then
        zypper --non-interactive update -y || FAILED=1
    fi

    OS_UPDATED=1

elif command -v yum >/dev/null 2>&1; then

    log "Detected YUM. Updating packages..."
    yum update -y || FAILED=1
    OS_UPDATED=1

else

    log "No supported system package manager found."

fi

if command -v flatpak >/dev/null 2>&1; then

    log "Detected Flatpak."

    if flatpak update --system --noninteractive -y; then
        log "Flatpak system updates completed."
    else
        log "Flatpak system update failed."
        FAILED=1
    fi

    if flatpak uninstall --system --unused --noninteractive -y; then
        log "Flatpak system updates completed."
    else
        log "Flatpak system update failed."
        FAILED=1
    fi

fi

if [[ "$OS_UPDATED" -eq 0 ]]; then
    log "WARNING: No supported OS package manager detected."
    FAILED=1
fi

if [[ "$FAILED" -ne 0 ]]; then
    log "One or more updates failed."
    exit 1
fi

log "All update operations completed successfully."
exit 0
UPDATE_SCRIPT

    chmod 755 "$SCRIPT_PATH"

    success "Update script created: $SCRIPT_PATH"
}

create_service() {

    info "Creating systemd service..."

    cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Automatic System Package Update
Wants=network-online.target
After=network-online.target

# On laptops, avoid downloading updates while on battery.
ConditionACPower=true

[Service]
Type=oneshot

# Make Flatpak's system export directory visible to the root-run process.
Environment=XDG_DATA_DIRS=/var/lib/flatpak/exports/share:/usr/local/share:/usr/share

ExecStart=$SCRIPT_PATH
Nice=$UPDATE_NICE
IOSchedulingClass=best-effort
IOSchedulingPriority=7
TimeoutStartSec=$UPDATE_TIMEOUT

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_PATH"

    success "Service created: $SERVICE_PATH"
}

create_timer() {

    info "Creating systemd timer..."

    cat > "$TIMER_PATH" <<EOF
[Unit]
Description=Automatic System Package Update Timer

[Timer]
OnCalendar=$TIMER_SCHEDULE
RandomizedDelaySec=$TIMER_RANDOM_DELAY
Persistent=$TIMER_PERSISTENT
Unit=$SERVICE_NAME

[Install]
WantedBy=timers.target
EOF

    chmod 644 "$TIMER_PATH"

    success "Timer created: $TIMER_PATH"
}

add() {

    require_root
    require_systemd

    info "Installing automatic system update..."

    create_update_script
    create_service
    create_timer

    systemctl daemon-reload

    success "Installation completed."

    echo
    echo "Next step:"
    echo "  sudo $0 enable"
}

remove() {

    require_root
    require_systemd

    info "Removing automatic system update..."

    systemctl disable --now "$TIMER_NAME" 2>/dev/null || true
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true

    rm -f "$SCRIPT_PATH"
    rm -f "$SERVICE_PATH"
    rm -f "$TIMER_PATH"

    systemctl daemon-reload
    systemctl reset-failed "$SERVICE_NAME" "$TIMER_NAME" 2>/dev/null || true

    success "Automatic system update removed."
}

enable() {

    require_root
    require_systemd

    if [[ ! -f "$TIMER_PATH" ]]; then
        error "Timer not installed. Run: $0 add"
        exit 1
    fi

    info "Enabling automatic updates..."

    systemctl daemon-reload
    systemctl enable --now "$TIMER_NAME"

    success "Automatic updates enabled."

    echo
    systemctl list-timers "$TIMER_NAME" --no-pager
}

disable() {

    require_root
    require_systemd

    info "Disabling automatic updates..."

    systemctl disable --now "$TIMER_NAME"

    success "Automatic updates disabled."
}

status() {

    echo
    echo "=========================================="
    echo " SYSTEM UPDATE STATUS"
    echo "=========================================="

    echo
    echo "Installation:"

    [[ -f "$SCRIPT_PATH" ]] && \
        success "Update script installed" || \
        warn "Update script missing"

    [[ -f "$SERVICE_PATH" ]] && \
        success "Service installed" || \
        warn "Service missing"

    [[ -f "$TIMER_PATH" ]] && \
        success "Timer installed" || \
        warn "Timer missing"

    echo
    echo "Timer status:"
    systemctl status "$TIMER_NAME" --no-pager || true

    echo
    echo "Service status:"
    systemctl status "$SERVICE_NAME" --no-pager || true

    echo
    echo "Next scheduled execution:"
    systemctl list-timers "$TIMER_NAME" --no-pager || true

    echo
}

run_update() {

    require_root
    require_systemd

    if [[ ! -x "$SCRIPT_PATH" ]]; then
        error "Update script not installed. Run: $0 add"
        exit 1
    fi

    info "Starting system update..."

    systemctl start "$SERVICE_NAME"

    success "Update service finished."

    echo
    journalctl -u "$SERVICE_NAME" -n 30 --no-pager || true
}

show_logs() {

    require_systemd

    journalctl -u "$SERVICE_NAME" -n 100 --no-pager
}

show_help() {

    cat <<EOF

System Update Manager

Usage:
    $0 COMMAND

Commands:

    add       Install update script, service and timer
    remove    Remove update script, service and timer
    enable    Enable automatic scheduled updates
    disable   Disable automatic scheduled updates
    status    Show installation and service status
    run       Run system updates immediately
    logs      Show update logs
    help      Show this help

Examples:

    sudo $0 add
    sudo $0 enable
    sudo $0 status
    sudo $0 run
    sudo $0 logs
    sudo $0 disable
    sudo $0 remove

Configuration:

    Update script: $SCRIPT_PATH
    Service:       $SERVICE_PATH
    Timer:         $TIMER_PATH

    Schedule:      $TIMER_SCHEDULE
    Random delay:  $TIMER_RANDOM_DELAY

EOF
}

COMMAND="${1:-help}"

case "$COMMAND" in

    add|install)
        add
        ;;

    remove|uninstall)
        remove
        ;;

    enable)
        enable
        ;;

    disable)
        disable
        ;;

    status)
        status
        ;;

    run|update)
        run_update
        ;;

    logs|log)
        show_logs
        ;;

    help|-h|--help)
        show_help
        ;;

    *)
        error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;

esac
