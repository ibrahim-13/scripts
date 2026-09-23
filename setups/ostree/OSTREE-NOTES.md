# OSTree / rpm-ostree on Fedora Atomic — research notes

Written 2026-09-23. Covers Fedora Atomic Desktops (Silverblue, Kinoite, Sway/Budgie/COSMIC
Atomic) on Fedora 44, plus what changes with bootc. The companion tool is a single
self-contained script, `~/test/ostree-mgr`, with three command groups: `pkg`, `layer`, `app`.

---

## 1. What "ostree" actually is

| Layer | Role |
|---|---|
| **ostree** | Git-like content store for whole OS filesystem trees. Each bootable tree is a *commit*; a checked-out, bootable commit is a *deployment*. Provides atomic upgrades and rollbacks. |
| **rpm-ostree** | Hybrid image/package client on top of ostree + libdnf. Pulls the base image, *layers* RPMs on top (client-side), manages deployments, kernel args, initramfs. This is the tool on every Fedora Atomic Desktop today. |
| **bootc** | Successor: the OS image is an OCI container image; ostree is still the on-disk backend. Fedora 41+ Atomic Desktop *bootc images* ship `bootc` + `dnf5` inside; Fedora 44 desktops installed from ISO still use rpm-ostree as the primary client. Full switch is planned after Fedora 45 (image-builder migration first). |
| **composefs** | Kernel-level read-only root (overlayfs + EROFS). Enabled by default for Atomic Desktops from Fedora 42 (CoreOS/IoT since 41). Makes `/` **truly** read-only, not just `chattr +i`. |

State machine you interact with:

```
 booted deployment (●)  ──rpm-ostree install/upgrade/rebase──▶  pending deployment (index 0, default next boot)
        ▲                                                          │ reboot
        └────────────── rollback deployment ◀──────────────────────┘
```

Default: **2 deployments kept** (current + rollback). A staged one makes 3 until reboot.
`ostree admin pin` protects a deployment from garbage collection.

---

## 2. Filesystem model — where writes work

| Path | Status | Notes |
|---|---|---|
| `/usr` | **read-only** (bind mount; kernel-enforced with composefs) | The whole image lives here (`/bin`, `/lib`, `/sbin` are symlinks into it). |
| `/etc` | writable, persistent | **3-way merge** on every deployment: new image defaults (`/usr/etc`) + your local changes. Files you *modified* win; files you *didn't touch* get the new default. |
| `/var` | writable, persistent, **never touched by upgrades** | Behaves like a Docker VOLUME: new image content under `/var` is NOT applied. Use `tmpfiles.d` for directory structure. |
| `/opt` → `/var/opt` | writable | Symlink. Installers writing to `/opt/<app>` work. |
| `/usr/local` → `/var/usrlocal` | writable | Symlink. `PREFIX=/usr/local` installs work. `/usr/local/bin` is in the default PATH; `/usr/local/share` is in `XDG_DATA_DIRS` (desktop files, icons, bash completions found). |
| `/home` → `/var/home`, `/root` → `/var/roothome`, `/srv` → `/var/srv`, `/mnt` → `/var/mnt` | writable | Homebrew at `/home/linuxbrew/.linuxbrew` works out of the box because `/home` is under `/var`. |
| Any **new top-level dir** (`/nix`, `/snap`, `/foo`) | **not possible** at runtime | `/` is read-only. Options: bind-mount from `/var` with `[root] transient=true` (§6.6), or build it into a custom bootc image. |
| `/boot`, `/sysroot` | managed by ostree | Don't write. `/sysroot` shows the real root; `/` appears "100% full, few MB" with composefs — that's normal. |

Bootc-specific knobs in `/etc/ostree/prepare-root.conf` (need reboot):

```ini
[composefs]
enabled = true        # or "verity"
[etc]
transient = true      # throw away /etc changes at each boot (stateless)
[root]
transient = true      # writable overlay on / until reboot — lets you mkdir /nix at boot via tmpfiles.d
```

