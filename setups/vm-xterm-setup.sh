
#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# XTerm + AI CLI Configuration Manager
#
# Supported:
#   Claude Code
#   OpenAI Codex CLI
#   Pi Coding Agent
#   OpenCode
#
# Existing configurations are preserved.
# ============================================================

SCRIPT_NAME="$(basename "$0")"

CONFIG_FILE="$HOME/.Xresources"
XINITRC="$HOME/.xinitrc"
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"

LOCAL_BIN="$HOME/.local/bin"

XTERM_MARKER="XTERM_AI_SETUP"
PATH_MARKER="XTERM_AI_SETUP_PATH"

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

log() {
    printf '\033[1;32m[INFO]\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33m[WARN]\033[0m %s\n' "$*"
}

err() {
    printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
}

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------

usage() {
    cat <<EOF

============================================================
 XTerm + AI CLI Configuration Manager
============================================================

Usage:
  $SCRIPT_NAME <command> [option]

COMMANDS:

  install
      Install XTerm, fonts and required utilities.

  configure
      Configure XTerm and all supported AI CLI tools.

  configure all
      Configure all supported AI CLI tools.

  configure xterm
      Configure only XTerm resources.

  configure claude
      Configure Claude Code launcher.

  configure codex
      Configure Codex CLI launcher.

  configure pi
      Configure Pi launcher.

  configure opencode
      Configure OpenCode launcher.

  claude-help
      Display Claude Code help.

  codex-help
      Display Codex CLI help.

  pi-help
      Display Pi help.

  opencode-help
      Display OpenCode help.

  test
      Test terminal capabilities and detect installed tools.

  all
      Install, configure all tools and run tests.

  help
      Display this help.

SUPPORTED TOOLS:

  claude       Anthropic Claude Code
  codex        OpenAI Codex CLI
  pi           Pi Coding Agent
  opencode     OpenCode

GENERATED LAUNCHERS:

  ~/.local/bin/claude-xterm
  ~/.local/bin/codex-xterm
  ~/.local/bin/pi-xterm
  ~/.local/bin/opencode-xterm

CONFIGURATION FILES:

  ~/.Xresources
  ~/.bashrc
  ~/.zshrc

EXAMPLES:

  $SCRIPT_NAME install
  $SCRIPT_NAME configure
  $SCRIPT_NAME configure xterm
  $SCRIPT_NAME configure claude
  $SCRIPT_NAME configure codex
  $SCRIPT_NAME configure pi
  $SCRIPT_NAME configure opencode
  $SCRIPT_NAME configure all

  $SCRIPT_NAME claude-help
  $SCRIPT_NAME codex-help
  $SCRIPT_NAME pi-help
  $SCRIPT_NAME opencode-help

  $SCRIPT_NAME test
  $SCRIPT_NAME all

IMPORTANT:

  - Existing configurations are preserved.
  - Only script-managed sections are replaced.
  - Backups are created before modifications.
  - Native AI CLI configurations are not overwritten.
  - Launchers use xterm-256color and truecolor.
  - Restart XTerm after configuring resources.

============================================================

EOF
}

check_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        err "This script requires Linux."
        exit 1
    fi
}

backup_file() {
    local file="$1"
    local timestamp
    local backup
    local counter=1

    [[ -f "$file" ]] || return 0

    timestamp="$(date +%Y%m%d_%H%M%S)"
    backup="${file}.backup.${timestamp}"
    while [[ -e "$backup" ]]; do
        backup="${file}.backup.${timestamp}.${counter}"
        ((counter += 1))
    done
    cp -p "$file" "$backup"
    log "Backup created: $backup"
}

