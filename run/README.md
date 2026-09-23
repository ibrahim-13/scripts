# run — one place for all my shell procedures

Shell procedures for VMs and hosts across distros (Fedora/RHEL, Debian/Ubuntu, Arch, SUSE, Alpine,
macOS/Homebrew): shared code in `lib/`, one file per procedure in `cmd/`, a live-filtering picker,
tab completion, single-file bundles for remote hosts. Pure bash >= 4.4 plus coreutils, no
third-party binaries; `ssh` only for `run remote`, `systemd-detect-virt` only for role detection.
After any change: `bash -n <file>` and `run selftest`.

Install: `~/.bashrc.d/run.sh` sets `RUN_HOME`, adds `bin/` to PATH and sources
`completions/run.bash` in interactive shells. New shells have it; current one: `source ~/.bashrc.d/run.sh`.

## Use

    run                          live picker: type to filter, Up/Down, Enter runs, Esc cancels
    Ctrl-G                       same picker inside the prompt; inserts "run <cmd> " at the cursor
    run v<TAB>                   completion with descriptions; a command's flags come from the script
    run flatpak/install chrome vlc   run a command with arguments   (also: run flatpak install ...)
    run gh/install lf fzf        catalog commands complete their names: run gh/install <TAB>
    run list                     everything with summary and role
    run search disk network      grep the index: commands AND library functions, any term matches
    run help vm/setup            a command's header;  run help  alone lists the verbs
    run bundle vm/setup          one self-contained script (libs+steps inlined): bash -s -- ARGS < it
    run remote myvm vm/setup     the bundle executed over ssh (myvm needs bash; Alpine: apk add bash)
    run -y os/upgrade            skip the "Run os/upgrade? [y/N]" question (same as RUN_YES=1)
    run root | run index | run selftest      resolved location | force index rebuild | tests

Every command asks `Run <cmd> ARGS? [y/N]` before `main` runs, showing its summary (and its
steps for a group; a group asks once, its steps skip the gate but still ask their own `confirm`
questions). `-y`/`RUN_YES=1` means yes to everything: no gate, `confirm` returns yes, `ask`
returns its default, package managers run with `-y`. `DRY_RUN=1` never asks. Without a terminal
the command dies with a hint instead of hanging. `run remote` asks locally and forwards the
passed gate plus `RUN_YES`/`DRY_RUN`/`RUN_FORCE` to the remote shell.

| Variable  | Read by            | Meaning                                                            |
|-----------|--------------------|--------------------------------------------------------------------|
| DRY_RUN   | your `main()`      | print instead of act — a convention: check it before anything destructive |
| RUN_YES   | run_main, confirm, ask, pkg_* | yes to everything (`run -y`)                            |
| RUN_CONFIRMED | run_main       | internal: gate already passed (set by run_cmd for steps, `run remote`, and after a yes) |
| RUN_FORCE | os_require_role    | wrong role becomes a warning                                       |
| RUN_ROLE  | os_detect          | force `vm`, `host` or `container` (testing)                        |
| PICK_ROWS | tools/pick.sh      | picker height, default 12; keep below the terminal height (redraw moves the cursor up) |
| PICK_TTY  | tools/pick.sh      | terminal device (tests)                                            |
| RUN_HOME  | ~/.bashrc.d/run.sh | where the tree is — the only place outside the tree that knows     |

`RUN_ROOT`/`RUN_LIB`/`RUN_CMD` are outputs of the loader (exported for tools); setting them has
no effect. `need_root` preserves `DRY_RUN`, `RUN_FORCE`, `RUN_ROLE`, `RUN_YES`, `RUN_CONFIRMED`
across sudo (the gate exports `RUN_CONFIRMED=1` once answered, so a re-exec does not ask twice).