Bootc also offers `systemctl enable ostree-state-overlay@opt.service` (persistent writable overlay
over `/opt` that gets reset by updates) — only relevant when `/opt` is a real dir in the image.

`dnf`/`dnf5` on a booted Atomic system prints an error pointing you to `rpm-ostree` (or to unlock).
`dnf` is meant for `Containerfile` builds of your own image.

---

## 3. Installing / uninstalling packages (`rpm-ostree`) — `ostree-mgr pkg`

Layering creates a **new deployment**; the change is live after a **reboot** (exception: `--apply-live`).

| Task | Command | Notes |
|---|---|---|
| Search | `rpm-ostree search TERM` | libdnf; uses `/etc/yum.repos.d` + `/usr/share/dnf5/repos.d` |
| Install | `rpm-ostree install PKG…` | Flags: `--idempotent` (no error if already requested), `--allow-inactive` (pkg already in base), `-r/--reboot`, `-n/--dry-run`, `-C/--cache-only`, `--download-only`, `--force-replacefiles`. |
| Install without reboot | `rpm-ostree install -A PKG` (`--apply-live`) | Adds to booted `/usr` via overlayfs **and** stages the deployment. Only *additions*; refuses if a pending deployment exists. |
| Local RPM | `rpm-ostree install ./foo.rpm` | Shows up as `LocalPackages`. URL → download first (script does this). |
| Uninstall layered | `rpm-ostree uninstall PKG…` | Also `--all`. Removing a **base** package is `override remove`, not `uninstall`. |
| Remove base pkg | `rpm-ostree override remove PKG` | e.g. drop `firefox` from image. Breaks upgrades if deps shift; use sparingly. |
| Replace base pkg | `rpm-ostree override replace RPM|URL` | Accepts Koji/Bodhi URLs — handy for testing a fixed build. |
| Undo overrides | `rpm-ostree override reset PKG…` / `--all` | |
| Where is a pkg from? | `rpm -q PKG` + `rpm-ostree status` | `status` shows `LayeredPackages`, `LocalPackages`, `RemovedBasePackages`, `ReplacedBasePackages`. `status -v` adds `InactiveRequests`. `status --json`, `-J <jsonpath>` for scripting. |
| Refresh metadata | `rpm-ostree refresh-md` | |
| Drop everything back to stock | `rpm-ostree reset [--overlays --overrides --initramfs]` | |
| Cancel running txn | `rpm-ostree cancel` | |

Third-party repos: copy the `.repo` file to `/etc/yum.repos.d/`. **`rpm --import` does not work
on a booted ostree** (rpmdb is read-only); instead put the key file in `/etc/pki/rpm-gpg/` and
point `gpgkey=file:///etc/pki/rpm-gpg/…` at it — all keys there are auto-trusted by rpm-ostree.
Known gotcha: a misconfigured `repo_gpgcheck` in third-party repos (Tailscale, VS Code) can break
GNOME Software; `ostree-mgr pkg repo add NAME URL --key URL` handles the key path rewrite.

**Guidance from Fedora/Bazzite docs:** layer only *system-level* things (drivers, VPN daemons,
`distrobox`, shells, `virt-manager`, codecs). Every layered package makes upgrades slower and
can block them when a dependency disappears from the image. For apps use Flatpak; for CLI/dev
tooling use `toolbox`/`distrobox`.

---

## 4. Deployments / layers / rollback — `ostree-mgr layer`

