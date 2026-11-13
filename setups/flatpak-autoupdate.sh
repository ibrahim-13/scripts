#!/usr/bin/env bash

flatpak_manager_setup() {
    # Change these names here if you want different systemd unit names.
    local service_name="flatpak-manager.service"
    local timer_name="flatpak-manager.timer"
    local unit_dir="/etc/systemd/system"
    local service="${unit_dir}/${service_name}"
    local timer="${unit_dir}/${timer_name}"
    local action="${1:-}"
    local flatpak_bin
    local service_tmp=""
    local timer_tmp=""

    _flatpak_manager_confirm() {
        local prompt="$1"
        local reply

        if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
            printf 'Cannot ask for confirmation without a terminal: %s\n' \
                "$prompt" >&2
            return 1
        fi

        printf '%s [y/N] ' "$prompt" > /dev/tty
        IFS= read -r reply < /dev/tty
        [[ "$reply" =~ ^([yY]|[yY][eE][sS])$ ]]
    }

    _flatpak_manager_cleanup() {
        [[ -n "$service_tmp" ]] && rm -f -- "$service_tmp"
        [[ -n "$timer_tmp" ]] && rm -f -- "$timer_tmp"
    }

    if [[ $# -ne 1 || ( "$action" != "install" && "$action" != "remove" ) ]]; then
        printf 'Usage: %s {install|remove}\n' "${0##*/}" >&2
        return 2
    fi

    if (( EUID != 0 )); then
        printf 'Run this script as root, for example: sudo %s %s\n' \
            "${0##*/}" "$action" >&2
        return 1
    fi

    if [[ "$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]')" != \
        "systemd" ]]; then
        printf 'PID 1 is not systemd; this setup requires systemd.\n' >&2
        return 1
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        printf 'systemctl was not found.\n' >&2
        return 1
    fi

    if [[ "$action" == "remove" ]]; then
        if [[ ! -e "$service" && ! -e "$timer" ]]; then
            printf 'Flatpak Manager units are not installed; nothing to remove.\n'
            return 0
        fi

        if ! _flatpak_manager_confirm \
            "Disable the timer and remove the Flatpak Manager unit files?"; then
            printf 'Removal cancelled.\n'
            return 0
        fi

        systemctl disable --now "$timer_name" 2>/dev/null || true
        systemctl stop "$service_name" 2>/dev/null || true
        rm -f -- "$service" "$timer" || return 1
        systemctl daemon-reload || return 1
        systemctl reset-failed "$service_name" "$timer_name" \
            2>/dev/null || true

        printf 'Flatpak Manager units removed.\n'
        return 0
    fi

    flatpak_bin="$(command -v flatpak 2>/dev/null)" || {
        printf 'Flatpak was not found; install and configure it first.\n' >&2
        return 1
    }

    flatpak_bin="$(readlink -f -- "$flatpak_bin" 2>/dev/null || \
        printf '%s' "$flatpak_bin")"

    if [[ -e "$service" || -e "$timer" ]]; then
        printf 'Existing Flatpak Manager unit file(s) were found.\n'

        if ! _flatpak_manager_confirm \
            "Replace the existing service and timer files?"; then
            printf 'Installation cancelled; existing files were left unchanged.\n'
            return 0
        fi
    fi

    service_tmp="$(mktemp "${unit_dir}/.${service_name}.XXXXXX")" ||
        return 1
    timer_tmp="$(mktemp "${unit_dir}/.${timer_name}.XXXXXX")" || {
        rm -f -- "$service_tmp"
        return 1
    }

    trap _flatpak_manager_cleanup RETURN

    cat >"$service_tmp" <<EOF
[Unit]
Description=Flatpak Manager
Documentation=man:flatpak(1)
Wants=network-online.target
After=network-online.target

# On laptops, avoid downloading updates while on battery.
ConditionACPower=true

[Service]
Type=oneshot

# Make Flatpak's system export directory visible to the root-run process.
Environment=XDG_DATA_DIRS=/var/lib/flatpak/exports/share:/usr/local/share:/usr/share

# Update system-installed Flatpaks.
ExecStart=${flatpak_bin} --system update --noninteractive

# Remove unused system Flatpak runtimes. Ignore failure of this cleanup step.
ExecStart=-${flatpak_bin} --system uninstall --unused --noninteractive

TimeoutStartSec=30min
Nice=10
IOSchedulingClass=idle
EOF

    cat >"$timer_tmp" <<EOF
[Unit]
Description=Run Flatpak Manager daily

[Timer]
Unit=${service_name}
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

    chmod 0644 "$service_tmp" "$timer_tmp" || return 1
    mv -f -- "$service_tmp" "$service" || return 1
    service_tmp=""
    mv -f -- "$timer_tmp" "$timer" || return 1
    timer_tmp=""

    systemctl daemon-reload || return 1

    if systemctl is-active --quiet "$timer_name"; then
        printf 'The timer is already active; its unit files have been updated.\n'
    else
        systemctl enable --now "$timer_name" || return 1
    fi

    printf 'Flatpak Manager is installed and its timer is enabled.\n'
    printf 'Check the timer with: systemctl status %s\n' "$timer_name"
    printf 'Check update logs with: journalctl -u %s\n' "$service_name"
}

flatpak_manager_setup "$@"
