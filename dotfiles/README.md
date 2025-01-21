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

## tmux