| Task | Command |
|---|---|
| Show deployments (boot order, ● = booted, first = next default) | `rpm-ostree status [-v]` |
| Upgrade | `rpm-ostree upgrade [--check | --preview | -r]` (`--unchanged-exit-77` for scripts) |
| Package diff booted → pending | `rpm-ostree db diff` (`db list`, `db version` too) |
| Roll back (swap default with previous) | `rpm-ostree rollback [-r]` |
| Deploy a specific version/commit | `rpm-ostree deploy 44.20260920.0` |
| Switch base image (keeps layers + /etc) | `rpm-ostree rebase fedora:fedora/45/x86_64/silverblue` or `rpm-ostree rebase ostree-image-signed:docker://quay.io/fedora/fedora-silverblue:45` |
| List branches | `ostree remote refs fedora` |
| Pin / unpin (survives cleanup) | `ostree admin pin 0` / `ostree admin pin --unpin 0`; INDEX may be a number or `booted`/`pending`/`rollback` |
| Free space / drop deployments | `rpm-ostree cleanup -p` (pending) `-r` (rollback) `-b` (transient base) `-m` (repo md cache) |
| Kernel args (new deployment) | `rpm-ostree kargs --append-if-missing=… --delete-if-present=… --replace=K=V=NEW --editor` |
| Local initramfs regen | `rpm-ostree initramfs --enable [--arg …]`; `initramfs-etc --track FILE` to bake /etc files in |
| Writable `/usr` for testing (gone at reboot) | `rpm-ostree usroverlay` (= `ostree admin unlock`) |
| Writable `/usr` that persists | `ostree admin unlock --hotfix` — clones the deployment; **the next `install`/`upgrade` creates a fresh deployment without the hotfix**. Emergency-only. |

Practical rules:
1. **Pin before risky changes** (`rebase`, `override remove`, kernel args): `ostree-mgr layer pin`.
2. Something staged you regret? `rpm-ostree cleanup -p` before rebooting.
3. Booted into a broken deployment? Pick the previous entry in GRUB, then `rpm-ostree rollback`.
4. Layered packages ride along with `upgrade`/`rebase`; they are re-applied on top of every new base.

---

## 5. Installing script-based applications — `ostree-mgr app`

Decision order (least invasive first):

1. **Flatpak** (GUI apps) — `flatpak install flathub …`. Untouched by ostree.
2. **Container + export** (CLI/dev tools): `toolbox create dev; toolbox enter` → `dnf install …`.
   `distrobox-export --bin /usr/bin/foo --export-path ~/.local/bin` or `--app foo` makes it
   look native. Toolbox has no exporter; a 2-line wrapper `exec toolbox run -c dev foo "$@"` does it.
3. **Run the installer with a writable prefix**: `PREFIX=/usr/local` or into `/opt/<app>`
   (both are `/var`). Most `install.sh`/`curl | sh` scripts honour `PREFIX`, `INSTALL_DIR`,
   `BIN_DIR` or similar; when they hard-code `/usr/bin`, rewrite with
   `sed 's#/usr/bin#/usr/local/bin#g'` (the rewriter in `ostree-mgr app run --rewrite` does this and
   keeps shebangs intact). User-level: `~/.local/bin`, `~/.local/opt`.
4. **Tarball / binary release**: unpack into `/var/opt/<app>` (visible as `/opt/<app>`), symlink
   binaries into `/usr/local/bin`.
5. **AppImage**: drop in `~/.local/bin`, write a `.desktop` in `~/.local/share/applications`.
   **Fedora 44 images removed FUSE2**; older AppImages need `APPIMAGE_EXTRACT_AND_RUN=1`
   (or `--appimage-extract-and-run`), or layer `fuse-libs` (`ostree-mgr pkg install fuse-libs`).
6. **RPM layering** if the vendor ships an RPM/repo (Tailscale, VS Code, Docker CE, 1Password).
7. **`usroverlay`** only to *test*; `--hotfix` only for emergencies.
8. **Custom image** (bootc `Containerfile` FROM `quay.io/fedora/fedora-silverblue:44` +
   `RUN dnf install …`, then `rpm-ostree rebase ostree-unverified-registry:…`) when you want
   many changes reproducibly. Universal Blue / BlueBuild are the ecosystem around this.

Things that break and the fix:

