#!/usr/bin/env bash

# log-viewer: interactive menu for reading system logs
#
# Adding a new log
# ----------------
# Add a single add_log line in the "LOG REGISTRY" section below:
#
#   add_log "<category>" "<name>" "<command that prints the log>"
#
# For a systemd service the helpers make it a one-liner:
#
#   add_service "<category>" "<unit name>"          # journalctl -u <unit>
#   add_file    "<category>" "<name>" "<file path>" # cat <file> (skipped in menu if missing)
#
# The command is run with "bash -c", so pipes/flags are fine. Output is
# piped to a pager or printed fully depending on what the user picks.

set -u

# Debugging
# ---------
# set -x : print out every line as it executes, with variables expanded
#		putting it at top of the script will enable this for the whole
#		script, or before a block of commands and end it with:
#		{ set +x; } 2>/dev/null
#
# bash -x script.sh : same as putting set -x at the top of script

function print_info { echo "[ info   ] $1"; }
function print_warn { echo "[ warn   ] $1"; }
function print_error { echo "[ error  ] $1" >&2; }

PAGER_CMD="${PAGER:-less}"
# -R: keep colors, +G: start at end of log (most recent entries)
if [ "$PAGER_CMD" == "less" ]; then PAGER_CMD="less -R +G"; fi

# force color output from journalctl even though stdout is a pipe
JCTL="SYSTEMD_COLORS=1 journalctl --no-pager"

################
# LOG REGISTRY #
################

LOG_CATEGORIES=()
LOG_NAMES=()
LOG_COMMANDS=()

# register a log
# $1: category (used as menu section header)
# $2: display name
# $3: command that prints the log to stdout
function add_log {
    LOG_CATEGORIES+=("$1")
    LOG_NAMES+=("$2")
    LOG_COMMANDS+=("$3")
}

# register a systemd service unit (system journal)
# $1: category
# $2: unit name (without .service)
function add_service {
    # only show services that exist on this machine
    if systemctl list-unit-files --type=service --no-legend "$2.service" 2>/dev/null | grep -q .; then
        add_log "$1" "$2.service" "$JCTL -u $2.service"
    fi
}

# register a plain log file
# $1: category
# $2: display name
# $3: file path (entry is skipped if the file does not exist)
function add_file {
    if [ -r "$3" ]; then
        add_log "$1" "$2" "cat '$3'"
    elif [ -e "$3" ]; then
        # exists but not readable as user: read via sudo (prompts on use)
        add_log "$1" "$2" "sudo cat '$3'"
    fi
}

# --- kernel / boot ---
add_log "kernel/boot" "kernel log (current boot)"      "$JCTL -k -b 0"
add_log "kernel/boot" "kernel log (previous boot)"     "$JCTL -k -b -1"
add_log "kernel/boot" "dmesg (raw kernel ring buffer)" "sudo dmesg --color=always"
add_log "kernel/boot" "full journal (current boot)"    "$JCTL -b 0"
add_log "kernel/boot" "full journal (previous boot)"   "$JCTL -b -1"
add_log "kernel/boot" "errors and worse (current boot)" "$JCTL -b 0 -p err"
add_log "kernel/boot" "boot timing (systemd-analyze blame)" "systemd-analyze blame --no-pager"
add_file "kernel/boot" "boot.log" "/var/log/boot.log"

# --- core system services ---
add_service "system services" "systemd-journald"
add_service "system services" "systemd-logind"
add_service "system services" "systemd-udevd"
add_service "system services" "systemd-resolved"
add_service "system services" "systemd-timesyncd"
add_service "system services" "systemd-oomd"
add_service "system services" "dbus-broker"
add_service "system services" "dbus"
add_service "system services" "polkit"
add_service "system services" "auditd"
add_service "system services" "crond"
add_service "system services" "cron"
add_service "system services" "chronyd"
add_service "system services" "rsyslog"

# --- network ---
add_service "network" "NetworkManager"
add_service "network" "wpa_supplicant"
add_service "network" "iwd"
add_service "network" "firewalld"
add_service "network" "sshd"
add_service "network" "ssh"
add_service "network" "bluetooth"
add_service "network" "avahi-daemon"
add_service "network" "tailscaled"
add_service "network" "wireguard"

# --- desktop / graphics ---
add_service "desktop" "gdm"
add_service "desktop" "sddm"
add_service "desktop" "lightdm"
add_file "desktop" "Xorg.0.log (system)"      "/var/log/Xorg.0.log"
add_file "desktop" "Xorg.0.log (user)"        "$HOME/.local/share/xorg/Xorg.0.log"
add_file "desktop" "Xorg.0.log.old (user)"    "$HOME/.local/share/xorg/Xorg.0.log.old"
add_log  "desktop" "gnome-shell (user journal)" "$JCTL --user -b 0 /usr/bin/gnome-shell 2>/dev/null || $JCTL -b 0 _COMM=gnome-shell"
add_log  "desktop" "user session journal (current boot)" "$JCTL --user -b 0"
add_service "desktop" "flatpak-system-helper"
add_service "desktop" "cups"
add_service "desktop" "upower"
add_service "desktop" "udisks2"
add_service "desktop" "power-profiles-daemon"
add_service "desktop" "tuned"