update_managed_block() {
    local file="$1"
    local start_marker="$2"
    local end_marker="$3"
    local prepend_if_missing="${4:-false}"

    local block_file
    local temp_file
    local new_file

    local starts=0
    local ends=0

    block_file="$(mktemp)"
    temp_file="$(mktemp)"
    new_file="$(mktemp)"

    cat > "$block_file"

    if [[ -f "$file" ]]; then
        starts=$(grep -Fxc -- "$start_marker" "$file" || true)
        ends=$(grep -Fxc -- "$end_marker" "$file" || true)

        if [[ "$starts" != "$ends" ]] || [[ "$starts" -gt 1 ]]; then
            err "Invalid or duplicated markers in $file"
            rm -f "$block_file" "$temp_file" "$new_file"
            return 1
        fi

        if [[ "$starts" -eq 1 ]]; then
            awk -v start="$start_marker" \
                -v end="$end_marker" '
                $0 == start {
                    inside = 1
                    next
                }

                $0 == end {
                    inside = 0
                    next
                }

                !inside {
                    print
                }
            ' "$file" > "$temp_file"
        else
            cp "$file" "$temp_file"
        fi
    else
        touch "$temp_file"
    fi

    {
        if [[ "$prepend_if_missing" == "true" && "$starts" -eq 0 ]]; then
            printf '%s\n' "$start_marker"
            cat "$block_file"
            printf '%s\n' "$end_marker"
            cat "$temp_file"
        else
            cat "$temp_file"
            printf '\n%s\n' "$start_marker"
            cat "$block_file"
            printf '%s\n' "$end_marker"
        fi
    } > "$new_file"

    if [[ -f "$file" ]]; then
        chmod --reference="$file" "$new_file"
        backup_file "$file"
    else
        chmod 644 "$new_file"
    fi

    mv "$new_file" "$file"
    rm -f "$block_file" "$temp_file"
    log "Updated: $file"
}

install_packages() {
    log "Installing XTerm and fonts..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y \
            xterm \
            x11-xserver-utils \
            ncurses-bin \
            fonts-dejavu-core \
            fonts-liberation
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed \
            xterm \
            xorg-xrdb \
            ncurses \
            ttf-dejavu \
            ttf-liberation
    elif command -v dnf >/dev/null 2>&1; then

        sudo dnf install -y \
            xterm \
            xorg-x11-server-utils \
            ncurses \
            dejavu-sans-mono-fonts \
            liberation-mono-fonts
    else
        err "Unsupported package manager."
        exit 1
    fi
    log "Package installation completed."
}

configure_xterm() {
    log "Configuring XTerm resources..."
    update_managed_block \
        "$CONFIG_FILE" \
        "! BEGIN ${XTERM_MARKER}" \
        "! END ${XTERM_MARKER}" <<'EOF'
! Font
XTerm*faceName: DejaVu Sans Mono
XTerm*faceSize: 10

! Terminal identification
XTerm*termName: xterm-256color

! Colors
XTerm*allowColorOps: true
XTerm*foreground: #d8dee9
XTerm*background: #1e222a
XTerm*cursorColor: #e5c07b

! Color palette
XTerm*color0:  #282c34
XTerm*color1:  #e06c75
XTerm*color2:  #98c379
XTerm*color3:  #e5c07b
XTerm*color4:  #61afef
XTerm*color5:  #c678dd
XTerm*color6:  #56b6c2
XTerm*color7:  #abb2bf
XTerm*color8:  #545862
XTerm*color9:  #e06c75
XTerm*color10: #98c379
XTerm*color11: #e5c07b
XTerm*color12: #61afef
XTerm*color13: #c678dd
XTerm*color14: #56b6c2
XTerm*color15: #ffffff

! UTF-8
XTerm*utf8: 2
XTerm*eightBitInput: false
XTerm*metaSendsEscape: true

! Scrollback and clipboard
XTerm*saveLines: 3000
XTerm*scrollBar: false
XTerm*selectToClipboard: true
! This configuration allows right-click to paste but may disable the right-click context menu.
!   To access the menu, hold Ctrl and right-click.
! Defualt paste key: Shift+Insert
XTerm*VT100.Translations: #override \
    Ctrl Shift <Key>C: copy-selection(CLIPBOARD) \n\
    Ctrl Shift <Key>V: insert-selection(CLIPBOARD) \n\
    ~Ctrl ~Meta ~Shift <Btn3Down>: select-end(CLIPBOARD, PRIMARY, CUT_BUFFER0) \n\
    ~Ctrl ~Meta ~Shift <Btn3Up>: insert-selection(CLIPBOARD, PRIMARY, CUT_BUFFER0)

EOF

    log "XTerm resource configured."

    if command -v xrdb >/dev/null 2>&1; then
        xrdb -merge "$CONFIG_FILE"
        log "XTerm resources loaded."

        local block
        block='
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources
'
        if [[ -f "$XINITRC" ]]; then
            update_managed_block \
                "$XINITRC" \
                "# BEGIN ${XTERM_MARKER}" \
                "# END ${XTERM_MARKER}" \
                true <<< "$block"
        fi
    else
        warn "xrdb unavailable. Install X resource utilities."
    fi
}

