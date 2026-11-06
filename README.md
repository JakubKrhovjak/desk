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

Panel and Night Shift state lives outside git, in `~/.local/state/desk`.

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
- Startup apps: `desk/autostart.json` holds absolute paths and can be edited in Nexus (Apps → app → Startup).
- Icons: the Simpleton theme in `~/.local/share/icons` is not part of this repository.

## Updating

```sh
desk-update
```

It commits and pushes the current state, runs `yay -Syu`, rebuilds `hyprbars` after a Hyprland update and merges new Caelestia releases into the patched copy.

Caelestia uses a vendor branch: `upstream` holds clean releases and `master` holds them with my changes. If a merge conflicts, it is aborted and the copy stays as it was, so you can resolve it by hand with `git -C ~/.config/quickshell/caelestia merge upstream`.

`desk-update --snapshot` only commits and pushes. `desk-update --hyprbars` only rebuilds the plugin.

Without the plugin, windows just lose their title bars and everything else keeps working.
