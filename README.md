# desk

Personal desktop environment for Arch Linux: floating windows and a Plasma/macOS feel on top of Hyprland (Lua config), with a custom Quickshell panel. Building blocks such as services, the lock screen and the window switcher come from a patched copy of [Caelestia shell](https://github.com/caelestia-dots/shell).

This is my own setup, shaped around my monitors and keyboards. It has no stable interface.

## Layout

There are two copies. The deployed one has `~/.config` as its work tree (git dir `~/.local/share/desk.git`), because Hyprland and Quickshell read their config from there; a fresh install clones it straight from GitHub. Only the paths in `desk_paths` in `desk/desk-update.sh` belong to it, and it is never edited by hand. Development happens in an ordinary clone in `~/projects/desk`: commit there, then `desk-deploy` pulls the commits into `~/.config` (no push needed), reloads Hyprland and restarts the shell. Push to GitHub when the change is good.

| Path | Purpose |
| --- | --- |
| `desk/` | Hyprland config, scripts, keyd config |
| `quickshell/desk/` | The shell: panel and `shell.qml` |
| `quickshell/caelestia/` | Submodule with the patched Caelestia copy |
| `ghostty/config` | Terminal config |
| `desk/icon-theme/Simpleton/` | Source of the icon theme. `install.sh` copies it to `~/.local/share/icons`, where `recolor-icons.sh` recolours it to match the colour scheme. Add new icons here too. |

Personal settings live outside git, in `~/.local/state/desk`: panel size and opacity, monitor layout, autostart, keyboard and mouse, panel pins and order, Night Shift and window positions. Defaults for a fresh install are in `desk/defaults/state`, and `start.sh` copies the missing ones at every login. They have no backup.

## Install

Requirements: Arch Linux, `git`, [yay](https://github.com/Jguer/yay), and an SSH key with access to the Caelestia submodule, which is currently a private repository.

Clone into `~/.config` (files in `~/.config` that also exist in the repository get overwritten):

```sh
git init -q -b main --separate-git-dir=$HOME/.local/share/desk.git $HOME/.config && cd $HOME/.config && git remote add origin git@github.com:JakubKrhovjak/desk.git && git fetch -q origin && git checkout -f -B main --track origin/main && git submodule update --init
```

Finish the setup:

```sh
~/.config/desk/install.sh
```

The script installs missing packages, prepares the submodule branches, builds the `hyprbars` plugin, adds the `Desk` login session and sets up keyd. Log out and back in afterwards, then pick `Desk` in the display manager.

### Manual steps

- Monitors: the Displays page in Nexus. It writes `desk/monitor-settings.lua` and goes back on its own unless you keep the changes.
- Keyboards: `desk/system/keyd/` is written for specific devices.
- Startup apps: `desk/autostart.json` can be edited in Nexus (Apps → app → Startup). A leading `~/` in a command is expanded.
- Colours: until Caelestia generates its scheme, Hyprland uses fallback colours from `desk/colours.lua`.
- Not restored from this repository: `~/.config/caelestia/shell.json`, `~/.config/caelestia/hypr-user.lua` and the `macOS Cmd` keymap for IntelliJ IDEA.

## Panel

Panel height and icon size are set in Nexus (Panels), or by right-clicking the panel. They are stored in `desk/panel-settings.json`.

An app with a tray icon lives only in the tray, unless you pin it to the panel. Clicking its icon shows or hides the window, and the close button in the title bar only hides it. `Super + Q` always closes the window.

## Colours

Nexus (Wallpaper & style → Colours) offers Simpleton, four warm pastel seasons and colours from the wallpaper. `desk/season-scheme.py` generates a scheme with Caelestia's own generator and sets the matching wallpaper. `desk/wallpapers/generate.py` draws the season wallpapers.

## Updating

```sh
desk-update
```

It runs `yay -Syu`, rebuilds `hyprbars` when it doesn't match the installed Hyprland and merges the installed Caelestia release into the patched copy. Both steps go by the current state, so they also catch up after a failed `yay` or an update run outside this script. It commits nothing in `~/.config`: the Caelestia merge happens in the working copy `~/projects/desk`, gets a commit there and is deployed with `desk-deploy`; pushing is up to you. Without a working copy (a fresh install) it merges in the deployed copy and does not push.

The keyd config in `desk/system/keyd/` is the source of truth. `desk-update` only warns when `/etc/keyd` differs, and `desk/system/install-keyd.sh` applies the repository copy.

Caelestia uses a vendor branch: `upstream` holds clean releases and `master` holds them with my changes. If a merge conflicts, it is aborted and the copy stays as it was, so you can resolve it by hand with `git -C ~/projects/desk/quickshell/caelestia merge upstream`.

`desk-update --hyprbars` only rebuilds the plugin.

Without the plugin, windows just lose their title bars and everything else keeps working.