configure_path() {
    mkdir -p "$LOCAL_BIN"
    local block
    block='
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
'

    for rc in "$BASHRC" "$ZSHRC"; do
        if [[ -f "$rc" ]]; then
            update_managed_block \
                "$rc" \
                "# BEGIN ${PATH_MARKER}" \
                "# END ${PATH_MARKER}" <<< "$block"
        fi
    done
    export PATH="$LOCAL_BIN:$PATH"
    log "PATH configured."
}

create_launcher() {
    local tool="$1"
    local launcher="$LOCAL_BIN/${tool}-xterm"

    mkdir -p "$LOCAL_BIN"
    if [[ -f "$launcher" ]]; then
        backup_file "$launcher"
    fi
    cat > "$launcher" <<EOF
#!/usr/bin/env bash

# Generated by ${SCRIPT_NAME}
# XTerm launcher for ${tool}

set -e

export TERM=xterm-256color
export COLORTERM=truecolor

if ! command -v ${tool} >/dev/null 2>&1; then
    echo "Error: ${tool} is not installed or not in PATH." >&2
    exit 127
fi

exec ${tool} "\$@"
EOF

    chmod 755 "$launcher"
    log "Created launcher: $launcher"
}

configure_tool() {
    local tool="$1"

    case "$tool" in
        claude|codex|pi|opencode)
            create_launcher "$tool"
            ;;
        all)
            create_launcher claude
            create_launcher codex
            create_launcher pi
            create_launcher opencode
            ;;

        *)
            err "Unknown tool: $tool"
            return 1
            ;;
    esac
}

configure_all() {
    local target="${1:-all}"

    if [[ "$target" == "xterm" || "$target" == "all" ]]; then
        configure_xterm
    fi
    if [[ "$target" != "xterm" ]]; then
        configure_path
        configure_tool "$target"
    fi

    log "Configuration completed: $target"
    warn "Restart XTerm to apply resource changes."
    warn "Open a new shell to load PATH changes."

    echo
    echo "Available launchers:"
    echo

    case "$target" in
        all)
            printf '  %s\n' \
                "$LOCAL_BIN/claude-xterm" \
                "$LOCAL_BIN/codex-xterm" \
                "$LOCAL_BIN/pi-xterm" \
                "$LOCAL_BIN/opencode-xterm"
            ;;
        xterm)
            echo "  XTerm resources configured."
            ;;
        *)
            printf '  %s\n' "$LOCAL_BIN/${target}-xterm"
            ;;
    esac
}

claude_help() {
    cat <<'EOF'

============================================================
 Claude Code + XTerm
============================================================

Launch:

  claude-xterm

Or:

  ~/.local/bin/claude-xterm

Inside Claude Code:

  /tui default

If alternate-screen problems occur:

  CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1 claude-xterm

Inspect options:

  claude --help

Native configuration:

  ~/.claude/settings.json

This script does not modify native Claude configuration.

============================================================

EOF
}

codex_help() {

    cat <<'EOF'

============================================================
 OpenAI Codex CLI + XTerm
============================================================

Launch:

  codex-xterm

Or:

  ~/.local/bin/codex-xterm

Inspect options:

  codex --help

Check version:

  codex --version

Native configuration:

  ~/.codex/config.toml

The launcher provides:

  TERM=xterm-256color
  COLORTERM=truecolor

This script does not modify Codex configuration.

============================================================

EOF
}

pi_help() {

    cat <<'EOF'

============================================================
 Pi Coding Agent + XTerm
============================================================

Launch:

  pi-xterm

Or:

  ~/.local/bin/pi-xterm

Inspect options:

  pi --help

Check version:

  pi --version

The launcher provides:

  TERM=xterm-256color
  COLORTERM=truecolor

Pi native configuration is preserved.

============================================================

EOF
}