## Layout and flow

    bin/run                dispatcher: the verbs above, else resolve cmd/<ns>/<name>.sh and exec it
    cmd/<ns>/<name>.sh     one procedure per file; directories are namespaces:
                             os/ (hostname, rtc, fonts, bluetooth, wifi module, upgrade)
                             system/ (install <tools>, github-cli, virt-manager, firefox-uninstall, neovim-reset)
                             fedora/ (rpmfusion-repo/-packages, ffmpeg, dnf-conf, ghostty)   debian/ (sources-trixie)
                             flatpak/ (flathub, install <apps>, vscodium-extensions)   gh/ (install lf fzf helium rclone, update)
                             dev/ (apps-path, yt-dlp, golang, nvm-node, claude-cli)   mac/ (dmg-install, lulu)
                             vm/ (setup*, dev-apps*, mount, resize-disk, xorg, awesome-xinit, ...)   logs/ (view)   * = group
    lib/loader.sh          `use`, header parsing — the only file scripts source directly
    lib/core.sh            log warn die have dry confirm confirm_do ask ask_required require_known refuse_root
                           tmpdir need_root run_cmd run_main
    lib/os.sh              os_detect (OS_ID OS_FAMILY OS_ROLE), os_dispatch, os_require_family, os_require_role
    lib/pkg.sh             pkg_install/remove/refresh/update/clean/group_install, pkg_install_for, pkg_repo_has,
                           dnf_copr_enable — per-family implementations inside; -y only under RUN_YES
    lib/fs.sh              line_exists append_once write_file bashrc_add_path fstab_add mount_exists ensure_unmounted expand_path
    lib/dl.sh              dl_to dl_print gh_release_json gh_latest_tag gh_latest_created_at gh_asset_url sys_os sys_arch
    lib/apps.sh            ~/apps + state files: apps_init/installed/current/mark/migrate, app_update (GitHub release flow)
    lib/svc.sh             svc_active svc_start svc_enable svc_enable_now
    tools/index.sh         headers -> .cache/index.tsv        tools/pick.sh      the live filter
    tools/bundle.sh        libs+steps -> one script           tools/selftest.sh  `run selftest`
    completions/run.bash   tab completion + Ctrl-G widget     .cache/            generated, git-ignored

`run vm/mount -l share -m /mnt/shared`: `bin/run` locates itself, sources `../lib/loader.sh`
(which sets `RUN_ROOT/RUN_LIB/RUN_CMD` from *its* location), resolves `cmd/vm/mount.sh` (one
word `vm/mount` or two words `vm mount`) and `exec`s it. The script is a plain executable,
identical when run directly, via a symlink or via `run`: it sources the loader relative to its
own file, `use core os pkg` sources each library once (dependencies first), and `run_main "$@"`
confirms and calls `main` only if the file was executed, not sourced.

Relocation: `mv` the tree anywhere; only `RUN_HOME` must follow (then open a new shell: the
completion file captures the root when sourced). Every entry point (bin/run, lib/loader.sh,
tools/*.sh, cmd/*/*.sh, completions/run.bash) finds the tree with
`readlink -f "${BASH_SOURCE[0]}"` — never `$0` in a sourced file, never cwd or PATH, never an
environment fallback (the loader overwrites inherited `RUN_*`), never a hard-coded path.
`run root` shows the result; the self-test copies the tree elsewhere and checks it.

The commands were ported from `~/projects/scripts/setups` (apps-mgr, ghapps-mgr, mcapps-mgr,
vm-setup, vm-apps, vm-mount, vm-resize, log-viewer). Helpers those scripts each carried their own
copy of (print_*, prompt_confirmation, line_exists, curl/wget download, GitHub tag lookup,
get_machine/get_arch, ~/apps state files) now exist once in `lib/`. The menu scripts became
catalog commands with completion (`system/install`, `flatpak/install`, `gh/install`) and the
multi-question setup scripts became groups (`vm/setup`, `vm/dev-apps`) whose steps run alone
too. State files under `~/apps` are read where the old scripts left them (`state/*.gh.state`;
`ytdlp.tag`/`golang.tag` are migrated into `state/` on first use). Nothing needs `gum` or `jq`.

