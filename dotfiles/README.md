# Environment Setup

## Index

- [nerd-font](#nerd-font)
- [lf](#lf)
- [fzf](#fzf)
- [nvim](#nvim)
- [tmux](#tmux)

## nerd-font

- [ryanoasis/nerd-fonts/](https://github.com/ryanoasis/nerd-fonts/)

### Mononoki

- Go to the release page of nerd-fonts
- Download Mononoki.zip/Mononoki.tar.xz
- Extract
- Install the font
  - MacOs: use Font Book

## lf

- [Github](https://github.com/gokcehan/lf)
- [docs](https://github.com/gokcehan/lf/blob/master/doc.md)
- [wiki](https://github.com/gokcehan/lf/wiki)

### Setup

Configuration directory

```
OS       system-wide               user-specific
Unix     /etc/lf/lfrc              ~/.config/lf/lfrc
Windows  C:\ProgramData\lf\lfrc    C:\Users\<user>\AppData\Local\lf\lfrc
```

You can configure these locations with the following variables given with their order of precedences and their default values:

```
Unix
    $LF_CONFIG_HOME
    $XDG_CONFIG_HOME
    ~/.config

    $LF_DATA_HOME
    $XDG_DATA_HOME
    ~/.local/share

Windows
    %ProgramData%
    C:\ProgramData

    %LF_CONFIG_HOME%
    %LOCALAPPDATA%
    C:\Users\<user>\AppData\Local
```

## fzf

- [Github](https://github.com/junegunn/fzf)

### Files and directories
Fuzzy completion for files and directories can be triggered if the word before the cursor ends with the trigger sequence, which is by default **.

COMMAND [DIRECTORY/][FUZZY_PATTERN]**<TAB>

```
# Files under the current directory
# - You can select multiple items with TAB key
vim **<TAB>

# Files under parent directory
vim ../**<TAB>

# Files under parent directory that match `fzf`
vim ../fzf**<TAB>

# Files under your home directory
vim ~/**<TAB>


# Directories under current directory (single-selection)
cd **<TAB>

# Directories under ~/github that match `fzf`
cd ~/github/fzf**<TAB>
```

### Process IDs
Fuzzy completion for PIDs is provided for kill command.

```
# Can select multiple processes with <TAB> or <Shift-TAB> keys
kill -9 **<TAB>
```

### Host names
For ssh and telnet commands, fuzzy completion for hostnames is provided. The names are extracted from /etc/hosts and ~/.ssh/config.

```
ssh **<TAB>
telnet **<TAB>
```

### Environment variables / Aliases

```
unset **<TAB>
export **<TAB>
unalias **<TAB>
```

### Customizing fzf options for completion

```
# Use ~~ as the trigger sequence instead of the default **
export FZF_COMPLETION_TRIGGER='~~'

# Options to fzf command
export FZF_COMPLETION_OPTS='--border --info=inline'

# Options for path completion (e.g. vim **<TAB>)
export FZF_COMPLETION_PATH_OPTS='--walker file,dir,follow,hidden'

# Options for directory completion (e.g. cd **<TAB>)
export FZF_COMPLETION_DIR_OPTS='--walker dir,follow'

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments ($@) to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'tree -C {} | head -200'   "$@" ;;
    export|unset) fzf --preview "eval 'echo \$'{}"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview 'bat -n --color=always {}' "$@" ;;
  esac
}
```

## nvim

- [NeoVim - Starting](https://neovim.io/doc/user/starting.html)
- [NeoVim - Buildin](https://neovim.io/doc/user/builtin.html)

Configuration directory:

```
CONFIG DIRECTORY (DEFAULT)
                  $XDG_CONFIG_HOME            Nvim: stdpath("config")
    Unix:         ~/.config                   ~/.config/nvim
    Windows:      ~/AppData/Local             ~/AppData/Local/nvim
DATA DIRECTORY (DEFAULT)
                  $XDG_DATA_HOME              Nvim: stdpath("data")
    Unix:         ~/.local/share              ~/.local/share/nvim
    Windows:      ~/AppData/Local             ~/AppData/Local/nvim-data
RUN DIRECTORY (DEFAULT)
                  $XDG_RUNTIME_DIR            Nvim: stdpath("run")
    Unix:         /tmp/nvim.user/xxx          /tmp/nvim.user/xxx
    Windows:      $TMP/nvim.user/xxx          $TMP/nvim.user/xxx
STATE DIRECTORY (DEFAULT)
                  $XDG_STATE_HOME             Nvim: stdpath("state")
    Unix:         ~/.local/state              ~/.local/state/nvim
    Windows:      ~/AppData/Local             ~/AppData/Local/nvim-data
CACHE DIRECTORY (DEFAULT)
                  $XDG_CACHE_HOME             Nvim: stdpath("cache")
    Unix:         ~/.cache                    ~/.cache/nvim
    Windows:      ~/AppData/Local/Temp        ~/AppData/Local/Temp/nvim-data
LOG FILE (DEFAULT)
                  $NVIM_LOG_FILE              Nvim: stdpath("log")/log
    Unix:         ~/.local/state/nvim         ~/.local/state/nvim/log
    Windows:      ~/AppData/Local/nvim-data   ~/AppData/Local/nvim-data/log
Note that stdpath("log") is currently an alias for stdpath("state").
ADDITIONAL CONFIGS DIRECTORY (DEFAULT)
                  $XDG_CONFIG_DIRS            Nvim: stdpath("config_dirs")
    Unix:         /etc/xdg/                   /etc/xdg/nvim
    Windows:      Not applicable              Not applicable
ADDITIONAL DATA DIRECTORY (DEFAULT)
                  $XDG_DATA_DIRS              Nvim: stdpath("data_dirs")
    Unix:         /usr/local/share            /usr/local/share/nvim
                  /usr/share                  /usr/share/nvim
    Windows:      Not applicable              Not applicable
```
Configuration entrypoint:

```
Unix			    ~/.config/nvim/init.vim		    (or init.lua)
Windows     		~/AppData/Local/nvim/init.vim	(or init.lua)
$XDG_CONFIG_HOME  	$XDG_CONFIG_HOME/nvim/init.vim	(or init.lua)
```

Clean cache data

```sh
rm -rf "$HOME/.config/nvim"
rm -rf "$HOME/.local/share/nvim"
rm -rf "$HOME/.local/state/nvim"
```

```bat
rmdir /s /q "%LOCALAPPDATA%/nvim"
rmdir /s /q "%USERPROFILE%\AppData\Local\nvim-data"
```

## tmux

Configuration directory

```
Configuratin:   $HOME/.config/tmux
Plugin:         $HOME/.tmux/plugins/tpm
```

- Setup plugin

```sh
# git is required
git clone "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"
```