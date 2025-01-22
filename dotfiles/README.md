# Environment Setup

## Index

- [lf](#lf)
- [nvim](#nvim)
- [tmux](#tmux)

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

Check if binary executable exists:

```lua
local function rg_exists()
  return vim.fn.executable('rg') == 1
end

if rg_exists() then
  print("ripgrep is installed and available in the PATH")
else
  print("ripgrep is not installed or not available in the PATH")
end


```

## tmux