# --- virtualization / containers ---
add_service "virt/containers" "docker"
add_service "virt/containers" "containerd"
add_service "virt/containers" "podman"
add_service "virt/containers" "libvirtd"
add_service "virt/containers" "virtqemud"

# --- packages / updates ---
add_file "packages" "dnf.log"          "/var/log/dnf.log"
add_file "packages" "dnf.rpm.log"      "/var/log/dnf.rpm.log"
add_file "packages" "dnf5.log"         "/var/log/dnf5.log"
add_file "packages" "apt history.log"  "/var/log/apt/history.log"
add_file "packages" "apt term.log"     "/var/log/apt/term.log"
add_file "packages" "pacman.log"       "/var/log/pacman.log"
add_service "packages" "packagekit"

# --- security ---
add_file "security" "audit.log"        "/var/log/audit/audit.log"
add_file "security" "secure (auth log)" "/var/log/secure"
add_file "security" "auth.log"         "/var/log/auth.log"
add_log  "security" "failed login attempts" "sudo lastb 2>/dev/null || lastb"
add_log  "security" "login history"    "last"
add_log  "security" "sudo usage (journal)" "$JCTL _COMM=sudo"
add_log  "security" "SELinux denials (journal)" "$JCTL -t setroubleshoot -t audit --grep=AVC 2>/dev/null || $JCTL _TRANSPORT=audit"

########
# MENU #
########

# number of menu entries per page
PAGE_SIZE=10

# print one page of the numbered menu grouped by category
# $1: page number (1-based)
# $2: page size
function show_menu {
    local page="$1"
    local page_size="$2"
    local total="${#LOG_NAMES[@]}"
    local pages=$(((total + page_size - 1) / page_size))
    local start=$(((page - 1) * page_size))
    local end=$((start + page_size))
    if [ "$end" -gt "$total" ]; then end="$total"; fi

    local i
    local last_category=""
    echo ""
    echo "=========================================="
    echo " Log Viewer - select a log to read"
    echo "=========================================="
    for ((i = start; i < end; i++)); do
        if [ "${LOG_CATEGORIES[$i]}" != "$last_category" ]; then
            last_category="${LOG_CATEGORIES[$i]}"
            echo "--- $last_category ---"
        fi
        printf "  %3d) %s\n" "$((i + 1))" "${LOG_NAMES[$i]}"
    done
    echo ""
    echo " page $page/$pages   [n]ext page  [p]rev page  [1-$total] view log  [q]uit"
    echo ""
}

# print the full menu without pagination (used by --list)
function show_menu_full {
    show_menu 1 "${#LOG_NAMES[@]}"
}

# show a single log
# $1: index into the registry arrays
function view_log {
    local name="${LOG_NAMES[$1]}"
    local cmd="${LOG_COMMANDS[$1]}"
    local mode

    echo ""
    print_info "log: $name"
    read -rp "view with [p]ager, [f]ull dump, or last [n] lines? [P/f/n] " mode
    case "$mode" in
        f|F)
            bash -c "$cmd"
            ;;
        n|N)
            local lines
            read -rp "number of lines [50]: " lines
            lines="${lines:-50}"
            bash -c "$cmd" | tail -n "$lines"
            ;;
        *)
            bash -c "$cmd" | $PAGER_CMD
            ;;
    esac
}

########
# MAIN #
########

function usage {
    echo "interactive system log viewer"
    echo ""
    echo "Usage: $(basename "$0") [-l|--list] [-h|--help]"
    echo ""
    echo "  -l|--list    print available logs and exit"
    echo "  -h|--help    show this help"
    echo ""
    echo "With no arguments an interactive menu is shown."
    exit 1
}

while [[ "$#" -gt 0 ]]; do case $1 in
    -l|--list) show_menu_full; exit 0;;
    -h|--help) usage;;
    *) usage;;
esac; done

if [ "${#LOG_NAMES[@]}" -eq 0 ]; then
    print_error "no logs available on this system"
    exit 1
fi

MENU_PAGE=1
TOTAL_PAGES=$(((${#LOG_NAMES[@]} + PAGE_SIZE - 1) / PAGE_SIZE))
while true; do
    show_menu "$MENU_PAGE" "$PAGE_SIZE"
    read -rp "select: " choice
    case "$choice" in
        q|Q) exit 0;;
        n|N)
            if [ "$MENU_PAGE" -lt "$TOTAL_PAGES" ]; then
                MENU_PAGE=$((MENU_PAGE + 1))
            else
                MENU_PAGE=1
            fi
            continue;;
        p|P)
            if [ "$MENU_PAGE" -gt 1 ]; then
                MENU_PAGE=$((MENU_PAGE - 1))
            else
                MENU_PAGE="$TOTAL_PAGES"
            fi
            continue;;
        ''|*[!0-9]*) print_warn "invalid selection"; continue;;
    esac
    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#LOG_NAMES[@]}" ]; then
        print_warn "selection out of range"
        continue
    fi
    view_log "$((choice - 1))"
done