opencode_help() {

    cat <<'EOF'

============================================================
 OpenCode + XTerm
============================================================

Launch:

  opencode-xterm

Or:

  ~/.local/bin/opencode-xterm

Inspect options:

  opencode --help

Check version:

  opencode --version

Native configuration is preserved.

The launcher provides:

  TERM=xterm-256color
  COLORTERM=truecolor

============================================================

EOF
}

test_terminal() {
    log "Testing terminal environment..."

    echo
    echo "================================================"
    echo "Terminal information"
    echo "================================================"

    printf 'TERM:       %s\n' "${TERM:-unset}"
    printf 'COLORTERM:  %s\n' "${COLORTERM:-unset}"

    printf 'Locale:     %s\n' \
        "$(locale charmap 2>/dev/null || echo unknown)"

    echo
    echo "================================================"
    echo "Terminfo"
    echo "================================================"

    if command -v infocmp >/dev/null 2>&1; then
        if infocmp xterm-256color >/dev/null 2>&1; then
            log "xterm-256color terminfo entry found."
        else
            warn "xterm-256color terminfo entry missing."
        fi
    else
        warn "infocmp unavailable."
    fi

    echo
    echo "================================================"
    echo "Color capability"
    echo "================================================"

    if command -v tput >/dev/null 2>&1; then
        printf 'Color count: '
        tput colors 2>/dev/null || echo "Unknown"
        echo
        echo "16-color palette:"
        for i in {0..15}; do
            printf '\033[48;5;%sm  %02d  \033[0m' "$i" "$i"
            if [[ $(( (i + 1) % 4 )) -eq 0 ]]; then
                echo
            fi
        done

        echo
        echo "Truecolor test:"

        printf '\033[38;2;255;100;100mRed '
        printf '\033[38;2;100;255;100mGreen '
        printf '\033[38;2;100;150;255mBlue\033[0m\n'
    else
        warn "tput unavailable."
    fi

    echo
    echo "================================================"
    echo "Unicode and box-drawing test"
    echo "================================================"

    printf '┌──────────────────────────┐\n'
    printf '│ AI CLI Terminal Test     │\n'
    printf '└──────────────────────────┘\n'

    printf 'Symbols: ● ✓ → ◆ ★ █ ░ ▒\n'

    echo
    echo "================================================"
    echo "Installed AI CLI tools"
    echo "================================================"

    local tools=(claude codex pi opencode)

    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf '[INSTALLED] %s\n' "$tool"
            "$tool" --version 2>/dev/null || true
        else
            printf '[NOT FOUND] %s\n' "$tool"
        fi
    done

    echo
    echo "================================================"
    echo "Launcher availability"
    echo "================================================"

    for tool in claude codex pi opencode; do
        if [[ -x "$LOCAL_BIN/${tool}-xterm" ]]; then
            log "${tool}-xterm is configured."
        else
            warn "${tool}-xterm is not configured."
        fi
    done
    echo
    log "Terminal tests completed."
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

main() {

    # No arguments: display full help.
    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    # Validate command.
    case "$1" in
        install|configure|claude-help|codex-help|pi-help|opencode-help|test|all|help)
            ;;
        *)
            err "Unknown command: $1"
            usage
            exit 1
            ;;
    esac

    check_linux

    case "$1" in
        install)
            install_packages
            ;;
        configure)
            local target="${2:-all}"
            case "$target" in
                all|xterm|claude|codex|pi|opencode)
                    configure_all "$target"
                    ;;
                *)
                    err "Unknown configuration target: $target"
                    usage
                    exit 1
                    ;;
            esac
            ;;
        claude-help)
            claude_help
            ;;
        codex-help)
            codex_help
            ;;
        pi-help)
            pi_help
            ;;
        opencode-help)
            opencode_help
            ;;
        test)
            test_terminal
            ;;
        all)
            install_packages
            configure_all all
            test_terminal
            ;;
        help)
            usage
            ;;
    esac
}

main "$@"