## Writing a command

    #!/usr/bin/env bash
    # @summary  One line shown by list, search, the picker and completion
    # @usage    run <ns>/<name> [--flag] [ARG]
    # @tags     words search and the picker match on
    # @roles    vm
    # @needs    core os pkg
    # @complete --flag
    set -euo pipefail
    source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
    complete_hook() { echo dynamic-candidate; }           # optional
    main() { os_require_role vm; pkg_install curl git; }   # pkg_* and dry honour DRY_RUN themselves
    run_main "$@"

- New namespace = new directory. Not allowed as namespace names (the dispatcher's verbs win):
  `list ls search s help h pick index bundle remote root selftest`. Depth is fixed at two
  (`../../lib` in the source line); adjust that path for a deeper layout.
- Header (`_run_header_field`, lib/loader.sh) = the comment/blank lines from the top to the first
  code line (`set -euo pipefail` included); anything after is invisible to help/search/
  completion/bundle. A field is `# @name value` on one line; a repeated field gives several
  lines; leading whitespace is trimmed.
  - `@summary` required, shown by list/search/picker/completion. `@usage` free text for `run help`.
    `@tags` extra words for search and the picker.
  - `@roles` `vm`, `host`, `container` (several allowed; omitted = `any`). Documentation and
    search data only — enforcement is `os_require_role vm` in `main`.
  - `@needs` every library whose functions the script calls directly. `use` loads exactly these
    (plus their own `@needs`) and the bundler inlines exactly these: a missing one works
    locally and fails bundled.
  - `@complete` static argument completions; define `complete_hook` for dynamic ones.
  - `@steps` groups only: every command run with `run_cmd`.
- Keep the `source ... loader.sh; use ...` line exactly: one line starting with `source` — the
  bundler removes it by that pattern (the trailing `; use ...` goes with it, intended). Keep
  `run_main "$@"` on its own line. Do not use `$0` inside `main` (in a bundle `$0` is `bash`).
- `chmod +x`; check with `bash -n`, `run help <ns>/<name>`, `run list` (the index refreshes
  itself), `DRY_RUN=1 run <ns>/<name>`.

## Command groups

    # @needs core os pkg
    # @steps fedora/rpmfusion-repo
    main() { os_require_family dnf; run_cmd fedora/rpmfusion-repo; pkg_install ffmpeg; }   # cmd/fedora/ffmpeg.sh

- `run_cmd <ns>/<name> [ARGS]` logs `step: ...`, runs the step with `RUN_CONFIRMED=1` (the group
  was confirmed as a whole; the step's own `confirm` questions still ask), returns its status; steps run in call order. Locally a step is a child
  process (its `set -e`, functions and variables stay private; exported `DRY_RUN`, `RUN_ROLE`,
  `RUN_FORCE` are inherited). Under the group's `set -e`
  the first failure aborts the group with the step's status; optional step:
  `run_cmd x/y || warn "x/y failed, continuing"`.
- `@steps` must list every step: it is what `run help` shows and what the bundler inlines.
  `run selftest` lints literal `run_cmd <id>` calls against it and checks each listed step
  exists; a computed id must be listed by hand.
- Groups nest; the bundler collects `@steps` recursively (inner first, each once). A cycle
  terminates but is a mistake. Steps keep their own role checks; give the group one too when it
  only makes sense on one role, so it stops before running half the steps.
- Bundled, each step becomes `__step_<id>() ( <step file minus shebang, loader line, run_main
  line>; main "$@" )` and `run_cmd` calls that function when it exists, so `bundle`/`remote`
  work without the tree. A step missing from `@steps` shows only when the bundle runs:
  `run_cmd: no such command 'x/y' (in a bundle: add it to '# @steps')`. Ids become function
  names by replacing non-alphanumerics with `_`, so `a-b` and `a_b` would collide.
- Examples: `vm/setup`, `vm/dev-apps`, `gh/update`, `fedora/ffmpeg`, `mac/lulu`.

## Libraries, distros, roles

- `lib/<topic>.sh`, loaded with `use <topic>`. Header: `# @summary`, `# @needs` (usually
  `core`). The loader sets its guard before sourcing, so cycles terminate — avoid them anyway.
- Functions and constants only: no top-level commands, no `set -e`, no `exit` outside `die`
  (`die [-c CODE] MSG`); the caller decides on errors. Never read files from the tree at
  runtime (bundles run without it) — embed data in the function. Anything with side effects
  goes through `dry` (or checks `DRY_RUN` itself) so `DRY_RUN=1` stays safe.
- Before writing a helper inside a command, check `run search <word>`: a procedure used twice
  belongs in `lib/`. Existing ones cover packages per family (`pkg_install_for "dnf:a b" "apt:c"`),
  services (`svc_*`), confirm-then-run (`confirm_do`), catalogs (`require_known`), files
  (`append_once`, `write_file`, `bashrc_add_path`), downloads and GitHub releases (`dl_*`,
  `gh_*`, `app_update`).
- `## name ARGS -> what it does` directly above a public function becomes its description in
  `run search`. Names starting with `_` or containing `__` are hidden (private / per-distro).
- Distro-specific behaviour: one public function that dispatches,
  `thing() { os_dispatch thing "$@"; }` with `thing__dnf`, `thing__apt`, `thing__default`.
  `os_dispatch` tries `thing__<OS_ID>` (e.g. `thing__fedora`, an exception inside its family),
  then `thing__<OS_FAMILY>`, then `thing__default`, and dies naming the function to write.
- New family (a package manager the toolkit has never seen): add a pattern to the `case` in
  `os_detect` (lib/os.sh) mapping `ID`/`ID_LIKE` words to a family name (`dnf apt pacman zypper
  apk brew`; macOS is detected by `uname` and is always a host), then write
  `pkg_install/pkg_remove/pkg_update__<family>` and any other `*__<family>` the commands need. Derivatives that already match via `ID_LIKE` (Rocky -> rhel, Mint ->
  ubuntu debian) need nothing. Test without the distro: export `OS_ID=alpine OS_FAMILY=apk
  OS_ROLE=vm`, define `sudo() { echo "[sudo] $*"; }` (pattern in tools/selftest.sh).
- Roles: `os_detect` sets `OS_ROLE` from `systemd-detect-virt` (container > vm > host), else the
  `hypervisor` CPU flag; `RUN_ROLE` overrides. `RUN_FORCE=1` turns a refusal into a warning.
- Moving a function between libraries: update every `@needs` that named the old one
  (`run search <fn>` shows where it lives, `grep -rl <fn> cmd lib` who uses it).

## Internals

- **Index** (`tools/index.sh` -> `.cache/index.tsv`): columns `kind id summary tags roles file`;
  `kind` is `cmd` or `fn`, fn rows carry `lib:<topic>` as tags. Rebuilt when any `cmd/**/*.sh`
  or `lib/*.sh` is newer than the index; `run index` forces it (needed after a `git checkout`
  moves mtimes backwards). Written to a temp file and renamed, so readers never see a partial
  index. `.cache/` is created on demand and git-ignored.
- **Completion** (`completions/run.bash`): word 1 from the index. Several matches are shown as
  `id  - summary` (bash cannot show descriptions); readline inserts only the common prefix,
  which equals the ids' common prefix, so the typed text stays clean; one match returns the
  bare id. Do not bind TAB to `menu-complete` for `run` — it would insert the description
  (`show-all-if-ambiguous` and `completion-ignore-case` are fine). Word 2+: `<script>
  --complete <words-so-far>` runs; `run_main` prints the `@complete` words, then
  `complete_hook`'s output. `complete_hook` gets the words after the command name, prints one
  candidate per line, must be fast and side-effect free (it runs on every Tab). Not a command
  => filename completion. Ctrl-G is `bind -x` + `READLINE_LINE`/`READLINE_POINT`; change the
  key in the file's last line; it replaces readline's default `abort` (a bell) on Ctrl-G.
- **Picker** (`tools/pick.sh`): TSV on stdin, first column returned; draws on `/dev/tty`
  (`PICK_TTY`), so it works in `$(...)` and `bind -x`. Exit 0 chosen, 1 Enter with no match,
  2 no terminal, 130 cancelled; `bin/run` refuses to start it without a terminal (keep that
  guard, or a cron job would run the first entry). Keys are in the file header. Match = AND of
  case-insensitive substrings over the whole line. Fuzzy variant, noisy without ranking beyond
  a few dozen entries — replace the test in `filter()` with:

      g="*${t//?/&*}"; g=${g//\*\*/*}      # "vmp" -> "*v*m*p*"
      [[ $l == $g ]] || { ok=0; break; }

- **Bundle** (`tools/bundle.sh`): shebang, `set -euo pipefail`, no-op `use`, `RUN_BUNDLE_ID/
  _SUMMARY/_STEPS` (the prompt cannot read a header from `$0` in a bundle), `_run_header_field`, libraries in dependency order (depth-first over `@needs` of the command
  and of every step, each once), one `__step_<id>()` per step (recursive, inner first), then the
  command minus shebang and loader line. `run remote HOST cmd ARGS` pipes it into
  `ssh HOST bash -s -- ARGS` with `%q`-quoted arguments. `run_main` runs `main` when
  `BASH_SOURCE[1]` is empty (the stdin case). A bundle is also sourceable: `source bundle.sh`
  defines everything and runs nothing.

## Testing and git

`run selftest` (tools/selftest.sh; no network, installs nothing, `DRY_RUN=1` throughout) checks
the real tree — syntax, every command listed with a summary, `@needs`/`@steps` lint, every
command bundled and parsed — then behaviour against a relocated copy with throw-away fixture
commands under `cmd/t/`: dispatch, help, roles, `use` guards, distro dispatch with fake OS
variables, library helpers, header parsing, both completion levels and `--complete`, bundles
(run from `/` with an empty environment, sourced, unknown step/library errors), remote quoting
with a fake `ssh`, groups (order, arguments, abort status, nesting, undeclared steps),
relocation with poisoned `RUN_*`, the no-terminal guard, the confirmation prompt (skip rules,
decline, accept, once per group, inner questions, injected facts in a bundle, forwarding by
`run remote`), and the picker through a pty (`script(1)` or python3's `pty`; skipped if
neither exists). Because behaviour tests use fixtures, adding or removing real commands never
breaks them. Add a check for every bug you fix. Tab display and Ctrl-G are tested
by hand in a new shell. `shellcheck` is optional; `# shellcheck disable` marks intentional word
splitting.

Git: `.cache/` is ignored. Commit command/library changes together with the `@needs`/`@steps`
updates they imply, and run `run selftest` first.

## Pitfalls

- `local a=$x b=$a` sees the OLD `$a` (all words of a builtin are expanded first): two statements.
- A `# @field` after the first code line is silently ignored.
- `readlink -f` is required: `dirname "$0"` breaks for symlinked commands and for sourced files.
- Under `set -u`, `BASH_SOURCE[1]` is unset for scripts on stdin: write `${BASH_SOURCE[1]:-}`.
- `__` in a function name hides it from search by design; ordinary names use one underscore.
- `git clone` does not create `.cache/`; the indexer does. Never commit it.
- A group that works locally but fails remotely has a `run_cmd` target missing from `@steps`.
- `usage()` in bin/run is an unquoted heredoc (so `$RUN_ROOT` expands): no backticks or `$(...)` in it.