| Symptom | Cause | Fix |
|---|---|---|
| `mkdir: cannot create directory '/usr/bin/…': Read-only file system` | writes under `/usr` | PREFIX / rewrite → `/usr/local` |
| `mkdir /nix: Read-only file system` | new top-level dir | `[root] transient=true` + `tmpfiles.d` `d /nix` + `nix.mount` binding `/var/lib/nix` (`ostree-mgr app bindmount`), or put it in a custom image |
| `rpm --import` fails / `error: can't create transaction lock` | rpmdb is read-only | key file into `/etc/pki/rpm-gpg` |
| `dnf: not supported on ostree` | host dnf refuses | `rpm-ostree install`, or do it inside toolbox |
| `dlopen(): libfuse.so.2` from an AppImage | FUSE2 gone in F44 | `APPIMAGE_EXTRACT_AND_RUN=1` or layer `fuse-libs` |
| Installer adds a systemd unit to `/usr/lib/systemd/system` | read-only | put it in `/etc/systemd/system` (writable) — works normally; udev rules → `/etc/udev/rules.d`, polkit → `/etc/polkit-1/rules.d`, profile → `/etc/profile.d` |
| Kernel module (VirtualBox, NVIDIA, v4l2loopback) | needs build against image kernel | layer `akmods` + `kmod-*` from RPM Fusion, or use a custom image that ships them |
| Homebrew | wants `/home/linuxbrew` | just works (`/home` → `/var/home`); needs `gcc`-less path or layer `gcc`/`procps-ng` if it asks |

`ostree-mgr app` records every file an installer created (mtime marker + `find -newer` over
`/usr/local`, `/var/opt`, `/etc/systemd/system`, `~/.local/…`) into
`/var/lib/ostree-app/<name>.manifest` (or `~/.local/state/ostree-app/`) so `ostree-mgr app uninstall`
can remove it — the missing piece with vendor `install.sh` scripts.

---

## 6. Script reference (`~/test/ostree-mgr`)

One file, no dependencies beyond bash + coreutils/grep/sed/awk/find. Usage:
`ostree-mgr [-n] [-y] <group> <command> [args]`; `ostree-mgr -h` for the overview,
`ostree-mgr <group> -h` for a group. `-n` prints the commands without running them, `-y` answers
yes to every confirmation. Every mutating action asks `[y/N]` first. On a non-ostree host it
refuses to run unless `OSTREE_FORCE=1` or `-n`.

### 6.1 `ostree-mgr pkg`
```
ostree-mgr pkg search htop
ostree-mgr pkg install htop --live            # rpm-ostree install --idempotent -A htop
ostree-mgr pkg install ./foo.rpm https://…/bar.rpm
ostree-mgr pkg uninstall htop --reboot
ostree-mgr pkg list                           # layered / local / removed / replaced of booted tree
ostree-mgr pkg info firefox                   # BASE IMAGE vs LAYERED
ostree-mgr pkg override remove firefox ; ostree-mgr pkg override reset firefox
ostree-mgr pkg repo add tailscale https://pkgs.tailscale.com/stable/fedora/tailscale.repo \
                    --key https://pkgs.tailscale.com/stable/fedora/repo.gpg
ostree-mgr pkg repo list | repo remove tailscale
ostree-mgr pkg refresh
```

### 6.2 `ostree-mgr layer`
```
ostree-mgr layer status | pending | diff
ostree-mgr layer upgrade [--check|--preview|--reboot]
ostree-mgr layer rollback [--reboot]
ostree-mgr layer deploy 44.20260920.0
ostree-mgr layer rebase fedora:fedora/45/x86_64/silverblue
ostree-mgr layer branches silverblue
ostree-mgr layer pin            # pins the booted deployment (index computed from status)
ostree-mgr layer unpin 1
ostree-mgr layer cleanup -b -m  | cleanup -p | cleanup all
ostree-mgr layer reset [--overlays] [--overrides] [--initramfs]
ostree-mgr layer kargs show | append quiet | delete quiet | replace foo=1=2
ostree-mgr layer unlock [--hotfix]
ostree-mgr layer space
```

