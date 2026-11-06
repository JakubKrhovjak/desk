# desk

Personal desktop environment for Arch Linux: floating windows and a Plasma/macOS feel on top of Hyprland (Lua config), with a custom Quickshell panel. Building blocks such as services, the lock screen and the window switcher come from a patched copy of [Caelestia shell](https://github.com/caelestia-dots/shell).

This is my own setup, shaped around my monitors and keyboards. It has no stable interface.

## Layout

The repository's work tree is `~/.config`, and only the paths listed in `desk_paths` in `desk/desk-update.sh` are ever committed.

| Path | Purpose |
| --- | --- |
| `desk/` | Hyprland config, scripts, keyd config |
| `quickshell/desk/` | The shell: panel and `shell.qml` |
| `quickshell/caelestia/` | Submodule with the patched Caelestia copy |
| `ghostty/config` | Terminal config |

Panel pins and order, Night Shift settings and window positions live outside git, in `~/.local/state/desk`. They have no backup, so a fresh install starts with defaults.

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

- Monitor names: `monitors` in `desk/config.lua`.
- Keyboards: `desk/system/keyd/` is written for specific devices.
- Startup apps: `desk/autostart.json` can be edited in Nexus (Apps → app → Startup). A leading `~/` in a command is expanded.
- Icons: the Simpleton theme in `~/.local/share/icons` is not part of this repository.
- Colours: until Caelestia generates its scheme, Hyprland uses fallback colours from `desk/colours.lua`.
- Not restored from this repository: `~/.config/caelestia/shell.json`, `~/.config/caelestia/hypr-user.lua` and the `macOS Cmd` keymap for IntelliJ IDEA.

## Panel

Panel height and icon size are set in Nexus (Top panel), or by right-clicking the panel. They are stored in `desk/panel-settings.json`.

An app with a tray icon lives only in the tray, unless you pin it to the panel. Clicking its icon shows or hides the window, and the close button in the title bar only hides it. `Super + Q` always closes the window.

## Updating

```sh
desk-update
```

It commits and pushes the current state, runs `yay -Syu`, rebuilds `hyprbars` when it doesn't match the installed Hyprland and merges the installed Caelestia release into the patched copy. Both steps go by the current state, so they also catch up after a failed `yay` or an update run outside this script. A commit that looks like it contains a secret is refused.

The keyd config in `desk/system/keyd/` is the source of truth. `desk-update` only warns when `/etc/keyd` differs, and `desk/system/install-keyd.sh` applies the repository copy.

Caelestia uses a vendor branch: `upstream` holds clean releases and `master` holds them with my changes. If a merge conflicts, it is aborted and the copy stays as it was, so you can resolve it by hand with `git -C ~/.config/quickshell/caelestia merge upstream`.

`desk-update --snapshot` only commits and pushes. `desk-update --hyprbars` only rebuilds the plugin.

Without the plugin, windows just lose their title bars and everything else keeps working.