### 6.3 `ostree-mgr app`
```
ostree-mgr app check https://example.com/install.sh          # report READ-ONLY / TOP-LEVEL / PKG-MGR / GPG / FUSE hits
ostree-mgr app run   https://example.com/install.sh --rewrite --name foo -- --some-installer-flag
ostree-mgr app run   ./install.sh --user                     # PREFIX=~/.local
ostree-mgr app tarball lazygit https://…/lazygit.tar.gz --bin lazygit
ostree-mgr app appimage ./Obsidian-1.8.AppImage --name obsidian
ostree-mgr app container dev --export gcc make -- sudo dnf install -y gcc make
ostree-mgr app bindmount /var/lib/nix /nix
ostree-mgr app list ; ostree-mgr app uninstall foo
```

### 6.4 Testing without an Atomic host
The scripts were exercised on this Fedora 44 Server VM with stub `rpm-ostree`/`ostree`/`rpm`/
`toolbox` binaries on `PATH` plus `OSTREE_FORCE=1`, and with a throw-away `$HOME` for the
`--user` paths (`run`, `tarball`, `appimage`, `container`, `list`, `uninstall` all round-tripped).
Real rpm-ostree behaviour (reboot requirements, --apply-live limits) is documented above but
was not executed here.

---

## 7. Sources
- rpm-ostree administrator handbook: https://coreos.github.io/rpm-ostree/administrator-handbook/
- rpm-ostree(1): https://www.mankier.com/1/rpm-ostree
- ostree deployment model: https://ostreedev.github.io/ostree/deployment/ ; adapting existing systems (symlinks into /var): https://ostreedev.github.io/ostree/adapting-existing/
- `ostree admin pin`: https://ostreedev.github.io/ostree/man/ostree-admin-pin.html ; `ostree admin unlock`: https://ostreedev.github.io/ostree/man/ostree-admin-unlock.html
- bootc filesystem docs (/opt, /usr/local, state overlays, transient root): https://bootc.dev/bootc/filesystem.html
- Fedora change: composefs for Atomic Desktops: https://fedoraproject.org/wiki/Changes/ComposefsAtomicDesktops
- Fedora change: DNF and bootc in image-mode Fedora: https://fedoraproject.org/wiki/Changes/DNFAndBootcInImageModeFedora
- What's new, Fedora Atomic Desktops 41 / 42 / 43 / 44: https://tim.siosm.fr/blog/2024/10/30/fedora-atomic-desktops-41/ , https://fedoramagazine.org/whats-new-for-fedora-atomic-desktops-in-fedora-42/ , https://fedoramagazine.org/whats-new-fedora-atomic-desktops-in-fedora-linux-43/ , https://tim.siosm.fr/blog/2026/04/28/fedora-atomic-desktops-44/
- Building your own Atomic (bootc) desktop: https://fedoramagazine.org/building-your-own-atomic-bootc-desktop/
- Bazzite docs on package layering (when to layer): https://docs.bazzite.gg/Installing_and_Managing_Software/rpm-ostree/
- usroverlay article proposal: https://discussion.fedoraproject.org/t/article-proposal-using-rpm-ostree-usroverlay-to-overridde-files-on-usr-on-ostree-systems/46776
- Tailscale on Silverblue (repo + gpg gotcha): https://github.com/tailscale/tailscale/issues/5582 , https://snikt.net/blog/2025/04/07/using-tailscale-on-fedora-silverblue/
- Nix on ostree (bind mount / root.transient): https://discussion.fedoraproject.org/t/making-nix-on-ostree-fedora-work/98228 , https://github.com/DeterminateSystems/nix-installer/issues/783
- distrobox-export: https://distrobox.it/usage/distrobox-export/
- Silverblue lessons (real-world workarounds): https://b.libdb.so/silverblue-lessons/
